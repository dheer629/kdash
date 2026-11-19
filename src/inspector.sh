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
  # kubelet has - the older rotated files too, see nodelog_older - up to KDASH_LOG_MAX_BYTES). Nothing is cut sideways: long lines
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

# ---- older log files (rotated by the kubelet) -------------------------------------------
# kubectl logs returns only the NEWEST log file of a container. The kubelet rotates that
# file at containerLogMaxSize (RKE2: 10 MiB) and keeps containerLogMaxFiles of them in
# /var/log/pods/<ns>_<pod>_<uid>/<container>/: <n>.log (being written), <n>.log.<date-time>
# (the newest older one) and <n>.log.<date-time>.gz (older still); <n> = the restart count.
# The older files are read through the API server's node proxy - GET
# /api/v1/nodes/<node>/proxy/logs/pods/... (the kubelet's /logs/ file listing) - when your
# RBAC allows "get nodes/proxy". That is asked once a session with kubectl auth can-i, so a
# user without it causes no failed (403) requests. Read-only; .gz files are unpacked here.
# KDASH_NODE_LOGS=0: never read them.
nodelog_can() { # -> 0 when older files can be read, else NODELOG_WHY says why
  local f="$TMPD/nodelog.can" a
  NODELOG_WHY=""
  [ "${KDASH_NODE_LOGS:-1}" != 0 ] || { NODELOG_WHY="rotated files not read (KDASH_NODE_LOGS=0)"; return 1; }
  if [ ! -s "$f" ]; then
    a="$(KDASH_CMD_TIMEOUT=15 "${KC[@]}" auth can-i get nodes --subresource=proxy 2>/dev/null | head -1)"
    case "$a" in yes|no) printf '%s\n' "$a" > "$f" ;;
      *) NODELOG_WHY="rotated files: nodes/proxy access could not be checked"; return 1 ;; esac
  fi
  [ "$(cat "$f" 2>/dev/null)" = yes ] && return 0
  NODELOG_WHY="rotated files need get nodes/proxy (your RBAC: no)"
  return 1
}
# CRI log lines (containerd, CRI-O): TIME STREAM TAG MESSAGE - TAG P = a partial line that
# goes on in the next one, F = the end of a line; docker json-file lines {"log":..,"time":..}.
# Out: "TIME MESSAGE", as kubectl logs --timestamps prints them.
NODELOG_AWK='
function unj(s,   o, i, c, n) {
  o = ""; n = length(s)
  for (i = 1; i <= n; i++) { c = substr(s, i, 1)
    if (c != "\\") { o = o c; continue }
    i++; c = substr(s, i, 1)
    if (c == "n") o = o "\n"; else if (c == "t") o = o "\t"; else if (c == "u") { o = o "?"; i += 4 } else if (c != "r") o = o c }
  return o }
function jval(s, key,   p, i, c, n, v) {
  p = index(s, "\"" key "\":\""); if (!p) return ""
  s = substr(s, p + length(key) + 4); n = length(s); v = ""
  for (i = 1; i <= n; i++) { c = substr(s, i, 1); if (c == "\\") { v = v c substr(s, i + 1, 1); i++; continue }; if (c == "\"") break; v = v c }
  return v }
substr($0, 1, 8) == "{\"log\":\"" {
  m = unj(jval($0, "log")); t = jval($0, "time"); st = jval($0, "stream")
  if (m ~ /\n$/) { sub(/\n$/, "", m); if (st in pt) { m = pd[st] m; t = pt[st]; delete pd[st]; delete pt[st] }; gsub(/\n/, " ", m); print t " " m }
  else { if (!(st in pt)) pt[st] = t; pd[st] = pd[st] m }
  next }
{ a = index($0, " "); if (!a) next; t = substr($0, 1, a - 1); r = substr($0, a + 1)
  b = index(r, " "); if (!b) next; st = substr(r, 1, b - 1); r = substr(r, b + 1)
  c = index(r, " "); if (c) { tag = substr(r, 1, c - 1); m = substr(r, c + 1) } else { tag = r; m = "" }
  if (tag ~ /P/) { if (!(st in pt)) pt[st] = t; pd[st] = pd[st] m; next }
  if (st in pt) { m = pd[st] m; t = pt[st]; delete pd[st]; delete pt[st] }
  print t " " m }
END { for (st in pt) print pt[st] " " pd[st] }'
nodelog_older() { # node pod-dir container instance out [cap] -> out = the older lines, oldest first
  # sets NODELOG_N (files read), NODELOG_ALL (files there), NODELOG_BYTES, NODELOG_WHY; 1 = nothing read
  local node="$1" pdir="$2" c="$3" inst="$4" out="$5" cap="${6:-268435456}" base f n=0 k tot=0 sz rc=0 lt bad="" budget
  lt="${KDASH_LOG_TIMEOUT:-300}"; case "$lt" in ''|*[!0-9]*|0) lt=300 ;; esac
  case "$cap" in ''|*[!0-9]*) cap=268435456 ;; esac
  base="/api/v1/nodes/$node/proxy/logs/pods/$pdir/$c"
  NODELOG_N=0; NODELOG_ALL=0; NODELOG_BYTES=0; NODELOG_CAPPED=0; NODELOG_WHY=""; : > "$out"
  KDASH_CMD_TIMEOUT=30 "${KC[@]}" get --raw "$base/" --request-timeout=25s > "$out.lst" 2> "$out.err" || rc=$?
  if [ "$rc" != 0 ]; then
    if grep -qi forbidden "$out.err"; then NODELOG_WHY="rotated files on node $node: no access (nodes/proxy)"
    else NODELOG_WHY="rotated files on node $node could not be listed ($(head -1 "$out.err" | inspector_clean | cut -c1-90))"; fi
    rm -f -- "$out.lst" "$out.err"; return 1
  fi
  # this instance's older files, newest first: <instance>.log.<YYYYmmdd-HHMMSS>[.gz]
  grep -o 'href="[^"]*"' "$out.lst" | sed 's/^href="//; s/"$//' | grep -E "^${inst}\\.log\\.[0-9]{8}-[0-9]{6}(\\.gz)?\$" | LC_ALL=C sort -r > "$out.names"
  NODELOG_ALL=$(awk 'END { print NR }' "$out.names")
  if [ "$NODELOG_ALL" = 0 ]; then rm -f -- "$out.lst" "$out.err" "$out.names"; return 1; fi
  # newest first until KDASH_LOG_MAX_BYTES, so a cap drops the oldest lines, never the newest
  while IFS= read -r f; do
    [ "$tot" -lt "$cap" ] || break
    budget=$((cap - tot))
    case "$f" in
      *.gz) KDASH_CMD_TIMEOUT=$((lt + 5)) "${KC[@]}" get --raw "$base/$f" --request-timeout="${lt}s" 2>> "$out.err" | gzip -dc 2>> "$out.err" | LC_ALL=C awk "$NODELOG_AWK" | tail -c "$((budget + 1))" > "$out.$n"
            [ "${PIPESTATUS[0]}${PIPESTATUS[1]}" = 00 ] || bad="${bad:+$bad, }$f" ;;
      *)    KDASH_CMD_TIMEOUT=$((lt + 5)) "${KC[@]}" get --raw "$base/$f" --request-timeout="${lt}s" 2>> "$out.err" | LC_ALL=C awk "$NODELOG_AWK" | tail -c "$((budget + 1))" > "$out.$n"
            [ "${PIPESTATUS[0]}" = 0 ] || bad="${bad:+$bad, }$f" ;;
    esac
    sz=$(wc -c < "$out.$n" | tr -d ' ')
    if [ "$sz" -gt "$budget" ]; then
      # Retain the newest complete lines of the oldest selected file. In
      # particular one unusually large rotation must not bypass the byte cap.
      tail -c "$((budget + 1))" "$out.$n" | LC_ALL=C awk 'NR > 1' > "$out.trim"
      mv -f -- "$out.trim" "$out.$n"
      sz=$(wc -c < "$out.$n" | tr -d ' '); NODELOG_CAPPED=1
    fi
    tot=$((tot + sz)); n=$((n + 1))
    [ "$NODELOG_CAPPED" = 0 ] || break
  done < "$out.names"
  for ((k = n - 1; k >= 0; k--)); do cat -- "$out.$k" >> "$out"; rm -f -- "$out.$k"; done
  NODELOG_N=$n; NODELOG_BYTES=$tot
  [ -z "$bad" ] || NODELOG_WHY="not read in full: $bad ($(head -1 "$out.err" | inspector_clean | cut -c1-80))"
  rm -f -- "$out.lst" "$out.err" "$out.names"
  [ "$n" -gt 0 ]
}
# Summarize a completed proxy read independently of the current log's exit code.
# Permission to try the node proxy is not evidence that any older files were read.
nodelog_result() { # metadata-file -> NODELOG_RESULT, NODELOG_READ
  local on=0 oa=0 capped=0 why=""
  NODELOG_READ=0; NODELOG_RESULT="rotated history not searched"
  [ -s "$1" ] || return 0
  IFS=$'\t' read -r on oa capped why < "$1" || true
  NODELOG_READ="${on:-0}"
  if [ -n "$why" ]; then NODELOG_RESULT="rotated history incomplete: $why"
  elif [ "$NODELOG_READ" -gt 0 ]; then
    NODELOG_RESULT="with $NODELOG_READ older file$([ "$NODELOG_READ" = 1 ] || printf s) from the node"
    [ "$NODELOG_READ" -ge "${oa:-0}" ] || NODELOG_RESULT+=" ($((oa - NODELOG_READ)) oldest not read)"
  elif [ "${oa:-0}" = 0 ]; then NODELOG_RESULT="no rotated files found on node"
  else NODELOG_RESULT="rotated history not read"; fi
  [ "${capped:-0}" != 1 ] || NODELOG_RESULT+=", oldest lines omitted at byte cap"
}
inspector_older() { # ns pod container current|previous out -> the older lines of that container instance
  local ns="$1" pod="$2" c="$3" mode="$4" out="$5" info uid node rs inst
  NODELOG_N=0; NODELOG_ALL=0; NODELOG_CAPPED=0; NODELOG_NODE=""
  nodelog_can || return 1
  info="$(KDASH_CMD_TIMEOUT=20 "${KC[@]}" get pod "$pod" -n "$ns" -o 'jsonpath={.metadata.uid}{"\t"}{.spec.nodeName}{"\t"}{range .status.containerStatuses[*]}{.name}{"="}{.restartCount}{" "}{end}{range .status.initContainerStatuses[*]}{.name}{"="}{.restartCount}{" "}{end}' 2>/dev/null)"
  IFS=$'\t' read -r uid node rs <<< "$info"
  if [ -z "$uid" ] || [ -z "$node" ]; then NODELOG_WHY="rotated files: the node or uid of the pod is not known"; return 1; fi
  inst="$(printf '%s\n' $rs | awk -F '=' -v c="$c" '$1 == c { print $2; exit }')"
  case "$inst" in ''|*[!0-9]*) inst=0 ;; esac
  [ "$mode" != previous ] || inst=$((inst - 1))
  [ "$inst" -ge 0 ] || return 1
  NODELOG_NODE="$node"
  nodelog_older "$node" "${ns}_${pod}_${uid}" "$c" "$inst" "$out" "${INSPECTOR_BYTES:-${KDASH_LOG_MAX_BYTES:-268435456}}"
}
# the time of the first line of a log ("2026-11-18 09:12:01"), for "since ..."
log_since() { LC_ALL=C awk 'NR == 1 { if ($1 ~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]/) print substr($1, 1, 10) " " substr($1, 12, 8); exit }' "$1" 2>/dev/null; }

