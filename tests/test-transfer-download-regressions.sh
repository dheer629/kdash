#!/usr/bin/env bash
# Run the download's real tar and verification paths against private local files.
# Kubernetes and terminal input are injected; existing destinations stay inspectable.
set -euo pipefail
REPO="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
source "$REPO/src/inspector.sh"
source "$REPO/src/interactive.sh"
DOWNLOAD_TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/kdash-download-tests.XXXXXXXX")"
trap 'rm -rf -- "$DOWNLOAD_TEST_ROOT"' EXIT
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
eval "$(declare -f xfer_down_pipe | sed '1s/xfer_down_pipe/download_real_pipe/')"
# Replace only the terminal input boundary, so CI needs no controlling terminal.
eval "$(declare -f xfer_download_once | sed 's@/dev/tty@/dev/null@g')"

run_download_case() (
    local mode="$1" rc=0 fixture="$DOWNLOAD_TEST_ROOT/$1"
    mkdir -p "$fixture/source/tree/empty dir" "$fixture/source/tree/nested dir" "$fixture/out" "$fixture/tmp"
    printf ORIGINAL > "$fixture/source/first file.txt"
    printf NESTED > "$fixture/source/tree/nested dir/data.txt"
    ln -s 'nested dir/data.txt' "$fixture/source/tree/link"
    if [ "$mode" != valid ]; then
        printf EXISTING > "$fixture/out/first file.txt"
        mkdir "$fixture/out/tree"
        printf KEEP > "$fixture/out/tree/old.txt"
    fi
    TMPD="$fixture/tmp"; KDASH_LAUNCH_DIR="$fixture/out"
    CTX_NAME=fixture; NS=demo; COLOR=0; BARCHR=ascii; picker_colors
    AUDIT_LOG="$fixture/audit.log"
    audit() { printf '%s\t%s\n' "$1" "${2:-}" >> "$AUDIT_LOG"; }
    xfer_browse() {
        XFER_DIR="$fixture/source"; XFER_SEL=('first file.txt' tree)
        XFER_SELT=(f d); XFER_SELS=(8 -)
    }
    xfer_run_bg() { shift 3; "$@"; }
    xfer_down_pipe() {
        download_real_pipe || return $?
        [ "$mode" != corrupt ] || printf 'CORRUPT!' > "$fixture/source/first file.txt"
        return 0
    }
    fake_exec() {
        while [ "$#" -gt 0 ] && [ "$1" != -- ]; do shift; done
        [ "$#" -gt 0 ] || return 90
        shift
        if [ "${3:-}" = "$XFER_SUM_SH" ]; then
            case "$mode" in
                missing) printf 'ALG\tsha256\n'; return 0 ;;
                partial) "$@" | head -n 2; return 0 ;;
                no-alg) "$@" | sed '/^ALG/d'; return 0 ;;
                failed-sum) "$@"; return 77 ;;
            esac
        fi
        "$@"
    }
    KC=(fake_exec)
    picker_size() { PK_COLS=100; PK_ROWS=32; }
    xfer_review_box() { :; }
    xfer_result_box() { printf 'RESULT identical=%s differ=%s\n' "$XV_OK" "$XV_BAD"; }
    local key_index=0
    read() {
        if [ "${1:-}" = -rsn1 ]; then
            local target="${@: -1}" key=x
            case "$key_index" in 0) key=y ;; 1) [ "$mode" = keep ] && key=k || key=r ;; esac
            key_index=$((key_index + 1))
            printf -v "$target" '%s' "$key"
            return 0
        fi
        builtin read "$@"
    }
    xfer_download_once demo api app > "$fixture/result.log" 2> "$fixture/error.log" || rc=$?
    case "$mode" in
        valid|replace|keep)
            [ "$rc" = 0 ] || fail "$mode download returned $rc"
            grep -q 'RESULT identical=2 differ=0' "$fixture/result.log" || fail "$mode download did not verify every selected item"
            local copied_file='first file.txt' copied_tree=tree
            if [ "$mode" = keep ]; then
                copied_file='first file (2).txt'; copied_tree='tree (2)'
                [ "$(cat "$fixture/out/first file.txt")" = EXISTING ] || fail 'keep both replaced existing file'
                [ "$(cat "$fixture/out/tree/old.txt")" = KEEP ] || fail 'keep both replaced existing directory'
            fi
            cmp "$fixture/source/first file.txt" "$fixture/out/$copied_file" || fail "$mode download changed file content"
            cmp "$fixture/source/tree/nested dir/data.txt" "$fixture/out/$copied_tree/nested dir/data.txt" || fail "$mode download changed nested content"
            [ -d "$fixture/out/$copied_tree/empty dir" ] || fail "$mode download lost empty directory"
            [ "$(readlink "$fixture/out/$copied_tree/link")" = 'nested dir/data.txt' ] || fail "$mode download changed symlink target"
            [ "$mode" != replace ] || [ ! -e "$fixture/out/tree/old.txt" ] || fail 'replace merged stale destination entries'
            grep -Eq '^CP_END.*rc=0.*identical=2 differ=0' "$AUDIT_LOG" || fail "$mode download audit omitted successful verification"
            ;;
        *)
            [ "$rc" != 0 ] || fail "$mode verification returned download success"
            [ "$(cat "$fixture/out/first file.txt")" = EXISTING ] || fail "$mode verification replaced existing file"
            [ "$(cat "$fixture/out/tree/old.txt")" = KEEP ] || fail "$mode verification replaced existing directory"
            if grep -Eq '^CP_END.*rc=0([[:space:]]|$)' "$AUDIT_LOG"; then fail "$mode verification audit reported success"; fi
            ;;
    esac
    if compgen -G "$fixture/out/.kdash-*" >/dev/null; then fail "$mode download left partial data or staging directory"; fi
)

