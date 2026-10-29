#!/usr/bin/env bash
# Isolated regression checks: no real kubeconfig, API, logs or user data are read.
set -euo pipefail
REPO="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
source "$REPO/src/inspector.sh"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/kdash-inspector-tests.XXXXXXXX")"
cleanup() {
  case "$TEST_ROOT" in "${TMPDIR:-/tmp}"/kdash-inspector-tests.*) rm -rf -- "$TEST_ROOT" ;; esac
}
trap cleanup EXIT
TMPD="$TEST_ROOT/tmp"; MODEL="$TEST_ROOT/model"; TOOLKIT_DIR="$TEST_ROOT/toolkit"
mkdir -p "$TMPD" "$MODEL" "$TOOLKIT_DIR"
CTX_NAME=production-west; NS=alpha; ALL_NS=1
CALLS="$TEST_ROOT/calls"; : > "$CALLS"
KC=(fake_kubectl --context production-west --request-timeout=6s)
fake_kubectl() {
  local arg verb="" output="" prev="" ns="" container="" tail="" limit="" previous=0
  printf '%s\t' "$@" >> "$CALLS"; printf '\n' >> "$CALLS"
  for arg in "$@"; do
    case "$prev" in --context) [ "$arg" = production-west ] || return 97 ;; -n) ns="$arg" ;; -o) output="$arg" ;; -c) container="$arg" ;; esac
    case "$arg" in get|logs|describe) verb="$arg" ;; --previous) previous=1 ;; --tail=*) tail="${arg#*=}" ;; --limit-bytes=*) limit="${arg#*=}" ;; apply|delete|edit|patch|exec|create|replace) return 98 ;; esac
    prev="$arg"
  done
  [ -n "$ns" ] || { printf 'Missing explicit namespace\n' >&2; return 96; }
  case "$verb" in
    get)
      case "$output" in
        *'Name:'*) printf 'Name: same-name\nNamespace: %s\nPhase: Running\nCONTAINERS\nweb image=web:v2\n\033[31mcontrol\033[0m\007\r\n' "$ns" ;;
        *'.status.containerStatuses'*) printf 'web\ttrue\t3\t\t\t2026-10-29T03:00:00Z\tOOMKilled\t137\nsidecar\ttrue\t0\t\t\t2026-10-29T03:00:00Z\t\t\n' ;;
        *'.spec.containers'*) printf 'regular\tweb\tweb:v2\nregular\tsidecar\tsidecar:v1\ninit\tinit-db\tdb:v1\n' ;;
        *) printf 'Name: same-name\nNamespace: %s\n' "$ns" ;;
      esac
      ;;
    logs)
      [ -n "$container" ] && [ -n "$tail" ] && [ -n "$limit" ] || return 95
      if [ "$container" = missing ]; then printf 'previous terminated container not found\n' >&2; return 1; fi
      printf '2026-10-29T03:00:00Z namespace=%s container=%s previous=%s\n' "$ns" "$container" "$previous"
      printf '2026-10-29T03:00:01Z INFO started container=%s\n' "$container"
      printf '2026-10-29T03:00:02Z WARN retrying container=%s\n' "$container"
      printf '2026-10-29T03:00:03Z ERROR boom container=%s\n' "$container"
      if [ "${FAKE_HUGE:-0}" = 1 ]; then awk 'BEGIN {for(i=0;i<10000;i++) print "a long application log line to test clipping and limits"}'; fi
      ;;
    describe) printf 'Name: same-name\nNamespace: %s\nEvents: none\n' "$ns" ;;
    *) return 94 ;;
  esac
}
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
assert_has() { grep -Fq -- "$2" "$1" || fail "$1 lacks $2"; }
assert_lacks() { ! grep -Fq -- "$2" "$1" || fail "$1 unexpectedly contains $2"; }
reset_calls() { : > "$CALLS"; }

inspector_render beta same-name > "$TEST_ROOT/summary"
assert_has "$TEST_ROOT/summary" 'Context: production-west | Namespace: beta | Pod: same-name'
assert_has "$CALLS" $'get\tpod\tsame-name\t-n\tbeta\t'
assert_lacks "$CALLS" $'logs\t'
assert_lacks "$TEST_ROOT/summary" $'\033'
assert_lacks "$TEST_ROOT/summary" $'\007'
[ ! -e "$TMPD/inspector/cli" ] || fail 'CLI temporary inspection content retained'
[ -z "$(find "$MODEL" -type f -print)" ] || fail 'summary leaked into report model'

