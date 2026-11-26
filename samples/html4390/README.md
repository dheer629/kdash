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
| [extended/fmea/runs/kdash-local_kdash-e2e/20261126164020.tsv](extended/fmea/runs/kdash-local_kdash-e2e/20261126164020.tsv) | 1598 |
| [extended/with-extras/fmea/runs/kdash-local_kdash-e2e/20261126164255.tsv](extended/with-extras/fmea/runs/kdash-local_kdash-e2e/20261126164255.tsv) | 1598 |
| [extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_164251/csv/cluster_ns.csv](extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_164251/csv/cluster_ns.csv) | 727 |
| [extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_164251/csv/containers.csv](extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_164251/csv/containers.csv) | 1630 |
| [extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_164251/csv/ip.csv](extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_164251/csv/ip.csv) | 1900 |
| [extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_164251/csv/ipblocks.csv](extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_164251/csv/ipblocks.csv) | 196 |
| [extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_164251/csv/memory.csv](extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_164251/csv/memory.csv) | 1758 |
| [extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_164251/csv/meta.csv](extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_164251/csv/meta.csv) | 1128 |
| [extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_164251/csv/nodes.csv](extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_164251/csv/nodes.csv) | 722 |
| [extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_164251/csv/pods.csv](extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_164251/csv/pods.csv) | 3379 |
| [extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_164251/csv/pools.csv](extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_164251/csv/pools.csv) | 498 |
| [extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_164251/csv/services.csv](extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_164251/csv/services.csv) | 717 |
| [extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_164251/csv/subnets.csv](extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_164251/csv/subnets.csv) | 39 |
| [extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_164251/csv/wl_node.csv](extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_164251/csv/wl_node.csv) | 1319 |
| [extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_164251/csv/workloads.csv](extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_164251/csv/workloads.csv) | 1309 |
| [extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_164251/diagnostics/events.tsv](extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_164251/diagnostics/events.tsv) | 15701 |
| [extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_164251/diagnostics/health-volume-usage.tsv](extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_164251/diagnostics/health-volume-usage.tsv) | 0 |
| [extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_164251/fmea.csv](extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_164251/fmea.csv) | 10286 |
| [extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_164251/report.html](extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_164251/report.html) | 68924 |
| [extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_164251/secrets.csv](extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_164251/secrets.csv) | 2325 |
| [extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_164251/secrets.json](extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_164251/secrets.json) | 5297 |
| [extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_164251/tsv/cluster_ns.tsv](extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_164251/tsv/cluster_ns.tsv) | 727 |
| [extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_164251/tsv/containers.tsv](extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_164251/tsv/containers.tsv) | 1702 |
| [extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_164251/tsv/ip.tsv](extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_164251/tsv/ip.tsv) | 1888 |
| [extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_164251/tsv/ipblocks.tsv](extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_164251/tsv/ipblocks.tsv) | 194 |
| [extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_164251/tsv/memory.tsv](extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_164251/tsv/memory.tsv) | 1784 |
| [extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_164251/tsv/meta.tsv](extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_164251/tsv/meta.tsv) | 1131 |
| [extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_164251/tsv/nodes.tsv](extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_164251/tsv/nodes.tsv) | 736 |
| [extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_164251/tsv/pods.tsv](extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_164251/tsv/pods.tsv) | 3405 |
| [extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_164251/tsv/pools.tsv](extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_164251/tsv/pools.tsv) | 504 |
| [extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_164251/tsv/services.tsv](extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_164251/tsv/services.tsv) | 743 |
| [extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_164251/tsv/subnets.tsv](extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_164251/tsv/subnets.tsv) | 39 |
| [extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_164251/tsv/wl_node.tsv](extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_164251/tsv/wl_node.tsv) | 1305 |
| [extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_164251/tsv/workloads.tsv](extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_164251/tsv/workloads.tsv) | 1415 |
| [extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_164251.html](extended/with-extras/kdash_kdash-local_kdash-e2e_20261126_164251.html) | 68924 |
| [extended/with-extras-snapshot/fmea/runs/kdash-local_kdash-e2e/20261126164259.tsv](extended/with-extras-snapshot/fmea/runs/kdash-local_kdash-e2e/20261126164259.tsv) | 1598 |
| [extended/with-extras-snapshot/index.html](extended/with-extras-snapshot/index.html) | 1013 |
| [extended/with-extras-snapshot/kdash_namespace_report_kdash-local_kdash-e2e_20261126_164256.html](extended/with-extras-snapshot/kdash_namespace_report_kdash-local_kdash-e2e_20261126_164256.html) | 435767 |
| [extended/without-extras/index.html](extended/without-extras/index.html) | 1007 |
| [extended/without-extras/kdash_namespace_report_kdash-local_kdash-e2e_20261126_164300.html](extended/without-extras/kdash_namespace_report_kdash-local_kdash-e2e_20261126_164300.html) | 386879 |
| [fmea/fmea_kdash-local_kdash-e2e_20261126_162925.html](fmea/fmea_kdash-local_kdash-e2e_20261126_162925.html) | 17949 |
| [fmea/runs/kdash-local_kdash-e2e/20261126162847.tsv](fmea/runs/kdash-local_kdash-e2e/20261126162847.tsv) | 1598 |
| [fmea/runs/kdash-local_kdash-e2e/20261126162910.tsv](fmea/runs/kdash-local_kdash-e2e/20261126162910.tsv) | 1598 |
| [fmea/runs/kdash-local_kdash-e2e/20261126162914.tsv](fmea/runs/kdash-local_kdash-e2e/20261126162914.tsv) | 1598 |
| [fmea/runs/kdash-local_kdash-e2e/20261126162918.tsv](fmea/runs/kdash-local_kdash-e2e/20261126162918.tsv) | 1598 |
| [fmea/runs/kdash-local_kdash-e2e/20261126162921.tsv](fmea/runs/kdash-local_kdash-e2e/20261126162921.tsv) | 1598 |
| [fmea/runs/kdash-local_kdash-e2e/20261126162925.tsv](fmea/runs/kdash-local_kdash-e2e/20261126162925.tsv) | 1598 |
| [fmea/runs/kdash-local_kdash-e2e/20261126162929.tsv](fmea/runs/kdash-local_kdash-e2e/20261126162929.tsv) | 1598 |
| [fmea/runs/kdash-local_kdash-e2e/20261126162932.tsv](fmea/runs/kdash-local_kdash-e2e/20261126162932.tsv) | 1598 |
| [fmea/runs/kdash-local_kdash-e2e/20261126162936.tsv](fmea/runs/kdash-local_kdash-e2e/20261126162936.tsv) | 1598 |
| [fmea/worksheet.csv](fmea/worksheet.csv) | 10290 |
| [fmea/worksheet.json](fmea/worksheet.json) | 19465 |
| [fmea/worksheet.tsv](fmea/worksheet.tsv) | 10172 |
| [index.html](index.html) | 2549 |
| [kdash_audit_20261126_163756.csv](kdash_audit_20261126_163756.csv) | 190814 |
| [kdash_audit_20261126_163756.html](kdash_audit_20261126_163756.html) | 430027 |
| [kdash_kdash-local_kdash-e2e_20261126_162850/csv/cluster_ns.csv](kdash_kdash-local_kdash-e2e_20261126_162850/csv/cluster_ns.csv) | 726 |
| [kdash_kdash-local_kdash-e2e_20261126_162850/csv/containers.csv](kdash_kdash-local_kdash-e2e_20261126_162850/csv/containers.csv) | 1634 |
| [kdash_kdash-local_kdash-e2e_20261126_162850/csv/io_nodes.csv](kdash_kdash-local_kdash-e2e_20261126_162850/csv/io_nodes.csv) | 248 |
| [kdash_kdash-local_kdash-e2e_20261126_162850/csv/io_pods.csv](kdash_kdash-local_kdash-e2e_20261126_162850/csv/io_pods.csv) | 1007 |
| [kdash_kdash-local_kdash-e2e_20261126_162850/csv/ip.csv](kdash_kdash-local_kdash-e2e_20261126_162850/csv/ip.csv) | 1904 |
| [kdash_kdash-local_kdash-e2e_20261126_162850/csv/ipblocks.csv](kdash_kdash-local_kdash-e2e_20261126_162850/csv/ipblocks.csv) | 196 |
| [kdash_kdash-local_kdash-e2e_20261126_162850/csv/memory.csv](kdash_kdash-local_kdash-e2e_20261126_162850/csv/memory.csv) | 1758 |
| [kdash_kdash-local_kdash-e2e_20261126_162850/csv/meta.csv](kdash_kdash-local_kdash-e2e_20261126_162850/csv/meta.csv) | 1275 |
| [kdash_kdash-local_kdash-e2e_20261126_162850/csv/nodes.csv](kdash_kdash-local_kdash-e2e_20261126_162850/csv/nodes.csv) | 722 |
| [kdash_kdash-local_kdash-e2e_20261126_162850/csv/pods.csv](kdash_kdash-local_kdash-e2e_20261126_162850/csv/pods.csv) | 3383 |
| [kdash_kdash-local_kdash-e2e_20261126_162850/csv/pools.csv](kdash_kdash-local_kdash-e2e_20261126_162850/csv/pools.csv) | 498 |
| [kdash_kdash-local_kdash-e2e_20261126_162850/csv/services.csv](kdash_kdash-local_kdash-e2e_20261126_162850/csv/services.csv) | 717 |
| [kdash_kdash-local_kdash-e2e_20261126_162850/csv/subnets.csv](kdash_kdash-local_kdash-e2e_20261126_162850/csv/subnets.csv) | 39 |
| [kdash_kdash-local_kdash-e2e_20261126_162850/csv/wl_node.csv](kdash_kdash-local_kdash-e2e_20261126_162850/csv/wl_node.csv) | 1319 |
| [kdash_kdash-local_kdash-e2e_20261126_162850/csv/workloads.csv](kdash_kdash-local_kdash-e2e_20261126_162850/csv/workloads.csv) | 1309 |
| [kdash_kdash-local_kdash-e2e_20261126_162850/diagnostics/events.tsv](kdash_kdash-local_kdash-e2e_20261126_162850/diagnostics/events.tsv) | 15701 |
| [kdash_kdash-local_kdash-e2e_20261126_162850/diagnostics/health-volume-usage.tsv](kdash_kdash-local_kdash-e2e_20261126_162850/diagnostics/health-volume-usage.tsv) | 0 |
| [kdash_kdash-local_kdash-e2e_20261126_162850/fmea.csv](kdash_kdash-local_kdash-e2e_20261126_162850/fmea.csv) | 10290 |
| [kdash_kdash-local_kdash-e2e_20261126_162850/report.html](kdash_kdash-local_kdash-e2e_20261126_162850/report.html) | 68936 |
| [kdash_kdash-local_kdash-e2e_20261126_162850/secrets.csv](kdash_kdash-local_kdash-e2e_20261126_162850/secrets.csv) | 2325 |
| [kdash_kdash-local_kdash-e2e_20261126_162850/secrets.json](kdash_kdash-local_kdash-e2e_20261126_162850/secrets.json) | 5297 |
| [kdash_kdash-local_kdash-e2e_20261126_162850/tsv/cluster_ns.tsv](kdash_kdash-local_kdash-e2e_20261126_162850/tsv/cluster_ns.tsv) | 726 |
| [kdash_kdash-local_kdash-e2e_20261126_162850/tsv/containers.tsv](kdash_kdash-local_kdash-e2e_20261126_162850/tsv/containers.tsv) | 1706 |
| [kdash_kdash-local_kdash-e2e_20261126_162850/tsv/io_nodes.tsv](kdash_kdash-local_kdash-e2e_20261126_162850/tsv/io_nodes.tsv) | 270 |
| [kdash_kdash-local_kdash-e2e_20261126_162850/tsv/io_pods.tsv](kdash_kdash-local_kdash-e2e_20261126_162850/tsv/io_pods.tsv) | 1115 |
| [kdash_kdash-local_kdash-e2e_20261126_162850/tsv/ip.tsv](kdash_kdash-local_kdash-e2e_20261126_162850/tsv/ip.tsv) | 1892 |
| [kdash_kdash-local_kdash-e2e_20261126_162850/tsv/ipblocks.tsv](kdash_kdash-local_kdash-e2e_20261126_162850/tsv/ipblocks.tsv) | 194 |
| [kdash_kdash-local_kdash-e2e_20261126_162850/tsv/memory.tsv](kdash_kdash-local_kdash-e2e_20261126_162850/tsv/memory.tsv) | 1784 |
| [kdash_kdash-local_kdash-e2e_20261126_162850/tsv/meta.tsv](kdash_kdash-local_kdash-e2e_20261126_162850/tsv/meta.tsv) | 1287 |
| [kdash_kdash-local_kdash-e2e_20261126_162850/tsv/nodes.tsv](kdash_kdash-local_kdash-e2e_20261126_162850/tsv/nodes.tsv) | 736 |
| [kdash_kdash-local_kdash-e2e_20261126_162850/tsv/pods.tsv](kdash_kdash-local_kdash-e2e_20261126_162850/tsv/pods.tsv) | 3409 |
| [kdash_kdash-local_kdash-e2e_20261126_162850/tsv/pools.tsv](kdash_kdash-local_kdash-e2e_20261126_162850/tsv/pools.tsv) | 504 |
| [kdash_kdash-local_kdash-e2e_20261126_162850/tsv/services.tsv](kdash_kdash-local_kdash-e2e_20261126_162850/tsv/services.tsv) | 743 |
| [kdash_kdash-local_kdash-e2e_20261126_162850/tsv/subnets.tsv](kdash_kdash-local_kdash-e2e_20261126_162850/tsv/subnets.tsv) | 39 |
| [kdash_kdash-local_kdash-e2e_20261126_162850/tsv/wl_node.tsv](kdash_kdash-local_kdash-e2e_20261126_162850/tsv/wl_node.tsv) | 1305 |
| [kdash_kdash-local_kdash-e2e_20261126_162850/tsv/workloads.tsv](kdash_kdash-local_kdash-e2e_20261126_162850/tsv/workloads.tsv) | 1415 |
| [kdash_kdash-local_kdash-e2e_20261126_162850.html](kdash_kdash-local_kdash-e2e_20261126_162850.html) | 68936 |
| [kdash_memory_dashboard_kdash-local_kdash-e2e_20261126_162848.html](kdash_memory_dashboard_kdash-local_kdash-e2e_20261126_162848.html) | 123090 |
| [kdash_memory_dashboard_kdash-local_kdash-e2e_20261126_162849.html](kdash_memory_dashboard_kdash-local_kdash-e2e_20261126_162849.html) | 123030 |
| [kdash_namespace_ip_pool_kdash-local_kdash-e2e_20261126_162848.html](kdash_namespace_ip_pool_kdash-local_kdash-e2e_20261126_162848.html) | 100874 |
| [kdash_namespace_report_kdash-local_kdash-e2e_20261126_162844.html](kdash_namespace_report_kdash-local_kdash-e2e_20261126_162844.html) | 446148 |
| [kdash_namespace_report_kdash-local_kdash-e2e_20261126_163755.html](kdash_namespace_report_kdash-local_kdash-e2e_20261126_163755.html) | 412913 |
| [kdash_network_disk_io_kdash-local_kdash-e2e_20261126_162848.html](kdash_network_disk_io_kdash-local_kdash-e2e_20261126_162848.html) | 76193 |
| [kdash_node_pools_worker_nodes_kdash-local_kdash-e2e_20261126_162848.html](kdash_node_pools_worker_nodes_kdash-local_kdash-e2e_20261126_162848.html) | 102777 |
| [kdash_node_pools_worker_nodes_kdash-local_kdash-e2e_20261126_162849.html](kdash_node_pools_worker_nodes_kdash-local_kdash-e2e_20261126_162849.html) | 102717 |
| [kdash_pod_container_resources_kdash-local_kdash-e2e_20261126_162848.html](kdash_pod_container_resources_kdash-local_kdash-e2e_20261126_162848.html) | 153399 |
| [kdash_workloads_per_worker_node_kdash-local_kdash-e2e_20261126_162848.html](kdash_workloads_per_worker_node_kdash-local_kdash-e2e_20261126_162848.html) | 117971 |
| [screenshots/combined-fmea.png](screenshots/combined-fmea.png) | 326604 |
| [screenshots/combined-secrets.png](screenshots/combined-secrets.png) | 165692 |
| [screenshots/fmea.png](screenshots/fmea.png) | 114714 |
| [screenshots/history.png](screenshots/history.png) | 137647 |
| [screenshots/io.png](screenshots/io.png) | 123179 |
| [screenshots/ip.png](screenshots/ip.png) | 178658 |
| [screenshots/mem.png](screenshots/mem.png) | 177260 |
| [screenshots/nodes.png](screenshots/nodes.png) | 184641 |
| [screenshots/overview.png](screenshots/overview.png) | 223190 |
| [screenshots/pods.png](screenshots/pods.png) | 207784 |
| [screenshots/secrets.png](screenshots/secrets.png) | 121081 |
| [screenshots/workloads.png](screenshots/workloads.png) | 193497 |
| [secrets/fmea/runs/kdash-local_kdash-e2e/20261126164544.tsv](secrets/fmea/runs/kdash-local_kdash-e2e/20261126164544.tsv) | 1598 |
| [secrets/index.html](secrets/index.html) | 991 |
| [secrets/kdash_namespace_report_kdash-local_kdash-e2e_20261126_164540.html](secrets/kdash_namespace_report_kdash-local_kdash-e2e_20261126_164540.html) | 458064 |
| [secrets/secrets/secrets_kdash-local_kdash-e2e_20261126_164517.html](secrets/secrets/secrets_kdash-local_kdash-e2e_20261126_164517.html) | 9147 |

Verify the published bytes with `sha256sum -c SHA256SUMS` in this directory.
Keep the relative filenames together when sharing. Review operational metadata
before distributing reports. Historical reports retain their original capture
version: [4.19.2](../html419/README.md), [4.23.1](../html423/README.md), [4.24.1](../html4241/README.md), [4.27.3](../html4273/README.md), [4.27.4](../html4274/README.md), [4.32.0](../html4320/README.md), [4.37.0](../html4370/README.md), [4.12.0](../html/).
