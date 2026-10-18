#!/usr/bin/env bash
# Run with Bash as a regular user: bash tests/test-uninstall.sh
# Every writable install target is inside a temporary HOME. Login-shell probes
# source only that HOME, and kubectl is stubbed so tests never contact a cluster.
set -euo pipefail

REPO="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
UNINSTALL="$REPO/kdash-uninstall.sh"
INSTALL="$REPO/kdash-bundle.sh"
if [ "$(id -u)" -eq 0 ]; then
  printf 'Run these tests as an unprivileged user; root installs target /etc.\n' >&2
  exit 1
fi
for script in "$UNINSTALL" "$INSTALL"; do
  [ -f "$script" ] || { printf 'Missing script: %s\n' "$script" >&2; exit 1; }
done

TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/kdash-uninstall-tests.XXXXXXXX")"
cleanup() {
  # TEST_ROOT was created by mktemp; only remove that exact, checked directory.
  case "$TEST_ROOT" in "${TMPDIR:-/tmp}"/kdash-uninstall-tests.*)
    chmod -R u+rwX -- "$TEST_ROOT"
    rm -rf -- "$TEST_ROOT"
    ;;
  esac
}
trap cleanup EXIT
TOOLS="$TEST_ROOT/tools"
mkdir -p -- "$TOOLS"
cat > "$TOOLS/kubectl" <<'STUB'
#!/bin/sh
# Installer diagnostics must not access a real kubeconfig or cluster.
exit 1
STUB
cat > "$TOOLS/bash" <<'STUB'
#!/bin/bash
# System /etc/profile may reset HOME or source the real user's dotfiles. Keep
# the installer's two login-shell probes entirely within the fixture instead.
case "${1:-}" in
  -lc)
    shift
    exec /bin/bash --noprofile --norc -c \
      'source "$HOME/.bash_profile"; eval "$1"' bash "${1:-}"
    ;;
  -il)
    shift
    [ "${1:-}" = -c ] && shift
    exec /bin/bash --noprofile --norc -c \
      'source "$HOME/.bash_profile"; eval "$1"' bash "${1:-}"
    ;;
  *) exec /bin/bash "$@" ;;
esac
STUB
chmod 755 "$TOOLS/bash" "$TOOLS/kubectl"

fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
assert_exists() { [ -e "$1" ] || fail "missing $1"; }
assert_absent() { [ ! -e "$1" ] && [ ! -L "$1" ] || fail "still exists: $1"; }
assert_same() { cmp -s -- "$1" "$2" || fail "contents differ: $1 and $2"; }

fixture() {
  CASE_DIR="$TEST_ROOT/$1"
  TEST_HOME="$CASE_DIR/home with spaces"
  PREFIX="$TEST_HOME/custom bin"
  LOG="$CASE_DIR/command.log"
  mkdir -p -- "$PREFIX" "$TEST_HOME/.config" "$TEST_HOME/kdash_reports/audit" "$TEST_HOME/.kdash-old"
  printf '# unrelated startup settings\nexport TEST_VALUE=retained\n' > "$TEST_HOME/.bashrc"
  printf '# unrelated login settings\nexport TEST_LOGIN=retained\n' > "$TEST_HOME/.bash_profile"
  printf 'KDASH_NS_MAP="test=retained"\n' > "$TEST_HOME/.config/kdash.conf"
  printf 'saved report\n' > "$TEST_HOME/kdash_reports/report.html"
  printf 'saved audit\n' > "$TEST_HOME/kdash_reports/audit/events.log"
  printf 'saved older binary\n' > "$TEST_HOME/.kdash-old/kdash.previous"
  cp -a -- "$TEST_HOME/.config" "$CASE_DIR/config.before"
  cp -a -- "$TEST_HOME/kdash_reports" "$CASE_DIR/reports.before"
  cp -a -- "$TEST_HOME/.kdash-old" "$CASE_DIR/old.before"
}