inspector_logs() { # ns pod container current|previous output-file
  local ns="$1" pod="$2" container="$3" mode="$4" dest="$5" rc=0
  local flags=()
  case "$mode" in current) ;; previous) flags+=(--previous) ;; *) printf 'Invalid log mode: current or previous required.\n' > "$dest"; return 2 ;; esac
  [[ "$container" =~ ^[a-z0-9]([-a-z0-9]*[a-z0-9])?$ ]] || {
    printf 'Choose a valid container before reading logs.\n' > "$dest"; return 2;
  }
  inspector_limits
  # A log is a stream that can take long over a slow link: the general request timeout
  # (seconds) and the 12 s command cap would cut it off and leave a log without its
  # newest lines. Log reads get their own limit (KDASH_LOG_TIMEOUT, default 300 s).
  local lt="${KDASH_LOG_TIMEOUT:-300}"; case "$lt" in ''|*[!0-9]*|0) lt=300 ;; esac
  # the whole log: first the older files the kubelet rotated (on the node), then the current one
  local older=0 since more=0 oldcut=0
  NODELOG_WHY=""; NODELOG_N=0; NODELOG_ALL=0; NODELOG_CAPPED=0; NODELOG_NODE=""
  if [ "$INSPECTOR_TAIL" = -1 ] && inspector_older "$ns" "$pod" "$container" "$mode" "$dest.older"; then older=1; fi
  KDASH_CMD_TIMEOUT=$((lt + 5)) INSPECTOR_QUERY_CAP="$INSPECTOR_BYTES" INSPECTOR_QUERY_NOTE=logs inspector_query "$dest.body" logs "$pod" -n "$ns" -c "$container" \
    --tail="$INSPECTOR_TAIL" --limit-bytes="$INSPECTOR_BYTES" --timestamps=true "${flags[@]}" --request-timeout="${lt}s" || rc=$?
  if [ "$older" = 1 ]; then
    cat -- "$dest.older" "$dest.body" > "$dest.merged"
    # The cap applies to the combined history, rather than once per file. The
    # current file stays newest; trim only the older end and whole text lines.
    if [ "$(wc -c < "$dest.merged")" -gt "$INSPECTOR_BYTES" ]; then
      tail -c "$((INSPECTOR_BYTES + 1))" "$dest.merged" | LC_ALL=C awk 'NR > 1' > "$dest.body"; oldcut=1
      rm -f -- "$dest.merged"
    else mv -f -- "$dest.merged" "$dest.body"; fi
  fi
  rm -f -- "$dest.older"
  # what was read, for the status rule: lines, bytes, since when, whether a limit was reached
  local nl nb; nl=$(awk '/^Read failed \(exit [0-9]+\)\. Verify the namespace/ { exit } { n++ } END { print n + 0 }' "$dest.body"); nb=$(wc -c < "$dest.body" | tr -d ' ')
  since="$(log_since "$dest.body")"
  INSPECTOR_LOGINFO="$nl lines $(xfer_hsize "$nb")${since:+ since $since}"
  if [ "$rc" != 0 ] && [ "$nl" -gt 0 ]; then
    # the read stopped part way: say so - the newest lines are the ones missing
    case "$rc" in 124|137) INSPECTOR_LOGINFO+=", INCOMPLETE: stopped after ${lt}s (KDASH_LOG_TIMEOUT), newest lines missing - r retries" ;;
                  *) INSPECTOR_LOGINFO+=", INCOMPLETE: the read failed (exit $rc), newest lines may be missing - r retries" ;; esac
  elif [ -f "$dest.body.capped" ]; then
    # kubectl cuts at the byte limit from the start of what was asked: the end is missing
    INSPECTOR_LOGINFO+=", $(xfer_hsize "$INSPECTOR_BYTES") cap reached - the newest lines are missing (A reads more)"; more=1
  elif [ "$rc" != 0 ]; then :
  elif [ "$INSPECTOR_TAIL" = -1 ]; then
    if [ "$older" = 1 ]; then
      if [ "$NODELOG_CAPPED" = 0 ] && [ "$oldcut" = 0 ] && [ "$NODELOG_N" -ge "$NODELOG_ALL" ] && [ -z "$NODELOG_WHY" ]; then INSPECTOR_LOGINFO+=", whole log: "
      else INSPECTOR_LOGINFO+=", retained history: "; fi
      INSPECTOR_LOGINFO+="$NODELOG_N rotated file$([ "$NODELOG_N" = 1 ] || printf s) from $NODELOG_NODE + $([ "$mode" = previous ] && printf 'its last file' || printf 'the current file')"
      [ "$NODELOG_N" -ge "$NODELOG_ALL" ] || INSPECTOR_LOGINFO+=" ($((NODELOG_ALL - NODELOG_N)) oldest not read: KDASH_LOG_MAX_BYTES)"
      if [ "$NODELOG_CAPPED" = 1 ] || [ "$oldcut" = 1 ]; then INSPECTOR_LOGINFO+=", oldest lines omitted at $(xfer_hsize "$INSPECTOR_BYTES") cap"; fi
      [ -z "$NODELOG_WHY" ] || INSPECTOR_LOGINFO+=" - $NODELOG_WHY"
      declare -F audit >/dev/null && audit LOG_OLDER_FILES "namespace=$ns pod=$pod container=$container node=$NODELOG_NODE files=$NODELOG_N bytes=$NODELOG_BYTES"
    elif [ -n "$NODELOG_WHY" ]; then INSPECTOR_LOGINFO+=", current file only - $NODELOG_WHY"
    else INSPECTOR_LOGINFO+=", whole log (nothing rotated yet)"; fi
  elif [ "$nl" -ge "$INSPECTOR_TAIL" ]; then INSPECTOR_LOGINFO+=", newest only (+ more, A all)"; more=1
  # fewer lines than asked: the whole CURRENT file - the kubelet may have rotated older ones
  elif nodelog_can; then INSPECTOR_LOGINFO+=", current file (/ and A also read the rotated ones)"; more=1
  else INSPECTOR_LOGINFO+=", current file only - $NODELOG_WHY"; fi
  rm -f -- "$dest.body.capped"
  printf '%s' "$INSPECTOR_LOGINFO" > "$dest.info"
  if [ "$more" = 1 ]; then : > "$dest.more"; else rm -f -- "$dest.more"; fi
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
  # byte by byte: a slow link may deliver ESC and the rest of an arrow key apart
  IFS= read -rsn1 -t 0.15 seq </dev/tty || seq=""
  case "$seq" in '['|O) IFS= read -rsn1 -t 0.15 extra </dev/tty || extra=""; seq="[$extra"; extra="" ;; esac
  case "$seq" in
    '[A') INSPECTOR_KEY=k ;; '[B') INSPECTOR_KEY=j ;;
    '[C') INSPECTOR_KEY='<RIGHT>' ;; '[D') INSPECTOR_KEY='<LEFT>' ;;
    '[H') INSPECTOR_KEY=g ;; '[F') INSPECTOR_KEY=G ;;
    '[5'|'[6'|'[1'|'[4')
      IFS= read -rsn1 -t 0.15 extra </dev/tty || true
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
    printf ' Empty Enter clears the search; Esc cancels; Enter applies what you typed.\n'
    printf ' Up / Down recall earlier searches; Left / Right / Home / End edit the text.\n'
    case "$pane" in current|previous)
      [ "${KDASH_SEARCH_ALL_LINES:-1}" = 0 ] || printf ' The whole log is searched: if only the newest lines are loaded, the whole log is read first.\n' ;;
    esac
    printf ' F in the pane searches every container and pod (this pod, its workload or the namespace).\n Current: %s%s\n%s\n' \
      "${INSPECTOR_SEARCH:-none}" "$([ "${INSPECTOR_ONLY:-0}" = 1 ] && printf ' (only matches)' || printf '')" "$msg"
    ui_edit_line line " $([ "$mode" = only ] && printf '&' || printf '/') " search || { printf '\033[?25l'; return 1; }
    printf '\033[?25l'
    case "$line" in q|Q) return 1 ;; esac
    if [ -z "$line" ]; then INSPECTOR_SEARCH=""; INSPECTOR_ONLY=0; return 0; fi
    if inspector_pattern_ok "$line"; then
      INSPECTOR_SEARCH="$line"; INSPECTOR_JUMPED=""
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
  KD_PAT="${INSPECTOR_SEARCH:-}" awk -v icase="$icase" -v lvl="${INSPECTOR_LEVEL_PAT:-}" \
      -v only="${INSPECTOR_ONLY:-0}" -v matchf="$matchf" -v metaf="$view.meta" -v w="$w" -v json="${INSPECTOR_JSON:-0}" '
    BEGIN { pat = ENVIRON["KD_PAT"] }
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
    function readable(line,   ts, rest, m, lv, sp, tag, q) {
      sp = index(line, " "); if (sp < 2) return line
      ts = substr(line, 1, sp - 1); rest = substr(line, sp + 1); tag = ""
      if (substr(rest, 1, 1) == "[" && (q = index(rest, "] ")) > 0) { tag = substr(rest, 1, q + 1); rest = substr(rest, q + 2) }
      if (substr(rest, 1, 1) != "{") return line
      m = jstr(rest, "message"); if (m == "") m = jstr(rest, "msg"); if (m == "") return line
      lv = jstr(rest, "severity"); if (lv == "") lv = jstr(rest, "level")
      if (ts ~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T/) ts = substr(ts, 6, 5) " " substr(ts, 12, 12)
      return ts "  " tag sprintf("%-7s", toupper(lv == "" ? "-" : lv)) "  " m }
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
  KD_PAT="${INSPECTOR_SEARCH:-}" awk -v first="$2" -v last="$3" -v w="$4" -v color="$5" -v hoff="$hoff" -v icase="$icase" '
    BEGIN { pat = ENVIRON["KD_PAT"]; if (icase == "1") pat = tolower(pat) }
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
# The find box of the container list: the cursor goes to the first container whose name,
# type, state, last exit or image matches (a lowercase pattern ignores case). Uses the
# arrays of inspector_container_picker; cnm = how many match, cbad = 1 for a bad pattern.
ctr_find() { # first|next [pattern]
  local i k h re="${2-$UE_T}" ic=0 first=-1 start="$cfrom"
  cnm=0; cbad=0
  [ -n "$re" ] || { [ "${1:-first}" = next ] || chosen=$cfrom; return 0; }
  [ "$re" != "${re,,}" ] || ic=1
  [[ "" =~ $re ]]; [ $? != 2 ] || { cbad=1; return 0; }
  [ "${1:-first}" != next ] || start=$((chosen + 1))
  for ((k = 0; k < n; k++)); do
    i=$(( (start + k) % n ))
    h="${N[i]} ${T[i]} ${ST[i]} ${LX[i]} ${IM[i]}"; [ "$ic" = 0 ] || h="${h,,}"
    if [[ "$h" =~ $re ]]; then cnm=$((cnm + 1)); [ "$first" -ge 0 ] || first=$i; fi
  done
  [ "$first" -lt 0 ] || chosen=$first
}

