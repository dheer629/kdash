# kdash samples

Shareable examples produced by the validation run `wsl-validation-20261018-115201`
(kdash 4.12.0, context `devops-admin@local-cluster`, three namespaces, five minutes
each). The raw evidence behind every file here is in `../artifacts/`.

## CLI screenshots - views 1-7 for each namespace

`samples/cli/<namespace>/01-pods.png` ... `07-alerts.png` - 21 images, seven per
namespace. Each is the saved live screen of that view, replayed cell by cell from
the tmux capture with `scripts/capture-terminal.py` (pyte + Pillow), at the real
terminal size of the run (170 columns x 50 rows). Every image names the namespace,
the view and the run in its header and prints the sha256 of the capture it came
from, so a screenshot can always be traced back to `artifacts/.../<namespace>/cli/`.

They are renders of the captured screen, not operating-system window screenshots,
and they show the viewport: a table longer than 50 rows continues below the visible
area. Use the `.txt` capture, the session TSV files or the HTML report for the
complete data set.

| Namespace | Views | Notes |
|---|---|---|
| `orders-service-e2e` | 1-7 | busiest namespace (27 pods), contains a crash loop, an unschedulable pod and workloads with restarts, so views 1, 5 and 7 have the most to show |
| `ml-service-prod` | 1-7 | small application namespace (4 pods: backend, frontend, postgres, redis) |
| `gitops-core` | 1-7 | cluster controllers (7 pods), a clean reference namespace |

## HTML reports

`samples/html/<namespace>/` holds the reports exactly as kdash wrote them (byte for
byte; `SHA256SUMS` lists all 36 files). Names follow kdash's own convention:

| Prefix | Produced by | What it is |
|---|---|---|
| `kdash_namespace_report_<ctx>_<ns>_<stamp>.html` | `x` while live, or `--session-report` | the all-tabs report: Overview, Pods, Node Pools, Workloads, IP Pool, Memory, Net & Disk IO and History with the live session's samples |
| `kdash_pod_container_resources_...`, `kdash_node_pools_worker_nodes_...`, `kdash_workloads_per_worker_node_...`, `kdash_namespace_ip_pool_...`, `kdash_memory_dashboard_...`, `kdash_network_disk_io_...` | `--snapshot all` | one standalone report per view |
| `kdash_<ctx>_<ns>_<stamp>.html` | `--report` | the combined dashboard of the evidence bundle (its text/TSV/CSV files stay in `artifacts/`) |
| `kdash_audit_<stamp>.html` and `.csv` | `--audit-report` | the audit log of that namespace as a page and a table |
| `index.html` | every snapshot/export | newest-first list of the reports in the directory |

`screenshots/` contains Microsoft Edge (headless) screenshots of the main pages of
each namespace: the report index and both namespace reports. They show what a
reader gets when the file is opened in a browser; they are not part of the evidence
chain, the HTML files themselves are.

Open the HTML files directly from disk (no web server needed). The reports contain
cluster metadata - context, namespace, pod, workload and image names, IP addresses,
node names, operator and timestamps - so review them before publishing.

## Verify

```bash
cd samples/html && sha256sum -c SHA256SUMS
```

## Earlier images kept at the top of samples/

The PNG files directly in `samples/` (`cli_*.png`, `html_*.png`) predate this run and
come from the repository history: they were taken with kdash 4.11.0 / 4.8.0 against
a different, multi-node context (`example-cluster-1`, namespace `demo-test`). They are
kept as historical examples of the dashboard on a production-like cluster. The
samples of this run are only the ones under `cli/` and `html/`.

## Reproduce

```bash
# inside WSL Ubuntu, from the repository root
bash scripts/wsl-validation.sh --minutes 5 --namespaces "orders-service-e2e ml-service-prod gitops-core"
bash scripts/compress-raw-captures.sh artifacts/<new-run-id>
```

```powershell
# on Windows, from the repository root
powershell -ExecutionPolicy Bypass -File scripts/render-cli-samples.ps1  -RunDirectory artifacts/<new-run-id>
powershell -ExecutionPolicy Bypass -File scripts/collect-html-samples.ps1 -RunDirectory artifacts/<new-run-id> -Screenshot
```
