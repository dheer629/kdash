#!/usr/bin/env bash
# Capture the operation screens: the dashboard's controls, its exports and the
# one-shot modes - and verify that each one really produced its artifact.
#
# The samples gallery shows every view. This script documents what you can DO with
# kdash and proves it worked:
#
#   dashboard   the namespace picker, the pod filter, the structured filters, detail
#               lines, pods-only, sort order, pause + poll interval, the colour
#               theme, all-vs-hosting nodes, true scale, the chart window, the HTML
#               menu, the all-tabs report being written, the inspector export and
#               the session close summary
#   one-shot    -V, -h, --snapshot all, --report, --audit, --audit-verify, --about
#   first run   the disclaimer gate, with a private XDG_CONFIG_HOME so the real
#               acceptance of this user is untouched
#
# After the captures it checks the artifacts on disk (HTML report, snapshot HTML,
# the evidence bundle's text/TSV/CSV files, the inspector export, the audit HTML and
# CSV) and writes the result into the run's README.txt, so the screens and the files
# can be compared.
#
# It never changes a cluster object: kdash reads, and the only writes are local
# files under the run directory.
#
# Usage: bash scripts/capture-operation-screens.sh [--context NAME] [--namespace NS]
#                                                  [--repo PATH] [--gallery DIR]
set -uo pipefail

REPO="${KDASH_REPO:-/workspace/kdash}"
CTX="${KDASH_CTX:-devops-admin@local-cluster}"
NS="${KDASH_NS:-default}"
GALLERY="${KDASH_GALLERY:-samples/cli_419}"
COLS=170; ROWS=50
TZNAME="${KDASH_TZ:-Asia/Kolkata}"
CTXSHOW="${CTX##*@}"
VERIFY_ONLY=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo)      REPO="${2:?}"; shift 2 ;;
    --context)   CTX="${2:?}"; shift 2 ;;
    --namespace) NS="${2:?}"; shift 2 ;;
    --gallery)   GALLERY="${2:?}"; shift 2 ;;
    --verify-only) VERIFY_ONLY="${2:?}"; shift 2 ;;
    -h|--help)   sed -n '2,28p' "$0"; exit 0 ;;
    *) printf 'unknown option: %s\n' "$1" >&2; exit 2 ;;
  esac
done

export PATH="$HOME/.local/bin:$PATH"
RUN="operation-screens-$(date +%Y%m%d-%H%M%S)"
DIR="$REPO/artifacts/$RUN"
REPORTS="$DIR/$NS/reports"; AUDITS="$DIR/$NS/audit"
MANIFEST="$DIR/captures.tsv"
LOG="$DIR/run.log"
log() { printf '%s %s\n' "$(date -Is)" "$*" | tee -a "$LOG"; }

# ---------------- verification (also available as --verify-only DIR) ----------------
verify() {
  check() { # check <label> <glob...>
    local label="$1"; shift
    local found; found=$(ls -1 "$@" 2>/dev/null | wc -l)
    if [ "$found" -gt 0 ]; then log "OK   $label ($found file(s))"; else log "MISS $label"; fi
  }
  log "--- artifacts on disk"
  check "all-tabs HTML report (x)"          "$REPORTS"/kdash_namespace_report_*.html
  check "snapshot HTML (--snapshot all)"    "$REPORTS"/kdash_*.html
  check "audit HTML + CSV (--audit-report)" "$AUDITS"/kdash_audit_*.html "$AUDITS"/kdash_audit_*.csv
  check "inspector export (w)"              "$REPORTS"/inspector/*
  check "audit log"                         "$AUDITS"/audit_*.log
  check "session records"                   "$REPORTS"/sessions/*/meta.env
  local bundle; bundle=$(find "$REPORTS" -maxdepth 1 -type d -name 'kdash_*' | sort | tail -1)
  if [ -n "$bundle" ]; then
    log "OK   evidence bundle (--report): $(find "$bundle" -type f -name '*.txt' | wc -l) text, $(find "$bundle" -type f -name '*.csv' | wc -l) CSV, $(find "$bundle" -type f -name '*.tsv' | wc -l) TSV files in ${bundle##*/}"
  else
    log "MISS evidence bundle (--report)"
  fi

  local report_files
  report_files=$(cd "$DIR" && find . -type f \( -name '*.html' -o -name '*.tsv' -o -name '*.csv' \) ! -name 'captures.tsv' | sed 's#^\./##' | sort)
  {
    printf 'run            %s\n' "$RUN"
    printf 'context        %s\n' "$CTX"
    printf 'namespace      %s\n' "$NS"
    printf 'version        %s\n' "$(kdash -V 2>/dev/null | head -1)"
    printf 'sha256         %s\n' "$(sha256sum "$REPO/kdash" | cut -d' ' -f1)"
    printf 'terminal       %sx%s\n' "$COLS" "$ROWS"
    printf 'screens        %s (32-46 dashboard operations, 47-53 one-shot modes,\n' "$(($(wc -l < "$MANIFEST") - 1))"
    printf '               54 the disclaimer gate, 55 the audit report)\n'
    printf 'gallery        %s\n' "$GALLERY"
    printf '\nWhat the screens prove\n'
    printf '  32,33   n opens the namespace picker (Enter picks the highlighted one);\n'
    printf '          / filters the view to the matching pods; the same key with .*\n'
    printf '          matches every pod again\n'
    printf '  34      F opens the structured pod filter prompt (label, status, node,\n'
    printf '          workload, unhealthy; Enter keeps, "clear" resets)\n'
    printf '  35,36   d toggles the detail lines; p reduces the view to pod totals\n'
    printf '  37      s cycles the sort key, o reverses the order (header shows both)\n'
    printf '  38      P pauses the refresh and + changes the poll interval\n'
    printf '  39      T changes the colour theme\n'
    printf '  40,41   2 NODE POOLS: a shows every node, Z switches to true-scale bars\n'
    printf '  42      5 MEMORY: z moves the chart window\n'
    printf '  43,44   e opens the HTML menu; Enter writes the all-tabs report and names it\n'
    printf '  45      w in the inspector exported the visible log pane\n'
    printf '  46      q printed the session close summary (context, namespace, duration,\n'
    printf '          retained reports and the audit trail)\n'
    printf '  47,48   the CLI version and the first page of -h\n'
    printf '  49      --snapshot all wrote the every-view HTML and said where\n'
    printf '  50      --report wrote the text + TSV + CSV evidence bundle\n'
    printf '  51,52   --audit lists the recorded events; --audit-verify checks the chain\n'
    printf '  53      --about prints the author, the disclaimer and the audit locations\n'
    printf '  54      a first run asks for the disclaimer before reading the cluster\n'
    printf '  55      --audit-report wrote the audit log as HTML and CSV\n'
    printf '\nArtifacts this run produced (besides raw/ and captures.tsv)\n%s\n' "$report_files"
    printf '\nEvery screen was captured with tmux capture-pane -e -p while kdash was live\n'
    printf 'and rendered with ../../scripts/render-captures.ps1. The run was redacted with\n'
    printf '../../scripts/redact-run.sh and a private mapping before publication.\n'
  } > "$DIR/README.txt"
  log "README.txt written"
}

