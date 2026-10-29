# kdash samples

The names in these samples are placeholders. Before publication the cluster
context, the namespaces, the namespace-derived pod prefixes, the operator and host
names, the home-directory paths and the product / organisation wording were
replaced with generic values (`devops-admin@local-cluster`, `orders-service-e2e`,
`ml-service-prod`, `gitops-core`, `orders-*`, operator `demo`, host `node`,
`/workspace/kdash`, `platform namespaces`) using `../scripts/redact-run.sh` and a
private mapping; the CLI screenshots were re-rendered from the redacted captures
and the HTML files were re-copied, so text and images agree. See
`../artifacts/README.md` (section "Redaction") for what was replaced, what was
kept, and the consequence that the published audit logs no longer verify their
hash chain.

Shareable examples produced by the validation run `wsl-validation-20261018-134816`
(kdash 4.12.0, context `devops-admin@local-cluster`, three namespaces, five minutes
each). The raw evidence behind every file here is in `../artifacts/`.

## 4.13.1 screenshots - the new views and the inspector

`samples/cli_413/` holds 22 fresh screens from **kdash 4.13.1** against a local WSL
vcluster (namespace `default`, 5 s poll). They cover
what the 4.12.0 run predates: the 4.13 tab bar in every view, **8 SERVICES**,
**9 STORAGE**, **E** Events, **!** explanations, **DOCTOR**, the inspector with
`/` find, `&` only matches, the `c` container picker and its key map, plus 100-column
layouts. Same method as above: `tmux capture-pane -e -p` while live, replayed cell by
cell with `scripts/capture-terminal.py`. The raw `.ansi` / `.txt` captures and the
manifest are in `../artifacts/feature-screens-20261029-151233/`, and
`samples/cli_413/SHA256SUMS` lists the 22 images. See
[`cli_413/README.md`](cli_413/README.md) for the file list and for the placeholder
names that `../scripts/redact-run.sh` substituted.

## 4.14.0 attachments - the opt-in shell and file copy

`samples/cli_414/` holds 7 screens from **kdash 4.14.0** that show the new interactive
mode end to end: `S` refused while it is off (with the audit line that proves it), the
pod picker that carries `S shell U/D copy`, a real shell prompt inside the container, the
dashboard after `exit`, the `D` download prompt and the finished download (with
`CP_DOWN`/`CP_END` in the audit), and the `U` upload prompt. Raw captures: 
`../artifacts/feature-screens-20261029-161848-attach/`. See
[`cli_414/README.md`](cli_414/README.md).

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

## The sample gallery at the top of samples/

`cli_*.png` are live CLI screens and `html_*.png` are pages of the HTML reports.
Every one of them was produced from this project's own runs against the local WSL
vcluster (context `devops-admin@local-cluster`), so the names inside them are the
generic ones of that cluster and nothing else.

| File | Shows | Made from |
|---|---|---|
| `cli_7_alerts_170col.png` | view 7 ALERTS on a 170x50 terminal | `artifacts/feature-screens-<run>/raw/07-alerts-170col-early.ansi` |
| `cli_7_alerts_100col.png` | the same view on a narrow 100x40 terminal | `.../raw/07-alerts-100col.ansi` |
| `cli_7_alerts_new_cleared.png` | the same view later in the run (new alerts, cleared counter) | `.../raw/07-alerts-170col-late.ansi` |
| `cli_7_alerts_help.png` | the `?` help screen of view 7 | `.../raw/07-alerts-help-170col.ansi` |
| `cli_7_alerts_help_narrow.png` | the same help screen at 100 columns | `.../raw/07-alerts-help-100col.ansi` |
| `cli_audit_log.png` | `kdash --audit 40` of the session | `.../raw/audit-log.ansi` |
| `cli_disclaimer_first_run.png` | the first-run disclaimer gate | `.../raw/disclaimer-first-run.ansi` |
| `cli_disclaimer_declined.png` | declining it: kdash exits 5 without reading the cluster | `.../raw/disclaimer-declined.ansi` |
| `cli_pods_audited_header.png` | view 1 PODS with the AUDITED header | `samples/cli/orders-service-e2e/01-pods.png` |
| `cli_pods_timeline_sparklines.png` | view 1 with the timeline charts and trend sparklines | `samples/cli/ml-service-prod/01-pods.png` |
| `cli_workloads_sparklines.png` | view 3 WORKLOADS with the per-replica sparklines | `samples/cli/gitops-core/03-workloads.png` |
| `html_overview.png` | Overview of the all-tabs namespace report | browser screenshot of the report HTML |
| `html_report_disclaimer_footer.png` | the same report down to its disclaimer footer | browser screenshot, tall window |
| `html_pods_charts.png` | Pods tab of a snapshot report | browser screenshot |
| `html_memory_charts.png` | Memory tab of a snapshot report | browser screenshot |
| `html_workloads_charts.png` | Workloads tab of a snapshot report | browser screenshot |
| `html_audit_report.png` | the audit report page | browser screenshot |

`samples/SHA256SUMS` lists all of them. The CLI images are renders of saved tmux
screens (not operating-system window screenshots) and the HTML images are
headless-browser screenshots, both stated in the images themselves. Where the
captured command had already finished - the audit table and the declined
disclaimer - tmux prints its own `Pane is dead (status N)` line at the bottom of
the pane: that is tmux's exit-status marker, not kdash output.

Regenerate the gallery with:

```bash
# inside WSL Ubuntu, from the repository root
bash scripts/capture-feature-screens.sh                  # live screens -> artifacts/feature-screens-<run>/
bash scripts/compress-raw-captures.sh artifacts/feature-screens-<run>
```

```powershell
# on Windows, from the repository root
powershell -ExecutionPolicy Bypass -File scripts/make-sample-gallery.ps1 `
  -RunDirectory artifacts/wsl-validation-<run-id> -FeatureDirectory artifacts/feature-screens-<run-id>
```

Earlier versions of this folder held sample images taken from a different,
non-generic environment. They were removed and replaced by the gallery above,
which comes entirely from the generic WSL vcluster runs recorded in `artifacts/`.

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
