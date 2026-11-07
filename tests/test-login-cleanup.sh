#!/usr/bin/env bash
# Exercise login cleanup against private synthetic processes, never a real login,
# kubeconfig or cluster. Test teardown uses pidfds where Linux provides them.
set -euo pipefail
REPO="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
if ! command -v python3 >/dev/null 2>&1 || [ ! -d /proc/self ]; then
  printf 'SKIP: login-cleanup checks require Python 3 and Linux procfs\n'
  exit 0
fi
export REPO
python3 - <<'PY'
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import uuid

repo = Path(os.environ["REPO"])
root = Path(tempfile.mkdtemp(prefix="kdash-login-cleanup-"))
tag = "kdash-test-" + uuid.uuid4().hex
checks = 0
owned = []


def start_time(pid):
    try:
        # The comm between parentheses may itself contain spaces/parentheses.
        return Path("/proc/%d/stat" % pid).read_text().rsplit(") ", 1)[1].split()[19]
    except (OSError, IndexError):
        return None


def alive(pid):
    try:
        return Path("/proc/%d/stat" % pid).read_text().rsplit(") ", 1)[1].split()[0] != "Z"
    except (OSError, IndexError):
        return False


def register(pid, proc=None):
    pidfd = None
    if hasattr(os, "pidfd_open"):
        try:
            pidfd = os.pidfd_open(pid)
        except OSError:
            pass
    owned.append((pid, start_time(pid), pidfd, proc))


helper_source = r'''
import ctypes, os, signal, subprocess, sys, time
from pathlib import Path
name = os.environ.get("FIXTURE_COMM", "login fixture").encode()[:15]
ctypes.CDLL(None).prctl(15, name, 0, 0, 0)
if os.environ.get("FIXTURE_IGNORE_TERM") == "1":
    signal.signal(signal.SIGTERM, signal.SIG_IGN)
if os.environ.get("FIXTURE_CHILD"):
    child_env = os.environ.copy()
    child_env.pop("FIXTURE_CHILD", None)
    child_env["FIXTURE_READY"] = os.environ["FIXTURE_CHILD_READY"]
    child_env["FIXTURE_COMM"] = "child ) helper"
    child = subprocess.Popen([sys.executable, os.environ["FIXTURE_CHILD"], "get-token"],
                             env=child_env, start_new_session=True)
    Path(os.environ["FIXTURE_CHILD_PID"]).write_text(str(child.pid))
    if os.environ.get("FIXTURE_DETACH") == "1":
        sys.exit(0)
Path(os.environ["FIXTURE_READY"]).write_text(str(os.getpid()))
while True:
    time.sleep(1)
'''
for name in ("kubelogin", "kubectl-oidc_login", "kubectl-oidc-login", "oidc-login", "oidc_login",
             "company-auth-helper", "browser", "not-kubelogin", "worker"):
    (root / name).write_text(helper_source)
(root / "credential-path").mkdir()
(root / "credential-path" / "worker").write_text(helper_source)


def wait_file(path, timeout=4):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if path.exists() and path.stat().st_size:
            return path.read_text().strip()
        time.sleep(.02)
    raise AssertionError("fixture did not become ready: " + str(path))


def launch(name, process_tag=tag, args=(), ignore_term=False, child=False, detach=False):
    identity = uuid.uuid4().hex
    ready = root / (identity + ".ready")
    env = os.environ.copy()
    env.pop("KDASH_LOGIN_TAG", None)
    if process_tag is not None:
        env["KDASH_LOGIN_TAG"] = process_tag
    env.update(FIXTURE_READY=str(ready), FIXTURE_COMM="parent ) helper")
    if ignore_term:
        env["FIXTURE_IGNORE_TERM"] = "1"
    if child:
        env.update(FIXTURE_CHILD=str(root / "kubelogin"),
                   FIXTURE_CHILD_READY=str(root / (identity + ".child-ready")),
                   FIXTURE_CHILD_PID=str(root / (identity + ".child-pid")),
                   FIXTURE_DETACH="1" if detach else "0")
    proc = subprocess.Popen([sys.executable, str(root / name), *args], env=env,
                            stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                            stderr=subprocess.DEVNULL, start_new_session=True)
    register(proc.pid, proc)
    child_pid = None
    if child:
        child_pid = int(wait_file(root / (identity + ".child-pid")))
        register(child_pid)
        wait_file(root / (identity + ".child-ready"))
    if detach:
        assert proc.wait(timeout=4) == 0
    else:
        wait_file(ready)
    return proc, child_pid


