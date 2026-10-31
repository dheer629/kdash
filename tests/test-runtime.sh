#!/usr/bin/env bash
# End-to-end runtime/CLI regression checks. Every kubectl invocation is a local
# fixture; kubeconfigs, user homes and clusters are never consulted.
set -euo pipefail
REPO="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/kdash-runtime-tests.XXXXXXXX")"
cleanup() {
  case "$TEST_ROOT" in "${TMPDIR:-/tmp}"/kdash-runtime-tests.*) rm -rf -- "$TEST_ROOT" ;; esac
}
trap cleanup EXIT
TOOLS="$TEST_ROOT/bin"; mkdir -p "$TOOLS" "$TEST_ROOT/home" "$TEST_ROOT/audit" "$TEST_ROOT/reports"
export FIXTURE_CALLS="$TEST_ROOT/calls" FIXTURE_SPEC="$TEST_ROOT/pods.spec"
: > "$FIXTURE_CALLS"
cat > "$FIXTURE_SPEC" <<'SPEC'
P|api-ready|Running|worker-a|Burstable|default|10.1.0.2|10.0.0.1|ReplicaSet|api-7c9d|false||
C|main|100m|500m|64Mi|128Mi
S|main|true|0||
P|worker-crash|Running|worker-b|Burstable|default|10.1.0.3|10.0.0.2|ReplicaSet|worker-554aa|false||
C|main|200m|1|128Mi|256Mi
S|main|false|3|OOMKilled|CrashLoopBackOff
P|queue-pending|Pending||Burstable|default|||ReplicaSet|queue-654cc|false||
C|main|100m|500m|64Mi|128Mi
S|main|false|0||ContainerCreating
P|job-finished|Succeeded|worker-a|Burstable|default|10.1.0.4|10.0.0.1|Job|cleanup-123|false||
C|main|50m|100m|32Mi|64Mi
S|main|false|0||
SPEC
cat > "$TOOLS/kubectl" <<'STUB'
#!/usr/bin/env bash
set -uo pipefail
verb=""; resource=""; fmt=""; next=""; verb_pos=-1; resource_pos=-1; scope_pos=-1; index=0
for arg in "$@"; do
  logged="${arg//$'\n'/\\n}"; printf '%s\t' "$logged" >> "$FIXTURE_CALLS"
  case "$next" in
    context|ns|selector) next=""; index=$((index+1)); continue ;;
    output) fmt="$arg"; next=""; index=$((index+1)); continue ;;
  esac
  case "$arg" in
    --context|-n|--namespace|--selector) next=context ;;
    -o|--output) next=output ;;
    --all-namespaces|-A) scope_pos=$index ;;
    -*) ;;
    *) if [ -z "$verb" ]; then verb="$arg"; verb_pos=$index
       elif [ -z "$resource" ]; then resource="$arg"; resource_pos=$index; fi ;;
  esac
  index=$((index+1))
done
printf '\n' >> "$FIXTURE_CALLS"
# -A is a verb/resource flag; reject the historic broken global-flag placement.
if [ "$scope_pos" -ge 0 ] && [ "$scope_pos" -lt "$resource_pos" ]; then
  printf 'fixture: --all-namespaces appeared before verb/resource\n' >&2; exit 92
fi
case "$verb" in
  config)
    case "$resource" in
      current-context) printf 'fixture-context\n' ;;
      get-contexts) printf 'fixture-context\n' ;;
      view) case "$fmt" in *cluster.server*) printf 'https://fixture.invalid:6443' ;; *) printf default ;; esac ;;
    esac
    exit 0 ;;
  top) printf 'error: Metrics API not available\n' >&2; exit 1 ;;
  logs)
    if [ "${FIXTURE_SCENARIO:-normal}" = hang ]; then sleep 20; fi
    printf '2026-10-29T01:00:00Z fixture log\n'; exit 0 ;;
  get)
    case "$resource" in
      pods|pod)
        case "${FIXTURE_SCENARIO:-normal}" in
          tls) printf 'Unable to connect to the server: x509: certificate signed by unknown authority\n' >&2; exit 1 ;;
          rbac) printf 'Error from server (Forbidden): pods is forbidden: cannot list resource pods\n' >&2; exit 1 ;;
          empty) exit 0 ;;
          partial-error) head -n 3 "$FIXTURE_SPEC"; printf 'connection reset by peer\n' >&2; exit 1 ;;
        esac
        if [ "$fmt" = name ]; then printf 'pod/api-ready\n'
        elif [[ "$fmt" == *'P|{.metadata.name}'* ]]; then cat "$FIXTURE_SPEC"
        elif [[ "$fmt" == *'Q|{.metadata.namespace}'* ]]; then printf 'Q|default|worker-a|Running|100m,64Mi,500m,128Mi;|ReplicaSet|api-7c9d|true|api-ready\n'
        fi ;;
      nodes)
        if [ "$fmt" = name ]; then printf 'node/worker-a\n'
        else printf 'N|worker-a|4|8Gi|4|8Gi|10.1.0.0/24|10.0.0.1|True|||110|map[nodepool:workers]\nN|worker-b|4|8Gi|4|8Gi|10.2.0.0/24|10.0.0.2|True|||110|map[nodepool:workers]\n'; fi ;;
      *) [ "$fmt" != name ] || printf '%s/fixture\n' "$resource" ;;
    esac
    exit 0 ;;
  auth) printf yes; exit 0 ;;
  *) printf 'fixture refused unexpected command: %s %s\n' "$verb" "$resource" >&2; exit 93 ;;
