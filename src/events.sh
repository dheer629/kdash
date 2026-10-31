# Kubernetes API Events and deterministic incident evidence. This source module
# is embedded into the deployable Bash CLI; it adds no runtime dependencies.
# events.tsv: NS KIND NAME UID TYPE REASON COUNT FIRST LAST MESSAGE (TSV).
# UID is the involved resource UID, not the Event UID. API Event UIDs are used
# internally to discard duplicate records, never to merge distinct Events.

# ---- table output for the diagnostics views (8 services, 9 storage, E events, ! why)
# Renderers print plain TSV; tk_table lays it out. Header flags: a leading ">" right-
# aligns the column, a trailing "*" colours it as a status (by keyword), a trailing
# "~" dims it. A cell may start with {r} {y} {g} {b} {d} to choose its own colour.
# Colour is written as "~[..m" markers (TK_COLOR=1, the live dashboard only) so the
# control-byte filter keeps working; tk_colorize turns them into escapes afterwards.
# TK_COLS limits the width: the last column is cut to fit, wide columns shrink first.
TK_TABLE_AWK='
function K(c, s) { return (TKC && c != "") ? "~[" c "m" s "~[0m" : s }
function vl(s,   t) { t = s; gsub(/~\[[0-9;]*m/, "", t); if (VLB) gsub(/[\200-\277]/, "", t); return length(t) }
function cut(s, w,   t, n) {
  if (w < 1) return ""; if (vl(s) <= w) return s
  t = s; n = w - 1
  if (VLB) { while (vl(t) > n) t = substr(t, 1, length(t) - 1) } else t = substr(t, 1, n)
  return t "~"
}
function pad(s, w, right,   g) { g = w - vl(s); if (g < 0) g = 0; return right ? sprintf("%" g "s", "") s : s sprintf("%" g "s", "") }
function sev(s,   t) { t = tolower(s)
  if (t ~ /fail|error|forbidden|denied|mismatch|missing|crash|oomkill|lost|critical|unbound|not ready|notready|unready|no endpoints|no match|evicted|auth-error|tls-error|unreachable|timeout/) return "1;31"
  if (t ~ /warn|pending|unknown|stale|waitfor|resiz|terminat|degraded|collecting|partial|no-data|unavailable|selectorless|released|info/) return "35"
  if (t ~ /^(ok|bound|running|ready|normal|healthy|true|available|succeeded|active|external|completed)/) return "32"
  return "90" }
function own(s) { if (s ~ /^\{[rygbd]\}/) { OC = substr(s, 2, 1); return substr(s, 4) } OC = ""; return s }
function occ(c) { return c == "r" ? "1;31" : c == "y" ? "35" : c == "g" ? "32" : c == "b" ? "1" : c == "d" ? "90" : "" }
BEGIN { FS = "\t"; TKC = (ENVIRON["TK_COLOR"] == "1"); W = ENVIRON["TK_COLS"] + 0
  VLB = (length("\342\226\210") != 1); DOT = (ENVIRON["TK_GLYPH"] == "ascii") ? "*" : "\342\227\217"; HR = (ENVIRON["TK_GLYPH"] == "ascii") ? "-" : "\342\224\200" }
NR == 1 { nc = split($0, H, "\t")
  for (i = 1; i <= nc; i++) { RA[i] = (substr(H[i], 1, 1) == ">"); if (RA[i]) H[i] = substr(H[i], 2)
    ST[i] = (H[i] ~ /\*$/); DM[i] = (H[i] ~ /~$/); if (ST[i] || DM[i]) H[i] = substr(H[i], 1, length(H[i]) - 1); WD[i] = vl(H[i]) }
  next }
{ nr++; for (i = 1; i <= nc; i++) { v = $i; if (v == "") v = "-"; v = own(v); CL[nr, i] = OC; if (ST[i]) v = DOT " " v
    CE[nr, i] = v; if (vl(v) > WD[i]) WD[i] = vl(v) } }
END {
  t = K("1", title); if (nr > 0 && count != "0") t = t "  " K("90", nr (nr == 1 ? " " one : " " many))
  if (sub_ != "") t = t K("90", "   " sub_)
  print ""; print t
  if (nr == 0) { print "  " K("90", empty != "" ? empty : "none"); exit }
  for (i = 1; i < nc; i++) if (WD[i] > 56) WD[i] = 56
  if (W > 0) {
    tot = 2; for (i = 1; i <= nc; i++) tot += WD[i] + (i > 1 ? 2 : 0)
    # the last column (long free text) gives way first, then the widest middle
    # column, and the first column (the object name) last of all
    while (tot > W && WD[nc] > 24) { WD[nc]--; tot-- }
    while (tot > W) { m = 0; for (i = 2; i < nc; i++) if (!ST[i] && !RA[i] && WD[i] > 20 && (m == 0 || WD[i] > WD[m])) m = i
      if (m == 0) break; WD[m]--; tot-- }
    while (tot > W && WD[1] > 40) { WD[1]--; tot-- }      # beyond this, h / l pans
    if (tot > W) { WD[nc] -= tot - W; if (WD[nc] < 12) WD[nc] = 12 }
  }
  h = "  "; for (i = 1; i <= nc; i++) h = h (i > 1 ? "  " : "") pad(cut(H[i], WD[i]), (i < nc || TKC) ? WD[i] : 0, RA[i])
  if (TKC) print K("1;4", h)
  else { print h; r = "  "; for (i = 1; i <= nc; i++) { r = r (i > 1 ? "  " : ""); lw = (i < nc) ? WD[i] : (WD[i] > 40 ? 40 : WD[i]); for (j = 0; j < lw; j++) r = r "-" } print r }
  for (n = 1; n <= nr; n++) { line = "  "
    for (i = 1; i <= nc; i++) { v = cut(CE[n, i], WD[i]); c = occ(CL[n, i])
      if (ST[i] && c == "") { c = sev(substr(CE[n, i], length(DOT) + 2)) }
      if (c == "" && DM[i]) c = "90"
      line = line (i > 1 ? "  " : "") K(c, pad(v, i < nc ? WD[i] : 0, RA[i])) }
    sub(/ +$/, "", line); print line }
}'
tk_table() { # title [subtitle] [empty-message] [one many] < TSV (header line first)
  LC_ALL=C awk -v title="$1" -v sub_="${2:-}" -v empty="${3:-}" -v one="${4:-item}" -v many="${5:-items}" -v count="${TK_COUNT:-1}" "$TK_TABLE_AWK"
}
tk_by_severity() { LC_ALL=C awk -F'\t' '{ r = ($1 ~ /CRIT/) ? 1 : ($1 ~ /WARN/) ? 2 : 3; print r "\t" $0 }' | LC_ALL=C sort -t $'\t' -k1,1n -k3,3 | cut -f2-; }
tk_colorize() { sed 's/~\[\([0-9;]*\)m/\x1b[\1m/g'; }
tk_note() { # dim footnote line
  if [ "${TK_COLOR:-0}" = 1 ]; then printf '  ~[90m%s~[0m\n' "$*"; else printf '  %s\n' "$*"; fi
}
tk_title() { # view title + subtitle, then a blank line
  if [ "${TK_COLOR:-0}" = 1 ]; then printf '~[1;7m %s ~[0m  ~[90m%s~[0m\n' "$1" "$2"; else printf '%s  -  %s\n' "$1" "$2"; fi
}
# "2026-10-30T08:05:12Z" -> epoch, in any awk (no mktime): days-from-civil
TK_TIME_AWK='
function epoch(s,   y, m, d, H, M, S, era, yoe, doy, doe) {
  if (s !~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]/) return -1
  y = substr(s, 1, 4) + 0; m = substr(s, 6, 2) + 0; d = substr(s, 9, 2) + 0; H = substr(s, 12, 2) + 0; M = substr(s, 15, 2) + 0; S = substr(s, 18, 2) + 0
  if (m <= 2) y--; era = int((y >= 0 ? y : y - 399) / 400); yoe = y - era * 400
  doy = int((153 * (m + (m > 2 ? -3 : 9)) + 2) / 5) + d - 1; doe = yoe * 365 + int(yoe / 4) - int(yoe / 100) + doy
  return ((era * 146097 + doe - 719468) * 86400) + H * 3600 + M * 60 + S }
