#!/usr/bin/env bash
# Check the shipped fingerprint program and saved namespace defaults against real
# files. Kubernetes and a terminal are unnecessary; the live suite covers exec.
set -euo pipefail
REPO="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
source "$REPO/src/inspector.sh"
source "$REPO/src/interactive.sh"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/kdash-verification-tests.XXXXXXXX")"
trap 'rm -rf -- "$TEST_ROOT"' EXIT
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
audit() { :; }
extract_function() {
    awk -v name="$1" 'index($0, name "()") == 1 {on=1} on {print} on && $0=="}" {exit}' "$REPO/kdash"
}
source <(extract_function ns_saved_default)
source <(extract_function ns_save_default)

mkdir -p "$TEST_ROOT/source/tree/empty dir" "$TEST_ROOT/source/tree/nested dir" "$TEST_ROOT/dest"
printf 'content one' > "$TEST_ROOT/source/tree/nested dir/file with spaces"
printf 'ordinary file' > "$TEST_ROOT/source/plain.txt"
printf 'host data must never be followed' > "$TEST_ROOT/host-file"
ln -s "$TEST_ROOT/host-file" "$TEST_ROOT/source/tree/host-link"
ln -s alpha "$TEST_ROOT/source/tree/dangling-link"
ln -s missing "$TEST_ROOT/source/top-link"
( cd "$TEST_ROOT/source" && tar cf - tree plain.txt top-link ) | ( cd "$TEST_ROOT/dest" && tar xf - )

declare -A STT=() STF=() STB=() STH=() DTT=() DTF=() DTB=() DTH=()
STALG=; DTALG=; XV_SRC=SOURCE; XV_DST=DESTINATION; BARCHR=ascii
xfer_glyphs
compare() {
    local alg="${1:-sha256}"
    STT=(); STF=(); STB=(); STH=(); DTT=(); DTF=(); DTB=(); DTH=()
    sh -c "$XFER_SUM_SH" kdash "$alg" "$TEST_ROOT/source" tree plain.txt top-link > "$TEST_ROOT/source.sum"
    sh -c "$XFER_SUM_SH" kdash "$alg" "$TEST_ROOT/dest" tree plain.txt top-link > "$TEST_ROOT/dest.sum"
    xfer_sum_parse "$TEST_ROOT/source.sum" ST
    xfer_sum_parse "$TEST_ROOT/dest.sum" DT
    xfer_verify_table "$TEST_ROOT/verify.tsv" tree plain.txt top-link
}
compare
[ "$XV_OK" = 3 ] && [ "$XV_BAD" = 0 ] || fail 'identical files, directories and dangling links do not verify'
[ "${STF[tree]}" = 1 ] || fail 'directory file count is not the count of regular files'

rm "$TEST_ROOT/dest/tree/dangling-link"
ln -s omega "$TEST_ROOT/dest/tree/dangling-link"
compare
[ "$XV_BAD" = 1 ] || fail 'changed nested symlink target was reported identical'
rm "$TEST_ROOT/dest/tree/dangling-link"
ln -s alpha "$TEST_ROOT/dest/tree/dangling-link"
rmdir "$TEST_ROOT/dest/tree/empty dir"
compare
[ "$XV_BAD" = 1 ] || fail 'missing empty directory was reported identical'
mkdir "$TEST_ROOT/dest/tree/empty dir"
printf 'content two' > "$TEST_ROOT/dest/tree/nested dir/file with spaces"
compare
[ "$XV_BAD" = 1 ] || fail 'same-size nested file corruption was reported identical'
printf 'content one' > "$TEST_ROOT/dest/tree/nested dir/file with spaces"
printf 'host data changed after the copy' > "$TEST_ROOT/host-file"
compare
[ "$XV_BAD" = 0 ] || fail 'directory fingerprints followed a symlink into this host'

if command -v md5sum >/dev/null 2>&1; then
    mkdir "$TEST_ROOT/dest/tree/extra-empty-dir"
    compare md5
    [ "$XV_BAD" = 1 ] || fail 'MD5 fallback missed an extra empty directory'
    rmdir "$TEST_ROOT/dest/tree/extra-empty-dir"
fi
printf 'longer ordinary file' > "$TEST_ROOT/dest/plain.txt"
compare none
[ "$XV_BAD" = 1 ] || fail 'size-only fallback missed a changed file size'

mkdir "$TEST_ROOT/names"
printf keep > "$TEST_ROOT/names/report.txt"
ln -s missing "$TEST_ROOT/names/report (2).txt"
[ "$(xfer_free_name "$TEST_ROOT/names" report.txt)" = 'report (3).txt' ] || fail 'keep both would replace an existing file or dangling link'
[ "$(cat "$TEST_ROOT/names/report.txt")" = keep ] || fail 'name selection modified an existing file'

# Available archive integrity checks must fail closed. Test real generated
# archives and deliberately corrupted bytes through the shipped helper.
( cd "$TEST_ROOT/source" && tar czf "$TEST_ROOT/valid.tar.gz" plain.txt )
xfer_archive_test tgz "$TEST_ROOT/valid.tar.gz" || fail 'valid tar.gz failed its integrity test'
printf corrupt > "$TEST_ROOT/corrupt.tar.gz"
if xfer_archive_test tgz "$TEST_ROOT/corrupt.tar.gz"; then fail 'corrupt tar.gz passed its integrity test'; fi
if command -v python3 >/dev/null 2>&1; then
    python3 - "$TEST_ROOT/valid.zip" <<'PY'
import sys, zipfile
with zipfile.ZipFile(sys.argv[1], "w") as z:
    z.writestr("plain.txt", b"ordinary file")
