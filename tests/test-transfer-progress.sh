#!/usr/bin/env bash
# Run the actual transfer progress UI in a controlling PTY. Verify completion
# when streamed tar bytes differ from the estimate, and stop nested verification
# workers with q without leaving background work running.
set -euo pipefail
command -v python3 >/dev/null 2>&1 || { printf 'SKIP: transfer PTY checks need optional python3\n'; exit 0; }
REPO="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
PROGRESS_TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/kdash-progress-tests.XXXXXXXX")"
trap 'rm -rf -- "$PROGRESS_TEST_ROOT"' EXIT
python3 - "$REPO" "$PROGRESS_TEST_ROOT" <<'PY'
import errno
import os
from pathlib import Path
import pty
import select
import signal
import sys
import time

repo, root = map(Path, sys.argv[1:])
worker = root / "worker.sh"
worker.write_text(r'''#!/usr/bin/env bash
set -uo pipefail
source "$1/src/inspector.sh"
source "$1/src/interactive.sh"
mode=$2; fixture=$3
COLOR=0; BARCHR=ascii; picker_colors
picker_size() { PK_COLS=120; PK_ROWS=32; }
copy_job() { head -c 422912 /dev/zero > "$fixture/count"; sleep 0.2; [ "$mode" != failed ]; }
verify_job() { python3 "$fixture/../tree.py" 4 "$fixture/pids"; }
quick_verify() { sleep 0.2; }
rc=0
case "$mode" in
    cancel) XFER_EXPECT=0 xfer_run_bg VERIFYING '' -- verify_job || rc=$? ;;
    verify) XFER_EXPECT=0 xfer_run_bg VERIFYING '' -- quick_verify || rc=$? ;;
    *) : > "$fixture/count"; XFER_EXPECT=1048576 xfer_run_bg COPYING "$fixture/count" -- copy_job || rc=$? ;;
esac
printf '\nRESULT_RC=%s\n' "$rc"
# Keep the controlling terminal alive while the test inspects workers. Exiting
# the session leader would send SIGHUP and could hide a cancellation leak.
if [ "$mode" = cancel ]; then IFS= read -r _ </dev/tty; fi
''')
(root / "tree.py").write_text('''import os, subprocess, sys, time
depth = int(sys.argv[1])
with open(sys.argv[2], "a") as f:
    f.write(str(os.getpid()) + "\\n")
if depth:
    child = subprocess.Popen([sys.executable, __file__, str(depth - 1), sys.argv[2]])
    child.wait()
else:
    time.sleep(600)
''')

def pids_for(fixture):
    try:
        return [int(line) for line in (fixture / "pids").read_text().splitlines()]
    except FileNotFoundError:
        return []

def running(pid):
    try:
        return Path(f"/proc/{pid}/stat").read_text().split(") ", 1)[1][0] != "Z"
    except FileNotFoundError:
        return False

def run(mode):
    fixture = root / mode
    fixture.mkdir()
    pid, fd = pty.fork()
    if pid == 0:
        os.execvp("bash", ["bash", str(worker), str(repo), mode, str(fixture)])
    output = bytearray()
    cancelled = False
    cancellation_checked = False
    exited = False
    try:
        deadline = time.monotonic() + 10
        while time.monotonic() < deadline:
            if mode == "cancel" and not cancelled and len(pids_for(fixture)) == 5:
                os.write(fd, b"q")
                cancelled = True
            ready, _, _ = select.select([fd], [], [], 0.05)
            if ready:
                try:
                    chunk = os.read(fd, 65536)
                    if chunk:
                        output.extend(chunk)
                except OSError as error:
                    if error.errno != errno.EIO:
                        raise
            if mode == "cancel" and not cancellation_checked and b"RESULT_RC=130" in output:
                stop_deadline = time.monotonic() + 2
                while time.monotonic() < stop_deadline and any(map(running, pids_for(fixture))):
                    time.sleep(0.05)
                alive = [p for p in pids_for(fixture) if running(p)]
                assert not alive, f"cancel left verification workers running: {alive}"
                cancellation_checked = True
                os.write(fd, b"\n")
            waited, status = os.waitpid(pid, os.WNOHANG)
            if waited:
                exited = True
                assert os.waitstatus_to_exitcode(status) == 0, output.decode(errors="replace")
                break
        assert exited, f"{mode} progress UI did not return"
        text = output.decode(errors="replace")
        if mode == "cancel":
            assert cancelled, "verification worker did not start its nested processes"
            assert "RESULT_RC=130" in text and "cancelled" in text, text
            assert cancellation_checked, "verification cancellation did not stop its workers"
        elif mode == "success":
            assert "RESULT_RC=0" in text and "100%" in text and "413.0 KiB transferred" in text, text
        elif mode == "failed":
            assert "RESULT_RC=1" in text and "failed" in text and "100%" not in text, text
        else:
            assert "RESULT_RC=0" in text and "checking files" in text and "100%" not in text, text
    finally:
        for child in pids_for(fixture):
            if running(child):
                try:
                    os.kill(child, signal.SIGKILL)
                except ProcessLookupError:
                    pass
        if not exited:
            try:
                os.kill(pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            os.waitpid(pid, 0)
        os.close(fd)

for mode in ("success", "failed", "verify", "cancel"):
    run(mode)
print("PASS: progress reaches 100% only after success; verification is cancellable and all nested workers stop")
PY