inspector_container_picker() { # ns pod dir
  local ns="$1" pod="$2" d="$3" purpose="${INSPECTOR_PICK_PURPOSE:-inspect}" chosen=0 top=0 i n line k
  local -a T N RD RS ST LX IM
  local w_n=9 w_t=4 w_r=9 w_s=5 w_l=9 type name ready rst state last image remembered
  local buf pad len rows banner sel stc pr pst prd prs pnd napp=0 ninit=0 ndbg=0 msg="" nrun=0
  local ctyp=0 cfrom=0 cnm=0 cbad=0 cq=""      # the find box (/)
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
    picker_size; rows=$((PK_ROWS - 15)); [ "$ctyp" != 1 ] || rows=$((rows - 3)); [ "$rows" -ge 3 ] || rows=3     # bar, 2 info + blank, frame (4), rule, panel (6), find box (3)
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
    # the containers, framed: # CONTAINER TYPE READY RST STATE LAST-EXIT IMAGE
    bx_init
    local W=$((PK_COLS - 1)) V_="${BX_C}${BX_V}${BX_R}" cell out kk sty
    local -a hd=('#' CONTAINER TYPE READY RST STATE 'LAST EXIT' IMAGE) cells
    local al="rlllrlll"
    bx_layout "$W" 7 2 "$w_n" "$w_t" "$w_r" 3 "$w_s" "$w_l" 20
    local -a cw=("${BX_CW[@]}")
    bx_sep "$W" t "${BX_J[@]}"; line="${BX_LINE/${BX_LT}/${BX_TL}}"; buf+="${line%${BX_RT}${BX_R}}${BX_TR}${BX_R}"$'\033[K\n'
    out="$V_"; for ((kk = 0; kk < 8; kk++)); do
      if [ "${al:kk:1}" = r ]; then printf -v cell " %*s " "${cw[kk]}" "${hd[kk]:0:${cw[kk]}}"; else printf -v cell " %-*s " "${cw[kk]}" "${hd[kk]:0:${cw[kk]}}"; fi
      out+="${PC_B}${cell}${PC_R}${V_}"; done
    buf+="$out"$'\033[K\n'
    bx_sep "$W" x "${BX_J[@]}"; buf+="$BX_LINE"$'\033[K\n'
    local shown=$((n - top < rows ? n - top : rows))
    for ((i = 0; i < shown; i++)); do
      k=$((top + i))
      image="${IM[k]}"
      # without the registry host, as in the shell header: name and tag tell them apart
      case "${image%%/*}" in *.*|*:*|localhost) [ "$image" = "${image%%/*}" ] || image="${image#*/}" ;; esac
      # images: keep the end (name:tag), that is what tells them apart
      [ "${#image}" -le "${cw[7]}" ] || image="~${image:$(( ${#image} - cw[7] + 1 ))}"
      cells=("$((k + 1))" "${N[k]}" "${T[k]}" "${RD[k]}" "${RS[k]}" "${ST[k]}" "${LX[k]}" "$image")
      case "${ST[k]}" in
        Running) stc="$PC_OK" ;; Completed|"no status yet") stc="$PC_D" ;;
        *CrashLoop*|*Error*|*OOMKilled*|*ImagePull*|*ErrImage*|*ConfigError*) stc="$PC_BAD" ;; *) stc="$PC_WARN" ;;
      esac
      local dim=""; [ -n "$banner" ] && [ "${ST[k]}" != Running ] && dim="$PC_D"   # not attachable
      if [ "$k" = "$chosen" ]; then out="$V_${PC_INV}${PC_B}"; else out="$V_"; fi
      for ((kk = 0; kk < 8; kk++)); do
        if [ "${al:kk:1}" = r ]; then printf -v cell " %*s " "${cw[kk]}" "${cells[kk]:0:${cw[kk]}}"; else printf -v cell " %-*s " "${cw[kk]}" "${cells[kk]:0:${cw[kk]}}"; fi
        if [ "$k" = "$chosen" ]; then out+="$cell"; [ "$kk" = 7 ] || out+="$BX_V"; continue; fi
        sty="$dim"
        if [ -z "$dim" ]; then case "$kk" in
          1) sty="$PC_B" ;; 2) sty="$PC_D" ;; 3) [ "${RD[k]}" = ready ] && sty="$PC_OK" || sty="$PC_WARN" ;;
          4) { [ "${RS[k]}" = 0 ] || [ "${RS[k]}" = "?" ]; } || sty="$PC_WARN" ;; 5) sty="$stc" ;;
          6) [ "${LX[k]}" = - ] && sty="$PC_D" || sty="$PC_BAD" ;; 7) sty="$PC_D" ;; esac; fi
        if [ -n "$sty" ]; then out+="${sty}${cell}${PC_R}${V_}"; else out+="${cell}${V_}"; fi
      done
      [ "$k" != "$chosen" ] || out+="${PC_R}${V_}"
      buf+="$out"$'\033[K\n'
    done
    bx_sep "$W" b "${BX_J[@]}"; line="${BX_LINE/${BX_LT}/${BX_BL}}"; buf+="${line%${BX_RT}${BX_R}}${BX_BR}${BX_R}"$'\033[K\n'
    for ((i = shown; i < rows; i++)); do buf+=$'\033[K\n'; done
    if [ "$ctyp" = 1 ]; then
      local cbr="$cnm of $n containers match"
      [ -n "$UE_T" ] || cbr="type: name, type, state or image"
      [ "$cbad" = 0 ] || cbr="not a valid pattern yet"
      [ -z "$UE_T" ] || [ "$cbad" = 1 ] || [ "$cnm" != 0 ] || cbr="no container matches"
      ue_view $((PK_COLS - 9))
      ui_search_box "$PK_COLS" "FIND CONTAINER" "$cbr" "/ $UE_VIS" $((UE_CUR + 2)) "Enter keep   Tab next match   Up/Down earlier   Esc back"
      buf+="$UI_SBOX"$'\n'
    fi
    # status rule: a message when there is one, otherwise where the cursor is
    if [ -n "$msg" ]; then ui_vlen "$msg"; [ "$UI_VL" -le $((PK_COLS - 8)) ] || { msg="${msg:0:$((PK_COLS - 10))}~"; ui_vlen "$msg"; }
      ui_rule "$((PK_COLS - 1))" "${PC_WARN}${msg}${PC_R}" "$UI_VL" "" 0
    else ui_vlen "$((chosen + 1)) / $n"; ui_rule "$((PK_COLS - 1))" "${PC_B}$((chosen + 1))${PC_R}${PC_D} / ${n}${PC_R}" "$UI_VL" "${PC_D}audited${PC_R}" 7; fi
    buf+="$UI_RULE"$'\033[K\n'
    local act; case "$purpose" in shell) act="open a shell in it" ;; up) act="upload into it" ;; down) act="download from it" ;; *) act="inspect it" ;; esac
    local okc=1; [ -n "$banner" ] && [ "${ST[chosen]}" != Running ] && okc=0
    if [ -n "$banner" ]; then
      bx_panel "$PK_COLS" 4 MOVE CHOOSE "$([ "$purpose" = shell ] && echo 'IN THE SHELL' || echo 'NEXT')" LEAVE \
        "j/k ${PC_UP}${PC_DN}|move|1" "g / G|first / last|1" "1-9|pick by number|1" "/ n|find, next match|1" \
        "Enter|${act}|$okc" "|only running ones can be used|0" "|$napp app$([ "$ninit" = 0 ] || echo ", $ninit init")$([ "$ndbg" = 0 ] || echo ", $ndbg debug")|0" "|runs with your RBAC, audited|0" \
        "$([ "$purpose" = shell ] && echo exit)|$([ "$purpose" = shell ] && echo 'back to kdash' || echo 'browse the container')|1" "$([ "$purpose" = shell ] && echo kdswitch)|$([ "$purpose" = shell ] && echo 'related pods' || echo 'pick files, review')|1" \
        "$([ "$purpose" = shell ] && echo kdquit)|$([ "$purpose" = shell ] && echo 'leave kdash' || echo 'then confirm or cancel')|1" "||0" \
        "q / Esc|back|1" "Q|quit kdash|1" ">|export to a log|1" "||0"
    else
      bx_panel "$PK_COLS" 4 MOVE INSPECT LOGS LEAVE \
        "j/k ${PC_UP}${PC_DN}|move|1" "g / G|first / last|1" "1-9|open by number|1" "/ n|find, next match|1" \
        "Enter / i|summary of it|1" "|$napp app$([ "$ninit" = 0 ] || echo ", $ninit init")$([ "$ndbg" = 0 ] || echo ", $ndbg debug")|0" "||0" "||0" \
        "l|logs|1" "p|previous logs|1" "||0" "||0" \
        "q / Esc|back|1" "Q|quit kdash|1" ">|export to a log|1" "||0"
    fi
    buf+="$BX_PANEL"
    ui_flush "$buf" "ctrpick:$PK_COLS:$PK_ROWS:$ctyp" "${CTP_FL:-1}"; CTP_FL=1
    if [ "$ctyp" = 1 ]; then
      # keys of the find box; keys typed ahead are taken together, then the list is drawn once
      while :; do
        ue_key
        case "$UE_ACT" in edit) ctr_find first ;; tab) ctr_find next ;; enter|cancel) break ;; esac
        read -t 0 </dev/tty 2>/dev/null || break
      done
      CTP_FL=0
      case "$UE_ACT" in
        enter) ctyp=0; ue_remember; cq="$UE_T"; [ -z "$cq" ] || [ "$cbad" = 1 ] || msg="$cnm of $n containers match /$cq - n next match" ;;
        cancel) ctyp=0; chosen=$cfrom; msg="find cancelled" ;;
      esac
      continue
    fi
    picker_key 60 || continue
    case "$PK_KEY_IN" in j|k|g|G|'<UP>'|'<DN>'|'<HOME>'|'<END>') CTP_FL=0 ;; esac
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
      /) cfrom=$chosen; cnm=0; cbad=0; ctyp=1; ue_begin ctrfind "" ;;
      '>') { printf 'TYPE\tCONTAINER\tREADY\tRESTARTS\tSTATE\tLAST EXIT\tIMAGE\n'; cat -- "$d/rows"; } | qx_align > "$d/qx.tsv"
           quick_export "containers_$pod" "container list | pod $ns/$pod | $n containers" "$d/qx.tsv" "EVERY CONTAINER OF THE POD"; msg="$QX_MSG" ;;
      n) if [ -n "$cq" ]; then cfrom=$chosen; ctr_find next "$cq"; msg="$cnm of $n containers match /$cq"; [ "$cnm" != 0 ] || msg="no container matches /$cq"
         else msg="/ finds a container by name, type, state or image"; fi ;;
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
  printf '  w  export what you see       q Esc  back                ?  this help\n'
  printf '  >  quick export to a log file: the screen and the whole pane (KDASH_EXPORT_DIR)\n\n'
  printf ' LONG AND MANY LINES\n'
  printf '  W  wrap on/off: on (default) shows every line in full; off cuts at the edge, <- -> pan\n'
  printf '  J  readable JSON: time, level and message of JSON log lines; J again shows them raw\n'
  printf '  +  read 4x more lines        A  read the whole log, the older files the kubelet rotated too (KDASH_LOG_MAX_BYTES)\n'
  printf '     older files are on the node: read with get nodes/proxy when your RBAC allows it (KDASH_NODE_LOGS=0: never)\n'
  printf '     the rule shows what was read and since when: "newest only", "current file", "whole log: 3 rotated files + the current file"\n\n'
  printf ' S  shell in the container    U  upload a file             D  download a file\n'
  printf ' S/U/D need --allow-interactive: they run in your name and are audited writes.\n'
  printf ' / keeps the context around every match and highlights it; & hides everything else.\n'
  printf ' A search covers the whole log: / reads all of it first (the rotated files too, with get nodes/proxy), so the count covers every line.\n'
  printf ' F searches the logs of every container of this pod, its workload or the namespace (and the\n'
  printf ' previous instance of restarted containers); matches of all logs are merged in time order.\n'
  printf ' Prompts: Up / Down recall earlier entries, Left / Right / Home / End edit, Esc cancels.\n'
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
    current) printf 'LOGS' ;; previous) printf 'PREVIOUS LOGS' ;; found) printf 'FIND IN LOGS' ;; *) printf '%s' "$1" | tr '[:lower:]' '[:upper:]' ;;
  esac
}
# The pod detail key rows: three groups (PANES, READ, MOVE) of whole "<key> label"
# pairs; a group that does not fit the width continues on the next row -> IK_LINES
inspector_keylines() {
  local s_w=off s_j=off s_f=off
  [ "${INSPECTOR_WRAP:-1}" != 1 ] || s_w=on; [ "${INSPECTOR_JSON:-0}" != 1 ] || s_j=on; [ "${follow:-0}" != 1 ] || s_f=on
  IK_LINES=()
  # wide, tall screens: one framed panel, seven aligned columns; otherwise the wrapped rows
  if [ "${INSPECTOR_COLS:-100}" -ge 128 ] && [ "${INSPECTOR_ROWS:-24}" -ge 30 ] && [ "${KDASH_KEYS:-panel}" != compact ]; then
    local ln
    bx_panel "$INSPECTOR_COLS" 7 "PANES" "LOGS" "ATTACH" "READ" "MOVE" "FIND" "OTHER" \
      "s|summary|1" "d|describe|1" "e|events|1" "!|why|1" \
      "l|logs|1" "p|prev logs|1" "c|container|1" "f|follow $s_f|1" \
      "S|shell|1" "U|upload|1" "D|download|1" ">|export log|1" \
      "W|wrap $s_w|1" "J|JSON $s_j|1" "L|level ${INSPECTOR_LEVEL_NAME:-all}|1" "+|4x lines|1" \
      "j/k|scroll|1" "g/G|top / end|1" "left/right|pan|1" "A|all lines|1" \
      "/|find|1" "&|only matches|1" "n/N|next / prev|1" "F|all pods' logs|1" \
      "r|reload|1" "?|keys|1" "q|back|1" "Q|quit|1"
    while IFS= read -r ln; do IK_LINES+=("${ln%$'\033[K'}"); done <<< "$BX_PANEL"
    return 0
  fi
  _ik_group PANES s summary d describe e events "!" why l logs p "prev logs" c container S shell U upload D download
  _ik_group READ W "wrap $s_w" J "JSON $s_j" \
    "+" "4x lines" A "all lines" "left/right" pan f "follow $s_f" L "level ${INSPECTOR_LEVEL_NAME:-all}" ">" "export log" w "export text"
  _ik_group MOVE / find "&" "only matches" "n/N" "next / prev" F "all pods' logs" "j/k" scroll g/G "top / end" r reload "?" keys q back Q quit
}
_ik_group() { # title pairs...
  local w=$((${INSPECTOR_COLS:-100} - 1)) line used=7 k a add
  printf -v line '%s%-5s%s  ' "$PC_D" "$1" "$PC_R"; shift
  while [ $# -ge 2 ]; do
    k=$1; a=$2; shift 2
    ui_vlen "<$k> $a"; add=$((UI_VL + 2))
    if [ $((used + add)) -gt "$w" ] && [ "$used" -gt 7 ]; then IK_LINES+=("$line"); line="       "; used=7; fi
    line+="${PC_B}<${k}>${PC_R} ${a}  "; used=$((used + add))
  done
  IK_LINES+=("$line")
}
# F in pod detail: search the logs of every container - this pod, every pod of its
# workload, or every pod of the namespace. Each container's current log is read in full
# (KDASH_LOG_MAX_BYTES, KDASH_LOG_TIMEOUT), plus the previous instance of a container
# that restarted. Reads run in parallel (KDASH_FIND_PARALLEL, default 4); Esc stops and
# keeps what was found. The result is a pane: a table of what was read (lines, matches,
# result per log - "no access" when RBAC forbids pods/log) and the matching lines of all
# logs merged in time order, each tagged [pod/container]. Read-only, like every log read.
inspector_find_all() { # ns pod dir -> d/found, d/found.info; 0 = a result was written
  local ns="$1" pod="$2" d="$3" fd="$3/find" key="" scope="" pat="" icase=0 lt mx per par
  local pl="$3/find.pods" owner="" wl="" n_pod=0 n_wl=0 n_ns=0 l_pod=0 l_wl=0 l_ns=0 i n run done_ hits t0 c kk label stopped=0 t_
  lt="${KDASH_LOG_TIMEOUT:-300}"; case "$lt" in ''|*[!0-9]*|0) lt=300 ;; esac
  mx="${KDASH_LOG_MAX_BYTES:-268435456}"; case "$mx" in ''|*[!0-9]*) mx=268435456 ;; esac
  per="${KDASH_FIND_MAX_LINES:-5000}"; case "$per" in ''|*[!0-9]*|0) per=5000 ;; esac
  par="${KDASH_FIND_PARALLEL:-4}"; case "$par" in ''|*[!0-9]*|0) par=4 ;; esac; [ "$par" -le 16 ] || par=16
  ui_screen "FIND IN LOGS" "$ns/$pod"
  printf ' %sreading the pod list of %s ...%s\n' "$PC_D" "$ns" "$PC_R"
  # name, owner, containers, restart count per container: one list read for all scopes
  "${KC[@]}" get pods -n "$ns" -o 'jsonpath={range .items[*]}{.metadata.name}{"\t"}{.metadata.ownerReferences[0].kind}{"/"}{.metadata.ownerReferences[0].name}{"\t"}{range .spec.containers[*]}{.name}{" "}{end}{"\t"}{range .status.containerStatuses[*]}{.name}{"="}{.restartCount}{" "}{end}{"\t"}{.metadata.uid}{"\t"}{.spec.nodeName}{"\n"}{end}' \
    2> "$pl.err" | inspector_clean > "$pl.raw" || true
  # the workload of a ReplicaSet pod is its Deployment (the ReplicaSet name less the hash)
  awk -F '\t' '
    NF >= 3 { o = $2; if (o ~ /^ReplicaSet\//) { sub(/^ReplicaSet\//, "Deployment/", o); sub(/-[a-z0-9]+$/, "", o) }
      if (o == "/") o = ""
      n = split($3, C, " "); cs = ""
      for (i = 1; i <= n; i++) if (C[i] != "") cs = cs (cs == "" ? "" : " ") C[i]
      m = split($4, R, " "); rs = ""
      for (i = 1; i <= m; i++) if (R[i] ~ /=[1-9][0-9]*$/) { sub(/=.*/, "", R[i]); rs = rs " " R[i] " " }
      print $1 "\t" o "\t" cs "\t" rs "\t" $4 "\t" $5 "\t" $6 }' "$pl.raw" > "$pl"
  owner="$(awk -F '\t' -v p="$pod" '$1 == p { print $2; exit }' "$pl")"
  # logs per scope: one per container, plus one per restarted container (previous)
  _ifa_count() { awk -F '\t' -v sel="$1" -v p="$pod" -v o="$owner" '
      (sel == "pod" && $1 == p) || (sel == "wl" && o != "" && $2 == o) || (sel == "wl" && o == "" && $1 == p) || sel == "ns" {
        np++; n = split($3, C, " "); for (i = 1; i <= n; i++) { nl++; if (index($4, " " C[i] " ")) nl++ } }
      END { print np + 0, nl + 0 }' "$pl"; }
  read -r n_pod l_pod <<< "$(_ifa_count pod)"; read -r n_wl l_wl <<< "$(_ifa_count wl)"; read -r n_ns l_ns <<< "$(_ifa_count ns)"
  if [ "$n_pod" = 0 ]; then          # the list could not be read: this pod and its known container only
    printf '%s\t\t%s\t\n' "$pod" "${KDASH_INSPECT_CONTAINER:-}" > "$pl"; n_pod=1; l_pod=1; n_wl=1; l_wl=1; n_ns=1; l_ns=1
  fi
  while :; do
    ui_screen "FIND IN LOGS" "$ns/$pod"
    printf ' Search the full current log of every container, and the previous log of each container that restarted.\n\n'
    printf '   %sp%s  this pod        %-44s %4s container log(s)\n' "$PC_B" "$PC_R" "$pod" "$l_pod"
    if [ -n "$owner" ]; then printf '   %sw%s  its workload    %-44s %4s pod(s), %s log(s)\n' "$PC_B" "$PC_R" "${owner/\// }" "$n_wl" "$l_wl"
    else printf '   %sw%s  its workload    %s(no owner - the same as p)%s\n' "$PC_D" "$PC_R" "$PC_D" "$PC_R"; fi
    printf '   %sn%s  the namespace   %-44s %4s pod(s), %s log(s)\n\n' "$PC_B" "$PC_R" "$ns" "$n_ns" "$l_ns"
    [ ! -s "$pl.err" ] || printf ' %spod list: %s%s\n\n' "$PC_WARN" "$(head -c 160 "$pl.err" | tr '\n' ' ')" "$PC_R"
    if nodelog_can; then printf ' %sOlder log files will also be requested from the nodes (get nodes/proxy, read-only); results show what was accessible.%s\n' "$PC_D" "$PC_R"
    else printf ' %sNot searched: the older log files the kubelet rotated - %s.%s\n' "$PC_D" "$NODELOG_WHY" "$PC_R"; fi
    printf ' %sEsc cancels.%s\n\n\033[?25h > ' "$PC_D" "$PC_R"
    key=""; IFS= read -rsn1 key </dev/tty || return 1
    case "$key" in
      p|P) scope=pod; label="pod $pod"; break ;;
      w|W) scope=wl; if [ -n "$owner" ]; then label="${owner/\// }"; else label="pod $pod"; fi; break ;;
      n|N) scope=ns; label="namespace $ns"; break ;;
      $'\033'|q) IFS= read -rsn2 -t 0.05 _ </dev/tty || true; printf '\033[?25l'; return 1 ;;
    esac
  done
  printf '%s\n\n' "$label"
  printf ' Extended regular expression; a lowercase pattern ignores case. Up / Down recall earlier searches.\n'
  while :; do
    ui_edit_line pat " find / " search "${INSPECTOR_SEARCH:-}" || { printf '\033[?25l'; return 1; }
    [ -n "$pat" ] || { printf '\033[?25l'; return 1; }
    inspector_pattern_ok "$pat" && break
    printf ' %sThat is not a valid regular expression - try again.%s\n' "$PC_WARN" "$PC_R"
  done
  icase="$(inspector_icase "$pat")"
  # the list of logs to read: pod TAB container TAB current|previous TAB instance TAB uid TAB node
  # (instance = the restart count: the number of the container's log files on the node)
  rm -rf -- "$fd"; mkdir -p "$fd"
  awk -F '\t' -v sel="$scope" -v p="$pod" -v o="$owner" '
    (sel == "pod" && $1 == p) || (sel == "wl" && o != "" && $2 == o) || (sel == "wl" && o == "" && $1 == p) || sel == "ns" {
      delete RC; m = split($5, M, " "); for (j = 1; j <= m; j++) { q = index(M[j], "="); if (q) RC[substr(M[j], 1, q - 1)] = substr(M[j], q + 1) + 0 }
      n = split($3, C, " "); for (i = 1; i <= n; i++) { r = (C[i] in RC) ? RC[C[i]] : 0
        print $1 "\t" C[i] "\tcurrent\t" r "\t" $6 "\t" $7; if (index($4, " " C[i] " ")) print $1 "\t" C[i] "\tprevious\t" (r - 1) "\t" $6 "\t" $7 } }' "$pl" > "$fd/list"
  n=$(awk 'END { print NR }' "$fd/list")
  [ "$n" -gt 0 ] || { printf ' nothing to read\n'; sleep 1; return 1; }
  declare -F audit >/dev/null && audit LOG_FIND "namespace=$ns pod=$pod scope=$scope logs=$n pattern=$(printf '%s' "$pat" | head -c 120)"
  local -a LP=() LC=() LM=() LI=() LU=() LN=() JP=()
  local ff=1 frame live nlok=0 e_ u_ n_
  while IFS=$'\t' read -r a b c_ e_ u_ n_; do LP+=("$a"); LC+=("$b"); LM+=("$c_"); LI+=("${e_:-0}"); LU+=("${u_:-}"); LN+=("${n_:-}"); done < "$fd/list"
  ! nodelog_can || nlok=1     # older (rotated) log files from the nodes too
  i=0; t0=$SECONDS
  printf '\033[?25l'
  while :; do
    # start reads while fewer than KDASH_FIND_PARALLEL run
    # only this search's own readers count (the dashboard has background jobs too)
    live=(); for c in "${JP[@]}"; do kill -0 "$c" 2>/dev/null && live+=("$c"); done; JP=("${live[@]}"); run=${#JP[@]}
    while [ "$stopped" = 0 ] && [ "$i" -lt "$n" ] && [ "$run" -lt "$par" ]; do
      local src="${LP[i]}/${LC[i]}" fl=()
      [ "${LM[i]}" = previous ] && { src+=" previous"; fl=(--previous); }
      (
        { if [ "$nlok" = 1 ] && [ -n "${LU[i]}" ] && [ -n "${LN[i]}" ] && [ "${LI[i]}" -ge 0 ] 2>/dev/null; then
            ! nodelog_older "${LN[i]}" "${ns}_${LP[i]}_${LU[i]}" "${LC[i]}" "${LI[i]}" "$fd/$i.older" "$mx" || cat -- "$fd/$i.older"
            printf '%s\t%s\t%s\t%s\n' "$NODELOG_N" "$NODELOG_ALL" "$NODELOG_CAPPED" "$NODELOG_WHY" > "$fd/$i.oldn"; rm -f -- "$fd/$i.older"
          elif [ "$nlok" = 1 ]; then
            printf '0\t0\t0\tpod uid, node or container instance unavailable\n' > "$fd/$i.oldn"
          fi
          KDASH_CMD_TIMEOUT=$((lt + 5)) "${KC[@]}" logs "${LP[i]}" -n "$ns" -c "${LC[i]}" "${fl[@]}" --tail=-1 --limit-bytes="$mx" \
            --timestamps=true --request-timeout="${lt}s" 2> "$fd/$i.err"; } |
          KD_PAT="$pat" awk -v icase="$icase" -v src="$src" -v hf="$fd/$i.hits" -v mx="$per" -v mf="$fd/$i.meta" '
            BEGIN { pat = ENVIRON["KD_PAT"]; if (icase == "1") pat = tolower(pat) }
            { n++; l = (icase == "1") ? tolower($0) : $0
              if (l ~ pat) { h++
                if (h <= mx) { sp = index($0, " "); if (sp < 2) sp = 0
                  print (sp ? substr($0, 1, sp - 1) : "-") " [" src "] " (sp ? substr($0, sp + 1) : $0) > hf } } }
            END { printf "%d %d\n", n + 0, h + 0 > mf }'
        printf '%s\n' "${PIPESTATUS[0]}" > "$fd/$i.rc"
      ) &
      JP+=("$!"); i=$((i + 1)); run=$((run + 1))
    done
    done_=$(ls "$fd" 2>/dev/null | grep -c '\.rc$')
    hits=$(cat "$fd"/*.meta 2>/dev/null | awk '{ h += $2 } END { print h + 0 }')
    if [ "${#JP[@]}" = 0 ] && { [ "$i" -ge "$n" ] || [ "$stopped" = 1 ]; }; then break; fi
    # progress: one frame, only changed lines are sent
    picker_colors; picker_size
    ui_bar "$PK_COLS" " KDASH ${PC_SEP} FIND IN LOGS ${PC_SEP} context ${CTX_NAME:-current} ${PC_SEP} namespace $ns " " $label "
    frame=$'\033[H'"$UI_BAR"$'\033[K\n\033[K\n'
    frame+=" /${PC_B}${pat}${PC_R}   $([ "$icase" = 1 ] && printf '(ignore case)' || printf '(case sensitive)')"$'\033[K\n\033[K\n'
    frame+=" ${PC_B}${done_} / ${n}${PC_R} logs read   $((i - done_)) reading   ${PC_B}${hits}${PC_R} matching lines so far   $((SECONDS - t0))s"$'\033[K\n\033[K\n'
    if [ "$stopped" = 1 ]; then frame+=" ${PC_WARN}stopping - reads under way are ended${PC_R}"$'\033[K\n'
    else frame+=" ${PC_D}Esc or q stops: what was found so far is kept.${PC_R}"$'\033[K\n'; fi
    ui_flush "$frame" "find:$PK_COLS:$PK_ROWS" "$ff"; ff=0
    kk=""; IFS= read -rsn1 -t 0.3 kk </dev/tty || true
    if [ "$kk" = $'\033' ]; then             # Esc stops; an arrow key (Esc [ A) does not
      t_=""; IFS= read -rsn1 -t 0.15 t_ </dev/tty || t_=""
      if [ "$t_" = '[' ] || [ "$t_" = O ]; then while IFS= read -rsn1 -t 0.15 t_ </dev/tty; do case "$t_" in [@-~]) break ;; esac; done; kk=""; fi
    fi
    case "$kk" in
      $'\033'|q|Q) stopped=1; for c in "${JP[@]}"; do xfer_stop_tree "$c"; done ;;
    esac
  done
  for c in "${JP[@]}"; do wait "$c" 2>/dev/null; done
  # the result: what was read, then the matching lines of every log in time order
  local nread=0 nlines=0 nhit=0 r ln_ hi_ st w1=6 rc_ olderfiles=0
  for ((c = 0; c < n; c++)); do r="${LP[c]}/${LC[c]}"; [ "${LM[c]}" = current ] || r+=" (previous)"; [ "${#r}" -le "$w1" ] || w1=${#r}; done
  {
    printf '%-*s  %10s  %7s  %s\n' "$w1" "LOG" "LINES" "MATCH" "RESULT"
    for ((c = 0; c < n; c++)); do
      r="${LP[c]}/${LC[c]}"; [ "${LM[c]}" = current ] || r+=" (previous)"
      ln_=-; hi_=-; st="not read (stopped)"
      if [ -f "$fd/$c.rc" ]; then
        read -r ln_ hi_ < "$fd/$c.meta" 2>/dev/null || { ln_=0; hi_=0; }
        rc_=$(cat "$fd/$c.rc")
        if [ "$rc_" = 0 ]; then st=ok; [ "$hi_" -le "$per" ] || st="ok - first $per matches kept (KDASH_FIND_MAX_LINES)"
        elif grep -qi 'forbidden' "$fd/$c.err"; then st="no access (RBAC: pods/log)"
        elif grep -qiE 'waiting to start|ContainerCreating|PodInitializing' "$fd/$c.err"; then st="not started"
        elif grep -qi 'previous terminated container' "$fd/$c.err"; then st="no previous instance"
        else case "$rc_" in 124|137) st="INCOMPLETE: stopped after ${lt}s" ;; 143) st="INCOMPLETE: stopped" ;; *) st="failed: $(head -1 "$fd/$c.err" | head -c 70)" ;; esac
        fi
        nread=$((nread + 1)); nlines=$((nlines + ${ln_:-0})); nhit=$((nhit + ${hi_:-0}))
        [ "$rc_" = 0 ] || [ "${ln_:-0}" != 0 ] || { ln_=-; hi_=-; }
      fi
      if [ "$nlok" = 1 ]; then
        nodelog_result "$fd/$c.oldn"; st+=", $NODELOG_RESULT"; olderfiles=$((olderfiles + NODELOG_READ))
      fi
      printf '%-*s  %10s  %7s  %s\n' "$w1" "$r" "$ln_" "$hi_" "$st"
    done
    if [ "$nlok" = 1 ]; then printf '\nRotated history: %s file(s) read from nodes; per-log coverage and failures appear above.\n' "$olderfiles"
    else nodelog_can || true; printf '\nNot searched: the older log files the kubelet rotated - %s.\n' "$NODELOG_WHY"; fi
    printf 'Matching lines of all logs, oldest first (G jumps to the newest); each line is tagged [pod/container]:\n'
    printf -- '----------------------------------------------------------------------------------------------------\n'
    cat "$fd"/*.hits 2>/dev/null | LC_ALL=C sort -s -k1,1
    [ "$nhit" -gt 0 ] || printf '(no line matched)\n'
  } > "$d/found"
  printf '%s' "/$pat in $label: $nread of $n logs read, $nlines lines, $nhit matching$([ "$stopped" = 0 ] || printf ' - STOPPED EARLY')" > "$d/found.info"
  INSPECTOR_SEARCH="$pat"; INSPECTOR_ONLY=0; INSPECTOR_JUMPED=""
  declare -F audit >/dev/null && audit LOG_FIND_END "namespace=$ns scope=$scope logs=$nread/$n lines=$nlines matches=$nhit stopped=$stopped"
  return 0
}
inspector_detail() { # nested UI; q returns to the picker, keeping the identity
  local ns="$1" pod="$2" d="$3" pane="${INSPECTOR_PANE:-summary}" loaded="" reload=1 viewdirty=1 rows_stale=1
  local body="$3/body" view="$3/view" matchf="$3/matches"
  local offset=0 count=0 total=0 matches=0 msg="" rows pid rc keep_offset=0 follow=0 atbottom=0 vcols=0 hoff=0
  INSPECTOR_JUMPED=""
  local container file="" target=0 idx=0 cline="" pinfo=""
  # speed: one frame per key through ui_flush (only changed lines are sent, no screen clear),
  # and what a scroll key cannot change is not looked up again
  local ifl=1 ptitle="" ptitle_for="" crow="" crow_key="" rgen=0 frame btxt nb t_ lnote="" wrapped=0
  # n / N step from the match they jumped to (ijl), as long as the pane was not scrolled
  # since (ijo = the offset shown after that jump) - a match on the last screen is not
  # at the top, so the offset alone would find the same match again
  local ijl="" ijo="" ijn=0
  # the search box (/ find, & only matching lines): typed in place, matches update as you type
  local ityping=0 ibad=0 sv_search="" sv_only=0
  local iopen="" iwas_t="" iwas_b="" icancel=0    # / waits for the whole log to be read (iopen = / or &)
  container="$(inspect_container_for "$ns" "$pod")"     # never a container of another pod
  local INSPECTOR_REFRESH_EVENTS=0
  INSPECTOR_PANE=""
  inspector_limits          # tail/bytes/follow defaults must exist in this shell too
  while :; do
    # bar + framed header (4), the key rows (3, more when a narrow screen wraps them), 1 message row
    inspector_size; picker_colors; inspector_keylines; rows=$((INSPECTOR_ROWS - 6 - ${#IK_LINES[@]})); [ "$ityping" != 1 ] || rows=$((rows - 3)); [ "$rows" -ge 3 ] || rows=3
    if [ "$loaded" != "$pane" ] || [ "$reload" = 1 ]; then
      picker_colors
      ui_bar "$INSPECTOR_COLS" " KDASH ${PC_SEP} POD DETAIL ${PC_SEP} context ${CTX_NAME:-current} ${PC_SEP} namespace $ns " " $(inspector_pane_title "$pane") "
      printf '\033[H\033[2J%s\n %spod%s        %s%s%s\n\n %sreading %s ...  q / Esc cancels%s\n' "$UI_BAR" "$PC_D" "$PC_R" "$PC_B" "$pod" "$PC_R" "$PC_D" "$pane" "$PC_R"
      [ -z "$lnote" ] || printf ' %s%s%s\n' "$PC_D" "$lnote" "$PC_R"; lnote=""
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
          found) if [ -s "$d/found" ]; then cat "$d/found" > "$body"; else printf 'No search yet: F searches the logs of every container of this pod, its workload or the namespace.\n' > "$body"; fi ;;
        esac
      ) & pid=$!
      while kill -0 "$pid" 2>/dev/null; do
        INSPECTOR_KEY=""; IFS= read -rsn1 -t 0.1 INSPECTOR_KEY </dev/tty || true
        # an arrow or page key pressed while the read runs is not Esc: drop the sequence
        if [ "$INSPECTOR_KEY" = $'\033' ]; then
          t_=""; IFS= read -rsn1 -t 0.15 t_ </dev/tty || t_=""
          if [ "$t_" = '[' ] || [ "$t_" = O ]; then
            while IFS= read -rsn1 -t 0.15 t_ </dev/tty; do case "$t_" in [@-~]) break ;; esac; done
            INSPECTOR_KEY=""
          fi
        fi
        case "$INSPECTOR_KEY" in
          q|b|$'\033')
            kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true
            # the whole-log read that / started: stop it, keep the loaded lines, open the box
            if [ -n "$iopen" ]; then icancel=1; break; fi
            return 0 ;;
          Q) kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; kdash_quit "loading" ;;
          X) interactive_toggle; msg="$INTERACTIVE_MSG" ;;
        esac
      done
      wait "$pid" 2>/dev/null || true
      if [ "$icancel" = 1 ]; then
        INSPECTOR_TAIL_SET="$iwas_t"; INSPECTOR_BYTES_SET="$iwas_b"; [ -n "$iwas_t" ] || unset INSPECTOR_TAIL_SET; [ -n "$iwas_b" ] || unset INSPECTOR_BYTES_SET
        msg="whole-log read stopped - the search covers the $(cat "$body.info" 2>/dev/null)"
      fi
      INSPECTOR_REFRESH_EVENTS=0; rows_stale=0; reload=0; loaded="$pane"; viewdirty=1; ifl=1; rgen=$((rgen + 1))
      if [ -n "$iopen" ]; then         # the read / asked for is done (or stopped): open the box now
        sv_search="${INSPECTOR_SEARCH:-}"; sv_only="${INSPECTOR_ONLY:-0}"; ityping=1; ibad=0
        if [ "$iopen" = '&' ]; then INSPECTOR_ONLY=1; else INSPECTOR_ONLY=0; fi
        ue_begin search ""; INSPECTOR_SEARCH=""; iopen=""; icancel=0
        continue                         # the rows are counted again with the box (3 rows) in them
      fi
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
      # Only when the search text changes: reloads, follow and resizes keep the position.
      if [ -n "${INSPECTOR_SEARCH:-}" ] && [ "$matches" -gt 0 ] && [ "$INSPECTOR_SEARCH" != "${INSPECTOR_JUMPED:-}" ]; then
        cur=1; ijl=$(awk 'NR == 1 {print $1}' "$matchf"); offset=$((ijl - 1)); ijn=1; msg="match 1/$matches"
      elif [ -n "${INSPECTOR_SEARCH:-}" ] && [ "$matches" = 0 ] && [ "$INSPECTOR_SEARCH" != "${INSPECTOR_JUMPED:-}" ]; then
        # say what was searched, so "0" is not mistaken for "everything was searched"
        case "$pane" in
          current|previous) t_="$(cat "$body.info" 2>/dev/null)"
            msg="no match for /$INSPECTOR_SEARCH in ${t_%%,*} of ${container:-the container} - F searches every container and pod"
            case "$t_" in *"current file only - "*) msg+=" (${t_##*current file only - })" ;; esac ;;
          found) msg="no match for /$INSPECTOR_SEARCH" ;;
          *) msg="no match for /$INSPECTOR_SEARCH in this pane ($total lines) - l searches the log, F every container and pod" ;;
        esac
      fi
      INSPECTOR_JUMPED="${INSPECTOR_SEARCH:-}"
    fi
    [ "$offset" -lt 0 ] && offset=0
    [ "$offset" -le "$((count > rows ? count - rows : 0))" ] || offset=$((count > rows ? count - rows : 0))
    [ "$ijn" = 0 ] || { ijo=$offset; ijn=0; }
    picker_colors
    # title bar, pod, container, then a rule that says where in the pane we are
    local c_n="" c_rd="" c_rs="" c_st="" c_lx="" c_im="" stc hdr
    if [ "$crow_key" != "$container:$rgen" ]; then
      crow="$(awk -F '\t' -v want="$container" '$2 == want { print; exit }' "$d/rows" 2>/dev/null)"; crow_key="$container:$rgen"
    fi
    IFS=$'\t' read -r _ c_n c_rd c_rs c_st c_lx c_im <<< "$crow" || true
    [ "$ptitle_for" = "$pane" ] || { ptitle="$(inspector_pane_title "$pane")"; ptitle_for="$pane"; }
    ui_bar "$INSPECTOR_COLS" " KDASH ${PC_SEP} POD DETAIL ${PC_SEP} ${CTX_NAME:-current} ${PC_SEP} $ns " " $ptitle "
    hdr="${UI_BAR}"$'\033[K\n'
    bx_init
    local IW=$((INSPECTOR_COLS - 1)) rinfo="READ-ONLY"
    interactive_enabled && rinfo="INTERACTIVE"
    rinfo+=" / audited"; [ "$follow" = 1 ] && rinfo+=" / follow ${INSPECTOR_FOLLOW_SECS:-5}s"
    bx_top "$IW" "$ptitle" "${PC_D}${rinfo}${PC_R}"; hdr+="$BX_LINE"$'\033[K\n'
    bx_row "$IW" "${PC_D}POD      ${PC_R}  ${PC_B}${pod}${PC_R}"; hdr+="$BX_LINE"$'\033[K\n'
    if [ -n "$c_n" ]; then
      case "$c_st" in Running) stc="$PC_OK" ;; Completed) stc="$PC_D" ;; *CrashLoop*|*Error*|*OOMKilled*|*ImagePull*|*ErrImage*) stc="$PC_BAD" ;; *) stc="$PC_WARN" ;; esac
      case "${c_im%%/*}" in *.*|*:*|localhost) [ "$c_im" = "${c_im%%/*}" ] || c_im="${c_im#*/}" ;; esac
      cline="${PC_D}CONTAINER${PC_R}  ${PC_B}${c_n}${PC_R}   ${stc}${PC_DOT} ${c_st}${PC_R}   ${PC_D}${c_rd}${PC_R}   ${PC_D}restarts${PC_R} ${c_rs}"
      [ "$c_lx" = - ] || [ -z "$c_lx" ] || cline+="   ${PC_D}last exit${PC_R} ${PC_BAD}${c_lx}${PC_R}"
      cline+="   ${PC_D}${c_im}${PC_R}"
    else cline="${PC_D}CONTAINER${PC_R}  ${container:-${PC_D}none reported${PC_R}}"; fi
    bx_row "$IW" "$cline"; hdr+="$BX_LINE"$'\033[K\n'
    # where we are (screen rows), how many lines, what was read and how lines are shown
    pinfo="rows $((count ? offset + 1 : 0))-$((offset + rows < count ? offset + rows : count)) / $count"
    # what was read (log panes: lines, size, complete or not); wrap and JSON state is on the READ key line
    [ "${INSPECTOR_VIEW_LOGICAL:-$total}" = "$total" ] || pinfo="$pinfo ${PC_MID} ${INSPECTOR_VIEW_LOGICAL} shown"
    [ -z "${INSPECTOR_SEARCH:-}" ] || [ "$pane" = found ] || {
      if [ "${INSPECTOR_ONLY:-0}" = 1 ]; then pinfo="$pinfo ${PC_MID} only /$INSPECTOR_SEARCH ($matches)"
      else pinfo="$pinfo ${PC_MID} /$INSPECTOR_SEARCH ($matches matching)"; fi; }
    [ "${INSPECTOR_WRAP:-1}" = 1 ] || [ "$hoff" = 0 ] || pinfo="$pinfo ${PC_MID} pan +$hoff"
    case "${INSPECTOR_LEVEL_NAME:-all}" in all) ;; *) pinfo="$pinfo ${PC_MID} level $INSPECTOR_LEVEL_NAME" ;; esac
    case "$pane" in
      current|previous) if [ -s "$body.info" ]; then pinfo="$pinfo ${PC_MID} $(< "$body.info")"; else pinfo="$pinfo ${PC_MID} $total lines"; fi ;;
      found) pinfo="$pinfo ${PC_MID} $(cat "$d/found.info" 2>/dev/null)" ;;
      *) pinfo="$pinfo ${PC_MID} $total lines" ;;
    esac
    ui_vlen "$pinfo"; [ "$UI_VL" -le $((INSPECTOR_COLS - 12)) ] || { pinfo="${pinfo:0:$((INSPECTOR_COLS - 14))}~"; }
    bx_bot "$IW" "${PC_B}${pinfo}${PC_R}" ""
    frame=$'\033[H'"${hdr}${BX_LINE}"$'\033[K\n'
    if [ "${INSPECTOR_WRAP:-1}" = 1 ]; then t_=0; else t_=$hoff; fi
    btxt="$(inspector_show "$view" "$((offset + 1))" "$((offset + rows))" "$INSPECTOR_COLS" "${COLOR:-1}" "$t_"; printf x)"; btxt="${btxt%x}"
    t_="${btxt//[!$'\n']/}"; nb=${#t_}
    frame+="${btxt//$'\n'/$'\033[K\n'}"
    for ((; nb < rows; nb++)); do frame+=$'\033[K\n'; done
    # k9s-style hints: panes, reading tools, moving / leaving (framed panel, or wrapped rows on small screens)
    local kl
    if [ "$ityping" = 1 ]; then
      local sbt="SEARCH" sbr sbk="Enter keep   Tab only matching lines   Up/Down earlier   Esc cancel"
      [ "${INSPECTOR_ONLY:-0}" != 1 ] || { sbt="SHOW ONLY MATCHING LINES"; sbk="Enter keep   Tab all lines with the matches marked   Up/Down earlier   Esc cancel"; }
      sbr="$matches matching line$([ "$matches" = 1 ] || printf s) of $total"
      [ -n "$UE_T" ] || sbr="type to search this pane ($total lines)"
      [ "$ibad" = 0 ] || sbr="not a valid pattern yet"
      case "$pane" in current|previous)
        [ "${KDASH_SEARCH_ALL_LINES:-1}" = 0 ] || [ ! -f "$body.more" ] || sbk="Enter keep (reads every line of the log first)   ${sbk#Enter keep   }" ;;
      esac
      ue_view $(( INSPECTOR_COLS - 9 ))
      ui_search_box "$INSPECTOR_COLS" "$sbt" "$sbr" "/ $UE_VIS" $(( UE_CUR + 2 )) "$sbk"
      frame+="$UI_SBOX"$'\n'
    fi
    for kl in "${IK_LINES[@]}"; do frame+="${kl}"$'\033[K\n'; done
    if [ -n "$msg" ]; then frame+=$'\033[1;33m'" ${msg:0:$((INSPECTOR_COLS - 2))}"$'\033[0m\033[K'; else frame+=$'\033[K'; fi
    ui_flush "$frame" "detail:$INSPECTOR_COLS:$INSPECTOR_ROWS:$ityping" "$ifl"; ifl=1
    if [ "$ityping" = 1 ]; then
      # keys of the search box; keys typed ahead are taken together, then the pane is drawn once
      while :; do
        ue_key
        case "$UE_ACT" in
          edit)
            if [ -z "$UE_T" ]; then INSPECTOR_SEARCH=""; ibad=0
            elif inspector_pattern_ok "$UE_T"; then INSPECTOR_SEARCH="$UE_T"; ibad=0
            else ibad=1; fi
            INSPECTOR_JUMPED="" ;;
          tab) INSPECTOR_ONLY=$(( 1 - ${INSPECTOR_ONLY:-0} )); offset=0 ;;
          enter|cancel) break ;;
        esac
        read -t 0 </dev/tty 2>/dev/null || break
      done
      case "$UE_ACT" in
        enter)
          ityping=0; ue_remember
          if [ -z "$UE_T" ]; then INSPECTOR_SEARCH=""; INSPECTOR_ONLY=0; msg="search cleared"
          elif [ "$ibad" = 1 ]; then INSPECTOR_SEARCH="$sv_search"; INSPECTOR_ONLY=$sv_only; msg="not a valid regular expression: $UE_T"
          else
            INSPECTOR_SEARCH="$UE_T"
            declare -F audit >/dev/null && audit INSPECT_SEARCH "namespace=$ns pod=$pod pane=$pane only=${INSPECTOR_ONLY:-0} pattern=$(printf '%s' "$UE_T" | head -c 120)"
            # a search covers the whole log: when only the newest lines (or a byte cap's
            # worth) are loaded, the whole log is read first
            case "$pane" in current|previous)
              if [ "${KDASH_SEARCH_ALL_LINES:-1}" != 0 ] && [ -f "$body.more" ]; then
                INSPECTOR_TAIL_SET=-1; INSPECTOR_BYTES_SET="${KDASH_LOG_MAX_BYTES:-268435456}"; reload=1; INSPECTOR_JUMPED=""
                lnote="searching the whole log: reading all of it first, older rotated files too when allowed (up to $(xfer_hsize "$INSPECTOR_BYTES_SET"))"
              fi ;;
            esac
          fi ;;
        cancel) ityping=0; INSPECTOR_SEARCH="$sv_search"; INSPECTOR_ONLY=$sv_only; INSPECTOR_JUMPED="$sv_search"; msg="search unchanged" ;;
      esac
      viewdirty=1; [ "$ityping" = 1 ] && ifl=0 || ifl=1
      continue
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
    case "$INSPECTOR_KEY" in j|k|' '|b|g|G|n|N|L|W|J|'<LEFT>'|'<RIGHT>') ifl=0 ;; esac   # the screen stays ours: send the difference
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
      X) interactive_toggle; msg="$INTERACTIVE_MSG"; rows_stale=1 ;;
      j) offset=$((offset + 1)) ;; k) offset=$((offset - 1)) ;; ' ') offset=$((offset + rows)) ;; b) offset=$((offset - rows)) ;;
      g) offset=0 ;; G) offset=999999 ;;
      '/'|'&') # the search box opens in place; Up recalls the earlier searches
         # a log pane with only the newest lines loaded: the whole log is read first, so the
         # count as you type covers every line (Esc while it reads: search the loaded lines)
         case "$pane" in current|previous)
           if [ "${KDASH_SEARCH_ALL_LINES:-1}" != 0 ] && [ -f "$body.more" ]; then
             iwas_t="${INSPECTOR_TAIL_SET:-}"; iwas_b="${INSPECTOR_BYTES_SET:-}"; iopen="$INSPECTOR_KEY"
             INSPECTOR_TAIL_SET=-1; INSPECTOR_BYTES_SET="${KDASH_LOG_MAX_BYTES:-268435456}"; reload=1
             lnote="reading the whole log first, so the search covers every line (older rotated files too when allowed) - Esc searches the loaded lines"
             continue
           fi ;;
         esac
         sv_search="${INSPECTOR_SEARCH:-}"; sv_only="${INSPECTOR_ONLY:-0}"; ityping=1; ibad=0; ifl=1
         if [ "$INSPECTOR_KEY" = '&' ]; then INSPECTOR_ONLY=1; else INSPECTOR_ONLY=0; fi
         ue_begin search ""; INSPECTOR_SEARCH=""; viewdirty=1 ;;
      F) if inspector_find_all "$ns" "$pod" "$d"; then pane=found; reload=1; viewdirty=1; offset=0; fi ;;
      n|N) if [ "$matches" -gt 0 ] && [ -s "$matchf" ]; then
             if [ -n "$ijl" ] && [ "$offset" = "$ijo" ]; then t_=$((ijl - 1)); else t_=$offset; fi
             read -r target idx <<< "$(awk -v cur="$t_" -v back="$([ "$INSPECTOR_KEY" = N ] && printf 1 || printf 0)" '
               { L[NR] = $1 }
               END { if (NR == 0) { print "0 0"; exit }
                 if (!back) { for (k = 1; k <= NR; k++) if (L[k] > cur + 1) { print L[k], k, 0; exit }
                              print L[1], 1, 1; exit }
                 for (k = NR; k >= 1; k--) if (L[k] < cur + 1) { print L[k], k, 0; exit }
                 print L[NR], NR, 1 }' "$matchf")"
             read -r target idx wrapped <<< "$target $idx"
             if [ "${target:-0}" -gt 0 ]; then offset=$((target - 1)); ijl=$target; ijn=1; msg="match $idx/$matches"
               if [ "${wrapped:-0}" = 1 ] && [ "$matches" -gt 1 ]; then
                 if [ "$INSPECTOR_KEY" = N ]; then msg+=" - continued from the bottom"; else msg+=" - continued from the top"; fi
               fi
             fi
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
             INSPECTOR_TAIL_SET=-1; INSPECTOR_BYTES_SET="${KDASH_LOG_MAX_BYTES:-268435456}"; reload=1; msg="reading the whole log, older rotated files too when allowed (up to $(xfer_hsize "$INSPECTOR_BYTES_SET"))" ;;
           *) msg="A applies to the log panes (l, p)" ;; esac ;;
      f) case "$pane" in
           current|previous) follow=$((1 - follow)); reload=1; keep_offset=1; viewdirty=1
             [ "$follow" = 1 ] && msg="follow every ${INSPECTOR_FOLLOW_SECS}s - press f to stop" || msg='follow off' ;;
           *) msg='follow applies to the log panes (l current, p previous)' ;;
         esac ;;
      w) # the export has whole lines (not the wrapped screen rows)
         inspector_view_build "$body" "$view.x" "$matchf.x" 0
         local xn="$INSPECTOR_VIEW_LINES"; INSPECTOR_VIEW_LINES="$count"; INSPECTOR_MATCHES="$matches"
         if file="$(inspector_export "$view.x" "$ns" "$pod" "$container" "$pane" "$total" "$matches")"; then
           msg="exported $xn complete line(s) to $file"
           declare -F audit >/dev/null && audit INSPECT_EXPORT "namespace=$ns pod=$pod container=${container:--} pane=$pane lines=$xn search=${INSPECTOR_SEARCH:-none} level=${INSPECTOR_LEVEL_NAME:-all} file=$file"
         else msg='export failed: is the report directory writable?'; fi ;;
      '>') # quick export: the screen, then the whole pane in whole lines (search / level as shown)
         inspector_view_build "$body" "$view.x" "$matchf.x" 0
         INSPECTOR_VIEW_LINES="$count"; INSPECTOR_MATCHES="$matches"
         local xt="pod detail, pane $pane | pod $ns/$pod | container ${container:-(none)}"
         case "$pane" in current|previous) [ ! -s "$body.info" ] || xt+=" | read: $(< "$body.info")" ;;
                         found) [ ! -s "$d/found.info" ] || xt+=" | $(< "$d/found.info")" ;; esac
         [ -z "${INSPECTOR_SEARCH:-}" ] || xt+=" | search /$INSPECTOR_SEARCH$([ "${INSPECTOR_ONLY:-0}" != 1 ] || printf ' (only matching lines)')"
         [ "${INSPECTOR_LEVEL_NAME:-all}" = all ] || xt+=" | level $INSPECTOR_LEVEL_NAME"
         quick_export "${pod}_${pane}" "$xt" "$view.x" "THE WHOLE $(printf '%s' "$pane" | tr '[:lower:]' '[:upper:]') PANE" \
           "logs and describe output can hold sensitive values (tokens, addresses, payloads) - review before sharing"
         msg="$QX_MSG" ;;
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

