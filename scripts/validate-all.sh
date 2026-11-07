#!/usr/bin/env bash
# Validate everything this repository publishes.
#
#   bash scripts/validate-all.sh
#
# Checks, in order:
#   1. Bash syntax of every shipped script
#   2. CLI, modules, installer, uninstaller and version synchronization
#   3. every fixture/integration test under tests/
#   4. every checksum in SHA256SUMS, samples/SHA256SUMS and samples/html/SHA256SUMS
#   5. historical evidence named by artifacts/latest-run.txt: status, failures, the
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
for f in scripts/*.py; do
  python3 -c 'import ast,sys; ast.parse(open(sys.argv[1], encoding="utf-8").read(), filename=sys.argv[1])' "$f" \
    && ok "syntax $f" || bad "syntax $f"
done
for f in scripts/*.mjs; do
  if command -v node >/dev/null 2>&1; then
    node --check "$f" && ok "syntax $f" || bad "syntax $f"
  else
    printf 'SKIP  JavaScript syntax %s (optional Node unavailable; browser evidence is verified below)\n' "$f"
  fi
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
if awk '
  /<<\047KDASH_UNINSTALL_EOF\047$/ { capture=1; starts++; next }
  capture && /^KDASH_UNINSTALL_EOF$/ { capture=0; ends++; next }
  capture { print }
  END { if (starts != 1 || ends != 1 || capture) exit 1 }
' kdash-bundle.sh > "$VALIDATE_TMP/uninstaller" &&
   cmp -s "$VALIDATE_TMP/uninstaller" kdash-uninstall.sh; then
  ok "kdash-bundle.sh embeds kdash-uninstall.sh byte for byte"
else
  bad "the installer uninstaller differs from kdash-uninstall.sh"
fi
if bash scripts/build.sh --check > "$VALIDATE_TMP/build-check" 2>&1; then
  ok "CLI, source modules, installer and versions are synchronized"
else
  bad "source/build synchronization"
  cat "$VALIDATE_TMP/build-check"
fi
version="$(sed -n 's/^KDASH_VERSION="\([^"]*\)"$/\1/p' kdash)"
if [ -n "$version" ] && grep -Fq "$version" README.md &&
   grep -Fq "## [$version]" CHANGELOG.md && grep -Fq "$version" RELEASES.md; then
  ok "current version $version documented in README, changelog and releases"
else
  bad "current version missing from release documentation"
fi

echo "=== 2. fixture and integration tests (no live cluster)"
for f in tests/*.sh; do
  if timeout --kill-after=5s "${KDASH_TEST_TIMEOUT:-180}s" bash "$f" > "$VALIDATE_TMP/test-output" 2>&1; then
    ok "$f: $(tail -1 "$VALIDATE_TMP/test-output")"
  else
    bad "$f"
    tail -10 "$VALIDATE_TMP/test-output"
  fi
done

echo "=== 3. checksums"
while IFS= read -r dir; do
  file=SHA256SUMS
  want=$(awk 'NF {n++} END {print n+0}' "$dir/$file" 2>/dev/null)
  if [ "${want:-0}" -gt 0 ] && (cd "$dir" && sha256sum -c "$file") > "$VALIDATE_TMP/checksums" 2>&1; then
    n=$(grep -c ': OK$' "$VALIDATE_TMP/checksums")
    [ "$n" = "$want" ] && ok "$dir/$file $n/$want" || bad "$dir/$file $n/$want verified"
  else
    bad "$dir/$file verification failed"
    [ ! -f "$VALIDATE_TMP/checksums" ] || tail -5 "$VALIDATE_TMP/checksums"
  fi
done < <(printf '.\n'; find samples -name SHA256SUMS -printf '%h\n' | sort)

echo "=== 4. historical recorded run (not validation of the current runtime)"
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
i=$(find samples -name '*.png' | wc -l); [ "$i" -ge 133 ] && ok "$i version-labelled screenshots (including 133 historical images)" || bad "$i screenshots; historical gallery incomplete"
h419=$(find samples/html419 -name '*.html' | wc -l)
c419=$(find samples/html419 -name '*.csv' | wc -l)
[ "$h419" = 10 ] && [ "$c419" = 1 ] && ok "html419: 10 report HTML, $c419 audit CSV" \
  || bad "html419: $h419 HTML, $c419 CSV"
h=$(find samples/html -name '*.html' | wc -l); [ "$h" = 33 ] && ok "33 HTML reports" || bad "$h HTML reports"
c=$(find samples/html -name '*.csv' | wc -l); [ "$c" = 3 ] && ok "3 audit CSVs" || bad "$c audit CSVs"
for f in samples/cli_7_alerts_170col.png samples/html_overview.png \
         samples/cli_413/01-pods.png samples/cli_413/08-services.png \
         samples/cli_413/09-storage.png samples/cli_413/10-events.png \
         samples/cli_413/12-doctor.png samples/cli_413/16-inspector-find.png \
         samples/cli_413/18-inspector-containers.png samples/cli_419/01-pods.png \
         samples/cli_419/07-alerts.png samples/cli_419/08-services.png \
         samples/cli_419/13-doctor.png samples/cli_419/17-inspector-find.png \
         samples/cli_419/18-inspector-only-matches.png samples/cli_419/24-attach-blocked.png \
         samples/cli_419/28-shell-inside.png samples/cli_419/30-download-prompt.png \
         samples/cli_419/33-pod-filter.png samples/cli_419/34-filters.png \
         samples/cli_419/43-html-menu.png samples/cli_419/44-html-report-written.png \
         samples/cli_419/46-session-summary.png samples/cli_419/49-snapshot-all.png \
         samples/cli_419/50-report-bundle.png samples/cli_419/51-audit-table.png \
         samples/cli_419/54-disclaimer-first-run.png; do
  [ -s "$f" ] && ok "present $f" || bad "missing $f"
done
FEATURE=artifacts/feature-screens-20261029-151233
if [ -d "$FEATURE" ]; then
  a=$(ls -1 "$FEATURE"/raw/*.ansi 2>/dev/null | wc -l)
  t=$(ls -1 "$FEATURE"/raw/*.txt 2>/dev/null | wc -l)
  m=$(awk 'NF {n++} END {print n+0}' "$FEATURE/captures.tsv" 2>/dev/null)
  [ "$a" = 22 ] && [ "$t" = 22 ] && [ "$m" = 23 ] \
    && ok "feature captures 22 pairs, $m manifest rows" \
    || bad "feature captures: $a ansi, $t txt, $m manifest rows"
else
  bad "no artifacts/feature-screens-* directory"
fi
ATTACH=$(find artifacts -maxdepth 1 -type d -name 'feature-screens-*-attach' 2>/dev/null | sort | tail -1)
if [ -n "$ATTACH" ]; then
  a=$(ls -1 "$ATTACH"/raw/*.ansi 2>/dev/null | wc -l)
  m=$(awk 'NF {n++} END {print n+0}' "$ATTACH/captures.tsv" 2>/dev/null)
  [ "$a" = 7 ] && [ "$m" = 8 ] && ok "attachment captures 7 pairs, $m manifest rows" \
    || bad "attachment captures: $a ansi, $m manifest rows"
else
  bad "no artifacts/feature-screens-*-attach directory"
fi
VIEWS=artifacts/view-screens-20261031-051739
if [ -d "$VIEWS" ]; then
  a=$(ls -1 "$VIEWS"/raw/*.ansi 2>/dev/null | wc -l)
  t=$(ls -1 "$VIEWS"/raw/*.txt 2>/dev/null | wc -l)
  m=$(awk 'NF {n++} END {print n+0}' "$VIEWS/captures.tsv" 2>/dev/null)
  [ "$a" = 31 ] && [ "$t" = 31 ] && [ "$m" = 32 ] \
    && ok "current-version captures 31 pairs, $m manifest rows" \
    || bad "current-version captures: $a ansi, $t txt, $m manifest rows"
  for s in 01-pods 13-doctor 17-inspector-find 18-inspector-only-matches \
           24-attach-blocked 28-shell-inside; do
    grep -q "raw/$s.ansi" "$VIEWS/captures.tsv" && ok "manifest lists $s" \
      || bad "manifest is missing $s"
  done
else
  bad "no artifacts/view-screens-* directory"
fi
OPS=artifacts/operation-screens-20261031-062953
if [ -d "$OPS" ]; then
  a=$(ls -1 "$OPS"/raw/*.ansi 2>/dev/null | wc -l)
  t=$(ls -1 "$OPS"/raw/*.txt 2>/dev/null | wc -l)
  m=$(awk 'NF {n++} END {print n+0}' "$OPS/captures.tsv" 2>/dev/null)
  [ "$a" = 24 ] && [ "$t" = 24 ] && [ "$m" = 25 ] \
    && ok "operation captures 24 pairs, $m manifest rows" \
    || bad "operation captures: $a ansi, $t txt, $m manifest rows"
  for s in 32-namespace-picker 34-filters 43-html-menu 44-html-report-written \
           46-session-summary 49-snapshot-all 51-audit-table 54-disclaimer-first-run; do
    grep -q "raw/$s.ansi" "$OPS/captures.tsv" && ok "manifest lists $s" \
      || bad "manifest is missing $s"
  done
  grep -q 'OK   audit HTML + CSV' "$OPS/run.log" 2>/dev/null \
    && ok "the run verified audit HTML + CSV" || bad "the run report lacks the audit check"
  grep -q 'chain intact' "$OPS/raw/52-audit-verify.txt" 2>/dev/null \
    && ok "the audit chain verified before redaction" || bad "no chain-intact evidence"
else
  bad "no artifacts/operation-screens-* directory"
fi

echo "=== 6. no environment, product, site or personal names"
# Inspect only files that can be published. Ignored private captures, downloaded
# developer tools and release staging directories are outside this check.
publication_paths() { git ls-files -z --cached --others --exclude-standard | sort -zu; }
# Galleries captured from a live local cluster keep that cluster's real namespace
# names (learnalgorithm, flux-system ...) on purpose, so they must be excluded from
# the name scan below. KEEP_PUBLIC lists the galleries that were published as the
# current capture of their release; add to it when a new gallery takes over, and
# redact the gallery only when the run itself is redacted.
KEEP_PUBLIC='cli_4232?|html4232?|cli_4241|html4241|cli_4273|html4273'
current_gallery_dirs() {
  local run png g1
  [ -f artifacts/latest-e2e.txt ] || return 0
  read -r run < artifacts/latest-e2e.txt || return 0
  [ -f "artifacts/$run/captures.tsv" ] || return 0
  png=$(awk -F '\t' 'NR==1 { for(i=1;i<=NF;i++) if($i=="png") col=i; next } col { print $col; exit }' "artifacts/$run/captures.tsv")
  [ -n "$png" ] || return 0
  g1="${png%/*}"
  printf '%s\n%s\n' "${g1#samples/}" "html${g1#samples/cli_}"
}
historical_paths() {
  local cur; cur="$(current_gallery_dirs | paste -sd'|' -)"
  publication_paths | grep -zvE "^(artifacts/live-e2e-|samples/(${KEEP_PUBLIC}${cur:+|$cur})/)"
}
hits=$(historical_paths | xargs -0 -r grep -lI --exclude='validate-all.sh' \
  -e kubernetes-super-admin -e devopssentinel -e learnalgorithm -e flux-system -e devopsonm \
  -e pny9 -e sjy9 -e ecev -e etdp -e ETDP -e sentinel -e Sentinel -e 'director host' \
  -e 'ccd/nodepool' -e '/home/dheer' -e 'Users/dheer' -e 'dheer@' 2>/dev/null | head -3)
[ -z "$hits" ] && ok "historical samples retain their documented redaction" || bad "found in: $hits"
# Current live evidence intentionally preserves actual local namespace names.
# Personal home paths and credentials are still checked in every published set.
personal=$(publication_paths | xargs -0 -r grep -lI --exclude='validate-all.sh' \
  -e '/home/dheer' -e 'Users/dheer' -e 'dheer@' 2>/dev/null | head -3)
[ -z "$personal" ] && ok "no personal home paths in published data" || bad "personal path in: $personal"
n=$(historical_paths | xargs -0 -r grep -nI --exclude='validate-all.sh' -e Dheeraj 2>/dev/null | grep -vc 'Dheeraj V')
[ "$n" = 0 ] && ok "the author credit is the only name reference" || bad "$n unexpected name references"
# A jsonpath selector such as {.users[0].user.client-certificate-data} names a
# kubeconfig field; it is not credential data. A selector closes the field name
# with "}", so those lines are not matches.
creds=$(publication_paths | grep -zvE '^\.github/' | xargs -0 -r grep -nIiE \
  'client-key-data|client-certificate-data|BEGIN [A-Z ]*PRIVATE KEY|^[[:space:]]*password[[:space:]]*[:=]|bearer [A-Za-z0-9._-]{20,}' \
  --exclude='validate-all.sh' 2>/dev/null | grep -vE 'client-(key|certificate)-data\}' | cut -d: -f1 | sort -u | head -3)
[ -z "$creds" ] && ok "no credential-looking strings" || bad "credential-looking content in: $creds"

echo "=== 7. README references"
if python3 scripts/validate-publication.py > "$VALIDATE_TMP/publication" 2>&1; then
  cat "$VALIDATE_TMP/publication"
  ok "all README references and current live evidence provenance"
else
  cat "$VALIDATE_TMP/publication"
  bad "README references or current live evidence provenance"
fi
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
for v in 4.14.0 4.13.1 4.13.0; do
  for asset in kdash kdash-bundle.sh "kdash-$v.tar.gz" SHA256SUMS; do
    grep -q "releases/download/v$v/$asset" README.md || { vbad=$((vbad + 1)); echo "   missing link: v$v/$asset"; }
  done
  grep -q "^| \*\*$v\*\* |" README.md && vers=$((vers + 1))
done
[ "$vbad" = 0 ] && ok "direct download links for 4.14.0, 4.13.1 and 4.13.0" || bad "$vbad download links missing"
[ "$vers" = 3 ] && ok "the release table lists all three versions" || bad "release table lists $vers of 3 versions"
grep -q 'archive/refs/tags/v4.12.0.tar.gz' README.md && ok "the older version stays reachable" || bad "no link for 4.12.0"
grep -q 'releases/download/v4.14.0/kdash-4.14.0.tar.gz' README.md && grep -q 'RELEASES.md' README.md \
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