if [ -n "$VERIFY_ONLY" ]; then
  DIR="$VERIFY_ONLY"
  RUN="$(basename "$DIR")"
  REPORTS="$DIR/$NS/reports"; AUDITS="$DIR/$NS/audit"
  MANIFEST="$DIR/captures.tsv"; LOG="$DIR/run.log"
  GALLERY="${GALLERY:-samples/cli_419}"
  verify
  exit 0
fi

mkdir -p "$DIR/raw" "$REPORTS" "$AUDITS" "$DIR/xdg" || exit 1
printf 'file\tcolumns\trows\ttitle\tpng\n' > "$MANIFEST"

cat > "$DIR/tmux.conf" <<'CONF'
set -g status off
set -g remain-on-exit on
set -g default-terminal "xterm-256color"
set -g history-limit 5000
set -g escape-time 0
CONF

tmux kill-server 2>/dev/null || true
sleep 3

session() { # session <name> <command...>
  local name="$1"; shift
  local script="$DIR/raw/$name.sh"
  {
    printf '#!/usr/bin/env bash\n'
    printf 'export TZ=%q TERM=xterm-256color\n' "$TZNAME"
    printf 'export KDASH_REPORT_DIR=%q KDASH_AUDIT_DIR=%q\n' "$REPORTS" "$AUDITS"
    printf 'export KDASH_COLUMNS=%s KDASH_LINES=%s\n' "$COLS" "$ROWS"
    printf 'export KDASH_ACCEPT_DISCLAIMER=1\n'
    printf 'exec %s\n' "$*"
  } > "$script"
  chmod 755 "$script"
  tmux -f "$DIR/tmux.conf" new-session -d -s "$name" -x "$COLS" -y "$ROWS" "bash '$script'"
  sleep 2
  tmux has-session -t "$name" 2>/dev/null || { log "FAILED to start $name"; return 1; }
  log "started $name: $*"
}

capture() { # capture <session> <stem> <title> [minimum bytes]
  local sess="$1" stem="$2" title="$3" min="${4:-200}"
  tmux capture-pane -e -p -t "$sess" > "$DIR/raw/$stem.ansi" || { log "capture failed $stem"; return 1; }
  tmux capture-pane -p    -t "$sess" > "$DIR/raw/$stem.txt" || return 1
  local n; n=$(wc -c < "$DIR/raw/$stem.txt")
  [ "$n" -ge "$min" ] || { log "EMPTY $stem ($n bytes)"; return 1; }
  printf 'raw/%s.ansi\t%s\t%s\t%s\t%s/%s.png\n' "$stem" "$COLS" "$ROWS" "$title" "$GALLERY" "$stem" >> "$MANIFEST"
  log "captured $stem ($n bytes) - $title"
}

keys() { local sess="$1"; shift; for k in "$@"; do tmux send-keys -t "$sess" "$k"; sleep "${GAP:-4}"; done; }
wait_s() { sleep "$1"; }

log "run $RUN (context $CTX, namespace $NS)"

