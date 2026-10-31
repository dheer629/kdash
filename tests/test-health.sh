#!/usr/bin/env bash
# Fixture-only coverage for service/storage collection, joins and unknown states.
# kubectl and optional curl are local stubs; no real kubeconfig or cluster is read.
set -euo pipefail
REPO="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
. "$REPO/src/health.sh"
. "$REPO/src/events.sh"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/kdash-health-tests.XXXXXXXX")"
cleanup() { case "$TEST_ROOT" in "${TMPDIR:-/tmp}"/kdash-health-tests.*) rm -rf -- "$TEST_ROOT" ;; esac; }
trap cleanup EXIT
mkdir -p "$TEST_ROOT/bin" "$TEST_ROOT/fixture" "$TEST_ROOT/snapshot" "$TEST_ROOT/model"
export HEALTH_FIXTURE="$TEST_ROOT/fixture" HEALTH_CALLS="$TEST_ROOT/calls"
TOOLKIT_DIR="$TEST_ROOT/snapshot"; MODEL="$TEST_ROOT/model"
NS=demo; ALL_NS=0; SCOPE=(-n demo)
KC=("$TEST_ROOT/bin/kubectl" --context fixture --request-timeout=12s)
PROM_URL=''; PROM_SVC=monitoring/prometheus:9090; IO_STATE=unavailable

cat > "$TEST_ROOT/bin/kubectl" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$HEALTH_CALLS"
while [ "$#" -gt 0 ]; do
  case "$1" in --context) shift 2 ;; --request-timeout=*) shift ;; get) shift; break ;;
    *) printf 'unexpected global argument or modifying verb: %s\n' "$1" >&2; exit 90 ;; esac
done
resource="${1:-}"; shift
case "$resource" in
  services) source=services ;; pods) source=pods ;;
  endpointslices.discovery.k8s.io) source=endpoints ;;
  ingresses.networking.k8s.io) source=ingresses ;;
  persistentvolumeclaims) source=pvcs ;; persistentvolumes) source=pvs ;;
  storageclasses.storage.k8s.io) source=storageclasses ;;
  --raw) source=metrics; case "${1:-}" in */federate\?match\[\]=*) shift ;; *) exit 91 ;; esac ;;
  *) printf 'unexpected resource %s\n' "$resource" >&2; exit 92 ;;
esac
has_output=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    -n) case "$source" in pvs|storageclasses|metrics) exit 93 ;; esac; shift 2 ;;
    --all-namespaces) case "$source" in pvs|storageclasses|metrics) exit 94 ;; esac; shift ;;
    --request-timeout=*) shift ;;
    -o) case "${2:-}" in go-template=*) has_output=1 ;; *) exit 95 ;; esac; shift 2 ;;
    *) printf 'unexpected resource argument %s\n' "$1" >&2; exit 96 ;;
  esac
done
[ "$source" = metrics ] || [ "$has_output" = 1 ] || exit 97
if [ -f "$HEALTH_FIXTURE/$source.fail" ]; then cat "$HEALTH_FIXTURE/$source.fail" >&2; exit 1; fi
cat "$HEALTH_FIXTURE/$source.raw"
STUB
cat > "$TEST_ROOT/bin/curl" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
printf 'curl %s\n' "$*" >> "$HEALTH_CALLS"
if [ -f "$HEALTH_FIXTURE/metrics.fail" ]; then cat "$HEALTH_FIXTURE/metrics.fail" >&2; exit 22; fi
cat "$HEALTH_FIXTURE/metrics.raw"
STUB
chmod 755 "$TEST_ROOT/bin/kubectl" "$TEST_ROOT/bin/curl"
export PATH="$TEST_ROOT/bin:$PATH"