run_in_home() {
  env -i HOME="$TEST_HOME" XDG_CONFIG_HOME="$TEST_HOME/.config" \
    PATH="$TOOLS:/usr/bin:/bin" TERM=dumb KUBECONFIG="$TEST_HOME/no-kubeconfig" \
    /bin/bash "$@"
}

run_ok() {
  if ! run_in_home "$@" > "$LOG" 2>&1; then
    cat -- "$LOG" >&2
    fail "command failed: $*"
  fi
}

run_fails() {
  if run_in_home "$@" > "$LOG" 2>&1; then
    cat -- "$LOG" >&2
    fail "command unexpectedly succeeded: $*"
  fi
}

seed_install() {
  printf '#!/bin/sh\nexit 0\n' > "$PREFIX/kdash"
  chmod 755 "$PREFIX/kdash"
  printf '# installed completion\n' > "$TEST_HOME/.kdash-completion.bash"
  printf '# installed shell integration\n' > "$TEST_HOME/.kdash-shell.bash"
  local startup
  for startup in "$TEST_HOME/.bashrc" "$TEST_HOME/.bash_profile"; do
    cp -- "$startup" "$startup.expected"
    printf '%s\n' '# >>> kdash setup >>>' \
      '[ -r "$HOME/.kdash-shell.bash" ] && . "$HOME/.kdash-shell.bash"' \
      '# <<< kdash setup <<<' >> "$startup"
    cp -- "$startup" "$startup.installed"
  done
}

assert_preserved_data() {
  diff -r -- "$CASE_DIR/config.before" "$TEST_HOME/.config" || fail 'configuration changed'
  diff -r -- "$CASE_DIR/reports.before" "$TEST_HOME/kdash_reports" || fail 'reports or audit changed'
  diff -r -- "$CASE_DIR/old.before" "$TEST_HOME/.kdash-old" || fail 'older binaries changed'
}

assert_backup_contains() {
  local startup="$1" expected="$2" backup
  for backup in "$startup".bak.kdash.*; do
    if [ -f "$backup" ] && cmp -s -- "$backup" "$expected"; then return 0; fi
  done
  fail "no backup contains original contents of $startup"
}

assert_removed() {
  assert_absent "$PREFIX/kdash"
  assert_absent "$TEST_HOME/.kdash-completion.bash"
  assert_absent "$TEST_HOME/.kdash-shell.bash"
  if grep -qFx '# >>> kdash setup >>>' "$TEST_HOME/.bashrc" "$TEST_HOME/.bash_profile"; then
    fail 'startup marker remains'
  fi
  assert_preserved_data
}

test_installer_roundtrip() {
  fixture roundtrip
  cp -- "$TEST_HOME/.bashrc" "$CASE_DIR/rc.original"
  cp -- "$TEST_HOME/.bash_profile" "$CASE_DIR/profile.original"
  # --keep-old prevents the installer from moving any existing host binary.
  run_ok "$INSTALL" --prefix "$PREFIX" --keep-old
  assert_exists "$PREFIX/kdash"
  assert_exists "$TEST_HOME/.kdash-completion.bash"
  assert_exists "$TEST_HOME/.kdash-shell.bash"
  cmp -s -- "$REPO/kdash" "$PREFIX/kdash" || fail 'installer payload differs from kdash'
  grep -qFx '# >>> kdash setup >>>' "$TEST_HOME/.bashrc" || fail 'installer did not add shell block'
  cp -- "$TEST_HOME/.bashrc" "$CASE_DIR/rc.installed"
  cp -- "$TEST_HOME/.bash_profile" "$CASE_DIR/profile.installed"
  # The installer adds a separator newline outside its markers; keep it.
  { cat "$CASE_DIR/rc.original"; printf '\n'; } > "$CASE_DIR/rc.expected"
  { cat "$CASE_DIR/profile.original"; printf '\n'; } > "$CASE_DIR/profile.expected"
  run_ok "$UNINSTALL" --prefix "$PREFIX"
  assert_removed
  assert_same "$CASE_DIR/rc.expected" "$TEST_HOME/.bashrc"
  assert_same "$CASE_DIR/profile.expected" "$TEST_HOME/.bash_profile"
  assert_backup_contains "$(readlink -f -- "$TEST_HOME/.bashrc")" "$CASE_DIR/rc.installed"
  assert_backup_contains "$TEST_HOME/.bash_profile" "$CASE_DIR/profile.installed"
  cp -a -- "$TEST_HOME" "$CASE_DIR/after-first-uninstall"
  run_ok "$UNINSTALL" --prefix "$PREFIX"
  diff -r -- "$CASE_DIR/after-first-uninstall" "$TEST_HOME" || fail 'repeated uninstall changed files'
}

