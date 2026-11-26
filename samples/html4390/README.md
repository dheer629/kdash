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
| [extended/fmea/runs/kdash-local_kdash-e2e/20261126095646.tsv](extended/fmea/runs/kdash-local_kdash-e2e/20261126095646.tsv) | 1598 |
| [extended/with-extras/fmea/runs/kdash-local_kdash-e2e/20261126095920.tsv](extended/with-extras/fmea/runs/kdash-local_kdash-e2e/20261126095920.tsv) | 1598 |
| [extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_095916/csv/cluster_ns.csv](extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_095916/csv/cluster_ns.csv) | 723 |
| [extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_095916/csv/containers.csv](extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_095916/csv/containers.csv) | 1629 |
| [extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_095916/csv/ip.csv](extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_095916/csv/ip.csv) | 1904 |
| [extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_095916/csv/ipblocks.csv](extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_095916/csv/ipblocks.csv) | 197 |
| [extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_095916/csv/memory.csv](extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_095916/csv/memory.csv) | 1753 |
| [extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_095916/csv/meta.csv](extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_095916/csv/meta.csv) | 1128 |
| [extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_095916/csv/nodes.csv](extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_095916/csv/nodes.csv) | 723 |
| [extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_095916/csv/pods.csv](extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_095916/csv/pods.csv) | 3378 |
| [extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_095916/csv/pools.csv](extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_095916/csv/pools.csv) | 498 |
| [extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_095916/csv/services.csv](extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_095916/csv/services.csv) | 717 |
| [extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_095916/csv/subnets.csv](extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_095916/csv/subnets.csv) | 39 |
| [extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_095916/csv/wl_node.csv](extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_095916/csv/wl_node.csv) | 1318 |
| [extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_095916/csv/workloads.csv](extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_095916/csv/workloads.csv) | 1308 |
| [extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_095916/diagnostics/events.tsv](extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_095916/diagnostics/events.tsv) | 113115 |
| [extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_095916/diagnostics/health-volume-usage.tsv](extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_095916/diagnostics/health-volume-usage.tsv) | 0 |
| [extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_095916/fmea.csv](extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_095916/fmea.csv) | 10290 |
| [extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_095916/report.html](extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_095916/report.html) | 68760 |
| [extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_095916/secrets.csv](extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_095916/secrets.csv) | 2325 |
| [extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_095916/secrets.json](extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_095916/secrets.json) | 5297 |
| [extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_095916/tsv/cluster_ns.tsv](extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_095916/tsv/cluster_ns.tsv) | 723 |
| [extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_095916/tsv/containers.tsv](extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_095916/tsv/containers.tsv) | 1701 |
| [extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_095916/tsv/ip.tsv](extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_095916/tsv/ip.tsv) | 1892 |
| [extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_095916/tsv/ipblocks.tsv](extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_095916/tsv/ipblocks.tsv) | 195 |
| [extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_095916/tsv/memory.tsv](extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_095916/tsv/memory.tsv) | 1779 |
| [extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_095916/tsv/meta.tsv](extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_095916/tsv/meta.tsv) | 1131 |
| [extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_095916/tsv/nodes.tsv](extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_095916/tsv/nodes.tsv) | 737 |
| [extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_095916/tsv/pods.tsv](extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_095916/tsv/pods.tsv) | 3404 |
| [extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_095916/tsv/pools.tsv](extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_095916/tsv/pools.tsv) | 504 |
| [extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_095916/tsv/services.tsv](extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_095916/tsv/services.tsv) | 743 |
| [extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_095916/tsv/subnets.tsv](extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_095916/tsv/subnets.tsv) | 39 |
| [extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_095916/tsv/wl_node.tsv](extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_095916/tsv/wl_node.tsv) | 1304 |
| [extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_095916/tsv/workloads.tsv](extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_095916/tsv/workloads.tsv) | 1414 |
| [extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_095916.html](extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_095916.html) | 68760 |
| [extended/with-extras-snapshot/fmea/runs/kdash-local_kdash-e2e/20261126095924.tsv](extended/with-extras-snapshot/fmea/runs/kdash-local_kdash-e2e/20261126095924.tsv) | 1598 |
| [extended/with-extras-snapshot/index.html](extended/with-extras-snapshot/index.html) | 1013 |
| [extended/with-extras-snapshot/kdash_namespace_report_kdash-local_kdash-e2e_20261126_095921.html](extended/with-extras-snapshot/kdash_namespace_report_kdash-local_kdash-e2e_20261126_095921.html) | 435773 |
| [extended/without-extras/index.html](extended/without-extras/index.html) | 1007 |
| [extended/without-extras/kdash_namespace_report_kdash-local_kdash-e2e_20261126_095924.html](extended/without-extras/kdash_namespace_report_kdash-local_kdash-e2e_20261126_095924.html) | 386882 |
| [fmea/fmea_kdash-local_kdash-e2e_20261126_091609.html](fmea/fmea_kdash-local_kdash-e2e_20261126_091609.html) | 17949 |
| [fmea/runs/kdash-local_kdash-e2e/20261126091530.tsv](fmea/runs/kdash-local_kdash-e2e/20261126091530.tsv) | 1598 |
| [fmea/runs/kdash-local_kdash-e2e/20261126091554.tsv](fmea/runs/kdash-local_kdash-e2e/20261126091554.tsv) | 1598 |
| [fmea/runs/kdash-local_kdash-e2e/20261126091558.tsv](fmea/runs/kdash-local_kdash-e2e/20261126091558.tsv) | 1598 |
| [fmea/runs/kdash-local_kdash-e2e/20261126091601.tsv](fmea/runs/kdash-local_kdash-e2e/20261126091601.tsv) | 1598 |
| [fmea/runs/kdash-local_kdash-e2e/20261126091605.tsv](fmea/runs/kdash-local_kdash-e2e/20261126091605.tsv) | 1598 |
| [fmea/runs/kdash-local_kdash-e2e/20261126091609.tsv](fmea/runs/kdash-local_kdash-e2e/20261126091609.tsv) | 1598 |
| [fmea/runs/kdash-local_kdash-e2e/20261126091612.tsv](fmea/runs/kdash-local_kdash-e2e/20261126091612.tsv) | 1598 |
| [fmea/runs/kdash-local_kdash-e2e/20261126091616.tsv](fmea/runs/kdash-local_kdash-e2e/20261126091616.tsv) | 1598 |
| [fmea/runs/kdash-local_kdash-e2e/20261126091620.tsv](fmea/runs/kdash-local_kdash-e2e/20261126091620.tsv) | 1598 |
| [fmea/worksheet.csv](fmea/worksheet.csv) | 10290 |
| [fmea/worksheet.json](fmea/worksheet.json) | 19465 |
| [fmea/worksheet.tsv](fmea/worksheet.tsv) | 10172 |
| [index.html](index.html) | 2703 |
| [kdash_audit_20261126_092442.csv](kdash_audit_20261126_092442.csv) | 189673 |
| [kdash_audit_20261126_092442.html](kdash_audit_20261126_092442.html) | 426914 |
| [kdash_kdash-local_kdash-e2e_20261126_091533/csv/cluster_ns.csv](kdash_kdash-local_kdash-e2e_20261126_091533/csv/cluster_ns.csv) | 724 |
| [kdash_kdash-local_kdash-e2e_20261126_091533/csv/containers.csv](kdash_kdash-local_kdash-e2e_20261126_091533/csv/containers.csv) | 1629 |
| [kdash_kdash-local_kdash-e2e_20261126_091533/csv/io_nodes.csv](kdash_kdash-local_kdash-e2e_20261126_091533/csv/io_nodes.csv) | 248 |
| [kdash_kdash-local_kdash-e2e_20261126_091533/csv/io_pods.csv](kdash_kdash-local_kdash-e2e_20261126_091533/csv/io_pods.csv) | 1007 |
| [kdash_kdash-local_kdash-e2e_20261126_091533/csv/ip.csv](kdash_kdash-local_kdash-e2e_20261126_091533/csv/ip.csv) | 1904 |
| [kdash_kdash-local_kdash-e2e_20261126_091533/csv/ipblocks.csv](kdash_kdash-local_kdash-e2e_20261126_091533/csv/ipblocks.csv) | 181 |
| [kdash_kdash-local_kdash-e2e_20261126_091533/csv/memory.csv](kdash_kdash-local_kdash-e2e_20261126_091533/csv/memory.csv) | 1753 |
| [kdash_kdash-local_kdash-e2e_20261126_091533/csv/meta.csv](kdash_kdash-local_kdash-e2e_20261126_091533/csv/meta.csv) | 1275 |
| [kdash_kdash-local_kdash-e2e_20261126_091533/csv/nodes.csv](kdash_kdash-local_kdash-e2e_20261126_091533/csv/nodes.csv) | 707 |
| [kdash_kdash-local_kdash-e2e_20261126_091533/csv/pods.csv](kdash_kdash-local_kdash-e2e_20261126_091533/csv/pods.csv) | 3378 |
| [kdash_kdash-local_kdash-e2e_20261126_091533/csv/pools.csv](kdash_kdash-local_kdash-e2e_20261126_091533/csv/pools.csv) | 498 |
| [kdash_kdash-local_kdash-e2e_20261126_091533/csv/services.csv](kdash_kdash-local_kdash-e2e_20261126_091533/csv/services.csv) | 717 |
| [kdash_kdash-local_kdash-e2e_20261126_091533/csv/subnets.csv](kdash_kdash-local_kdash-e2e_20261126_091533/csv/subnets.csv) | 39 |
| [kdash_kdash-local_kdash-e2e_20261126_091533/csv/wl_node.csv](kdash_kdash-local_kdash-e2e_20261126_091533/csv/wl_node.csv) | 1318 |
| [kdash_kdash-local_kdash-e2e_20261126_091533/csv/workloads.csv](kdash_kdash-local_kdash-e2e_20261126_091533/csv/workloads.csv) | 1308 |
| [kdash_kdash-local_kdash-e2e_20261126_091533/diagnostics/events.tsv](kdash_kdash-local_kdash-e2e_20261126_091533/diagnostics/events.tsv) | 102414 |
| [kdash_kdash-local_kdash-e2e_20261126_091533/diagnostics/health-volume-usage.tsv](kdash_kdash-local_kdash-e2e_20261126_091533/diagnostics/health-volume-usage.tsv) | 0 |
| [kdash_kdash-local_kdash-e2e_20261126_091533/fmea.csv](kdash_kdash-local_kdash-e2e_20261126_091533/fmea.csv) | 10290 |
| [kdash_kdash-local_kdash-e2e_20261126_091533/report.html](kdash_kdash-local_kdash-e2e_20261126_091533/report.html) | 68728 |
| [kdash_kdash-local_kdash-e2e_20261126_091533/secrets.csv](kdash_kdash-local_kdash-e2e_20261126_091533/secrets.csv) | 2325 |
| [kdash_kdash-local_kdash-e2e_20261126_091533/secrets.json](kdash_kdash-local_kdash-e2e_20261126_091533/secrets.json) | 5297 |
| [kdash_kdash-local_kdash-e2e_20261126_091533/tsv/cluster_ns.tsv](kdash_kdash-local_kdash-e2e_20261126_091533/tsv/cluster_ns.tsv) | 724 |
| [kdash_kdash-local_kdash-e2e_20261126_091533/tsv/containers.tsv](kdash_kdash-local_kdash-e2e_20261126_091533/tsv/containers.tsv) | 1701 |
| [kdash_kdash-local_kdash-e2e_20261126_091533/tsv/io_nodes.tsv](kdash_kdash-local_kdash-e2e_20261126_091533/tsv/io_nodes.tsv) | 270 |
| [kdash_kdash-local_kdash-e2e_20261126_091533/tsv/io_pods.tsv](kdash_kdash-local_kdash-e2e_20261126_091533/tsv/io_pods.tsv) | 1115 |
| [kdash_kdash-local_kdash-e2e_20261126_091533/tsv/ip.tsv](kdash_kdash-local_kdash-e2e_20261126_091533/tsv/ip.tsv) | 1892 |
| [kdash_kdash-local_kdash-e2e_20261126_091533/tsv/ipblocks.tsv](kdash_kdash-local_kdash-e2e_20261126_091533/tsv/ipblocks.tsv) | 179 |
| [kdash_kdash-local_kdash-e2e_20261126_091533/tsv/memory.tsv](kdash_kdash-local_kdash-e2e_20261126_091533/tsv/memory.tsv) | 1779 |
| [kdash_kdash-local_kdash-e2e_20261126_091533/tsv/meta.tsv](kdash_kdash-local_kdash-e2e_20261126_091533/tsv/meta.tsv) | 1287 |
| [kdash_kdash-local_kdash-e2e_20261126_091533/tsv/nodes.tsv](kdash_kdash-local_kdash-e2e_20261126_091533/tsv/nodes.tsv) | 721 |
| [kdash_kdash-local_kdash-e2e_20261126_091533/tsv/pods.tsv](kdash_kdash-local_kdash-e2e_20261126_091533/tsv/pods.tsv) | 3404 |
| [kdash_kdash-local_kdash-e2e_20261126_091533/tsv/pools.tsv](kdash_kdash-local_kdash-e2e_20261126_091533/tsv/pools.tsv) | 504 |
| [kdash_kdash-local_kdash-e2e_20261126_091533/tsv/services.tsv](kdash_kdash-local_kdash-e2e_20261126_091533/tsv/services.tsv) | 743 |
| [kdash_kdash-local_kdash-e2e_20261126_091533/tsv/subnets.tsv](kdash_kdash-local_kdash-e2e_20261126_091533/tsv/subnets.tsv) | 39 |
| [kdash_kdash-local_kdash-e2e_20261126_091533/tsv/wl_node.tsv](kdash_kdash-local_kdash-e2e_20261126_091533/tsv/wl_node.tsv) | 1304 |
| [kdash_kdash-local_kdash-e2e_20261126_091533/tsv/workloads.tsv](kdash_kdash-local_kdash-e2e_20261126_091533/tsv/workloads.tsv) | 1414 |
| [kdash_kdash-local_kdash-e2e_20261126_091533.html](kdash_kdash-local_kdash-e2e_20261126_091533.html) | 68728 |
| [kdash_memory_dashboard_kdash-local_kdash-e2e_20261126_091531.html](kdash_memory_dashboard_kdash-local_kdash-e2e_20261126_091531.html) | 123041 |
| [kdash_memory_dashboard_kdash-local_kdash-e2e_20261126_091532.html](kdash_memory_dashboard_kdash-local_kdash-e2e_20261126_091532.html) | 122981 |
| [kdash_namespace_ip_pool_kdash-local_kdash-e2e_20261126_091531.html](kdash_namespace_ip_pool_kdash-local_kdash-e2e_20261126_091531.html) | 100801 |
| [kdash_namespace_report_kdash-local_kdash-e2e_20261126_091527.html](kdash_namespace_report_kdash-local_kdash-e2e_20261126_091527.html) | 445922 |
| [kdash_namespace_report_kdash-local_kdash-e2e_20261126_091930.html](kdash_namespace_report_kdash-local_kdash-e2e_20261126_091930.html) | 496111 |
| [kdash_namespace_report_kdash-local_kdash-e2e_20261126_092441.html](kdash_namespace_report_kdash-local_kdash-e2e_20261126_092441.html) | 412718 |
| [kdash_network_disk_io_kdash-local_kdash-e2e_20261126_091531.html](kdash_network_disk_io_kdash-local_kdash-e2e_20261126_091531.html) | 76195 |
| [kdash_node_pools_worker_nodes_kdash-local_kdash-e2e_20261126_091531.html](kdash_node_pools_worker_nodes_kdash-local_kdash-e2e_20261126_091531.html) | 102739 |
| [kdash_node_pools_worker_nodes_kdash-local_kdash-e2e_20261126_091532.html](kdash_node_pools_worker_nodes_kdash-local_kdash-e2e_20261126_091532.html) | 102679 |
| [kdash_pod_container_resources_kdash-local_kdash-e2e_20261126_091531.html](kdash_pod_container_resources_kdash-local_kdash-e2e_20261126_091531.html) | 153349 |
| [kdash_workloads_per_worker_node_kdash-local_kdash-e2e_20261126_091531.html](kdash_workloads_per_worker_node_kdash-local_kdash-e2e_20261126_091531.html) | 117963 |
| [screenshots/combined-fmea.png](screenshots/combined-fmea.png) | 331026 |
| [screenshots/combined-secrets.png](screenshots/combined-secrets.png) | 169908 |
| [screenshots/fmea.png](screenshots/fmea.png) | 114761 |
| [screenshots/history.png](screenshots/history.png) | 182601 |
| [screenshots/io.png](screenshots/io.png) | 147763 |
| [screenshots/ip.png](screenshots/ip.png) | 185873 |
| [screenshots/mem.png](screenshots/mem.png) | 169063 |
| [screenshots/nodes.png](screenshots/nodes.png) | 179080 |
| [screenshots/overview.png](screenshots/overview.png) | 228178 |
| [screenshots/pods.png](screenshots/pods.png) | 182971 |
| [screenshots/secrets.png](screenshots/secrets.png) | 121361 |
| [screenshots/workloads.png](screenshots/workloads.png) | 183505 |
| [secrets/fmea/runs/kdash-local_kdash-e2e/20261126093429.tsv](secrets/fmea/runs/kdash-local_kdash-e2e/20261126093429.tsv) | 1580 |
| [secrets/index.html](secrets/index.html) | 991 |
| [secrets/kdash_namespace_report_kdash-local_kdash-e2e_20261126_093425.html](secrets/kdash_namespace_report_kdash-local_kdash-e2e_20261126_093425.html) | 456191 |
| [secrets/secrets/secrets_kdash-local_kdash-e2e_20261126_093402.html](secrets/secrets/secrets_kdash-local_kdash-e2e_20261126_093402.html) | 9147 |

Verify the published bytes with `sha256sum -c SHA256SUMS` in this directory.
Keep the relative filenames together when sharing. Review operational metadata
before distributing reports. Historical reports retain their original capture
version: [4.19.2](../html419/README.md), [4.23.1](../html423/README.md), [4.24.1](../html4241/README.md), [4.27.3](../html4273/README.md), [4.27.4](../html4274/README.md), [4.32.0](../html4320/README.md), [4.37.0](../html4370/README.md), [4.12.0](../html/).
