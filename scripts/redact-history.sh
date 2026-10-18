#!/usr/bin/env bash
# Rewrite a branch so that no commit carries the names of a private mapping file.
# This is the companion of scripts/redact-run.sh for data that is already
# committed; the mapping file itself must never be committed.
#
#   bash scripts/redact-history.sh --map ~/map.tsv [--branch main]
#
# What the rewrite does in every commit
#   * replaces the mapped names in text files and in gzip-compressed captures
#   * renames files and directories whose name carries a mapped name
#   * in the commits that still contain a mapped name (the pre-redaction ones) it
#     also drops the screenshot images, because an image cannot be edited as text:
#     those images are re-rendered from the redacted captures in the tip commit
#
# Before it runs, the working tree must be clean and the tip commit must already be
# redacted. Rewriting history changes commit ids, so only do this on unpublished
# history, or publish with:  git push --force-with-lease origin <branch>
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1

MAP=""; BRANCH=main
while [ "$#" -gt 0 ]; do
  case "$1" in
    --map)    MAP="${2:?}"; shift 2 ;;
    --branch) BRANCH="${2:?}"; shift 2 ;;
    -h|--help) sed -n '2,18p' "$0"; exit 0 ;;
    *) printf 'unknown option: %s\n' "$1" >&2; exit 2 ;;
  esac
done
[ -n "$MAP" ] && [ -f "$MAP" ] || { printf 'a mapping file is required: --map FILE\n' >&2; exit 2; }
[ -z "$(git status --porcelain --untracked-files=no)" ] || { printf 'tracked files are modified - commit first\n' >&2; exit 1; }

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
SED="$WORK/redact.sed"; PATTERNS="$WORK/patterns"; FILTER="$WORK/filter.sh"
: > "$SED"; : > "$PATTERNS"
{
  printf '#!/usr/bin/env bash\nset -uo pipefail\n'
  printf 'if grep -qF -f %q README.md DEVOPS_USER_GUIDE.md KDASH_EXPLAINER.txt 2>/dev/null; then\n' "$PATTERNS"
  printf '  find samples -name "*.png" -delete 2>/dev/null\n'
  printf '  find samples -type d -empty -delete 2>/dev/null\n'
  printf 'fi\n'
  printf 'find . -path ./.git -prune -o -type f ! -name "*.png" ! -name "*.lock" ! -name "*.gz" -print0 | xargs -0 -r sed -i -f %q\n' "$SED"
  printf 'find . -path ./.git -prune -o -type f -name "*.gz" -print0 | while IFS= read -r -d "" gz; do\n'
  printf '  zcat -- "$gz" | sed -f %q | gzip -9 -n > "$gz.new" && mv -- "$gz.new" "$gz"\n' "$SED"
  printf 'done\n'
  printf 'find . -path ./.git -prune -o -depth -print0 | while IFS= read -r -d "" p; do\n'
  printf '  base="$(basename -- "$p")"; new="$base"\n'
} > "$FILTER"
while IFS= read -r line; do
  case "$line" in ''|'#'*) continue ;; esac
  from="${line%%$'\t'*}"; to="${line#*$'\t'}"
  [ "$from" = "$line" ] && continue
  printf '%s\n' "$from" >> "$PATTERNS"
  escaped="$(printf '%s' "$from" | sed 's/[][\\.^$*+?(){}|/]/\\&/g')"
  printf 's/%s/%s/g\n' "$escaped" "$to" >> "$SED"
  printf '  new="${new//%s/%s}"\n' "$from" "$to" >> "$FILTER"
done < <(awk -F'\t' 'NF>=2 { print length($1) "\t" $0 }' "$MAP" | sort -rn -k1,1 | cut -f2-)
{
  printf '  if [ "$new" != "$base" ]; then mv -n -- "$p" "$(dirname -- "$p")/$new"; fi\n'
  printf 'done\n'
} >> "$FILTER"
chmod 755 "$FILTER"
[ -s "$SED" ] || { printf 'the mapping file has no usable pairs\n' >&2; exit 2; }

export FILTER_BRANCH_SQUELCH_WARNING=1
git filter-branch --force --prune-empty --tree-filter "$FILTER" -- "$BRANCH" || exit 1
git update-ref -d "refs/original/refs/heads/$BRANCH" 2>/dev/null || true
git reflog expire --expire=now --all
git gc --prune=now --quiet

printf '\n=== commits on %s\n' "$BRANCH"
git --no-pager log --oneline "$BRANCH"
printf '=== remaining matches in any commit of %s (must be empty)\n' "$BRANCH"
git rev-list "$BRANCH" | while read -r c; do
  git grep -I -F -f "$PATTERNS" "$c" -- . 2>/dev/null
done | head -10
printf '=== files whose name still carries a mapped name (must be empty)\n'
git ls-tree -r --name-only "$BRANCH" | grep -F -f "$PATTERNS" || true