test_dry_run() {
  fixture dry-run
  seed_install
  cp -a -- "$TEST_HOME" "$CASE_DIR/before"
  run_ok "$UNINSTALL" --prefix "$PREFIX" --dry-run
  diff -r -- "$CASE_DIR/before" "$TEST_HOME" || fail 'dry run modified files'
  grep -qF "$PREFIX/kdash" "$LOG" || fail 'dry run omitted binary target'
}

test_binary_only() {
  fixture binary-only
  seed_install
  cp -a -- "$TEST_HOME" "$CASE_DIR/expected"
  rm -- "$CASE_DIR/expected/custom bin/kdash"
  rm -- "$CASE_DIR/expected/.kdash-completion.bash"
  run_ok "$UNINSTALL" --prefix "$PREFIX" --no-shell
  diff -r -- "$CASE_DIR/expected" "$TEST_HOME" || fail '--no-shell changed shell files or user data'
}

test_other_prefix_integration() {
  fixture other-prefix
  seed_install
  local other_prefix="$TEST_HOME/active bin"
  mkdir -- "$other_prefix"
  cp -- "$PREFIX/kdash" "$other_prefix/kdash"
  printf 'KDASH_BIN="%s/kdash"\n' "$other_prefix" > "$TEST_HOME/.kdash-shell.bash"
  cp -a -- "$TEST_HOME" "$CASE_DIR/expected"
  rm -- "$CASE_DIR/expected/custom bin/kdash"
  run_ok "$UNINSTALL" --prefix "$PREFIX"
  diff -r -- "$CASE_DIR/expected" "$TEST_HOME" || fail 'uninstall changed a different prefix installation'
}

test_default_prefix() {
  fixture default-prefix
  PREFIX="$TEST_HOME/.local/bin"
  mkdir -p -- "$PREFIX"
  seed_install
  run_ok "$UNINSTALL"
  assert_removed
}

test_malformed_markers() {
  local malformed
  for malformed in unterminated orphan nested; do
    fixture "malformed-$malformed"
    seed_install
    case "$malformed" in
      unterminated) printf '%s\n' '# >>> kdash setup >>>' 'keep this content' ;;
      orphan) printf '%s\n' '# <<< kdash setup <<<' 'keep this content' ;;
      nested) printf '%s\n' '# >>> kdash setup >>>' '# >>> kdash setup >>>' '# <<< kdash setup <<<' ;;
    esac >> "$TEST_HOME/.bash_profile"
    cp -a -- "$TEST_HOME" "$CASE_DIR/before"
    run_fails "$UNINSTALL" --prefix "$PREFIX"
    diff -r -- "$CASE_DIR/before" "$TEST_HOME" || fail "malformed $malformed block caused changes"
  done
}

