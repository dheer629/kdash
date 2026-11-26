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

printf 'PASS: %s Events/HTML-menu key checks\n' "$count"
