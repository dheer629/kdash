# kdash 4.39.0 live WSL HTML reports

The files in this directory come from the generated reports of
[`live-e2e-v4390`](../../artifacts/live-e2e-v4390), running the installed kdash 4.39.0 against local WSL
Kubernetes. The [results](../../artifacts/live-e2e-v4390/results.json) and [checks](../../artifacts/live-e2e-v4390/checks.tsv)
record export validation; the [terminal gallery](../cli_4390/README.md) records
the corresponding live interface.
Actual local workload names, cluster context and measured values are preserved.

The namespace report includes Overview, six resource tabs and recorded History,
plus FMEA and Secrets map tabs when live diagnostic extras are enabled. Offline
session reconstruction omits these live extras.
CLI Alerts appear in the Overview; Services, Storage, Events and explanations are
preserved in the evidence bundle's diagnostic text/tables rather than extra
namespace HTML tabs. Missing metrics remain unavailable instead of becoming zero.

FMEA has a static HTML worksheet and CSV, TSV and JSON exports in
`fmea/`. Current combined namespace reports also include a searchable, sortable
FMEA tab. Browser checks cover both forms with actual failure-mode rows.


The Secrets map has a static HTML report under `secrets/` and a tab in current
combined namespace reports. Its live
fixture and browser checks verify certificate metadata and workload usage;
secret values and private-key material are not included.

Reports are self-contained for local viewing and include table search/sort,
CSV/JSON export, themes, timezone selection and chart controls where data exists.
Multi-megabyte full-log export dumps stay in the evidence bundle (checks, raw
terminal captures and representative export files) instead of being committed
here; the run's `SHA256SUMS` covers every published byte.

