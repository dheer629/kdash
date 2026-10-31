# Runtime diagnostics, filtering and bounded background snapshots (embedded).
toolkit_clean() { LC_ALL=C tr -d '\000-\010\013\014\016-\037\177'; }

doctor_classify() {
    if grep -qiE 'forbidden|cannot (get|list)' "$1"; then printf 'RBAC denied'
    elif grep -qiE 'Unauthorized|must be logged in|credentials|expired' "$1"; then printf 'authentication failed or expired'
    elif grep -qiE 'x509|certificate|TLS' "$1"; then printf 'TLS certificate validation failed'
    elif grep -qiE 'refused|no route|no such host|dial tcp|Unable to connect' "$1"; then printf 'endpoint unreachable'
    elif grep -qiE 'timeout|deadline exceeded|context canceled' "$1"; then printf 'request timed out'
    elif grep -qiE 'metrics.*not available|not find.*resource|not found|doesn.t have a resource' "$1"; then printf 'API or metrics unavailable'
    else printf 'read failed'; fi
}

doctor_run() {
    local endpoint code=0 probe="$TMPD/doctor.out" err="$TMPD/doctor.err" rows="$TMPD/doctor.rows" resource why
    tk_title "KDASH $KDASH_VERSION DOCTOR" "read-only capability checks - no cluster changes are made"
    endpoint="$("${KC[@]}" config view --minify -o jsonpath='{.clusters[0].cluster.server}' 2>/dev/null)"
    # Only display an endpoint without user info or query parameters.
    endpoint="${endpoint%%\?*}"; case "$endpoint" in *@*) endpoint='(endpoint contains user information; hidden)' ;; esac
    { printf 'SETTING\tVALUE\n'
      printf 'context\t%s\nnamespace\t%s\nkubeconfig\t%s\nAPI endpoint\t%s\naudit log\t%s\n' "$CTX_NAME" "$NS" "$KUBECONF_SHOWN" "${endpoint:-not configured}" "${AUDIT_FILE:-$AUDIT_DIR}"
    } | toolkit_clean | TK_COUNT=0 tk_table "CONNECTION"
    printf 'CHECK\tRESULT*\tDETAIL\tNEXT STEP~\n' > "$rows"
    if "${KC[@]}" get pods "${SCOPE[@]}" -o name > "$probe" 2> "$err"; then
        printf 'pods\t{g}PASS\treadable (an empty namespace is valid)\t-\n' >> "$rows"
    else
        printf 'pods\t{r}FAIL\t%s\tkubectl --context %q -n %q get pods --request-timeout=%ss\n' "$(doctor_classify "$err")" "$CTX_NAME" "${NS/\(all namespaces\)/default}" "$REQUEST_TIMEOUT" >> "$rows"; code=1
    fi
    for resource in nodes services endpointslices.discovery.k8s.io persistentvolumeclaims events; do
        if [ "$resource" = nodes ]; then
            "${KC[@]}" get "$resource" -o name > "$probe" 2> "$err"
        else
            "${KC[@]}" get "$resource" "${SCOPE[@]}" -o name > "$probe" 2> "$err"
        fi
        if [ $? = 0 ]; then printf '%s\t{g}PASS\treadable\t-\n' "$resource" >> "$rows"
        else why="$(doctor_classify "$err")"; printf '%s\t{y}INFO\t%s - this view shows "unknown"\t%s\n' "$resource" "$why" \
               "$([ "$why" = 'RBAC denied' ] && printf 'ask for list on %s' "$resource" || printf -- '-')" >> "$rows"; fi
    done
    if "${KC[@]}" top pod "${SCOPE[@]}" --no-headers > "$probe" 2> "$err"; then
        printf 'metrics\t{g}PASS\tpod CPU / memory readable\t-\n' >> "$rows"
    else
        printf 'metrics\t{y}INFO\t%s; requests / limits and object health remain available\tcheck metrics-server and your metrics.k8s.io permissions\n' "$(doctor_classify "$err")" >> "$rows"
    fi
    if [ -d "$REPORT_DIR" ] && [ -w "$REPORT_DIR" ] || { mkdir -p "$REPORT_DIR" 2>/dev/null && [ -w "$REPORT_DIR" ]; }; then
        printf 'local reports\t{g}PASS\twritable: %s\t-\n' "$REPORT_DIR" >> "$rows"
    else printf 'local reports\t{r}FAIL\tdirectory is not writable: %s\tset KDASH_REPORT_DIR to a writable directory\n' "$REPORT_DIR" >> "$rows"; code=1; fi
    toolkit_clean < "$rows" | tk_table "CHECKS" "$([ "$code" = 0 ] && printf 'all required checks passed' || printf 'a required check failed')" "" check checks
    rm -f "$rows"
    printf '\n'; tk_note "Read-only checks complete; no cluster changes made."
    audit DOCTOR "result=$code context=$CTX_NAME namespace=$NS"
    return "$code"
}

