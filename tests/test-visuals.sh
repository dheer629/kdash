#!/usr/bin/env bash
# Validate the actual shared frame helpers across byte and UTF-8 locales. A
# malformed UTF-8 border or a wrapped frame row breaks the interactive screen.
set -euo pipefail
REPO="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
if ! command -v python3 >/dev/null 2>&1; then
    printf 'SKIP: frame encoding and width checks (optional python3 is unavailable)\n'
    exit 0
fi
python3 - "$REPO" <<'PY'
import os, re, subprocess, sys

script = r'''
set -uo pipefail
source "$1/src/inspector.sh"
source "$1/src/interactive.sh"
BARCHR=$2; COLOR=$3; w=$4
picker_colors; bx_init
bx_layout "$w" 0 24 10 14
bx_top "$w" REVIEW audited "${BX_J[@]}"; printf '%s\n' "$BX_LINE"
bx_sep "$w" x "${BX_J[@]}"; printf '%s\n' "$BX_LINE"
bx_bot "$w" saved verified "${BX_J[@]}"; printf '%s\n' "$BX_LINE"
bx_sep_mix "$w" '12 24' '24 48'; printf '%s\n' "$BX_LINE"
bx_row "$w" "${PC_B}content with │ borders and ░ fill${PC_R}"; printf '%s\n' "$BX_LINE"
BX_OUT=; BX_PREV='12 24'; bx_close "$w"; printf '%s' "$BX_OUT"
pk_fit "${PC_B}ab│cde█fg${PC_R}" 5; printf '%s\n' "$PK_FIT"
bx_pad "${PC_B}ab│cde█fg${PC_R}" 6; printf '%s\n' "$BX_PAD"
'''
ansi = re.compile(r"\x1b\[[0-9;]*[A-Za-z]")
cases = 0
for locale in ("C", "C.UTF-8"):
    for glyphs in ("ascii", "unicode"):
        for color in ("0", "1"):
            for width in (79, 99, 169):
                result = subprocess.run(
                    ["bash", "-s", "--", sys.argv[1], glyphs, color, str(width)],
                    input=script.encode(), capture_output=True,
                    env=dict(os.environ, LC_ALL=locale), check=True,
                )
                # decode() is deliberately strict: replacement glyphs conceal
                # a frame helper cutting or replacing half of a UTF-8 glyph.
                text = result.stdout.decode("utf-8")
                rows = ansi.sub("", text).splitlines()
                assert len(rows) == 8, (locale, glyphs, color, rows)
                for row in rows[:6]:
                    assert len(row) == width, (locale, glyphs, color, width, len(row), row)
                assert rows[6] == "ab│cd", (locale, glyphs, color, rows[6])
                assert len(rows[7]) == 6 and rows[7].endswith("~"), rows[7]
                if color == "0":
                    assert "\x1b[0m" not in text, text
                cases += 1
print(f"PASS: {cases} frame encoding, junction, clipping and width combinations (C/UTF-8, ASCII/Unicode, color/mono, 80/100/170 columns)")
PY