def run_shell(command, process_tag=tag, keep=None, configured="company-auth-helper", extra_env=None):
    env = os.environ.copy()
    env.pop("KDASH_LOGIN_TAG", None)
    if process_tag is not None:
        env["KDASH_LOGIN_TAG"] = process_tag
    env.update(REPO=str(repo), FIXTURE_KEEP=str(keep or ""),
               FIXTURE_CONFIGURED=configured)
    if extra_env:
        env.update(extra_env)
    # A fresh session also ensures an accidentally reintroduced old session-wide
    # pkill cannot reach the test driver, fixtures or any user's terminal session.
    result = subprocess.run(["bash", "-c", r'''
set -uo pipefail
source "$REPO/src/interactive.sh"
for helper in login__process_start login__is_descendant login__is_helper; do
  declare -F "$helper" >/dev/null || { printf 'missing helper: %s\n' "$helper" >&2; exit 92; }
done
LOGIN_HELPER_COMMAND="$FIXTURE_CONFIGURED"
certs__kcfg() { printf '%s' "$FIXTURE_CONFIGURED"; }
''' + command], env=env, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE, text=True, timeout=20,
                            start_new_session=True)
    assert result.returncode == 0, (command, result.returncode, result.stdout, result.stderr)
    return result.stdout.strip()


def check_alive(pid, label):
    global checks
    assert alive(pid), label + " was terminated"
    checks += 1


def check_dead(pid, label):
    global checks
    deadline = time.monotonic() + 2
    while alive(pid) and time.monotonic() < deadline:
        time.sleep(.02)
    assert not alive(pid), label + " survived cleanup"
    checks += 1


