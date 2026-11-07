# kdash 4.27.4 live WSL HTML reports

The files in this directory come from the generated reports of
[`live-e2e-20261107-083145`](../../artifacts/live-e2e-20261107-083145), running the installed kdash 4.27.4 against local WSL
Kubernetes. The [results](../../artifacts/live-e2e-20261107-083145/results.json) and [checks](../../artifacts/live-e2e-20261107-083145/checks.tsv)
record export validation; the [terminal gallery](../cli_4274/README.md) records
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
| [kdash_audit_20261107_141020.csv](kdash_audit_20261107_141020.csv) | 160878 |
| [kdash_audit_20261107_141020.html](kdash_audit_20261107_141020.html) | 364621 |
| [kdash_memory_dashboard_vcluster-docker_dev_kdash-e2e_20261107_140210.html](kdash_memory_dashboard_vcluster-docker_dev_kdash-e2e_20261107_140210.html) | 92708 |
| [kdash_memory_dashboard_vcluster-docker_dev_kdash-e2e_20261107_140211.html](kdash_memory_dashboard_vcluster-docker_dev_kdash-e2e_20261107_140211.html) | 92616 |
| [kdash_namespace_ip_pool_vcluster-docker_dev_kdash-e2e_20261107_140210.html](kdash_namespace_ip_pool_vcluster-docker_dev_kdash-e2e_20261107_140210.html) | 78696 |
| [kdash_namespace_report_vcluster-docker_dev_kdash-e2e_20261107_140209.html](kdash_namespace_report_vcluster-docker_dev_kdash-e2e_20261107_140209.html) | 237946 |
| [kdash_namespace_report_vcluster-docker_dev_kdash-e2e_20261107_140535.html](kdash_namespace_report_vcluster-docker_dev_kdash-e2e_20261107_140535.html) | 277057 |
| [kdash_namespace_report_vcluster-docker_dev_kdash-e2e_20261107_141020.html](kdash_namespace_report_vcluster-docker_dev_kdash-e2e_20261107_141020.html) | 136394 |
| [kdash_network_disk_io_vcluster-docker_dev_kdash-e2e_20261107_140210.html](kdash_network_disk_io_vcluster-docker_dev_kdash-e2e_20261107_140210.html) | 68414 |
| [kdash_node_pools_worker_nodes_vcluster-docker_dev_kdash-e2e_20261107_140210.html](kdash_node_pools_worker_nodes_vcluster-docker_dev_kdash-e2e_20261107_140210.html) | 99488 |
| [kdash_node_pools_worker_nodes_vcluster-docker_dev_kdash-e2e_20261107_140211.html](kdash_node_pools_worker_nodes_vcluster-docker_dev_kdash-e2e_20261107_140211.html) | 99396 |
| [kdash_pod_container_resources_vcluster-docker_dev_kdash-e2e_20261107_140210.html](kdash_pod_container_resources_vcluster-docker_dev_kdash-e2e_20261107_140210.html) | 93771 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261107_140213/csv/cluster_ns.csv](kdash_vcluster-docker_dev_kdash-e2e_20261107_140213/csv/cluster_ns.csv) | 660 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261107_140213/csv/containers.csv](kdash_vcluster-docker_dev_kdash-e2e_20261107_140213/csv/containers.csv) | 668 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261107_140213/csv/io_nodes.csv](kdash_vcluster-docker_dev_kdash-e2e_20261107_140213/csv/io_nodes.csv) | 247 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261107_140213/csv/io_pods.csv](kdash_vcluster-docker_dev_kdash-e2e_20261107_140213/csv/io_pods.csv) | 330 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261107_140213/csv/ip.csv](kdash_vcluster-docker_dev_kdash-e2e_20261107_140213/csv/ip.csv) | 547 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261107_140213/csv/ipblocks.csv](kdash_vcluster-docker_dev_kdash-e2e_20261107_140213/csv/ipblocks.csv) | 180 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261107_140213/csv/memory.csv](kdash_vcluster-docker_dev_kdash-e2e_20261107_140213/csv/memory.csv) | 531 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261107_140213/csv/meta.csv](kdash_vcluster-docker_dev_kdash-e2e_20261107_140213/csv/meta.csv) | 1199 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261107_140213/csv/nodes.csv](kdash_vcluster-docker_dev_kdash-e2e_20261107_140213/csv/nodes.csv) | 691 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261107_140213/csv/pods.csv](kdash_vcluster-docker_dev_kdash-e2e_20261107_140213/csv/pods.csv) | 1054 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261107_140213/csv/pools.csv](kdash_vcluster-docker_dev_kdash-e2e_20261107_140213/csv/pools.csv) | 483 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261107_140213/csv/services.csv](kdash_vcluster-docker_dev_kdash-e2e_20261107_140213/csv/services.csv) | 178 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261107_140213/csv/subnets.csv](kdash_vcluster-docker_dev_kdash-e2e_20261107_140213/csv/subnets.csv) | 38 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261107_140213/csv/wl_node.csv](kdash_vcluster-docker_dev_kdash-e2e_20261107_140213/csv/wl_node.csv) | 419 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261107_140213/csv/workloads.csv](kdash_vcluster-docker_dev_kdash-e2e_20261107_140213/csv/workloads.csv) | 514 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261107_140213/report.html](kdash_vcluster-docker_dev_kdash-e2e_20261107_140213/report.html) | 35215 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261107_140213.html](kdash_vcluster-docker_dev_kdash-e2e_20261107_140213.html) | 35215 |
| [kdash_workloads_per_worker_node_vcluster-docker_dev_kdash-e2e_20261107_140210.html](kdash_workloads_per_worker_node_vcluster-docker_dev_kdash-e2e_20261107_140210.html) | 82566 |
| [screenshots/history.png](screenshots/history.png) | 181853 |
| [screenshots/io.png](screenshots/io.png) | 193284 |
| [screenshots/ip.png](screenshots/ip.png) | 179670 |
| [screenshots/mem.png](screenshots/mem.png) | 171171 |
| [screenshots/nodes.png](screenshots/nodes.png) | 176914 |
| [screenshots/overview.png](screenshots/overview.png) | 222298 |
| [screenshots/pods.png](screenshots/pods.png) | 182492 |
| [screenshots/workloads.png](screenshots/workloads.png) | 177935 |

Verify the published bytes with `sha256sum -c SHA256SUMS` in this directory.
Keep the relative filenames together when sharing. Review operational metadata
before distributing reports. Historical reports retain their original capture
version: [4.19.2](../html419/README.md), [4.23.1](../html423/README.md), [4.24.1](../html4241/README.md), [4.27.3](../html4273/README.md), [4.12.0](../html/).