reset_calls
KDASH_INSPECT_LOGS=current inspector_render beta same-name > "$TEST_ROOT/current"
assert_has "$CALLS" $'logs\tsame-name\t-n\tbeta\t-c\tweb\t'
assert_has "$CALLS" $'--tail=200\t--limit-bytes=65536\t--timestamps=true\t'
assert_lacks "$CALLS" --previous
assert_has "$TEST_ROOT/current" 'namespace=beta container=web previous=0'

reset_calls
KDASH_INSPECT_LOGS=previous KDASH_INSPECT_CONTAINER=init-db inspector_render gamma same-name > "$TEST_ROOT/previous"
assert_has "$CALLS" $'logs\tsame-name\t-n\tgamma\t-c\tinit-db\t'
assert_has "$CALLS" --previous
assert_has "$TEST_ROOT/previous" 'previous=1'
assert_lacks "$CALLS" '.spec.containers'
assert_lacks "$CALLS" --all-namespaces

reset_calls
FAKE_HUGE=1 KDASH_LOG_LIMIT_BYTES=2048 KDASH_LOG_TAIL=0009 KDASH_INSPECT_LOGS=current \
  KDASH_INSPECT_CONTAINER=web inspector_render beta same-name > "$TEST_ROOT/bounded"
assert_has "$CALLS" --tail=9
assert_has "$CALLS" --limit-bytes=2048
assert_has "$TEST_ROOT/bounded" '[Output clipped at 2048 bytes.]'
[ "$(wc -c < "$TEST_ROOT/bounded")" -lt 2600 ] || fail 'log output is unbounded'
KDASH_LOG_LIMIT_BYTES=9999999999999999999 KDASH_LOG_TAIL=9999999999 inspector_limits
[ "$INSPECTOR_BYTES" = 1048576 ] && [ "$INSPECTOR_TAIL" = 2000 ] || fail 'maximum log caps not enforced'

reset_calls
if KDASH_INSPECT_LOGS=previous KDASH_INSPECT_CONTAINER=missing inspector_render beta same-name > "$TEST_ROOT/error"; then fail 'failed log request reported success'; fi
assert_has "$TEST_ROOT/error" 'Read failed (exit 1)'
assert_has "$TEST_ROOT/error" 'Previous logs require a previously terminated instance'
assert_has "$TEST_ROOT/error" 'previous terminated container not found'
reset_calls
if inspector_render --all-namespaces same-name > /dev/null 2>&1; then fail 'invalid namespace accepted'; fi
[ ! -s "$CALLS" ] || fail 'invalid identity reached kubectl'
if KDASH_INSPECT_LOGS=bad KDASH_INSPECT_CONTAINER=web inspector_render beta same-name > "$TEST_ROOT/invalid-mode"; then fail 'invalid log mode accepted'; fi
[ ! -s "$CALLS" ] || fail 'invalid mode reached kubectl'

inspector_filter_apply 'label=app in (api,worker);status=Pending;node=worker-a;workload=checkout;unhealthy=1'
[ "$KDASH_LABEL_SELECTOR" = 'app in (api,worker)' ] || fail 'set based label selector changed'
[ "$KDASH_STATUS_FILTER" = Pending ] && [ "$KDASH_NODE_FILTER" = worker-a ] || fail 'structured filter not applied'
if inspector_filter_apply 'status=Running;unknown=bad' 2>/dev/null; then fail 'unknown filter accepted'; fi
[ "$KDASH_STATUS_FILTER" = Pending ] || fail 'invalid filter partially applied'
if inspector_filter_apply 'status=[' 2>/dev/null; then fail 'invalid status regex accepted'; fi
if inspector_filter_apply 'workload=api(' 2>/dev/null; then fail 'invalid workload regex accepted'; fi
[ "$KDASH_STATUS_FILTER" = Pending ] || fail 'invalid regex partially applied'
if inspector_filter_apply $'node=worker\033[2J' 2>/dev/null; then fail 'control bytes accepted'; fi
inspector_filter_apply 'workload=$(touch /tmp/kdash-do-not-run)'
[ "$KDASH_WORKLOAD_FILTER" = '$(touch /tmp/kdash-do-not-run)' ] || fail 'filter was evaluated as shell text'
inspector_filter_apply clear
[ -z "$KDASH_LABEL_SELECTOR$KDASH_STATUS_FILTER$KDASH_NODE_FILTER$KDASH_WORKLOAD_FILTER" ] && [ "$KDASH_UNHEALTHY" = 0 ] || fail 'clear left filters behind'