function ago(s,   e, a) { e = epoch(s); if (e < 0) return "-"; a = NOW - e; if (a < 0) a = 0
  if (a < 60) return a "s"; if (a < 3600) return int(a / 60) "m"; if (a < 86400) return int(a / 3600) "h" sprintf("%02dm", int((a % 3600) / 60)); return int(a / 86400) "d" sprintf("%02dh", int((a % 86400) / 3600)) }
'

events_context() {
    local value="${CTX_NAME:-${CTX:-}}" arg next=0
    for arg in "${KC[@]}"; do
        if [ "$next" = 1 ]; then value="$arg"; next=0; continue; fi
        case "$arg" in
            --context) next=1 ;;
            --context=*) value="${arg#*=}" ;;
        esac
    done
    printf '%s' "${value:-<selected-context>}"
}

events_scope_key() {
    local arg next=0 config=""
    for arg in "${KC[@]}"; do
        if [ "$next" = 1 ]; then config="$arg"; next=0; continue; fi
        case "$arg" in
            --kubeconfig) next=1 ;;
            --kubeconfig=*) config="${arg#*=}" ;;
        esac
    done
    printf '%q|%q|%q|%q' "$(events_context)" "$config" "${NS:-}" "${ALL_NS:-0}"
}

events_text() {
    # Prevent object/event strings from injecting terminal controls or rows.
    LC_ALL=C awk 'BEGIN { ORS = "" } { gsub(/[[:cntrl:]]/, " "); if (NR > 1) printf " "; printf "%s", $0 }'
}

