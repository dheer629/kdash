#!/usr/bin/env bash
# Validate everything this repository publishes.
#
#   bash scripts/validate-all.sh
#
# Checks, in order:
#   1. Bash syntax of every shipped script
#   2. the installer embeds kdash byte for byte
#   3. the uninstall integration tests
#   4. every checksum in SHA256SUMS, samples/SHA256SUMS and samples/html/SHA256SUMS
#   5. the recorded run named by artifacts/latest-run.txt: status, failures, the
#      seven captures per namespace and the exit status of each namespace
#   6. the published samples: counts and a few files that must exist
#   7. no environment, product, site or personal names in the tree (the author's
#      own credit in the README and the tool is the one allowed reference)
#   8. every image and link the README points at exists
#   9. the working tree is clean and, when a remote is reachable, GitHub's main
#      matches this checkout
#
# Exit status 0 means every check passed. CI runs the same script.
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1

fail=0
ok()  { printf 'PASS  %s\n' "$*"; }
bad() { printf 'FAIL  %s\n' "$*"; fail=$((fail + 1)); }

echo "=== 1. Bash syntax and installer payload"
for f in kdash kdash-bundle.sh kdash-uninstall.sh tests/*.sh; do
  bash -n "$f" 2>/dev/null && ok "syntax $f" || bad "syntax $f"
done
for f in scripts/*.sh; do
  case "$f" in scripts/_*) continue ;; esac
  bash -n "$f" 2>/dev/null && ok "syntax $f" || bad "syntax $f"
done
if sed -n '347,5894p' kdash-bundle.sh > /tmp/kdash-payload.$$ 2>/dev/null &&
   cmp -s /tmp/kdash-payload.$$ kdash; then
  ok "kdash-bundle.sh embeds kdash byte for byte"
else
  bad "the installer payload differs from kdash"
fi
rm -f /tmp/kdash-payload.$$

echo "=== 2. uninstall integration tests"
if bash tests/test-uninstall.sh > /tmp/kdash-tests.$$ 2>&1; then
  ok "$(tail -1 /tmp/kdash-tests.$$)"
else
  bad "uninstall integration tests"
  tail -5 /tmp/kdash-tests.$$
fi
rm -f /tmp/kdash-tests.$$

echo "=== 3. checksums"
for pair in ".:SHA256SUMS:31" "samples:SHA256SUMS:17" "samples/html:SHA256SUMS:36"; do
  dir="${pair%%:*}"; rest="${pair#*:}"; file="${rest%%:*}"; want="${rest##*:}"
  n=$(cd "$dir" && sha256sum -c "$file" 2>/dev/null | grep -c ': OK$')
  [ "$n" = "$want" ] && ok "$dir/$file $n/$want" || bad "$dir/$file $n/$want verified"
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
i=$(find samples -name '*.png' | wc -l); [ "$i" = 47 ] && ok "47 screenshots" || bad "$i screenshots"
h=$(find samples/html -name '*.html' | wc -l); [ "$h" = 33 ] && ok "33 HTML reports" || bad "$h HTML reports"
c=$(find samples/html -name '*.csv' | wc -l); [ "$c" = 3 ] && ok "3 audit CSVs" || bad "$c audit CSVs"
for f in samples/cli_7_alerts_170col.png samples/html_overview.png; do
  [ -s "$f" ] && ok "present $f" || bad "missing $f"
done

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

echo "=== 8. git state"
d=$(git status --porcelain 2>/dev/null | wc -l)
[ "$d" = 0 ] && ok "working tree clean" || { bad "$d uncommitted change(s)"; git status --short | head -10; }
ok "HEAD $(git log --oneline -1)"
if r=$(git ls-remote origin refs/heads/main 2>/dev/null | cut -f1) && [ -n "$r" ]; then
  l=$(git rev-parse HEAD)
  [ "$r" = "$l" ] && ok "GitHub main matches this checkout ($l)" || bad "GitHub main $r differs from local $l"
else
  printf 'SKIP  remote not reachable (offline checkout)\n'
fi

echo
if [ "$fail" = 0 ]; then echo "ALL CHECKS PASSED"; else echo "$fail CHECK(S) FAILED"; fi
exit "$fail"
