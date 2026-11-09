#!/usr/bin/env bash
# Isolated FMEA behaviour checks. Every Kubernetes command is a local fixture;
# no real kubeconfig, user config, saved report or API endpoint is consulted.
set -euo pipefail
REPO="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/kdash-fmea-tests.XXXXXXXX")"
cleanup() { case "$TEST_ROOT" in "${TMPDIR:-/tmp}"/kdash-fmea-tests.*) rm -rf -- "$TEST_ROOT" ;; esac; }
trap cleanup EXIT
mkdir -p "$TEST_ROOT/bin" "$TEST_ROOT/home" "$TEST_ROOT/config space" "$TEST_ROOT/runs" "$TEST_ROOT/model" "$TEST_ROOT/data"
export HOME="$TEST_ROOT/home" XDG_CONFIG_HOME="$TEST_ROOT/config space" KUBECONFIG="$TEST_ROOT/no-kubeconfig"
export FIXTURE_CALLS="$TEST_ROOT/calls" FIXTURE_ROOT="$TEST_ROOT"
: > "$FIXTURE_CALLS"
. "$REPO/src/runtime.sh"
. "$REPO/src/events.sh"
. "$REPO/src/health.sh"
. "$REPO/src/inspector.sh"
. "$REPO/src/interactive.sh"
TOOLKIT_DIR="$TEST_ROOT/data"; MODEL="$TEST_ROOT/model"; TMPD="$TEST_ROOT"
CTX_NAME=fixture-context; NS=demo; ALL_NS=0; SPEC_OK=1; SPEC_REASON=''
REPORT_DIR="$TEST_ROOT/reports"; KDASH_VERSION=fixture; KDASH_FMEA_PARALLEL=2
audit() { printf '%s\t%s\n' "$1" "${2:-}" >> "$TEST_ROOT/audit"; }
# Keep even machine-wide optional site config and historic run discovery isolated.
fmea__site_files() { [ ! -f "$XDG_CONFIG_HOME/kdash-fmea.tsv" ] || printf '%s\n' "$XDG_CONFIG_HOME/kdash-fmea.tsv"; return 0; }
fmea__runs_dir() { printf '%s\n' "$TEST_ROOT/runs"; }
fmea_catalogue > "$TEST_ROOT/builtin-catalogue"
fmea_catalogue() { cat "$TEST_ROOT/catalogue"; }
cp "$TEST_ROOT/builtin-catalogue" "$TEST_ROOT/catalogue"

cat > "$TEST_ROOT/bin/kubectl" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\t' "$@" >> "$FIXTURE_CALLS"; printf '\n' >> "$FIXTURE_CALLS"
while [ "$#" -gt 0 ]; do
  case "$1" in --context|--kubeconfig|-n|--namespace) shift 2 ;; --request-timeout=*) shift ;; *) break ;; esac
done
case "${1:-}" in
  auth)
    case "${2:-}" in
      whoami) printf 'ATTRIBUTE VALUE\nUsername fixture-user\nGroups [fixture-readers fixture-auditors]\n' ;;
      can-i) case "${4:-}" in denied.example) echo no; exit 1 ;; broken.example) echo 'fixture transport failure' >&2; exit 1 ;; *) echo yes ;; esac ;;
      *) exit 92 ;;
    esac ;;
  config) printf fixture-user ;;
  get|describe)
    if [ -f "$FIXTURE_ROOT/read-failure" ]; then printf 'partial stale object\n'; cat "$FIXTURE_ROOT/read-failure" >&2; exit 1; fi
    printf 'fixture object\n' ;;
  *) printf 'fixture rejected modifying or unexpected verb: %s\n' "${1:-}" >&2; exit 93 ;;
esac
STUB
chmod 755 "$TEST_ROOT/bin/kubectl"
KC=("$TEST_ROOT/bin/kubectl" --context fixture-context)

