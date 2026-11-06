#!/usr/bin/env bash
# Real terminal regression for read-only / interactive switching. Every API call
# goes to an isolated fixture; no cluster, kubeconfig or user terminal is used.
set -euo pipefail
REPO="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
if ! command -v python3 >/dev/null 2>&1; then
  printf 'SKIP: mode-switch PTY checks require Python 3\n'
  exit 0
fi
export REPO
python3 - <<'PY'
import errno
import fcntl
import os
from pathlib import Path
import pty
import re
import select
import shutil
import signal
import struct
import tempfile
import termios
import time

root = Path(tempfile.mkdtemp(prefix="kdash-mode-switch-"))
repo = Path(os.environ["REPO"])
ansi = re.compile(rb"\x1b\[[0-?]*[ -/]*[@-~]")
checks = 0

# Use the shipped guard, including the environment check performed on every
# invocation, rather than a test copy of its permission logic.
cli = (repo / "kdash").read_text()
guard = cli[cli.index("audit_wrap_kubectl() {"):]
guard = guard[:guard.index("\n}") + 2]
(root / "guard.sh").write_text(guard + "\n")
fixture = root / "kubectl"
fixture.write_text(r'''#!/usr/bin/env bash
printf '%s\t' "$@" >> "$FIXTURE_CALLS"; printf '\n' >> "$FIXTURE_CALLS"
verb=""; output=""; prev=""; previous=0
for arg in "$@"; do
  [ "$prev" != -o ] || output="$arg"
  case "$arg" in get|logs|describe|exec|cp) verb="$arg" ;; --previous) previous=1 ;; esac
  prev="$arg"
done
case "$verb" in
  exec|cp) printf 'FIXTURE_WRITE %s\n' "$verb" ;;
  get) case "$output" in
    *'.status.containerStatuses'*) printf 'web\ttrue\t0\t\t\t2026-11-06T00:00:00Z\t\t\n' ;;
    *'Name:'*)
      [ "${FIXTURE_SLOW_SUMMARY:-0}" = 0 ] || sleep "$FIXTURE_SLOW_SUMMARY"
      printf 'Name: mode-pod\nNamespace: alpha\nPhase: Running\n' ;;
    *'.spec.containers'*) printf 'app\tweb\tfixture:v1\n' ;;
    *) printf 'Name: mode-pod\n' ;;
  esac ;;
  logs) printf '2026-11-06T00:00:00Z INFO fixture previous=%s\n' "$previous" ;;
  describe) printf 'Name: mode-pod\n' ;;
  *) exit 97 ;;
esac
''')
fixture.chmod(0o755)
common = r'''
set -uo pipefail
source "$REPO/src/inspector.sh"
source "$REPO/src/interactive.sh"
source "$FIXTURE_ROOT/guard.sh"
export FIXTURE_CALLS="$CASE_ROOT/calls"
mkdir -p "$CASE_ROOT/tmp" "$CASE_ROOT/model" "$CASE_ROOT/toolkit"
TMPD="$CASE_ROOT/tmp"; MODEL="$CASE_ROOT/model"; TOOLKIT_DIR="$CASE_ROOT/toolkit"
CTX_NAME=fixture-context; NS=alpha; ALL_NS=0; COLOR=0; ALTSCR=0
KC=("$FIXTURE_ROOT/kubectl" --context fixture-context --request-timeout=3s)
audit() { printf '%s\t%s\n' "$1" "${2:-}" >> "$CASE_ROOT/audit"; }
flash() { :; }
fetch() { :; }
unset KDASH_ALLOW_INTERACTIVE
audit_wrap_kubectl
'''


