#!/usr/bin/env bash
# Capture one live screen per view and feature of a running kdash, for the gallery.
#
# The samples gallery shows every view of the current version plus the screens a
# five-minute validation run does not reach: the command palette, the doctor, the
# inspector (pod picker, summary, previous logs, find, only-matches, container
# picker, key map), the dashboard help and two 100-column layouts.
#
# With --attach it also captures the opt-in interactive mode end to end: the
# refusal while interactive mode is off, the X gate, the shell picker, a real
# shell inside a container, the dashboard after exit, and the download and upload
# browsers. That part runs kubectl exec, so it stays behind the flag; no command
# is typed inside the shell and kdash audits every step as a write.
#
# Nothing here changes a cluster object by itself: every screen is captured with
# `tmux capture-pane -e -p` while the dashboard is live, and the raw captures are
# left in artifacts/<run>/raw/ for rendering and review.
#
# Usage: bash scripts/capture-view-screens.sh [--context NAME] [--namespace NS]
#                                            [--repo PATH] [--attach]
set -uo pipefail

REPO="${KDASH_REPO:-/workspace/kdash}"
CTX="${KDASH_CTX:-devops-admin@local-cluster}"
NS="${KDASH_NS:-default}"
ATTACH=0
COLS=170; ROWS=50; NARROW_COLS=100; NARROW_ROWS=40
TZNAME="${KDASH_TZ:-Asia/Kolkata}"
GALLERY="${KDASH_GALLERY:-samples/cli}"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo)      REPO="${2:?}"; shift 2 ;;
    --context)   CTX="${2:?}"; shift 2 ;;
    --namespace) NS="${2:?}"; shift 2 ;;
    --gallery)   GALLERY="${2:?}"; shift 2 ;;
    --attach)    ATTACH=1; shift ;;
    -h|--help)   sed -n '2,20p' "$0"; exit 0 ;;
    *) printf 'unknown option: %s\n' "$1" >&2; exit 2 ;;
  esac
done

export PATH="$HOME/.local/bin:$PATH"
RUN="view-screens-$(date +%Y%m%d-%H%M%S)"
DIR="$REPO/artifacts/$RUN"
mkdir -p "$DIR/audit" "$DIR/reports" "$DIR/raw" || exit 1
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

capture() { # capture <session> <stem> <columns> <rows> <title>
  local sess="$1" stem="$2" cols="$3" rows="$4" title="$5"
  tmux capture-pane -e -p -t "$sess" > "$DIR/raw/$stem.ansi"
  tmux capture-pane -p    -t "$sess" > "$DIR/raw/$stem.txt"
  printf 'raw/%s.ansi\t%s\t%s\t%s\t%s/%s.png\n' "$stem" "$cols" "$rows" "$title" "$GALLERY" "$stem" >> "$MANIFEST"
  log "captured $stem"
}

step() { # step <seconds> <session> <keys...>
  local secs="$1" sess="$2"; shift 2
  local t=$(( $(date +%s) + secs ))
  tmux send-keys -t "$sess" "$@"
  while [ "$(date +%s)" -lt "$t" ]; do sleep 1; done
}

# ---- the dashboard session: one screen per view, then the panels ----
launch kd-view "$COLS" "$ROWS" KDASH_ACCEPT_DISCLAIMER=1 -- kdash -c "$CTX" -n "$NS" -i 5
launch kd-narrow "$NARROW_COLS" "$NARROW_ROWS" KDASH_ACCEPT_DISCLAIMER=1 -- kdash -c "$CTX" -n "$NS" -i 5
sleep 30

step 7 kd-view 1 ;  capture kd-view 01-pods       "$COLS" "$ROWS" \
  "1 PODS - pod and container usage against requests and limits"
step 7 kd-view 2 ;  capture kd-view 02-nodes      "$COLS" "$ROWS" \
  "2 NODE POOLS - this namespace against the whole cluster, per worker node"
step 7 kd-view 3 ;  capture kd-view 03-workloads  "$COLS" "$ROWS" \
  "3 WORKLOADS - replicas, rollout state and pods per node"
step 7 kd-view 4 ;  capture kd-view 04-ip         "$COLS" "$ROWS" \
  "4 IP POOL - pod IPs, node blocks, subnets and services"
step 7 kd-view 5 ;  capture kd-view 05-mem        "$COLS" "$ROWS" \
  "5 MEMORY - trend, node bars, top pods and OOM risk"
step 7 kd-view 6 ;  capture kd-view 06-io         "$COLS" "$ROWS" \
  "6 NET & DISK IO - traffic and disk read/write per node and pod"
step 7 kd-view 7 ;  capture kd-view 07-alerts     "$COLS" "$ROWS" \
  "7 ALERTS - verdict, every section and the kubectl action to run"
step 7 kd-view 8 ;  capture kd-view 08-services   "$COLS" "$ROWS" \
  "8 SERVICES - Ingress -> Service -> EndpointSlice -> ready pods"
step 7 kd-view 9 ;  capture kd-view 09-storage    "$COLS" "$ROWS" \
  "9 STORAGE - Pod -> PVC -> PV -> StorageClass"
step 7 kd-view E ;  capture kd-view 10-events     "$COLS" "$ROWS" \
  "E KUBERNETES EVENTS - real Events, deduplicated and counted"
