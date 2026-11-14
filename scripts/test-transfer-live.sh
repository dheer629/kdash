#!/usr/bin/env bash
# Opt-in transfer checks against an explicitly selected, writable test container.
# All container writes stay in one newly-created /tmp directory, removed on exit.
set -euo pipefail
if [ "$#" -lt 3 ] || [ "$#" -gt 5 ]; then
  printf 'Usage: bash scripts/test-transfer-live.sh NAMESPACE POD CONTAINER [OUTPUT_DIR] [--bin]\n' >&2
  exit 2
fi
REPO="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
source "$REPO/src/inspector.sh"
source "$REPO/src/interactive.sh"
LIVE_NS=$1; LIVE_POD=$2; LIVE_CONTAINER=$3
LIVE_OUT=${4:-"$REPO/artifacts/transfer-live-$(date +%Y%m%d-%H%M%S)"}
LIVE_BIN=${5:-}
[ -z "$LIVE_BIN" ] || [ "$LIVE_BIN" = --bin ] || { printf 'Unknown option: %s\n' "$LIVE_BIN" >&2; exit 2; }
mkdir -p -- "$LIVE_OUT"
LIVE_OUT="$(cd -- "$LIVE_OUT" && pwd)"
LIVE_WORK="$(mktemp -d /tmp/kdash-transfer-live.XXXXXXXX)"
LIVE_REMOTE=""
LIVE_WINDOWS_STAGE=""
KC=(kubectl --request-timeout=30s)
cleanup() {
  local rc=$?
  case "$LIVE_REMOTE" in /tmp/kdash-transfer-live.*)
    "${KC[@]}" -n "$LIVE_NS" exec "$LIVE_POD" -c "$LIVE_CONTAINER" -- rm -rf -- "$LIVE_REMOTE" >/dev/null 2>&1 || true ;;
  esac
  case "$LIVE_WORK" in /tmp/kdash-transfer-live.*) rm -rf -- "$LIVE_WORK" ;; esac
  case "$LIVE_WINDOWS_STAGE" in "$LIVE_OUT"/.bin-stage.*) rm -rf -- "$LIVE_WINDOWS_STAGE" ;; esac
  return "$rc"
}
trap cleanup EXIT
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
pass() { printf 'PASS: %s\n' "$*" | tee -a "$LIVE_OUT/results.txt"; }
: > "$LIVE_OUT/results.txt"
{
  printf 'context=%s\nnamespace=%s\npod=%s\ncontainer=%s\n' \
    "$(kubectl config current-context)" "$LIVE_NS" "$LIVE_POD" "$LIVE_CONTAINER"
  printf 'started_utc=%s\n' "$(date -u +%FT%TZ)"
} > "$LIVE_OUT/environment.txt"
LIVE_REMOTE="$("${KC[@]}" -n "$LIVE_NS" exec "$LIVE_POD" -c "$LIVE_CONTAINER" -- mktemp -d /tmp/kdash-transfer-live.XXXXXXXX)"
case "$LIVE_REMOTE" in /tmp/kdash-transfer-live.*) ;; *) fail 'unexpected remote temporary directory';; esac

mkdir -p "$LIVE_WORK/source/tree/empty dir" "$LIVE_WORK/source/tree/nested dir"
printf 'ordinary transfer data\n' > "$LIVE_WORK/source/plain file.txt"
dd if=/dev/urandom of="$LIVE_WORK/source/tree/nested dir/payload" bs=1024 count=128 status=none
printf A | dd of="$LIVE_WORK/source/tree/nested dir/payload" bs=1 count=1 conv=notrunc status=none
ln "$LIVE_WORK/source/tree/nested dir/payload" "$LIVE_WORK/source/tree/hardlink"
ln -s '../plain file.txt' "$LIVE_WORK/source/tree/file-link"
ln -s 'missing target' "$LIVE_WORK/source/dangling-link"
ln -s tree "$LIVE_WORK/source/directory-link"

