# Kubernetes API Events and deterministic incident evidence. This source module
# is embedded into the deployable Bash CLI; it adds no runtime dependencies.
# events.tsv: NS KIND NAME UID TYPE REASON COUNT FIRST LAST MESSAGE (TSV).
# UID is the involved resource UID, not the Event UID. API Event UIDs are used
# internally to discard duplicate records, never to merge distinct Events.

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

events_header() {    # filtered namespace (empty = all), optional pod
    local namespace="${1:-}" pod="${2:-}" status=unknown updated="" now age
    printf 'Context: %s | Scope: %s' "$(events_context | events_text)" "$(printf '%s' "${namespace:-all namespaces}" | events_text)"
    [ -z "$pod" ] || printf ' | Pod: %s' "$(printf '%s' "$pod" | events_text)"
    printf '\n'
    if ! events_cache_valid; then
        printf 'Coverage: unknown (no Events collected for this context and scope).\n'
        return 0
    fi
    [ ! -f "$TOOLKIT_DIR/events.status" ] || IFS= read -r status < "$TOOLKIT_DIR/events.status" || true
    [ ! -f "$TOOLKIT_DIR/events.updated" ] || IFS= read -r updated < "$TOOLKIT_DIR/events.updated" || true
    printf 'Coverage: %s' "$(printf '%s' "$status" | events_text)"
    case "$updated" in
        ''|*[!0-9]*) printf ' | No successful Events observation.\n' ;;
        *) now=$(date +%s); age=$((now - updated)); [ "$age" -ge 0 ] || age=0
            printf ' | Last successful read: %s (%ss ago)%s\n' \
                "$(date -d "@$updated" '+%Y-%m-%d %H:%M:%S %z' 2>/dev/null || printf '%s' "$updated")" "$age" \
                "$([ "$status" = ok ] || printf ' | STALE retained evidence')" ;;
    esac
    if [ "$status" != ok ] && [ -s "$TOOLKIT_DIR/events.error" ]; then
        printf '  %s\n' "$(events_text < "$TOOLKIT_DIR/events.error")"
    fi
    printf 'These are Kubernetes API Events; local session change records are separate.\n'
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
    printf 'KUBERNETES EVENTS\n'
    events_header "$namespace" "$pod"
    events_rows "$namespace" "$pod" | LC_ALL=C awk -F '\t' -v limit="$maximum" '
        {
            count++
            if (count > limit) next
            printf "\n%s/%s %s | %s | %s | count %s\n", $1, $2, $3, $5, $6, $7
            printf "  First: %s | Last: %s | Resource UID: %s\n  %s\n", $8, $9, $4, $10
        }
        END {
            if (!count) print "No matching retained Kubernetes Events; this does not establish application health."
            else if (count > limit) printf "\nShowing newest %d of %d matching events.\n", limit, count
        }
    '
}

explain_render() {    # optional namespace, pod; hypotheses never assert causation
    local namespace="${1:-}" pod="${2:-}" ens kind name uid type reason count first last message
    local shown=0 category key previous="|" object_kind
    if [ "$#" -eq 0 ] && [ "${ALL_NS:-0}" != 1 ]; then namespace="${NS:-}"; fi
    printf 'INCIDENT EVIDENCE AND POSSIBLE EXPLANATIONS\n'
    events_header "$namespace" "$pod"
    printf 'Events describe observations, including historical failures. Timing alone does not establish a cause.\n'
    if [ -n "${MODEL:-}" ] && [ -f "$MODEL/pods.tsv" ]; then
        LC_ALL=C awk -F '\t' -v ns="$namespace" -v pod="$pod" '
            NR > 1 && (ns == "" || $2 == ns) && (pod == "" || $3 == pod) {
                line = "Cached pod fact: " $2 "/" $3 " status=" $4 " ready=" $5 " cumulative restarts=" $6 " node=" $7
                gsub(/[[:cntrl:]]/, " ", line); print line
            }
        ' "$MODEL/pods.tsv"
        printf 'Pod facts use the dashboard model; their collection time can differ from Events.\n'
    fi
    while IFS=$'\t' read -r ens kind name uid type reason count first last message; do
        [ -n "$ens" ] || continue
        category=other
        case "$reason" in
            FailedScheduling|SchedulingGated) category=scheduling ;;
            FailedMount|FailedAttachVolume|FailedBinding|ProvisioningFailed|FailedMapVolume|FailedUnmapVolume|VolumeFailedMount) category=storage ;;
            Unhealthy|ProbeWarning) category=probe ;;
            ErrImagePull|ImagePullBackOff|InvalidImageName|InspectFailed|ErrImageNeverPull) category=image ;;
            BackOff) category=restart ;;
            OOMKilling|OOMKilled) category=memory ;;
        esac
        if printf '%s' "$message" | LC_ALL=C grep -qiE 'failed to pull|pull image|imagepull|manifest unknown|back-off pulling'; then category=image; fi
        key="$ens/$kind/$name/$uid/$category"
        case "$previous" in *"|$key|"*) continue ;; esac
        previous="$previous$key|"; shown=$((shown + 1))
        printf '\nObserved: %s/%s %s | %s | count %s | first %s | last %s | resource UID %s\n' "$ens" "$kind" "$name" "$reason" "$count" "$first" "$last" "$uid"
        printf '  Event fact: %s\n' "$message"
        case "$category" in
            scheduling) printf '  Possible explanation: scheduler constraints, capacity or an unbound claim may block placement. Read the scheduler message before deciding which applies.\n' ;;
            storage) printf '  Possible explanation: volume binding, provisioning, attachment or mounting may be blocking startup. This event does not establish volume fullness.\n' ;;
            probe) printf '  Possible explanation: a readiness, liveness or startup probe may be failing. Check its configuration and application evidence; one event does not establish an ongoing outage.\n' ;;
            image) printf '  Possible explanation: image reference, registry access or pull credentials may prevent container startup. Do not expose credentials when collecting evidence.\n' ;;
            restart) printf '  Possible explanation: a container may be repeatedly exiting. The event alone does not identify why it exited.\n' ;;
            memory) printf '  Possible explanation: the event reports memory pressure or a kill at its timestamp; it is not a current memory measurement.\n' ;;
            *) printf '  Possible explanation: this warning needs object-specific investigation; its presence alone does not establish the underlying cause.\n' ;;
        esac
        object_kind="$(printf '%s' "$kind" | LC_ALL=C tr '[:upper:]' '[:lower:]')"
        printf '  Next read-only check: '
        events_command "$ens" describe "$object_kind" "$name"
        if [ "$category" = storage ]; then
            printf '  Next read-only check: '; events_command "$ens" get pvc
        elif [ "$kind" = Pod ]; then
            case "$category" in
                restart|memory) printf '  Next read-only check: '; events_command "$ens" logs "$name" --all-containers --previous --tail=100 ;;
                probe) printf '  Next read-only check: '; events_command "$ens" logs "$name" --all-containers --tail=100 --since=5m ;;
            esac
        fi
        [ "$shown" -lt 20 ] || break
    done < <(events_rows "$namespace" "$pod" 1)
    if [ "$shown" = 0 ]; then
        printf '\nNo matching retained warning event evidence. Coverage gaps, event expiry and failures without Events remain possible.\n'
        if [ -n "$pod" ]; then
            printf 'Next read-only check: '; events_command "$namespace" describe pod "$pod"
        fi
    fi
    printf '\nCompare current readiness, resource identities, logs and workload conditions before deciding on a change.\n'
}
