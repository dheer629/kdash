# Interactive pod inspection (read-only reads) plus the opt-in container shell and file copy. This source is embedded in the release
# executable; all API reads use the audited, context-pinned KC argv array.
# Logs live only in TMPD/inspector and never enter MODEL or report/session files.

inspector_clean() {
  # Preserve UTF-8, tabs and line endings, but remove terminal control bytes.
  LC_ALL=C tr -d '\000-\010\013-\037\177'
}

inspector_identity_ok() {
  [[ "${1:-}" =~ ^[a-z0-9]([-a-z0-9]*[a-z0-9])?$ ]] &&
    [[ "${2:-}" =~ ^[a-z0-9]([-a-z0-9.]*[a-z0-9])?$ ]] &&
    [ "${#1}" -le 63 ] && [ "${#2}" -le 253 ]
}

inspector_limits() {
  # Logs are read in full up to these limits (+ reads 4x more, A reads everything the
  # kubelet still has, up to KDASH_LOG_MAX_BYTES). Nothing is cut sideways: long lines
  # wrap (W toggles), so a JSON or stack-trace line is shown completely.
  INSPECTOR_TAIL="${INSPECTOR_TAIL_SET:-${KDASH_LOG_TAIL:-5000}}"
  INSPECTOR_BYTES="${INSPECTOR_BYTES_SET:-${KDASH_LOG_LIMIT_BYTES:-8388608}}"
  case "$INSPECTOR_TAIL" in -1) ;; ''|*[!0-9]*) INSPECTOR_TAIL=5000 ;; esac
  case "$INSPECTOR_BYTES" in ''|*[!0-9]*) INSPECTOR_BYTES=8388608 ;; esac
  [ "${#INSPECTOR_TAIL}" -gt 7 ] && INSPECTOR_TAIL=1000000
  [ "${#INSPECTOR_BYTES}" -gt 9 ] && INSPECTOR_BYTES=268435456
  [ "$INSPECTOR_TAIL" = -1 ] || INSPECTOR_TAIL=$((10#$INSPECTOR_TAIL)); INSPECTOR_BYTES=$((10#$INSPECTOR_BYTES))
  [ "$INSPECTOR_TAIL" = -1 ] || [ "$INSPECTOR_TAIL" -ge 1 ] || INSPECTOR_TAIL=1
  [ "$INSPECTOR_TAIL" = -1 ] || [ "$INSPECTOR_TAIL" -le 1000000 ] || INSPECTOR_TAIL=1000000
  [ "$INSPECTOR_BYTES" -ge 1024 ] || INSPECTOR_BYTES=1024
  [ "$INSPECTOR_BYTES" -le 268435456 ] || INSPECTOR_BYTES=268435456
  # f follows a log pane: reload it every KDASH_INSPECT_FOLLOW seconds (1..60).
  INSPECTOR_FOLLOW_SECS="${KDASH_INSPECT_FOLLOW:-5}"
  case "$INSPECTOR_FOLLOW_SECS" in ''|*[!0-9]*) INSPECTOR_FOLLOW_SECS=5 ;; esac
  [ "$INSPECTOR_FOLLOW_SECS" -lt 1 ] && INSPECTOR_FOLLOW_SECS=1
  [ "$INSPECTOR_FOLLOW_SECS" -gt 60 ] && INSPECTOR_FOLLOW_SECS=60
  return 0
}

inspector_query() { # output-file kubectl-args...; bounded text, preserved rc
  local dest="$1" rc=0 cap="${INSPECTOR_QUERY_CAP:-262144}" reader; shift
  "${KC[@]}" "$@" > "$dest.raw" 2> "$dest.err" & reader=$!
  wait "$reader" || rc=$?
  { head -c "$cap" "$dest.raw"; } | inspector_clean > "$dest"
  if [ "$rc" != 0 ]; then
    printf '\nRead failed (exit %s). Verify the namespace, pod and your RBAC permissions.\n' "$rc" >> "$dest"
    head -c 4096 "$dest.err" | inspector_clean >> "$dest"
  fi
  if [ "$(wc -c < "$dest.raw")" -ge "$cap" ]; then
    if [ "${INSPECTOR_QUERY_NOTE:-}" = logs ]; then : > "$dest.capped"
    else printf '\n[Output clipped at %s bytes.]\n' "$cap" >> "$dest"; fi
  fi
  rm -f -- "$dest.raw" "$dest.err"
  return "$rc"
}

inspector_containers() { # ns pod -> TYPE<TAB>NAME<TAB>IMAGE (including init/debug)
  "${KC[@]}" get pod "$2" -n "$1" -o 'jsonpath={range .spec.containers[*]}regular{"\t"}{.name}{"\t"}{.image}{"\n"}{end}{range .spec.initContainers[*]}init{"\t"}{.name}{"\t"}{.image}{"\n"}{end}{range .spec.ephemeralContainers[*]}debug{"\t"}{.name}{"\t"}{.image}{"\n"}{end}' |
    inspector_clean
}

inspector_summary() { # ns pod output-file
  inspector_query "$3" get pod "$2" -n "$1" -o 'jsonpath=Name: {.metadata.name}{"\n"}Namespace: {.metadata.namespace}{"\n"}UID: {.metadata.uid}{"\n"}Created: {.metadata.creationTimestamp}{"\n"}Phase: {.status.phase}{"\n"}Reason: {.status.reason}{"\n"}Message: {.status.message}{"\n"}Node: {.spec.nodeName}{"\n"}Pod IP: {.status.podIP}{"\n"}Service account: {.spec.serviceAccountName}{"\n"}{range .metadata.ownerReferences[*]}Owner: {.kind}/{.name}{"\n"}{end}{"\nCONDITIONS\n"}{range .status.conditions[*]}{.type}{"\t"}{.status}{"\t"}{.reason}{"\t"}{.message}{"\n"}{end}{"\nCONTAINERS (requests / limits)\n"}{range .spec.containers[*]}{.name}{"\t"}{.image}{"\n"}  CPU: {.resources.requests.cpu} / {.resources.limits.cpu}{"\t"}Memory: {.resources.requests.memory} / {.resources.limits.memory}{"\n"}{end}{"\nCONTAINER STATUS\n"}{range .status.containerStatuses[*]}{.name}{"\tready="}{.ready}{"\trestarts="}{.restartCount}{"\n"}  Waiting: {.state.waiting.reason} {.state.waiting.message}{"\n"}  Running since: {.state.running.startedAt}{"\n"}  Terminated: {.state.terminated.reason} exit={.state.terminated.exitCode}{"\n"}  Previous: {.lastState.terminated.reason} exit={.lastState.terminated.exitCode}{"\n"}{end}{"\nINIT CONTAINER STATUS\n"}{range .status.initContainerStatuses[*]}{.name}{"\tready="}{.ready}{"\trestarts="}{.restartCount}{"\t"}{.state.waiting.reason}{.state.terminated.reason}{"\n"}{end}'
}

inspector_logs() { # ns pod container current|previous output-file
  local ns="$1" pod="$2" container="$3" mode="$4" dest="$5" rc=0
  local flags=()
  case "$mode" in current) ;; previous) flags+=(--previous) ;; *) printf 'Invalid log mode: current or previous required.\n' > "$dest"; return 2 ;; esac
  [[ "$container" =~ ^[a-z0-9]([-a-z0-9]*[a-z0-9])?$ ]] || {
    printf 'Choose a valid container before reading logs.\n' > "$dest"; return 2;
  }
  inspector_limits
  INSPECTOR_QUERY_CAP="$INSPECTOR_BYTES" INSPECTOR_QUERY_NOTE=logs inspector_query "$dest.body" logs "$pod" -n "$ns" -c "$container" \
    --tail="$INSPECTOR_TAIL" --limit-bytes="$INSPECTOR_BYTES" --timestamps=true "${flags[@]}" || rc=$?
  # what was read, for the status rule: lines, bytes, whether a limit was reached
  local nl nb; nl=$(awk 'END { print NR }' "$dest.body"); nb=$(wc -c < "$dest.body" | tr -d ' ')
  INSPECTOR_LOGINFO="$nl lines, $(xfer_hsize "$nb")"
  if [ "$INSPECTOR_TAIL" = -1 ]; then INSPECTOR_LOGINFO+=" - everything the kubelet has"
  elif [ "$nl" -ge "$INSPECTOR_TAIL" ]; then INSPECTOR_LOGINFO+=" - newest $INSPECTOR_TAIL only: + more, A all"
  else INSPECTOR_LOGINFO+=" - complete"; fi
  [ ! -f "$dest.body.capped" ] || { INSPECTOR_LOGINFO+=" - $(xfer_hsize "$INSPECTOR_BYTES") limit reached: A reads more"; rm -f -- "$dest.body.capped"; }
  printf '%s' "$INSPECTOR_LOGINFO" > "$dest.info"
  cat "$dest.body" > "$dest"; rm -f -- "$dest.body"
  [ "$mode" != previous ] || [ "$rc" = 0 ] || printf '\nPrevious logs require a previously terminated instance of this container.\n' >> "$dest"
  return "$rc"
}

inspector_events() { # ns pod output-file
  if declare -F events_render >/dev/null; then
    events_render "$1" "$2" | inspector_clean > "$3"
  else
    inspector_query "$3" get events -n "$1" --field-selector="involvedObject.kind=Pod,involvedObject.name=$2" \
      --sort-by=.metadata.creationTimestamp -o wide
  fi
}

inspector_explain() { # ns pod output-file
  if declare -F explain_render >/dev/null; then
    explain_render "$1" "$2" | inspector_clean > "$3"
  else
    printf 'Failure explanations are unavailable. Inspect conditions, Events and previous logs for evidence.\n' > "$3"
  fi
}

inspector_render() { # ns pod: plain bounded CLI output; logs require explicit opt-in
  local ns="${1:-${NS:-default}}" pod="${2:-}" d container="${KDASH_INSPECT_CONTAINER:-}" rc=0 mode="${KDASH_INSPECT_LOGS:-}"
  inspector_identity_ok "$ns" "$pod" || { printf 'kdash: inspect requires a valid namespace and pod name.\n' >&2; return 2; }
  d="${TMPD:?}/inspector/cli"; (umask 077; mkdir -p "$d") || return 1
  printf 'Context: %s | Namespace: %s | Pod: %s\n\n' "${CTX_NAME:-${CTX:-current}}" "$ns" "$pod" | inspector_clean
  if [ -n "$mode" ]; then
    if [ -z "$container" ]; then
      if ! inspector_containers "$ns" "$pod" > "$d/containers" 2> "$d/container.err"; then
        printf 'Cannot discover containers.\n' >&2
        head -c 4096 "$d/container.err" | inspector_clean >&2
        rm -rf -- "$d"; return 1
      fi
      container="$(awk -F '\t' 'NF >= 2 {print $2; exit}' "$d/containers")"
    fi
    inspector_logs "$ns" "$pod" "$container" "$mode" "$d/output" || rc=$?
  else
    inspector_summary "$ns" "$pod" "$d/output" || rc=$?
  fi
  cat "$d/output"
  rm -rf -- "$d"
  return "$rc"
}

inspector_model_rows() { # MODEL has already applied the dashboard/API filters
  [ -r "${MODEL:?}/pods.tsv" ] || return 0
  awk -F '\t' '
    NR > 1 {printf "%s\t%s\t%s\t%s\t%s\t%s\n", $2, $3, $4, $5, $6, $7}
  ' "$MODEL/pods.tsv" | inspector_clean
}

inspector_size() {
  INSPECTOR_ROWS="${KDASH_LINES:-${LINES:-24}}"; INSPECTOR_COLS="${KDASH_COLUMNS:-${COLUMNS:-100}}"
  if command -v tput >/dev/null 2>&1; then
    [ -n "${KDASH_LINES:-}" ] || INSPECTOR_ROWS="$(tput lines 2>/dev/null || printf 24)"
    [ -n "${KDASH_COLUMNS:-}" ] || INSPECTOR_COLS="$(tput cols 2>/dev/null || printf 100)"
  fi
  case "$INSPECTOR_ROWS" in ''|*[!0-9]*) INSPECTOR_ROWS=24 ;; esac
  case "$INSPECTOR_COLS" in ''|*[!0-9]*) INSPECTOR_COLS=100 ;; esac
  [ "$INSPECTOR_ROWS" -ge 12 ] || INSPECTOR_ROWS=12
  [ "$INSPECTOR_COLS" -ge 40 ] || INSPECTOR_COLS=40
  return 0
}

# Escape sequences: arrows, PgUp/PgDn, Home/End. Decoded after a short pause so
# a bare Esc still means "back".
inspector_decode_escape() {
  local seq="" extra=""
  IFS= read -rsn2 -t 0.05 seq </dev/tty || true
  case "$seq" in
    '[A') INSPECTOR_KEY=k ;; '[B') INSPECTOR_KEY=j ;;
    '[C') INSPECTOR_KEY='<RIGHT>' ;; '[D') INSPECTOR_KEY='<LEFT>' ;;
    '[H') INSPECTOR_KEY=g ;; '[F') INSPECTOR_KEY=G ;;
    '[5'|'[6'|'[1'|'[4')
      IFS= read -rsn1 -t 0.05 extra </dev/tty || true
      case "$seq$extra" in '[5~') INSPECTOR_KEY=b ;; '[6~') INSPECTOR_KEY=' ' ;; '[1~') INSPECTOR_KEY=g ;; '[4~') INSPECTOR_KEY=G ;; esac ;;
  esac
}