printf 'KEY\tNAMESPACE\tPOD\tSTATUS\tREADY\tRESTARTS\tNODE\tPOOL\tPOD_IP\tHOST_IP\tQOS\tKIND\tWORKLOAD\n' > "$MODEL/pods.tsv"
printf 'alpha/same-name\talpha\tsame-name\tRunning\t1/1\t0\tworker-a\tpool\t-\t-\t-\tDeployment\tcheckout\n' >> "$MODEL/pods.tsv"
printf 'beta/same-name\tbeta\tsame-name\tPending\t0/1\t2\tworker-b\tpool\t-\t-\t-\tDeployment\tcheckout\n' >> "$MODEL/pods.tsv"
printf 'alpha/failed\talpha\tfailed\tCrashLoopBackOff\t0/1\t5\tworker-a\tpool\t-\t-\t-\tDeployment\tworker\n' >> "$MODEL/pods.tsv"
printf 'alpha/job\talpha\tjob\tSucceeded\t0/1\t0\tworker-a\tpool\t-\t-\t-\tJob\tcleanup\n' >> "$MODEL/pods.tsv"
inspector_model_rows > "$TEST_ROOT/inventory"
[ "$(wc -l < "$TEST_ROOT/inventory")" = 4 ] || fail 'model pod inventory lost rows'
assert_has "$TEST_ROOT/inventory" $'beta\tsame-name\tPending'
assert_has "$TEST_ROOT/inventory" $'alpha\tsame-name\tRunning'
# The root collector owns structured filtering. Never apply conflicting filter
# semantics a second time in the picker (notably regex alternation and case).
KDASH_STATUS_FILTER='Pending|Running' KDASH_WORKLOAD_FILTER='checkout|worker' \
  KDASH_NODE_FILTER=worker-a KDASH_UNHEALTHY=1 inspector_model_rows > "$TEST_ROOT/already-filtered"
cmp -s "$TEST_ROOT/inventory" "$TEST_ROOT/already-filtered" || fail 'picker re-filtered the dashboard model'

events_render() { printf 'Scoped events namespace=%s pod=%s\033[2J\n' "$1" "$2"; }
explain_render() { printf 'Scoped explanation namespace=%s pod=%s\n' "$1" "$2"; }
reset_calls
inspector_events beta same-name "$TEST_ROOT/events"
inspector_explain beta same-name "$TEST_ROOT/explain"
assert_has "$TEST_ROOT/events" 'namespace=beta pod=same-name'
assert_lacks "$TEST_ROOT/events" $'\033'
assert_has "$TEST_ROOT/explain" 'namespace=beta pod=same-name'
[ ! -s "$CALLS" ] || fail 'cached renderers contacted the API'

# ---- container inventory with live state (spec + status merged) --------------------
reset_calls
inspector_container_rows beta same-name "$TEST_ROOT/rows.spec" "$TEST_ROOT/rows.status" > "$TEST_ROOT/rows"
assert_has "$TEST_ROOT/rows" $'regular\tweb\tready\t3\tRunning\tOOMKilled exit=137\tweb:v2'
assert_has "$TEST_ROOT/rows" $'regular\tsidecar\tready\t0\tRunning\t-\tsidecar:v1'
assert_has "$TEST_ROOT/rows" $'init\tinit-db\t?\t?\tno status yet\t-\tdb:v1'
[ "$(grep -c '.status.containerStatuses' "$CALLS")" = 1 ] || fail 'status read missing'
assert_has "$CALLS" $'get\tpod\tsame-name\t-n\tbeta\t'

