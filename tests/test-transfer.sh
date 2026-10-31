#!/usr/bin/env bash
# Exercise the shipped Python ZIP fallback on an extracted container tar archive.
# All symlink targets and data are private fixtures; no cluster or terminal is used.
set -euo pipefail
if ! command -v python3 >/dev/null 2>&1; then
    printf 'SKIP: Python ZIP fallback checks (optional python3 is unavailable)\n'
    exit 0
fi
REPO="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TRANSFER_TEST_TMP="$(mktemp -d "${TMPDIR:-/tmp}/kdash-transfer-test.XXXXXXXX")"
trap 'rm -rf -- "$TRANSFER_TEST_TMP"' EXIT
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
mkdir -p "$TRANSFER_TEST_TMP/source/tree" "$TRANSFER_TEST_TMP/stage" "$TRANSFER_TEST_TMP/host-dir"
printf 'HOST-ONLY-CONTENT' > "$TRANSFER_TEST_TMP/host-file"
printf 'HOST-DIRECTORY-CONTENT' > "$TRANSFER_TEST_TMP/host-dir/host-child"
printf 'container regular file' > "$TRANSFER_TEST_TMP/source/regular.txt"
printf 'container nested file' > "$TRANSFER_TEST_TMP/source/tree/ordinary.txt"
for dir in "$TRANSFER_TEST_TMP/source" "$TRANSFER_TEST_TMP/source/tree"; do
    ln -s "$TRANSFER_TEST_TMP/host-file" "$dir/file-link"
    ln -s "$TRANSFER_TEST_TMP/host-dir" "$dir/dir-link"
    ln -s "$TRANSFER_TEST_TMP/missing-host-path" "$dir/dangling-link"
done
( cd "$TRANSFER_TEST_TMP/source" && tar cf "$TRANSFER_TEST_TMP/container.tar" \
    regular.txt file-link dir-link dangling-link tree )
tar xf "$TRANSFER_TEST_TMP/container.tar" -C "$TRANSFER_TEST_TMP/stage"

# Extract the actual embedded program, so this verifies the published fallback
# rather than a second implementation of its archive logic.
awk '
  index($0, "python3 - ") && /<<\047PY\047$/ { capture=1; starts++; next }
  capture && $0 == "PY" { capture=0; ends++; next }
  capture { print }
  END { if (starts != 1 || ends != 1 || capture) exit 1 }
' "$REPO/src/interactive.sh" > "$TRANSFER_TEST_TMP/fallback.py" || fail 'cannot locate ZIP fallback'
( cd "$TRANSFER_TEST_TMP/stage" && python3 "$TRANSFER_TEST_TMP/fallback.py" \
    "$TRANSFER_TEST_TMP/result.zip" regular.txt file-link dir-link dangling-link tree )

python3 - "$TRANSFER_TEST_TMP" <<'PY'
import pathlib, stat, sys, zipfile
base = pathlib.Path(sys.argv[1])
with zipfile.ZipFile(base / "result.zip") as z:
    names = set(z.namelist())
    expected = {
        "regular.txt", "file-link", "dir-link", "dangling-link", "tree/",
        "tree/ordinary.txt", "tree/file-link", "tree/dir-link", "tree/dangling-link",
    }
    assert names == expected, ("unexpected archive entries", names)
    for prefix in ("", "tree/"):
        for name, target in (
            ("file-link", "host-file"),
            ("dir-link", "host-dir"),
            ("dangling-link", "missing-host-path"),
        ):
            entry = z.getinfo(prefix + name)
            assert entry.create_system == 3 and stat.S_ISLNK(entry.external_attr >> 16), entry
            assert z.read(entry) == str(base / target).encode(), ("link target changed", entry.filename)
    assert z.read("regular.txt") == b"container regular file"
    assert z.read("tree/ordinary.txt") == b"container nested file"
    for name in names:
        contents = z.read(name)
        assert b"HOST-ONLY-CONTENT" not in contents, ("host file leaked", name)
        assert b"HOST-DIRECTORY-CONTENT" not in contents, ("host directory leaked", name)
print("PASS: Python ZIP fallback preserves regular files and six file/directory/dangling links without reading host targets")
PY
