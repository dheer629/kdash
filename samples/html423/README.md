# kdash 4.23.1 live WSL HTML reports

The files in this directory come from the generated reports of
[`live-e2e-20261106-v4231`](../../artifacts/live-e2e-20261106-v4231), running the installed kdash 4.23.1 against local WSL
Kubernetes. The [results](../../artifacts/live-e2e-20261106-v4231/results.json) and [checks](../../artifacts/live-e2e-20261106-v4231/checks.tsv)
record export validation; the [terminal gallery](../cli_423/README.md) records
the corresponding live interface.

The namespace report includes Overview, six resource tabs and recorded History.
CLI Alerts appear in the Overview; Services, Storage, Events and explanations are
preserved in the evidence bundle's diagnostic text/tables rather than extra
namespace HTML tabs. Missing metrics remain unavailable instead of becoming zero.
Reports are self-contained for local viewing and include table search/sort,
CSV/JSON export, themes, timezone selection and chart controls where data exists.

| File | Bytes |
|---|---:|
| [index.html](index.html) | 2712 |
| [kdash_audit_20261106_182524.csv](kdash_audit_20261106_182524.csv) | 129620 |
| [kdash_audit_20261106_182524.html](kdash_audit_20261106_182524.html) | 296583 |
| [kdash_kdash-local_kdash-e2e_20261106_181826/csv/cluster_ns.csv](kdash_kdash-local_kdash-e2e_20261106_181826/csv/cluster_ns.csv) | 661 |
| [kdash_kdash-local_kdash-e2e_20261106_181826/csv/containers.csv](kdash_kdash-local_kdash-e2e_20261106_181826/csv/containers.csv) | 666 |
| [kdash_kdash-local_kdash-e2e_20261106_181826/csv/io_nodes.csv](kdash_kdash-local_kdash-e2e_20261106_181826/csv/io_nodes.csv) | 247 |
| [kdash_kdash-local_kdash-e2e_20261106_181826/csv/io_pods.csv](kdash_kdash-local_kdash-e2e_20261106_181826/csv/io_pods.csv) | 330 |
| [kdash_kdash-local_kdash-e2e_20261106_181826/csv/ip.csv](kdash_kdash-local_kdash-e2e_20261106_181826/csv/ip.csv) | 547 |
| [kdash_kdash-local_kdash-e2e_20261106_181826/csv/ipblocks.csv](kdash_kdash-local_kdash-e2e_20261106_181826/csv/ipblocks.csv) | 180 |
| [kdash_kdash-local_kdash-e2e_20261106_181826/csv/memory.csv](kdash_kdash-local_kdash-e2e_20261106_181826/csv/memory.csv) | 529 |
| [kdash_kdash-local_kdash-e2e_20261106_181826/csv/meta.csv](kdash_kdash-local_kdash-e2e_20261106_181826/csv/meta.csv) | 1197 |
| [kdash_kdash-local_kdash-e2e_20261106_181826/csv/nodes.csv](kdash_kdash-local_kdash-e2e_20261106_181826/csv/nodes.csv) | 689 |
| [kdash_kdash-local_kdash-e2e_20261106_181826/csv/pods.csv](kdash_kdash-local_kdash-e2e_20261106_181826/csv/pods.csv) | 1052 |
| [kdash_kdash-local_kdash-e2e_20261106_181826/csv/pools.csv](kdash_kdash-local_kdash-e2e_20261106_181826/csv/pools.csv) | 483 |
| [kdash_kdash-local_kdash-e2e_20261106_181826/csv/services.csv](kdash_kdash-local_kdash-e2e_20261106_181826/csv/services.csv) | 178 |
| [kdash_kdash-local_kdash-e2e_20261106_181826/csv/subnets.csv](kdash_kdash-local_kdash-e2e_20261106_181826/csv/subnets.csv) | 38 |
| [kdash_kdash-local_kdash-e2e_20261106_181826/csv/wl_node.csv](kdash_kdash-local_kdash-e2e_20261106_181826/csv/wl_node.csv) | 417 |
| [kdash_kdash-local_kdash-e2e_20261106_181826/csv/workloads.csv](kdash_kdash-local_kdash-e2e_20261106_181826/csv/workloads.csv) | 512 |
| [kdash_kdash-local_kdash-e2e_20261106_181826/report.html](kdash_kdash-local_kdash-e2e_20261106_181826/report.html) | 35173 |
| [kdash_kdash-local_kdash-e2e_20261106_181826.html](kdash_kdash-local_kdash-e2e_20261106_181826.html) | 35173 |
| [kdash_memory_dashboard_kdash-local_kdash-e2e_20261106_181825.html](kdash_memory_dashboard_kdash-local_kdash-e2e_20261106_181825.html) | 92600 |
| [kdash_memory_dashboard_kdash-local_kdash-e2e_20261106_181826.html](kdash_memory_dashboard_kdash-local_kdash-e2e_20261106_181826.html) | 92540 |
| [kdash_namespace_ip_pool_kdash-local_kdash-e2e_20261106_181825.html](kdash_namespace_ip_pool_kdash-local_kdash-e2e_20261106_181825.html) | 78612 |
| [kdash_namespace_report_kdash-local_kdash-e2e_20261106_181824.html](kdash_namespace_report_kdash-local_kdash-e2e_20261106_181824.html) | 237721 |
| [kdash_namespace_report_kdash-local_kdash-e2e_20261106_182113.html](kdash_namespace_report_kdash-local_kdash-e2e_20261106_182113.html) | 278541 |
| [kdash_namespace_report_kdash-local_kdash-e2e_20261106_182523.html](kdash_namespace_report_kdash-local_kdash-e2e_20261106_182523.html) | 241257 |
| [kdash_network_disk_io_kdash-local_kdash-e2e_20261106_181825.html](kdash_network_disk_io_kdash-local_kdash-e2e_20261106_181825.html) | 68330 |
| [kdash_node_pools_worker_nodes_kdash-local_kdash-e2e_20261106_181825.html](kdash_node_pools_worker_nodes_kdash-local_kdash-e2e_20261106_181825.html) | 99399 |
| [kdash_node_pools_worker_nodes_kdash-local_kdash-e2e_20261106_181826.html](kdash_node_pools_worker_nodes_kdash-local_kdash-e2e_20261106_181826.html) | 99339 |
| [kdash_pod_container_resources_kdash-local_kdash-e2e_20261106_181825.html](kdash_pod_container_resources_kdash-local_kdash-e2e_20261106_181825.html) | 93663 |
| [kdash_workloads_per_worker_node_kdash-local_kdash-e2e_20261106_181825.html](kdash_workloads_per_worker_node_kdash-local_kdash-e2e_20261106_181825.html) | 82462 |
| [screenshots/history.png](screenshots/history.png) | 180139 |
| [screenshots/io.png](screenshots/io.png) | 186727 |
| [screenshots/ip.png](screenshots/ip.png) | 180557 |
| [screenshots/mem.png](screenshots/mem.png) | 173044 |
| [screenshots/nodes.png](screenshots/nodes.png) | 177321 |
| [screenshots/overview.png](screenshots/overview.png) | 219047 |
| [screenshots/pods.png](screenshots/pods.png) | 181862 |
| [screenshots/workloads.png](screenshots/workloads.png) | 176282 |

Verify the published bytes with `sha256sum -c SHA256SUMS` in this directory.
Keep the relative filenames together when sharing. Review operational metadata
before distributing reports. Historical [4.19.2 reports](../html419/README.md)
and [4.12.0 reports](../html/) retain their original capture version.
