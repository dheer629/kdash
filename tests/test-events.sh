#!/usr/bin/env bash
# Deterministic API Event fixtures. No kubeconfig, cluster or extra tools needed.
set -euo pipefail

REPO="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/kdash-events-tests.XXXXXXXX")"
events_test_cleanup() {
    case "$TEST_ROOT" in "${TMPDIR:-/tmp}"/kdash-events-tests.*) rm -rf -- "$TEST_ROOT" ;; esac
}
trap events_test_cleanup EXIT
source "$REPO/src/events.sh"

TOOLKIT_DIR="$TEST_ROOT/toolkit"
MODEL="$TEST_ROOT/model"
EVENT_LOG="$TEST_ROOT/arguments"
EVENT_FIXTURE="$TEST_ROOT/events.raw"
EVENT_MODE=ok
CTX_NAME=fixture-context
NS=ops
ALL_NS=0
SCOPE=(-n "$NS")
mkdir -p -- "$TOOLKIT_DIR" "$MODEL"

events_test_stub() {
    printf '%s\n' "$@" > "$EVENT_LOG"
    case "$EVENT_MODE" in
        ok) cat -- "$EVENT_FIXTURE" ;;
        empty) return 0 ;;
        forbidden) printf 'Error: events is forbidden; private-token-do-not-publish\n' >&2; return 1 ;;
        unavailable) printf 'the server could not find the requested resource\n' >&2; return 1 ;;
        error) printf 'TLS handshake timeout; private-token-do-not-publish\n' >&2; return 1 ;;
        malformed) printf 'not-an-event-row\n' ;;
        *) return 1 ;;
    esac
}
KC=(events_test_stub --context fixture-context --kubeconfig "$TEST_ROOT/config with spaces")

events_test_fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
events_test_contains() { grep -Fq -- "$2" "$1" || events_test_fail "missing expected text: $2"; }
events_test_absent() { if grep -Fq -- "$2" "$1"; then events_test_fail "unexpected text: $2"; fi; }
events_test_equal() { [ "$1" = "$2" ] || events_test_fail "$3: expected [$2], got [$1]"; }
events_test_pass() { printf 'ok - %s\n' "$1"; }

# Fields are emitted by kubectl go-template printf %q: raw newline/tab/control
# bytes are escaped inside one string, and the final internal field is Event UID.
cat > "$EVENT_FIXTURE" <<'FIXTURE'
"ops"	"Pod"	"api-0"	"pod-new"	"Warning"	"FailedScheduling"	3	"2026-10-29T10:00:00Z"	"2026-10-29T10:01:00Z"	"0/2 nodes are available\nInsufficient cpu\tcheck \"team\" \x1b[31m"	"event-schedule"
"ops"	"Pod"	"api-0"	"pod-new"	"Warning"	"FailedScheduling"	5	"2026-10-29T10:00:00Z"	"2026-10-29T10:02:00Z"	"0/2 nodes are available\nInsufficient cpu\tcheck \"team\" \x1b[31m"	"event-schedule"
"ops"	"Pod"	"api-0"	"pod-old"	"Warning"	"Unhealthy"	1	"2026-10-29T09:55:00Z"	"2026-10-29T09:56:00Z"	"Readiness probe failed: literal \\n is text"	"event-probe"
"ops"	"Pod"	"api-0"	"pod-new"	"Warning"	"BackOff"	2	"2026-10-29T10:03:00Z"	"2026-10-29T10:04:00Z"	"Back-off restarting failed container"	"event-restart"
"ops"	"Pod"	"api-1"	"pod-image"	"Warning"	"BackOff"	2	"2026-10-29T10:04:00Z"	"2026-10-29T10:05:00Z"	"Back-off pulling image registry.invalid/app:bad"	"event-image"
"ops"	"PersistentVolumeClaim"	"data"	"claim-1"	"Warning"	"ProvisioningFailed"	4	"2026-10-29T10:02:00Z"	"2026-10-29T10:06:00Z"	"Provisioner cannot bind claim"	"event-volume"
"ops"	"Pod"	"api-0"	"pod-new"	"Normal"	"Started"	1	"2026-10-29T10:07:00Z"	"2026-10-29T10:07:00Z"	"Started container app"	"event-started"
"other"	"Pod"	"other-pod"	"pod-other"	"Warning"	"FailedMount"	1	"2026-10-29T10:08:00Z"	"2026-10-29T10:08:00Z"	"Different namespace evidence"	"event-other"
FIXTURE