events_command() {    # namespace, verb/resource/arguments: printable Bash command
    local namespace="$1" arg next=0 config=""
    shift
    for arg in "${KC[@]}"; do
        if [ "$next" = 1 ]; then config="$arg"; next=0; continue; fi
        case "$arg" in
            --kubeconfig) next=1 ;;
            --kubeconfig=*) config="${arg#*=}" ;;
        esac
    done
    printf 'kubectl --context %q' "$(events_context)"
    [ -z "$config" ] || printf ' --kubeconfig %q' "$config"
    printf ' %q' "$@"
    if [ -n "$namespace" ]; then printf ' -n %q' "$namespace"; fi
    printf ' --request-timeout=10s\n'
}

events_empty_table() {
    printf 'NS\tKIND\tNAME\tUID\tTYPE\tREASON\tCOUNT\tFIRST\tLAST\tMESSAGE\n'
}

events_collect() {
    local directory="${TOOLKIT_DIR:?TOOLKIT_DIR must name a private directory}"
    local stem="$directory/events.collect.${BASHPID:-$$}" scope status error template
    mkdir -p -- "$directory" || return 1
    scope="$(events_scope_key)"
    if [ ! -f "$directory/events.scope" ] || [ "$(cat -- "$directory/events.scope")" != "$scope" ]; then
        # A failed read after switching scope must not reveal an older scope.
        events_empty_table > "$directory/events.tsv"
        rm -f -- "$directory/events.updated"
    fi
    printf '%s\n' "$scope" > "$directory/events.scope"
    date +%s > "$directory/events.checked"

    # Go's quoted strings keep embedded newlines and tabs inside one field.
    # The portable awk decoder below flattens controls without eval or JSON tools.
    template='{{range .items}}{{printf "%q\t%q\t%q\t%q\t%q\t%q\t" .metadata.namespace .involvedObject.kind .involvedObject.name .involvedObject.uid .type .reason}}{{if .series.count}}{{.series.count}}{{else if .count}}{{.count}}{{else}}1{{end}}{{printf "\t"}}{{if .firstTimestamp}}{{printf "%q" .firstTimestamp}}{{else if .eventTime}}{{printf "%q" .eventTime}}{{else}}{{printf "%q" .metadata.creationTimestamp}}{{end}}{{printf "\t"}}{{if .series.lastObservedTime}}{{printf "%q" .series.lastObservedTime}}{{else if .lastTimestamp}}{{printf "%q" .lastTimestamp}}{{else if .eventTime}}{{printf "%q" .eventTime}}{{else}}{{printf "%q" .metadata.creationTimestamp}}{{end}}{{printf "\t%q\t%q\n" .message .metadata.uid}}{{end}}'

    status=ok; error=""
    if "${KC[@]}" get events "${SCOPE[@]}" --request-timeout=10s -o go-template="$template" > "$stem.raw" 2> "$stem.err"; then
        if LC_ALL=C awk '
            BEGIN { FS = "\t"; OFS = "\t" }
            function clean(s,    i,c,e,n,out) {
                if (s == "" || s == "<nil>" || s == "<no value>" || substr(s, 1, 3) == "%!q") return "-"
                if (substr(s, 1, 1) == "\"" && substr(s, length(s), 1) == "\"") s = substr(s, 2, length(s) - 2)
                out = ""
                for (i = 1; i <= length(s); i++) {
                    c = substr(s, i, 1)
                    if (c == "\\" && i < length(s)) {
                        e = substr(s, ++i, 1)
                        if (e == "\\" || e == "\"") c = e
                        else if (e ~ /^[abfnrtv]$/) c = " "
                        else if (e == "x") { i += 2; c = " " }
                        else if (e == "u" || e == "U") {
                            n = (e == "u" ? 4 : 8); c = "\\" e substr(s, i + 1, n); i += n
                        } else c = "\\" e
                    }
                    out = out c
                }
                gsub(/[[:cntrl:]]/, " ", out)
                gsub(/[[:space:]]+/, " ", out)
                sub(/^ /, "", out); sub(/ $/, "", out)
                return out == "" ? "-" : out
            }
            function timekey(s,    fraction) {
                if (s == "-") return ""
                fraction = (substr(s, 20, 1) == "." ? substr(s, 21) : "")
                sub(/[^0-9].*$/, "", fraction)
                return substr(s, 1, 19) "." substr(fraction "000000000", 1, 9)
            }
            NF != 11 { bad = 1; next }
            {
                for (i = 1; i <= 11; i++) v[i] = clean($i)
                if (v[7] !~ /^[0-9]+$/ || v[7] + 0 < 1) v[7] = 1
                key = (v[11] == "-" ? "row:" NR : "uid:" v[11])
                row = v[1]; for (i = 2; i <= 10; i++) row = row OFS v[i]
                if (!(key in rows) || timekey(v[9]) >= last[key]) { rows[key] = row; last[key] = timekey(v[9]) }
            }
            END { if (bad) exit 2; for (key in rows) print last[key], rows[key] }
        ' "$stem.raw" > "$stem.rows"; then
            events_empty_table > "$stem.tsv"
            if LC_ALL=C sort -t $'\t' -k1,1r -k2,2 -k4,4 "$stem.rows" | cut -f2- >> "$stem.tsv"; then
                if [ "$(cat -- "$directory/events.scope")" != "$scope" ]; then
                    rm -f -- "$stem.raw" "$stem.err" "$stem.rows" "$stem.tsv"
                    return 1
                fi
                mv -f -- "$stem.tsv" "$directory/events.tsv"
                date +%s > "$directory/events.updated"
            else
                status=error; error="Events could not be saved; check the local toolkit directory."
            fi
        else
            status=error; error="Events response could not be parsed; coverage is unknown."
        fi
    elif LC_ALL=C grep -qiE 'forbidden|cannot (list|get).*events' "$stem.err"; then
        status=forbidden; error="Events access denied; check list events permission for this scope."
    elif LC_ALL=C grep -qiE "doesn.t have a resource type|could not find the requested resource|resource.*not found|not supported" "$stem.err"; then
        status=unavailable; error="The Kubernetes Events API is unavailable for this connection."
    else
        status=error; error="Events request failed; check connection, TLS, authentication and timeout with --doctor."
    fi
    if [ "$(cat -- "$directory/events.scope")" != "$scope" ]; then
        rm -f -- "$stem.raw" "$stem.err" "$stem.rows" "$stem.tsv"
        return 1
    fi
    # Never publish raw kubectl stderr: authentication plugins can include secrets.
    printf '%s\n' "$status" > "$directory/events.status"
    printf '%s\n' "$error" > "$directory/events.error"
    rm -f -- "$stem.raw" "$stem.err" "$stem.rows" "$stem.tsv"
    [ "$status" = ok ]
}