try:
    # One cleanup sweep must kill only this session's actual helper identities.
    stale, _ = launch("kubelogin", args=("get-token",))
    resistant, _ = launch("oidc-login", ignore_term=True)
    configured, _ = launch("company-auth-helper")
    other, _ = launch("kubelogin", process_tag=tag + "-other", args=("get-token",))
    untagged, _ = launch("kubelogin", process_tag=None, args=("get-token",))
    browser, _ = launch("browser", args=("https://credential.example.test/login",))
    credential_path, _ = launch("credential-path/worker")
    lookalike, _ = launch("not-kubelogin", args=("get-token",))
    argument_only, _ = launch("browser", args=(str(root / "kubelogin"), "get-token"))
    keeper, kept_child = launch("worker", child=True)
    # Both the ancestor and child have spaces and ')' in comm. Test start-time
    # parsing and ancestor walking independently before trusting the keep filter.
    observed = run_shell('login__process_start "$FIXTURE_KEEP"', keep=kept_child)
    assert observed == start_time(kept_child), (observed, start_time(kept_child))
    checks += 1
    descendant = run_shell('login__is_descendant %d "$FIXTURE_KEEP" && printf YES' % kept_child,
                           keep=keeper.pid)
    assert descendant == "YES", "kept descendant not recognized with spaces in comm"
    checks += 1
    run_shell('login__kill_stale "$FIXTURE_KEEP"', keep=keeper.pid)
    for proc, label in ((stale, "same-tag helper"), (resistant, "TERM-resistant helper"),
                        (configured, "configured exec helper")):
        check_dead(proc.pid, label)
    assert stale.wait(timeout=2) == -signal.SIGTERM, "ordinary helper was not stopped with TERM"
    assert resistant.wait(timeout=2) == -signal.SIGKILL, "TERM-resistant helper was not escalated"
    checks += 2
    for pid, label in ((other.pid, "other session helper"), (untagged.pid, "untagged helper"),
                       (browser.pid, "unrelated browser URL"), (credential_path.pid, "credential path"),
                       (lookalike.pid, "lookalike helper name"), (argument_only.pid, "helper name in arguments"),
                       (keeper.pid, "kept parent"), (kept_child, "kept descendant")):
        check_alive(pid, label)

    # An untagged caller must be a no-op even with recognizable helpers present.
    run_shell('login__kill_stale', process_tag=None)
    check_alive(kept_child, "helper after tagless cleanup")
    check_alive(untagged.pid, "untagged helper after tagless cleanup")

    # Every built-in helper name must work when executed as a script through
    # Python, while identity remains based on the command rather than arguments.
    names = ("kubectl-oidc_login", "kubectl-oidc-login", "oidc_login")
    builtins = [launch(name)[0] for name in names]
    run_shell('login__kill_stale')
    check_dead(kept_child, "released kept descendant")
    for proc, name in zip(builtins, names):
        check_dead(proc.pid, name)

    # A foreground login uses its own tag, so detached/reparented helpers survive
    # ordinary background-probe cleanup and are removed explicitly at completion.
    active_tag = tag + "-active"
    _, active_child = launch("worker", process_tag=active_tag, child=True, detach=True)
    run_shell('login__kill_stale')
    check_alive(active_child, "detached active login helper")
    run_shell('login__kill_stale', process_tag=active_tag)
    check_dead(active_child, "completed active login helper")

    # PID reuse cannot be forced reliably. Instead change the returned birth
    # identity after discovery, while a real owned helper remains available for
    # signaling. Omitting either signal-time recheck would terminate the fixture.
    for change_at, ignore_term in ((2, False), (3, True)):
        race_tag = tag + "-identity-%d" % change_at
        race, _ = launch("kubelogin", process_tag=race_tag, ignore_term=ignore_term)
        counter = root / ("identity-%d.count" % change_at)
        run_shell(r'''
eval "$(declare -f login__process_start | sed '1s/login__process_start/login__fixture_original_start/')"
login__process_start() {
  local count=0
  if [ "$1" = "$FIXTURE_RACE_PID" ]; then
    [ ! -r "$FIXTURE_RACE_COUNTER" ] || read -r count < "$FIXTURE_RACE_COUNTER"
    count=$((count + 1)); printf '%s\n' "$count" > "$FIXTURE_RACE_COUNTER"
    if [ "$count" -ge "$FIXTURE_RACE_CHANGE_AT" ]; then printf '0'; return 0; fi
  fi
  login__fixture_original_start "$1"
}
login__kill_stale
''', process_tag=race_tag,
                  extra_env={"FIXTURE_RACE_PID": str(race.pid),
                             "FIXTURE_RACE_COUNTER": str(counter),
                             "FIXTURE_RACE_CHANGE_AT": str(change_at)})
        assert int(counter.read_text()) >= change_at, "identity was not rechecked before signaling"
        checks += 1
        check_alive(race.pid, "changed identity before " + ("TERM" if change_at == 2 else "KILL"))

    print("PASS: %d login-cleanup checks, exact helper/tag scope, keep tree, detached login and TERM/KILL" % checks)
finally:
    for pid, expected_start, pidfd, proc in reversed(owned):
        try:
            if pidfd is not None and hasattr(signal, "pidfd_send_signal"):
                signal.pidfd_send_signal(pidfd, signal.SIGKILL)
            elif expected_start is not None and start_time(pid) == expected_start:
                os.kill(pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        finally:
            if pidfd is not None:
                os.close(pidfd)
        if proc is not None:
            try:
                proc.wait(timeout=2)
            except subprocess.TimeoutExpired:
                pass
    shutil.rmtree(root)
PY
