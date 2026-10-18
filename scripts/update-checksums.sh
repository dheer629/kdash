#!/usr/bin/env bash
# Regenerate SHA256SUMS at the repository root.
#
# It covers what the repository ships: the Bash entry points, the documentation
# and the sample gallery images. Verify with:  sha256sum -c SHA256SUMS
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1

{
  for f in kdash kdash-bundle.sh kdash-uninstall.sh tests/test-uninstall.sh \
           README.md DEVOPS_USER_GUIDE.md KDASH_EXPLAINER.txt \
           artifacts/README.md samples/README.md; do
    [ -f "$f" ] && sha256sum "$f"
  done
  for f in $(ls -1 samples/*.png 2>/dev/null | LC_ALL=C sort); do
    sha256sum "$f"
  done
} > SHA256SUMS

printf 'SHA256SUMS written: %s entries\n' "$(wc -l < SHA256SUMS)"