# Blocking without an argument; with a timeout it returns 1 when no key arrived
# (follow mode uses that to reload the pane).
inspector_key() {
  local t="${1:-}"
  INSPECTOR_KEY=""
  if [ -n "$t" ]; then
    IFS= read -rsn1 -t "$t" INSPECTOR_KEY </dev/tty || { INSPECTOR_KEY=""; return 1; }
  else
    IFS= read -rsn1 INSPECTOR_KEY </dev/tty || return 1
  fi
  [ "$INSPECTOR_KEY" != $'\033' ] || inspector_decode_escape
  return 0
}

#---- search, log level, filtering and highlighting (all local, never the API) --------
INSPECTOR_SEARCH="${INSPECTOR_SEARCH:-}"
INSPECTOR_ONLY="${INSPECTOR_ONLY:-0}"     # 1 = the view keeps only matching lines (key &)
INSPECTOR_LEVEL_NAME="${INSPECTOR_LEVEL_NAME:-all}"
INSPECTOR_LEVEL_PAT="${INSPECTOR_LEVEL_PAT:-}"

# A lowercase pattern without regex metacharacters matches case-insensitively, which is
# what an operator typing "error" means; anything else is used exactly as written.
inspector_icase() {
  case "$1" in
    *[A-Z]*) printf 0 ;;
    *"["*|*"]"*|*"("*|*")"*|*"|"*|*"+"*|*"*"*|*"?"*|*"{"*|*"}"*|*"^"*|*"$"*|*"."*|*"\\"*) printf 0 ;;
    *) printf 1 ;;
  esac
}

inspector_pattern_ok() {  # valid extended regular expression, no control bytes
  local p="$1" rc=0
  [ "${#p}" -le 200 ] || return 1
  [[ "$p" != *[$'\001'-$'\037'$'\177']* ]] || return 1
  printf '' | grep -E -- "$p" >/dev/null 2>&1 || rc=$?
  [ "$rc" != 2 ]
}

inspector_search_prompt() {  # pane name [only]; sets INSPECTOR_SEARCH and INSPECTOR_ONLY
  local line="" msg="" pane="$1" mode="${2:-find}"
  while :; do
    ui_screen "$([ "$mode" = only ] && printf 'SHOW ONLY MATCHES' || printf 'FIND') | $(printf '%s' "$pane" | tr '[:lower:]' '[:upper:]')" "${POD_PICK:-}${KDASH_INSPECT_CONTAINER:+ / $KDASH_INSPECT_CONTAINER}"
    printf ' Extended regular expression. A lowercase pattern ignores case.\n Examples: error   OOMKilled   FailedMount|MountVolume  127.0.0.1  ^2026-10-29T1\n\n'
    printf ' %s\n' "$([ "$mode" = only ] && printf 'The pane will show only the lines that match (press / for context again).' || printf 'Every line stays visible: matches are highlighted, n and N jump between them.')"
    printf ' Empty Enter clears the search; q cancels; Enter applies what you typed.\n Current: %s%s\n%s\n\033[?25h %s ' \
      "${INSPECTOR_SEARCH:-none}" "$([ "${INSPECTOR_ONLY:-0}" = 1 ] && printf ' (only matches)' || printf '')" "$msg" \
      "$([ "$mode" = only ] && printf '&' || printf '/')"
    IFS= read -r line </dev/tty || { printf '\033[?25l'; return 1; }
    printf '\033[?25l'
    case "$line" in q|Q) return 1 ;; esac
    if [ -z "$line" ]; then INSPECTOR_SEARCH=""; INSPECTOR_ONLY=0; return 0; fi
    if inspector_pattern_ok "$line"; then
      INSPECTOR_SEARCH="$line"
      [ "$mode" = only ] && INSPECTOR_ONLY=1 || INSPECTOR_ONLY=0
      return 0
    fi
    msg=' That is not a valid regular expression - try again.'
  done
}

# Cumulative log levels, like a logging framework: ERROR hides the chatter, DEBUG keeps it.
inspector_level_cycle() {
  case "${INSPECTOR_LEVEL_NAME:-all}" in
    all)   INSPECTOR_LEVEL_NAME=ERROR; INSPECTOR_LEVEL_PAT='(^|[^A-Za-z])(ERROR|FATAL|SEVERE|Exception|exception|panic)' ;;
    ERROR) INSPECTOR_LEVEL_NAME=WARN;  INSPECTOR_LEVEL_PAT='(^|[^A-Za-z])(WARN|WARNING|ERROR|FATAL|SEVERE|Exception|exception|panic)' ;;
    WARN)  INSPECTOR_LEVEL_NAME=INFO;  INSPECTOR_LEVEL_PAT='(^|[^A-Za-z])(INFO|WARN|WARNING|ERROR|FATAL|SEVERE)' ;;
    INFO)  INSPECTOR_LEVEL_NAME=DEBUG; INSPECTOR_LEVEL_PAT='(^|[^A-Za-z])(DEBUG|TRACE|INFO|WARN|ERROR|FATAL)' ;;
    *)     INSPECTOR_LEVEL_NAME=all;   INSPECTOR_LEVEL_PAT='' ;;
  esac
}

# Build the view: level filter, then search filter, plus the line numbers of the matches
# inside that view (so n/N can jump) and the counts for the header.
inspector_view_build() { # body view matches [width]
  local body="$1" view="$2" matchf="$3" icase=0 w="${4:-0}"
  [ -z "${INSPECTOR_SEARCH:-}" ] || icase="$(inspector_icase "$INSPECTOR_SEARCH")"
  [ "${INSPECTOR_WRAP:-1}" = 1 ] || w=0
  awk -v pat="${INSPECTOR_SEARCH:-}" -v icase="$icase" -v lvl="${INSPECTOR_LEVEL_PAT:-}" \
      -v only="${INSPECTOR_ONLY:-0}" -v matchf="$matchf" -v metaf="$view.meta" -v w="$w" -v json="${INSPECTOR_JSON:-0}" '
    function hit(line) {
      if (pat == "") return 0
      return (icase ? (tolower(line) ~ tolower(pat)) : (line ~ pat))
    }
    # "TS {json}" -> "TS  LEVEL  message  (logger)": the fields an operator reads first
    function jstr(s, key,   i, c, out, p) {
      p = index(s, "\"" key "\":"); if (!p) return ""
      s = substr(s, p + length(key) + 3); sub(/^[ \t]+/, "", s)
      if (substr(s, 1, 1) != "\"") return ""
      s = substr(s, 2); out = ""
      for (i = 1; i <= length(s); i++) { c = substr(s, i, 1)
        if (c == "\\") { i++; c = substr(s, i, 1); if (c == "n" || c == "t" || c == "r") c = " "; out = out c; continue }
        if (c == "\"") break; out = out c }
      return out }
    function readable(line,   ts, rest, m, lv, sp) {
      sp = index(line, " "); if (sp < 2) return line
      ts = substr(line, 1, sp - 1); rest = substr(line, sp + 1)
      if (substr(rest, 1, 1) != "{") return line
      m = jstr(rest, "message"); if (m == "") m = jstr(rest, "msg"); if (m == "") return line
      lv = jstr(rest, "severity"); if (lv == "") lv = jstr(rest, "level")
      if (ts ~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T/) ts = substr(ts, 6, 5) " " substr(ts, 12, 12)
      return ts "  " sprintf("%-7s", toupper(lv == "" ? "-" : lv)) "  " m }
    { line = (json == "1") ? readable($0) : $0
      if (lvl != "" && line !~ lvl) next
      m = hit(line)
      if (only == "1" && pat != "" && !m) next
      lines++
      if (m) { hits++; print n + 1 > matchf }
      if (w < 20 || length(line) <= w) { n++; print line; next }
      # wrap: the whole line is shown, continuation rows are indented
      n++; print substr(line, 1, w); rest = substr(line, w + 1)
      while (rest != "") { n++; print "    " substr(rest, 1, w - 4); rest = substr(rest, w - 3) } }
    END { printf "%d %d %d\n", n + 0, hits + 0, lines + 0 > metaf }
  ' "$body" > "$view"
  INSPECTOR_VIEW_LINES=0; INSPECTOR_MATCHES=0; INSPECTOR_VIEW_LOGICAL=0
  [ -r "$view.meta" ] && read -r INSPECTOR_VIEW_LINES INSPECTOR_MATCHES INSPECTOR_VIEW_LOGICAL < "$view.meta"
  return 0
}

# Print the visible slice, clipped to the terminal width and with the matches marked.
# Clipping happens before the colour codes are added so the width stays exact.
inspector_show() { # view first last cols color [horizontal offset]
  local icase="" view="$1" hoff="${6:-0}"
  [ -z "${INSPECTOR_SEARCH:-}" ] || icase="$(inspector_icase "$INSPECTOR_SEARCH")"
  awk -v first="$2" -v last="$3" -v w="$4" -v color="$5" -v hoff="$hoff" \
      -v pat="${INSPECTOR_SEARCH:-}" -v icase="$icase" '
    function hl(s, p,   out, rest, hay, at, len) {
      if (p == "" || color != "1") return s
      out = ""; rest = s
      while (rest != "") {
        hay = (icase == "1") ? tolower(rest) : rest
        at = match(hay, p)
        if (at == 0) { out = out rest; break }
        len = RLENGTH
        if (len < 1) { out = out rest; break }
        out = out substr(rest, 1, at - 1) "\033[1;31m" substr(rest, at, len) "\033[0m"
        rest = substr(rest, at + len)
      }
      return out
    }
    NR > last { exit }
    NR >= first && NR <= last { s = substr($0, 1 + hoff); more = (length(s) > w)
      s = substr(s, 1, more ? w - 1 : w); print hl(s, pat) (more ? (color == "1" ? "\033[2m>\033[0m" : ">") : "") }
  ' "$view"
}
# Container inventory with live state: the spec gives name, image and type, the status
# gives readiness, restarts, current state and the last exit. Both are bounded reads and
# both are needed before an operator can decide which container to read logs from.
inspector_container_rows() { # ns pod spec-file status-file -> TYPE NAME READY RST STATE LAST-EXIT IMAGE
  local ns="$1" pod="$2" spec="$3" status="$4"
  "${KC[@]}" get pod "$pod" -n "$ns" -o 'jsonpath={range .spec.containers[*]}app{"\t"}{.name}{"\t"}{.image}{"\n"}{end}{range .spec.initContainers[*]}init{"\t"}{.name}{"\t"}{.image}{"\n"}{end}{range .spec.ephemeralContainers[*]}debug{"\t"}{.name}{"\t"}{.image}{"\n"}{end}' | inspector_clean > "$spec"
  "${KC[@]}" get pod "$pod" -n "$ns" -o 'jsonpath={range .status.containerStatuses[*]}{.name}{"\t"}{.ready}{"\t"}{.restartCount}{"\t"}{.state.waiting.reason}{"\t"}{.state.terminated.reason}{"\t"}{.state.running.startedAt}{"\t"}{.lastState.terminated.reason}{"\t"}{.lastState.terminated.exitCode}{"\n"}{end}{range .status.initContainerStatuses[*]}{.name}{"\t"}{.ready}{"\t"}{.restartCount}{"\t"}{.state.waiting.reason}{"\t"}{.state.terminated.reason}{"\t"}{.state.running.startedAt}{"\t"}{.lastState.terminated.reason}{"\t"}{.lastState.terminated.exitCode}{"\n"}{end}' | inspector_clean > "$status"
  awk -F '\t' -v sf="$status" '
    FILENAME == sf { nm = $1
      st = ($4 != "") ? $4 : (($5 != "") ? $5 : (($6 != "") ? "Running" : "unknown"))
      STATE[nm] = st; READY[nm] = $2; RST[nm] = $3
      LAST[nm] = ($7 != "") ? $7 (($8 != "" && $8 != "0") ? " exit=" $8 : "") : ""
      next }
    NF >= 3 { nm = $2
      printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\n", $1, nm,
        (READY[nm] == "" ? "?" : (READY[nm] == "true" ? "ready" : "not-ready")),
        (RST[nm] == "" ? "?" : RST[nm]),
        (STATE[nm] == "" ? "no status yet" : STATE[nm]),
        (LAST[nm] == "" ? "-" : LAST[nm]),
        ($3 == "" ? "-" : $3) }
  ' "$status" "$spec"
}