checks=0; failures=0
check() {
  checks=$((checks + 1))
  if "$@"; then return 0; fi
  failures=$((failures + 1)); printf 'FAIL: FMEA check %d: %s\n' "$checks" "$*" >&2
  return 0
}
row_is() { # ID awk-condition
  awk -F'\t' -v id="$1" '$6 == id { found = 1; if (!('"$2"')) bad = 1 } END { exit (!found || bad) }' "$TOOLKIT_DIR/fmea-rows.tsv"
}
catrow() { # id S D required-perms sources count-kind
  printf '%s\tWorkload\tMode\tEffect\tCause\tSignal\t%s\t%s\t%s\t%s\t%s\n' "$1" "$4" "$2" "$3" "${6:-cluster}" "$5"
}
score_setup() {
  : > "$TEST_ROOT/catalogue"; : > "$TOOLKIT_DIR/fmea-hits.tsv"; : > "$TOOLKIT_DIR/fmea-counts.tsv"
  printf 'U\tfixture-user\tfixture-readers\nP\tlist:pods\tyes\nP\tlist:events\tyes\n' > "$TOOLKIT_DIR/fmea-access.tsv"
  rm -f "$XDG_CONFIG_HOME/kdash-fmea.tsv" "$TOOLKIT_DIR"/health-*.status
  SPEC_OK=1; SPEC_REASON=''; printf 'ok\n' > "$TOOLKIT_DIR/events.status"
}

# Explicit boundary examples document kdash's AP policy; they do not certify an
# automotive standard or infer a universal Kubernetes risk model from RPN.
cat > "$TEST_ROOT/ap-cases" <<'CASES'
1 10 10 L
3 7 10 L
3 8 4 L
3 8 5 M
6 8 4 M
6 8 5 H
6 6 1 L
6 6 2 M
6 4 6 L
6 4 7 M
8 8 1 H
8 6 1 M
8 6 2 H
8 4 6 M
8 4 7 H
8 2 4 L
8 2 5 M
10 6 1 H
10 4 1 M
10 4 2 H
10 2 4 L
10 2 5 M
10 2 7 H
10 1 10 L
CASES
check awk "$FMEA_AP_AWK"'{ if (ap($1, $2, $3) != $4) { print "AP mismatch:", $0; bad = 1 } } END { exit bad }' "$TEST_ROOT/ap-cases"
check awk "$FMEA_AP_AWK"'BEGIN { for (s=1;s<=10;s++) for(o=1;o<=10;o++) for(d=1;d<=10;d++) if(ap(s,o,d)!~/^[HML]$/) exit 1 }'

# Access scopes, errors, cache reuse, scope invalidation, and no impersonation.
catrow ACCESS 7 4 'list:pods list:nodes@ list:pods#kube-system get:/readyz list:denied.example list:broken.example' spec > "$TEST_ROOT/catalogue"
check fmea_access force
check grep -Fq $'U\tfixture-user\tfixture-readers fixture-auditors' "$TOOLKIT_DIR/fmea-access.tsv"
check grep -Fq $'P\tlist:denied.example\tno' "$TOOLKIT_DIR/fmea-access.tsv"
check grep -Fq $'P\tlist:broken.example\terror' "$TOOLKIT_DIR/fmea-access.tsv"
check grep -Fq $'can-i\tlist\tnodes\t--all-namespaces' "$FIXTURE_CALLS"
check grep -Fq $'can-i\tlist\tpods\t-n\tkube-system' "$FIXTURE_CALLS"
check grep -Fq $'can-i\tget\t/readyz\t--request-timeout=8s' "$FIXTURE_CALLS"
before=$(wc -l < "$FIXTURE_CALLS"); FMEA_ACCESS_FRESH=0
check fmea_access
check test "$(wc -l < "$FIXTURE_CALLS")" = "$before"
NS=other; check fmea_access; check test "$(wc -l < "$FIXTURE_CALLS")" -gt "$before"; NS=demo
check bash -c '! grep -Eq -- "--as($|[[:space:]=])" "$1"' _ "$FIXTURE_CALLS"

