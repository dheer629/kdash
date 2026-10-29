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
    local endpoint code=0 probe="$TMPD/doctor.out" err="$TMPD/doctor.err"
    printf 'KDASH %s DOCTOR\nContext: %s\nNamespace: %s\nKubeconfig: %s\n' "$KDASH_VERSION" "$CTX_NAME" "$NS" "$KUBECONF_SHOWN"
    endpoint="$("${KC[@]}" config view --minify -o jsonpath='{.clusters[0].cluster.server}' 2>/dev/null)"
    # Only display an endpoint without user info or query parameters.
    endpoint="${endpoint%%\?*}"; case "$endpoint" in *@*) endpoint='(endpoint contains user information; hidden)' ;; esac
    printf 'Endpoint: %s\n' "${endpoint:-not configured}" | toolkit_clean
    if "${KC[@]}" get pods "${SCOPE[@]}" -o name > "$probe" 2> "$err"; then
        printf 'PASS pods: readable (an empty namespace is valid)\n'
    else
        printf 'FAIL pods: %s\n' "$(doctor_classify "$err")"; code=1
        printf 'Next: kubectl --context %q -n %q get pods --request-timeout=%ss\n' "$CTX_NAME" "${NS/\(all namespaces\)/default}" "$REQUEST_TIMEOUT"
        printf 'For a local vcluster, check its existing runtime and connection; keep recovery kubeconfigs separate.\n'
    fi
    local resource
    for resource in nodes services endpointslices.discovery.k8s.io persistentvolumeclaims events; do
        if [ "$resource" = nodes ]; then
            "${KC[@]}" get "$resource" -o name > "$probe" 2> "$err"
        else
            "${KC[@]}" get "$resource" "${SCOPE[@]}" -o name > "$probe" 2> "$err"
        fi
        if [ $? = 0 ]; then printf 'PASS %s: readable\n' "$resource"
        else printf 'INFO %s: %s (capability unavailable)\n' "$resource" "$(doctor_classify "$err")"; fi
    done
    if "${KC[@]}" top pod "${SCOPE[@]}" --no-headers > "$probe" 2> "$err"; then
        printf 'PASS metrics: pod CPU/memory readable\n'
    else
        printf 'INFO metrics: %s; requests/limits and object health remain available\n' "$(doctor_classify "$err")"
        printf 'Next: inspect the existing Metrics API/metrics-server and your metrics permissions.\n'
    fi
    if [ -d "$REPORT_DIR" ] && [ -w "$REPORT_DIR" ] || { mkdir -p "$REPORT_DIR" 2>/dev/null && [ -w "$REPORT_DIR" ]; }; then
        printf 'PASS local reports: writable\n'
    else printf 'FAIL local reports: directory is not writable\n'; code=1; fi
    printf 'Audit: %s\nRead-only checks complete; no cluster changes made.\n' "${AUDIT_FILE:-$AUDIT_DIR}"
    audit DOCTOR "result=$code context=$CTX_NAME namespace=$NS"
    return "$code"
}

toolkit_init() {
    TOOLKIT_DIR="$TMPD/toolkit"; mkdir -p "$TOOLKIT_DIR"
    FETCH_PID=""; FETCH_NEXT=0; FETCH_FAILURES=0; FETCH_SUCCESS=0
    TOOLKIT_PID=""; TOOLKIT_NEXT=0
    TOOLKIT_REQUESTED=0
}

filter_spec() {
    awk -F'|' -v sf="${KDASH_STATUS_FILTER:-}" -v nf="${KDASH_NODE_FILTER:-}" \
        -v wf="${KDASH_WORKLOAD_FILTER:-}" -v uh="${KDASH_UNHEALTHY:-0}" '
    function flush(  a,st,w,ok,i) {
        if (!n) return
        split(row[1],a,"|"); st=a[3]; if (waiting!="") st=waiting
        if (st=="Running" && !ready) st="NotReady"
        w=a[10]; sub(/-[a-z0-9]+$/, "", w)
        ok=(sf=="" || st~sf) && (nf=="" || a[4]==nf) && (wf=="" || w~wf)
        if (uh==1 && (st=="Succeeded" || st=="Completed" || (st=="Running" && ready))) ok=0
        if(ok) for(i=1;i<=n;i++) print row[i]
    }
    $1=="P" {flush(); n=0; waiting=""; ready=1}
    {row[++n]=$0; if($1=="S") {if($3!="true")ready=0; if($6!="")waiting=$6}}
    END {flush()}' "$1"
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
        doctor_run > "$TOOLKIT_DIR/doctor.txt"
    ) & TOOLKIT_PID=$!
}

toolkit_cancel() {
    local pid
    for pid in "${FETCH_PID:-}" "${TOOLKIT_PID:-}"; do
        [ -z "$pid" ] || { kill "$pid" 2>/dev/null || true; wait "$pid" 2>/dev/null || true; }
    done
    FETCH_PID=""; TOOLKIT_PID=""
    rm -rf "$TMPD/fetch-job" "$TMPD/toolkit-next"
}

toolkit_panel() {
    local view="$1"
    printf 'KDASH %s  %s\nContext %s | namespace %s\n' "$KDASH_VERSION" "$view" "$CTX_NAME" "$NS" > "$HDRF"
    case "$view" in
        services) health_render_services ;; storage) health_render_storage ;;
        events) events_render ;; explain) explain_render "${NS/\(all namespaces\)/}" "${EXPLAIN_POD:-}" ;;
        doctor) if [ -f "$TOOLKIT_DIR/doctor.txt" ]; then cat "$TOOLKIT_DIR/doctor.txt"; else printf 'Checking capabilities in background...\n'; fi ;;
    esac | toolkit_clean > "$BODYF"
    printf '8 services | 9 storage | E events | ! explain | i inspect | : commands | q quit\n' > "$FTRF"
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
    local now="${KDASH_LABEL_SELECTOR:-}|${KDASH_STATUS_FILTER:-}|${KDASH_NODE_FILTER:-}|${KDASH_WORKLOAD_FILTER:-}|${KDASH_UNHEALTHY:-0}"
    if [ "$now" != "${TOOLKIT_FILTER_STATE:-}" ]; then
        toolkit_cancel; SPEC_AT=0; FETCH_NEXT=0; LAST=0
        TOOLKIT_FILTER_STATE="$now"; build_model
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
