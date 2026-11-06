# kdash 4.24.1 live WSL HTML reports

The files in this directory come from the generated reports of
[`live-e2e-20261106-183122`](../../artifacts/live-e2e-20261106-183122), running the installed kdash 4.24.1 against local WSL
Kubernetes. The [results](../../artifacts/live-e2e-20261106-183122/results.json) and [checks](../../artifacts/live-e2e-20261106-183122/checks.tsv)
record export validation; the [terminal gallery](../cli_4241/README.md) records
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
| [kdash_audit_20261107_000925.csv](kdash_audit_20261107_000925.csv) | 132852 |
| [kdash_audit_20261107_000925.html](kdash_audit_20261107_000925.html) | 302591 |
| [kdash_kdash-local_kdash-e2e_20261107_000148/csv/cluster_ns.csv](kdash_kdash-local_kdash-e2e_20261107_000148/csv/cluster_ns.csv) | 660 |
| [kdash_kdash-local_kdash-e2e_20261107_000148/csv/containers.csv](kdash_kdash-local_kdash-e2e_20261107_000148/csv/containers.csv) | 667 |
| [kdash_kdash-local_kdash-e2e_20261107_000148/csv/io_nodes.csv](kdash_kdash-local_kdash-e2e_20261107_000148/csv/io_nodes.csv) | 247 |
| [kdash_kdash-local_kdash-e2e_20261107_000148/csv/io_pods.csv](kdash_kdash-local_kdash-e2e_20261107_000148/csv/io_pods.csv) | 330 |
| [kdash_kdash-local_kdash-e2e_20261107_000148/csv/ip.csv](kdash_kdash-local_kdash-e2e_20261107_000148/csv/ip.csv) | 547 |
| [kdash_kdash-local_kdash-e2e_20261107_000148/csv/ipblocks.csv](kdash_kdash-local_kdash-e2e_20261107_000148/csv/ipblocks.csv) | 180 |
| [kdash_kdash-local_kdash-e2e_20261107_000148/csv/memory.csv](kdash_kdash-local_kdash-e2e_20261107_000148/csv/memory.csv) | 530 |
| [kdash_kdash-local_kdash-e2e_20261107_000148/csv/meta.csv](kdash_kdash-local_kdash-e2e_20261107_000148/csv/meta.csv) | 1198 |
| [kdash_kdash-local_kdash-e2e_20261107_000148/csv/nodes.csv](kdash_kdash-local_kdash-e2e_20261107_000148/csv/nodes.csv) | 690 |
| [kdash_kdash-local_kdash-e2e_20261107_000148/csv/pods.csv](kdash_kdash-local_kdash-e2e_20261107_000148/csv/pods.csv) | 1053 |
| [kdash_kdash-local_kdash-e2e_20261107_000148/csv/pools.csv](kdash_kdash-local_kdash-e2e_20261107_000148/csv/pools.csv) | 483 |
| [kdash_kdash-local_kdash-e2e_20261107_000148/csv/services.csv](kdash_kdash-local_kdash-e2e_20261107_000148/csv/services.csv) | 178 |
| [kdash_kdash-local_kdash-e2e_20261107_000148/csv/subnets.csv](kdash_kdash-local_kdash-e2e_20261107_000148/csv/subnets.csv) | 38 |
| [kdash_kdash-local_kdash-e2e_20261107_000148/csv/wl_node.csv](kdash_kdash-local_kdash-e2e_20261107_000148/csv/wl_node.csv) | 418 |
| [kdash_kdash-local_kdash-e2e_20261107_000148/csv/workloads.csv](kdash_kdash-local_kdash-e2e_20261107_000148/csv/workloads.csv) | 513 |
| [kdash_kdash-local_kdash-e2e_20261107_000148/report.html](kdash_kdash-local_kdash-e2e_20261107_000148/report.html) | 35186 |
| [kdash_kdash-local_kdash-e2e_20261107_000148.html](kdash_kdash-local_kdash-e2e_20261107_000148.html) | 35186 |
| [kdash_memory_dashboard_kdash-local_kdash-e2e_20261107_000145.html](kdash_memory_dashboard_kdash-local_kdash-e2e_20261107_000145.html) | 92625 |
| [kdash_memory_dashboard_kdash-local_kdash-e2e_20261107_000147.html](kdash_memory_dashboard_kdash-local_kdash-e2e_20261107_000147.html) | 92565 |
| [kdash_namespace_ip_pool_kdash-local_kdash-e2e_20261107_000145.html](kdash_namespace_ip_pool_kdash-local_kdash-e2e_20261107_000145.html) | 78623 |
| [kdash_namespace_report_kdash-local_kdash-e2e_20261107_000144.html](kdash_namespace_report_kdash-local_kdash-e2e_20261107_000144.html) | 237844 |
| [kdash_namespace_report_kdash-local_kdash-e2e_20261107_000459.html](kdash_namespace_report_kdash-local_kdash-e2e_20261107_000459.html) | 276465 |
| [kdash_namespace_report_kdash-local_kdash-e2e_20261107_000924.html](kdash_namespace_report_kdash-local_kdash-e2e_20261107_000924.html) | 241364 |
| [kdash_network_disk_io_kdash-local_kdash-e2e_20261107_000145.html](kdash_network_disk_io_kdash-local_kdash-e2e_20261107_000145.html) | 68341 |
| [kdash_node_pools_worker_nodes_kdash-local_kdash-e2e_20261107_000145.html](kdash_node_pools_worker_nodes_kdash-local_kdash-e2e_20261107_000145.html) | 99412 |
| [kdash_node_pools_worker_nodes_kdash-local_kdash-e2e_20261107_000147.html](kdash_node_pools_worker_nodes_kdash-local_kdash-e2e_20261107_000147.html) | 99352 |
| [kdash_pod_container_resources_kdash-local_kdash-e2e_20261107_000145.html](kdash_pod_container_resources_kdash-local_kdash-e2e_20261107_000145.html) | 93710 |
| [kdash_workloads_per_worker_node_kdash-local_kdash-e2e_20261107_000145.html](kdash_workloads_per_worker_node_kdash-local_kdash-e2e_20261107_000145.html) | 82483 |
| [screenshots/history.png](screenshots/history.png) | 171819 |
| [screenshots/io.png](screenshots/io.png) | 191457 |
| [screenshots/ip.png](screenshots/ip.png) | 176291 |
| [screenshots/mem.png](screenshots/mem.png) | 173514 |
| [screenshots/nodes.png](screenshots/nodes.png) | 172928 |
| [screenshots/overview.png](screenshots/overview.png) | 219807 |
| [screenshots/pods.png](screenshots/pods.png) | 182732 |
| [screenshots/workloads.png](screenshots/workloads.png) | 173994 |

Verify the published bytes with `sha256sum -c SHA256SUMS` in this directory.
Keep the relative filenames together when sharing. Review operational metadata
before distributing reports. Historical reports retain their original capture
version: [4.19.2](../html419/README.md), [4.23.1](../html423/README.md), [4.12.0](../html/).