events_collect || events_test_fail 'successful event collection failed'
events_test_equal "$(cat "$TOOLKIT_DIR/events.status")" ok 'coverage status'
events_test_equal "$(head -n 1 "$TOOLKIT_DIR/events.tsv")" $'NS\tKIND\tNAME\tUID\tTYPE\tREASON\tCOUNT\tFIRST\tLAST\tMESSAGE' 'schema'
events_test_equal "$(wc -l < "$TOOLKIT_DIR/events.tsv" | tr -d ' ')" 8 'Event UID deduplication'
events_test_equal "$(awk -F '\t' '$6 == "FailedScheduling" { print $7 }' "$TOOLKIT_DIR/events.tsv")" 5 'newest duplicate count'
awk -F '\t' 'NF != 10 { exit 1 }' "$TOOLKIT_DIR/events.tsv" || events_test_fail 'TSV field count changed'
if LC_ALL=C grep -q $'\033' "$TOOLKIT_DIR/events.tsv"; then events_test_fail 'terminal escape survived'; fi
events_test_contains "$TOOLKIT_DIR/events.tsv" 'Insufficient cpu check "team" [31m'
events_test_contains "$TOOLKIT_DIR/events.tsv" 'literal \n is text'
events_test_pass 'quoted messages flatten controls, preserve literals and deduplicate Event identities'

events_test_equal "$(sed -n '5p' "$EVENT_LOG")" get 'kubectl verb order'
events_test_equal "$(sed -n '6p' "$EVENT_LOG")" events 'kubectl resource order'
events_test_equal "$(sed -n '7p' "$EVENT_LOG")" -n 'namespace flag follows resource'
events_test_contains "$EVENT_LOG" --request-timeout=10s
events_test_pass 'collection uses explicit context, bounded timeout and command-local scope flags'

cp -- "$EVENT_LOG" "$TEST_ROOT/arguments.before"
events_render ops api-0 > "$TEST_ROOT/events.txt"
cmp -s "$EVENT_LOG" "$TEST_ROOT/arguments.before" || events_test_fail 'render called kubectl'
grep -Eq 'events[[:space:]]+.*ok[[:space:]]' "$TEST_ROOT/events.txt" || events_test_fail 'successful Events source state is missing'
events_test_contains "$TEST_ROOT/events.txt" 'local session changes are recorded separately'
events_test_contains "$TEST_ROOT/events.txt" 'FailedScheduling'
events_test_absent "$TEST_ROOT/events.txt" 'api-1'
events_test_absent "$TEST_ROOT/events.txt" 'Different namespace evidence'
events_test_pass 'cached rendering filters by namespace and pod without network calls'

printf 'KEY\tNAMESPACE\tPOD\tSTATUS\tREADY\tRESTARTS\tNODE\napi-0\tops\tapi-0\tPending\t0/1\t4\t(unscheduled)\n' > "$MODEL/pods.tsv"
explain_render ops api-0 > "$TEST_ROOT/explain.txt"
events_test_contains "$TEST_ROOT/explain.txt" 'PODS NEEDING ATTENTION'
grep -Eq 'api-0[[:space:]]+.*Pending' "$TEST_ROOT/explain.txt" || events_test_fail 'cached pod status is missing'
events_test_contains "$TEST_ROOT/explain.txt" 'scheduler constraints, capacity or an unbound claim'
events_test_contains "$TEST_ROOT/explain.txt" 'readiness, liveness or startup probe'
events_test_contains "$TEST_ROOT/explain.txt" 'may be exiting repeatedly'
# Evidence from the old and new Pod UIDs stays separate in the source, and the
# explanation still includes both the probe and restart categories.
events_test_contains "$TOOLKIT_DIR/events.tsv" 'pod-old'
events_test_contains "$TOOLKIT_DIR/events.tsv" 'pod-new'
events_test_contains "$TEST_ROOT/explain.txt" 'Unhealthy'
events_test_contains "$TEST_ROOT/explain.txt" 'BackOff'
events_test_contains "$TEST_ROOT/explain.txt" 'kubectl --context fixture-context'
events_test_contains "$TEST_ROOT/explain.txt" 'logs api-0 --all-containers --previous --tail=100'
events_test_contains "$TEST_ROOT/explain.txt" 'timing alone does not establish a cause'
events_test_absent "$TEST_ROOT/explain.txt" 'Provisioner cannot bind'
cmp -s "$EVENT_LOG" "$TEST_ROOT/arguments.before" || events_test_fail 'explanation called kubectl'
events_test_pass 'explanations distinguish historical identities and print context-scoped read-only checks'