cat > "$HEALTH_FIXTURE/services.raw" <<'DATA'
S|demo|web|ClusterIP||10.0.0.1|app=web,
T|demo|web|http|80|http|TCP
S|demo|frontend|ClusterIP||10.0.0.2|app=web,tier=frontend,
T|demo|frontend|http|80|http|TCP
S|demo|unready|ClusterIP||10.0.0.3|app=cold,
T|demo|unready|http|80|8080|TCP
S|demo|mismatch|ClusterIP||10.0.0.4|app=typo,
T|demo|mismatch|http|80|8080|TCP
S|demo|named|ClusterIP||10.0.0.5|app=web,
T|demo|named|http|80|missing-port|TCP
S|demo|external|ExternalName|database.example.invalid||
T|demo|external|postgres|5432|5432|TCP
S|demo|manual|ClusterIP||10.0.0.6|
T|demo|manual|http|80|8080|TCP
S|demo|headless|ClusterIP||None|app=web,
T|demo|headless|http|80|http|TCP
DATA
cat > "$HEALTH_FIXTURE/pods.raw" <<'DATA'
P|demo|web-1|Running|True|app=web,tier=frontend,|10.1.0.1|
C|demo|web-1|app|http|8080|TCP
V|demo|web-1|data|data
M|demo|web-1|app|data|/var/data|false
M|demo|web-1|init:prepare|data|/prepare|false
P|demo|web-2|Running|False|app=web,tier=backend,|10.1.0.2|
C|demo|web-2|app|http|8080|TCP
P|demo|web-prefix|Running|True|app=web-extra,tier=frontend,|10.1.0.3|
P|demo|cold-1|Pending|False|app=cold,||
V|demo|cold-1|missing|missing-claim
P|other|web-1|Running|True|app=web,|10.2.0.1|
DATA
cat > "$HEALTH_FIXTURE/endpoints.raw" <<'DATA'
E|demo|web|web-one|IPv4
B|demo|web|web-one|http|8080|TCP
D|demo|web|web-one|demo|web-1|Pod|true|true|false|10.1.0.1,
D|demo|web|web-one|demo|web-2|Pod|false|false|false|10.1.0.2,
D|demo|web|web-one||||<no value>|||10.1.0.99,
E|demo|manual|manual-one|IPv4
D|demo|manual|manual-one||||true|||192.0.2.1,
DATA
cat > "$HEALTH_FIXTURE/ingresses.raw" <<'DATA'
I|demo|web|nginx|web.example.invalid|/|web|http
I|demo|wrong-port|nginx|wrong.example.invalid|/|web|4040
I|demo|missing-service|nginx|missing.example.invalid|/|missing|http
I|demo|alias|nginx|alias.example.invalid|/|external|postgres
DATA
cat > "$HEALTH_FIXTURE/pvcs.raw" <<'DATA'
Q|demo|data|Bound|pv-data|fast|8Gi|10Gi|ReadWriteOnce,|Filesystem
F|demo|data|FileSystemResizePending|True|NodeResizePending
Q|demo|queued|Pending||delayed|1Gi||ReadWriteOnce,|Filesystem
Q|demo|orphan|Bound|pv-missing|fast|1Gi|1Gi|ReadWriteOnce,|Filesystem
Q|demo|badref|Bound|pv-other|fast|1Gi|1Gi|ReadWriteOnce,|Filesystem
DATA
cat > "$HEALTH_FIXTURE/pvs.raw" <<'DATA'
Z|pv-data|Bound|fast|10Gi|Delete|demo|data|example.csi.invalid
Z|pv-other|Bound|fast|1Gi|Retain|other|claim|example.csi.invalid
DATA
cat > "$HEALTH_FIXTURE/storageclasses.raw" <<'DATA'
K|fast|example.csi.invalid|Immediate|true|Delete
K|delayed|example.csi.invalid|WaitForFirstConsumer|true|Delete
DATA
sample_ms="$(( $(date +%s) * 1000 - 60000 ))"
cat > "$HEALTH_FIXTURE/metrics.raw" <<DATA
# HELP kubelet_volume_stats_used_bytes Number of used bytes in a volume.
kubelet_volume_stats_used_bytes{namespace="demo",persistentvolumeclaim="data",instance="one"} 536870912 $sample_ms
kubelet_volume_stats_used_bytes{namespace="demo",persistentvolumeclaim="data",instance="duplicate"} 268435456 $sample_ms
kubelet_volume_stats_capacity_bytes{namespace="demo",persistentvolumeclaim="data"} 1073741824 $sample_ms
kubelet_volume_stats_available_bytes{namespace="demo",persistentvolumeclaim="data"} 536870912 $sample_ms
kubelet_volume_stats_used_bytes{namespace="other",persistentvolumeclaim="data"} 9999999999 $sample_ms
kubelet_volume_stats_used_bytes{namespace="demo",persistentvolumeclaim="queued"} NaN $sample_ms
DATA
# Storage consumes the same Kubernetes API Event schema as the Events view,
# rather than the separate five-column session-change timeline.
printf 'NS\tKIND\tNAME\tUID\tTYPE\tREASON\tCOUNT\tFIRST\tLAST\tMESSAGE\ndemo\tPod\tweb-1\tweb-uid\tWarning\tFailedMount\t2\t2026-10-29T10:00:00Z\t2026-10-29T10:01:00Z\tvolume setup failed\n' > "$TOOLKIT_DIR/events.tsv"

pass=0
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
contains() { grep -Fq -- "$2" "$1" || fail "$1 lacks: $2"; }
matches() { grep -Eq -- "$2" "$1" || fail "$1 does not match: $2"; }
absent() { if grep -Fq -- "$2" "$1"; then fail "$1 unexpectedly contains: $2"; fi; }
ok() { pass=$((pass+1)); printf 'PASS %s\n' "$*"; }