toolkit_init() {
    TOOLKIT_DIR="$TMPD/toolkit"; mkdir -p "$TOOLKIT_DIR"
    FETCH_PID=""; FETCH_NEXT=0; FETCH_FAILURES=0; FETCH_SUCCESS=0
    TOOLKIT_PID=""; TOOLKIT_NEXT=0
    TOOLKIT_REQUESTED=0
    case "${KDASH_UNHEALTHY:-0}" in 1|true|yes|on) KDASH_UNHEALTHY=1 ;; *) KDASH_UNHEALTHY=0 ;; esac
    # Remember the filters the run started with, so the first loop iteration does
    # not mistake them for a change and cancel the initial background read.
    TOOLKIT_FILTER_STATE="$(filter_state)"
}

filter_state() {
    printf '%s|%s|%s|%s|%s' "${KDASH_LABEL_SELECTOR:-}" "${KDASH_STATUS_FILTER:-}" "${KDASH_NODE_FILTER:-}" \
        "${KDASH_WORKLOAD_FILTER:-}" "${KDASH_UNHEALTHY:-0}"
}
# any filter narrowing the pod set (pod regex, label, status, node, workload, unhealthy)
filters_active() {
    case "${FILTER:-.*}" in ''|'.*') ;; *) return 0 ;; esac
    [ -n "${KDASH_LABEL_SELECTOR:-}${KDASH_STATUS_FILTER:-}${KDASH_NODE_FILTER:-}${KDASH_WORKLOAD_FILTER:-}" ] && return 0
    [ "${KDASH_UNHEALTHY:-0}" = 1 ]
}
# human readable filter set, for headers, "no pods match" lines and reports
filter_desc() {
    local d="${FILTER:-.*}"
    [ -z "${KDASH_LABEL_SELECTOR:-}" ] || d="$d label=$KDASH_LABEL_SELECTOR"
    [ -z "${KDASH_STATUS_FILTER:-}" ] || d="$d status=$KDASH_STATUS_FILTER"
    [ -z "${KDASH_NODE_FILTER:-}" ] || d="$d node=$KDASH_NODE_FILTER"
    [ -z "${KDASH_WORKLOAD_FILTER:-}" ] || d="$d workload=$KDASH_WORKLOAD_FILTER"
    [ "${KDASH_UNHEALTHY:-0}" != 1 ] || d="$d unhealthy"
    printf '%s' "$d"
}

