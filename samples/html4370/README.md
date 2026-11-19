# kdash 4.37.0 live WSL HTML reports

The files in this directory come from the generated reports of
[`live-e2e-v4370`](../../artifacts/live-e2e-v4370), running the installed kdash 4.37.0 against local WSL
Kubernetes. The [results](../../artifacts/live-e2e-v4370/results.json) and [checks](../../artifacts/live-e2e-v4370/checks.tsv)
record export validation; the [terminal gallery](../cli_4370/README.md) records
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

| File | Bytes |
|---|---:|
| [fmea/fmea_kdash-local_kdash-e2e_20261120_001745.html](fmea/fmea_kdash-local_kdash-e2e_20261120_001745.html) | 17196 |
| [fmea/runs/kdash-local_kdash-e2e/20261120001631.tsv](fmea/runs/kdash-local_kdash-e2e/20261120001631.tsv) | 1497 |
| [fmea/runs/kdash-local_kdash-e2e/20261120001714.tsv](fmea/runs/kdash-local_kdash-e2e/20261120001714.tsv) | 1497 |
| [fmea/runs/kdash-local_kdash-e2e/20261120001722.tsv](fmea/runs/kdash-local_kdash-e2e/20261120001722.tsv) | 1497 |
| [fmea/runs/kdash-local_kdash-e2e/20261120001730.tsv](fmea/runs/kdash-local_kdash-e2e/20261120001730.tsv) | 1497 |
| [fmea/runs/kdash-local_kdash-e2e/20261120001738.tsv](fmea/runs/kdash-local_kdash-e2e/20261120001738.tsv) | 1497 |
| [fmea/runs/kdash-local_kdash-e2e/20261120001745.tsv](fmea/runs/kdash-local_kdash-e2e/20261120001745.tsv) | 1497 |
| [fmea/runs/kdash-local_kdash-e2e/20261120001753.tsv](fmea/runs/kdash-local_kdash-e2e/20261120001753.tsv) | 1497 |
| [fmea/runs/kdash-local_kdash-e2e/20261120001800.tsv](fmea/runs/kdash-local_kdash-e2e/20261120001800.tsv) | 1497 |
| [fmea/runs/kdash-local_kdash-e2e/20261120001808.tsv](fmea/runs/kdash-local_kdash-e2e/20261120001808.tsv) | 1497 |
| [fmea/runs/kdash-local_kdash-e2e/20261120003336.tsv](fmea/runs/kdash-local_kdash-e2e/20261120003336.tsv) | 1497 |
| [fmea/worksheet.csv](fmea/worksheet.csv) | 9745 |
| [fmea/worksheet.json](fmea/worksheet.json) | 18616 |
| [fmea/worksheet.tsv](fmea/worksheet.tsv) | 9631 |
| [index.html](index.html) | 2945 |
| [kdash_audit_20261120_003854.csv](kdash_audit_20261120_003854.csv) | 191093 |
| [kdash_audit_20261120_003854.html](kdash_audit_20261120_003854.html) | 430643 |
| [kdash_kdash-local_kdash-e2e_20261120_001635/csv/cluster_ns.csv](kdash_kdash-local_kdash-e2e_20261120_001635/csv/cluster_ns.csv) | 728 |
| [kdash_kdash-local_kdash-e2e_20261120_001635/csv/containers.csv](kdash_kdash-local_kdash-e2e_20261120_001635/csv/containers.csv) | 1492 |
| [kdash_kdash-local_kdash-e2e_20261120_001635/csv/io_nodes.csv](kdash_kdash-local_kdash-e2e_20261120_001635/csv/io_nodes.csv) | 248 |
| [kdash_kdash-local_kdash-e2e_20261120_001635/csv/io_pods.csv](kdash_kdash-local_kdash-e2e_20261120_001635/csv/io_pods.csv) | 937 |
| [kdash_kdash-local_kdash-e2e_20261120_001635/csv/ip.csv](kdash_kdash-local_kdash-e2e_20261120_001635/csv/ip.csv) | 1782 |
| [kdash_kdash-local_kdash-e2e_20261120_001635/csv/ipblocks.csv](kdash_kdash-local_kdash-e2e_20261120_001635/csv/ipblocks.csv) | 210 |
| [kdash_kdash-local_kdash-e2e_20261120_001635/csv/memory.csv](kdash_kdash-local_kdash-e2e_20261120_001635/csv/memory.csv) | 1601 |
| [kdash_kdash-local_kdash-e2e_20261120_001635/csv/meta.csv](kdash_kdash-local_kdash-e2e_20261120_001635/csv/meta.csv) | 1275 |
| [kdash_kdash-local_kdash-e2e_20261120_001635/csv/nodes.csv](kdash_kdash-local_kdash-e2e_20261120_001635/csv/nodes.csv) | 736 |
| [kdash_kdash-local_kdash-e2e_20261120_001635/csv/pods.csv](kdash_kdash-local_kdash-e2e_20261120_001635/csv/pods.csv) | 3137 |
| [kdash_kdash-local_kdash-e2e_20261120_001635/csv/pools.csv](kdash_kdash-local_kdash-e2e_20261120_001635/csv/pools.csv) | 498 |
| [kdash_kdash-local_kdash-e2e_20261120_001635/csv/services.csv](kdash_kdash-local_kdash-e2e_20261120_001635/csv/services.csv) | 655 |
| [kdash_kdash-local_kdash-e2e_20261120_001635/csv/subnets.csv](kdash_kdash-local_kdash-e2e_20261120_001635/csv/subnets.csv) | 39 |
| [kdash_kdash-local_kdash-e2e_20261120_001635/csv/wl_node.csv](kdash_kdash-local_kdash-e2e_20261120_001635/csv/wl_node.csv) | 1213 |
| [kdash_kdash-local_kdash-e2e_20261120_001635/csv/workloads.csv](kdash_kdash-local_kdash-e2e_20261120_001635/csv/workloads.csv) | 1232 |
| [kdash_kdash-local_kdash-e2e_20261120_001635/diagnostics/events.tsv](kdash_kdash-local_kdash-e2e_20261120_001635/diagnostics/events.tsv) | 24454 |
| [kdash_kdash-local_kdash-e2e_20261120_001635/diagnostics/health-volume-usage.tsv](kdash_kdash-local_kdash-e2e_20261120_001635/diagnostics/health-volume-usage.tsv) | 0 |
| [kdash_kdash-local_kdash-e2e_20261120_001635/fmea.csv](kdash_kdash-local_kdash-e2e_20261120_001635/fmea.csv) | 9745 |
| [kdash_kdash-local_kdash-e2e_20261120_001635/report.html](kdash_kdash-local_kdash-e2e_20261120_001635/report.html) | 66067 |
| [kdash_kdash-local_kdash-e2e_20261120_001635/secrets.csv](kdash_kdash-local_kdash-e2e_20261120_001635/secrets.csv) | 1267 |
| [kdash_kdash-local_kdash-e2e_20261120_001635/secrets.json](kdash_kdash-local_kdash-e2e_20261120_001635/secrets.json) | 2777 |
| [kdash_kdash-local_kdash-e2e_20261120_001635/tsv/cluster_ns.tsv](kdash_kdash-local_kdash-e2e_20261120_001635/tsv/cluster_ns.tsv) | 728 |
| [kdash_kdash-local_kdash-e2e_20261120_001635/tsv/containers.tsv](kdash_kdash-local_kdash-e2e_20261120_001635/tsv/containers.tsv) | 1568 |
| [kdash_kdash-local_kdash-e2e_20261120_001635/tsv/io_nodes.tsv](kdash_kdash-local_kdash-e2e_20261120_001635/tsv/io_nodes.tsv) | 270 |
| [kdash_kdash-local_kdash-e2e_20261120_001635/tsv/io_pods.tsv](kdash_kdash-local_kdash-e2e_20261120_001635/tsv/io_pods.tsv) | 1039 |
| [kdash_kdash-local_kdash-e2e_20261120_001635/tsv/ip.tsv](kdash_kdash-local_kdash-e2e_20261120_001635/tsv/ip.tsv) | 1771 |
| [kdash_kdash-local_kdash-e2e_20261120_001635/tsv/ipblocks.tsv](kdash_kdash-local_kdash-e2e_20261120_001635/tsv/ipblocks.tsv) | 208 |
| [kdash_kdash-local_kdash-e2e_20261120_001635/tsv/memory.tsv](kdash_kdash-local_kdash-e2e_20261120_001635/tsv/memory.tsv) | 1633 |
| [kdash_kdash-local_kdash-e2e_20261120_001635/tsv/meta.tsv](kdash_kdash-local_kdash-e2e_20261120_001635/tsv/meta.tsv) | 1287 |
| [kdash_kdash-local_kdash-e2e_20261120_001635/tsv/nodes.tsv](kdash_kdash-local_kdash-e2e_20261120_001635/tsv/nodes.tsv) | 750 |
| [kdash_kdash-local_kdash-e2e_20261120_001635/tsv/pods.tsv](kdash_kdash-local_kdash-e2e_20261120_001635/tsv/pods.tsv) | 3169 |
| [kdash_kdash-local_kdash-e2e_20261120_001635/tsv/pools.tsv](kdash_kdash-local_kdash-e2e_20261120_001635/tsv/pools.tsv) | 504 |
| [kdash_kdash-local_kdash-e2e_20261120_001635/tsv/services.tsv](kdash_kdash-local_kdash-e2e_20261120_001635/tsv/services.tsv) | 679 |
| [kdash_kdash-local_kdash-e2e_20261120_001635/tsv/subnets.tsv](kdash_kdash-local_kdash-e2e_20261120_001635/tsv/subnets.tsv) | 39 |
| [kdash_kdash-local_kdash-e2e_20261120_001635/tsv/wl_node.tsv](kdash_kdash-local_kdash-e2e_20261120_001635/tsv/wl_node.tsv) | 1201 |
| [kdash_kdash-local_kdash-e2e_20261120_001635/tsv/workloads.tsv](kdash_kdash-local_kdash-e2e_20261120_001635/tsv/workloads.tsv) | 1330 |
| [kdash_kdash-local_kdash-e2e_20261120_001635.html](kdash_kdash-local_kdash-e2e_20261120_001635.html) | 66067 |
| [kdash_memory_dashboard_kdash-local_kdash-e2e_20261120_001632.html](kdash_memory_dashboard_kdash-local_kdash-e2e_20261120_001632.html) | 120456 |
| [kdash_memory_dashboard_kdash-local_kdash-e2e_20261120_001634.html](kdash_memory_dashboard_kdash-local_kdash-e2e_20261120_001634.html) | 120396 |
| [kdash_namespace_ip_pool_kdash-local_kdash-e2e_20261120_001632.html](kdash_namespace_ip_pool_kdash-local_kdash-e2e_20261120_001632.html) | 98247 |
| [kdash_namespace_report_kdash-local_kdash-e2e_20261120_001624.html](kdash_namespace_report_kdash-local_kdash-e2e_20261120_001624.html) | 425236 |
| [kdash_namespace_report_kdash-local_kdash-e2e_20261120_003330.html](kdash_namespace_report_kdash-local_kdash-e2e_20261120_003330.html) | 553764 |
| [kdash_namespace_report_kdash-local_kdash-e2e_20261120_003852.html](kdash_namespace_report_kdash-local_kdash-e2e_20261120_003852.html) | 399076 |
| [kdash_namespace_report_kdash-local_kdash-e2e_20261120_004235.html](kdash_namespace_report_kdash-local_kdash-e2e_20261120_004235.html) | 448690 |
| [kdash_network_disk_io_kdash-local_kdash-e2e_20261120_001632.html](kdash_network_disk_io_kdash-local_kdash-e2e_20261120_001632.html) | 75716 |
| [kdash_node_pools_worker_nodes_kdash-local_kdash-e2e_20261120_001632.html](kdash_node_pools_worker_nodes_kdash-local_kdash-e2e_20261120_001632.html) | 102937 |
| [kdash_node_pools_worker_nodes_kdash-local_kdash-e2e_20261120_001634.html](kdash_node_pools_worker_nodes_kdash-local_kdash-e2e_20261120_001634.html) | 102877 |
| [kdash_pod_container_resources_kdash-local_kdash-e2e_20261120_001632.html](kdash_pod_container_resources_kdash-local_kdash-e2e_20261120_001632.html) | 148275 |
| [kdash_workloads_per_worker_node_kdash-local_kdash-e2e_20261120_001632.html](kdash_workloads_per_worker_node_kdash-local_kdash-e2e_20261120_001632.html) | 114252 |
| [screenshots/combined-fmea.png](screenshots/combined-fmea.png) | 329309 |
| [screenshots/combined-secrets.png](screenshots/combined-secrets.png) | 167788 |
| [screenshots/fmea.png](screenshots/fmea.png) | 113362 |
| [screenshots/history.png](screenshots/history.png) | 157856 |
| [screenshots/io.png](screenshots/io.png) | 142754 |
| [screenshots/ip.png](screenshots/ip.png) | 183489 |
| [screenshots/mem.png](screenshots/mem.png) | 163838 |
| [screenshots/nodes.png](screenshots/nodes.png) | 174254 |
| [screenshots/overview.png](screenshots/overview.png) | 245435 |
| [screenshots/pods.png](screenshots/pods.png) | 173401 |
| [screenshots/secrets.png](screenshots/secrets.png) | 121324 |
| [screenshots/workloads.png](screenshots/workloads.png) | 186878 |
| [secrets/secrets/secrets_kdash-local_kdash-e2e_20261120_004016.html](secrets/secrets/secrets_kdash-local_kdash-e2e_20261120_004016.html) | 9147 |
| [with-extras/fmea/runs/kdash-local_kdash-e2e/20261120004742.tsv](with-extras/fmea/runs/kdash-local_kdash-e2e/20261120004742.tsv) | 1598 |
| [with-extras/kdash_kdash-local_kdash-e2e_20261120_004733/csv/cluster_ns.csv](with-extras/kdash_kdash-local_kdash-e2e_20261120_004733/csv/cluster_ns.csv) | 730 |
| [with-extras/kdash_kdash-local_kdash-e2e_20261120_004733/csv/containers.csv](with-extras/kdash_kdash-local_kdash-e2e_20261120_004733/csv/containers.csv) | 1587 |
| [with-extras/kdash_kdash-local_kdash-e2e_20261120_004733/csv/ip.csv](with-extras/kdash_kdash-local_kdash-e2e_20261120_004733/csv/ip.csv) | 1910 |
| [with-extras/kdash_kdash-local_kdash-e2e_20261120_004733/csv/ipblocks.csv](with-extras/kdash_kdash-local_kdash-e2e_20261120_004733/csv/ipblocks.csv) | 210 |
| [with-extras/kdash_kdash-local_kdash-e2e_20261120_004733/csv/memory.csv](with-extras/kdash_kdash-local_kdash-e2e_20261120_004733/csv/memory.csv) | 1714 |
| [with-extras/kdash_kdash-local_kdash-e2e_20261120_004733/csv/meta.csv](with-extras/kdash_kdash-local_kdash-e2e_20261120_004733/csv/meta.csv) | 1128 |
| [with-extras/kdash_kdash-local_kdash-e2e_20261120_004733/csv/nodes.csv](with-extras/kdash_kdash-local_kdash-e2e_20261120_004733/csv/nodes.csv) | 736 |
| [with-extras/kdash_kdash-local_kdash-e2e_20261120_004733/csv/pods.csv](with-extras/kdash_kdash-local_kdash-e2e_20261120_004733/csv/pods.csv) | 3351 |
| [with-extras/kdash_kdash-local_kdash-e2e_20261120_004733/csv/pools.csv](with-extras/kdash_kdash-local_kdash-e2e_20261120_004733/csv/pools.csv) | 498 |
| [with-extras/kdash_kdash-local_kdash-e2e_20261120_004733/csv/services.csv](with-extras/kdash_kdash-local_kdash-e2e_20261120_004733/csv/services.csv) | 717 |
| [with-extras/kdash_kdash-local_kdash-e2e_20261120_004733/csv/subnets.csv](with-extras/kdash_kdash-local_kdash-e2e_20261120_004733/csv/subnets.csv) | 39 |
| [with-extras/kdash_kdash-local_kdash-e2e_20261120_004733/csv/wl_node.csv](with-extras/kdash_kdash-local_kdash-e2e_20261120_004733/csv/wl_node.csv) | 1319 |
| [with-extras/kdash_kdash-local_kdash-e2e_20261120_004733/csv/workloads.csv](with-extras/kdash_kdash-local_kdash-e2e_20261120_004733/csv/workloads.csv) | 1309 |
| [with-extras/kdash_kdash-local_kdash-e2e_20261120_004733/diagnostics/events.tsv](with-extras/kdash_kdash-local_kdash-e2e_20261120_004733/diagnostics/events.tsv) | 17505 |
| [with-extras/kdash_kdash-local_kdash-e2e_20261120_004733/diagnostics/health-volume-usage.tsv](with-extras/kdash_kdash-local_kdash-e2e_20261120_004733/diagnostics/health-volume-usage.tsv) | 0 |
| [with-extras/kdash_kdash-local_kdash-e2e_20261120_004733/fmea.csv](with-extras/kdash_kdash-local_kdash-e2e_20261120_004733/fmea.csv) | 10290 |
| [with-extras/kdash_kdash-local_kdash-e2e_20261120_004733/report.html](with-extras/kdash_kdash-local_kdash-e2e_20261120_004733/report.html) | 69132 |
| [with-extras/kdash_kdash-local_kdash-e2e_20261120_004733/secrets.csv](with-extras/kdash_kdash-local_kdash-e2e_20261120_004733/secrets.csv) | 2325 |
| [with-extras/kdash_kdash-local_kdash-e2e_20261120_004733/secrets.json](with-extras/kdash_kdash-local_kdash-e2e_20261120_004733/secrets.json) | 5297 |
| [with-extras/kdash_kdash-local_kdash-e2e_20261120_004733/tsv/cluster_ns.tsv](with-extras/kdash_kdash-local_kdash-e2e_20261120_004733/tsv/cluster_ns.tsv) | 730 |
| [with-extras/kdash_kdash-local_kdash-e2e_20261120_004733/tsv/containers.tsv](with-extras/kdash_kdash-local_kdash-e2e_20261120_004733/tsv/containers.tsv) | 1665 |
| [with-extras/kdash_kdash-local_kdash-e2e_20261120_004733/tsv/ip.tsv](with-extras/kdash_kdash-local_kdash-e2e_20261120_004733/tsv/ip.tsv) | 1898 |
| [with-extras/kdash_kdash-local_kdash-e2e_20261120_004733/tsv/ipblocks.tsv](with-extras/kdash_kdash-local_kdash-e2e_20261120_004733/tsv/ipblocks.tsv) | 208 |
| [with-extras/kdash_kdash-local_kdash-e2e_20261120_004733/tsv/memory.tsv](with-extras/kdash_kdash-local_kdash-e2e_20261120_004733/tsv/memory.tsv) | 1746 |
| [with-extras/kdash_kdash-local_kdash-e2e_20261120_004733/tsv/meta.tsv](with-extras/kdash_kdash-local_kdash-e2e_20261120_004733/tsv/meta.tsv) | 1131 |
| [with-extras/kdash_kdash-local_kdash-e2e_20261120_004733/tsv/nodes.tsv](with-extras/kdash_kdash-local_kdash-e2e_20261120_004733/tsv/nodes.tsv) | 750 |
| [with-extras/kdash_kdash-local_kdash-e2e_20261120_004733/tsv/pods.tsv](with-extras/kdash_kdash-local_kdash-e2e_20261120_004733/tsv/pods.tsv) | 3382 |
| [with-extras/kdash_kdash-local_kdash-e2e_20261120_004733/tsv/pools.tsv](with-extras/kdash_kdash-local_kdash-e2e_20261120_004733/tsv/pools.tsv) | 504 |
| [with-extras/kdash_kdash-local_kdash-e2e_20261120_004733/tsv/services.tsv](with-extras/kdash_kdash-local_kdash-e2e_20261120_004733/tsv/services.tsv) | 743 |
| [with-extras/kdash_kdash-local_kdash-e2e_20261120_004733/tsv/subnets.tsv](with-extras/kdash_kdash-local_kdash-e2e_20261120_004733/tsv/subnets.tsv) | 39 |
| [with-extras/kdash_kdash-local_kdash-e2e_20261120_004733/tsv/wl_node.tsv](with-extras/kdash_kdash-local_kdash-e2e_20261120_004733/tsv/wl_node.tsv) | 1305 |
| [with-extras/kdash_kdash-local_kdash-e2e_20261120_004733/tsv/workloads.tsv](with-extras/kdash_kdash-local_kdash-e2e_20261120_004733/tsv/workloads.tsv) | 1415 |
| [with-extras/kdash_kdash-local_kdash-e2e_20261120_004733.html](with-extras/kdash_kdash-local_kdash-e2e_20261120_004733.html) | 69132 |

Representative quick-export logs are under `exports/`. Multi-megabyte full-log
search dumps are recorded by the run checks and raw captures but are not committed
here. Published text replaces the validation host operator identity with
`operator@validation-host`; cluster data is unchanged.

Verify the published bytes with `sha256sum -c SHA256SUMS` in this directory.
Keep the relative filenames together when sharing. Review operational metadata
before distributing reports. Historical reports retain their original capture
version: [4.19.2](../html419/README.md), [4.23.1](../html423/README.md), [4.24.1](../html4241/README.md), [4.27.3](../html4273/README.md), [4.27.4](../html4274/README.md), [4.32.0](../html4320/README.md), [4.12.0](../html/).