# Container picker - same look and keys as the pod list. Columns are sized from the
# data, the highlighted row is a full-width bar, and the title says what Enter does
# (INSPECTOR_PICK_PURPOSE: shell | up | down | inspect). Returns the chosen name in
# INSPECTOR_CONTAINER (plus INSPECTOR_PANE for l/p when inspecting).
inspector_container_picker() { # ns pod dir
  local ns="$1" pod="$2" d="$3" purpose="${INSPECTOR_PICK_PURPOSE:-inspect}" chosen=0 top=0 i n line k
  local -a T N RD RS ST LX IM
  local w_n=9 w_t=4 w_r=9 w_s=5 w_l=9 type name ready rst state last image remembered
  local buf pad len rows banner sel stc pr pst prd prs pnd napp=0 ninit=0 ndbg=0 msg="" nrun=0
  INSPECTOR_CONTAINER=""; INSPECTOR_PANE=""
  if [ -n "${INSPECTOR_PICKER_ROWS:-}" ] && [ -r "$INSPECTOR_PICKER_ROWS" ]; then
    cp -f "$INSPECTOR_PICKER_ROWS" "$d/rows"        # caller already read (and narrowed) the list
  else
    inspector_container_rows "$ns" "$pod" "$d/rows.spec" "$d/rows.status" > "$d/rows" 2> "$d/rows.err" || true
  fi
  remembered="${INSPECTOR_PICK_PRESELECT:-$(inspect_container_for "$ns" "$pod")}"
  while IFS=$'\t' read -r type name ready rst state last image; do
    [ -n "$name" ] || continue
    T+=("$type"); N+=("$name"); RD+=("$ready"); RS+=("$rst"); ST+=("$state"); LX+=("$last"); IM+=("$image")
    [ "${#name}" -le "$w_n" ] || w_n=${#name}; [ "${#type}" -le "$w_t" ] || w_t=${#type}
    [ "${#ready}" -le "$w_r" ] || w_r=${#ready}; [ "${#state}" -le "$w_s" ] || w_s=${#state}; [ "${#last}" -le "$w_l" ] || w_l=${#last}
    case "$type" in init) ninit=$((ninit + 1)) ;; debug) ndbg=$((ndbg + 1)) ;; *) napp=$((napp + 1)) ;; esac
    [ "$name" != "$remembered" ] || chosen=$(( ${#N[@]} - 1 ))
  done < "$d/rows"
  n=${#N[@]}
  declare -F picker_colors >/dev/null && picker_colors
  if [ "$n" = 0 ]; then
    printf '\033[H\033[2J %sNo containers reported for %s/%s.%s\n %s\n\n Press any key to return.' "$PC_BAD" "$ns" "$pod" "$PC_R" "$(head -c 300 "$d/rows.err" 2>/dev/null)"
    IFS= read -rsn1 _ </dev/tty || true
    return 1
  fi
  [ "$w_n" -le 40 ] || w_n=40; [ "$w_s" -le 26 ] || w_s=26; [ "$w_l" -le 22 ] || w_l=22
  # the pod around them, from the current model
  [ ! -r "${MODEL:-}/pods.tsv" ] || pr="$(awk -F'\t' -v ns="$ns" -v p="$pod" '$2 == ns && $3 == p { print $4 "\t" $5 "\t" $6 "\t" $7; exit }' "$MODEL/pods.tsv")"
  [ -z "${pr:-}" ] || IFS=$'\t' read -r pst prd prs pnd <<< "$pr"
  case "$purpose" in
    shell) banner=" ${PC_PTR} Enter opens a SHELL " ;; up) banner=" ${PC_PTR} Enter UPLOADS into the container " ;;
    down)  banner=" ${PC_PTR} Enter DOWNLOADS from the container " ;; *) banner="" ;;
  esac
  # attaching needs a running container: start on one, and say how many there are
  if [ -n "$banner" ]; then
    for ((i = 0; i < n; i++)); do [ "${ST[i]}" != Running ] || nrun=$((nrun + 1)); done
    if [ "${ST[chosen]}" != Running ]; then
      for ((i = 0; i < n; i++)); do [ "${ST[i]}" = Running ] && { chosen=$i; break; }; done
    fi
  fi
  printf '\033[?25l\033[2J'
  # keys typed while the list was loading (a second Enter, or the LF of a CR+LF
  # terminal) must not pick a container the operator has not seen yet
  while IFS= read -rsn1 -t 0.05 _k </dev/tty; do :; done
  while :; do
    picker_size; rows=$((PK_ROWS - 9)); [ "$rows" -ge 3 ] || rows=3
    [ "$chosen" -ge "$top" ] || top=$chosen
    [ "$chosen" -lt $((top + rows)) ] || top=$((chosen - rows + 1))
    # title bar, the pod, the containers
    ui_bar "$PK_COLS" " KDASH ${PC_SEP} SELECT CONTAINER ${PC_SEP} context ${CTX_NAME:-current} ${PC_SEP} namespace $ns " " $n container$([ "$n" = 1 ] || echo s) " "$banner"
    buf=$'\033[H'"${UI_BAR}"$'\033[K\n'
    line=" ${PC_D}pod${PC_R}        ${PC_B}${pod}${PC_R}"
    if [ -n "${pst:-}" ]; then
      case "$pst" in Running|Succeeded|Completed) stc="$PC_OK" ;; *) stc="$PC_BAD" ;; esac
      line+="   ${stc}${PC_DOT}${PC_R} ${stc}${pst}${PC_R}   ${PC_D}ready${PC_R} ${prd}   ${PC_D}restarts${PC_R} ${prs}"
    fi
    pk_fit "$line" "$((PK_COLS - 1))"; buf+="$PK_FIT"$'\033[K\n'
    line=" ${PC_D}node${PC_R}       ${pnd:--}   ${PC_D}containers${PC_R} ${napp} app"
    [ "$ninit" = 0 ] || line+=", ${ninit} init"; [ "$ndbg" = 0 ] || line+=", ${ndbg} debug"
    if [ -n "$banner" ]; then
      line+="   ${PC_D}running${PC_R} ${nrun} of ${n}"
      [ "$nrun" = "$n" ] || line+="   ${PC_WARN}only a running container can be attached to${PC_R}"
    fi
    pk_fit "${line}${PC_R}" "$((PK_COLS - 1))"; buf+="$PK_FIT"$'\033[K\n\033[K\n'
    # header
    printf -v line '   %2s  %-*s  %-*s  %-*s  %3s  %-*s  %-*s  %s' '#' "$w_n" CONTAINER "$w_t" TYPE "$w_r" READY RST "$w_s" STATE "$w_l" 'LAST EXIT' IMAGE
    line="${line:0:$((PK_COLS - 1))}"; printf -v line '%-*s' "$((PK_COLS - 1))" "$line"
    buf+="${PC_HDR}${line}${PC_R}"$'\033[K\n'
    for ((i = 0; i < rows; i++)); do
      k=$((top + i))
      [ "$k" -lt "$n" ] || { buf+=$'\033[K\n'; continue; }
      image="${IM[k]}"
      # without the registry host, as in the shell header: name and tag tell them apart
      case "${image%%/*}" in *.*|*:*|localhost) [ "$image" = "${image%%/*}" ] || image="${image#*/}" ;; esac
      len=$((PK_COLS - 3 - 2 - 2 - w_n - 2 - w_t - 2 - w_r - 2 - 3 - 2 - w_s - 2 - w_l - 2 - 1))
      [ "$len" -ge 8 ] || len=8
      # images: keep the end (name:tag), that is what tells them apart
      [ "${#image}" -le "$len" ] || image="~${image:$(( ${#image} - len + 1 ))}"
      if [ "$k" = "$chosen" ]; then
        printf -v line '%s %2s  %-*s  %-*s  %-*s  %3s  %-*s  %-*s  %s' "$PC_PTR" "$((k + 1))" "$w_n" "${N[k]:0:$w_n}" "$w_t" "${T[k]}" "$w_r" "${RD[k]}" "${RS[k]}" "$w_s" "${ST[k]:0:$w_s}" "$w_l" "${LX[k]:0:$w_l}" "$image"
        line="${line:0:$((PK_COLS - 2))}"; pad=$((PK_COLS - 2 - ${#line})); [ "$pad" -ge 0 ] || pad=0; printf -v pad '%*s' "$pad" ''
        buf+=" ${PC_INV}${PC_B}${line}${pad}${PC_R}"$'\033[K\n'
      elif [ -n "$banner" ] && [ "${ST[k]}" != Running ]; then
        # not attachable: shown dimmed, so it is clear why it cannot be picked
        printf -v line '   %2s  %-*s  %-*s  %-*s  %3s  %-*s  %-*s  %s' "$((k + 1))" "$w_n" "${N[k]:0:$w_n}" "$w_t" "${T[k]}" "$w_r" "${RD[k]}" "${RS[k]}" "$w_s" "${ST[k]:0:$w_s}" "$w_l" "${LX[k]:0:$w_l}" "$image"
        buf+="${PC_D}${line:0:$PK_COLS}${PC_R}"$'\033[K\n'
      else
        case "${ST[k]}" in
          Running) stc="$PC_OK" ;; Completed|"no status yet") stc="$PC_D" ;;
          *CrashLoop*|*Error*|*OOMKilled*|*ImagePull*|*ErrImage*|*ConfigError*) stc="$PC_BAD" ;; *) stc="$PC_WARN" ;;
        esac
        local row_=""
        printf -v line '   %2s  %s%-*s%s  %s%-*s%s  ' "$((k + 1))" "$PC_B" "$w_n" "${N[k]:0:$w_n}" "$PC_R" "$PC_D" "$w_t" "${T[k]}" "$PC_R"
        row_+="$line"
        [ "${RD[k]}" = ready ] && row_+="$PC_OK" || row_+="$PC_WARN"
        printf -v line '%-*s%s  ' "$w_r" "${RD[k]}" "$PC_R"; row_+="$line"
        [ "${RS[k]}" = 0 ] || [ "${RS[k]}" = "?" ] || row_+="$PC_WARN"
        printf -v line '%3s%s  %s%-*s%s  ' "${RS[k]}" "$PC_R" "$stc" "$w_s" "${ST[k]:0:$w_s}" "$PC_R"; row_+="$line"
        [ "${LX[k]}" = - ] && row_+="$PC_D" || row_+="$PC_BAD"
        printf -v line '%-*s%s  %s' "$w_l" "${LX[k]:0:$w_l}" "$PC_R" "$image"; row_+="$line"
        pk_fit "$row_" "$((PK_COLS - 1))"; buf+="$PK_FIT"$'\033[K\n'
      fi
    done
    # status rule: a message when there is one, otherwise where the cursor is
    if [ -n "$msg" ]; then ui_vlen "$msg"; [ "$UI_VL" -le $((PK_COLS - 8)) ] || { msg="${msg:0:$((PK_COLS - 10))}~"; ui_vlen "$msg"; }
      ui_rule "$((PK_COLS - 1))" "${PC_WARN}${msg}${PC_R}" "$UI_VL" "" 0
    else ui_vlen "$((chosen + 1)) / $n"; ui_rule "$((PK_COLS - 1))" "${PC_B}$((chosen + 1))${PC_R}${PC_D} / ${n}${PC_R}" "$UI_VL" "${PC_D}audited${PC_R}" 7; fi
    buf+="$UI_RULE"$'\033[K\n'
    local f1 f2 act
    if [ -n "$banner" ]; then
      case "$purpose" in shell) act="open shell" ;; up) act="upload here" ;; *) act="download from here" ;; esac
      ui_keys "$((PK_COLS - 1))" Enter "$act" 1-9 pick q back Q "quit kdash" j/k move; f1="$UI_KEYS"
      ui_keys "$((PK_COLS - 1))" exit "in the shell returns to kdash" kdswitch "related pods" kdquit "leaves kdash"; f2="$UI_KEYS"
      [ "$purpose" = shell ] || { ui_keys "$((PK_COLS - 1))" next "browse the container, pick files, review, confirm" audited "every transfer is logged"; f2="$UI_KEYS"; }
    else
      ui_keys "$((PK_COLS - 1))" Enter inspect l logs p "previous logs" 1-9 open q back Q "quit kdash" j/k move; f1="$UI_KEYS"
      ui_keys "$((PK_COLS - 1))" all "containers of the pod, including init and debug"; f2="$UI_KEYS"
    fi
    buf+="$f1"$'\033[K\n'"$f2"$'\033[K'
    printf '%s\033[J' "$buf"
    picker_key 60 || continue
    msg=""
    # a digit picks that row; Enter / i the highlighted one
    case "$PK_KEY_IN" in [1-9]) i=$((PK_KEY_IN - 1)); [ "$i" -lt "$n" ] || continue; chosen=$i; PK_KEY_IN='<ENTER>' ;; esac
    if [ -n "$banner" ] && { [ "$PK_KEY_IN" = '<ENTER>' ] || [ "$PK_KEY_IN" = i ]; } && [ "${ST[chosen]}" != Running ]; then
      msg="${N[chosen]} is ${ST[chosen]} - kubectl exec / cp need a running container$([ "${ST[chosen]}" = "no status yet" ] || printf '; its logs show why (q, then l or p)')"
      continue
    fi
    case "$PK_KEY_IN" in
      q|'<ESC>') return 1 ;;
      Q) kdash_quit "container list" ;;
      j|'<DN>') chosen=$(((chosen + 1) % n)) ;;
      k|'<UP>') chosen=$(((chosen + n - 1) % n)) ;;
      g|'<HOME>') chosen=0 ;; G|'<END>') chosen=$((n - 1)) ;;
      l|p) [ -z "$banner" ] || continue
           INSPECTOR_CONTAINER="${N[chosen]}"
           [ "$PK_KEY_IN" = l ] && INSPECTOR_PANE=current || INSPECTOR_PANE=previous
           return 0 ;;
      '<ENTER>'|i) INSPECTOR_CONTAINER="${N[chosen]}"; return 0 ;;
    esac
  done
}

inspector_safe_name() {
  case "$1" in
    ''|*[!A-Za-z0-9._-]*) printf '%s' "$1" | LC_ALL=C tr -c 'A-Za-z0-9._-' '_' ;;
    *) printf '%s' "$1" ;;
  esac
}

inspector_report_dir() { printf '%s' "${KDASH_REPORT_DIR:-${HOME:-/tmp}/kdash_reports}"; }

