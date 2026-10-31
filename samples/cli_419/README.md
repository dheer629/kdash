# kdash 4.19.2 screenshots - the current interface

31 saved live screens from **kdash 4.19.2** (`~/.local/bin/kdash`, the same file as
`kdash` in this repository) running against a local WSL vcluster (namespace
`default`, 5 s poll, 170x50 and 100x40 terminals).

The names are placeholders, as in the rest of `samples/`: the context is shown as
`devops-admin@local-cluster`, the personal paths as `/home/demo`, the host as
`node`, the operator as `demo`, and the other tenants of that shared development
cluster as `ml-service-prod`, `ml-service-dev` and `gitops-core`. The captures were
rewritten with [`scripts/redact-run.sh`](../redact-run.sh) using a private mapping
that is not in this repository, and the images were re-rendered afterwards so text
and pixels agree.

Nothing here is drawn or retyped: each screen was captured with
`tmux capture-pane -e -p` while the dashboard was live and then rendered cell by
cell with [`scripts/capture-terminal.py`](../capture-terminal.py) (pyte + Pillow).
The raw captures - `.ansi` with colours and `.txt` as plain text - are published
next to the manifest in
[`artifacts/view-screens-20261031-051739/`](../../artifacts/view-screens-20261031-051739),
which
[`scripts/capture-view-screens.sh`](../capture-view-screens.sh) produced and
[`scripts/render-captures.ps1`](../render-captures.ps1) rendered into this folder.

| File | Screen |
|---|---|
| `01-pods.png` | 1 PODS - pod and container usage against requests and limits |
| `02-nodes.png` | 2 NODE POOLS - this namespace against the whole cluster, per worker node |
| `03-workloads.png` | 3 WORKLOADS - replicas, rollout state and pods per node |
| `04-ip.png` | 4 IP POOL - pod IPs, node blocks, subnets and services |
| `05-mem.png` | 5 MEMORY - trend, node bars, top pods and OOM risk |
| `06-io.png` | 6 NET & DISK IO - traffic and disk read/write per node and pod |
| `07-alerts.png` | 7 ALERTS - verdict, every section and the kubectl action to run |
| `08-services.png` | 8 SERVICES - Ingress -> Service -> EndpointSlice -> ready pods |
| `09-storage.png` | 9 STORAGE - Pod -> PVC -> PV -> StorageClass |
| `10-events.png` | E Kubernetes Events, deduplicated and counted |
| `11-explain.png` | `!` incident evidence: observed fact, explanation, next read-only check |
| `12-palette.png` | the `:` command palette (fixed commands, never shell text) |
| `13-doctor.png` | DOCTOR - connection, TLS, RBAC, metrics and reports, each with a next check |
| `14-inspector-pod-picker.png` | inspector: pick a pod (state, restarts, last exit, node) |
| `15-inspector-summary.png` | inspector: pod summary and container state |
| `16-inspector-previous-logs.png` | inspector: previous logs of the container, with the byte and line counts |
| `17-inspector-find.png` | inspector: `/` find - context kept, matches highlighted and counted |
| `18-inspector-only-matches.png` | inspector: `&` only matches - 1152 log lines reduced to the 823 that match |
| `19-inspector-containers.png` | inspector: `c` container picker with state and last exit |
| `20-inspector-help.png` | inspector: `?` key map (find, panes, navigate, export) |
| `21-help-keys.png` | dashboard `?` help, including the inspector and interactive keys |
| `22-pods-100col.png` | 1 PODS at 100 columns |
| `23-services-100col.png` | 8 SERVICES at 100 columns |
| `24-attach-blocked.png` | `S` while interactive mode is off: refused and audited |
| `25-interactive-ask.png` | `X` asks first - interactive mode is opt-in |
| `26-interactive-on.png` | interactive mode on for this session, with the audit line |
| `27-shell-picker.png` | `S` - pick the pod and container for the shell |
| `28-shell-inside.png` | a real shell inside the container (kubectl exec, audited) |
| `29-back-in-dashboard.png` | back in the dashboard after `exit` |
| `30-download-prompt.png` | `D` - the download browser (local files, container files, review) |
| `31-upload-prompt.png` | `U` - the upload browser |

Facts visible in these screens are the cluster's, not examples: the Kafka pod
really runs `apache/kafka:3.9.1` with `restarts 3`, its previous-log window really
held 1152 lines of which 823 matched `INFO`, and the namespace really holds three
`platform-*` deployments with 3, 3 and 3 restarts.

Verify the images are unchanged: `sha256sum -c SHA256SUMS` in this directory.
The 4.13.1 screens are in [`../cli_413/`](../cli_413), the 4.14.0 interactive
screens in [`../cli_414/`](../cli_414) and the 4.12.0 validation run's views in
[`../cli/`](../cli); this folder is the current version's gallery.