round_trip() {
  local ns=$LIVE_NS pod=$LIVE_POD c=$LIVE_CONTAINER
  local lsrc="$LIVE_WORK/source" dst=$LIVE_REMOTE src stage part d XP_TOOLS=' tar sha256sum '
  local -a items=('plain file.txt' tree dangling-link directory-link)
  local -A STT=() STF=() STB=() STH=() DTT=() DTF=() DTB=() DTH=()
  local STALG='' DTALG='' XV_OK=0 XV_BAD=0 XV_SRC=LOCAL XV_DST=REMOTE
  BARCHR=ascii; xfer_glyphs
  d="$LIVE_WORK/upload-state"; mkdir -p "$d"; : > "$d/err"
  xfer_up_pipe || fail 'real upload pipeline'
  xfer_upload_sums || fail 'real upload checksum execution'
  xfer_sum_parse "$d/lsum" ST; xfer_sum_parse "$d/rsum" DT
  xfer_verify_table "$LIVE_OUT/upload-verify.tsv" "${items[@]}"
  [ "$XV_OK" = 4 ] && [ "$XV_BAD" = 0 ] || fail 'uploaded fixture differs'
  pass 'upload: file with spaces, tree, empty directory, symlinks and hardlinks verify'

  "${KC[@]}" -n "$ns" exec "$pod" -c "$c" -- sh -c \
    'printf X | dd of="$1/tree/nested dir/payload" bs=1 count=1 conv=notrunc 2>/dev/null' kdash "$dst"
  xfer_upload_sums || fail 'checksum execution after private corruption'
  STT=(); STF=(); STB=(); STH=(); DTT=(); DTF=(); DTB=(); DTH=()
  xfer_sum_parse "$d/lsum" ST; xfer_sum_parse "$d/rsum" DT
  xfer_verify_table "$LIVE_OUT/corruption-verify.tsv" "${items[@]}"
  [ "$XV_BAD" -gt 0 ] || fail 'same-size corruption escaped detection'
  pass 'same-size corruption in the uploaded tree is detected'
  xfer_up_pipe || fail 'restore private uploaded fixture'

  src=$LIVE_REMOTE; stage="$LIVE_WORK/download"; mkdir -p "$stage"
  d="$LIVE_WORK/download-state"; mkdir -p "$d"; : > "$d/err"; part="$d/received.tar"
  xfer_down_pipe || fail 'real download pipeline'
  tar xf "$part" -C "$stage"
  STT=(); STF=(); STB=(); STH=(); DTT=(); DTF=(); DTB=(); DTH=()
  xfer_download_sums || fail 'real download checksum execution'
  xfer_sum_parse "$d/rsum" ST; xfer_sum_parse "$d/lsum" DT
  XV_SRC=REMOTE; XV_DST=LOCAL
  xfer_verify_table "$LIVE_OUT/download-verify.tsv" "${items[@]}"
  [ "$XV_OK" = 4 ] && [ "$XV_BAD" = 0 ] || fail 'downloaded fixture differs'
  [ -d "$stage/tree/empty dir" ] || fail 'empty directory disappeared'
  [ "$(readlink "$stage/dangling-link")" = 'missing target' ] || fail 'dangling symlink changed'
  [ "$(stat -c '%d:%i' "$stage/tree/hardlink")" = "$(stat -c '%d:%i' "$stage/tree/nested dir/payload")" ] || fail 'hardlink was not retained'
  pass 'download: all fixture entries verify and empty directories/links survive'
}
round_trip

if [ "$LIVE_BIN" = --bin ]; then
  t0=$(date +%s%N)
  timeout 30s "${KC[@]}" -n "$LIVE_NS" exec "$LIVE_POD" -c "$LIVE_CONTAINER" -- \
    sh -c "$XFER_SUM_SH" kdash auto / bin > "$LIVE_OUT/bin-remote.sum"
  t1=$(date +%s%N)
  awk -v a="$t0" -v b="$t1" 'BEGIN {printf "remote_bin_seconds=%.3f\n", (b-a)/1e9}' | tee -a "$LIVE_OUT/environment.txt"
  "${KC[@]}" -n "$LIVE_NS" exec "$LIVE_POD" -c "$LIVE_CONTAINER" -- tar cf - -C / bin > "$LIVE_WORK/bin.tar"
  mkdir "$LIVE_WORK/bin-stage"
  LIVE_WINDOWS_STAGE=$(mktemp -d "$LIVE_OUT/.bin-stage.XXXXXXXX")
  for bin_stage in "$LIVE_WORK/bin-stage" "$LIVE_WINDOWS_STAGE"; do
    tar xf "$LIVE_WORK/bin.tar" -C "$bin_stage"
    t0=$(date +%s%N)
    timeout 30s sh -c "$XFER_SUM_SH" kdash auto "$bin_stage" bin > "$LIVE_WORK/bin-local.sum"
    t1=$(date +%s%N)
    cmp "$LIVE_OUT/bin-remote.sum" "$LIVE_WORK/bin-local.sum" || fail '/bin fingerprints differ after download'
    awk -v a="$t0" -v b="$t1" -v path="$bin_stage" 'BEGIN {printf "local_bin_seconds=%.3f path=%s\n", (b-a)/1e9, path}' | tee -a "$LIVE_OUT/environment.txt"
  done
  cp "$LIVE_WORK/bin-local.sum" "$LIVE_OUT/bin-local.sum"
  pass '/bin remote fingerprint matches downloads in WSL and the output filesystem'
fi
pass 'live transfer validation complete; private remote and staging data cleaned on exit'