check_hardlink_cache() (
    local fixture="$DOWNLOAD_TEST_ROOT/hardlinks" n
    mkdir -p "$fixture/source/tree" "$fixture/dest" "$fixture/bin"
    printf 'one inode shared by twelve regular files' > "$fixture/source/tree/original"
    for n in {1..11}; do ln "$fixture/source/tree/original" "$fixture/source/tree/copy-$n"; done
    cp -R "$fixture/source/tree" "$fixture/dest/tree"
    export HASH_COUNT_FILE="$fixture/hash-calls" REAL_SHA256SUM
    REAL_SHA256SUM="$(command -v sha256sum)"
    cat > "$fixture/bin/sha256sum" <<'SH'
#!/bin/sh
printf 'hash\n' >> "$HASH_COUNT_FILE"
exec "$REAL_SHA256SUM" "$@"
SH
    chmod +x "$fixture/bin/sha256sum"
    : > "$HASH_COUNT_FILE"
    PATH="$fixture/bin:$PATH" sh -c "$XFER_SUM_SH" kdash sha256 "$fixture/source" tree > "$fixture/source.sum"
    # One digest for the shared data and one digest for the sorted manifest.
    [ "$(wc -l < "$HASH_COUNT_FILE")" = 2 ] || fail 'directory verification repeatedly hashed one hardlinked inode'
    sh -c "$XFER_SUM_SH" kdash sha256 "$fixture/dest" tree > "$fixture/dest.sum"
    cmp "$fixture/source.sum" "$fixture/dest.sum" || fail 'hardlink cache changed the fingerprint of independent destination copies'
)

download_failures=0
for mode in valid replace keep corrupt missing partial no-alg failed-sum; do
    if ! run_download_case "$mode"; then download_failures=$((download_failures + 1)); fi
done
if ! check_hardlink_cache; then download_failures=$((download_failures + 1)); fi
[ "$download_failures" = 0 ] || fail "$download_failures download regression case(s) failed"
printf 'PASS: downloads verify before replacing destinations; keep both and hardlink caching preserve data; failed or incomplete verification leaves no partial files\n'
