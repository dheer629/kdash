#!/usr/bin/env bash
# Exercise the actual login screen in an isolated PTY with a fake kubectl. No
# kubeconfig, identity provider, browser, cluster or user terminal is accessed.
set -euo pipefail
REPO="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
if ! command -v python3 >/dev/null 2>&1; then
  printf 'SKIP: login-flow PTY checks require Python 3\n'
  exit 0
fi
export REPO
python3 - <<'PY'
import errno
import os
from pathlib import Path
import pty
import re
import select
import shutil
import signal
import tempfile
import time

repo = Path(os.environ['REPO'])
root = Path(tempfile.mkdtemp(prefix='kdash-login-flow-'))
ansi = re.compile(rb'\x1b\[[0-?]*[ -/]*[@-~]')
checks = 0
terminals = []

fixture = root / 'fixture-kubectl'
fixture.write_text(r'''#!/usr/bin/env bash
n=0; [ ! -f "$CASE_ROOT/count" ] || read -r n < "$CASE_ROOT/count"
n=$((n + 1)); printf '%s\n' "$n" > "$CASE_ROOT/count"
printf '%s\n' "${KDASH_LOGIN_TAG:-unset}" >> "$CASE_ROOT/tags"
case "$FIXTURE_MODE" in
  success) printf 'Username fixture-user\n'; exit 0 ;;
  retry) [ "$n" -lt 2 ] || { printf 'Username fixture-user\n'; exit 0; } ;;
esac
printf 'oidc-login: discovery error: Get https://id.example.test/.well-known/openid-configuration: dial tcp: no such host\n' >&2
exit 1
''')
fixture.chmod(0o755)

common = r'''
set -uo pipefail
source "$REPO/src/runtime.sh"
source "$REPO/src/interactive.sh"
export KDASH_LOGIN_TAG="fixture-session-$BASHPID"
LOGIN_HELPER_COMMAND="$FIXTURE_ROOT/fixture-kubectl"
TMPD="$CASE_ROOT/tmp"; TOOLKIT_DIR="$CASE_ROOT/toolkit"
mkdir -p "$TMPD" "$TOOLKIT_DIR"
CTX_NAME=fixture-context; ALTSCR=0; COLOR=0; INTERACTIVE=1
LOGIN_HAS_PLUGIN=1; LOGIN_NEEDED=0; LOGIN_AUTO_DONE=0
KC=("$FIXTURE_ROOT/fixture-kubectl" --context fixture-context)
FETCH_PID=""; TOOLKIT_PID=""; CERTQ_PID=""; FETCH_NEXT=0
TOOLKIT_REQUESTED=1; TOOLKIT_NEXT=0; VIEW=certs
login__issuer() { printf 'https://id.example.test\tfixture-client\n'; }
certs__kcfg() { :; }
audit() { printf '%s %s\n' "$1" "${2:-}" >> "$CASE_ROOT/audit"; }
flash() { printf '%s\n' "$1" >> "$CASE_ROOT/flashes"; }
cleanup() { printf 'CLEANUP\n'; }
fetch_worker() { touch "$CASE_ROOT/fetch-started"; }
events_collect() { touch "$CASE_ROOT/toolkit-started"; }
'''