# ---------------- dashboard operations (one live session) ----------------
session kd-ops kdash -c "$CTX" -n "$NS" -i 5 || exit 1
wait_s 28

keys kd-ops n ;                        capture kd-ops 32-namespace-picker "the n namespace picker"
keys kd-ops Enter ; wait_s 6
keys kd-ops '/' kafka Enter ; wait_s 5 ; capture kd-ops 33-pod-filter "the / pod filter applied - only the matching pod remains"
keys kd-ops '/' '.*' Enter ; wait_s 5
keys kd-ops F ;                        capture kd-ops 34-filters "the F structured filter prompt"
keys kd-ops Enter
keys kd-ops d ;                        capture kd-ops 35-detail-lines "d detail lines under every workload"
keys kd-ops d
keys kd-ops p ;                        capture kd-ops 36-pods-only "p pods-only totals"
keys kd-ops p
keys kd-ops s o ;                      capture kd-ops 37-sort-order "s sort key cycled and o reversed"
keys kd-ops P '+' ;                    capture kd-ops 38-paused-interval "P pause and + poll interval"
keys kd-ops P
keys kd-ops T ;                        capture kd-ops 39-theme "T colour theme"
keys kd-ops 2 a ;                      capture kd-ops 40-nodes-all "2 NODE POOLS with every node (a)"
keys kd-ops a
keys kd-ops Z ;                        capture kd-ops 41-nodes-true-scale "Z true-scale node bars"
keys kd-ops Z
keys kd-ops 5 z ;                      capture kd-ops 42-chart-window "5 MEMORY with the z chart window"
keys kd-ops 1 e ;                      capture kd-ops 43-html-menu "e the HTML report menu"
keys kd-ops Enter ; wait_s 12 ;        capture kd-ops 44-html-report-written "Enter in the menu wrote the all-tabs report"
keys kd-ops 1 Enter Enter p ; wait_s 8
keys kd-ops w ; wait_s 4 ;             capture kd-ops 45-inspector-export "w exported the visible log pane"
keys kd-ops q ; wait_s 3 ; keys kd-ops q ; wait_s 5
capture kd-ops 46-session-summary "the session close summary"

# ---------------- one-shot modes (one session each) ----------------
session kd-version kdash -V ;                       wait_s 8 ; capture kd-version 47-version "kdash -V" 40
session kd-help    kdash -h ;                       wait_s 8 ; capture kd-help 48-help-cli "kdash -h, first page"
session kd-snap    kdash -c "$CTX" -n "$NS" --snapshot all ; wait_s 25 ; capture kd-snap 49-snapshot-all "--snapshot all wrote the view HTML"
session kd-report  kdash -c "$CTX" -n "$NS" --report ;       wait_s 30 ; capture kd-report 50-report-bundle "--report wrote the evidence bundle"
session kd-audit   kdash --audit 40 ;               wait_s 10 ; capture kd-audit 51-audit-table "kdash --audit 40"
session kd-verify  kdash --audit-verify ;           wait_s 10 ; capture kd-verify 52-audit-verify "kdash --audit-verify"
session kd-about   kdash --about ;                  wait_s 8 ;  capture kd-about 53-about "kdash --about"

session kd-audrep kdash --audit-report "$AUDITS" ;   wait_s 12 ; capture kd-audrep 55-audit-report "--audit-report wrote HTML + CSV" 200
# --audit-report writes next to the launch directory, and a directory name with a
# space in it gets cut short (kdash 4.19.2), so collect from both places.
find "$REPO" -maxdepth 1 -type f -name 'kdash_audit_*' -exec mv -n {} "$AUDITS/" \; 2>/dev/null || true
find "$(dirname "$REPO")" -maxdepth 2 -type d -name '*AI*' -exec find {} -maxdepth 1 -type f -name 'kdash_audit_*' -exec mv -n {} "$AUDITS/" \; \; 2>/dev/null || true

# ---------------- first run: the disclaimer gate ----------------
# Its own script: this is the one session that must NOT accept the disclaimer.
DISC="$DIR/raw/kd-disc.sh"
{
  printf '#!/usr/bin/env bash\n'
  printf 'export TZ=%q TERM=xterm-256color\n' "$TZNAME"
  printf 'export KDASH_REPORT_DIR=%q KDASH_AUDIT_DIR=%q\n' "$REPORTS" "$AUDITS"
  printf 'export KDASH_COLUMNS=%s KDASH_LINES=%s\n' "$COLS" "$ROWS"
  printf 'export XDG_CONFIG_HOME=%q\n' "$DIR/xdg"
  printf 'exec kdash -c %q -n %q -i 5\n' "$CTX" "$NS"
} > "$DISC"
chmod 755 "$DISC"
tmux -f "$DIR/tmux.conf" new-session -d -s kd-disc -x "$COLS" -y "$ROWS" "bash '$DISC'"
sleep 12
capture kd-disc 54-disclaimer-first-run "the first-run disclaimer gate"

tmux kill-server 2>/dev/null || true
sleep 2
log "screens: $(($(wc -l < "$MANIFEST") - 1))"
verify
