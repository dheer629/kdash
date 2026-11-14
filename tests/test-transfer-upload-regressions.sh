#!/usr/bin/env bash
# Exercise real upload tar streams and post-copy verification against a private
# local receiver. Only Kubernetes transport and terminal selection are injected.
set -euo pipefail
REPO="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
source "$REPO/src/inspector.sh"
source "$REPO/src/interactive.sh"
UPLOAD_TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/kdash-upload-tests.XXXXXXXX")"
trap 'rm -rf -- "$UPLOAD_TEST_ROOT"' EXIT
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
eval "$(declare -f xfer_up_pipe | sed '1s/xfer_up_pipe/upload_real_pipe/')"

run_upload_case() (
    local mode="$1" rc=0
    local fixture="$UPLOAD_TEST_ROOT/$mode"
    mkdir -p "$fixture/source/tree/empty dir" "$fixture/source/tree/nested dir" "$fixture/dest"
    printf ORIGINAL > "$fixture/source/first file.txt"
    printf SECOND > "$fixture/source/second.txt"
    printf NESTED > "$fixture/source/tree/nested dir/data.txt"
    ln -s 'nested dir/data.txt' "$fixture/source/tree/link"
    TMPD="$fixture/tmp"; mkdir -p "$TMPD"
    CTX_NAME=fixture; NS=demo; COLOR=0; BARCHR=ascii; picker_colors
    AUDIT_LOG="$fixture/audit.log"
    audit() { printf '%s\t%s\n' "$1" "${2:-}" >> "$AUDIT_LOG"; }
    xfer_browse() {
        if [ "$1" = local ]; then
            XFER_DIR="$fixture/source"
            XFER_SEL=('first file.txt' second.txt tree)
            XFER_SELT=(f f d); XFER_SELS=(8 6 -)
        else XFER_DIR="$fixture/dest"; fi
    }
    xfer_upload_summary() { XP_TOOLS=' tar sha256sum '; return 0; }
    xfer_run_bg() { shift 3; "$@"; }
    sh() {
        local sh_rc=0
        command sh "$@" || sh_rc=$?
        if [ "$mode" = failed-local-sum ] && [ "${2:-}" = "$XFER_SUM_SH" ] && [ "${5:-}" = "$fixture/source" ]; then return 76; fi
        return "$sh_rc"
    }
    xfer_up_pipe() {
        upload_real_pipe || return $?
        case "$mode" in
            corrupt) printf 'CORRUPT!' > "$fixture/dest/first file.txt" ;;
            symlink) rm "$fixture/dest/tree/link"; ln -s second.txt "$fixture/dest/tree/link" ;;
            empty-dir) rmdir "$fixture/dest/tree/empty dir" ;;
        esac
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
    xfer_result_box() { printf 'RESULT identical=%s differ=%s\n' "$XV_OK" "$XV_BAD"; }
    read() { if [ "${1:-}" = -rsn1 ]; then return 1; else builtin read "$@"; fi; }
    xfer_upload_once demo api app > "$fixture/result.log" 2> "$fixture/error.log" || rc=$?
    if [ "$mode" = valid ]; then
        [ "$rc" = 0 ] || fail "valid upload returned $rc"
        grep -q 'RESULT identical=3 differ=0' "$fixture/result.log" || fail 'valid upload did not verify all selected items'
        cmp "$fixture/source/first file.txt" "$fixture/dest/first file.txt" || fail 'upload changed file data'
        [ "$(readlink "$fixture/dest/tree/link")" = 'nested dir/data.txt' ] || fail 'upload changed symlink target'
        [ -d "$fixture/dest/tree/empty dir" ] || fail 'upload lost empty directory'
        grep -Eq '^CP_END.*rc=0 identical=3 differ=0' "$AUDIT_LOG" || fail 'valid upload audit is missing success'
    else
        [ "$rc" != 0 ] || fail "$mode verification returned upload success"
        if grep -Eq '^CP_END.*rc=0([[:space:]]|$)' "$AUDIT_LOG"; then fail "$mode verification audit reported success"; fi
    fi
)

