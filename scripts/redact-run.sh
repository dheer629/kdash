#!/usr/bin/env bash
# Redact environment-specific names from a validation run and from the samples.
#
# The names being removed live in a private mapping file, never in this
# repository: one "old<TAB>new" pair per line, longest source first (the script
# sorts by length itself). Every text file, every gzip-compressed capture and
# every file or directory name that carries one of the names is rewritten.
#
#   bash scripts/redact-run.sh --check --map /tmp/map.tsv artifacts samples README.md
#   bash scripts/redact-run.sh         --map /tmp/map.tsv artifacts samples README.md
#
# Then re-render the screenshots, because images carry the names in pixels and
# cannot be edited as text:
#
#   powershell -File scripts/render-cli-samples.ps1  -RunDirectory artifacts/<run>
#   powershell -File scripts/collect-html-samples.ps1 -RunDirectory artifacts/<run> -Screenshot
#   powershell -File scripts/make-sample-gallery.ps1 -RunDirectory artifacts/<run> \
#     -FeatureDirectory artifacts/feature-screens-<run>
#   bash scripts/update-checksums.sh
#
# What it does not change
#   * PNG screenshots (re-render them from the redacted captures)
#   * an audit hash chain: redaction changes bytes, so the chain of a redacted
#     audit log no longer verifies. Verify and record the result before redacting,
#     and state the redaction when publishing.
set -uo pipefail

MAP=""; CHECK=0; TARGETS=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --map)   MAP="${2:?}"; shift 2 ;;
    --check) CHECK=1; shift ;;
    -h|--help) sed -n '2,26p' "$0"; exit 0 ;;
    -*) printf 'unknown option: %s\n' "$1" >&2; exit 2 ;;
    *)  TARGETS+=("$1"); shift ;;
  esac
done
[ -n "$MAP" ] && [ -f "$MAP" ] || { printf 'a mapping file is required: --map FILE\n' >&2; exit 2; }
[ "${#TARGETS[@]}" -gt 0 ] || { printf 'give at least one file or directory\n' >&2; exit 2; }

PAIRS=()
while IFS= read -r line; do
  case "$line" in ''|'#'*) continue ;; esac
  PAIRS+=("$line")
done < <(awk -F'\t' 'NF>=2 { print length($1) "\t" $0 }' "$MAP" | sort -rn -k1,1 | cut -f2-)
FROM=(); TO=()
for p in "${PAIRS[@]}"; do FROM+=("${p%%$'\t'*}"); TO+=("${p#*$'\t'}"); done
[ "${#FROM[@]}" -gt 0 ] || { printf 'the mapping file has no usable pairs\n' >&2; exit 2; }

SED_SCRIPT="$(mktemp)"; PATTERN_FILE="$(mktemp)"
trap 'rm -f "$SED_SCRIPT" "$PATTERN_FILE"' EXIT
: > "$PATTERN_FILE"
for i in "${!FROM[@]}"; do
  # Escape the pattern (every regex metacharacter) and the replacement (backslash,
  # the delimiter and &). An unescaped "/" in a replacement makes the whole sed
  # script invalid, and an invalid script silently changes nothing.
  esc_from="$(printf '%s' "${FROM[$i]}" | sed 's/[][\\.^$*+?(){}|/]/\\&/g')"
  esc_to="$(printf '%s' "${TO[$i]}" | sed 's/[\\&/]/\\&/g')"
  printf 's/%s/%s/g\n' "$esc_from" "$esc_to" >> "$SED_SCRIPT"
  printf '%s\n' "${FROM[$i]}" >> "$PATTERN_FILE"
done
# refuse to touch anything with a broken rule set
if ! sed -f "$SED_SCRIPT" </dev/null >/dev/null 2>&1; then
  printf 'the generated rules are invalid - nothing was changed\n' >&2
  exit 3
fi

text=0; changed=0; gz=0; renamed=0; images=0
for target in "${TARGETS[@]}"; do
  [ -e "$target" ] || { printf 'skipping missing target: %s\n' "$target" >&2; continue; }
  while IFS= read -r -d '' f; do
    case "$f" in
      *.png)  images=$((images + 1)); continue ;;
      *.lock) continue ;;
      *.gz)
        gz=$((gz + 1))
        if [ "$CHECK" = 0 ]; then
          # never replace a capture unless the rewrite produced content
          tmp="$(mktemp)"
          if zcat -- "$f" | sed -f "$SED_SCRIPT" > "$tmp" && [ -s "$tmp" ]; then
            gzip -9 -n -c "$tmp" > "$f.new" && mv -- "$f.new" "$f"
          else
            printf 'left unchanged (rewrite failed): %s\n' "$f" >&2
          fi
          rm -f "$tmp"
        fi
        continue ;;
    esac
    text=$((text + 1))
    if grep -qF -f "$PATTERN_FILE" -- "$f" 2>/dev/null; then
      changed=$((changed + 1))
      [ "$CHECK" = 0 ] && sed -i -f "$SED_SCRIPT" -- "$f"
      printf '%s\n' "$f"
    fi
  done < <(find "$target" -type f -print0)
done

# names of files and directories, deepest first so a rename never invalidates a path
for target in "${TARGETS[@]}"; do
  [ -e "$target" ] || continue
  while IFS= read -r -d '' p; do
    base="$(basename -- "$p")"; new="$base"
    for i in "${!FROM[@]}"; do new="${new//${FROM[$i]}/${TO[$i]}}"; done
    if [ "$new" != "$base" ]; then
      renamed=$((renamed + 1))
      [ "$CHECK" = 0 ] && mv -n -- "$p" "$(dirname -- "$p")/$new"
    fi
  done < <(find "$target" -depth -print0)
done

printf '\n%s: %s text files scanned (%s contained a name), %s gzip captures, %s names renamed, %s images left for re-rendering\n' \
  "$([ "$CHECK" = 1 ] && printf 'check' || printf 'redacted')" "$text" "$changed" "$gz" "$renamed" "$images"
