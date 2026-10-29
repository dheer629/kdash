# kdash 4.14.0 attachments - screenshots

Seven saved live screens of the opt-in shell and file copy, taken against a local WSL
vcluster (namespace `default`) with **kdash 4.14.0**:

| File | Screen |
|---|---|
| `03-attach-blocked-off.png` | `S` with interactive mode **off**: the dashboard explains that it is read-only by default and the attempt is audited as `INTERACTIVE_BLOCKED` |
| `05-attach-picker-on.png` | `S` with `--allow-interactive`: pick the pod; the footer carries `S shell U/D copy` |
| `06-shell-inside.png` | the terminal handed over: a real shell prompt inside `platform-kafka-65c6d4dcfd-l7mqq` |
| `08-back-in-dashboard.png` | after `exit`: the dashboard repainted and flashed `attach shell default/platform-kafka-… exited rc=0` |
| `10-download-prompt.png` | `D`: the download prompt (remote path, then local destination) |
| `11-download-done.png` | `D` finished: `/etc/hostname` copied out, audited as `CP_DOWN` + `CP_END dir=down rc=0 bytes=32` |
| `12-upload-prompt.png` | `U`: the upload prompt (local file, then remote path) |

Same method as every other set in `samples/`: `tmux capture-pane -e -p` while live,
replayed cell by cell with [`scripts/capture-terminal.py`](../capture-terminal.py), never
drawn by hand. The raw captures are in
[`artifacts/feature-screens-20261029-161848-attach`](../../artifacts/feature-screens-20261029-161848-attach),
and the names are placeholders (context `devops-admin@local-cluster`, paths
`/home/demo`, tenants `ml-service-prod` / `ml-service-dev` / `gitops-core`), rewritten
with [`scripts/redact-run.sh`](../redact-run.sh) before rendering.

What the audit log of that session recorded (the evidence behind the images):

```
EXEC        pod=default/platform-kafka-65c6d4dcfd-l7mqq container=kafka mode=shell shell=bash-or-sh
EXEC_END    pod=default/platform-kafka-65c6d4dcfd-l7mqq container=kafka rc=0
CP_DOWN     pod=default/platform-kafka-65c6d4dcfd-l7mqq container=kafka remote=/etc/hostname local=./hostname
CP_END      pod=default/platform-kafka-65c6d4dcfd-l7mqq dir=down rc=0 bytes=32 local=./hostname
CP_UP       pod=default/platform-kafka-65c6d4dcfd-l7mqq container=kafka remote=/tmp/kdash-upload-test.txt local=/home/demo/kdash-upload-test.txt
CP_END      pod=default/platform-kafka-65c6d4dcfd-l7mqq dir=up rc=0 bytes=18
INTERACTIVE_BLOCKED action=shell reason=not-enabled      # the run without --allow-interactive
```

Verify the images: `sha256sum -c SHA256SUMS` in this directory.