# Export exactly what is on screen (the filtered view) so it can go into a ticket.
# This is always explicit: the automatic report bundle still never contains logs.
inspector_export() { # view-file ns pod container pane [total-lines] [matching-lines] -> writes the file and prints its path
  local view="$1" ns="$2" pod="$3" cont="$4" pane="$5" tot="${6:-0}" hit="${7:-0}" dir="" file=""
  dir="$(inspector_report_dir)/inspector"
  (umask 077; mkdir -p "$dir") || return 1
  file="$dir/kdash_inspect_$(inspector_safe_name "$ns")_$(inspector_safe_name "$pod")_$(inspector_safe_name "${cont:-pod}")_$(inspector_safe_name "$pane")_$(date +%Y%m%d_%H%M%S).txt"
  {
    printf '# kdash inspector export\n'
    printf '# context: %s | namespace: %s | pod: %s | container: %s | pane: %s\n' "${CTX_NAME:-current}" "$ns" "$pod" "${cont:-(none)}" "$pane"
    printf '# generated: %s by %s on %s\n' "$(date -Is 2>/dev/null || date)" "${USER:-unknown}" "$(hostname 2>/dev/null || printf host)"
    printf '# search: %s | level: %s | lines exported: %s of %s | matching lines: %s\n' \
      "${INSPECTOR_SEARCH:-none}" "${INSPECTOR_LEVEL_NAME:-all}" "${INSPECTOR_VIEW_LINES:-0}" "$tot" "$hit"
    printf '# NOTE: describe output and logs can contain sensitive values (tokens, addresses,\n#       payloads). Review before sharing outside your team.\n\n'
    cat "$view"
  } > "$file" || return 1
  printf '%s' "$file"
}

inspector_help() {
  ui_screen "POD DETAIL | KEYS" "any key returns"
  printf ' FIND                          PANES                       NAVIGATE\n'
  printf '  /  find in this pane         s  summary                  j k arrows  line\n'
  printf '  &  show only matches         d  describe                 space b     page\n'
  printf '  n N  next / previous match   e  events                   PgUp PgDn   page\n'
  printf '  L  log level: all, ERROR,    !  why (event hypotheses)    g G Home End  top/bottom\n'
  printf '     WARN, INFO, DEBUG         l  current logs             c  choose container\n'
  printf '  f  follow logs               p  previous logs            r  reload now\n'
  printf '  w  export what you see       q Esc  back                ?  this help\n\n'
  printf ' LONG AND MANY LINES\n'
  printf '  W  wrap on/off: on (default) shows every line in full; off cuts at the edge, <- -> pan\n'
  printf '  J  readable JSON: time, level and message of JSON log lines; J again shows them raw\n'
  printf '  +  read 4x more lines        A  read every line the kubelet keeps (KDASH_LOG_MAX_BYTES)\n'
  printf '     the rule shows what was read: "5000 lines, 3.1 MiB - complete" or "- newest 5000 only"\n\n'
  printf ' S  shell in the container    U  upload a file             D  download a file\n'
  printf ' S/U/D need --allow-interactive: they run in your name and are audited writes.\n'
  printf ' / keeps the context around every match and highlights it; & hides everything else.\n'
  printf ' A lowercase pattern ignores case: /error finds ERROR and error.\n'
  printf ' n and N wrap around and put the match at the top of the pane.\n'
  printf ' c lists every container with readiness, restarts, state and last exit: pick one\n'
  printf ' and l/p read that container. Search and level stay active across panes.\n'
  printf ' w writes the filtered pane to %s/inspector/ (review it before sharing).\n\n' "$(inspector_report_dir)"
  printf '\033[?25h any key returns'
  IFS= read -rsn1 _ </dev/tty || true
}

inspector_pane_title() { # pane -> title shown in the bar
  case "$1" in
    summary) printf SUMMARY ;; describe) printf DESCRIBE ;; events) printf EVENTS ;; explain) printf 'WHY (EVENT HYPOTHESES)' ;;
    current) printf 'LOGS' ;; previous) printf 'PREVIOUS LOGS' ;; *) printf '%s' "$1" | tr '[:lower:]' '[:upper:]' ;;
  esac
}
inspector_detail() { # nested UI; q returns to the picker, keeping the identity
  local ns="$1" pod="$2" d="$3" pane="${INSPECTOR_PANE:-summary}" loaded="" reload=1 viewdirty=1 rows_stale=1
  local body="$3/body" view="$3/view" matchf="$3/matches"
  local offset=0 count=0 total=0 matches=0 msg="" rows pid rc keep_offset=0 follow=0 atbottom=0 vcols=0 hoff=0
  local container file="" target=0 idx=0 cline="" pinfo=""
  container="$(inspect_container_for "$ns" "$pod")"     # never a container of another pod
  local INSPECTOR_REFRESH_EVENTS=0
  INSPECTOR_PANE=""
  inspector_limits          # tail/bytes/follow defaults must exist in this shell too
  while :; do
    inspector_size; rows=$((INSPECTOR_ROWS - 8))      # 4 header rows, 3 key rows, 1 message row
    if [ "$loaded" != "$pane" ] || [ "$reload" = 1 ]; then
      picker_colors
      ui_bar "$INSPECTOR_COLS" " KDASH ${PC_SEP} POD DETAIL ${PC_SEP} context ${CTX_NAME:-current} ${PC_SEP} namespace $ns " " $(inspector_pane_title "$pane") "
      printf '\033[H\033[2J%s\n %spod%s        %s%s%s\n\n %sreading %s ...  q / Esc cancels%s\n' "$UI_BAR" "$PC_D" "$PC_R" "$PC_B" "$pod" "$PC_R" "$PC_D" "$pane" "$PC_R"
      # Keep navigation available during a slow read. KC supplies request-timeout.
      (
        trap 'for inspector_child in $(jobs -pr); do kill "$inspector_child" 2>/dev/null || true; done; exit 130' TERM INT
        if [ "$rows_stale" = 1 ]; then
          inspector_container_rows "$ns" "$pod" "$d/rows.spec" "$d/rows.status" > "$d/rows" 2> "$d/rows.err" || true
        fi
        if { [ "$pane" = events ] || [ "$pane" = explain ]; } && declare -F events_collect >/dev/null; then
          if [ ! -f "${TOOLKIT_DIR:-}/events.status" ] || [ "$INSPECTOR_REFRESH_EVENTS" = 1 ]; then events_collect; fi
        fi
        case "$pane" in
          summary) inspector_summary "$ns" "$pod" "$body" ;;
          describe) inspector_query "$body" describe pod "$pod" -n "$ns" ;;
          events) inspector_events "$ns" "$pod" "$body" ;;
          explain) inspector_explain "$ns" "$pod" "$body" ;;
          current|previous)
            if [ -z "$container" ]; then container="$(awk -F '\t' 'NF >= 2 {print $2; exit}' "$d/rows" 2>/dev/null)"; fi
            inspector_logs "$ns" "$pod" "$container" "$pane" "$body" ;;
        esac
      ) & pid=$!
      while kill -0 "$pid" 2>/dev/null; do
        INSPECTOR_KEY=""; IFS= read -rsn1 -t 0.1 INSPECTOR_KEY </dev/tty || true
        case "$INSPECTOR_KEY" in q|b|$'\033')
          kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true
          return 0 ;;
        esac
      done
      wait "$pid" 2>/dev/null || true
      INSPECTOR_REFRESH_EVENTS=0; rows_stale=0; reload=0; loaded="$pane"; viewdirty=1
      [ "$pane" != summary ] || rows_stale=1      # the summary pane shows per-container state
      if [ -z "$container" ]; then container="$(awk -F '\t' 'NF >= 2 {print $2; exit}' "$d/rows" 2>/dev/null)"; fi
      [ "$keep_offset" = 1 ] || offset=0
      keep_offset=0
      declare -F audit >/dev/null && audit INSPECT "namespace=$ns pod=$pod pane=$pane container=${container:--} search=${INSPECTOR_SEARCH:-none} level=${INSPECTOR_LEVEL_NAME:-all}"
    fi
    [ "${vcols:-0}" = "$INSPECTOR_COLS" ] || viewdirty=1
    if [ "$viewdirty" = 1 ]; then
      inspector_view_build "$body" "$view" "$matchf" "$((INSPECTOR_COLS - 1))"
      viewdirty=0; count="$INSPECTOR_VIEW_LINES"; matches="$INSPECTOR_MATCHES"; vcols="$INSPECTOR_COLS"
      total="$(awk 'END { print NR }' "$body" 2>/dev/null || printf 0)"
      # A new search starts at its first match, which is what an operator expects.
      if [ -n "${INSPECTOR_SEARCH:-}" ] && [ "$matches" -gt 0 ]; then
        cur=1; offset=$(($(awk 'NR == 1 {print $1}' "$matchf") - 1)); msg="match 1/$matches"
      fi
    fi
    [ "$offset" -lt 0 ] && offset=0
    [ "$offset" -le "$((count > rows ? count - rows : 0))" ] || offset=$((count > rows ? count - rows : 0))
    picker_colors
    # title bar, pod, container, then a rule that says where in the pane we are
    local c_n="" c_rd="" c_rs="" c_st="" c_lx="" c_im="" stc hdr
    IFS=$'\t' read -r _ c_n c_rd c_rs c_st c_lx c_im < <(awk -F '\t' -v want="$container" '$2 == want { print; exit }' "$d/rows" 2>/dev/null) || true
    ui_bar "$INSPECTOR_COLS" " KDASH ${PC_SEP} POD DETAIL ${PC_SEP} context ${CTX_NAME:-current} ${PC_SEP} namespace $ns " " $(inspector_pane_title "$pane") "
    hdr="${UI_BAR}"$'\033[K\n'
    pk_fit " ${PC_D}pod${PC_R}        ${PC_B}${pod}${PC_R}" "$((INSPECTOR_COLS - 1))"; hdr+="$PK_FIT"$'\033[K\n'
    if [ -n "$c_n" ]; then
      case "$c_st" in Running) stc="$PC_OK" ;; Completed) stc="$PC_D" ;; *CrashLoop*|*Error*|*OOMKilled*|*ImagePull*|*ErrImage*) stc="$PC_BAD" ;; *) stc="$PC_WARN" ;; esac
      case "${c_im%%/*}" in *.*|*:*|localhost) [ "$c_im" = "${c_im%%/*}" ] || c_im="${c_im#*/}" ;; esac
      cline=" ${PC_D}container${PC_R}  ${PC_B}${c_n}${PC_R}   ${stc}${PC_DOT} ${c_st}${PC_R}   ${PC_D}${c_rd}${PC_R}   ${PC_D}restarts${PC_R} ${c_rs}"
      [ "$c_lx" = - ] || [ -z "$c_lx" ] || cline+="   ${PC_D}last exit${PC_R} ${PC_BAD}${c_lx}${PC_R}"
      cline+="   ${PC_D}${c_im}${PC_R}"
    else cline=" ${PC_D}container${PC_R}  ${container:-${PC_D}none reported${PC_R}}"; fi
    pk_fit "$cline" "$((INSPECTOR_COLS - 1))"; hdr+="$PK_FIT"$'\033[K\n'
    # where we are (screen rows), how many lines, what was read and how lines are shown
    pinfo="rows $((count ? offset + 1 : 0))-$((offset + rows < count ? offset + rows : count)) / $count"
    if [ "${INSPECTOR_VIEW_LOGICAL:-$total}" != "$total" ]; then pinfo="$pinfo ${PC_MID} ${INSPECTOR_VIEW_LOGICAL} of $total lines"
    else pinfo="$pinfo ${PC_MID} $total lines"; fi
    [ "${INSPECTOR_WRAP:-1}" = 1 ] && pinfo="$pinfo ${PC_MID} wrap" || pinfo="$pinfo ${PC_MID} no wrap$([ "$hoff" = 0 ] || printf ' +%s' "$hoff")"
    [ "${INSPECTOR_JSON:-0}" != 1 ] || pinfo="$pinfo ${PC_MID} readable JSON"
    [ -z "${INSPECTOR_SEARCH:-}" ] || {
      if [ "${INSPECTOR_ONLY:-0}" = 1 ]; then pinfo="$pinfo ${PC_MID} only /$INSPECTOR_SEARCH ($matches)"
      else pinfo="$pinfo ${PC_MID} /$INSPECTOR_SEARCH ($matches matching)"; fi; }
    case "$pane" in current|previous) [ ! -s "$body.info" ] || pinfo="$pinfo ${PC_MID} $(cat "$body.info")" ;; esac
    case "${INSPECTOR_LEVEL_NAME:-all}" in all) ;; *) pinfo="$pinfo ${PC_MID} level $INSPECTOR_LEVEL_NAME" ;; esac
    ui_vlen "$pinfo"; [ "$UI_VL" -le $((INSPECTOR_COLS - 20)) ] || { pinfo="${pinfo:0:$((INSPECTOR_COLS - 22))}~"; ui_vlen "$pinfo"; }
    local pw=$UI_VL rinfo="audited"; [ "$follow" = 1 ] && rinfo="follow ${INSPECTOR_FOLLOW_SECS:-5}s"
    ui_rule "$((INSPECTOR_COLS - 1))" "${PC_B}${pinfo}${PC_R}" "$pw" "${PC_D}${rinfo}${PC_R}" "${#rinfo}"
    printf '\033[H\033[2J%s%s\033[K\n' "$hdr" "$UI_RULE"
    inspector_show "$view" "$((offset + 1))" "$((offset + rows))" "$INSPECTOR_COLS" "${COLOR:-1}" "$([ "${INSPECTOR_WRAP:-1}" = 1 ] && echo 0 || echo "$hoff")"
    ui_keys "$((INSPECTOR_COLS - 1))" s summary d describe e events "!" why l logs p "previous logs" c container S shell U upload D download
    printf '\033[%s;1H%s\033[J' "$((INSPECTOR_ROWS - 3))" "$UI_KEYS"
    ui_keys "$((INSPECTOR_COLS - 1))" W "wrap $([ "${INSPECTOR_WRAP:-1}" = 1 ] && echo on || echo off)" J "readable JSON $([ "${INSPECTOR_JSON:-0}" = 1 ] && echo on || echo off)" \
      "+" "4x more lines" A "all lines" "<- ->" "pan (wrap off)" f "follow $([ "$follow" = 1 ] && printf on || printf off)" L "level ${INSPECTOR_LEVEL_NAME:-all}" w "export the view"
    printf '\033[%s;1H%s\033[K' "$((INSPECTOR_ROWS - 2))" "$UI_KEYS"
    ui_keys "$((INSPECTOR_COLS - 1))" q back Q quit / find "&" "only matches" "n/N" "next / prev" "j/k Space/b g/G" scroll r reload "?" keys
    printf '\033[%s;1H%s\033[K' "$((INSPECTOR_ROWS - 1))" "$UI_KEYS"
    if [ -n "$msg" ]; then
      printf '\033[%s;1H\033[1;33m %s\033[0m\033[K' "$INSPECTOR_ROWS" "${msg:0:$((INSPECTOR_COLS - 2))}"
    else
      printf '\033[%s;1H\033[K' "$INSPECTOR_ROWS"
    fi
    if [ "$follow" = 1 ] && { [ "$pane" = current ] || [ "$pane" = previous ]; }; then
      [ "$offset" -lt "$((count > rows ? count - rows : 0))" ] && atbottom=0 || atbottom=1
      if ! inspector_key "${INSPECTOR_FOLLOW_SECS:-5}"; then
        # No key inside the follow interval: refresh the log pane where the operator is.
        reload=1; keep_offset=1
        [ "$atbottom" = 0 ] || offset=999999
        msg=''
        continue
      fi
    elif inspector_key; then :; else return 0; fi
    msg=""
    case "$INSPECTOR_KEY" in
      q|$'\033') return 0 ;;
      Q) kdash_quit inspector ;;
      s) pane=summary ;; d) pane=describe ;; e) pane=events ;; '!') pane=explain ;; l) pane=current ;; p) pane=previous ;;
      # Interactive attachments (opt-in): the pod and container you are looking at.
      S|U|D)
         if ! interactive_enabled; then msg="$(interactive_hint)"
         else
           case "$INSPECTOR_KEY" in S) a_=shell; e_=EXEC ;; U) a_=up; e_=CP_UP ;; *) a_=down; e_=CP_DOWN ;; esac
           interactive_attach "$a_" "$ns" "$pod" "$d" "$container"; msg="$a_ in ${INTERACTIVE_CONTAINER:-?} ended rc=$? (logged as $e_)"
           [ -z "${KDASH_SWITCH:-}" ] || return 0             # kdswitch: back to the pod list
           [ -z "${INTERACTIVE_WHY:-}" ] || msg="$INTERACTIVE_WHY"
           rows_stale=1
         fi ;;
      j) offset=$((offset + 1)) ;; k) offset=$((offset - 1)) ;; ' ') offset=$((offset + rows)) ;; b) offset=$((offset - rows)) ;;
      g) offset=0 ;; G) offset=999999 ;;
      '/') if inspector_search_prompt "$pane" find; then viewdirty=1; fi ;;
      '&') if inspector_search_prompt "$pane" only; then viewdirty=1; fi ;;
      n|N) if [ "$matches" -gt 0 ] && [ -s "$matchf" ]; then
             read -r target idx <<< "$(awk -v cur="$offset" -v back="$([ "$INSPECTOR_KEY" = N ] && printf 1 || printf 0)" '
               { L[NR] = $1 }
               END { if (NR == 0) { print "0 0"; exit }
                 if (!back) { for (k = 1; k <= NR; k++) if (L[k] > cur + 1) { print L[k], k; exit }
                              print L[1], 1; exit }
                 for (k = NR; k >= 1; k--) if (L[k] < cur + 1) { print L[k], k; exit }
                 print L[NR], NR }' "$matchf")"
             if [ "${target:-0}" -gt 0 ]; then offset=$((target - 1)); msg="match $idx/$matches"; fi
           else msg="no match for /${INSPECTOR_SEARCH:-} (press / to search)"; fi ;;
      L) inspector_level_cycle; viewdirty=1; offset=0; msg="log level: $INSPECTOR_LEVEL_NAME" ;;
      W) if [ "${INSPECTOR_WRAP:-1}" = 1 ]; then INSPECTOR_WRAP=0; msg="wrap off - <- and -> pan sideways, > marks a longer line"
         else INSPECTOR_WRAP=1; hoff=0; msg="wrap on - every line is shown in full"; fi; viewdirty=1 ;;
      J) if [ "${INSPECTOR_JSON:-0}" = 1 ]; then INSPECTOR_JSON=0; msg="raw lines"; else INSPECTOR_JSON=1; msg="readable JSON: time, level and message of JSON log lines (J for raw)"; fi; viewdirty=1; offset=0 ;;
      '<RIGHT>') if [ "${INSPECTOR_WRAP:-1}" = 1 ]; then msg="lines wrap - W turns wrap off to pan sideways"; else hoff=$((hoff + INSPECTOR_COLS / 2)); fi ;;
      '<LEFT>') if [ "${INSPECTOR_WRAP:-1}" = 1 ]; then msg="lines wrap - W turns wrap off to pan sideways"; else hoff=$((hoff - INSPECTOR_COLS / 2)); [ "$hoff" -ge 0 ] || hoff=0; fi ;;
      '+') case "$pane" in current|previous)
             inspector_limits
             if [ "$INSPECTOR_TAIL" = -1 ]; then msg="already reading every line"
             else INSPECTOR_TAIL_SET=$((INSPECTOR_TAIL * 4)); [ "$INSPECTOR_TAIL_SET" -le 1000000 ] || INSPECTOR_TAIL_SET=1000000
                  INSPECTOR_BYTES_SET=$((INSPECTOR_BYTES * 4)); [ "$INSPECTOR_BYTES_SET" -le 268435456 ] || INSPECTOR_BYTES_SET=268435456
                  reload=1; msg="reading the newest $INSPECTOR_TAIL_SET lines"; fi ;;
           *) msg="+ applies to the log panes (l, p)" ;; esac ;;
      A) case "$pane" in current|previous)
             INSPECTOR_TAIL_SET=-1; INSPECTOR_BYTES_SET="${KDASH_LOG_MAX_BYTES:-268435456}"; reload=1; msg="reading every line the kubelet keeps (up to $(xfer_hsize "$INSPECTOR_BYTES_SET"))" ;;
           *) msg="A applies to the log panes (l, p)" ;; esac ;;
      f) case "$pane" in
           current|previous) follow=$((1 - follow)); reload=1; keep_offset=1; viewdirty=1
             [ "$follow" = 1 ] && msg="follow every ${INSPECTOR_FOLLOW_SECS}s - press f to stop" || msg='follow off' ;;
           *) msg='follow applies to the log panes (l current, p previous)' ;;
         esac ;;
      w) # the export has whole lines (not the wrapped screen rows)
         inspector_view_build "$body" "$view.x" "$matchf.x" 0; viewdirty=1
         local xn="$INSPECTOR_VIEW_LINES"
         if file="$(inspector_export "$view.x" "$ns" "$pod" "$container" "$pane" "$total" "$matches")"; then
           msg="exported $xn complete line(s) to $file"
           declare -F audit >/dev/null && audit INSPECT_EXPORT "namespace=$ns pod=$pod container=${container:--} pane=$pane lines=$xn search=${INSPECTOR_SEARCH:-none} level=${INSPECTOR_LEVEL_NAME:-all} file=$file"
         else msg='export failed: is the report directory writable?'; fi ;;
      '?') inspector_help ;;
      r) if [ "$pane" = events ] || [ "$pane" = explain ]; then
           # Collection runs in the same cancellable worker on the next pass.
           rm -f -- "$d/events-refreshed"; INSPECTOR_REFRESH_EVENTS=1
         fi
         rows_stale=1; reload=1; keep_offset=1; msg='reloading' ;;
      c) if inspector_container_picker "$ns" "$pod" "$d"; then
           container="$INSPECTOR_CONTAINER"; KDASH_INSPECT_CONTAINER="$container"; KDASH_INSPECT_CONTAINER_POD="$ns/$pod"
           if [ -n "${INSPECTOR_PANE:-}" ]; then pane="$INSPECTOR_PANE"; INSPECTOR_PANE=""; fi
           rows_stale=1; reload=1; viewdirty=1; msg="container: $container"
           declare -F audit >/dev/null && audit INSPECT_CONTAINER "namespace=$ns pod=$pod container=$container pane=$pane"
         else msg='container selection cancelled'; fi ;;
    esac
  done
}

