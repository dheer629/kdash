#!/usr/bin/env bash
# Build/import regression tests use private copies and never edit the checkout.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_TEST_TMP="$(mktemp -d "${TMPDIR:-/tmp}/kdash-build-test.XXXXXXXX")"
trap 'rm -rf -- "$BUILD_TEST_TMP"' EXIT
count=0; fixture=""
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
pass() { count=$((count + 1)); printf 'PASS: %s\n' "$*"; }

fresh() {
    fixture="$BUILD_TEST_TMP/case-$count"
    mkdir -p "$fixture/src" "$fixture/scripts"
    cp "$ROOT/kdash" "$ROOT/kdash-bundle.sh" "$ROOT/kdash-uninstall.sh" "$fixture/"
    cp "$ROOT"/src/*.sh "$fixture/src/"
    cp "$ROOT/scripts/build.sh" "$fixture/scripts/"
}
snapshot() {
    find "$fixture" -type f -exec sha256sum {} + | LC_ALL=C sort > "$1"
}
reject_unchanged() {
    local message="$1"; shift
    snapshot "$BUILD_TEST_TMP/before"
    if bash "$fixture/scripts/build.sh" "$@" > "$BUILD_TEST_TMP/output" 2>&1; then
        fail "$message unexpectedly succeeded"
    fi
    snapshot "$BUILD_TEST_TMP/after"
    cmp -s "$BUILD_TEST_TMP/before" "$BUILD_TEST_TMP/after" || fail "$message changed files"
    pass "$message refuses without changing files"
}
build() {
    bash "$fixture/scripts/build.sh" "$@" > "$BUILD_TEST_TMP/output" 2>&1 \
        || { cat "$BUILD_TEST_TMP/output" >&2; fail "build $*"; }
}

fresh
snapshot "$BUILD_TEST_TMP/before"
build --check
build --from-bundle
build
build --check
snapshot "$BUILD_TEST_TMP/after"
cmp -s "$BUILD_TEST_TMP/before" "$BUILD_TEST_TMP/after" || fail 'import/build roundtrip changed synchronized files'
pass 'import, build and check preserve synchronized files byte for byte'

fresh
printf '\n# fixture source edit\n' >> "$fixture/src/runtime.sh"
reject_unchanged 'check detects a stale embedded module' --check
build
build --check
grep -q '^# fixture source edit$' "$fixture/kdash" || fail 'source edit was lost during build'
pass 'normal build propagates source module edits into both entry points'

fresh
# Import must recover all derived sources, including a completely stale CLI.
printf '#!/usr/bin/env bash\nKDASH_VERSION="0.0.0"\n' > "$fixture/kdash"
printf '# stale module\n' > "$fixture/src/runtime.sh"
printf '# stale uninstaller\n' > "$fixture/kdash-uninstall.sh"
cp "$fixture/kdash-bundle.sh" "$BUILD_TEST_TMP/bundle-before"
build --from-bundle
build --check
cmp -s "$fixture/kdash" "$ROOT/kdash" || fail 'import did not recover CLI'
cmp -s "$fixture/src/runtime.sh" "$ROOT/src/runtime.sh" || fail 'import did not recover source module'
cmp -s "$fixture/kdash-uninstall.sh" "$ROOT/kdash-uninstall.sh" || fail 'import did not recover uninstaller'
cmp -s "$fixture/kdash-bundle.sh" "$BUILD_TEST_TMP/bundle-before" || fail 'import changed authoritative bundle'
pass 'bundle import recovers CLI, modules and uninstaller without changing the bundle'

fresh
sed -i 's/^KDASH_VERSION="[^"]*"$/KDASH_VERSION="0.0.0"/' "$fixture/kdash"
reject_unchanged 'normal build protects a newer bundle'
grep -q -- '--from-bundle' "$BUILD_TEST_TMP/output" || fail 'newer-bundle refusal lacks import hint'

fresh
sed -i 's/^KDASH_PAYLOAD_EOF$/BROKEN_PAYLOAD_MARKER/' "$fixture/kdash-bundle.sh"
reject_unchanged 'import rejects a malformed payload marker' --from-bundle

fresh
sed -i 's/^# END KDASH MODULES$/# BROKEN MODULE END/' "$fixture/kdash-bundle.sh"
reject_unchanged 'import rejects malformed module markers' --from-bundle

fresh
sed -i 's/^# Kubernetes API Events and deterministic incident evidence\. This source module$/# changed fixture boundary/' "$fixture/kdash-bundle.sh"
reject_unchanged 'import rejects an unknown module boundary' --from-bundle

fresh
sed -i '/^# Runtime diagnostics, filtering and bounded background snapshots (embedded)\.$/a # Runtime diagnostics, filtering and bounded background snapshots (embedded).' "$fixture/kdash-bundle.sh"
reject_unchanged 'import rejects a duplicated module boundary' --from-bundle

fresh
printf '\n# fixture uninstall edit\n' >> "$fixture/kdash-uninstall.sh"
reject_unchanged 'check detects a stale embedded uninstaller' --check
build
build --check
grep -q '^# fixture uninstall edit$' "$fixture/kdash-bundle.sh" || fail 'uninstaller edit was not embedded'
cp "$fixture/kdash-uninstall.sh" "$BUILD_TEST_TMP/uninstaller-before"
build --from-bundle
cmp -s "$fixture/kdash-uninstall.sh" "$BUILD_TEST_TMP/uninstaller-before" || fail 'uninstaller roundtrip changed bytes'
pass 'normal build and import synchronize the standalone uninstaller'

fresh
sed -i 's/^KDASH_UNINSTALL_EOF$/BROKEN_UNINSTALL_MARKER/' "$fixture/kdash-bundle.sh"
reject_unchanged 'build rejects a malformed uninstaller marker'

printf 'PASS: %s build/import checks (no cluster required)\n' "$count"
