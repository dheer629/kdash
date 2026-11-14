# kdash 4.32.0 live WSL HTML reports

The files in this directory come from the generated reports of
[`live-e2e-v4320`](../../artifacts/live-e2e-v4320), running the installed kdash 4.32.0 against local WSL
Kubernetes. The [results](../../artifacts/live-e2e-v4320/results.json) and [checks](../../artifacts/live-e2e-v4320/checks.tsv)
record export validation; the [terminal gallery](../cli_4320/README.md) records
the corresponding live interface.
The operator identity, host and context are redacted; measured workload data is preserved.

The namespace report includes Overview, six resource tabs and recorded History.
CLI Alerts appear in the Overview; Services, Storage, Events and explanations are
preserved in the evidence bundle's diagnostic text/tables rather than extra
namespace HTML tabs. Missing metrics remain unavailable instead of becoming zero.

FMEA has a separate static HTML worksheet and CSV, TSV and JSON exports in
`fmea/`; it is separate from the namespace report tabs. The browser checks
include its real worksheet rows and screenshot.


The Secrets map is a separate static HTML report under `secrets/`. Its live
fixture and browser checks verify certificate metadata and workload usage;
secret values and private-key material are not included.

Reports are self-contained for local viewing and include table search/sort,
CSV/JSON export, themes, timezone selection and chart controls where data exists.

