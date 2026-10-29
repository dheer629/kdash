#!/usr/bin/env bash
# Opt-in container shell and file copy: the guard, the exact kubectl argv, the
# audit trail and the input validation. No cluster, no kubeconfig, no terminal
# and no user data: kubectl is a fixture and the prompts are injected.
set -euo pipefail
REPO="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
source "$REPO/src/interactive.sh"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/kdash-interactive-tests.XXXXXXXX")"
cleanup() {
  case "$TEST_ROOT" in "${TMPDIR:-/tmp}"/kdash-interactive-tests.*) rm -rf -- "$TEST_ROOT" ;; esac
}
trap cleanup EXIT
TMPD="$TEST_ROOT/tmp"; mkdir -p "$TMPD/inspector/live"
CTX_NAME=production-west; NS=alpha
CALLS="$TEST_ROOT/calls"; : > "$CALLS"
AUD="audit"; : > "$AUD"
audit() { printf '%s\t%s\n' "$1" "${2:-}" >> "$TEST_ROOT/$AUD"; }
flash() { printf 'flash: %s\n' "$1" >> "$TEST_ROOT/flash"; }
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
assert_has() { grep -Fq -- "$2" "$1" || fail "$1 lacks $2"; }
assert_lacks() { ! grep -Fq -- "$2" "$1" || fail "$1 unexpectedly contains $2"; }
assert_match() { grep -Eq -- "$2" "$1" || fail "$1 does not match /$2/"; }
extract_function() {
  awk -v name="$1" 'index($0, name "()") == 1 {on=1} on {print} on && $0=="}" {exit}' "$REPO/kdash"
}

# A kubectl that records exactly what it was given: that is the contract under
# test (kdash must never build a different command than the one documented).
cat > "$TEST_ROOT/kubectl" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$KDASH_TEST_CALLS"
exit "${KDASH_TEST_RC:-0}"
STUB
chmod 755 "$TEST_ROOT/kubectl"
export KDASH_TEST_CALLS="$CALLS"
KC=("$TEST_ROOT/kubectl" --context production-west)

echo "== 1. with interactive mode off (the default) exec and cp are refused"
(
  set -uo pipefail
  source <(extract_function audit_wrap_kubectl)
  TMPD="$TEST_ROOT/guard-off"; mkdir -p "$TMPD"
  KC=("$TEST_ROOT/kubectl" --context production-west)
  unset KDASH_ALLOW_INTERACTIVE
  audit_wrap_kubectl
  rc=0
  "${KC[@]}" exec -it api-ready -c main -n alpha -- sh -c 'id' > /dev/null 2> "$TEST_ROOT/off.err" || rc=$?
  [ "$rc" = 126 ] || fail "exec was not refused while interactive mode is off (rc=$rc)"
  assert_has "$TEST_ROOT/off.err" '--allow-interactive'
  rc=0
  "${KC[@]}" cp /etc/hostname alpha/api-ready:/tmp/x -n alpha > /dev/null 2>&1 || rc=$?
  [ "$rc" = 126 ] || fail "cp was not refused while interactive mode is off (rc=$rc)"
  assert_has "$AUDIT_KLOG" REFUSED
  "${KC[@]}" get pods -n alpha > /dev/null || fail 'a read no longer works'
)
assert_lacks "$CALLS" 'exec -it api-ready'

echo "== 2. with --allow-interactive the same two verbs run, marked as writes"
(
  set -uo pipefail
  source <(extract_function audit_wrap_kubectl)
  source <(extract_function audit_kubectl_summary)
  TMPD="$TEST_ROOT/guard-on"; mkdir -p "$TMPD"
  KC=("$TEST_ROOT/kubectl" --context production-west)
  KDASH_ALLOW_INTERACTIVE=1
  audit_wrap_kubectl
  : > "$CALLS"
  "${KC[@]}" exec -it api-ready -c main -n alpha -- sh -c 'id' > /dev/null || fail 'exec failed while interactive mode is on'
  "${KC[@]}" cp /etc/hostname alpha/api-ready:/tmp/x -n alpha > /dev/null || fail 'cp failed while interactive mode is on'
  "${KC[@]}" get pods -n alpha > /dev/null || fail 'a read failed while interactive mode is on'
  assert_has "$CALLS" 'exec -it api-ready -c main -n alpha -- sh -c id'
  assert_has "$CALLS" 'cp /etc/hostname alpha/api-ready:/tmp/x -n alpha'
  # The kcall log marks the verb as a write; the shape carries the global flags first.
  assert_match "$AUDIT_KLOG" 'WRITE .*exec -it api-ready'
  assert_match "$AUDIT_KLOG" 'WRITE .*cp /etc/hostname'
  ! grep -Eq 'WRITE .*get pods' "$AUDIT_KLOG" || fail 'a read was marked as a write'
  summary="$(audit_kubectl_summary)"
  case "$summary" in *writes=2*) ;; *) fail "the audit summary did not count the writes: $summary" ;; esac
  case "$summary" in *refused=0*) ;; *) fail "the guard refused something it allows: $summary" ;; esac
)