health_collect
[ "$(health__state services)" = ok ] || fail 'services collection status'
[ "$(health__state volume-metrics)" = ok ] || fail 'volume metrics collection status'
[ "$(wc -l < "$HEALTH_CALLS")" = 8 ] || fail 'expected seven resource reads plus one configured metrics read'
contains "$HEALTH_CALLS" 'get services -n demo --request-timeout=12s'
contains "$HEALTH_CALLS" 'get persistentvolumes --request-timeout=12s'
ok 'bounded read-only collector scopes namespace flags after the resource'

health_render_services > "$TEST_ROOT/services.txt"
contains "$TEST_ROOT/services.txt" 'SERVICES AND BACKENDS'
matches "$TEST_ROOT/services.txt" 'web.example.invalid/.*web:http'
contains "$TEST_ROOT/services.txt" '1/3 ready (1 unknown)'
matches "$TEST_ROOT/services.txt" 'web[[:space:]]+.*OK[[:space:]]+ClusterIP[[:space:]]+2[[:space:]]+1'
contains "$TEST_ROOT/services.txt" 'selector app=typo matches no pod'
contains "$TEST_ROOT/services.txt" 'selected pod(s), none Ready and serving'
contains "$TEST_ROOT/services.txt" 'named targetPort missing-port/TCP is not declared on 2 of 2'
contains "$TEST_ROOT/services.txt" 'no selector: backends are managed manually'
contains "$TEST_ROOT/services.txt" 'database.example.invalid'
contains "$TEST_ROOT/services.txt" 'backend port 4040 is not a port of Service web'
contains "$TEST_ROOT/services.txt" 'backend Service missing does not exist'
matches "$TEST_ROOT/services.txt" 'headless[[:space:]]+.*Headless'
contains "$TEST_ROOT/services.txt" 'reachability is not tested'
ok 'service and Ingress joins distinguish mismatch, unready, unknown, named ports and manual/DNS backends'

health_render_storage > "$TEST_ROOT/storage.txt"
matches "$TEST_ROOT/storage.txt" 'data[[:space:]]+web-1.*app[[:space:]]+/var/data'
matches "$TEST_ROOT/storage.txt" 'init:prepare[[:space:]]+/prepare'
contains "$TEST_ROOT/storage.txt" 'binds only when a consuming pod is scheduled'
contains "$TEST_ROOT/storage.txt" 'bound volume pv-missing is missing'
contains "$TEST_ROOT/storage.txt" 'volume pv-other claimRef points to other/claim'
contains "$TEST_ROOT/storage.txt" 'pod refers to claim missing-claim, which does not exist'
matches "$TEST_ROOT/storage.txt" 'data[[:space:]]+.*512.0MiB[[:space:]]+50%'
contains "$TEST_ROOT/storage.txt" 'a missing sample never means zero usage'
contains "$TEST_ROOT/storage.txt" 'FileSystemResizePending (NodeResizePending)'
contains "$TEST_ROOT/storage.txt" 'FailedMount'
contains "$TEST_ROOT/storage.txt" 'volume setup failed'
# The compact UI no longer prints exporter timestamps or measured capacity in
# prose. Keep those data semantics asserted on the retained sample itself.
awk -F'\t' -v epoch="$((sample_ms / 1000))" '
  $1 == "demo" && $2 == "data" {
    found++; if (NF != 11 || $3 != 536870912 || $4 != epoch || $5 != "exporter" ||
                 $6 != 1073741824 || $7 != epoch || $8 != "exporter" ||
                 $9 != 536870912 || $10 != epoch || $11 != "exporter") exit 1
  }
  END { if (found != 1) exit 1 }
' "$TOOLKIT_DIR/health-volume-usage.tsv" || fail 'measured capacity, timestamp origin or duplicate-series aggregation changed'
matches "$TEST_ROOT/storage.txt" 'queued[[:space:]]+.*Pending[[:space:]]+1Gi[[:space:]]+-[[:space:]]+-[[:space:]]+-'
absent "$TOOLKIT_DIR/health-volume-usage.tsv" $'demo\tqueued\t'
ok 'storage joins bindings, class mode, pod mounts, recorded events and measured usage without equating allocation'

ALL_NS=1; SCOPE=(--all-namespaces); NS='(all namespaces)'
health_collect
contains "$HEALTH_CALLS" 'get pods --all-namespaces --request-timeout=12s'
[ "$(wc -l < "$TOOLKIT_DIR/health-volume-usage.tsv")" = 2 ] || fail 'all-namespace metrics did not keep distinct namespace/claim keys'
ok 'all-namespace reads keep command-local flags in place and metrics joins keep namespace identity'
ALL_NS=0; SCOPE=(-n demo); NS=demo