# A failed read must discard partial/stale output and distinguish denied/timeout.
check fmea__read fm-deploy '{{range .items}}{{end}}' deployments.apps -n demo
check test "$(health__state fm-deploy)" = ok
printf 'Error from server (Forbidden): cannot list deployments\n' > "$TEST_ROOT/read-failure"
check fmea__read fm-deploy template deployments.apps -n demo
check test "$(health__state fm-deploy)" = forbidden
check test ! -s "$TOOLKIT_DIR/health-fm-deploy.raw"
printf 'context deadline exceeded\n' > "$TEST_ROOT/read-failure"
check fmea__read fm-deploy template deployments.apps -n demo
check test "$(health__state fm-deploy)" = timeout
rm -f "$TEST_ROOT/read-failure"

score_setup
catrow FULL 7 4 list:pods spec > "$TEST_ROOT/catalogue"
catrow DENIED 7 4 list:denied.example spec >> "$TEST_ROOT/catalogue"
catrow UNKNOWN 7 4 list:broken.example spec >> "$TEST_ROOT/catalogue"
catrow PARTIAL 7 4 'list:pods list:denied.example' spec >> "$TEST_ROOT/catalogue"
catrow NOSOURCE 7 4 list:pods fm-deploy >> "$TEST_ROOT/catalogue"
printf 'P\tlist:denied.example\tno\nP\tlist:broken.example\terror\n' >> "$TOOLKIT_DIR/fmea-access.tsv"
printf 'PARTIAL\tdemo/known-risk\trisk\tpositive fixture signal\tfm-WRK-03|demo|known-risk\tdemo\t\n' > "$TOOLKIT_DIR/fmea-hits.tsv"
check fmea_score
check row_is FULL '$11 == "ok" && $12 == "full" && $4 == 4'
check row_is DENIED '$11 == "noaccess" && $12 == "none" && $4 == 10'
check row_is UNKNOWN '$11 == "nosignal" && $12 == "unknown" && $4 == 10'
check row_is PARTIAL '$12 == "partial" && $4 == 6'
check row_is NOSOURCE '$11 == "nosignal" && $4 == 10'
check awk -F'\t' '$4 != 2 || $5 != 5 { exit 1 }' "$TOOLKIT_DIR/fmea.summary"
health__status fm-deploy forbidden denied
check fmea_score
check row_is NOSOURCE '$11 == "noaccess" && $12 == "none" && $4 == 10'

# Rank AP before RPN: M (S10,O4,D1,RPN40) precedes L (S6,O4,D6,RPN144).
score_setup
catrow MEDIUM 10 1 list:pods spec > "$TEST_ROOT/catalogue"
catrow LOW 6 6 list:pods spec >> "$TEST_ROOT/catalogue"
printf 'LOW\tdemo/low\trisk\tfixture risk\tfm-WRK-03|demo|low\tdemo\t\nMEDIUM\tdemo/medium\trisk\tfixture risk\tfm-WRK-03|demo|medium\tdemo\t\n' > "$TOOLKIT_DIR/fmea-hits.tsv"
check fmea_score
check row_is MEDIUM '$1 == "M" && $5 == 40'
check row_is LOW '$1 == "L" && $5 == 144'
check test "$(head -1 "$TOOLKIT_DIR/fmea-rows.tsv" | cut -f6)" = MEDIUM