events_cache_valid() {
    [ -f "${TOOLKIT_DIR:-}/events.scope" ] &&
        [ "$(cat -- "$TOOLKIT_DIR/events.scope")" = "$(events_scope_key)" ]
}

events_header() {    # filtered namespace (empty = all), optional pod -> a one-row source table
    local namespace="${1:-}" pod="${2:-}" status=unknown updated="" now age="-" detail
    if ! events_cache_valid; then
        if [ -n "${TOOLKIT_PID:-}" ]; then status=collecting; detail="first read in progress; values appear when it completes"
        else status=unknown; detail="no Events collected for this context and scope"; fi
    else
        [ ! -f "$TOOLKIT_DIR/events.status" ] || IFS= read -r status < "$TOOLKIT_DIR/events.status" || true
        [ ! -f "$TOOLKIT_DIR/events.updated" ] || IFS= read -r updated < "$TOOLKIT_DIR/events.updated" || true
        case "$updated" in ''|*[!0-9]*) detail="no successful Events read yet" ;;
            *) now=$(date +%s); age="$((now - updated))s ago"; detail="read succeeded"
               [ "$status" = ok ] || detail="STALE - showing the last successful read" ;; esac
        if [ "$status" != ok ] && [ -s "$TOOLKIT_DIR/events.error" ]; then detail="$detail; $(events_text < "$TOOLKIT_DIR/events.error")"; fi
    fi
    { printf 'SOURCE\tSTATE*\t>READ\tSCOPE\tDETAIL~\n'
      printf 'events\t%s\t%s\t%s\t%s\n' "$(printf '%s' "$status" | events_text)" "$age" \
        "$(printf '%s%s' "${namespace:-all namespaces}" "${pod:+ / pod $pod}" | events_text)" "$detail"
    } | TK_COUNT=0 tk_table "DATA SOURCES" "context $(events_context | events_text)"
}

