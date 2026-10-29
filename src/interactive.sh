# Interactive attachments: open a shell in a container, and copy files in or out
# of one. These are the only kdash actions that can change something outside the
# display, so:
#   * they are OFF unless KDASH_ALLOW_INTERACTIVE=1 (--allow-interactive), and the
#     kubectl guard refuses exec/cp with exit 126 while they are off;
#   * every use is audited as a write event (EXEC, CP_UP, CP_DOWN) with the pod,
#     container, direction and paths - credential-looking paths are masked;
#   * nothing they produce enters the model, a report, a session or an export.
# The command is built from the audited KC argv array on the host side: the
# dashboard never evaluates shell text.
interactive_enabled() { [ "${KDASH_ALLOW_INTERACTIVE:-0}" = 1 ]; }

interactive_hint() {
    printf 'interactive actions are off: kdash is read-only by default. Restart with --allow-interactive (or KDASH_ALLOW_INTERACTIVE=1) to open a shell or copy files.'
}

interactive_require() { # action
    interactive_enabled && return 0
    declare -F audit >/dev/null && audit INTERACTIVE_BLOCKED "action=${1:-unknown} reason=not-enabled"
    return 1
}

# A path is recorded as a path, not as a secret: anything that looks like a key,
# a token or a password store is replaced by a placeholder.
interactive_audit_path() {
    case "${1:-}" in
        *[Ss]ecret*|*[Pp]assword*|*token*|*[Cc]redential*|*.pem|*.key|*.p12|*.pfx|*.kdbx|id_rsa*|id_ed25519*|.netrc|.pgpass) printf '<redacted path>' ;;
        *) printf '%s' "${1:0:200}" ;;
    esac
}

interactive_ask() { # prompt [default] -> INTERACTIVE_ANSWER
    local ans=""
    printf '%s' "$1"
    IFS= read -r ans </dev/tty || return 1
    INTERACTIVE_ANSWER="${ans:-${2:-}}"
    return 0
}

interactive_valid_path() { # value
    [ -n "${1:-}" ] || return 1
    [ "${#1}" -le 1024 ] || return 1
    case "$1" in *[$'\001'-$'\037'$'\177']*) return 1 ;; esac
    return 0
}

# Hand the terminal to a command and take it back: the dashboard leaves the
# alternate screen, the child gets the real tty (so kubectl -it works), and the
# dashboard repaints on the next loop iteration.
interactive_run() { # cmd...
    local rc=0
    printf '\033[2J\033[H\033[?25h'
    [ "${ALTSCR:-1}" = 1 ] && printf '\033[?1049l'
    while IFS= read -rsn1 -t 0.01 _flush </dev/tty; do :; done   # drop buffered keys
    stty sane </dev/tty 2>/dev/null || true
    "$@" </dev/tty >/dev/tty 2>&1; rc=$?
    printf '\033[?25l'
    [ "${ALTSCR:-1}" = 1 ] && printf '\033[?1049h'
    return "$rc"
}

interactive_pause() { sleep "${1:-2}" 2>/dev/null || true; }

interactive_shell() { # ns pod [container]
    local ns="$1" pod="$2" c="${3:-${KDASH_INSPECT_CONTAINER:-}}" rc=0
    local args=()
    interactive_require shell || return 1
    audit EXEC "pod=$ns/$pod container=${c:--} mode=shell shell=bash-or-sh"
    printf '\033[H\033[2J Shell in %s/%s%s | Context: %s\n\n This runs in your name with your RBAC, it is not read-only, and it\n ends when you type exit (Ctrl-D). Logged as EXEC.\n\n Opening...\n' \
        "$ns" "$pod" "${c:+ (container $c)}" "${CTX_NAME:-current}"
    args=(exec -it "$pod")
    [ -z "$c" ] || args+=(-c "$c")
    args+=(-- sh -c 'if command -v bash >/dev/null 2>&1; then exec bash; else exec sh; fi')
    interactive_run "${KC[@]}" -n "$ns" "${args[@]}"; rc=$?
    audit EXEC_END "pod=$ns/$pod container=${c:--} rc=$rc"
    return "$rc"
}