echo "== 3. the 12s command cap applies to reads, never to an attachment"
(
  set -uo pipefail
  source <(extract_function audit_wrap_kubectl)
  TMPD="$TEST_ROOT/guard-timeout"; mkdir -p "$TMPD"
  SLOWDIR="$TEST_ROOT/slow"; mkdir -p "$SLOWDIR"
  cat > "$SLOWDIR/kubectl" <<'SLOW'
#!/usr/bin/env bash
sleep 3
exit 0
SLOW
  chmod 755 "$SLOWDIR/kubectl"
  KC=("$SLOWDIR/kubectl" --context production-west)
  export KDASH_ALLOW_INTERACTIVE=1 KDASH_CMD_TIMEOUT=1
  audit_wrap_kubectl
  start=$SECONDS; rc=0
  "${KC[@]}" logs api-ready -n alpha > /dev/null 2>&1 || rc=$?
  [ "$rc" = 124 ] || fail "a read is no longer capped by the command timeout (rc=$rc)"
  [ "$((SECONDS-start))" -lt 3 ] || fail 'the read cap did not apply'
  start=$SECONDS; rc=0
  "${KC[@]}" exec -it api-ready -n alpha -- sh -c 'id' > /dev/null 2>&1 || rc=$?
  [ "$rc" = 0 ] || fail "the attachment was cut short by the command timeout (rc=$rc)"
  [ "$((SECONDS-start))" -ge 3 ] || fail 'the attachment did not run to completion'
)

echo "== 4. the shell: the exact argv, and the audit events around it"
# No terminal here, so the tty handover and the on-screen pause are stubbed;
# everything else (argv, audit, validation) is the shipped code.
interactive_run() { printf 'TTY %s\n' "$*" >> "$TEST_ROOT/tty"; "$@"; }
interactive_pause() { :; }
: > "$CALLS"; : > "$TEST_ROOT/$AUD"
KDASH_ALLOW_INTERACTIVE=1
interactive_shell alpha api-ready main > "$TEST_ROOT/shell1.out" 2>&1 || fail 'interactive_shell reported failure'
assert_has "$CALLS" '-n alpha exec -it api-ready -c main -- sh -c'
assert_has "$CALLS" 'command -v bash'
assert_has "$TEST_ROOT/$AUD" $'EXEC\tpod=alpha/api-ready container=main mode=shell'
assert_has "$TEST_ROOT/$AUD" $'EXEC_END\tpod=alpha/api-ready container=main rc=0'
# Without a chosen container the flag is simply absent (one-container pods).
: > "$CALLS"
interactive_shell alpha api-ready > "$TEST_ROOT/shell2.out" 2>&1 || fail 'interactive_shell failed without an explicit container'
assert_has "$CALLS" '-n alpha exec -it api-ready -- sh -c'
assert_lacks "$CALLS" 'exec -it api-ready -c'

