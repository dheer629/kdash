# Interactive, read-only pod inspection. This source is embedded in the release
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
  INSPECTOR_TAIL="${KDASH_LOG_TAIL:-200}"
  INSPECTOR_BYTES="${KDASH_LOG_LIMIT_BYTES:-65536}"
  case "$INSPECTOR_TAIL" in ''|*[!0-9]*) INSPECTOR_TAIL=200 ;; esac
  case "$INSPECTOR_BYTES" in ''|*[!0-9]*) INSPECTOR_BYTES=65536 ;; esac
  [ "${#INSPECTOR_TAIL}" -gt 4 ] && INSPECTOR_TAIL=2000
  [ "${#INSPECTOR_BYTES}" -gt 7 ] && INSPECTOR_BYTES=1048576
  INSPECTOR_TAIL=$((10#$INSPECTOR_TAIL)); INSPECTOR_BYTES=$((10#$INSPECTOR_BYTES))
  [ "$INSPECTOR_TAIL" -lt 1 ] && INSPECTOR_TAIL=1
  [ "$INSPECTOR_TAIL" -gt 2000 ] && INSPECTOR_TAIL=2000
  [ "$INSPECTOR_BYTES" -lt 1024 ] && INSPECTOR_BYTES=1024
  [ "$INSPECTOR_BYTES" -gt 1048576 ] && INSPECTOR_BYTES=1048576
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
  if [ "$(wc -c < "$dest.raw")" -gt "$cap" ]; then
    printf '\n[Output clipped at %s bytes.]\n' "$cap" >> "$dest"
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
  printf 'Container: %s | %s logs | last %s lines | maximum %s bytes | timestamps\n\n' "$container" "$mode" "$INSPECTOR_TAIL" "$INSPECTOR_BYTES" > "$dest"
  INSPECTOR_QUERY_CAP="$INSPECTOR_BYTES" inspector_query "$dest.body" logs "$pod" -n "$ns" -c "$container" \
    --tail="$INSPECTOR_TAIL" --limit-bytes="$INSPECTOR_BYTES" --timestamps=true "${flags[@]}" || rc=$?
  cat "$dest.body" >> "$dest"; rm -f -- "$dest.body"
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
    '[C') INSPECTOR_KEY=l ;; '[D') INSPECTOR_KEY=b ;;
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
    printf '\033[H\033[2J %s in the %s pane | Pod: %s | Container: %s\n\n' \
      "$([ "$mode" = only ] && printf 'Show only matching lines' || printf 'Find')" "$pane" "${POD_PICK:-}" "${KDASH_INSPECT_CONTAINER:-all}"
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
inspector_view_build() { # body view matches
  local body="$1" view="$2" matchf="$3" icase=0
  [ -z "${INSPECTOR_SEARCH:-}" ] || icase="$(inspector_icase "$INSPECTOR_SEARCH")"
  awk -v pat="${INSPECTOR_SEARCH:-}" -v icase="$icase" -v lvl="${INSPECTOR_LEVEL_PAT:-}" \
      -v only="${INSPECTOR_ONLY:-0}" -v matchf="$matchf" -v metaf="$view.meta" '
    function hit(line) {
      if (pat == "") return 0
      return (icase ? (tolower(line) ~ tolower(pat)) : (line ~ pat))
    }
    { if (lvl != "" && $0 !~ lvl) next
      m = hit($0)
      if (only == "1" && pat != "" && !m) next
      n++
      print
      if (m) { hits++; print n > matchf } }
    END { printf "%d %d\n", n + 0, hits + 0 > metaf }
  ' "$body" > "$view"
  INSPECTOR_VIEW_LINES=0; INSPECTOR_MATCHES=0
  [ -r "$view.meta" ] && read -r INSPECTOR_VIEW_LINES INSPECTOR_MATCHES < "$view.meta"
  return 0
}

