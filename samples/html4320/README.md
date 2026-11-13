# kdash 4.32.0 live WSL HTML reports

The files in this directory come from the generated reports of
[`live-e2e-v4320`](../../artifacts/live-e2e-v4320), running the installed kdash 4.32.0 against local WSL
Kubernetes. The [results](../../artifacts/live-e2e-v4320/results.json) and [checks](../../artifacts/live-e2e-v4320/checks.tsv)
record export validation; the [terminal gallery](../cli_4320/README.md) records
the corresponding live interface.

The namespace report includes Overview, six resource tabs and recorded History.
CLI Alerts appear in the Overview; Services, Storage, Events and explanations are
preserved in the evidence bundle's diagnostic text/tables rather than extra
namespace HTML tabs. Missing metrics remain unavailable instead of becoming zero.

FMEA has a separate static HTML worksheet and CSV, TSV and JSON exports in
`fmea/`; it is separate from the namespace report tabs. The browser checks
include its real worksheet rows and screenshot.

Reports are self-contained for local viewing and include table search/sort,
CSV/JSON export, themes, timezone selection and chart controls where data exists.

| File | Bytes |
|---|---:|
| [fmea/fmea_vcluster-docker_dev_kdash-e2e_20261114_002011.html](fmea/fmea_vcluster-docker_dev_kdash-e2e_20261114_002011.html) | 14375 |
| [fmea/fmea_vcluster-docker_dev_kdash-e2e_20261114_010855.html](fmea/fmea_vcluster-docker_dev_kdash-e2e_20261114_010855.html) | 14375 |
| [fmea/fmea_vcluster-docker_dev_kdash-e2e_20261114_014728.html](fmea/fmea_vcluster-docker_dev_kdash-e2e_20261114_014728.html) | 14375 |
| [fmea/runs/vcluster-docker_dev_kdash-e2e/20261114001859.tsv](fmea/runs/vcluster-docker_dev_kdash-e2e/20261114001859.tsv) | 928 |
| [fmea/runs/vcluster-docker_dev_kdash-e2e/20261114001940.tsv](fmea/runs/vcluster-docker_dev_kdash-e2e/20261114001940.tsv) | 928 |
| [fmea/runs/vcluster-docker_dev_kdash-e2e/20261114001948.tsv](fmea/runs/vcluster-docker_dev_kdash-e2e/20261114001948.tsv) | 928 |
| [fmea/runs/vcluster-docker_dev_kdash-e2e/20261114001955.tsv](fmea/runs/vcluster-docker_dev_kdash-e2e/20261114001955.tsv) | 928 |
| [fmea/runs/vcluster-docker_dev_kdash-e2e/20261114002003.tsv](fmea/runs/vcluster-docker_dev_kdash-e2e/20261114002003.tsv) | 928 |
| [fmea/runs/vcluster-docker_dev_kdash-e2e/20261114002011.tsv](fmea/runs/vcluster-docker_dev_kdash-e2e/20261114002011.tsv) | 928 |
| [fmea/runs/vcluster-docker_dev_kdash-e2e/20261114002018.tsv](fmea/runs/vcluster-docker_dev_kdash-e2e/20261114002018.tsv) | 928 |
| [fmea/runs/vcluster-docker_dev_kdash-e2e/20261114002026.tsv](fmea/runs/vcluster-docker_dev_kdash-e2e/20261114002026.tsv) | 928 |
| [fmea/runs/vcluster-docker_dev_kdash-e2e/20261114002034.tsv](fmea/runs/vcluster-docker_dev_kdash-e2e/20261114002034.tsv) | 928 |
| [fmea/runs/vcluster-docker_dev_kdash-e2e/20261114004054.tsv](fmea/runs/vcluster-docker_dev_kdash-e2e/20261114004054.tsv) | 928 |
| [fmea/runs/vcluster-docker_dev_kdash-e2e/20261114010744.tsv](fmea/runs/vcluster-docker_dev_kdash-e2e/20261114010744.tsv) | 928 |
| [fmea/runs/vcluster-docker_dev_kdash-e2e/20261114010824.tsv](fmea/runs/vcluster-docker_dev_kdash-e2e/20261114010824.tsv) | 928 |
| [fmea/runs/vcluster-docker_dev_kdash-e2e/20261114010832.tsv](fmea/runs/vcluster-docker_dev_kdash-e2e/20261114010832.tsv) | 928 |
| [fmea/runs/vcluster-docker_dev_kdash-e2e/20261114010840.tsv](fmea/runs/vcluster-docker_dev_kdash-e2e/20261114010840.tsv) | 928 |
| [fmea/runs/vcluster-docker_dev_kdash-e2e/20261114010848.tsv](fmea/runs/vcluster-docker_dev_kdash-e2e/20261114010848.tsv) | 928 |
| [fmea/runs/vcluster-docker_dev_kdash-e2e/20261114010855.tsv](fmea/runs/vcluster-docker_dev_kdash-e2e/20261114010855.tsv) | 928 |
| [fmea/runs/vcluster-docker_dev_kdash-e2e/20261114010903.tsv](fmea/runs/vcluster-docker_dev_kdash-e2e/20261114010903.tsv) | 928 |
| [fmea/runs/vcluster-docker_dev_kdash-e2e/20261114010911.tsv](fmea/runs/vcluster-docker_dev_kdash-e2e/20261114010911.tsv) | 928 |
| [fmea/runs/vcluster-docker_dev_kdash-e2e/20261114010919.tsv](fmea/runs/vcluster-docker_dev_kdash-e2e/20261114010919.tsv) | 910 |
| [fmea/runs/vcluster-docker_dev_kdash-e2e/20261114012334.tsv](fmea/runs/vcluster-docker_dev_kdash-e2e/20261114012334.tsv) | 928 |
| [fmea/runs/vcluster-docker_dev_kdash-e2e/20261114014618.tsv](fmea/runs/vcluster-docker_dev_kdash-e2e/20261114014618.tsv) | 928 |
| [fmea/runs/vcluster-docker_dev_kdash-e2e/20261114014657.tsv](fmea/runs/vcluster-docker_dev_kdash-e2e/20261114014657.tsv) | 928 |
| [fmea/runs/vcluster-docker_dev_kdash-e2e/20261114014705.tsv](fmea/runs/vcluster-docker_dev_kdash-e2e/20261114014705.tsv) | 928 |
| [fmea/runs/vcluster-docker_dev_kdash-e2e/20261114014713.tsv](fmea/runs/vcluster-docker_dev_kdash-e2e/20261114014713.tsv) | 928 |
| [fmea/runs/vcluster-docker_dev_kdash-e2e/20261114014720.tsv](fmea/runs/vcluster-docker_dev_kdash-e2e/20261114014720.tsv) | 928 |
| [fmea/runs/vcluster-docker_dev_kdash-e2e/20261114014727.tsv](fmea/runs/vcluster-docker_dev_kdash-e2e/20261114014727.tsv) | 928 |
| [fmea/runs/vcluster-docker_dev_kdash-e2e/20261114014735.tsv](fmea/runs/vcluster-docker_dev_kdash-e2e/20261114014735.tsv) | 928 |
| [fmea/runs/vcluster-docker_dev_kdash-e2e/20261114014742.tsv](fmea/runs/vcluster-docker_dev_kdash-e2e/20261114014742.tsv) | 928 |
| [fmea/runs/vcluster-docker_dev_kdash-e2e/20261114014750.tsv](fmea/runs/vcluster-docker_dev_kdash-e2e/20261114014750.tsv) | 928 |
| [fmea/worksheet.csv](fmea/worksheet.csv) | 7675 |
| [fmea/worksheet.json](fmea/worksheet.json) | 15331 |
| [fmea/worksheet.tsv](fmea/worksheet.tsv) | 7579 |
| [index.html](index.html) | 2931 |
| [kdash_audit_20261114_004110.csv](kdash_audit_20261114_004110.csv) | 190689 |
| [kdash_audit_20261114_004110.html](kdash_audit_20261114_004110.html) | 430535 |
| [kdash_audit_20261114_012350.csv](kdash_audit_20261114_012350.csv) | 190431 |
| [kdash_audit_20261114_012350.html](kdash_audit_20261114_012350.html) | 430030 |
| [kdash_audit_20261114_015613.csv](kdash_audit_20261114_015613.csv) | 190123 |
| [kdash_audit_20261114_015613.html](kdash_audit_20261114_015613.html) | 429460 |
| [kdash_memory_dashboard_vcluster-docker_dev_kdash-e2e_20261114_001901.html](kdash_memory_dashboard_vcluster-docker_dev_kdash-e2e_20261114_001901.html) | 95070 |
| [kdash_memory_dashboard_vcluster-docker_dev_kdash-e2e_20261114_001903.html](kdash_memory_dashboard_vcluster-docker_dev_kdash-e2e_20261114_001903.html) | 94978 |
| [kdash_memory_dashboard_vcluster-docker_dev_kdash-e2e_20261114_010745.html](kdash_memory_dashboard_vcluster-docker_dev_kdash-e2e_20261114_010745.html) | 95070 |
| [kdash_memory_dashboard_vcluster-docker_dev_kdash-e2e_20261114_010748.html](kdash_memory_dashboard_vcluster-docker_dev_kdash-e2e_20261114_010748.html) | 94978 |
| [kdash_memory_dashboard_vcluster-docker_dev_kdash-e2e_20261114_014620.html](kdash_memory_dashboard_vcluster-docker_dev_kdash-e2e_20261114_014620.html) | 95070 |
| [kdash_memory_dashboard_vcluster-docker_dev_kdash-e2e_20261114_014622.html](kdash_memory_dashboard_vcluster-docker_dev_kdash-e2e_20261114_014622.html) | 94978 |
| [kdash_namespace_ip_pool_vcluster-docker_dev_kdash-e2e_20261114_001901.html](kdash_namespace_ip_pool_vcluster-docker_dev_kdash-e2e_20261114_001901.html) | 81633 |
| [kdash_namespace_ip_pool_vcluster-docker_dev_kdash-e2e_20261114_010745.html](kdash_namespace_ip_pool_vcluster-docker_dev_kdash-e2e_20261114_010745.html) | 81633 |
| [kdash_namespace_ip_pool_vcluster-docker_dev_kdash-e2e_20261114_014620.html](kdash_namespace_ip_pool_vcluster-docker_dev_kdash-e2e_20261114_014620.html) | 81633 |
| [kdash_namespace_report_vcluster-docker_dev_kdash-e2e_20261114_001853.html](kdash_namespace_report_vcluster-docker_dev_kdash-e2e_20261114_001853.html) | 282473 |
| [kdash_namespace_report_vcluster-docker_dev_kdash-e2e_20261114_002346.html](kdash_namespace_report_vcluster-docker_dev_kdash-e2e_20261114_002346.html) | 312219 |
| [kdash_namespace_report_vcluster-docker_dev_kdash-e2e_20261114_004108.html](kdash_namespace_report_vcluster-docker_dev_kdash-e2e_20261114_004108.html) | 259230 |
| [kdash_namespace_report_vcluster-docker_dev_kdash-e2e_20261114_010737.html](kdash_namespace_report_vcluster-docker_dev_kdash-e2e_20261114_010737.html) | 282466 |
| [kdash_namespace_report_vcluster-docker_dev_kdash-e2e_20261114_011230.html](kdash_namespace_report_vcluster-docker_dev_kdash-e2e_20261114_011230.html) | 310420 |
| [kdash_namespace_report_vcluster-docker_dev_kdash-e2e_20261114_012348.html](kdash_namespace_report_vcluster-docker_dev_kdash-e2e_20261114_012348.html) | 259507 |
| [kdash_namespace_report_vcluster-docker_dev_kdash-e2e_20261114_014612.html](kdash_namespace_report_vcluster-docker_dev_kdash-e2e_20261114_014612.html) | 282476 |
| [kdash_namespace_report_vcluster-docker_dev_kdash-e2e_20261114_015101.html](kdash_namespace_report_vcluster-docker_dev_kdash-e2e_20261114_015101.html) | 308999 |
| [kdash_namespace_report_vcluster-docker_dev_kdash-e2e_20261114_015612.html](kdash_namespace_report_vcluster-docker_dev_kdash-e2e_20261114_015612.html) | 260469 |
| [kdash_network_disk_io_vcluster-docker_dev_kdash-e2e_20261114_001901.html](kdash_network_disk_io_vcluster-docker_dev_kdash-e2e_20261114_001901.html) | 70484 |
| [kdash_network_disk_io_vcluster-docker_dev_kdash-e2e_20261114_010745.html](kdash_network_disk_io_vcluster-docker_dev_kdash-e2e_20261114_010745.html) | 70484 |
| [kdash_network_disk_io_vcluster-docker_dev_kdash-e2e_20261114_014620.html](kdash_network_disk_io_vcluster-docker_dev_kdash-e2e_20261114_014620.html) | 70484 |
| [kdash_node_pools_worker_nodes_vcluster-docker_dev_kdash-e2e_20261114_001901.html](kdash_node_pools_worker_nodes_vcluster-docker_dev_kdash-e2e_20261114_001901.html) | 101527 |
| [kdash_node_pools_worker_nodes_vcluster-docker_dev_kdash-e2e_20261114_001903.html](kdash_node_pools_worker_nodes_vcluster-docker_dev_kdash-e2e_20261114_001903.html) | 101435 |
| [kdash_node_pools_worker_nodes_vcluster-docker_dev_kdash-e2e_20261114_010745.html](kdash_node_pools_worker_nodes_vcluster-docker_dev_kdash-e2e_20261114_010745.html) | 101520 |
| [kdash_node_pools_worker_nodes_vcluster-docker_dev_kdash-e2e_20261114_010748.html](kdash_node_pools_worker_nodes_vcluster-docker_dev_kdash-e2e_20261114_010748.html) | 101428 |
| [kdash_node_pools_worker_nodes_vcluster-docker_dev_kdash-e2e_20261114_014620.html](kdash_node_pools_worker_nodes_vcluster-docker_dev_kdash-e2e_20261114_014620.html) | 101535 |
| [kdash_node_pools_worker_nodes_vcluster-docker_dev_kdash-e2e_20261114_014622.html](kdash_node_pools_worker_nodes_vcluster-docker_dev_kdash-e2e_20261114_014622.html) | 101443 |
| [kdash_pod_container_resources_vcluster-docker_dev_kdash-e2e_20261114_001901.html](kdash_pod_container_resources_vcluster-docker_dev_kdash-e2e_20261114_001901.html) | 95336 |
| [kdash_pod_container_resources_vcluster-docker_dev_kdash-e2e_20261114_010745.html](kdash_pod_container_resources_vcluster-docker_dev_kdash-e2e_20261114_010745.html) | 95336 |
| [kdash_pod_container_resources_vcluster-docker_dev_kdash-e2e_20261114_014620.html](kdash_pod_container_resources_vcluster-docker_dev_kdash-e2e_20261114_014620.html) | 95336 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_001905/csv/cluster_ns.csv](kdash_vcluster-docker_dev_kdash-e2e_20261114_001905/csv/cluster_ns.csv) | 661 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_001905/csv/containers.csv](kdash_vcluster-docker_dev_kdash-e2e_20261114_001905/csv/containers.csv) | 695 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_001905/csv/io_nodes.csv](kdash_vcluster-docker_dev_kdash-e2e_20261114_001905/csv/io_nodes.csv) | 247 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_001905/csv/io_pods.csv](kdash_vcluster-docker_dev_kdash-e2e_20261114_001905/csv/io_pods.csv) | 330 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_001905/csv/ip.csv](kdash_vcluster-docker_dev_kdash-e2e_20261114_001905/csv/ip.csv) | 540 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_001905/csv/ipblocks.csv](kdash_vcluster-docker_dev_kdash-e2e_20261114_001905/csv/ipblocks.csv) | 180 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_001905/csv/memory.csv](kdash_vcluster-docker_dev_kdash-e2e_20261114_001905/csv/memory.csv) | 547 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_001905/csv/meta.csv](kdash_vcluster-docker_dev_kdash-e2e_20261114_001905/csv/meta.csv) | 1199 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_001905/csv/nodes.csv](kdash_vcluster-docker_dev_kdash-e2e_20261114_001905/csv/nodes.csv) | 691 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_001905/csv/pods.csv](kdash_vcluster-docker_dev_kdash-e2e_20261114_001905/csv/pods.csv) | 1057 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_001905/csv/pools.csv](kdash_vcluster-docker_dev_kdash-e2e_20261114_001905/csv/pools.csv) | 483 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_001905/csv/services.csv](kdash_vcluster-docker_dev_kdash-e2e_20261114_001905/csv/services.csv) | 178 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_001905/csv/subnets.csv](kdash_vcluster-docker_dev_kdash-e2e_20261114_001905/csv/subnets.csv) | 38 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_001905/csv/wl_node.csv](kdash_vcluster-docker_dev_kdash-e2e_20261114_001905/csv/wl_node.csv) | 419 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_001905/csv/workloads.csv](kdash_vcluster-docker_dev_kdash-e2e_20261114_001905/csv/workloads.csv) | 514 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_001905/diagnostics/events.tsv](kdash_vcluster-docker_dev_kdash-e2e_20261114_001905/diagnostics/events.tsv) | 806 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_001905/diagnostics/health-volume-usage.tsv](kdash_vcluster-docker_dev_kdash-e2e_20261114_001905/diagnostics/health-volume-usage.tsv) | 0 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_001905/fmea.csv](kdash_vcluster-docker_dev_kdash-e2e_20261114_001905/fmea.csv) | 7675 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_001905/report.html](kdash_vcluster-docker_dev_kdash-e2e_20261114_001905/report.html) | 35123 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_001905/secrets.csv](kdash_vcluster-docker_dev_kdash-e2e_20261114_001905/secrets.csv) | 242 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_001905/secrets.json](kdash_vcluster-docker_dev_kdash-e2e_20261114_001905/secrets.json) | 295 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_001905/tsv/cluster_ns.tsv](kdash_vcluster-docker_dev_kdash-e2e_20261114_001905/tsv/cluster_ns.tsv) | 661 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_001905/tsv/containers.tsv](kdash_vcluster-docker_dev_kdash-e2e_20261114_001905/tsv/containers.tsv) | 716 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_001905/tsv/io_nodes.tsv](kdash_vcluster-docker_dev_kdash-e2e_20261114_001905/tsv/io_nodes.tsv) | 269 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_001905/tsv/io_pods.tsv](kdash_vcluster-docker_dev_kdash-e2e_20261114_001905/tsv/io_pods.tsv) | 360 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_001905/tsv/ip.tsv](kdash_vcluster-docker_dev_kdash-e2e_20261114_001905/tsv/ip.tsv) | 538 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_001905/tsv/ipblocks.tsv](kdash_vcluster-docker_dev_kdash-e2e_20261114_001905/tsv/ipblocks.tsv) | 178 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_001905/tsv/memory.tsv](kdash_vcluster-docker_dev_kdash-e2e_20261114_001905/tsv/memory.tsv) | 555 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_001905/tsv/meta.tsv](kdash_vcluster-docker_dev_kdash-e2e_20261114_001905/tsv/meta.tsv) | 1211 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_001905/tsv/nodes.tsv](kdash_vcluster-docker_dev_kdash-e2e_20261114_001905/tsv/nodes.tsv) | 705 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_001905/tsv/pods.tsv](kdash_vcluster-docker_dev_kdash-e2e_20261114_001905/tsv/pods.tsv) | 1066 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_001905/tsv/pools.tsv](kdash_vcluster-docker_dev_kdash-e2e_20261114_001905/tsv/pools.tsv) | 489 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_001905/tsv/services.tsv](kdash_vcluster-docker_dev_kdash-e2e_20261114_001905/tsv/services.tsv) | 182 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_001905/tsv/subnets.tsv](kdash_vcluster-docker_dev_kdash-e2e_20261114_001905/tsv/subnets.tsv) | 38 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_001905/tsv/wl_node.tsv](kdash_vcluster-docker_dev_kdash-e2e_20261114_001905/tsv/wl_node.tsv) | 417 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_001905/tsv/workloads.tsv](kdash_vcluster-docker_dev_kdash-e2e_20261114_001905/tsv/workloads.tsv) | 547 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_001905.html](kdash_vcluster-docker_dev_kdash-e2e_20261114_001905.html) | 35123 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_010749/csv/cluster_ns.csv](kdash_vcluster-docker_dev_kdash-e2e_20261114_010749/csv/cluster_ns.csv) | 661 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_010749/csv/containers.csv](kdash_vcluster-docker_dev_kdash-e2e_20261114_010749/csv/containers.csv) | 695 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_010749/csv/io_nodes.csv](kdash_vcluster-docker_dev_kdash-e2e_20261114_010749/csv/io_nodes.csv) | 247 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_010749/csv/io_pods.csv](kdash_vcluster-docker_dev_kdash-e2e_20261114_010749/csv/io_pods.csv) | 330 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_010749/csv/ip.csv](kdash_vcluster-docker_dev_kdash-e2e_20261114_010749/csv/ip.csv) | 540 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_010749/csv/ipblocks.csv](kdash_vcluster-docker_dev_kdash-e2e_20261114_010749/csv/ipblocks.csv) | 180 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_010749/csv/memory.csv](kdash_vcluster-docker_dev_kdash-e2e_20261114_010749/csv/memory.csv) | 547 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_010749/csv/meta.csv](kdash_vcluster-docker_dev_kdash-e2e_20261114_010749/csv/meta.csv) | 1199 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_010749/csv/nodes.csv](kdash_vcluster-docker_dev_kdash-e2e_20261114_010749/csv/nodes.csv) | 691 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_010749/csv/pods.csv](kdash_vcluster-docker_dev_kdash-e2e_20261114_010749/csv/pods.csv) | 1057 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_010749/csv/pools.csv](kdash_vcluster-docker_dev_kdash-e2e_20261114_010749/csv/pools.csv) | 483 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_010749/csv/services.csv](kdash_vcluster-docker_dev_kdash-e2e_20261114_010749/csv/services.csv) | 178 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_010749/csv/subnets.csv](kdash_vcluster-docker_dev_kdash-e2e_20261114_010749/csv/subnets.csv) | 38 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_010749/csv/wl_node.csv](kdash_vcluster-docker_dev_kdash-e2e_20261114_010749/csv/wl_node.csv) | 419 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_010749/csv/workloads.csv](kdash_vcluster-docker_dev_kdash-e2e_20261114_010749/csv/workloads.csv) | 514 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_010749/diagnostics/events.tsv](kdash_vcluster-docker_dev_kdash-e2e_20261114_010749/diagnostics/events.tsv) | 982 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_010749/diagnostics/health-volume-usage.tsv](kdash_vcluster-docker_dev_kdash-e2e_20261114_010749/diagnostics/health-volume-usage.tsv) | 0 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_010749/fmea.csv](kdash_vcluster-docker_dev_kdash-e2e_20261114_010749/fmea.csv) | 7675 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_010749/report.html](kdash_vcluster-docker_dev_kdash-e2e_20261114_010749/report.html) | 35123 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_010749/secrets.csv](kdash_vcluster-docker_dev_kdash-e2e_20261114_010749/secrets.csv) | 242 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_010749/secrets.json](kdash_vcluster-docker_dev_kdash-e2e_20261114_010749/secrets.json) | 295 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_010749/tsv/cluster_ns.tsv](kdash_vcluster-docker_dev_kdash-e2e_20261114_010749/tsv/cluster_ns.tsv) | 661 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_010749/tsv/containers.tsv](kdash_vcluster-docker_dev_kdash-e2e_20261114_010749/tsv/containers.tsv) | 716 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_010749/tsv/io_nodes.tsv](kdash_vcluster-docker_dev_kdash-e2e_20261114_010749/tsv/io_nodes.tsv) | 269 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_010749/tsv/io_pods.tsv](kdash_vcluster-docker_dev_kdash-e2e_20261114_010749/tsv/io_pods.tsv) | 360 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_010749/tsv/ip.tsv](kdash_vcluster-docker_dev_kdash-e2e_20261114_010749/tsv/ip.tsv) | 538 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_010749/tsv/ipblocks.tsv](kdash_vcluster-docker_dev_kdash-e2e_20261114_010749/tsv/ipblocks.tsv) | 178 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_010749/tsv/memory.tsv](kdash_vcluster-docker_dev_kdash-e2e_20261114_010749/tsv/memory.tsv) | 555 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_010749/tsv/meta.tsv](kdash_vcluster-docker_dev_kdash-e2e_20261114_010749/tsv/meta.tsv) | 1211 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_010749/tsv/nodes.tsv](kdash_vcluster-docker_dev_kdash-e2e_20261114_010749/tsv/nodes.tsv) | 705 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_010749/tsv/pods.tsv](kdash_vcluster-docker_dev_kdash-e2e_20261114_010749/tsv/pods.tsv) | 1066 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_010749/tsv/pools.tsv](kdash_vcluster-docker_dev_kdash-e2e_20261114_010749/tsv/pools.tsv) | 489 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_010749/tsv/services.tsv](kdash_vcluster-docker_dev_kdash-e2e_20261114_010749/tsv/services.tsv) | 182 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_010749/tsv/subnets.tsv](kdash_vcluster-docker_dev_kdash-e2e_20261114_010749/tsv/subnets.tsv) | 38 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_010749/tsv/wl_node.tsv](kdash_vcluster-docker_dev_kdash-e2e_20261114_010749/tsv/wl_node.tsv) | 417 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_010749/tsv/workloads.tsv](kdash_vcluster-docker_dev_kdash-e2e_20261114_010749/tsv/workloads.tsv) | 547 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_010749.html](kdash_vcluster-docker_dev_kdash-e2e_20261114_010749.html) | 35123 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_014624/csv/cluster_ns.csv](kdash_vcluster-docker_dev_kdash-e2e_20261114_014624/csv/cluster_ns.csv) | 663 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_014624/csv/containers.csv](kdash_vcluster-docker_dev_kdash-e2e_20261114_014624/csv/containers.csv) | 695 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_014624/csv/io_nodes.csv](kdash_vcluster-docker_dev_kdash-e2e_20261114_014624/csv/io_nodes.csv) | 247 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_014624/csv/io_pods.csv](kdash_vcluster-docker_dev_kdash-e2e_20261114_014624/csv/io_pods.csv) | 330 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_014624/csv/ip.csv](kdash_vcluster-docker_dev_kdash-e2e_20261114_014624/csv/ip.csv) | 540 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_014624/csv/ipblocks.csv](kdash_vcluster-docker_dev_kdash-e2e_20261114_014624/csv/ipblocks.csv) | 180 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_014624/csv/memory.csv](kdash_vcluster-docker_dev_kdash-e2e_20261114_014624/csv/memory.csv) | 547 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_014624/csv/meta.csv](kdash_vcluster-docker_dev_kdash-e2e_20261114_014624/csv/meta.csv) | 1199 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_014624/csv/nodes.csv](kdash_vcluster-docker_dev_kdash-e2e_20261114_014624/csv/nodes.csv) | 691 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_014624/csv/pods.csv](kdash_vcluster-docker_dev_kdash-e2e_20261114_014624/csv/pods.csv) | 1057 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_014624/csv/pools.csv](kdash_vcluster-docker_dev_kdash-e2e_20261114_014624/csv/pools.csv) | 483 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_014624/csv/services.csv](kdash_vcluster-docker_dev_kdash-e2e_20261114_014624/csv/services.csv) | 178 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_014624/csv/subnets.csv](kdash_vcluster-docker_dev_kdash-e2e_20261114_014624/csv/subnets.csv) | 38 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_014624/csv/wl_node.csv](kdash_vcluster-docker_dev_kdash-e2e_20261114_014624/csv/wl_node.csv) | 419 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_014624/csv/workloads.csv](kdash_vcluster-docker_dev_kdash-e2e_20261114_014624/csv/workloads.csv) | 514 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_014624/diagnostics/events.tsv](kdash_vcluster-docker_dev_kdash-e2e_20261114_014624/diagnostics/events.tsv) | 983 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_014624/diagnostics/health-volume-usage.tsv](kdash_vcluster-docker_dev_kdash-e2e_20261114_014624/diagnostics/health-volume-usage.tsv) | 0 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_014624/fmea.csv](kdash_vcluster-docker_dev_kdash-e2e_20261114_014624/fmea.csv) | 7675 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_014624/report.html](kdash_vcluster-docker_dev_kdash-e2e_20261114_014624/report.html) | 35123 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_014624/secrets.csv](kdash_vcluster-docker_dev_kdash-e2e_20261114_014624/secrets.csv) | 242 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_014624/secrets.json](kdash_vcluster-docker_dev_kdash-e2e_20261114_014624/secrets.json) | 295 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_014624/tsv/cluster_ns.tsv](kdash_vcluster-docker_dev_kdash-e2e_20261114_014624/tsv/cluster_ns.tsv) | 663 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_014624/tsv/containers.tsv](kdash_vcluster-docker_dev_kdash-e2e_20261114_014624/tsv/containers.tsv) | 716 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_014624/tsv/io_nodes.tsv](kdash_vcluster-docker_dev_kdash-e2e_20261114_014624/tsv/io_nodes.tsv) | 269 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_014624/tsv/io_pods.tsv](kdash_vcluster-docker_dev_kdash-e2e_20261114_014624/tsv/io_pods.tsv) | 360 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_014624/tsv/ip.tsv](kdash_vcluster-docker_dev_kdash-e2e_20261114_014624/tsv/ip.tsv) | 538 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_014624/tsv/ipblocks.tsv](kdash_vcluster-docker_dev_kdash-e2e_20261114_014624/tsv/ipblocks.tsv) | 178 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_014624/tsv/memory.tsv](kdash_vcluster-docker_dev_kdash-e2e_20261114_014624/tsv/memory.tsv) | 555 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_014624/tsv/meta.tsv](kdash_vcluster-docker_dev_kdash-e2e_20261114_014624/tsv/meta.tsv) | 1211 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_014624/tsv/nodes.tsv](kdash_vcluster-docker_dev_kdash-e2e_20261114_014624/tsv/nodes.tsv) | 705 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_014624/tsv/pods.tsv](kdash_vcluster-docker_dev_kdash-e2e_20261114_014624/tsv/pods.tsv) | 1066 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_014624/tsv/pools.tsv](kdash_vcluster-docker_dev_kdash-e2e_20261114_014624/tsv/pools.tsv) | 489 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_014624/tsv/services.tsv](kdash_vcluster-docker_dev_kdash-e2e_20261114_014624/tsv/services.tsv) | 182 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_014624/tsv/subnets.tsv](kdash_vcluster-docker_dev_kdash-e2e_20261114_014624/tsv/subnets.tsv) | 38 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_014624/tsv/wl_node.tsv](kdash_vcluster-docker_dev_kdash-e2e_20261114_014624/tsv/wl_node.tsv) | 417 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_014624/tsv/workloads.tsv](kdash_vcluster-docker_dev_kdash-e2e_20261114_014624/tsv/workloads.tsv) | 547 |
| [kdash_vcluster-docker_dev_kdash-e2e_20261114_014624.html](kdash_vcluster-docker_dev_kdash-e2e_20261114_014624.html) | 35123 |
| [kdash_workloads_per_worker_node_vcluster-docker_dev_kdash-e2e_20261114_001901.html](kdash_workloads_per_worker_node_vcluster-docker_dev_kdash-e2e_20261114_001901.html) | 84829 |
| [kdash_workloads_per_worker_node_vcluster-docker_dev_kdash-e2e_20261114_010745.html](kdash_workloads_per_worker_node_vcluster-docker_dev_kdash-e2e_20261114_010745.html) | 84829 |
| [kdash_workloads_per_worker_node_vcluster-docker_dev_kdash-e2e_20261114_014620.html](kdash_workloads_per_worker_node_vcluster-docker_dev_kdash-e2e_20261114_014620.html) | 84829 |
| [screenshots/fmea.png](screenshots/fmea.png) | 129078 |
| [screenshots/history.png](screenshots/history.png) | 166179 |
| [screenshots/io.png](screenshots/io.png) | 147381 |
| [screenshots/ip.png](screenshots/ip.png) | 178425 |
| [screenshots/mem.png](screenshots/mem.png) | 164912 |
| [screenshots/nodes.png](screenshots/nodes.png) | 169441 |
| [screenshots/overview.png](screenshots/overview.png) | 222109 |
| [screenshots/pods.png](screenshots/pods.png) | 179093 |
| [screenshots/workloads.png](screenshots/workloads.png) | 169050 |

Verify the published bytes with `sha256sum -c SHA256SUMS` in this directory.
Keep the relative filenames together when sharing. Review operational metadata
before distributing reports. Historical reports retain their original capture
version: [4.19.2](../html419/README.md), [4.23.1](../html423/README.md), [4.24.1](../html4241/README.md), [4.27.3](../html4273/README.md), [4.27.4](../html4274/README.md), [4.12.0](../html/).