# Structured filters on the raw pod spec. Status and workload are derived exactly
# like the model does (MODEL_AWK), so a value shown in a table always filters:
#   status   deletionTimestamp -> Terminating, status.reason (Evicted ...), a waiting
#            reason (CrashLoopBackOff ...), Running with unready containers -> NotReady
#   workload ReplicaSet -> its Deployment, Job with a timestamp suffix -> its CronJob,
#            otherwise the owner name (StatefulSet / DaemonSet / Job), no owner -> pod.
#            The regex is matched against "name" and "Kind/name".
#   node     exact node name, "(unscheduled)" for pods without one
# Regexes come in through ENVIRON: awk -v would rewrite backslash escapes (\. \-).
filter_spec() {
    KDF_SF="${KDASH_STATUS_FILTER:-}" KDF_NF="${KDASH_NODE_FILTER:-}" KDF_WF="${KDASH_WORKLOAD_FILTER:-}" \
    KDF_UH="${KDASH_UNHEALTHY:-0}" awk -F'|' '
    BEGIN { sf = ENVIRON["KDF_SF"]; nf = ENVIRON["KDF_NF"]; wf = ENVIRON["KDF_WF"]; uh = ENVIRON["KDF_UH"] }
    function wl(kind, name, pod,   suf) {
        if (kind == "") { WK = "Pod"; return pod }
        if (kind == "ReplicaSet") {
            WK = "Deployment"
            if (match(name, /-[a-z0-9]+$/)) { suf = substr(name, RSTART + 1); if (length(suf) >= 5 && length(suf) <= 10) return substr(name, 1, RSTART - 1) }
            WK = "ReplicaSet"; return name
        }
        if (kind == "Job" && match(name, /-[0-9]+$/) && RLENGTH >= 9) { WK = "CronJob"; return substr(name, 1, RSTART - 1) }
        WK = kind; return name
    }
    function flush(   a, o, st, w, nd, ok, i, healthy) {
        if (!n) return
        split(row[1], a, "|")
        st = a[3]
        if (a[12] != "") st = "Terminating"; else if (a[13] != "") st = a[13]; else if (waiting != "") st = waiting
        else if (st == "Running" && nready < nctr) st = "NotReady"
        split(a[9], o, " "); k_ = o[1]; split(a[10], o, " "); w = wl(k_, o[1], a[2])
        nd = (a[4] == "") ? "(unscheduled)" : a[4]
        ok = (sf == "" || st ~ sf) && (nf == "" || nd == nf) && (wf == "" || w ~ wf || (WK "/" w) ~ wf)
        healthy = (st == "Succeeded" || st == "Completed" || (st == "Running" && nready >= nctr))
        if (uh == "1" && healthy) ok = 0
        if (ok) for (i = 1; i <= n; i++) print row[i]
    }
    $1 == "P" { flush(); n = 0; waiting = ""; nready = 0; nctr = 0 }
    { row[++n] = $0
      if ($1 == "C") nctr++
      if ($1 == "S") { if ($3 == "true") nready++; if ($6 != "" && waiting == "") waiting = $6 } }
    END { flush() }' "$1"
}

build_model() {
    local original="$SPEC"
    filter_spec "$original" > "$TMPD/spec.filtered"
    SPEC="$TMPD/spec.filtered"; build_model_core; local rc=$?; SPEC="$original"
    return "$rc"
}

