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
| [fmea/fmea_kdash-local_kdash-e2e_20261119_211011.html](fmea/fmea_kdash-local_kdash-e2e_20261119_211011.html) | 17196 |
| [fmea/runs/kdash-local_kdash-e2e/20261119210901.tsv](fmea/runs/kdash-local_kdash-e2e/20261119210901.tsv) | 1497 |
| [fmea/runs/kdash-local_kdash-e2e/20261119210942.tsv](fmea/runs/kdash-local_kdash-e2e/20261119210942.tsv) | 1497 |
| [fmea/runs/kdash-local_kdash-e2e/20261119210950.tsv](fmea/runs/kdash-local_kdash-e2e/20261119210950.tsv) | 1497 |
| [fmea/runs/kdash-local_kdash-e2e/20261119210957.tsv](fmea/runs/kdash-local_kdash-e2e/20261119210957.tsv) | 1497 |
| [fmea/runs/kdash-local_kdash-e2e/20261119211004.tsv](fmea/runs/kdash-local_kdash-e2e/20261119211004.tsv) | 1497 |
| [fmea/runs/kdash-local_kdash-e2e/20261119211011.tsv](fmea/runs/kdash-local_kdash-e2e/20261119211011.tsv) | 1497 |
| [fmea/runs/kdash-local_kdash-e2e/20261119211018.tsv](fmea/runs/kdash-local_kdash-e2e/20261119211018.tsv) | 1497 |
| [fmea/runs/kdash-local_kdash-e2e/20261119211026.tsv](fmea/runs/kdash-local_kdash-e2e/20261119211026.tsv) | 1497 |
| [fmea/runs/kdash-local_kdash-e2e/20261119211035.tsv](fmea/runs/kdash-local_kdash-e2e/20261119211035.tsv) | 1497 |
| [fmea/runs/kdash-local_kdash-e2e/20261119213902.tsv](fmea/runs/kdash-local_kdash-e2e/20261119213902.tsv) | 1598 |
| [fmea/worksheet.csv](fmea/worksheet.csv) | 9745 |
| [fmea/worksheet.json](fmea/worksheet.json) | 18616 |
| [fmea/worksheet.tsv](fmea/worksheet.tsv) | 9631 |
| [index.html](index.html) | 2945 |
| [kdash_audit_20261119_211916.csv](kdash_audit_20261119_211916.csv) | 44789 |
| [kdash_audit_20261119_211916.html](kdash_audit_20261119_211916.html) | 102140 |
| [kdash_kdash-local_kdash-e2e_20261119_210906/csv/cluster_ns.csv](kdash_kdash-local_kdash-e2e_20261119_210906/csv/cluster_ns.csv) | 730 |
| [kdash_kdash-local_kdash-e2e_20261119_210906/csv/containers.csv](kdash_kdash-local_kdash-e2e_20261119_210906/csv/containers.csv) | 1476 |
| [kdash_kdash-local_kdash-e2e_20261119_210906/csv/io_nodes.csv](kdash_kdash-local_kdash-e2e_20261119_210906/csv/io_nodes.csv) | 248 |
| [kdash_kdash-local_kdash-e2e_20261119_210906/csv/io_pods.csv](kdash_kdash-local_kdash-e2e_20261119_210906/csv/io_pods.csv) | 937 |
| [kdash_kdash-local_kdash-e2e_20261119_210906/csv/ip.csv](kdash_kdash-local_kdash-e2e_20261119_210906/csv/ip.csv) | 1773 |
| [kdash_kdash-local_kdash-e2e_20261119_210906/csv/ipblocks.csv](kdash_kdash-local_kdash-e2e_20261119_210906/csv/ipblocks.csv) | 195 |
| [kdash_kdash-local_kdash-e2e_20261119_210906/csv/memory.csv](kdash_kdash-local_kdash-e2e_20261119_210906/csv/memory.csv) | 1601 |
| [kdash_kdash-local_kdash-e2e_20261119_210906/csv/meta.csv](kdash_kdash-local_kdash-e2e_20261119_210906/csv/meta.csv) | 1275 |
| [kdash_kdash-local_kdash-e2e_20261119_210906/csv/nodes.csv](kdash_kdash-local_kdash-e2e_20261119_210906/csv/nodes.csv) | 721 |
| [kdash_kdash-local_kdash-e2e_20261119_210906/csv/pods.csv](kdash_kdash-local_kdash-e2e_20261119_210906/csv/pods.csv) | 3128 |
| [kdash_kdash-local_kdash-e2e_20261119_210906/csv/pools.csv](kdash_kdash-local_kdash-e2e_20261119_210906/csv/pools.csv) | 498 |
| [kdash_kdash-local_kdash-e2e_20261119_210906/csv/services.csv](kdash_kdash-local_kdash-e2e_20261119_210906/csv/services.csv) | 655 |
| [kdash_kdash-local_kdash-e2e_20261119_210906/csv/subnets.csv](kdash_kdash-local_kdash-e2e_20261119_210906/csv/subnets.csv) | 39 |
| [kdash_kdash-local_kdash-e2e_20261119_210906/csv/wl_node.csv](kdash_kdash-local_kdash-e2e_20261119_210906/csv/wl_node.csv) | 1213 |
| [kdash_kdash-local_kdash-e2e_20261119_210906/csv/workloads.csv](kdash_kdash-local_kdash-e2e_20261119_210906/csv/workloads.csv) | 1232 |
| [kdash_kdash-local_kdash-e2e_20261119_210906/diagnostics/events.tsv](kdash_kdash-local_kdash-e2e_20261119_210906/diagnostics/events.tsv) | 25536 |
| [kdash_kdash-local_kdash-e2e_20261119_210906/diagnostics/health-volume-usage.tsv](kdash_kdash-local_kdash-e2e_20261119_210906/diagnostics/health-volume-usage.tsv) | 0 |
| [kdash_kdash-local_kdash-e2e_20261119_210906/fmea.csv](kdash_kdash-local_kdash-e2e_20261119_210906/fmea.csv) | 9693 |
| [kdash_kdash-local_kdash-e2e_20261119_210906/report.html](kdash_kdash-local_kdash-e2e_20261119_210906/report.html) | 65997 |
| [kdash_kdash-local_kdash-e2e_20261119_210906/secrets.csv](kdash_kdash-local_kdash-e2e_20261119_210906/secrets.csv) | 1267 |
| [kdash_kdash-local_kdash-e2e_20261119_210906/secrets.json](kdash_kdash-local_kdash-e2e_20261119_210906/secrets.json) | 2777 |
| [kdash_kdash-local_kdash-e2e_20261119_210906/tsv/cluster_ns.tsv](kdash_kdash-local_kdash-e2e_20261119_210906/tsv/cluster_ns.tsv) | 730 |
| [kdash_kdash-local_kdash-e2e_20261119_210906/tsv/containers.tsv](kdash_kdash-local_kdash-e2e_20261119_210906/tsv/containers.tsv) | 1553 |
| [kdash_kdash-local_kdash-e2e_20261119_210906/tsv/io_nodes.tsv](kdash_kdash-local_kdash-e2e_20261119_210906/tsv/io_nodes.tsv) | 270 |
| [kdash_kdash-local_kdash-e2e_20261119_210906/tsv/io_pods.tsv](kdash_kdash-local_kdash-e2e_20261119_210906/tsv/io_pods.tsv) | 1039 |
| [kdash_kdash-local_kdash-e2e_20261119_210906/tsv/ip.tsv](kdash_kdash-local_kdash-e2e_20261119_210906/tsv/ip.tsv) | 1762 |
| [kdash_kdash-local_kdash-e2e_20261119_210906/tsv/ipblocks.tsv](kdash_kdash-local_kdash-e2e_20261119_210906/tsv/ipblocks.tsv) | 193 |
| [kdash_kdash-local_kdash-e2e_20261119_210906/tsv/memory.tsv](kdash_kdash-local_kdash-e2e_20261119_210906/tsv/memory.tsv) | 1633 |
| [kdash_kdash-local_kdash-e2e_20261119_210906/tsv/meta.tsv](kdash_kdash-local_kdash-e2e_20261119_210906/tsv/meta.tsv) | 1287 |
| [kdash_kdash-local_kdash-e2e_20261119_210906/tsv/nodes.tsv](kdash_kdash-local_kdash-e2e_20261119_210906/tsv/nodes.tsv) | 735 |
| [kdash_kdash-local_kdash-e2e_20261119_210906/tsv/pods.tsv](kdash_kdash-local_kdash-e2e_20261119_210906/tsv/pods.tsv) | 3160 |
| [kdash_kdash-local_kdash-e2e_20261119_210906/tsv/pools.tsv](kdash_kdash-local_kdash-e2e_20261119_210906/tsv/pools.tsv) | 504 |
| [kdash_kdash-local_kdash-e2e_20261119_210906/tsv/services.tsv](kdash_kdash-local_kdash-e2e_20261119_210906/tsv/services.tsv) | 679 |
| [kdash_kdash-local_kdash-e2e_20261119_210906/tsv/subnets.tsv](kdash_kdash-local_kdash-e2e_20261119_210906/tsv/subnets.tsv) | 39 |
| [kdash_kdash-local_kdash-e2e_20261119_210906/tsv/wl_node.tsv](kdash_kdash-local_kdash-e2e_20261119_210906/tsv/wl_node.tsv) | 1201 |
| [kdash_kdash-local_kdash-e2e_20261119_210906/tsv/workloads.tsv](kdash_kdash-local_kdash-e2e_20261119_210906/tsv/workloads.tsv) | 1330 |
| [kdash_kdash-local_kdash-e2e_20261119_210906.html](kdash_kdash-local_kdash-e2e_20261119_210906.html) | 65997 |
| [kdash_memory_dashboard_kdash-local_kdash-e2e_20261119_210903.html](kdash_memory_dashboard_kdash-local_kdash-e2e_20261119_210903.html) | 120424 |
| [kdash_memory_dashboard_kdash-local_kdash-e2e_20261119_210904.html](kdash_memory_dashboard_kdash-local_kdash-e2e_20261119_210904.html) | 120364 |
| [kdash_namespace_ip_pool_kdash-local_kdash-e2e_20261119_210903.html](kdash_namespace_ip_pool_kdash-local_kdash-e2e_20261119_210903.html) | 98170 |
| [kdash_namespace_report_kdash-local_kdash-e2e_20261119_210855.html](kdash_namespace_report_kdash-local_kdash-e2e_20261119_210855.html) | 425099 |
| [kdash_namespace_report_kdash-local_kdash-e2e_20261119_211350.html](kdash_namespace_report_kdash-local_kdash-e2e_20261119_211350.html) | 469774 |
| [kdash_namespace_report_kdash-local_kdash-e2e_20261119_211915.html](kdash_namespace_report_kdash-local_kdash-e2e_20261119_211915.html) | 398233 |
| [kdash_namespace_report_kdash-local_kdash-e2e_20261119_213856.html](kdash_namespace_report_kdash-local_kdash-e2e_20261119_213856.html) | 433155 |
| [kdash_network_disk_io_kdash-local_kdash-e2e_20261119_210903.html](kdash_network_disk_io_kdash-local_kdash-e2e_20261119_210903.html) | 75714 |
| [kdash_node_pools_worker_nodes_kdash-local_kdash-e2e_20261119_210903.html](kdash_node_pools_worker_nodes_kdash-local_kdash-e2e_20261119_210903.html) | 102915 |
| [kdash_node_pools_worker_nodes_kdash-local_kdash-e2e_20261119_210904.html](kdash_node_pools_worker_nodes_kdash-local_kdash-e2e_20261119_210904.html) | 102855 |
| [kdash_pod_container_resources_kdash-local_kdash-e2e_20261119_210903.html](kdash_pod_container_resources_kdash-local_kdash-e2e_20261119_210903.html) | 148273 |
| [kdash_workloads_per_worker_node_kdash-local_kdash-e2e_20261119_210903.html](kdash_workloads_per_worker_node_kdash-local_kdash-e2e_20261119_210903.html) | 114250 |
| [screenshots/combined-fmea.png](screenshots/combined-fmea.png) | 325506 |
| [screenshots/combined-secrets.png](screenshots/combined-secrets.png) | 163660 |
| [screenshots/fmea.png](screenshots/fmea.png) | 113377 |
| [screenshots/history.png](screenshots/history.png) | 136585 |
| [screenshots/io.png](screenshots/io.png) | 124542 |
| [screenshots/ip.png](screenshots/ip.png) | 177884 |
| [screenshots/mem.png](screenshots/mem.png) | 176608 |
| [screenshots/nodes.png](screenshots/nodes.png) | 184355 |
| [screenshots/overview.png](screenshots/overview.png) | 239627 |
| [screenshots/pods.png](screenshots/pods.png) | 219563 |
| [screenshots/secrets.png](screenshots/secrets.png) | 121172 |
| [screenshots/workloads.png](screenshots/workloads.png) | 193264 |
| [secrets/secrets/secrets_kdash-local_kdash-e2e_20261119_213749.html](secrets/secrets/secrets_kdash-local_kdash-e2e_20261119_213749.html) | 9147 |
| [with-extras/fmea/runs/kdash-local_kdash-e2e/20261119221835.tsv](with-extras/fmea/runs/kdash-local_kdash-e2e/20261119221835.tsv) | 1598 |
| [with-extras/kdash_kdash-local_kdash-e2e_20261119_221827/csv/cluster_ns.csv](with-extras/kdash_kdash-local_kdash-e2e_20261119_221827/csv/cluster_ns.csv) | 728 |
| [with-extras/kdash_kdash-local_kdash-e2e_20261119_221827/csv/containers.csv](with-extras/kdash_kdash-local_kdash-e2e_20261119_221827/csv/containers.csv) | 1585 |
| [with-extras/kdash_kdash-local_kdash-e2e_20261119_221827/csv/ip.csv](with-extras/kdash_kdash-local_kdash-e2e_20261119_221827/csv/ip.csv) | 1906 |
| [with-extras/kdash_kdash-local_kdash-e2e_20261119_221827/csv/ipblocks.csv](with-extras/kdash_kdash-local_kdash-e2e_20261119_221827/csv/ipblocks.csv) | 195 |
| [with-extras/kdash_kdash-local_kdash-e2e_20261119_221827/csv/memory.csv](with-extras/kdash_kdash-local_kdash-e2e_20261119_221827/csv/memory.csv) | 1714 |
| [with-extras/kdash_kdash-local_kdash-e2e_20261119_221827/csv/meta.csv](with-extras/kdash_kdash-local_kdash-e2e_20261119_221827/csv/meta.csv) | 1128 |
| [with-extras/kdash_kdash-local_kdash-e2e_20261119_221827/csv/nodes.csv](with-extras/kdash_kdash-local_kdash-e2e_20261119_221827/csv/nodes.csv) | 721 |
| [with-extras/kdash_kdash-local_kdash-e2e_20261119_221827/csv/pods.csv](with-extras/kdash_kdash-local_kdash-e2e_20261119_221827/csv/pods.csv) | 3345 |
| [with-extras/kdash_kdash-local_kdash-e2e_20261119_221827/csv/pools.csv](with-extras/kdash_kdash-local_kdash-e2e_20261119_221827/csv/pools.csv) | 498 |
| [with-extras/kdash_kdash-local_kdash-e2e_20261119_221827/csv/services.csv](with-extras/kdash_kdash-local_kdash-e2e_20261119_221827/csv/services.csv) | 718 |
| [with-extras/kdash_kdash-local_kdash-e2e_20261119_221827/csv/subnets.csv](with-extras/kdash_kdash-local_kdash-e2e_20261119_221827/csv/subnets.csv) | 39 |
| [with-extras/kdash_kdash-local_kdash-e2e_20261119_221827/csv/wl_node.csv](with-extras/kdash_kdash-local_kdash-e2e_20261119_221827/csv/wl_node.csv) | 1318 |
| [with-extras/kdash_kdash-local_kdash-e2e_20261119_221827/csv/workloads.csv](with-extras/kdash_kdash-local_kdash-e2e_20261119_221827/csv/workloads.csv) | 1308 |
| [with-extras/kdash_kdash-local_kdash-e2e_20261119_221827/diagnostics/events.tsv](with-extras/kdash_kdash-local_kdash-e2e_20261119_221827/diagnostics/events.tsv) | 16171 |
| [with-extras/kdash_kdash-local_kdash-e2e_20261119_221827/diagnostics/health-volume-usage.tsv](with-extras/kdash_kdash-local_kdash-e2e_20261119_221827/diagnostics/health-volume-usage.tsv) | 0 |
| [with-extras/kdash_kdash-local_kdash-e2e_20261119_221827/fmea.csv](with-extras/kdash_kdash-local_kdash-e2e_20261119_221827/fmea.csv) | 10290 |
| [with-extras/kdash_kdash-local_kdash-e2e_20261119_221827/report.html](with-extras/kdash_kdash-local_kdash-e2e_20261119_221827/report.html) | 69083 |
| [with-extras/kdash_kdash-local_kdash-e2e_20261119_221827/secrets.csv](with-extras/kdash_kdash-local_kdash-e2e_20261119_221827/secrets.csv) | 2325 |
| [with-extras/kdash_kdash-local_kdash-e2e_20261119_221827/secrets.json](with-extras/kdash_kdash-local_kdash-e2e_20261119_221827/secrets.json) | 5297 |
| [with-extras/kdash_kdash-local_kdash-e2e_20261119_221827/tsv/cluster_ns.tsv](with-extras/kdash_kdash-local_kdash-e2e_20261119_221827/tsv/cluster_ns.tsv) | 728 |
| [with-extras/kdash_kdash-local_kdash-e2e_20261119_221827/tsv/containers.tsv](with-extras/kdash_kdash-local_kdash-e2e_20261119_221827/tsv/containers.tsv) | 1663 |
| [with-extras/kdash_kdash-local_kdash-e2e_20261119_221827/tsv/ip.tsv](with-extras/kdash_kdash-local_kdash-e2e_20261119_221827/tsv/ip.tsv) | 1894 |
| [with-extras/kdash_kdash-local_kdash-e2e_20261119_221827/tsv/ipblocks.tsv](with-extras/kdash_kdash-local_kdash-e2e_20261119_221827/tsv/ipblocks.tsv) | 193 |
| [with-extras/kdash_kdash-local_kdash-e2e_20261119_221827/tsv/memory.tsv](with-extras/kdash_kdash-local_kdash-e2e_20261119_221827/tsv/memory.tsv) | 1746 |
| [with-extras/kdash_kdash-local_kdash-e2e_20261119_221827/tsv/meta.tsv](with-extras/kdash_kdash-local_kdash-e2e_20261119_221827/tsv/meta.tsv) | 1131 |
| [with-extras/kdash_kdash-local_kdash-e2e_20261119_221827/tsv/nodes.tsv](with-extras/kdash_kdash-local_kdash-e2e_20261119_221827/tsv/nodes.tsv) | 735 |
| [with-extras/kdash_kdash-local_kdash-e2e_20261119_221827/tsv/pods.tsv](with-extras/kdash_kdash-local_kdash-e2e_20261119_221827/tsv/pods.tsv) | 3376 |
| [with-extras/kdash_kdash-local_kdash-e2e_20261119_221827/tsv/pools.tsv](with-extras/kdash_kdash-local_kdash-e2e_20261119_221827/tsv/pools.tsv) | 504 |
| [with-extras/kdash_kdash-local_kdash-e2e_20261119_221827/tsv/services.tsv](with-extras/kdash_kdash-local_kdash-e2e_20261119_221827/tsv/services.tsv) | 744 |
| [with-extras/kdash_kdash-local_kdash-e2e_20261119_221827/tsv/subnets.tsv](with-extras/kdash_kdash-local_kdash-e2e_20261119_221827/tsv/subnets.tsv) | 39 |
| [with-extras/kdash_kdash-local_kdash-e2e_20261119_221827/tsv/wl_node.tsv](with-extras/kdash_kdash-local_kdash-e2e_20261119_221827/tsv/wl_node.tsv) | 1304 |
| [with-extras/kdash_kdash-local_kdash-e2e_20261119_221827/tsv/workloads.tsv](with-extras/kdash_kdash-local_kdash-e2e_20261119_221827/tsv/workloads.tsv) | 1414 |
| [with-extras/kdash_kdash-local_kdash-e2e_20261119_221827.html](with-extras/kdash_kdash-local_kdash-e2e_20261119_221827.html) | 69083 |

Representative quick-export logs are under `exports/`. Multi-megabyte full-log
search dumps are recorded by the run checks and raw captures but are not committed
here. Published text replaces the validation host operator identity with
`operator@validation-host`; cluster data is unchanged.

Verify the published bytes with `sha256sum -c SHA256SUMS` in this directory.
Keep the relative filenames together when sharing. Review operational metadata
before distributing reports. Historical reports retain their original capture
version: [4.19.2](../html419/README.md), [4.23.1](../html423/README.md), [4.24.1](../html4241/README.md), [4.27.3](../html4273/README.md), [4.27.4](../html4274/README.md), [4.32.0](../html4320/README.md), [4.12.0](../html/).