events_rows() {    # namespace, pod, warnings-only (0/1); no API calls
    local namespace="${1:-}" pod="${2:-}" warnings="${3:-0}"
    events_cache_valid && [ -f "$TOOLKIT_DIR/events.tsv" ] || return 0
    LC_ALL=C awk -F '\t' -v ns="$namespace" -v pod="$pod" -v warn="$warnings" '
        NR > 1 && (ns == "" || $1 == ns) && (pod == "" || ($2 == "Pod" && $3 == pod)) && (!warn || $5 == "Warning") { print }
    ' "$TOOLKIT_DIR/events.tsv"
}

events_render() {    # optional namespace, pod; rendering never calls the API
    local namespace="${1:-}" pod="${2:-}" maximum="${KDASH_EVENTS_TOP:-100}"
    if [ "$#" -eq 0 ] && [ "${ALL_NS:-0}" != 1 ]; then namespace="${NS:-}"; fi
    case "$maximum" in ''|*[!0-9]*) maximum=100 ;; esac
    [ "$maximum" -ge 1 ] && [ "$maximum" -le 500 ] || maximum=100
    tk_title "KUBERNETES EVENTS" "API events, newest first - local session changes are recorded separately"
    events_header "$namespace" "$pod"
    events_rows "$namespace" "$pod" | LC_ALL=C awk -F '\t' -v limit="$maximum" -v now="$(date +%s)" -v allns="$([ -z "$namespace" ] && echo 1 || echo 0)" "$TK_TIME_AWK"'
        BEGIN { NOW = now; print "LAST SEEN\tTYPE*\tREASON\tOBJECT\t>COUNT\tFIRST SEEN~\tMESSAGE" > "/dev/stderr" }
        { n++; if ($5 == "Warning") w++
          if (n > limit) next
          printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\n", ago($9), ($5 == "Warning" ? "{y}Warning" : $5), ($5 == "Warning" ? "{b}" : "") $6, (allns ? $1 "/" : "") $2 "/" $3, $7, ago($8) " ago", $10 }
        END { printf "%d\t%d\n", n, w > "/dev/stderr" }
    ' 2> "${TOOLKIT_DIR:-/tmp}/events.view.meta" > "${TOOLKIT_DIR:-/tmp}/events.view.rows"
    local hdr total=0 warn=0
    { IFS= read -r hdr; IFS=$'\t' read -r total warn; } < "${TOOLKIT_DIR:-/tmp}/events.view.meta" || true
    { printf '%s\n' "$hdr"; cat "${TOOLKIT_DIR:-/tmp}/events.view.rows"; } |
        tk_table "EVENTS" "$([ "${total:-0}" -gt 0 ] && printf '%s warning, %s normal%s' "${warn:-0}" "$(( ${total:-0} - ${warn:-0} ))" "$([ "$total" -gt "$maximum" ] && printf ' - newest %s shown (KDASH_EVENTS_TOP)' "$maximum")")" \
        "no retained Events match - this does not establish application health" event events
    rm -f "${TOOLKIT_DIR:-/tmp}/events.view.meta" "${TOOLKIT_DIR:-/tmp}/events.view.rows"
}

