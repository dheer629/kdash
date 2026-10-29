#!/usr/bin/env bash
# Validate everything this repository publishes.
#
#   bash scripts/validate-all.sh
#
# Checks, in order:
#   1. Bash syntax of every shipped script
#   2. the installer embeds kdash byte for byte
#   3. every fixture/integration test under tests/
#   4. every checksum in SHA256SUMS, samples/SHA256SUMS and samples/html/SHA256SUMS
#   5. the recorded run named by artifacts/latest-run.txt: status, failures, the
#      seven captures per namespace and the exit status of each namespace
#   6. the published samples: counts and a few files that must exist
#   7. no environment, product, site or personal names in the tree (the author's
#      own credit in the README and the tool is the one allowed reference)
#   8. every image and link the README points at exists
#   9. the working tree is clean and, when a matching remote branch exists,
#      that branch matches this checkout (detached/tag checkouts skip this)
#
# Exit status 0 means every check passed. CI runs the same script.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1
shopt -s nullglob
VALIDATE_TMP="$(mktemp -d "${TMPDIR:-/tmp}/kdash-validate.XXXXXXXX")" || exit 1
validate_cleanup() {
  case "$VALIDATE_TMP" in "${TMPDIR:-/tmp}"/kdash-validate.*) rm -rf -- "$VALIDATE_TMP" ;; esac
}
trap validate_cleanup EXIT

fail=0
ok()  { printf 'PASS  %s\n' "$*"; }
bad() { printf 'FAIL  %s\n' "$*"; fail=$((fail + 1)); }

