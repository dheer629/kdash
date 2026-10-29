#!/usr/bin/env bash
# Package a specific committed version without changing the working tree.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
ref="${1:-HEAD}"; output="${2:-dist}"
commit="$(git rev-parse --verify "$ref^{commit}")"
version="$(git show "$commit:kdash" | sed -n 's/^KDASH_VERSION="\([^"]*\)"$/\1/p' | head -1)"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[A-Za-z0-9.]+)?$ ]] || { echo 'invalid release version' >&2; exit 1; }
dir="$output/v$version"; mkdir -p "$dir"
for file in kdash kdash-bundle.sh kdash-uninstall.sh README.md LICENSE; do
    git show "$commit:$file" > "$dir/$file"
done
chmod 755 "$dir/kdash" "$dir/kdash-bundle.sh" "$dir/kdash-uninstall.sh"
tar -czf "$dir/kdash-$version.tar.gz" -C "$dir" kdash kdash-bundle.sh kdash-uninstall.sh README.md LICENSE
( cd "$dir"; sha256sum kdash kdash-bundle.sh kdash-uninstall.sh README.md LICENSE "kdash-$version.tar.gz" > SHA256SUMS )
printf 'Version: %s\nCommit: %s\nAssets: %s\n' "$version" "$commit" "$dir"
