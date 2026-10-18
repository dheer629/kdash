#!/usr/bin/env bash
# Full kdash validation cycle on WSL Ubuntu against the local vcluster.
#
# Steps, in order:
#   1  inventory the machine, the installed kdash and the cluster (read-only)
#   2  preview and run kdash-uninstall.sh, keeping every line of output
#   3  verify the removal and that reports, audit logs and configuration survive
#   4  install again with kdash-bundle.sh and verify a login shell runs v4
#   5  run kdash live for N minutes in one tmux session per namespace, capture
#      views 1-7 of every namespace, export the all-tabs HTML with x, quit with
#      q and record the exit status and the measured duration
#   6  rebuild the HTML from the recorded session, write the one-shot snapshots,
#      the text/TSV/CSV bundle and the audit report
#   7  write run-metadata.json, controller-actions.json and RUN_INVENTORY.md
#
# Everything is written under artifacts/<run-id>/. The checkout is not modified
# and no cluster object is created, changed or deleted (kdash is read-only).
#
# Usage: bash scripts/wsl-validation.sh [--namespaces "a b c"] [--minutes 5]
#        [--context NAME] [--repo DIR]
set -uo pipefail

REPO="${KDASH_REPO:-/workspace/kdash}"
CTX="${KDASH_CTX:-devops-admin@local-cluster}"
NAMESPACES="${KDASH_NS_LIST:-orders-service-e2e ml-service-prod gitops-core}"
MINUTES="${KDASH_RUN_MINUTES:-5}"
POLL="${KDASH_POLL:-5}"
SAMPLE="${KDASH_SAMPLE:-5}"
COLS="${KDASH_COLS:-170}"
ROWS="${KDASH_ROWS:-50}"
TZNAME="${KDASH_TZ:-Asia/Kolkata}"
VIEWS=(pods nodes workloads ip mem io alerts)

while [ "$#" -gt 0 ]; do
  case "$1" in
    --namespaces) NAMESPACES="${2:?}"; shift 2 ;;
    --minutes)    MINUTES="${2:?}"; shift 2 ;;
    --context)    CTX="${2:?}"; shift 2 ;;
    --repo)       REPO="${2:?}"; shift 2 ;;
    -h|--help)    sed -n '2,22p' "$0"; exit 0 ;;
    *) printf 'unknown option: %s\n' "$1" >&2; exit 2 ;;
  esac
done
case "$MINUTES" in ''|*[!0-9]*) printf -- '--minutes must be a number\n' >&2; exit 2 ;; esac

RUN_ID="wsl-validation-$(date +%Y%m%d-%H%M%S)"
ART="$REPO/artifacts/$RUN_ID"
LOGS="$ART/logs"
mkdir -p "$LOGS" || exit 1
RUN_LOG="$ART/run.log"; : > "$RUN_LOG"
STATUS_FILE="$ART/status.txt"
STARTED_ISO="$(date -Is)"
printf 'RUNNING %s\n' "$STARTED_ISO" > "$STATUS_FILE"
# the user install prefix first, so every kdash call in this script and in the
# tmux sessions resolves the copy this run installs
export PATH="$HOME/.local/bin:$PATH"
# a killed run must not look like a completed one
ON_EXIT_STATUS="aborted"
trap 'if [ "$ON_EXIT_STATUS" = aborted ]; then printf "ABORTED %s\n" "$(date -Is)" > "$STATUS_FILE"; fi' EXIT

FAILURES=()
log()  { printf '%s %s\n' "$(date -Is)" "$*" | tee -a "$RUN_LOG"; }
step() { log ""; log "==================== $* ===================="; }

# run_logged <logfile> <cmd...> : stdout+stderr to console, log file and run.log
run_logged() {
  local file="$1"; shift
  local rc=0
  { printf '$ %s\n\n' "$*"; "$@" 2>&1; rc=$?; printf '\n[exit %s]\n' "$rc"; } > "$file" 2>&1
  cat "$file" >> "$RUN_LOG"
  return "$rc"
}

# record one controller action as NDJSON (converted to JSON at the end)
ACTIONS="$ART/controller-actions.ndjson"; : > "$ACTIONS"
action() { # action <action> <namespace> [k=v ...]
  local what="$1" ns="$2"; shift 2
  local extra="" pair
  for pair in "$@"; do extra="$extra, \"${pair%%=*}\": ${pair#*=}"; done
  printf '{"epoch": %s, "time_utc": "%s", "action": "%s", "namespace": "%s"%s}\n' \
    "$(date +%s)" "$(date -u +%Y-%m-%dT%H:%M:%S+00:00)" "$what" "$ns" "$extra" >> "$ACTIONS"
}