PY
    xfer_archive_test zip "$TEST_ROOT/valid.zip" || fail 'valid ZIP failed its integrity test'
    printf corrupt > "$TEST_ROOT/corrupt.zip"
    if xfer_archive_test zip "$TEST_ROOT/corrupt.zip"; then fail 'corrupt ZIP passed its integrity test'; fi
fi

# Exercise the complete upload's post-copy branch. Only the transport and UI
# selection are injected: the real fingerprint/comparison, return and audit run.
# Same-length corruption must return failure even though the copy transport said
# success, while retaining the useful CHECK table for the operator.
(
    TMPD="$TEST_ROOT/upload-tmp"; mkdir -p "$TMPD"
    mkdir -p "$TEST_ROOT/upload-source" "$TEST_ROOT/upload-dest"
    printf ORIGINAL > "$TEST_ROOT/upload-source/plain.txt"
    CTX_NAME=fixture; NS=demo; COLOR=0; BARCHR=ascii; picker_colors
    AUDIT_LOG="$TEST_ROOT/upload.audit"
    audit() { printf '%s\t%s\n' "$1" "${2:-}" >> "$AUDIT_LOG"; }
    xfer_browse() {
        if [ "$1" = local ]; then
            XFER_DIR="$TEST_ROOT/upload-source"; XFER_SEL=(plain.txt); XFER_SELT=(f); XFER_SELS=(8)
        else XFER_DIR="$TEST_ROOT/upload-dest"; fi
    }
    xfer_upload_summary() { XP_TOOLS=' tar sha256sum '; return 0; }
    xfer_run_bg() { shift 3; "$@"; }
    xfer_up_pipe() { printf 'CORRUPT!' > "$TEST_ROOT/upload-dest/plain.txt"; return 0; }
    fake_exec() { while [ "$#" -gt 0 ] && [ "$1" != -- ]; do shift; done; shift; "$@"; }
    KC=(fake_exec)
    picker_size() { PK_COLS=100; PK_ROWS=32; }
    xfer_result_box() { printf 'CHECK: %s mismatched item(s)\n' "$XV_BAD"; }
    read() { if [ "${1:-}" = -rsn1 ]; then return 1; else builtin read "$@"; fi; }
    rc=0
    xfer_upload_once demo api app > "$TEST_ROOT/upload-result" 2> "$TEST_ROOT/upload.err" || rc=$?
    [ "$rc" = 1 ] || fail "checksum mismatch returned upload success ($rc)"
    grep -Fq 'CHECK: 1 mismatched item(s)' "$TEST_ROOT/upload-result" || fail 'mismatch hid the detailed result'
    grep -Eq '^CP_END.*rc=1 identical=0 differ=1 alg=sha256' "$AUDIT_LOG" || fail 'mismatched upload audit reported success'
)

USERCONF="$TEST_ROOT/kdash.conf"
printf 'KDASH_INTERVAL=7\nKDASH_NS_MAP="older=keep target=previous"\n' > "$USERCONF"
KDASH_NS_MAP='older=keep target=previous'; CTX_NAME=target
ns_save_default preferred
[ "$(ns_saved_default)" = preferred ] || fail 'saved namespace cannot be retrieved'
grep -qx 'KDASH_INTERVAL=7' "$USERCONF" || fail 'saving a namespace changed unrelated settings'
[ "$(grep -c '^KDASH_NS_MAP=' "$USERCONF")" = 1 ] || fail 'saving appended a duplicate namespace assignment'
CTX_NAME='cluster$(printf changed)"`printf altered`\'
ns_save_default preferred
restored="$(bash --noprofile --norc -c '. "$1"; printf %s "$KDASH_NS_MAP"' _ "$USERCONF")"
[ "$restored" = "$KDASH_NS_MAP" ] || fail 'context shell syntax was evaluated while loading the saved config'
CTX_NAME=target
ns_save_default ''
[ -z "$(ns_saved_default)" ] || fail 'forget default did not remove the selected context'
[[ "$KDASH_NS_MAP" == *older=keep* ]] || fail 'forget default removed another context'

awk '
  index($0, "if [ -z \"$NS\" ] && [ \"$ALL_NS\" = 0 ] && [ \"$DO_SREP\" = 0 ]; then") == 1 {on=1}
  on && index($0, "[ \"$ALL_NS\" = 1 ] && PICK_NS=0") == 1 {exit}
  on {print}
' "$REPO/kdash" > "$TEST_ROOT/namespace-resolution.sh"
[ -s "$TEST_ROOT/namespace-resolution.sh" ] || fail 'could not locate the shipped namespace resolution'
fake_kubectl() { case "$*" in 'config current-context') printf target ;; 'config view'*) printf kube-namespace ;; *) return 99 ;; esac; }
resolve_namespace() (
    NS="$1"; CTX="$2"; KDASH_NS_MAP="$3"; ALL_NS="${4:-0}"; DO_SREP=0; INTERACTIVE=0; KC=(fake_kubectl)
    source "$TEST_ROOT/namespace-resolution.sh"
    printf '%s' "$NS"
)
[ "$(resolve_namespace explicit target target=saved)" = explicit ] || fail 'saved namespace overrode explicit -n'
[ "$(resolve_namespace '' target target=saved)" = saved ] || fail 'kubeconfig namespace overrode the saved default'
[ "$(resolve_namespace '' '' target=saved)" = saved ] || fail 'saved default did not resolve the current context'
[ "$(resolve_namespace '' target other=saved)" = kube-namespace ] || fail 'another context changed kubeconfig fallback'
[ -z "$(resolve_namespace '' target target=saved 1)" ] || fail 'saved default overrode all-namespaces scope'
printf 'PASS: transfer fingerprints and archive checks catch corruption; mismatches fail and are audited; keep both and namespace defaults preserve user data\n'