# Workers never modify the displayed model. A complete snapshot is adopted only
# after the worker exits. A hung credential plugin is also bounded by the guard.
fetch_worker() (
    trap - EXIT INT TERM HUP
    local parent="$TMPD" job="$TMPD/fetch-job" name
    mkdir -p "$job"
    for name in spec top topprev nodes topnode svc cluster workloads; do cp -f "$parent/$name" "$job/$name" 2>/dev/null || : > "$job/$name"; done
    cp -f "$parent"/*.updated "$job/" 2>/dev/null || true
    [ ! -d "$parent/io" ] || cp -a "$parent/io" "$job/io"
    TMPD="$job"; SPEC="$job/spec"; TOPC="$job/top"; TOPP="$job/topprev"
    NODES="$job/nodes"; TOPN_F="$job/topnode"; SVC="$job/svc"; CLUS="$job/cluster"; WLS="$job/workloads"
    local now; now=$(date +%s)
    if [ $((now - SPEC_AT)) -ge "$SPEC_TTL" ] || [ "$SPEC_OK" != 1 ]; then refresh_spec; fi
    if [ "$now" -ge "${METRICS_NEXT:-0}" ]; then
        [ "$TOPN_STATE" != forbidden ] || TOPN_STATE=unread
        refresh_top
        if [ "$TOP_OK" = 1 ]; then METRICS_NEXT=0; else METRICS_NEXT=$((now + 30)); fi
    fi
    IO_PID=""; io_tick
    if [ -n "$IO_PID" ]; then wait "$IO_PID" 2>/dev/null || true; IO_PID=""; io_tick; fi
    [ -z "$IO_PID" ] || { wait "$IO_PID" 2>/dev/null || true; IO_PID=""; }
    for name in SPEC_OK SPEC_AT TOP_OK TOP_AT NODES_STATE SVC_STATE TOPN_STATE TOPN_OK CLUSTER_STATE WL_STATE WL_KINDS TOPA_STATE NS_SCAN_AT METRICS_NEXT IO_STATE IO_SRC IO_REASON IO_LAST IO_DETECT_AT IO_SAMPLE_AT IO_SRC_PATH; do
        printf '%s\t%s\n' "$name" "${!name:-}"
    done > "$job/state"
    date +%s > "$job/finished"
)

fetch_adopt() {
    [ -n "${FETCH_PID:-}" ] || return 0
    kill -0 "$FETCH_PID" 2>/dev/null && return 0
    wait "$FETCH_PID" 2>/dev/null || true; FETCH_PID=""
    local job="$TMPD/fetch-job" name value
    [ -f "$job/finished" ] || { FETCH_NEXT=$(( $(date +%s) + 5 )); return 0; }
    for name in spec top topprev nodes topnode svc cluster workloads; do [ ! -f "$job/$name" ] || mv -f "$job/$name" "$TMPD/$name"; done
    cp -f "$job"/*.updated "$TMPD/" 2>/dev/null || true
    if [ -d "$job/io" ]; then rm -rf "$TMPD/io"; mv "$job/io" "$TMPD/io"; fi
    while IFS=$'\t' read -r name value; do
        case "$name" in SPEC_OK|SPEC_AT|TOP_OK|TOP_AT|NODES_STATE|SVC_STATE|TOPN_STATE|TOPN_OK|CLUSTER_STATE|WL_STATE|WL_KINDS|TOPA_STATE|NS_SCAN_AT|METRICS_NEXT|IO_STATE|IO_SRC|IO_REASON|IO_LAST|IO_DETECT_AT|IO_SAMPLE_AT|IO_SRC_PATH) printf -v "$name" '%s' "$value" ;; esac
    done < "$job/state"
    if [ "$SPEC_OK" = 1 ]; then FETCH_SUCCESS=$(cat "$job/finished"); FETCH_FAILURES=0
    else FETCH_FAILURES=$(( FETCH_FAILURES + 1 )); fi
    local delay="$INTERVAL"
    [ "$FETCH_FAILURES" = 0 ] || delay=$(( 2 ** (FETCH_FAILURES > 5 ? 5 : FETCH_FAILURES) ))
    FETCH_NEXT=$(( $(date +%s) + ${delay%.*} ))
    build_model; session_tick; FETCH_AT=$(date +%s)
}

fetch() {
    if [ "${INTERACTIVE:-0}" != 1 ]; then fetch_sync; return; fi
    fetch_adopt
    [ -z "${FETCH_PID:-}" ] || return 0
    [ "$(date +%s)" -ge "${FETCH_NEXT:-0}" ] || return 0
    fetch_worker & FETCH_PID=$!
}

toolkit_tick() {
    if [ -n "${TOOLKIT_PID:-}" ] && ! kill -0 "$TOOLKIT_PID" 2>/dev/null; then
        wait "$TOOLKIT_PID" 2>/dev/null || true; TOOLKIT_PID=""
        if [ -d "$TMPD/toolkit-next" ]; then
            rm -rf "$TOOLKIT_DIR"; mv "$TMPD/toolkit-next" "$TOOLKIT_DIR"
        fi
        TOOLKIT_NEXT=$(( $(date +%s) + 30 ))
    fi
    [ "${TOOLKIT_REQUESTED:-0}" = 1 ] || return 0
    [ -z "${TOOLKIT_PID:-}" ] || return 0
    [ "$(date +%s)" -ge "${TOOLKIT_NEXT:-0}" ] || return 0
    (
        trap - EXIT INT TERM HUP
        local next="$TMPD/toolkit-next"
        mkdir -p "$next"; cp -f "$TOOLKIT_DIR"/* "$next/" 2>/dev/null || true
        TOOLKIT_DIR="$next"
        events_collect; health_collect
        TK_COLOR="${COLOR:-1}" TK_COLS="${KDASH_COLUMNS:-$(tput cols 2>/dev/null || echo 160)}" TK_GLYPH="${BARCHR:-unicode}" doctor_run > "$TOOLKIT_DIR/doctor.txt"
    ) & TOOLKIT_PID=$!
}

toolkit_cancel() {
    local pid kids
    for pid in "${FETCH_PID:-}" "${TOOLKIT_PID:-}"; do
        # its children too (kubectl, cp, mv): left running they would write into the
        # removed temp dir and print "No such file or directory" after kdash quit
        [ -n "$pid" ] || continue
        kids=""; command -v pgrep >/dev/null 2>&1 && kids="$(pgrep -P "$pid" 2>/dev/null | tr '\n' ' ')"
        kill "$pid" 2>/dev/null || true                    # the worker first: it then reports nothing
        [ -z "$kids" ] || kill $kids 2>/dev/null || true
        wait "$pid" 2>/dev/null || true
    done
    FETCH_PID=""; TOOLKIT_PID=""
    rm -rf "$TMPD/fetch-job" "$TMPD/toolkit-next"
}

toolkit_panel() {
    local view="$1"
    # Standard header (tab bar, clock, context, health line, warnings), then the panel body.
    HEADER_ONLY=1 render_core
    # tables fit the window and carry colour markers (made into escapes after cleaning)
    local TK_COLOR="${COLOR:-1}" TK_COLS="${KDASH_COLUMNS:-$(tput cols 2>/dev/null || echo 160)}" TK_GLYPH="${BARCHR:-unicode}"
    export TK_COLOR TK_COLS TK_GLYPH
    case "$view" in
        services) health_render_services ;; storage) health_render_storage ;;
        events) events_render ;; explain) explain_render "${NS/\(all namespaces\)/}" "${EXPLAIN_POD:-}" ;;
        doctor) if [ -f "$TOOLKIT_DIR/doctor.txt" ]; then cat "$TOOLKIT_DIR/doctor.txt"; else printf 'Checking capabilities in background...\n'; fi ;;
    esac | toolkit_clean | tk_colorize > "$BODYF"
    export -n TK_COLOR TK_COLS TK_GLYPH
    printf '8 services | 9 storage | E events | ! why | j/k scroll | h/l pan | i inspect | : commands | q quit\n' > "$FTRF"
}

render() {
    case "$VIEW" in services|storage|events|explain|doctor) toolkit_panel "$VIEW" ;;
        *) render_core ;;
    esac
    local age=never status=not-collected
    [ "${SPEC_AT:-0}" = 0 ] || age="$(( $(date +%s) - SPEC_AT ))s"
    [ "${SPEC_OK:-0}" != 1 ] || status=fresh
    [ "${SPEC_OK:-0}" = 1 ] || { [ ! -s "$SPEC" ] || status=STALE; }
    printf 'Data pods=%s age=%s metrics=%s | Enter/i inspect | 8 services 9 storage E events ! explain : commands\n' \
        "$status" "$age" "$([ "$TOP_OK" = 1 ] && echo available || echo unavailable)" >> "$HDRF"
    local source updated
    for source in nodes svc; do
        updated="$(cat "$TMPD/$source.updated" 2>/dev/null || printf 0)"
        case "$updated" in ''|*[!0-9]*) updated=0 ;; esac
        if [ "$updated" != 0 ] && [ $(( $(date +%s) - updated )) -gt "$SPEC_TTL" ]; then
            printf 'STALE %s: last successful read %ss ago\n' "$source" "$(( $(date +%s) - updated ))" >> "$HDRF"
        fi
    done
}

toolkit_filters_changed() {
    local now; now="$(filter_state)"
    if [ "$now" != "${TOOLKIT_FILTER_STATE:-}" ]; then
        local old_label="${TOOLKIT_FILTER_STATE%%|*}"
        toolkit_cancel; FETCH_NEXT=0; LAST=0
        # Only a label selector changes what the API returns; the other filters
        # run locally on the spec already read, so the view updates immediately.
        [ "$old_label" = "${KDASH_LABEL_SELECTOR:-}" ] || SPEC_AT=0
        TOOLKIT_FILTER_STATE="$now"; build_model
        declare -F session_reset_state >/dev/null && session_reset_state
        NPODS=$(awk -F'\t' '$1=="pods"{print $2}' "$MODEL/meta.tsv" 2>/dev/null)
        declare -F flash >/dev/null && flash "filters: $(filter_desc) - ${NPODS:-0} pod(s)" 6
    fi
}

toolkit_export() {
    local dir="$1" item
    [ -d "$dir" ] || return 0
    for item in services storage events explain; do
        case "$item" in services) health_render_services ;; storage) health_render_storage ;;
            events) events_render ;; explain) explain_render ;; esac | toolkit_clean > "$dir/$item.txt"
    done
    mkdir -p "$dir/diagnostics"
    cp -f "$TOOLKIT_DIR"/*.tsv "$TOOLKIT_DIR"/*.status "$dir/diagnostics/" 2>/dev/null || true
}
