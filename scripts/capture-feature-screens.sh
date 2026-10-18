#!/usr/bin/env bash
# Capture the extra live screens used by the samples gallery.
#
# The gallery in samples/ shows features that a five-minute validation run does
# not cover: the help screen, a narrow terminal, alerts that appear and clear,
# the audit table and the first-run disclaimer. This script captures them from
# the same generic WSL vcluster, in tmux, exactly like the validation run does,
# and writes the raw screens plus a manifest the gallery script renders from.
#
# It is read-only: it never changes a cluster object. The disclaimer session uses
# its own XDG_CONFIG_HOME so the real acceptance of this user is untouched, and
# every session writes its audit log into this run's directory.
#
# Usage: bash scripts/capture-feature-screens.sh [--context NAME] [--namespace NS]
set -uo pipefail

REPO="${KDASH_REPO:-/workspace/kdash}"
CTX="${KDASH_CTX:-devops-admin@local-cluster}"
NS="${KDASH_NS:-orders-service-e2e}"
COLS=170; ROWS=50; NARROW_COLS=100; NARROW_ROWS=40
TZNAME="${KDASH_TZ:-Asia/Kolkata}"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --context)   CTX="${2:?}"; shift 2 ;;
    --namespace) NS="${2:?}"; shift 2 ;;
    -h|--help)   sed -n '2,18p' "$0"; exit 0 ;;
    *) printf 'unknown option: %s\n' "$1" >&2; exit 2 ;;
  esac
done

export PATH="$HOME/.local/bin:$PATH"
RUN="feature-screens-$(date +%Y%m%d-%H%M%S)"
DIR="$REPO/artifacts/$RUN"
mkdir -p "$DIR/audit" "$DIR/reports" "$DIR/xdg" "$DIR/raw" || exit 1
MANIFEST="$DIR/captures.tsv"
printf 'file\tcolumns\trows\ttitle\tpng\n' > "$MANIFEST"
log() { printf '%s %s\n' "$(date -Is)" "$*"; }

cat > "$DIR/tmux.conf" <<'CONF'
set -g status off
set -g remain-on-exit on
set -g default-terminal "xterm-256color"
set -g history-limit 5000
set -g escape-time 0
CONF

# start a fresh server so this run's geometry and config apply
tmux kill-server 2>/dev/null || true
for _ in $(seq 1 20); do tmux ls >/dev/null 2>&1 || break; sleep 1; done

launch() { # launch <session> <cols> <rows> <extra env...> -- <command...>
  local sess="$1" cols="$2" rows="$3"; shift 3
  local envs=()
  while [ "$1" != "--" ]; do envs+=("$1"); shift; done
  shift
  local script="$DIR/raw/$sess.sh"
  {
    printf '#!/usr/bin/env bash\n'
    printf 'export TZ=%q TERM=xterm-256color\n' "$TZNAME"
    printf 'export KDASH_REPORT_DIR=%q KDASH_AUDIT_DIR=%q\n' "$DIR/reports" "$DIR/audit"
    printf 'export KDASH_COLUMNS=%s KDASH_LINES=%s KDASH_SAMPLE_EVERY=5\n' "$cols" "$rows"
    for e in "${envs[@]}"; do printf 'export %q\n' "$e"; done
    printf 'exec %s\n' "$*"
  } > "$script"
  chmod 755 "$script"
  tmux -f "$DIR/tmux.conf" new-session -d -s "$sess" -x "$cols" -y "$rows" "bash '$script'"
  log "started $sess (${cols}x${rows})"
}

capture() { # capture <session> <stem> <columns> <rows> <title> <png>
  local sess="$1" stem="$2" cols="$3" rows="$4" title="$5" png="$6"
  tmux capture-pane -e -p -t "$sess" > "$DIR/raw/$stem.ansi"
  tmux capture-pane -p    -t "$sess" > "$DIR/raw/$stem.txt"
  printf 'raw/%s.ansi\t%s\t%s\t%s\t%s\n' "$stem" "$cols" "$rows" "$title" "$png" >> "$MANIFEST"
  log "captured $stem -> $png"
}

wait_until() { while [ "$(date +%s)" -lt "$1" ]; do sleep 1; done; }

t0=$(date +%s)
launch feat-narrow "$NARROW_COLS" "$NARROW_ROWS" KDASH_ACCEPT_DISCLAIMER=1 -- kdash -c "$CTX" -n "$NS" -i 5
launch feat-wide   "$COLS"        "$ROWS"        KDASH_ACCEPT_DISCLAIMER=1 -- kdash -c "$CTX" -n "$NS" -i 5

wait_until $((t0 + 35))
tmux send-keys -t feat-narrow 7
tmux send-keys -t feat-wide 7
wait_until $((t0 + 42))
capture feat-narrow 07-alerts-100col "$NARROW_COLS" "$NARROW_ROWS" \
  "kdash alerts view on a 100 column terminal - namespace $NS" cli_7_alerts_100col.png
capture feat-wide 07-alerts-170col-early "$COLS" "$ROWS" \
  "kdash alerts view on a 170 column terminal - namespace $NS" cli_7_alerts_170col.png

tmux send-keys -t feat-narrow "?"
wait_until $((t0 + 48))
capture feat-narrow 07-alerts-help-100col "$NARROW_COLS" "$NARROW_ROWS" \
  "kdash help screen for the alerts view (100 columns)" cli_7_alerts_help_narrow.png
tmux send-keys -t feat-narrow q

wait_until $((t0 + 110))
capture feat-wide 07-alerts-170col-late "$COLS" "$ROWS" \
  "kdash alerts view later in the run - new and cleared alerts - namespace $NS" cli_7_alerts_new_cleared.png

tmux send-keys -t feat-wide "?"
wait_until $((t0 + 116))
capture feat-wide 07-alerts-help-170col "$COLS" "$ROWS" \
  "kdash help screen for the alerts view" cli_7_alerts_help.png
tmux send-keys -t feat-wide q
wait_until $((t0 + 125))

# audit table: prints and exits on its own
launch feat-audit "$COLS" "$ROWS" KDASH_ACCEPT_DISCLAIMER=1 -- kdash --audit 40
wait_until $((t0 + 136))
capture feat-audit audit-log "$COLS" "$ROWS" \
  "kdash audit log of this session" cli_audit_log.png

# first-run disclaimer, with a private XDG_CONFIG_HOME so nothing is accepted
launch feat-disclaimer "$COLS" "$ROWS" "XDG_CONFIG_HOME=$DIR/xdg" -- kdash -c "$CTX" -n "$NS" -i 5
wait_until $((t0 + 146))
capture feat-disclaimer disclaimer-first-run "$COLS" "$ROWS" \
  "kdash first interactive run: the disclaimer gate" cli_disclaimer_first_run.png
tmux send-keys -t feat-disclaimer "no"
tmux send-keys -t feat-disclaimer Enter
wait_until $((t0 + 154))
capture feat-disclaimer disclaimer-declined "$COLS" "$ROWS" \
  "kdash first run declined: it exits without reading the cluster" cli_disclaimer_declined.png

tmux kill-server 2>/dev/null || true
{
  printf 'run            %s\n' "$RUN"
  printf 'context        %s\n' "$CTX"
  printf 'namespace      %s\n' "$NS"
  printf 'started        %s\n' "$(date -Is -d @"$t0")"
  printf 'finished       %s\n' "$(date -Is)"
  printf 'purpose        extra live screens for the samples gallery (help, narrow\n'
  printf '               terminal, alerts over time, audit table, disclaimer gate)\n'
} > "$DIR/README.txt"
log "done - $DIR"
