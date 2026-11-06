# kdash 4.23.2 live WSL HTML reports

The files in this directory come from the generated reports of
[`live-e2e-20261106-162543`](../../artifacts/live-e2e-20261106-162543), running the installed kdash 4.23.2 against local WSL
Kubernetes. The [results](../../artifacts/live-e2e-20261106-162543/results.json) and [checks](../../artifacts/live-e2e-20261106-162543/checks.tsv)
record export validation; the [terminal gallery](../cli_4232/README.md) records
the corresponding live interface.

The namespace report includes Overview, six resource tabs and recorded History.
CLI Alerts appear in the Overview; Services, Storage, Events and explanations are
preserved in the evidence bundle's diagnostic text/tables rather than extra
namespace HTML tabs. Missing metrics remain unavailable instead of becoming zero.
Reports are self-contained for local viewing and include table search/sort,
CSV/JSON export, themes, timezone selection and chart controls where data exists.

| File | Bytes |
|---|---:|
| [index.html](index.html) | 2711 |
| [kdash_audit_20261106_220347.csv](kdash_audit_20261106_220347.csv) | 131841 |
| [kdash_audit_20261106_220347.html](kdash_audit_20261106_220347.html) | 300437 |
| [kdash_kdash-local_kdash-e2e_20261106_215610/csv/cluster_ns.csv](kdash_kdash-local_kdash-e2e_20261106_215610/csv/cluster_ns.csv) | 662 |
| [kdash_kdash-local_kdash-e2e_20261106_215610/csv/containers.csv](kdash_kdash-local_kdash-e2e_20261106_215610/csv/containers.csv) | 667 |
| [kdash_kdash-local_kdash-e2e_20261106_215610/csv/io_nodes.csv](kdash_kdash-local_kdash-e2e_20261106_215610/csv/io_nodes.csv) | 247 |
| [kdash_kdash-local_kdash-e2e_20261106_215610/csv/io_pods.csv](kdash_kdash-local_kdash-e2e_20261106_215610/csv/io_pods.csv) | 330 |
| [kdash_kdash-local_kdash-e2e_20261106_215610/csv/ip.csv](kdash_kdash-local_kdash-e2e_20261106_215610/csv/ip.csv) | 547 |
| [kdash_kdash-local_kdash-e2e_20261106_215610/csv/ipblocks.csv](kdash_kdash-local_kdash-e2e_20261106_215610/csv/ipblocks.csv) | 180 |
| [kdash_kdash-local_kdash-e2e_20261106_215610/csv/memory.csv](kdash_kdash-local_kdash-e2e_20261106_215610/csv/memory.csv) | 530 |
| [kdash_kdash-local_kdash-e2e_20261106_215610/csv/meta.csv](kdash_kdash-local_kdash-e2e_20261106_215610/csv/meta.csv) | 1198 |
| [kdash_kdash-local_kdash-e2e_20261106_215610/csv/nodes.csv](kdash_kdash-local_kdash-e2e_20261106_215610/csv/nodes.csv) | 690 |
| [kdash_kdash-local_kdash-e2e_20261106_215610/csv/pods.csv](kdash_kdash-local_kdash-e2e_20261106_215610/csv/pods.csv) | 1053 |
| [kdash_kdash-local_kdash-e2e_20261106_215610/csv/pools.csv](kdash_kdash-local_kdash-e2e_20261106_215610/csv/pools.csv) | 483 |
| [kdash_kdash-local_kdash-e2e_20261106_215610/csv/services.csv](kdash_kdash-local_kdash-e2e_20261106_215610/csv/services.csv) | 178 |
| [kdash_kdash-local_kdash-e2e_20261106_215610/csv/subnets.csv](kdash_kdash-local_kdash-e2e_20261106_215610/csv/subnets.csv) | 38 |
| [kdash_kdash-local_kdash-e2e_20261106_215610/csv/wl_node.csv](kdash_kdash-local_kdash-e2e_20261106_215610/csv/wl_node.csv) | 418 |
| [kdash_kdash-local_kdash-e2e_20261106_215610/csv/workloads.csv](kdash_kdash-local_kdash-e2e_20261106_215610/csv/workloads.csv) | 513 |
| [kdash_kdash-local_kdash-e2e_20261106_215610/report.html](kdash_kdash-local_kdash-e2e_20261106_215610/report.html) | 35186 |
| [kdash_kdash-local_kdash-e2e_20261106_215610.html](kdash_kdash-local_kdash-e2e_20261106_215610.html) | 35186 |
| [kdash_memory_dashboard_kdash-local_kdash-e2e_20261106_215607.html](kdash_memory_dashboard_kdash-local_kdash-e2e_20261106_215607.html) | 92615 |
| [kdash_memory_dashboard_kdash-local_kdash-e2e_20261106_215609.html](kdash_memory_dashboard_kdash-local_kdash-e2e_20261106_215609.html) | 92555 |
| [kdash_namespace_ip_pool_kdash-local_kdash-e2e_20261106_215607.html](kdash_namespace_ip_pool_kdash-local_kdash-e2e_20261106_215607.html) | 78615 |
| [kdash_namespace_report_kdash-local_kdash-e2e_20261106_215606.html](kdash_namespace_report_kdash-local_kdash-e2e_20261106_215606.html) | 237764 |
| [kdash_namespace_report_kdash-local_kdash-e2e_20261106_215922.html](kdash_namespace_report_kdash-local_kdash-e2e_20261106_215922.html) | 279460 |
| [kdash_namespace_report_kdash-local_kdash-e2e_20261106_220346.html](kdash_namespace_report_kdash-local_kdash-e2e_20261106_220346.html) | 241313 |
| [kdash_network_disk_io_kdash-local_kdash-e2e_20261106_215607.html](kdash_network_disk_io_kdash-local_kdash-e2e_20261106_215607.html) | 68333 |
| [kdash_node_pools_worker_nodes_kdash-local_kdash-e2e_20261106_215607.html](kdash_node_pools_worker_nodes_kdash-local_kdash-e2e_20261106_215607.html) | 99399 |
| [kdash_node_pools_worker_nodes_kdash-local_kdash-e2e_20261106_215609.html](kdash_node_pools_worker_nodes_kdash-local_kdash-e2e_20261106_215609.html) | 99352 |
| [kdash_pod_container_resources_kdash-local_kdash-e2e_20261106_215607.html](kdash_pod_container_resources_kdash-local_kdash-e2e_20261106_215607.html) | 93677 |
| [kdash_workloads_per_worker_node_kdash-local_kdash-e2e_20261106_215607.html](kdash_workloads_per_worker_node_kdash-local_kdash-e2e_20261106_215607.html) | 82475 |
| [screenshots/history.png](screenshots/history.png) | 179730 |
| [screenshots/io.png](screenshots/io.png) | 192668 |
| [screenshots/ip.png](screenshots/ip.png) | 179896 |
| [screenshots/mem.png](screenshots/mem.png) | 162207 |
| [screenshots/nodes.png](screenshots/nodes.png) | 171554 |
| [screenshots/overview.png](screenshots/overview.png) | 226646 |
| [screenshots/pods.png](screenshots/pods.png) | 182670 |
| [screenshots/workloads.png](screenshots/workloads.png) | 171823 |

Verify the published bytes with `sha256sum -c SHA256SUMS` in this directory.
Keep the relative filenames together when sharing. Review operational metadata
before distributing reports. Historical reports retain their original capture
version: [4.19.2](../html419/README.md), [4.23.1](../html423/README.md), [4.12.0](../html/).