| File | Bytes |
|---|---:|
| [fmea/fmea_vcluster-docker_dev_kdash-e2e_20261114_222411.html](fmea/fmea_vcluster-docker_dev_kdash-e2e_20261114_222411.html) | 17204 |
| [fmea/runs/vcluster-docker_dev_kdash-e2e/20261114222304.tsv](fmea/runs/vcluster-docker_dev_kdash-e2e/20261114222304.tsv) | 1497 |
| [fmea/runs/vcluster-docker_dev_kdash-e2e/20261114222343.tsv](fmea/runs/vcluster-docker_dev_kdash-e2e/20261114222343.tsv) | 1497 |
| [fmea/runs/vcluster-docker_dev_kdash-e2e/20261114222350.tsv](fmea/runs/vcluster-docker_dev_kdash-e2e/20261114222350.tsv) | 1497 |
| [fmea/runs/vcluster-docker_dev_kdash-e2e/20261114222357.tsv](fmea/runs/vcluster-docker_dev_kdash-e2e/20261114222357.tsv) | 1497 |
| [fmea/runs/vcluster-docker_dev_kdash-e2e/20261114222403.tsv](fmea/runs/vcluster-docker_dev_kdash-e2e/20261114222403.tsv) | 1497 |
| [fmea/runs/vcluster-docker_dev_kdash-e2e/20261114222411.tsv](fmea/runs/vcluster-docker_dev_kdash-e2e/20261114222411.tsv) | 1497 |
| [fmea/runs/vcluster-docker_dev_kdash-e2e/20261114222418.tsv](fmea/runs/vcluster-docker_dev_kdash-e2e/20261114222418.tsv) | 1497 |
| [fmea/runs/vcluster-docker_dev_kdash-e2e/20261114222425.tsv](fmea/runs/vcluster-docker_dev_kdash-e2e/20261114222425.tsv) | 1497 |
| [fmea/runs/vcluster-docker_dev_kdash-e2e/20261114222432.tsv](fmea/runs/vcluster-docker_dev_kdash-e2e/20261114222432.tsv) | 1497 |
| [fmea/worksheet.csv](fmea/worksheet.csv) | 9745 |
| [fmea/worksheet.json](fmea/worksheet.json) | 18624 |
| [fmea/worksheet.tsv](fmea/worksheet.tsv) | 9631 |
| [index.html](index.html) | 2895 |
| [kdash_audit_20261114_223314.csv](kdash_audit_20261114_223314.csv) | 192698 |
| [kdash_audit_20261114_223314.html](kdash_audit_20261114_223314.html) | 434383 |
| [kdash_memory_dashboard_vcluster-docker_dev_kdash-e2e_20261114_222306.html](kdash_memory_dashboard_vcluster-docker_dev_kdash-e2e_20261114_222306.html) | 120488 |
| [kdash_memory_dashboard_vcluster-docker_dev_kdash-e2e_20261114_222308.html](kdash_memory_dashboard_vcluster-docker_dev_kdash-e2e_20261114_222308.html) | 120396 |
| [kdash_namespace_ip_pool_vcluster-docker_dev_kdash-e2e_20261114_222306.html](kdash_namespace_ip_pool_vcluster-docker_dev_kdash-e2e_20261114_222306.html) | 98294 |
| [kdash_namespace_report_vcluster-docker_dev_kdash-e2e_20261114_222259.html](kdash_namespace_report_vcluster-docker_dev_kdash-e2e_20261114_222259.html) | 425008 |
| [kdash_namespace_report_vcluster-docker_dev_kdash-e2e_20261114_222745.html](kdash_namespace_report_vcluster-docker_dev_kdash-e2e_20261114_222745.html) | 477052 |
| [kdash_namespace_report_vcluster-docker_dev_kdash-e2e_20261114_223312.html](kdash_namespace_report_vcluster-docker_dev_kdash-e2e_20261114_223312.html) | 398651 |
| [kdash_network_disk_io_vcluster-docker_dev_kdash-e2e_20261114_222306.html](kdash_network_disk_io_vcluster-docker_dev_kdash-e2e_20261114_222306.html) | 75746 |
| [kdash_node_pools_worker_nodes_vcluster-docker_dev_kdash-e2e_20261114_222306.html](kdash_node_pools_worker_nodes_vcluster-docker_dev_kdash-e2e_20261114_222306.html) | 102969 |
| [kdash_node_pools_worker_nodes_vcluster-docker_dev_kdash-e2e_20261114_222308.html](kdash_node_pools_worker_nodes_vcluster-docker_dev_kdash-e2e_20261114_222308.html) | 102877 |
| [kdash_pod_container_resources_vcluster-docker_dev_kdash-e2e_20261114_222306.html](kdash_pod_container_resources_vcluster-docker_dev_kdash-e2e_20261114_222306.html) | 148104 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_222309/csv/cluster_ns.csv](kdash_vcluster-docker_dev_kdash-e2e_20261114_222309/csv/cluster_ns.csv) | 728 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_222309/csv/containers.csv](kdash_vcluster-docker_dev_kdash-e2e_20261114_222309/csv/containers.csv) | 1483 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_222309/csv/io_nodes.csv](kdash_vcluster-docker_dev_kdash-e2e_20261114_222309/csv/io_nodes.csv) | 248 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_222309/csv/io_pods.csv](kdash_vcluster-docker_dev_kdash-e2e_20261114_222309/csv/io_pods.csv) | 937 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_222309/csv/ip.csv](kdash_vcluster-docker_dev_kdash-e2e_20261114_222309/csv/ip.csv) | 1785 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_222309/csv/ipblocks.csv](kdash_vcluster-docker_dev_kdash-e2e_20261114_222309/csv/ipblocks.csv) | 211 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_222309/csv/memory.csv](kdash_vcluster-docker_dev_kdash-e2e_20261114_222309/csv/memory.csv) | 1592 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_222309/csv/meta.csv](kdash_vcluster-docker_dev_kdash-e2e_20261114_222309/csv/meta.csv) | 1275 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_222309/csv/nodes.csv](kdash_vcluster-docker_dev_kdash-e2e_20261114_222309/csv/nodes.csv) | 737 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_222309/csv/pods.csv](kdash_vcluster-docker_dev_kdash-e2e_20261114_222309/csv/pods.csv) | 3131 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_222309/csv/pools.csv](kdash_vcluster-docker_dev_kdash-e2e_20261114_222309/csv/pools.csv) | 498 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_222309/csv/services.csv](kdash_vcluster-docker_dev_kdash-e2e_20261114_222309/csv/services.csv) | 655 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_222309/csv/subnets.csv](kdash_vcluster-docker_dev_kdash-e2e_20261114_222309/csv/subnets.csv) | 39 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_222309/csv/wl_node.csv](kdash_vcluster-docker_dev_kdash-e2e_20261114_222309/csv/wl_node.csv) | 1213 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_222309/csv/workloads.csv](kdash_vcluster-docker_dev_kdash-e2e_20261114_222309/csv/workloads.csv) | 1232 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_222309/diagnostics/events.tsv](kdash_vcluster-docker_dev_kdash-e2e_20261114_222309/diagnostics/events.tsv) | 15020 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_222309/diagnostics/health-volume-usage.tsv](kdash_vcluster-docker_dev_kdash-e2e_20261114_222309/diagnostics/health-volume-usage.tsv) | 0 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_222309/fmea.csv](kdash_vcluster-docker_dev_kdash-e2e_20261114_222309/fmea.csv) | 9745 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_222309/report.html](kdash_vcluster-docker_dev_kdash-e2e_20261114_222309/report.html) | 66055 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_222309/secrets.csv](kdash_vcluster-docker_dev_kdash-e2e_20261114_222309/secrets.csv) | 1267 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_222309/secrets.json](kdash_vcluster-docker_dev_kdash-e2e_20261114_222309/secrets.json) | 2785 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_222309/tsv/cluster_ns.tsv](kdash_vcluster-docker_dev_kdash-e2e_20261114_222309/tsv/cluster_ns.tsv) | 728 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_222309/tsv/containers.tsv](kdash_vcluster-docker_dev_kdash-e2e_20261114_222309/tsv/containers.tsv) | 1560 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_222309/tsv/io_nodes.tsv](kdash_vcluster-docker_dev_kdash-e2e_20261114_222309/tsv/io_nodes.tsv) | 270 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_222309/tsv/io_pods.tsv](kdash_vcluster-docker_dev_kdash-e2e_20261114_222309/tsv/io_pods.tsv) | 1039 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_222309/tsv/ip.tsv](kdash_vcluster-docker_dev_kdash-e2e_20261114_222309/tsv/ip.tsv) | 1774 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_222309/tsv/ipblocks.tsv](kdash_vcluster-docker_dev_kdash-e2e_20261114_222309/tsv/ipblocks.tsv) | 209 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_222309/tsv/memory.tsv](kdash_vcluster-docker_dev_kdash-e2e_20261114_222309/tsv/memory.tsv) | 1625 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_222309/tsv/meta.tsv](kdash_vcluster-docker_dev_kdash-e2e_20261114_222309/tsv/meta.tsv) | 1287 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_222309/tsv/nodes.tsv](kdash_vcluster-docker_dev_kdash-e2e_20261114_222309/tsv/nodes.tsv) | 751 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_222309/tsv/pods.tsv](kdash_vcluster-docker_dev_kdash-e2e_20261114_222309/tsv/pods.tsv) | 3164 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_222309/tsv/pools.tsv](kdash_vcluster-docker_dev_kdash-e2e_20261114_222309/tsv/pools.tsv) | 504 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_222309/tsv/services.tsv](kdash_vcluster-docker_dev_kdash-e2e_20261114_222309/tsv/services.tsv) | 679 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_222309/tsv/subnets.tsv](kdash_vcluster-docker_dev_kdash-e2e_20261114_222309/tsv/subnets.tsv) | 39 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_222309/tsv/wl_node.tsv](kdash_vcluster-docker_dev_kdash-e2e_20261114_222309/tsv/wl_node.tsv) | 1201 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_222309/tsv/workloads.tsv](kdash_vcluster-docker_dev_kdash-e2e_20261114_222309/tsv/workloads.tsv) | 1330 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_222309.html](kdash_vcluster-docker_dev_kdash-e2e_20261114_222309.html) | 66055 |
| [kdash_workloads_per_worker_node_vcluster-docker_dev_kdash-e2e_20261114_222306.html](kdash_workloads_per_worker_node_vcluster-docker_dev_kdash-e2e_20261114_222306.html) | 114288 |
| [screenshots/fmea.png](screenshots/fmea.png) | 114170 |
| [screenshots/history.png](screenshots/history.png) | 186689 |
| [screenshots/io.png](screenshots/io.png) | 147247 |
| [screenshots/ip.png](screenshots/ip.png) | 189822 |
| [screenshots/mem.png](screenshots/mem.png) | 178182 |
| [screenshots/nodes.png](screenshots/nodes.png) | 182508 |
| [screenshots/overview.png](screenshots/overview.png) | 229026 |
| [screenshots/pods.png](screenshots/pods.png) | 183278 |
| [screenshots/secrets.png](screenshots/secrets.png) | 121874 |
| [screenshots/workloads.png](screenshots/workloads.png) | 186787 |
| [secrets/secrets/secrets_vcluster-docker_dev_kdash-e2e_20261114_223449.html](secrets/secrets/secrets_vcluster-docker_dev_kdash-e2e_20261114_223449.html) | 9155 |

Verify the published bytes with `sha256sum -c SHA256SUMS` in this directory.
Keep the relative filenames together when sharing. Review operational metadata
before distributing reports. Historical reports retain their original capture
version: [4.19.2](../html419/README.md), [4.23.1](../html423/README.md), [4.24.1](../html4241/README.md), [4.27.3](../html4273/README.md), [4.27.4](../html4274/README.md), [4.12.0](../html/).
