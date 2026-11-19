#!/usr/bin/env bash
# Rotated-log reads use fixture bytes only; no kubeconfig or cluster is consulted.
set -euo pipefail
REPO="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
source "$REPO/src/inspector.sh"
source "$REPO/src/interactive.sh"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/kdash-log-history.XXXXXXXX")"
trap 'case "$TEST_ROOT" in "${TMPDIR:-/tmp}"/kdash-log-history.*) rm -rf -- "$TEST_ROOT" ;; esac' EXIT
TMPD="$TEST_ROOT/tmp"; mkdir -p "$TMPD"
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
checks=0
pass() { checks=$((checks + 1)); }
has() { grep -Fq -- "$2" "$1" || fail "$1 lacks $2"; pass; }

# Exercise CRI partial-line joining and Docker JSON decoding independently of
# transport, then exercise plain/gzip rotation order and aggregate byte limits.
printf '%s\n' \
  '2026-11-18T00:00:00Z stdout P hel' \
  '2026-11-18T00:00:01Z stdout F lo' \
  '{"log":"docker line\n","stream":"stdout","time":"2026-11-18T00:00:02Z"}' |
  LC_ALL=C awk "$NODELOG_AWK" > "$TEST_ROOT/decoded"
has "$TEST_ROOT/decoded" '2026-11-18T00:00:00Z hello'
has "$TEST_ROOT/decoded" '2026-11-18T00:00:02Z docker line'

for ((i = 1; i <= 80; i++)); do
  printf '2026-11-18T00:00:00Z stdout F rotation-row-%03d Unicode: Kubernetes ✓\n' "$i"
done > "$TEST_ROOT/rotation"
printf '2026-11-17T00:00:00Z stdout F previous-rotation\n' > "$TEST_ROOT/old"
printf '2026-11-19T00:00:00Z newest-current-line\n' > "$TEST_ROOT/current"
gzip -c "$TEST_ROOT/rotation" > "$TEST_ROOT/rotation.gz"
mode=normal; log_rc=0
fixture_kubectl() {
  local arg path="" verb="$1"
  for arg in "$@"; do case "$arg" in /api/*) path="$arg" ;; esac; done
  case "$verb" in
    auth) printf 'yes\n'; return 0 ;;
    logs) cat "$TEST_ROOT/current"; return "$log_rc" ;;
  esac
  if [ -z "$path" ]; then printf 'fixture-uid\tworker-a\tweb=0 \n'; return 0; fi
  if [ "$mode" = denied ]; then printf 'Forbidden: nodes/proxy\n' >&2; return 1; fi
  case "$path" in
    */)
      if [ "$mode" = gzip ]; then printf '<a href="0.log.20261118-000000.gz">newer</a>\n'
      else printf '<a href="0.log.20261117-000000">older</a>\n<a href="0.log.20261118-000000">newer</a>\n'; fi ;;
    *.gz) cat "$TEST_ROOT/rotation.gz" ;;
    *20261118-000000) cat "$TEST_ROOT/rotation" ;;
    *20261117-000000) cat "$TEST_ROOT/old" ;;
    *) return 93 ;;
  esac
}
KC=(fixture_kubectl)
nodelog_older worker-a alpha_pod_uid web 0 "$TEST_ROOT/all" 100000
[ "$NODELOG_N" = 2 ] && [ "$NODELOG_ALL" = 2 ] && [ "$NODELOG_CAPPED" = 0 ] || fail 'complete rotation count'
pass
[ "$(head -1 "$TEST_ROOT/all")" = '2026-11-17T00:00:00Z previous-rotation' ] || fail 'rotations were not oldest first'
pass
has "$TEST_ROOT/all" rotation-row-080

nodelog_older worker-a alpha_pod_uid web 0 "$TEST_ROOT/capped" 512
[ "$(wc -c < "$TEST_ROOT/capped")" -le 512 ] && [ "$NODELOG_BYTES" -le 512 ] && [ "$NODELOG_CAPPED" = 1 ] || fail 'one oversized rotation bypassed byte cap'
pass
has "$TEST_ROOT/capped" rotation-row-080
! grep -Fq rotation-row-001 "$TEST_ROOT/capped" || fail 'cap kept oldest instead of newest lines'
pass
# Complete-line trimming cannot leave half of a multibyte glyph or timestamp.
LC_ALL=C awk '!/^[0-9][0-9][0-9][0-9]-/ {exit 1}' "$TEST_ROOT/capped" || fail 'cap cut through a log line'
pass
if command -v python3 >/dev/null 2>&1; then
  python3 -c 'import sys; open(sys.argv[1], encoding="utf-8").read()' "$TEST_ROOT/capped"
  pass
fi
mode=gzip
nodelog_older worker-a alpha_pod_uid web 0 "$TEST_ROOT/capped-gzip" 512
cmp -s "$TEST_ROOT/capped" "$TEST_ROOT/capped-gzip" || fail 'gzip rotation changed decoded retained lines'
pass
mode=denied
if nodelog_older worker-a alpha_pod_uid web 0 "$TEST_ROOT/denied" 512; then fail 'denied rotation returned success'; fi
[[ "$NODELOG_WHY" == *'no access'* ]] || fail 'denied rotation lost access reason'
pass

mode=normal; KDASH_NODE_LOGS=1; INSPECTOR_TAIL_SET=-1; INSPECTOR_BYTES_SET=1024
inspector_logs alpha pod web current "$TEST_ROOT/merged"
[ "$(wc -c < "$TEST_ROOT/merged")" -le 1024 ] || fail 'older plus current history exceeded aggregate cap'
pass
has "$TEST_ROOT/merged" newest-current-line
has "$TEST_ROOT/merged" rotation-row-080
has "$TEST_ROOT/merged.info" 'oldest lines omitted'
! grep -Fq 'whole log:' "$TEST_ROOT/merged.info" || fail 'truncated history was labelled complete'
pass
KDASH_NODE_LOGS=0; log_rc=124
if inspector_logs alpha pod web current "$TEST_ROOT/partial"; then fail 'failed log read returned success'; fi
has "$TEST_ROOT/partial" newest-current-line
has "$TEST_ROOT/partial.info" 'INCOMPLETE: stopped after'
printf '0\t0\t0\trotated files on node worker-a could not be listed (404 Not Found)\n' > "$TEST_ROOT/history-result"
nodelog_result "$TEST_ROOT/history-result"
[ "$NODELOG_READ" = 0 ] && [[ "$NODELOG_RESULT" == *'incomplete'*'404 Not Found'* ]] || fail 'proxy failure was presented as read coverage'
pass
printf '0\t0\t0\t\n' > "$TEST_ROOT/history-result"
nodelog_result "$TEST_ROOT/history-result"
[ "$NODELOG_READ" = 0 ] && [ "$NODELOG_RESULT" = 'no rotated files found on node' ] || fail 'empty successful listing was presented as read coverage'
pass
printf '2\t3\t1\t\n' > "$TEST_ROOT/history-result"
nodelog_result "$TEST_ROOT/history-result"
[ "$NODELOG_READ" = 2 ] && [[ "$NODELOG_RESULT" == *'with 2 older files'*'1 oldest not read'*'byte cap'* ]] || fail 'rotated coverage lost counts or cap'
pass
printf 'PASS: %s rotated-log decoding, ordering, gzip, byte-cap, access and incomplete-read checks\n' "$checks"