explain_render ops > "$TEST_ROOT/explain-all.txt"
events_test_contains "$TEST_ROOT/explain-all.txt" 'registry access or pull credentials'
events_test_contains "$TEST_ROOT/explain-all.txt" 'volume binding, provisioning, attachment or mounting'
events_test_contains "$TEST_ROOT/explain-all.txt" '--context fixture-context'
events_test_contains "$TEST_ROOT/explain-all.txt" '--kubeconfig'
events_test_contains "$TEST_ROOT/explain-all.txt" '-n ops get pvc'
events_test_absent "$TEST_ROOT/explain-all.txt" 'Different namespace evidence'
events_test_pass 'image and storage explanations follow reason/message evidence'

cp -- "$TOOLKIT_DIR/events.tsv" "$TEST_ROOT/last-success.tsv"
EVENT_MODE=forbidden
if events_collect; then events_test_fail 'forbidden collection succeeded'; fi
events_test_equal "$(cat "$TOOLKIT_DIR/events.status")" forbidden 'forbidden coverage'
cmp -s "$TOOLKIT_DIR/events.tsv" "$TEST_ROOT/last-success.tsv" || events_test_fail 'failure discarded successful same-scope evidence'
events_render ops api-0 > "$TEST_ROOT/forbidden.txt"
events_test_contains "$TEST_ROOT/forbidden.txt" 'STALE - showing the last successful read'
events_test_contains "$TEST_ROOT/forbidden.txt" 'list events permission'
events_test_absent "$TOOLKIT_DIR/events.error" private-token-do-not-publish
events_test_absent "$TEST_ROOT/forbidden.txt" private-token-do-not-publish
events_test_pass 'denied reads retain stale evidence while sanitizing diagnostic errors'

for EVENT_MODE in unavailable error malformed; do
    if events_collect; then events_test_fail "$EVENT_MODE collection succeeded"; fi
    expected="$EVENT_MODE"; [ "$EVENT_MODE" != malformed ] || expected=error
    events_test_equal "$(cat "$TOOLKIT_DIR/events.status")" "$expected" "$EVENT_MODE status"
    cmp -s "$TOOLKIT_DIR/events.tsv" "$TEST_ROOT/last-success.tsv" || events_test_fail "$EVENT_MODE discarded successful evidence"
    events_test_absent "$TOOLKIT_DIR/events.error" private-token-do-not-publish
done
events_test_pass 'unavailable, transport and malformed responses preserve unknown/stale coverage'

NS=next-namespace
SCOPE=(-n "$NS")
EVENT_MODE=forbidden
if events_collect; then events_test_fail 'scope-switch forbidden collection succeeded'; fi
events_test_equal "$(wc -l < "$TOOLKIT_DIR/events.tsv" | tr -d ' ')" 1 'scope-switch cached row count'
[ ! -f "$TOOLKIT_DIR/events.updated" ] || events_test_fail 'scope-switch retained success timestamp'
events_render > "$TEST_ROOT/switched.txt"
events_test_absent "$TEST_ROOT/switched.txt" 'api-0'
events_test_pass 'scope changes cannot leak earlier cached evidence'

NS=ops
SCOPE=(-n "$NS")
EVENT_MODE=ok
events_collect || events_test_fail 'recovery failed'
EVENT_MODE=empty
events_collect || events_test_fail 'successful empty collection failed'
events_test_equal "$(cat "$TOOLKIT_DIR/events.status")" ok 'empty coverage'
events_test_equal "$(wc -l < "$TOOLKIT_DIR/events.tsv" | tr -d ' ')" 1 'empty result clears old rows'
events_render > "$TEST_ROOT/empty.txt"
events_test_contains "$TEST_ROOT/empty.txt" 'no retained Events match'
events_test_absent "$TEST_ROOT/empty.txt" 'STALE'
events_test_pass 'recovery and successful empty responses replace earlier evidence'

ALL_NS=1
NS='*'
SCOPE=(--all-namespaces)
EVENT_MODE=ok
events_collect || events_test_fail 'all-namespace collection failed'
events_test_equal "$(sed -n '7p' "$EVENT_LOG")" --all-namespaces 'all-namespace flag order'
events_render > "$TEST_ROOT/all-namespaces.txt"
events_test_contains "$TEST_ROOT/all-namespaces.txt" 'all namespaces'
events_test_contains "$TEST_ROOT/all-namespaces.txt" 'Different namespace evidence'
CTX_NAME=other-context
KC=(events_test_stub --context other-context)
events_render > "$TEST_ROOT/no-collection.txt"
events_test_contains "$TEST_ROOT/no-collection.txt" 'unknown'
events_test_contains "$TEST_ROOT/no-collection.txt" 'context other-context'
events_test_absent "$TEST_ROOT/no-collection.txt" 'Different namespace evidence'
events_test_pass 'all-namespace reads keep command order and context changes invalidate cached rendering'

printf 'All Events tests passed.\n'