step 7 kd-view '!' ; capture kd-view 11-explain   "$COLS" "$ROWS" \
  "! INCIDENT EVIDENCE - observed fact, explanation, next read-only check"

# command palette and doctor
step 6 kd-view ':' ; capture kd-view 12-palette   "$COLS" "$ROWS" \
  "the : command palette in a running kdash"
step 3 kd-view doctor ; step 8 kd-view Enter ; capture kd-view 13-doctor "$COLS" "$ROWS" \
  "DOCTOR - connection, TLS, RBAC, metrics and reports, each with a next check"

# inspector: picker, summary, previous logs, find, only-matches, containers, keys
step 7 kd-view 1
step 4 kd-view Enter ; capture kd-view 14-inspector-picker "$COLS" "$ROWS" \
  "inspector pod picker - every pod with state, restarts and age"
step 4 kd-view Enter ; capture kd-view 15-inspector-summary "$COLS" "$ROWS" \
  "inspector - pod summary and container state"
step 8 kd-view p ;     capture kd-view 16-inspector-previous-logs "$COLS" "$ROWS" \
  "inspector - previous logs of the selected container"
step 3 kd-view '/' ; step 2 kd-view error ; step 6 kd-view Enter
capture kd-view 17-inspector-find "$COLS" "$ROWS" \
  "inspector / find - matches highlighted, header counts them"
step 3 kd-view '&' ; step 2 kd-view error ; step 6 kd-view Enter
capture kd-view 18-inspector-only-matches "$COLS" "$ROWS" \
  "inspector & - only the matching lines remain"
step 6 kd-view c ;     capture kd-view 19-inspector-containers "$COLS" "$ROWS" \
  "inspector c - container picker with state, last exit and image"
step 5 kd-view '?' ;   capture kd-view 20-inspector-help "$COLS" "$ROWS" \
  "inspector ? - the key map of the log pane"

# back to the dashboard, then its own help
step 4 kd-view q
step 5 kd-view '?' ;   capture kd-view 21-help-keys "$COLS" "$ROWS" \
  "the dashboard ? help, including the inspector and interactive keys"
step 3 kd-view q

# 100-column layouts
step 20 kd-narrow 1 ;  capture kd-narrow 22-pods-100col "$NARROW_COLS" "$NARROW_ROWS" \
  "1 PODS on a 100 column terminal"
step 7  kd-narrow 8 ;  capture kd-narrow 23-services-100col "$NARROW_COLS" "$NARROW_ROWS" \
  "8 SERVICES on a 100 column terminal"

# ---- opt-in interactive mode (kdash -X keys), only with --attach ----
if [ "$ATTACH" = 1 ]; then
  step 7 kd-view 1
  step 4 kd-view S ;   capture kd-view 24-attach-blocked "$COLS" "$ROWS" \
    "S while interactive mode is off - kdash refuses and audits the refusal"
  step 4 kd-view X ;   capture kd-view 25-interactive-ask "$COLS" "$ROWS" \
    "X asks first: interactive mode is opt-in and audited"
  step 6 kd-view y ;   capture kd-view 26-interactive-on "$COLS" "$ROWS" \
    "interactive mode on for this session, with the audit line"
  step 6 kd-view S ;   capture kd-view 27-shell-picker "$COLS" "$ROWS" \
    "S - pick the pod and container for the shell"
  step 4 kd-view Enter
  step 12 kd-view ;    capture kd-view 28-shell-inside "$COLS" "$ROWS" \
    "a real shell inside the container (kubectl exec, audited)"
  step 3 kd-view exit ; step 2 kd-view Enter ; step 8 kd-view
  capture kd-view 29-back-in-dashboard "$COLS" "$ROWS" \
    "back in the dashboard after exit"
  step 6 kd-view D ;   capture kd-view 30-download-prompt "$COLS" "$ROWS" \
    "D - the download browser (local files, container files, review)"
  step 3 kd-view Escape ; step 3 kd-view Escape
  step 6 kd-view U ;   capture kd-view 31-upload-prompt "$COLS" "$ROWS" \
    "U - the upload browser"
  step 3 kd-view Escape ; step 3 kd-view Escape
fi

tmux kill-server 2>/dev/null || true
{
  printf 'run            %s\n' "$RUN"
  printf 'context        %s\n' "$CTX"
  printf 'namespace      %s\n' "$NS"
  printf 'version        %s\n' "$("$REPO/kdash" --version 2>/dev/null | head -1)"
  printf 'sha256         %s\n' "$(sha256sum "$REPO/kdash" 2>/dev/null | cut -d' ' -f1)"
  printf 'terminal       %s\n' "${COLS}x${ROWS} and ${NARROW_COLS}x${NARROW_ROWS}"
  printf 'interactive    %s\n' "$([ "$ATTACH" = 1 ] && echo 'captured (--attach)' || echo 'not captured (no --attach)')"
  printf 'purpose        one live screen per view of the current version plus the\n'
  printf '               panels, the inspector screens, the help and the opt-in\n'
  printf '               interactive mode, for the samples gallery\n'
} > "$DIR/README.txt"
log "done - $DIR"
printf '\nscreens: %s\n' "$(($(wc -l < "$MANIFEST") - 1))"