esac
STUB
chmod 755 "$TOOLS/kubectl"
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
assert_has() { grep -Fq -- "$2" "$1" || fail "$1 lacks $2"; }
assert_absent() { ! grep -Fq -- "$2" "$1" || fail "$1 unexpectedly contains $2"; }
run_cli() {
  env -i HOME="$TEST_ROOT/home" XDG_CONFIG_HOME="$TEST_ROOT/home/.config" \
    PATH="$TOOLS:/usr/bin:/bin" TERM=dumb NO_COLOR=1 KUBECONFIG="$TEST_ROOT/no-kubeconfig" \
    KDASH_AUDIT_DIR="$TEST_ROOT/audit" KDASH_AUDIT_CENTRAL="$TEST_ROOT/no-central" KDASH_AUDIT_SYSLOG=0 \
    KDASH_REPORT_DIR="$TEST_ROOT/reports" KDASH_ACCEPT_DISCLAIMER=1 KDASH_IO=0 \
    KDASH_CMD_TIMEOUT="${TEST_CMD_TIMEOUT:-4}" FIXTURE_SCENARIO="${SCENARIO:-normal}" \
    FIXTURE_CALLS="$FIXTURE_CALLS" FIXTURE_SPEC="$FIXTURE_SPEC" \
    bash "$REPO/kdash" --no-cluster --no-node-metrics --no-io "$@"
}
run_once() { run_cli --once -n default -v pods -o tsv "$@"; }

if ! grep -q '^# BEGIN KDASH MODULES$' "$REPO/kdash"; then
  fail 'generated CLI is missing modules; run bash scripts/build.sh first'
fi

SCENARIO=normal run_cli --doctor -n default > "$TEST_ROOT/doctor" 2> "$TEST_ROOT/doctor.err"
grep -Eq 'pods[[:space:]]+.*PASS[[:space:]]+readable' "$TEST_ROOT/doctor" || fail 'doctor did not classify pods as readable'
grep -Eq 'metrics[[:space:]]+.*INFO[[:space:]]+API or metrics unavailable' "$TEST_ROOT/doctor" || fail 'doctor did not classify unavailable metrics'
assert_has "$TEST_ROOT/doctor" 'requests / limits'
assert_has "$TEST_ROOT/doctor" 'Read-only checks complete'
if SCENARIO=tls run_cli --doctor -n default > "$TEST_ROOT/tls" 2>&1; then fail 'doctor TLS failure returned success'; fi
grep -Eq 'pods[[:space:]]+.*FAIL[[:space:]]+TLS certificate validation failed' "$TEST_ROOT/tls" || fail 'doctor lost TLS classification'
if SCENARIO=rbac run_cli --doctor -n default > "$TEST_ROOT/rbac" 2>&1; then fail 'doctor RBAC failure returned success'; fi
grep -Eq 'pods[[:space:]]+.*FAIL[[:space:]]+RBAC denied' "$TEST_ROOT/rbac" || fail 'doctor lost RBAC classification'

: > "$FIXTURE_CALLS"
run_once > "$TEST_ROOT/pods" 2> "$TEST_ROOT/pods.err"
awk -F '\t' '
  $1=="KEY" {for(i=1;i<=NF;i++) h[$i]=i; next}
  $3=="api-ready" {found=1; if($(h["CPU_USED_m"])!="-" || $(h["MEM_USED_Mi"])!="-" || $(h["CPU_REQ_m"])!=100 || $(h["CPU_LIM_m"])!=500 || $(h["MEM_REQ_Mi"])!=64 || $(h["MEM_LIM_Mi"])!=128) exit 1}
  END {if(!found) exit 1}
' "$TEST_ROOT/pods" || fail 'missing metrics lost object inventory or requests/limits'
assert_has "$FIXTURE_CALLS" $'--context\tfixture-context\tget\tpods\t-n\tdefault'
assert_has "$FIXTURE_CALLS" --request-timeout=5s