# ---- search, highlighting, level filter and export ---------------------------------
INSPECTOR_SEARCH=""; INSPECTOR_LEVEL_NAME=all; INSPECTOR_LEVEL_PAT=""
printf 'plain line\nINFO ok\nERROR boom\nwarning: slow\n' > "$TEST_ROOT/body"
inspector_view_build "$TEST_ROOT/body" "$TEST_ROOT/view" "$TEST_ROOT/matches"
[ "$INSPECTOR_VIEW_LINES" = 4 ] && [ "$INSPECTOR_MATCHES" = 0 ] || fail 'unfiltered view counts'
INSPECTOR_SEARCH=error      # lowercase pattern ignores case
inspector_view_build "$TEST_ROOT/body" "$TEST_ROOT/view" "$TEST_ROOT/matches"
[ "$INSPECTOR_MATCHES" = 1 ] || fail "case-insensitive search found $INSPECTOR_MATCHES"
INSPECTOR_SEARCH=ERROR      # uppercase pattern is exact
inspector_view_build "$TEST_ROOT/body" "$TEST_ROOT/view" "$TEST_ROOT/matches"
[ "$INSPECTOR_MATCHES" = 1 ] || fail 'case-sensitive search'
case "$(COLOR=1 inspector_show "$TEST_ROOT/view" 1 10 200 1)" in
  *$'\033[1;31mERROR'*) ;;
  *) fail 'matches are not highlighted' ;;
esac
case "$(COLOR=0 inspector_show "$TEST_ROOT/view" 1 10 200 0)" in
  *$'\033'*) fail 'colour off still emitted escape codes' ;;
esac
INSPECTOR_SEARCH=''; INSPECTOR_LEVEL_NAME=ERROR
INSPECTOR_LEVEL_PAT='(^|[^A-Za-z])(ERROR|FATAL|SEVERE|Exception|exception|panic)'
inspector_view_build "$TEST_ROOT/body" "$TEST_ROOT/view" "$TEST_ROOT/matches"
[ "$INSPECTOR_VIEW_LINES" = 1 ] || fail 'level filter did not narrow the view'
inspector_level_cycle
[ "$INSPECTOR_LEVEL_NAME" = WARN ] || fail 'level cycle order'
inspector_level_cycle; inspector_level_cycle; inspector_level_cycle
[ "$INSPECTOR_LEVEL_NAME" = all ] && [ -z "$INSPECTOR_LEVEL_PAT" ] || fail 'level cycle did not reset'
inspector_pattern_ok 'a[' && fail 'invalid regex accepted'
inspector_pattern_ok $'a\033b' && fail 'control bytes accepted in a search'
inspector_pattern_ok 'error|OOMKilled' || fail 'valid regex rejected'
[ "$(inspector_icase error)" = 1 ] && [ "$(inspector_icase OOMKilled)" = 0 ] \
  && [ "$(inspector_icase 'a|b')" = 0 ] || fail 'case-sensitivity rule'
INSPECTOR_SEARCH=ERROR; INSPECTOR_LEVEL_NAME=all; INSPECTOR_LEVEL_PAT=""
inspector_view_build "$TEST_ROOT/body" "$TEST_ROOT/view" "$TEST_ROOT/matches"
exported="$(KDASH_REPORT_DIR="$TEST_ROOT/reports" inspector_export "$TEST_ROOT/view" beta same-name web current 4 1)"
[ -n "$exported" ] && [ -f "$exported" ] || fail 'export did not write a file'
case "$exported" in *"$TEST_ROOT/reports/inspector/"*) ;; *) fail 'export ignored KDASH_REPORT_DIR' ;; esac
assert_has "$exported" '# kdash inspector export'
assert_has "$exported" 'namespace: beta | pod: same-name | container: web | pane: current'
assert_has "$exported" 'search: ERROR'
assert_has "$exported" 'lines exported: 4 of 4 | matching lines: 1'
assert_has "$exported" 'ERROR boom'
assert_lacks "$exported" $'\033'
assert_has "$exported" 'Review before sharing'
INSPECTOR_SEARCH=""; INSPECTOR_LEVEL_NAME=all; INSPECTOR_LEVEL_PAT=""

# Exercise actual terminal navigation when the standard CI Python is available.
# The application itself continues to require only Bash/awk/coreutils/kubectl.
if command -v python3 >/dev/null 2>&1; then
  export REPO TEST_ROOT TMPD MODEL TOOLKIT_DIR CALLS
  export -f fake_kubectl
  python3 - <<'PY'
import errno
import os
import pty
import select
import signal
import time

pid, fd = pty.fork()
if pid == 0:
    os.environ.update(TERM="xterm", KDASH_LINES="26", KDASH_COLUMNS="120",
                      KDASH_REPORT_DIR=os.path.join(os.environ["TEST_ROOT"], "reports-live"),
                      KDASH_INSPECT_FOLLOW="1")
    os.execvp("bash", ["bash", "-c", '''
      set -uo pipefail
      source "$REPO/src/inspector.sh"
      CTX_NAME=production-west; NS='(all namespaces)'; ALL_NS=1
      KC=(fake_kubectl --context production-west --request-timeout=6s)
      POD_PICK=beta/same-name
      inspector_open
      printf '\nINSPECTOR_EXIT identity=%s\n' "$POD_PICK"
    '''])