# Print the visible slice, clipped to the terminal width and with the matches marked.
# Clipping happens before the colour codes are added so the width stays exact.
inspector_show() { # view first last cols color
  local icase="" view="$1"
  [ -z "${INSPECTOR_SEARCH:-}" ] || icase="$(inspector_icase "$INSPECTOR_SEARCH")"
  awk -v first="$2" -v last="$3" -v w="$4" -v color="$5" \
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
    NR >= first && NR <= last { print hl(substr($0, 1, w), pat) }
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

# Pick a container: name, type, readiness, restarts, state, last exit and image.
# Returns the chosen name in INSPECTOR_CONTAINER (plus INSPECTOR_PANE for l/p).
inspector_container_picker() { # ns pod dir
  local ns="$1" pod="$2" d="$3" rows first=0 chosen=0 i=0 n=0
  local name type ready rst state last image line=""
  local items=()
  INSPECTOR_CONTAINER=""; INSPECTOR_PANE=""
  inspector_size; rows=$((INSPECTOR_ROWS - 9)); [ "$rows" -ge 3 ] || rows=3
  inspector_container_rows "$ns" "$pod" "$d/rows.spec" "$d/rows.status" > "$d/rows" 2> "$d/rows.err" || true
  while IFS= read -r line; do [ -n "$line" ] && items+=("$line"); done < "$d/rows"
  n=${#items[@]}
  if [ "$n" = 0 ]; then
    printf '\033[H\033[2J No containers reported for %s/%s.\n %s\n\n Press any key to return.\033[?25h' "$ns" "$pod" "$(head -c 300 "$d/rows.err" 2>/dev/null)"
    IFS= read -rsn1 _ </dev/tty || true
    return 1
  fi
  for ((i = 0; i < n; i++)); do
    IFS=$'\t' read -r type name _ <<< "${items[$i]}"
    [ "$name" != "${KDASH_INSPECT_CONTAINER:-}" ] || chosen=$i
  done
  while :; do
    [ "$chosen" -ge "$first" ] || first=$chosen
    [ "$chosen" -lt "$((first + rows))" ] || first=$((chosen - rows + 1))
    printf '\033[H\033[2J Containers of %s/%s | Context: %s\n\n' "$ns" "$pod" "${CTX_NAME:-current}"
    printf ' %-3s %-26s %-8s %-6s %-5s %-5s %-16s %-14s %s\n' '#' NAME TYPE READY RST STATE 'LAST EXIT' IMAGE
    for ((i = first; i < n && i < first + rows; i++)); do
      IFS=$'\t' read -r type name ready rst state last image <<< "${items[$i]}"
      printf '%s%-3s %-26s %-8s %-6s %-5s %-5s %-16s %-14s %s\n' "$([ "$i" = "$chosen" ] && printf '>' || printf ' ')" "$((i + 1))" \
        "${name:0:26}" "${type:0:8}" "${ready}" "$rst" "${state:0:16}" "${last:0:14}" \
        "${image:0:$((INSPECTOR_COLS - 100 > 8 ? INSPECTOR_COLS - 100 : 8))}"
    done
    printf '\033[%s;1H j/k or arrows select | 1-9 open that container | Enter summary | l current logs | p previous logs | q/Esc cancel\033[J' "$((INSPECTOR_ROWS - 2))"
    printf '\033[%s;1H Every container of this pod, including init and debug containers. Init is shown first in the pod spec.\033[?25h' "$((INSPECTOR_ROWS - 1))"
    inspector_key || break
    case "$INSPECTOR_KEY" in
      q|$'\033') return 1 ;;
      j) chosen=$(((chosen + 1) % n)) ;;
      k) chosen=$(((chosen + n - 1) % n)) ;;
      g) chosen=0 ;; G) chosen=$((n - 1)) ;;
      [1-9]) i=$((INSPECTOR_KEY - 1))
             [ "$i" -lt "$n" ] || continue
             IFS=$'\t' read -r type name _ <<< "${items[$i]}"; INSPECTOR_CONTAINER="$name"; return 0 ;;
      l|p) IFS=$'\t' read -r type name _ <<< "${items[$chosen]}"
           INSPECTOR_CONTAINER="$name"
           [ "$INSPECTOR_KEY" = l ] && INSPECTOR_PANE=current || INSPECTOR_PANE=previous
           return 0 ;;
      ''|i|$'\n') IFS=$'\t' read -r type name _ <<< "${items[$chosen]}"; INSPECTOR_CONTAINER="$name"; return 0 ;;
    esac
  done
  return 1
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
  printf '\033[H\033[2J kdash inspector - keys (any key returns)\n\n'
  printf ' FIND                          PANES                       NAVIGATE\n'
  printf '  /  find in this pane         s  summary                  j k arrows  line\n'
  printf '  &  show only matches         d  describe                 space b     page\n'
  printf '  n N  next / previous match   e  events                   PgUp PgDn   page\n'
  printf '  L  log level: all, ERROR,    !  why (event hypotheses)    g G Home End  top/bottom\n'
  printf '     WARN, INFO, DEBUG         l  current logs             c  choose container\n'
  printf '  f  follow logs               p  previous logs            r  reload now\n'
  printf '  w  export what you see       q Esc  back                ?  this help\n\n'
  printf ' / keeps the context around every match and highlights it; & hides everything else.\n'
  printf ' A lowercase pattern ignores case: /error finds ERROR and error.\n'
  printf ' n and N wrap around and put the match at the top of the pane.\n'
  printf ' c lists every container with readiness, restarts, state and last exit: pick one\n'
  printf ' and l/p read that container. Search and level stay active across panes.\n'
  printf ' w writes the filtered pane to %s/inspector/ (review it before sharing).\n\n' "$(inspector_report_dir)"
  printf '\033[?25h any key returns'
  IFS= read -rsn1 _ </dev/tty || true
}

