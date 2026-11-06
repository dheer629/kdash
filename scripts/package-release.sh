#!/usr/bin/env bash
# Package a specific committed version without changing the working tree.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
ref="${1:-HEAD}"; output="${2:-dist}"
commit="$(git rev-parse --verify "$ref^{commit}")"
version="$(git show "$commit:kdash" | sed -n 's/^KDASH_VERSION="\([^"]*\)"$/\1/p' | head -1)"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[A-Za-z0-9.]+)?$ ]] || { echo 'invalid release version' >&2; exit 1; }
dir="$output/v$version"; mkdir -p "$dir"
files=(kdash kdash-bundle.sh kdash-uninstall.sh README.md LICENSE)
for doc in CHANGELOG.md RELEASES.md DEVOPS_USER_GUIDE.md; do
    if git cat-file -e "$commit:$doc" 2>/dev/null; then files+=("$doc"); fi
done
for file in "${files[@]}"; do
    git show "$commit:$file" > "$dir/$file"
done
if run="$(git show "$commit:artifacts/latest-e2e.txt" 2>/dev/null)" && [ -n "$run" ]; then
    [[ "$run" =~ ^live-e2e-[A-Za-z0-9-]+$ ]] || { echo 'invalid validation evidence path' >&2; exit 1; }
    git show "$commit:artifacts/$run/results.json" > "$dir/VALIDATION.json"
    git show "$commit:artifacts/$run/captures.tsv" > "$dir/SCREENSHOTS.tsv"
    git show "$commit:artifacts/$run/browser-results.json" > "$dir/BROWSER_VALIDATION.json"
    files+=(VALIDATION.json BROWSER_VALIDATION.json SCREENSHOTS.tsv)
fi
chmod 755 "$dir/kdash" "$dir/kdash-bundle.sh" "$dir/kdash-uninstall.sh"
tar -czf "$dir/kdash-$version.tar.gz" -C "$dir" "${files[@]}"
( cd "$dir"; sha256sum "${files[@]}" "kdash-$version.tar.gz" > SHA256SUMS )
printf 'Version: %s\nCommit: %s\nAssets: %s\n' "$version" "$commit" "$dir"