class Terminal:
    def __init__(self, name, script, columns=120, rows=32, dynamic_size=False):
        self.path = root / name
        self.path.mkdir()
        self.buffer = b""
        self.transcript = b""
        self.pid, self.fd = pty.fork()
        if self.pid == 0:
            os.environ.update(TERM="xterm", REPO=str(repo), FIXTURE_ROOT=str(root),
                              CASE_ROOT=str(self.path),
                              KDASH_COLUMNS="" if dynamic_size else str(columns),
                              KDASH_LINES="" if dynamic_size else str(rows),
                              KDASH_INSPECT_FOLLOW="1")
            os.execvp("bash", ["bash", "-c", common + script])
        self.resize(columns, rows)

    def resize(self, columns, rows):
        fcntl.ioctl(self.fd, termios.TIOCSWINSZ,
                    struct.pack("HHHH", rows, columns, 0, 0))

    def send(self, value):
        os.write(self.fd, value)

    def expect(self, needle, timeout=8):
        global checks
        needle = needle.encode()
        deadline = time.monotonic() + timeout
        while needle not in self.buffer:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise AssertionError("%s missing %r; terminal tail %r" %
                                     (self.path.name, needle, self.transcript[-3500:]))
            ready, _, _ = select.select([self.fd], [], [], min(remaining, .15))
            if ready:
                try:
                    chunk = os.read(self.fd, 65536)
                except OSError as exc:
                    if exc.errno != errno.EIO:
                        raise
                    chunk = b""
                if not chunk:
                    raise AssertionError("%s exited waiting for %r; terminal tail %r" %
                                         (self.path.name, needle, self.transcript[-3500:]))
                chunk = ansi.sub(b"", chunk)
                self.buffer += chunk
                self.transcript += chunk
        self.buffer = self.buffer[self.buffer.index(needle) + len(needle):]
        checks += 1

    def close(self):
        try:
            os.kill(self.pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
        try:
            os.close(self.fd)
        except OSError:
            pass
        try:
            os.waitpid(self.pid, 0)
        except ChildProcessError:
            pass

    def expect_exit(self, timeout=3):
        global checks
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            pid, status = os.waitpid(self.pid, os.WNOHANG)
            if pid:
                assert os.waitstatus_to_exitcode(status) == 0, status
                checks += 1
                return
            time.sleep(.03)
        raise AssertionError("%s did not quit promptly" % self.path.name)


def confirmation(name, reply, enabled):
    t = Terminal("confirm-" + name, r'''
parent_int_seen=0
trap 'parent_int_seen=$((parent_int_seen + 1))' INT
trap -p INT > "$CASE_ROOT/trap.before"
tty_before="$(stty -g </dev/tty)"
printf 'CONFIRM_READY\n'
interactive_toggle
trap -p INT > "$CASE_ROOT/trap.after"
cmp -s "$CASE_ROOT/trap.before" "$CASE_ROOT/trap.after" || exit 90
[ "$(stty -g </dev/tty)" = "$tty_before" ] || exit 91
printf '\nRESTORED during=%s\n' "$parent_int_seen"
kill -INT "$$"
printf 'PARENT_INT=%s\n' "$parent_int_seen"
printf '%s\n' "${KDASH_ALLOW_INTERACTIVE:-0}" > "$CASE_ROOT/confirmation-result"
printf '\nRESULT mode=%s\n' "${KDASH_ALLOW_INTERACTIVE:-0}"
rc=0; "${KC[@]}" exec mode-pod -n alpha -- id >/dev/null 2>&1 || rc=$?
printf 'EXEC_RC=%s\n' "$rc"
rc=0; "${KC[@]}" cp /tmp/source alpha/mode-pod:/tmp/dest >/dev/null 2>&1 || rc=$?
printf 'CP_RC=%s\n' "$rc"
"${KC[@]}" get pod mode-pod -n alpha >/dev/null || exit 98
printf 'READ_OK\n'
# A confirmation must not leak Enter/escape bytes into the caller's key loop.
key=''; key_rc=0; IFS= read -rsn1 -t .2 key </dev/tty || key_rc=$?
printf 'NEXT_KEY=%q rc=%s\n' "$key" "$key_rc"
''', columns=80, rows=24)
    try:
        t.expect("CONFIRM_READY")
        t.expect("[y/N]")
        if isinstance(reply, list):
            t.send(reply[0])
            time.sleep(.15)
            assert not (t.path / "confirmation-result").exists(), "enabled before Enter confirmed"
            t.send(reply[1])
        else:
            t.send(reply)
        t.expect("RESTORED during=0")
        t.expect("PARENT_INT=1")
        t.expect("RESULT mode=%d" % enabled)
        t.expect("EXEC_RC=%d" % (0 if enabled else 126))
        t.expect("CP_RC=%d" % (0 if enabled else 126))
        t.expect("READ_OK")
        t.expect("NEXT_KEY='' rc=142", timeout=3)
    finally:
        t.close()


try:
    for name, reply, enabled in [
        ("y", b"y\r", 1), ("Y", b"Y\r", 1), ("yes-enter", b"yes\r", 1),
        ("YES-enter", b"YES\r", 1), ("n", b"n\r", 0), ("N", b"N\r", 0),
        ("wait-for-enter", [b"y", b"\r"], 1),
        ("backspace", b"yess\x7f\r", 1),
        ("clear-line", b"yes\x15n\r", 0), ("CRLF", b"yes\r\n", 1),
        ("invalid", b"maybe\r", 0),
        ("enter", b"\r", 0), ("escape", b"\x1b", 0),
        ("escape-sequence", b"\x1b[A", 0), ("q", b"q", 0),
        ("control-c", b"\x03", 0), ("control-d", b"\x04", 0),
    ]:
        confirmation(name, reply, enabled)

    # A real tty hangup makes the prompt's read fail. The mode must remain off;
    # the result is written outside the tty because its master has been closed.
    t = Terminal("confirm-eof", r'''
trap '' HUP
printf 'EOF_READY\n'
interactive_toggle
printf '%s\n' "${KDASH_ALLOW_INTERACTIVE:-0}" > "$CASE_ROOT/result"
''')
    t.expect("EOF_READY")
    t.expect("[y/N]")
    os.close(t.fd)
    deadline = time.monotonic() + 3
    while not (t.path / "result").exists() and time.monotonic() < deadline:
        time.sleep(.03)
    assert (t.path / "result").read_text().strip() == "0", "EOF enabled interactive mode"
    checks += 1
    t.close()

    t = Terminal("loading-toggle", r'''
export FIXTURE_SLOW_SUMMARY=2
mkdir -p "$TMPD/inspector/live"
inspector_detail alpha mode-pod "$TMPD/inspector/live"
printf '\nLOADING_EXIT mode=%s\n' "${KDASH_ALLOW_INTERACTIVE:-0}"
''')
    try:
        t.expect("reading summary")
        t.send(b"X")
        t.expect("[y/N]")
        t.send(b"yes\r")
        t.expect("interactive mode ON")
        t.send(b"q")
        t.expect("LOADING_EXIT mode=1")
    finally:
        t.close()

    t = Terminal("loading-quit", r'''
export FIXTURE_SLOW_SUMMARY=5
mkdir -p "$TMPD/inspector/live"
inspector_detail alpha mode-pod "$TMPD/inspector/live"
printf '\nUNEXPECTED_LOADING_RETURN\n'
exit 99
''')
    try:
        t.expect("reading summary")
        t.send(b"Q")
        t.expect_exit()
        assert "QUIT\t" in (t.path / "audit").read_text()
        checks += 1
    finally:
        t.close()

    t = Terminal("detail", r'''
printf 'KEY\tNAMESPACE\tPOD\tSTATUS\tREADY\tRESTARTS\tNODE\tPOOL\tPOD_IP\tHOST_IP\tQOS\tKIND\tWORKLOAD\nalpha/mode-pod\talpha\tmode-pod\tRunning\t1/1\t0\tfixture-node\tpool\t-\t-\t-\tDeployment\tfixture\n' > "$MODEL/pods.tsv"
# Keep shell execution on the audited path without launching a real shell.
interactive_shell() {
  local rc=0
  "${KC[@]}" -n "$1" exec -it "$2" -c "$3" -- id || rc=$?
  printf '\nATTACH_RC=%s target=%s/%s/%s\n' "$rc" "$1" "$2" "$3"
  return "$rc"
}
inspector_open
printf '\nPICKER_EXIT mode=%s\n' "${KDASH_ALLOW_INTERACTIVE:-0}"
''', dynamic_size=True)
    try:
        t.expect("SELECT POD")
        t.expect("READ-ONLY")
        t.send(b"\r")
        t.expect("POD DETAIL")
        t.expect("<?> keys")
        t.send(b"S")
        t.expect("Press X")
        for pane_key, pane_title in [(b"s", "SUMMARY"), (b"l", "LOGS"),
                                     (b"p", "PREVIOUS LOGS")]:
            t.send(pane_key)
            t.expect(pane_title)
            t.send(b"X")
            t.expect("[y/N]")
            t.send(b"y\r")
            t.expect("interactive mode ON")
            t.send(b"S")
            t.expect("ATTACH_RC=0 target=alpha/mode-pod/web")
            t.send(b"X")
            t.expect("interactive mode OFF")
            t.send(b"S")
            t.expect("Press X")
        t.send(b"f")
        t.expect("follow every 1s")
        t.resize(80, 24)
        t.send(b"X")
        t.expect("[y/N]")
        t.send(b"Y\r")
        t.expect("interactive mode ON")
        # Leave detail: the parent pod list must share the same exported mode.
        # Its permission state must remain visible at the narrow 80-column size.
        t.send(b"q")
        t.expect("SELECT POD")
        t.expect("INTERACTIVE")
        t.send(b"X")
        t.expect("interactive mode OFF")
        t.send(b"X")
        t.expect("[y/N]")
        t.send(b"n\r")
        t.expect("interactive mode stays off")
        t.send(b"q")
        t.expect("PICKER_EXIT mode=0")
        audit = (t.path / "audit").read_text()
        assert audit.count("INTERACTIVE_ON\t") == 4, audit
        assert audit.count("INTERACTIVE_OFF\t") == 4, audit
        calls = (t.path / "calls").read_text()
        assert calls.count("exec\t-it\tmode-pod\t-c\tweb\t--\tid") == 3, calls
        checks += 3
    finally:
        t.close()
    print("PASS: %d mode-switch terminal checks, guarded writes, detail panes, follow and parent state" % checks)
finally:
    shutil.rmtree(root)
PY