#---- pod picker -------------------------------------------------------------------
# Built for 100s of pods over a slow SSH session:
#   * rows are formatted once per data refresh by one awk pass (aligned columns,
#     colour class, search text); a keypress only redraws from memory - no forks,
#     no screen clear (cursor home + clear-to-end-of-line), so nothing flickers
#   * type-to-filter (/), "needs attention" toggle (u), sort (s), number jump (12),
#     page / home / end keys, and live refresh every poll while the picker is open
#   * actions straight from the list: Enter summary, l logs, p previous logs,
#     d describe, e events, w why, c container, S shell, U upload, D download
PICKER_ROWS_AWK='
BEGIN { FS = OFS = "\t" }
FNR == 1 { next }
{ n++; K[n] = $1; NS[n] = $2; P[n] = $3; ST[n] = $4; RD[n] = $5; RST[n] = $6 + 0; ND[n] = $7
  CU[n] = $14; CL[n] = $16; MU[n] = $17; ML[n] = $19; LT[n] = $22
  if (length(P[n]) > pw) pw = length(P[n]); if (length(NS[n]) > nw) nw = length(NS[n]); if (length(ST[n]) > sw) sw = length(ST[n]) }
function cls(i,   r) {
  split(RD[i], r, "/")
  if (ST[i] ~ /Succeeded|Completed/) return "done"
  if (ST[i] ~ /CrashLoop|Error|Failed|Evicted|OOMKilled|ImagePull|ErrImage|ConfigError|Unknown|NotReady|Invalid/) return "bad"
  if (ST[i] ~ /Pending|ContainerCreating|Terminating|Init|PodInitializing/) return "warn"
  if (ST[i] == "Running" && r[1] + 0 < r[2] + 0) return "bad"
  return "ok"
}
function mem(v) { if (v == "-" || v == "") return "-"; v += 0; return (v >= 10240) ? sprintf("%.1fGi", v / 1024) : sprintf("%dMi", v + 0.5) }
function cpu(v) { if (v == "-" || v == "") return "-"; v += 0; return (v >= 10000) ? sprintf("%.1fc", v / 1000) : sprintf("%dm", v + 0.5) }
function clip(s, w) { return (length(s) <= w) ? s : substr(s, 1, w - 1) "~" }
# pod names: keep the start (component) and the end (hash / ordinal) - the end is what
# tells sibling pods apart, so never cut it off
function mclip(s, w,   h) { if (length(s) <= w) return s; h = int((w - 1) / 2); return substr(s, 1, w - 1 - h) "~" substr(s, length(s) - h + 1) }
END {
  if (sw > 18) sw = 18; if (sw < 7) sw = 7; if (nw > 24) nw = 24
  # pod column: as wide as the longest name the terminal can afford
  fixed = 3 + (allns ? nw + 2 : 0) + sw + 2 + 5 + 1 + 4 + 2 + 6 + 1 + 7 + 1 + 5 + 2 + 14
  if (pw > cols - fixed) pw = cols - fixed; if (pw < 20) pw = 20
  printf "%s%-" pw "s  %-" sw "s  %5s %4s  %6s %7s %5s  %s\n", (allns ? sprintf("%-" nw "s  ", "NAMESPACE") : ""), "POD", "STATUS", "READY", "RST", "CPU", "MEM", "%LIM", "NODE" > hdrf
  rank["bad"] = 0; rank["warn"] = 1; rank["ok"] = 2; rank["done"] = 3
  for (i = 1; i <= n; i++) {
    c = cls(i); att = (c == "bad" || c == "warn" || (RST[i] > 0 && c != "done")) ? 1 : 0
    CNT[ST[i]]++; SEV[ST[i]] = rank[c]
    pl = (MU[i] != "-" && ML[i] != "-" && ML[i] + 0 > 0) ? MU[i] * 100 / ML[i] : -1
    if      (mode == "status")   sk = rank[c] " " NS[i] "/" P[i]
    else if (mode == "restarts") sk = sprintf("%012d", RST[i])
    else if (mode == "cpu")      sk = sprintf("%012d", (CU[i] == "-") ? -1 : CU[i])
    else if (mode == "mem")      sk = sprintf("%012d", (MU[i] == "-") ? -1 : MU[i])
    else if (mode == "mempct")   sk = sprintf("%012d", pl * 100)
    else                         sk = NS[i] "/" P[i]
    a = (allns ? sprintf("%-" nw "s  ", clip(NS[i], nw)) : "") sprintf("%-" pw "s  ", mclip(P[i], pw))
    b = sprintf("%-" sw "s  ", clip(ST[i], sw))
    r1 = sprintf("%5s ", RD[i]); r2 = sprintf("%4s  ", RST[i]); r3 = sprintf("%6s %7s ", cpu(CU[i]), mem(MU[i]))
    r4 = sprintf("%5s  ", (pl < 0 ? "-" : sprintf("%.0f%%", pl))); r5 = ND[i] (LT[i] != "-" && LT[i] != "" ? "  last-exit " LT[i] : "")
    s = tolower(NS[i] " " P[i] " " ST[i] " " ND[i] " " LT[i] " " c (att ? " attention" : ""))
    print sk, NS[i], P[i], c, att, (RST[i] > 0 ? 1 : 0), (pl >= 90 ? 2 : (pl >= 75 ? 1 : 0)), s, a, b, r1, r2, r3, r4, r5
  }
  for (k in CNT) printf "%d\t%d\t%s\n", SEV[k], CNT[k], k > sumf
}'

