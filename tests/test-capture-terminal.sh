#!/usr/bin/env bash
# The saved ANSI replay must preserve bright grey and independent bold state on
# distro pyte as well as current pip pyte; no cluster or desktop is required.
set -euo pipefail
REPO="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
if ! python3 -c 'import pyte, PIL' >/dev/null 2>&1; then
  printf 'SKIP: terminal replay palette checks (optional pyte/Pillow unavailable)\n'
  exit 0
fi
python3 - "$REPO" <<'PY'
import importlib.util
from pathlib import Path
import sys
import pyte

spec = importlib.util.spec_from_file_location('capture_terminal', Path(sys.argv[1])/'scripts/capture-terminal.py')
capture = importlib.util.module_from_spec(spec)
spec.loader.exec_module(capture)
names = ('black', 'red', 'green', 'brown', 'blue', 'magenta', 'cyan', 'white')
checks = 0
for offset, name in enumerate(names):
    for code, component in ((90 + offset, 0), (100 + offset, 1)):
        screen = capture.CaptureScreen(12, 2)
        pyte.Stream(screen).feed(f'\033[{code}mX')
        cell = screen.buffer[0][0]
        assert capture.cell_colors(cell)[component] == capture.PALETTE['bright' + name], (code, cell)
        assert not cell.bold, (code, 'brightness unexpectedly enables bold', cell)
        checks += 1

screen = capture.CaptureScreen(30, 2)
pyte.Stream(screen).feed('\033[1;90mA\033[22mB\033[0mC\033[38;2;90;91;92mD\033[38;5;90mE\033[90;7mF')
cells = screen.buffer[0]
assert cells[0].bold and not cells[1].bold
assert capture.cell_colors(cells[0])[0] == capture.PALETTE['brightblack']
assert capture.cell_colors(cells[1])[0] == capture.PALETTE['brightblack']
assert capture.cell_colors(cells[2]) == (capture.FOREGROUND, capture.BACKGROUND)
assert capture.cell_colors(cells[3])[0] == '#5a5b5c'
assert capture.cell_colors(cells[4])[0] == '#870087'
assert capture.cell_colors(cells[5]) == (capture.BACKGROUND, capture.PALETTE['brightblack'])
print(f'PASS: {checks + 7} terminal replay checks preserve bright colors, bold, reset, RGB/indexed payloads and reverse video')
PY
