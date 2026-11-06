#!/usr/bin/env bash
# Regenerate SHA256SUMS at the repository root.
#
# It covers what the repository ships: the Bash entry points, the documentation
# source modules, release helpers and sample gallery images.
# Verify with: sha256sum -c SHA256SUMS
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1
shopt -s nullglob

# Only refresh the selected run's galleries; historical manifests stay intact.
# Repeat --gallery samples/NAME to select explicit terminal or HTML galleries.
galleries=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --gallery)
      [ "$#" -ge 2 ] || { printf 'Missing --gallery directory\n' >&2; exit 2; }
      case "$2" in samples/cli_*|samples/html*) galleries+=("${2%/}");; *) printf 'Expected samples/cli_* or samples/html*: %s\n' "$2" >&2; exit 2;; esac
      shift 2;;
    *) printf 'Unknown option: %s\n' "$1" >&2; exit 2;;
  esac
done
if [ "${#galleries[@]}" -eq 0 ] && [ -f artifacts/latest-e2e.txt ]; then
  read -r run_name < artifacts/latest-e2e.txt
  if [ -f "artifacts/$run_name/captures.tsv" ]; then
    png=$(awk -F '\t' 'NR==1 { for(i=1;i<=NF;i++) if($i=="png") col=i; next } col { print $col; exit }' "artifacts/$run_name/captures.tsv")
    gallery=${png%/*}
    case "$gallery" in
      samples/cli_*) galleries+=("$gallery" "samples/html${gallery#samples/cli_}");;
    esac
  fi
fi

{
  for f in kdash kdash-bundle.sh kdash-uninstall.sh \
           README.md DEVOPS_USER_GUIDE.md KDASH_EXPLAINER.txt CHANGELOG.md \
           CONTRIBUTING.md CODE_OF_CONDUCT.md SECURITY.md LICENSE RELEASES.md \
           ENHANCEMENT_ROADMAP.md artifacts/README.md samples/README.md \
           samples/cli_*/README.md samples/html*/README.md \
           src/*.sh tests/*.sh scripts/*.sh scripts/*.py scripts/*.mjs \
           .editorconfig .gitattributes .gitignore .github/CODEOWNERS \
           .github/PULL_REQUEST_TEMPLATE.md .github/ISSUE_TEMPLATE/*.md \
           .github/ISSUE_TEMPLATE/*.yml .github/workflows/*.yml samples/*.png; do
    [ -f "$f" ] || continue
    sha256sum "$f"
  done
} > SHA256SUMS

# Each selected gallery carries its own manifest.
for set in "${galleries[@]}"; do
  [ -d "$set" ] || continue
  case "$set" in
    samples/cli_*)
      ( cd "$set" && find . -type f -name '*.png' -print0 | sort -z | xargs -0 -r sha256sum > SHA256SUMS );;
    samples/html*)
      ( cd "$set" && find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 -r sha256sum > SHA256SUMS );;
  esac
  printf '%s/SHA256SUMS written: %s entries\n' "$set" "$(wc -l < "$set/SHA256SUMS")"
done

printf 'SHA256SUMS written: %s entries\n' "$(wc -l < SHA256SUMS)"