echo "== 5. upload and download: argv, direction and path hygiene"
# Prompts are injected: the test never reads a terminal.
answers=()
interactive_ask() {
  printf '%s\n' "$1" >> "$TEST_ROOT/prompts"
  INTERACTIVE_ANSWER="${answers[0]:-${2:-}}"
  answers=("${answers[@]:1}")
  return 0
}
printf 'payload\n' > "$TEST_ROOT/payload.txt"
: > "$CALLS"; : > "$TEST_ROOT/$AUD"
answers=("$TEST_ROOT/payload.txt" /tmp/payload.txt)
interactive_copy up alpha api-ready main > "$TEST_ROOT/copy1.out" 2>&1 || fail 'upload failed'
assert_has "$CALLS" "cp -c main $TEST_ROOT/payload.txt alpha/api-ready:/tmp/payload.txt"
assert_has "$TEST_ROOT/$AUD" $'CP_UP\tpod=alpha/api-ready container=main remote=/tmp/payload.txt'
assert_has "$TEST_ROOT/$AUD" $'CP_END\tpod=alpha/api-ready dir=up rc=0 bytes=8'
# The upload default remote path is /tmp/<basename>.
: > "$CALLS"; : > "$TEST_ROOT/prompts"
answers=("$TEST_ROOT/payload.txt" "")
interactive_copy up alpha api-ready main > "$TEST_ROOT/copy2.out" 2>&1 || fail 'upload with the default remote path failed'
assert_has "$CALLS" "alpha/api-ready:/tmp/payload.txt"
assert_has "$TEST_ROOT/prompts" '/tmp/payload.txt'

: > "$CALLS"; : > "$TEST_ROOT/$AUD"
answers=(/var/log/app.log "$TEST_ROOT/app.log")
interactive_copy down alpha api-ready main > "$TEST_ROOT/copy3.out" 2>&1 || fail 'download failed'
assert_has "$CALLS" "cp -c main alpha/api-ready:/var/log/app.log $TEST_ROOT/app.log"
assert_has "$TEST_ROOT/$AUD" $'CP_DOWN\tpod=alpha/api-ready container=main remote=/var/log/app.log'
assert_has "$TEST_ROOT/$AUD" $'CP_END\tpod=alpha/api-ready dir=down rc=0'

echo "== 6. path hygiene: credential-looking paths, absolute paths, control bytes"
: > "$TEST_ROOT/$AUD"
answers=(/etc/kubernetes/admin.key "$TEST_ROOT/out")
interactive_copy down alpha api-ready main > /dev/null || fail 'download of a key-looking path failed'
assert_has "$TEST_ROOT/$AUD" '<redacted path>'
assert_lacks "$TEST_ROOT/$AUD" 'admin.key'
: > "$CALLS"; : > "$TEST_ROOT/$AUD"
answers=("$TEST_ROOT/payload.txt" relative/path)     # remote must be absolute
if interactive_copy up alpha api-ready main > "$TEST_ROOT/relative" 2>&1; then fail 'a relative remote path was accepted'; fi
assert_has "$TEST_ROOT/relative" 'must be absolute'
assert_lacks "$CALLS" 'relative/path'
answers=("$TEST_ROOT/payload.txt" $'/tmp/bad\r/name')
if interactive_copy up alpha api-ready main > /dev/null 2>&1; then fail 'control bytes in a path were accepted'; fi
answers=("$TEST_ROOT/missing.txt" /tmp/x)
if interactive_copy up alpha api-ready main > /dev/null 2>&1; then fail 'a missing local file was accepted'; fi

echo "== 7. off by default: the keys explain themselves and nothing runs"
unset KDASH_ALLOW_INTERACTIVE
: > "$CALLS"; : > "$TEST_ROOT/$AUD"; : > "$TEST_ROOT/flash"
if interactive_attach shell alpha api-ready "$TMPD/inspector/live"; then fail 'the shell opened while interactive mode is off'; fi
assert_has "$TEST_ROOT/$AUD" 'INTERACTIVE_BLOCKED'
assert_has "$TEST_ROOT/flash" '--allow-interactive'
assert_lacks "$CALLS" 'exec'
interactive_hint > "$TEST_ROOT/hint"
assert_has "$TEST_ROOT/hint" 'read-only by default'

echo "== 8. the wiring is published: flag, keys, help and the embedded module"
assert_has "$REPO/kdash" 'interactive_attach'
assert_has "$REPO/kdash" '-X|--allow-interactive)'
assert_has "$REPO/kdash" 'S|U|D) KDASH_ATTACH_ACTION='
assert_has "$REPO/src/inspector.sh" 'S) interactive_attach shell'
grep -q 'allow-interactive' "$REPO/README.md" || fail 'the README does not document the opt-in'
bash "$REPO/kdash" --help > "$TEST_ROOT/help" || fail 'kdash --help failed'
assert_has "$TEST_ROOT/help" '--allow-interactive'
assert_has "$TEST_ROOT/help" 'INTERACTIVE (opt-in, audited writes)'
assert_has "$TEST_ROOT/help" 'open a shell in the selected container'

printf 'interactive regression checks passed\n'