: > "$FIXTURE_CALLS"
run_cli --once -A -v pods -o tsv > "$TEST_ROOT/all-ns" 2> "$TEST_ROOT/all-ns.err"
assert_has "$FIXTURE_CALLS" $'get\tpods\t--all-namespaces'
assert_has "$FIXTURE_CALLS" $'top\tpod\t--all-namespaces'
assert_absent "$FIXTURE_CALLS" $'--all-namespaces\tget'

: > "$FIXTURE_CALLS"
run_once --selector 'app in (api,worker)' > "$TEST_ROOT/selector" 2> "$TEST_ROOT/selector.err"
assert_has "$FIXTURE_CALLS" $'get\tpods\t-n\tdefault\t--selector\tapp in (api,worker)'
run_once --status 'CrashLoop|ContainerCreating' > "$TEST_ROOT/status" 2> "$TEST_ROOT/status.err"
assert_has "$TEST_ROOT/status" $'worker-crash\tCrashLoopBackOff'
assert_has "$TEST_ROOT/status" $'queue-pending\tContainerCreating'
assert_absent "$TEST_ROOT/status" $'api-ready\tRunning'
run_once --node worker-a > "$TEST_ROOT/node" 2> "$TEST_ROOT/node.err"
assert_has "$TEST_ROOT/node" $'api-ready\tRunning'
assert_has "$TEST_ROOT/node" $'job-finished\tSucceeded'
assert_absent "$TEST_ROOT/node" worker-crash
run_once --workload '^worker$' > "$TEST_ROOT/workload" 2> "$TEST_ROOT/workload.err"
assert_has "$TEST_ROOT/workload" worker-crash
assert_absent "$TEST_ROOT/workload" api-ready
run_once --unhealthy > "$TEST_ROOT/unhealthy" 2> "$TEST_ROOT/unhealthy.err"
assert_has "$TEST_ROOT/unhealthy" worker-crash
assert_has "$TEST_ROOT/unhealthy" queue-pending
assert_absent "$TEST_ROOT/unhealthy" api-ready
assert_absent "$TEST_ROOT/unhealthy" job-finished
if run_once --status '[' > "$TEST_ROOT/regex" 2>&1; then fail 'invalid regex accepted'; fi
assert_has "$TEST_ROOT/regex" 'invalid structured filter regex'

# Source only the current refresh function to test the transition from an old
# successful inventory to an empty success, and then a failed partial response.
extract_function() {
  awk -v name="$1" 'index($0,name "()") == 1 {on=1} on {print} on && $0=="}" {exit}' "$REPO/kdash"
}
(
  set -uo pipefail
  source <(extract_function refresh_spec)
  source <(extract_function _klass)
  refresh_cluster() { :; }; refresh_workloads() { :; }
  TMPD="$TEST_ROOT/refresh"; mkdir -p "$TMPD"
  KC=("$TOOLS/kubectl" --request-timeout=5s --context fixture-context)
  SCOPE=(-n default); KDASH_LABEL_SELECTOR=""
  SPEC="$TMPD/spec"; NODES="$TMPD/nodes"; SVC="$TMPD/svc"
  SPEC_TPL='P|{.metadata.name}'; NODE_TPL=node; SVC_TPL=service
  # Mirror the initial state the real script sets before the first refresh.
  WL_STATE=unread; NODES_STATE=unread; SVC_STATE=unread; SPEC_OK=0; SPEC_AT=0
  cat "$FIXTURE_SPEC" > "$SPEC"
  FIXTURE_SCENARIO=empty; export FIXTURE_SCENARIO
  refresh_spec
  [ "$SPEC_OK" = 1 ] && [ ! -s "$SPEC" ] && [ "$SPEC_AT" -gt 0 ] || fail 'successful empty refresh kept stale pods'
  cat "$FIXTURE_SPEC" > "$SPEC"; cp "$SPEC" "$TMPD/before"
  FIXTURE_SCENARIO=partial-error
  refresh_spec
  [ "$SPEC_OK" = 0 ] || fail 'failed pipeline was reported as a successful empty read'
  cmp -s "$SPEC" "$TMPD/before" || fail 'failed partial response replaced the last good inventory'
)

# The audited wrapper caps external processes as well as HTTP requests. This
# catches credential plugins hanging before kubectl can apply request-timeout.
(
  set -uo pipefail
  source <(extract_function audit_wrap_kubectl)
  TMPD="$TEST_ROOT/guard"; mkdir -p "$TMPD"
  KC=("$TOOLS/kubectl" --request-timeout=5s --context fixture-context)
  KDASH_CMD_TIMEOUT=1; FIXTURE_SCENARIO=hang; export KDASH_CMD_TIMEOUT FIXTURE_SCENARIO
  audit_wrap_kubectl
  start=$SECONDS; rc=0
  "${KC[@]}" logs api-ready -n default > /dev/null 2>&1 || rc=$?
  [ "$rc" = 124 ] || fail "command deadline returned $rc instead of 124"
  [ "$((SECONDS-start))" -lt 5 ] || fail 'hung read exceeded the process deadline'
  if "${KC[@]}" delete pod api-ready -n default > /dev/null 2>&1; then fail 'read-only guard allowed a mutation'; fi
  assert_has "$AUDIT_KLOG" REFUSED
)