inspector_detail() { # nested UI; q returns to the picker, keeping the identity
  local ns="$1" pod="$2" d="$3" pane="${INSPECTOR_PANE:-summary}" loaded="" reload=1 viewdirty=1 rows_stale=1
  local body="$3/body" view="$3/view" matchf="$3/matches"
  local offset=0 count=0 total=0 matches=0 msg="" rows pid rc keep_offset=0 follow=0 atbottom=0
  local container="${KDASH_INSPECT_CONTAINER:-}" file="" target=0 idx=0 cline="" pinfo=""
  local INSPECTOR_REFRESH_EVENTS=0
  INSPECTOR_PANE=""
  inspector_limits          # tail/bytes/follow defaults must exist in this shell too
  while :; do
    inspector_size; rows=$((INSPECTOR_ROWS - 8))
    if [ "$loaded" != "$pane" ] || [ "$reload" = 1 ]; then
      printf '\033[H\033[2J Context: %s | Namespace: %s | Pod: %s\n\n Reading %s... (q/Esc cancels)\n' "${CTX_NAME:-current}" "$ns" "$pod" "$pane"
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
    if [ "$viewdirty" = 1 ]; then
      inspector_view_build "$body" "$view" "$matchf"
      viewdirty=0; count="$INSPECTOR_VIEW_LINES"; matches="$INSPECTOR_MATCHES"
      total="$(wc -l < "$body" 2>/dev/null || printf 0)"
      # A new search starts at its first match, which is what an operator expects.
      if [ -n "${INSPECTOR_SEARCH:-}" ] && [ "$matches" -gt 0 ]; then
        cur=1; offset=$(($(awk 'NR == 1 {print $1}' "$matchf") - 1)); msg="match 1/$matches"
      fi
    fi
    [ "$offset" -lt 0 ] && offset=0
    [ "$offset" -le "$((count > rows ? count - rows : 0))" ] || offset=$((count > rows ? count - rows : 0))
    cline=""
    cline="$(awk -F '\t' -v want="$container" '$2 == want { printf "%s | %s | restarts %s | %s | last exit %s | %s", $2, $3, $4, $5, $6, $7; exit }' "$d/rows" 2>/dev/null)"
    [ -n "$cline" ] || cline="${container:-(no container reported)}"
    pinfo="Pane: $pane | rows $((offset + 1))-$((offset + rows < count ? offset + rows : count))/$count"
    [ "$total" = "$count" ] || pinfo="$pinfo (of $total after filtering)"
    [ -z "${INSPECTOR_SEARCH:-}" ] || {
      if [ "${INSPECTOR_ONLY:-0}" = 1 ]; then pinfo="$pinfo | only /$INSPECTOR_SEARCH: $matches of $total lines"
      else pinfo="$pinfo | search /$INSPECTOR_SEARCH ($matches matching)"; fi; }
    case "${INSPECTOR_LEVEL_NAME:-all}" in all) ;; *) pinfo="$pinfo | level $INSPECTOR_LEVEL_NAME" ;; esac
    [ "$follow" = 1 ] && pinfo="$pinfo | follow ${INSPECTOR_FOLLOW_SECS:-5}s"
    printf '\033[H\033[2J Context: %s\n Namespace: %s | Pod: %s\n Container: %s\n %s\n\n' \
      "${CTX_NAME:-current}" "$ns" "$pod" "${cline:0:$INSPECTOR_COLS}" "${pinfo:0:$INSPECTOR_COLS}"
    inspector_show "$view" "$((offset + 1))" "$((offset + rows))" "$INSPECTOR_COLS" "${COLOR:-1}"
    printf '\033[%s;1H s summary | d describe | e events | ! why | l logs | p previous | c container | ? keys\033[J' "$((INSPECTOR_ROWS - 2))"
    printf '\033[%s;1H / find | & only matches | n N match | L level | f follow(%s) | w export | r reload | q back\033[K' \
      "$((INSPECTOR_ROWS - 1))" "$([ "$follow" = 1 ] && printf on || printf off)"
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
      s) pane=summary ;; d) pane=describe ;; e) pane=events ;; '!') pane=explain ;; l) pane=current ;; p) pane=previous ;;
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
      f) case "$pane" in
           current|previous) follow=$((1 - follow)); reload=1; keep_offset=1; viewdirty=1
             [ "$follow" = 1 ] && msg="follow every ${INSPECTOR_FOLLOW_SECS}s - press f to stop" || msg='follow off' ;;
           *) msg='follow applies to the log panes (l current, p previous)' ;;
         esac ;;
      w) if file="$(inspector_export "$view" "$ns" "$pod" "$container" "$pane" "$total" "$matches")"; then
           msg="exported $count line(s) to $file"
           declare -F audit >/dev/null && audit INSPECT_EXPORT "namespace=$ns pod=$pod container=${container:--} pane=$pane lines=$count search=${INSPECTOR_SEARCH:-none} level=${INSPECTOR_LEVEL_NAME:-all} file=$file"
         else msg='export failed: is the report directory writable?'; fi ;;
      '?') inspector_help ;;
      r) if [ "$pane" = events ] || [ "$pane" = explain ]; then
           # Collection runs in the same cancellable worker on the next pass.
           rm -f -- "$d/events-refreshed"; INSPECTOR_REFRESH_EVENTS=1
         fi
         rows_stale=1; reload=1; keep_offset=1; msg='reloading' ;;
      c) if inspector_container_picker "$ns" "$pod" "$d"; then
           container="$INSPECTOR_CONTAINER"; KDASH_INSPECT_CONTAINER="$container"
           if [ -n "${INSPECTOR_PANE:-}" ]; then pane="$INSPECTOR_PANE"; INSPECTOR_PANE=""; fi
           rows_stale=1; reload=1; viewdirty=1; msg="container: $container"
           declare -F audit >/dev/null && audit INSPECT_CONTAINER "namespace=$ns pod=$pod container=$container pane=$pane"
         else msg='container selection cancelled'; fi ;;
    esac
  done
}