run_pipeline_case() (
    local mode="$1" rc=0
    local fixture="$UPLOAD_TEST_ROOT/pipe-$mode"
    mkdir -p "$fixture/source" "$fixture/dest" "$fixture/tmp"
    printf stream-data > "$fixture/source/file.txt"
    local lsrc="$fixture/source" dst="$fixture/dest" d="$fixture/tmp" ns=demo pod=api c=app
    local -a items=(file.txt)
    fake_exec() { while [ "$#" -gt 0 ] && [ "$1" != -- ]; do shift; done; shift; "$@"; }
    KC=(fake_exec)
    if [ "$mode" = tee ]; then
        tee() { command tee "$@"; return 73; }
    else
        tar() { command tar "$@"; return 74; }
    fi
    upload_real_pipe || rc=$?
    [ "$rc" != 0 ] || fail "failed $mode stage returned transport success"
)

run_no_stat_case() (
    local fixture="$UPLOAD_TEST_ROOT/no-stat" tool mode hash_tool
    mkdir -p "$fixture/tools"
    ln "$UPLOAD_TEST_ROOT/valid/source/tree/nested dir/data.txt" "$UPLOAD_TEST_ROOT/valid/source/tree/hardlink"
    ln "$UPLOAD_TEST_ROOT/valid/dest/tree/nested dir/data.txt" "$UPLOAD_TEST_ROOT/valid/dest/tree/hardlink"
    /bin/sh -c "$XFER_SUM_SH" kdash sha256 "$UPLOAD_TEST_ROOT/valid/source" tree > "$fixture/baseline.sum" || fail 'standard fingerprint failed'
    for tool in find sort sha256sum cut wc tr cat readlink; do
        ln -s "$(command -v "$tool")" "$fixture/tools/$tool"
    done
    for mode in absent broken; do
        if [ "$mode" = broken ]; then
            printf '#!/bin/sh\nexit 2\n' > "$fixture/tools/stat"
            chmod +x "$fixture/tools/stat"
        fi
        PATH="$fixture/tools" /bin/sh -c "$XFER_SUM_SH" kdash sha256 "$UPLOAD_TEST_ROOT/valid/source" tree > "$fixture/source.sum" || fail "fingerprint fallback failed with $mode stat"
        PATH="$fixture/tools" /bin/sh -c "$XFER_SUM_SH" kdash sha256 "$UPLOAD_TEST_ROOT/valid/dest" tree > "$fixture/dest.sum" || fail "destination fingerprint fallback failed with $mode stat"
        cmp "$fixture/baseline.sum" "$fixture/source.sum" || fail "fallback differs from standard fingerprint with $mode stat"
        cmp "$fixture/source.sum" "$fixture/dest.sum" || fail "source and destination fingerprints differ with $mode stat"
    done
    # A checksum tool can produce a plausible digest before returning an error.
    # That digest must never make a read failure look like a verified upload.
    hash_tool="$(command -v sha256sum)"
    rm "$fixture/tools/sha256sum"
    printf '#!/bin/sh\n"%s" "$@"\nexit 79\n' "$hash_tool" > "$fixture/tools/sha256sum"
    chmod +x "$fixture/tools/sha256sum"
    if PATH="$fixture/tools" /bin/sh -c "$XFER_SUM_SH" kdash sha256 "$UPLOAD_TEST_ROOT/valid/source" tree > "$fixture/failed.sum"; then
        fail 'checksum tool failure was hidden by its digest output'
    fi
)

upload_failures=0
for mode in valid corrupt symlink empty-dir missing partial no-alg failed-sum failed-local-sum; do
    if ! run_upload_case "$mode"; then upload_failures=$((upload_failures + 1)); fi
done
for mode in tee tar; do
    if ! run_pipeline_case "$mode"; then upload_failures=$((upload_failures + 1)); fi
done
if ! run_no_stat_case; then upload_failures=$((upload_failures + 1)); fi
[ "$upload_failures" = 0 ] || fail "$upload_failures upload regression case(s) failed"
printf 'PASS: uploads preserve files, links and empty directories; corruption, incomplete verification and failed stream stages return failure\n'