log "run id        $RUN_ID"
log "repository    $REPO"
log "context       $CTX"
log "namespaces    $NAMESPACES"
log "live window   $MINUTES minute(s), poll ${POLL}s, history sample ${SAMPLE}s, terminal ${COLS}x${ROWS}"
log "artifacts     $ART"

# ---------------------------------------------------------------- 1 inventory
step "1  inventory: host, installed kdash, cluster (read-only)"
run_logged "$LOGS/01-preinstall.log" bash -c '
  set -u
  echo "date:            $(date -Is)"
  echo "host:            $(hostname)  (kernel $(uname -r))"
  echo "user:            $(id -un) uid=$(id -u)"
  echo "bash:            $(bash --version | head -1)"
  echo "tmux:            $(tmux -V 2>&1)"
  echo "python3:         $(command -v python3 || echo missing)"
  echo "kubectl:         $(command -v kubectl || echo missing)"
  echo "kubectl client:  $(kubectl version --client 2>/dev/null | tr "\n" " ")"
  echo "awk:             $(awk --version 2>/dev/null | head -1 || awk -W version 2>&1 | head -1)"
  echo
  echo "kdash on PATH (this shell):"
  type -a kdash 2>&1 || echo "  (not found in this non-login shell)"
  echo
  echo "kdash installed files:"
  ls -l "$HOME/.local/bin/kdash" /usr/local/bin/kdash "$HOME/.kdash-shell.bash" "$HOME/.kdash-completion.bash" 2>&1
  echo
  echo "installed kdash version:"
  "$HOME/.local/bin/kdash" --version 2>&1 | head -3 || true
  echo
  echo "installed kdash sha256 vs repository copy:"
  sha256sum "$HOME/.local/bin/kdash" "'"$REPO"'/kdash" 2>&1
  echo
  echo "kept data before removal (config, reports, sessions, audit, old versions):"
  ls -ld "$HOME/.config/kdash" "$HOME/kdash_reports" "$HOME/kdash_reports/audit" "$HOME/.kdash-old" 2>&1
  find "$HOME/kdash_reports" -maxdepth 1 -mindepth 1 -printf "  %f\n" 2>/dev/null | sort | head -20
  echo
  echo "kubectl contexts:"
  kubectl config get-contexts 2>&1
  echo
  echo "nodes:"
  kubectl --context "'"$CTX"'" get nodes -o wide 2>&1 | head -5
  echo
  echo "namespaces:"
  kubectl --context "'"$CTX"'" get ns --no-headers -o custom-columns=NAME:.metadata.name 2>&1 | tr "\n" " "
  echo
  echo "pods per namespace in scope:"
  for ns in '"$NAMESPACES"'; do
    printf "  %-24s %s\n" "$ns" "$(kubectl --context "'"$CTX"'" -n "$ns" get pods --no-headers 2>/dev/null | wc -l)"
  done
  echo
  echo "kubectl read permissions used by kdash:"
  for v in "list pods" "list nodes" "list services" "get nodes/proxy" "list pods.metrics.k8s.io"; do
    printf "  %-28s %s\n" "$v" "$(kubectl --context "'"$CTX"'" auth can-i $v 2>/dev/null | head -1)"
  done
' || FAILURES+=("inventory")

# --------------------------------------------------------------- 2 uninstall
step "2  uninstall: preview, then remove the installed copy"
run_logged "$LOGS/02-uninstall-preview.log" bash "$REPO/kdash-uninstall.sh" --dry-run \
  || FAILURES+=("uninstall-preview")
run_logged "$LOGS/03-uninstall.log" bash "$REPO/kdash-uninstall.sh" || FAILURES+=("uninstall")