buffer = b""
def expect(needle, timeout=8):
    global buffer
    end = time.monotonic() + timeout
    needle = needle.encode()
    while needle not in buffer:
        remaining = end - time.monotonic()
        if remaining <= 0:
            raise AssertionError("terminal did not show %r; got %r" % (needle, buffer[-3000:]))
        ready, _, _ = select.select([fd], [], [], min(remaining, .2))
        if ready:
            try:
                chunk = os.read(fd, 32768)
            except OSError as exc:
                if exc.errno == errno.EIO:
                    chunk = b""
                else:
                    raise
            if not chunk:
                raise AssertionError("terminal exited waiting for %r: %r" % (needle, buffer[-3000:]))
            buffer += chunk
    buffer = buffer[buffer.index(needle) + len(needle):]

try:
    expect("Select pod")
    os.write(fd, b"\n")
    expect("Pane: summary")
    expect("Namespace: beta")
    os.write(fd, b"l")
    expect("Pane: current")
    expect("Container: web | current logs")
    expect("INFO started container=web")
    # find keeps the context, counts the matches and highlights them
    os.write(fd, b"/")
    expect("Find in the current pane")
    os.write(fd, b"ERROR\n")
    expect("rows 1-6/6")
    expect("search /ERROR (1 matching)")
    expect("\x1b[1;31mERROR")
    expect("boom container=web")
    os.write(fd, b"n")
    expect("match 1/1")
    # & hides everything that does not match
    os.write(fd, b"&")
    expect("Show only matching lines")
    os.write(fd, b"ERROR\n")
    expect("rows 1-1/1")
    expect("only /ERROR: 1 of 6 lines")
    # clearing the search brings the whole pane back
    os.write(fd, b"/")
    os.write(fd, b"\n")
    expect("rows 1-6/6")
    expect("INFO started container=web")
    # previous logs of the same container
    os.write(fd, b"p")
    expect("Pane: previous")
    expect("previous=1")
    # the container picker: every container with readiness, restarts and last exit
    os.write(fd, b"c")
    expect("Containers of beta/same-name")
    expect("OOMKilled")
    expect("init-db")
    os.write(fd, b"2")
    expect("Container: sidecar | previous logs")
    expect("previous=1")
    # follow mode reloads the pane on the interval; any key stops it
    os.write(fd, b"f")
    expect("follow every 1s")
    time.sleep(2.5)
    expect("Pane: previous")
    os.write(fd, b"f")
    expect("follow off")
    # export what is on screen, then cycle the log level back to all
    os.write(fd, b"w")
    expect("exported ")
    expect("/inspector/")
    os.write(fd, b"L")
    expect("log level: ERROR")
    os.write(fd, b"L")
    expect("log level: WARN")
    os.write(fd, b"L")
    expect("log level: INFO")
    os.write(fd, b"L")
    expect("log level: DEBUG")
    os.write(fd, b"L")
    expect("log level: all")
    os.write(fd, b"?")
    expect("kdash inspector - keys")
    os.write(fd, b" ")
    os.write(fd, b"q")
    expect("Select pod")
    expect("Selected identity: beta/same-name")
    os.write(fd, b"q")
    expect("INSPECTOR_EXIT identity=beta/same-name")
    _, status = os.waitpid(pid, 0)
    assert os.waitstatus_to_exitcode(status) == 0
except BaseException:
    os.kill(pid, signal.SIGTERM)
    os.waitpid(pid, 0)
    raise
finally:
    os.close(fd)
PY
  # The explicit export must land in KDASH_REPORT_DIR, keep the filtered lines and
  # never contain terminal escape codes.
  found=0
  for f in "$TEST_ROOT"/reports-live/inspector/kdash_inspect_*; do
    [ -f "$f" ] || continue
    found=1
    assert_has "$f" '# kdash inspector export'
    assert_has "$f" 'ERROR boom'
    assert_has "$f" 'Review before sharing'
    assert_lacks "$f" $'\033'
  done
  [ "$found" = 1 ] || fail 'no inspector export was written'
fi
printf 'PASS: inspector identity, bounded opt-in logs, search and highlighting, level filter, container drill-down, export, failures, filters and report isolation\n'