explain_render() {    # optional namespace, pod; hypotheses never assert causation
    local namespace="${1:-}" pod="${2:-}" d="${TOOLKIT_DIR:-/tmp}/why-view" command_prefix
    if [ "$#" -eq 0 ] && [ "${ALL_NS:-0}" != 1 ]; then namespace="${NS:-}"; fi
    command_prefix="$(events_command "")"
    mkdir -p "$d"
    tk_title "WHY - INCIDENT EVIDENCE" "warning events grouped into possible explanations - timing alone does not establish a cause"
    events_header "$namespace" "$pod"
    # pods that are not Running and fully ready (the dashboard model, its own read time)
    if [ -n "${MODEL:-}" ] && [ -f "$MODEL/pods.tsv" ]; then
        LC_ALL=C awk -F '\t' -v ns="$namespace" -v pod="$pod" -v of="$d/pods.tsv" '
            BEGIN { print "POD\tSTATUS*\t>READY\t>RESTARTS\tNODE" > of }
            NR > 1 && (ns == "" || $2 == ns) && (pod == "" || $3 == pod) {
                split($5, r, "/"); ok = ($4 == "Running" || $4 == "Succeeded" || $4 == "Completed") && (r[1] == r[2] || $4 != "Running")
                if (pod == "" && ok) { healthy++; next }
                for (i = 2; i <= 7; i++) gsub(/[[:cntrl:]]/, " ", $i)
                print (ns == "" ? $2 "/" : "") $3 "\t" $4 "\t" $5 "\t" ($6 + 0 > 0 ? "{y}" : "") $6 "\t" $7 > of }
            END { printf "%d\n", healthy + 0 }
        ' "$MODEL/pods.tsv" > "$d/healthy"
        tk_table "PODS NEEDING ATTENTION" "$(n=$(cat "$d/healthy" 2>/dev/null); [ "${n:-0}" = 0 ] || printf '%s other pods are Running and ready' "$n") - from the dashboard model" \
            "every pod is Running and ready" pod pods < "$d/pods.tsv"
    fi
    # warning evidence, one row per object and category; explanations and checks below
    events_rows "$namespace" "$pod" 1 | EVENTS_COMMAND_PREFIX="$command_prefix" LC_ALL=C awk -F '\t' -v now="$(date +%s)" -v allns="$([ -z "$namespace" ] && echo 1 || echo 0)" \
        -v ef="$d/evidence.tsv" -v xf="$d/explain.tsv" -v cf="$d/checks.tsv" "$TK_TIME_AWK"'
        function cat_of(reason, msg,   c, m) { c = "other"; m = tolower(msg)
            if (reason ~ /^(FailedScheduling|SchedulingGated)$/) c = "scheduling"
            else if (reason ~ /^(FailedMount|FailedAttachVolume|FailedBinding|ProvisioningFailed|FailedMapVolume|FailedUnmapVolume|VolumeFailedMount)$/) c = "storage"
            else if (reason ~ /^(Unhealthy|ProbeWarning)$/) c = "probe"
            else if (reason ~ /^(ErrImagePull|ImagePullBackOff|InvalidImageName|InspectFailed|ErrImageNeverPull)$/) c = "image"
            else if (reason == "BackOff") c = "restart"
            else if (reason ~ /^(OOMKilling|OOMKilled)$/) c = "memory"
            if (m ~ /failed to pull|pull image|imagepull|manifest unknown|back-off pulling/) c = "image"
            return c }
        function col(c) { return (c == "memory" || c == "image" || c == "restart") ? "{r}" : (c == "other" ? "{d}" : "{y}") }
        function q(s,   quote) {
            if (s ~ /^[A-Za-z0-9._\/:=-]+$/) return s
            quote = sprintf("%c", 39)
            gsub(quote, quote "\\\\" quote quote, s)
            return quote s quote
        }
        BEGIN { NOW = now; prefix = ENVIRON["EVENTS_COMMAND_PREFIX"]
            X["scheduling"] = "scheduler constraints, capacity or an unbound claim may block placement - read the scheduler message"
            X["storage"] = "volume binding, provisioning, attachment or mounting may block startup - not evidence of a full volume"
            X["probe"] = "a readiness, liveness or startup probe may be failing - check its settings and the application logs"
            X["image"] = "image reference, registry access or pull credentials may prevent the container from starting"
            X["restart"] = "a container may be exiting repeatedly - the event alone does not say why"
            X["memory"] = "memory pressure or an OOM kill at that time - not a current memory measurement"
            X["other"] = "needs object-specific investigation - its presence alone does not establish a cause"
            print "#\tLAST SEEN\tOBJECT\tREASON\t>COUNT\tCATEGORY\tMESSAGE" > ef
            print "CATEGORY\tEVIDENCE\tPOSSIBLE EXPLANATION" > xf
            print "#\tNEXT READ-ONLY CHECK" > cf }
        { c = cat_of($6, $10); key = $1 "/" $2 "/" $3 "/" $4 "/" c
          if (key in seen) next; seen[key] = 1; if (++n > 20) next
          obj = (allns ? $1 "/" : "") $2 "/" $3
          printf "%d\t%s\t%s\t%s\t%s\t%s\t%s\n", n, ago($9), obj, $6, $7, col(c) c, $10 > ef
          if (!(c in EV)) CO[++nc] = c; EV[c] = EV[c] (EV[c] == "" ? "#" : ", #") n
          kind = tolower($2); base = prefix " -n " q($1) " "
          if (!((base "describe " kind " " q($3)) in done)) { done[base "describe " kind " " q($3)] = 1; printf "%d\t%sdescribe %s %s\n", n, base, kind, q($3) > cf }
          if (c == "storage" && !((base "get pvc") in done)) { done[base "get pvc"] = 1; printf "%d\t%sget pvc\n", n, base > cf }
          if ($2 == "Pod" && (c == "restart" || c == "memory") && !((base "logs P" $3) in done)) { done[base "logs P" $3] = 1; printf "%d\t%slogs %s --all-containers --previous --tail=100\n", n, base, q($3) > cf }
          if ($2 == "Pod" && c == "probe" && !((base "logs C" $3) in done)) { done[base "logs C" $3] = 1; printf "%d\t%slogs %s --all-containers --tail=100 --since=5m\n", n, base, q($3) > cf } }
        END { for (i = 1; i <= nc; i++) printf "%s\t%s\t%s\n", col(CO[i]) CO[i], EV[CO[i]], X[CO[i]] > xf }
    '
    tk_table "WARNING EVIDENCE" "one row per object and category, newest first, up to 20" \
        "no retained warning events - coverage gaps, expired events and failures without events remain possible" item items < "$d/evidence.tsv"
    [ "$(wc -l < "$d/explain.tsv")" -le 1 ] || tk_table "POSSIBLE EXPLANATIONS" "hypotheses to check, not conclusions" "" category categories < "$d/explain.tsv"
    if [ "$(wc -l < "$d/checks.tsv")" -gt 1 ]; then
        tk_table "NEXT READ-ONLY CHECKS" "copy and run - all of them only read" "" check checks < "$d/checks.tsv"
    elif [ -n "$pod" ]; then
        printf '#\tNEXT READ-ONLY CHECK\n-\t%s\n' \
            "$(events_command "$namespace" describe pod "$pod")" | tk_table "NEXT READ-ONLY CHECKS" "" ""
    fi
    printf '\n'
    tk_note "Compare current readiness, resource identities, logs and workload conditions before deciding on a change."
    rm -rf "$d"
}