test_symlink_and_text_preservation() {
  fixture symlink
  seed_install
  mkdir -- "$TEST_HOME/startup"
  mv -- "$TEST_HOME/.bashrc" "$TEST_HOME/startup/bashrc"
  ln -s 'startup/bashrc' "$TEST_HOME/.bashrc"
  # Marker-like text outside an exact marked block must remain byte-for-byte.
  printf ' # >>> kdash setup >>>\n# <<< kdash setup <<< suffix\nlast line without newline' >> "$TEST_HOME/.bashrc"
  printf ' # >>> kdash setup >>>\n# <<< kdash setup <<< suffix\nlast line without newline' >> "$TEST_HOME/.bashrc.expected"
  cp -- "$TEST_HOME/.bashrc" "$CASE_DIR/rc.installed"
  chmod 640 "$TEST_HOME/startup/bashrc"
  run_ok "$UNINSTALL" --prefix "$PREFIX"
  assert_removed
  [ -L "$TEST_HOME/.bashrc" ] || fail 'startup symlink was replaced'
  [ "$(readlink -- "$TEST_HOME/.bashrc")" = 'startup/bashrc' ] || fail 'startup symlink target changed'
  assert_same "$TEST_HOME/.bashrc.expected" "$TEST_HOME/startup/bashrc"
  [ "$(stat -c %a "$TEST_HOME/startup/bashrc")" = 640 ] || fail 'startup permissions changed'
  assert_backup_contains "$(readlink -f -- "$TEST_HOME/.bashrc")" "$CASE_DIR/rc.installed"
}

test_permission_failure() {
  fixture permission-failure
  seed_install
  cp -a -- "$TEST_HOME" "$CASE_DIR/before"
  chmod 555 "$PREFIX"
  run_fails "$UNINSTALL" --prefix "$PREFIX"
  assert_exists "$PREFIX/kdash"
  chmod 755 "$PREFIX"
  diff -r -- "$CASE_DIR/before" "$TEST_HOME" || fail 'permission failure caused changes'
  assert_preserved_data
}

test_binary_symlinks() {
  local kind
  for kind in valid broken; do
    fixture "binary-symlink-$kind"
    seed_install
    mv -- "$PREFIX/kdash" "$TEST_HOME/retained-binary"
    if [ "$kind" = valid ]; then
      ln -s "$TEST_HOME/retained-binary" "$PREFIX/kdash"
    else
      ln -s "$TEST_HOME/absent-binary" "$PREFIX/kdash"
    fi
    cp -- "$TEST_HOME/retained-binary" "$CASE_DIR/binary.before"
    run_ok "$UNINSTALL" --prefix "$PREFIX"
    assert_removed
    assert_same "$CASE_DIR/binary.before" "$TEST_HOME/retained-binary"
  done
}

test_cli_validation() {
  fixture cli-validation
  seed_install
  cp -a -- "$TEST_HOME" "$CASE_DIR/before"
  run_ok "$UNINSTALL" --help
  run_fails "$UNINSTALL" --prefix
  run_fails "$UNINSTALL" --unknown-option
  diff -r -- "$CASE_DIR/before" "$TEST_HOME" || fail 'help or invalid flags modified files'
}

test_bundle_compatibility() {
  fixture bundle-compatibility
  awk '
    copying && $0 == "KDASH_UNINSTALL_EOF" { exit }
    copying { print }
    /^  bash -s -- / && /KDASH_UNINSTALL_EOF/ { copying=1 }
  ' "$INSTALL" > "$CASE_DIR/embedded-uninstall.sh"
  assert_same "$UNINSTALL" "$CASE_DIR/embedded-uninstall.sh"
  seed_install
  cp -a -- "$TEST_HOME" "$CASE_DIR/before"
  run_ok "$INSTALL" --uninstall --prefix "$PREFIX" --dry-run
  diff -r -- "$CASE_DIR/before" "$TEST_HOME" || fail 'bundle uninstall dry run modified files'
  run_ok "$INSTALL" --uninstall --prefix "$PREFIX"
  assert_removed
  assert_same "$TEST_HOME/.bashrc.expected" "$TEST_HOME/.bashrc"
}

passed=0
for test in test_installer_roundtrip test_dry_run test_binary_only test_other_prefix_integration \
  test_default_prefix test_malformed_markers test_symlink_and_text_preservation \
  test_permission_failure test_binary_symlinks test_cli_validation test_bundle_compatibility; do
  ( "$test" )
  passed=$((passed + 1))
  printf 'PASS %s\n' "$test"
done
printf 'Passed %s uninstall integration tests.\n' "$passed"