# Site overlays preserve blank defaults and use paths containing spaces.
score_setup
catrow BASE 7 4 list:pods spec > "$TEST_ROOT/catalogue"
printf 'BASE\tdemo/app\tfail\tfailed now\tfm-WRK-01|demo|app\tdemo\t\n' > "$TOOLKIT_DIR/fmea-hits.tsv"
printf 'BASE\t\tSite mode\t\t\t\t\t8\t3\tOps team\topen\ncriticality\tdemo\tcritical\n' > "$XDG_CONFIG_HOME/kdash-fmea.tsv"
check fmea_score
check row_is BASE '$2 == 9 && $4 == 3 && $9 == "Site mode" && $15 == "Effect" && $17 == "Ops team" && $19 == "site"'
printf 'criticality\tdemo/app\tlow\n' >> "$XDG_CONFIG_HOME/kdash-fmea.tsv"
check fmea_score
check row_is BASE '$2 == 6'
printf 'SITE-01\tSite\tManual mode\tImpact\tCause\tReviewed signal\t\t9\t2\tReviewer\topen\t7\n' >> "$XDG_CONFIG_HOME/kdash-fmea.tsv"
check fmea_score
check row_is SITE-01 '$2 == 9 && $3 == 7 && $4 == 2 && $8 == "site" && $11 == "risk" && $13 == 0 && $17 == "Reviewer"'
printf 'SITE-02\tSite\tOut of bounds\tImpact\tCause\tReviewed signal\t\t99\t99\tReviewer\topen\t999\n' >> "$XDG_CONFIG_HOME/kdash-fmea.tsv"
check fmea_score
check row_is SITE-02 '$2 == 10 && $3 == 10 && $4 == 10 && $5 == 1000'

# Occurrence counts failing DAYS, not runs or objects on the same day.
printf 'BASE\tdemo/a\tfail\tH\nBASE\tdemo/b\tfail\tH\n#sum\t1\t0\t0\t1\t1\n' > "$TEST_ROOT/runs/20261101_010000.tsv"
printf 'BASE\tdemo/a\tfail\tH\n#sum\t1\t0\t0\t1\t1\n' > "$TEST_ROOT/runs/20261101_020000.tsv"
printf 'BASE\tdemo/a\tfail\tH\n#sum\t1\t0\t0\t1\t1\n' > "$TEST_ROOT/runs/20261102_010000.tsv"
fmea__history > "$TEST_ROOT/history"
check grep -Fxq $'#days\t2' "$TEST_ROOT/history"
check grep -Fxq $'BASE\t2' "$TEST_ROOT/history"

# Current usage near a CPU limit is a risk indicator, not proof of throttling.
# Volume fullness cannot be OK when no source measured the volume bytes.
score_setup
cp "$TEST_ROOT/builtin-catalogue" "$TEST_ROOT/catalogue"
printf 'P\tget:pods.metrics.k8s.io\tyes\nP\tlist:persistentvolumeclaims\tyes\n' >> "$TOOLKIT_DIR/fmea-access.tsv"
fmea__source_states | while IFS=$'\t' read -r source _; do : > "$TOOLKIT_DIR/health-$source.raw"; done
: > "$TOOLKIT_DIR/health-fm-whep.raw"; : > "$TOOLKIT_DIR/check-findings.tsv"; : > "$TOOLKIT_DIR/events.tsv"
: > "$MODEL/nodes.tsv"
export TEST_ROOT
python3 - <<'PY'
from pathlib import Path
import os
r=Path(os.environ['TEST_ROOT'])
p=['-']*28
for i,v in {1:'demo',2:'busy',3:'Running',6:'node-one',10:'Burstable',
            11:'Deployment',12:'busy',13:'95',15:'100'}.items(): p[i]=v
(r/'model/pods.tsv').write_text('header\n'+'\t'.join(p)+'\n')
PY
printf 'Q|demo|data|Bound|pv-data|standard\n' > "$TOOLKIT_DIR/health-pvcs.raw"
health__status pvcs ok measured
health__status volume-metrics unknown unconfigured
check fmea_evaluate
check awk -F'\t' '$1=="POD-08" { found=1; if($3!="risk" || $5~/pod-oom/) bad=1 } END { exit !found || bad }' "$TOOLKIT_DIR/fmea-hits.tsv"
check fmea_score
check row_is PVC-02 '$11 == "nosignal" && $10 !~ /all .* ok/'

