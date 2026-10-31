#!/usr/bin/env bash
# Assemble source modules into the single-file CLI and installer. Import a new
# one-file utility with --from-bundle before building, or use --check in CI.
# The standalone uninstaller is kept byte-identical to its embedded copy too.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

mode="${1:-build}"
case "$mode" in
    build|--check|--from-bundle) [ "$#" -le 1 ] ;;
    -h|--help)
        printf '%s\n' 'Usage: bash scripts/build.sh [--check | --from-bundle]' \
            '  no option       rebuild kdash from src/ and synchronize the installer' \
            '  --check         verify payloads, modules and versions without changing files' \
            '  --from-bundle   import kdash, uninstaller and src/ from an updated bundle'
        exit 0 ;;
    *) printf 'build: unknown option: %s\n' "$mode" >&2; exit 2 ;;
esac

build_tmp="$(mktemp -d "${TMPDIR:-/tmp}/kdash-build.XXXXXXXX")"
trap 'rm -rf -- "$build_tmp"' EXIT
modules=(runtime events health inspector interactive)
fail() { printf 'build: %s\n' "$*" >&2; exit 1; }

extract_payload() {
    awk '
      /^cat > "\$tmp" <<\047KDASH_PAYLOAD_EOF\047$/ { starts++; capture=1; next }
      capture && /^KDASH_PAYLOAD_EOF$/ { ends++; capture=0; next }
      capture { print }
      END { if (starts != 1 || ends != 1 || capture) exit 1 }
    ' kdash-bundle.sh > "$build_tmp/payload" || fail 'installer payload markers are missing or repeated'
    bash -n "$build_tmp/payload"
    awk '
      /<<\047KDASH_UNINSTALL_EOF\047$/ { starts++; capture=1; next }
      capture && /^KDASH_UNINSTALL_EOF$/ { ends++; capture=0; next }
      capture { print }
      END { if (starts != 1 || ends != 1 || capture) exit 1 }
    ' kdash-bundle.sh > "$build_tmp/uninstall-payload" || fail 'uninstaller markers are missing or repeated'
    bash -n "$build_tmp/uninstall-payload"
}

check_layout() {
    awk '
      /^# BEGIN KDASH MODULES$/ { if (state != 0) exit 1; starts++; state=1; next }
      /^# END KDASH MODULES$/ { if (state != 1) exit 1; ends++; state=2; next }
      /^#-- main / { if (state != 2) exit 1; mains++ }
      END { if (starts != 1 || ends != 1 || mains != 1 || state != 2) exit 1 }
    ' "$1" || fail 'CLI module/main markers are missing, out of order or repeated'
}

cli_version() {
    sed -n 's/^KDASH_VERSION="\([^"]*\)"$/\1/p' "$1"
}