picker_colors() {
  if [ "${COLOR:-1}" = 1 ]; then
    PC_R=$'\033[0m'; PC_B=$'\033[1m'; PC_D=$'\033[90m'; PC_INV=$'\033[7m'; PC_OK=$'\033[32m'; PC_BAD=$'\033[1;31m'
    PC_WARN=$'\033[35m'; PC_INFO=$'\033[1;94m'; PC_TITLE=$'\033[7;1m'; PC_ACT=$'\033[1;97;41m'
  else
    PC_R=""; PC_B=""; PC_D=""; PC_INV=""; PC_OK=""; PC_BAD=""; PC_WARN=""; PC_INFO=""; PC_TITLE=""; PC_ACT=""
  fi
  if [ "${BARCHR:-unicode}" = ascii ]; then PC_PTR=">"; PC_UP="^"; PC_DN="v"; PC_CARET="_"; PC_SEP="|"; PC_HR="-"; PC_DOT="*"; PC_MID="-"
  else PC_PTR=$'\342\226\266'; PC_UP=$'\342\206\221'; PC_DN=$'\342\206\223'; PC_CARET=$'\342\226\217'
       PC_SEP=$'\342\224\202'; PC_HR=$'\342\224\200'; PC_DOT=$'\342\227\217'; PC_MID=$'\302\267'; fi
  # header row of a table: bold + underlined (reads on light and dark backgrounds)
  if [ "${COLOR:-1}" = 1 ]; then PC_HDR=$'\033[1;4m'; else PC_HDR=""; fi
  # a glyph is 1 character in a UTF-8 locale but 3 bytes in the C locale
  UI_BYTES=0; [ "${#PC_SEP}" -le 1 ] || UI_BYTES=1
}

# ---- shared screen chrome: title bar, rules and key hints look the same on every
# kdash screen (pod picker, container list, container shell header)
ui_vlen() { # text -> UI_VL (visible characters; no escape codes in the text)
  local t="$1"
  [ "${UI_BYTES:-0}" = 0 ] || t="${t//[$'\200'-$'\277']/}"
  UI_VL=${#t}
}
# full-width reverse title bar: left text, an optional action chip, right text;
# the right part is dropped, then the left cut, when the window is too narrow
ui_bar() { # width left right [chip] -> UI_BAR
  local w="$1" l="$2" r="$3" chip="${4:-}" lv rv cv gap sp
  ui_vlen "$l"; lv=$UI_VL; ui_vlen "$r"; rv=$UI_VL; cv=0
  [ -z "$chip" ] || { ui_vlen "$chip"; cv=$UI_VL; }
  [ $((lv + cv + rv)) -le "$w" ] || { r=""; rv=0; }
  [ $((lv + cv)) -le "$w" ] || { chip=""; cv=0; }
  if [ "$lv" -gt "$w" ]; then l="${l:0:$((w - 1))}~"; ui_vlen "$l"; lv=$UI_VL; fi
  gap=$((w - lv - cv - rv)); [ "$gap" -ge 0 ] || gap=0; printf -v sp '%*s' "$gap" ''
  UI_BAR="${PC_TITLE}${l}${PC_R}"
  [ -z "$chip" ] || UI_BAR+="${PC_ACT}${chip}${PC_R}"
  UI_BAR+="${PC_TITLE}${sp}${r}${PC_R}"
}
# "colour" "text" pairs -> UI_SEG (coloured) + UI_SEGW (visible width); a pair that
# does not fit in the width is left out with everything after it
ui_seg() { # width pairs...
  local w="$1" col txt; shift
  UI_SEG=""; UI_SEGW=0
  while [ $# -ge 2 ]; do
    col=$1; txt=$2; shift 2; ui_vlen "$txt"
    [ $((UI_SEGW + UI_VL)) -le "$w" ] || break
    UI_SEG+="${col}${txt}${PC_R}"; UI_SEGW=$((UI_SEGW + UI_VL))
  done
}
# a thin rule with status text set into it:  ── 1/127 ── 20 failing ─────── live 2s ──
ui_rule() { # width "left (coloured)" left-width "right (coloured)" right-width -> UI_RULE
  local w="$1" l="$2" lw="$3" r="$4" rw="$5" n t
  [ $((lw + rw + 6)) -le "$w" ] || { r=""; rw=0; }
  [ $((lw + 4)) -le "$w" ] || { l=""; lw=0; }
  n=$((w - 4 - (lw ? lw + 2 : 0) - (rw ? rw + 2 : 0))); [ "$n" -ge 1 ] || n=1
  printf -v t '%*s' "$n" ''; t="${t// /$PC_HR}"
  UI_RULE="${PC_D}${PC_HR}${PC_HR}${PC_R}"
  [ "$lw" = 0 ] || UI_RULE+=" ${l} "
  UI_RULE+="${PC_D}${t}${PC_R}"
  [ "$rw" = 0 ] || UI_RULE+=" ${r} "
  UI_RULE+="${PC_D}${PC_HR}${PC_HR}${PC_R}"
}
# a full screen with the title bar on its first line (help, lists, prompts)
ui_screen() { # title right
  local w
  picker_colors; picker_size; w=$PK_COLS
  ui_bar "$w" " KDASH ${PC_SEP} ${1// | / $PC_SEP } ${PC_SEP} context ${CTX_NAME:-current} ${PC_SEP} namespace ${NS:-default} " "${2:+ ${2// | / $PC_SEP } }"
  printf '\033[H\033[2J%s\033[K\n\n' "$UI_BAR"
}
# key hints, most important first: "key" "what it does" pairs, whole pairs only
ui_keys() { # width pairs... -> UI_KEYS
  local w="$1" k a used=1 add; shift
  UI_KEYS=" "
  while [ $# -ge 2 ]; do
    k=$1; a=$2; shift 2
    ui_vlen "$k $a"; add=$UI_VL; [ "$used" -le 1 ] || add=$((add + 3))
    [ $((used + add)) -le "$w" ] || break
    [ "$used" -le 1 ] || UI_KEYS+="${PC_D} ${PC_MID} ${PC_R}"
    UI_KEYS+="${PC_B}${k}${PC_R} ${a}"; used=$((used + add))
  done
}

# Cut a coloured line to the visible width (escape sequences are copied, not counted).
# A line that wraps would scroll the whole picker and push its title off the screen.
pk_fit() { # string width -> PK_FIT
  local str="$1" w="$2" out="" i=0 n=${#1} vis=0 ch j
  if [ "$n" -le "$w" ]; then PK_FIT="$str"; return 0; fi
  while [ "$i" -lt "$n" ]; do
    ch="${str:i:1}"
    if [ "$ch" = $'\033' ]; then
      j=$i; while [ "$j" -lt "$n" ]; do case "${str:j:1}" in [A-Za-z]) [ "$j" -gt "$i" ] && break ;; esac; j=$((j + 1)); done
      out+="${str:i:$((j - i + 1))}"; i=$((j + 1)); continue
    fi
    [ "$vis" -lt "$w" ] || break
    out+="$ch"; vis=$((vis + 1)); i=$((i + 1))
  done
  PK_FIT="$out${PC_R:-}"
}

picker_size() {
  local s
  s="$(stty size </dev/tty 2>/dev/null)" || s=""
  PK_ROWS="${KDASH_LINES:-${s% *}}"; PK_COLS="${KDASH_COLUMNS:-${s#* }}"
  case "$PK_ROWS" in ''|*[!0-9]*) PK_ROWS=24 ;; esac
  case "$PK_COLS" in ''|*[!0-9]*) PK_COLS=100 ;; esac
  [ "$PK_ROWS" -ge 12 ] || PK_ROWS=12; [ "$PK_COLS" -ge 60 ] || PK_COLS=60
  INSPECTOR_ROWS="$PK_ROWS"; INSPECTOR_COLS="$PK_COLS"; PK_RESIZED=0
}

# Read the model once into arrays (sorted by PK_SORT), then apply the filter.
picker_load() { # dir
  local d="$1" order line sk ns pod c att rst ml s a b r1 r2 r3 r4 r5
  order=(-k1,1 -k2,2 -k3,3)
  case "$PK_SORT" in restarts|cpu|mem|mempct) order=(-k1,1nr -k2,2 -k3,3) ;; esac
  PK_KEY=(); PK_CLS=(); PK_ATT=(); PK_RST=(); PK_ML=(); PK_SRCH=(); PK_A=(); PK_B=(); PK_C1=(); PK_C2=(); PK_C3=(); PK_C4=(); PK_C5=()
  : > "$d/pick.hdr"; : > "$d/pick.sum"
  if [ -r "${MODEL:?}/pods.tsv" ]; then
    while IFS=$'\t' read -r sk ns pod c att rst ml s a b r1 r2 r3 r4 r5; do
      PK_KEY+=("$ns/$pod"); PK_CLS+=("$c"); PK_ATT+=("$att"); PK_RST+=("$rst"); PK_ML+=("$ml")
      PK_SRCH+=("$s"); PK_A+=("$a"); PK_B+=("$b"); PK_C1+=("$r1"); PK_C2+=("$r2"); PK_C3+=("$r3"); PK_C4+=("$r4"); PK_C5+=("$r5")
    done < <(awk -v cols="$PK_COLS" -v allns="${ALL_NS:-0}" -v mode="$PK_SORT" -v hdrf="$d/pick.hdr" -v sumf="$d/pick.sum" \
               "$PICKER_ROWS_AWK" "$MODEL/pods.tsv" | inspector_clean | LC_ALL=C sort -t $'\t' "${order[@]}")
  fi
  IFS= read -r PK_HDR < "$d/pick.hdr" || PK_HDR=""
  # status summary, worst first: "Running 120  Succeeded 20  Failed 2"
  PK_SUM=""; PK_SUMV=(); PK_NBAD=0; PK_NWARN=0
  local sev cnt st col
  while IFS=$'\t' read -r sev cnt st; do
    case "$sev" in 0) col="$PC_BAD"; PK_NBAD=$((PK_NBAD + cnt)) ;; 1) col="$PC_WARN"; PK_NWARN=$((PK_NWARN + cnt)) ;; 2) col="$PC_OK" ;; *) col="$PC_D" ;; esac
    PK_SUM+="${col}${PC_DOT}${PC_R} ${st} ${PC_B}${cnt}${PC_R}   "; PK_SUMV+=("$col" "$st" "$cnt")
  done < <(LC_ALL=C sort -t $'\t' -k1,1n -k2,2nr "$d/pick.sum")
  PK_LOADED_AT="${FETCH_AT:-0}"
  picker_filter
}

