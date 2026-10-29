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

inspector_key() {
  INSPECTOR_KEY=""; local seq=""
  IFS= read -rsn1 INSPECTOR_KEY </dev/tty || return 1
  if [ "$INSPECTOR_KEY" = $'\033' ]; then
    IFS= read -rsn2 -t 0.05 seq </dev/tty || true
    case "$seq" in '[A') INSPECTOR_KEY=k ;; '[B') INSPECTOR_KEY=j ;; '[C') INSPECTOR_KEY=l ;; '[D') INSPECTOR_KEY=b ;; esac
  fi
}

inspector_detail() { # nested UI, q returns to picker without losing identity
  local ns="$1" pod="$2" d="$3" pane=summary oldpane="" offset=0 count=0 container="${KDASH_INSPECT_CONTAINER:-}"
  local body="$3/body" name type image i=0 current=0 containers=() msg="" rows pid rc
  local INSPECTOR_REFRESH_EVENTS=0
  # Existing model inventory avoids an extra blocking API read before showing
  # summary. Include live init/debug containers when inventory is unavailable.
  if [ -r "${MODEL:-}/containers.tsv" ]; then
    awk -F '\t' -v key="$ns/$pod" -v pod="$pod" 'NR>1 && ($1==key || $1==pod) {print "regular\t" $3 "\t-"}' "${MODEL}/containers.tsv" > "$d/containers"
  else : > "$d/containers"; fi
  while IFS=$'\t' read -r type name image; do
    [[ "$name" =~ ^[a-z0-9]([-a-z0-9]*[a-z0-9])?$ ]] || continue
    containers+=("$name"); [ "$name" != "$container" ] || current=$i; i=$((i + 1))
  done < "$d/containers"
  if [ "${#containers[@]}" -gt 0 ]; then container="${containers[$current]}"; else container=""; fi
  while :; do
    inspector_size; rows=$((INSPECTOR_ROWS - 8))
    if [ "$pane" != "$oldpane" ]; then
      offset=0
      printf '\033[H\033[2J Context: %s | Namespace: %s | Pod: %s\n\n Reading %s... (q/Esc cancels)\n' "${CTX_NAME:-current}" "$ns" "$pod" "$pane"
      # Keep navigation available during a slow read. KC supplies request-timeout.
      (
        trap 'for inspector_child in $(jobs -pr); do kill "$inspector_child" 2>/dev/null || true; done; exit 130' TERM INT
        if { [ "$pane" = events ] || [ "$pane" = explain ]; } && declare -F events_collect >/dev/null; then
          if [ ! -f "${TOOLKIT_DIR:-}/events.status" ] || [ "$INSPECTOR_REFRESH_EVENTS" = 1 ]; then events_collect; fi
        fi
        case "$pane" in
          summary)
            inspector_summary "$ns" "$pod" "$body"
            inspector_containers "$ns" "$pod" > "$d/containers.new" 2> "$d/container.err" &
            if wait "$!"; then mv -f -- "$d/containers.new" "$d/containers"; fi ;;
          describe) inspector_query "$body" describe pod "$pod" -n "$ns" ;;
          events) inspector_events "$ns" "$pod" "$body" ;;
          explain) inspector_explain "$ns" "$pod" "$body" ;;
          current|previous)
            if [ -z "$container" ]; then
              inspector_containers "$ns" "$pod" > "$d/containers" 2> "$d/container.err" || true
              container="$(awk -F '\t' 'NF >= 2 {print $2;exit}' "$d/containers")"
            fi
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
      INSPECTOR_REFRESH_EVENTS=0
      containers=(); i=0; current=0
      while IFS=$'\t' read -r type name image; do
        [[ "$name" =~ ^[a-z0-9]([-a-z0-9]*[a-z0-9])?$ ]] || continue
        containers+=("$name"); [ "$name" != "$container" ] || current=$i; i=$((i + 1))
      done < "$d/containers"
      [ "${#containers[@]}" = 0 ] || container="${containers[$current]}"
      oldpane="$pane"
      count="$(wc -l < "$body" 2>/dev/null || printf 0)"
      declare -F audit >/dev/null && audit INSPECT "namespace=$ns pod=$pod pane=$pane container=$container"
    fi
    [ "$offset" -lt 0 ] && offset=0
    [ "$offset" -le "$((count > rows ? count - rows : 0))" ] || offset=$((count > rows ? count - rows : 0))
    printf '\033[H\033[2J Context: %s\n Namespace: %s | Pod: %s\n Pane: %s | Container: %s | rows %s-%s/%s\n\n' \
      "${CTX_NAME:-current}" "$ns" "$pod" "$pane" "${container:-(unavailable)}" "$((offset + 1))" "$((offset + rows < count ? offset + rows : count))" "$count"
    awk -v first="$((offset + 1))" -v last="$((offset + rows))" -v w="$INSPECTOR_COLS" 'NR >= first && NR <= last {print substr($0,1,w)}' "$body"
    printf '\033[%s;1H s summary | d describe | e events | ! why | l logs | p previous\n c next container | r reload | j/k scroll | space/b page | q/Esc back\033[J' "$((INSPECTOR_ROWS - 2))"
    inspector_key || return 0
    case "$INSPECTOR_KEY" in
      q|$'\033') return 0 ;;
      s) pane=summary ;; d) pane=describe ;; e) pane=events ;; '!') pane=explain ;; l) pane=current ;; p) pane=previous ;;
      j) offset=$((offset + 1)) ;; k) offset=$((offset - 1)) ;; ' ') offset=$((offset + rows)) ;; b) offset=$((offset - rows)) ;;
      r) if [ "$pane" = events ] || [ "$pane" = explain ]; then
           # Collection runs in the same cancellable worker on the next pass.
           rm -f -- "$d/events-refreshed"; INSPECTOR_REFRESH_EVENTS=1
         fi
         oldpane="" ;;
      c) if [ "${#containers[@]}" -gt 0 ]; then current=$(((current + 1) % ${#containers[@]})); container="${containers[$current]}"; oldpane=""; fi ;;
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
    printf '\033[%s;1H j/k or arrows select | Enter/i inspect | F filters | q/Esc dashboard\n Logs are fetched only when you open l/p; they are excluded from reports.\033[J' "$((INSPECTOR_ROWS - 1))"
    inspector_key || break
    case "$INSPECTOR_KEY" in
      q|$'\033') break ;;
      j) [ "$n" = 0 ] || chosen=$(((chosen + 1) % n)) ;;
      k) [ "$n" = 0 ] || chosen=$(((chosen + n - 1) % n)) ;;
      ''|i) if [ "$n" -gt 0 ]; then
        IFS=$'\t' read -r ns pod _ <<< "${items[$chosen]}"; POD_PICK="$ns/$pod"
        inspector_detail "$ns" "$pod" "$d"
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