extract_payload
payload_version="$(cli_version "$build_tmp/payload")"
installer_version="$(sed -n 's/^VERSION="\([^"]*\)"$/\1/p' kdash-bundle.sh)"
[[ "$payload_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail 'payload must have exactly one semantic version'
[ "$payload_version" = "$installer_version" ] || fail 'installer VERSION differs from the embedded CLI'

if [ "$mode" = --from-bundle ]; then
    check_layout "$build_tmp/payload"
    mkdir "$build_tmp/src"
    # These module headings are stable source boundaries in the single-file CLI.
    # Keep every byte of each module, removing only the build separator blank line.
    awk -v dest="$build_tmp/src" '
      /^# BEGIN KDASH MODULES$/ { active=1; next }
      /^# END KDASH MODULES$/ { active=0; next }
      !active { next }
      /^# Runtime diagnostics, filtering and bounded background snapshots \(embedded\)\.$/ { name="runtime"; count++ }
      /^# Kubernetes API Events and deterministic incident evidence\. This source module$/ { name="events"; count++ }
      /^# Service and storage diagnostics\. Embedded into kdash before main; also sourceable$/ { name="health"; count++ }
      /^# Interactive pod inspection \(read-only reads\) plus the opt-in container shell and file copy\. This source is embedded in the release$/ { name="inspector"; count++ }
      /^# Interactive attachments: open a shell in a container, and copy files in or out$/ { name="interactive"; count++ }
      { if (name == "") exit 1; print > (dest "/" name ".segment") }
      END { if (count != 5) exit 1 }
    ' "$build_tmp/payload" || fail 'cannot identify all five source module boundaries'
    : > "$build_tmp/modules"
    for module in "${modules[@]}"; do
        [ -s "$build_tmp/src/$module.segment" ] || fail "missing embedded module: $module"
        awk 'NR > 1 { print previous } { previous=$0 } END { if (previous != "") exit 1 }' \
            "$build_tmp/src/$module.segment" > "$build_tmp/src/$module.sh" \
            || fail "missing separator after module: $module"
        bash -n "$build_tmp/src/$module.sh"
        cat "$build_tmp/src/$module.sh" >> "$build_tmp/modules"
        printf '\n' >> "$build_tmp/modules"
    done
    awk '/^# BEGIN KDASH MODULES$/ { active=1; next } /^# END KDASH MODULES$/ { active=0; next } active' \
        "$build_tmp/payload" > "$build_tmp/embedded-modules"
    cmp -s "$build_tmp/modules" "$build_tmp/embedded-modules" || fail 'module import would change the payload'
    cat "$build_tmp/payload" > kdash
    cat "$build_tmp/uninstall-payload" > kdash-uninstall.sh
    for module in "${modules[@]}"; do cat "$build_tmp/src/$module.sh" > "src/$module.sh"; done
    printf 'Imported kdash %s, uninstaller and source modules (installer unchanged).\n' "$payload_version"
    exit 0
fi

check_layout kdash
version="$(cli_version kdash)"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail 'kdash must have exactly one semantic version'
if [ "$mode" = build ] && [ "$payload_version" != "$version" ] &&
   [ "$(printf '%s\n%s\n' "$version" "$payload_version" | sort -V | tail -1)" = "$payload_version" ]; then
    fail "installer $payload_version is newer than kdash $version; import it with --from-bundle first"
fi

awk '/^# BEGIN KDASH MODULES$/ { exit } { print }' kdash > "$build_tmp/kdash"
printf '# BEGIN KDASH MODULES\n' >> "$build_tmp/kdash"
for module in "${modules[@]}"; do
    [ -f "src/$module.sh" ] || fail "missing src/$module.sh"
    bash -n "src/$module.sh"
    cat "src/$module.sh" >> "$build_tmp/kdash"
    printf '\n' >> "$build_tmp/kdash"
done
printf '# END KDASH MODULES\n' >> "$build_tmp/kdash"
awk 'found { print } /^# END KDASH MODULES$/ { found=1 }' kdash >> "$build_tmp/kdash"
bash -n "$build_tmp/kdash"

awk '/^cat > "\$tmp" <<\047KDASH_PAYLOAD_EOF\047$/ { print; exit } { print }' kdash-bundle.sh > "$build_tmp/bundle"
cat "$build_tmp/kdash" >> "$build_tmp/bundle"
awk 'found { print } /^KDASH_PAYLOAD_EOF$/ { found=1; print }' kdash-bundle.sh >> "$build_tmp/bundle"
bash -n kdash-uninstall.sh
awk -v source="kdash-uninstall.sh" '
  /<<\047KDASH_UNINSTALL_EOF\047$/ {
    print
    while ((getline line < source) > 0) print line
    close(source); skip=1; next
  }
  /^KDASH_UNINSTALL_EOF$/ { skip=0 }
  !skip { print }
' "$build_tmp/bundle" > "$build_tmp/with-uninstaller"
sed "s/^VERSION=\"[^\"]*\"$/VERSION=\"$version\"/" "$build_tmp/with-uninstaller" > "$build_tmp/installer"
bash -n "$build_tmp/installer"

if [ "$mode" = --check ]; then
    cmp -s "$build_tmp/kdash" kdash || fail 'src modules differ from kdash; run scripts/build.sh'
    cmp -s "$build_tmp/payload" kdash || fail 'installer payload differs from kdash; build or import the intended source'
    cmp -s "$build_tmp/uninstall-payload" kdash-uninstall.sh || fail 'embedded and standalone uninstallers differ'
    cmp -s "$build_tmp/installer" kdash-bundle.sh || fail 'installer version or payload is out of sync'
    printf 'kdash %s: source modules, CLI and installer are synchronized.\n' "$version"
else
    # Validate both generated outputs before replacing either published entry point.
    cat "$build_tmp/kdash" > kdash
    cat "$build_tmp/installer" > kdash-bundle.sh
    printf 'Built kdash %s and synchronized installer.\n' "$version"
fi
