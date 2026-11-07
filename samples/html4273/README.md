# kdash 4.27.3 live WSL HTML reports

The files in this directory come from the generated reports of
[`live-e2e-20261107-054006`](../../artifacts/live-e2e-20261107-054006), running the installed kdash 4.27.3 against local WSL
Kubernetes. The [results](../../artifacts/live-e2e-20261107-054006/results.json) and [checks](../../artifacts/live-e2e-20261107-054006/checks.tsv)
record export validation; the [terminal gallery](../cli_4273/README.md) records
the corresponding live interface.

The namespace report includes Overview, six resource tabs and recorded History.
CLI Alerts appear in the Overview; Services, Storage, Events and explanations are
preserved in the evidence bundle's diagnostic text/tables rather than extra
namespace HTML tabs. Missing metrics remain unavailable instead of becoming zero.
Reports are self-contained for local viewing and include table search/sort,
CSV/JSON export, themes, timezone selection and chart controls where data exists.

| File | Bytes |
|---|---:|
| [index.html](index.html) | 2903 |
| [kdash_audit_20261107_111806.csv](kdash_audit_20261107_111806.csv) | 143423 |
| [kdash_audit_20261107_111806.html](kdash_audit_20261107_111806.html) | 324965 |
| [kdash_memory_dashboard_vcluster-docker_dev_kdash-e2e_20261107_111030.html](kdash_memory_dashboard_vcluster-docker_dev_kdash-e2e_20261107_111030.html) | 92708 |
| [kdash_memory_dashboard_vcluster-docker_dev_kdash-e2e_20261107_111031.html](kdash_memory_dashboard_vcluster-docker_dev_kdash-e2e_20261107_111031.html) | 92616 |
| [kdash_namespace_ip_pool_vcluster-docker_dev_kdash-e2e_20261107_111030.html](kdash_namespace_ip_pool_vcluster-docker_dev_kdash-e2e_20261107_111030.html) | 78696 |
| [kdash_namespace_report_vcluster-docker_dev_kdash-e2e_20261107_111029.html](kdash_namespace_report_vcluster-docker_dev_kdash-e2e_20261107_111029.html) | 237953 |
| [kdash_namespace_report_vcluster-docker_dev_kdash-e2e_20261107_111343.html](kdash_namespace_report_vcluster-docker_dev_kdash-e2e_20261107_111343.html) | 280375 |
| [kdash_namespace_report_vcluster-docker_dev_kdash-e2e_20261107_111806.html](kdash_namespace_report_vcluster-docker_dev_kdash-e2e_20261107_111806.html) | 241562 |
| [kdash_network_disk_io_vcluster-docker_dev_kdash-e2e_20261107_111030.html](kdash_network_disk_io_vcluster-docker_dev_kdash-e2e_20261107_111030.html) | 68414 |
| [kdash_node_pools_worker_nodes_vcluster-docker_dev_kdash-e2e_20261107_111030.html](kdash_node_pools_worker_nodes_vcluster-docker_dev_kdash-e2e_20261107_111030.html) | 99493 |
| [kdash_node_pools_worker_nodes_vcluster-docker_dev_kdash-e2e_20261107_111031.html](kdash_node_pools_worker_nodes_vcluster-docker_dev_kdash-e2e_20261107_111031.html) | 99401 |
| [kdash_pod_container_resources_vcluster-docker_dev_kdash-e2e_20261107_111030.html](kdash_pod_container_resources_vcluster-docker_dev_kdash-e2e_20261107_111030.html) | 93773 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261107_111033/csv/cluster_ns.csv](kdash_vcluster-docker_dev_kdash-e2e_20261107_111033/csv/cluster_ns.csv) | 661 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261107_111033/csv/containers.csv](kdash_vcluster-docker_dev_kdash-e2e_20261107_111033/csv/containers.csv) | 668 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261107_111033/csv/io_nodes.csv](kdash_vcluster-docker_dev_kdash-e2e_20261107_111033/csv/io_nodes.csv) | 247 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261107_111033/csv/io_pods.csv](kdash_vcluster-docker_dev_kdash-e2e_20261107_111033/csv/io_pods.csv) | 330 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261107_111033/csv/ip.csv](kdash_vcluster-docker_dev_kdash-e2e_20261107_111033/csv/ip.csv) | 547 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261107_111033/csv/ipblocks.csv](kdash_vcluster-docker_dev_kdash-e2e_20261107_111033/csv/ipblocks.csv) | 180 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261107_111033/csv/memory.csv](kdash_vcluster-docker_dev_kdash-e2e_20261107_111033/csv/memory.csv) | 531 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261107_111033/csv/meta.csv](kdash_vcluster-docker_dev_kdash-e2e_20261107_111033/csv/meta.csv) | 1199 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261107_111033/csv/nodes.csv](kdash_vcluster-docker_dev_kdash-e2e_20261107_111033/csv/nodes.csv) | 691 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261107_111033/csv/pods.csv](kdash_vcluster-docker_dev_kdash-e2e_20261107_111033/csv/pods.csv) | 1054 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261107_111033/csv/pools.csv](kdash_vcluster-docker_dev_kdash-e2e_20261107_111033/csv/pools.csv) | 483 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261107_111033/csv/services.csv](kdash_vcluster-docker_dev_kdash-e2e_20261107_111033/csv/services.csv) | 178 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261107_111033/csv/subnets.csv](kdash_vcluster-docker_dev_kdash-e2e_20261107_111033/csv/subnets.csv) | 38 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261107_111033/csv/wl_node.csv](kdash_vcluster-docker_dev_kdash-e2e_20261107_111033/csv/wl_node.csv) | 419 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261107_111033/csv/workloads.csv](kdash_vcluster-docker_dev_kdash-e2e_20261107_111033/csv/workloads.csv) | 514 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261107_111033/report.html](kdash_vcluster-docker_dev_kdash-e2e_20261107_111033/report.html) | 35215 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261107_111033.html](kdash_vcluster-docker_dev_kdash-e2e_20261107_111033.html) | 35215 |
| [kdash_workloads_per_worker_node_vcluster-docker_dev_kdash-e2e_20261107_111030.html](kdash_workloads_per_worker_node_vcluster-docker_dev_kdash-e2e_20261107_111030.html) | 82566 |
| [screenshots/history.png](screenshots/history.png) | 180858 |
| [screenshots/io.png](screenshots/io.png) | 195253 |
| [screenshots/ip.png](screenshots/ip.png) | 179900 |
| [screenshots/mem.png](screenshots/mem.png) | 180382 |
| [screenshots/nodes.png](screenshots/nodes.png) | 178257 |
| [screenshots/overview.png](screenshots/overview.png) | 226996 |
| [screenshots/pods.png](screenshots/pods.png) | 181653 |
| [screenshots/workloads.png](screenshots/workloads.png) | 179049 |

Verify the published bytes with `sha256sum -c SHA256SUMS` in this directory.
Keep the relative filenames together when sharing. Review operational metadata
before distributing reports. Historical reports retain their original capture
version: [4.19.2](../html419/README.md), [4.23.1](../html423/README.md), [4.24.1](../html4241/README.md), [4.12.0](../html/).