interactive_copy() { # up|down ns pod [container]
    local dir="$1" ns="$2" pod="$3" c="${4:-${KDASH_INSPECT_CONTAINER:-}}"
    local remote="" local_path="" rc=0 bytes=0 size=0
    local args=()
    case "$dir" in up|down) ;; *) return 2 ;; esac
    interactive_require "copy-$dir" || return 1

    printf '\033[H\033[2J %s %s/%s%s | Context: %s\n\n kubectl cp runs in your name; it needs a copy helper (tar) inside the\n container, which distroless and scratch images do not have.\n\n' \
        "$([ "$dir" = up ] && printf 'Upload into' || printf 'Download from')" \
        "$ns" "$pod" "${c:+ (container $c)}" "${CTX_NAME:-current}"

    if [ "$dir" = up ]; then
        interactive_ask ' local file or directory to send: ' || { printf '\033[?25l\n cancelled\n'; interactive_pause; return 1; }
        local_path="$INTERACTIVE_ANSWER"
        if [ ! -e "$local_path" ]; then
            printf '\n %s does not exist on this host.\n' "${local_path:0:200}"; interactive_pause 3; return 1
        fi
        interactive_ask " remote path inside the container (Enter for /tmp/$(basename "$local_path")): " "/tmp/$(basename "$local_path")" \
            || { printf '\033[?25l\n cancelled\n'; interactive_pause; return 1; }
        remote="$INTERACTIVE_ANSWER"
    else
        interactive_ask ' remote path inside the container (e.g. /var/log/app/app.log): ' \
            || { printf '\033[?25l\n cancelled\n'; interactive_pause; return 1; }
        remote="$INTERACTIVE_ANSWER"
        interactive_ask " local destination (Enter for ./$(basename "$remote")): " "./$(basename "$remote")" \
            || { printf '\033[?25l\n cancelled\n'; interactive_pause; return 1; }
        local_path="$INTERACTIVE_ANSWER"
    fi
    printf '\033[?25l'
    case "$remote" in
        /*) ;;
        *) printf '\n the remote path must be absolute: it starts with / (got %s)\n' "${remote:0:80}"; interactive_pause 3; return 2 ;;
    esac
    if ! interactive_valid_path "$remote" || ! interactive_valid_path "$local_path"; then
        printf '\n paths must be 1..1024 characters with no control bytes.\n'; interactive_pause 3; return 2
    fi
    if [ "$dir" = down ] && [ -e "$local_path" ]; then
        interactive_ask " local path $local_path exists - overwrite? [y/N] "
        case "$INTERACTIVE_ANSWER" in [yY]*) ;; *) printf '\n cancelled\n'; interactive_pause; return 1 ;; esac
    fi

    args=(cp)
    [ -z "$c" ] || args+=(-c "$c")
    if [ "$dir" = up ]; then args+=("$local_path" "$ns/$pod:$remote"); else args+=("$ns/$pod:$remote" "$local_path"); fi
    if [ "$dir" = up ]; then
        audit CP_UP "pod=$ns/$pod container=${c:--} remote=$(interactive_audit_path "$remote") local=$(interactive_audit_path "$local_path")"
    else
        audit CP_DOWN "pod=$ns/$pod container=${c:--} remote=$(interactive_audit_path "$remote") local=$(interactive_audit_path "$local_path")"
    fi
    printf '\n %s %s/%s:%s -> %s\n\n' "$([ "$dir" = up ] && printf 'uploading' || printf 'downloading')" \
        "$ns" "$pod" "${remote:0:120}" "${local_path:0:120}"
    interactive_run "${KC[@]}" -n "$ns" "${args[@]}"; rc=$?
    if [ -f "$local_path" ]; then
        size="$(wc -c < "$local_path" 2>/dev/null)"; case "$size" in ''|*[!0-9]*) size=0 ;; esac; bytes="$size"
    fi
    if [ "$rc" = 0 ]; then
        audit CP_END "pod=$ns/$pod dir=$dir rc=0 bytes=$bytes local=$(interactive_audit_path "$local_path")"
        printf ' copy finished (%s bytes) - audit event: %s\n' "$bytes" "$([ "$dir" = up ] && printf CP_UP || printf CP_DOWN)"
    else
        audit CP_END "pod=$ns/$pod dir=$dir rc=$rc bytes=$bytes"
        printf ' copy failed (rc=%s).\n If the image has no tar (distroless/scratch), cp cannot work: open a shell (S),\n use kubectl debug --copy-to, or kubectl exec ... -- cat > file.\n' "$rc"
    fi
    interactive_pause 4
    return "$rc"
}

# One entry point for the dashboard and the inspector: S shell, U upload, D download.
interactive_attach() { # shell|up|down ns pod dir
    local action="$1" ns="$2" pod="$3" d="$4" rc=0
    case "$action" in
        S|s|shell) action=shell ;; U|u|up) action=up ;; D|d|down) action=down ;;
    esac
    if ! interactive_require "$action"; then
        declare -F flash >/dev/null && flash "$(interactive_hint)" 10
        return 1
    fi
    if ! interactive_container "$ns" "$pod" "$d"; then
        declare -F flash >/dev/null && flash "no container reported for $ns/$pod" 6
        return 1
    fi
    case "$action" in
        shell) interactive_shell "$ns" "$pod" "$INTERACTIVE_CONTAINER"; rc=$? ;;
        up)    interactive_copy up "$ns" "$pod" "$INTERACTIVE_CONTAINER"; rc=$? ;;
        down)  interactive_copy down "$ns" "$pod" "$INTERACTIVE_CONTAINER"; rc=$? ;;
    esac
    declare -F flash >/dev/null && flash "attach $action $ns/$pod exited rc=$rc" 6
    return "$rc"
}


# Which container the action applies to: the selected one, the only one, or the
# picker. Sets INTERACTIVE_CONTAINER.
interactive_container() { # ns pod dir
    local ns="$1" pod="$2" d="$3" n=""
    INTERACTIVE_CONTAINER="${KDASH_INSPECT_CONTAINER:-}"
    [ -z "$INTERACTIVE_CONTAINER" ] || return 0
    if [ ! -s "$d/rows" ] && declare -F inspector_container_rows >/dev/null; then
        inspector_container_rows "$ns" "$pod" "$d/rows.spec" "$d/rows.status" > "$d/rows" 2> "$d/rows.err" || true
    fi
    n="$(awk -F'\t' 'NF >= 2 {c++} END {print c+0}' "$d/rows" 2>/dev/null)"
    case "$n" in
        0) return 1 ;;
        1) INTERACTIVE_CONTAINER="$(awk -F'\t' 'NF >= 2 {print $2; exit}' "$d/rows")" ;;
        *) declare -F inspector_container_picker >/dev/null || return 1
           inspector_container_picker "$ns" "$pod" "$d" || return 1
           INTERACTIVE_CONTAINER="$INSPECTOR_CONTAINER" ;;
    esac
    return 0
}