# rows of the pod list (sorted) -> one file per column for picker_load. A row is split as
# bash "read" with IFS=tab splits it: runs of tabs are one break, the last field keeps
# the rest of the line.
PICKER_COLS_AWK='
BEGIN { split("KEY CLS ATT RST ML SRCH A B C1 C2 C3 C4 C5 TNS TPOD TST TRD TRS TCPU TMEM TLIM TND", NM, " ")
  for (i = 1; i <= 22; i++) { F[i] = d "/pk." NM[i]; printf "" > F[i] }
  wns = 9; wst = 6; wnd = 4; wpod = 3 }
{ ln = $0; gsub(/\t+/, "\t", ln); sub(/^\t/, "", ln); sub(/\t$/, "", ln)
  n = split(ln, x, "\t"); for (i = n + 1; i <= 15; i++) x[i] = ""
  for (i = 16; i <= n; i++) x[15] = x[15] "\t" x[i]
  st = x[10]; sub(/ +$/, "", st); rd = x[11]; gsub(/ /, "", rd); rs = x[12]; gsub(/ /, "", rs)
  c3 = x[13]; sub(/^[ \t]+/, "", c3); sub(/[ \t]+$/, "", c3); p = index(c3, " ")
  if (p) { cu = substr(c3, 1, p - 1); mu = substr(c3, p + 1); sub(/^[ \t]+/, "", mu) } else { cu = c3; mu = "" }
  lm = x[14]; gsub(/ /, "", lm)
  v[1] = x[2] "/" x[3]; v[2] = x[4]; v[3] = x[5]; v[4] = x[6]; v[5] = x[7]; v[6] = x[8]; v[7] = x[9]; v[8] = x[10]
  v[9] = x[11]; v[10] = x[12]; v[11] = x[13]; v[12] = x[14]; v[13] = x[15]
  v[14] = x[2]; v[15] = x[3]; v[16] = st; v[17] = rd; v[18] = rs; v[19] = cu; v[20] = mu; v[21] = lm; v[22] = x[15]
  for (i = 1; i <= 22; i++) print v[i] > F[i]
  if (length(x[2]) > wns) wns = length(x[2]); if (length(st) > wst) wst = length(st)
  if (length(x[15]) > wnd) wnd = length(x[15]); if (length(x[3]) > wpod) wpod = length(x[3]) }