# Test asynchronous adoption using real background Bash workers and isolated
# snapshots. A successful recovery must clear backoff and adopt the new data.
(
  set -uo pipefail
  source "$REPO/src/runtime.sh"
  source "$REPO/src/events.sh"
  TMPD="$TEST_ROOT/async"; mkdir -p "$TMPD"
  for file in spec top topprev nodes topnode svc cluster workloads; do printf 'old\n' > "$TMPD/$file"; done
  SPEC="$TMPD/spec"; TOPC="$TMPD/top"; TOPP="$TMPD/topprev"; NODES="$TMPD/nodes"
  TOPN_F="$TMPD/topnode"; SVC="$TMPD/svc"; CLUS="$TMPD/cluster"; WLS="$TMPD/workloads"
  INTERACTIVE=1; INTERVAL=1; SPEC_AT=0; SPEC_TTL=1; SPEC_OK=0; TOP_OK=0
  # Mirror the initial collector state the real script sets before the first poll.
  TOPN_STATE=off; TOPN_OK=0; CLUSTER_STATE=off; WL_STATE=unread; NODES_STATE=unread; SVC_STATE=unread
  io_tick() { :; }
  refresh_spec() { sleep 1; printf 'recovered\n' > "$SPEC"; SPEC_OK=1; SPEC_AT=$(date +%s); }
  refresh_top() { printf 'metrics\n' > "$TOPC"; TOP_OK=1; TOP_AT=$(date +%s); }
  build_model() { cp "$SPEC" "$TEST_ROOT/adopted"; }; session_tick() { :; }
  toolkit_init
  FETCH_FAILURES=3
  tick="${EPOCHREALTIME:-$SECONDS}"
  fetch
  tock="${EPOCHREALTIME:-$SECONDS}"
  awk -v a="$tick" -v b="$tock" 'BEGIN {exit !(b-a<0.8)}' || fail 'fetch blocked the input loop during a slow read'
  [ -n "$FETCH_PID" ] || fail 'fetch did not start a worker'
  assert_has "$SPEC" old
  wait "$FETCH_PID"
  fetch_adopt
  [ -z "$FETCH_PID" ] && [ "$FETCH_FAILURES" = 0 ] && [ "$FETCH_SUCCESS" -gt 0 ] || fail 'recovery did not clear backoff'
  assert_has "$SPEC" recovered
  assert_has "$TEST_ROOT/adopted" recovered
  toolkit_cancel
)

# The panel views (services / storage / events / explain) must reuse the standard
# header - tab bar, clock, context line, health line - and replace only the body and
# the footer, so they look like every other view.
(
  set -uo pipefail
  source "$REPO/src/runtime.sh"
  source "$REPO/src/events.sh"
  TMPD="$TEST_ROOT/panel"; mkdir -p "$TMPD"
  HDRF="$TMPD/hdr"; BODYF="$TMPD/body"; FTRF="$TMPD/ftr"
  TOOLKIT_DIR="$TMPD/toolkit"; mkdir -p "$TOOLKIT_DIR"
  NS=default; CTX_NAME=fixture-context
  render_core() { printf 'STANDARD-HEADER 1 PODS 8 SERVICES\n' > "$HDRF"; }
  health_render_services() { printf 'SERVICES AND BACKENDS\n'; }
  health_render_storage() { printf 'PERSISTENT STORAGE\n'; }
  events_render() { printf 'KUBERNETES EVENTS\n'; }
  explain_render() { printf 'INCIDENT EVIDENCE\n'; }
  for panel in services storage events explain; do
    toolkit_panel "$panel"
    assert_has "$HDRF" 'STANDARD-HEADER'
    assert_has "$FTRF" '9 storage'
    assert_has "$BODYF" "$(case "$panel" in services) printf 'SERVICES AND BACKENDS' ;; storage) printf 'PERSISTENT STORAGE' ;; events) printf 'KUBERNETES EVENTS' ;; explain) printf 'INCIDENT EVIDENCE' ;; esac)"
  done
  printf 'panel views keep the standard header and their own body and footer\n'
)

printf 'PASS: runtime doctor, CLI scoping/filters, missing metrics, empty/error transitions, command deadline, panel wiring and asynchronous recovery\n'