# Independently parse exports and ensure external text cannot become HTML markup.
export TEST_ROOT
python3 - <<'PY'
from pathlib import Path
import os
p = Path(os.environ['TEST_ROOT']) / 'data'
row = ['H','9','10','4','360','X-1','Workload','demo/api',
       'quote "comma, slash \\ <script>alert(1)</script>', 'path C:\\data\\new "quoted"',
       'fail','full','0','fm-WRK-01|demo|api','Impact & <unsafe>', 'Cause', 'Ops "A", B', '', 'site']
(p/'fmea-rows.tsv').write_text('\t'.join(row)+'\n')
(p/'fmea.summary').write_text('1\t0\t0\t1\t1\tfixture-user\n')
PY
cp "$TOOLKIT_DIR/fmea-rows.tsv" "$TEST_ROOT/export-source.tsv"
fmea_export csv > "$TEST_ROOT/export.csv"
fmea_export tsv > "$TEST_ROOT/export.tsv"
python3 - <<'PY'
from pathlib import Path
import os
p=Path(os.environ['TEST_ROOT'])/'data/fmea-rows.tsv'
p.write_bytes(p.read_bytes().replace(b'"quoted"',b'"quoted"\rcontrol'))
PY
CTX_NAME=$'fixture\\context "quoted"\\n-literal\nactual\r\t\001'
fmea_export json > "$TEST_ROOT/export.json"
check fmea_html "$TEST_ROOT/export.html"
check python3 - <<'PY'
from pathlib import Path
import csv, json, os
from html.parser import HTMLParser
r=Path(os.environ['TEST_ROOT'])
source=(r/'export-source.tsv').read_bytes().decode().rstrip('\n').split('\t')
expected=source[:13]+source[14:18]
for name, delimiter in [('export.csv',','),('export.tsv','\t')]:
    rows=list(csv.reader((r/name).open(newline=''),delimiter=delimiter))
    assert len(rows)==2 and len(rows[0])==17 and rows[1]==expected, (name,rows)
data=json.loads((r/'export.json').read_text())
assert data['high']==1 and data['modes']==1 and len(data['rows'])==1
assert data['context']=='fixture\\context "quoted"\\n-literal\nactual\r\t\x01'
assert data['rows'][0]['mode']==source[8] and data['rows'][0]['now']==source[9]+'\rcontrol'
assert data['rows'][0]['o_estimated'] is False
class Tags(HTMLParser):
    def __init__(self): super().__init__(); self.tags=[]
    def handle_starttag(self,tag,attrs): self.tags.append(tag)
h=(r/'export.html').read_text(); parser=Tags(); parser.feed(h)
assert 'script' not in parser.tags and '&lt;script&gt;' in h
assert 'Impact &amp; &lt;unsafe&gt;' in h
PY

# Read command capture must keep CHANGE instructions out of --run execution.
CTX_NAME=fixture-context; RB_CAPTURE="$TEST_ROOT/read-commands.tsv"; RB_SEEN_FILE=''; RB_CUR_N=1; : > "$RB_CAPTURE"
fmea_hints fm-WRK-01 demo api > "$TEST_ROOT/hints"
check grep -Fq 'rollout undo' "$TEST_ROOT/hints"
check awk -F'\t' '$2 !~ /^kubectl -n demo (get|describe) deployment api/ { bad=1 } END { exit bad || NR!=2 }' "$RB_CAPTURE"
check bash -c '! grep -Eq "rollout.undo|scale|delete|patch" "$1"' _ "$RB_CAPTURE"
printf '1\tkubectl delete pod api\n1\tkubectl get pods; touch %s/injection-ran\n' "$TEST_ROOT" >> "$RB_CAPTURE"
: > "$FIXTURE_CALLS"
check check_run 1 "$RB_CAPTURE" "$TEST_ROOT/read-results"
check test "$CHECK_RAN" = 2
check test "$CHECK_SKIPPED" = 2
check test ! -e "$TEST_ROOT/injection-ran"
check bash -c '! grep -Eq "(^|[[:space:]])delete([[:space:]]|$)" "$1"' _ "$FIXTURE_CALLS"