# Narrow to the rows matching every word of PK_Q (and "needs attention" when on).
picker_filter() {
  local i w ok q="${PK_Q,,}" words=()
  read -r -a words <<< "$q"
  PK_V=()
  for ((i = 0; i < ${#PK_KEY[@]}; i++)); do
    [ "$PK_ATTN" = 1 ] && [ "${PK_ATT[i]}" != 1 ] && continue
    ok=1; for w in "${words[@]}"; do [[ "${PK_SRCH[i]}" == *"$w"* ]] || { ok=0; break; }; done
    [ "$ok" = 1 ] && PK_V+=("$i")
  done
  # keep the cursor on the same pod when it is still in the list
  PK_SEL=0
  if [ -n "${PK_SEL_KEY:-}" ]; then
    for ((i = 0; i < ${#PK_V[@]}; i++)); do [ "${PK_KEY[${PK_V[i]}]}" = "$PK_SEL_KEY" ] && { PK_SEL=$i; break; }; done
  fi
}

picker_draw() {
  local nv=${#PK_V[@]} rows top i j a b c ml rc line len pad buf banner mode sel_key title right status_col
  rows=$((PK_ROWS - 7)); [ "$rows" -ge 3 ] || rows=3
  [ "$PK_SEL" -lt "$nv" ] || PK_SEL=$((nv > 0 ? nv - 1 : 0)); [ "$PK_SEL" -ge 0 ] || PK_SEL=0
  [ "$PK_SEL" -ge "$PK_TOP" ] || PK_TOP=$PK_SEL
  [ "$PK_SEL" -lt $((PK_TOP + rows)) ] || PK_TOP=$((PK_SEL - rows + 1))
  [ "$PK_TOP" -le $((nv > rows ? nv - rows : 0)) ] || PK_TOP=$((nv > rows ? nv - rows : 0))
  [ "$PK_TOP" -ge 0 ] || PK_TOP=0; top=$PK_TOP
  [ "$nv" = 0 ] || PK_SEL_KEY="${PK_KEY[${PK_V[PK_SEL]}]}"
  case "${KDASH_ATTACH_ACTION:-}" in
    S) banner=" ${PC_PTR} Enter opens a SHELL " ;; U) banner=" ${PC_PTR} Enter UPLOADS into the pod " ;; D) banner=" ${PC_PTR} Enter DOWNLOADS from the pod " ;; *) banner="" ;;
  esac
  title=" KDASH ${PC_SEP} SELECT POD ${PC_SEP} context ${CTX_NAME:-current} ${PC_SEP} namespace ${NS:-default} "
  if interactive_enabled; then mode="INTERACTIVE"; else mode="READ-ONLY"; fi
  right=" ${mode} ${PC_SEP} ${#PK_V[@]} of ${#PK_KEY[@]} pods "
  ui_bar "$PK_COLS" "$title" "$right" "$banner"
  buf=$'\033[H'"${UI_BAR}"$'\033[K\n'
  # status counts, worst first; a status that does not fit is left out whole
  line=" ${PC_D}pods${PC_R}  "; len=7
  if [ "${#PK_SUMV[@]}" = 0 ]; then line+="${PC_D}none${PC_R}"; fi
  for ((i = 0; i + 2 < ${#PK_SUMV[@]}; i += 3)); do
    a="${PK_SUMV[i+1]} ${PK_SUMV[i+2]}"; [ $((len + ${#a} + 5)) -lt "$PK_COLS" ] || break
    line+="  ${PK_SUMV[i]}${PC_DOT}${PC_R} ${PK_SUMV[i+1]} ${PC_B}${PK_SUMV[i+2]}${PC_R}"; len=$((len + ${#a} + 4))
  done
  buf+="$line"$'\033[K\n'
  # filter / mode line
  if [ "$PK_TYPING" = 1 ]; then
    buf+=" ${PC_INFO}/${PC_R} ${PC_B}${PK_Q}${PC_R}${PC_INFO}${PC_CARET}${PC_R}  ${PC_D}type to filter (words AND, any of pod / status / node)  Enter keep  Esc clear  ^U erase${PC_R}"
  else
    # built twice - coloured (cl) and plain (pl) - so the line can be cut to the width:
    # a wrapped line would push the whole list down and the title off the screen
    local cl="" pl="" seg msg
    if [ -n "$PK_Q" ]; then cl+=" ${PC_INFO}filter${PC_R} ${PC_B}${PK_Q}${PC_R}"; pl+=" filter ${PK_Q}"; else cl+=" ${PC_D}/ search${PC_R}"; pl+=" / search"; fi
    if [ "$PK_ATTN" = 1 ]; then cl+="   ${PC_D}view${PC_R} ${PC_WARN}needs attention (u)${PC_R}"; pl+="   view needs attention (u)"
    else cl+="   ${PC_D}view${PC_R} all (u)"; pl+="   view all (u)"; fi
    interactive_enabled || { cl+="   ${PC_D}X${PC_R} enables shell / upload / download"; pl+="   X enables shell / upload / download"; }
    cl+="   ${PC_D}sort${PC_R} ${PK_SORT}"; pl+="   sort ${PK_SORT}"
    [ -z "${PK_NUM:-}" ] || { cl+="   ${PC_INFO}go to #${PK_NUM}${PC_R}"; pl+="   go to #${PK_NUM}"; }
    if [ -n "${PK_MSG:-}" ]; then
      len=$((PK_COLS - ${#pl} - 4))
      if [ "$len" -ge 12 ]; then msg="$PK_MSG"; [ "${#msg}" -le "$len" ] || msg="${msg:0:$((len - 1))}~"; cl+="   ${PC_WARN}${msg}${PC_R}"
      else cl=" ${PC_WARN}${PK_MSG:0:$((PK_COLS - 2))}${PC_R}"; fi     # narrow window: the message wins
    fi
    pk_fit "$cl" "$((PK_COLS - 1))"; buf+="$PK_FIT"
  fi
  buf+=$'\033[K\n'
  line="   ${PK_HDR}"; line="${line:0:$((PK_COLS - 1))}"; printf -v line '%-*s' "$((PK_COLS - 1))" "$line"
  buf+="${PC_HDR}${line}${PC_R}"$'\033[K\n'
  for ((i = 0; i < rows; i++)); do
    j=$((top + i))
    if [ "$j" -ge "$nv" ]; then
      if [ "$i" = 0 ]; then
        if [ "${#PK_KEY[@]}" = 0 ]; then buf+="   ${PC_D}no pods in the model - F edits filters, r re-reads${PC_R}"
        else buf+="   ${PC_WARN}nothing matches${PC_R} ${PC_D}- Esc clears the filter, u shows all pods${PC_R}"; fi
      fi
      buf+=$'\033[K\n'; continue
    fi
    j=${PK_V[j]}; a="${PK_A[j]}"; b="${PK_B[j]}"
    c="${PK_C1[j]}${PK_C2[j]}${PK_C3[j]}${PK_C4[j]}${PK_C5[j]}"
    len=$((PK_COLS - 4 - ${#a} - ${#b})); [ "$len" -ge 0 ] || len=0; c="${c:0:$len}"
    if [ $((top + i)) = "$PK_SEL" ]; then
      line="${PC_PTR} ${a}${b}${c}"; pad=$((PK_COLS - 2 - ${#line})); [ "$pad" -ge 0 ] || pad=0
      printf -v pad '%*s' "$pad" ''
      buf+=" ${PC_INV}${PC_B}${line}${pad}${PC_R}"$'\033[K\n'
    else
      case "${PK_CLS[j]}" in bad) status_col="$PC_BAD" ;; warn) status_col="$PC_WARN" ;; done) status_col="$PC_D" ;; *) status_col="$PC_OK" ;; esac
      line="   ${a}${status_col}${b}${PC_R}"
      if [ "${PK_CLS[j]}" = done ]; then line+="${PC_D}${c}${PC_R}"
      elif [ "${#c}" -ge "$(( ${#PK_C1[j]} + ${#PK_C2[j]} + ${#PK_C3[j]} + ${#PK_C4[j]} ))" ]; then
        # restarts and memory % of limit stand out when they matter
        case "${PK_ML[j]}" in 2) ml="$PC_BAD" ;; 1) ml="$PC_WARN" ;; *) ml="" ;; esac
        rc=""; [ "${PK_RST[j]}" != 1 ] || rc="$PC_WARN"
        line+="${PK_C1[j]}${rc}${PK_C2[j]}${PC_R}${PK_C3[j]}${ml}${PK_C4[j]}${PC_R}${PC_D}${c:$(( ${#PK_C1[j]} + ${#PK_C2[j]} + ${#PK_C3[j]} + ${#PK_C4[j]} ))}${PC_R}"
      else line+="$c"; fi
      buf+="$line"$'\033[K\n'
    fi
  done
  # position rule + keys
  local up=$top dn=$((nv - top - rows)) lp=() rp=()
  [ "$dn" -ge 0 ] || dn=0
  lp=("$PC_B" "$((nv ? PK_SEL + 1 : 0))" "$PC_D" " / ${nv}")
  [ "$up" = 0 ] || lp+=("$PC_D" "   ${PC_UP} ${up} above")
  [ "$dn" = 0 ] || lp+=("$PC_D" "   ${PC_DN} ${dn} below")
  [ "$PK_NBAD" = 0 ] || lp+=("$PC_BAD" "   ${PK_NBAD} failing")
  [ "$PK_NWARN" = 0 ] || lp+=("$PC_WARN" "   ${PK_NWARN} pending / starting")
  ui_seg "$((PK_COLS - 30))" "${lp[@]}"; local ls="$UI_SEG" lw="$UI_SEGW"
  if [ "${PAUSED:-0}" = 1 ]; then rp=("$PC_WARN" "PAUSED"); else rp=("$PC_D" "live ${PC_MID} refresh ${INTERVAL:-2}s"); fi
  ui_seg 28 "${rp[@]}"
  ui_rule "$((PK_COLS - 1))" "$ls" "$lw" "$UI_SEG" "$UI_SEGW"; buf+="$UI_RULE"$'\033[K\n'
  local f1 f2
  if [ -n "${KDASH_ATTACH_ACTION:-}" ]; then
    case "$KDASH_ATTACH_ACTION" in S) mode="open shell" ;; U) mode="upload" ;; *) mode="download" ;; esac
    ui_keys "$((PK_COLS - 1))" Enter "$mode" q dashboard Q "quit kdash" / search u attention j/k move "PgUp/PgDn" page 12 "go to row"; f1="$UI_KEYS"
    ui_keys "$((PK_COLS - 1))" exit "in the shell returns here" kdswitch "related pods" kdquit "leaves kdash" audited "runs with your RBAC"; f2="$UI_KEYS"
  else
    ui_keys "$((PK_COLS - 1))" Enter summary l logs p "prev logs" d describe e events w why c containers S shell U upload D download; f1="$UI_KEYS"
    ui_keys "$((PK_COLS - 1))" q back Q quit / search u attention s sort F filters r refresh "?" help j/k move 12 "go to row"; f2="$UI_KEYS"
  fi
  buf+="$f1"$'\033[K\n'"$f2"$'\033[K'
  printf '%s\033[J' "$buf"
}

# One key; arrows and page keys become tokens. Returns 1 on timeout (live refresh).
picker_key() { # timeout
  local seq="" extra=""
  PK_KEY_IN=""
  IFS= read -rsn1 -t "$1" PK_KEY_IN </dev/tty || { PK_KEY_IN=""; return 1; }
  if [ "$PK_KEY_IN" = $'\033' ]; then
    IFS= read -rsn2 -t 0.03 seq </dev/tty || true
    case "$seq" in
      '[A'|'OA') PK_KEY_IN='<UP>' ;; '[B'|'OB') PK_KEY_IN='<DN>' ;; '[H'|'OH') PK_KEY_IN='<HOME>' ;; '[F'|'OF') PK_KEY_IN='<END>' ;;
      '[C'|'OC') PK_KEY_IN='<RIGHT>' ;; '[D'|'OD') PK_KEY_IN='<LEFT>' ;;
      '[5'|'[6'|'[1'|'[4'|'[7'|'[8')
        IFS= read -rsn1 -t 0.03 extra </dev/tty || true
        case "$seq$extra" in '[5~') PK_KEY_IN='<PGUP>' ;; '[6~') PK_KEY_IN='<PGDN>' ;; '[1~'|'[7~') PK_KEY_IN='<HOME>' ;; '[4~'|'[8~') PK_KEY_IN='<END>' ;; esac ;;
      '') PK_KEY_IN='<ESC>' ;;
      *) PK_KEY_IN='<ESC>' ;;
    esac
  elif [ -z "$PK_KEY_IN" ]; then PK_KEY_IN='<ENTER>'
  fi
  return 0
}

picker_help() {
  ui_screen "SELECT POD | KEYS" "any key returns"
  cat <<'H'
  MOVE        j / k / arrows     one row          PgDn / PgUp / space / b   one page
              g / G / Home / End first / last     12 (digits)  jump to row 12 of the list
  FIND        /                  type to filter: every word must match the pod name,
                                 status or node (e.g. "/fileserver3 failed")
              Esc                clear the filter    u  only pods that need attention
              s                  sort: name, status (worst first), restarts, cpu, mem, mem% of limit
              F                  structured filters (label / status / node / workload)
  ACT ON THE  Enter / i          summary          l  current logs      p  previous logs
  SELECTED    d                  describe         e  events            w  why (event hypotheses)
  POD         c                  pick a container first, then inspect
              S / U / D          shell / upload / download (interactive mode)
              X                  interactive mode on / off (asks first; also: kdx, kdash -X)
  OTHER       r                  re-read now (the list also refreshes every poll)
              q                  back to the dashboard     Q  quit kdash (from any screen)

  Colours: green running and ready, magenta pending / starting / terminating,
  red failing / not ready / >= 90% of memory limit, grey completed.
  "needs attention" = failing, pending or restarted pods.
H
  IFS= read -rsn1 _k </dev/tty || true
}

# After a shell / copy: "kdswitch" in the container asks for the pods related to the
# one just left (same workload), in shell mode; otherwise say where we came back from.
picker_switch() {
  [ -n "${KDASH_SWITCH:-}" ] || return 0
  KDASH_SWITCH=""; KDASH_ATTACH_ACTION=S
  PK_Q="${KDASH_SWITCH_Q:-}"; PK_ATTN=0; PK_TYPING=0; PK_SEL_KEY="${KDASH_SWITCH_FROM:-}"
  PK_MSG="related pods of ${KDASH_SWITCH_Q:-?} - Enter opens a shell, / changes the filter"
}
# kdsh FILTER / ":shell FILTER": exactly one pod matches -> straight into its shell.
# Decided once real data is there (at start-up the first cluster read is still running).
picker_auto() { # dir
  [ "${PK_AUTO:-0}" = 1 ] || return 0
  [ "${#PK_KEY[@]}" -gt 0 ] || return 0                 # nothing read yet: decide later
  PK_AUTO=0
  [ "${KDASH_ATTACH_ACTION:-}" = S ] && [ "${#PK_V[@]}" = 1 ] || return 0
  PK_SEL=0; PK_SEL_KEY="${PK_KEY[${PK_V[0]}]}"
  picker_act shell "$1"; picker_back shell; picker_size; picker_load "$1"
}
picker_back() { # what
  [ -z "${PK_MSG:-}" ] || return 0                      # keep a refusal message
  [ -n "${KDASH_SWITCH:-}" ] && { picker_switch; return 0; }
  case "$1" in shell) PK_MSG="back from ${POD_PICK:-the pod} - Enter opens another shell, q dashboard, Q quit" ;; esac
}