step "3  uninstall verification (binary gone, data kept)"
run_logged "$LOGS/04-uninstall-verification.log" bash -c '
  set -u
  echo "kdash files that must be gone:"
  for f in "$HOME/.local/bin/kdash" "$HOME/.kdash-shell.bash" "$HOME/.kdash-completion.bash"; do
    if [ -e "$f" ] || [ -L "$f" ]; then echo "  STILL PRESENT  $f"; else echo "  removed        $f"; fi
  done
  echo
  echo "kdash setup block in startup files:"
  grep -n "kdash setup" "$HOME/.bashrc" "$HOME/.bash_profile" 2>/dev/null || echo "  none (correct)"
  echo
  echo "startup backups written by the uninstaller:"
  ls -l "$HOME"/.bashrc.bak.kdash.* "$HOME"/.bash_profile.bak.kdash.* 2>/dev/null || echo "  none"
  echo
  echo "data that must survive:"
  ls -ld "$HOME/.config/kdash" "$HOME/kdash_reports" "$HOME/kdash_reports/audit" 2>&1
  ls -l "$HOME"/kdash_reports/audit/*.log 2>&1 | tail -3
  echo
  echo "login shell resolution after removal:"
  bash -lc "type -a kdash 2>&1 | head -3; kdash --version 2>&1 | head -2" 2>&1
  echo
  echo "hash chain of the kept audit log (verified with the repository copy):"
  bash "'"$REPO"'/kdash" --audit-verify 2>&1 | head -6 || true
' || FAILURES+=("uninstall-verification")

# ----------------------------------------------------------------- 4 install
step "4  install again with kdash-bundle.sh (current user -> ~/.local/bin)"
run_logged "$LOGS/05-install.log" bash "$REPO/kdash-bundle.sh" || FAILURES+=("install")
run_logged "$LOGS/06-install-verification.log" bash -c '
  set -u
  echo "installer self-check:"
  bash "'"$REPO"'/kdash-bundle.sh" --check 2>&1
  echo
  echo "login shell resolution:"
  bash -lc "type -a kdash; kdash --version" 2>&1
  echo
  echo "installed sha256 vs repository copy:"
  sha256sum "$HOME/.local/bin/kdash" "'"$REPO"'/kdash" 2>&1
  echo
  echo "author and audit locations:"
  kdash --about 2>&1 | head -12
' || FAILURES+=("install-verification")
# --accept-disclaimer only sets the acceptance flag and then runs the dashboard,
# so acceptance is exercised here through the environment variable in a one-shot
# run that prints one frame and exits; the live sessions inherit the same flag.
FIRST_NS="${NAMESPACES%% *}"
run_logged "$LOGS/07-disclaimer-accept.log" timeout 120 bash -c \
  "KDASH_ACCEPT_DISCLAIMER=1 kdash -c '$CTX' -n '$FIRST_NS' --once -o text" \
  || FAILURES+=("disclaimer")
run_logged "$LOGS/08-oneshot-pods-text.log" timeout 120 bash -c \
  "kdash -c '$CTX' -n '$FIRST_NS' --once -v pods -o tsv --io-wait 8 | head -15" \
  || FAILURES+=("oneshot")

# ------------------------------------------------------------------ 5 live run
step "5  live run: $MINUTES minute(s) per namespace, views 1-7 captured"
cat > "$ART/tmux.conf" <<'TMUXCONF'
set -g status off
set -g default-terminal "xterm-256color"
set -g history-limit 5000
set -g escape-time 0
TMUXCONF

NS_ARR=(); SESS_ARR=(); DIR_ARR=(); n=0
# a fresh tmux server is required so that this run's config (no status line,
# 170x50 panes) applies; leftover sessions from an earlier run are ended here
if tmux ls >/dev/null 2>&1; then
  log "  ending leftover tmux sessions from an earlier run: $(tmux ls | tr '\n' ' ')"
  tmux kill-server 2>/dev/null || true
  for _ in $(seq 1 20); do tmux ls >/dev/null 2>&1 || break; sleep 1; done
fi
for ns in $NAMESPACES; do
  n=$((n + 1))
  dir="$ART/$ns"; sess="kdash-validation-$n"
  mkdir -p "$dir/cli" "$dir/reports" "$dir/audit"
  cat > "$dir/launch.sh" <<LAUNCH
#!/usr/bin/env bash
# live kdash run: namespace $ns, context $CTX, ${MINUTES} minute observation window
export TZ='$TZNAME' TERM=xterm-256color
export KDASH_REPORT_DIR='$dir/reports'
export KDASH_AUDIT_DIR='$dir/audit'
export KDASH_ACCEPT_DISCLAIMER=1
export KDASH_COLUMNS=$COLS KDASH_LINES=$ROWS KDASH_SAMPLE_EVERY=$SAMPLE
date +%s > '$dir/started.epoch'; date -Is > '$dir/started.iso'
kdash -c '$CTX' -n '$ns' -i $POLL
rc=\$?
printf '%s\n' "\$rc" > '$dir/exit-status.txt'
date +%s > '$dir/ended.epoch'; date -Is > '$dir/ended.iso'
exit "\$rc"
LAUNCH
  chmod 755 "$dir/launch.sh"
  tmux -f "$ART/tmux.conf" new-session -d -s "$sess" -x "$COLS" -y "$ROWS" "bash '$dir/launch.sh'"
  tmux pipe-pane -t "$sess" "cat >> '$dir/terminal.raw.log'"
  NS_ARR+=("$ns"); SESS_ARR+=("$sess"); DIR_ARR+=("$dir")
  log "  started $sess for $ns (terminal ${COLS}x${ROWS}, reports $dir/reports)"
done

for i in "${!SESS_ARR[@]}"; do
  for _ in $(seq 1 90); do [ -s "${DIR_ARR[$i]}/started.epoch" ] && break; sleep 1; done
done
sleep 5
t0=$(date +%s)
action controller_start "-" "epoch=$t0" "namespaces=\"$(printf '%s' "$NAMESPACES" | tr ' ' '+')\""
log "  all dashboards up; live window starts now (t0=$t0)"

for i in $(seq 1 ${#VIEWS[@]}); do
  target=$((t0 + 10 + (i - 1) * 40))
  while [ "$(date +%s)" -lt "$target" ]; do sleep 1; done
  for j in "${!SESS_ARR[@]}"; do
    tmux send-keys -t "${SESS_ARR[$j]}" "$i"
    action select_view "${NS_ARR[$j]}" "view=$i"
  done
  sleep 4
  stem="$(printf '%02d-%s' "$i" "${VIEWS[$((i - 1))]}")"
  for j in "${!SESS_ARR[@]}"; do
    tmux capture-pane -e -p -t "${SESS_ARR[$j]}" > "${DIR_ARR[$j]}/cli/$stem.ansi"
    tmux capture-pane -p    -t "${SESS_ARR[$j]}" > "${DIR_ARR[$j]}/cli/$stem.txt"
    action capture_view "${NS_ARR[$j]}" "view=$i" "stem=\"$stem\""
  done
  log "  captured $stem for every namespace ($(wc -l < "${DIR_ARR[0]}/cli/$stem.txt") rows)"
done

while [ "$(( $(date +%s) - t0 ))" -lt $((MINUTES * 60)) ]; do sleep 5; done
log "  live window complete ($(( $(date +%s) - t0 ))s); exporting the all-tabs HTML with key x"
for j in "${!SESS_ARR[@]}"; do
  tmux send-keys -t "${SESS_ARR[$j]}" x
  action export_namespace_html "${NS_ARR[$j]}"
done
sleep 20
for j in "${!SESS_ARR[@]}"; do
  newest="$(find "${DIR_ARR[$j]}/reports" -maxdepth 1 -name '*.html' -newermt "@$t0" 2>/dev/null | head -2 | tr '\n' ' ')"
  log "  HTML written by x for ${NS_ARR[$j]}: ${newest:-none}"
done

while [ "$(( $(date +%s) - t0 ))" -lt $((MINUTES * 60 + 20)) ]; do sleep 2; done
for j in "${!SESS_ARR[@]}"; do tmux send-keys -t "${SESS_ARR[$j]}" q; action quit "${NS_ARR[$j]}"; done
for _ in $(seq 1 60); do
  all_done=1
  for d in "${DIR_ARR[@]}"; do [ -s "$d/exit-status.txt" ] || all_done=0; done
  [ "$all_done" = 1 ] && break
  sleep 2
done
for i in "${!SESS_ARR[@]}"; do
  d="${DIR_ARR[$i]}"
  if [ -s "$d/exit-status.txt" ] && [ -s "$d/ended.epoch" ] && [ -s "$d/started.epoch" ]; then
    rc="$(cat "$d/exit-status.txt")"
    elapsed=$(( $(cat "$d/ended.epoch") - $(cat "$d/started.epoch") ))
  else
    rc="missing"; elapsed=0
  fi
  log "  ${NS_ARR[$i]}: kdash exit=$rc, measured live duration=${elapsed}s"
  action completed "${NS_ARR[$i]}" "exit_status=$rc" "elapsed_seconds=$elapsed"
  [ "$rc" = 0 ] || FAILURES+=("live-${NS_ARR[$i]}-exit-${rc}")
  [ "$elapsed" -ge $((MINUTES * 60)) ] || FAILURES+=("live-${NS_ARR[$i]}-shorter-than-${MINUTES}m")
done
tmux kill-server 2>/dev/null || true

# ------------------------------------------------------------------ 6 reports
step "6  reports: session rebuild, one-shot snapshots, bundle, audit evidence"
for i in "${!NS_ARR[@]}"; do
  ns="${NS_ARR[$i]}"; dir="${DIR_ARR[$i]}"
  export TZ="$TZNAME" TERM=xterm-256color
  export KDASH_REPORT_DIR="$dir/reports" KDASH_AUDIT_DIR="$dir/audit"
  export KDASH_ACCEPT_DISCLAIMER=1 KDASH_SAMPLE_EVERY="$SAMPLE"
  sd="$(ls -1dt "$dir/reports"/sessions/kdash_* 2>/dev/null | head -1)"
  printf '%s\n' "${sd:-none}" > "$dir/session-dir.txt"
  log "  $ns recorded session: ${sd:-none}"
  [ -n "$sd" ] || { FAILURES+=("no-session-$ns"); continue; }
  run_logged "$LOGS/10-session-report-$ns.log" timeout 240 kdash -c "$CTX" -n "$ns" --session-report "$sd" \
    || FAILURES+=("session-report-$ns")
  run_logged "$LOGS/11-snapshot-all-$ns.log" timeout 300 kdash -c "$CTX" -n "$ns" --snapshot all --io-wait 10 \
    || FAILURES+=("snapshot-all-$ns")
  run_logged "$LOGS/12-report-bundle-$ns.log" timeout 300 kdash -c "$CTX" -n "$ns" --report "$dir/reports" \
    || FAILURES+=("report-bundle-$ns")
  run_logged "$LOGS/13-audit-$ns.log" timeout 120 bash -c 'kdash --audit 200; echo; kdash --audit-verify' \
    || FAILURES+=("audit-$ns")
  run_logged "$LOGS/14-audit-report-$ns.log" timeout 120 kdash --audit-report "$dir/audit" \
    || FAILURES+=("audit-report-$ns")
done
unset KDASH_REPORT_DIR KDASH_AUDIT_DIR

# ---------------------------------------------------------------- 7 inventory
step "7  run inventory"
if command -v python3 >/dev/null 2>&1; then
  python3 - "$ACTIONS" "$ART/controller-actions.json" <<'PY' >> "$RUN_LOG" 2>&1
import json, sys
src, dst = sys.argv[1], sys.argv[2]
items = [json.loads(line) for line in open(src, encoding="utf-8") if line.strip()]
with open(dst, "w", encoding="utf-8") as handle:
    handle.write(json.dumps(items, indent=2) + "\n")
print(f"  {len(items)} controller actions -> {dst}")
PY
else
  cp "$ACTIONS" "$ART/controller-actions.json"
fi

KVER="$("$HOME/.local/bin/kdash" --version 2>/dev/null | head -1 | sed 's/^kdash //')"
FAIL_JSON=""
if [ "${#FAILURES[@]}" -gt 0 ]; then
  FAIL_JSON="$(printf '"%s", ' "${FAILURES[@]}" | sed 's/, $//')"
fi
{
  printf '{\n'
  printf '  "run_id": "%s",\n' "$RUN_ID"
  printf '  "started_iso": "%s",\n' "$STARTED_ISO"
  printf '  "finished_iso": "%s",\n' "$(date -Is)"
  printf '  "context": "%s",\n' "$CTX"
  printf '  "timezone": "%s",\n' "$TZNAME"
  printf '  "kdash_version": "%s",\n' "$KVER"
  printf '  "live_window_seconds": %s,\n' "$((MINUTES * 60))"
  printf '  "poll_seconds": %s,\n' "$POLL"
  printf '  "history_sample_seconds": %s,\n' "$SAMPLE"
  printf '  "terminal": {"columns": %s, "rows": %s},\n' "$COLS" "$ROWS"
  printf '  "namespaces": [%s],\n' "$(printf '"%s", ' $NAMESPACES | sed 's/, $//')"
  printf '  "sessions": [\n'
  for i in "${!NS_ARR[@]}"; do
    d="${DIR_ARR[$i]}"
    printf '    {"namespace": "%s", "tmux_session": "%s", "directory": "%s", "exit_status": "%s", "elapsed_seconds": %s}%s\n' \
      "${NS_ARR[$i]}" "${SESS_ARR[$i]}" "$d" \
      "$(cat "$d/exit-status.txt" 2>/dev/null || echo missing)" \
      "$(( $(cat "$d/ended.epoch" 2>/dev/null || echo 0) - $(cat "$d/started.epoch" 2>/dev/null || echo 0) ))" \
      "$([ "$i" -lt $(( ${#NS_ARR[@]} - 1 )) ] && printf ',' || printf '')"
  done
  printf '  ],\n'
  printf '  "failures": [%s]\n' "$FAIL_JSON"
  printf '}\n'
} > "$ART/run-metadata.json"
printf '%s\n' "$RUN_ID" > "$REPO/artifacts/latest-run.txt"
log "  metadata: $ART/run-metadata.json"

{
  printf '# kdash WSL vcluster validation run %s\n\n' "$RUN_ID"
  printf 'Started %s, finished %s. Context `%s`, timezone %s.\n\n' "$STARTED_ISO" "$(date -Is)" "$CTX" "$TZNAME"
  printf 'kdash %s, live window %s minute(s) per namespace, poll %ss, history sample %ss, terminal %sx%s.\n\n' \
    "$KVER" "$MINUTES" "$POLL" "$SAMPLE" "$COLS" "$ROWS"
  printf '## Steps and logs\n\n'
  printf '| Step | Log |\n|---|---|\n'
  for f in "$LOGS"/*.log; do
    printf '| %s | `%s` |\n' "$(basename "$f" .log)" "${f#"$REPO"/}"
  done
  printf '\n## Namespaces\n\n'
  printf '| Namespace | tmux session | exit | live seconds | recorded session | CLI captures | HTML reports |\n|---|---|---|---|---|---|---|\n'
  for i in "${!NS_ARR[@]}"; do
    d="${DIR_ARR[$i]}"
    printf '| %s | %s | %s | %s | `%s` | %s | %s |\n' \
      "${NS_ARR[$i]}" "${SESS_ARR[$i]}" \
      "$(cat "$d/exit-status.txt" 2>/dev/null || echo missing)" \
      "$(( $(cat "$d/ended.epoch" 2>/dev/null || echo 0) - $(cat "$d/started.epoch" 2>/dev/null || echo 0) ))" \
      "$(basename "$(cat "$d/session-dir.txt" 2>/dev/null)" 2>/dev/null)" \
      "$(ls -1 "$d/cli"/*.ansi 2>/dev/null | wc -l)" \
      "$(find "$d/reports" -maxdepth 1 -name '*.html' 2>/dev/null | wc -l)"
  done
  printf '\n## HTML and table files produced\n\n'
  for i in "${!NS_ARR[@]}"; do
    d="${DIR_ARR[$i]}"
    printf '### %s\n\n' "${NS_ARR[$i]}"
    find "$d/reports" -maxdepth 1 -type f \( -name '*.html' -o -name '*.tsv' -o -name '*.csv' -o -name '*.txt' -o -name 'SHA256SUMS' \) -printf '%f\t%s bytes\n' 2>/dev/null | sort
    printf '\nAudit files: '
    find "$d/audit" -maxdepth 1 -type f -printf '%f ' 2>/dev/null
    printf '\n\n'
  done
  printf '## Failures\n\n'
  if [ "${#FAILURES[@]}" -eq 0 ]; then printf 'None.\n'; else printf '%s\n' "${FAILURES[@]}" | sed 's/^/- /'; fi
  printf '\n## Integrity\n\n```\n'
  find "$ART" -maxdepth 1 -name '*.json' -printf '%f ' 2>/dev/null; printf '\n'
  for d in "${DIR_ARR[@]}"; do
    sha256sum "$d/cli"/*.ansi 2>/dev/null | sed "s#$REPO/##"
  done
  printf '```\n'
} > "$ART/RUN_INVENTORY.md"

ON_EXIT_STATUS="done"
if [ "${#FAILURES[@]}" -eq 0 ]; then
  printf 'DONE\n' > "$STATUS_FILE"
  log "DONE - all steps completed, no failures"
  rc=0
else
  printf 'DONE_WITH_FAILURES\n' > "$STATUS_FILE"
  log "DONE_WITH_FAILURES: ${FAILURES[*]}"
  rc=1
fi
log "artifacts: $ART"
exit "$rc"
