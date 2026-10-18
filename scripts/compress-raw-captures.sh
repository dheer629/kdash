#!/usr/bin/env bash
# Compress the raw tmux terminal captures of a validation run and record the
# sha256 of every file before it is compressed.
#
# A five-minute live TUI writes several megabytes of raw pane output per
# namespace. The bytes are evidence, so they are kept - just gzip -9 compressed,
# with a hash manifest beside them so the original content stays verifiable
# (gzip also stores the original size and CRC32 in its trailer).
#
# Usage: bash scripts/compress-raw-captures.sh artifacts/<run-id>
set -uo pipefail

run="${1:?usage: bash scripts/compress-raw-captures.sh <run-directory>}"
[ -d "$run" ] || { printf 'not a directory: %s\n' "$run" >&2; exit 1; }

manifest="$run/RAW-TERMINAL-SHA256.txt"
{
  printf '# sha256 of every terminal.raw.log before gzip -9 compression\n'
  for f in "$run"/*/terminal.raw.log; do
    [ -f "$f" ] || continue
    sha256sum "$f"
  done
} > "$manifest"
gzip -9 "$run"/*/terminal.raw.log || exit 1

printf 'compressed:\n'
ls -l "$run"/*/terminal.raw.log.gz
printf 'manifest: %s\n' "$manifest"
printf 'read one with: zcat %s/<namespace>/terminal.raw.log.gz | less\n' "$run"
