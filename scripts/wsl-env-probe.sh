#!/usr/bin/env bash
# Read-only environment inventory for the kdash WSL Ubuntu validation workflow.
# Run from Windows: wsl -d Ubuntu -- bash "/mnt/c/.../scripts/wsl-env-probe.sh"
# It reads versions, paths, contexts and namespace names only. It never installs,
# removes or changes anything, and it prints no credentials.
set -uo pipefail

REPO="${KDASH_REPO:-/workspace/kdash}"
CTX="${KDASH_PROBE_CONTEXT:-devops-admin@local-cluster}"

echo "== date"; date -Is
echo "== uname"; uname -srmo
echo "== id"; id
echo "== bash"; bash --version | head -n 1
echo "== tools"
for tool in kubectl awk gawk mawk tmux python3 pip3 curl sha256sum flock timeout stdbuf script tput less; do
  printf '%s: ' "$tool"
  command -v "$tool" || echo MISSING
done
echo "== python modules"
python3 -c 'import pyte, PIL; print("pyte", pyte.__version__, "pillow", PIL.__version__)' 2>&1 | tail -n 2
echo "== passwordless sudo"
sudo -n true 2>&1; echo "rc=$?"
echo "== apt candidates (python3-pyte / python3-pil)"
apt-cache policy python3-pyte python3-pil 2>&1 | grep -E 'python3-(pyte|pil)|Installed|Candidate' || echo 'apt-cache unavailable'
echo "== kdash resolution"
type -a kdash 2>&1
echo "== kdash version"
kdash --version 2>&1 | head -n 3
echo "== kdash installed files"
ls -l "$HOME/.local/bin/kdash" /usr/local/bin/kdash "$HOME/.kdash-shell.bash" "$HOME/.kdash-completion.bash" 2>&1
echo "== kubectl contexts"
kubectl config get-contexts 2>&1
echo "== nodes"
kubectl --context "$CTX" get nodes -o wide 2>&1 | head -n 5
echo "== namespaces"
kubectl --context "$CTX" get ns --no-headers -o custom-columns=NAME:.metadata.name 2>&1
echo "== pods per candidate namespace"
for ns in orders-service-e2e ml-service-prod gitops-core ops-monitor cert-manager kube-system; do
  printf '%s pods: ' "$ns"
  kubectl --context "$CTX" -n "$ns" get pods --no-headers 2>/dev/null | wc -l
done
echo "== tmux"; tmux -V 2>&1
echo "== report dir"; ls -ld "$HOME/kdash_reports" 2>&1
echo "== checkout line endings (CR count per file; 0 = LF only)"
for f in kdash kdash-bundle.sh kdash-uninstall.sh scripts/capture-terminal.py scripts/record-validation.py scripts/wsl-env-probe.sh; do
  printf '%s: ' "$f"
  grep -c $'\r' "$REPO/$f" 2>/dev/null || echo 0
done
echo "== monospace fonts"
ls /usr/share/fonts/truetype/dejavu/ 2>&1 | head -n 6
echo "== done"
