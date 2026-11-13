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
# Q, anywhere: leave kdash at once. The EXIT trap (cleanup) restores the screen,
# writes the audit END record and removes temporary files.
kdash_quit() { # where
  declare -F audit >/dev/null && audit QUIT "key Q (${1:-?})"
  printf '\033[r\033[9999;1H\033[?25h'
  exit 0
}

interactive_enabled() { [ "${KDASH_ALLOW_INTERACTIVE:-0}" = 1 ]; }

interactive_hint() {
    printf 'interactive actions are off (read-only). Press X to turn them on, or start kdash with kdx / kdash -X.'
}

# X key: switch interactive mode on (with a y/N confirmation) or off without restarting.
# The kubectl guard reads the exported KDASH_ALLOW_INTERACTIVE on every call, so the
# change applies at once. Both directions are audited.
interactive_toggle() {
    local ans="" rows
    if interactive_enabled; then
        KDASH_ALLOW_INTERACTIVE=0; export KDASH_ALLOW_INTERACTIVE
        declare -F audit >/dev/null && audit INTERACTIVE_OFF "by key X"
        INTERACTIVE_MSG="interactive mode OFF - kdash is read-only again"
        return 0
    fi
    rows="${KDASH_LINES:-$(tput lines 2>/dev/null || echo 24)}"
    printf '\033[%s;1H\033[K\033[?25h\033[1;97;41m Turn on interactive mode? S shell / U upload / D download run in YOUR name and are audited writes. [y/N] \033[0m ' "$rows"
    IFS= read -rsn1 ans </dev/tty || ans=""
    printf '\033[?25l'
    case "$ans" in
        y|Y) KDASH_ALLOW_INTERACTIVE=1; export KDASH_ALLOW_INTERACTIVE
             declare -F audit >/dev/null && audit INTERACTIVE_ON "by key X"
             INTERACTIVE_MSG="interactive mode ON - S shell, U upload, D download (X turns it off)" ;;
        *)   INTERACTIVE_MSG="interactive mode stays off" ;;
    esac
    return 0
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
interactive_run() { # cmd...   (INTERACTIVE_BANNER is printed once the real screen is up)
    local rc=0 t0=$SECONDS keep="${INTERACTIVE_KEEP:-1}"
    printf '\033[2J\033[H\033[?25h'
    [ "${ALTSCR:-1}" = 1 ] && printf '\033[?1049l'
    while IFS= read -rsn1 -t 0.01 _flush </dev/tty; do :; done   # drop buffered keys
    stty sane </dev/tty 2>/dev/null || true
    # the banner goes to the normal screen, so it stays in the scrollback with the session
    [ -z "${INTERACTIVE_BANNER:-}" ] || printf '%s' "$INTERACTIVE_BANNER" >/dev/tty
    # Ctrl-C must stop kubectl, not quit kdash: a no-op handler (not "ignore", which
    # the child would inherit) keeps the dashboard alive while kubectl gets SIGINT.
    trap ':' INT
    "$@" </dev/tty >/dev/tty 2>&1; rc=$?
    trap 'AUDIT_SIG=INT; cleanup; exit 0' INT
    # a pinned header inside may have left a scroll region; resetting it homes the cursor,
    # so put the cursor back on the last line before printing anything
    printf '\033[r\033[9999;1H\r\033[K' >/dev/tty
    [ -z "${INTERACTIVE_FOOTER:-}" ] || printf "$INTERACTIVE_FOOTER" "$rc" "$((SECONDS - t0))" >/dev/tty
    # "auto": a shell returns its last command's status, so only a quick failure
    # (kubectl could not attach) is worth stopping for
    [ "$keep" != auto ] || { [ "$rc" != 0 ] && [ "$rc" != 197 ] && [ "$rc" != 198 ] && [ $((SECONDS - t0)) -lt 5 ] && keep=1 || keep=0; }
    if [ "$rc" != 0 ] && [ "$keep" = 1 ]; then
        # Keep kubectl's error on screen: the dashboard used to repaint over it at once.
        printf '\n\033[1m kubectl exited with rc=%s - read the message above.\033[0m  Press any key to return to kdash. ' "$rc" >/dev/tty
        IFS= read -rsn1 _k </dev/tty || true
    fi
    printf '\033[?25l'
    [ "${ALTSCR:-1}" = 1 ] && printf '\033[?1049h'
    return "$rc"
}

# Runs inside the container (sh -c: bash, ash or dash). Exports what the operator is
# attached to and starts the shell. With bash, a 5-row header panel is pinned to the top of
# the screen (a terminal scroll region, redrawn before every prompt by PROMPT_COMMAND,
# so it survives clear, Ctrl-L, full-screen tools and window resizes) and the prompt is
# a plain "user@container:dir$". Without bash the same header is printed once.
# Colours read on white and black backgrounds: bold, reverse video, green / red only.
# Arguments come in as positional parameters - nothing is spliced into the script.
INTERACTIVE_SHELL_SCRIPT='
export KDASH_CONTEXT="$1" KDASH_NAMESPACE="$2" KDASH_POD="$3" KDASH_CONTAINER="$4"
export KDASH_H_COLOR="$5" KDASH_H_GLYPH="$6" KDASH_H_STATUS="$7" KDASH_H_READY="$8" KDASH_H_RESTARTS="$9"
shift 9
export KDASH_H_NODE="$1" KDASH_H_IP="$2" KDASH_H_MEM="$3" KDASH_H_IMAGE="$4" KDASH_H_CPU="$5" KDASH_H_QOS="$6" KDASH_H_CSTATE="$7" KDASH_HDR="$8"
if command -v bash >/dev/null 2>&1; then
  if [ "$KDASH_H_COLOR" = 1 ]; then
    KDASH_PS1="\[\033[1m\]\u\[\033[0m\]@\[\033[32m\]$KDASH_CONTAINER\[\033[0m\]:\[\033[1m\]\w\[\033[0m\]\\$ "
  else
    KDASH_PS1="\u@$KDASH_CONTAINER:\w\\$ "
  fi
  # image rc files (/etc/bash.bashrc, /etc/bashrc, ~/.bashrc) may set their own PS1 or
  # PROMPT_COMMAND; this runs after them, before every prompt
  PS1=$KDASH_PS1; PROMPT_COMMAND="eval \"\$KDASH_HDR\""; export KDASH_PS1 PS1 PROMPT_COMMAND
  exec bash -i
fi
u=$(id -un 2>/dev/null || id -u 2>/dev/null || echo "?")
if [ "$KDASH_H_COLOR" = 1 ]; then B=$(printf "\033[1m"); V=$(printf "\033[7m"); X=$(printf "\033[0m"); else B=; V=; X=; fi
printf "%s KDASH | SHELL | context %s | namespace %s | audited    exit: back   exit 198: related pods   exit 197: leave kdash %s\n" "$V$B" "$KDASH_CONTEXT" "$KDASH_NAMESPACE" "$X"
printf " POD        %s%s%s | %s   ready %s   restarts %s   QoS %s\n" "$B" "$KDASH_POD" "$X" "$KDASH_H_STATUS" "$KDASH_H_READY" "$KDASH_H_RESTARTS" "$KDASH_H_QOS"
printf " CONTAINER  %s%s%s  %s | state %s\n" "$B" "$KDASH_CONTAINER" "$X" "$KDASH_H_IMAGE" "$KDASH_H_CSTATE"
printf " NODE       %s%s   %s%s | cpu %s   mem %s   user %s\n\n" "$B" "$KDASH_H_NODE" "$KDASH_H_IP" "$X" "$KDASH_H_CPU" "$KDASH_H_MEM" "$u"
PS1="$u@$KDASH_CONTAINER\$ "; export PS1
exec sh -i
'

# bash code run by PROMPT_COMMAND inside the container (passed as an argument, never
# written to a file). The first run defines the drawing functions, kdquit / kdswitch,
# a clear() and Ctrl-L that keep the header, then clears the screen. The header is a
# 6-row panel: a title bar (reverse video) and a frame of up to three cards - POD
# (pod, container, node), STATE and RESOURCES - whose bottom border carries the OS and
# shell. A narrow window drops RESOURCES, then STATE; values are cut with ~, never wrapped. Glyph widths are measured with __kd_vlen, so alignment
# holds in UTF-8 and in POSIX-locale containers (where bash counts bytes).
INTERACTIVE_HDR_CODE='
if ! declare -F __kd_hdr >/dev/null 2>&1; then
  shopt -s checkwinsize 2>/dev/null
  if [ "$KDASH_H_COLOR" = 1 ]; then KD_B=$(printf "\e[1m"); KD_G=$(printf "\e[32m"); KD_E=$(printf "\e[31m"); KD_V=$(printf "\e[7m"); KD_X=$(printf "\e[0m")
  else KD_B=; KD_G=; KD_E=; KD_V=; KD_X=; fi
  if [ "$KDASH_H_GLYPH" = ascii ]; then KD_RULE="-"; KD_SEP="|"; KD_DOT="*"; KD_MID="-"
  else KD_RULE="─"; KD_SEP="│"; KD_DOT="●"; KD_MID="·"; fi
  if [ "$KDASH_H_GLYPH" = ascii ]; then KD_TL="+"; KD_TR="+"; KD_BL="+"; KD_BR="+"; KD_TJ="+"; KD_BJ="+"
  else KD_TL="┌"; KD_TR="┐"; KD_BL="└"; KD_BR="┘"; KD_TJ="┬"; KD_BJ="┴"; fi
  KD_USER=$(id -un 2>/dev/null || id -u 2>/dev/null); KD_UID=$(id -u 2>/dev/null)
  KD_OS=$( (. /etc/os-release 2>/dev/null && printf "%s" "${PRETTY_NAME:-$NAME}") )
  case "$KDASH_H_STATUS" in Running) KD_S=$KD_G ;; ""|-) KD_S= ;; *) KD_S=$KD_E ;; esac
  __kd_size() {
    local s; s=$(stty size 2>/dev/null); KD_R=${s% *}; KD_C=${s#* }
    case "$KD_R$KD_C" in ""|*[!0-9]*) KD_R=${LINES:-24}; KD_C=${COLUMNS:-80} ;; esac
    [ "$KD_C" -gt 20 ] || KD_C=80; [ "$KD_R" -gt 10 ] || KD_R=24
  }
  # visible width: each glyph counts 1 whatever the locale
  __kd_vlen() { local t=$1; t=${t//$KD_SEP/x}; t=${t//$KD_DOT/x}; t=${t//$KD_RULE/x}; t=${t//$KD_MID/x}; KD_VL=${#t}; }
  # plain text padded / cut to a width
  __kd_pad() {
    local s=$1 w=$2
    [ "$w" -gt 0 ] || { KD_P=""; return; }
    [ "${#s}" -le "$w" ] || s="${s:0:$(( w > 1 ? w - 1 : 1 ))}~"
    printf -v KD_P "%-*s" "$w" "$s"
  }
  # one row from "colour" "text" pairs; whole fields only: a label (no colour) is
  # shown only together with the value after it, and the row stops at the first
  # field that does not fit, so it never wraps and never shows a cut-off word
  __kd_line() {
    local row=$1 used=0 cl="" col txt need; shift
    while [ $# -ge 2 ]; do
      col=$1; txt=$2; shift 2
      __kd_vlen "$txt"; need=$KD_VL
      if [ -z "$col" ] && [ $# -ge 2 ] && [ -n "$1" ]; then __kd_vlen "$2"; need=$(( need + KD_VL )); __kd_vlen "$txt"; fi
      [ $(( used + need )) -le "$KD_C" ] || break
      [ -n "$txt" ] || break
      used=$(( used + KD_VL )); cl+="$col$txt$KD_X"
    done
    __kd_put "$row" "$cl"
  }
  __kd_rep() { local r n=$1; [ "$n" -gt 0 ] || n=0; printf -v r "%*s" "$n" ""; KD_REP=${r// /$KD_RULE}; }
  # one framed row: per card its width, the plain text (measured) and the coloured text (shown)
  __kd_cells() {
    local row=$1 out="$KD_SEP" w pad; shift
    while [ $# -ge 3 ]; do
      w=$1; __kd_vlen "$2"; pad=$(( w - KD_VL )); [ "$pad" -ge 0 ] || pad=0
      printf -v pad "%*s" "$pad" ""; out+=" $3$KD_X$pad $KD_SEP"; shift 3
    done
    __kd_put "$row" "$out"
  }
  KD_PIN=${KD_PIN0:-0}
  __kd_put() { if [ "$KD_PIN" = 1 ]; then printf "\e[%d;1H%s\e[K" "$1" "$2"; else printf "%s\n" "$2"; fi; }
  __kd_hdr() {
    local L R gap lw cw t lim pod_ ctr_ img_ node_ tail n rule
    __kd_size
    [ "$KD_PIN" != 1 ] || printf "\e7\e[7;%dr" "$KD_R"
    # title bar: identity on the left, the three exits on the right (shortened or
    # dropped when the window is narrow)
    L=" KDASH $KD_SEP SHELL $KD_SEP context $KDASH_CONTEXT $KD_SEP namespace $KDASH_NAMESPACE $KD_SEP audited "
    if [ "$KD_PIN" = 1 ]; then t="kdpin release header"; else t="kdpin pin header"; fi
    for R in " exit back to kdash  $KD_MID  kdswitch related pods  $KD_MID  kdquit leave kdash  $KD_MID  $t " " exit $KD_MID kdswitch $KD_MID kdquit $KD_MID kdpin " " exit $KD_MID kdswitch $KD_MID kdquit " ""; do
      __kd_vlen "$L$R"; [ "$KD_VL" -gt "$KD_C" ] || break
    done
    __kd_vlen "$L"
    if [ "$KD_VL" -gt "$KD_C" ]; then L=" KDASH $KD_SEP SHELL $KD_SEP $KDASH_NAMESPACE "; L=${L:0:$KD_C}; KD_VL=${#L}; R=""; fi
    gap=$(( KD_C - KD_VL )); __kd_vlen "$R"; gap=$(( gap - KD_VL )); [ "$gap" -ge 0 ] || gap=0
    printf -v t "%*s" "$gap" ""
    __kd_put 1 "$KD_V$KD_B$L$KD_X$KD_V$t$R$KD_X"
    # the cards: natural widths first, then what the window allows
    local nc=3 W1 W2=7 W3=11 a x s1 s2 s3 r1 r2 r3 top bot wl
    s1="status  $KD_DOT ${KDASH_H_STATUS:--}   ready ${KDASH_H_READY:--}"
    s2="state   ${KDASH_H_CSTATE:--}"
    s3="restarts ${KDASH_H_RESTARTS:--}   QoS ${KDASH_H_QOS:--}"
    r1="cpu   ${KDASH_H_CPU:--}"; r2="mem   ${KDASH_H_MEM:--}"; r3="user  $KD_USER${KD_UID:+ (uid $KD_UID)}"
    for x in "$s1" "$s2" "$s3"; do __kd_vlen "$x"; [ "$KD_VL" -le "$W2" ] || W2=$KD_VL; done
    for x in "$r1" "$r2" "$r3"; do __kd_vlen "$x"; [ "$KD_VL" -le "$W3" ] || W3=$KD_VL; done
    lw=${#KDASH_POD}
    t="$KDASH_CONTAINER  $KDASH_H_IMAGE"; [ "${#t}" -le "$lw" ] || lw=${#t}
    t="$KDASH_H_NODE   $KDASH_H_IP"; [ "${#t}" -le "$lw" ] || lw=${#t}
    a=$(( KD_C - 10 - W2 - W3 ))
    if [ "$a" -lt 31 ]; then nc=2; a=$(( KD_C - 7 - W2 )); fi
    if [ "$a" -lt 31 ]; then nc=1; a=$(( KD_C - 4 )); fi
    [ "$a" -ge 14 ] || a=14
    W1=$(( 11 + lw )); [ "$W1" -le "$a" ] || W1=$a; lw=$(( W1 - 11 ))
    x=$(( a - W1 )); case $nc in 3) W3=$(( W3 + x )) ;; 2) W2=$(( W2 + x )) ;; *) W1=$(( W1 + x )) ;; esac
    __kd_pad "$KDASH_POD" "$lw"; pod_=$KD_P
    cw=${#KDASH_CONTAINER}; [ "$cw" -le "$lw" ] || cw=$lw
    __kd_pad "$KDASH_CONTAINER" "$cw"; ctr_=$KD_P
    if [ $(( lw - cw )) -ge 6 ]; then __kd_pad "  $KDASH_H_IMAGE" $(( lw - cw )); img_=$KD_P; else printf -v img_ "%*s" $(( lw - cw )) ""; fi
    __kd_pad "$KDASH_H_NODE   $KDASH_H_IP" "$lw"; node_=$KD_P
    # top border with the card titles
    __kd_rep $(( W1 - 4 )); top="$KD_TL$KD_RULE ${KD_B}POD$KD_X $KD_REP"; wl=$W1
    [ "$nc" -lt 2 ] || { __kd_rep $(( W2 - 6 )); top+="$KD_TJ$KD_RULE ${KD_B}STATE$KD_X $KD_REP"; wl=$W2; }
    [ "$nc" -lt 3 ] || { __kd_rep $(( W3 - 10 )); top+="$KD_TJ$KD_RULE ${KD_B}RESOURCES$KD_X $KD_REP"; wl=$W3; }
    __kd_put 2 "$top$KD_TR"
    # three rows
    local -a A2=() A3=() A4=()
    A2=("$W1" "pod        $pod_" "pod        $KD_B$pod_"); A3=("$W1" "container  $ctr_$img_" "container  $KD_B$KD_G$ctr_$KD_X$img_"); A4=("$W1" "node       $node_" "node       $KD_B$node_")
    if [ "$nc" -ge 2 ]; then
      A2+=("$W2" "$s1" "status  $KD_B$KD_S$KD_DOT ${KDASH_H_STATUS:--}$KD_X   ready $KD_B${KDASH_H_READY:--}")
      A3+=("$W2" "$s2" "state   $KD_B${KDASH_H_CSTATE:--}")
      A4+=("$W2" "$s3" "restarts $KD_B${KDASH_H_RESTARTS:--}$KD_X   QoS $KD_B${KDASH_H_QOS:--}")
    fi
    if [ "$nc" -ge 3 ]; then
      A2+=("$W3" "$r1" "cpu   $KD_B${KDASH_H_CPU:--}"); A3+=("$W3" "$r2" "mem   $KD_B${KDASH_H_MEM:--}"); A4+=("$W3" "$r3" "user  $KD_B$KD_USER$KD_X${KD_UID:+ (uid $KD_UID)}")
    fi
    __kd_cells 3 "${A2[@]}"; __kd_cells 4 "${A3[@]}"; __kd_cells 5 "${A4[@]}"
    # bottom border; the OS and shell are set into its right end when they fit
    tail=" ${KD_OS:+$KD_OS, }bash ${BASH_VERSION%%(*} "
    [ "${#tail}" -le "$wl" ] || tail=" bash ${BASH_VERSION%%(*} "
    [ "${#tail}" -le "$wl" ] || tail=""
    bot="$KD_BL"
    if [ "$nc" -ge 2 ]; then __kd_rep $(( W1 + 2 )); bot+="$KD_REP$KD_BJ"; fi
    if [ "$nc" -ge 3 ]; then __kd_rep $(( W2 + 2 )); bot+="$KD_REP$KD_BJ"; fi
    if [ -n "$tail" ]; then __kd_rep $(( wl - ${#tail} )); bot+="$KD_REP$tail$KD_RULE$KD_RULE"; else __kd_rep $(( wl + 2 )); bot+="$KD_REP"; fi
    __kd_put 6 "$bot$KD_BR"
    [ "$KD_PIN" = 1 ] || return 0
    if [ "${1:-}" = home ]; then printf "\e[7;1H"; else printf "\e8"; fi
  }
  # the header scrolls away like any output (default) or stays pinned at the top: kdpin
  # switches between the two, kdheader prints / repaints it
  clear() { if [ "$KD_PIN" = 1 ]; then printf "\e[r\e[H\e[2J"; __kd_hdr home; else printf "\e[H\e[2J"; fi; }
  kdheader() { __kd_hdr; }
  kdpin() {
    if [ "$KD_PIN" = 1 ]; then
      KD_PIN=0; printf "\e7\e[r\e8"; printf "kdash: header released - it scrolls away with the output (kdpin pins it again, kdheader prints it)\n"
    else
      KD_PIN=1; printf "\e[H\e[2J"; __kd_hdr home
    fi
  }
  kdquit() { exit 197; }      # kdash quits at once
  kdswitch() { exit 198; }    # kdash shows the pods of the same workload, in shell mode
  bind -x "\"\C-l\": clear" 2>/dev/null
  # resetting the scroll region homes the cursor (VT100): go back to the last line, or
  # whatever is printed next (kubectl, kdash, the host prompt) overwrites the session
  __kd_bye() { [ "$KD_PIN" != 1 ] || printf "\e[r\e[9999;1H\n"; }
  trap __kd_bye EXIT
  printf "\e[H\e[2J"; __kd_hdr home
else
  [ "$KD_PIN" != 1 ] || __kd_hdr
fi
PS1=$KDASH_PS1
'

interactive_shell() { # ns pod [container]
    local ns="$1" pod="$2" c="${3:-${KDASH_INSPECT_CONTAINER:-}}" rc=0 ctx b g r m mem
    local args=() row="" ctype="" cready="" crst="" cstate="" clast="" cimage="" pr=""
    local pstatus="" pready="" prst="" pnode="" pip="" pkind="" pwl="" pqos="" pmem="" pmlim="" pcpu="" pclim="" cpu img cst
    interactive_require shell || return 1
    # sanitize the context name: it ends up in the remote prompt
    ctx="$(printf '%s' "${CTX_NAME:-current}" | tr -c 'A-Za-z0-9._@:-' '_')"
    # what we know about the pod and the container, from this refresh
    [ ! -r "${MODEL:-}/pods.tsv" ] || pr="$(awk -F'\t' -v ns="$ns" -v p="$pod" '$2 == ns && $3 == p { print; exit }' "$MODEL/pods.tsv")"
    [ -z "$pr" ] || IFS=$'\t' read -r _ _ _ pstatus pready prst pnode _ pip _ pqos pkind pwl pcpu _ pclim pmem _ pmlim _ <<< "$pr"
    for row in "${TMPD:-/nonexistent}/inspector/live/attach.rows" "${TMPD:-/nonexistent}/inspector/live/rows"; do
        [ -r "$row" ] || continue
        row="$(awk -F'\t' -v k="$c" '$2 == k { print; exit }' "$row")"
        [ -n "$row" ] && { IFS=$'\t' read -r ctype _ cready crst cstate clast cimage <<< "$row"; break; }
    done
    if [ "${COLOR:-1}" = 1 ]; then b=$'\033[1m'; g=$'\033[32m'; r=$'\033[0m'; m=$'\033[7m'
    else b=""; g=""; r=""; m=""; fi
    [ "$clast" != - ] || clast=""
    [ "$cimage" != - ] || cimage=""
    # header values in readable units: "3.5Gi / 140.3Gi (2%)", "120m / 2c"
    IFS=$'\t' read -r cpu mem <<< "$(awk -v cu="${pcpu:--}" -v cl="${pclim:--}" -v mu="${pmem:--}" -v ml="${pmlim:--}" '
      function M(v) { return (v >= 1024) ? sprintf("%.1fGi", v / 1024) : sprintf("%dMi", v + 0.5) }
      function U(v,   s) { if (v < 1000) return sprintf("%dm", v + 0.5); s = sprintf("%.1f", v / 1000); sub(/\.0$/, "", s); return s "c" }
      function N(v) { return v == "-" || v == "" }
      BEGIN { c = N(cu) ? (N(cl) ? "-" : "limit " U(cl)) : U(cu) (N(cl) ? " (no limit)" : " / " U(cl))
              m = N(mu) ? (N(ml) ? "-" : "limit " M(ml)) : M(mu) (N(ml) ? " (no limit)" : sprintf(" / %s (%d%%)", M(ml), mu * 100 / ml + 0.5))
              printf "%s\t%s\n", c, m }')"
    # image without the registry host: the name and tag are what matter
    img="$cimage"; case "${img%%/*}" in *.*|*:*|localhost) [ "$img" = "${img%%/*}" ] || img="${img#*/}" ;; esac
    cst="${cstate:--}"; [ -z "$cready" ] || cst+=", $cready"; [ -z "$crst" ] || cst+=", restarts $crst"; [ -z "$clast" ] || cst+=", last exit $clast"
    # shown only while kubectl connects (the container clears it), or with its error
    local dm=""; [ "${COLOR:-1}" != 1 ] || dm=$'\033[90m'
    printf -v INTERACTIVE_BANNER '%s KDASH %s  connecting   %s%s%s  %scontainer%s %s%s%s  %scontext %s%s ...\n' \
      "$m$b" "$r" "$b" "$pod" "$r" "$dm" "$r" "$b" "${c:-default}" "$r" "$dm" "$ctx" "$r"
    INTERACTIVE_FOOTER="${m}${b} KDASH ${r}  shell closed  ${b}${pod}${r}  ${dm}container${r} ${b}${c:-default}${r}  ${dm}exit status${r} %s  ${dm}duration${r} %ss  ${dm}audited${r}\n"
    audit EXEC "pod=$ns/$pod container=${c:--} mode=shell shell=bash-or-sh"
    args=(exec -it "$pod")
    [ -z "$c" ] || args+=(-c "$c")
    args+=(-- sh -c "$INTERACTIVE_SHELL_SCRIPT" kdash "$ctx" "$ns" "$pod" "${c:-default}" "${COLOR:-1}" \
           "$([ "${BARCHR:-unicode}" = ascii ] && echo ascii || echo unicode)" "${pstatus:--}" "${pready:--}" "${prst:--}" \
           "${pnode:--}" "${pip:--}" "${mem:--}" "${img:--}" "${cpu:--}" "${pqos:--}" "$cst" "KD_PIN0=$([ "${KDASH_SHELL_HEADER:-scroll}" = pinned ] && echo 1 || echo 0); $INTERACTIVE_HDR_CODE")
    INTERACTIVE_KEEP=auto interactive_run "${KC[@]}" -n "$ns" "${args[@]}"; rc=$?
    INTERACTIVE_BANNER=""; INTERACTIVE_FOOTER=""
    audit EXEC_END "pod=$ns/$pod container=${c:--} rc=$rc"
    case "$rc" in
      197) kdash_quit "kdquit in $ns/$pod" ;;                       # kdquit: leave kdash
      198) KDASH_SWITCH=1; KDASH_SWITCH_FROM="$ns/$pod"             # kdswitch: related pods
           KDASH_SWITCH_Q="${pwl##*/}"; [ -n "$KDASH_SWITCH_Q" ] || KDASH_SWITCH_Q="${pod%-*}"; rc=0 ;;
    esac
    return "$rc"
}

# ~ and ~/x are not expanded by "read": do it, or the file "does not exist".
interactive_expand() {
    case "$1" in "~") printf '%s' "$HOME" ;; "~/"*) printf '%s/%s' "$HOME" "${1#\~/}" ;; *) printf '%s' "$1" ;; esac
}

interactive_copy() { # up|down ns pod container
    local dir="$1" ns="$2" pod="$3" c="${4:-}"
    local remote="" local_path="" rc=0 bytes=0
    local args=()
    case "$dir" in up|down) ;; *) return 2 ;; esac
    interactive_require "copy-$dir" || return 1

    picker_colors; picker_size
    local what; [ "$dir" = up ] && what="UPLOAD" || what="DOWNLOAD"
    ui_bar "$PK_COLS" " KDASH ${PC_SEP} ${what} ${PC_SEP} context ${CTX_NAME:-current} ${PC_SEP} namespace $ns " " kubectl cp ${PC_SEP} audited "
    printf '\033[H\033[2J%s\n %spod%s        %s%s%s\n %scontainer%s  %s%s%s\n %sdirection%s  %s\n %slocal dir%s  %s\n\n' \
        "$UI_BAR" "$PC_D" "$PC_R" "$PC_B" "$pod" "$PC_R" "$PC_D" "$PC_R" "$PC_B" "${c:-default}" "$PC_R" \
        "$PC_D" "$PC_R" "$([ "$dir" = up ] && printf 'this host  %s  container' "$PC_PTR" || printf 'container  %s  this host' "$PC_PTR")" "$PC_D" "$PC_R" "$PWD"
    local note="runs in your name ${PC_MID} needs tar in the image ${PC_MID} ~ is expanded ${PC_MID} empty answer or Ctrl-D cancels"
    ui_vlen "$note"; [ "$UI_VL" -le $((PK_COLS - 8)) ] || { note="runs in your name ${PC_MID} Ctrl-D cancels"; ui_vlen "$note"; }
    ui_rule "$((PK_COLS - 1))" "${PC_D}${note}${PC_R}" "$UI_VL" "" 0
    printf '%s\n\n' "$UI_RULE"
    printf '\033[?25h'

    if [ "$dir" = up ]; then
        interactive_ask ' local file or directory to send: ' && [ -n "$INTERACTIVE_ANSWER" ] || { printf '\033[?25l\n cancelled\n'; interactive_pause 1; return 1; }
        local_path="$(interactive_expand "$INTERACTIVE_ANSWER")"
        if [ ! -e "$local_path" ]; then
            printf '\033[?25l\n %s does not exist on this host.\n' "${local_path:0:200}"; interactive_pause 3; return 1
        fi
        [ -r "$local_path" ] || { printf '\033[?25l\n %s is not readable by %s.\n' "${local_path:0:200}" "$(id -un)"; interactive_pause 3; return 1; }
        interactive_ask " remote path inside the container (Enter for /tmp/$(basename "$local_path")): " "/tmp/$(basename "$local_path")" \
            || { printf '\033[?25l\n cancelled\n'; interactive_pause 1; return 1; }
        remote="$INTERACTIVE_ANSWER"
        # "/tmp/" means "into /tmp": kubectl cp needs the full target name
        case "$remote" in */) remote="$remote$(basename "$local_path")" ;; esac
    else
        interactive_ask ' remote path inside the container (e.g. /var/log/app/app.log): ' && [ -n "$INTERACTIVE_ANSWER" ] \
            || { printf '\033[?25l\n cancelled\n'; interactive_pause 1; return 1; }
        remote="${INTERACTIVE_ANSWER%/}"; [ -n "$remote" ] || remote=/
        interactive_ask " local destination (Enter for ./$(basename "$remote")): " "./$(basename "$remote")" \
            || { printf '\033[?25l\n cancelled\n'; interactive_pause 1; return 1; }
        local_path="$(interactive_expand "$INTERACTIVE_ANSWER")"
        # an existing directory (or a trailing /) means "into that directory"
        if [ -d "$local_path" ] || [ "${local_path%/}" != "$local_path" ]; then local_path="${local_path%/}/$(basename "$remote")"; fi
        if [ ! -d "$(dirname -- "$local_path")" ]; then
            printf '\033[?25l\n local directory %s does not exist.\n' "$(dirname -- "$local_path")"; interactive_pause 3; return 1
        fi
        [ -w "$(dirname -- "$local_path")" ] || { printf '\033[?25l\n %s is not writable by %s.\n' "$(dirname -- "$local_path")" "$(id -un)"; interactive_pause 3; return 1; }
    fi
    case "$remote" in
        /*) ;;
        *) printf '\033[?25l\n the remote path must be absolute: it starts with / (got %s)\n' "${remote:0:80}"; interactive_pause 3; return 2 ;;
    esac
    if ! interactive_valid_path "$remote" || ! interactive_valid_path "$local_path"; then
        printf '\033[?25l\n paths must be 1..1024 characters with no control bytes.\n'; interactive_pause 3; return 2
    fi
    # kubectl cp reads "a:b" as pod:path, so a local name with ":" cannot work
    case "$local_path" in *:*) printf '\033[?25l\n kubectl cp cannot use a local path with ":" (%s) - rename it or pick another destination.\n' "${local_path:0:120}"; interactive_pause 4; return 2 ;; esac
    if [ "$dir" = down ] && [ -e "$local_path" ]; then
        interactive_ask " local path $local_path exists - overwrite? [y/N] " || INTERACTIVE_ANSWER=n
        case "$INTERACTIVE_ANSWER" in [yY]*) ;; *) printf '\033[?25l\n cancelled\n'; interactive_pause 1; return 1 ;; esac
    fi
    printf '\033[?25l'

    args=(cp)
    [ -z "$c" ] || args+=(-c "$c")
    if [ "$dir" = up ]; then args+=("$local_path" "$ns/$pod:$remote"); else args+=("$ns/$pod:$remote" "$local_path"); fi
    if [ "$dir" = up ]; then
        audit CP_UP "pod=$ns/$pod container=${c:--} remote=$(interactive_audit_path "$remote") local=$(interactive_audit_path "$local_path")"
    else
        audit CP_DOWN "pod=$ns/$pod container=${c:--} remote=$(interactive_audit_path "$remote") local=$(interactive_audit_path "$local_path")"
    fi
    printf '\n %s%s%s  %s%s:%s%s %s %s\n\n' "$PC_B" "$([ "$dir" = up ] && printf 'uploading  ' || printf 'downloading')" "$PC_R" "$PC_B" "$pod" "${remote:0:120}" "$PC_R" "$([ "$dir" = up ] && printf '%s' '<-' || printf '%s' '->')" "${local_path:0:120}"
    INTERACTIVE_KEEP=0 interactive_run "${KC[@]}" -n "$ns" "${args[@]}"; rc=$?
    if [ -e "$local_path" ]; then
        bytes="$(du -sb -- "$local_path" 2>/dev/null | awk '{print $1}')"; case "$bytes" in ''|*[!0-9]*) bytes=0 ;; esac
    fi
    printf '\033[H\033[2J%s\n\n' "$UI_BAR"
    local from to; if [ "$dir" = up ]; then from="$local_path"; to="$pod:$remote"; else from="$pod:$remote"; to="$local_path"; fi
    if [ "$rc" = 0 ]; then
        audit CP_END "pod=$ns/$pod dir=$dir rc=0 bytes=$bytes local=$(interactive_audit_path "$local_path")"
        printf ' %s%s COPY COMPLETE %s\n\n %sfrom%s       %s\n %sto%s         %s\n %ssize%s       %s bytes\n %saudit%s      %s\n' "$PC_OK" "$PC_B" "$PC_R" \
            "$PC_D" "$PC_R" "${from:0:200}" "$PC_D" "$PC_R" "${to:0:200}" "$PC_D" "$PC_R" "$bytes" "$PC_D" "$PC_R" "$([ "$dir" = up ] && printf CP_UP || printf CP_DOWN)"
    else
        audit CP_END "pod=$ns/$pod dir=$dir rc=$rc bytes=$bytes"
        printf ' %s COPY FAILED %s  exit status %s - the kubectl output was shown before this screen\n\n %sfrom%s       %s\n %sto%s         %s\n\n %scommon causes%s\n   %s no tar in the image (distroless / scratch): open a shell (S) or use kubectl debug\n   %s remote path missing, or not writable by the container user (try /tmp)\n   %s RBAC: kubectl cp needs create on pods/exec\n' \
            "$PC_ACT" "$PC_R" "$rc" "$PC_D" "$PC_R" "${from:0:200}" "$PC_D" "$PC_R" "${to:0:200}" "$PC_B" "$PC_R" "$PC_MID" "$PC_MID" "$PC_MID"
    fi
    printf '\n %spress any key to return to kdash%s ' "$PC_D" "$PC_R"
    IFS= read -rsn1 _k </dev/tty || true
    return "$rc"
}

# ---- boxed tables (k9s-style frames): titles set into the border, real column
# outlines, grey borders, reverse video for the selected row. Only the terminal's
# own foreground/background, bold, reverse and the 8 standard colours are used, so
# every frame reads the same on white and on black backgrounds.
bx_init() {
  if [ "${BARCHR:-unicode}" = ascii ]; then
    BX_TL="+"; BX_TR="+"; BX_BL="+"; BX_BR="+"; BX_H="-"; BX_V="|"; BX_LT="+"; BX_RT="+"; BX_TT="+"; BX_BT="+"; BX_X="+"; BX_FULL="#"; BX_EMPTY="."
  else
    BX_TL="┌"; BX_TR="┐"; BX_BL="└"; BX_BR="┘"; BX_H="─"; BX_V="│"; BX_LT="├"; BX_RT="┤"; BX_TT="┬"; BX_BT="┴"; BX_X="┼"; BX_FULL="█"; BX_EMPTY="░"
  fi
  BX_C="${PC_D:-}"; BX_R="${PC_R:-}"
}
bx_vis() { # text (may hold colour escapes) -> BX_VL visible width
  local t="$1"
  while [[ "$t" == *$'\033['* ]]; do
    local pre="${t%%$'\033['*}" rest="${t#*$'\033['}"
    rest="${rest#*[A-Za-z]}"; t="$pre$rest"
  done
  [ "${UI_BYTES:-0}" = 0 ] || t="${t//[$'\200'-$'\277']/}"
  BX_VL=${#t}
}
bx_rep() { local s; printf -v s '%*s' "$2" ''; printf '%s' "${s// /$1}"; }   # glyph count (printing)
bx_repv() { local s; printf -v s '%*s' "$2" ''; BX_REP="${s// /$1}"; }       # same, into BX_REP
bx_cut() { # text width -> BX_CUT (clipped with ~, colour kept)
  bx_vis "$1"
  if [ "$BX_VL" -le "$2" ]; then BX_CUT="$1"; return; fi
  pk_fit "$1" "$(($2 - 1))"; BX_CUT="${PK_FIT}~"
}
bx_pad() { # text width [right] -> BX_PAD
  bx_cut "$1" "$2"; bx_vis "$BX_CUT"
  local g=$(($2 - BX_VL)) sp; [ "$g" -ge 0 ] || g=0; printf -v sp '%*s' "$g" ''
  if [ "${3:-}" = r ]; then BX_PAD="$sp$BX_CUT"; else BX_PAD="$BX_CUT$sp"; fi
}
# ┌─ TITLE ─────────── right ─┐  (title bold; right dim); joints at column edges
bx_top() { # width title right [joint positions...]
  local w="$1" t="$2" r="$3" line mid i; shift 3
  bx_vis "$t"; local tv=$BX_VL; bx_vis "$r"; local rv=$BX_VL
  local fill=$((w - 2 - (tv ? tv + 3 : 0) - (rv ? rv + 3 : 0)))
  [ "$fill" -ge 1 ] || { r=""; rv=0; fill=$((w - 2 - (tv ? tv + 3 : 0))); }
  [ "$fill" -ge 1 ] || fill=1
  bx_repv "$BX_H" "$fill"; mid="$BX_REP"
  if [ $# -gt 0 ]; then   # put ┬ where the columns start (offsets from the left border)
    local off=$((tv ? tv + 3 : 0)) p
    for p in "$@"; do i=$((p - 1 - off)); [ "$i" -ge 0 ] && [ "$i" -lt "$fill" ] && mid="${mid:0:i}${BX_TT}${mid:i+1}"; done
  fi
  line="${BX_C}${BX_TL}${BX_R}"
  [ "$tv" = 0 ] || line+="${BX_C}${BX_H}${BX_R} ${PC_B}${t}${PC_R} "
  line+="${BX_C}${mid}${BX_R}"
  [ "$rv" = 0 ] || line+=" ${r} ${BX_C}${BX_H}${BX_R}"
  line+="${BX_C}${BX_TR}${BX_R}"
  BX_LINE="$line"
}
bx_bot() { # width left-text right-text [joint positions...]
  local w="$1" t="$2" r="$3" mid p i; shift 3
  bx_vis "$t"; local tv=$BX_VL; bx_vis "$r"; local rv=$BX_VL
  local fill=$((w - 2 - (tv ? tv + 3 : 0) - (rv ? rv + 3 : 0)))
  [ "$fill" -ge 1 ] || { t=""; tv=0; fill=$((w - 2 - (rv ? rv + 3 : 0))); }
  bx_repv "$BX_H" "$fill"; mid="$BX_REP"
  local off=$((tv ? tv + 3 : 0))
  for p in "$@"; do i=$((p - 1 - off)); [ "$i" -ge 0 ] && [ "$i" -lt "$fill" ] && mid="${mid:0:i}${BX_BT}${mid:i+1}"; done
  BX_LINE="${BX_C}${BX_BL}${BX_R}"
  [ "$tv" = 0 ] || BX_LINE+="${BX_C}${BX_H}${BX_R} ${t} "
  BX_LINE+="${BX_C}${mid}${BX_R}"
  [ "$rv" = 0 ] || BX_LINE+=" ${r} ${BX_C}${BX_H}${BX_R}"
  BX_LINE+="${BX_C}${BX_BR}${BX_R}"
}
# ├──┬──┼──┴──┤ : kinds per joint position: t (┬) x (┼) b (┴)
bx_sep() { # width kind joint-positions...
  local w="$1" k="$2" mid i p g; shift 2
  case "$k" in t) g="$BX_TT" ;; b) g="$BX_BT" ;; *) g="$BX_X" ;; esac
  bx_repv "$BX_H" $((w - 2)); mid="$BX_REP"
  for p in "$@"; do i=$((p - 1)); [ "$i" -ge 0 ] && [ "$i" -lt $((w - 2)) ] && mid="${mid:0:i}${g}${mid:i+1}"; done
  BX_LINE="${BX_C}${BX_LT}${mid}${BX_RT}${BX_R}"
}
bx_row() { # width content  -> │ content │ (full width)
  bx_pad "$2" $(($1 - 4)); BX_LINE="${BX_C}${BX_V}${BX_R} ${BX_PAD} ${BX_C}${BX_V}${BX_R}"
}
# ├──┴──┬──┼──┤ between two tables: ┴ where only the upper table has a column edge,
# ┬ where only the lower one has, ┼ where both have
bx_sep_mix() { # width "upper joints" "lower joints"
  local w="$1" mid i p; bx_repv "$BX_H" $((w - 2)); mid="$BX_REP"
  for p in $2; do i=$((p - 1)); [ "$i" -ge 0 ] && [ "$i" -lt $((w - 2)) ] && mid="${mid:0:i}${BX_BT}${mid:i+1}"; done
  for p in $3; do i=$((p - 1)); [ "$i" -ge 0 ] && [ "$i" -lt $((w - 2)) ] || continue
    if [ "${mid:i:1}" = "$BX_BT" ]; then mid="${mid:0:i}${BX_X}${mid:i+1}"; else mid="${mid:0:i}${BX_TT}${mid:i+1}"; fi; done
  BX_LINE="${BX_C}${BX_LT}${mid}${BX_RT}${BX_R}"
}
# A whole table inside a frame that is already open: separator from the previous
# section, bold header, ├┼┤, rows (TSV; cells may carry colour), no closing line.
# BX_PREV holds the joints of the section above ("" = a full-width row).
bx_table() { # width flex aligns tsv-file natural-widths...
  local w="$1" flex="$2" al="$3" f="$4" line; shift 4
  local -a nat=("$@") cells; local i n=${#nat[@]}
  # natural widths from the data (capped), at least the given minimum
  while IFS=$'\t' read -r -a cells; do
    for ((i = 0; i < n; i++)); do bx_vis "${cells[i]:-}"; [ "$BX_VL" -le "${nat[i]}" ] || nat[i]=$BX_VL; done
  done < "$f"
  for ((i = 0; i < n; i++)); do [ "${nat[i]}" -le 60 ] || nat[i]=60; done
  bx_layout "$w" "$flex" "${nat[@]}"
  bx_sep_mix "$w" "$BX_PREV" "${BX_J[*]}"; BX_OUT+="$BX_LINE"$'\033[K\n'
  local first=1
  while IFS=$'\t' read -r -a cells; do
    if [ "$first" = 1 ]; then
      local -a hb=(); for ((i = 0; i < n; i++)); do hb+=("${PC_B}${cells[i]:-}${PC_R}"); done
      bx_cells "$al" "${hb[@]}"; BX_OUT+="$BX_LINE"$'\033[K\n'
      bx_sep "$w" x "${BX_J[@]}"; BX_OUT+="$BX_LINE"$'\033[K\n'; first=0; continue
    fi
    local -a cc=(); for ((i = 0; i < n; i++)); do cc+=("${cells[i]:-}"); done
    bx_cells "$al" "${cc[@]}"; BX_OUT+="$BX_LINE"$'\033[K\n'
  done < "$f"
  BX_PREV="${BX_J[*]}"
}
bx_full() { # width content -> a full-width row after any section
  if [ -n "${BX_PREV:-}" ]; then bx_sep_mix "$1" "$BX_PREV" ""; BX_OUT+="$BX_LINE"$'\033[K\n'; BX_PREV=""; fi
  bx_row "$1" "$2"; BX_OUT+="$BX_LINE"$'\033[K\n'
}
bx_close() { # width
  local mid i p; bx_repv "$BX_H" $(($1 - 2)); mid="$BX_REP"
  for p in ${BX_PREV:-}; do i=$((p - 1)); [ "$i" -ge 0 ] && [ "$i" -lt $(($1 - 2)) ] && mid="${mid:0:i}${BX_BT}${mid:i+1}"; done
  BX_OUT+="${BX_C}${BX_BL}${mid}${BX_BR}${BX_R}"$'\033[K\n'; BX_PREV=""
}
# Column layout: BX_W[] widths from natural sizes; the column marked flexible takes the
# rest (or gives way first). BX_J[] = joint offsets for the separators.
bx_layout() { # total-width flex-index natural-widths...
  local w="$1" flex="$2" i n sum=0 over; shift 2
  BX_CW=("$@"); n=${#BX_CW[@]}
  for ((i = 0; i < n; i++)); do sum=$((sum + BX_CW[i])); done
  local avail=$((w - 1 - 3 * n))      # │ + per column " x " + │
  if [ "$sum" -lt "$avail" ]; then BX_CW[flex]=$((BX_CW[flex] + avail - sum))
  else over=$((sum - avail))
    # the flexible column (the name) gives way first, down to BX_FLEX_MIN; then the
    # widest other column, one cell at a time; the name again only as a last resort
    # BX_FAIR=1 (key panels): no favourite - always the widest column gives way
    local fmin="${BX_FLEX_MIN:-10}" fair="${BX_FAIR:-0}"; [ "$fair" = 0 ] || fmin=99999
    while [ "$over" -gt 0 ] && [ "${BX_CW[flex]}" -gt "$fmin" ]; do BX_CW[flex]=$((BX_CW[flex] - 1)); over=$((over - 1)); done
    while [ "$over" -gt 0 ]; do local m=-1 j; for ((j = 0; j < n; j++)); do [ "$j" != "$flex" ] || [ "$fair" = 1 ] || continue; { [ "$m" -lt 0 ] || [ "${BX_CW[j]}" -gt "${BX_CW[m]}" ]; } && m=$j; done
      if [ "$m" -ge 0 ] && [ "${BX_CW[m]}" -gt 6 ]; then BX_CW[m]=$((BX_CW[m] - 1))
      elif [ "${BX_CW[flex]}" -gt 6 ]; then BX_CW[flex]=$((BX_CW[flex] - 1))
      else break; fi; over=$((over - 1)); done
  fi
  BX_J=(); local pos=0
  for ((i = 0; i < n - 1; i++)); do pos=$((pos + BX_CW[i] + 3)); BX_J+=("$pos"); done
}
bx_cells() { # aligns(l/r string per column, e.g. "llrl") cells... -> BX_LINE
  local al="$1" i=0 c line="${BX_C}${BX_V}${BX_R}"; shift
  for c in "$@"; do
    if [ "${al:i:1}" = r ]; then bx_pad "$c" "${BX_CW[i]}" r; else bx_pad "$c" "${BX_CW[i]}"; fi
    line+=" ${BX_PAD} ${BX_C}${BX_V}${BX_R}"; i=$((i + 1))
  done
  BX_LINE="$line"
}
# the cursor row: plain cells, the whole inside of the row in reverse video
bx_cells_sel() { # aligns cells...
  local al="$1" i=0 c inner=""; shift
  for c in "$@"; do
    if [ "${al:i:1}" = r ]; then bx_pad "$c" "${BX_CW[i]}" r; else bx_pad "$c" "${BX_CW[i]}"; fi
    [ "$i" = 0 ] || inner+="$BX_V"
    inner+=" ${BX_PAD} "; i=$((i + 1))
  done
  BX_LINE="${BX_C}${BX_V}${BX_R}${PC_INV}${PC_B}${inner}${PC_R}${BX_C}${BX_V}${BX_R}"
}
# k9s-style key hints: <key> label   (keys bold, labels plain; whole pairs, wrapped)
bx_keys() { # width pairs...
  local w="$1" k a used=1 add; shift
  BX_KEYS=" "
  while [ $# -ge 2 ]; do
    k=$1; a=$2; shift 2
    [ -n "$k" ] || continue
    ui_vlen "<$k> $a"; add=$((UI_VL + 2))
    # a pair that does not fit starts a new row (no key is ever dropped)
    if [ $((used + add)) -gt "$w" ] && [ "$used" -gt 1 ]; then BX_KEYS+=$'\033[K\n '; used=1; fi
    BX_KEYS+="${PC_B}<${k}>${PC_R} ${a}  "; used=$((used + add))
  done
}
# a progress bar: done total width -> BX_BAR (+ percentage)
bx_bar() {
  local d="${1:-0}" t="${2:-0}" w="$3" f pct
  if [ "$t" -gt 0 ]; then pct=$((d * 100 / t)); [ "$pct" -le 100 ] || pct=100; else pct=0; fi
  f=$((w * pct / 100))
  bx_repv "$BX_FULL" "$f"; BX_BAR="${PC_OK}${BX_REP}${PC_R}"; bx_repv "$BX_EMPTY" $((w - f)); BX_BAR+="${PC_D}${BX_REP}${PC_R}"; BX_PCT=$pct
}

# ---- file transfer: browse the container (or this host), select, review, transfer
# Download: container picker -> browse the container -> select one or more entries ->
# summary (sizes, format, destination = the directory kdash was started from) ->
# confirm -> tar streamed over kubectl exec -> zip / tar.gz / plain files -> verify.
# Upload: browse this host -> select -> browse the container for the destination ->
# summary (overwrites) -> confirm -> tar | kubectl exec -i tar x -> verify sizes.
# Every step can be cancelled (q) and nothing is written before the confirmation.

# Lists one directory inside the container. Prints "PWD<TAB>dir", "TAR<TAB>1",
# "E<TAB>type<TAB>name" (d f o, + l for a symlink) and "S<TAB>size<TAB>mtime<TAB>name".
XFER_LIST_SH='d=${1:-.}
cd -- "$d" 2>/dev/null || { echo "ERR	cannot open $d (missing or no permission)"; exit 3; }
printf "PWD\t%s\n" "$(pwd)"
command -v tar >/dev/null 2>&1 && printf "TAR\t1\n"
set -- * .[!.]* ..?*
for f do
  [ -e "$f" ] || [ -L "$f" ] || continue
  if [ -d "$f" ]; then t=d; elif [ -f "$f" ]; then t=f; else t=o; fi
  [ -L "$f" ] && t="${t}l"
  [ -r "$f" ] || t="${t}x"
  printf "E\t%s\t%s\n" "$t" "$f"
done
[ $# -gt 0 ] && command -v stat >/dev/null 2>&1 && stat -L -c "S	%s	%Y	%n" -- "$@" 2>/dev/null
exit 0'
# Sizes of the selected entries (directories counted in full), in KiB.
XFER_DU_SH='cd -- "$1" 2>/dev/null || exit 3; shift; du -sk -- "$@" 2>/dev/null; exit 0'

xfer_tzoff() { local z; z=$(date +%z 2>/dev/null); case "$z" in [+-][0-9][0-9][0-9][0-9]) ;; *) z=+0000 ;; esac
  local s=1; [ "${z:0:1}" = - ] && s=-1; echo $(( s * (10#${z:1:2} * 3600 + 10#${z:3:2} * 60) )); }

# raw listing -> sorted rows: type size human mtime name (directories first)
XFER_ROWS_AWK='
function civil(e,   z, era, doe, yoe, y, doy, mp, d, m, s) {
  if (e !~ /^[0-9]+$/) return "-"; e += off; s = e % 86400; z = int(e / 86400) + 719468
  era = int(z / 146097); doe = z - era * 146097; yoe = int((doe - int(doe / 1460) + int(doe / 36524) - int(doe / 146096)) / 365)
  y = yoe + era * 400; doy = doe - (365 * yoe + int(yoe / 4) - int(yoe / 100)); mp = int((5 * doy + 2) / 153)
  d = doy - int((153 * mp + 2) / 5) + 1; m = mp + (mp < 10 ? 3 : -9); if (m <= 2) y++
  return sprintf("%04d-%02d-%02d %02d:%02d", y, m, d, int(s / 3600), int((s % 3600) / 60)) }
function hs(n,   u, i) { if (n !~ /^[0-9]+$/) return "-"; split("B KiB MiB GiB TiB", u, " "); i = 1; n += 0
  while (n >= 1024 && i < 5) { n /= 1024; i++ } return (i == 1) ? n " B" : sprintf("%.1f %s", n, u[i]) }
BEGIN { FS = "\t" }
$1 == "PWD" { print "P\t" $2 > meta; next }
$1 == "TAR" { print "T\t1" > meta; next }
$1 == "ERR" { print "X\t" $2 > meta; next }
$1 == "E" { n++; T[n] = $2; N[n] = $3; idx[$3] = n; next }
$1 == "S" { nm = $4; for (i = 5; i <= NF; i++) nm = nm "\t" $i; if (nm in idx) { SZ[idx[nm]] = $2; MT[idx[nm]] = $3 } next }
END { for (i = 1; i <= n; i++) { t = T[i]; dir = (substr(t, 1, 1) == "d")
    gsub(/[[:cntrl:]]/, "?", N[i])
    printf "%d%s\t%s\t%s\t%s\t%s\t%s\n", (dir ? 0 : 1), tolower(N[i]), t, (dir ? "-" : (SZ[i] == "" ? "-" : SZ[i])), (dir ? "-" : hs(SZ[i])), civil(MT[i]), N[i] } }'

xfer_list_remote() { # ns pod container dir outfile -> 0, or 1 with XFER_ERR
  local ns="$1" pod="$2" c="$3" dir="$4" out="$5" raw="$5.raw"
  XFER_ERR=""
  "${KC[@]}" -n "$ns" exec "$pod" ${c:+-c "$c"} -- sh -c "$XFER_LIST_SH" kdash "$dir" > "$raw" 2> "$raw.err" </dev/null
  if ! grep -q '^PWD' "$raw" 2>/dev/null; then
    XFER_ERR="$(grep -m1 '^ERR' "$raw" | cut -f2)"
    [ -n "$XFER_ERR" ] || XFER_ERR="$(grep -v '^\s*$' "$raw.err" | tail -n 1 | cut -c1-200)"
    [ -n "$XFER_ERR" ] || XFER_ERR="listing failed (the container needs sh)"
    return 1
  fi
  xfer_rows "$raw" "$out"
}
xfer_list_local() { # dir outfile
  local dir="$1" out="$2" raw="$2.raw" f t
  XFER_ERR=""
  [ -d "$dir" ] && [ -r "$dir" ] && [ -x "$dir" ] || { XFER_ERR="cannot open $dir (missing or no permission)"; return 1; }
  dir="$(cd -- "$dir" && pwd)"
  {
    printf 'PWD\t%s\nTAR\t1\n' "$dir"
    for f in "$dir"/* "$dir"/.[!.]* "$dir"/..?*; do
      [ -e "$f" ] || [ -L "$f" ] || continue
      if [ -d "$f" ]; then t=d; elif [ -f "$f" ]; then t=f; else t=o; fi
      [ -L "$f" ] && t="${t}l"; [ -r "$f" ] || t="${t}x"
      printf 'E\t%s\t%s\n' "$t" "${f##*/}"
    done
    ( cd -- "$dir" && find . -mindepth 1 -maxdepth 1 -printf 'S\t%s\t%T@\t%f\n' 2>/dev/null | sed 's/\.[0-9]*\t/\t/' ) || true
  } > "$raw"
  # find prints the link itself; the size of the target matters
  xfer_rows "$raw" "$out"
}
xfer_rows() { # raw out
  LC_ALL=C awk -v off="$(xfer_tzoff)" -v meta="$2.meta" "$XFER_ROWS_AWK" "$1" | LC_ALL=C sort -t $'\t' -k1,1 | cut -f2- > "$2"
  XFER_PWD="$(awk -F'\t' '$1 == "P" { print $2 }' "$2.meta" 2>/dev/null)"
  XFER_TAR="$(awk -F'\t' '$1 == "T" { print $2 }' "$2.meta" 2>/dev/null)"
}

xfer_hsize() { awk -v n="${1:-0}" 'BEGIN { split("B KiB MiB GiB TiB", u, " "); i = 1; while (n >= 1024 && i < 5) { n /= 1024; i++ }
  if (i == 1) printf "%d B", n; else printf "%.1f %s", n, u[i] }'; }

# One cell of the key panel: the key in bold, what it does now; a key that does
# nothing in the current state is shown dimmed (it is still listed, so the panel
# never jumps around).
xfer_cell() { # key label on(1/0) width keywidth -> XFER_CELL
  local k="$1" l="$2" on="$3" w="$4" kw="${5:-10}" lw t pad
  ui_vlen "$k"; [ "$UI_VL" -lt "$kw" ] || kw=$UI_VL          # a key wider than its column keeps the cell width
  lw=$((w - kw - 1)); [ "$lw" -ge 1 ] || lw=1
  ui_vlen "$l"; [ "$UI_VL" -le "$lw" ] || l="${l:0:$((lw - 1))}~"
  ui_vlen "$k"; printf -v t '%*s' $((kw - UI_VL > 0 ? kw - UI_VL : 0)) ''
  ui_vlen "$l"; pad=$((lw - UI_VL)); [ "$pad" -ge 0 ] || pad=0; printf -v pad '%*s' "$pad" ''
  if [ -z "$k" ] && [ -z "$l" ]; then printf -v XFER_CELL '%*s' "$w" ''
  elif [ "$on" = 1 ]; then XFER_CELL="${PC_B}${k}${PC_R}${t} ${l}${pad}"
  else XFER_CELL="${PC_D}${k}${t} ${l}${pad}${PC_R}"; fi
}
# The key panel: a frame of N columns x 4 rows, column titles set into the top
# border (┌─ MOVE ───┬─ FIND ───┐). Cells are "key|label|on" (on=0 dims a key that
# does nothing right now). The last column (usually the action) takes the slack.
bx_panel() { # width ncols title1..N then N*4 cells (column by column) -> BX_PANEL
  # the same panel as last time (most key presses only move the cursor): reuse it
  local key="${BARCHR:-u}|${COLOR:-1}|$*"
  [ "$key" != "${BX_PANEL_KEY:-}" ] || return 0
  BX_PANEL_KEY="$key"
  local w="$1" nc="$2" r c line i t o first rest each; shift 2
  local -a TT=() CE KW nat
  for ((c = 0; c < nc; c++)); do TT+=("$1"); shift; done
  CE=("$@")
  bx_init
  # natural width of a column: its widest key + label, or its title; the screen width
  # is shared out from that (narrow terminals shorten the widest columns first)
  for ((c = 0; c < nc; c++)); do KW[c]=1; ui_vlen "${TT[c]}"; nat[c]=$((UI_VL + 2)); local lmax=0
    for ((r = 0; r < 4; r++)); do each="${CE[c * 4 + r]}"; i="${each%%|*}"; rest="${each#*|}"; t="${rest%|*}"
      ui_vlen "$i"; [ "$UI_VL" -lt "${KW[c]}" ] || KW[c]=$((UI_VL + 1))
      ui_vlen "$t"; [ "$UI_VL" -le "$lmax" ] || lmax=$UI_VL; done
    [ $((KW[c] + 1 + lmax)) -le "${nat[c]}" ] || nat[c]=$((KW[c] + 1 + lmax)); done
  BX_FAIR=1 bx_layout "$((w - 1))" $((nc - 1)) "${nat[@]}"
  line="${BX_C}${BX_TL}${BX_R}"
  for ((c = 0; c < nc; c++)); do
    local tt="${TT[c]}"; ui_vlen "$tt"; [ "$UI_VL" -le $((BX_CW[c] - 1)) ] || { tt="${tt%% ${PC_MID} *}"; tt="${tt%% · *}"; tt="${tt%% - *}"; ui_vlen "$tt"; }
    [ "$UI_VL" -le $((BX_CW[c] - 1)) ] || { tt="${tt:0:$((BX_CW[c] - 1))}"; ui_vlen "$tt"; }
    local fill=$((BX_CW[c] + 2 - UI_VL - 3)); [ "$fill" -ge 1 ] || fill=1
    bx_repv "$BX_H" "$fill"; line+="${BX_C}${BX_H}${BX_R} ${PC_B}${tt}${PC_R} ${BX_C}${BX_REP}"
    if [ "$c" = $((nc - 1)) ]; then line+="${BX_TR}${BX_R}"; else line+="${BX_TT}${BX_R}"; fi
  done
  BX_PANEL="$line"$'\033[K\n'
  for ((r = 0; r < 4; r++)); do
    local -a cells=()
    for ((c = 0; c < nc; c++)); do
      each="${CE[c * 4 + r]}"; i="${each%%|*}"; rest="${each#*|}"; t="${rest%|*}"; o="${rest##*|}"
      # narrow column: the key column shrinks so labels keep at least 7 cells
      local kwe="${KW[c]}"; [ $((BX_CW[c] - kwe - 1)) -ge 7 ] || { kwe=$((BX_CW[c] - 8)); [ "$kwe" -ge 2 ] || kwe=2; }
      xfer_cell "$i" "$t" "${o:-1}" "${BX_CW[c]}" "$kwe"; cells+=("$XFER_CELL")
    done
    local als; printf -v als '%*s' "$nc" ''; bx_cells "${als// /l}" "${cells[@]}"; BX_PANEL+="$BX_LINE"$'\033[K\n'
  done
  line="${BX_C}${BX_BL}"; for ((c = 0; c < nc; c++)); do bx_repv "$BX_H" $((BX_CW[c] + 2)); line+="$BX_REP"; if [ "$c" = $((nc - 1)) ]; then line+="$BX_BR"; else line+="$BX_BT"; fi; done
  BX_PANEL+="${line}${BX_R}"$'\033[K'
}
xfer_panel() { # width title1..4 then 16 cells -> XFER_PANEL (4 columns)
  local w="$1"; shift
  bx_panel "$w" 4 "$@"; XFER_PANEL="$BX_PANEL"
}

# One full-screen browser. side=remote|local, mode=pick (select entries) or dir
# (choose a destination directory). Returns 0 with XFER_DIR (+ XFER_SEL for pick),
# 1 when cancelled. Q leaves kdash from here too.
xfer_browse() { # side mode title ns pod container start
  local side="$1" mode="$2" title="$3" ns="$4" pod="$5" c="$6" dir="$7" d="$TMPD/xfer"
  local -a T S H M N V
  local -A SEL=()
  local sel=0 top=0 n=0 nv i j k line buf rows q="" typing=0 qd=0 msg="" act="" reload=1 prev="" w_n w_s nsel selb t name mark st lw
  # speed: nothing in the loop below starts a process, and what does not change between
  # two key presses (host name, title bar, table head, the rows themselves, the filtered
  # list) is kept; ui_flush then sends only the lines that differ
  local hn fl=1 vkey="" lkey="" hdr3="" botl="" barkey="" bar1="" nfile=0 ndir=0 selb_h="" selb_p=-1 sp
  local -a RC=()
  hn=$(hostname 2>/dev/null)
  mkdir -p "$d"
  picker_colors
  printf '\033[?25l\033[2J'
  while :; do
    picker_size; bx_init; rows=$((PK_ROWS - 14)); [ "$rows" -ge 3 ] || rows=3
    if [ "$reload" = 1 ]; then
      ui_bar "$PK_COLS" " KDASH ${PC_SEP} ${title} ${PC_SEP} context ${CTX_NAME:-current} ${PC_SEP} namespace $ns " " $([ "$side" = remote ] && printf '%s %s %s' "$pod" "$PC_SEP" "$c" || printf 'this host %s %s' "$PC_SEP" "$(hostname 2>/dev/null)") "
      printf '\033[H%s\033[K\n\033[K\n %sreading%s %s ...\033[J' "$UI_BAR" "$PC_D" "$PC_R" "$dir"
      if [ "$side" = remote ]; then xfer_list_remote "$ns" "$pod" "$c" "$dir" "$d/list"; else xfer_list_local "$dir" "$d/list"; fi
      if [ $? != 0 ]; then
        msg="$XFER_ERR"
        if [ -n "$prev" ] && [ "$prev" != "$dir" ]; then dir="$prev"; continue; fi
        # nothing to go back to: the listing itself does not work here
        printf '\033[H\033[2J%s\n\n %s%s%s\n\n %scannot browse - press any key%s' "$UI_BAR" "$PC_BAD" "$msg" "$PC_R" "$PC_D" "$PC_R"
        IFS= read -rsn1 _ </dev/tty || true; XFER_ERR="$msg"; return 2
      fi
      dir="$XFER_PWD"; prev="$dir"; reload=0; T=(); S=(); H=(); M=(); N=()
      while IFS=$'\t' read -r t k j line name; do T+=("$t"); S+=("$k"); H+=("$j"); M+=("$line"); N+=("$name"); done < "$d/list"
      [ "${#SEL[@]}" = 0 ] || act="${act:+$act - }marks cleared (one directory at a time)"
      n=${#N[@]}; SEL=(); sel=0; top=0; q=""; vkey=""; RC=(); fl=1
      [ "$side" != remote ] || [ "${XFER_TAR:-}" = 1 ] || msg="this container has no tar - transfers will not work (kubectl cp needs it too)"
    fi
    # visible rows (filter)
    if [ "$vkey" != "x$q" ]; then
      V=(); nfile=0; ndir=0
      for ((i = 0; i < n; i++)); do
        [ -z "$q" ] || [[ "${N[i],,}" == *"${q,,}"* ]] || continue
        V+=("$i"); case "${T[i]}" in f*) nfile=$((nfile + 1)) ;; d*) ndir=$((ndir + 1)) ;; esac
      done
      vkey="x$q"
    fi
    nv=${#V[@]}
    [ "$sel" -lt "$nv" ] || sel=$((nv > 0 ? nv - 1 : 0)); [ "$sel" -ge 0 ] || sel=0
    [ "$sel" -ge "$top" ] || top=$sel; [ "$sel" -lt $((top + rows)) ] || top=$((sel - rows + 1))
    w_n=$((PK_COLS - 46)); [ "$w_n" -ge 16 ] || w_n=16
    nsel=0; selb=0; for k in "${!SEL[@]}"; do nsel=$((nsel + 1)); [ "${S[k]}" = - ] || selb=$((selb + S[k])); done
    # screen
    if [ "$barkey" != "$PK_COLS" ]; then
      if [ "$side" = remote ]; then ui_bar "$PK_COLS" " KDASH ${PC_SEP} ${title} ${PC_SEP} ${CTX_NAME:-current} ${PC_SEP} $ns " " $pod $PC_PTR $c "
      else ui_bar "$PK_COLS" " KDASH ${PC_SEP} ${title} ${PC_SEP} ${CTX_NAME:-current} ${PC_SEP} $ns " " this host $PC_PTR $hn "; fi
      bar1="$UI_BAR"; barkey="$PK_COLS"
    fi
    buf=$'\033[H'"${bar1}"$'\033[K\n'
    # path on the left; entries / filter / marks on the right
    local pr pl
    if [ "$typing" = 1 ]; then
      if [ "$mode" = dir ] || [ -z "$q" ]; then t=open; else t=keep; fi
      pr="${PC_INFO}/${PC_R} ${PC_B}${q}${PC_R}${PC_INFO}${PC_CARET}${PC_R}  ${PC_D}FILTER: type a name ${PC_MID} ${PC_UP}${PC_DN} move ${PC_MID} Enter $t ${PC_MID} Esc clear${PC_R}"
    else
      pr="${PC_D}$n entries${PC_R}"; [ -z "$q" ] || pr+="  ${PC_MID}  ${PC_INFO}filter${PC_R} ${PC_B}${q}${PC_R} ${PC_D}($nv)${PC_R}"
      if [ "$selb" != "$selb_p" ]; then selb_h=""; [ "$selb" = 0 ] || selb_h=$(xfer_hsize "$selb"); selb_p=$selb; fi
      [ "$mode" != pick ] || [ "$nsel" = 0 ] || { pr+="  ${PC_MID}  ${PC_OK}${PC_B}${nsel} marked${PC_R}"; [ "$selb" = 0 ] || pr+=" ${PC_D}${selb_h}${PC_R}"; }
    fi
    if [ "$side" = remote ]; then pl=" ${PC_D}CONTAINER${PC_R}  ${PC_B}${dir}${PC_R}"; else pl=" ${PC_D}THIS HOST${PC_R}  ${PC_B}${dir}${PC_R}"; fi
    bx_vis "$pr"; local prw=$BX_VL; bx_cut "$pl" $((PK_COLS - 4 - prw)); bx_vis "$BX_CUT"
    printf -v sp '%*s' $((PK_COLS - 2 - BX_VL - prw > 0 ? PK_COLS - 2 - BX_VL - prw : 1)) ''
    buf+="${BX_CUT}${sp}${pr}"$'\033[K\n'
    # the list, framed: [x] TYPE NAME SIZE MODIFIED
    local al
    if [ "$mode" = pick ]; then bx_layout "$((PK_COLS - 1))" 2 3 5 20 10 16; al="lllrl"
    else bx_layout "$((PK_COLS - 1))" 1 5 20 10 16; al="llrl"; fi
    if [ "$lkey" != "$PK_COLS" ]; then   # table head and foot: once per window width
      bx_sep "$((PK_COLS - 1))" t "${BX_J[@]}"; hdr3="${BX_LINE/${BX_LT}/${BX_TL}}"; hdr3="${hdr3%${BX_RT}${BX_R}}${BX_TR}${BX_R}"$'\033[K\n'
      if [ "$mode" = pick ]; then bx_cells "$al" "${PC_B}SEL${PC_R}" "${PC_B}TYPE${PC_R}" "${PC_B}NAME${PC_R}" "${PC_B}SIZE${PC_R}" "${PC_B}MODIFIED${PC_R}"
      else bx_cells "$al" "${PC_B}TYPE${PC_R}" "${PC_B}NAME${PC_R}" "${PC_B}SIZE${PC_R}" "${PC_B}MODIFIED${PC_R}"; fi
      hdr3+="$BX_LINE"$'\033[K\n'
      bx_sep "$((PK_COLS - 1))" x "${BX_J[@]}"; hdr3+="$BX_LINE"$'\033[K\n'
      bx_sep "$((PK_COLS - 1))" b "${BX_J[@]}"; botl="${BX_LINE/${BX_LT}/${BX_BL}}"; botl="${botl%${BX_RT}${BX_R}}${BX_BR}${BX_R}"$'\033[K\n'
      lkey="$PK_COLS"; RC=()
    fi
    buf+="$hdr3"
    # the frame is as tall as the list; the key panel stays at the bottom of the screen
    local shown=$((nv - top < rows ? nv - top : rows)); [ "$shown" -ge 1 ] || shown=1
    for ((i = 0; i < shown; i++)); do
      j=$((top + i))
      local -a cl=()
      if [ "$j" -ge "$nv" ]; then
        if [ "$mode" = pick ]; then bx_cells "$al" "" "" "${PC_D}$([ "$n" = 0 ] && printf 'empty directory' || printf 'nothing matches - Esc clears the filter')${PC_R}" "" ""
        else bx_cells "$al" "" "${PC_D}$([ "$n" = 0 ] && printf 'empty directory' || printf 'nothing matches - Esc clears the filter')${PC_R}" "" ""; fi
        buf+="$BX_LINE"$'\033[K\n'; continue
      fi
      k=${V[j]}
      if [ "$j" != "$sel" ] && [ -n "${RC[k]:-}" ]; then buf+="${RC[k]}"; continue; fi
      t=${T[k]}; name=${N[k]}
      case "$t" in d*) st="dir"; name+="/" ;; f*) st="file" ;; *) st="other" ;; esac
      case "$t" in *l*) st="link" ;; esac
      if [ -n "${SEL[$k]:-}" ]; then mark="[x]"; else mark="[ ]"; fi
      [ "$mode" = pick ] && cl=("$mark") || cl=()
      cl+=("$st" "$name" "${H[k]}" "${M[k]}")
      if [ "$j" = "$sel" ]; then bx_cells_sel "$al" "${cl[@]}"
      else
        local cc=""
        if [ -n "${SEL[$k]:-}" ]; then cc="${PC_OK}${PC_B}"; elif [[ "$t" == *x* ]]; then cc="$PC_D"; elif [[ "$t" == d* ]]; then cc="${PC_INFO}"; fi
        if [ -n "$cc" ]; then local -a c2=(); for name in "${cl[@]}"; do c2+=("${cc}${name}${PC_R}"); done; cl=("${c2[@]}"); fi
        bx_cells "$al" "${cl[@]}"; RC[k]="$BX_LINE"$'\033[K\n'
      fi
      buf+="$BX_LINE"$'\033[K\n'
    done
    buf+="$botl"
    for ((i = shown; i < rows; i++)); do buf+=$'\033[K\n'; done
    # status rule: the last thing that happened (or a warning) and the position
    local lt rt cur="" curt="" cn="" up="${dir%/*}"; [ -n "$up" ] || up=/
    [ "$nv" = 0 ] || { cur=${V[sel]}; curt=${T[cur]}; cn=${N[cur]}; }
    if [ -n "$msg" ]; then lt="${PC_WARN}${msg}${PC_R}"; ui_vlen "$msg"
    elif [ -n "$act" ]; then lt="${PC_OK}${PC_PTR}${PC_R} ${act}"; ui_vlen "x $act"
    else lt="${PC_D}ready${PC_R}"; ui_vlen "ready"; fi
    lw=$UI_VL; [ "$lw" -le $((PK_COLS - 40)) ] || { lt="${lt:0:$((PK_COLS - 40))}${PC_R}"; lw=$((PK_COLS - 40)); }
    rt="$((nv ? sel + 1 : 0)) / ${nv} ${PC_MID} ${side} ${PC_MID} audited"; ui_vlen "$rt"
    ui_rule "$((PK_COLS - 1))" "$lt" "$lw" "${PC_D}${rt}${PC_R}" "$UI_VL"
    buf+="$UI_RULE"$'\033[K\n'
    # key panel, labels for exactly this state
    local c1 c2 c3 c4 t4 t3 isd=0 isf=0 tgt="" l1 l2 l3 o1 o2 o3
    [[ "$curt" == d* ]] && isd=1; [[ "$curt" == f* ]] && isf=1
    local nsd=0; for k in "${!SEL[@]}"; do [[ "${T[k]}" == d* ]] && nsd=$((nsd + 1)); done
    if [ "$nsel" -gt 0 ]; then
      tgt="$nsel marked"
      if [ "$selb" != 0 ] && [ "$nsd" -gt 0 ]; then tgt+=" ($selb_h + $nsd dir)"
      elif [ "$selb" != 0 ]; then tgt+=" ($selb_h)"; elif [ "$nsd" -gt 0 ]; then tgt+=" ($nsd dir)"; fi
    elif [ -n "$cn" ]; then tgt="$cn"; fi
    if [ -n "$q" ]; then l1="\"$q\" - Esc clears"; else l1="filter names"; fi
    c1=("j/k ${PC_UP}${PC_DN}|move|1" "PgUp/PgDn|page|1" "g / G|first / last|1" "/|$l1|1")
    if [ "$isd" = 1 ]; then l1="open $cn/"; o1=1; elif [ "$isf" = 1 ] && [ "$mode" = pick ]; then l1="mark $cn"; o1=1; else l1="open (directories)"; o1=0; fi
    if [ "$dir" = / ]; then l2="up (already at /)"; o2=0; elif [ "$up" = / ]; then l2="up to /"; o2=1; else l2="up to ${up##*/}/"; o2=1; fi
    if [ "$isf" = 1 ]; then l3="view $cn"; else l3="view (files only)"; fi
    c2=("Enter|$l1|$o1" "h / Bksp|$l2|$o2" "p|go to a path|1" "v|$l3|$isf")
    if [ "$mode" = pick ]; then
      t3=SELECT
      if [ -z "$cn" ]; then l1="mark"; o1=0; elif [ -n "${SEL[$cur]:-}" ]; then l1="unmark $cn"; o1=1; else l1="mark $cn"; o1=1; fi
      [ "$nfile" -gt 0 ] && o2=1 || o2=0; [ "$nsel" -gt 0 ] && o3=1 || o3=0; [ "$nsel" = 1 ] && l3="clear 1 mark" || l3="clear $nsel marks"
      c3=("Space|$l1|$o1" "a|mark all files ($nfile)|$o2" "n|$l3|$o3" "r|reload this list|1")
    else
      t3=DESTINATION
      [ "$ndir" = 1 ] && l1="1 sub-directory" || l1="$ndir sub-directories"
      c3=("|in ${dir##*/}/|1" "|$l1|0" "|Enter opens one|0" "r|reload this list|1")
    fi
    [ -n "$tgt" ] && o1=1 || o1=0
    if [ "$side" = remote ] && [ "$mode" = pick ]; then
      t4="DOWNLOAD"; [ -n "$tgt" ] && l1="download $tgt" || l1="download"
      c4=("d|$l1|$o1" "|then: review, confirm or cancel|0" "q / Esc|cancel, back to kdash|1" "Q|quit kdash|1")
    elif [ "$mode" = pick ]; then
      t4="UPLOAD  step 1 of 2"; [ -n "$tgt" ] && l1="next: destination for $tgt" || l1="next: destination"
      c4=("u|$l1|$o1" "|nothing is copied yet|0" "q / Esc|cancel, back to kdash|1" "Q|quit kdash|1")
    else
      t4="UPLOAD  step 2 of 2"
      c4=("u|upload ${XFER_UPN:-the items} into ${dir##*/}/|1" "|then: review, confirm or cancel|0" "q / Esc|cancel, back to kdash|1" "Q|quit kdash|1")
    fi
    xfer_panel "$PK_COLS" "MOVE" "OPEN ${PC_MID} VIEW" "$t3" "$t4" "${c1[@]}" "${c2[@]}" "${c3[@]}" "${c4[@]}"
    buf+="$XFER_PANEL"
    ui_flush "$buf" "xfer:$side:$mode:$PK_COLS:$PK_ROWS" "$fl"; fl=1
    picker_key 120 || continue
    # after a key that only moves, marks or types in the filter the screen is still ours: send the difference
    if [ "$typing" = 1 ]; then case "$PK_KEY_IN" in '<ENTER>'|'<LEFT>'|'<RIGHT>') ;; *) fl=0 ;; esac
    else case "$PK_KEY_IN" in j|k|g|G|' '|a|n|/|'<UP>'|'<DN>'|'<PGUP>'|'<PGDN>'|'<HOME>'|'<END>'|'<ESC>') fl=0 ;; esac; fi
    msg=""; act=""
    if [ "$typing" = 1 ]; then
      # the filter never traps the keys: arrows still move, Enter opens the directory under the
      # cursor (destination list, or nothing typed yet), Backspace on an empty filter goes up
      case "$PK_KEY_IN" in
        '<ESC>') typing=0; q=""; act="filter cleared"; continue ;;
        '<ENTER>') typing=0
          if [ "$mode" != dir ] && [ -n "$q" ]; then act="filter \"$q\": $nv match"; continue; fi ;;
        $'\177'|$'\b')
          if [ -n "$q" ]; then q="${q%?}"; qd=1; sel=0; continue; fi
          typing=0; if [ "$qd" = 1 ]; then act="filter closed - Backspace again goes up one directory"; continue; fi ;;
        $'\025') q=""; qd=1; continue ;;
        '<UP>'|'<DN>'|'<PGUP>'|'<PGDN>'|'<HOME>'|'<END>') ;;
        '<LEFT>'|'<RIGHT>') typing=0 ;;
        '<'*'>') continue ;;
        *) q+="$PK_KEY_IN"; sel=0; continue ;;
      esac
    fi
    k=""; [ "$nv" = 0 ] || k=${V[sel]}
    # Esc clears an active filter first; only then does it leave (like q)
    if [ "$PK_KEY_IN" = '<ESC>' ] && [ -n "$q" ]; then q=""; act="filter cleared"; continue; fi
    case "$PK_KEY_IN" in
      q|'<ESC>') return 1 ;;
      Q) kdash_quit "file browser" ;;
      j|'<DN>') [ "$nv" = 0 ] || sel=$(( (sel + 1) % nv )) ;;
      k|'<UP>') [ "$nv" = 0 ] || sel=$(( (sel + nv - 1) % nv )) ;;
      '<PGDN>'|' '*) [ "$PK_KEY_IN" = '<PGDN>' ] && sel=$((sel + rows)) ;;
      '<PGUP>') sel=$((sel - rows)) ;;
      g|'<HOME>') sel=0 ;; G|'<END>') sel=$((nv - 1)) ;;
      /) typing=1; qd=0 ;;
      r) reload=1; act="reloaded" ;;
      h|'<LEFT>'|$'\177'|$'\b'|-) if [ "$dir" = / ]; then msg="already at /"; else dir="${dir%/*}"; [ -n "$dir" ] || dir=/; reload=1; act="up to $dir"; fi ;;
      l|'<RIGHT>') [ -n "$k" ] && [[ "${T[k]}" == d* ]] && { dir="${dir%/}/${N[k]}"; reload=1; act="opened ${N[k]}/"; } ;;
      p|:) printf '\033[%s;1H\033[K\033[?25h %spath%s (absolute, or relative to %s): ' "$PK_ROWS" "$PC_B" "$PC_R" "$dir"
           local np=""; IFS= read -r np </dev/tty || np=""; printf '\033[?25l'; case "$np" in *$'\e'*) np="" ;; esac
           if [ -n "$np" ] && interactive_valid_path "$np"; then
             [ "$side" = local ] && np="$(interactive_expand "$np")"
             case "$np" in /*) dir="$np" ;; *) dir="${dir%/}/$np" ;; esac; reload=1; act="went to $np"
           fi ;;
      v) if [ -n "$k" ] && [[ "${T[k]}" == f* ]]; then xfer_view "$side" "$ns" "$pod" "$c" "$dir" "${N[k]}" "${S[k]}"; printf '\033[?25l\033[2J'; act="viewed ${N[k]}"
         else msg="v views files - the cursor is not on a file"; fi ;;
      a) if [ "$mode" = pick ]; then i=0; for k in "${V[@]}"; do [[ "${T[k]}" == f* ]] && { SEL[$k]=1; i=$((i + 1)); }; done; act="marked all $i files (${#SEL[@]} marked)"; RC=(); fi ;;
      n) [ "${#SEL[@]}" = 0 ] && msg="nothing is marked" || act="cleared ${#SEL[@]} mark(s)"; SEL=(); RC=() ;;
      '<ENTER>')
        [ -n "$k" ] || continue
        if [[ "${T[k]}" == d* ]]; then dir="${dir%/}/${N[k]}"; reload=1; act="opened ${N[k]}/"
        elif [ "$mode" = pick ]; then if [ -n "${SEL[$k]:-}" ]; then unset "SEL[$k]" "RC[$k]"; act="unmarked ${N[k]} (${#SEL[@]} marked)"; else SEL[$k]=1; unset "RC[$k]"; act="marked ${N[k]} (${#SEL[@]} marked)"; fi; sel=$((sel + 1))
        else msg="${N[k]} is a file - choose a directory, then u"; fi ;;
      d|u)
        if [ "$mode" = dir ]; then [ "$PK_KEY_IN" = u ] || continue; XFER_DIR="$dir"; return 0; fi
        { [ "$side" = remote ] && [ "$PK_KEY_IN" = d ]; } || { [ "$side" = local ] && [ "$PK_KEY_IN" = u ]; } || continue
        if [ "${#SEL[@]}" = 0 ] && [ -n "$k" ]; then SEL[$k]=1; fi     # nothing marked: take the highlighted entry
        XFER_DIR="$dir"; XFER_SEL=(); XFER_SELT=(); XFER_SELS=()
        for ((i = 0; i < n; i++)); do [ -n "${SEL[$i]:-}" ] || continue; XFER_SEL+=("${N[i]}"); XFER_SELT+=("${T[i]}"); XFER_SELS+=("${S[i]}"); done
        [ "${#XFER_SEL[@]}" -gt 0 ] && return 0 ;;
    esac
    # Space toggles (picker_key returns it as a plain " ")
    if [ "$PK_KEY_IN" = " " ] && [ "$mode" = pick ] && [ -n "$k" ]; then
      if [ -n "${SEL[$k]:-}" ]; then unset "SEL[$k]" "RC[$k]"; act="unmarked ${N[k]} (${#SEL[@]} marked)"; else SEL[$k]=1; unset "RC[$k]"; act="marked ${N[k]} (${#SEL[@]} marked)"; fi
      sel=$((sel + 1)); [ "$sel" -lt "$nv" ] || sel=$((nv - 1))
    fi
    [ "$sel" -ge 0 ] || sel=0
  done
}

# First 64 KiB of a file, in less (or more) - read-only.
xfer_view() { # side ns pod container dir name size
  local f="$TMPD/xfer/view.txt" p="${2:-}" pager
  if [ "$1" = remote ]; then
    "${KC[@]}" -n "$2" exec "$3" ${4:+-c "$4"} -- sh -c 'cd -- "$1" && head -c 65536 -- "$2"' kdash "$5" "$6" 2>&1 </dev/null | inspector_clean > "$f"
  else head -c 65536 -- "$5/$6" 2>&1 | inspector_clean > "$f"; fi
  [ "${7:-0}" = - ] || [ "${7:-0}" -le 65536 ] 2>/dev/null || printf '\n[kdash: first 64 KiB of %s shown]\n' "$(xfer_hsize "$7")" >> "$f"
  pager="$(command -v less || command -v more || echo cat)"
  printf '\033[2J\033[H\033[?25h'
  { printf '%s/%s  (q returns)\n\n' "$5" "$6"; cat "$f"; } | LESS='-R -K' "$pager"
  [ "${pager##*/}" != cat ] || { printf '\n any key returns'; IFS= read -rsn1 _ </dev/tty; }
  printf '\033[?25l'
}

# key/value + table rows on a plain screen (the summaries)
xfer_kv() { printf ' %s%-11s%s %s\n' "$PC_D" "$1" "$PC_R" "$2"; }
xfer_table() { TK_COLOR="${COLOR:-1}" TK_COLS="$PK_COLS" TK_GLYPH="${BARCHR:-unicode}" tk_table "$@" | tk_colorize; }

# A transfer in the background: poll every 0.3 s, show bytes and rate, q cancels.
xfer_run_bg() { # label count-file -- cmd... (runs "$@" in a subshell) -> rc, 130 = cancelled
  local label="$1" cnt="$2" pid rc t0=$SECONDS b el rate key k left w bw total="${XFER_EXPECT:-0}"; shift 2; [ "$1" = -- ] && shift
  bx_init; picker_size; w=$((PK_COLS - 1)); bw=$((w - 62)); [ "$bw" -ge 10 ] || bw=10
  bx_top "$w" "$label" "${PC_D}q cancels${PC_R}"; printf '%s\n' "$BX_LINE"
  ( "$@" ) & pid=$!
  while kill -0 "$pid" 2>/dev/null; do
    b=0; [ -z "$cnt" ] || b=$(stat -c %s -- "$cnt" 2>/dev/null || wc -c < "$cnt" 2>/dev/null || echo 0)
    el=$((SECONDS - t0)); rate=$(( el > 0 ? b / el : b ))
    if [ "$total" -gt 0 ]; then
      bx_bar "$b" "$total" "$bw"
      left="-"; [ "$rate" -gt 0 ] && [ "$b" -lt "$total" ] && left="$(( (total - b) / rate ))s"
      bx_row "$w" "${BX_BAR} ${PC_B}$(printf '%3s' "$BX_PCT")%${PC_R}  $(xfer_hsize "$b") / $(xfer_hsize "$total")  ${PC_D}${PC_MID}${PC_R}  $(xfer_hsize "$rate")/s  ${PC_D}${PC_MID}${PC_R}  ${el}s  ${PC_D}left${PC_R} ${left}"
    else
      bx_row "$w" "$(xfer_hsize "$b")  ${PC_D}${PC_MID}${PC_R}  $(xfer_hsize "$rate")/s  ${PC_D}${PC_MID}${PC_R}  ${el}s"
    fi
    printf '\r%s' "$BX_LINE"
    key=""; IFS= read -rsn1 -t 0.3 key </dev/tty || true
    if [ "$key" = q ] || [ "$key" = Q ]; then
      local kids=""; command -v pgrep >/dev/null 2>&1 && kids="$(pgrep -P "$pid" 2>/dev/null | tr '\n' ' ')"
      kill "$pid" 2>/dev/null; [ -z "$kids" ] || kill $kids 2>/dev/null
      for k in $kids; do pkill -TERM -P "$k" 2>/dev/null; done          # kubectl under the guard
      wait "$pid" 2>/dev/null
      bx_bot "$w" "${PC_WARN}cancelled${PC_R}" ""; printf '\n%s\n' "$BX_LINE"; return 130
    fi
  done
  wait "$pid"; rc=$?
  bx_bot "$w" "$([ "$rc" = 0 ] && printf '%sdone%s - verifying' "$PC_OK" "$PC_R" || printf '%sfailed%s' "$PC_BAD" "$PC_R")" ""; printf '\n%s\n' "$BX_LINE"
  return "$rc"
}

# the two transfer pipelines; they run in xfer_run_bg's subshell with the caller's locals
xfer_down_pipe() {
  "${KC[@]}" -n "$ns" exec "$pod" ${c:+-c "$c"} -- sh -c 'cd -- "$1" && shift && tar cf - -- "$@"' kdash "$src" "${items[@]}" > "$part" 2>> "$d/err" </dev/null
}
xfer_up_pipe() {
  local st
  ( cd -- "$lsrc" && tar cf - -- "${items[@]}" ) 2>> "$d/err" | tee "$d/sent" |
    "${KC[@]}" -n "$ns" exec -i "$pod" ${c:+-c "$c"} -- sh -c 'cd -- "$1" && tar xf -' kdash "$dst" > /dev/null 2>> "$d/err"
  st=("${PIPESTATUS[@]}")
  [ "${st[0]}" = 0 ] || return "${st[0]}"
  return "${st[2]}"
}
xfer_stamp() { date +%Y%m%d_%H%M%S; }
xfer_safe() { printf '%s' "$1" | tr -c 'A-Za-z0-9._-' '_' | cut -c1-60; }
xfer_zip_tool() { if command -v zip >/dev/null 2>&1; then echo zip; elif command -v python3 >/dev/null 2>&1; then echo python3; else echo ""; fi; }

# Fingerprints of the transferred items, computed the same way in the container and
# on this host (POSIX sh, no awk): file = size + hash; directory = number of files,
# total bytes and one hash over "hash path" of every file in sorted order; symlink =
# hash of its target text. ALG sha256 (preferred), md5 or none (sizes only).
XFER_SUM_SH='alg=$1; d=$2; shift 2
cd -- "$d" 2>/dev/null || exit 3
if [ "$alg" = auto ]; then
  if command -v sha256sum >/dev/null 2>&1; then alg=sha256; elif command -v md5sum >/dev/null 2>&1; then alg=md5; else alg=none; fi
fi
[ "${KDASH_XFER_HASH:-1}" = 0 ] && alg=none
case "$alg" in sha256) H=sha256sum ;; md5) H=md5sum ;; *) H="" ;; esac
hs() { if [ -n "$H" ]; then $H | cut -d " " -f 1; else cat > /dev/null; echo -; fi; }
printf "ALG\t%s\n" "$alg"
for n do
  if [ -L "$n" ]; then t=l; f=0; b=$(readlink -- "$n" | wc -c); h=$(readlink -- "$n" | hs)
  elif [ -f "$n" ]; then t=f; f=1; b=$(wc -c < "$n"); h=$(hs < "$n")
  elif [ -d "$n" ]; then t=d
    l=$(find "$n" -type f 2>/dev/null | LC_ALL=C sort | while IFS= read -r x; do printf "%s %s %s\n" "$(wc -c < "$x" | tr -d " ")" "$(hs < "$x")" "$x"; done)
    f=0; b=0
    while read -r s r; do [ -n "$s" ] || continue; f=$((f + 1)); b=$((b + s)); done <<EOT
$l
EOT
    h=$(printf "%s\n" "$l" | hs)
  else t=o; f=0; b=0; h=-; fi
  printf "I\t%s\t%s\t%s\t%s\t%s\n" "$t" "$f" "$(echo $b)" "$h" "$n"
done
exit 0'
# Pre-flight facts about one directory: tools, writable, free KiB, du of items.
XFER_PRE_SH='d=$1; shift; cd -- "$d" 2>/dev/null || { printf "ERR\tcannot open %s\n" "$d"; exit 3; }
for t in tar sha256sum md5sum; do command -v $t >/dev/null 2>&1 && printf "TOOL\t%s\n" $t; done
[ -w . ] && printf "WRITABLE\t1\n"
printf "FREE\t%s\n" "$(df -Pk . 2>/dev/null | tail -n 1 | tr -s " " | cut -d " " -f 4)"
[ $# -gt 0 ] && du -sk -- "$@" 2>/dev/null | sed "s/^/DU	/"
exit 0'

xfer_pre_parse() { # file -> XP_TOOLS XP_WRITABLE XP_FREE (KiB) XP_DU[name]=KiB XP_ERR
  local k a b
  XP_TOOLS=" "; XP_WRITABLE=0; XP_FREE=""; XP_ERR=""; XP_DU=()
  while IFS=$'\t' read -r k a b; do
    case "$k" in TOOL) XP_TOOLS+="$a " ;; WRITABLE) XP_WRITABLE=1 ;; FREE) XP_FREE="$a" ;; DU) XP_DU[$b]="$a" ;; ERR) XP_ERR="$a" ;; esac
  done < "$1"
  case "$XP_FREE" in ''|*[!0-9]*) XP_FREE="" ;; esac
}
xfer_sum_parse() { # file prefix -> <prefix>T[name] F B H, <prefix>ALG
  local k t f b h n
  while IFS=$'\t' read -r k t f b h n; do
    case "$k" in
      ALG) eval "${2}ALG=\$t" ;;
      I) eval "${2}T[\$n]=\$t; ${2}F[\$n]=\$f; ${2}B[\$n]=\$b; ${2}H[\$n]=\$h" ;;
    esac
  done < "$1"
}
xfer_glyphs() { if [ "${BARCHR:-unicode}" = ascii ]; then XG_OK="*"; XG_BAD="*"; XG_WARN="*"; XG_ELL=".."; else XG_OK="●"; XG_BAD="●"; XG_WARN="●"; XG_ELL="…"; fi; }
# a solid status chip: READY / VERIFIED (green), CHECK (yellow), BLOCKED / FAILED (red)
xfer_chip() { # pass|warn|fail text
  if [ "${COLOR:-1}" != 1 ]; then printf '[ %s ]' "$2"; return; fi
  case "$1" in pass) printf '\033[1;30;42m %s \033[0m' "$2" ;; warn) printf '\033[1;30;43m %s \033[0m' "$2" ;; *) printf '\033[1;97;41m %s \033[0m' "$2" ;; esac
}
# label + value lines of the review / result screens
xfer_n() { [ "$1" = 1 ] && printf '1 %s' "$2" || printf '%s %ss' "$1" "$2"; }   # 1 item / 3 items
xfer_secs() { [ "$1" -gt 0 ] 2>/dev/null && printf '%ss' "$1" || printf 'under 1s'; }
xfer_line() { printf '  %s%-6s%s %s\n' "$PC_D" "$1" "$PC_R" "$2"; }
# the checks as one verdict line; only what needs attention is spelled out
xfer_checks_view() { # checks-file what(download|upload) -> sets XC_FAIL
  local n=0 nb=0 nw=0 names="" chk res det
  while IFS=$'\t' read -r chk res det; do
    [ "$chk" = CHECK ] && continue; n=$((n + 1))
    case "$res" in "{r}"*) nb=$((nb + 1)) ;; "{y}"*) nw=$((nw + 1)) ;;
      *) case "$chk" in tar*) chk=tar ;; checksum*) chk=checksum ;; readable*) chk=readable ;; "local directory"|"destination writable") chk=writable ;; *space*) chk="free space" ;; esac
         names+="${names:+ $PC_MID }$chk" ;; esac
  done < "$1"
  XC_FAIL=$nb
  if [ "$nb" -gt 0 ]; then printf '  %s  %s%s of %s checks block the %s%s\n' "$(xfer_chip fail BLOCKED)" "$PC_BAD" "$nb" "$n" "$2" "$PC_R"
  elif [ "$nw" -gt 0 ]; then printf '  %s  %s passed, %s to note\n' "$(xfer_chip warn READY)" "$((n - nw))" "$nw"
  else printf '  %s  all %s checks passed  %s%s%s\n' "$(xfer_chip pass READY)" "$n" "$PC_D" "$names" "$PC_R"; fi
  while IFS=$'\t' read -r chk res det; do
    case "$res" in "{r}"*) printf '     %s%s%s %-28s %s\n' "$PC_BAD" "$XG_BAD" "$PC_R" "$chk" "$det" ;; "{y}"*) printf '     %s%s%s %-28s %s\n' "$PC_WARN" "$XG_WARN" "$PC_R" "$chk" "$det" ;; esac
  done < "$1"
}
# item list: name, size, note - one header, no table chrome
xfer_items_view() { # rows-file (name TAB size TAB note), max rows
  local max="${2:-12}" n=0 w=24 nm sz no total
  total=$(wc -l < "$1")
  while IFS=$'\t' read -r nm sz no; do [ "${#nm}" -le "$w" ] || w=${#nm}; done < "$1"
  [ "$w" -le 60 ] || w=60
  printf '  %s%-*s  %10s  %-30s%s\n' "$PC_HDR" "$w" ITEM SIZE "" "$PC_R"
  while IFS=$'\t' read -r nm sz no; do
    n=$((n + 1)); [ "$n" -le "$max" ] || break
    [ "${#nm}" -le "$w" ] || nm="${nm:0:$((w - 1))}~"
    no="${no#  }"
    printf '  %-*s  %10s  %s\n' "$w" "$nm" "$sz" "$no"
  done < "$1"
  [ "$total" -le "$max" ] || printf '  %s+ %s more%s\n' "$PC_D" "$((total - max))" "$PC_R"
}
# one row of a CHECKS table: name pass|warn|fail detail
xfer_check() { case "$2" in pass) printf '%s\t{g}%s pass\t%s\n' "$1" "$XG_OK" "$3" ;; warn) printf '%s\t{y}%s check\t%s\n' "$1" "$XG_WARN" "$3" ;; *) printf '%s\t{r}%s blocked\t%s\n' "$1" "$XG_BAD" "$3" ;; esac; }
xfer_short_hash() { [ "${1:--}" = - ] && { printf -- '-'; return; }; printf '%s%s%s' "${1:0:10}" "$XG_ELL" "${1: -6}"; }
xfer_kind() { case "$1" in d*) echo dir ;; f*) echo file ;; l*) echo link ;; *) echo other ;; esac; }
xfer_free_name() { # dir name -> a name that does not exist yet: "name (2).ext"
  local dir="$1" n="$2" stem ext i=2
  [ -e "$dir/$n" ] || [ -L "$dir/$n" ] || { printf '%s' "$n"; return; }
  stem="$n"; ext=""; case "$n" in ?*.*) stem="${n%.*}"; ext=".${n##*.}" ;; esac
  while [ -e "$dir/$stem ($i)$ext" ] || [ -L "$dir/$stem ($i)$ext" ]; do i=$((i + 1)); done
  printf '%s' "$stem ($i)$ext"
}
# compare two fingerprints into a VERIFICATION table; sets XV_OK XV_BAD
xfer_verify_table() { # rows-file names...   (uses ST_* = source, DT_* = destination, labels in XV_SRC / XV_DST)
  local f="$1" n ok; shift
  XV_OK=0; XV_BAD=0
  printf 'ITEM\tTYPE\t>FILES\t>%s\t>%s\t%s\tCHECK\n' "$XV_SRC" "$XV_DST" "$(case "${STALG:-none}" in sha256) echo SHA-256 ;; md5) echo MD5 ;; *) echo CHECKSUM ;; esac)" > "$f"
  for n in "$@"; do
    ok=1
    [ "${STT[$n]:-?}" = "${DTT[$n]:-!}" ] || ok=0
    [ "${STB[$n]:-?}" = "${DTB[$n]:-!}" ] || ok=0
    [ "${STF[$n]:-?}" = "${DTF[$n]:-!}" ] || ok=0
    [ "${STALG:-none}" = none ] || [ "${STH[$n]:-?}" = "${DTH[$n]:-!}" ] || ok=0
    if [ -z "${DTT[$n]:-}" ]; then st="{r}$XG_BAD missing"; XV_BAD=$((XV_BAD + 1))
    elif [ "$ok" = 1 ]; then st="{g}$XG_OK identical"; XV_OK=$((XV_OK + 1))
    elif [ "${STB[$n]:-}" != "${DTB[$n]:-}" ] && [ "${STT[$n]:-}" = f ]; then st="{r}$XG_BAD size differs"; XV_BAD=$((XV_BAD + 1))
    else st="{r}$XG_BAD content differs"; XV_BAD=$((XV_BAD + 1)); fi
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$n$([ "${STT[$n]:-}" = d ] && echo /)" "$(xfer_kind "${STT[$n]:-o}")" "${STF[$n]:--}" \
      "$([ -n "${STB[$n]:-}" ] && xfer_hsize "${STB[$n]}" || echo -)" "$([ -n "${DTB[$n]:-}" ] && xfer_hsize "${DTB[$n]}" || echo -)" \
      "$(xfer_short_hash "${STH[$n]:--}")" "$st" >> "$f"
  done
}
# headline of a result screen: one chip + one line
xfer_result_head() { # differ seconds
  local alg; case "${STALG:-none}" in sha256) alg="SHA-256" ;; md5) alg="MD5" ;; *) alg="file count and bytes" ;; esac
  if [ "$1" = 0 ]; then printf '  %s  %s identical %s %s %s %s\n\n' "$(xfer_chip pass VERIFIED)" "$(xfer_n "$XV_OK" item)" "$PC_MID" "$alg" "$PC_MID" "$(xfer_secs "$2")"
  else printf '  %s  %s%s of %s items differ%s %s %s - a file may still be written to; run it again\n\n' "$(xfer_chip fail CHECK)" "$PC_BAD" "$1" "$((XV_OK + $1))" "$PC_R" "$PC_MID" "$alg"; fi
}
# the verification as a short list: item, size, result (hashes only when they differ)
xfer_verify_view() { # verify-file (from xfer_verify_table)
  local it ty fc sb db hs ck w=24
  while IFS=$'\t' read -r it ty fc sb db hs ck; do [ "$it" = ITEM ] && continue; [ "${#it}" -le "$w" ] || w=${#it}; done < "$1"
  [ "$w" -le 60 ] || w=60
  printf '  %s%-*s  %10s  %-20s%s\n' "$PC_HDR" "$w" ITEM SIZE RESULT "$PC_R"
  while IFS=$'\t' read -r it ty fc sb db hs ck; do
    [ "$it" = ITEM ] && continue
    case "$ck" in
      "{g}"*) printf '  %-*s  %10s  %s%s identical%s%s\n' "$w" "${it:0:$w}" "$db" "$PC_OK" "$XG_OK" "$PC_R" "$([ "$ty" = dir ] && printf '  %s%s files%s' "$PC_D" "$fc" "$PC_R")" ;;
      *) printf '  %-*s  %10s  %s%s %s%s  %sexpected %s, %s%s\n' "$w" "${it:0:$w}" "${db:--}" "$PC_BAD" "$XG_BAD" "${ck#\{r\}* }" "$PC_R" "$PC_D" "$sb" "$hs" "$PC_R" ;;
    esac
  done < "$1"
}
# the line under the verification table
xfer_verdict() { # what
  if [ "$XV_BAD" = 0 ]; then
    printf ' %s%s %s of %s item(s) identical%s  %s%s%s\n' "$PC_OK$PC_B" "$XG_OK" "$XV_OK" "$((XV_OK + XV_BAD))" "$PC_R" "$PC_D" \
      "$([ "${STALG:-none}" = none ] && printf -- '- file count and bytes compared (no checksum tool in the container)' || printf -- '- file count, bytes and %s of every file compared' "$([ "$STALG" = sha256 ] && echo SHA-256 || echo MD5)")" "$PC_R"
  else
    printf ' %s%s %s of %s item(s) differ%s  %s- a file may still be written to, or the copy was incomplete; run it again%s\n' "$PC_BAD" "$XG_BAD" "$XV_BAD" "$((XV_OK + XV_BAD))" "$PC_R" "$PC_D" "$PC_R"
  fi
}

# The review screen (download and upload): one frame - route, items, checks - then
# the verdict chip and the keys. Nothing has been copied when this is shown.
xfer_review_box() { # what(DOWNLOAD|UPLOAD) from to tonote rows-file checks-file summary keys...
  local what="$1" from="$2" to="$3" tonote="$4" rows="$5" checks="$6" summ="$7" w; shift 7
  bx_init; w=$((PK_COLS - 1))
  ui_bar "$PK_COLS" " KDASH ${PC_SEP} ${what} ${PC_SEP} REVIEW ${PC_SEP} ${CTX_NAME:-current} ${PC_SEP} $ns " " nothing is copied before Enter "
  BX_OUT="$UI_BAR"$'\033[K\n\n'; BX_PREV=""
  bx_top "$w" "$what" "${PC_D}review${PC_R}"; BX_OUT+="$BX_LINE"$'\033[K\n'
  bx_row "$w" "${PC_D}FROM ${PC_R}  ${from}"; BX_OUT+="$BX_LINE"$'\033[K\n'
  bx_row "$w" "${PC_D}TO   ${PC_R}  ${to}   ${PC_D}${tonote}${PC_R}"; BX_OUT+="$BX_LINE"$'\033[K\n'
  { printf 'ITEM\tSIZE\tNOTE\n'; cat "$rows"; } > "$rows.t"
  bx_table "$w" 2 lrl "$rows.t" 30 10 12
  bx_full "$w" "${PC_D}${summ}${PC_R}"
  # checks: result words coloured, details plain
  awk -F'\t' -v ok="$PC_OK" -v wa="$PC_WARN" -v ba="$PC_BAD" -v r="$PC_R" -v dot="$XG_OK" '
    NR == 1 { gsub(/[*~]/, ""); print; next }
    { c = $2; col = (c ~ /^\{r\}/) ? ba : (c ~ /^\{y\}/) ? wa : ok; sub(/^\{[a-z]\}/, "", c); sub(/^[^ ]* /, "", c)
      print $1 "\t" col dot " " c r "\t" $3 }' "$checks" > "$checks.t"
  bx_table "$w" 2 lll "$checks.t" 26 9 20
  bx_close "$w"
  printf '\033[H\033[2J%s' "$BX_OUT"
  xfer_checks_verdict "$checks"
  bx_keys "$w" "$@"; printf '%s\n' "$BX_KEYS"
}
# one chip + one sentence under the frame
xfer_checks_verdict() { # checks-file -> XC_FAIL
  local n=0 nb=0 nw=0 chk res det
  while IFS=$'\t' read -r chk res det; do
    [ "$chk" = CHECK ] && continue; n=$((n + 1))
    case "$res" in "{r}"*) nb=$((nb + 1)) ;; "{y}"*) nw=$((nw + 1)) ;; esac
  done < "$1"
  XC_FAIL=$nb
  if [ "$nb" -gt 0 ]; then printf '\n %s  %s of %s checks block this - see the red rows\n' "$(xfer_chip fail BLOCKED)" "$nb" "$n"
  elif [ "$nw" -gt 0 ]; then printf '\n %s  %s checks passed, %s to note (yellow)\n' "$(xfer_chip warn READY)" "$((n - nw))" "$nw"
  else printf '\n %s  all %s checks passed\n' "$(xfer_chip pass READY)" "$n"; fi
}

# The result screen: verdict chip, where it went, then the verification table.
xfer_result_box() { # what verify-file label1 value1 [label2 value2 ...]
  local what="$1" vf="$2" w alg; shift 2
  bx_init; picker_size; w=$((PK_COLS - 1))
  case "${STALG:-none}" in sha256) alg="SHA-256" ;; md5) alg="MD5" ;; *) alg="file count and bytes" ;; esac
  ui_bar "$PK_COLS" " KDASH ${PC_SEP} ${what} ${PC_SEP} RESULT ${PC_SEP} ${CTX_NAME:-current} ${PC_SEP} $ns " " audited "
  BX_OUT="$UI_BAR"$'\033[K\n\n'; BX_PREV=""
  bx_top "$w" "$what" "${PC_D}result${PC_R}"; BX_OUT+="$BX_LINE"$'\033[K\n'
  if [ "$XV_BAD" = 0 ]; then
    bx_row "$w" "$(xfer_chip pass VERIFIED)  $(xfer_n "$XV_OK" item) identical  ${PC_D}${PC_MID}${PC_R}  ${alg}  ${PC_D}${PC_MID}${PC_R}  $(xfer_secs "${XR_SECS:-0}")"
  else
    bx_row "$w" "$(xfer_chip fail CHECK)  ${PC_BAD}${XV_BAD} of $((XV_OK + XV_BAD)) items differ${PC_R}  ${PC_D}${PC_MID} a file may still be written to - run it again${PC_R}"
  fi
  BX_OUT+="$BX_LINE"$'\033[K\n'
  while [ $# -ge 2 ]; do bx_row "$w" "${PC_D}$(printf '%-6s' "$1")${PC_R} $2"; BX_OUT+="$BX_LINE"$'\033[K\n'; shift 2; done
  # ITEM TYPE FILES <src> <dst> HASH CHECK  (results coloured, hashes shortened)
  awk -F'\t' -v ok="$PC_OK" -v ba="$PC_BAD" -v r="$PC_R" '
    NR == 1 { gsub(/[>*~]/, ""); print; next }
    { c = $7; col = (c ~ /^\{g\}/) ? ok : ba; sub(/^\{[a-z]\}/, "", c); $7 = col c r; print }' OFS='\t' "$vf" > "$vf.t"
  bx_table "$w" 0 llrrrll "$vf.t" 24 5 5 12 12 19 14
  bx_close "$w"
  printf '\033[H\033[2J%s' "$BX_OUT"
}

xfer_download() { # ns pod container  (b on the summary goes back to the list)
  local rc; while :; do xfer_download_once "$@"; rc=$?; [ "$rc" = 3 ] || return "$rc"; done
}
xfer_download_once() { # ns pod container
  local ns="$1" pod="$2" c="$3" i rc fmt name base ans d="$TMPD/xfer" part st nm kb tb=0 fail=0 nconf=0 need
  local launch="${KDASH_LAUNCH_DIR:-$PWD}" zt; zt="$(xfer_zip_tool)"
  local -A XP_DU=() STT=() STF=() STB=() STH=() DTT=() DTF=() DTB=() DTH=()
  local STALG="" DTALG="" XP_TOOLS XP_WRITABLE XP_FREE XP_ERR XV_OK XV_BAD XV_SRC XV_DST
  xfer_glyphs; mkdir -p "$d"
  xfer_browse remote pick "DOWNLOAD" "$ns" "$pod" "$c" "${XFER_BACK:-}" ; rc=$?
  XFER_BACK=""
  [ "$rc" = 0 ] || return "$rc"
  local src="$XFER_DIR"; local -a items=("${XFER_SEL[@]}") types=("${XFER_SELT[@]}") sizes=("${XFER_SELS[@]}")
  picker_size
  ui_bar "$PK_COLS" " KDASH ${PC_SEP} DOWNLOAD ${PC_SEP} SUMMARY ${PC_SEP} context ${CTX_NAME:-current} ${PC_SEP} namespace $ns " " review before anything is copied "
  printf '\033[H\033[2J%s\n\n %schecking %s item(s) in the container ...%s' "$UI_BAR" "$PC_D" "${#items[@]}" "$PC_R"
  "${KC[@]}" -n "$ns" exec "$pod" ${c:+-c "$c"} -- sh -c "$XFER_PRE_SH" kdash "$src" "${items[@]}" > "$d/pre" 2>/dev/null </dev/null || true
  xfer_pre_parse "$d/pre"
  for ((i = 0; i < ${#items[@]}; i++)); do
    if [[ "${types[i]}" == f* ]] && [ "${sizes[i]:--}" != - ]; then tb=$((tb + sizes[i])); else tb=$((tb + ${XP_DU[${items[i]}]:-0} * 1024)); fi; done
  # default: the files and directories under their own names; zip / tar.gz on request,
  # named after the item (one) or the directory they come from (several)
  fmt=files
  if [ "${#items[@]}" = 1 ]; then base="${items[0]}"; else base="${src##*/}"; [ -n "$base" ] || base="root"; fi
  local outdir="$launch"
  while :; do
    case "$fmt" in zip) name="$base.zip" ;; tgz) name="$base.tar.gz" ;; files) name="" ;; esac
    # pre-flight checks
    fail=0; nconf=0
    if [ "$fmt" = files ]; then for nm in "${items[@]}"; do { [ -e "$outdir/$nm" ] || [ -L "$outdir/$nm" ]; } && nconf=$((nconf + 1)); done
    else { [ -e "$outdir/$name" ] || [ -L "$outdir/$name" ]; } && nconf=1; fi
    need=$((tb / 1024 + 1)); [ "$fmt" = files ] || need=$((need * 2))      # archives: staging + archive
    local lfree; lfree="$(df -Pk "$outdir" 2>/dev/null | tail -n 1 | tr -s ' ' | cut -d ' ' -f 4)"
    local nunread=0; for ((i = 0; i < ${#items[@]}; i++)); do [[ "${types[i]}" == *x* ]] && nunread=$((nunread + 1)); done
    {
      printf 'CHECK\tRESULT\tDETAIL~\n'
      if [ "${XFER_TAR:-}" = 1 ] || [[ "$XP_TOOLS" == *" tar "* ]]; then xfer_check "tar in the container" pass "streams the selection"
      else xfer_check "tar in the container" fail "not found - the image cannot send files"; fail=1; fi
      if [[ "$XP_TOOLS" == *" sha256sum "* ]]; then xfer_check "checksum in the container" pass "sha256sum - every file is verified after the copy"
      elif [[ "$XP_TOOLS" == *" md5sum "* ]]; then xfer_check "checksum in the container" warn "only md5sum - files are verified with MD5"
      else xfer_check "checksum in the container" warn "none - only file count and bytes are compared"; fi
      if [ "$nunread" = 0 ]; then xfer_check "readable in the container" pass "${#items[@]} of ${#items[@]} item(s)"
      else xfer_check "readable in the container" fail "$nunread item(s) not readable by the container user"; fail=1; fi
      if [ -w "$outdir" ]; then xfer_check "local directory" pass "writable"
      else xfer_check "local directory" fail "$outdir is not writable - l chooses another"; fail=1; fi
      if [ -z "$lfree" ]; then xfer_check "local free space" warn "unknown - about $(xfer_hsize $((need * 1024))) needed"
      elif [ "$lfree" -ge "$need" ]; then xfer_check "local free space" pass "$(xfer_hsize $((lfree * 1024))) free, about $(xfer_hsize $((need * 1024))) needed"
      else xfer_check "local free space" fail "$(xfer_hsize $((lfree * 1024))) free, about $(xfer_hsize $((need * 1024))) needed"; fail=1; fi
      if [ "$nconf" = 0 ]; then xfer_check "names" pass "$([ "$fmt" = files ] && echo 'same names as in the container, none exists here yet' || echo "$name does not exist yet")"
      else xfer_check "names" warn "$(xfer_n "$nconf" item) already here - Enter asks: replace or keep both"; fi
    } > "$d/checks"
    for ((i = 0; i < ${#items[@]}; i++)); do
      nm="${items[i]}"; kb="${XP_DU[$nm]:-}"
      printf '%s\t%s\t%s\n' "$nm$([[ "${types[i]}" == d* ]] && echo /)" \
        "$(if [[ "${types[i]}" == f* ]] && [ "${sizes[i]:--}" != - ]; then xfer_hsize "${sizes[i]}"; elif [ -n "$kb" ]; then xfer_hsize $((kb * 1024)); else echo -; fi)" \
        "$(case "${types[i]}" in d*) printf 'directory';; l*) printf 'symlink';; *) printf 'file';; esac)$([ "$fmt" = files ] && { [ -e "$outdir/$nm" ] || [ -L "$outdir/$nm" ]; } && printf ' - %sexists here%s' "$PC_WARN" "$PC_R")"
    done > "$d/rows"
    xfer_review_box DOWNLOAD "${PC_B}${pod}${PC_R} ${PC_D}${PC_PTR}${PC_R} ${c:-default} ${PC_D}${PC_PTR}${PC_R} ${PC_B}${src}${PC_R}" \
      "${PC_B}${outdir%/}/${name}${PC_R}" "$(case "$fmt" in files) echo 'same names as in the container';; zip) echo "zip archive$([ "$zt" = python3 ] && echo ' (python3)')";; tgz) echo 'tar.gz archive';; esac)" \
      "$d/rows" "$d/checks" \
      "$(xfer_n "${#items[@]}" item)  ${PC_MID}  $(xfer_hsize "$tb")  ${PC_MID}  $([[ "$XP_TOOLS" == *" sha256sum "* ]] && echo 'SHA-256 verified after the copy' || { [[ "$XP_TOOLS" == *" md5sum "* ]] && echo 'MD5 verified after the copy' || echo 'size verified after the copy'; })" \
      enter "$([ "$fail" = 0 ] && echo download || echo 'download (blocked)')" f "$(case "$fmt" in files) echo 'zip';; zip) echo 'tar.gz';; *) echo 'same names';; esac)" \
      l "other folder" n "$([ "$fmt" = files ] && echo 'rename (archives)' || echo 'rename')" b "back to files" q cancel
    [ -z "${XFER_NOTE:-}" ] || printf '\n  %s%s%s %s\n' "$PC_OK" "$PC_PTR" "$PC_R" "$XFER_NOTE"
    XFER_NOTE=""
    printf ' \033[?25h%schoose%s %s>%s ' "$PC_B" "$PC_R" "$PC_D" "$PC_R"
    ans=""; IFS= read -rsn1 ans </dev/tty || ans=q; printf '\033[?25l'
    case "$ans" in
      ''|y|Y) [ "$fail" = 0 ] || { XFER_NOTE="the download is blocked: fix the checks marked $XG_BAD (l changes the local directory)"; continue; }
              if [ "$nconf" -gt 0 ]; then
                printf '\n  %s %s%s already here%s   r replace   k keep both ("name (2)")   other key: back ' "$(xfer_chip warn NAMES)" "$PC_WARN" "$(xfer_n "$nconf" item)" "$PC_R"
                ans=""; IFS= read -rsn1 ans </dev/tty || ans=""
                case "$ans" in r|R) XFER_CONFLICT=replace ;; k|K) XFER_CONFLICT=keep ;; *) continue ;; esac
              else XFER_CONFLICT=replace; fi
              break ;;
      f|F) case "$fmt" in files) if [ -n "$zt" ]; then fmt=zip; else fmt=tgz; fi ;; zip) fmt=tgz ;; *) fmt=files ;; esac
           XFER_NOTE="format is now $(case "$fmt" in zip) echo "zip ($base.zip)";; tgz) echo "tar.gz ($base.tar.gz)";; *) echo 'the same names as in the container';; esac)" ;;
      l|L) printf '\n local directory: '; local nd=""; IFS= read -r nd </dev/tty || nd=""; case "$nd" in *$'\e'*) nd="" ;; esac; nd="$(interactive_expand "$nd")"
           if [ -n "$nd" ] && [ -d "$nd" ]; then outdir="$(cd -- "$nd" && pwd)"; XFER_NOTE="local directory is now $outdir"
           elif [ -n "$nd" ]; then XFER_NOTE="$nd is not a directory - unchanged"; fi ;;
      n|N) [ "$fmt" = files ] && { XFER_NOTE="plain files keep their names - f switches to zip or tar.gz"; continue; }
           printf '\n archive name without extension [%s]: ' "$base"; local nb=""; IFS= read -r nb </dev/tty || nb=""; case "$nb" in *$'\e'*) nb="" ;; esac
           [ -z "$nb" ] || { base="${nb%.zip}"; base="${base%.tar.gz}"; base="${base//\//_}"; XFER_NOTE="archive name is now $base"; } ;;
      b|B) XFER_BACK="$src"; return 3 ;;
      q|$'\033') audit CP_CANCEL "dir=down pod=$ns/$pod container=${c:--} at=summary"; return 1 ;;
      Q) kdash_quit "download summary" ;;
    esac
  done
  # transfer: tar stream to a partial file, unpacked into a staging directory next to
  # the result, verified against the container, then moved / archived under the names
  part="$outdir/.kdash-partial-$$.tar"; local stage="$outdir/.kdash-stage-$$"
  audit CP_DOWN "pod=$ns/$pod container=${c:--} remote=$(interactive_audit_path "$src") items=${#items[@]} format=$fmt local=$(interactive_audit_path "$outdir/${name:-}")"
  printf '\n'
  : > "$d/err"; local t0=$SECONDS
  XFER_EXPECT="$tb" xfer_run_bg "DOWNLOADING ${PC_MID} $(xfer_n "${#items[@]}" item) from ${pod}" "$part" -- xfer_down_pipe; rc=$?
  local out="" count=0 asum="" atest="" saved=()
  if [ "$rc" = 0 ] && [ -s "$part" ]; then
    rm -rf "$stage"; mkdir -p "$stage" && tar xf "$part" -C "$stage" 2>> "$d/err" || rc=1
    count="$(tar tf "$part" 2>/dev/null | wc -l | tr -d ' ')"
  elif [ "$rc" = 0 ]; then rc=1; fi
  rm -f "$part"
  if [ "$rc" = 0 ]; then
    printf ' %sverifying: checksums in the container and here ...%s' "$PC_D" "$PC_R"
    "${KC[@]}" -n "$ns" exec "$pod" ${c:+-c "$c"} -- sh -c "$XFER_SUM_SH" kdash auto "$src" "${items[@]}" > "$d/rsum" 2>/dev/null </dev/null || true
    xfer_sum_parse "$d/rsum" ST
    sh -c "$XFER_SUM_SH" kdash "${STALG:-none}" "$stage" "${items[@]}" > "$d/lsum" 2>/dev/null || true
    xfer_sum_parse "$d/lsum" DT
    XV_SRC="IN CONTAINER"; XV_DST="HERE"; xfer_verify_table "$d/verify" "${items[@]}"
    # put the result in place under the names chosen on the summary
    case "$fmt" in
      files)
        for nm in "${items[@]}"; do
          local tgt="$nm"
          if [ -e "$outdir/$nm" ] || [ -L "$outdir/$nm" ]; then
            if [ "$XFER_CONFLICT" = keep ]; then tgt="$(xfer_free_name "$outdir" "$nm")"; else rm -rf -- "${outdir:?}/$nm"; fi
          fi
          mv -f -- "$stage/$nm" "$outdir/$tgt" 2>> "$d/err" && saved+=("$([ "$tgt" = "$nm" ] && printf '%s' "$nm" || printf '%s -> %s (kept both)' "$nm" "$tgt")") || rc=1
        done
        out="$outdir" ;;
      tgz)
        [ "$XFER_CONFLICT" = keep ] && name="$(xfer_free_name "$outdir" "$name")"
        out="$outdir/$name"
        ( cd "$stage" && tar czf "$out.part" -- "${items[@]}" ) 2>> "$d/err" && mv -f "$out.part" "$out" || rc=1
        [ "$rc" = 0 ] && { gzip -t "$out" 2>/dev/null && atest="$XG_OK gzip -t passed" || atest="$XG_BAD gzip -t failed"; } ;;
      zip)
        [ "$XFER_CONFLICT" = keep ] && name="$(xfer_free_name "$outdir" "$name")"
        out="$outdir/$name"; rm -f "$out"
        if [ "$zt" = zip ]; then ( cd "$stage" && zip -qry "$out" "${items[@]/#/./}" ) 2>> "$d/err" || rc=1
        else ( cd "$stage" && python3 - "$out" "${items[@]}" <<'PY'
import os, sys, zipfile
out = sys.argv[1]
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED, allowZip64=True) as z:
    def add(path):
        if os.path.islink(path):
            # Link targets belong to the container. Never resolve them on this host.
            info = zipfile.ZipInfo(path.replace(os.sep, "/"))
            info.create_system = 3
            info.external_attr = os.lstat(path).st_mode << 16
            info.compress_type = zipfile.ZIP_DEFLATED
            z.writestr(info, os.readlink(path))
        else:
            z.write(path)
    for top in sys.argv[2:]:
        if os.path.isdir(top) and not os.path.islink(top):
            for root, dirs, files in os.walk(top, followlinks=False):
                add(root)
                for d in dirs[:]:
                    path = os.path.join(root, d)
                    if os.path.islink(path):
                        add(path)
                        dirs.remove(d)
                for f in files: add(os.path.join(root, f))
        else: add(top)
PY
          ) 2>> "$d/err" || rc=1; fi
        if [ "$rc" = 0 ]; then
          if command -v unzip >/dev/null 2>&1; then unzip -tq "$out" >/dev/null 2>&1 && atest="$XG_OK unzip -t passed" || atest="$XG_BAD unzip -t failed"
          elif command -v python3 >/dev/null 2>&1; then python3 -c 'import sys,zipfile; sys.exit(zipfile.ZipFile(sys.argv[1]).testzip() is not None)' "$out" 2>/dev/null && atest="$XG_OK zip test passed" || atest="$XG_BAD zip test failed"; fi
        fi ;;
    esac
    [ "$fmt" = files ] || { [ "$rc" = 0 ] && command -v sha256sum >/dev/null && asum="$(sha256sum -- "$out" | cut -c1-64)"; }
  fi
  rm -rf "$stage"
  picker_size
  ui_bar "$PK_COLS" " KDASH ${PC_SEP} DOWNLOAD ${PC_SEP} RESULT ${PC_SEP} ${CTX_NAME:-current} ${PC_SEP} $ns " " audited "
  printf '\033[H\033[2J%s\n\n' "$UI_BAR"
  if [ "$rc" = 0 ]; then
    audit CP_END "pod=$ns/$pod dir=down rc=0 entries=$count identical=$XV_OK differ=$XV_BAD alg=${STALG:-none} local=$(interactive_audit_path "$out")"
    XR_SECS=$((SECONDS - t0))
    if [ "$fmt" = files ]; then
      local sv=""; for nm in "${saved[@]}"; do sv+="${sv:+  $PC_MID  }$nm"; done
      xfer_result_box DOWNLOAD "$d/verify" SAVED "${PC_B}${outdir%/}/${PC_R}   ${sv:0:200}" \
        FROM "${pod} ${PC_D}${PC_PTR}${PC_R} ${c:-default} ${PC_D}${PC_PTR}${PC_R} ${src}"
    else
      xfer_result_box DOWNLOAD "$d/verify" SAVED "${PC_B}${out}${PC_R}   ${PC_D}$(xfer_hsize "$(stat -c %s -- "$out" 2>/dev/null || echo 0)")${PC_R}" \
        TEST "${atest}$([ -z "$asum" ] || printf '   %ssha256 %s%s' "$PC_D" "$asum" "$PC_R")" \
        FROM "${pod} ${PC_D}${PC_PTR}${PC_R} ${c:-default} ${PC_D}${PC_PTR}${PC_R} ${src}"
    fi
  else
    audit CP_END "pod=$ns/$pod dir=down rc=$rc"
    if [ "$rc" = 130 ]; then printf '  %s  partial data was removed, nothing was saved\n' "$(xfer_chip warn CANCELLED)"
    else
      printf '  %s  exit status %s\n\n' "$(xfer_chip fail FAILED)" "$rc"
      grep -v '^\s*$' "$d/err" 2>/dev/null | grep -v 'Removing leading' | tail -n 6 | inspector_clean | sed 's/^/   /'
      printf '\n %scommon causes%s\n   %s no tar in the image (distroless / scratch)\n   %s files not readable by the container user\n   %s RBAC: needs create on pods/exec\n   %s local disk full or not writable\n' \
        "$PC_B" "$PC_R" "$PC_MID" "$PC_MID" "$PC_MID" "$PC_MID"
    fi
  fi
  printf '\n %s<any key>%s back to kdash ' "$PC_B" "$PC_R"; IFS= read -rsn1 _ </dev/tty || true
  return "$rc"
}

# Upload summary: runs with xfer_upload's locals. 0 = start, 1 = cancel, 3 = back to
# the local list, 4 = choose another destination.
xfer_upload_summary() {
  local nm kb i st ans fail nunread rfree need
  EXIST=(); KB=(); total=0; nover=0
  while IFS=$'\t' read -r _ _ _ _ nm; do EXIST[$nm]=1; done < "$d/list"
  while IFS=$'\t' read -r kb nm; do nm="${nm##*/}"; KB[$nm]="$kb"; done < <(cd -- "$lsrc" && du -sk -- "${items[@]}" 2>/dev/null)
  tb=0; for ((i = 0; i < ${#items[@]}; i++)); do
    if [[ "${types[i]}" == f* ]] && [ "${sizes[i]:--}" != - ]; then tb=$((tb + sizes[i])); else tb=$((tb + ${KB[${items[i]}]:-0} * 1024)); fi; done
  picker_size
  ui_bar "$PK_COLS" " KDASH ${PC_SEP} UPLOAD ${PC_SEP} SUMMARY ${PC_SEP} context ${CTX_NAME:-current} ${PC_SEP} namespace $ns " " review before anything is copied "
  printf '\033[H\033[2J%s\n\n %schecking the destination in the container ...%s' "$UI_BAR" "$PC_D" "$PC_R"
  "${KC[@]}" -n "$ns" exec "$pod" ${c:+-c "$c"} -- sh -c "$XFER_PRE_SH" kdash "$dst" > "$d/pre" 2>/dev/null </dev/null || true
  xfer_pre_parse "$d/pre"
  while :; do
    nover=0; for nm in "${items[@]}"; do [ -z "${EXIST[$nm]:-}" ] || nover=$((nover + 1)); done
    nunread=0; for ((i = 0; i < ${#items[@]}; i++)); do [[ "${types[i]}" == *x* ]] && nunread=$((nunread + 1)); done
    need=$((tb / 1024 + 1)); fail=0
    {
      printf 'CHECK\tRESULT\tDETAIL~\n'
      if [ "$nunread" = 0 ]; then xfer_check "readable here" pass "${#items[@]} of ${#items[@]} item(s)"
      else xfer_check "readable here" fail "$nunread item(s) not readable by $(id -un)"; fail=1; fi
      if [[ "$XP_TOOLS" == *" tar "* ]] || [ "${XFER_TAR:-}" = 1 ]; then xfer_check "tar in the container" pass "receives the stream"
      else xfer_check "tar in the container" fail "not found - the image cannot receive files"; fail=1; fi
      if [ "$XP_WRITABLE" = 1 ]; then xfer_check "destination writable" pass "$dst"
      else xfer_check "destination writable" fail "$dst is not writable by the container user - d chooses another (try /tmp)"; fail=1; fi
      if [ -z "$XP_FREE" ]; then xfer_check "free space in the container" warn "unknown - about $(xfer_hsize $((need * 1024))) needed"
      elif [ "$XP_FREE" -ge "$need" ]; then xfer_check "free space in the container" pass "$(xfer_hsize $((XP_FREE * 1024))) free, about $(xfer_hsize $((need * 1024))) needed"
      else xfer_check "free space in the container" fail "$(xfer_hsize $((XP_FREE * 1024))) free, about $(xfer_hsize $((need * 1024))) needed"; fail=1; fi
      if [[ "$XP_TOOLS" == *" sha256sum "* ]]; then xfer_check "checksum in the container" pass "sha256sum - every file is verified after the copy"
      elif [[ "$XP_TOOLS" == *" md5sum "* ]]; then xfer_check "checksum in the container" warn "only md5sum - files are verified with MD5"
      else xfer_check "checksum in the container" warn "none - only file count and bytes are compared"; fi
      if [ "$nover" = 0 ]; then xfer_check "names" pass "same names as here, none exists in the destination yet"
      else xfer_check "names" warn "$(xfer_n "$nover" item) already in the destination - Enter asks before replacing"; fi
    } > "$d/checks"
    for ((i = 0; i < ${#items[@]}; i++)); do
      nm="${items[i]}"
      printf '%s\t%s\t%s\n' "$nm$([[ "${types[i]}" == d* ]] && echo /)" \
        "$(if [[ "${types[i]}" == f* ]] && [ "${sizes[i]:--}" != - ]; then xfer_hsize "${sizes[i]}"; elif [ -n "${KB[$nm]:-}" ]; then xfer_hsize $(( ${KB[$nm]} * 1024 )); else echo -; fi)" \
        "$(case "${types[i]}" in d*) printf 'directory';; l*) printf 'symlink';; *) printf 'file';; esac)$([ -z "${EXIST[$nm]:-}" ] || printf ' - %sexists in the container%s' "$PC_WARN" "$PC_R")"
    done > "$d/rows"
    xfer_review_box UPLOAD "${PC_B}${lsrc}${PC_R}   ${PC_D}this host${PC_R}" \
      "${PC_B}${pod}${PC_R} ${PC_D}${PC_PTR}${PC_R} ${c:-default} ${PC_D}${PC_PTR}${PC_R} ${PC_B}${dst%/}/${PC_R}" "same names as here" \
      "$d/rows" "$d/checks" \
      "$(xfer_n "${#items[@]}" item)  ${PC_MID}  $(xfer_hsize "$tb")  ${PC_MID}  $([[ "$XP_TOOLS" == *" sha256sum "* ]] && echo 'SHA-256 verified after the copy' || { [[ "$XP_TOOLS" == *" md5sum "* ]] && echo 'MD5 verified after the copy' || echo 'size verified after the copy'; })" \
      enter "$([ "$fail" = 0 ] && echo upload || echo 'upload (blocked)')" d "other destination" b "back to files" q cancel
    [ -z "${XFER_NOTE:-}" ] || printf '\n  %s%s%s %s\n' "$PC_WARN" "$PC_PTR" "$PC_R" "$XFER_NOTE"
    XFER_NOTE=""
    printf ' \033[?25h%schoose%s %s>%s ' "$PC_B" "$PC_R" "$PC_D" "$PC_R"
    ans=""; IFS= read -rsn1 ans </dev/tty || ans=q; printf '\033[?25l'
    case "$ans" in
      ''|y|Y) [ "$fail" = 0 ] || { XFER_NOTE="the upload is blocked: fix the checks marked $XG_BAD (d chooses another destination)"; continue; }
              if [ "$nover" -gt 0 ]; then printf '\n  %s replace %s in the container? [y/N] ' "$(xfer_chip warn NAMES)" "$(xfer_n "$nover" existing\ item)"; ans=""; IFS= read -rsn1 ans </dev/tty || ans=n
                case "$ans" in y|Y) break ;; *) continue ;; esac; fi; break ;;
      d|D) return 4 ;;
      b|B) XFER_BACK="$lsrc"; return 3 ;;
      q|$'\033') audit CP_CANCEL "dir=up pod=$ns/$pod container=${c:--} at=summary"; return 1 ;;
      Q) kdash_quit "upload summary" ;;
    esac
  done
  return 0
}

xfer_upload() { # ns pod container  (b on the summary goes back to the local list)
  local rc; while :; do xfer_upload_once "$@"; rc=$?; [ "$rc" = 3 ] || return "$rc"; done
}
xfer_upload_once() { # ns pod container
  local ns="$1" pod="$2" c="$3" rc i ans d="$TMPD/xfer" total=0 tb=0 lsrc dst nm kb st nover=0
  local -A EXIST=() KB=() XP_DU=() STT=() STF=() STB=() STH=() DTT=() DTF=() DTB=() DTH=()
  local STALG="" DTALG="" XP_TOOLS XP_WRITABLE XP_FREE XP_ERR XV_OK=0 XV_BAD=0 XV_SRC XV_DST
  local launch="${KDASH_LAUNCH_DIR:-$PWD}"
  xfer_glyphs; mkdir -p "$d"
  xfer_browse local pick "UPLOAD ${PC_SEP} 1 SELECT LOCAL FILES" "$ns" "$pod" "$c" "${XFER_BACK:-$launch}"; rc=$?
  XFER_BACK=""
  [ "$rc" = 0 ] || return "$rc"
  lsrc="$XFER_DIR"; local -a items=("${XFER_SEL[@]}") types=("${XFER_SELT[@]}") sizes=("${XFER_SELS[@]}")
  XFER_UPN="${#items[@]} item$([ "${#items[@]}" = 1 ] || echo s)"
  local rdir=""
  while :; do
    xfer_browse remote dir "UPLOAD ${PC_SEP} 2 CHOOSE DESTINATION" "$ns" "$pod" "$c" "$rdir"; rc=$?
    [ "$rc" = 0 ] || return "$rc"
    dst="$XFER_DIR"; rdir="$dst"
    xfer_upload_summary; rc=$?
    [ "$rc" = 4 ] && continue          # d: choose another destination
    [ "$rc" = 0 ] || return "$rc"
    break
  done
  audit CP_UP "pod=$ns/$pod container=${c:--} remote=$(interactive_audit_path "$dst") items=${#items[@]} local=$(interactive_audit_path "$lsrc")"
  printf '\n'
  : > "$d/sent"; : > "$d/err"; local t0=$SECONDS
  XFER_EXPECT="$tb" xfer_run_bg "UPLOADING ${PC_MID} $(xfer_n "${#items[@]}" item) to ${pod}" "$d/sent" -- xfer_up_pipe; rc=$?
  if [ "$rc" = 0 ]; then
    # verify with the algorithm the container has: this host first, then the container
    printf ' %sverifying: checksums here and in the container ...%s' "$PC_D" "$PC_R"
    local alg=none; [[ "$XP_TOOLS" == *" sha256sum "* ]] && alg=sha256; [ "$alg" != none ] || [[ "$XP_TOOLS" != *" md5sum "* ]] || alg=md5
    sh -c "$XFER_SUM_SH" kdash "$alg" "$lsrc" "${items[@]}" > "$d/lsum" 2>/dev/null || true
    xfer_sum_parse "$d/lsum" ST
    "${KC[@]}" -n "$ns" exec "$pod" ${c:+-c "$c"} -- sh -c "$XFER_SUM_SH" kdash "${STALG:-none}" "$dst" "${items[@]}" > "$d/rsum" 2>/dev/null </dev/null || true
    xfer_sum_parse "$d/rsum" DT
    XV_SRC="HERE"; XV_DST="IN CONTAINER"; xfer_verify_table "$d/verify" "${items[@]}"
  fi
  picker_size
  ui_bar "$PK_COLS" " KDASH ${PC_SEP} UPLOAD ${PC_SEP} RESULT ${PC_SEP} ${CTX_NAME:-current} ${PC_SEP} $ns " " audited "
  printf '\033[H\033[2J%s\n\n' "$UI_BAR"
  if [ "$rc" = 0 ]; then
    audit CP_END "pod=$ns/$pod dir=up rc=0 identical=$XV_OK differ=$XV_BAD alg=${STALG:-none}"
    XR_SECS=$((SECONDS - t0))
    local sv=""; for nm in "${items[@]}"; do sv+="${sv:+  $PC_MID  }$nm"; done
    xfer_result_box UPLOAD "$d/verify" SAVED "${PC_B}${pod}${PC_R} ${PC_D}${PC_PTR}${PC_R} ${c:-default} ${PC_D}${PC_PTR}${PC_R} ${PC_B}${dst%/}/${PC_R}   ${sv:0:160}" \
      FROM "${lsrc}   ${PC_D}this host${PC_R}"
  else
    audit CP_END "pod=$ns/$pod dir=up rc=$rc"
    if [ "$rc" = 130 ]; then printf '  %s  files already written in the container stay there\n' "$(xfer_chip warn CANCELLED)"
    else
      printf '  %s  exit status %s\n\n' "$(xfer_chip fail FAILED)" "$rc"
      grep -v '^\s*$' "$d/err" 2>/dev/null | tail -n 6 | inspector_clean | sed 's/^/   /'
      printf '\n %scommon causes%s\n   %s no tar in the image\n   %s destination not writable by the container user (try /tmp)\n   %s RBAC: needs create on pods/exec\n' "$PC_B" "$PC_R" "$PC_MID" "$PC_MID" "$PC_MID"
    fi
  fi
  rm -f "$d/sent"
  printf '\n %s<any key>%s back to kdash ' "$PC_B" "$PC_R"; IFS= read -rsn1 _ </dev/tty || true
  return "$rc"
}

# One entry point for the dashboard and the inspector: S shell, U upload, D download.
interactive_attach() { # shell|up|down ns pod dir [container]
    local action="$1" ns="$2" pod="$3" d="$4" want="${5:-}" rc=0
    case "$action" in
        S|s|shell) action=shell ;; U|u|up) action=up ;; D|d|down) action=down ;;
    esac
    if ! interactive_require "$action"; then
        declare -F flash >/dev/null && flash "$(interactive_hint)" 10
        return 1
    fi
    INTERACTIVE_ACTION="$action"
    if ! interactive_container "$ns" "$pod" "$d" "$want"; then
        declare -F flash >/dev/null && flash "${INTERACTIVE_WHY:-no container chosen for $ns/$pod}" 8
        return 1
    fi
    case "$action" in
        shell) interactive_shell "$ns" "$pod" "$INTERACTIVE_CONTAINER"; rc=$? ;;
        # the file browser; the typed-path dialog only when the container cannot be browsed
        up)    xfer_upload "$ns" "$pod" "$INTERACTIVE_CONTAINER"; rc=$?
               [ "$rc" != 2 ] || { interactive_copy up "$ns" "$pod" "$INTERACTIVE_CONTAINER"; rc=$?; } ;;
        down)  xfer_download "$ns" "$pod" "$INTERACTIVE_CONTAINER"; rc=$?
               [ "$rc" != 2 ] || { interactive_copy down "$ns" "$pod" "$INTERACTIVE_CONTAINER"; rc=$?; } ;;
    esac
    declare -F flash >/dev/null && flash "$action $ns/$pod (container $INTERACTIVE_CONTAINER) ended rc=$rc" 6
    return "$rc"
}

# The container a choice was made for belongs to one pod: KDASH_INSPECT_CONTAINER_POD
# records which ("*" = --container on the command line, valid for any pod that has it).
inspect_container_for() { # ns pod -> remembered container for exactly this pod, or nothing
    case "${KDASH_INSPECT_CONTAINER_POD:-}" in "$1/$2"|"*") printf '%s' "${KDASH_INSPECT_CONTAINER:-}" ;; esac
}

# Which container the action applies to: the wanted / remembered one when this pod
# really has it, the only one, or the picker. The container list is always read
# fresh for THIS pod (it used to be reused from the previously opened pod, so
# kubectl was asked for a container of another pod). Sets INTERACTIVE_CONTAINER.
interactive_container() { # ns pod dir [wanted]
    local ns="$1" pod="$2" d="$3" want="${4:-}" n="" rows
    INTERACTIVE_CONTAINER=""; INTERACTIVE_WHY=""
    # Only --container on the command line (kdsh POD --container NAME) skips the list.
    # A container remembered from the inspector or the last attachment is preselected,
    # but with two or more containers the operator always confirms which one.
    local named=""; [ "${KDASH_INSPECT_CONTAINER_POD:-}" = "*" ] && named="${KDASH_INSPECT_CONTAINER:-}"
    [ -n "$want" ] || want="$(inspect_container_for "$ns" "$pod")"
    mkdir -p "$d" 2>/dev/null
    rows="$d/attach.rows"
    inspector_container_rows "$ns" "$pod" "$rows.spec" "$rows.status" > "$rows" 2> "$rows.err" || true
    # only containers that can be attached to: init containers that finished cannot
    awk -F'\t' 'NF >= 2 && !($1 == "init" && $5 != "Running")' "$rows" > "$rows.live"
    n="$(awk 'END {print NR+0}' "$rows.live")"
    if [ "$n" = 0 ]; then
        INTERACTIVE_WHY="no running container found in $ns/$pod: $(head -c 160 "$rows.err" 2>/dev/null | tr '\n' ' ')"
        return 1
    fi
    if [ -n "$named" ] && awk -F'\t' -v w="$named" '$2 == w {f=1} END {exit !f}' "$rows.live"; then
        INTERACTIVE_CONTAINER="$named"; return 0
    fi
    if [ "$n" = 1 ]; then INTERACTIVE_CONTAINER="$(awk -F'\t' '{print $2; exit}' "$rows.live")"; return 0; fi
    # several: let the operator choose (the picker reads $d/rows)
    cp -f "$rows.live" "$d/rows"; cp -f "$rows.spec" "$d/rows.spec" 2>/dev/null; cp -f "$rows.status" "$d/rows.status" 2>/dev/null
    INSPECTOR_PICK_PRESELECT="$want" INSPECTOR_PICKER_ROWS="$rows.live" INSPECTOR_PICK_PURPOSE="${INTERACTIVE_ACTION:-shell}" \
        inspector_container_picker "$ns" "$pod" "$d" || { INTERACTIVE_WHY="container selection cancelled"; return 1; }
    INTERACTIVE_CONTAINER="$INSPECTOR_CONTAINER"
    # remember it for this pod: preselected next time
    KDASH_INSPECT_CONTAINER="$INSPECTOR_CONTAINER"; KDASH_INSPECT_CONTAINER_POD="$ns/$pod"
    return 0
}

# ---- certificate and login expiry (key C, -v certs, --certs) -------------------
# Read-only. TLS endpoints are checked with an openssl handshake: nothing is sent
# after it. Kubeconfig fields are read locally. CA bundles and cert-manager status
# come from ordinary API reads. Tokens and keys are never printed or written to
# disk; only their expiry, issuer and subject are kept.
# rows.tsv: GROUP WHAT OBJECT WHERE EPOCH STATE NOTE KIND
#   EPOCH is the notAfter / exp time (empty if unknown). STATE is ok when a date was
#   read, otherwise why not (unreachable, no-tls, unreadable, ...).
#   KIND picks the thresholds: cert (days), login (hours), idtoken (renewed on use).
CERT_WARN_DAYS="${KDASH_CERT_WARN_DAYS:-30}"
CERT_CRIT_DAYS="${KDASH_CERT_CRIT_DAYS:-7}"
CERT_RKE2_DIR="${KDASH_RKE2_DATA_DIR:-/var/lib/rancher/rke2}"

certs__row() { # group what object where epoch state note kind
  local IFS=$'\t'
  printf '%s\n' "$*" | LC_ALL=C tr -d '\000-\010\013\014\016-\037\177' >> "$CERTS_ROWS"
}

certs__x509() { # < PEM (first certificate) -> "epoch<TAB>subject CN<TAB>issuer CN"
  local out end sub iss e
  out="$(openssl x509 -noout -enddate -subject -issuer -nameopt RFC2253 2>/dev/null)" || return 1
  end="$(printf '%s\n' "$out" | sed -n 's/^notAfter=//p')"
  sub="$(printf '%s\n' "$out" | sed -n 's/^subject=//p')"; iss="$(printf '%s\n' "$out" | sed -n 's/^issuer=//p')"
  e="$(date -u -d "$end" +%s 2>/dev/null)" || return 1
  printf '%s\t%s\t%s\n' "$e" "$(certs__cn "$sub")" "$(certs__cn "$iss")"
}
certs__cn() { # RFC2253 name -> its CN (or the whole name, shortened)
  local n="$1" cn
  cn="$(printf '%s' "$n" | sed -n 's/.*CN=\([^,]*\).*/\1/p')"
  [ -n "$cn" ] || cn="${n:0:60}"
  printf '%s' "${cn:--}"
}

certs__pem_soonest() { # file with one or more PEM certificates -> certs__x509 line of the soonest
  local f="$1" dir c line best="" be=""
  dir="$(mktemp -d "$CERTS_DIR/pem.XXXXXX")" || return 1
  awk -v d="$dir" '/-----BEGIN CERTIFICATE-----/ { n++; f = d "/" n ".pem" }
                   f != "" { print > f }
                   /-----END CERTIFICATE-----/ { if (f != "") close(f); f = "" }' "$f"
  for c in "$dir"/*.pem; do
    [ -s "$c" ] || continue
    line="$(certs__x509 < "$c")" || continue
    if [ -z "$be" ] || [ "${line%%$'\t'*}" -lt "$be" ]; then best="$line"; be="${line%%$'\t'*}"; fi
  done
  rm -rf "$dir"
  [ -n "$best" ] || return 1
  printf '%s\n' "$best"
}

certs__b64() { # base64 or base64url text on stdin -> bytes (padding added)
  local s; s="$(tr -d ' \n\r' | tr '_-' '/+')"
  case $(( ${#s} % 4 )) in 2) s="$s==" ;; 3) s="$s=" ;; esac
  printf '%s' "$s" | base64 -d 2>/dev/null
}

certs__jwt() { # JWT -> "exp<TAB>iss" (both may be empty; not a JWT -> fails)
  local t="$1" p json exp iss
  case "$t" in *.*.*) ;; *) return 1 ;; esac
  p="${t#*.}"; p="${p%%.*}"
  json="$(printf '%s' "$p" | certs__b64)" || return 1
  exp="$(printf '%s' "$json" | LC_ALL=C grep -o '"exp" *: *[0-9]*' | head -n 1 | LC_ALL=C tr -dc '0-9')"
  iss="$(printf '%s' "$json" | LC_ALL=C grep -o '"iss" *: *"[^"]*"' | head -n 1 | sed 's/.*: *"//; s/"$//')"
  [ -n "$exp$iss" ] || return 1
  printf '%s\t%s\n' "$exp" "$iss"
}

certs__kcfg() { "${KC[@]}" config view --minify --raw -o "jsonpath=$1" 2>/dev/null; }

certs__host() { local u="${1#*://}"; u="${u%%/*}"; printf '%s' "${u:-$1}"; }
certs__hostport() { # https://host:port/path -> "host port"
  local u="${1#*://}" h p
  u="${u%%/*}"; u="${u##*@}"
  case "$u" in
    \[*\]:*) h="${u%%]*}"; h="${h#[}"; p="${u##*]:}" ;;
    \[*\]) h="${u#[}"; h="${h%]}"; p=443 ;;
    *:*) h="${u%:*}"; p="${u##*:}" ;;
    *) h="$u"; p=443 ;;
  esac
  printf '%s %s' "$h" "$p"
}

# where the kubeconfig of this context gets its trust and its identity from
certs__kubeconfig() {
  local server ca cafile cc ccfile tok idt rt cmd args line e iss exp cache f newest="" nf issuer="" a prev=""
  server="$(certs__kcfg '{.clusters[0].cluster.server}')"
  if [ -n "$server" ]; then
    printf 'endpoint\tAPI endpoint\t%s\t%s\tapi\n' "$(certs__hostport "$server")" "$CTX_NAME" >> "$CERTS_DIR/probes"
  fi
  ca="$(certs__kcfg '{.clusters[0].cluster.certificate-authority-data}')"
  cafile="$(certs__kcfg '{.clusters[0].cluster.certificate-authority}')"
  if [ -n "$ca" ]; then printf '%s' "$ca" | certs__b64 > "$CERTS_DIR/ca.pem"
  elif [ -n "$cafile" ] && [ -r "$cafile" ]; then cat -- "$cafile" > "$CERTS_DIR/ca.pem"; fi
  if [ -s "$CERTS_DIR/ca.pem" ]; then
    if line="$(certs__pem_soonest "$CERTS_DIR/ca.pem")"; then
      IFS=$'\t' read -r e a iss <<< "$line"
      certs__row KUBECONFIG "cluster CA (kubeconfig)" "$a" "$CTX_NAME" "$e" ok "issued by $iss" cert
    else certs__row KUBECONFIG "cluster CA (kubeconfig)" - "$CTX_NAME" "" unreadable "not a PEM certificate" cert; fi
  elif [ -n "$cafile" ]; then certs__row KUBECONFIG "cluster CA (kubeconfig)" "$cafile" "$CTX_NAME" "" unreadable "file not readable" cert
  fi
  rm -f "$CERTS_DIR/ca.pem"
  cc="$(certs__kcfg '{.users[0].user.client-certificate-data}')"
  ccfile="$(certs__kcfg '{.users[0].user.client-certificate}')"
  if [ -n "$cc" ] || [ -n "$ccfile" ]; then
    if [ -n "$cc" ]; then printf '%s' "$cc" | certs__b64 > "$CERTS_DIR/cc.pem"; elif [ -r "$ccfile" ]; then cat -- "$ccfile" > "$CERTS_DIR/cc.pem"; fi
    if [ -s "$CERTS_DIR/cc.pem" ] && line="$(certs__pem_soonest "$CERTS_DIR/cc.pem")"; then
      IFS=$'\t' read -r e a iss <<< "$line"
      certs__row KUBECONFIG "client certificate" "$a" "$CTX_NAME" "$e" ok "issued by $iss - kubectl stops working when it expires" cert
    else certs__row KUBECONFIG "client certificate" "${ccfile:--}" "$CTX_NAME" "" unreadable "certificate not readable" cert; fi
    rm -f "$CERTS_DIR/cc.pem"
  fi
  tok="$(certs__kcfg '{.users[0].user.token}')"
  if [ -n "$tok" ]; then
    if line="$(certs__jwt "$tok")"; then IFS=$'\t' read -r exp iss <<< "$line"
      if [ -n "$exp" ]; then certs__row LOGIN "bearer token" "${iss:-token}" "$CTX_NAME" "$exp" ok "a new token is needed after this" login
      else certs__row LOGIN "bearer token" "${iss:-token}" "$CTX_NAME" "" no-expiry "token carries no expiry time" login; fi
    else certs__row LOGIN "bearer token" token "$CTX_NAME" "" no-expiry "not a JWT - lifetime not visible here" login; fi
  fi
  unset tok
  idt="$(certs__kcfg '{.users[0].user.auth-provider.config.id-token}')"
  rt="$(certs__kcfg '{.users[0].user.auth-provider.config.refresh-token}')"
  if [ -n "$idt$rt" ]; then certs__tokens "OIDC" "$idt" "$rt"; fi
  unset idt rt
  cmd="$(certs__kcfg '{.users[0].user.exec.command}')"
  if [ -n "$cmd" ]; then
    args="$(certs__kcfg '{.users[0].user.exec.args[*]}')"
    case "$cmd $args" in
      *oidc-login*|*kubelogin*)
        cache="$HOME/.kube/cache/oidc-login"
        for a in $args; do
          case "$a" in --token-cache-dir=*) cache="${a#*=}" ;; --oidc-issuer-url=*) issuer="${a#*=}" ;; esac
          case "$prev" in --token-cache-dir) cache="$a" ;; --oidc-issuer-url) issuer="$a" ;; esac
          prev="$a"
        done
        cache="${cache/#\~/$HOME}"
        case "$args" in *--token-cache-storage=keyring*|*"--token-cache-storage keyring"*)
          certs__row LOGIN "OIDC login (kubelogin)" "${issuer:-oidc}" "$CTX_NAME" "" keyring "tokens are kept in the OS keyring - lifetime not visible here" login; return 0 ;; esac
        # the newest cache entry for this issuer (the file name is a hash of the login settings)
        for f in "$cache"/*; do
          [ -f "$f" ] && [ -r "$f" ] || continue
          case "$f" in *.lock) continue ;; esac
          idt="$(LC_ALL=C grep -o '"id_token" *: *"[^"]*"' "$f" 2>/dev/null | head -n 1 | sed 's/.*: *"//; s/"$//')"
          [ -n "$idt" ] || continue
          if [ -n "$issuer" ]; then line="$(certs__jwt "$idt")" || continue
            case "${line#*$'\t'}" in "${issuer%/}"|"${issuer%/}/") ;; *) continue ;; esac; fi
          if [ -z "$newest" ] || [ "$f" -nt "$newest" ]; then newest="$f"; fi
        done
        if [ -n "$newest" ]; then
          idt="$(LC_ALL=C grep -o '"id_token" *: *"[^"]*"' "$newest" | head -n 1 | sed 's/.*: *"//; s/"$//')"
          rt="$(LC_ALL=C grep -o '"refresh_token" *: *"[^"]*"' "$newest" | head -n 1 | sed 's/.*: *"//; s/"$//')"
          certs__tokens "OIDC" "$idt" "$rt"
          unset idt rt
        else
          certs__row LOGIN "OIDC login (kubelogin)" "${issuer:-oidc}" "$CTX_NAME" "" not-logged-in "no cached login in ${cache/#$HOME/\~} - the next kubectl call opens a login" login
        fi ;;
      *) certs__row LOGIN "exec credential plugin" "${cmd##*/}" "$CTX_NAME" "" not-visible "the plugin manages the credential - lifetime not visible here" login ;;
    esac
  fi
  return 0
}

certs__tokens() { # label id_token refresh_token
  local label="$1" idt="$2" rt="$3" line exp iss
  if [ -n "$idt" ] && line="$(certs__jwt "$idt")"; then IFS=$'\t' read -r exp iss <<< "$line"
    certs__row LOGIN "$label ID token" "$(certs__host "${iss:-oidc}")" "$CTX_NAME" "$exp" "$([ -n "$exp" ] && echo ok || echo no-expiry)" "short-lived; renewed with the refresh token" idtoken
  fi
  if [ -n "$rt" ]; then
    if line="$(certs__jwt "$rt")" && exp="${line%%$'\t'*}" && [ -n "$exp" ]; then iss="${line#*$'\t'}"
      certs__row LOGIN "$label refresh token" "$(certs__host "${iss:-oidc}")" "$CTX_NAME" "$exp" ok "after this kubectl asks you to log in again" login
    else certs__row LOGIN "$label refresh token" oidc "$CTX_NAME" "" not-visible "opaque token - lifetime set by the identity provider" login; fi
  elif [ -n "$idt" ]; then certs__row LOGIN "$label refresh token" oidc "$CTX_NAME" "" none "no refresh token: a new login is needed when the ID token expires" login
  fi
}

# API reads: CA bundles of webhooks and aggregated APIs, cert-manager certificates,
# nodes (for the per-node TLS endpoints) and ingress TLS host names
certs__api() {
  local mode="$1" e a iss line k n w svc ca tgt ip ips role ver cnt=0 maxn="${KDASH_CERT_MAX_NODES:-60}" maxh="${KDASH_CERT_MAX_HOSTS:-20}"
  health__read cert-webhooks validatingwebhookconfigurations.admissionregistration.k8s.io,mutatingwebhookconfigurations.admissionregistration.k8s.io no \
    '{{range .items}}{{$o := .}}{{range .webhooks}}W|{{$o.kind}}|{{$o.metadata.name}}|{{.name}}|{{with .clientConfig.service}}{{.namespace}}/{{.name}}{{end}}{{with .clientConfig.url}}{{.}}{{end}}|{{.clientConfig.caBundle}}{{"\n"}}{{end}}{{end}}'
  while IFS='|' read -r k a n w svc ca; do
    [ "$k" = W ] || continue
    case "$a" in Validating*) a="webhook CA (validating)" ;; Mutating*) a="webhook CA (mutating)" ;; *) a="webhook CA" ;; esac
    if [ -z "$ca" ] || [ "$ca" = "<no value>" ]; then
      case "$svc" in https://*) printf 'webhook\t%s\t%s\t%s\turl\n' "$a" "$(certs__hostport "$svc")" "$n" >> "$CERTS_DIR/probes" ;;
        *) certs__row WEBHOOKS "$a" "$n" "${svc:--}" "" no-ca "no caBundle: the API server trusts its own roots" cert ;; esac
      continue
    fi
    printf '%s' "$ca" | certs__b64 > "$CERTS_DIR/wh.pem"
    if line="$(certs__pem_soonest "$CERTS_DIR/wh.pem")"; then IFS=$'\t' read -r e iss tgt <<< "$line"
      certs__row WEBHOOKS "$a" "$n" "${svc:--}" "$e" ok "CA $iss - calls fail (x509) once it expires" cert
    else certs__row WEBHOOKS "$a" "$n" "${svc:--}" "" unreadable "caBundle is not a PEM certificate" cert; fi
  done < "$TOOLKIT_DIR/health-cert-webhooks.raw"
  health__read cert-apiservices apiservices.apiregistration.k8s.io no \
    '{{range .items}}{{$o := .}}{{with .spec.service}}A|{{$o.metadata.name}}|{{.namespace}}/{{.name}}|{{$o.spec.caBundle}}|{{$o.spec.insecureSkipTLSVerify}}|{{range $o.status.conditions}}{{if eq .type "Available"}}{{.status}} {{.reason}}{{end}}{{end}}{{"\n"}}{{end}}{{end}}'
  while IFS='|' read -r k n svc ca w a; do
    [ "$k" = A ] || continue
    if [ "$w" = true ]; then certs__row "AGGREGATED APIS" "API service CA" "$n" "$svc" "" skip-verify "insecureSkipTLSVerify - no expiry to check (${a:-status unknown})" cert; continue; fi
    if [ -z "$ca" ] || [ "$ca" = "<no value>" ]; then certs__row "AGGREGATED APIS" "API service CA" "$n" "$svc" "" no-ca "no caBundle (${a:-status unknown})" cert; continue; fi
    printf '%s' "$ca" | certs__b64 > "$CERTS_DIR/as.pem"
    if line="$(certs__pem_soonest "$CERTS_DIR/as.pem")"; then IFS=$'\t' read -r e iss tgt <<< "$line"
      certs__row "AGGREGATED APIS" "API service CA" "$n" "$svc" "$e" ok "CA $iss - Available: ${a:-unknown}" cert
    else certs__row "AGGREGATED APIS" "API service CA" "$n" "$svc" "" unreadable "caBundle is not a PEM certificate" cert; fi
  done < "$TOOLKIT_DIR/health-cert-apiservices.raw"
  rm -f "$CERTS_DIR/wh.pem" "$CERTS_DIR/as.pem"
  health__read cert-manager certificates.cert-manager.io yes \
    '{{range .items}}M|{{.metadata.namespace}}|{{.metadata.name}}|{{.spec.secretName}}|{{.status.notAfter}}|{{.status.renewalTime}}|{{range .status.conditions}}{{if eq .type "Ready"}}{{.status}} {{.reason}}{{end}}{{end}}{{"\n"}}{{end}}'
  [ "$(health__state cert-manager)" != unavailable ] || health__status cert-manager not-installed 'no cert-manager Certificate API in this cluster'
  while IFS='|' read -r k a n w e ren tgt; do
    [ "$k" = M ] || continue
    [ "$e" != "<no value>" ] || e=""; [ "$ren" != "<no value>" ] || ren=""
    line=""; [ -z "$e" ] || line="$(date -u -d "$e" +%s 2>/dev/null)"
    local rn="" re=""; [ -z "$ren" ] || re="$(date -u -d "$ren" +%s 2>/dev/null)"
    if [ -n "$re" ] && [ "$re" -lt "$(date +%s)" ]; then rn="renewal overdue since ${ren%%T*} - check the issuer and its events"
    elif [ -n "$re" ]; then rn="renews ${ren%%T*}"; else rn="no renewal time - check the issuer"; fi
    certs__row CERT-MANAGER "cert-manager certificate" "$a/$n" "secret ${w:--}" "$line" "$([ -n "$line" ] && echo ok || echo not-issued)" "Ready ${tgt:-unknown}; $rn" cert
  done < "$TOOLKIT_DIR/health-cert-manager.raw"
  [ "$mode" = full ] || return 0
  health__read cert-nodes nodes no \
    '{{range .items}}N|{{.metadata.name}}|{{range .status.addresses}}{{if eq .type "InternalIP"}}{{.address}} {{end}}{{end}}|{{if index .metadata.labels "node-role.kubernetes.io/control-plane"}}cp{{else if index .metadata.labels "node-role.kubernetes.io/master"}}cp{{end}}|{{.status.nodeInfo.kubeletVersion}}{{"\n"}}{{end}}'
  CERTS_RKE2=0
  while IFS='|' read -r k n ips role ver; do
    [ "$k" = N ] || continue
    [ "$cnt" -lt "$maxn" ] || { CERTS_NODES_CUT=1; break; }; cnt=$((cnt + 1))
    case "$ver" in *rke2*) CERTS_RKE2=1 ;; esac
    ip="${ips%% *}"; [ -n "$ip" ] || continue
    if [ "$role" = cp ]; then
      printf 'node\tkube-apiserver\t%s 6443\t%s\tnode-api\n' "$ip" "$n" >> "$CERTS_DIR/probes"
      case "$ver" in *rke2*) printf 'node\trke2 supervisor\t%s 9345\t%s\tnode-rke2\n' "$ip" "$n" >> "$CERTS_DIR/probes" ;; esac
    fi
    printf 'node\tkubelet\t%s 10250\t%s\tnode-kubelet\n' "$ip" "$n" >> "$CERTS_DIR/probes"
  done < "$TOOLKIT_DIR/health-cert-nodes.raw"
  health__read cert-ingress ingresses.networking.k8s.io yes \
    '{{range .items}}{{$o := .}}{{range .spec.tls}}{{range .hosts}}T|{{$o.metadata.namespace}}|{{$o.metadata.name}}|{{.}}{{"\n"}}{{end}}{{end}}{{end}}'
  cnt=0
  while IFS='|' read -r k a n w; do
    [ "$k" = T ] || continue
    case "$w" in ''|\**) continue ;; esac
    [ "$cnt" -lt "$maxh" ] || break; cnt=$((cnt + 1))
    printf 'ingress\tingress TLS (%s)\t%s 443\t%s/%s\tingress\n' "$w" "$w" "$a" "$n" >> "$CERTS_DIR/probes"
  done < <(LC_ALL=C sort -u -t '|' -k4,4 "$TOOLKIT_DIR/health-cert-ingress.raw")
  return 0
}

certs__probe_one() { # group what host port object kind out
  local g="$1" what="$2" h="$3" p="$4" obj="$5" kind="$6" out="$7" hp sni=() rc line e sub iss grp note st
  case "$h" in *:*) hp="[$h]:$p" ;; *) hp="$h:$p" ;; esac
  case "$h" in *[!0-9.]*) case "$h" in *:*) ;; *) sni=(-servername "$h") ;; esac ;; esac
  timeout "${KDASH_CERT_TIMEOUT:-4}" openssl s_client -connect "$hp" "${sni[@]}" < /dev/null > "$out.pem" 2> "$out.err"; rc=$?
  case "$kind" in
    api) grp=ENDPOINTS; note="what kubectl connects to" ;;
    node-api) grp=NODES; note="this server's API certificate" ;;
    node-rke2) grp=NODES; note="RKE2 join / supervisor port" ;;
    node-kubelet) grp=NODES; note="logs, exec and metrics go through it" ;;
    ingress) grp=INGRESS; note="what clients of $obj see" ;;
    url) grp=WEBHOOKS; note="webhook URL endpoint" ;;
    *) grp=ENDPOINTS; note="" ;;
  esac
  if line="$(certs__x509 < "$out.pem")"; then
    IFS=$'\t' read -r e sub iss <<< "$line"
    case "$kind" in ingress|url) note="$note; CN $sub" ;; esac
    printf '%s\t%s\t%s\t%s\t%s\tok\t%s\t%s\n' "$grp" "$what" "$obj" "$hp" "$e" "$note; issuer $iss" "$kind" > "$out"
  else
    if [ "$rc" = 124 ]; then st=unreachable; note="no answer in ${KDASH_CERT_TIMEOUT:-4}s from this host"
    elif grep -qiE 'refused|no route|unreachable|Name or service not known|getaddrinfo|resolve' "$out.err"; then st=unreachable; note="$(grep -m1 -oiE 'connection refused|no route to host|network is unreachable|Name or service not known|getaddrinfo[^:]*' "$out.err") from this host"
    else st="no-tls"; note="connected but no certificate was presented"; fi
    printf '%s\t%s\t%s\t%s\t\t%s\t%s\t%s\n' "$grp" "$what" "$obj" "$hp" "$st" "$note" "$kind" > "$out"
  fi
  rm -f "$out.pem" "$out.err"
}

certs__probe_all() {
  local max="${KDASH_CERT_PARALLEL:-8}" n=0 g what hp obj kind h p seen=" "
  [ -s "$CERTS_DIR/probes" ] || { health__status cert-tls unknown 'no TLS endpoint to check'; return 0; }
  command -v openssl >/dev/null 2>&1 || { health__status cert-tls unavailable 'openssl is not installed on this host; TLS endpoints not checked'; return 0; }
  while IFS=$'\t' read -r g what hp obj kind; do
    h="${hp% *}"; p="${hp##* }"
    case "$seen" in *" $h:$p "*) continue ;; esac; seen="$seen$h:$p "
    certs__probe_one "$g" "$what" "$h" "$p" "$obj" "$kind" "$CERTS_DIR/probe.$n" &
    n=$((n + 1)); [ $((n % max)) -ne 0 ] || wait
  done < "$CERTS_DIR/probes"
  wait
  cat "$CERTS_DIR"/probe.* >> "$CERTS_ROWS" 2>/dev/null; rm -f "$CERTS_DIR"/probe.*
  local okn; okn="$(awk -F'\t' '$6 == "ok"' "$CERTS_ROWS" | awk -F'\t' '$8 ~ /^(api|node-|ingress|url)/' | wc -l | tr -d ' ')"
  health__status cert-tls ok "$okn of $n TLS endpoints answered from this host"
}

# This host's own RKE2 certificates, when it is an RKE2 node and kdash may read them
certs__local() {
  local f line e sub iss base n=0
  [ -d "$CERT_RKE2_DIR" ] || return 0
  for f in "$CERT_RKE2_DIR"/server/tls/*.crt "$CERT_RKE2_DIR"/server/tls/etcd/*.crt "$CERT_RKE2_DIR"/agent/*.crt; do
    [ -e "$f" ] || continue
    [ -r "$f" ] || { CERTS_LOCAL_DENIED=1; continue; }
    case "$f" in *-ca.crt|*/ca.crt) base="CA $(basename "$f" .crt)" ;; *) base="$(basename "$f" .crt)" ;; esac
    line="$(certs__pem_soonest "$f")" || continue
    IFS=$'\t' read -r e sub iss <<< "$line"
    certs__row "THIS HOST (RKE2)" "$base" "$sub" "${f#$CERT_RKE2_DIR/}" "$e" ok "issuer $iss" "$(case "$base" in CA*) echo ca ;; *) echo rke2 ;; esac)"
    n=$((n + 1))
  done
  if [ "$n" -gt 0 ]; then health__status cert-host ok "$n certificate files read under $CERT_RKE2_DIR"
  elif [ "${CERTS_LOCAL_DENIED:-0}" = 1 ]; then health__status cert-host forbidden "files under $CERT_RKE2_DIR need root - run: sudo rke2 certificate check --output table"; fi
  return 0
}

certs_collect() { # quick (kubeconfig + API endpoint + CA bundles) | full (adds nodes, ingress, this host)
  local mode="${1:-full}"
  [ -n "${TOOLKIT_DIR:-}" ] || return 1
  CERTS_DIR="$TOOLKIT_DIR/certs-work"; rm -rf "$CERTS_DIR"; mkdir -p "$CERTS_DIR" || return 1
  chmod 700 "$CERTS_DIR" 2>/dev/null
  CERTS_ROWS="$CERTS_DIR/rows.tsv"; : > "$CERTS_ROWS"; : > "$CERTS_DIR/probes"
  CERTS_NODES_CUT=0; CERTS_LOCAL_DENIED=0; CERTS_RKE2=0
  certs__kubeconfig
  health__status cert-kubeconfig ok "context $CTX_NAME read locally (tokens are never shown or stored)"
  certs__api "$mode"
  certs__probe_all
  [ "$mode" != full ] || certs__local
  printf 'mode=%s\nrke2=%s\nnodes_cut=%s\nat=%s\n' "$mode" "${CERTS_RKE2:-0}" "${CERTS_NODES_CUT:-0}" "$(date +%s)" > "$CERTS_DIR/meta"
  rm -rf "$TOOLKIT_DIR/certs"; mv "$CERTS_DIR" "$TOOLKIT_DIR/certs"
  certs_summary > "$TOOLKIT_DIR/certs.summary"
  return 0
}

# rows -> rows with LEFT / STATUS decided (thresholds), sorted soonest first
CERTS_GRADE_AWK='
BEGIN { FS = OFS = "\t" }
function left(s,   d, h, m, a) { a = s < 0 ? -s : s; d = int(a / 86400); h = int(a / 3600); m = int(a / 60)
  t = d >= 2 ? d " d" : h >= 1 ? h " h" : m " min"; return s < 0 ? t " ago" : t }
{ g = $1; what = $2; obj = $3; where = $4; e = $5; st = $6; note = $7; kind = $8
  if (st != "ok" || e == "") {
    lvl = (st ~ /unreachable|not-visible|keyring|no-ca|no-expiry|skip-verify|none|not-logged-in/) ? "{d}" : "{y}"
    s = st; gsub(/-/, " ", s); rank = 4
    if (st == "not-issued") { lvl = "{r}"; s = "NOT ISSUED"; rank = 1 }
    if (st == "not-logged-in") s = "not logged in"
    print rank, "99999999999", lvl s, "-", "-", what, obj, where, note, g, kind; next }
  sec = e - now
  if (kind == "idtoken") { lvl = sec < 0 ? "{d}" : "{g}"; s = sec < 0 ? "renews on use" : "OK"; rank = 3 }
  else if (kind == "login") {
    if (sec < 0) { lvl = "{y}"; s = "LOGIN NEEDED"; rank = 2 } else if (sec < 3600) { lvl = "{y}"; s = "WARNING"; rank = 2 } else { lvl = "{g}"; s = "OK"; rank = 3 } }
  else {
    if (sec < 0) { lvl = "{r}"; s = "EXPIRED"; rank = 0 }
    else if (sec < crit * 86400) { lvl = "{r}"; s = "CRITICAL"; rank = 1 }
    else if (sec < warn * 86400) { lvl = "{y}"; s = "WARNING"; rank = 2 }
    else { lvl = "{g}"; s = "OK"; rank = 3 }
    if ((kind ~ /^node-(api|rke2|kubelet)$/ && rke2 == "1") || kind == "rke2") if (sec >= 0 && sec < 120 * 86400) note = note "; RKE2 renews it on the next service restart" }
  print rank, e, lvl s, left(sec), strftime_(e), what, obj, where, note, g, kind
}
function strftime_(e,   z, era, doe, yoe, y, doy, mp, d, m, sod) {
  z = int(e / 86400) + 719468; era = int(z / 146097); doe = z - era * 146097
  yoe = int((doe - int(doe / 1460) + int(doe / 36524) - int(doe / 146096)) / 365)
  y = yoe + era * 400; doy = doe - (365 * yoe + int(yoe / 4) - int(yoe / 100)); mp = int((5 * doy + 2) / 153)
  d = doy - int((153 * mp + 2) / 5) + 1; m = mp < 10 ? mp + 3 : mp - 9; if (m <= 2) y++
  sod = e % 86400
  return sprintf("%04d-%02d-%02d %02d:%02d", y, m, d, int(sod / 3600), int((sod % 3600) / 60))
}'
certs__graded() {
  [ -s "$TOOLKIT_DIR/certs/rows.tsv" ] || return 0
  LC_ALL=C awk -v now="$(date +%s)" -v warn="$CERT_WARN_DAYS" -v crit="$CERT_CRIT_DAYS" \
    -v rke2="$(sed -n 's/^rke2=//p' "$TOOLKIT_DIR/certs/meta" 2>/dev/null)" "$CERTS_GRADE_AWK" "$TOOLKIT_DIR/certs/rows.tsv" |
    LC_ALL=C sort -t $'\t' -k1,1n -k2,2n | cut -f3-
}

certs_summary() { # one line: "expired N critical N warning N login N soonest WHAT|LEFT"
  certs__graded | awk -F'\t' '
    { s = $1; sub(/^\{.\}/, "", s) }
    s == "EXPIRED" { x++ } s == "CRITICAL" || s == "NOT ISSUED" { c++ } s == "WARNING" { w++ } s == "LOGIN NEEDED" { l++ }
    s ~ /EXPIRED|CRITICAL|WARNING/ && first == "" { first = $4 " (" $5 ")" ; fl = $2 }
    END { printf "expired=%d critical=%d warning=%d login=%d first=%s|%s\n", x, c, w, l, first, fl }'
}

certs_render() {
  local d="$TOOLKIT_DIR/certs" meta mode rke2 cut
  tk_title "CERTIFICATES AND LOGINS" "expiry of the TLS certificates and logins this cluster and your access depend on - TLS handshakes only, nothing is changed"
  if [ ! -d "$d" ]; then
    if [ -n "${TOOLKIT_PID:-}" ]; then printf '\nChecking certificates in the background (TLS handshakes to the API, nodes and ingress hosts)...\n'
    else printf '\nNo certificate check yet.\n'; fi
    return 0
  fi
  mode="$(sed -n 's/^mode=//p' "$d/meta")"; rke2="$(sed -n 's/^rke2=//p' "$d/meta")"; cut="$(sed -n 's/^nodes_cut=//p' "$d/meta")"
  health__sources cert-kubeconfig cert-tls cert-webhooks cert-apiservices cert-manager $([ "$mode" = full ] && printf 'cert-nodes cert-ingress') $([ -f "$TOOLKIT_DIR/health-cert-host.status" ] && printf cert-host)
  local all="$d/graded.tsv" sum
  certs__graded > "$all"
  sum="$(certs_summary)"
  local x c w l
  x="$(printf '%s' "$sum" | sed -n 's/.*expired=\([0-9]*\).*/\1/p')"; c="$(printf '%s' "$sum" | sed -n 's/.*critical=\([0-9]*\).*/\1/p')"
  w="$(printf '%s' "$sum" | sed -n 's/.*warning=\([0-9]*\).*/\1/p')"; l="$(printf '%s' "$sum" | sed -n 's/.*login=\([0-9]*\).*/\1/p')"
  { printf 'STATUS*\t>LEFT\tEXPIRES UTC\tWHAT\tOBJECT\tWHERE\tNOTE~\n'
    awk -F'\t' '$3 != "-"' "$all" | cut -f1-7
  } | tk_table "EXPIRY" "soonest first - warning under $CERT_WARN_DAYS days, critical under $CERT_CRIT_DAYS days (KDASH_CERT_WARN_DAYS / KDASH_CERT_CRIT_DAYS)" \
      "$(awk -F'\t' '$3 == "-" { f = 1 } END { exit !f }' "$all" && printf 'no expiry dates could be read - see NOT CHECKED below' || printf 'nothing to check: no TLS endpoint, client certificate, token or CA bundle was found')" item items
  { awk -F'\t' -v host="$(hostname -s 2>/dev/null || hostname)" '
      function hint(   o, a) {
        if ($9 ~ /^node-/) return "cert-node||" $5 "|" (($5 in SRV) ? "server" : "agent")
        if ($9 == "rke2") return "cert-rke2file||" host "|server"
        if ($9 == "ca") return "cert-ca||" host
        if ($9 == "api" || $9 == "url") return "cert-endpoint|||" $6
        if ($8 == "KUBECONFIG") return "cert-kubeconfig-ca"
        if ($8 == "WEBHOOKS") return "cert-webhook||" $5 "|" $6 "|" ($4 ~ /mutating/ ? "mutatingwebhookconfiguration" : "validatingwebhookconfiguration")
        if ($8 == "AGGREGATED APIS") return "cert-apiservice||" $5 "|" $6
        o = $5; split(o, a, "/")
        if ($8 == "CERT-MANAGER") return "cert-manager|" a[1] "|" a[2]
        if ($8 == "INGRESS") return "cert-ingress|" a[1] "|" a[2]
        if ($8 == "LOGIN") return "login"
        return "" }
      NR == FNR { if ($9 == "node-api" || $9 == "node-rke2") SRV[$5] = 1; next }
      { s = $1; sub(/^\{.\}/, "", s) }
      s == "EXPIRED"  { printf "{r}CRITICAL\t%s\t%s expired %s - TLS to it fails now\t%s\n", $5, $4, $2, hint() }
      s == "CRITICAL" { printf "{r}CRITICAL\t%s\t%s expires in %s (%s UTC)\t%s\n", $5, $4, $2, $3, hint() }
      s == "WARNING"  { printf "{y}WARNING\t%s\t%s expires in %s (%s UTC)\t%s\n", $5, $4, $2, $3, hint() }
      s == "LOGIN NEEDED" { printf "{y}WARNING\t%s\t%s expired %s - the next kubectl call asks you to log in\t%s\n", $5, $4, $2, hint() }
      s == "NOT ISSUED" { printf "{r}CRITICAL\t%s\t%s has no issued certificate (%s)\t%s\n", $5, $4, $7, hint() }
      $7 ~ /renewal overdue/ && s != "EXPIRED" && s != "CRITICAL" { printf "{y}WARNING\t%s\t%s: %s\t%s\n", $5, $4, substr($7, index($7, "renewal overdue")), hint() }' "$all" "$all"
    if [ -s "$TOOLKIT_DIR/events.tsv" ]; then
      awk -F'\t' 'tolower($10) ~ /x509: certificate has expired|certificate has expired or is not yet valid|x509: certificate signed by unknown authority/ {
        k = $2 "/" $3; if (k in S) next; S[k] = 1; m = $10; gsub(/\t/, " ", m); if (length(m) > 110) m = substr(m, 1, 107) "..."
        printf "{r}CRITICAL\t%s\tevent %s: %s\tevent-x509|%s|%s|%s\n", ($1 != "" ? $1 "/" : "") $3, $6, m, $1, $3, tolower($2) }' "$TOOLKIT_DIR/events.tsv"
    fi
  } | rb_findings "FINDINGS" "critical first; includes x509 errors in Kubernetes events - next commands below" "nothing expires within $CERT_WARN_DAYS days"
  if awk -F'\t' '$3 == "-" { f = 1 } END { exit !f }' "$all"; then
    { printf 'STATE*\tWHAT\tOBJECT\tWHERE\tWHY~\n'
      awk -F'\t' 'BEGIN { OFS = "\t" } $3 == "-" { print $1, $4, $5, $6, $7 }' "$all"
    } | tk_table "NOT CHECKED" "no expiry date could be read for these from this host" "" item items
  fi
  printf '\n'
  { [ "$rke2" = 1 ] || [ -d "$CERT_RKE2_DIR" ]; } &&
    tk_note "RKE2 renews certificates with under 120 days left whenever the service starts; a node that never restarts can expire silently. Full procedure: R (runbook cert-rotate)."
  [ "$cut" != 1 ] || tk_note "only the first ${KDASH_CERT_MAX_NODES:-60} nodes were probed (KDASH_CERT_MAX_NODES)"
  [ "$mode" = full ] || tk_note "quick check: nodes, ingress hosts and this host were not probed (open key C or run --certs for all)"
  return 0
}

certs_exit_code() { # 0 nothing within the warning window, 1 warning / login, 2 critical or expired
  local s; s="$(cat "$TOOLKIT_DIR/certs.summary" 2>/dev/null)"
  case "$s" in *expired=[1-9]*|*critical=[1-9]*) return 2 ;; *warning=[1-9]*|*login=[1-9]*) return 1 ;; esac
  return 0
}

certs_age() { # seconds since the last full check (a large number when there is none)
  local at mode
  mode="$(sed -n 's/^mode=//p' "${TOOLKIT_DIR:-/nonexistent}/certs/meta" 2>/dev/null)"
  at="$(sed -n 's/^at=//p' "${TOOLKIT_DIR:-/nonexistent}/certs/meta" 2>/dev/null)"
  case "$mode:$at" in full:[0-9]*) printf '%s' "$(( $(date +%s) - at ))" ;; *) printf 999999 ;; esac
}

certs_badge() { # summary line -> short text for the header ("" when nothing is due)
  local s="$1" x c w l t=""
  x="$(printf '%s' "$s" | sed -n 's/.*expired=\([0-9]*\).*/\1/p')"; c="$(printf '%s' "$s" | sed -n 's/.*critical=\([0-9]*\).*/\1/p')"
  w="$(printf '%s' "$s" | sed -n 's/.*warning=\([0-9]*\).*/\1/p')"; l="$(printf '%s' "$s" | sed -n 's/.*login=\([0-9]*\).*/\1/p')"
  [ "${x:-0}" = 0 ] || t="$t${t:+, }$x EXPIRED"
  [ "${c:-0}" = 0 ] || t="$t${t:+, }$c critical"
  [ "${w:-0}" = 0 ] || t="$t${t:+, }$w expiring"
  [ "${l:-0}" = 0 ] || t="$t${t:+, }login needed"
  printf '%s' "$t"
}

# A quick check (kubeconfig, API endpoint, CA bundles) in the background at start and
# then hourly; it only sets the header badge and flashes once when something is due.
certs_quick_poll() {
  [ "${KDASH_CERT_CHECK:-1}" = 1 ] || return 0
  local now; now=$(date +%s)
  if [ -n "${CERTQ_PID:-}" ] && ! kill -0 "$CERTQ_PID" 2>/dev/null; then
    wait "$CERTQ_PID" 2>/dev/null || true; CERTQ_PID=""; CERTQ_NEXT=$((now + 3600))
    CERT_BADGE="$(certs_badge "$(cat "$TMPD/certq/certs.summary" 2>/dev/null)")"
  fi
  # once per session, and never over another message (it waits until that one ends)
  if [ -n "${CERT_BADGE:-}" ] && [ "${CERTQ_FLASHED:-0}" = 0 ] && [ -s "$TMPD/certq/certs.summary" ] && [ "$now" -ge "${FLASH_UNTIL:-0}" ]; then
    local sum first; sum="$(cat "$TMPD/certq/certs.summary")"; CERTQ_FLASHED=1
    first="${sum##*first=}"; first="${first%%|*}"
    declare -F flash >/dev/null && flash "certificates: $CERT_BADGE${first:+ - soonest: $first} - press C for details" 12
    audit CERTS_WARNING "$sum"
  fi
  # a full check (key C) is newer and more complete: it decides the badge
  if [ -s "${TOOLKIT_DIR:-}/certs.summary" ]; then CERT_BADGE="$(certs_badge "$(cat "$TOOLKIT_DIR/certs.summary")")"; fi
  if [ -z "${CERTQ_PID:-}" ] && [ "$now" -ge "${CERTQ_NEXT:-0}" ] && [ "${LOGIN_NEEDED:-0}" != 1 ]; then
    ( trap - EXIT INT TERM HUP; TOOLKIT_DIR="$TMPD/certq"; rm -rf "$TOOLKIT_DIR"; mkdir -p "$TOOLKIT_DIR"
      certs_collect quick ) > /dev/null 2>&1 &
    CERTQ_PID=$!; CERTQ_NEXT=$((now + 300))
  fi
  return 0
}

# ---- runbook hints (next commands per finding) and runbooks (key R, --runbook) ---
# kdash never runs any of these commands: it prints them, with the context, namespace
# and object names filled in. "read" lines only read; "CHANGE" lines modify the cluster
# or a node and are for the operator to decide on.
RB_TOPICS="etcd-restore cert-rotate node-notready api-unreachable oidc-login"
RB_DATA="${KDASH_RKE2_DATA_DIR:-/var/lib/rancher/rke2}"

rb_q() { # shell-quote one word only when it needs it
  case "$1" in ''|*[!A-Za-z0-9._/:=@%+,-]*) printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")" ;; *) printf '%s' "$1" ;; esac
}
rb_k() { # kubectl prefix [-n ns] words...
  local ns="$1"; shift
  printf '%s' "${RB_K:-kubectl}"
  [ -z "$ns" ] || printf ' -n %s' "$(rb_q "$ns")"
  local w; for w in "$@"; do printf ' %s' "$w"; done
}
rb_line() { # kind (read|CHANGE|note) command [comment] [where]
  local kind="$1" cmd="$2" why="${3:-}" where="${4:-}" tag
  # instant checks: remember the read commands of the current finding (run with Enter / --run N)
  [ -z "${RB_CAPTURE:-}" ] || [ "$kind" != read ] || [ -n "$where" ] || printf '%s\t%s\n' "${RB_CUR_N:--}" "$cmd" >> "$RB_CAPTURE"
  [ -z "$RB_SEEN_FILE" ] || { if [ "$kind" != note ] && grep -qxF -- "$where$cmd" "$RB_SEEN_FILE" 2>/dev/null; then return 0; fi; printf '%s\n' "$where$cmd" >> "$RB_SEEN_FILE"; }
  if [ "${TK_COLOR:-0}" = 1 ]; then
    case "$kind" in read) tag='~[32mread  ~[0m' ;; CHANGE) tag='~[1;33mCHANGE~[0m' ;; *) tag='~[90mnote  ~[0m' ;; esac
    [ -z "$where" ] || where="~[36m[on $where]~[0m "
    if [ "$kind" = note ]; then printf '      %s ~[90m%s~[0m\n' "$tag" "$cmd"
    else printf '      %s %s%s%s\n' "$tag" "$where" "$cmd" "${why:+  ~[90m# $why~[0m}"; fi
  else
    case "$kind" in read) tag='read  ' ;; CHANGE) tag='CHANGE' ;; *) tag='note  ' ;; esac
    [ -z "$where" ] || where="[on $where] "
    printf '      %s %s%s%s\n' "$tag" "$where" "$cmd" "${why:+  # $why}"
  fi
}
rb_head() { # " #n  severity  object - text"
  local num="#$1"; [ -n "$1" ] || num="> "
  if [ "${TK_COLOR:-0}" = 1 ]; then printf '\n  ~[1m%s~[0m  %s  ~[1m%s~[0m  ~[90m%s~[0m\n' "$num" "$2" "$3" "$4"
  else printf '\n  %s  %s  %s  %s\n' "$num" "$2" "$3" "$4"; fi
}

# The catalogue: key ns name [extra...] -> read / CHANGE / note lines
rb_hints() {
  local key="$1" ns="${2:-}" name="${3:-}" x1="${4:-}" x2="${5:-}" x3="${6:-}" n; n="$(rb_q "$name")"
  case "$key" in
    svc-nomatch)
      rb_line read "$(rb_k "$ns" get service "$n" -o "jsonpath='{.spec.selector}{\"\\n\"}'")" "what the Service selects"
      rb_line read "$(rb_k "$ns" get pods --show-labels)" "labels the pods really have"
      rb_line CHANGE "$(rb_k "$ns" edit service "$n")" "make spec.selector match the pod labels (or fix the labels on the workload)" ;;
    svc-notready)
      rb_line read "$(rb_k "$ns" get pods -l "$(rb_q "$x1")" -o wide)" "the selected pods and their nodes"
      rb_line read "$(rb_k "$ns" describe pods -l "$(rb_q "$x1")")" "readiness probe failures and events"
      rb_line read "$(rb_k "$ns" logs -l "$(rb_q "$x1")" --all-containers --tail=50 --prefix)" "why the application is not ready"
      rb_line note "kdash: i, pick a backend pod, then l (logs) or ! (why) for the same evidence" ;;
    svc-port)
      rb_line read "$(rb_k "$ns" get service "$n" -o "jsonpath='{range .spec.ports[*]}{.name} {.port} -> {.targetPort}{\"\\n\"}{end}'")" "the Service ports"
      rb_line read "$(rb_k "$ns" get pods -l "$(rb_q "$x1")" -o "jsonpath='{range .items[0].spec.containers[*].ports[*]}{.name} {.containerPort}{\"\\n\"}{end}'")" "the port names the pods declare"
      rb_line CHANGE "$(rb_k "$ns" edit service "$n")" "set targetPort to a declared container port name or number" ;;
    svc-noendpoints)
      rb_line read "$(rb_k "$ns" get endpointslices -l "kubernetes.io/service-name=$n" -o wide)" "EndpointSlices of the Service"
      rb_line read "$(rb_k kube-system get pods -o wide) | grep controller-manager" "EndpointSlices are written by kube-controller-manager" ;;
    svc-manual)
      rb_line read "$(rb_k "$ns" get endpointslices -l "kubernetes.io/service-name=$n" -o wide)" "manually managed backends" ;;
    ing-svcmissing)
      rb_line read "$(rb_k "$ns" get ingress "$n" -o "jsonpath='{range .spec.rules[*].http.paths[*]}{.path} -> {.backend.service.name}:{.backend.service.port.number}{.backend.service.port.name}{\"\\n\"}{end}'")" "the routes and their backends"
      rb_line read "$(rb_k "$ns" get services)" "Services that exist"
      rb_line CHANGE "$(rb_k "$ns" edit ingress "$n")" "point the backend at an existing Service (or deploy the missing one)" ;;
    ing-port)
      rb_line read "$(rb_k "$ns" get service "$(rb_q "$x1")" -o "jsonpath='{range .spec.ports[*]}{.name} {.port}{\"\\n\"}{end}'")" "ports Service $x1 offers"
      rb_line CHANGE "$(rb_k "$ns" edit ingress "$n")" "use one of those port names or numbers in the backend" ;;
    pvc-full)
      rb_line read "$(rb_k "" get storageclass "$(rb_q "$x1")" -o "jsonpath='{.allowVolumeExpansion}{\"\\n\"}'")" "true = the claim can be expanded online"
      [ -z "$x3" ] || rb_line read "$(rb_k "$ns" exec "$(rb_q "$x3")" -- df -h)" "what is using the space (needs exec rights)"
      rb_line CHANGE "$(rb_k "$ns" patch pvc "$n" -p "'{\"spec\":{\"resources\":{\"requests\":{\"storage\":\"${x2:-<NEW-SIZE>}\"}}}}'")" "grow the volume (only when the class allows expansion; it cannot shrink)" ;;
    pvc-pending)
      rb_line read "$(rb_k "$ns" describe pvc "$n")" "the provisioner's reason is in the events"
      [ -z "$x1" ] || rb_line read "$(rb_k "" get storageclass "$(rb_q "$x1")" -o wide)" "provisioner and binding mode"
      [ "$x2" != wffc ] || rb_line note "WaitForFirstConsumer: the claim binds when a pod that uses it is scheduled - check that pod (i in kdash)" ;;
    pvc-lost)
      rb_line read "$(rb_k "$ns" describe pvc "$n")" "which volume it pointed to"
      rb_line read "$(rb_k "$ns" get volumesnapshots) 2>/dev/null" "snapshots you could restore from (if VolumeSnapshots are used)"
      rb_line note "the data is gone from the cluster: restore it from your backup (VolumeSnapshot, Velero or the application's own backup) into a new claim" ;;
    pv-missing|pv-claimref)
      rb_line read "$(rb_k "$ns" get pvc "$n" -o "jsonpath='{.spec.volumeName}{\"\\n\"}'")" "the volume the claim expects"
      [ -z "$x1" ] || rb_line read "$(rb_k "" get pv "$(rb_q "$x1")" -o yaml)" "its claimRef and phase (cluster-scoped read)" ;;
    sc-missing)
      rb_line read "$(rb_k "" get storageclass)" "classes that exist"
      rb_line note "storageClassName cannot be changed on an existing claim: create the class $x1, or recreate the claim with an existing class" ;;
    pvc-unused)
      rb_line read "$(rb_k "$ns" get pvc "$n" -o wide)" "kept on purpose? the data stays while the claim exists" ;;
    pvc-condition)
      rb_line read "$(rb_k "$ns" describe pvc "$n")" "the condition's message"
      case "$x1" in *FileSystemResizePending*) rb_line note "FileSystemResizePending finishes when a pod mounting the claim (re)starts - restart that pod's workload at a quiet time" ;; esac ;;
    pod-claimmissing)
      rb_line read "$(rb_k "$ns" get pod "$n" -o "jsonpath='{range .spec.volumes[*]}{.name} {.persistentVolumeClaim.claimName}{\"\\n\"}{end}'")" "claims the pod expects"
      rb_line CHANGE "create the claim $x1 in $ns (from the workload's chart or manifest)" "the pod stays Pending until it exists" ;;
    pv-released)
      rb_line read "$(rb_k "" get pv "$n" -o yaml)" "the retained data and its old claimRef"
      rb_line CHANGE "$(rb_k "" patch pv "$n" --type json -p "'[{\"op\":\"remove\",\"path\":\"/spec/claimRef\"}]'")" "only to reuse the data: makes the volume Available to a new claim" ;;
    cert-node|cert-rke2file)
      rb_line read "sudo rke2 certificate check --output table" "every certificate on that node with its expiry" "$name"
      if [ "$x1" = server ]; then
        rb_line CHANGE "sudo systemctl stop rke2-server && sudo rke2 certificate rotate && sudo systemctl start rke2-server" "one server at a time; wait for Ready before the next" "$name"
      else
        rb_line CHANGE "sudo systemctl restart rke2-agent" "an agent renews its certificates (under 120 days left) when it starts" "$name"
      fi
      rb_line note "full procedure: kdash --runbook cert-rotate  (or R in kdash)" ;;
    cert-endpoint)
      rb_line read "openssl s_client -connect $(rb_q "$x1") </dev/null 2>/dev/null | openssl x509 -noout -subject -enddate" "what this endpoint presents now"
      rb_line note "the API endpoint is served by the RKE2 servers (or a load balancer in front of them): renew there - kdash --runbook cert-rotate" ;;
    cert-ca)
      rb_line read "sudo rke2 certificate check --output table | grep -i ' ca'" "the CA certificates on a server" "$name"
      rb_line note "a CA is not renewed by rke2 certificate rotate - plan a CA rotation (rke2 certificate rotate-ca) from the RKE2 documentation; never improvise it" ;;
    cert-kubeconfig-ca)
      rb_line read "$(rb_k "" config view --minify --raw -o "jsonpath='{.clusters[0].cluster.certificate-authority-data}'") | base64 -d | openssl x509 -noout -subject -enddate" "the CA your kubeconfig trusts"
      rb_line note "after a CA rotation, refresh the kubeconfig from your access portal / cluster admin" ;;
    cert-webhook)
      rb_line read "$(rb_k "" get "$x2" "$n" -o "jsonpath='{range .webhooks[*]}{.name} {.clientConfig.service.namespace}/{.clientConfig.service.name}{\"\\n\"}{end}'")" "which service serves the webhook"
      rb_line read "$(rb_k "" get certificates.cert-manager.io -A) 2>/dev/null | grep -i ${x1%%/*}" "is the webhook certificate cert-manager managed?"
      rb_line note "renew the webhook's serving certificate with its owner (operator, Helm chart or cert-manager cainjector) - the caBundle must be updated with it; until then calls fail with x509 errors" ;;
    cert-apiservice)
      rb_line read "$(rb_k "" get apiservice "$n" -o wide)" "Available condition"
      rb_line read "$(rb_k "${x1%%/*}" get pods -o wide)" "the pods behind ${x1}"
      rb_line note "redeploy or renew the serving certificate of $x1 (its chart usually regenerates it)" ;;
    cert-manager)
      rb_line read "$(rb_k "$ns" describe certificate "$n")" "status, conditions and the last failure"
      rb_line read "$(rb_k "$ns" get certificaterequests,orders.acme.cert-manager.io,challenges.acme.cert-manager.io) 2>/dev/null" "where issuance is stuck"
      rb_line read "$(rb_k "" get clusterissuers,issuers -A -o wide)" "is the issuer Ready?"
      rb_line CHANGE "cmctl renew -n $(rb_q "$ns") $n" "trigger a renewal once the issuer works (or: kubectl cert-manager renew)" ;;
    cert-ingress)
      rb_line read "$(rb_k "$ns" get ingress "$n" -o "jsonpath='{range .spec.tls[*]}{.secretName}: {.hosts}{\"\\n\"}{end}'")" "which secret holds the certificate"
      rb_line read "$(rb_k "$ns" get certificates.cert-manager.io) 2>/dev/null" "cert-manager managed?"
      rb_line note "renew the TLS secret (cert-manager, or replace it: kubectl create secret tls NAME --cert=... --key=... --dry-run=client -o yaml | kubectl apply -f -); the ingress controller reloads it" ;;
    login)
      rb_line read "$(rb_k "" auth whoami)" "any API call opens a new OIDC login when the refresh token has expired"
      rb_line CHANGE "kubectl oidc-login clean" "clears cached tokens if a login keeps failing (you log in again)"
      rb_line note "full procedure: kdash --runbook oidc-login" ;;
    event-x509)
      rb_line read "$(rb_k "$ns" describe "$(rb_q "$x1")" "$n")" "the object behind the x509 error"
      rb_line note "an expired webhook, aggregated API or registry certificate is the usual cause - see the CERTIFICATES rows above" ;;
    *) check_hints "$@"; return $? ;;
  esac
  return 0
}

# FINDINGS (numbered) followed by NEXT COMMANDS for every finding that has hints.
# stdin rows: SEVERITY OBJECT FINDING HINTKEY (HINTKEY = key|ns|name|extra|extra|extra)
rb_findings() { # title subtitle empty-text
  local title="$1" sub="$2" empty="$3" tmp n sev obj text hk key ns name x1 x2 x3 shown=0 max="${KDASH_HINT_MAX:-15}"
  tmp="$(mktemp "${TOOLKIT_DIR:-${TMPDIR:-/tmp}}/rbf.XXXXXX")" || return 1
  tk_by_severity | awk -F'\t' 'BEGIN { OFS = "\t" } { print NR, $0 }' > "$tmp"
  # the instant check (key K) gathers every view's findings through here
  [ -z "${RB_COLLECT_FINDINGS:-}" ] || awk -F'\t' -v a="${RB_AREA:-}" 'BEGIN { OFS = "\t" } { $1 = a; print }' "$tmp" >> "$RB_COLLECT_FINDINGS"
  [ -z "${RB_COLLECT_FINDINGS:-}" ] || { rm -f "$tmp"; return 0; }
  { printf '#\tSEVERITY*\tOBJECT\tFINDING\n'; cut -f1-4 "$tmp"; } | tk_table "$title" "$sub" "$empty" finding findings
  rb_next_list "$tmp"
  rm -f "$tmp"
  return 0
}
rb_next_list() { # numbered rows: N SEVERITY OBJECT FINDING HINTKEY
  local tmp="$1" n sev obj text hk key ns name x1 x2 x3 shown=0 max="${KDASH_HINT_MAX:-15}"
  awk -F'\t' '$5 != "" && $2 !~ /INFO/ { f = 1 } END { exit !f }' "$tmp" || return 0
  RB_K="$(events_kubectl_prefix)"; RB_SEEN_FILE="$tmp.seen"; : > "$RB_SEEN_FILE"
  printf '\n'
  if [ "${TK_COLOR:-0}" = 1 ]; then printf '~[1mNEXT COMMANDS~[0m  ~[90mread = only reads, CHANGE = modifies the cluster or a node (printed only)%s~[0m\n' "${RB_RUN_HINT:+  -  $RB_RUN_HINT}"
  else printf 'NEXT COMMANDS  -  read = only reads, CHANGE = modifies the cluster or a node (printed only)%s\n' "${RB_RUN_HINT:+  -  $RB_RUN_HINT}"; fi
  while IFS=$'\t' read -r n sev obj text hk; do
    [ -n "$hk" ] || continue
    case "$sev" in *INFO*) continue ;; esac
    [ "$shown" -lt "$max" ] || { tk_note "... hints for the remaining findings are left out (KDASH_HINT_MAX=$max)"; break; }
    IFS='|' read -r key ns name x1 x2 x3 <<< "$hk"
    RB_CUR_N="$n"
    rb_head "$n" "${sev#\{?\}}" "$obj" "$(printf '%s' "$text" | cut -c1-90)"
    local first; first="$(awk -F'\t' -v k="$key|$ns|$name" '$1 == k { print $2; exit }' "$tmp.keys" 2>/dev/null)"
    if [ -n "$first" ]; then rb_line note "same object as #$first - the commands listed there apply"
      [ -z "${RB_CAPTURE:-}" ] || printf '@%s\t%s\n' "$n" "$first" >> "$RB_CAPTURE"
    else printf '%s\t%s\n' "$key|$ns|$name" "$n" >> "$tmp.keys"
      rb_hints "$key" "$ns" "$name" "$x1" "$x2" "$x3" || rb_line note "no specific hint - describe the object and read its events"; fi
    shown=$((shown + 1))
  done < "$tmp"
  printf '\n'
  rm -f "$tmp.seen" "$tmp.keys"; RB_SEEN_FILE=""; RB_CUR_N=""
  return 0
}

# ---- runbooks -----------------------------------------------------------------
rb_collect() { # API reads the runbooks fill their commands from (all optional)
  health__read rb-snapshots etcdsnapshotfiles.k3s.cattle.io no \
    '{{range .items}}E|{{.metadata.name}}|{{.spec.snapshotName}}|{{.spec.nodeName}}|{{.spec.location}}|{{.status.size}}|{{.status.creationTime}}|{{.status.readyToUse}}|{{with .spec.s3}}{{.bucket}}|{{.endpoint}}|{{.region}}|{{.prefix}}{{else}}|||{{end}}|{{with .status.error}}{{.message}}{{end}}{{"\n"}}{{end}}'
  health__read rb-nodes nodes no \
    '{{range .items}}N|{{.metadata.name}}|{{range .status.addresses}}{{if eq .type "InternalIP"}}{{.address}} {{end}}{{end}}|{{if index .metadata.labels "node-role.kubernetes.io/control-plane"}}server{{else if index .metadata.labels "node-role.kubernetes.io/master"}}server{{else}}agent{{end}}|{{.status.nodeInfo.kubeletVersion}}|{{range .status.conditions}}{{if eq .type "Ready"}}{{.status}}|{{.reason}}|{{.lastTransitionTime}}{{end}}{{end}}|{{if .spec.unschedulable}}cordoned{{end}}{{"\n"}}{{end}}'
  printf '%s\n' "$(certs__kcfg '{.clusters[0].cluster.server}' 2>/dev/null)" > "$TOOLKIT_DIR/rb-server.txt"
  date +%s > "$TOOLKIT_DIR/rb.at"
}
rb_age() { local at; at="$(cat "${TOOLKIT_DIR:-/nonexistent}/rb.at" 2>/dev/null)"; case "$at" in [0-9]*) printf '%s' "$(( $(date +%s) - at ))" ;; *) printf 999999 ;; esac; }

rb_step() { # number title
  if [ "${TK_COLOR:-0}" = 1 ]; then printf '\n  ~[1mSTEP %s~[0m  %s\n' "$1" "$2"; else printf '\n  STEP %s  %s\n' "$1" "$2"; fi
}
rb_section() { # title text
  if [ "${TK_COLOR:-0}" = 1 ]; then printf '\n~[1;4m%s~[0m  ~[90m%s~[0m\n' "$1" "$2"; else printf '\n%s  -  %s\n' "$1" "$2"; fi
}
rb_warn() {
  if [ "${TK_COLOR:-0}" = 1 ]; then printf '  ~[1;31m!~[0m ~[1m%s~[0m\n' "$*"; else printf '  ! %s\n' "$*"; fi
}

rb_render() { # [topic]
  local topic="${1:-${RB_TOPIC:-etcd-restore}}" t i=0 bar=""
  case " $RB_TOPICS " in *" $topic "*) ;; *) topic=etcd-restore ;; esac
  RB_K="$(events_kubectl_prefix)"; RB_SEEN_FILE=""
  tk_title "RUNBOOK - $topic" "printed procedures with your cluster's names filled in - kdash never runs them"
  for t in $RB_TOPICS; do i=$((i + 1))
    if [ "$t" = "$topic" ]; then bar="$bar  [$i $t]"; else bar="$bar   $i $t "; fi; done
  if [ "${TK_COLOR:-0}" = 1 ]; then printf '~[90mrunbooks:~[0m%s   ~[90m[ ] previous / next   (kdash --runbook NAME)~[0m\n' "$bar"
  else printf 'runbooks:%s   [ ] previous / next   (kdash --runbook NAME)\n' "$bar"; fi
  [ -f "$TOOLKIT_DIR/rb.at" ] || { printf '\nReading snapshots and nodes in the background...\n'; return 0; }
  case "$topic" in
    etcd-restore) rb_etcd_restore ;; cert-rotate) rb_cert_rotate ;; node-notready) rb_node_notready ;;
    api-unreachable) rb_api_unreachable ;; oidc-login) rb_oidc_login ;;
  esac
  return 0
}

rb__servers() { # -> "name<TAB>ip" lines of the control-plane nodes, sorted
  awk -F'|' '$1 == "N" && $4 == "server" { ip = $3; sub(/ .*/, "", ip); print $2 "\t" ip }' "$TOOLKIT_DIR/health-rb-nodes.raw" 2>/dev/null | LC_ALL=C sort
}

rb_etcd_restore() {
  local snaps="$TOOLKIT_DIR/rb-snaps.tsv" ss sn path="" node="" name="" s3b="" s3e="" s3r="" s3p="" created="" s1="" others="" all="" n cnt
  ss="$(health__state rb-snapshots)"; sn="$(health__state rb-nodes)"
  # snapshots, newest first: NAME NODE WHERE SIZE CREATED AGE READY
  LC_ALL=C awk -F'|' -v now="$(date +%s)" "$TK_TIME_AWK"'
    BEGIN { NOW = now; OFS = "\t" }
    $1 == "E" { loc = $5; where = (loc ~ /^s3:/ || $9 != "") ? "S3 " $9 : "local"
      r = ($8 == "true") ? "{g}yes" : ($13 != "" ? "{r}no: " $13 : "{y}" ($8 == "" ? "unknown" : $8))
      print $7, $3, $4, where, size($6), $7, ago($7), r, loc, $9, $10, $11, $12 }
    function size(s,   n, u, i) { if (s == "") return "-"; if (s !~ /^[0-9]+$/) return s
      n = s + 0; split("B KiB MiB GiB TiB", u, " "); i = 1; while (n >= 1024 && i < 5) { n /= 1024; i++ }
      return sprintf("%.1f %s", n, u[i]) }
  ' "$TOOLKIT_DIR/health-rb-snapshots.raw" 2>/dev/null | LC_ALL=C sort -r | cut -f2- > "$snaps"
  cnt="$(wc -l < "$snaps" | tr -d ' ')"
  rb_section "WHEN TO USE" "etcd data is lost or corrupted, or the cluster must go back to a known state"
  rb_warn "A restore rolls the WHOLE cluster back to the snapshot time: everything created or changed after it is lost."
  rb_warn "Restoring onto NEW hosts needs the ORIGINAL server token (it decrypts the bootstrap data in the snapshot)."
  rb_warn "Snapshots contain the cluster CA keys and all Secrets: copy and store them like secrets."
  # the snapshot to use: KDASH_RB_SNAPSHOT, else the newest that is ready
  if [ "$cnt" -gt 0 ]; then
    IFS='|' read -r name node created path s3b s3e s3r s3p < <(awk -F'\t' -v want="${KDASH_RB_SNAPSHOT:-}" '(want == "" && $7 ~ /yes/) || (want != "" && $1 == want) { print $1 "|" $2 "|" $5 "|" $8 "|" $9 "|" $10 "|" $11 "|" $12; exit }' "$snaps")
    { printf '#\tSNAPSHOT\tNODE\tSTORED\t>SIZE\tCREATED UTC\t>AGE\tREADY*\n'
      awk -F'\t' 'BEGIN { OFS = "\t" } NR <= 10 { c = $5; sub(/T/, " ", c); sub(/Z$/, "", c); print NR, $1, $2, $3, $4, c, $6, $7 }' "$snaps"
    } | tk_table "SNAPSHOTS" "ETCDSnapshotFile objects, newest first (up to 10 of $cnt) - the newest ready one is used below" "" snapshot snapshots
  else
    printf 'SNAPSHOTS\n' | tk_table "SNAPSHOTS" "" "$(case "$ss" in ok) printf 'no ETCDSnapshotFile objects - list them on a server: sudo rke2 etcd-snapshot ls' ;; forbidden) printf 'not readable with your access (cluster-scoped) - list them on a server: sudo rke2 etcd-snapshot ls' ;; *) printf 'unknown (%s) - list them on a server: sudo rke2 etcd-snapshot ls' "$ss" ;; esac)"
  fi
  case "$path" in file://*) path="${path#file://}" ;; s3://*|'') path="" ;; esac
  if [ "$cnt" -gt 0 ]; then
    local newest age_h=""
    newest="$(head -n 1 "$snaps")"
    case "$(printf '%s' "$newest" | cut -f7)" in *yes*) ;; *) rb_warn "The NEWEST snapshot $(printf '%s' "$newest" | cut -f1) ($(printf '%s' "$newest" | cut -f6) ago) is NOT usable ($(printf '%s' "$newest" | cut -f7 | sed 's/^{.}//; s/^no: //')) - fix the snapshot job / S3 access before you need it." ;; esac
    [ -n "$name" ] || rb_warn "No usable snapshot found$([ -n "${KDASH_RB_SNAPSHOT:-}" ] && printf ' named %s' "$KDASH_RB_SNAPSHOT") - the commands below use placeholders."
    if [ -n "$created" ]; then
      age_h=$(( ( $(date +%s) - $(date -u -d "$created" +%s 2>/dev/null || date +%s) ) / 3600 ))
      [ "$age_h" -lt "${KDASH_RPO_HOURS:-24}" ] || rb_warn "The snapshot used is ${age_h}h old - more than KDASH_RPO_HOURS (${KDASH_RPO_HOURS:-24}h): check the etcd-snapshot-schedule-cron."
      rb_warn "Restoring $name loses everything after $(printf '%s' "$created" | sed 's/T/ /; s/Z$//') UTC (data loss window = its age)."
    fi
    tk_note "another snapshot: KDASH_RB_SNAPSHOT=<SNAPSHOT> kdash --runbook etcd-restore"
  fi
  # servers: S1 = the node that holds a local snapshot, else the first server
  while IFS=$'\t' read -r n ip; do [ -n "$n" ] && all="$all${all:+, }$n"; done < <(rb__servers)
  if [ -n "$path" ] && [ -n "$node" ]; then s1="$node"; else s1="$(rb__servers | head -n 1 | cut -f1)"; fi
  while IFS=$'\t' read -r n ip; do [ -n "$n" ] && [ "$n" != "$s1" ] && others="$others${others:+, }$n"; done < <(rb__servers)
  [ -n "$all" ] || all="every server node"; [ -n "$s1" ] || s1="S1 (the server that holds the snapshot)"
  [ -n "$others" ] || others="$([ "$sn" = ok ] && printf 'the other servers (none found)' || printf 'every other server')"
  local rp="${path:-$RB_DATA/server/db/snapshots/<SNAPSHOT-NAME>}" s3args=""
  if [ -n "$s3b" ]; then rp="${name:-<SNAPSHOT-NAME>}"
    s3args=" --etcd-s3 --etcd-s3-bucket=$(rb_q "$s3b")${s3e:+ --etcd-s3-endpoint=$(rb_q "$s3e")}${s3r:+ --etcd-s3-region=$(rb_q "$s3r")}${s3p:+ --etcd-s3-folder=$(rb_q "$s3p")} --etcd-s3-access-key=<ACCESS-KEY> --etcd-s3-secret-key=<SECRET-KEY>"; fi
  rb_section "A. RESTORE ONTO THE EXISTING SERVERS" "servers: $all"
  rb_step 0 "prepare (nothing changes yet)"
  rb_line read "sudo rke2 etcd-snapshot ls" "confirm the snapshot is on this node$([ -n "$s3b" ] && printf ' (S3: add the --s3 flags)')" "$s1"
  rb_line read "sudo cat $RB_DATA/server/token" "save the server token in your secret store first - needed for any restore onto new hosts" "$s1"
  rb_line read "kdash --report" "evidence of the current state before you change it"
  rb_step 1 "stop rke2-server on every server"
  rb_line CHANGE "sudo systemctl stop rke2-server" "all servers must be down before the reset" "$all"
  rb_step 2 "reset the cluster from the snapshot (on $s1 only)"
  rb_line CHANGE "sudo rke2 server --cluster-reset$s3args --cluster-reset-restore-path=$rp" "wait for: Managed etcd cluster membership has been reset, restart without --cluster-reset flag now" "$s1"
  [ -z "$s3b" ] || rb_line note "S3: the restore path is the snapshot NAME only; the S3 config Secret is not used for restores - pass the flags (or use the etcd-s3 settings in config.yaml)"
  [ -n "$s3b" ] || rb_line note "if config.yaml has etcd-s3 settings and you restore this LOCAL file, add --etcd-s3=false"
  rb_step 3 "start rke2-server on $s1"
  rb_line CHANGE "sudo systemctl start rke2-server" "the reset flag file is removed on this normal start" "$s1"
  rb_line read "$(rb_k "" get nodes -o wide)" "wait until $s1 is Ready"
  rb_step 4 "on every OTHER server: back up and delete the old etcd data"
  rb_line CHANGE "sudo mv $RB_DATA/server/db $RB_DATA/server/db.bak-\$(date +%Y%m%d%H%M%S)" "RKE2 asks to back up and delete server/db on each peer (the docs show: sudo rm -rf $RB_DATA/server/db/)" "$others"
  rb_step 5 "start rke2-server on the other servers, one at a time"
  rb_line CHANGE "sudo systemctl start rke2-server" "they rejoin the restored cluster; wait for Ready before the next" "$others"
  rb_step 6 "verify"
  rb_line read "$(rb_k "" get nodes -o wide)" "all servers and agents Ready"
  rb_line read "$(rb_k "" get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded)" "what has not come back yet"
  rb_line read "kdash --doctor && kdash --certs" "API, access and certificates"
  rb_line note "nodes are restored from the snapshot too: delete nodes that no longer exist ($(rb_k "" delete node NAME)) and re-run workloads changed after the snapshot from Git / Flux"
  rb_section "B. RESTORE ONTO NEW HOSTS" "the old servers are gone"
  rb_warn "You need the ORIGINAL server token: $RB_DATA/server/token from an old server, or your secret store. Without it the restore fails; a different token in config.yaml stops RKE2 from starting."
  rb_step 1 "copy the snapshot to the new first server"
  rb_line CHANGE "sudo mkdir -p $RB_DATA/server/db/snapshots && sudo cp <SNAPSHOT-FILE> $RB_DATA/server/db/snapshots/" "for S3 snapshots skip this and pass the S3 flags" "NEW-S1"
  rb_step 2 "reset from the snapshot with the original token"
  rb_line CHANGE "sudo rke2 server --cluster-reset$s3args --cluster-reset-restore-path=$rp --token=<ORIGINAL-SERVER-TOKEN>" "the token can also be set in /etc/rancher/rke2/config.yaml" "NEW-S1"
  rb_step 3 "start it, then join the other new servers with the same token"
  rb_line CHANGE "sudo systemctl start rke2-server" "" "NEW-S1"
  rb_line note "other servers: config.yaml with  server: https://NEW-S1:9345  and  token: <ORIGINAL-SERVER-TOKEN>, then systemctl start rke2-server"
  rb_line CHANGE "$(rb_k "" delete node OLD-NODE-NAME)" "old nodes come back from the snapshot as NotReady: delete those that no longer exist"
  rb_section "NOTES" "from the RKE2 documentation"
  tk_note "--cluster-reset WITHOUT --cluster-reset-restore-path only resets etcd membership to one member; no data is restored."
  tk_note "A reset writes $RB_DATA/server/db/reset-flag (blocks a second reset) and moves the old data to $RB_DATA/server/db/etcd-old-<timestamp>."
  tk_note "A newer RKE2 minor version can restore an older snapshot. Snapshots cover embedded etcd only."
  tk_note "Default snapshot directory: $RB_DATA/server/db/snapshots"
}

rb_cert_rotate() {
  local all="" agents="" n ip
  while IFS=$'\t' read -r n ip; do [ -n "$n" ] && all="$all${all:+, }$n"; done < <(rb__servers)
  agents="$(awk -F'|' '$1 == "N" && $4 == "agent" { printf "%s%s", (c++ ? ", " : ""), $2 }' "$TOOLKIT_DIR/health-rb-nodes.raw" 2>/dev/null)"
  rb_section "WHEN TO USE" "RKE2 certificates (API server, kubelet, supervisor, etcd) are close to expiry - see key C / kdash --certs"
  rb_warn "RKE2 renews certificates with under 120 days left only when the service starts; a node that never restarts expires silently."
  rb_warn "This renews leaf certificates. It does not rotate the CA (that is rke2 certificate rotate-ca - a separate, planned procedure)."
  rb_step 1 "check, on each server"
  rb_line read "sudo rke2 certificate check --output table" "" "${all:-each server}"
  rb_step 2 "rotate on ONE server at a time"
  rb_line CHANGE "sudo systemctl stop rke2-server" "" "${all:-server N}"
  rb_line CHANGE "sudo rke2 certificate rotate" "add --service NAME to rotate only some (e.g. --service api-server)" "${all:-server N}"
  rb_line CHANGE "sudo systemctl start rke2-server" "" "${all:-server N}"
  rb_line read "$(rb_k "" get nodes)" "the server is Ready again before you continue"
  rb_step 3 "agents"
  rb_line CHANGE "sudo systemctl restart rke2-agent" "renews the agent's certificates (under 120 days left)" "${agents:-each agent}"
  rb_step 4 "verify"
  rb_line read "kdash --certs" "nothing left in WARNING / CRITICAL"
  rb_line note "kubeconfig files that embed a client certificate (e.g. rke2.yaml) may need to be copied again after a rotation"
}

rb_node_notready() {
  local bad
  bad="$(awk -F'|' '$1 == "N" && $6 != "True" { printf "%s%s", (c++ ? ", " : ""), $2 }' "$TOOLKIT_DIR/health-rb-nodes.raw" 2>/dev/null)"
  rb_section "WHEN TO USE" "a node is NotReady or Unknown${bad:+ - now: $bad}"
  { printf 'NODE\tROLE\tREADY*\tREASON\tSINCE\tSCHEDULING\n'
    LC_ALL=C awk -F'|' -v now="$(date +%s)" "$TK_TIME_AWK"'BEGIN { NOW = now; OFS = "\t" }
      $1 == "N" { r = ($6 == "True") ? "{g}Ready" : "{r}" ($6 == "" ? "Unknown" : "NotReady"); print $2, $4, r, ($7 == "" ? "-" : $7), ago($8), ($9 == "" ? "-" : "{y}" $9) }' "$TOOLKIT_DIR/health-rb-nodes.raw" 2>/dev/null
  } | tk_table "NODES" "" "nodes not readable ($(health__state rb-nodes))" node nodes
  local n="${bad%%,*}"; n="${n:-NODE}"
  rb_step 1 "what the API knows"
  rb_line read "$(rb_k "" describe node "$(rb_q "$n")")" "conditions (MemoryPressure, DiskPressure, PIDPressure) and recent events"
  rb_line read "$(rb_k "" get pods -A -o wide --field-selector spec.nodeName=$(rb_q "$n"))" "what runs there"
  rb_step 2 "on the node"
  rb_line read "sudo systemctl status rke2-agent rke2-server --no-pager" "which one is installed and running" "$n"
  rb_line read "sudo journalctl -u rke2-agent -u rke2-server --since -30min --no-pager | tail -n 100" "kubelet / containerd errors" "$n"
  rb_line read "df -h / /var/lib/rancher; free -m" "disk or memory exhausted?" "$n"
  rb_line read "sudo $RB_DATA/bin/crictl --runtime-endpoint unix:///run/k3s/containerd/containerd.sock ps" "are the containers up?" "$n"
  rb_step 3 "recover"
  rb_line CHANGE "sudo systemctl restart rke2-agent" "(rke2-server on a server node)" "$n"
  rb_line CHANGE "$(rb_k "" cordon "$(rb_q "$n")")" "stop new pods landing there while you work on it"
  rb_line CHANGE "$(rb_k "" drain "$(rb_q "$n")" --ignore-daemonsets --delete-emptydir-data --timeout=10m)" "move workloads away (emptyDir data is lost)"
  rb_line CHANGE "$(rb_k "" uncordon "$(rb_q "$n")")" "when it is healthy again"
}

rb_api_unreachable() {
  local server hp all="" n ip
  server="$(cat "$TOOLKIT_DIR/rb-server.txt" 2>/dev/null)"; hp="$(certs__hostport "${server:-https://<API-HOST>:6443}" | tr ' ' ':')"
  while IFS=$'\t' read -r n ip; do [ -n "$n" ] && all="$all${all:+, }$n"; done < <(rb__servers)
  rb_section "WHEN TO USE" "kubectl / kdash cannot reach the API server ${server:+($server)}"
  rb_step 1 "from this host"
  rb_line read "$(rb_k "" cluster-info)" "the exact error: refused, timeout, x509, Unauthorized"
  rb_line read "curl -sk https://$hp/readyz; echo" "any answer (even Unauthorized) means the network path and TLS work"
  rb_line read "timeout 4 openssl s_client -connect $hp </dev/null 2>/dev/null | openssl x509 -noout -enddate" "certificate expired? (then: kdash --runbook cert-rotate)"
  rb_line note "Unauthorized / login prompt that fails: kdash --runbook oidc-login"
  rb_step 2 "on a server"
  rb_line read "sudo systemctl status rke2-server --no-pager" "" "${all:-each server}"
  rb_line read "sudo journalctl -u rke2-server --since -30min --no-pager | tail -n 100" "etcd quorum, certificate or disk errors" "${all:-each server}"
  rb_line read "sudo $RB_DATA/bin/crictl --runtime-endpoint unix:///run/k3s/containerd/containerd.sock ps | grep -E 'kube-apiserver|etcd'" "are the API server and etcd containers running?" "${all:-each server}"
  rb_line read "sudo $RB_DATA/bin/kubectl --kubeconfig /etc/rancher/rke2/rke2.yaml get --raw '/readyz?verbose'" "which API check fails, bypassing the load balancer and OIDC" "${all:-each server}"
  rb_step 3 "recover"
  local ns_=0; ns_="$(rb__servers | grep -c .)"
  rb_line CHANGE "sudo systemctl restart rke2-server" "one server at a time; etcd needs a majority up ($([ "$ns_" -gt 0 ] && printf '%s of %s' $(( ns_ / 2 + 1 )) "$ns_" || printf '2 of 3'))" "${all:-the failed server}"
  rb_line note "if etcd lost quorum or its data is corrupt: kdash --runbook etcd-restore"
}

rb_oidc_login() {
  local args cache="~/.kube/cache/oidc-login"
  args="$(certs__kcfg '{.users[0].user.exec.args[*]}' 2>/dev/null)"
  case "$args" in *--token-cache-dir=*) cache="${args##*--token-cache-dir=}"; cache="${cache%% *}" ;; esac
  rb_section "WHEN TO USE" "kubectl asks for a login, the login fails, or kdash shows LOGIN NEEDED"
  rb_step 1 "check"
  rb_line read "$(rb_k "" auth whoami)" "triggers a new login when the refresh token has expired"
  rb_line read "$(rb_k "" config view --minify -o "jsonpath='{.users[0].user.exec.args}{\"\\n\"}'")" "issuer URL and client id this context uses"
  rb_step 2 "log in again"
  rb_line CHANGE "kubectl oidc-login clean$([ "$cache" = "~/.kube/cache/oidc-login" ] || printf ' --token-cache-dir=%s' "$(rb_q "$cache")")" "forgets cached tokens; the next kubectl call opens a fresh login"
  rb_line read "$(rb_k "" auth whoami)" "should show your user and groups"
  rb_line note "still failing: check the identity provider (issuer URL reachable from this host, clock skew, your group membership)"
}

# WHY view: the read-only checks per evidence row, then what to change per category
rb_why_next() { # dir namespace pod
  local d="$1" namespace="$2" pod="$3" n cmd last="" cat
  RB_K="$(events_kubectl_prefix)"; RB_SEEN_FILE=""
  if [ "$(wc -l < "$d/checks.tsv")" -le 1 ] && [ -z "$pod" ]; then return 0; fi
  printf '\n'
  if [ "${TK_COLOR:-0}" = 1 ]; then printf '~[1mNEXT COMMANDS~[0m  ~[90mprinted only - kdash never runs them; read = only reads, CHANGE = modifies the cluster~[0m\n'
  else printf 'NEXT COMMANDS  -  printed only - kdash never runs them; read = only reads, CHANGE = modifies the cluster\n'; fi
  if [ "$(wc -l < "$d/checks.tsv")" -gt 1 ]; then
    while IFS=$'\t' read -r n cmd; do
      [ "$n" != "#" ] || continue
      [ "$n" = "$last" ] || { rb_head "$n" "" "evidence #$n" "(WARNING EVIDENCE above)"; last="$n"; RB_CUR_N="$n"; }
      rb_line read "$cmd"
    done < "$d/checks.tsv"
  else
    rb_head "-" "pod" "$pod" ""
    rb_line read "$(events_command "$namespace" describe pod "$pod")"
  fi
  [ -s "$d/explain.tsv" ] || return 0
  local ns="${namespace:-NAMESPACE}"; RB_CUR_N="-"
  while IFS=$'\t' read -r cat _ _; do
    cat="${cat#\{?\}}"
    case "$cat" in
      memory) rb_head "" "memory" "OOM kills" "what usually fixes it"
        rb_line read "$(rb_k "$ns" top pods --containers) 2>/dev/null" "live usage per container (also key 5 MEMORY)"
        rb_line CHANGE "$(rb_k "$ns" set resources deployment/DEPLOYMENT -c CONTAINER --limits=memory=SIZE --requests=memory=SIZE)" "raise the limit (or statefulset/NAME), or fix the leak" ;;
      image) rb_head "" "image" "pull failures" "what usually fixes it"
        rb_line read "$(rb_k "$ns" get pods -o "jsonpath='{range .items[*]}{.metadata.name}: {.spec.containers[*].image} pullSecrets={.spec.imagePullSecrets[*].name}{\"\\n\"}{end}'")" "the image references and pull secrets"
        rb_line note "check the tag exists in the registry and the pull secret is valid; the registry must be reachable from the nodes" ;;
      scheduling) rb_head "" "scheduling" "pods not placed" "what usually fixes it"
        rb_line read "$(rb_k "" describe nodes) | grep -A 8 'Allocated resources'" "free capacity per node"
        rb_line note "reduce requests, add capacity, or fix the nodeSelector / affinity / taint tolerations the scheduler message names" ;;
      probe) rb_head "" "probe" "probe failures" "what usually fixes it"
        rb_line note "if the app is slow to start, a startupProbe (or a longer initialDelaySeconds) usually fixes it; if it really fails, the logs above say why" ;;
      restart) rb_head "" "restart" "crash loop" "what usually fixes it"
        rb_line note "the previous logs (above) show the exit reason; a config or Secret change is the usual cause - compare with the last rollout:"
        rb_line read "$(rb_k "$ns" rollout history deployment/DEPLOYMENT)" "what changed and when" ;;
      storage) rb_head "" "storage" "volume problems" "see key 9 STORAGE: its findings carry their own next commands" ;;
    esac
  done < <(tail -n +2 "$d/explain.tsv")
  return 0
}

# ---- instant check (key K, --check) and running the read commands of a finding -
# One screen with everything that is wrong now, from every area kdash reads (API,
# nodes, pods, services, storage, certificates and logins, etcd snapshots), most
# severe first, each with its next commands. Enter (or --check --run N) runs the
# READ commands of a finding at once and shows their output; CHANGE commands never run.
CHECK_AREAS="api nodes pods services storage certificates secrets etcd"

check_collect() { # API reads the instant check needs beyond the dashboard data
  # certificates: reuse a recent full check, else a quick one (kubeconfig, API endpoint, CA bundles)
  if [ "$(certs_age)" -ge "${KDASH_CERT_TTL:-300}" ]; then
    local cq="$TOOLKIT_DIR/check-certs"
    ( TOOLKIT_DIR="$cq"; rm -rf "$cq"; mkdir -p "$cq"; cp -f "${TOOLKIT_DIR%/check-certs}/events.tsv" "$cq/" 2>/dev/null; certs_collect quick ) > /dev/null 2>&1
  else rm -rf "$TOOLKIT_DIR/check-certs"; fi
  [ "$(rb_age)" -lt 60 ] || rb_collect
  # certificates inside Secrets and who uses them (the secrets map, key Y): reused for KDASH_SECRETS_CHECK_TTL s
  if [ "${KDASH_SECRETS_IN_CHECK:-1}" = 1 ]; then
    [ "$(sm_age)" -lt "${KDASH_SECRETS_CHECK_TTL:-300}" ] || sm_collect > /dev/null 2>&1
  else rm -f "$TOOLKIT_DIR/sm.at" "$TOOLKIT_DIR/sm-findings.tsv"; health__status sm-secrets disabled 'KDASH_SECRETS_IN_CHECK=0'; fi
  date +%s > "$TOOLKIT_DIR/check.at"
}
check_age() { local at; at="$(cat "${TOOLKIT_DIR:-/nonexistent}/check.at" 2>/dev/null)"; case "$at" in [0-9]*) printf '%s' "$(( $(date +%s) - at ))" ;; *) printf 999999 ;; esac; }

# extra catalogue entries used only here (pods, nodes, API, etcd snapshots)
check_hints() { # key ns name x1 x2
  local key="$1" ns="$2" name="$3" x1="${4:-}" x2="${5:-}" n; n="$(rb_q "$name")"
  case "$key" in
    pod-crash)
      rb_line read "$(rb_k "$ns" logs "$n" --all-containers --previous --tail=100)" "why the last run ended"
      rb_line read "$(rb_k "$ns" describe pod "$n")" "exit codes, reasons and events"
      [ -z "$x1" ] || [ "$x1" = "-" ] || rb_line read "$(rb_k "$ns" rollout history "$(rb_q "$x1")")" "a recent rollout is the usual cause" ;;
    pod-image)
      rb_line read "$(rb_k "$ns" describe pod "$n")" "the pull error is in the events"
      rb_line read "$(rb_k "$ns" get pod "$n" -o "jsonpath='{range .spec.containers[*]}{.name}: {.image}{\"\\n\"}{end}pullSecrets: {.spec.imagePullSecrets[*].name}{\"\\n\"}'")" "image references and pull secrets"
      rb_line note "check the tag exists in the registry and the pull secret is valid; the registry must be reachable from the node" ;;
    pod-pending)
      rb_line read "$(rb_k "$ns" describe pod "$n")" "the scheduler's message is in the events"
      rb_line read "$(rb_k "$ns" get pvc)" "an unbound claim also keeps a pod Pending" ;;
    pod-notready)
      rb_line read "$(rb_k "$ns" describe pod "$n")" "which probe fails and why"
      rb_line read "$(rb_k "$ns" logs "$n" --all-containers --tail=100 --since=10m)" "what the application says" ;;
    pod-oom)
      rb_line read "$(rb_k "$ns" describe pod "$n")" "OOMKilled container and its limit"
      rb_line read "$(rb_k "$ns" top pod "$n" --containers)" "usage now (also key 5 MEMORY)"
      [ -z "$x1" ] || [ "$x1" = "-" ] || rb_line CHANGE "$(rb_k "$ns" set resources "$(rb_q "$x1")" -c CONTAINER --limits=memory=SIZE)" "raise the limit, or fix the leak" ;;
    node)
      rb_line read "$(rb_k "" describe node "$n")" "conditions and recent events"
      rb_line read "$(rb_k "" get pods -A -o wide --field-selector "spec.nodeName=$n")" "what runs on it"
      rb_line note "on the node and how to recover: kdash --runbook node-notready (R in kdash)" ;;
    api)
      [ "${LOGIN_NEEDED:-0}" != 1 ] || rb_line note "OIDC login: press L - kdash shows the login URL and continues afterwards"
      rb_line read "$(rb_k "" cluster-info)" "the exact error"
      rb_line note "full procedure: kdash --runbook api-unreachable (R in kdash)" ;;
    etcd-snap)
      rb_line read "$(rb_k "" get etcdsnapshotfiles.k3s.cattle.io -o wide)" "all snapshots with status"
      [ -z "$name" ] || rb_line read "$(rb_k "" describe etcdsnapshotfiles.k3s.cattle.io "$n")" "the error of this snapshot"
      rb_line read "sudo journalctl -u rke2-server --since -24h --no-pager | grep -i snapshot | tail -n 20" "snapshot job errors" "${x1:-a server}"
      rb_line note "restore procedure (and which snapshot it would use): kdash --runbook etcd-restore" ;;
    *) fmea_hints "$@"; return $? ;;
  esac
  return 0
}

# rows: AREA SEVERITY OBJECT FINDING HINTKEY -> $TOOLKIT_DIR/check-findings.tsv
check_findings() {
  local out="$TOOLKIT_DIR/check-findings.tsv"
  : > "$out"
  # API
  if [ "${SPEC_OK:-1}" != 1 ] && [ -n "${SPEC_REASON:-}" ]; then
    printf 'api\t{r}CRITICAL\t%s\tcannot read pods: %s\tapi\n' "${CTX_NAME:-context}" "$SPEC_REASON" >> "$out"
  fi
  # pods (the dashboard model)
  if [ -n "${MODEL:-}" ] && [ -s "$MODEL/pods.tsv" ]; then
    LC_ALL=C awk -F'\t' -v all="${ALL_NS:-0}" '
      NR == 1 { next }
      { ns = $2; p = $3; st = $4; split($5, r, "/"); rs = $6 + 0; kind = tolower($12); wl = $13; lt = $22
        obj = (all == "1" ? ns "/" : "") p; owner = (kind != "" && wl != "" && wl != "-") ? kind "/" wl : "-"
        if (kind !~ /^(deployment|statefulset|daemonset)$/) owner = "-"
        if (st ~ /CrashLoopBackOff|^Error$|CreateContainerConfigError|CreateContainerError|RunContainerError|Init:CrashLoopBackOff|Init:Error/)
          printf "pods\t{r}CRITICAL\t%s\t%s, %d restarts%s\tpod-crash|%s|%s|%s\n", obj, st, rs, (lt != "" && lt != "-" ? " (last: " lt ")" : ""), ns, p, owner
        else if (st ~ /ImagePullBackOff|ErrImagePull|InvalidImageName/)
          printf "pods\t{r}CRITICAL\t%s\t%s - the image cannot be pulled\tpod-image|%s|%s\n", obj, st, ns, p
        else if (st ~ /OOMKilled/ || lt ~ /OOMKilled/)
          printf "pods\t{y}WARNING\t%s\t%s - %d restarts, last ended OOMKilled\tpod-oom|%s|%s|%s\n", obj, st, rs, ns, p, owner
        else if (st == "Pending" || st ~ /ContainerCreating|PodInitializing|^Init:/)
          printf "pods\t{y}WARNING\t%s\t%s\tpod-pending|%s|%s\n", obj, st, ns, p
        else if (st == "Running" && r[1] != r[2])
          printf "pods\t{y}WARNING\t%s\tRunning but %s ready%s\tpod-notready|%s|%s\n", obj, $5, (rs > 0 ? ", " rs " restarts" : ""), ns, p
        else if (st ~ /Unknown|NodeLost|Evicted/)
          printf "pods\t{y}WARNING\t%s\t%s\tpod-notready|%s|%s\n", obj, st, ns, p }
    ' "$MODEL/pods.tsv" >> "$out"
  fi
  # nodes
  awk -F'|' '$1 == "N" && $6 != "True" { printf "nodes\t{r}CRITICAL\t%s\t%s %s (%s)\tnode||%s\n", $2, $4, ($6 == "" ? "Unknown" : "NotReady"), ($7 == "" ? "no reason" : $7), $2 }
             $1 == "N" && $6 == "True" && $9 != "" { printf "nodes\t{d}INFO\t%s\tcordoned (no new pods)\tnode||%s\n", $2, $2 }' \
    "$TOOLKIT_DIR/health-rb-nodes.raw" 2>/dev/null >> "$out"
  # etcd snapshots (when readable)
  if [ "$(health__state rb-snapshots)" = ok ]; then
    LC_ALL=C awk -F'|' -v now="$(date +%s)" -v rpo="${KDASH_RPO_HOURS:-24}" "$TK_TIME_AWK"'
      BEGIN { NOW = now }
      $1 == "E" { n++; if ($7 > newest) { newest = $7; nn = $3; nok = ($8 == "true"); nerr = $13; nnode = $4; nid = $2 }
                  if ($8 == "true" && $7 > good) { good = $7; gn = $3 } }
      END {
        if (n == 0) { printf "etcd\t{y}WARNING\tsnapshots\tno etcd snapshots exist\tetcd-snap\n"; exit }
        if (!nok) printf "etcd\t{y}WARNING\t%s\tnewest snapshot (%s ago) is not usable%s\tetcd-snap||%s|%s\n", nn, ago(newest), (nerr != "" ? ": " nerr : ""), nid, nnode
        if (good == "") printf "etcd\t{r}CRITICAL\tsnapshots\tno usable etcd snapshot - a restore is impossible\tetcd-snap\n"
        else if (NOW - epoch(good) > rpo * 3600) printf "etcd\t{y}WARNING\t%s\tnewest usable snapshot is %s old (more than %sh)\tetcd-snap\n", gn, ago(good), rpo }
    ' "$TOOLKIT_DIR/health-rb-snapshots.raw" >> "$out"
  fi
  # services, storage, certificates: the views' own findings, gathered without drawing them
  RB_COLLECT_FINDINGS="$out" RB_AREA=services health_render_services > /dev/null 2>&1
  RB_COLLECT_FINDINGS="$out" RB_AREA=storage health_render_storage > /dev/null 2>&1
  if [ -d "$TOOLKIT_DIR/check-certs/certs" ]; then
    ( TOOLKIT_DIR="$TOOLKIT_DIR/check-certs"; RB_COLLECT_FINDINGS="$out" RB_AREA=certificates certs_render ) > /dev/null 2>&1
  elif [ -d "$TOOLKIT_DIR/certs" ]; then RB_COLLECT_FINDINGS="$out" RB_AREA=certificates certs_render > /dev/null 2>&1; fi
  # secrets map: expired / expiring certificates in Secrets, missing Secrets, broken chains, stale consumers
  if [ -s "$TOOLKIT_DIR/sm-findings.tsv" ]; then
    awk -F'\t' -v all="${ALL_NS:-0}" '{ o = $2; if (all != "1") sub(/^[^\/]*\//, "", o); printf "secrets\t%s\t%s\t%s\t%s\n", $1, o, $3, $4 }' "$TOOLKIT_DIR/sm-findings.tsv" >> "$out"
  fi
  return 0
}

check_render() {
  local f="$TOOLKIT_DIR/check-findings.tsv" num="$TOOLKIT_DIR/check-numbered.tsv" crit warn a st det cnt
  tk_title "CHECK NOW" "everything kdash can see that is wrong right now - most severe first, with the commands to check and fix it"
  if [ ! -f "$TOOLKIT_DIR/check.at" ]; then printf '\nChecking API, nodes, pods, services, storage, certificates, Secrets and etcd snapshots...\n'; return 0; fi
  check_findings
  # the verdict line
  crit="$(grep -c $'\t{r}CRITICAL' "$f")"; warn="$(grep -c $'\t{y}WARNING' "$f")"
  if [ "${TK_COLOR:-0}" = 1 ]; then
    if [ "$crit" -gt 0 ]; then printf '\n ~[1;41;97m %s CRITICAL ~[0m' "$crit"; fi
    if [ "$warn" -gt 0 ]; then printf '%s~[1;43;30m %s WARNING ~[0m' "$([ "$crit" -gt 0 ] && printf ' ' || printf '\n ')" "$warn"; fi
    if [ "$crit$warn" = 00 ]; then printf '\n ~[1;42;30m ALL CLEAR ~[0m'; fi
    printf '  ~[90mchecked %ss ago - r re-checks now~[0m\n' "$(check_age)"
  else
    printf '\n %s CRITICAL  %s WARNING  (checked %ss ago - r re-checks now)\n' "$crit" "$warn" "$(check_age)"
  fi
  # area summary
  { printf 'AREA\tSTATUS*\t>FINDINGS\tDETAIL\n'
    for a in $CHECK_AREAS; do
      cnt="$(awk -F'\t' -v a="$a" '$1 == a && $2 !~ /INFO/' "$f" | wc -l | tr -d ' ')"
      st="{g}OK"
      awk -F'\t' -v a="$a" '$1 == a && $2 ~ /WARN/ { f = 1 } END { exit !f }' "$f" && st="{y}WARNING"
      awk -F'\t' -v a="$a" '$1 == a && $2 ~ /CRIT/ { f = 1 } END { exit !f }' "$f" && st="{r}CRITICAL"
      case "$a" in
        api) det="$([ "${SPEC_OK:-1}" = 1 ] && printf 'pods read %ss ago' "$(( $(date +%s) - ${SPEC_AT:-0} ))" || printf '%s' "${SPEC_REASON:-not read yet}")" ;;
        nodes) case "$(health__state rb-nodes)" in ok) det="$(awk -F'|' '$1 == "N" { n++; if ($6 == "True") r++ } END { printf "%d of %d Ready", r, n }' "$TOOLKIT_DIR/health-rb-nodes.raw")" ;; *) [ "$cnt" != 0 ] || st="{d}not visible"; det="nodes: $(health__state rb-nodes)" ;; esac ;;
        pods) det="$(awk -F'\t' 'NR > 1 { n++ } END { printf "%d pods in the dashboard scope", n }' "$MODEL/pods.tsv" 2>/dev/null)" ;;
        services) det="services $(health__state services), endpoints $(health__state endpoints), ingresses $(health__state ingresses)" ;;
        storage) det="claims $(health__state pvcs), volumes $(health__state pvs)" ;;
        certificates) det="$(if [ -d "$TOOLKIT_DIR/check-certs/certs" ]; then printf 'quick check (C for nodes, kubelets, ingress)'; elif [ -d "$TOOLKIT_DIR/certs" ]; then printf 'full check %ss ago' "$(certs_age)"; else printf 'not checked'; fi)" ;;
        secrets) case "$(health__state sm-secrets)" in
                   ok) det="$(awk -F'\t' '{ printf "%d certificates in %d Secrets", $2, $1 }' "$TOOLKIT_DIR/sm.summary" 2>/dev/null) - Y shows who uses them and where" ;;
                   disabled) st="{d}not checked"; det="switched off (KDASH_SECRETS_IN_CHECK=0) - Y still shows the map" ;;
                   *) [ "$cnt" != 0 ] || st="{d}not visible"; det="Secrets read $(health__state sm-secrets): certificates inside them are not visible to you" ;; esac ;;
        etcd) case "$(health__state rb-snapshots)" in ok) det="$(awk -F'|' '$1 == "E" { n++; if ($8 == "true") r++ } END { printf "%d snapshots, %d usable", n, r }' "$TOOLKIT_DIR/health-rb-snapshots.raw")" ;;
                *) st="{d}not visible"; det="snapshots: $(health__state rb-snapshots) - on a server: sudo rke2 etcd-snapshot ls" ;; esac ;;
      esac
      printf '%s\t%s\t%s\t%s\n' "$a" "$st" "$cnt" "$det"
    done
  } | tk_table "AREAS" "" "" area areas
  # findings, numbered across all areas (INFO last), then their commands
  awk -F'\t' 'BEGIN { OFS = "\t" } { r = ($2 ~ /CRIT/) ? 1 : ($2 ~ /WARN/) ? 2 : 3; print r, $0 }' "$f" | LC_ALL=C sort -t $'\t' -s -k1,1n | cut -f2- |
    awk -F'\t' 'BEGIN { OFS = "\t" } { print NR, $0 }' > "$num"
  { printf '#\tSEVERITY*\tAREA\tOBJECT\tFINDING\n'; awk -F'\t' 'BEGIN { OFS = "\t" } { print $1, $3, $2, $4, $5 }' "$num"; } |
    tk_table "FINDINGS" "critical first - Enter runs the read commands of one now (CHANGE commands are never run)" "nothing wrong found - the areas above say what was checked" finding findings
  awk -F'\t' 'BEGIN { OFS = "\t" } { print $1, $3, $4, $5, $6 }' "$num" > "$num.list"
  KDASH_HINT_MAX="${KDASH_CHECK_HINT_MAX:-60}" rb_next_list "$num.list"
  rm -f "$num.list"
  return 0
}

# Run the read commands captured for finding N; output to a file (the caller shows it)
check_run() { # finding-number capture-file output-file
  local n="$1" cap="$2" out="$3" alias cmd verb w i ran=0 skipped=0 rc t0
  local -a argv rest
  [ -s "$cap" ] || { printf 'no commands recorded - open the view first\n' > "$out"; return 1; }
  alias="$(awk -F'\t' -v k="@$n" '$1 == k { print $2; exit }' "$cap")"; [ -z "$alias" ] || n="$alias"
  : > "$out"
  printf 'kdash instant check - finding #%s - context %s - %s\nread-only commands, run now through the audited kubectl guard\n' "$n" "$CTX_NAME" "$(date '+%Y-%m-%d %H:%M:%S %Z')" >> "$out"
  while IFS=$'\t' read -r i cmd; do
    [ "$i" = "$n" ] || continue
    cmd="${cmd% 2>/dev/null}"
    printf '\n$ %s\n' "$cmd" >> "$out"
    # only plain kubectl reads: no pipes, redirections, substitutions or variables
    case "$cmd" in kubectl\ *) ;; *) printf '(not run: not a kubectl command - run it yourself where it says)\n' >> "$out"; skipped=$((skipped + 1)); continue ;; esac
    case "$cmd" in *'|'*|*';'*|*'&'*|*'`'*|*'$'*|*'>'*|*'<'*) printf '(not run: pipes and redirections are left to you)\n' >> "$out"; skipped=$((skipped + 1)); continue ;; esac
    argv=()
    set -f; if ! eval "argv=( $cmd )" 2>/dev/null; then set +f; printf '(not run: could not parse)\n' >> "$out"; skipped=$((skipped + 1)); continue; fi; set +f
    rest=(); w=1
    while [ "$w" -lt "${#argv[@]}" ]; do
      case "${argv[w]}" in
        --context|--kubeconfig) w=$((w + 2)); continue ;;
        --context=*|--kubeconfig=*) w=$((w + 1)); continue ;;
      esac
      rest+=("${argv[w]}"); w=$((w + 1))
    done
    verb=""; w=0
    while [ "$w" -lt "${#rest[@]}" ]; do
      case "${rest[w]}" in -n|--namespace|-l|-o|-c|--selector|--field-selector) w=$((w + 2)) ;; -*) w=$((w + 1)) ;; *) verb="${rest[w]}"; break ;; esac
    done
    case "$verb" in
      get|describe|logs|top|explain|events|version|cluster-info|api-resources) ;;
      auth) case " ${rest[*]} " in *" whoami "*|*" can-i "*) ;; *) verb="" ;; esac ;;
      rollout) case " ${rest[*]} " in *" history "*|*" status "*) ;; *) verb="" ;; esac ;;
      *) verb="" ;;
    esac
    case " ${rest[*]} " in *" --raw "*|*" -w "*|*" --watch "*|*" -f "*|*" --follow "*) verb="" ;; esac
    if [ -z "$verb" ]; then printf '(not run: only get, describe, logs, top, rollout history/status and auth whoami/can-i run from here)\n' >> "$out"; skipped=$((skipped + 1)); continue; fi
    t0=$(date +%s)
    timeout "${KDASH_CHECK_TIMEOUT:-30}" "${KC[@]}" "${rest[@]}" < /dev/null 2>&1 | head -c "${KDASH_CHECK_BYTES:-262144}" | inspector_clean >> "$out"
    rc="${PIPESTATUS[0]}"
    [ "$rc" = 0 ] || printf '(exit %s%s)\n' "$rc" "$([ "$rc" = 124 ] && printf ' - timed out after %ss' "${KDASH_CHECK_TIMEOUT:-30}")" >> "$out"
    printf '(%ss)\n' "$(( $(date +%s) - t0 ))" >> "$out"
    ran=$((ran + 1))
  done < "$cap"
  [ $((ran + skipped)) -gt 0 ] || printf '\nno read commands for finding #%s (it may only have notes or CHANGE commands)\n' "$n" >> "$out"
  audit CHECK_RUN "finding=$n ran=$ran skipped=$skipped view=${VIEW:-check}"
  CHECK_RAN="$ran"; CHECK_SKIPPED="$skipped"
  [ "$ran" -gt 0 ]
}

# Enter in a view with findings: ask for the number, run, show in the pager
check_run_prompt() {
  local cap="$TOOLKIT_DIR/run-$VIEW.tsv" n out="$TMPD/check-run.out" pager first
  [ -s "$cap" ] || paint 2>/dev/null
  first="$(awk -F'\t' '$1 ~ /^[0-9]+$/ { print $1; exit }' "$cap" 2>/dev/null)"
  [ -n "$first" ] || { flash "no read commands to run in this view" 4; return 0; }
  printf '\033[%s;1H\033[K\033[?25h run the read commands of finding # (Enter = %s, Esc cancels): ' "$(tput lines 2>/dev/null || echo 24)" "$first"
  IFS= read -r n </dev/tty || n=""; printf '\033[?25l'
  case "$n" in *$'\e'*|q|Q) return 0 ;; '') n="$first" ;; esac
  case "$n" in \#*) n="${n#\#}" ;; esac
  case "$n" in *[!0-9]*) flash "not a finding number: $n" 4; return 0 ;; esac
  flash "running the read commands of #$n ..." 30; paint 2>/dev/null
  check_run "$n" "$cap" "$out"
  pager="$(command -v less || command -v more || echo cat)"
  printf '\033[2J\033[H\033[?25h'
  { printf '(q returns to kdash)\n\n'; cat "$out"; } | LESS='-R -K -S' "$pager"
  [ "${pager##*/}" != cat ] || { printf '\n any key returns'; IFS= read -rsn1 _ </dev/tty; }
  printf '\033[?25l\033[2J'
  flash "#$n: ran ${CHECK_RAN:-0}, left to you ${CHECK_SKIPPED:-0} - output kept in $out" 8
}

# ---- OIDC / exec-plugin login (startup check, key L) ----------------------------
# kubectl's login helper (kubelogin / oidc-login) prints a URL and waits for the
# browser (or for a code typed in). kdash runs its API reads in the background with
# no terminal, so that URL used to vanish into an error file and every read failed.
# Now: a login that is due is found before the dashboard starts (and when a read
# fails later), the helper runs in the foreground with the URL shown prominently,
# and the dashboard picks up again as soon as the login succeeds.
LOGIN_ERR_RE='visit the following url|open the following url|please visit|in your browser|enter code|device code|user code|oidc-login|kubelogin|get-token|getting credentials|exec plugin|executable .* failed|you must be logged in|unauthorized|invalid_grant|refresh token|token is expired|token has expired|authentication required|interactive login'
LOGIN_NEEDED=0; LOGIN_URL=""; LOGIN_USER=""

# The login URL(s) a helper printed: a URL on a line that asks to visit / open / sign in
# (or on the next lines, when the helper prints the URL on its own line). URLs inside
# API connection errors ('Get "https://...": dial tcp ...') and the API server itself
# are never login URLs. Up to 3 distinct URLs, in order.
login_urls_of() { # file
  [ -s "$1" ] || return 0
  LC_ALL=C awk -v api="${LOGIN_API_URL:-}" '
    function grab(s,   u) {
      while (match(s, /https?:\/\/[^] \t"<>'"'"'()]+/)) {
        u = substr(s, RSTART, RLENGTH); s = substr(s, RSTART + RLENGTH)
        sub(/[.,;:]+$/, "", u)
        if (api != "" && index(u, api) == 1) continue
        if (!(u in seen) && n < 3) { seen[u] = 1; n++; print u }
      } }
    { gsub(/\r/, ""); l = tolower($0) }
    l ~ /dial tcp|get "https?:|post "https?:|unable to connect to the server|connection refused|i\/o timeout|no such host|tls handshake/ { want = 0; next }
    l ~ /visit|open |opening|browser|log ?in|sign ?in|authenticat|device|verif|go to|navigate|following url|authori[sz]e/ { want = 3; grab($0); next }
    want > 0 { grab($0); want-- }
  ' "$1"
}
login_url_of() { login_urls_of "$1" | head -n 1; }
# a helper waits for the user: a login URL, or a prompt for a code
login_prompted() { [ -n "$(login_urls_of "$1")" ] || grep -qiE 'enter (the )?code|user code|device code|verification code' "$1" 2>/dev/null; }
# does this context log in through a helper at all (exec plugin / oidc auth-provider)?
login_has_plugin() {
  if [ -z "${LOGIN_HAS_PLUGIN:-}" ]; then
    if [ -n "$(certs__kcfg '{.users[0].user.exec.command}')" ] || [ -n "$(certs__kcfg '{.users[0].user.auth-provider.name}')" ]; then LOGIN_HAS_PLUGIN=1; else LOGIN_HAS_PLUGIN=0; fi
    LOGIN_API_URL="$(certs__kcfg '{.clusters[0].cluster.server}')"
  fi
  [ "$LOGIN_HAS_PLUGIN" = 1 ]
}
login_err_check() { [ -s "$1" ] || return 1; login_has_plugin || return 1; login_prompted "$1" || grep -qiE "$LOGIN_ERR_RE" "$1"; }

login__argv() { # -> LOGIN_KUBECTL (real kubectl) + LOGIN_ARGS (context / kubeconfig only)
  local a skip=0 i=1
  LOGIN_KUBECTL="${KDASH_REAL_KUBECTL:-}"; LOGIN_ARGS=()
  if [ "${KC[0]}" = bash ] && [ "${KC[1]:-}" = "$TMPD/kubectl" ]; then i=2; else LOGIN_KUBECTL="${LOGIN_KUBECTL:-${KC[0]}}"; fi
  [ -n "$LOGIN_KUBECTL" ] || LOGIN_KUBECTL="$(command -v kubectl)"
  for a in "${KC[@]:$i}"; do
    if [ "$skip" = 1 ]; then skip=0; continue; fi
    case "$a" in --request-timeout) skip=1 ;; --request-timeout=*) ;; *) LOGIN_ARGS+=("$a") ;; esac
  done
}

# what the kubelogin token cache says, without any network call:
# noplugin | valid | none | expired | unknown
login__cache_state() {
  local cmd ap args cache issuer="" a prev="" f newest="" idt rt line e now
  cmd="$(certs__kcfg '{.users[0].user.exec.command}')"
  ap="$(certs__kcfg '{.users[0].user.auth-provider.name}')"
  if [ -z "$cmd" ]; then [ "$ap" = oidc ] && { printf unknown; return 0; }; printf noplugin; return 0; fi
  args="$(certs__kcfg '{.users[0].user.exec.args[*]}')"
  case "$cmd $args" in *oidc-login*|*oidc_login*|*kubelogin*) ;; *) printf unknown; return 0 ;; esac
  case "$args" in *--oidc-issuer-url*) ;; *) printf unknown; return 0 ;; esac   # e.g. Azure kubelogin: another cache
  case "$args" in *keyring*) printf unknown; return 0 ;; esac
  cache="$HOME/.kube/cache/oidc-login"
  for a in $args; do
    case "$a" in --token-cache-dir=*) cache="${a#*=}" ;; --oidc-issuer-url=*) issuer="${a#*=}" ;; esac
    case "$prev" in --token-cache-dir) cache="$a" ;; --oidc-issuer-url) issuer="$a" ;; esac
    prev="$a"
  done
  cache="${cache/#\~/$HOME}"
  for f in "$cache"/*; do
    [ -f "$f" ] && [ -r "$f" ] || continue
    case "$f" in *.lock) continue ;; esac
    idt="$(LC_ALL=C grep -o '"id_token" *: *"[^"]*"' "$f" 2>/dev/null | head -n 1 | sed 's/.*: *"//; s/"$//')"
    [ -n "$idt" ] || continue
    if [ -n "$issuer" ]; then line="$(certs__jwt "$idt")" || continue
      case "${line#*$'\t'}" in "${issuer%/}"|"${issuer%/}/") ;; *) continue ;; esac; fi
    if [ -z "$newest" ] || [ "$f" -nt "$newest" ]; then newest="$f"; fi
  done
  [ -n "$newest" ] || { printf none; return 0; }
  now=$(date +%s)
  idt="$(LC_ALL=C grep -o '"id_token" *: *"[^"]*"' "$newest" | head -n 1 | sed 's/.*: *"//; s/"$//')"
  rt="$(LC_ALL=C grep -o '"refresh_token" *: *"[^"]*"' "$newest" | head -n 1 | sed 's/.*: *"//; s/"$//')"
  e="$(certs__jwt "$idt" 2>/dev/null | cut -f1)"
  if [ -n "$e" ] && [ "$e" -gt $((now + 60)) ]; then printf valid; return 0; fi
  [ -n "$rt" ] || { printf expired; return 0; }
  e="$(certs__jwt "$rt" 2>/dev/null | cut -f1)"
  if [ -z "$e" ]; then printf unknown; elif [ "$e" -gt $((now + 60)) ]; then printf valid; else printf expired; fi
  return 0
}

# Stand-in browsers: a helper that "opens" the login page in a browser (xdg-open, BROWSER,
# ...) - on a director host that is usually nothing, or a remote X11 window - records the
# URL here instead, and kdash shows it. KDASH_LOGIN_BROWSER=system lets it open a browser.
login__browser_dir() { # dir -> creates the stand-ins, empties the URL record
  local d="$1" b
  mkdir -p "$d" 2>/dev/null || return 1
  for b in xdg-open x-www-browser www-browser sensible-browser gnome-open kde-open wslview open firefox google-chrome chromium chromium-browser; do
    [ -x "$d/$b" ] && continue
    printf '#!/bin/sh\n# kdash: records the URL a login helper wanted to open (nothing is opened)\n[ -n "$1" ] && printf "%%s\\n" "$1" >> "%s/url"\nexit 0\n' "$d" > "$d/$b"
    chmod 700 "$d/$b"
  done
  rm -f "$d/url"
}
login__env() { # run a command with the stand-in browsers (unless KDASH_LOGIN_BROWSER=system)
  local d="$1"; shift
  if [ "${KDASH_LOGIN_BROWSER:-capture}" = capture ] && login__browser_dir "$d"; then PATH="$d:$PATH" BROWSER="$d/xdg-open" "$@"
  else "$@"; fi
}
login__kill_tree() { # pid: it and all its descendants
  local p kids=""
  if command -v pgrep >/dev/null 2>&1; then for p in $(pgrep -P "$1" 2>/dev/null); do login__kill_tree "$p"; done; fi
  kill "$1" 2>/dev/null || true
}
# while the login screen waits: did the login complete (here or in another terminal)?
login__poll_ok() {
  [ "$(login__cache_state 2>/dev/null)" != valid ] || return 0
  KDASH_LOGIN_PROBE="${KDASH_LOGIN_POLL_PROBE:-4}" LOGIN_PROBE_DIR="$TMPD/login-poll" login_probe >/dev/null 2>&1
}
login__issuer() { # the issuer URL and client id the context logs in with (from the kubeconfig)
  local args a prev="" iss="" cid=""
  args="$(certs__kcfg '{.users[0].user.exec.args[*]}')"
  for a in $args; do
    case "$a" in --oidc-issuer-url=*) iss="${a#*=}" ;; --oidc-client-id=*) cid="${a#*=}" ;; esac
    case "$prev" in --oidc-issuer-url) iss="$a" ;; --oidc-client-id) cid="$a" ;; esac
    prev="$a"
  done
  [ -n "$iss" ] || iss="$(certs__kcfg '{.users[0].user.auth-provider.config.idp-issuer-url}')"
  [ -n "$cid" ] || cid="$(certs__kcfg '{.users[0].user.auth-provider.config.client-id}')"
  printf '%s\t%s' "$iss" "$cid"
}

# kill login helpers left behind by background reads (they hold the callback port 8000)
login__kill_stale() { # [keep-pid]: every login helper started by this kdash (tagged), except keep-pid's tree
  local p keep="${1:-}" pids="" sig
  if [ -n "${KDASH_LOGIN_TAG:-}" ] && [ -d /proc/self ]; then
    for p in /proc/[0-9]*; do
      p="${p#/proc/}"; [ "$p" != "$$" ] || continue
      [ -r "/proc/$p/environ" ] || continue
      # (a process can end while this looks: every read is silent)
      { tr '\0' '\n' < "/proc/$p/environ"; } 2>/dev/null | grep -qxF "KDASH_LOGIN_TAG=$KDASH_LOGIN_TAG" || continue
      { tr '\0' ' ' < "/proc/$p/cmdline"; } 2>/dev/null | grep -qE 'oidc[-_]login|kubelogin|get-token|credential' || continue
      if [ -n "$keep" ] && login__is_descendant "$p" "$keep"; then continue; fi
      pids="$pids $p"
    done
  else
    pids="$(ps -o pid=,args= -s "$(ps -o sid= $$ 2>/dev/null | tr -d ' ')" 2>/dev/null | grep -E 'oidc[-_]login get-token|kubelogin get-token' | grep -v grep | awk '{print $1}')"
  fi
  [ -n "${pids// /}" ] || return 0
  kill $pids 2>/dev/null; sleep 0.3
  for p in $pids; do kill -0 "$p" 2>/dev/null && kill -9 "$p" 2>/dev/null; done
  return 0
}
login__is_descendant() { # pid ancestor
  local p="$1" i=0
  while [ -n "$p" ] && [ "$p" -gt 1 ] && [ "$i" -lt 30 ]; do
    [ "$p" != "$2" ] || return 0
    p="$( { awk '{print $4}' "/proc/$p/stat"; } 2>/dev/null)"; i=$((i + 1))
  done
  return 1
}

# A short look with no terminal: 0 = the API answers, 1 = a login is needed, 2 = another error.
# The helper is stopped as soon as it prints a URL (it would wait for the browser).
login_probe() {
  local err="$TMPD/login-probe.err" pid i=0 max=$(( ${KDASH_LOGIN_PROBE:-10} * 5 )) rc
  login__argv
  : > "$err"
  local pd="${LOGIN_PROBE_DIR:-$TMPD/login-probe}"
  if command -v setsid >/dev/null 2>&1; then login__env "$pd" setsid "$LOGIN_KUBECTL" "${LOGIN_ARGS[@]}" version --request-timeout=8s < /dev/null > /dev/null 2> "$err" & pid=$!
  else login__env "$pd" "$LOGIN_KUBECTL" "${LOGIN_ARGS[@]}" version --request-timeout=8s < /dev/null > /dev/null 2> "$err" & pid=$!; fi
  while kill -0 "$pid" 2>/dev/null; do
    if login_prompted "$err" || [ -s "$pd/url" ]; then
      kill -- "-$pid" 2>/dev/null || login__kill_tree "$pid"; wait "$pid" 2>/dev/null; LOGIN_URL="$(login_url_of "$err")"
      login__kill_stale "${LOGIN_HP:-}"; return 1
    fi
    i=$((i + 1)); [ "$i" -lt "$max" ] || { kill -- "-$pid" 2>/dev/null || login__kill_tree "$pid"; break; }
    sleep 0.2
  done
  wait "$pid" 2>/dev/null; rc=$?
  login__kill_stale "${LOGIN_HP:-}"     # its helper may outlive kubectl (never the login screen's own)
  [ "$rc" != 0 ] || return 0
  if login_err_check "$err"; then LOGIN_URL="$(login_url_of "$err")"; return 1; fi
  return 2
}

# before the dashboard (and before one-shot commands): log in first when it is due
login_preflight() {
  [ "${KDASH_LOGIN_CHECK:-1}" = 1 ] || return 0
  local st; st="$(login__cache_state 2>/dev/null)"
  case "$st" in noplugin|valid) return 0 ;; esac
  login_probe; case $? in 0|2) return 0 ;; esac
  audit LOGIN_NEEDED "context=$CTX_NAME when=start cache=$st"
  if [ -t 0 ] && [ -t 1 ] && [ -r /dev/tty ]; then
    login_interactive start; return 0
  fi
  printf 'kdash: the OIDC login for context %s has expired - run kdash (or: kubectl --context %s auth whoami) in a terminal to log in\n' "$CTX_NAME" "$CTX_NAME" >&2
  return 4
}

login__box() { # url [more urls] -> prominent box + help for a callback on this host
  local url="$1" host port user code more
  host="$(hostname -f 2>/dev/null || hostname)"; user="${SUDO_USER:-${USER:-$(id -un)}}"
  code="$(grep -oiE '(user |verification |device )?code[^A-Za-z0-9]{1,4}[A-Z0-9]{3,5}-?[A-Z0-9]{3,5}' "$TMPD/login.err" 2>/dev/null | grep -oE '[A-Z0-9]{3,5}-?[A-Z0-9]{3,5}$' | head -n 1)"
  {
    printf '\n\033[1;7m  OPEN THIS URL IN YOUR BROWSER  \033[0m   (Ctrl+click or copy it; the whole line is the URL)\n'
    # the URL alone on its own line, no box characters, so terminals detect and copy it whole
    printf '\n\033[1m%s\033[0m\n\n' "$url"
    shift; for more in "$@"; do printf '  also printed: %s\n' "$more"; done
    [ -z "$code" ] || printf '\033[1;7m  CODE TO ENTER ON THAT PAGE: %s  \033[0m\n\n' "$code"
    case "$url" in
      http://localhost:*|http://127.0.0.1:*|http://localhost/*|http://127.0.0.1/*)
        port="${url#http://*:}"; port="${port%%/*}"; case "$port" in ''|*[!0-9]*) port=8000 ;; esac
        printf '  This address is on THIS host (%s): after you sign in, the browser is sent back to port %s here.\n' "$host" "$port"
        printf '  From a browser on your PC, forward the port first (in a new local terminal), then open the URL:\n'
        printf '\033[1m      ssh -L %s:localhost:%s %s@%s\033[0m\n' "$port" "$port" "$user" "$host"
        printf '  MobaXterm: Tunneling > New SSH tunnel > Local port forwarding: %s -> localhost:%s through %s.\n' "$port" "$port" "$host"
        printf '  No tunnel possible? Ask for --grant-type=authcode-keyboard (or device-code) in the kubeconfig:\n'
        printf '  the helper then prints the identity provider URL and asks for a code instead.\n' ;;
      *) printf '  Sign in there. If the page shows a code, type it at the prompt here and press Enter.\n' ;;
    esac
    printf '\n  Waiting for the login to finish ... (Ctrl-C cancels)\n\n'
  } > /dev/tty
}

# Run the login helper in the foreground; returns 0 when kubectl works again.
login_interactive() { # start | session [auto]
  local when="${1:-session}" auto="${2:-}" f="$TMPD/login.err" out="$TMPD/login.out" w rc key ok=0 t0=$SECONDS
  local bdir="$TMPD/login-browser" hp n elsewhere iss cid
  IFS=$'\t' read -r iss cid <<< "$(login__issuer 2>/dev/null)"
  login__argv
  [ "$when" = start ] || toolkit_cancel 2>/dev/null
  login__kill_stale
  printf '\033[2J\033[H\033[?25h' > /dev/tty
  [ "$when" = start ] || { [ "${ALTSCR:-1}" = 1 ] && printf '\033[?1049l' > /dev/tty; }
  while IFS= read -rsn1 -t 0.01 _flush </dev/tty; do :; done
  stty sane </dev/tty 2>/dev/null || true
  while :; do
    : > "$f"; : > "$out"
    printf '\033[1;7m KDASH | OIDC LOGIN | context %s \033[0m\n\n' "$CTX_NAME" > /dev/tty
    printf '  Your login for context %s %s%s. The login helper starts now and shows a URL:\n' "$CTX_NAME" "$([ -n "$auto" ] && printf 'has expired - kdash opened the login for you' || printf 'is needed')" "$([ "$when" = start ] && printf ' before kdash can read anything' || printf ' - the dashboard keeps its last data meanwhile')" > /dev/tty
    printf '  open it, sign in, and kdash continues by itself.\n' > /dev/tty
    [ -z "$iss" ] || printf '\n  \033[2missuer   %s%s\033[0m\n' "$iss" "${cid:+   client $cid}" > /dev/tty
    audit LOGIN_START "context=$CTX_NAME when=$when${auto:+ auto=1}"
    login__browser_dir "$bdir" 2>/dev/null
    ( i=0; hinted=0; while [ "$i" -lt 3000 ]; do
        u="$(login_urls_of "$f")"; if [ -n "$u" ]; then sleep 0.3; login__box $(login_urls_of "$f"); exit 0; fi
        # a helper that opened a "browser" instead of printing the URL: the stand-in recorded it
        if [ -s "$bdir/url" ]; then sleep 0.3; [ -n "$(login_urls_of "$f")" ] && { login__box $(login_urls_of "$f"); exit 0; }
          printf '\n  \033[2m(the login helper tried to open a browser on this host - its URL was caught instead)\033[0m\n' > /dev/tty
          login__box $(awk '!s[$0]++' "$bdir/url" | head -n 3); exit 0; fi
        if [ "$hinted" = 0 ] && [ "$i" -ge $(( ${KDASH_LOGIN_NOURL_HINT:-8} * 5 )) ]; then hinted=1
          { printf '\n  The login helper has not printed a URL yet. It may have opened a browser on this host\n'
            printf '  (DISPLAY=%s), be waiting for a code, or be stuck. Ctrl-C stops it; then r tries again.\n\n' "${DISPLAY:-unset}"; } > /dev/tty
        fi
        sleep 0.2; i=$((i + 1)); done ) & w=$!
    trap ':' INT
    elsewhere=0; n=0
    login__env "$bdir" "$LOGIN_KUBECTL" "${LOGIN_ARGS[@]}" auth whoami < /dev/tty > "$out" 2> >(tee -a "$f" > /dev/tty) & hp=$!
    LOGIN_HP="$hp"
    # meanwhile, every KDASH_LOGIN_POLL s once the URL is out: a login completed in another
    # terminal (or a helper that never returns) must not keep kdash waiting
    while kill -0 "$hp" 2>/dev/null; do
      sleep 1; n=$((n + 1))
      [ $((n % ${KDASH_LOGIN_POLL:-5})) -eq 0 ] || continue
      [ -n "$(login_urls_of "$f")" ] || [ -s "$bdir/url" ] || [ "$n" -ge 20 ] || continue
      if login__poll_ok; then elsewhere=1; login__kill_tree "$hp"; break; fi
    done
    wait "$hp" 2>/dev/null; rc=$?
    LOGIN_HP=""; login__kill_stale        # nothing of this attempt keeps running (port 8000, provider polling)
    [ "$elsewhere" = 0 ] || rc=0
    trap 'AUDIT_SIG=INT; cleanup; exit 0' INT
    kill "$w" 2>/dev/null; wait "$w" 2>/dev/null
    if [ "$elsewhere" = 1 ]; then
      printf '\n  \033[1mThe API answers now - the login was completed%s.\033[0m\n' "$([ -s "$out" ] && printf '' || printf ' (here or in another terminal)')" > /dev/tty
      [ -s "$out" ] || "$LOGIN_KUBECTL" "${LOGIN_ARGS[@]}" auth whoami --request-timeout=10s < /dev/null > "$out" 2>/dev/null || true
    fi
    sleep 0.2
    # an old cluster without "auth whoami": the token is there if any read works now
    if [ "$rc" != 0 ] && ! login_err_check "$f" && grep -qiE "unknown command|could not find the requested resource|doesn.t have a resource|not found" "$f"; then
      "$LOGIN_KUBECTL" "${LOGIN_ARGS[@]}" version --request-timeout=10s < /dev/null > /dev/null 2>> "$f" && rc=0
    fi
    if [ "$rc" = 0 ]; then
      LOGIN_USER="$(awk '/^Username/ { $1 = ""; sub(/^ +/, ""); print; exit }' "$out")"
      printf '\n\033[1;32m  Logged in%s.\033[0m kdash continues ...\n' "${LOGIN_USER:+ as $LOGIN_USER}" > /dev/tty
      rm -f "${TOOLKIT_DIR:-/nonexistent}/fmea-access.tsv" 2>/dev/null
      audit LOGIN_OK "context=$CTX_NAME user=${LOGIN_USER:-?} seconds=$((SECONDS - t0))$([ "$elsewhere" = 1 ] && printf ' via=poll')$([ -s "$bdir/url" ] && printf ' url=captured')"
      ok=1; sleep 1; break
    fi
    audit LOGIN_FAILED "context=$CTX_NAME rc=$rc"
    printf '\n\033[1;31m  The login did not complete (rc=%s).\033[0m Last messages:\n' "$rc" > /dev/tty
    tail -n 4 "$f" | sed 's/^/    /' > /dev/tty
    if grep -qiE 'discovery error|openid-configuration' "$f" && grep -qiE 'dial tcp|no such host|timeout|refused|x509|certificate' "$f"; then
      printf '\n  \033[1mThe identity provider%s cannot be reached from this host\033[0m (network, proxy, DNS or its certificate) -
  no login can work until it can. Check: curl -sS %s/.well-known/openid-configuration\n' "${iss:+ $iss}" "${iss:-ISSUER}" > /dev/tty
    fi
    printf '\n  r try again   c continue without login (reads will fail)   q quit kdash  > ' > /dev/tty
    IFS= read -rsn1 key </dev/tty || key=q
    printf '\n' > /dev/tty
    # c: the choice holds - no reads (they would start more logins) and no automatic login until L
    case "$key" in r|R) printf '\033[2J\033[H' > /dev/tty; continue ;; c|C) LOGIN_NEEDED=1; LOGIN_AUTO_DONE=1; break ;; *) cleanup 2>/dev/null; exit 4 ;; esac
  done
  if [ "$ok" = 1 ]; then
    rm -rf "$TMPD/fetch-job" "$TMPD/toolkit-next" "$TMPD/certq"
    LOGIN_NEEDED=0; LOGIN_URL=""; SPEC_REASON=""; LOGIN_AUTO_DONE=0
    FETCH_NEXT=0; FETCH_FAILURES=0; SPEC_AT=0; LAST=0; TOOLKIT_NEXT=0
    CERTQ_NEXT=0; CERT_BADGE=""
  fi
  if [ "$when" != start ]; then
    printf '\033[?25l' > /dev/tty
    [ "${ALTSCR:-1}" = 1 ] && printf '\033[?1049h' > /dev/tty
    printf '\033[2J' > /dev/tty
    if [ "$ok" = 1 ]; then flash "logged in${LOGIN_USER:+ as $LOGIN_USER} - reading data again" 6; else flash "still not logged in - press L to log in (the URL is shown again)" 600; fi
  fi
  [ "$ok" = 1 ]
}

# Background reads that hit an expired login do not fail at once: the helper prints its
# URL and waits for a browser until the guard stops it (12 s per call, many calls).
# Their error files are watched while they run, so the login is noticed in a second.
login_watch_jobs() {
  [ "${LOGIN_NEEDED:-0}" != 1 ] || return 0
  local f
  for f in "$TMPD"/fetch-job/*.err "$TMPD"/toolkit-next/*.err "$TMPD"/certq/*.err; do
    [ -s "$f" ] || continue
    { login_prompted "$f" || grep -qiE 'oidc-login|kubelogin|get-token|getting credentials' "$f" 2>/dev/null; } || continue
    login_note_failure "$f" || continue
    toolkit_cancel; rm -rf "$TMPD/certq"; login__kill_stale
    SPEC_REASON="OIDC login needed - press L (the login URL is shown, kdash continues afterwards)"
    return 0
  done
  return 0
}

# Not logged in any more: open the login (and its URL) by itself, once per expiry.
# After "c continue without login" it waits for L; KDASH_LOGIN_AUTO=0 always waits for L.
login_auto_maybe() {
  [ "${LOGIN_NEEDED:-0}" = 1 ] && [ "${KDASH_LOGIN_AUTO:-1}" = 1 ] && [ "${LOGIN_AUTO_DONE:-0}" = 0 ] || return 1
  LOGIN_AUTO_DONE=1
  login_interactive session auto
  return 0
}

# a background read failed: is it the login? (called with that read's error file)
login_note_failure() { # errfile
  [ "${KDASH_LOGIN_CHECK:-1}" = 1 ] || return 1
  login_err_check "$1" || return 1
  if [ "$LOGIN_NEEDED" != 1 ]; then
    LOGIN_NEEDED=1; LOGIN_URL="$(login_url_of "$1")"   # shown by the login screen, which runs the helper again
    audit LOGIN_NEEDED "context=$CTX_NAME when=session"
    declare -F flash >/dev/null && flash "OIDC LOGIN NEEDED for $CTX_NAME - $([ "${KDASH_LOGIN_AUTO:-1}" = 1 ] && [ "${LOGIN_AUTO_DONE:-0}" = 0 ] && printf 'opening the login' || printf 'press L'): kdash shows the login URL and continues afterwards" 600
    login__kill_stale
  fi
  return 0
}

# ---- FMEA: failure modes, effects and analysis (read-only) ---------------------
# A generic catalogue per Kubernetes resource type, applied to every object the
# signed-in user can read. S = catalogue severity (+ kdash.io/criticality label or
# site file), O = what kdash sees now and in saved runs, D = how early a kdash
# signal fires - and the user's own RBAC: a check the user cannot run is shown as
# "no access" (D 10), never as OK. Action Priority (H/M/L) = the AIAG-VDA 2019 table;
# RPN = S x O x D is shown beside it but never ranks. Nothing here changes anything.

# id kind mode effect cause signal requires S D count sources
fmea_catalogue() {
  cat <<'FMEA_CAT'
POD-01	Pod	CrashLoopBackOff	Restarts; service degraded or down	App error, bad config, failing start	waiting.reason, restartCount	list:pods	7	4	pods	spec
POD-02	Pod	OOMKilled	Restarts, in-flight work lost	Memory limit below need, leak	lastState.terminated.reason, memory vs limit	list:pods	6	4	pods	spec
POD-03	Pod	Pending, unschedulable	New or moved pods never start	No CPU/memory left, taints, affinity, PVC zone	PodScheduled=False, FailedScheduling events	list:pods list:events	7	4	pods	spec events
POD-04	Pod	ImagePullBackOff	Rollouts and scale-up stall	Registry down, wrong tag, expired pull secret	waiting.reason, events	list:pods	6	4	pods	spec
POD-05	Pod	Readiness probe failing	Pod removed from Service endpoints	Slow start, dependency down, strict probe	Ready=False, Unhealthy events	list:pods	6	5	pods	spec
POD-06	Pod	Liveness probe kills a healthy pod	Restart loop under load	Timeout too short for peak latency	Killing / Unhealthy (liveness) events	list:pods list:events	5	6	pods	spec events
POD-07	Pod	Evicted	Pod lost, rescheduled elsewhere	Node pressure, ephemeral storage over limit	status.reason=Evicted	list:pods	5	5	pods	spec
POD-08	Pod	CPU throttled	Latency up, timeouts	CPU limit too low	live CPU vs limit (metrics-server)	list:pods get:pods.metrics.k8s.io	4	6	pods	spec
POD-09	Pod	Stuck Terminating	Replacement and volume release blocked	Finalizer, lost node, preStop hang	deletionTimestamp older than the grace period	list:pods	5	5	pods	pods
WRK-01	Deployment	All replicas unavailable	Service outage	Bad rollout, dependency down	availableReplicas=0	list:deployments.apps	9	4	deployments	fm-deploy
WRK-02	Deployment	Rollout stuck	Mixed versions, less capacity	New pods failing, no room to surge	Progressing=False (ProgressDeadlineExceeded)	list:deployments.apps	6	4	deployments	fm-deploy
WRK-03	Deployment, StatefulSet	Single replica	Outage on any pod or node loss, every drain	Chart or manifest default	spec.replicas=1	list:deployments.apps list:statefulsets.apps	6	2	workloads	fm-deploy fm-sts
WRK-04	StatefulSet	Ordinal stuck, later pods never start	Clustered app below quorum	Pod N not ready, PVC tied to a lost node	readyReplicas < replicas	list:statefulsets.apps list:pods	8	4	statefulsets	fm-sts spec
WRK-05	DaemonSet	Missing on some nodes	Per-node function absent (logs, CNI, CSI)	Taints, resources, image	desired vs ready, misscheduled	list:daemonsets.apps	6	4	daemonsets	fm-ds
WRK-06	Any workload	No requests or limits	Evicted first, noisy neighbour, OOM	Not set in the spec	QoS BestEffort	list:pods	4	2	pods	spec
WRK-07	Any workload	All replicas on one node	One node loss takes every replica	No anti-affinity or topology spread	pod placement	list:pods	7	2	workloads	spec
JOB-01	Job	Failed after backoffLimit	Batch work not done	App error, missing input	Failed condition	list:jobs.batch	6	5	jobs	fm-jobs
JOB-02	CronJob	Not running on schedule	Missed backups, stale data	suspend, missed deadline, concurrency Forbid	lastSuccessfulTime vs lastScheduleTime	list:cronjobs.batch	7	4	cronjobs	fm-cron
PVC-01	PersistentVolumeClaim	Pending	Pod cannot start	No StorageClass, provisioner down, quota	phase=Pending, ProvisioningFailed events	list:persistentvolumeclaims	8	4	pvcs	pvcs
PVC-02	PersistentVolumeClaim	Volume full	Write errors, database stops	Growth without expansion	kubelet volume stats (Prometheus), used vs capacity	list:persistentvolumeclaims	8	3	pvcs	pvcs volume-metrics?
PVC-03	PVC / PersistentVolume	Attach or mount failure	Pod stuck ContainerCreating	RWO multi-attach, CSI down, lost node	FailedAttachVolume / FailedMount events, lost claims	list:persistentvolumeclaims list:events	7	5	pvcs	pvcs events
PVC-04	PersistentVolume	Reclaim policy Delete on stateful data	Data deleted with the claim	StorageClass default	persistentVolumeReclaimPolicy	list:persistentvolumes@	7	2	storageclasses	pvs
PVC-05	StorageClass	Expansion not allowed	A full volume cannot grow online	allowVolumeExpansion false	StorageClass field	list:storageclasses.storage.k8s.io@	4	2	storageclasses	storageclasses
SVC-01	Service	No endpoints	Callers get connection refused	Selector mismatch, no ready pods	EndpointSlices empty	list:services list:endpointslices.discovery.k8s.io	8	4	services	services endpoints
SVC-02	Service	targetPort not exposed by the pods	Traffic reaches nothing	Spec drift	targetPort vs container ports	list:services list:pods	6	3	services	services pods
SVC-03	Service (LoadBalancer)	External IP pending	Not reachable from outside	LB controller down, IP pool exhausted	status.loadBalancer empty	list:services	7	4	services	fm-svclb
ING-01	Ingress	Backend Service missing	503 for that host or path	Rename, wrong namespace	backend lookup	list:ingresses.networking.k8s.io list:services	7	3	ingresses	ingresses services
ING-02	Ingress	TLS secret missing or expiring	Clients fail TLS	Secret not renewed	ingress TLS probe, days left	list:ingresses.networking.k8s.io	7	2	ingresses	ingresses
NET-01	NetworkPolicy	Default deny blocks needed traffic	Calls time out	New policy without an allow rule	policies selecting all pods without rules	list:networkpolicies.networking.k8s.io	6	8	netpols	fm-netpol
DNS-01	CoreDNS	DNS failing	Every call by service name fails	CoreDNS pods down or overloaded	CoreDNS ready count	list:pods#kube-system	9	4	dns	fm-dns
CFG-01	ConfigMap, Secret	Referenced object missing	CreateContainerConfigError	Not created, wrong name or key	waiting.reason, FailedMount events	list:pods list:events	7	4	pods	spec events
CFG-02	Secret	Certificate inside it expiring or broken	App TLS or auth fails	Not rotated, wrong chain or key	certificates in Secrets: notAfter, chain, key (and cert-manager)	list:secrets	6	2	certificates	sm-secrets
HPA-01	HorizontalPodAutoscaler	Cannot read metrics	No scaling under load	metrics-server down, missing requests	ScalingActive=False	list:horizontalpodautoscalers.autoscaling	6	4	hpas	fm-hpa
HPA-02	HorizontalPodAutoscaler	Pinned at maxReplicas	Overload, latency	Max set too low	currentReplicas = maxReplicas	list:horizontalpodautoscalers.autoscaling	5	5	hpas	fm-hpa
PDB-01	PodDisruptionBudget	Allows 0 disruptions	Drains and upgrades hang	minAvailable equals replicas	disruptionsAllowed=0	list:poddisruptionbudgets.policy	5	2	pdbs	fm-pdb
PDB-02	PodDisruptionBudget	Missing for a multi-replica workload	A drain can take all replicas	Not defined	no PDB selects the workload	list:poddisruptionbudgets.policy list:deployments.apps	5	2	workloads	fm-pdb fm-deploy hpods
QTA-01	ResourceQuota	Quota nearly used up	New pods and PVCs rejected	Growth	used vs hard at 90 % or more	list:resourcequotas	7	3	quotas	fm-quota
NOD-01	Node	NotReady	Its pods evicted after the timeout	Kubelet, network, hardware	Ready condition	list:nodes@	8	4	nodes	rb-nodes
NOD-02	Node	Memory, disk or PID pressure	Evictions	Workload growth, logs, images	node conditions	list:nodes@	7	4	nodes	fm-nodes
NOD-03	Node	Cordoned and forgotten	Capacity lost	Maintenance not closed	spec.unschedulable	list:nodes@	4	2	nodes	fm-nodes
NOD-04	Node	Limits far above allocatable	OOM and throttling at peak	Limits not sized	memory limits of all pods vs allocatable	list:nodes@	5	3	nodes	spec rb-nodes
CP-01	API server	Unreachable or slow	No changes; controllers stall	Control plane down, overload	readyz checks, kdash read failures	get:/readyz	10	3	cluster	readyz
CP-02	etcd	Quorum lost or unhealthy	Cluster read-only	Member loss, disk, no defrag	readyz etcd check	get:/readyz	10	5	cluster	readyz
CP-03	Cluster backup	No recent backup	Restore impossible	Schedule off, target failing	etcd snapshot age (RKE2/K3s)	list:etcdsnapshotfiles.k3s.cattle.io@	10	3	cluster	rb-snapshots
CRT-01	Cluster certificates	API or kubelet cert expiring	kubectl and node calls fail	Rotation not happening	certificate probes, days left		10	2	cluster	certs
ADM-01	Admission webhook	Webhook down with failurePolicy Fail	Creates and updates in scope rejected	Webhook pod down, cert expired	webhook Service endpoints and cert	list:validatingwebhookconfigurations.admissionregistration.k8s.io@ list:mutatingwebhookconfigurations.admissionregistration.k8s.io@	9	4	webhooks	fm-webhooks
CRD-01	Operator / CRD	Operator not running	Custom resources not reconciled	Pod crash, RBAC change	operator workload available count	list:deployments.apps	6	5	deployments	fm-deploy
ACC-01	RBAC, ServiceAccount	Permission denied	App or controller actions fail	Role or binding changed	forbidden in events	list:events	6	6	cluster	events
ACC-02	Operator login (OIDC)	Provider unreachable or token expired	Operators cannot act	Network, token lifetime	kdash login check		8	3	cluster	login
NS-01	Namespace	Stuck Terminating	Namespace cannot be recreated	Finalizers, unavailable API service	phase=Terminating	list:namespaces@	4	4	namespaces	fm-ns
FMEA_CAT
}

# AIAG-VDA 2019 action priority (same answer on every host)
FMEA_AP_AWK='
function ap(s, o, d) {
  if (s <= 1) return "L"
  if (s <= 3) return (o >= 8 && d >= 5) ? "M" : "L"
  if (s <= 6) {
    if (o >= 8) return d >= 5 ? "H" : "M"
    if (o >= 6) return d >= 2 ? "M" : "L"
    if (o >= 4) return d >= 7 ? "M" : "L"
    return "L" }
  if (s <= 8) {
    if (o >= 8) return "H"
    if (o >= 6) return d >= 2 ? "H" : "M"
    if (o >= 4) return d >= 7 ? "H" : "M"
    if (o >= 2) return d >= 5 ? "M" : "L"
    return "L" }
  if (o >= 6) return "H"
  if (o >= 4) return d >= 2 ? "H" : "M"
  if (o >= 2) return d >= 7 ? "H" : (d >= 5 ? "M" : "L")
  return "L"
}'

fmea_age() { local at; at="$(cat "${TOOLKIT_DIR:-/nonexistent}/fmea.at" 2>/dev/null)"; case "$at" in [0-9]*) printf '%s' "$(( $(date +%s) - at ))" ;; *) printf 999999 ;; esac; }
fmea__site_files() { local f; for f in /etc/kdash-fmea.tsv "${XDG_CONFIG_HOME:-$HOME/.config}/kdash-fmea.tsv"; do [ -r "$f" ] && printf '%s\n' "$f"; done; return 0; }
fmea__runs_dir() { printf '%s/fmea/runs/%s_%s' "${REPORT_DIR:-$HOME/kdash_reports}" "$(safe_name "${CTX_NAME:-ctx}")" "$(safe_name "${NS:-ns}")"; }

# the catalogue with the site files applied: same columns + owner status manualO
# site file: id kind mode effect cause signal requires S D owner status [O]
#            (a known id overrides the non-empty fields; a new id adds a manual row)
#            "criticality<TAB>NAMESPACE[/KIND/NAME]<TAB>low|normal|critical"
fmea__catalogue_merged() {
  local files; files="$(fmea__site_files)"
  { fmea_catalogue | sed 's/^/C\t/'
    [ -z "$files" ] || printf '%s\n' "$files" | while IFS= read -r f; do sed -e 's/\r$//' -e '/^[[:space:]]*#/d' -e '/^[[:space:]]*$/d' "$f" | sed 's/^/O\t/'; done
  } | LC_ALL=C awk -F'\t' 'BEGIN { OFS = "\t" }
      $1 == "C" { n++; id[n] = $2; for (i = 2; i <= 12; i++) V[$2, i] = $i; known[$2] = 1; next }
      $1 == "O" && $2 == "criticality" { next }
      $1 == "O" && tolower($2) != "id" && $2 != "" {
        if (!($2 in known)) { n++; id[n] = $2; known[$2] = 1; man[$2] = 1
          V[$2, 3] = "Site"; V[$2, 4] = "site failure mode"; V[$2, 9] = 5; V[$2, 10] = 10; V[$2, 11] = "cluster"; V[$2, 12] = "manual" }
        for (i = 3; i <= 10; i++) if ($i != "") V[$2, i] = $i
        if ($11 != "") OW[$2] = $11; if ($12 != "") STA[$2] = $12; if ($13 ~ /^[0-9]+$/) MO[$2] = $13
        ov[$2] = 1 }
      END { for (k = 1; k <= n; k++) { x = id[k]; line = x
              for (i = 3; i <= 12; i++) line = line "\t" V[x, i]
              print line, OW[x], STA[x], (x in man ? (x in MO ? MO[x] : 5) : ""), (x in ov ? "site" : "") } }'
}

fmea__site_crit() { # -> "NAMESPACE[/KIND/NAME]<TAB>level" lines from the site files
  local files; files="$(fmea__site_files)"; [ -n "$files" ] || return 0
  printf '%s\n' "$files" | while IFS= read -r f; do awk -F'\t' '$1 == "criticality" && $2 != "" { print $2 "\t" tolower($3) }' "$f"; done
}

# ---- access: who is this, and what may they read (kubectl auth whoami / can-i) ----
fmea__perm_args() { # perm -> can-i words; NS scope from the dashboard
  local p="$1" verb res
  verb="${p%%:*}"; res="${p#*:}"
  case "$res" in
    /*) printf '%s\n%s\n' "$verb" "$res" ;;
    *@) printf '%s\n%s\n--all-namespaces\n' "$verb" "${res%@}" ;;   # cluster scope: without -A the context namespace is used, and a namespace Role on "*" answers yes
    *'#'*) printf '%s\n%s\n-n\n%s\n' "$verb" "${res%%#*}" "${res#*#}" ;;
    *) printf '%s\n%s\n' "$verb" "$res"
       if [ "${ALL_NS:-0}" = 1 ]; then printf -- '--all-namespaces\n'; else printf -- '-n\n%s\n' "${NS:-default}"; fi ;;
  esac
}
fmea_access() { # [force] -> $TOOLKIT_DIR/fmea-access.tsv
  local f="$TOOLKIT_DIR/fmea-access.tsv" key now perms p i=0 user groups w d
  local -a args pids
  key="${CTX_NAME:-?}|${NS:-?}|${ALL_NS:-0}"; now=$(date +%s)
  if [ "${1:-}" != force ] && [ -s "$f" ]; then
    IFS=$'\t' read -r _ k at < "$f"
    if [ "$k" = "$key" ] && [ $((now - ${at:-0})) -lt "${KDASH_FMEA_ACCESS_TTL:-300}" ]; then return 0; fi
  fi
  d="$TOOLKIT_DIR/fmea-access.d"; rm -rf "$d"; mkdir -p "$d"
  # who: the OIDC token's user and groups (Kubernetes 1.28+); older: the kubeconfig user
  "${KC[@]}" auth whoami --request-timeout=8s > "$d/whoami" 2>/dev/null || true
  user="$(awk '$1 == "Username" { $1 = ""; sub(/^ +/, ""); print; exit }' "$d/whoami")"
  groups="$(awk '$1 == "Groups" { $1 = ""; sub(/^ +/, ""); gsub(/[][]/, ""); print; exit }' "$d/whoami")"
  [ -n "$user" ] || user="$("${KC[@]}" config view --minify -o 'jsonpath={.contexts[0].context.user}' 2>/dev/null)"
  perms="$(fmea__catalogue_merged | awk -F'\t' '{ n = split($7, a, " "); for (i = 1; i <= n; i++) if (!(a[i] in s)) { s[a[i]] = 1; print a[i] } }')"
  # each permission once, a few at a time (each call is capped by the kubectl guard)
  for p in $perms; do
    args=(); while IFS= read -r w; do args+=("$w"); done < <(fmea__perm_args "$p")
    ( r="$("${KC[@]}" auth can-i "${args[@]}" --request-timeout=8s 2>"$d/$i.err" | head -1)"
      case "$r" in yes*) r=yes ;; no*) r=no ;; *) r=error ;; esac
      printf 'P\t%s\t%s\n' "$p" "$r" > "$d/$i.p" ) &
    pids+=("$!"); i=$((i + 1))
    if [ "${#pids[@]}" -ge "${KDASH_FMEA_PARALLEL:-8}" ]; then wait "${pids[@]}" 2>/dev/null; pids=(); fi
  done
  [ "${#pids[@]}" = 0 ] || wait "${pids[@]}" 2>/dev/null
  { printf '#\t%s\t%s\n' "$key" "$now"; printf 'U\t%s\t%s\n' "${user:-unknown}" "${groups:--}"
    cat "$d"/*.p 2>/dev/null | LC_ALL=C sort; } > "$f.new" && mv -f "$f.new" "$f"
  rm -rf "$d"
  FMEA_ACCESS_FRESH=1
  return 0
}

# ---- extra reads (only for this view): same status handling as the health reads ----
fmea__read() { # source template [kubectl get words...]  (no words: SCOPE)
  local source="$1" template="$2"; shift 2
  local tmp="$TOOLKIT_DIR/health-$source.new" err="$TOOLKIT_DIR/health-$source.err"
  local -a words=("$@"); [ "${#words[@]}" -gt 0 ] || return 1
  if "${KC[@]}" get "${words[@]}" --request-timeout="${KDASH_HEALTH_TIMEOUT:-12s}" -o "go-template=$template" > "$tmp" 2> "$err"; then
    mv -f "$tmp" "$TOOLKIT_DIR/health-$source.raw"; health__status "$source" ok 'successful API read'
  else rm -f "$tmp"; : > "$TOOLKIT_DIR/health-$source.raw"; health__failure "$source" "$err"; fi
  return 0
}
FMEA_T_CRIT='{{with .metadata.labels}}{{index . "kdash.io/criticality"}}{{end}}'
fmea_reads() {
  local -a sc=("${SCOPE[@]}")
  fmea__read fm-deploy "{{range .items}}FD|{{.metadata.namespace}}|{{.metadata.name}}|{{.spec.replicas}}|{{.status.availableReplicas}}|{{.status.readyReplicas}}|{{range .status.conditions}}{{if eq .type \"Progressing\"}}{{.reason}}{{end}}{{end}}|$FMEA_T_CRIT|{{with .spec.template.spec.affinity}}{{if .podAntiAffinity}}aa{{end}}{{end}}{{if .spec.template.spec.topologySpreadConstraints}}ts{{end}}|{{range \$k, \$v := .spec.selector.matchLabels}}{{\$k}}={{\$v}},{{end}}{{\"\\n\"}}{{end}}" deployments.apps "${sc[@]}"
  fmea__read fm-sts "{{range .items}}FS|{{.metadata.namespace}}|{{.metadata.name}}|{{.spec.replicas}}|{{.status.readyReplicas}}|{{.status.currentReplicas}}||$FMEA_T_CRIT||{{range \$k, \$v := .spec.selector.matchLabels}}{{\$k}}={{\$v}},{{end}}{{\"\\n\"}}{{end}}" statefulsets.apps "${sc[@]}"
  fmea__read fm-ds "{{range .items}}FA|{{.metadata.namespace}}|{{.metadata.name}}|{{.status.desiredNumberScheduled}}|{{.status.numberReady}}|{{.status.numberMisscheduled}}|{{.status.numberUnavailable}}|$FMEA_T_CRIT{{\"\\n\"}}{{end}}" daemonsets.apps "${sc[@]}"
  fmea__read fm-jobs "{{range .items}}FJ|{{.metadata.namespace}}|{{.metadata.name}}|{{range .status.conditions}}{{if eq .type \"Failed\"}}{{.status}}{{end}}{{end}}|{{range .status.conditions}}{{if eq .type \"Failed\"}}{{.reason}}{{end}}{{end}}|{{range .metadata.ownerReferences}}{{if eq .kind \"CronJob\"}}{{.name}}{{end}}{{end}}|{{.status.startTime}}|$FMEA_T_CRIT{{\"\\n\"}}{{end}}" jobs.batch "${sc[@]}"
  fmea__read fm-cron "{{range .items}}FR|{{.metadata.namespace}}|{{.metadata.name}}|{{.spec.schedule}}|{{.spec.suspend}}|{{.status.lastScheduleTime}}|{{.status.lastSuccessfulTime}}|$FMEA_T_CRIT{{\"\\n\"}}{{end}}" cronjobs.batch "${sc[@]}"
  fmea__read fm-hpa "{{range .items}}FH|{{.metadata.namespace}}|{{.metadata.name}}|{{.spec.minReplicas}}|{{.spec.maxReplicas}}|{{.status.currentReplicas}}|{{range .status.conditions}}{{if eq .type \"ScalingActive\"}}{{.status}}{{end}}{{end}}|{{range .status.conditions}}{{if eq .type \"ScalingActive\"}}{{.reason}}{{end}}{{end}}|{{.spec.scaleTargetRef.kind}}/{{.spec.scaleTargetRef.name}}{{\"\\n\"}}{{end}}" horizontalpodautoscalers.autoscaling "${sc[@]}"
  fmea__read fm-pdb "{{range .items}}FB|{{.metadata.namespace}}|{{.metadata.name}}|{{.status.disruptionsAllowed}}|{{.status.currentHealthy}}|{{.status.desiredHealthy}}|{{.status.expectedPods}}|{{range \$k, \$v := .spec.selector.matchLabels}}{{\$k}}={{\$v}},{{end}}{{\"\\n\"}}{{end}}" poddisruptionbudgets.policy "${sc[@]}"
  fmea__read fm-quota "{{range .items}}FU|{{.metadata.namespace}}|{{.metadata.name}}|{{range \$k, \$v := .status.hard}}{{\$k}}={{\$v}},{{end}}|{{range \$k, \$v := .status.used}}{{\$k}}={{\$v}},{{end}}{{\"\\n\"}}{{end}}" resourcequotas "${sc[@]}"
  fmea__read fm-netpol "{{range .items}}FY|{{.metadata.namespace}}|{{.metadata.name}}|{{if .spec.podSelector.matchLabels}}some{{else if .spec.podSelector.matchExpressions}}some{{else}}all{{end}}|{{range .spec.policyTypes}}{{.}},{{end}}|{{with .spec.ingress}}{{len .}}{{else}}0{{end}}|{{with .spec.egress}}{{len .}}{{else}}0{{end}}{{\"\\n\"}}{{end}}" networkpolicies.networking.k8s.io "${sc[@]}"
  fmea__read fm-svclb "{{range .items}}{{if eq .spec.type \"LoadBalancer\"}}FL|{{.metadata.namespace}}|{{.metadata.name}}|{{range .status.loadBalancer.ingress}}{{.ip}}{{.hostname}},{{end}}{{\"\\n\"}}{{end}}{{end}}" services "${sc[@]}"
  fmea__read fm-nodes "{{range .items}}FN|{{.metadata.name}}|{{range .status.conditions}}{{if eq .status \"True\"}}{{if ne .type \"Ready\"}}{{.type}},{{end}}{{end}}{{end}}|{{if .spec.unschedulable}}cordoned{{end}}{{\"\\n\"}}{{end}}" nodes
  fmea__read fm-ns "{{range .items}}FX|{{.metadata.name}}|{{.status.phase}}|$FMEA_T_CRIT{{\"\\n\"}}{{end}}" namespaces
  fmea__read fm-dns "{{range .items}}FC|{{.metadata.name}}|{{.status.phase}}|{{range .status.conditions}}{{if eq .type \"Ready\"}}{{.status}}{{end}}{{end}}{{\"\\n\"}}{{end}}" pods -n kube-system -l k8s-app=kube-dns
  fmea__read fm-webhooks "{{range .items}}{{\$o := .}}{{range .webhooks}}FW|{{\$o.kind}}|{{\$o.metadata.name}}|{{.name}}|{{.failurePolicy}}|{{with .clientConfig.service}}{{.namespace}}|{{.name}}{{else}}|{{end}}{{\"\\n\"}}{{end}}{{end}}" validatingwebhookconfigurations.admissionregistration.k8s.io,mutatingwebhookconfigurations.admissionregistration.k8s.io
  # the Services behind failurePolicy=Fail webhooks: do they have ready endpoints?
  : > "$TOOLKIT_DIR/health-fm-whep.raw"
  if [ "$(health__state fm-webhooks)" = ok ]; then
    awk -F'|' '$1 == "FW" && $5 == "Fail" && $6 != "" && !s[$6 "|" $7]++ { print $6 "\t" $7 }' "$TOOLKIT_DIR/health-fm-webhooks.raw" | head -n "${KDASH_FMEA_WEBHOOK_MAX:-10}" |
    while IFS=$'\t' read -r wns wsvc; do
      if "${KC[@]}" get endpointslices.discovery.k8s.io -n "$wns" -l "kubernetes.io/service-name=$wsvc" --request-timeout=8s \
           -o 'go-template={{range .items}}{{range .endpoints}}{{if .conditions.ready}}R{{"\n"}}{{end}}{{end}}{{end}}' > "$TOOLKIT_DIR/fm-whep.tmp" 2>/dev/null; then
        printf 'FE|%s|%s|%s\n' "$wns" "$wsvc" "$(grep -c R "$TOOLKIT_DIR/fm-whep.tmp")" >> "$TOOLKIT_DIR/health-fm-whep.raw"
      else printf 'FE|%s|%s|?\n' "$wns" "$wsvc" >> "$TOOLKIT_DIR/health-fm-whep.raw"; fi
    done
    rm -f "$TOOLKIT_DIR/fm-whep.tmp"
  fi
  # API server and etcd: /readyz?verbose is readable by every authenticated user by default
  if "${KC[@]}" get --raw '/readyz?verbose' --request-timeout=8s > "$TOOLKIT_DIR/health-readyz.raw" 2> "$TOOLKIT_DIR/health-readyz.err"; then
    health__status readyz ok 'successful API read'
  elif grep -q '\[-\]' "$TOOLKIT_DIR/health-readyz.err" 2>/dev/null; then
    # not ready: HTTP 500, the check list comes back inside the error text
    sed 's/\\n/\n/g' "$TOOLKIT_DIR/health-readyz.err" | grep -o '\[[+-]\][^[]*' | sed 's/[" ]*$//' > "$TOOLKIT_DIR/health-readyz.raw"
    health__status readyz ok 'API server not ready: see the failed checks'
  else : > "$TOOLKIT_DIR/health-readyz.raw"; health__failure readyz "$TOOLKIT_DIR/health-readyz.err"; fi
  return 0
}

# ---- evaluation: every catalogue mode against every object read ------------------
# -> fmea-hits.tsv: ID OBJECT STATUS(fail|risk) NOW HINTKEY NS CRIT
#    fmea-counts.tsv: COUNTKEY N
fmea_evaluate() {
  local d="$TOOLKIT_DIR" hits="$TOOLKIT_DIR/fmea-hits.tsv"
  : > "$hits"
  # 1. what the instant check already finds now (pods, nodes, services, storage, certs, etcd)
  [ -f "$d/check-findings.tsv" ] || check_findings
  LC_ALL=C awk -F'\t' -v login="${LOGIN_NEEDED:-0}" -v ctx="${CTX_NAME:-cluster}" 'BEGIN { OFS = "\t" }
    { sev = $2; obj = $3; txt = $4; split($5, h, "|"); key = h[1]; ns = h[2]; nm = h[3]
      if (ns != "" && nm != "") obj = ns "/" nm; else if (nm != "") obj = nm
      st = (sev ~ /CRIT/) ? "fail" : "risk"; id = ""
      if (key == "pod-crash") { id = (txt ~ /CreateContainerConfigError/) ? "CFG-01" : "POD-01"; st = "fail" }
      else if (key == "pod-image") { id = "POD-04"; st = "fail" }
      else if (key == "pod-oom") { id = "POD-02"; st = "fail" }
      else if (key == "pod-pending") { id = "POD-03"; st = "fail" }
      else if (key == "pod-notready") { id = (txt ~ /Evicted/) ? "POD-07" : "POD-05"; st = "fail" }
      else if (key == "node") { if (txt ~ /cordoned/) next; id = "NOD-01"; st = "fail" }
      else if (key == "api") { id = "CP-01"; st = "fail"; obj = ctx }
      else if (key == "etcd-snap") { id = "CP-03"; obj = (nm != "" ? nm : "etcd snapshots") }
      else if (key ~ /^svc-(nomatch|notready|noendpoints)$/) { id = "SVC-01"; st = "fail" }
      else if (key == "svc-port") id = "SVC-02"
      else if (key ~ /^ing-(svcmissing|port)$/) { id = "ING-01"; st = "fail" }
      else if (key == "pvc-full") id = "PVC-02"
      else if (key ~ /^(pvc-pending|sc-missing|pod-claimmissing)$/) { id = "PVC-01"; st = "fail" }
      else if (key ~ /^(pvc-lost|pv-missing|pv-claimref)$/) { id = "PVC-03"; st = "fail" }
      else if (key ~ /^cert-(node|rke2file|endpoint|ca|kubeconfig-ca|apiservice)$/) id = "CRT-01"
      else if (key == "cert-webhook") id = "ADM-01"
      else if (key == "cert-ingress") id = "ING-02"
      else if (key == "cert-manager") id = "CFG-02"
      else if (key ~ /^sm-(expired|expiring|key|weak|chain|restart)$/) { if (sev ~ /INFO/) next; id = "CFG-02" }
      else if (key == "sm-missing") { id = "CFG-01"; st = "fail" }
      else if (key == "login") id = "ACC-02"
      if (id == "") next
      if (sev ~ /CRIT/ && id ~ /^(CRT|ING-02|CFG-02|ADM|ACC|PVC-02|CP-03)/) st = "fail"
      print id, obj, st, txt, $5, ns, "" }
    END { if (login == "1") print "ACC-02", ctx, "fail", "OIDC login needed for " ctx " - press L", "login", "", "" }
  ' "$d/check-findings.tsv" 2>/dev/null >> "$hits"
  # 2. the modes only FMEA looks at
  LC_ALL=C awk -v now="$(date +%s)" -v cronh="${KDASH_FMEA_CRON_HOURS:-48}" -v ovc="${KDASH_FMEA_OVERCOMMIT:-150}" -v ctx="${CTX_NAME:-cluster}" \
      -v readyz_state="$(health__state readyz)" -v cntf="$d/fmea-counts.tsv" "$TK_TIME_AWK"'
    function kv(s, A,   n, a, i, p) { delete A; n = split(s, a, ","); for (i = 1; i <= n; i++) { p = index(a[i], "="); if (p) A[substr(a[i], 1, p - 1)] = substr(a[i], p + 1) } }
    function qty(s,   n, u) { if (s == "") return 0; n = s + 0; u = s; sub(/^[0-9.]+/, "", u)
      if (u == "m") return n / 1000; if (u == "k" || u == "K") return n * 1000; if (u == "M") return n * 1e6; if (u == "G") return n * 1e9; if (u == "T") return n * 1e12
      if (u == "Ki") return n * 1024; if (u == "Mi") return n * 1048576; if (u == "Gi") return n * 1073741824; if (u == "Ti") return n * 1099511627776; return n }
    function hit(id, obj, st, now_, hk, ns, cr) { printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\n", id, obj, st, now_, hk, ns, cr }
    function sub_of(sel, L,   n, a, i, p, k, v) { n = split(sel, a, ","); m = 0
      for (i = 1; i <= n; i++) { if (a[i] == "") continue; p = index(a[i], "="); k = substr(a[i], 1, p - 1); v = substr(a[i], p + 1); m++; if (L[k] != v) return 0 }
      return m > 0 }
    BEGIN { FS = "|"; NOW = now }
    FILENAME !~ /\.tsv$/ && index($0, "<no value>") { gsub(/<no value>/, "") }
    FILENAME ~ /pods\.tsv$/ { if (FNR == 1) next; split($0, P, "\t"); ns = P[2]; pod = P[3]; npods++
      wk = tolower(P[12]); wl = P[13]; node = P[7]
      PN[ns "/" pod] = 1; PWK[ns "/" pod] = wk "/" wl
      if (P[11] == "BestEffort" && wk != "job") { if (wl != "" && wl != "-") { be[ns "|" wk "/" wl]++ } else be[ns "|pod/" pod]++ }
      if (P[16] + 0 > 0 && P[14] != "" && P[14] != "-" && P[14] + 0 >= 0.9 * P[16]) hit("POD-08", ns "/" pod, "fail", "cpu " P[14] "m of " P[16] "m limit", "pod-oom|" ns "|" pod, ns, "")
      if (wl != "" && wl != "-" && wk ~ /^(deployment|statefulset|replicaset)$/ && P[4] == "Running") { g = ns "|" wk "/" wl; gp[g]++; if (!((g, node) in gn)) { gn[g, node] = 1; gnc[g]++; gnode[g] = node } }
      next }
    FILENAME ~ /nodes\.tsv$/ { if (FNR == 1) next; split($0, N, "\t"); if (N[16] + 0 > 0 && N[28] + 0 > N[16] * ovc / 100)
        hit("NOD-04", N[2], "risk", sprintf("memory limits %d%% of allocatable (%d of %d Mi)", 100 * N[28] / N[16], N[28], N[16]), "fm-NOD-04||" N[2], "", ""); next }
    FILENAME ~ /events\.tsv$/ { if (FNR == 1) next; split($0, E, "\t"); ens = E[1]; ek = E[2]; en = E[3]; er = E[6]; em = E[10]
      if (ek == "Pod" && er == "Killing" && em ~ /[Ll]iveness/) { if (!lk[ens "/" en]++) hit("POD-06", ens "/" en, "fail", "killed by its liveness probe (" E[7] "x)", "fm-POD-06|" ens "|" en, ens, "") }
      else if (ek == "Pod" && er == "Unhealthy" && em ~ /^Liveness/) { if (!lu[ens "/" en]++) lv[ens "/" en] = E[7] }
      if (ek == "Pod" && (er == "FailedAttachVolume" || er == "FailedMount")) {
        if (em ~ /(configmap|secret)s? "[^"]*" not found/) { if (!cf[ens "/" en]++) hit("CFG-01", ens "/" en, "fail", substr(em, 1, 90), "fm-CFG-01|" ens "|" en, ens, "") }
        else if (!fm[ens "/" en]++) hit("PVC-03", ens "/" en, "fail", er ": " substr(em, 1, 80), "fm-PVC-03|" ens "|" en, ens, "") }
      if (tolower(em) ~ /forbidden/ && er !~ /^(Unhealthy|BackOff)$/) { k = ens "/" ek "/" en; if (!fb[k]++) hit("ACC-01", ens "/" tolower(ek) "/" en, "fail", er ": " substr(em, 1, 80), "fm-ACC-01|" ens "|" en "|" ek, ens, "") }
      next }
    FILENAME ~ /health-pods\.raw$/ { if ($1 != "P") next; w = PWK[$2 "/" $3]; if (w != "" && !(($2 "|" w) in WPL)) WPL[$2 "|" w] = $6; if ($8 != "" && $8 != "<no value>") { e = epoch($8); if (e > 0 && NOW - e > 300) hit("POD-09", $2 "/" $3, "fail", "Terminating since " ago($8), "fm-POD-09|" $2 "|" $3, $2, "") }; next }
    $1 == "FD" { ndep++; nwl++; rep = $4 + 0; av = $5 + 0; op = ($3 ~ /operator|controller/)
      CRITW[$2 "|deployment/" $3] = $8; SELW[$2 "|deployment/" $3] = $10; REPW[$2 "|deployment/" $3] = rep
      if (rep > 0 && av == 0) hit(op ? "CRD-01" : "WRK-01", $2 "/" $3, "fail", "0 of " rep " replicas available", "fm-WRK-01|" $2 "|" $3 "|deployment", $2, $8)
      if ($7 == "ProgressDeadlineExceeded") hit("WRK-02", $2 "/" $3, "fail", "rollout exceeded its progress deadline", "fm-WRK-02|" $2 "|" $3, $2, $8)
      if (rep == 1) hit("WRK-03", $2 "/deployment/" $3, "risk", "1 replica", "fm-WRK-03|" $2 "|" $3 "|deployment", $2, $8)
      next }
    $1 == "FS" { nsts++; nwl++; rep = $4 + 0; rd = $5 + 0; CRITW[$2 "|statefulset/" $3] = $8; SELW[$2 "|statefulset/" $3] = $10; REPW[$2 "|statefulset/" $3] = rep
      if (rep > 1 && rd < rep) hit("WRK-04", $2 "/" $3, "fail", "ready " rd " of " rep " - later ordinals wait for earlier ones", "fm-WRK-04|" $2 "|" $3, $2, $8)
      if (rep == 1) hit("WRK-03", $2 "/statefulset/" $3, "risk", "1 replica", "fm-WRK-03|" $2 "|" $3 "|statefulset", $2, $8)
      next }
    $1 == "FA" { nds++; if ($4 + 0 > $5 + 0 || $6 + 0 > 0) hit("WRK-05", $2 "/" $3, "fail", "ready " ($5 + 0) " of " ($4 + 0) " nodes" ($6 + 0 > 0 ? ", " $6 " misscheduled" : ""), "fm-WRK-05|" $2 "|" $3, $2, $8); next }
    $1 == "FJ" { njob++; if ($4 == "True") { if ($6 != "") { if (!(($2 "|" $6) in jl)) jl[$2 "|" $6] = $3 } else hit("JOB-01", $2 "/" $3, "fail", "failed" ($5 != "" ? ": " $5 : ""), "fm-JOB-01|" $2 "|" $3, $2, $8) }; next }
    $1 == "FR" { ncron++
      if ($5 == "true") hit("JOB-02", $2 "/" $3, "risk", "suspended (schedule " $4 ")", "fm-JOB-02|" $2 "|" $3, $2, $8)
      else if ($6 != "" && $6 != "<no value>") { ls = epoch($6); su = ($7 != "" && $7 != "<no value>") ? epoch($7) : 0
        if (su == 0 && NOW - ls > 3600) hit("JOB-02", $2 "/" $3, "fail", "never succeeded; last run " ago($6) " ago", "fm-JOB-02|" $2 "|" $3, $2, $8)
        else if (su > 0 && NOW - su > cronh * 3600 && ls > su) hit("JOB-02", $2 "/" $3, "fail", "last success " ago($7) " ago, runs since then failed", "fm-JOB-02|" $2 "|" $3, $2, $8) }
      next }
    $1 == "FH" { nhpa++
      if ($7 == "False") hit("HPA-01", $2 "/" $3, "fail", "ScalingActive=False" ($8 != "" ? " (" $8 ")" : ""), "fm-HPA-01|" $2 "|" $3, $2, "")
      else if ($5 + 0 > 0 && $6 + 0 >= $5 + 0) hit("HPA-02", $2 "/" $3, "fail", "at maxReplicas " $5, "fm-HPA-01|" $2 "|" $3, $2, "")
      next }
    $1 == "FB" { npdb++; PDBS[npdb] = $2 SUBSEP $8
      if ($7 + 0 > 0 && $4 + 0 == 0) hit("PDB-01", $2 "/" $3, "risk", "0 disruptions allowed (healthy " ($5 + 0) ", needs " ($6 + 0) ")", "fm-PDB-01|" $2 "|" $3, $2, ""); next }
    $1 == "FU" { nq++; kv($4, HQ); kv($5, UQ); worst = ""; wr = 0
      for (k in HQ) { h = qty(HQ[k]); if (h <= 0) continue; r = qty(UQ[k]) / h; if (r > wr) { wr = r; worst = k } }
      if (wr >= 0.9) hit("QTA-01", $2 "/" $3, wr >= 1 ? "fail" : "risk", sprintf("%s at %d%% (%s of %s)", worst, wr * 100, UQ[worst], HQ[worst]), "fm-QTA-01|" $2 "|" $3, $2, ""); next }
    $1 == "FY" { nnp++; if ($4 == "all" && $5 ~ /Ingress/ && $6 + 0 == 0) hit("NET-01", $2 "/" $3, "risk", "default deny: every pod in " $2 " refuses ingress not allowed by another policy", "fm-NET-01|" $2 "|" $3, $2, ""); next }
    $1 == "FL" { if ($4 == "") hit("SVC-03", $2 "/" $3, "fail", "LoadBalancer without an external IP", "fm-SVC-03|" $2 "|" $3, $2, ""); next }
    $1 == "FN" { nnode++
      if ($3 != "") { c = $3; sub(/,$/, "", c); hit("NOD-02", $2, "fail", c, "fm-NOD-02||" $2, "", "") }
      if ($4 == "cordoned") hit("NOD-03", $2, "risk", "cordoned (no new pods)", "fm-NOD-03||" $2, "", "")
      next }
    $1 == "FX" { nns++; NSC[$2] = $4; if ($3 == "Terminating") hit("NS-01", $2, "fail", "Terminating", "fm-NS-01||" $2, $2, $4); next }
    $1 == "FC" { ndns++; if ($4 == "True") dnsok++; next }
    $1 == "FW" { nwh++; if ($5 == "Fail" && $6 != "") { WH[$6 "|" $7] = WH[$6 "|" $7] (WH[$6 "|" $7] == "" ? "" : ",") $3 }; next }
    $1 == "FE" { if ($4 == "0") { split(WH[$2 "|" $3], wn, ","); hit("ADM-01", wn[1], "fail", "failurePolicy Fail and service " $2 "/" $3 " has no ready endpoint", "fm-ADM-01|" $2 "|" $3 "|" wn[1], $2, "") }; next }
    FILENAME ~ /readyz\.raw$/ { if ($0 ~ /^\[-\]etcd/) etcdbad = $0; else if ($0 ~ /^\[\+\]etcd/) etcdok = 1; else if ($0 ~ /^\[-\]/) { ryb++; ryt = ryt (ryt == "" ? "" : ", ") substr($0, 4, 40) }; next }
    FILENAME ~ /health-pvs\.raw$/ { if ($1 == "Z" && $3 == "Bound" && $6 == "Delete") del[$4]++; next }
    FILENAME ~ /health-storageclasses\.raw$/ { if ($1 == "K") { nsc++; SCX[$2] = $5 }; next }
    FILENAME ~ /health-pvcs\.raw$/ { if ($1 == "Q") { npvc++; if ($4 == "Bound") bsc[$6]++ }; next }
    END {
      for (k in lv) if (!((k) in lk)) { split(k, a, "/"); hit("POD-06", k, "risk", "liveness probe failing (" lv[k] "x), not killed yet", "fm-POD-06|" a[1] "|" a[2], a[1], "") }
      for (k in jl) { split(k, a, "|"); hit("JOB-01", a[1] "/" jl[k], "fail", "failed (CronJob " a[2] ")", "fm-JOB-01|" a[1] "|" jl[k], a[1], "") }
      for (g in be) { split(g, a, "|"); hit("WRK-06", a[1] "/" a[2], "risk", be[g] " pod(s) BestEffort - no requests or limits", "fm-WRK-06|" a[1] "|" substr(a[2], index(a[2], "/") + 1) "|" substr(a[2], 1, index(a[2], "/") - 1), a[1], CRITW[a[1] "|" a[2]]) }
      for (g in gp) if (gp[g] >= 2 && gnc[g] == 1) { split(g, a, "|"); w = a[2]; sub(/^replicaset\//, "deployment/", w)
        hit("WRK-07", a[1] "/" w, "risk", gp[g] " of " gp[g] " replicas on " gnode[g], "fm-WRK-07|" a[1] "|" substr(w, index(w, "/") + 1), a[1], CRITW[a[1] "|" w]) }
      for (w in REPW) if (REPW[w] >= 2) { split(w, a, "|"); covered = 0
        for (i = 1; i <= npdb && !covered; i++) { split(PDBS[i], b, SUBSEP); if (b[1] != a[1]) continue
          kv(SELW[w], WS); if (sub_of(b[2], WS)) covered = 1
          if (!covered && (w in WPL)) { kv(WPL[w], PLB); if (sub_of(b[2], PLB)) covered = 1 } }
        if (!covered) hit("PDB-02", a[1] "/" a[2], "risk", REPW[w] " replicas, no PodDisruptionBudget", "fm-PDB-02|" a[1] "|" substr(a[2], index(a[2], "/") + 1), a[1], CRITW[w]) }
      for (s in del) if (s != "") hit("PVC-04", "storageclass/" s, "risk", del[s] " bound volume(s) deleted with their claims (reclaimPolicy Delete)", "fm-PVC-04||" s, "", "")
      for (s in bsc) if (s in SCX && SCX[s] != "true") hit("PVC-05", "storageclass/" s, "risk", bsc[s] " bound claim(s) cannot grow online", "fm-PVC-05||" s, "", "")
      if (ndns > 0 && dnsok == 0) hit("DNS-01", "kube-system/coredns", "fail", "0 of " ndns " CoreDNS pods ready", "fm-DNS-01|kube-system|coredns", "kube-system", "")
      else if (ndns > 0 && dnsok < ndns) hit("DNS-01", "kube-system/coredns", "risk", dnsok " of " ndns " CoreDNS pods ready", "fm-DNS-01|kube-system|coredns", "kube-system", "")
      if (etcdbad != "") hit("CP-02", "etcd", "fail", substr(etcdbad, 1, 80), "fm-CP-02", "", "")
      if (ryb > 0) hit("CP-01", ctx, "fail", "readyz: " ryt, "fm-CP-01", "", "")
      printf "pods\t%d\ndeployments\t%d\nstatefulsets\t%d\ndaemonsets\t%d\nworkloads\t%d\njobs\t%d\ncronjobs\t%d\nhpas\t%d\npdbs\t%d\nquotas\t%d\nnetpols\t%d\nnodes\t%d\nnamespaces\t%d\ndns\t%d\nwebhooks\t%d\npvcs\t%d\nstorageclasses\t%d\netcd\t%d\n", \
        npods, ndep, nsts, nds, nwl, njob, ncron, nhpa, npdb, nq, nnp, nnode, nns, ndns, nwh, npvc, nsc, (etcdok || etcdbad != "") > cntf
      for (n in NSC) if (NSC[n] != "") printf "nscrit\t%s\t%s\n", n, NSC[n] > cntf
    }' "$MODEL/pods.tsv" "$MODEL/nodes.tsv" "$d/events.tsv" "$d/health-pods.raw" "$d"/health-fm-deploy.raw "$d"/health-fm-sts.raw "$d"/health-fm-ds.raw \
       "$d"/health-fm-jobs.raw "$d"/health-fm-cron.raw "$d"/health-fm-hpa.raw "$d"/health-fm-pdb.raw "$d"/health-fm-quota.raw "$d"/health-fm-netpol.raw \
       "$d"/health-fm-svclb.raw "$d"/health-fm-nodes.raw "$d"/health-fm-ns.raw "$d"/health-fm-dns.raw "$d"/health-fm-webhooks.raw "$d"/health-fm-whep.raw \
       "$d/health-readyz.raw" "$d/health-pvs.raw" "$d/health-storageclasses.raw" "$d/health-pvcs.raw" 2>/dev/null >> "$hits"
  # object counts for services / ingresses come from the health reads
  { printf 'services\t%s\n' "$(grep -c '^S|' "$d/health-services.raw" 2>/dev/null)"
    printf 'ingresses\t%s\n' "$(cut -d'|' -f2,3 "$d/health-ingresses.raw" 2>/dev/null | sort -u | grep -c .)"
    printf 'certificates\t%s\n' "$(awk -F'\t' '$4 == 1' "$d/sm-certs.tsv" 2>/dev/null | grep -c .)"
    printf 'cmcerts\t%s\n' "$(cat "$d/check-certs/health-cert-manager.raw" "$d/health-cert-manager.raw" 2>/dev/null | grep -c .)"
    printf 'cluster\t1\n'; } >> "$d/fmea-counts.tsv"
  return 0
}

# source states per catalogue source name -> "name state"
fmea__source_states() {
  local s st
  for s in spec events pods services endpoints ingresses pvcs pvs storageclasses volume-metrics rb-nodes rb-snapshots readyz certs cert-manager sm-secrets login \
           fm-deploy fm-sts fm-ds fm-jobs fm-cron fm-hpa fm-pdb fm-quota fm-netpol fm-svclb fm-nodes fm-ns fm-dns fm-webhooks hpods; do
    case "$s" in
      spec) [ "${SPEC_OK:-0}" = 1 ] && st=ok || st="$(printf '%s' "${SPEC_REASON:-error}" | grep -qiE 'forbidden|403' && echo forbidden || echo error)" ;;
      events) st="$(cat "$TOOLKIT_DIR/events.status" 2>/dev/null)"; case "$st" in ok*) st=ok ;; *forbid*) st=forbidden ;; '') st=unknown ;; *) st=error ;; esac ;;
      hpods) st="$(health__state pods)" ;;
      certs) if [ -d "$TOOLKIT_DIR/check-certs/certs" ] || [ -d "$TOOLKIT_DIR/certs" ]; then st=ok; else st=no-data; fi ;;
      cert-manager) st="$( [ -f "$TOOLKIT_DIR/health-cert-manager.status" ] && health__state cert-manager || ( TOOLKIT_DIR="$TOOLKIT_DIR/check-certs"; health__state cert-manager ) )"; [ -n "$st" ] || st=no-data ;;
      login) st=ok ;;
      *) st="$(health__state "$s")" ;;
    esac
    printf '%s\t%s\n' "$s" "$st"
  done
}

# history: days on which each mode failed (saved runs, last 30 days) -> "ID days" + "#days N"
fmea__history() {
  local dir; dir="$(fmea__runs_dir)"
  [ -d "$dir" ] || { printf '#days\t0\n'; return 0; }
  find "$dir" -name '*.tsv' -mtime -"${KDASH_FMEA_O_DAYS:-30}" 2>/dev/null | LC_ALL=C sort | while IFS= read -r f; do
    b="${f##*/}"; awk -F'\t' -v day="${b:0:8}" '$1 !~ /^#/ && $3 == "fail" { print day "\t" $1 } $1 == "#sum" { print day "\t#run" }' "$f"
  done | LC_ALL=C sort -u | awk -F'\t' '$2 == "#run" { days++; next } { n[$2]++ } END { printf "#days\t%d\n", days; for (k in n) printf "%s\t%d\n", k, n[k] }'
}

# ---- scoring -> fmea-rows.tsv --------------------------------------------------
# AP S O D RPN ID KIND OBJECT MODE NOW STATUS ACCESS EST HINTKEY EFFECT CAUSE OWNER MISSING SITE
fmea_score() {
  local d="$TOOLKIT_DIR"
  fmea__catalogue_merged > "$d/fmea-cat.tsv"
  fmea__source_states > "$d/fmea-src.tsv"
  fmea__history > "$d/fmea-hist.tsv"
  fmea__site_crit > "$d/fmea-crit.tsv"
  LC_ALL=C awk -F'\t' -v ntot=0 "$FMEA_AP_AWK"'
    function clamp(x) { return x < 1 ? 1 : (x > 10 ? 10 : x) }
    function hum(m,   n, a, i, o, w, v, r) { n = split(m, a, " "); o = ""
      for (i = 1; i <= n; i++) { w = a[i]
        if (w ~ /^read:/) continue
        if (w == "source:volume-metrics") w = "a volume metrics source (Prometheus)"
        else { v = substr(w, 1, index(w, ":") - 1); r = substr(w, index(w, ":") + 1)
          if (r ~ /@$/) { sub(/@$/, "", r); w = v " " r " (cluster-wide)" }
          else if (r ~ /#/) w = v " " substr(r, 1, index(r, "#") - 1) " in " substr(r, index(r, "#") + 1)
          else w = v " " r }
        o = o (o == "" ? "" : ", ") w }
      return o == "" ? "read access" : o }
    function oh(id,   n) { n = HI[id] + 0; if (n == 0) { EST = (HD < 7); return EST ? 2 : 1 } EST = (HD < 7)
      return n >= 8 ? 9 : n >= 4 ? 7 : n >= 2 ? 5 : 3 }
    function critadj(ns, obj, cr,   c) { c = cr
      if (c == "" && obj in SC) c = SC[obj]
      if (c == "" && ns in SC) c = SC[ns]
      if (c == "" && ns in NC) c = NC[ns]
      return c == "critical" ? 1 : c == "low" ? -2 : 0 }
    FILENAME ~ /fmea-cat/ { n++; ID[n] = $1; K[$1] = $2; MO[$1] = $3; EF[$1] = $4; CA[$1] = $5; SG[$1] = $6; RQ[$1] = $7; S0[$1] = $8 + 0; D0[$1] = $9 + 0
      CK[$1] = $10; SR[$1] = $11; OW[$1] = $12; STA[$1] = $13; MAN[$1] = $14; SITE[$1] = $15; next }
    FILENAME ~ /fmea-access/ { if ($1 == "P") PERM[$2] = $3; else if ($1 == "U") USER = $2; next }
    FILENAME ~ /fmea-src/ { SS[$1] = $2; next }
    FILENAME ~ /fmea-hist/ { if ($1 == "#days") HD = $2 + 0; else HI[$1] = $2 + 0; next }
    FILENAME ~ /fmea-crit/ { SC[$1] = $2; next }
    FILENAME ~ /fmea-counts/ { if ($1 == "nscrit") NC[$2] = $3; else CNT[$1] = $2 + 0; next }
    FILENAME ~ /fmea-hits/ { if (($1, $2) in dup) next; dup[$1, $2] = 1; nh++; HID[nh] = $1; HOB[nh] = $2; HST[nh] = $3; HNW[nh] = $4; HHK[nh] = $5; HNS[nh] = $6; HCR[nh] = $7; has[$1]++; next }
    END {
      for (k = 1; k <= n; k++) { id = ID[k]
        # access: every required permission granted = full; some = partial; none = none
        np = split(RQ[id], rq, " "); yes = 0; er = 0; miss = ""
        for (i = 1; i <= np; i++) { if (PERM[rq[i]] == "yes") yes++; else { if (PERM[rq[i]] != "no") er++; miss = miss (miss == "" ? "" : " ") rq[i] } }
        acc = (np == 0 || yes == np) ? "full" : (yes == 0 ? (er == np ? "unknown" : "none") : "partial")
        ns_ = split(SR[id], sr, " "); nosig = 0; part = 0; fs = 0; req = 0
        for (i = 1; i <= ns_; i++) { s = sr[i]; opt = (s ~ /\?$/); if (opt) sub(/\?$/, "", s); st = SS[s]; if (!opt) req++
          if (st == "forbidden") { fs++; if (acc == "full") acc = "partial"; miss = miss (miss == "" ? "" : " ") "read:" s }
          else if (st != "ok" && st != "") { if (opt) part = 1; else nosig = 1 } }
        # every read this mode needs was refused: no access, whatever can-i said
        if (req > 0 && fs >= req) acc = "none"
        if (part && acc == "full") { acc = "partial"; miss = miss (miss == "" ? "" : " ") "source:volume-metrics" }
        if (MAN[id] != "") { acc = "full"; nosig = 0 }
        s0 = clamp(S0[id]); d0 = clamp(D0[id]); dd = acc == "partial" ? clamp(d0 + 2) : d0
        if (!has[id] && (acc == "none" || acc == "unknown" || nosig)) {
          o = oh(id); e = EST; dx = 10; stt = (acc == "none" ? "noaccess" : "nosignal")
          now_ = (acc == "none" ? "no access for " USER ": needs " hum(miss) : acc == "unknown" ? "not checked: the API did not answer the access check" : "not visible on this cluster: " SG[id])
          out(id, s0, o, dx, ID[k], (CK[id] == "cluster" ? "cluster" : "-"), now_, stt, acc, e, "", miss)
          continue }
        if (MAN[id] != "") { out(id, s0, MAN[id] + 0, d0, id, "site", "manual row from the site file", "risk", acc, 0, "", miss); continue }
        if (has[id]) {
          for (h = 1; h <= nh; h++) { if (HID[h] != id) continue
            s1 = clamp(s0 + critadj(HNS[h], HOB[h], HCR[h]))
            if (HST[h] == "fail") { o = 10; e = 0 } else { o = oh(id); e = EST; if (o < 4) { o = 4; e = 0 } }
            out(id, s1, o, dd, id, HOB[h], HNW[h], HST[h], acc, e, HHK[h], miss) }
        } else {
          c = CNT[CK[id]] + 0; o = oh(id); e = EST
          now_ = (CK[id] == "cluster") ? "ok" : (c > 0 ? "all " c " " CK[id] " ok" : "no " CK[id] " in scope")
          if (acc == "partial") now_ = now_ " (partial: needs " hum(miss) ")"
          out(id, s0, o, dd, id, (CK[id] == "cluster" ? "cluster" : "-"), now_, "ok", acc, e, "", miss) }
      }
    }
    function out(id, s, o, d, x, obj, now_, st, acc, est, hk, miss,   a, r) { a = ap(s, o, d); r = s * o * d
      printf "%s\t%d\t%d\t%d\t%d\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%d\t%s\t%s\t%s\t%s\t%s\t%s\n", a, s, o, d, r, id, K[id], obj, MO[id], now_, st, acc, est, hk, EF[id], CA[id], OW[id], miss, SITE[id] }
  ' "$d/fmea-cat.tsv" "$d/fmea-access.tsv" "$d/fmea-src.tsv" "$d/fmea-hist.tsv" "$d/fmea-crit.tsv" "$d/fmea-counts.tsv" "$d/fmea-hits.tsv" |
    LC_ALL=C awk -F'\t' 'BEGIN { OFS = "\t" } { r = ($1 == "H") ? 1 : ($1 == "M") ? 2 : 3; print r, 100 - $2, 100000 - $5, $0 }' |
    LC_ALL=C sort -t $'\t' -k1,1n -k2,2n -k3,3n -k9,9 -k11,11 | cut -f4- > "$d/fmea-rows.tsv"
  # summary: H M L visible total user
  awk -F'\t' -v u="$(awk -F'\t' '$1 == "U" { print $2; exit }' "$d/fmea-access.tsv")" '
    { c[$1]++; if (!($6 in seen)) { seen[$6] = 1; tot++; if ($11 != "noaccess") vis++ } }
    END { printf "%d\t%d\t%d\t%d\t%d\t%s\n", c["H"], c["M"], c["L"], vis, tot, u }' "$d/fmea-rows.tsv" > "$d/fmea.summary"
  date +%s > "$d/fmea.at"
}

# keep this run for Occurrence and the trend (interactive: at most every KDASH_FMEA_SAVE_EVERY s)
fmea_save() { # cli|view
  [ "${KDASH_FMEA_SAVE:-1}" = 1 ] || return 0
  local dir last; dir="$(fmea__runs_dir)"
  mkdir -p "$dir" 2>/dev/null || return 0
  if [ "${1:-cli}" = view ]; then
    last="$(ls -1 "$dir" 2>/dev/null | LC_ALL=C sort | tail -1)"
    if [ -n "$last" ] && [ $(( $(date +%s) - $(stat -c %Y "$dir/$last" 2>/dev/null || echo 0) )) -lt "${KDASH_FMEA_SAVE_EVERY:-600}" ]; then return 0; fi
  fi
  { awk -F'\t' 'BEGIN { OFS = "\t" } { print $6, $8, $11, $1 }' "$TOOLKIT_DIR/fmea-rows.tsv"
    awk -F'\t' '{ printf "#sum\t%s\t%s\t%s\t%s\t%s\n", $1, $2, $3, $4, $5 }' "$TOOLKIT_DIR/fmea.summary"; } > "$dir/$(date +%Y%m%d%H%M%S).tsv" 2>/dev/null
  find "$dir" -name '*.tsv' -mtime +"${KDASH_FMEA_KEEP_DAYS:-90}" -exec rm -f {} + 2>/dev/null
  return 0
}

fmea_collect() { # cli|view
  local was_fresh
  fmea_access
  [ "${FMEA_ACCESS_FRESH:-0}" != 1 ] || audit FMEA_ACCESS "$(awk -F'\t' '$1 == "U" { u = $2; g = $3; gsub(/ /, ",", g) } $1 == "P" { n++; if ($3 == "yes") y++ } END { printf "user=%s groups=%s permissions=%d/%d", u, g, y, n }' "$TOOLKIT_DIR/fmea-access.tsv")"
  # access just (re)checked: the node / snapshot reads must not be older than it
  if [ "${FMEA_ACCESS_FRESH:-0}" = 1 ] || [ "$(rb_age)" -ge 60 ]; then rb_collect; fi
  fmea_reads
  # certificates in Secrets feed CFG-02, missing Secrets CFG-01 (the secrets map, reused while fresh)
  if [ "${KDASH_SECRETS_IN_CHECK:-1}" = 1 ]; then
    if [ "${FMEA_ACCESS_FRESH:-0}" = 1 ] || [ "$(sm_age)" -ge "${KDASH_SECRETS_CHECK_TTL:-300}" ]; then sm_collect > /dev/null 2>&1; fi
  else health__status sm-secrets disabled 'KDASH_SECRETS_IN_CHECK=0'; fi
  rm -f "$TOOLKIT_DIR/check-findings.tsv"; check_findings > /dev/null 2>&1
  fmea_evaluate
  fmea_score
  # a read RBAC refused although can-i said yes (or the reverse): access changed - ask again next time
  awk -F'\t' '$2 == "forbidden" { f = 1 } END { exit !f }' "$TOOLKIT_DIR/fmea-src.tsv" && [ "${FMEA_ACCESS_FRESH:-0}" != 1 ] && rm -f "$TOOLKIT_DIR/fmea-access.tsv"
  if [ -n "$(fmea__site_files)" ]; then
    was_fresh="$(fmea__site_files | xargs cat 2>/dev/null | cksum | cut -d' ' -f1)"
    [ "$was_fresh" = "$(cat "$TOOLKIT_DIR/fmea-site.sum" 2>/dev/null)" ] || {
      printf '%s\n' "$was_fresh" > "$TOOLKIT_DIR/fmea-site.sum"
      audit FMEA_SITE_OVERRIDE "files=$(fmea__site_files | tr '\n' ',') ids=$(awk -F'\t' '$19 == "site" && !s[$6]++ { printf "%s,", $6 }' "$TOOLKIT_DIR/fmea-rows.tsv")"; }
  fi
  fmea_save "${1:-cli}"
  FMEA_ACCESS_FRESH=0
  return 0
}

fmea_badge() { # "3 high, 82% visible" ("" when nothing to say)
  local h m l v t u
  [ -s "${TOOLKIT_DIR:-}/fmea.summary" ] || return 0
  IFS=$'\t' read -r h m l v t u < "$TOOLKIT_DIR/fmea.summary"
  [ "${t:-0}" -gt 0 ] || return 0
  if [ "${h:-0}" -gt 0 ] || [ "${v:-0}" -lt "$t" ]; then printf '%s high, %s%% visible' "$h" "$(( 100 * v / t ))"; fi
}

# ---- runbook lines per mode (read = may run with Enter; CHANGE = printed only) ----
fmea_hints() { # key ns name x1 ...
  local key="$1" ns="${2:-}" name="${3:-}" x1="${4:-}" n; n="$(rb_q "$name")"
  case "$key" in
    fm-WRK-01|fm-WRK-02)
      rb_line read "$(rb_k "$ns" get deployment "$n" -o wide)" "replicas desired, ready, available"
      rb_line read "$(rb_k "$ns" describe deployment "$n")" "conditions and the ReplicaSets it owns"
      rb_line note "a recent change is the usual cause: $(rb_k "$ns" rollout history deployment "$n") in your terminal"
      rb_line CHANGE "$(rb_k "$ns" rollout undo deployment "$n")" "back to the previous revision, when the last change broke it" ;;
    fm-WRK-03)
      rb_line read "$(rb_k "$ns" get "${x1:-deployment}" "$n" -o wide)" "replicas now"
      rb_line CHANGE "$(rb_k "$ns" scale "${x1:-deployment}" "$n" --replicas=2)" "only when the application supports more than one replica (set it in its chart too)" ;;
    fm-WRK-04)
      rb_line read "$(rb_k "$ns" describe statefulset "$n")" "which ordinal is not ready"
      rb_line read "$(rb_k "$ns" get pods -o wide) | grep $n" "the pods and their nodes"
      rb_line note "a StatefulSet starts pod N+1 only when pod N is Ready (podManagementPolicy OrderedReady)" ;;
    fm-WRK-05)
      rb_line read "$(rb_k "$ns" describe daemonset "$n")" "desired vs ready, and why"
      rb_line read "$(rb_k "" get nodes -o wide)" "taints and Ready state of the nodes it misses" ;;
    fm-WRK-06)
      rb_line read "$(rb_k "$ns" get "${x1:-pod}" "$n" -o "jsonpath='{range .spec.template.spec.containers[*]}{.name}: {.resources}{\"\\n\"}{end}'")" "requests and limits per container"
      rb_line CHANGE "$(rb_k "$ns" set resources "${x1:-deployment}" "$n" --requests=cpu=100m,memory=128Mi --limits=memory=256Mi)" "size from key 5 MEMORY and the live usage" ;;
    fm-WRK-07)
      rb_line read "$(rb_k "$ns" get pods -o wide) | grep $n" "where the replicas run"
      rb_line note "add podAntiAffinity or topologySpreadConstraints (topologyKey kubernetes.io/hostname) in the chart" ;;
    fm-POD-06)
      rb_line read "$(rb_k "$ns" describe pod "$n")" "the probe, its timeout and the kill events"
      rb_line note "raise timeoutSeconds / failureThreshold, or add a startupProbe for slow starts" ;;
    fm-POD-09)
      rb_line read "$(rb_k "$ns" get pod "$n" -o "jsonpath='{.metadata.finalizers}{\" \"}{.spec.nodeName}{\"\\n\"}'")" "finalizers and the node"
      rb_line read "$(rb_k "$ns" describe pod "$n")" "what it waits for"
      rb_line CHANGE "$(rb_k "$ns" delete pod "$n" --grace-period=0 --force)" "last resort, only when its node is really gone" ;;
    fm-CFG-01)
      rb_line read "$(rb_k "$ns" describe pod "$n")" "which ConfigMap or Secret (and key) is missing"
      rb_line read "$(rb_k "$ns" get configmaps,secrets)" "what exists (names only)" ;;
    fm-PVC-03)
      rb_line read "$(rb_k "$ns" describe pod "$n")" "the attach / mount error"
      rb_line read "$(rb_k "" get volumeattachments)" "an RWO volume still attached to another node" ;;
    fm-PVC-04)
      rb_line read "$(rb_k "" get pv -o custom-columns=NAME:.metadata.name,CLAIM:.spec.claimRef.name,CLASS:.spec.storageClassName,RECLAIM:.spec.persistentVolumeReclaimPolicy)" "volumes and their reclaim policy"
      rb_line CHANGE "$(rb_k "" patch pv PV-NAME -p "'{\"spec\":{\"persistentVolumeReclaimPolicy\":\"Retain\"}}'")" "keep the data of an important volume when its claim is deleted" ;;
    fm-PVC-05)
      rb_line read "$(rb_k "" get storageclass "$n" -o yaml)" "allowVolumeExpansion"
      rb_line note "expansion is set on the StorageClass by the storage admin (only when the CSI driver supports it)" ;;
    fm-SVC-03)
      rb_line read "$(rb_k "$ns" describe service "$n")" "the load balancer events"
      rb_line note "the LoadBalancer controller (cloud, MetalLB, kube-vip) assigns the IP - check its pods and IP pool" ;;
    fm-NET-01)
      rb_line read "$(rb_k "$ns" get networkpolicies)" "every policy in the namespace"
      rb_line read "$(rb_k "$ns" describe networkpolicy "$n")" "what it allows"
      rb_line note "a default deny needs allow rules for every caller (ingress controller, monitoring, other services)" ;;
    fm-DNS-01)
      rb_line read "$(rb_k kube-system get pods -l k8s-app=kube-dns -o wide)" "CoreDNS pods"
      rb_line read "$(rb_k kube-system logs -l k8s-app=kube-dns --tail=50)" "CoreDNS errors" ;;
    fm-HPA-01)
      rb_line read "$(rb_k "$ns" describe hpa "$n")" "conditions and the metrics it reads"
      rb_line read "$(rb_k "" top pods -n "$(rb_q "$ns")")" "metrics-server answers?" ;;
    fm-PDB-01|fm-PDB-02)
      rb_line read "$(rb_k "$ns" get pdb -o wide)" "budgets and allowed disruptions"
      [ "$key" = fm-PDB-02 ] && rb_line note "add a PodDisruptionBudget (maxUnavailable: 1) for $name in its chart"
      [ "$key" = fm-PDB-01 ] && rb_line note "minAvailable equal to replicas blocks every drain - use maxUnavailable: 1" ;;
    fm-QTA-01)
      rb_line read "$(rb_k "$ns" describe resourcequota "$n")" "used vs hard per resource" ;;
    fm-NOD-02|fm-NOD-03|fm-NOD-04)
      rb_line read "$(rb_k "" describe node "$n")" "conditions, allocatable and allocated resources"
      [ "$key" = fm-NOD-03 ] && rb_line CHANGE "$(rb_k "" uncordon "$n")" "only when the maintenance is finished" ;;
    fm-CP-01|fm-CP-02)
      rb_line read "$(rb_k "" get --raw "'/readyz?verbose'")" "which API server checks fail"
      rb_line note "full procedure: kdash --runbook $([ "$key" = fm-CP-02 ] && echo etcd-restore || echo api-unreachable)" ;;
    fm-ADM-01)
      rb_line read "$(rb_k "" get validatingwebhookconfigurations,mutatingwebhookconfigurations)" "webhooks and their configurations"
      rb_line read "$(rb_k "$ns" get endpointslices -l "kubernetes.io/service-name=$n")" "the webhook backends"
      rb_line note "with failurePolicy Fail and no backend every matching create/update is rejected - restore the webhook pods first" ;;
    fm-ACC-01)
      rb_line read "$(rb_k "$ns" get events --field-selector "involvedObject.name=$n")" "the forbidden calls"
      rb_line note "the ServiceAccount of $name needs a Role/RoleBinding for that call - ask the namespace admin" ;;
    fm-NS-01)
      rb_line read "$(rb_k "" get namespace "$n" -o "jsonpath='{.status.conditions}{\"\\n\"}'")" "what blocks the deletion"
      rb_line read "$(rb_k "" get apiservices) | grep -v True" "an unavailable API service blocks namespace deletion" ;;
    fm-JOB-01)
      rb_line read "$(rb_k "$ns" describe job "$n")" "why it failed"
      rb_line read "$(rb_k "$ns" logs "job/$n" --tail=100)" "the last output" ;;
    fm-JOB-02)
      rb_line read "$(rb_k "$ns" get cronjob "$n" -o wide)" "schedule, suspend, last schedule"
      rb_line read "$(rb_k "$ns" get jobs --sort-by=.metadata.creationTimestamp)" "its recent jobs" ;;
    *) sm_hints "$@"; return $? ;;
  esac
  return 0
}

# ---- screens ----------------------------------------------------------------------
fmea__ap_word() { case "$1" in H) printf '{r}HIGH' ;; M) printf '{y}MEDIUM' ;; *) printf '{d}LOW' ;; esac; }
fmea_render() {
  local d="$TOOLKIT_DIR" h m l v t u num="$TOOLKIT_DIR/fmea-numbered.tsv" kind="${FMEA_KIND:-}"
  tk_title "FMEA" "failure modes of every object you can read, ranked by Action Priority (AIAG-VDA) - S severity, O occurrence, D detection"
  if [ ! -s "$d/fmea-rows.tsv" ]; then printf '\nChecking your access (kubectl auth can-i), then scoring every failure mode ...\n'; return 0; fi
  IFS=$'\t' read -r h m l v t u < "$d/fmea.summary"
  if [ "${TK_COLOR:-0}" = 1 ]; then
    printf '\n ~[1;41;97m %s HIGH ~[0m ~[1;43;30m %s MEDIUM ~[0m ~[1;47;30m %s LOW ~[0m  ~[1m%s of %s modes visible to %s~[0m  ~[90mscored %ss ago - r re-scores, : access shows your rights~[0m\n' \
      "$h" "$m" "$l" "$v" "$t" "${u:-you}" "$(fmea_age)"
  else
    printf '\n %s HIGH  %s MEDIUM  %s LOW   %s of %s modes visible to %s   (scored %ss ago - r re-scores)\n' "$h" "$m" "$l" "$v" "$t" "${u:-you}" "$(fmea_age)"
  fi
  [ -z "$kind" ] || tk_note "showing kind: $kind (t cycles, empty = all)"
  awk -F'\t' -v k="$kind" 'BEGIN { OFS = "\t" } k == "" || index(tolower($7), tolower(k)) { print }' "$d/fmea-rows.tsv" |
    case "${FMEA_SORT:-ap}" in
      rpn) LC_ALL=C sort -t $'\t' -k5,5nr ;; s) LC_ALL=C sort -t $'\t' -k2,2nr -k5,5nr ;; *) cat ;;
    esac | awk -F'\t' 'BEGIN { OFS = "\t" } { print NR, $0 }' > "$num"
  { printf '#\tAP\t>S\t>O\t>D\t>RPN\tID\tOBJECT\tFAILURE MODE\tNOW~\n'
    awk -F'\t' 'BEGIN { OFS = "\t" }
      function apw(a) { return a == "H" ? "{r}HIGH" : a == "M" ? "{y}MEDIUM" : "{d}LOW" }
      { o = $4 ($14 == "1" ? "*" : ""); now_ = $11
        if ($12 == "noaccess") now_ = "{d}" now_; else if ($12 == "nosignal") now_ = "{d}" now_; else if ($12 == "ok") now_ = "{g}" now_; else if ($12 == "fail") now_ = "{r}" now_; else now_ = "{y}" now_
        print $1, apw($2), $3, o, $5, $6, $7, $9, $10, now_ }' "$num"; } |
    tk_table "WORKSHEET" "* = O estimated (under 7 days of saved runs) - s sorts AP / RPN / S, t filters the kind" "nothing to show" "row" "rows"
  tk_note "AP follows the AIAG-VDA 2019 table; RPN (S x O x D) is shown but does not rank. \"no access\" rows are never counted as OK."
  # next commands for the HIGH / MEDIUM rows that have something wrong now or a risk
  awk -F'\t' 'BEGIN { OFS = "\t" } ($2 == "H" || $2 == "M") && ($12 == "fail" || $12 == "risk") && $15 != "" {
      print $1, ($2 == "H" ? "{r}CRITICAL" : "{y}WARNING"), $9, $7 " " $10 ": " $11, $15 }' "$num" > "$num.list"
  KDASH_HINT_MAX="${KDASH_FMEA_HINT_MAX:-25}" rb_next_list "$num.list"
  rm -f "$num.list"
  return 0
}

fmea__role_yaml() { # missing perms -> a read-only Role / ClusterRole to ask an admin for
  awk -v ns="${NS:-default}" -v allns="${ALL_NS:-0}" -v user="$1" '
    { verbs = "get, list, watch"; p = $0; sub(/^[a-z]+:/, "", p)
      if (p ~ /^\//) { if (!(p in nr)) nn++; nr[p] = 1; next }
      sc = (p ~ /@$/ || allns == "1") ? "c" : "n"; tns = ns
      if (p ~ /#/) { tns = substr(p, index(p, "#") + 1); p = substr(p, 1, index(p, "#") - 1); sc = "n" }
      sub(/@$/, "", p); g = ""; r = p; if (index(p, ".")) { r = substr(p, 1, index(p, ".") - 1); g = substr(p, index(p, ".") + 1) }
      if (sc == "c") { if (!(g in C)) nc++; C[g] = C[g] }; if (sc == "c") C[g] = C[g] (C[g] == "" ? "" : ", ") r; else { N[tns SUBSEP g] = N[tns SUBSEP g] (N[tns SUBSEP g] == "" ? "" : ", ") r; nsl[tns] = 1 } }
    END {
      for (t in nsl) { printf "---\napiVersion: rbac.authorization.k8s.io/v1\nkind: Role\nmetadata:\n  name: kdash-fmea-read\n  namespace: %s\nrules:\n", t
        for (k in N) { split(k, a, SUBSEP); if (a[1] != t) continue; printf "  - apiGroups: [\"%s\"]\n    resources: [%s]\n    verbs: [get, list, watch]\n", a[2], N[k] } }
      if (nc + nn > 0) { printf "---\napiVersion: rbac.authorization.k8s.io/v1\nkind: ClusterRole\nmetadata:\n  name: kdash-fmea-read\nrules:\n"
        for (g in C) printf "  - apiGroups: [\"%s\"]\n    resources: [%s]\n    verbs: [get, list, watch]\n", g, C[g]
        for (u in nr) printf "  - nonResourceURLs: [\"%s\"]\n    verbs: [get]\n", u }
      printf "# bind it to %s (RoleBinding / ClusterRoleBinding) - read verbs only\n", user }'
}

fmea_access_render() {
  local d="$TOOLKIT_DIR" f="$TOOLKIT_DIR/fmea-access.tsv" u g y n cov
  tk_title "ACCESS" "what you may read, checked with kubectl auth whoami / can-i - every FMEA check runs only where this allows"
  [ -s "$f" ] || { printf '\nChecking your access ...\n'; return 0; }
  IFS=$'\t' read -r _ u g < <(grep $'^U\t' "$f")
  printf '\n user %s   groups %s   context %s   scope %s   checked %ss ago\n' "$u" "$g" "${CTX_NAME:-?}" "$([ "${ALL_NS:-0}" = 1 ] && echo 'all namespaces' || echo "${NS:-?}")" \
    "$(( $(date +%s) - $(awk -F'\t' '$1 == "#" { print $3; exit }' "$f") ))"
  { printf 'PERMISSION\tSCOPE\tALLOWED*\tNEEDED BY~\n'
    awk -F'\t' -v ns="${NS:-}" -v allns="${ALL_NS:-0}" 'BEGIN { OFS = "\t" } FILENAME ~ /fmea-cat/ { n = split($7, a, " "); for (i = 1; i <= n; i++) need[a[i]] = need[a[i]] (need[a[i]] == "" ? "" : " ") $1; next }
      $1 == "P" { p = $2; s = (p ~ /^[a-z]+:\// || p ~ /@$/) ? "cluster" : (p ~ /#/ ? substr(p, index(p, "#") + 1) : (allns == "1" ? "all namespaces" : ns))
        w = p; sub(/@$/, "", w); sub(/#.*/, "", w); sub(/:/, " ", w)
        print w, s, ($3 == "yes" ? "{g}yes" : $3 == "no" ? "{r}no" : "{y}error"), need[p] }' "$d/fmea-cat.tsv" "$f" | LC_ALL=C sort -t $'\t' -k3,3r -k1,1; } |
    tk_table "PERMISSIONS" "read verbs only; kdash never impersonates (--as) and never asks for more" "no permissions checked" "permission" "permissions"
  if [ -s "$d/fmea-rows.tsv" ]; then
    { printf 'ACCESS*\t>MODES\tIDS~\n'
      awk -F'\t' '!s[$6]++ { c[$12]++; ids[$12] = ids[$12] (ids[$12] == "" ? "" : " ") $6 }
        END { for (k in c) print (k == "full" ? "{g}full" : k == "partial" ? "{y}partial" : k == "unknown" ? "{y}not checked" : "{r}none") "\t" c[k] "\t" ids[k] }' "$d/fmea-rows.tsv" | LC_ALL=C sort; } |
      tk_table "COVERAGE" "full = every check runs; partial = a fallback signal, D + 2; none = no access, D 10 and never counted as OK" "" "level" "levels"
  fi
  awk -F'\t' '$1 == "P" && $3 != "yes" { print $2 }' "$f" > "$d/fmea-missing.txt"
  if [ -s "$d/fmea-missing.txt" ]; then
    printf '\n'; tk_note "To close the gaps, ask your admin for this read-only access (printed only - kdash applies nothing):"
    fmea__role_yaml "$u" < "$d/fmea-missing.txt" | sed 's/^/    /'
  else tk_note "every permission the FMEA checks need is granted"; fi
  rm -f "$d/fmea-missing.txt"
  return 0
}

# ---- exports -----------------------------------------------------------------------
fmea_export() { # csv|tsv|json
  local f="$TOOLKIT_DIR/fmea-rows.tsv"
  case "$1" in
    json) awk -F'\t' -v ctx="${CTX_NAME:-}" -v ns="${NS:-}" -v at="$(date -u +%Y-%m-%dT%H:%M:%SZ)" -v sum="$(cat "$TOOLKIT_DIR/fmea.summary")" '
        function j(s) { gsub(/\\/, "\\\\", s); gsub(/"/, "\\\"", s); gsub(/\t/, " ", s); return "\"" s "\"" }
        BEGIN { split(sum, S, "\t"); printf "{\"context\":%s,\"namespace\":%s,\"generated\":%s,\"user\":%s,\"high\":%d,\"medium\":%d,\"low\":%d,\"visible_modes\":%d,\"modes\":%d,\"rows\":[", j(ctx), j(ns), j(at), j(S[6]), S[1], S[2], S[3], S[4], S[5] }
        { printf "%s{\"ap\":%s,\"s\":%d,\"o\":%d,\"d\":%d,\"rpn\":%d,\"id\":%s,\"kind\":%s,\"object\":%s,\"mode\":%s,\"now\":%s,\"status\":%s,\"access\":%s,\"o_estimated\":%s,\"effect\":%s,\"cause\":%s,\"owner\":%s,\"missing\":%s}", \
            (NR > 1 ? "," : ""), j($1), $2, $3, $4, $5, j($6), j($7), j($8), j($9), j($10), j($11), j($12), ($13 == "1" ? "true" : "false"), j($15), j($16), j($17), j($18) }
        END { print "]}" }' "$f" ;;
    *) local sep=$'\t'; [ "$1" = csv ] && sep=,
       { printf 'AP\tS\tO\tD\tRPN\tID\tKIND\tOBJECT\tFAILURE_MODE\tNOW\tSTATUS\tACCESS\tO_ESTIMATED\tEFFECT\tCAUSE\tOWNER\tMISSING\n'
         cut -f1-13,15-18 "$f"; } | if [ "$1" = csv ]; then awk -F'\t' '{ for (i = 1; i <= NF; i++) { v = $i; if (v ~ /[",]/) { gsub(/"/, "\"\"", v); v = "\"" v "\"" } printf "%s%s", v, (i < NF ? "," : "\n") } }'; else cat; fi ;;
  esac
  audit FMEA_EXPORT "format=$1 rows=$(wc -l < "$f" | tr -d ' ')"
}

fmea__esc() { printf '%s' "$1" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g' -e 's/"/\&quot;/g'; }
fmea_html() { # [file] -> path
  local out="${1:-}" f="$TOOLKIT_DIR/fmea-rows.tsv" h m l v t u
  [ -n "$out" ] || { mkdir -p "${REPORT_DIR:-$HOME/kdash_reports}/fmea"; out="${REPORT_DIR:-$HOME/kdash_reports}/fmea/fmea_$(safe_name "${CTX_NAME:-ctx}")_$(safe_name "${NS:-ns}")_$(date +%Y%m%d_%H%M%S).html"; }
  IFS=$'\t' read -r h m l v t u < "$TOOLKIT_DIR/fmea.summary"
  { cat <<'HTML'
<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>kdash FMEA</title>
<style>:root{--bg:#fff;--fg:#1d1d1f;--mu:#6b6b70;--li:#e3e3e8;--h:#c62828;--m:#b26a00;--l:#5f6368;--ok:#2e7d32}
@media (prefers-color-scheme:dark){:root{--bg:#121214;--fg:#ececf1;--mu:#a0a0aa;--li:#2c2c33;--h:#ff6b6b;--m:#ffb74d;--l:#9aa0a6;--ok:#81c784}}
body{background:var(--bg);color:var(--fg);font:14px/1.45 system-ui,sans-serif;margin:24px}h1{font-size:20px;margin:0 0 4px}.mu{color:var(--mu)}
table{border-collapse:collapse;width:100%;margin-top:16px}th,td{border-bottom:1px solid var(--li);padding:6px 8px;text-align:left;vertical-align:top}th{font-weight:600}
td.n{text-align:right;font-variant-numeric:tabular-nums}.H{color:var(--h);font-weight:700}.M{color:var(--m);font-weight:700}.L{color:var(--l)}.ok{color:var(--ok)}.na{color:var(--mu)}
.b{display:inline-block;padding:2px 8px;border-radius:6px;margin-right:6px;font-weight:600}</style></head><body>
HTML
    printf '<h1>FMEA - %s / %s</h1><div class="mu">kdash %s, %s, user %s - read-only; Action Priority per AIAG-VDA 2019; RPN shown, not ranked</div>\n' \
      "$(fmea__esc "$CTX_NAME")" "$(fmea__esc "$NS")" "$KDASH_VERSION" "$(date '+%Y-%m-%d %H:%M %Z')" "$(fmea__esc "${u:-?}")"
    printf '<p><span class="b H">%s HIGH</span><span class="b M">%s MEDIUM</span><span class="b L">%s LOW</span> %s of %s modes visible to this user</p>\n' "$h" "$m" "$l" "$v" "$t"
    printf '<table><tr><th>AP</th><th>S</th><th>O</th><th>D</th><th>RPN</th><th>ID</th><th>Object</th><th>Failure mode</th><th>Now</th><th>Effect</th><th>Access</th></tr>\n'
    awk -F'\t' 'function e(s) { gsub(/&/, "\\&amp;", s); gsub(/</, "\\&lt;", s); gsub(/>/, "\\&gt;", s); return s }
      { c = ($11 == "ok") ? "ok" : ($11 ~ /no/) ? "na" : ""
        printf "<tr><td class=\"%s\">%s</td><td class=n>%s</td><td class=n>%s%s</td><td class=n>%s</td><td class=n>%s</td><td>%s</td><td>%s</td><td>%s</td><td class=\"%s\">%s</td><td>%s</td><td>%s</td></tr>\n", \
          $1, ($1 == "H" ? "HIGH" : $1 == "M" ? "MEDIUM" : "LOW"), $2, $3, ($13 == "1" ? "*" : ""), $4, $5, e($6), e($8), e($9), c, e($10), e($15), $12 }' "$f"
    printf '</table><p class="mu">* O estimated (under 7 days of saved runs). Recommended commands: kdash --fmea in a terminal (M in kdash).</p></body></html>\n'
  } > "$out" || return 1
  audit FMEA_EXPORT "format=html file=$out"
  printf '%s\n' "$out"
}

fmea_trend() { # since (e.g. 30d) -> one line per day: H M L visible
  local dir days; dir="$(fmea__runs_dir)"; days="${1%d}"; case "$days" in ''|*[!0-9]*) days=30 ;; esac
  tk_title "FMEA TREND" "high / medium / low per day from saved runs of $CTX_NAME / $NS (last $days days)"
  { printf 'DAY\t>HIGH\t>MEDIUM\t>LOW\t>VISIBLE\t>RUNS\n'
    find "$dir" -name '*.tsv' -mtime -"$days" 2>/dev/null | LC_ALL=C sort | while IFS= read -r f; do
      b="${f##*/}"; awk -F'\t' -v day="${b:0:4}-${b:4:2}-${b:6:2}" '$1 == "#sum" { print day "\t" $2 "\t" $3 "\t" $4 "\t" $5 "/" $6 }' "$f"; done |
      awk -F'\t' 'BEGIN { OFS = "\t" } { last[$1] = $0; runs[$1]++; if (!($1 in seen)) { seen[$1] = 1; order[++n] = $1 } }
        END { for (i = n; i >= 1; i--) { split(last[order[i]], a, "\t"); print a[1], a[2], a[3], a[4], a[5], runs[order[i]] } }'; } |
    tk_table "PER DAY" "the last run of each day, newest first" "no saved runs yet - every kdash --fmea run (and the M view) saves one" "day" "days"
}

# ---- SECRETS MAP: certificates and keys in Secrets, who uses them, where they live -----
# (key Y, -v secrets, --secrets). Read-only, and only what your RBAC lets you read.
# What reaches kdash: Secret names, types, key names and sizes, PEM header kinds, and
# certificate blocks. kubectl's template drops every other value before kdash sees it:
# private keys, passwords and tokens are never received, printed or written to disk.
# (A value holding a certificate AND a key in one file is filtered in a pipe: only
# its CERTIFICATE blocks are kept.)  KDASH_SECRETS_KEYCHECK=1 additionally compares
# each tls.key with its certificate - the key is piped to openssl, never stored.
# Files: sm-secrets.tsv  NS NAME TYPE CREATED MANAGER KEYS NCERT IMMUTABLE
#        sm-certs.tsv    NS SECRET KEY IDX ROLE CN SANS ISSUER NOTBEFORE NOTAFTER ALG FP SELF KEYSTATE
#        sm-uses.tsv     NS SECRET HOW WORKLOAD POD CONTAINER INPOD RELOAD NODE HOSTPATH PODSTART OPTIONAL LOCAL
SM_KUBELET_DIR="${KDASH_KUBELET_DIR:-/var/lib/kubelet}"

sm_age() { local at; at="$(cat "${TOOLKIT_DIR:-/nonexistent}/sm.at" 2>/dev/null)"; case "$at" in [0-9]*) printf '%s' "$(( $(date +%s) - at ))" ;; *) printf 999999 ;; esac; }

# openssl text of one certificate -> NOTBEFORE NOTAFTER CN ISSUERCN FP SANS CA ALG SELF (TSV)
SM_X509_AWK='
function mon(m) { return (index("JanFebMarAprMayJunJulAugSepOctNovDec", m) + 2) / 3 }
function when(s,   a, t) { gsub(/  +/, " ", s); split(s, a, " "); split(a[3], t, ":")
  return epoch(sprintf("%04d-%02d-%02dT%02d:%02d:%02dZ", a[4], mon(a[1]), a[2], t[1], t[2], t[3])) }
function cn(s,   t) { t = s; if (match(t, /CN=[^,]*/)) return substr(t, RSTART + 3, RLENGTH - 3); return substr(s, 1, 60) }
/^notBefore=/ { nb = when(substr($0, 11)); next }
/^notAfter=/ { na = when(substr($0, 10)); next }
/^subject=/ { su = substr($0, 9); next }
/^issuer=/ { is = substr($0, 8); next }
/Fingerprint=/ { fp = $0; sub(/^.*=/, "", fp); gsub(/:/, "", fp); next }
/Subject Alternative Name/ { want = "san"; next }
/Basic Constraints/ { want = "bc"; next }
want == "san" { s = $0; gsub(/^ +/, "", s); gsub(/DNS:/, "", s); gsub(/IP Address:/, "", s); gsub(/, /, ",", s); sans = s; want = ""; next }
want == "bc" { ca = ($0 ~ /CA:TRUE/) ? "ca" : "leaf"; want = ""; next }
/Public Key Algorithm:/ { alg = $NF; next }
/Public-Key:/ { bits = $0; gsub(/[^0-9]/, "", bits); next }
END { if (na == "") exit 1
  a = (alg ~ /rsa/) ? "RSA" : (alg ~ /ec/) ? "EC" : (alg ~ /ED25519|ed25519/) ? "Ed25519" : alg
  if (bits != "" && a != "Ed25519") a = a " " bits
  printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n", nb, na, cn(su), cn(is), tolower(substr(fp, 1, 16)), (sans == "" ? "-" : sans), (ca == "" ? "leaf" : ca), (a == "" ? "-" : a), (su == is ? "self" : "") }'
sm__x509() { # < one PEM certificate
  local out
  out="$(openssl x509 -noout -startdate -enddate -subject -issuer -fingerprint -sha256 -nameopt RFC2253 -ext subjectAltName,basicConstraints \
          -text -certopt no_header,no_version,no_serial,no_signame,no_validity,no_subject,no_issuer,no_sigdump,no_aux,no_extensions 2>/dev/null)" ||
  out="$(openssl x509 -noout -startdate -enddate -subject -issuer -fingerprint -sha256 -nameopt RFC2253 2>/dev/null)" || return 1
  printf '%s\n' "$out" | LC_ALL=C awk "$TK_TIME_AWK$SM_X509_AWK"
}

sm__kind() { # first 24 base64 characters of a PEM value -> what it is
  case "$1" in
    LS0tLS1CRUdJTiBDRVJUSUZJ) printf cert ;;
    LS0tLS1CRUdJTiBQUklWQVRF) printf 'private key (PKCS8)' ;;
    LS0tLS1CRUdJTiBSU0EgUFJJ) printf 'private key (RSA)' ;;
    LS0tLS1CRUdJTiBFQyBQUklW) printf 'private key (EC)' ;;
    LS0tLS1CRUdJTiBEU0EgUFJJ) printf 'private key (DSA)' ;;
    LS0tLS1CRUdJTiBPUEVOU1NI) printf 'private key (OpenSSH)' ;;
    LS0tLS1CRUdJTiBFTkNSWVBU) printf 'private key (encrypted)' ;;
    LS0tLS1CRUdJTiBQVUJMSUMg) printf 'public key' ;;
    LS0tLS1CRUdJTiBUUlVTVEVE) printf cert ;;
    LS0tLS1CRUdJ*) printf 'PEM' ;;
    *) printf '' ;;
  esac
}
sm__kind_by_name() { # type key
  case "$1" in
    kubernetes.io/dockerconfigjson|kubernetes.io/dockercfg) printf 'registry credentials' ;;
    kubernetes.io/service-account-token) printf 'service-account token' ;;
    kubernetes.io/basic-auth|kubernetes.io/ssh-auth) printf 'credentials' ;;
    *) case "$2" in
         *.jks|*.p12|*.pfx|*.keystore|*.truststore|*keystore*|*truststore*) printf 'keystore (binary, not parsed)' ;;
         *) printf value ;;
       esac ;;
  esac
}

# ---- reads ---------------------------------------------------------------------------
sm__read_secrets() {
  local d="$TOOLKIT_DIR" w="$TOOLKIT_DIR/sm-work" err="$TOOLKIT_DIR/health-sm-secrets.err" rc n=0 max="${KDASH_SECRETS_MAX_CERTS:-600}"
  local rec a b c e f g h cur="" keys="" ncert=0 kind i pem line ks
  rm -rf "$w"; mkdir -p "$w"; : > "$d/sm-secrets.tsv"; : > "$d/sm-certs.tsv"
  # values: only PEM certificate values pass the template; every other value is reduced to its length
  # (a PEM value: its 18-byte header). Helm release payloads are left out at the API.
  "${KC[@]}" get secrets "${SCOPE[@]}" --field-selector 'type!=helm.sh/release.v1' --request-timeout="${KDASH_HEALTH_TIMEOUT:-12s}" -o 'go-template={{range .items}}{{$o := .}}S|{{.metadata.namespace}}|{{.metadata.name}}|{{.type}}|{{.metadata.creationTimestamp}}|{{.immutable}}|{{with .metadata.annotations}}{{index . "cert-manager.io/certificate-name"}}{{end}}|{{with .metadata.annotations}}{{index . "cert-manager.io/issuer-name"}}{{end}}|{{with .metadata.annotations}}{{index . "meta.helm.sh/release-name"}}{{end}}|{{with .metadata.labels}}{{index . "app.kubernetes.io/managed-by"}}{{end}}|{{range .metadata.ownerReferences}}{{.kind}}/{{.name}}{{end}}|{{with .metadata.annotations}}{{index . "kubernetes.io/service-account.name"}}{{end}}{{"\n"}}{{range $k, $v := .data}}K|{{$k}}|{{len $v}}|{{if ge (len $v) 28}}{{if eq (slice $v 0 12) "LS0tLS1CRUdJ"}}{{slice $v 0 24}}{{end}}{{end}}|{{if ge (len $v) 28}}{{if eq (slice $v 0 28) "LS0tLS1CRUdJTiBDRVJUSUZJQ0FU"}}{{$v}}{{end}}{{end}}{{"\n"}}{{end}}E|{{"\n"}}{{end}}' 2> "$err" |
  { local sns="" sname="" stype="" screated="" simm="" mgr=""
    while IFS='|' read -r rec a b c e f g h i line ks pem; do
      case "$rec" in
        S) sns="$a"; sname="$b"; stype="$c"; screated="$e"; simm="$f"; keys=""; ncert=0
           # manager: cert-manager certificate, Helm release, an owner, or by hand
           mgr="manual"
           if [ -n "${g#<no value>}" ]; then mgr="cert-manager: ${g}${h:+ (issuer ${h#<no value>})}"; mgr="${mgr% (issuer )}"
           elif [ -n "${i#<no value>}" ]; then mgr="helm: $i"
           elif [ -n "${ks#<no value>}" ]; then mgr="owner: $ks"
           elif [ -n "${pem#<no value>}" ]; then mgr="service account: $pem"
           elif [ -n "${line#<no value>}" ]; then mgr="$line"; fi ;;
        K) # a = key, b = base64 length, c = PEM header (24 chars), e = certificate value (base64) or empty
           kind="$(sm__kind "$c")"; [ -n "$kind" ] || kind="$(sm__kind_by_name "$stype" "$a")"
           if [ -n "$e" ] && [ "$n" -lt "$max" ]; then
             # only CERTIFICATE blocks are kept: anything else in the value is dropped in the pipe
             f="$w/$(( n + 1 ))"
             printf '%s' "$e" | base64 -d 2>/dev/null | LC_ALL=C awk -v p="$f" '
               /-----BEGIN (TRUSTED )?CERTIFICATE-----/ { c++; o = p "." c ".pem" }
               /-----BEGIN .*PRIVATE KEY-----/ { pk = 1 }
               o != "" { print > o }
               /-----END (TRUSTED )?CERTIFICATE-----/ { if (o != "") close(o); o = "" }
               END { print c + 0, pk + 0 }' > "$f.n"
             read -r g h < "$f.n"; rm -f "$f.n"
             [ "${h:-0}" = 1 ] && kind="cert + private key in one file"
             i=1
             while [ "$i" -le "${g:-0}" ]; do
               if line="$(sm__x509 < "$f.$i.pem")"; then
                 n=$(( n + 1 )); ncert=$(( ncert + 1 ))
                 printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$sns" "$sname" "$a" "$i" "$line" "$([ "${h:-0}" = 1 ] && echo samefile)" >> "$d/sm-certs.raw"
                 cp -f "$f.$i.pem" "$w/fp-$(printf '%s' "$line" | cut -f5).pem" 2>/dev/null
               fi
               rm -f "$f.$i.pem"; i=$(( i + 1 ))
             done
           fi
           keys="$keys${keys:+; }$a [$kind, $(( b * 3 / 4 )) B]" ;;
        E) [ -z "$sname" ] || printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$sns" "$sname" "$stype" "$screated" "$mgr" "${keys:-(no data)}" "$ncert" "$([ "$simm" = true ] && echo immutable)" >> "$d/sm-secrets.tsv"
           sname="" ;;
      esac
    done; }
  rc="${PIPESTATUS[0]}"
  if [ "$rc" = 0 ]; then health__status sm-secrets ok 'successful API read'; else : > "$d/sm-secrets.tsv"; rm -f "$d/sm-certs.raw"; health__failure sm-secrets "$err"; fi
  # per certificate: role in its file (first = the certificate, further ones = its chain) and the key beside it
  if [ -s "$d/sm-certs.raw" ]; then
    LC_ALL=C awk -F'\t' 'BEGIN { OFS = "\t" }
      FILENAME ~ /sm-secrets/ { K[$1 "/" $2] = $6; T[$1 "/" $2] = $3; next }
      { s = $1 "/" $2; role = ($4 > 1) ? ($11 == "ca" ? "chain CA" : "chain") : ($11 == "ca" ? "CA" : "certificate")
        ks = ""
        if ($4 > 1) ks = "-"
        else if ($14 == "samefile") ks = "in the same file"
        else if (T[s] == "kubernetes.io/tls" || $3 == "tls.crt") ks = (K[s] ~ /tls\.key \[private key/) ? "tls.key present" : "{r}tls.key MISSING"
        else if (K[s] ~ /private key/) ks = "key in this secret"
        else ks = (role == "CA") ? "none (CA only)" : "no key here"
        print $1, $2, $3, $4, role, $7, $10, $8, $5, $6, $12, $9, $13, ks, "-" }' "$d/sm-secrets.tsv" "$d/sm-certs.raw" > "$d/sm-certs.tsv"
    sm__chain
  fi
  rm -f "$d/sm-certs.raw"
  # optional: does each tls.key belong to its certificate? (the key goes through a pipe only)
  if [ "${KDASH_SECRETS_KEYCHECK:-0}" = 1 ] && [ "$rc" = 0 ] && [ -s "$d/sm-certs.tsv" ]; then
    awk -F'\t' '$3 == "tls.crt" && $4 == 1 && $14 == "tls.key present" { print $1 "\t" $2 "\t" $12 }' "$d/sm-certs.tsv" | head -n "${KDASH_SECRETS_KEYCHECK_MAX:-100}" |
    while IFS=$'\t' read -r a b c; do
      e="$(openssl x509 -in "$w/fp-$c.pem" -noout -pubkey 2>/dev/null | openssl pkey -pubin -outform DER 2>/dev/null | openssl dgst -sha256 2>/dev/null | awk '{ print $NF }')"
      f="$("${KC[@]}" get secret "$b" -n "$a" --request-timeout=8s -o 'go-template={{index .data "tls.key"}}' 2>/dev/null | base64 -d 2>/dev/null | openssl pkey -pubout -outform DER 2>/dev/null | openssl dgst -sha256 2>/dev/null | awk '{ print $NF }')"
      [ -n "$e" ] && [ -n "$f" ] || continue
      printf '%s\t%s\t%s\n' "$a" "$b" "$([ "$e" = "$f" ] && echo 'tls.key matches' || echo '{r}tls.key DOES NOT MATCH')"
    done > "$d/sm-keycheck.tsv"
    [ ! -s "$d/sm-keycheck.tsv" ] || { LC_ALL=C awk -F'\t' 'BEGIN { OFS = "\t" } FILENAME ~ /keycheck/ { R[$1 "/" $2] = $3; next }
        { if ($3 == "tls.crt" && $4 == 1 && ($1 "/" $2) in R) $14 = R[$1 "/" $2]; print }' "$d/sm-keycheck.tsv" "$d/sm-certs.tsv" > "$d/sm-certs.new" && mv -f "$d/sm-certs.new" "$d/sm-certs.tsv"; }
    rm -f "$d/sm-keycheck.tsv"
  fi
  return 0
}

# Is each certificate really signed by what is stored beside it? (signatures only: an
# expired or weak certificate is reported elsewhere, not here) -> column 15 of sm-certs.tsv
sm__verify() { # leaf cafile [untrusted] -> openssl's verdict text, exit 0 when the chain links
  local out
  out="$(openssl verify -no_check_time -auth_level 0 -partial_chain -CAfile "$2" ${3:+-untrusted "$3"} "$1" 2>&1)" && { printf '%s' "$out"; return 0; }
  case "$out" in *[Uu]sage:*|*"nknown option"*|*"nrecognized"*|*"Invalid command"*)   # an older openssl: without the two newer switches
    out="$(openssl verify -partial_chain -CAfile "$2" ${3:+-untrusted "$3"} "$1" 2>&1)" && { printf '%s' "$out"; return 0; } ;; esac
  printf '%s' "$out"; return 1
}
sm__chain() {
  local d="$TOOLKIT_DIR" w="$TOOLKIT_DIR/sm-work" ns sec key leaf self iss chain c2 cas f out st n=0
  command -v openssl >/dev/null 2>&1 || return 0
  LC_ALL=C awk -F'\t' 'BEGIN { OFS = "\t" }
      { k = $1 SUBSEP $2 SUBSEP $3
        if ($4 == 1) { ord[++n] = k; LF[k] = $12; SF[k] = ($13 == "" ? "-" : $13); IS[k] = $8; RO[k] = $5 }
        else { CH[k] = CH[k] (CH[k] == "" ? "" : ",") $12; if (!(k in C2)) C2[k] = $6 }
        if ($3 == "ca.crt") CA[$1 SUBSEP $2] = CA[$1 SUBSEP $2] (CA[$1 SUBSEP $2] == "" ? "" : ",") $12 }
      END { for (i = 1; i <= n; i++) { k = ord[i]; split(k, a, SUBSEP); if (RO[k] != "certificate") continue
          print a[1], a[2], a[3], LF[k], SF[k], (IS[k] == "" ? "-" : IS[k]), (CH[k] == "" ? "-" : CH[k]), (C2[k] == "" ? "-" : C2[k]), (a[3] != "ca.crt" && CA[a[1] SUBSEP a[2]] != "" ? CA[a[1] SUBSEP a[2]] : "-") } }' "$d/sm-certs.tsv" |
  while IFS=$'\t' read -r ns sec key leaf self iss chain c2 cas; do
    n=$(( n + 1 )); [ "$n" -le "${KDASH_SECRETS_CHAIN_MAX:-300}" ] || break
    [ -f "$w/fp-$leaf.pem" ] || continue
    : > "$w/ca.pem"; : > "$w/un.pem"
    if [ "$chain" != - ]; then for f in ${chain//,/ }; do cat "$w/fp-$f.pem" 2>/dev/null; done > "$w/un.pem"; fi
    if [ "$self" = self ]; then st="self-signed"
    elif [ "$cas" != - ]; then
      for f in ${cas//,/ }; do cat "$w/fp-$f.pem" 2>/dev/null; done > "$w/ca.pem"
      if out="$(sm__verify "$w/fp-$leaf.pem" "$w/ca.pem" "$([ -s "$w/un.pem" ] && printf '%s' "$w/un.pem")")"; then st="{g}ok: signed by the ca.crt beside it"
      else case "$out" in
          *"signature failure"*|*"unable to get local issuer"*|*"unable to get issuer"*|*"unable to verify the first"*) st="{r}NOT signed by the ca.crt beside it" ;;
          *) st="{d}not verified ($(printf '%s' "$out" | sed -n 's/^error [0-9]* at [0-9]* depth lookup: *//p' | head -1 | cut -c1-40))" ;; esac
      fi
    elif [ "$chain" != - ]; then
      if out="$(sm__verify "$w/fp-$leaf.pem" "$w/un.pem")"; then
        if [ "$c2" = "$iss" ]; then st="{g}ok: chain in the file (issuer $iss)"; else st="{y}chain in the file is out of order (issuer $iss is not next)"; fi
      else case "$out" in
          *"signature failure"*|*"unable to get local issuer"*|*"unable to get issuer"*|*"unable to verify the first"*) st="{y}the chain in the file does not sign it (issuer $iss is missing)" ;;
          *) st="{d}not verified ($(printf '%s' "$out" | sed -n 's/^error [0-9]* at [0-9]* depth lookup: *//p' | head -1 | cut -c1-40))" ;; esac
      fi
    else st="issuer not in this Secret"; fi
    printf '%s\t%s\t%s\t%s\n' "$ns" "$sec" "$key" "$st"
  done > "$d/sm-chain.tsv"
  if [ -s "$d/sm-chain.tsv" ]; then
    LC_ALL=C awk -F'\t' 'BEGIN { OFS = "\t" } FILENAME ~ /sm-chain/ { C[$1, $2, $3] = $4; next }
      { if ($4 == 1 && (($1, $2, $3) in C)) $15 = C[$1, $2, $3]; print }' "$d/sm-chain.tsv" "$d/sm-certs.tsv" > "$d/sm-certs.new" && mv -f "$d/sm-certs.new" "$d/sm-certs.tsv"
  fi
  rm -f "$d/sm-chain.tsv" "$w/ca.pem" "$w/un.pem"
  return 0
}

sm__read_refs() { # pods and ingresses: who refers to which Secret (works without any right on Secrets)
  local d="$TOOLKIT_DIR" tmp err
  tmp="$d/health-sm-pods.new"; err="$d/health-sm-pods.err"
  if "${KC[@]}" get pods "${SCOPE[@]}" --request-timeout="${KDASH_HEALTH_TIMEOUT:-12s}" -o 'go-template={{range .items}}{{$o := .}}U|{{.metadata.namespace}}|{{.metadata.name}}|{{.metadata.uid}}|{{.spec.nodeName}}|{{.status.startTime}}|{{range .metadata.ownerReferences}}{{.kind}}/{{.name}}{{end}}|{{range $k, $v := .metadata.labels}}{{$k}}={{$v}},{{end}}{{"\n"}}{{range .spec.volumes}}{{$vn := .name}}{{with .secret}}V|{{$o.metadata.namespace}}|{{$o.metadata.name}}|{{$vn}}|{{.secretName}}|{{.optional}}|volume|{{range .items}}{{.key}}>{{.path}},{{end}}{{"\n"}}{{end}}{{with .projected}}{{range .sources}}{{with .secret}}V|{{$o.metadata.namespace}}|{{$o.metadata.name}}|{{$vn}}|{{.name}}|{{.optional}}|projected|{{range .items}}{{.key}}>{{.path}},{{end}}{{"\n"}}{{end}}{{end}}{{end}}{{end}}{{range .spec.imagePullSecrets}}I|{{$o.metadata.namespace}}|{{$o.metadata.name}}|{{.name}}{{"\n"}}{{end}}{{range .spec.initContainers}}{{$c := .}}{{range .volumeMounts}}M|{{$o.metadata.namespace}}|{{$o.metadata.name}}|{{$c.name}} (init)|{{.name}}|{{.mountPath}}|{{.subPath}}{{"\n"}}{{end}}{{range .env}}{{$e := .}}{{with .valueFrom}}{{with .secretKeyRef}}E|{{$o.metadata.namespace}}|{{$o.metadata.name}}|{{$c.name}} (init)|{{.name}}|{{.key}}|{{.optional}}|{{$e.name}}{{"\n"}}{{end}}{{end}}{{end}}{{range .envFrom}}{{with .secretRef}}F|{{$o.metadata.namespace}}|{{$o.metadata.name}}|{{$c.name}} (init)|{{.name}}|{{.optional}}{{"\n"}}{{end}}{{end}}{{end}}{{range .spec.containers}}{{$c := .}}{{range .volumeMounts}}M|{{$o.metadata.namespace}}|{{$o.metadata.name}}|{{$c.name}}|{{.name}}|{{.mountPath}}|{{.subPath}}{{"\n"}}{{end}}{{range .env}}{{$e := .}}{{with .valueFrom}}{{with .secretKeyRef}}E|{{$o.metadata.namespace}}|{{$o.metadata.name}}|{{$c.name}}|{{.name}}|{{.key}}|{{.optional}}|{{$e.name}}{{"\n"}}{{end}}{{end}}{{end}}{{range .envFrom}}{{with .secretRef}}F|{{$o.metadata.namespace}}|{{$o.metadata.name}}|{{$c.name}}|{{.name}}|{{.optional}}{{"\n"}}{{end}}{{end}}{{end}}{{end}}' > "$tmp" 2> "$err"; then
    mv -f "$tmp" "$d/health-sm-pods.raw"; health__status sm-pods ok 'successful API read'
  else rm -f "$tmp"; : > "$d/health-sm-pods.raw"; health__failure sm-pods "$err"; fi
  tmp="$d/health-sm-ing.new"; err="$d/health-sm-ing.err"
  if "${KC[@]}" get ingresses.networking.k8s.io "${SCOPE[@]}" --request-timeout="${KDASH_HEALTH_TIMEOUT:-12s}" -o 'go-template={{range .items}}{{$o := .}}{{range .spec.tls}}G|{{$o.metadata.namespace}}|{{$o.metadata.name}}|{{.secretName}}|{{range .hosts}}{{.}},{{end}}{{"\n"}}{{end}}{{end}}' > "$tmp" 2> "$err"; then
    mv -f "$tmp" "$d/health-sm-ing.raw"; health__status sm-ing ok 'successful API read'
  else rm -f "$tmp"; : > "$d/health-sm-ing.raw"; health__failure sm-ing "$err"; fi
  return 0
}

# one row per (secret, pod, way of use); services of each workload in sm-svc.tsv
sm__uses() {
  local d="$TOOLKIT_DIR"
  LC_ALL=C awk -v kd="$SM_KUBELET_DIR" -v svcf="$d/sm-svc.tsv" "$TK_TIME_AWK"'
    function wl(owner, pod,   k, n) { if (owner == "") return "pod/" pod
      k = owner; sub(/\/.*/, "", k); n = owner; sub(/^[^\/]*\//, "", n)
      if (k == "ReplicaSet") { sub(/-[a-z0-9]+$/, "", n); return "deployment/" n }
      if (k == "Job") return "job/" n
      return tolower(k) "/" n }
    function out(ns, sec, how, pod, ctr, inpod, reload, hp, opt,   p) { p = ns "/" pod
      printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t\n", ns, sec, how, W[p], pod, ctr, inpod, reload, (N[p] == "" ? "-" : N[p]), hp, ST[p], opt }
    function files(dir, sec, items,   n, a, i, q, o, c) { o = ""; c = 0
      if (items != "") { n = split(items, a, ","); for (i = 1; i <= n; i++) if (a[i] != "") { q = index(a[i], ">"); o = o (o == "" ? "" : ",") substr(a[i], q + 1); c++ } }
      else if (sec in KN) { o = KN[sec]; c = KC_[sec] }
      if (c == 0) return dir "/"
      return (c == 1) ? dir "/" o : dir "/{" o "}" }
    BEGIN { FS = "|" }
    FILENAME ~ /sm-secrets\.tsv$/ { split($0, t, "\t"); n = split(t[6], ka, "; "); o = ""; c = 0
      for (i = 1; i <= n; i++) { k = ka[i]; sub(/ \[.*$/, "", k); if (k != "" && k != "(no data)") { o = o (o == "" ? "" : ",") k; c++ } }
      KN[t[1] "/" t[2]] = o; KC_[t[1] "/" t[2]] = c; next }
    index($0, "<no value>") { gsub(/<no value>/, "") }
    $1 == "S" { if ($7 != "") { ns_ = $2; SV[++nsv] = $2 SUBSEP $3 SUBSEP $7 }; next }
    $1 == "U" { p = $2 "/" $3; UID[p] = $4; N[p] = $5; ST[p] = ($6 == "" ? "" : epoch($6)); W[p] = wl($7, $3); L[p] = $8; PODS[++np] = p; PNS[p] = $2; next }
    $1 == "V" { p = $2 "/" $3; nv++; VP[nv] = p; VN[nv] = $4; VS[nv] = $5; VO[nv] = $6; VK[nv] = $7; VI[nv] = $8; next }
    $1 == "M" { p = $2 "/" $3; k = p SUBSEP $5; MC[k] = MC[k] (MC[k] == "" ? "" : "\n") $4 "|" $6 "|" $7; next }
    $1 == "E" { p = $2 "/" $3; out($2, $5, "env", $3, $4, "$" $8 " <- " $6, "restart needed (env)", "-", $7); next }
    $1 == "F" { p = $2 "/" $3; out($2, $5, "envFrom", $3, $4, "all keys as env variables", "restart needed (env)", "-", $6); next }
    $1 == "I" { p = $2 "/" $3; out($2, $4, "imagePull", $3, "-", "(image pull credentials)", "next image pull", "-", ""); next }
    $1 == "G" { printf "%s\t%s\tingress-tls\tingress/%s\t-\t-\thosts: %s\tcontroller reloads it\t-\t-\t\t\t\n", $2, $4, $3, ($5 == "" ? "(all)" : substr($5, 1, length($5) - 1)); next }
    END {
      for (i = 1; i <= nv; i++) { p = VP[i]; split(p, a, "/"); k = p SUBSEP VN[i]
        hp = (N[p] == "" || UID[p] == "") ? "-" : kd "/pods/" UID[p] "/volumes/kubernetes.io~" (VK[i] == "projected" ? "projected" : "secret") "/" VN[i]
        if (!(k in MC)) { out(a[1], VS[i], VK[i], a[2], "-", "(volume " VN[i] " is not mounted)", "-", hp, VO[i]); continue }
        m = split(MC[k], ml, "\n")
        for (j = 1; j <= m; j++) { split(ml[j], f, "|")
          mp = f[2]; sub(/\/+$/, "", mp)
          if (f[3] != "") out(a[1], VS[i], VK[i], a[2], f[1], f[2] "  (subPath " f[3] ")", "restart needed (subPath)", hp, VO[i])
          else out(a[1], VS[i], VK[i], a[2], f[1], files(mp, a[1] "/" VS[i], VI[i]), "auto-sync by the kubelet", hp, VO[i]) } }
      # Services whose selector matches the pods of a workload
      for (i = 1; i <= np; i++) { p = PODS[i]; n = split(L[p], la, ","); for (x in LB) delete LB[x]
        for (j = 1; j <= n; j++) { q = index(la[j], "="); if (q) LB[substr(la[j], 1, q - 1)] = substr(la[j], q + 1) }
        for (s = 1; s <= nsv; s++) { split(SV[s], sv, SUBSEP); if (sv[1] != PNS[p]) continue
          n2 = split(sv[3], sl, ","); ok = 0
          for (j = 1; j <= n2; j++) { if (sl[j] == "") continue; q = index(sl[j], "="); if (LB[substr(sl[j], 1, q - 1)] != substr(sl[j], q + 1)) { ok = -1; break } ok = 1 }
          if (ok == 1 && !((PNS[p], W[p], sv[2]) in seen)) { seen[PNS[p], W[p], sv[2]] = 1; printf "%s\t%s\t%s\n", PNS[p], W[p], sv[2] > svcf } } }
    }' "$d/sm-secrets.tsv" "$d/health-services.raw" "$d/health-sm-pods.raw" "$d/health-sm-ing.raw" 2>/dev/null > "$d/sm-uses.tsv"
  [ -f "$d/sm-svc.tsv" ] || : > "$d/sm-svc.tsv"
  # on this host: is the file the kubelet wrote the certificate the Secret holds now?
  if [ -d "$SM_KUBELET_DIR/pods" ] && [ -s "$d/sm-certs.tsv" ]; then
    local ln ns sec hp f fp cur st
    awk -F'\t' '$10 != "-" { print NR "\t" $1 "\t" $2 "\t" $10 }' "$d/sm-uses.tsv" | head -n "${KDASH_SECRETS_LOCAL_MAX:-300}" |
    while IFS=$'\t' read -r ln ns sec hp; do
      [ -d "$hp" ] || continue
      st="present"
      for f in "$hp"/*; do
        [ -f "$f" ] && [ -r "$f" ] || continue
        grep -q 'BEGIN CERTIFICATE' "$f" 2>/dev/null || continue
        fp="$(openssl x509 -in "$f" -noout -fingerprint -sha256 2>/dev/null | sed 's/^.*=//; s/://g' | tr 'A-F' 'a-f' | cut -c1-16)"
        [ -n "$fp" ] || continue
        # the Secret's current certificate for that file name, else any of its certificates
        cur="$(awk -F'\t' -v n="$ns" -v s="$sec" -v k="${f##*/}" -v x="$fp" '$1 == n && $2 == s && $4 == 1 && $3 == k { c = $12 } $1 == n && $2 == s && $12 == x { any = 1 } END { print (c != "" ? c : (any ? x : "none")) }' "$d/sm-certs.tsv")"
        if [ "$cur" = "$fp" ]; then st="in sync"; else st="STALE (file differs from the Secret)"; break; fi
      done
      printf '%s\t%s\n' "$ln" "$st"
    done > "$d/sm-local.tsv"
    if [ -s "$d/sm-local.tsv" ]; then
      awk -F'\t' 'BEGIN { OFS = "\t" } FILENAME ~ /sm-local/ { L[$1] = $2; next } { if (FNR in L) $13 = L[FNR]; print }' "$d/sm-local.tsv" "$d/sm-uses.tsv" > "$d/sm-uses.new" && mv -f "$d/sm-uses.new" "$d/sm-uses.tsv"
    fi
    rm -f "$d/sm-local.tsv"
  fi
  return 0
}

# findings -> sm-findings.tsv: SEVERITY OBJECT FINDING HINTKEY   (HINTKEY = key|ns|name|x1)
sm__findings() {
  local d="$TOOLKIT_DIR"
  LC_ALL=C awk -F'\t' -v now="$(date +%s)" -v warn="${CERT_WARN_DAYS:-30}" -v crit="${CERT_CRIT_DAYS:-7}" -v sec_ok="$([ "$(health__state sm-secrets)" = ok ] && echo 1 || echo 0)" '
    function f(sev, obj, txt, key) { printf "%s\t%s\t%s\t%s\n", sev, obj, txt, key }
    function days(e) { return int((e - now) / 86400) }
    FILENAME ~ /sm-secrets/ { EX[$1 "/" $2] = 1; TY[$1 "/" $2] = $3; MG[$1 "/" $2] = $5; KS[$1 "/" $2] = $6; next }
    FILENAME ~ /sm-certs/ { s = $1 "/" $2; dl = days($10); what = ($5 ~ /CA/ ? "CA " : ($5 == "chain" ? "chain " : "")) "certificate " $6 " (" $3 ")"
      by = (MG[s] ~ /^cert-manager/) ? "; " MG[s] " should renew it" : "; managed by hand"
      if ($10 < now) f("{r}CRITICAL", s, what " EXPIRED " (-dl) " d ago" by, "sm-expired|" $1 "|" $2 "|" $3)
      else if (dl <= crit) f("{r}CRITICAL", s, what " expires in " dl " d" by, "sm-expiring|" $1 "|" $2 "|" $3)
      else if (dl <= warn) f("{y}WARNING", s, what " expires in " dl " d" by, "sm-expiring|" $1 "|" $2 "|" $3)
      if ($14 ~ /MISSING|NOT MATCH/) { t = $14; sub(/^\{r\}/, "", t); f("{r}CRITICAL", s, t " for " $6, "sm-key|" $1 "|" $2) }
      if ($15 ~ /^\{r\}/) { t = $15; sub(/^\{r\}/, "", t); f("{r}CRITICAL", s, "certificate " $6 " (" $3 ") is " t ": clients that trust that CA will reject it", "sm-chain|" $1 "|" $2 "|" $3) }
      else if ($15 ~ /^\{y\}/) { t = $15; sub(/^\{y\}/, "", t); f("{y}WARNING", s, "certificate " $6 " (" $3 "): " t, "sm-chain|" $1 "|" $2 "|" $3) }
      if ($11 ~ /^RSA / && substr($11, 5) + 0 < 2048 && $4 == 1) f("{y}WARNING", s, "weak key: " $11 " in " $6, "sm-weak|" $1 "|" $2)
      if ($4 == 1) NB[s] = ($9 > NB[s]) ? $9 : NB[s]
      if ($4 == 1 && $5 != "CA") { if (!(($12) in FPS)) FPS[$12] = s; else if (FPS[$12] != s && !((s, $12) in dup)) { dup[s, $12] = 1; DUP[$12] = (DUP[$12] == "" ? FPS[$12] : DUP[$12]) ", " s } }
      next }
    FILENAME ~ /sm-uses/ { s = $1 "/" $2; U[s]++
      if (sec_ok == "1" && !(s in EX) && $12 != "true" && !((s, $4) in miss)) { miss[s, $4] = 1; f("{r}CRITICAL", s, "Secret does not exist but " $4 " needs it (" $3 "): " ($3 == "ingress-tls" ? "that host is served with the controller default certificate" : ($3 == "imagePull" ? "private images cannot be pulled" : "its pods cannot start")), "sm-missing|" $1 "|" $2 "|" $4) }
      if ($8 ~ /^restart/ && (s in NB) && $11 != "" && NB[s] > $11 && !((s, $4) in rs)) { rs[s, $4] = 1
        f("{y}WARNING", s, $4 " started before the current certificate was issued and reads it via " ($3 == "env" || $3 == "envFrom" ? "env" : "subPath") ": it still runs the old one", "sm-restart|" $1 "|" $2 "|" $4) }
      if ($13 ~ /^STALE/ && !((s, $5) in stl)) { stl[s, $5] = 1; f("{y}WARNING", s, "the file on this host for pod " $5 " is not the certificate the Secret holds now", "sm-restart|" $1 "|" $2 "|" $4) }
      next }
    END { for (x in DUP) f("{d}INFO", FPS[x], "the same certificate is stored in several Secrets: " DUP[x] " - rotate them together", "sm-dup|" substr(FPS[x], 1, index(FPS[x], "/") - 1) "|" substr(FPS[x], index(FPS[x], "/") + 1)) }
  ' "$d/sm-secrets.tsv" "$d/sm-certs.tsv" "$d/sm-uses.tsv" 2>/dev/null |
    LC_ALL=C awk -F'\t' '{ r = ($1 ~ /CRIT/) ? 1 : ($1 ~ /WARN/) ? 2 : 3; print r "\t" $0 }' | LC_ALL=C sort -t $'\t' -k1,1n -k3,3 | cut -f2- > "$d/sm-findings.tsv"
}

sm_collect() {
  local d="$TOOLKIT_DIR" u
  [ -s "$d/health-services.status" ] || health_collect
  # who am I, and may I read Secrets here (auth can-i; nothing is asked beyond reads)
  u="$("${KC[@]}" auth whoami --request-timeout=8s 2>/dev/null | awk '$1 == "Username" { $1 = ""; sub(/^ +/, ""); print; exit }')"
  [ -n "$u" ] || u="$("${KC[@]}" config view --minify -o 'jsonpath={.contexts[0].context.user}' 2>/dev/null)"
  sm__read_secrets; sm__read_refs; sm__uses; sm__findings
  rm -rf "$d/sm-work"
  awk -F'\t' -v now="$(date +%s)" -v warn="${CERT_WARN_DAYS:-30}" -v crit="${CERT_CRIT_DAYS:-7}" -v u="${u:-unknown}" -v st="$(health__state sm-secrets)" '
    FILENAME ~ /sm-secrets/ { ns++; next }
    FILENAME ~ /sm-certs/ { nc++; dl = ($10 - now) / 86400; if ($10 < now) ex++; else if (dl <= crit) cr++; else if (dl <= warn) wa++; next }
    FILENAME ~ /sm-findings/ { if ($1 ~ /CRIT/) fc++; else if ($1 ~ /WARN/) fw++; next }
    END { printf "%d\t%d\t%d\t%d\t%d\t%d\t%d\t%s\t%s\n", ns, nc, ex, cr, wa, fc, fw, u, st }' "$d/sm-secrets.tsv" "$d/sm-certs.tsv" "$d/sm-findings.tsv" 2>/dev/null > "$d/sm.summary"
  date +%s > "$d/sm.at"
  return 0
}

sm_exit_code() { # 2 expired / critical findings, 1 warnings, 0 otherwise
  awk -F'\t' '{ print ($6 > 0) ? 2 : ($7 > 0) ? 1 : 0 }' "$TOOLKIT_DIR/sm.summary" 2>/dev/null || echo 0
}

# ---- runbook lines (read = may run with Enter; CHANGE = printed only) -----------------
sm_hints() { # key ns name x1
  local key="$1" ns="${2:-}" name="${3:-}" x1="${4:-}" n; n="$(rb_q "$name")"
  case "$key" in
    sm-expired|sm-expiring|sm-weak|sm-key|sm-dup|sm-chain)
      rb_line read "$(rb_k "$ns" describe secret "$n")" "type, key names and sizes (never the values)"
      rb_line read "$(rb_k "$ns" get secret "$n" -o custom-columns=NAME:.metadata.name,TYPE:.type,OWNER:.metadata.ownerReferences[*].name,CREATED:.metadata.creationTimestamp)" "type, owner and age"
      x1="${x1:-tls.crt}"; rb_line note "inspect the certificate: $(rb_k "$ns" get secret "$n" -o "jsonpath='{.data.${x1//./\\.}}'") | base64 -d | openssl x509 -noout -subject -issuer -dates"
      case "$key" in sm-expired|sm-expiring)
        rb_line note "cert-manager: cmctl renew <certificate> -n $ns (or delete the Secret: it is issued again). By hand: replace it with the next line"
        rb_line CHANGE "$(rb_k "$ns" create secret tls "$n" --cert=NEW.crt --key=NEW.key --dry-run=client -o yaml) | kubectl apply -f -" "then restart the workloads marked \"restart needed\" in WHERE USED" ;; esac
      [ "$key" != sm-chain ] || rb_line note "tls.crt must hold the certificate first, then its intermediates in order; ca.crt the CA that signed them. Check by hand: openssl verify -CAfile ca.crt -untrusted chain.pem cert.pem"
      [ "$key" != sm-key ] || rb_line note "a kubernetes.io/tls Secret needs tls.crt and tls.key from the same key pair; KDASH_SECRETS_KEYCHECK=1 compares them" ;;
    sm-missing)
      rb_line read "$(rb_k "$ns" get secrets)" "the Secrets that do exist (a typo, another namespace?)"
      rb_line read "$(rb_k "$ns" get events --field-selector reason=FailedMount)" "mount errors naming it"
      rb_line note "create the Secret (chart value, cert-manager Certificate or kubectl create secret); $x1 starts once it exists" ;;
    sm-restart)
      rb_line read "$(rb_k "$ns" get pods -o wide)" "the pods and when they started"
      rb_line CHANGE "$(rb_k "$ns" rollout restart "${x1:-deployment/NAME}")" "env and subPath mounts are read once, at container start" ;;
    *) return 1 ;;
  esac
  return 0
}

# ---- screens: tables only ----------------------------------------------------------------
sm__chip() { # label value colour(41;97)
  if [ "${TK_COLOR:-0}" = 1 ]; then printf '~[1;%sm %s %s ~[0m ' "$3" "$2" "$1"; else printf '%s %s   ' "$2" "$1"; fi
}
sm_render() {
  local d="$TOOLKIT_DIR" ns nc ex cr wa fc fw u st now num="$TOOLKIT_DIR/sm-numbered.tsv" one=1
  [ "${ALL_NS:-0}" != 1 ] || one=0     # one namespace: its name is in the header, not in every row
  tk_title "SECRETS" "certificates and keys in Secrets: expiry, who manages them, who uses them and where the files are - values are never read"
  if [ ! -s "$d/sm.summary" ]; then printf '\nReading Secrets (names, types, certificates) and every reference to them ...\n'; return 0; fi
  IFS=$'\t' read -r ns nc ex cr wa fc fw u st < "$d/sm.summary"; now="$(date +%s)"
  printf '\n '
  if [ "$st" = ok ]; then
    sm__chip EXPIRED "$ex" '41;97'; sm__chip "CRITICAL (<= ${CERT_CRIT_DAYS:-7} d)" "$cr" '41;97'; sm__chip "WARNING (<= ${CERT_WARN_DAYS:-30} d)" "$wa" '43;30'
    sm__chip certificates "$nc" '47;30'; sm__chip secrets "$ns" '47;30'
  else   # never zeros for something that could not be read
    sm__chip "- Secrets read $st: certificates and expiry unknown" "NOT VISIBLE" '43;30'
    sm__chip "references from pods / ingresses" "$(cut -f1,2 "$d/sm-uses.tsv" 2>/dev/null | sort -u | grep -c .)" '47;30'
  fi
  if [ "${TK_COLOR:-0}" = 1 ]; then printf ' ~[90muser %s - read %ss ago - r re-reads~[0m\n' "$u" "$(sm_age)"; else printf '  user %s - read %ss ago\n' "$u" "$(sm_age)"; fi
  # access: one table row per source, so a refused read is never mistaken for "nothing there"
  { printf 'SOURCE\tACCESS*\tUSED FOR~\n'
    printf 'secrets\t%s\tnames, types, key names, certificates (private keys and other values are dropped by kubectl before kdash sees them)\n' "$st"
    printf 'pods\t%s\tvolume mounts, env, envFrom, imagePullSecrets, node and pod UID (host path)\n' "$(health__state sm-pods)"
    printf 'ingresses\t%s\tTLS secretName per host\n' "$(health__state sm-ing)"
    printf 'services\t%s\twhich Services front the workloads that use a Secret\n' "$(health__state services)"; } |
    TK_COUNT=0 tk_table "ACCESS" "user $u, scope $([ "${ALL_NS:-0}" = 1 ] && echo 'all namespaces' || echo "${NS:-?}") - only what your RBAC allows is read"
  if [ "$st" != ok ]; then
    tk_note "Secrets cannot be read here ($st): certificates and expiry are not visible to you. References from pods and ingresses are still shown below."
    tk_note "To see them, ask for: verbs get, list on resource secrets in this namespace (read-only)."
  fi
  # 1. certificates: the list (what expires when, who uses it), then the details by the same #
  awk -F'\t' -v now="$now" -v warn="${CERT_WARN_DAYS:-30}" -v crit="${CERT_CRIT_DAYS:-7}" -v one="$one" 'BEGIN { OFS = "\t" }
      FILENAME ~ /sm-secrets/ { MG[$1 "/" $2] = $5; next }
      FILENAME ~ /sm-uses/ { s = $1 "/" $2; if (!((s, $4) in seen)) { seen[s, $4] = 1; UB[s] = UB[s] (UB[s] == "" ? "" : ", ") $4 }; next }
      { s = $1 "/" $2; dl = int(($10 - now) / 86400)
        stt = ($10 < now) ? "{r}EXPIRED" : (dl <= crit) ? "{r}CRITICAL" : (dl <= warn) ? "{y}WARNING" : "{g}OK"
        cmd = "date -u -d @" $10 " +%Y-%m-%d\\ %H:%M 2>/dev/null"; t = "-"; cmd | getline t; close(cmd)
        san = $7; gsub(/,/, ", ", san)
        print $10, stt, dl, t, (one ? $2 : s), $3 ($4 > 1 ? " #" $4 : ""), ($13 == "self" && $5 == "certificate" ? "self-signed" : $5), $6, ($13 == "self" ? "(self)" : $8),
              ($4 > 1 ? "{d}(with the certificate above it)" : (UB[s] == "" ? (PODS_OK ? "{y}no pod or ingress" : "{d}not visible (pods)") : UB[s] (PODS_OK ? "" : " (+ pods not visible)"))), $11, $14, MG[s], $12, san, ($15 == "" ? "-" : $15) }' \
      PODS_OK="$([ "$(health__state sm-pods)" = ok ] && echo 1 || echo 0)" "$d/sm-secrets.tsv" "$d/sm-uses.tsv" "$d/sm-certs.tsv" 2>/dev/null | LC_ALL=C sort -t $'\t' -k1,1n -k5,5 -k6,6 | cut -f2- |
    awk -F'\t' 'BEGIN { OFS = "\t" } { print NR, $0 }' > "$num.c"
  { printf '>#\tSTATE\t>DAYS\tEXPIRES (UTC)\tSECRET\tKEY\tSUBJECT (CN)\tISSUER\tUSED BY\n'
    awk -F'\t' 'BEGIN { OFS = "\t" } { print $1, $2, $3, $4, $5, $6, $8, $9, $10 }' "$num.c"; } |
    tk_table "CERTIFICATES IN SECRETS" "soonest expiry first; \"#2\" after a key = further certificate in the same file (its chain)" \
      "$([ "$st" = ok ] && echo 'no certificate in any Secret you can read' || echo "not visible: Secrets read $st")" certificate certificates
  if [ -s "$num.c" ]; then
    { printf '>#\tSECRET\tKEY\tROLE\tALGO\tPRIVATE KEY\tCHAIN (signatures)\tMANAGED BY\tSHA-256~\tSAN (names the certificate is valid for)\n'
      awk -F'\t' 'BEGIN { OFS = "\t" } { print $1, $5, $6, $7, ($11 ~ /^RSA / && substr($11, 5) + 0 < 2048 ? "{y}" : "") $11, $12, $16, $13, $14, $15 }' "$num.c"; } |
      TK_COUNT=0 tk_table "CERTIFICATE DETAILS" "same # as above; CHAIN = is it signed by the ca.crt or the intermediates stored with it; the private key is never read"
  fi
  rm -f "$num.c"
  # 2. where used: in the container ...
  { printf 'SECRET\tUSED BY\tSERVICE\tHOW\tCONTAINER\tFILES IN THE CONTAINER\t>PODS\tAFTER A ROTATION*\n'
    awk -F'\t' 'BEGIN { OFS = "\t" }
      FILENAME ~ /sm-svc/ { SV[$1, $2] = SV[$1, $2] (SV[$1, $2] == "" ? "" : ", ") $3; next }
      FILENAME ~ /sm-secrets/ { EX[$1 "/" $2] = 1; next }
      { k = $1 SUBSEP $2 SUBSEP $3 SUBSEP $4 SUBSEP $6 SUBSEP $7
        if (!(k in C)) { ord[++n] = k; RL[k] = $8 }
        if (!((k, $5) in P)) { P[k, $5] = 1; C[k]++ } }
      END { for (i = 1; i <= n; i++) { k = ord[i]; split(k, a, SUBSEP); s = a[1] "/" a[2]; sn = (ONE ? a[2] : s)
          rl = RL[k]; col = (rl ~ /^restart/) ? "{y}" : (rl ~ /^auto/) ? "{g}" : "{d}"
          print (EXS && !(s in EX) ? "{r}" sn "  (does not exist)" : sn), a[4], (SV[a[1], a[4]] == "" ? "-" : SV[a[1], a[4]]), a[3], a[5], a[6], C[k], col rl } }' \
        EXS="$([ "$st" = ok ] && echo 1 || echo 0)" ONE="$one" "$d/sm-svc.tsv" "$d/sm-secrets.tsv" "$d/sm-uses.tsv" 2>/dev/null | LC_ALL=C sort -t $'\t' -k1,1 -k2,2 -k4,4; } |
    tk_table "WHERE EACH SECRET IS USED" "one row per workload and way of use; volumes follow a rotation by themselves, env and subPath need a restart" \
      "$([ "$(health__state sm-pods)" = ok ] && echo 'no pod or ingress in scope refers to a Secret' || echo "not visible: pods read $(health__state sm-pods)")" use uses
  [ "$(health__state sm-pods)" = ok ] || tk_note "not visible: pods read $(health__state sm-pods) - volume, env and imagePull uses are missing above; only ingress TLS is shown. Ask for get, list on pods."
  [ "$(health__state sm-ing)" = ok ] || tk_note "not visible: ingresses read $(health__state sm-ing) - ingress TLS uses are missing above."
  # ... and on the nodes: the kubelet's copy of each Secret volume, per pod
  { printf 'SECRET\tPOD\tNODE\tTHIS HOST*\tKUBELET PATH ON THE NODE\n'
    awk -F'\t' -v one="$one" 'BEGIN { OFS = "\t" } $10 != "-" && !(($5, $10) in seen) { seen[$5, $10] = 1
        print (one ? $2 : $1 "/" $2), $5, $9, ($13 == "" ? "{d}not this host" : ($13 ~ /STALE/ ? "{r}STALE: differs from the Secret" : "{g}" $13)), $10 }' "$d/sm-uses.tsv" 2>/dev/null | LC_ALL=C sort -t $'\t' -k1,1 -k3,3 -k2,2; } |
    tk_table "FILES ON THE NODES" "tmpfs under $SM_KUBELET_DIR, readable by root on that node; THIS HOST compares the file with the Secret when kdash runs there" \
      "no pod with a Secret volume is scheduled on a node (env, imagePull and ingress uses have no file)" file files
  # 3. inventory
  { printf 'SECRET\tTYPE\t>AGE\tMANAGED BY\t>CERTS\t>USED BY\tNOTE~\tKEYS (name = kind, size) - never the value\n'
    awk -F'\t' -v now="$now" -v one="$one" "$TK_TIME_AWK"'BEGIN { OFS = "\t" }
      FILENAME ~ /sm-uses/ { s = $1 "/" $2; if (!((s, $4) in seen)) { seen[s, $4] = 1; U[s]++ }; next }
      { s = $1 "/" $2; e = epoch($4); age = (e > 0) ? int((now - e) / 86400) "d" : "-"
        note = $8; if (U[s] == 0 && $3 !~ /service-account-token|bootstrap/) note = note (note == "" ? "" : ", ") (PODS_OK ? "unused in scope" : "use not visible")
        ks = $6; gsub(/ \[/, " = ", ks); gsub(/\]/, "", ks)
        print (one ? $2 : s), $3, age, $5, $7, U[s] + 0, note, ks }' PODS_OK="$([ "$(health__state sm-pods)" = ok ] && echo 1 || echo 0)" "$d/sm-uses.tsv" "$d/sm-secrets.tsv" 2>/dev/null | LC_ALL=C sort -t $'\t' -k1,1; } |
    tk_table "ALL SECRETS" "what each Secret holds, by key name and kind; Helm release payloads are left out" \
      "$([ "$st" = ok ] && echo 'no Secret in scope' || echo "not visible: Secrets read $st")" secret secrets
  # 4. findings, with the next commands
  awk -F'\t' 'BEGIN { OFS = "\t" } { print NR, $0 }' "$d/sm-findings.tsv" 2>/dev/null > "$num"
  { printf '#\tSEVERITY\tSECRET\tFINDING\n'; awk -F'\t' -v one="$one" 'BEGIN { OFS = "\t" } { o = $3; if (one) sub(/^[^\/]*\//, "", o); print $1, $2, o, $4 }' "$num"; } |
    tk_table "FINDINGS" "Enter runs the read commands of a row; CHANGE commands are only printed" "nothing to act on: no certificate inside the warning window, no missing Secret" finding findings
  awk -F'\t' 'BEGIN { OFS = "\t" } $2 !~ /INFO/ { print $1, $2, $3, $4, $5 }' "$num" > "$num.list"
  KDASH_HINT_MAX="${KDASH_SECRETS_HINT_MAX:-20}" rb_next_list "$num.list"
  rm -f "$num.list"
  return 0
}

# ---- exports (the full data, nothing cut to the screen width) -------------------------------
sm__flat() { # one row per secret x certificate x use; blanks where there is no certificate / no use
  local d="$TOOLKIT_DIR"
  awk -F'\t' -v now="$(date +%s)" 'BEGIN { OFS = "\t" }
    function use(s, i) { return (i ? UW[s, i] OFS UO[s, i] OFS SV[UNS[s, i], UW[s, i]] OFS UH[s, i] OFS UC[s, i] OFS UP[s, i] OFS UN[s, i] OFS UX[s, i] OFS UR[s, i] OFS UL[s, i] : "" OFS "" OFS "" OFS "" OFS "" OFS "" OFS "" OFS "" OFS "" OFS "") }
    FILENAME ~ /sm-svc/ { SV[$1, $2] = SV[$1, $2] (SV[$1, $2] == "" ? "" : ";") $3; next }
    FILENAME ~ /sm-secrets/ { s = $1 "/" $2; if (!(s in SEEN)) { SEEN[s] = 1; ORD[++no] = s }; MG[s] = $5; TY[s] = $3; next }
    FILENAME ~ /sm-uses/ { s = $1 "/" $2; if (!(s in SEEN)) { SEEN[s] = 1; ORD[++no] = s; TY[s] = "(not readable or missing)" }
      n = ++NU[s]; UW[s, n] = $4; UH[s, n] = $3; UC[s, n] = $6; UP[s, n] = $7; UR[s, n] = $8; UN[s, n] = $9; UX[s, n] = $10; UO[s, n] = $5; UL[s, n] = $13; UNS[s, n] = $1; next }
    { s = $1 "/" $2; dl = int(($10 - now) / 86400); ks = $14; sub(/^\{[a-z]\}/, "", ks); n = ++NC[s]
      ch = ($15 == "" ? "-" : $15); sub(/^\{[a-z]\}/, "", ch)
      CE[s, n] = $3 OFS $4 OFS $5 OFS $6 OFS $7 OFS $8 OFS $9 OFS $10 OFS dl OFS ($10 < now ? "expired" : "valid") OFS $11 OFS $12 OFS ks OFS ch }
    END { for (x = 1; x <= no; x++) { s = ORD[x]; ns_ = substr(s, 1, index(s, "/") - 1); nm = substr(s, index(s, "/") + 1)
        nc = (NC[s] > 0) ? NC[s] : 1; nu = (NU[s] > 0) ? NU[s] : 1
        for (c = 1; c <= nc; c++) for (u = 1; u <= nu; u++)
          print ns_, nm, TY[s], (NC[s] > 0 ? CE[s, c] : "" OFS "" OFS "" OFS "" OFS "" OFS "" OFS "" OFS "" OFS "" OFS "" OFS "" OFS "" OFS "" OFS ""), MG[s], use(s, (NU[s] > 0 ? u : 0)) } }' \
    "$d/sm-svc.tsv" "$d/sm-secrets.tsv" "$d/sm-uses.tsv" "$d/sm-certs.tsv" 2>/dev/null
}
sm_export() { # csv|tsv|json
  local d="$TOOLKIT_DIR"
  case "$1" in
    json) awk -F'\t' -v ctx="${CTX_NAME:-}" -v ns="${NS:-}" -v at="$(date -u +%Y-%m-%dT%H:%M:%SZ)" -v sum="$(cat "$d/sm.summary")" -v now="$(date +%s)" '
        function j(s) { gsub(/\\/, "\\\\", s); gsub(/"/, "\\\"", s); gsub(/\t/, " ", s); sub(/^\{[a-z]\}/, "", s); return "\"" s "\"" }
        FILENAME ~ /sm-svc/ { SV[$1, $2] = SV[$1, $2] (SV[$1, $2] == "" ? "" : ",") j($3); next }
        FILENAME ~ /sm-certs/ { s = $1 "/" $2; C[s] = C[s] (C[s] == "" ? "" : ",") sprintf("{\"key\":%s,\"index\":%d,\"role\":%s,\"subject\":%s,\"san\":%s,\"issuer\":%s,\"not_before\":%d,\"not_after\":%d,\"days_left\":%d,\"algorithm\":%s,\"sha256_prefix\":%s,\"self_signed\":%s,\"private_key\":%s,\"chain\":%s}", j($3), $4, j($5), j($6), j($7), j($8), $9, $10, int(($10 - now) / 86400), j($11), j($12), ($13 == "self" ? "true" : "false"), j($14), j($15 == "" ? "-" : $15)); next }
        FILENAME ~ /sm-uses/ { s = $1 "/" $2; U[s] = U[s] (U[s] == "" ? "" : ",") sprintf("{\"workload\":%s,\"pod\":%s,\"services\":[%s],\"how\":%s,\"container\":%s,\"path_in_container\":%s,\"node\":%s,\"host_path\":%s,\"after_rotation\":%s,\"this_host\":%s}", j($4), j($5), SV[$1, $4], j($3), j($6), j($7), j($9), j($10), j($8), j($13)); if (!(s in ORD)) { ORD[s] = 1; UO[++nu] = s }; next }
        FILENAME ~ /sm-findings/ { F = F (F == "" ? "" : ",") sprintf("{\"severity\":%s,\"secret\":%s,\"finding\":%s}", j($1), j($2), j($3)); next }
        { s = $1 "/" $2; HAVE[s] = 1; S = S (S == "" ? "" : ",") sprintf("{\"namespace\":%s,\"name\":%s,\"type\":%s,\"created\":%s,\"managed_by\":%s,\"keys\":%s,\"immutable\":%s,\"certificates\":[%s],\"used_by\":[%s]}", j($1), j($2), j($3), j($4), j($5), j($6), ($8 == "immutable" ? "true" : "false"), C[s], U[s]) }
        END { split(sum, M, "\t")
          for (i = 1; i <= nu; i++) if (!(UO[i] in HAVE)) { split(UO[i], a, "/"); X = X (X == "" ? "" : ",") sprintf("{\"namespace\":%s,\"name\":%s,\"used_by\":[%s]}", j(a[1]), j(a[2]), U[UO[i]]) }
          printf "{\"context\":%s,\"namespace\":%s,\"generated\":%s,\"user\":%s,\"secrets_access\":%s,\"counts\":{\"secrets\":%d,\"certificates\":%d,\"expired\":%d,\"critical\":%d,\"warning\":%d},\"secrets\":[%s],\"referenced_but_not_readable_or_missing\":[%s],\"findings\":[%s]}\n", j(ctx), j(ns), j(at), j(M[8]), j(M[9]), M[1], M[2], M[3], M[4], M[5], S, X, F }' \
        "$d/sm-svc.tsv" "$d/sm-certs.tsv" "$d/sm-uses.tsv" "$d/sm-findings.tsv" "$d/sm-secrets.tsv" 2>/dev/null ;;
    *) { printf 'NAMESPACE\tSECRET\tTYPE\tKEY\tINDEX\tROLE\tSUBJECT\tSAN\tISSUER\tNOT_BEFORE\tNOT_AFTER\tDAYS_LEFT\tVALIDITY\tALGORITHM\tSHA256_PREFIX\tPRIVATE_KEY\tCHAIN\tMANAGED_BY\tUSED_BY\tPOD\tSERVICES\tHOW\tCONTAINER\tPATH_IN_CONTAINER\tNODE\tHOST_PATH\tAFTER_ROTATION\tTHIS_HOST\n'
         sm__flat | awk -F'\t' 'BEGIN { OFS = "\t" } { for (i = 10; i <= 11; i++) if ($i != "") { cmd = "date -u -d @" $i " +%Y-%m-%dT%H:%M:%SZ 2>/dev/null"; cmd | getline t; close(cmd); $i = t } print }'; } |
       if [ "$1" = csv ]; then awk -F'\t' '{ for (i = 1; i <= NF; i++) { v = $i; if (v ~ /[",]/) { gsub(/"/, "\"\"", v); v = "\"" v "\"" } printf "%s%s", v, (i < NF ? "," : "\n") } }'; else cat; fi ;;
  esac
  audit SECRETS_EXPORT "format=$1"
}
sm_html() { # [file] -> path   (the same tables as the screen, full width)
  local out="${1:-}" d="$TOOLKIT_DIR" ns nc ex cr wa fc fw u st
  [ -n "$out" ] || { mkdir -p "${REPORT_DIR:-$HOME/kdash_reports}/secrets"; out="${REPORT_DIR:-$HOME/kdash_reports}/secrets/secrets_$(safe_name "${CTX_NAME:-ctx}")_$(safe_name "${NS:-ns}")_$(date +%Y%m%d_%H%M%S).html"; }
  IFS=$'\t' read -r ns nc ex cr wa fc fw u st < "$d/sm.summary"
  { cat <<'HTML'
<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>kdash secrets map</title>
<style>:root{--bg:#fff;--fg:#1d1d1f;--mu:#6b6b70;--li:#e3e3e8;--h:#c62828;--m:#a35f00;--ok:#2e7d32;--card:#f5f5f7}
@media (prefers-color-scheme:dark){:root{--bg:#121214;--fg:#ececf1;--mu:#a0a0aa;--li:#2c2c33;--h:#ff6b6b;--m:#ffb74d;--ok:#81c784;--card:#1b1b1f}}
body{background:var(--bg);color:var(--fg);font:14px/1.45 system-ui,sans-serif;margin:24px}h1{font-size:20px;margin:0 0 4px}h2{font-size:15px;margin:28px 0 6px}.mu{color:var(--mu)}
.w{overflow-x:auto}table{border-collapse:collapse;min-width:100%}th,td{border-bottom:1px solid var(--li);padding:6px 9px;text-align:left;vertical-align:top;white-space:nowrap}
td.x{white-space:normal;min-width:220px}th{font-weight:600;position:sticky;top:0;background:var(--bg)}td.n{text-align:right;font-variant-numeric:tabular-nums}
.r{color:var(--h);font-weight:700}.y{color:var(--m);font-weight:700}.g{color:var(--ok)}.d{color:var(--mu)}
.b{display:inline-block;padding:3px 10px;border-radius:6px;margin:0 6px 6px 0;font-weight:600;background:var(--card)}code{font:12px ui-monospace,Menlo,monospace}</style></head><body>
HTML
    printf '<h1>Secrets map - %s / %s</h1><div class="mu">kdash %s, %s, user %s - read-only; private keys and other values are never fetched</div>\n' \
      "$(fmea__esc "$CTX_NAME")" "$(fmea__esc "$([ "${ALL_NS:-0}" = 1 ] && echo 'all namespaces' || echo "$NS")")" "$KDASH_VERSION" "$(date '+%Y-%m-%d %H:%M %Z')" "$(fmea__esc "${u:-?}")"
    if [ "$st" = ok ]; then printf '<p><span class="b r">%s expired</span><span class="b r">%s critical</span><span class="b y">%s warning</span><span class="b">%s certificates</span><span class="b">%s secrets</span></p>\n' "$ex" "$cr" "$wa" "$nc" "$ns"
    else printf '<p><span class="b y">NOT VISIBLE - Secrets read %s: certificates and expiry unknown for this user</span></p>\n' "$st"; fi
    # the screen tables again, as HTML: TSV with a header line, {r}{y}{g}{d} cell colours
    TK_COLOR=0 TK_COLS=0 SM_HTML=1 sm__tables_tsv | awk -F'\t' '
      function e(s) { gsub(/&/, "\\&amp;", s); gsub(/</, "\\&lt;", s); gsub(/>/, "\\&gt;", s); return s }
      /^@@/ { if (open) print "</table></div>"; split(substr($0, 3), tt, "|"); print "<h2>" e(tt[1]) "</h2>" (tt[2] != "" ? "<div class=mu>" e(tt[2]) "</div>" : "") "<div class=w><table>"; open = 1; hdr = 1; next }
      hdr { printf "<tr>"; for (i = 1; i <= NF; i++) { h = $i; RA[i] = (h ~ /^>/); gsub(/^>|[*~]$/, "", h); printf "<th>%s</th>", e(h) } print "</tr>"; hdr = 0; next }
      { printf "<tr>"; for (i = 1; i <= NF; i++) { v = $i; c = ""; if (v ~ /^\{[rygbd]\}/) { c = substr(v, 2, 1); v = substr(v, 4) }
          printf "<td class=\"%s%s%s\">%s</td>", c, (RA[i] ? " n" : ""), (length(v) > 60 ? " x" : ""), e(v == "" ? "-" : v) } print "</tr>" }
      END { if (open) print "</table></div>" }'
    printf '<p class="mu">Paths: "in the container" is the mountPath; "on the node" is the kubelet copy under %s on that node. After a rotation, env and subPath consumers need a restart.</p></body></html>\n' "$SM_KUBELET_DIR"
  } > "$out" || return 1
  audit SECRETS_EXPORT "format=html file=$out"
  printf '%s\n' "$out"
}
# ---- FMEA and the secrets map inside the namespace report and the report bundle -------
fmea__tables_tsv() {
  printf '@@FMEA worksheet|every failure mode on every object this user can read, ranked by Action Priority (AIAG-VDA 2019); RPN = S x O x D is shown, not ranked; * = O estimated\n'
  printf 'AP\t>S\t>O\t>D\t>RPN\tID\tKIND\tOBJECT\tFAILURE MODE\tNOW\tACCESS\tEFFECT\n'
  awk -F'\t' 'BEGIN { OFS = "\t" } { now_ = $10; c = ($11 == "ok") ? "{g}" : ($11 == "fail") ? "{r}" : ($11 == "risk") ? "{y}" : "{d}"
      print ($1 == "H" ? "{r}HIGH" : $1 == "M" ? "{y}MEDIUM" : "{d}LOW"), $2, $3 ($13 == "1" ? "*" : ""), $4, $5, $6, $7, $8, $9, c now_, $12, $15 }' "$TOOLKIT_DIR/fmea-rows.tsv" 2>/dev/null
}
# stdin: "@@Title|subtitle", a header line, rows (TSV; {r}{y}{g}{d} = cell colour, ">" = right-aligned column)
# -> panels in the report's own style: sortable, searchable, CSV per table
report__html_tables() { # id-prefix
  awk -F'\t' -v pre="$1" '
    function e(s) { gsub(/&/, "\\&amp;", s); gsub(/</, "\\&lt;", s); gsub(/>/, "\\&gt;", s); gsub(/"/, "\\&quot;", s); return s }
    function shut() { if (open) { if (rows == 0) printf "<tr><td class=\"l na\" colspan=\"%d\">nothing to show</td></tr>\n", nc; print "</tbody></table></div></section>" } open = 0 }
    /^@@/ { shut(); n++; split(substr($0, 3), t, "|"); id = pre n; nm = tolower(t[1]); gsub(/[^a-z0-9]+/, "_", nm)
      printf "<section class=\"panel\"><div class=\"ph\"><h2>%s</h2><p>%s</p><div class=\"tools\"><span class=\"count\" data-count=\"%s\"></span><button class=\"btn\" onclick=\"kdCSV(&quot;%s&quot;,&quot;%s&quot;)\">CSV</button></div></div>\n<div class=\"scroll\"><table class=\"cli\" id=\"%s\"><thead>", e(t[1]), e(t[2]), id, id, nm, id
      open = 1; hdr = 1; rows = 0; next }
    hdr { printf "<tr>"; nc = NF; for (i = 1; i <= NF; i++) { h = $i; RA[i] = (h ~ /^>/); gsub(/^>|[*~]$/, "", h); printf "<th%s onclick=\"kdSort(this)\">%s</th>", (RA[i] ? "" : " class=\"l\""), e(h) }
      print "</tr></thead><tbody>"; hdr = 0; next }
    { all = $0; gsub(/\{[rygbd]\}/, "", all); gsub(/\t/, " ", all); printf "<tr data-s=\"%s\">", e(all)
      for (i = 1; i <= nc; i++) { v = $i; st = ""
        if (v ~ /^\{[rygbd]\}/) { k = substr(v, 2, 1); v = substr(v, 4); st = (k == "r") ? "color:var(--h4);font-weight:700" : (k == "y") ? "color:var(--h3);font-weight:700" : (k == "g") ? "color:var(--h1)" : "color:var(--dim)" }
        printf "<td class=\"%s%s\"%s>%s</td>", (RA[i] ? "" : "l"), (length(v) > 70 ? " wrap" : ""), (st != "" ? " style=\"" st "\"" : ""), e(v == "" ? "-" : v) }
      print "</tr>"; rows++ }
    END { shut() }'
}
report__lead() { # title text  -> one summary panel
  printf '<section class="panel"><div class="ph"><h2>%s</h2><p>%s</p></div></section>\n' "$(fmea__esc "$1")" "$(fmea__esc "$2")"
}
# report_extras [session]: writes $TMPD/nsr_fmea.html and $TMPD/nsr_secrets.html (empty = no tab).
# Read-only like everything else, and only what this user's RBAC allows; data newer than 5 minutes is reused.
report_extras() {
  local h m l v t u ns nc ex cr wa fc fw st
  : > "$TMPD/nsr_fmea.html"; : > "$TMPD/nsr_secrets.html"
  [ "${KDASH_REPORT_EXTRAS:-1}" = 1 ] && [ "${NSR_OFFLINE:-0}" != 1 ] || return 0
  [ -n "${TOOLKIT_DIR:-}" ] && [ -d "$TOOLKIT_DIR" ] || return 0
  ( trap - EXIT INT TERM HUP
    [ -s "$TOOLKIT_DIR/health-services.status" ] || { events_collect; health_collect; }
    [ "$(check_age)" -lt 300 ] || check_collect
    [ "$(fmea_age)" -lt 300 ] || fmea_collect view
    [ "$(sm_age)" -lt 300 ] || [ "${KDASH_SECRETS_IN_CHECK:-1}" != 1 ] || sm_collect ) > /dev/null 2>&1
  if [ -s "$TOOLKIT_DIR/fmea-rows.tsv" ] && [ -s "$TOOLKIT_DIR/fmea.summary" ]; then
    IFS=$'\t' read -r h m l v t u < "$TOOLKIT_DIR/fmea.summary"
    { report__lead "FMEA - $h high, $m medium, $l low" "$v of $t failure modes visible to ${u:-this user} - a check this user cannot run is listed as \"no access\", never as OK. In kdash: key M, or kdash --fmea"
      fmea__tables_tsv | report__html_tables fmea_; } > "$TMPD/nsr_fmea.html"
  fi
  if [ -s "$TOOLKIT_DIR/sm.summary" ]; then
    IFS=$'\t' read -r ns nc ex cr wa fc fw u st < "$TOOLKIT_DIR/sm.summary"
    { if [ "$st" = ok ]; then report__lead "Secrets map - $ex expired, $cr critical, $wa warning" "$nc certificates in $ns Secrets, read as ${u:-this user} - private keys and other values are never fetched. In kdash: key Y, or kdash --secrets"
      else report__lead "Secrets map - NOT VISIBLE" "Secrets read $st for ${u:-this user}: certificates and expiry are unknown; references from pods and ingresses are still listed"; fi
      sm__tables_tsv | report__html_tables sm_; } > "$TMPD/nsr_secrets.html"
  fi
  audit REPORT_EXTRAS "fmea=$([ -s "$TMPD/nsr_fmea.html" ] && echo yes || echo no) secrets=$([ -s "$TMPD/nsr_secrets.html" ] && echo yes || echo no)"
  return 0
}
report_bundle_extras() { # dir: the same data as files in the report bundle
  local dir="$1"
  [ -d "$dir" ] && [ "${KDASH_REPORT_EXTRAS:-1}" = 1 ] || return 0
  ( trap - EXIT INT TERM HUP
    [ "$(check_age)" -lt 300 ] || check_collect
    [ "$(fmea_age)" -lt 300 ] || fmea_collect view
    [ "$(sm_age)" -lt 300 ] || [ "${KDASH_SECRETS_IN_CHECK:-1}" != 1 ] || sm_collect ) > /dev/null 2>&1
  if [ -s "$TOOLKIT_DIR/fmea-rows.tsv" ]; then
    TK_COLOR=0 TK_COLS=0 fmea_render 2>/dev/null | toolkit_clean > "$dir/fmea.txt"; fmea_export csv > "$dir/fmea.csv" 2>/dev/null
  fi
  if [ -s "$TOOLKIT_DIR/sm.summary" ]; then
    TK_COLOR=0 TK_COLS=0 sm_render 2>/dev/null | toolkit_clean > "$dir/secrets.txt"; sm_export csv > "$dir/secrets.csv" 2>/dev/null; sm_export json > "$dir/secrets.json" 2>/dev/null
  fi
  return 0
}

sm__tables_tsv() { # the four tables as "@@TITLE" + TSV (for the HTML report)
  local d="$TOOLKIT_DIR" now; now="$(date +%s)"
  printf '@@Certificates in Secrets|soonest expiry first; CHAIN = is it signed by the ca.crt or the intermediates stored with it\n'
  printf 'STATE\t>DAYS\tEXPIRES (UTC)\tSECRET\tKEY\tROLE\tSUBJECT\tSAN\tISSUER\tALGO\tPRIVATE KEY\tCHAIN (signatures)\tMANAGED BY\tSHA-256 (prefix)\n'
  awk -F'\t' -v now="$now" -v warn="${CERT_WARN_DAYS:-30}" -v crit="${CERT_CRIT_DAYS:-7}" 'BEGIN { OFS = "\t" }
    FILENAME ~ /sm-secrets/ { MG[$1 "/" $2] = $5; next }
    { s = $1 "/" $2; dl = int(($10 - now) / 86400); stt = ($10 < now) ? "{r}EXPIRED" : (dl <= crit) ? "{r}CRITICAL" : (dl <= warn) ? "{y}WARNING" : "{g}OK"
      cmd = "date -u -d @" $10 " +%Y-%m-%d\\ %H:%M 2>/dev/null"; cmd | getline t; close(cmd)
      print $10, stt, dl, t, s, $3 ($4 > 1 ? " #" $4 : ""), $5 ($13 == "self" && $5 != "CA" ? ", self-signed" : ""), $6, $7, ($13 == "self" ? "(self)" : $8), $11, $14, ($15 == "" ? "-" : $15), MG[s], $12 }' "$d/sm-secrets.tsv" "$d/sm-certs.tsv" 2>/dev/null | LC_ALL=C sort -t $'\t' -k1,1n | cut -f2-
  printf '@@Where each Secret is used|one row per pod and way of use; volumes follow a rotation by themselves, env and subPath need a restart\n'
  printf 'SECRET\tUSED BY\tPOD\tSERVICE\tHOW\tCONTAINER\tPATH IN THE CONTAINER\tNODE\tPATH ON THE NODE (kubelet)\tAFTER A ROTATION\tTHIS HOST\n'
  awk -F'\t' 'BEGIN { OFS = "\t" } FILENAME ~ /sm-svc/ { SV[$1, $2] = SV[$1, $2] (SV[$1, $2] == "" ? "" : ", ") $3; next }
    { print $1 "/" $2, $4, $5, SV[$1, $4], $3, $6, $7, $9, $10, ($8 ~ /^restart/ ? "{y}" : "") $8, $13 }' "$d/sm-svc.tsv" "$d/sm-uses.tsv" 2>/dev/null | LC_ALL=C sort -t $'\t' -k1,1 -k2,2
  printf '@@All Secrets|key names, kinds and sizes only\n'
  printf 'SECRET\tTYPE\tKEYS [kind, size]\tCREATED\tMANAGED BY\t>CERTS\tNOTE\n'
  awk -F'\t' 'BEGIN { OFS = "\t" } { print $1 "/" $2, $3, $6, $4, $5, $7, $8 }' "$d/sm-secrets.tsv" 2>/dev/null | LC_ALL=C sort
  printf '@@Findings|what to act on\n'
  printf 'SEVERITY\tSECRET\tFINDING\n'
  cut -f1-3 "$d/sm-findings.tsv" 2>/dev/null
}