| File | Bytes |
|---|---:|
| [extended/fmea/runs/kdash-local_kdash-e2e/20261126151036.tsv](extended/fmea/runs/kdash-local_kdash-e2e/20261126151036.tsv) | 1598 |
| [extended/with-extras/fmea/runs/kdash-local_kdash-e2e/20261126151311.tsv](extended/with-extras/fmea/runs/kdash-local_kdash-e2e/20261126151311.tsv) | 1598 |
| [extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_151307/csv/cluster_ns.csv](extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_151307/csv/cluster_ns.csv) | 728 |
| [extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_151307/csv/containers.csv](extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_151307/csv/containers.csv) | 1633 |
| [extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_151307/csv/ip.csv](extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_151307/csv/ip.csv) | 1901 |
| [extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_151307/csv/ipblocks.csv](extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_151307/csv/ipblocks.csv) | 196 |
| [extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_151307/csv/memory.csv](extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_151307/csv/memory.csv) | 1757 |
| [extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_151307/csv/meta.csv](extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_151307/csv/meta.csv) | 1128 |
| [extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_151307/csv/nodes.csv](extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_151307/csv/nodes.csv) | 722 |
| [extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_151307/csv/pods.csv](extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_151307/csv/pods.csv) | 3379 |
| [extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_151307/csv/pools.csv](extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_151307/csv/pools.csv) | 498 |
| [extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_151307/csv/services.csv](extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_151307/csv/services.csv) | 717 |
| [extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_151307/csv/subnets.csv](extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_151307/csv/subnets.csv) | 39 |
| [extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_151307/csv/wl_node.csv](extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_151307/csv/wl_node.csv) | 1318 |
| [extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_151307/csv/workloads.csv](extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_151307/csv/workloads.csv) | 1308 |
| [extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_151307/diagnostics/events.tsv](extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_151307/diagnostics/events.tsv) | 15715 |
| [extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_151307/diagnostics/health-volume-usage.tsv](extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_151307/diagnostics/health-volume-usage.tsv) | 0 |
| [extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_151307/fmea.csv](extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_151307/fmea.csv) | 10290 |
| [extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_151307/report.html](extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_151307/report.html) | 68920 |
| [extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_151307/secrets.csv](extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_151307/secrets.csv) | 2325 |
| [extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_151307/secrets.json](extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_151307/secrets.json) | 5297 |
| [extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_151307/tsv/cluster_ns.tsv](extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_151307/tsv/cluster_ns.tsv) | 728 |
| [extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_151307/tsv/containers.tsv](extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_151307/tsv/containers.tsv) | 1705 |
| [extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_151307/tsv/ip.tsv](extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_151307/tsv/ip.tsv) | 1889 |
| [extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_151307/tsv/ipblocks.tsv](extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_151307/tsv/ipblocks.tsv) | 194 |
| [extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_151307/tsv/memory.tsv](extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_151307/tsv/memory.tsv) | 1783 |
| [extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_151307/tsv/meta.tsv](extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_151307/tsv/meta.tsv) | 1131 |
| [extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_151307/tsv/nodes.tsv](extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_151307/tsv/nodes.tsv) | 736 |
| [extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_151307/tsv/pods.tsv](extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_151307/tsv/pods.tsv) | 3405 |
| [extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_151307/tsv/pools.tsv](extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_151307/tsv/pools.tsv) | 504 |
| [extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_151307/tsv/services.tsv](extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_151307/tsv/services.tsv) | 743 |
| [extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_151307/tsv/subnets.tsv](extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_151307/tsv/subnets.tsv) | 39 |
| [extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_151307/tsv/wl_node.tsv](extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_151307/tsv/wl_node.tsv) | 1304 |
| [extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_151307/tsv/workloads.tsv](extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_151307/tsv/workloads.tsv) | 1414 |
| [extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_151307.html](extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_151307.html) | 68920 |
| [extended/with-extras-snapshot/fmea/runs/kdash-local_kdash-e2e/20261126151316.tsv](extended/with-extras-snapshot/fmea/runs/kdash-local_kdash-e2e/20261126151316.tsv) | 1598 |
| [extended/with-extras-snapshot/index.html](extended/with-extras-snapshot/index.html) | 1013 |
| [extended/with-extras-snapshot/kdash_namespace_report_kdash-local_kdash-e2e_20261126_151313.html](extended/with-extras-snapshot/kdash_namespace_report_kdash-local_kdash-e2e_20261126_151313.html) | 435793 |
| [extended/without-extras/index.html](extended/without-extras/index.html) | 1007 |
| [extended/without-extras/kdash_namespace_report_kdash-local_kdash-e2e_20261126_151317.html](extended/without-extras/kdash_namespace_report_kdash-local_kdash-e2e_20261126_151317.html) | 386899 |
| [fmea/fmea_kdash-local_kdash-e2e_20261126_145941.html](fmea/fmea_kdash-local_kdash-e2e_20261126_145941.html) | 17949 |
| [fmea/runs/kdash-local_kdash-e2e/20261126145901.tsv](fmea/runs/kdash-local_kdash-e2e/20261126145901.tsv) | 1598 |
| [fmea/runs/kdash-local_kdash-e2e/20261126145926.tsv](fmea/runs/kdash-local_kdash-e2e/20261126145926.tsv) | 1598 |
| [fmea/runs/kdash-local_kdash-e2e/20261126145929.tsv](fmea/runs/kdash-local_kdash-e2e/20261126145929.tsv) | 1598 |
| [fmea/runs/kdash-local_kdash-e2e/20261126145933.tsv](fmea/runs/kdash-local_kdash-e2e/20261126145933.tsv) | 1598 |
| [fmea/runs/kdash-local_kdash-e2e/20261126145937.tsv](fmea/runs/kdash-local_kdash-e2e/20261126145937.tsv) | 1598 |
| [fmea/runs/kdash-local_kdash-e2e/20261126145941.tsv](fmea/runs/kdash-local_kdash-e2e/20261126145941.tsv) | 1598 |
| [fmea/runs/kdash-local_kdash-e2e/20261126145945.tsv](fmea/runs/kdash-local_kdash-e2e/20261126145945.tsv) | 1598 |
| [fmea/runs/kdash-local_kdash-e2e/20261126145949.tsv](fmea/runs/kdash-local_kdash-e2e/20261126145949.tsv) | 1598 |
| [fmea/runs/kdash-local_kdash-e2e/20261126145954.tsv](fmea/runs/kdash-local_kdash-e2e/20261126145954.tsv) | 1598 |
| [fmea/worksheet.csv](fmea/worksheet.csv) | 10286 |
| [fmea/worksheet.json](fmea/worksheet.json) | 19465 |
| [fmea/worksheet.tsv](fmea/worksheet.tsv) | 10172 |
| [index.html](index.html) | 2549 |
| [kdash_audit_20261126_150812.csv](kdash_audit_20261126_150812.csv) | 190094 |
| [kdash_audit_20261126_150812.html](kdash_audit_20261126_150812.html) | 428590 |
| [kdash_kdash-local_kdash-e2e_20261126_145904/csv/cluster_ns.csv](kdash_kdash-local_kdash-e2e_20261126_145904/csv/cluster_ns.csv) | 729 |
| [kdash_kdash-local_kdash-e2e_20261126_145904/csv/containers.csv](kdash_kdash-local_kdash-e2e_20261126_145904/csv/containers.csv) | 1633 |
| [kdash_kdash-local_kdash-e2e_20261126_145904/csv/io_nodes.csv](kdash_kdash-local_kdash-e2e_20261126_145904/csv/io_nodes.csv) | 248 |
| [kdash_kdash-local_kdash-e2e_20261126_145904/csv/io_pods.csv](kdash_kdash-local_kdash-e2e_20261126_145904/csv/io_pods.csv) | 1007 |
| [kdash_kdash-local_kdash-e2e_20261126_145904/csv/ip.csv](kdash_kdash-local_kdash-e2e_20261126_145904/csv/ip.csv) | 1901 |
| [kdash_kdash-local_kdash-e2e_20261126_145904/csv/ipblocks.csv](kdash_kdash-local_kdash-e2e_20261126_145904/csv/ipblocks.csv) | 196 |
| [kdash_kdash-local_kdash-e2e_20261126_145904/csv/memory.csv](kdash_kdash-local_kdash-e2e_20261126_145904/csv/memory.csv) | 1757 |
| [kdash_kdash-local_kdash-e2e_20261126_145904/csv/meta.csv](kdash_kdash-local_kdash-e2e_20261126_145904/csv/meta.csv) | 1275 |
| [kdash_kdash-local_kdash-e2e_20261126_145904/csv/nodes.csv](kdash_kdash-local_kdash-e2e_20261126_145904/csv/nodes.csv) | 722 |
| [kdash_kdash-local_kdash-e2e_20261126_145904/csv/pods.csv](kdash_kdash-local_kdash-e2e_20261126_145904/csv/pods.csv) | 3379 |
| [kdash_kdash-local_kdash-e2e_20261126_145904/csv/pools.csv](kdash_kdash-local_kdash-e2e_20261126_145904/csv/pools.csv) | 498 |
| [kdash_kdash-local_kdash-e2e_20261126_145904/csv/services.csv](kdash_kdash-local_kdash-e2e_20261126_145904/csv/services.csv) | 717 |
| [kdash_kdash-local_kdash-e2e_20261126_145904/csv/subnets.csv](kdash_kdash-local_kdash-e2e_20261126_145904/csv/subnets.csv) | 39 |
| [kdash_kdash-local_kdash-e2e_20261126_145904/csv/wl_node.csv](kdash_kdash-local_kdash-e2e_20261126_145904/csv/wl_node.csv) | 1318 |
| [kdash_kdash-local_kdash-e2e_20261126_145904/csv/workloads.csv](kdash_kdash-local_kdash-e2e_20261126_145904/csv/workloads.csv) | 1308 |
| [kdash_kdash-local_kdash-e2e_20261126_145904/diagnostics/events.tsv](kdash_kdash-local_kdash-e2e_20261126_145904/diagnostics/events.tsv) | 15715 |
| [kdash_kdash-local_kdash-e2e_20261126_145904/diagnostics/health-volume-usage.tsv](kdash_kdash-local_kdash-e2e_20261126_145904/diagnostics/health-volume-usage.tsv) | 0 |
| [kdash_kdash-local_kdash-e2e_20261126_145904/fmea.csv](kdash_kdash-local_kdash-e2e_20261126_145904/fmea.csv) | 10290 |
| [kdash_kdash-local_kdash-e2e_20261126_145904/report.html](kdash_kdash-local_kdash-e2e_20261126_145904/report.html) | 68920 |
| [kdash_kdash-local_kdash-e2e_20261126_145904/secrets.csv](kdash_kdash-local_kdash-e2e_20261126_145904/secrets.csv) | 2325 |
| [kdash_kdash-local_kdash-e2e_20261126_145904/secrets.json](kdash_kdash-local_kdash-e2e_20261126_145904/secrets.json) | 5297 |
| [kdash_kdash-local_kdash-e2e_20261126_145904/tsv/cluster_ns.tsv](kdash_kdash-local_kdash-e2e_20261126_145904/tsv/cluster_ns.tsv) | 729 |
| [kdash_kdash-local_kdash-e2e_20261126_145904/tsv/containers.tsv](kdash_kdash-local_kdash-e2e_20261126_145904/tsv/containers.tsv) | 1705 |
| [kdash_kdash-local_kdash-e2e_20261126_145904/tsv/io_nodes.tsv](kdash_kdash-local_kdash-e2e_20261126_145904/tsv/io_nodes.tsv) | 270 |
| [kdash_kdash-local_kdash-e2e_20261126_145904/tsv/io_pods.tsv](kdash_kdash-local_kdash-e2e_20261126_145904/tsv/io_pods.tsv) | 1115 |
| [kdash_kdash-local_kdash-e2e_20261126_145904/tsv/ip.tsv](kdash_kdash-local_kdash-e2e_20261126_145904/tsv/ip.tsv) | 1889 |
| [kdash_kdash-local_kdash-e2e_20261126_145904/tsv/ipblocks.tsv](kdash_kdash-local_kdash-e2e_20261126_145904/tsv/ipblocks.tsv) | 194 |
| [kdash_kdash-local_kdash-e2e_20261126_145904/tsv/memory.tsv](kdash_kdash-local_kdash-e2e_20261126_145904/tsv/memory.tsv) | 1783 |
| [kdash_kdash-local_kdash-e2e_20261126_145904/tsv/meta.tsv](kdash_kdash-local_kdash-e2e_20261126_145904/tsv/meta.tsv) | 1287 |
| [kdash_kdash-local_kdash-e2e_20261126_145904/tsv/nodes.tsv](kdash_kdash-local_kdash-e2e_20261126_145904/tsv/nodes.tsv) | 736 |
| [kdash_kdash-local_kdash-e2e_20261126_145904/tsv/pods.tsv](kdash_kdash-local_kdash-e2e_20261126_145904/tsv/pods.tsv) | 3405 |
| [kdash_kdash-local_kdash-e2e_20261126_145904/tsv/pools.tsv](kdash_kdash-local_kdash-e2e_20261126_145904/tsv/pools.tsv) | 504 |
| [kdash_kdash-local_kdash-e2e_20261126_145904/tsv/services.tsv](kdash_kdash-local_kdash-e2e_20261126_145904/tsv/services.tsv) | 743 |
| [kdash_kdash-local_kdash-e2e_20261126_145904/tsv/subnets.tsv](kdash_kdash-local_kdash-e2e_20261126_145904/tsv/subnets.tsv) | 39 |
| [kdash_kdash-local_kdash-e2e_20261126_145904/tsv/wl_node.tsv](kdash_kdash-local_kdash-e2e_20261126_145904/tsv/wl_node.tsv) | 1304 |
| [kdash_kdash-local_kdash-e2e_20261126_145904/tsv/workloads.tsv](kdash_kdash-local_kdash-e2e_20261126_145904/tsv/workloads.tsv) | 1414 |
| [kdash_kdash-local_kdash-e2e_20261126_145904.html](kdash_kdash-local_kdash-e2e_20261126_145904.html) | 68920 |
| [kdash_memory_dashboard_kdash-local_kdash-e2e_20261126_145902.html](kdash_memory_dashboard_kdash-local_kdash-e2e_20261126_145902.html) | 123083 |
| [kdash_memory_dashboard_kdash-local_kdash-e2e_20261126_145904.html](kdash_memory_dashboard_kdash-local_kdash-e2e_20261126_145904.html) | 123023 |
| [kdash_namespace_ip_pool_kdash-local_kdash-e2e_20261126_145902.html](kdash_namespace_ip_pool_kdash-local_kdash-e2e_20261126_145902.html) | 100862 |
| [kdash_namespace_report_kdash-local_kdash-e2e_20261126_145858.html](kdash_namespace_report_kdash-local_kdash-e2e_20261126_145858.html) | 446098 |
| [kdash_namespace_report_kdash-local_kdash-e2e_20261126_150812.html](kdash_namespace_report_kdash-local_kdash-e2e_20261126_150812.html) | 411660 |
| [kdash_network_disk_io_kdash-local_kdash-e2e_20261126_145902.html](kdash_network_disk_io_kdash-local_kdash-e2e_20261126_145902.html) | 76193 |
| [kdash_node_pools_worker_nodes_kdash-local_kdash-e2e_20261126_145902.html](kdash_node_pools_worker_nodes_kdash-local_kdash-e2e_20261126_145902.html) | 102790 |
| [kdash_node_pools_worker_nodes_kdash-local_kdash-e2e_20261126_145904.html](kdash_node_pools_worker_nodes_kdash-local_kdash-e2e_20261126_145904.html) | 102730 |
| [kdash_pod_container_resources_kdash-local_kdash-e2e_20261126_145902.html](kdash_pod_container_resources_kdash-local_kdash-e2e_20261126_145902.html) | 153371 |
| [kdash_workloads_per_worker_node_kdash-local_kdash-e2e_20261126_145902.html](kdash_workloads_per_worker_node_kdash-local_kdash-e2e_20261126_145902.html) | 117955 |
| [screenshots/combined-fmea.png](screenshots/combined-fmea.png) | 326916 |
| [screenshots/combined-secrets.png](screenshots/combined-secrets.png) | 165320 |
| [screenshots/fmea.png](screenshots/fmea.png) | 114752 |
| [screenshots/history.png](screenshots/history.png) | 137867 |
| [screenshots/io.png](screenshots/io.png) | 123084 |
| [screenshots/ip.png](screenshots/ip.png) | 179018 |
| [screenshots/mem.png](screenshots/mem.png) | 177552 |
| [screenshots/nodes.png](screenshots/nodes.png) | 184760 |
| [screenshots/overview.png](screenshots/overview.png) | 223325 |
| [screenshots/pods.png](screenshots/pods.png) | 207764 |
| [screenshots/secrets.png](screenshots/secrets.png) | 121266 |
| [screenshots/workloads.png](screenshots/workloads.png) | 194149 |
| [secrets/fmea/runs/kdash-local_kdash-e2e/20261126151602.tsv](secrets/fmea/runs/kdash-local_kdash-e2e/20261126151602.tsv) | 1598 |
| [secrets/index.html](secrets/index.html) | 991 |
| [secrets/kdash_namespace_report_kdash-local_kdash-e2e_20261126_151558.html](secrets/kdash_namespace_report_kdash-local_kdash-e2e_20261126_151558.html) | 458569 |
| [secrets/secrets/secrets_kdash-local_kdash-e2e_20261126_151535.html](secrets/secrets/secrets_kdash-local_kdash-e2e_20261126_151535.html) | 9147 |

Verify the published bytes with `sha256sum -c SHA256SUMS` in this directory.
Keep the relative filenames together when sharing. Review operational metadata
before distributing reports. Historical reports retain their original capture
version: [4.19.2](../html419/README.md), [4.23.1](../html423/README.md), [4.24.1](../html4241/README.md), [4.27.3](../html4273/README.md), [4.27.4](../html4274/README.md), [4.32.0](../html4320/README.md), [4.37.0](../html4370/README.md), [4.12.0](../html/).
