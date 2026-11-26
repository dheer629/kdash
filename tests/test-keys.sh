#!/usr/bin/env bash
# Regression for the dashboard key map: Events is reachable with e and E, and the
# HTML export menu lives on Ctrl-E so a lowercase e cannot open a prompt that
# swallows the next key. Static checks of the built CLI and the documentation.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
count=0
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
pass() { count=$((count + 1)); printf 'PASS: %s\n' "$*"; }

grep -Fq 'E|e) VIEW=events' "$ROOT/kdash" \
    || fail 'the dashboard does not open Events with lowercase e'
pass 'e and E both switch to the Events view'

grep -Fq "\$'\\005') printf" "$ROOT/kdash" \
    || fail 'the HTML menu is not bound to Ctrl-E'
pass 'the HTML export menu is bound to Ctrl-E'

if grep -Fq '    e) printf' "$ROOT/kdash"; then
    fail 'lowercase e still opens the HTML menu prompt'
fi
pass 'lowercase e no longer opens the HTML menu prompt'

grep -Fq 'E / e' "$ROOT/kdash" || fail 'the help text does not document E / e for Events'
grep -Fq '^E HTML menu' "$ROOT/kdash" || fail 'the help text does not document ^E for the HTML menu'
pass 'both keys appear in the dashboard help text'

grep -Fq '`E` / `e`' "$ROOT/README.md" || fail 'the README key table lacks e for Events'
grep -Fq '`^E` (Ctrl-E)' "$ROOT/README.md" || fail 'the README key table lacks Ctrl-E for the HTML menu'
pass 'the README key table documents both bindings'

grep -Fq '^E HTML menu' "$ROOT/kdash-bundle.sh" || fail 'the installer summary still advertises e for the HTML menu'
pass 'the installer summary matches the new binding'

# The dashboard search must ignore case for every pattern, including capitalised
# resource names. Slice the real function out of the built CLI and run it on a
# fixture body, so the assertion tests the shipped code.
source "$ROOT/src/inspector.sh"
search_tmp="$(mktemp -d "${TMPDIR:-/tmp}/kdash-search-test.XXXXXXXX")"
trap 'rm -rf -- "$search_tmp"' EXIT
printf 'Deployment app-server running\nz-crash CrashLoopBackOff\nNODE dev ready\n' > "$search_tmp/body"
awk '/^ds_match\(\) \{/,/^\}$/' "$ROOT/kdash" > "$search_tmp/ds_match.sh"
grep -Fq 'awk -v ic=1' "$search_tmp/ds_match.sh" || fail 'ds_match does not force case-insensitive matching'
BODYF="$search_tmp/body"; DS_MODE=find
source "$search_tmp/ds_match.sh"
ds_case() {
    DS_PAT="$1"; ds_match
    [ "$DS_N" = "$2" ] || fail "search '$1' found $DS_N line(s), expected $2"
}
ds_case app-server 1
ds_case App-Server 1
ds_case APP-SERVER 1
ds_case z-crash 1
ds_case Z-Crash 1
ds_case 'NODE' 1
ds_case 'node' 1
ds_case 'nope' 0
pass 'dashboard search ignores case for lowercase, capitalised and upper-case patterns'

grep -Fq 'search box: find in the view, case-insensitive' "$ROOT/kdash" \
    || fail 'the help text does not document the case-insensitive search'
grep -Fq 'Every pattern ignores case' "$ROOT/README.md" \
    || fail 'the README does not document the case-insensitive search'
pass 'documentation states that the dashboard search ignores case'

printf 'PASS: %s Events/HTML-menu/search key checks\n' "$count"