inspector_open() { # optional explicit ns/pod; otherwise a persistent pod picker
  local d="${TMPD:?}/inspector/live" chosen=0 first=0 rows i n line ns pod status ready restarts node
  local items=() picked="${POD_PICK:-}"
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
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    items+=("$line")
    IFS=$'\t' read -r ns pod _ <<< "$line"
    [ "$ns/$pod" != "$picked" ] || chosen=$((${#items[@]} - 1))
  done < <(inspector_model_rows)
  n=${#items[@]}
  while :; do
    inspector_size; rows=$((INSPECTOR_ROWS - 8))
    [ "$chosen" -ge "$first" ] || first=$chosen
    [ "$chosen" -lt "$((first + rows))" ] || first=$((chosen - rows + 1))
    printf '\033[H\033[2J Select pod | Context: %s\n Namespace: %s | %s matching pods\n Selected identity: %s\n\n' "${CTX_NAME:-current}" "${NS:-default}" "$n" "${POD_PICK:-(none)}"
    if [ "$n" = 0 ]; then printf ' No pods match. F edits structured filters; q returns.\n'; fi
    for ((i=first; i<n && i<first+rows; i++)); do
      IFS=$'\t' read -r ns pod status ready restarts node <<< "${items[$i]}"
      line="$(printf '%s %s/%s  %s  ready=%s  restarts=%s  node=%s' "$([ "$i" = "$chosen" ] && printf '>' || printf ' ')" "$ns" "$pod" "$status" "$ready" "$restarts" "$node")"
      printf '%s\n' "${line:0:$INSPECTOR_COLS}"
    done
    printf '\033[%s;1H j/k or arrows select | Enter/i inspect | c containers | F filters | q/Esc dashboard\n Logs are fetched only when you open l/p; search and follow stay inside the pod.\033[J' "$((INSPECTOR_ROWS - 1))"
    inspector_key || break
    case "$INSPECTOR_KEY" in
      q|$'\033') break ;;
      j) [ "$n" = 0 ] || chosen=$(((chosen + 1) % n)) ;;
      k) [ "$n" = 0 ] || chosen=$(((chosen + n - 1) % n)) ;;
      ''|i) if [ "$n" -gt 0 ]; then
        IFS=$'\t' read -r ns pod _ <<< "${items[$chosen]}"; POD_PICK="$ns/$pod"
        inspector_detail "$ns" "$pod" "$d"
      fi ;;
      c) if [ "$n" -gt 0 ]; then
        # Go straight into one container of the highlighted pod.
        IFS=$'\t' read -r ns pod _ <<< "${items[$chosen]}"; POD_PICK="$ns/$pod"
        if inspector_container_picker "$ns" "$pod" "$d"; then
          KDASH_INSPECT_CONTAINER="$INSPECTOR_CONTAINER"
          inspector_detail "$ns" "$pod" "$d"
          KDASH_INSPECT_CONTAINER=""; INSPECTOR_PANE=""
        fi
      fi ;;
      F) inspector_filter_prompt; break ;;
    esac
  done
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
    printf '\033[H\033[2J Structured pod filters | Context: %s | Namespace: %s\n\n' "${CTX_NAME:-current}" "${NS:-default}"
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
  printf '\033[H\033[2J Command palette | Context: %s | Namespace: %s\n\n' "${CTX_NAME:-current}" "${NS:-default}"
  printf ' inspect                 Choose a pod and inspect it\n filter                  Structured pod filters\n pods / nodes / workloads / ip / mem / io / alerts\n services / storage / events / explain / doctor\n help                    Dashboard help\n\n Commands use fixed handlers and never execute shell text.\n\033[?25h : '
  IFS= read -r command </dev/tty || { printf '\033[?25l'; return 1; }; printf '\033[?25l'
  case "$command" in
    '') return 0 ;; inspect|i) inspector_open ;; filter|F) inspector_filter_prompt ;;
    pods|nodes|workloads|ip|mem|io|alerts) VIEW="$command"; SCROLL=0; HSCROLL=0 ;;
    services|storage|events|explain|doctor) VIEW="$command"; TOOLKIT_REQUESTED=1; SCROLL=0; HSCROLL=0 ;;
    help|'?') if declare -F show_help >/dev/null; then show_help; else printf '\n Use ? on the dashboard for help.\n'; fi ;;
    *) declare -F flash >/dev/null && flash "Unknown command: ${command:0:70}" 5; return 2 ;;
  esac
}
