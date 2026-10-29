# kdash 4.13.1 screenshots

22 saved live screens from **kdash 4.13.1** (`~/.local/bin/kdash`, built from commit
`6a3b2f7`) running against a local WSL vcluster (namespace `default`, 5 s poll).

The names are placeholders, as in the rest of `samples/`: the context is shown as
`devops-admin@local-cluster`, the personal paths as `/home/demo`, the host as `node`,
and the other tenants of that shared development cluster as `ml-service-prod`,
`ml-service-dev` and `gitops-core`. The captures were rewritten with
[`scripts/redact-run.sh`](../redact-run.sh) using a private mapping that is not in this
repository, and the images were re-rendered afterwards so text and pixels agree.

Nothing here is drawn or retyped: each screen was captured with
`tmux capture-pane -e -p` while the dashboard was live and then rendered cell by cell
with [`scripts/capture-terminal.py`](../capture-terminal.py) (pyte + Pillow). The raw
captures - `.ansi` with colours and `.txt` as plain text - are published next to the
manifest in
[`artifacts/feature-screens-20261029-151233/`](../../artifacts/feature-screens-20261029-151233).

| File | Screen |
|---|---|
| `01-pods.png` | 1 PODS - pod and container usage against requests and limits, with the 4.13 tab bar |
| `02-nodes.png` | 2 NODE POOLS |
| `03-workloads.png` | 3 WORKLOADS |
| `04-ip.png` | 4 IP POOL |
| `05-mem.png` | 5 MEMORY |
| `06-io.png` | 6 NET & DISK IO |
| `07-alerts.png` | 7 ALERTS |
| `08-services.png` | **8 SERVICES** - Ingress -> Service -> EndpointSlice -> ready pods |
| `09-storage.png` | **9 STORAGE** - Pod -> PVC -> PV -> StorageClass |
| `10-events.png` | **E** Kubernetes Events, deduplicated and counted |
| `11-explain.png` | **!** incident evidence: observed fact, possible explanation, next check |
| `12-doctor.png` | **DOCTOR** - connection, TLS, RBAC, metrics, reports |
| `13-inspector-pod-picker.png` | inspector: pick a pod |
| `14-inspector-summary.png` | inspector: summary pane |
| `15-inspector-previous-logs.png` | inspector: previous logs of the Kafka container |
| `16-inspector-find.png` | inspector: `/` find - context kept, matches highlighted, `137 matching` |
| `17-inspector-only-matches.png` | inspector: `&` only matches - 202 lines reduced to 37 |
| `18-inspector-containers.png` | inspector: `c` container picker with state and last exit |
| `19-inspector-help.png` | inspector: `?` key map |
| `20-help-keys.png` | dashboard `?` help, including the inspector keys |
| `21-pods-100col.png` | 1 PODS at 100 columns |
| `22-services-100col.png` | 8 SERVICES at 100 columns |

Facts visible in these screens are the cluster's, not examples: the Kafka pod really had
`restarts 3`, `last exit Unknown exit=255` and `apache/kafka:3.9.1`; the previous-log
window really held 202 lines, of which `GroupMetadataManager` matched 137 and
`Finished loading offsets` matched 37.

Verify the images are unchanged: `sha256sum -c SHA256SUMS` in this directory.
The 4.12.0 run's screens are in [`../cli/`](../cli) and its evidence in
[`../../artifacts/`](../../artifacts/README.md).