printf 'Error from server (Forbidden): nodes unavailable to this account\n' > "$HEALTH_FIXTURE/pvs.fail"
printf 'Error from server (NotFound): the server could not find the requested resource\n' > "$HEALTH_FIXTURE/ingresses.fail"
printf 'Error from server (Forbidden): cannot list endpointslices\n' > "$HEALTH_FIXTURE/endpoints.fail"
health_collect
health_render_services > "$TEST_ROOT/services-denied.txt"
health_render_storage > "$TEST_ROOT/storage-denied.txt"
[ "$(health__state pvs)" = forbidden ] || fail 'PV denial classification'
[ "$(health__state ingresses)" = unavailable ] || fail 'optional API classification'
matches "$TEST_ROOT/services-denied.txt" 'endpoints[[:space:]]+.*forbidden'
absent "$TEST_ROOT/services-denied.txt" 'no EndpointSlice exists'
contains "$TEST_ROOT/storage-denied.txt" 'unknown - pvs source forbidden'
absent "$TEST_ROOT/storage-denied.txt" 'bound volume pv-missing is missing'
ok 'optional API/RBAC failures stay unknown and do not become absent resources or zero endpoints'
rm -f "$HEALTH_FIXTURE/pvs.fail" "$HEALTH_FIXTURE/ingresses.fail" "$HEALTH_FIXTURE/endpoints.fail"

printf 'Unable to connect to the server: x509: certificate signed by unknown authority\n' > "$HEALTH_FIXTURE/pods.fail"
health_collect; health_render_services > "$TEST_ROOT/services-tls.txt"; health_render_storage > "$TEST_ROOT/storage-tls.txt"
[ "$(health__state pods)" = tls-error ] || fail 'TLS error classification'
matches "$TEST_ROOT/services-tls.txt" 'pods[[:space:]]+.*tls-error'
absent "$TEST_ROOT/services-tls.txt" 'matches no pod'
contains "$TEST_ROOT/storage-tls.txt" 'unknown - pods source tls-error'
ok 'failed pod collection never becomes selector mismatch or zero mount references'
rm -f "$HEALTH_FIXTURE/pods.fail"

PROM_SVC=''; IO_STATE=unavailable
health_collect; health_render_storage > "$TEST_ROOT/storage-no-metrics.txt"
[ "$(health__state volume-metrics)" = unknown ] || fail 'unconfigured volume source status'
contains "$TEST_ROOT/storage-no-metrics.txt" 'no configured or existing Prometheus source'
contains "$TEST_ROOT/storage-no-metrics.txt" 'USED / USE% need kubelet volume samples'
absent "$TEST_ROOT/storage-no-metrics.txt" '512.0MiB'
ok 'unconfigured metrics remain unknown and do not trigger discovery or extra API permissions'

PROM_URL=https://prometheus.example.invalid; IO_STATE=prom-url
health_collect
[ "$(health__state volume-metrics)" = ok ] || fail 'configured URL metrics'
contains "$HEALTH_CALLS" 'curl -fsS --connect-timeout 5 --max-time 12 --globoff'
PROM_URL=''; IO_STATE=prom-svc; IO_SRC_PATH=/api/v1/namespaces/monitoring/services/prometheus:9090/proxy
health_collect
[ "$(health__state volume-metrics)" = ok ] || fail 'existing IO source metrics'
printf 'context deadline exceeded\n' > "$HEALTH_FIXTURE/metrics.fail"
health_collect
[ "$(health__state volume-metrics)" = timeout ] || fail 'metrics timeout'
health_render_storage > "$TEST_ROOT/storage-timeout.txt"
matches "$TEST_ROOT/storage-timeout.txt" 'volume-metrics[[:space:]]+.*timeout'
absent "$TEST_ROOT/storage-timeout.txt" '512.0MiB'
ok 'configured URL/existing service proxy are reused and failed samples never reuse old measured data'

rm -f "$HEALTH_FIXTURE/metrics.fail"
PROM_SVC=monitoring/prometheus:9090; IO_STATE=unavailable
: > "$HEALTH_FIXTURE/metrics.raw"; : > "$HEALTH_FIXTURE/pvcs.raw"; : > "$HEALTH_FIXTURE/services.raw"
health_collect; health_render_services > "$TEST_ROOT/services-empty.txt"; health_render_storage > "$TEST_ROOT/storage-empty.txt"
[ "$(health__state volume-metrics)" = no-data ] || fail 'empty metrics source status'
contains "$TEST_ROOT/services-empty.txt" 'no Services in this scope'
contains "$TEST_ROOT/storage-empty.txt" 'no claims in this scope'
ok 'successful empty resource responses replace prior data while empty metrics stay no-data'

printf '%s health fixture tests passed.\n' "$pass"