# Exercise the actual CLI FMEA dispatch and exit handling, with acquisition
# replaced by an already-scored fixture. Extract the shipped branch rather than
# duplicating threshold logic in the test or performing real cluster reads.
export REPO
python3 - <<'PY'
from pathlib import Path
import os
cli=(Path(os.environ['REPO'])/'kdash').read_text()
start=cli.index('if [ "${DO_FMEA:-0}" = 1 ] ||')
end=cli.index('if [ "${DO_RUNBOOK:-0}" = 1 ] ||',start)
(Path(os.environ['TEST_ROOT'])/'fmea-cli-branch.sh').write_text(cli[start:end])
PY
cat > "$TEST_ROOT/fmea-cli-harness.sh" <<'HARNESS'
set -uo pipefail
DO_FMEA=1; VIEW=fmea; ONCE=1; OUTFMT=tsv; COLOR=0; KDASH_COLUMNS=120
TOOLKIT_DIR="$FIXTURE_ROOT/data"; TMPD="$FIXTURE_ROOT"
refresh_spec() { SPEC_OK=1; }
build_model() { :; }
events_collect() { :; }
health_collect() { :; }
check_collect() { :; }
audit() { :; }
fmea_collect() { cp "$FIXTURE_ROOT/cli-row.tsv" "$TOOLKIT_DIR/fmea-rows.tsv"; printf '0\t0\t0\t1\t1\tfixture-user\n' > "$TOOLKIT_DIR/fmea.summary"; }
fmea_export() { cat "$TOOLKIT_DIR/fmea-rows.tsv"; }
. "$FIXTURE_ROOT/fmea-cli-branch.sh"
HARNESS
cli_exit_is() { # threshold AP status expected-code
  local rc=0
  printf '%s\t9\t10\t4\t360\tX-1\tWorkload\tdemo/api\tMode\tNow\t%s\tfull\t0\t\tEffect\tCause\tOwner\t\tsite\n' "$2" "$3" > "$TEST_ROOT/cli-row.tsv"
  FMEA_FAIL_ON="$1" bash "$TEST_ROOT/fmea-cli-harness.sh" > "$TEST_ROOT/cli-output" 2> "$TEST_ROOT/cli-error" || rc=$?
  if [ "$rc" != "$4" ]; then cat "$TEST_ROOT/cli-error" >&2; printf 'threshold %s AP %s status %s: got %s expected %s\n' "$1" "$2" "$3" "$rc" "$4" >&2; return 1; fi
}
check cli_exit_is high H fail 2
check cli_exit_is high M risk 0
check cli_exit_is high L ok 0
check cli_exit_is medium H fail 2
check cli_exit_is medium M risk 1
check cli_exit_is medium L ok 0
check cli_exit_is low L risk 1
check cli_exit_is low L ok 0
check cli_exit_is '' H fail 0
rc=0
env -i HOME="$HOME" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" PATH="$TEST_ROOT/bin:/usr/bin:/bin" \
  KUBECONFIG="$KUBECONFIG" KDASH_AUDIT_DIR="$TEST_ROOT/audit-dir" KDASH_AUDIT_CENTRAL="$TEST_ROOT/no-central" \
  KDASH_AUDIT_SYSLOG=0 FIXTURE_CALLS="$FIXTURE_CALLS" FIXTURE_ROOT="$FIXTURE_ROOT" \
  bash "$REPO/kdash" --fmea --fail-on invalid > "$TEST_ROOT/invalid-output" 2>&1 || rc=$?
check test "$rc" = 2
check grep -Fq -- '--fail-on takes high | medium | low' "$TEST_ROOT/invalid-output"

if [ "$failures" -gt 0 ]; then printf 'FAIL: %d of %d FMEA fixture checks\n' "$failures" "$checks" >&2; exit 1; fi
printf 'PASS: %d FMEA fixture checks\n' "$checks"
