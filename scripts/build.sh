#!/usr/bin/env bash
# Assemble optional source modules into the single-file CLI and installer.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
tmp="$(mktemp)"; bundle="$(mktemp)"
trap 'rm -f "$tmp" "$bundle"' EXIT
awk '/^# BEGIN KDASH MODULES$/ {skip=1; next} /^# END KDASH MODULES$/ {skip=0; next} !skip {print}' kdash > "$tmp"
awk '/^#-- main / {exit} {print}' "$tmp" > "$bundle"
printf '# BEGIN KDASH MODULES\n' >> "$bundle"
for module in runtime events health inspector; do
    [ -f "src/$module.sh" ] || { printf 'missing src/%s.sh\n' "$module" >&2; exit 1; }
    cat "src/$module.sh" >> "$bundle"; printf '\n' >> "$bundle"
done
printf '# END KDASH MODULES\n' >> "$bundle"
awk 'found {print} /^#-- main / {found=1; print}' "$tmp" >> "$bundle"
bash -n "$bundle"
cat "$bundle" > kdash
awk '/^cat > "\$tmp" <<\047KDASH_PAYLOAD_EOF\047$/ {print; exit} {print}' kdash-bundle.sh > "$tmp"
cat kdash >> "$tmp"
awk 'found {print} /^KDASH_PAYLOAD_EOF$/ {found=1; print}' kdash-bundle.sh >> "$tmp"
version="$(sed -n 's/^KDASH_VERSION="\([^"]*\)"$/\1/p' kdash | head -1)"
sed "s/^VERSION=\"[^\"]*\"$/VERSION=\"$version\"/" "$tmp" > "$bundle"
bash -n "$bundle"
cat "$bundle" > kdash-bundle.sh
printf 'Built kdash %s and synchronized installer.\n' "$version"