echo "=== 1. Bash syntax and installer payload"
for f in kdash kdash-bundle.sh kdash-uninstall.sh src/*.sh tests/*.sh; do
  bash -n "$f" 2>/dev/null && ok "syntax $f" || bad "syntax $f"
done
for f in scripts/*.sh; do
  case "$f" in scripts/_*) continue ;; esac
  bash -n "$f" 2>/dev/null && ok "syntax $f" || bad "syntax $f"
done
if awk '
  /^cat > "\$tmp" <<\047KDASH_PAYLOAD_EOF\047$/ { capture=1; starts++; next }
  capture && /^KDASH_PAYLOAD_EOF$/ { capture=0; ends++; next }
  capture { print }
  END { if (starts != 1 || ends != 1 || capture) exit 1 }
' kdash-bundle.sh > "$VALIDATE_TMP/payload" &&
   cmp -s "$VALIDATE_TMP/payload" kdash; then
  ok "kdash-bundle.sh embeds kdash byte for byte"
else
  bad "the installer payload differs from kdash"
fi
echo "=== 2. fixture and integration tests (no live cluster)"
for f in tests/*.sh; do
  if bash "$f" > "$VALIDATE_TMP/test-output" 2>&1; then
    ok "$f: $(tail -1 "$VALIDATE_TMP/test-output")"
  else
    bad "$f"
    tail -10 "$VALIDATE_TMP/test-output"
  fi
done

echo "=== 3. checksums"
for dir in . samples samples/html samples/cli_413; do
  file=SHA256SUMS
  want=$(awk 'NF {n++} END {print n+0}' "$dir/$file" 2>/dev/null)
  if [ "${want:-0}" -gt 0 ] && (cd "$dir" && sha256sum -c "$file") > "$VALIDATE_TMP/checksums" 2>&1; then
    n=$(grep -c ': OK$' "$VALIDATE_TMP/checksums")
    [ "$n" = "$want" ] && ok "$dir/$file $n/$want" || bad "$dir/$file $n/$want verified"
  else
    bad "$dir/$file verification failed"
    [ ! -f "$VALIDATE_TMP/checksums" ] || tail -5 "$VALIDATE_TMP/checksums"
  fi
done

echo "=== 4. the recorded run"
RUN="$(cat artifacts/latest-run.txt 2>/dev/null || true)"
if [ -n "$RUN" ] && [ -d "artifacts/$RUN" ]; then
  ok "latest run $RUN"
  [ "$(cat "artifacts/$RUN/status.txt" 2>/dev/null)" = DONE ] \
    && ok "run status DONE" || bad "run status: $(cat "artifacts/$RUN/status.txt" 2>/dev/null)"
  grep -q '"failures": \[\]' "artifacts/$RUN/run-metadata.json" 2>/dev/null \
    && ok "no failures recorded" || bad "the run recorded failures"
  for ns in $(sed -n 's/^  "namespaces": \[\(.*\)\],$/\1/p' "artifacts/$RUN/run-metadata.json" | tr -d '"' | tr ',' ' '); do
    c=$(ls -1 "artifacts/$RUN/$ns/cli"/*.ansi 2>/dev/null | wc -l)
    [ "$c" = 7 ] && ok "7 CLI captures for $ns" || bad "$c CLI captures for $ns"
    [ "$(cat "artifacts/$RUN/$ns/exit-status.txt" 2>/dev/null)" = 0 ] \
      && ok "$ns exited 0" || bad "$ns exit status: $(cat "artifacts/$RUN/$ns/exit-status.txt" 2>/dev/null)"
  done
else
  bad "artifacts/latest-run.txt does not name an existing run"
fi

echo "=== 5. the published samples"
i=$(find samples -name '*.png' | wc -l); [ "$i" = 69 ] && ok "69 screenshots" || bad "$i screenshots"
h=$(find samples/html -name '*.html' | wc -l); [ "$h" = 33 ] && ok "33 HTML reports" || bad "$h HTML reports"
c=$(find samples/html -name '*.csv' | wc -l); [ "$c" = 3 ] && ok "3 audit CSVs" || bad "$c audit CSVs"
for f in samples/cli_7_alerts_170col.png samples/html_overview.png \
         samples/cli_413/01-pods.png samples/cli_413/08-services.png \
         samples/cli_413/09-storage.png samples/cli_413/10-events.png \
         samples/cli_413/12-doctor.png samples/cli_413/16-inspector-find.png \
         samples/cli_413/18-inspector-containers.png; do
  [ -s "$f" ] && ok "present $f" || bad "missing $f"
done
FEATURE=$(ls -d artifacts/feature-screens-* 2>/dev/null | tail -1)
if [ -n "$FEATURE" ]; then
  a=$(ls -1 "$FEATURE"/raw/*.ansi 2>/dev/null | wc -l)
  t=$(ls -1 "$FEATURE"/raw/*.txt 2>/dev/null | wc -l)
  m=$(awk 'NF {n++} END {print n+0}' "$FEATURE/captures.tsv" 2>/dev/null)
  [ "$a" = 22 ] && [ "$t" = 22 ] && [ "$m" = 23 ] \
    && ok "feature captures 22 pairs, $m manifest rows" \
    || bad "feature captures: $a ansi, $t txt, $m manifest rows"
else
  bad "no artifacts/feature-screens-* directory"
fi

echo "=== 6. no environment, product, site or personal names"
hits=$(grep -rlI --exclude-dir=.git --exclude='_*' --exclude='validate-all.sh' \
  -e kubernetes-super-admin -e devopssentinel -e learnalgorithm -e flux-system -e devopsonm \
  -e pny9 -e sjy9 -e ecev -e etdp -e ETDP -e sentinel -e Sentinel -e 'director host' \
  -e 'ccd/nodepool' -e '/home/dheer' -e 'Users/dheer' -e 'dheer@' . 2>/dev/null | head -3)
[ -z "$hits" ] && ok "no environment, product or personal names" || bad "found in: $hits"
n=$(grep -rnI --exclude-dir=.git --exclude='_*' -e Dheeraj . 2>/dev/null | grep -vc 'Dheeraj V')
[ "$n" = 0 ] && ok "the author credit is the only name reference" || bad "$n unexpected name references"
creds=$(grep -rniE 'client-key-data|client-certificate-data|BEGIN [A-Z ]*PRIVATE KEY|^[[:space:]]*password[[:space:]]*[:=]|bearer [A-Za-z0-9._-]{20,}' \
  --exclude-dir=.git --exclude-dir=.github --exclude='validate-all.sh' . 2>/dev/null | head -3)
[ -z "$creds" ] && ok "no credential-looking strings" || bad "credential-looking string: $creds"

echo "=== 7. README references"
refs=0; missing=0
while IFS= read -r p; do
  case "$p" in ''|http*|mailto:*) continue ;; esac
  refs=$((refs + 1))
  [ -e "$p" ] || { missing=$((missing + 1)); echo "   missing: $p"; }
done < <({ grep -o 'src="[^"]*"' README.md | sed 's/^src="//; s/"$//'
           grep -o '](\([^)]*\))' README.md | sed 's/^](//; s/)$//'; } | sed 's/#.*$//' | sort -u)
[ "$missing" = 0 ] && ok "all $refs README references resolve" || bad "$missing of $refs README references missing"

echo "=== 7b. versioned downloads in the README"
vbad=0; vers=0
for v in 4.13.1 4.13.0; do
  for asset in kdash kdash-bundle.sh "kdash-$v.tar.gz" SHA256SUMS; do
    grep -q "releases/download/v$v/$asset" README.md || { vbad=$((vbad + 1)); echo "   missing link: v$v/$asset"; }
  done
  grep -q "^| \*\*$v\*\* |" README.md && vers=$((vers + 1))
done
[ "$vbad" = 0 ] && ok "direct download links for 4.13.1 and 4.13.0" || bad "$vbad download links missing"
[ "$vers" = 2 ] && ok "the release table lists both versions" || bad "release table lists $vers of 2 versions"
grep -q 'archive/refs/tags/v4.12.0.tar.gz' README.md && ok "the older version stays reachable" || bad "no link for 4.12.0"
grep -q 'releases/download/v4.13.1/kdash-4.13.1.tar.gz' README.md && grep -q 'RELEASES.md' README.md \
  && ok "install-one-version recipe documented" || bad "no one-version install recipe"

echo "=== 8. git state"
d=$(git status --porcelain 2>/dev/null | wc -l)
if [ "$d" = 0 ]; then
  ok "working tree clean"
elif [ "${KDASH_VALIDATE_ALLOW_DIRTY:-0}" = 1 ]; then
  printf 'SKIP  clean working tree requirement explicitly disabled (%s changes)\n' "$d"
else
  bad "$d uncommitted change(s)"; git status --short | head -10
fi
ok "HEAD $(git log --oneline -1)"
branch=$(git symbolic-ref --quiet --short HEAD 2>/dev/null || true)
if [ -z "$branch" ]; then
  printf 'SKIP  remote branch comparison (detached or tag checkout)\n'
elif r=$(git ls-remote --exit-code origin "refs/heads/$branch" 2>/dev/null | cut -f1) && [ -n "$r" ]; then
  l=$(git rev-parse HEAD)
  [ "$r" = "$l" ] && ok "remote branch $branch matches this checkout ($l)" || bad "remote branch $branch $r differs from local $l"
else
  printf 'SKIP  remote branch absent or unreachable (%s)\n' "$branch"
fi

echo
if [ "$fail" = 0 ]; then echo "ALL CHECKS PASSED"; else echo "$fail CHECK(S) FAILED"; fi
exit "$fail"