class Terminal:
    def __init__(self, name, mode, script):
        self.path = root / name
        self.path.mkdir()
        self.buffer = b''
        self.transcript = b''
        self.reaped = False
        self.pid, self.fd = pty.fork()
        if self.pid == 0:
            os.environ.update(TERM='xterm', REPO=str(repo), FIXTURE_ROOT=str(root),
                              CASE_ROOT=str(self.path), FIXTURE_MODE=mode,
                              KDASH_LOGIN_POLL='60')
            os.execvp('bash', ['bash', '-c', common + script])
        terminals.append(self)

    def expect(self, needle, timeout=8):
        global checks
        needle = needle.encode()
        deadline = time.monotonic() + timeout
        while needle not in self.buffer:
            if time.monotonic() >= deadline:
                raise AssertionError(f'{self.path.name}: missing {needle!r}: {self.transcript[-2500:]!r}')
            ready, _, _ = select.select([self.fd], [], [], .1)
            if ready:
                try:
                    chunk = os.read(self.fd, 65536)
                except OSError as exc:
                    if exc.errno != errno.EIO:
                        raise
                    chunk = b''
                if not chunk:
                    raise AssertionError(f'{self.path.name}: exited before {needle!r}: {self.transcript[-2500:]!r}')
                chunk = ansi.sub(b'', chunk)
                self.buffer += chunk
                self.transcript += chunk
        self.buffer = self.buffer[self.buffer.index(needle) + len(needle):]
        checks += 1

    def send(self, value):
        os.write(self.fd, value)

    def exited(self, expected=0):
        global checks
        deadline = time.monotonic() + 4
        while time.monotonic() < deadline:
            pid, status = os.waitpid(self.pid, os.WNOHANG)
            if pid:
                self.reaped = True
                actual = os.waitstatus_to_exitcode(status)
                assert actual == expected, (self.path.name, actual, self.transcript[-2000:])
                checks += 1
                return
            time.sleep(.02)
        raise AssertionError(f'{self.path.name}: did not exit')

    def close(self):
        if not self.reaped:
            try:
                os.killpg(self.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            try:
                os.waitpid(self.pid, 0)
            except ChildProcessError:
                pass
        os.close(self.fd)


try:
    # Continuing suppresses both read engines and automatic login, while a later
    # explicit L action can still retry and resume the existing dashboard.
    for key in (b'c', b'C'):
        t = Terminal('continue-' + key.decode(), 'fail', r'''
rc=0; login_interactive session || rc=$?
printf '\nCONTINUED rc=%s needed=%s auto=%s\n' "$rc" "$LOGIN_NEEDED" "$LOGIN_AUTO_DONE"
[ -z "${LOGIN_ACTIVE_TAG:-}" ] && [ -z "${LOGIN_HP:-}" ] || exit 96
fetch; toolkit_tick
auto_rc=0; login_auto_maybe || auto_rc=$?
[ ! -e "$CASE_ROOT/fetch-started" ] || exit 91
[ ! -e "$CASE_ROOT/toolkit-started" ] || exit 92
printf 'PAUSED auto_rc=%s count=%s\n' "$auto_rc" "$(cat "$CASE_ROOT/count")"
export FIXTURE_MODE=success
login_interactive session || exit 93
printf 'RESUMED needed=%s auto=%s user=%s active=%s hp=%s next=%s\n' "$LOGIN_NEEDED" "$LOGIN_AUTO_DONE" "$LOGIN_USER" "${LOGIN_ACTIVE_TAG:-}" "${LOGIN_HP:-}" "$FETCH_NEXT"
''')
        t.expect('The identity provider https://id.example.test cannot be reached')
        t.expect('Check: curl -sS https://id.example.test/.well-known/openid-configuration')
        t.expect('q quit kdash  > ')
        t.send(key)
        t.expect('CONTINUED rc=1 needed=1 auto=1')
        t.expect('PAUSED auto_rc=1 count=1')
        t.expect('Logged in as fixture-user.')
        t.expect('RESUMED needed=0 auto=0 user=fixture-user active= hp= next=0')
        t.exited()
        tags = (t.path / 'tags').read_text().splitlines()
        assert len(tags) == 2 and len(set(tags)) == 2, tags
        assert all(re.fullmatch(r'fixture-session-\d+-login-\d+-\d+', tag) for tag in tags), tags
        checks += 2

    for key in (b'r', b'R'):
        t = Terminal('retry-' + key.decode(), 'retry', r'''
login_interactive start || exit 94
printf '\nRETRY_OK count=%s needed=%s auto=%s\n' "$(cat "$CASE_ROOT/count")" "$LOGIN_NEEDED" "$LOGIN_AUTO_DONE"
''')
        t.expect('q quit kdash  > ')
        t.send(key)
        t.expect('Logged in as fixture-user.')
        t.expect('RETRY_OK count=2 needed=0 auto=0')
        t.exited()
        tags = (t.path / 'tags').read_text().splitlines()
        assert len(tags) == 2 and len(set(tags)) == 2, ('retry reused its login attempt tag', tags)
        assert all(re.fullmatch(r'fixture-session-\d+-login-\d+-\d+', tag) for tag in tags), tags
        checks += 2

    # Startup continue has the same persistent pause, even before the main loop.
    t = Terminal('startup-continue', 'fail', r'''
rc=0; login_interactive start || rc=$?
printf '\nSTART_PAUSED rc=%s needed=%s auto=%s\n' "$rc" "$LOGIN_NEEDED" "$LOGIN_AUTO_DONE"
''')
    t.expect('before kdash can read anything')
    t.expect('q quit kdash  > ')
    t.send(b'c')
    t.expect('START_PAUSED rc=1 needed=1 auto=1')
    t.exited()

    t = Terminal('quit', 'fail', 'login_interactive session; exit 95\n')
    t.expect('q quit kdash  > ')
    t.send(b'q')
    t.expect('CLEANUP')
    t.exited(expected=4)

    print(f'PASS: {checks} login-flow PTY checks (no cluster or identity provider required)')
finally:
    for terminal in terminals:
        terminal.close()
    shutil.rmtree(root)
PY