END { for (i = 1; i <= 22; i++) close(F[i]); print wns, wst, wnd, wpod > (d "/pk.widths") }'

picker_colors() {
  if [ "${COLOR:-1}" = 1 ]; then
    PC_R=$'\033[0m'; PC_B=$'\033[1m'; PC_D=$'\033[90m'; PC_INV=$'\033[7m'; PC_OK=$'\033[32m'; PC_BAD=$'\033[1;31m'
    PC_WARN=$'\033[35m'; PC_INFO=$'\033[1;94m'; PC_TITLE=$'\033[7;1m'; PC_ACT=$'\033[1;97;41m'
  else
    PC_R=""; PC_B=""; PC_D=""; PC_INV=""; PC_OK=""; PC_BAD=""; PC_WARN=""; PC_INFO=""; PC_TITLE=""; PC_ACT=""
  fi
  if [ "${BARCHR:-unicode}" = ascii ]; then PC_PTR=">"; PC_UP="^"; PC_DN="v"; PC_CARET="_"; PC_SEP="|"; PC_HR="-"; PC_DOT="*"; PC_MID="-"
  else PC_PTR=$'\342\226\272'; PC_UP=$'\342\206\221'; PC_DN=$'\342\206\223'; PC_CARET=$'\342\226\214'
       PC_SEP=$'\342\224\202'; PC_HR=$'\342\224\200'; PC_DOT=$'\342\227\217'; PC_MID=$'\302\267'; fi
  # header row of a table: bold + underlined (reads on light and dark backgrounds)
  if [ "${COLOR:-1}" = 1 ]; then PC_HDR=$'\033[1;4m'; else PC_HDR=""; fi
  # a glyph is 1 character in a UTF-8 locale but 3 bytes in the C locale
  local utf8_probe=$'\342\224\202'
  UI_BYTES=0; [ "${#utf8_probe}" -le 1 ] || UI_BYTES=1
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
# Write one frame. A frame is a buffer that starts at the top-left corner, one screen
# line per text line. When the previous frame of the same screen (same key) is still
# what the terminal shows, only the lines that differ are sent - a cursor move repaints
# two rows instead of the whole screen, which is what makes scrolling quick over SSH.
# full=1 (or another key, or KDASH_REDRAW=full) sends everything.
# While kdash owns the screen the terminal does not echo: a key pressed while a slow
# read runs must not print "^[[A" into the frame (only changed lines are repainted, so
# it would stay). Prompts read through ui_edit_line, which draws what is typed itself.
UI_STTY0=""; UI_QUIET=0
ui_tty_quiet() { # on | off | restore
  [ -t 0 ] || [ -r /dev/tty ] || return 0
  case "$1" in
    on)  [ -n "$UI_STTY0" ] || UI_STTY0="$(stty -g </dev/tty 2>/dev/null)"
         stty -echo </dev/tty 2>/dev/null && UI_QUIET=1 ;;
    off) stty echo </dev/tty 2>/dev/null; UI_QUIET=0 ;;
    restore) [ -z "$UI_STTY0" ] || stty "$UI_STTY0" </dev/tty 2>/dev/null; UI_QUIET=0 ;;
  esac
  return 0
}
# One-line editor for every prompt. The arrow keys move inside the text and never type
# escape bytes into it; Up / Down recall the earlier entries of the same prompt (this
# session only); Home / End / Ctrl-A / Ctrl-E, Delete, Backspace, Ctrl-U (to the start),
# Ctrl-W (word). Enter accepts (0), Esc, Ctrl-C or Ctrl-D on an empty line cancel (1).
# The text is drawn after PROMPT on the current row and scrolls sideways when long.
declare -A UI_HIST=()
# One key of the line editor shared by every prompt and search box. State: UE_T (text),
# UE_POS (cursor), UE_H (history of this prompt), UE_HI (position in it). After a key,
# UE_ACT says what happened: edit, move, enter, cancel, tab. ue_begin KEY TEXT starts.
UE_T=""; UE_POS=0; UE_HI=0; UE_ACT=""; UE_KEY=""; declare -a UE_H=()
ue_begin() { # history-key [initial text]
  UE_KEY="${1:-}"; UE_T="${2:-}"; UE_POS=${#UE_T}; UE_H=()
  [ -z "$UE_KEY" ] || [ -z "${UI_HIST[$UE_KEY]:-}" ] || mapfile -t UE_H <<< "${UI_HIST[$UE_KEY]}"
  UE_HI=${#UE_H[@]}
}
ue_remember() { # store UE_T in the history of this prompt (session only)
  local x
  [ -n "$UE_KEY" ] && [ -n "$UE_T" ] && [ "$UE_T" != "${UE_H[${#UE_H[@]}-1]:-}" ] || return 0
  UE_H+=("$UE_T"); [ "${#UE_H[@]}" -le 50 ] || UE_H=("${UE_H[@]:1}")
  printf -v x '%s\n' "${UE_H[@]}"; UI_HIST[$UE_KEY]="${x%$'\n'}"
}
ue_key() { # [timeout] -> reads one key (an escape sequence whole) and applies it; 1 = no key
  local c q k2 x t="${1:-}"
  UE_ACT=""
  if [ -n "$t" ]; then IFS= read -rsn1 -t "$t" c </dev/tty || return 1; else IFS= read -rsn1 c </dev/tty || { UE_ACT=cancel; return 0; }; fi
  case "$c" in
    '') UE_ACT=enter ;;
    $'\033') q=""
       if IFS= read -rsn1 -t 0.15 k2 </dev/tty; then
         q="$k2"
         if [ "$k2" = '[' ] || [ "$k2" = O ]; then
           while IFS= read -rsn1 -t 0.15 k2 </dev/tty; do q+="$k2"; case "$k2" in [@-~]) [ "${#q}" -gt 1 ] && break ;; esac; done
         fi
       fi
       UE_ACT=move
       case "$q" in
         '') UE_ACT=cancel ;;
         '[D'|OD) [ "$UE_POS" -le 0 ] || UE_POS=$((UE_POS - 1)) ;;
         '[C'|OC) [ "$UE_POS" -ge "${#UE_T}" ] || UE_POS=$((UE_POS + 1)) ;;
         '[H'|OH|'[1~'|'[7~') UE_POS=0 ;;
         '[F'|OF|'[4~'|'[8~') UE_POS=${#UE_T} ;;
         '[3~') UE_T="${UE_T:0:UE_POS}${UE_T:UE_POS+1}"; UE_ACT=edit ;;
         '[A'|OA) if [ "$UE_HI" -gt 0 ]; then UE_HI=$((UE_HI - 1)); UE_T="${UE_H[UE_HI]}"; UE_POS=${#UE_T}; UE_ACT=edit; fi ;;
         '[B'|OB) if [ "$UE_HI" -lt "${#UE_H[@]}" ]; then UE_HI=$((UE_HI + 1)); UE_T="${UE_H[UE_HI]:-}"; UE_POS=${#UE_T}; UE_ACT=edit; fi ;;
         '[Z') UE_ACT=tab ;;                                   # Shift-Tab
         b|B) while [ "$UE_POS" -gt 0 ] && [ "${UE_T:UE_POS-1:1}" = ' ' ]; do UE_POS=$((UE_POS - 1)); done
              while [ "$UE_POS" -gt 0 ] && [ "${UE_T:UE_POS-1:1}" != ' ' ]; do UE_POS=$((UE_POS - 1)); done ;;
         f|F) while [ "$UE_POS" -lt "${#UE_T}" ] && [ "${UE_T:UE_POS:1}" = ' ' ]; do UE_POS=$((UE_POS + 1)); done
              while [ "$UE_POS" -lt "${#UE_T}" ] && [ "${UE_T:UE_POS:1}" != ' ' ]; do UE_POS=$((UE_POS + 1)); done ;;
       esac ;;
    $'\t') UE_ACT=tab ;;
    $'\177'|$'\b') [ "$UE_POS" -le 0 ] || { UE_T="${UE_T:0:UE_POS-1}${UE_T:UE_POS}"; UE_POS=$((UE_POS - 1)); }; UE_ACT=edit ;;
    $'\001') UE_POS=0; UE_ACT=move ;; $'\005') UE_POS=${#UE_T}; UE_ACT=move ;;
    $'\002') [ "$UE_POS" -le 0 ] || UE_POS=$((UE_POS - 1)); UE_ACT=move ;; $'\006') [ "$UE_POS" -ge "${#UE_T}" ] || UE_POS=$((UE_POS + 1)); UE_ACT=move ;;
    $'\025') UE_T="${UE_T:UE_POS}"; UE_POS=0; UE_ACT=edit ;;
    $'\013') UE_T="${UE_T:0:UE_POS}"; UE_ACT=edit ;;
    $'\027') x="${UE_T:0:UE_POS}"; while [ -n "$x" ] && [ "${x: -1}" = ' ' ]; do x="${x%?}"; done; x="${x%"${x##* }"}"
             UE_T="$x${UE_T:UE_POS}"; UE_POS=${#x}; UE_ACT=edit ;;
    $'\003') UE_ACT=cancel ;;
    $'\004') if [ -z "$UE_T" ]; then UE_ACT=cancel; else UE_T="${UE_T:0:UE_POS}${UE_T:UE_POS+1}"; UE_ACT=edit; fi ;;
    [[:cntrl:]]) UE_ACT=move ;;
    *) UE_T="${UE_T:0:UE_POS}$c${UE_T:UE_POS}"; UE_POS=$((UE_POS + 1)); UE_ACT=edit ;;
  esac
  return 0
}
ue_view() { # width -> UE_VIS (the part of the text that fits) and UE_CUR (cursor column in it)
  local av="$1" ofs=0
  [ "$av" -ge 8 ] || av=8
  if [ "${#UE_T}" -gt "$av" ]; then ofs=$(( UE_POS > av ? UE_POS - av : 0 )); fi
  UE_VIS="${UE_T:ofs:av}"; UE_CUR=$(( UE_POS - ofs ))
}
# One-line prompt on the current row (the editor above; Tab is ignored here).
ui_edit_line() { # var prompt [history-key] [initial text]
  local __v="$1" pr="$2" pl x w rc=0 old_int intr=0
  x="$pr"; while [[ "$x" =~ $'\033'\[[0-9\;?]*[A-Za-z] ]]; do x="${x/"${BASH_REMATCH[0]}"/}"; done; pl=${#x}
  w=$(stty size </dev/tty 2>/dev/null); w=${w#* }; case "$w" in ''|*[!0-9]*) w=${KDASH_COLUMNS:-80} ;; esac
  ue_begin "${3:-}" "${4:-}"
  old_int="$(trap -p INT)"; trap 'intr=1' INT
  printf '\033[?25h'
  while :; do
    if ! read -t 0 </dev/tty 2>/dev/null; then          # a paste is drawn once, not per character
      ue_view $(( w - pl - 2 ))
      printf '\r%s%s\033[K\r' "$pr" "$UE_VIS"; [ $(( pl + UE_CUR )) -le 0 ] || printf '\033[%dC' $(( pl + UE_CUR ))
    fi
    ue_key
    [ "$intr" = 0 ] || { rc=1; break; }
    case "$UE_ACT" in enter) break ;; cancel) rc=1; break ;; esac
  done
  if [ -n "$old_int" ]; then eval "$old_int"; else trap - INT; fi
  ue_view $(( w - pl - 2 )); printf '\r%s%s\033[K\n' "$pr" "$UE_VIS"
  [ "$rc" != 0 ] || ue_remember
  printf -v "$__v" '%s' "$UE_T"
  return "$rc"
}
# The search box: three framed rows. Title and count in the top border, the text with
# its cursor in the middle, the keys in the bottom border.
ui_search_box() { # width title right-info text cursor-col(-1 = none) keys -> UI_SBOX
  local w="$1" t="$2" ri="$3" tx="$4" cc="$5" ks="$6" hz="─" tl="┌" tr="┐" bl="└" br="┘" vb="│" d="" b="" r="" rv="" x n mid
  [ "${BARCHR:-unicode}" != ascii ] || { hz="-"; tl="+"; tr="+"; bl="+"; br="+"; vb="|"; }
  if [ "${COLOR:-1}" = 1 ]; then d=$'\033[90m'; b=$'\033[1m'; r=$'\033[0m'; rv=$'\033[7m'; fi
  [ "$w" -ge 30 ] || w=30
  ui_vlen "$t"; x=$UI_VL; ui_vlen "$ri"; n=$(( w - 8 - x - UI_VL )); [ -n "$ri" ] || n=$(( w - 6 - x ))
  [ "$n" -ge 1 ] || { ri=""; n=$(( w - 6 - x )); }
  printf -v mid '%*s' "$n" ''; mid="${mid// /$hz}"
  UI_SBOX="${d}${tl}${hz}${r} ${b}${t}${r} ${d}${mid}${r}${ri:+ $ri }${d}${hz}${tr}${r}"$'\033[K\n'
  # middle: "/ text" with a block cursor
  local body="$tx"
  if [ "$cc" -ge 0 ] 2>/dev/null; then body="${tx:0:cc}${rv}${tx:cc:1}"; [ -n "${tx:cc:1}" ] || body+=" "; body+="${r}${b}${tx:cc+1}"; fi
  ui_vlen "$tx"; n=$(( w - 4 - UI_VL )); [ "$cc" -lt 0 ] 2>/dev/null || [ "$cc" -lt "${#tx}" ] || n=$((n - 1)); [ "$n" -ge 0 ] || n=0
  printf -v x '%*s' "$n" ''
  UI_SBOX+="${d}${vb}${r} ${b}${body}${r}${x} ${d}${vb}${r}"$'\033[K\n'
  ui_vlen "$ks"; n=$(( w - 5 - UI_VL )); [ -n "$ks" ] || n=$(( w - 3 ))
  [ "$n" -ge 1 ] || { ks=""; n=$(( w - 3 )); }
  printf -v mid '%*s' "$n" ''; mid="${mid// /$hz}"
  UI_SBOX+="${d}${bl}${hz}${r}${ks:+ ${d}${ks}${r} }${d}${mid}${br}${r}"$'\033[K'
}
UI_FL_KEY=""; UI_FL_PREV=()
# The module is also sourced on its own by integrations. Core initializes the
# theme mapping before embedding this file; preserve that map when it exists.
if ! declare -p UI_MAPK >/dev/null 2>&1; then
  declare -a UI_MAPK=() UI_MAPV=()
fi
# one line, colour roles -> theme colours (UI_ML); per line, as bash 4.4 is slow on a
# replace over the whole frame
ui_mapl() {
  UI_ML="$1"; [[ "$UI_ML" == *$'\033['* ]] || return 0
  local j
  for ((j = 0; j < ${#UI_MAPK[@]}; j++)); do
    [[ "$UI_ML" != *"${UI_MAPK[j]}"* ]] || UI_ML="${UI_ML//"${UI_MAPK[j]}"/"${UI_MAPV[j]}"}"
  done
}
ui_flush() { # buffer key [full]
  local key="$2" i n pn out=""
  local -a L
  mapfile -t L <<< "$1"
  n=${#L[@]}; [ "$n" = 0 ] || [ -n "${L[n-1]}" ] || { unset 'L[n-1]'; n=$((n - 1)); }
  pn=${#UI_FL_PREV[@]}
  if [ "${3:-0}" = 1 ] || [ "$key" != "$UI_FL_KEY" ] || [ "${KDASH_REDRAW:-diff}" = full ] || [ "$pn" = 0 ]; then
    if [ "${#UI_MAPK[@]}" = 0 ]; then printf '%s\033[J' "$1"
    else
      for ((i = 0; i < n; i++)); do ui_mapl "${L[i]}"; out+="$UI_ML"$'\n'; done
      [[ "$1" == *$'\n' ]] || out="${out%$'\n'}"
      printf '%s\033[J' "$out"
    fi
  else
    # a list that moved by one row: let the terminal scroll that band, then only the
    # rows that really differ (the cursor row, the new row) are sent
    if [ "${KDASH_REDRAW:-diff}" != noscroll ] && [ "$n" = "$pn" ]; then
      local a=-1 b=-1 up=0 dn=0
      for ((i = 1; i < n - 1; i++)); do
        [ "${L[i]}" != "${UI_FL_PREV[i]}" ] || continue
        [ "${L[i]}" != "${UI_FL_PREV[i+1]}" ] || up=$((up + 1)); [ "${L[i]}" != "${UI_FL_PREV[i-1]}" ] || dn=$((dn + 1))
      done
      if [ "$up" -ge 6 ] && [ "$up" -gt "$dn" ]; then
        for ((i = 1; i < n - 1; i++)); do [ "${L[i]}" = "${UI_FL_PREV[i]}" ] || [ "${L[i]}" != "${UI_FL_PREV[i+1]}" ] || { [ "$a" -ge 0 ] || a=$i; b=$i; }; done
        out+=$'\033['"$((a + 1));$((b + 2))"$'r\033['"$((b + 2))"$';1H\n\033[r'
        for ((i = a; i <= b; i++)); do UI_FL_PREV[i]="${UI_FL_PREV[i+1]}"; done; UI_FL_PREV[b+1]=""
      elif [ "$dn" -ge 6 ] && [ "$dn" -gt "$up" ]; then
        for ((i = 1; i < n - 1; i++)); do [ "${L[i]}" = "${UI_FL_PREV[i]}" ] || [ "${L[i]}" != "${UI_FL_PREV[i-1]}" ] || { [ "$a" -ge 0 ] || a=$i; b=$i; }; done
        out+=$'\033['"$((a));$((b + 1))"$'r\033['"$((a))"$';1H\033M\033[r'
        for ((i = b; i >= a; i--)); do UI_FL_PREV[i]="${UI_FL_PREV[i-1]}"; done; UI_FL_PREV[a-1]=""
      fi
    fi
    for ((i = 0; i < n; i++)); do
      [ "${L[i]}" != "${UI_FL_PREV[i]-}" ] || continue
      if [ "${#UI_MAPK[@]}" = 0 ]; then out+=$'\033['"$((i + 1))"';1H'"${L[i]#$'\033[H'}"
      else ui_mapl "${L[i]#$'\033[H'}"; out+=$'\033['"$((i + 1))"';1H'"$UI_ML"; fi
    done
    out+=$'\033['"$((n + 1))"';1H'; [ "$n" -ge "$pn" ] || out+=$'\033[J'
    printf '%s' "$out"
  fi
  UI_FL_KEY="$key"; UI_FL_PREV=("${L[@]}")
}

# ---- quick export (>) ------------------------------------------------------------------
# One key on every kdash screen - dashboard views, pod detail panes (logs, describe,
# events, found), the pod / namespace / container lists and the file browser: what is on
# the screen now AND the whole content behind it (every line and column of the view, the
# pane or the list - nothing cut) go to one plain-text log file. Colours and cursor codes
# are removed, trailing blanks trimmed. One file per press in KDASH_EXPORT_DIR (default
# <report dir>/exports, mode 600); every export of the session is also appended to
# kdash_session_<id>.log there, so one file holds them all, and latest.log points to the
# newest. File names: kdash_<what>_<date-time>.log. Nothing is run against the
# cluster for it; each export is audited (QUICK_EXPORT). QX_NOSCREEN=1: no screen part.
qx_dir() { printf '%s' "${KDASH_EXPORT_DIR:-${KDASH_REPORT_DIR:-${HOME:-/tmp}/kdash_reports}/exports}"; }
qx_safe() { printf '%s' "$1" | tr -c 'A-Za-z0-9._-' '_' | cut -c1-60; }
qx_plain() { LC_ALL=C awk '{ gsub(/\033\[[0-9;?]*[A-Za-z]/, ""); gsub(/\033[()][0-9A-Za-z]/, ""); gsub(/\033[=>78DEMc]/, ""); gsub(/\r/, ""); sub(/[ \t]+$/, ""); print }'; }
qx_align() { # TSV on stdin -> aligned plain columns (no column is cut)
  LC_ALL=C awk -F '\t' '{ n[NR] = NF; for (i = 1; i <= NF; i++) { c[NR, i] = $i; if (length($i) > w[i]) w[i] = length($i) } }
    END { for (r = 1; r <= NR; r++) { s = ""; for (i = 1; i <= n[r]; i++) s = s (i < n[r] ? sprintf("%-" w[i] "s  ", c[r, i]) : c[r, i]); sub(/ +$/, "", s); print s } }'
}
quick_export() { # what title [whole-file] [whole-title] [note] -> QX_FILE, QX_DISP, QX_MSG; 1 = failed
  local what="$1" title="$2" full="${3:-}" ftitle="${4:-}" note="${5:-}" dir f base ts k=1 sn sl nl=0 hr
  QX_FILE=""; QX_DISP=""; dir="$(qx_dir)"
  if ! (umask 077; mkdir -p -- "$dir") 2>/dev/null || [ ! -w "$dir" ]; then
    QX_MSG="export failed: $dir is not writable (KDASH_EXPORT_DIR names another folder)"; return 1
  fi
  printf -v ts '%(%Y%m%d-%H%M%S)T' -1
  base="$dir/kdash_$(qx_safe "$what")_$ts"
  f="$base.log"; while [ -e "$f" ]; do k=$((k + 1)); f="${base}_$k.log"; done
  sl=${#UI_FL_PREV[@]}; [ "${QX_NOSCREEN:-0}" != 1 ] || sl=0
  [ -z "$full" ] || [ ! -r "$full" ] || nl=$(LC_ALL=C awk 'END { print NR }' "$full")
  hr="================================================================================"
  if ! ( umask 077
    {
      printf '# kdash %s - quick export (key >)\n' "${KDASH_VERSION:-}"
      printf '# screen   : %s\n' "$title"
      printf '# context  : %s    namespace: %s\n' "${CTX_NAME:-current}" "${NS:-?}"
      printf '# taken    : %s by %s on %s (session %s)\n' "$(date '+%Y-%m-%d %H:%M:%S %z')" "${USER:-$(id -un 2>/dev/null)}" "$(hostname 2>/dev/null)" "${AUDIT_SID:-?}"
      [ -z "$note" ] || printf '# note     : %s\n' "$note"
      printf '# a copy of what kdash showed - nothing was run against the cluster to make it\n'
      if [ "$sl" -gt 0 ]; then
        printf '\n%s\n ON THE SCREEN (%s rows, as you saw it)\n%s\n' "$hr" "$sl" "$hr"
        printf '%s\n' "${UI_FL_PREV[@]}" | qx_plain
      fi
      if [ -n "$full" ]; then
        printf '\n%s\n %s (%s lines, every line and column - nothing cut)\n%s\n' "$hr" "$ftitle" "$nl" "$hr"
        qx_plain < "$full"
      fi
      printf '\n# end of export\n'
    } > "$f" ) 2>/dev/null; then
    rm -f -- "$f"; QX_MSG="export failed: could not write $f"; return 1
  fi
  sn="$dir/kdash_session_$(qx_safe "${AUDIT_SID:-$$}").log"
  ( umask 077; { printf '\n'; cat -- "$f"; } >> "$sn" ) 2>/dev/null || true
  ln -sfn -- "${f##*/}" "$dir/latest.log" 2>/dev/null || true     # the newest export, whatever its name
  QX_FILE="$f"; QX_DISP="$f"
  if [ -n "${HOME:-}" ] && [ "$HOME" != / ]; then case "$f" in "$HOME"/*) QX_DISP="~/${f#"$HOME"/}" ;; esac; fi
  QX_MSG="exported to $QX_DISP"
  declare -F audit >/dev/null && audit QUICK_EXPORT "screen=$what rows=$sl lines=$nl file=$f"
  return 0
}
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
    if [ "${UI_BYTES:-0}" = 1 ]; then
      while [ "$i" -lt "$n" ]; do
        case "${str:i:1}" in [$'\200'-$'\277']) out+="${str:i:1}"; i=$((i + 1)) ;; *) break ;; esac
      done
    fi
  done
  PK_FIT="$out${PC_R:-}"
}

PK_SZ_AT=""; PK_SZ=""
picker_size() {
  # asked on every key press: the terminal is queried at most once a second (and at
  # once after a resize signal), so moving the cursor starts no process
  local s
  if [ -n "$PK_SZ" ] && [ "$PK_SZ_AT" = "$SECONDS" ] && [ "${PK_RESIZED:-0}" != 1 ]; then s="$PK_SZ"
  else s="$(stty size </dev/tty 2>/dev/null)" || s=""; PK_SZ="$s"; PK_SZ_AT="$SECONDS"; fi
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
  # plain cells for the framed table: namespace, pod, status, ready, restarts, cpu,
  # memory, % of limit, node (+ last exit); widths from the data. One awk pass writes a
  # file per column and mapfile reads each in one go (a read loop per pod was slow)
  PK_TNS=(); PK_TPOD=(); PK_TST=(); PK_TRD=(); PK_TRS=(); PK_TCPU=(); PK_TMEM=(); PK_TLIM=(); PK_TND=()
  unset PK_RCACHE; declare -gA PK_RCACHE=()          # formatted rows, per row and width
  PK_WNS=9; PK_WST=6; PK_WND=4; PK_WPOD=3
  local k
  if [ -r "${MODEL:?}/pods.tsv" ]; then
    awk -v cols="$PK_COLS" -v allns="${ALL_NS:-0}" -v mode="$PK_SORT" -v hdrf="$d/pick.hdr" -v sumf="$d/pick.sum" \
        "$PICKER_ROWS_AWK" "$MODEL/pods.tsv" | inspector_clean | LC_ALL=C sort -t $'\t' "${order[@]}" | LC_ALL=C awk -v d="$d" "$PICKER_COLS_AWK"
    for k in KEY CLS ATT RST ML SRCH A B C1 C2 C3 C4 C5 TNS TPOD TST TRD TRS TCPU TMEM TLIM TND; do mapfile -t "PK_$k" < "$d/pk.$k"; done
    read -r PK_WNS PK_WST PK_WND PK_WPOD < "$d/pk.widths"
  fi
  IFS= read -r PK_HDR < "$d/pick.hdr" || PK_HDR=""
  [ "$PK_WNS" -le 24 ] || PK_WNS=24; [ "$PK_WST" -le 18 ] || PK_WST=18; [ "$PK_WND" -le 40 ] || PK_WND=40
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
  rows=$((PK_ROWS - 14)); [ "$PK_TYPING" != 1 ] || rows=$((rows - 3)); [ "$rows" -ge 3 ] || rows=3       # bar, 2 info lines, frame (4), rule, key panel (6), search box (3)
  [ "$PK_SEL" -lt "$nv" ] || PK_SEL=$((nv > 0 ? nv - 1 : 0)); [ "$PK_SEL" -ge 0 ] || PK_SEL=0
  [ "$PK_SEL" -ge "$PK_TOP" ] || PK_TOP=$PK_SEL
  [ "$PK_SEL" -lt $((PK_TOP + rows)) ] || PK_TOP=$((PK_SEL - rows + 1))
  [ "$PK_TOP" -le $((nv > rows ? nv - rows : 0)) ] || PK_TOP=$((nv > rows ? nv - rows : 0))
  [ "$PK_TOP" -ge 0 ] || PK_TOP=0; top=$PK_TOP
  [ "$nv" = 0 ] || PK_SEL_KEY="${PK_KEY[${PK_V[PK_SEL]}]}"
  case "${KDASH_ATTACH_ACTION:-}" in
    S) banner=" ${PC_PTR} Enter opens a SHELL " ;; U) banner=" ${PC_PTR} Enter UPLOADS into the pod " ;; D) banner=" ${PC_PTR} Enter DOWNLOADS from the pod " ;; *) banner="" ;;
  esac
  # Keep the permission state in the left title: optional right-hand chips are
  # hidden on narrow terminals, which must never hide whether writes are enabled.
  if interactive_enabled; then mode="INTERACTIVE"; else mode="READ-ONLY"; fi
  title=" KDASH ${PC_SEP} SELECT POD ${PC_SEP} ${mode} ${PC_SEP} context ${CTX_NAME:-current} ${PC_SEP} namespace ${NS:-default} "
  right=" ${#PK_V[@]} of ${#PK_KEY[@]} pods "
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
      if [ "${#PK_MSG}" -le "$len" ]; then cl+="   ${PC_WARN}${PK_MSG}${PC_R}"
      else cl=" ${PC_WARN}${PK_MSG:0:$((PK_COLS - 2))}${PC_R}"; fi     # no room beside the rest: the message wins
    fi
    pk_fit "$cl" "$((PK_COLS - 1))"; buf+="$PK_FIT"
  fi
  buf+=$'\033[K\n'
  # ---- the pods, framed: [NAMESPACE] POD STATUS READY RST CPU MEM %LIM NODE
  bx_init
  local W=$((PK_COLS - 1)) allns="${ALL_NS:-0}" pw nw=$PK_WNS
  local -a cw al hd
  if [ "$allns" = 1 ]; then hd=(NAMESPACE POD STATUS READY RST CPU MEM %LIM NODE); al="llllrrrrl"
    BX_FLEX_MIN=24 bx_layout "$W" 1 "$nw" "$PK_WPOD" "$PK_WST" 5 3 6 7 5 "$PK_WND"
  else hd=(POD STATUS READY RST CPU MEM %LIM NODE); al="lllrrrrl"
    BX_FLEX_MIN=24 bx_layout "$W" 0 "$PK_WPOD" "$PK_WST" 5 3 6 7 5 "$PK_WND"; fi
  # narrow screens: the NODE column (last) goes first so the pod name stays readable
  if [ "$W" -lt 100 ]; then hd=("${hd[@]:0:${#hd[@]}-1}"); al="${al:0:${#al}-1}"
    if [ "$allns" = 1 ]; then BX_FLEX_MIN=20 bx_layout "$W" 1 "$nw" "$PK_WPOD" "$PK_WST" 5 3 6 7 5
    else BX_FLEX_MIN=24 bx_layout "$W" 0 "$PK_WPOD" "$PK_WST" 5 3 6 7 5; fi; fi
  cw=("${BX_CW[@]}")
  local V_="${BX_C}${BX_V}${BX_R}" ncol=${#cw[@]} k cell out sty
  # rows are built with printf on plain text, colour is wrapped around the padded cell
  bx_sep "$W" t "${BX_J[@]}"; line="${BX_LINE/${BX_LT}/${BX_TL}}"; buf+="${line%${BX_RT}${BX_R}}${BX_TR}${BX_R}"$'\033[K\n'
  out="$V_"; for ((k = 0; k < ncol; k++)); do
    if [ "${al:k:1}" = r ]; then printf -v cell " %*s " "${cw[k]}" "${hd[k]:0:${cw[k]}}"; else printf -v cell " %-*s " "${cw[k]}" "${hd[k]:0:${cw[k]}}"; fi
    out+="${PC_B}${cell}${PC_R}${V_}"; done
  buf+="$out"$'\033[K\n'
  bx_sep "$W" x "${BX_J[@]}"; buf+="$BX_LINE"$'\033[K\n'
  local shown=$((nv - top < rows ? nv - top : rows)); [ "$shown" -ge 1 ] || shown=1
  for ((i = 0; i < shown; i++)); do
    j=$((top + i))
    if [ "$j" -ge "$nv" ]; then
      bx_row "$W" "$([ "${#PK_KEY[@]}" = 0 ] && printf '%sno pods in the model - F edits filters, r re-reads%s' "$PC_D" "$PC_R" || printf '%snothing matches%s %s- Esc clears the filter, u shows all pods%s' "$PC_WARN" "$PC_R" "$PC_D" "$PC_R")"
      buf+="$BX_LINE"$'\033[K\n'; continue
    fi
    j=${PK_V[j]}
    local pn="${PK_TPOD[j]}" pwid
    if [ "$allns" = 1 ]; then pwid=${cw[1]}; else pwid=${cw[0]}; fi
    # long pod names keep their start and their hash / ordinal end
    if [ "${#pn}" -gt "$pwid" ]; then local h=$(( (pwid - 1) / 2 )); pn="${pn:0:$((pwid - 1 - h))}~${pn: -$h}"; fi
    local -a cells=()
    [ "$allns" = 1 ] && cells+=("${PK_TNS[j]}")
    cells+=("$pn" "${PK_TST[j]}" "${PK_TRD[j]}" "${PK_TRS[j]}" "${PK_TCPU[j]}" "${PK_TMEM[j]}" "${PK_TLIM[j]}" "${PK_TND[j]}")
    local ck="$j|$W"
    if [ $((top + i)) != "$PK_SEL" ] && [ -n "${PK_RCACHE[$ck]:-}" ]; then buf+="${PK_RCACHE[$ck]}"$'\033[K\n'; continue; fi
    if [ $((top + i)) = "$PK_SEL" ]; then
      out="$V_${PC_INV}${PC_B}"
      for ((k = 0; k < ncol; k++)); do
        if [ "${al:k:1}" = r ]; then printf -v cell " %*s " "${cw[k]}" "${cells[k]:0:${cw[k]}}"; else printf -v cell " %-*s " "${cw[k]}" "${cells[k]:0:${cw[k]}}"; fi
        out+="$cell"; [ "$k" = $((ncol - 1)) ] || out+="$BX_V"
      done
      buf+="${out}${PC_R}${V_}"$'\033[K\n'
    else
      local stc rsc mlc dim=""
      case "${PK_CLS[j]}" in bad) stc="$PC_BAD" ;; warn) stc="$PC_WARN" ;; done) stc="$PC_D"; dim="$PC_D" ;; *) stc="$PC_OK" ;; esac
      rsc=""; [ "${PK_RST[j]}" != 1 ] || rsc="$PC_WARN"
      case "${PK_ML[j]}" in 2) mlc="$PC_BAD" ;; 1) mlc="$PC_WARN" ;; *) mlc="" ;; esac
      out="$V_"
      for ((k = 0; k < ncol; k++)); do
        if [ "${al:k:1}" = r ]; then printf -v cell " %*s " "${cw[k]}" "${cells[k]:0:${cw[k]}}"; else printf -v cell " %-*s " "${cw[k]}" "${cells[k]:0:${cw[k]}}"; fi
        sty="$dim"
        case "${hd[k]}" in STATUS) sty="$stc" ;; RST) [ -z "$rsc" ] || sty="$rsc" ;; %LIM) [ -z "$mlc" ] || sty="$mlc" ;; NODE) [ -n "$dim" ] || sty="$PC_D" ;; esac
        if [ -n "$sty" ]; then out+="${sty}${cell}${PC_R}${V_}"; else out+="${cell}${V_}"; fi
      done
      PK_RCACHE[$ck]="$out"
      buf+="$out"$'\033[K\n'
    fi
  done
  bx_sep "$W" b "${BX_J[@]}"; line="${BX_LINE/${BX_LT}/${BX_BL}}"; buf+="${line%${BX_RT}${BX_R}}${BX_BR}${BX_R}"$'\033[K\n'
  for ((i = shown; i < rows; i++)); do buf+=$'\033[K\n'; done
  if [ "$PK_TYPING" = 1 ]; then
    ui_search_box "$PK_COLS" "FILTER PODS" "$nv of ${#PK_KEY[@]} pods" "/ $PK_Q" $(( ${#PK_Q} + 2 )) "Enter keep   Esc clear   ^U erase   words AND: pod, status or node"
    buf+="$UI_SBOX"$'\n'
  fi
  # ---- position / last action, then the key panel
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
  local cur=""; [ "$nv" = 0 ] || { cur="${PK_TPOD[${PK_V[PK_SEL]}]}"; [ "${#cur}" -le 30 ] || cur="${cur:0:14}~${cur: -14}"; }
  local on=0; [ -n "$cur" ] && on=1
  local ion=0 xl="enable S / U / D"; interactive_enabled && { ion=$on; xl="interactive: on"; }
  if [ -n "${KDASH_ATTACH_ACTION:-}" ]; then
    case "$KDASH_ATTACH_ACTION" in S) mode="open a shell in" ;; U) mode="upload into" ;; *) mode="download from" ;; esac
    bx_panel "$PK_COLS" 4 MOVE FIND "IN THE SHELL" "$(case "$KDASH_ATTACH_ACTION" in S) echo SHELL;; U) echo UPLOAD;; *) echo DOWNLOAD;; esac)" \
      "j/k ${PC_UP}${PC_DN}|move|1" "PgUp/PgDn|page|1" "g / G|first / last|1" "12|go to row 12|1" \
      "/|search pod / status / node|1" "u|needs attention only|1" "Esc|clear the search|1" "|${nv} of ${#PK_KEY[@]} pods|0" \
      "exit|back to this list|1" "kdswitch|related pods|1" "kdquit|leave kdash|1" "|runs with your RBAC|0" \
      "Enter|${mode} the highlighted pod|$on" "|then: pick the container|0" "q / Q|back / quit|1" ">|export to a log|1"
  else
    bx_panel "$PK_COLS" 5 MOVE FIND INSPECT "SHELL ${PC_MID} FILES" LEAVE \
      "j/k ${PC_UP}${PC_DN}|move|1" "PgUp/PgDn|page|1" "g / G|first / last|1" "12|go to row 12|1" \
      "/|search|1" "u|needs attention|1" "s|sort: ${PK_SORT}|1" "F|filters|1" \
      "Enter|summary|$on" "l / p|logs / previous logs|$on" "d / e|describe / events|$on" "w / c|why / containers|$on" \
      "S|shell|$ion" "U|upload|$ion" "D|download|$ion" "X|$xl|1" \
      "q / Q|back / quit|1" ">|export to a log|1" "r|refresh now|1" "?|all keys|1"
  fi
  buf+="$BX_PANEL"
  ui_flush "$buf" "podpick:$PK_COLS:$PK_ROWS" "${PK_FL:-1}"; PK_FL=1
}

# One key; arrows and page keys become tokens. Returns 1 on timeout (live refresh).
picker_key() { # timeout
  local seq="" extra=""
  PK_KEY_IN=""
  IFS= read -rsn1 -t "$1" PK_KEY_IN </dev/tty || { PK_KEY_IN=""; return 1; }
  if [ "$PK_KEY_IN" = $'\033' ]; then
    IFS= read -rsn1 -t 0.15 seq </dev/tty || seq=""
    case "$seq" in '['|O) IFS= read -rsn1 -t 0.15 extra </dev/tty || extra=""; seq+="$extra"; extra="" ;; esac
    case "$seq" in
      '[A'|'OA') PK_KEY_IN='<UP>' ;; '[B'|'OB') PK_KEY_IN='<DN>' ;; '[H'|'OH') PK_KEY_IN='<HOME>' ;; '[F'|'OF') PK_KEY_IN='<END>' ;;
      '[C'|'OC') PK_KEY_IN='<RIGHT>' ;; '[D'|'OD') PK_KEY_IN='<LEFT>' ;;
      '[5'|'[6'|'[1'|'[4'|'[7'|'[8')
        IFS= read -rsn1 -t 0.15 extra </dev/tty || true
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
              >                  export the screen and the whole list to a log file

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
        ! login_auto_maybe || { PK_RESIZED=1; continue; }
      fi
      [ -z "$PK_NUM" ] || [ $((SECONDS - PK_NUM_AT)) -lt 2 ] || PK_NUM=""
      PK_FL=0; continue
    fi
    k="$PK_KEY_IN"; PK_MSG=""
    # keys that only move, sort or filter leave the screen ours: the next frame sends the difference
    if [ "$PK_TYPING" = 1 ]; then PK_FL=0; else case "$k" in j|k|g|G|b|' '|/|'<UP>'|'<DN>'|'<PGUP>'|'<PGDN>'|'<HOME>'|'<END>'|'<LEFT>'|'<RIGHT>'|[0-9]|u|s) PK_FL=0 ;; esac; fi
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
      '>') qx_podlist ;;
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

# > in the pod list: the screen and every pod of the list (its filter and sort), full names
qx_podlist() {
  local f="$TMPD/qx-pods.tsv" j t
  { [ "${ALL_NS:-0}" != 1 ] || printf 'NAMESPACE\t'; printf 'POD\tSTATUS\tREADY\tRESTARTS\tCPU\tMEM\t%%LIMIT\tNODE\n'
    for j in ${PK_V[@]+"${PK_V[@]}"}; do
      [ "${ALL_NS:-0}" != 1 ] || printf '%s\t' "${PK_TNS[j]}"
      printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "${PK_TPOD[j]}" "${PK_TST[j]}" "${PK_TRD[j]}" "${PK_TRS[j]}" "${PK_TCPU[j]}" "${PK_TMEM[j]}" "${PK_TLIM[j]}" "${PK_TND[j]}"
    done; } | qx_align > "$f"
  t="pod list | ${#PK_V[@]} of ${#PK_KEY[@]} pods${PK_Q:+ | filter \"$PK_Q\"}$([ "${PK_ATTN:-0}" != 1 ] || printf ' | needs attention only') | sort ${PK_SORT:-name}"
  quick_export "pod-list_${NS:-ns}" "$t" "$f" "THE WHOLE POD LIST"; PK_MSG="$QX_MSG"
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
    printf ' Enter semicolon-separated fields; omitted fields stay unchanged.\n Example: label=app in (api,worker);status=Pending|CrashLoop;unhealthy=1\n Node uses an exact match; status and workload use extended regex.\n Empty value clears a field. Type clear to reset all; Enter or Esc cancels.\n%s\n\033[?25h filters > ' "$msg"
    ui_edit_line line " > " podfilters || { printf '\033[?25l'; return 1; }
    printf '\033[?25l'
    # Esc, q or an empty line cancels.
    case "$line" in ''|q|Q|*$'\e'*) return 1 ;; esac
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
  printf ' shell [FILTER]          Shell in a pod: one match opens it, otherwise the filtered list\n quit                    Leave kdash (also Q on any screen)\n secrets                 Certificates and keys in Secrets: expiry, users, paths (also Y)\n fmea | access           Failure modes ranked by Action Priority | your RBAC access (also M)\n inspect                 Choose a pod and inspect it\n filter                  Structured pod filters\n pods / nodes / workloads / ip / mem / io / alerts\n check / services / storage / events / explain / doctor / certs\n runbook [etcd-restore | cert-rotate | node-notready | api-unreachable | oidc-login]\n help                    Dashboard help\n\n Commands use fixed handlers and never execute shell text.\n\033[?25h : '
  ui_edit_line command " : " palette || { printf '\033[?25l'; return 0; }; printf '\033[?25l'
  case "$command" in
    '') return 0 ;; inspect|i) inspector_open ;; filter|F) inspector_filter_prompt ;;
    quit|exit|Q) kdash_quit palette ;;
    shell|sh|"shell "*|"sh "*)
      if ! interactive_enabled; then declare -F flash >/dev/null && flash "$(interactive_hint)" 8; return 0; fi
      PK_Q="${command#* }"; [ "$PK_Q" != "$command" ] || PK_Q=""; PK_AUTO=1; PK_SEL_KEY=""
      KDASH_ATTACH_ACTION=S; inspector_open; KDASH_ATTACH_ACTION="" ;;
    pods|nodes|workloads|ip|mem|io|alerts) VIEW="$command"; SCROLL=0; HSCROLL=0 ;;
    services|storage|events|explain|doctor|certs|runbook|check) VIEW="$command"; TOOLKIT_REQUESTED=1; SCROLL=0; HSCROLL=0 ;;
    secrets|secret|Y|secret-map|tls) VIEW=secrets; TOOLKIT_REQUESTED=1; SCROLL=0; HSCROLL=0; [ "$(sm_age)" -lt 60 ] || TOOLKIT_NEXT=0; audit SECRETS_VIEW "from=palette" ;;
    fmea|M|access|rbac) VIEW="$(norm_view "$command")"; TOOLKIT_REQUESTED=1; SCROLL=0; HSCROLL=0; [ "$(fmea_age)" -lt 60 ] || TOOLKIT_NEXT=0; audit FMEA_VIEW "view=$VIEW from=palette" ;;
    runbook\ *) RB_TOPIC="${command#runbook }"; VIEW=runbook; TOOLKIT_REQUESTED=1; SCROLL=0; HSCROLL=0 ;;
    help|'?') if declare -F show_help >/dev/null; then show_help; else printf '\n Use ? on the dashboard for help.\n'; fi ;;
    *) declare -F flash >/dev/null && flash "Unknown command: ${command:0:70}" 5; return 2 ;;
  esac
}