# Open the inspector on the selected pod at a given pane (or the container picker).
picker_act() { # what dir
  local what="$1" d="$2" key="${PK_KEY[${PK_V[PK_SEL]}]}" ns pod
  ns="${key%%/*}"; pod="${key#*/}"; POD_PICK="$key"
  case "$what" in
    shell|up|down)
      if interactive_enabled; then
        INTERACTIVE_WHY=""; interactive_attach "$what" "$ns" "$pod" "$d"
        # a refusal (no running container, cancelled pick) must be visible here,
        # not only in the dashboard status bar behind the picker
        [ -z "${INTERACTIVE_WHY:-}" ] || { PK_MSG="$INTERACTIVE_WHY"; return 0; }
      else PK_MSG="$(interactive_hint)"; return 0; fi ;;
    container)
      if inspector_container_picker "$ns" "$pod" "$d"; then
        KDASH_INSPECT_CONTAINER="$INSPECTOR_CONTAINER"; KDASH_INSPECT_CONTAINER_POD="$key"
        inspector_detail "$ns" "$pod" "$d"
      fi ;;
    *) INSPECTOR_PANE="$what"; inspector_detail "$ns" "$pod" "$d" ;;
  esac
  INSPECTOR_PANE=""
  printf '\033[?25l\033[2J'
}

inspector_open() { # optional explicit ns/pod; otherwise the pod picker
  local d="${TMPD:?}/inspector/live" k now done_=0 prev_winch
  if [ ! -t 0 ] || [ ! -t 1 ]; then
    [ -n "${2:-}" ] && { inspector_render "$1" "$2"; return $?; }
    printf 'kdash: the pod picker requires a terminal; use --inspect POD for text output.\n' >&2; return 2
  fi
  (umask 077; mkdir -p "$d") || return 1
  if [ -n "${2:-}" ]; then
    inspector_identity_ok "$1" "$2" || return 2
    POD_PICK="$1/$2"; inspector_detail "$1" "$2" "$d"
    rm -rf -- "$d"; return 0
  fi
  picker_colors; picker_size
  PK_Q="${PK_Q:-}"; PK_ATTN="${PK_ATTN:-0}"; PK_SORT="${PK_SORT:-name}"; PK_TOP=0; PK_TYPING=0; PK_NUM=""; PK_MSG=""
  PK_SEL_KEY="${POD_PICK:-}"
  prev_winch="$(trap -p WINCH)"; trap 'PK_RESIZED=1' WINCH
  printf '\033[?25l\033[2J'
  picker_load "$d"
  picker_auto "$d"
  while [ "$done_" = 0 ]; do
    [ "${PK_RESIZED:-0}" = 0 ] || { picker_size; picker_load "$d"; printf '\033[2J'; }
    picker_draw
    if ! picker_key 1; then
      # no key for a second: keep the list live (the dashboard loop is paused here)
      if [ "${PAUSED:-0}" = 0 ] && [ "$PK_TYPING" = 0 ]; then
        fetch; [ "${FETCH_AT:-0}" = "${PK_LOADED_AT:-0}" ] || { picker_load "$d"; picker_auto "$d"; }
      fi
      [ -z "$PK_NUM" ] || [ $((SECONDS - PK_NUM_AT)) -lt 2 ] || PK_NUM=""
      continue
    fi
    k="$PK_KEY_IN"; PK_MSG=""
    if [ "$PK_TYPING" = 1 ]; then            # live filter input
      case "$k" in
        '<ENTER>') PK_TYPING=0 ;;
        '<ESC>') PK_TYPING=0; PK_Q=""; picker_filter ;;
        $'\177'|$'\b') PK_Q="${PK_Q%?}"; picker_filter ;;
        $'\025') PK_Q=""; picker_filter ;;
        '<UP>') PK_SEL=$((PK_SEL - 1)) ;; '<DN>') PK_SEL=$((PK_SEL + 1)) ;;
        '<'*'>') ;;
        *) [[ "$k" == [[:print:]] ]] && { PK_Q+="$k"; PK_SEL_KEY=""; picker_filter; } ;;
      esac
      continue
    fi
    if [[ "$k" == [0-9] ]]; then             # number jump: "1" then "2" goes to row 12
      [ -n "$PK_NUM" ] && [ $((SECONDS - PK_NUM_AT)) -lt 2 ] || PK_NUM=""
      PK_NUM+="$k"; PK_NUM_AT=$SECONDS
      [ "$((10#$PK_NUM))" -ge 1 ] && PK_SEL=$((10#$PK_NUM - 1)); continue
    fi
    PK_NUM=""
    local page=$((PK_ROWS - 8))
    case "$k" in
      q) done_=1 ;;
      Q) kdash_quit "pod list" ;;
      '<ESC>') if [ -n "$PK_Q" ]; then PK_Q=""; picker_filter; else done_=1; fi ;;
      j|'<DN>') PK_SEL=$((PK_SEL + 1)) ;;
      k|'<UP>') PK_SEL=$((PK_SEL - 1)) ;;
      ' '|'<PGDN>'|'<RIGHT>') PK_SEL=$((PK_SEL + page)) ;;
      b|'<PGUP>'|'<LEFT>') PK_SEL=$((PK_SEL - page)) ;;
      g|'<HOME>') PK_SEL=0 ;;
      G|'<END>') PK_SEL=$(( ${#PK_V[@]} - 1 )) ;;
      /) PK_TYPING=1 ;;
      u) PK_ATTN=$((1 - PK_ATTN)); picker_filter ;;
      s) case "$PK_SORT" in name) PK_SORT=status ;; status) PK_SORT=restarts ;; restarts) PK_SORT=cpu ;; cpu) PK_SORT=mem ;; mem) PK_SORT=mempct ;; *) PK_SORT=name ;; esac
         picker_load "$d"; PK_SEL_KEY=""; PK_SEL=0; PK_TOP=0 ;;
      r) SPEC_AT=0; FETCH_NEXT=0; fetch; PK_MSG="re-reading..." ;;
      F) inspector_filter_prompt; declare -F toolkit_filters_changed >/dev/null && toolkit_filters_changed
         picker_load "$d"; printf '\033[?25l\033[2J' ;;
      '?') picker_help; printf '\033[2J' ;;
      X) interactive_toggle; PK_MSG="$INTERACTIVE_MSG"; printf '\033[2J' ;;
      *)
        [ "${#PK_V[@]}" -gt 0 ] || continue
        if [ -n "${KDASH_ATTACH_ACTION:-}" ] && [ "$k" = '<ENTER>' ]; then
          # shell / upload / download mode stays on: after the attachment ends the
          # list comes back, ready for the next pod (q dashboard, Q quit kdash)
          case "$KDASH_ATTACH_ACTION" in S) k=shell ;; U) k=up ;; *) k=down ;; esac
          picker_act "$k" "$d"; picker_back "$k"
          picker_size; picker_load "$d"; continue
        fi
        case "$k" in
          '<ENTER>'|i) picker_act summary "$d" ;;
          l) picker_act current "$d" ;;  p) picker_act previous "$d" ;;
          d) picker_act describe "$d" ;; e) picker_act events "$d" ;;  w) picker_act explain "$d" ;;
          c) picker_act container "$d" ;;
          S) picker_act shell "$d"; picker_back shell ;;    U) picker_act up "$d" ;;     D) picker_act down "$d" ;;
          *) continue ;;
        esac
        picker_switch
        picker_size; picker_load "$d" ;;
    esac
  done
  if [ -n "$prev_winch" ]; then eval "$prev_winch"; else trap - WINCH; fi
  rm -rf -- "$d"
  printf '\033[2J'
  return 0
}

inspector_filter_apply() { # semicolon separated fields, atomically assigned
  local value="$1" pair key val regex_rc
  local label="${KDASH_LABEL_SELECTOR:-}" status="${KDASH_STATUS_FILTER:-}" node="${KDASH_NODE_FILTER:-}"
  local workload="${KDASH_WORKLOAD_FILTER:-}" unhealthy="${KDASH_UNHEALTHY:-0}" fields=()
  if [ "$value" = clear ]; then
    KDASH_LABEL_SELECTOR=""; KDASH_STATUS_FILTER=""; KDASH_NODE_FILTER=""; KDASH_WORKLOAD_FILTER=""; KDASH_UNHEALTHY=0
    return 0
  fi
  IFS=';' read -r -a fields <<< "$value"
  for pair in "${fields[@]}"; do
    pair="${pair#"${pair%%[![:space:]]*}"}"; pair="${pair%"${pair##*[![:space:]]}"}"
    [ -n "$pair" ] || continue
    case "$pair" in *=*) ;; *) printf 'Each filter must be key=value.\n' >&2; return 2 ;; esac
    key="${pair%%=*}"; val="${pair#*=}"
    [[ "$val" != *[$'\001'-$'\037'$'\177']* ]] || { printf 'Control bytes are not allowed in filters.\n' >&2; return 2; }
    [ "${#val}" -le 1024 ] || { printf 'Filter values must be at most 1024 characters.\n' >&2; return 2; }
    case "$key" in
      label) label="$val" ;; status) status="$val" ;; node) node="$val" ;; workload) workload="$val" ;;
      unhealthy) case "$val" in 1|true|yes) unhealthy=1 ;; 0|false|no|'') unhealthy=0 ;; *) printf 'unhealthy must be 0 or 1.\n' >&2; return 2 ;; esac ;;
      *) printf 'Unknown filter %s. Use label, status, node, workload, unhealthy.\n' "$key" >&2; return 2 ;;
    esac
  done
  for val in "$status" "$workload"; do
    if printf '' | grep -E -- "$val" >/dev/null 2>&1; then :
    else
      regex_rc=$?
      [ "$regex_rc" = 1 ] || { printf 'Status and workload must be valid extended regular expressions.\n' >&2; return 2; }
    fi
  done
  KDASH_LABEL_SELECTOR="$label"; KDASH_STATUS_FILTER="$status"; KDASH_NODE_FILTER="$node"
  KDASH_WORKLOAD_FILTER="$workload"; KDASH_UNHEALTHY="$unhealthy"
  return 0
}

inspector_filter_prompt() {
  local line="" msg=""
  while :; do
    ui_screen "POD FILTERS" "structured, AND-combined"
    printf ' label=%s\n status=%s\n node=%s\n workload=%s\n unhealthy=%s\n\n' \
      "${KDASH_LABEL_SELECTOR:-}" "${KDASH_STATUS_FILTER:-}" "${KDASH_NODE_FILTER:-}" "${KDASH_WORKLOAD_FILTER:-}" "${KDASH_UNHEALTHY:-0}"
    printf ' Enter semicolon-separated fields; omitted fields stay unchanged.\n Example: label=app in (api,worker);status=Pending|CrashLoop;unhealthy=1\n Node uses an exact match; status and workload use extended regex.\n Empty value clears a field. Type clear to reset all; Enter cancels.\n%s\n\033[?25h filters > ' "$msg"
    IFS= read -r line </dev/tty || { printf '\033[?25l'; return 1; }
    printf '\033[?25l'
    [ -n "$line" ] || return 1
    if msg="$(inspector_filter_apply "$line" 2>&1)"; then
      # Apply in this shell too: command substitution above isolated assignments.
      inspector_filter_apply "$line" || return 2
      declare -F audit >/dev/null && audit FILTER_STRUCTURED "label=$KDASH_LABEL_SELECTOR status=$KDASH_STATUS_FILTER node=$KDASH_NODE_FILTER workload=$KDASH_WORKLOAD_FILTER unhealthy=$KDASH_UNHEALTHY"
      return 0
    fi
  done
}

inspector_palette() {
  local command=""
  ui_screen "COMMAND PALETTE" "Enter on an empty line cancels"
  printf ' shell [FILTER]          Shell in a pod: one match opens it, otherwise the filtered list\n quit                    Leave kdash (also Q on any screen)\n inspect                 Choose a pod and inspect it\n filter                  Structured pod filters\n pods / nodes / workloads / ip / mem / io / alerts\n services / storage / events / explain / doctor\n help                    Dashboard help\n\n Commands use fixed handlers and never execute shell text.\n\033[?25h : '
  IFS= read -r command </dev/tty || { printf '\033[?25l'; return 1; }; printf '\033[?25l'
  case "$command" in
    '') return 0 ;; inspect|i) inspector_open ;; filter|F) inspector_filter_prompt ;;
    quit|exit|Q) kdash_quit palette ;;
    shell|sh|"shell "*|"sh "*)
      if ! interactive_enabled; then declare -F flash >/dev/null && flash "$(interactive_hint)" 8; return 0; fi
      PK_Q="${command#* }"; [ "$PK_Q" != "$command" ] || PK_Q=""; PK_AUTO=1; PK_SEL_KEY=""
      KDASH_ATTACH_ACTION=S; inspector_open; KDASH_ATTACH_ACTION="" ;;
    pods|nodes|workloads|ip|mem|io|alerts) VIEW="$command"; SCROLL=0; HSCROLL=0 ;;
    services|storage|events|explain|doctor) VIEW="$command"; TOOLKIT_REQUESTED=1; SCROLL=0; HSCROLL=0 ;;
    help|'?') if declare -F show_help >/dev/null; then show_help; else printf '\n Use ? on the dashboard for help.\n'; fi ;;
    *) declare -F flash >/dev/null && flash "Unknown command: ${command:0:70}" 5; return 2 ;;
  esac
}
