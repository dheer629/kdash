#!/usr/bin/env bash
# Regenerate SHA256SUMS at the repository root.
#
# It covers what the repository ships: the Bash entry points, the documentation
# source modules, release helpers and sample gallery images.
# Verify with: sha256sum -c SHA256SUMS
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1
shopt -s nullglob

{
  for f in kdash kdash-bundle.sh kdash-uninstall.sh \
           README.md DEVOPS_USER_GUIDE.md KDASH_EXPLAINER.txt CHANGELOG.md \
           CONTRIBUTING.md CODE_OF_CONDUCT.md SECURITY.md LICENSE RELEASES.md \
           ENHANCEMENT_ROADMAP.md artifacts/README.md samples/README.md \
           samples/cli_413/README.md samples/cli_414/README.md \
           src/*.sh tests/*.sh scripts/*.sh scripts/*.py \
           .editorconfig .gitattributes .gitignore .github/CODEOWNERS \
           .github/PULL_REQUEST_TEMPLATE.md .github/ISSUE_TEMPLATE/*.md \
           .github/ISSUE_TEMPLATE/*.yml .github/workflows/*.yml samples/*.png; do
    [ -f "$f" ] || continue
    sha256sum "$f"
  done
} > SHA256SUMS

# Each published screenshot set carries its own manifest.
for set in samples/cli_413 samples/cli_414; do
  [ -d "$set" ] || continue
  ( cd "$set" && sha256sum ./*.png > SHA256SUMS )
  printf '%s/SHA256SUMS written: %s entries\n' "$set" "$(wc -l < "$set/SHA256SUMS")"
done

printf 'SHA256SUMS written: %s entries\n' "$(wc -l < SHA256SUMS)"
