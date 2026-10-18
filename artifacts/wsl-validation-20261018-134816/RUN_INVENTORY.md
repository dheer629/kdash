# kdash WSL vcluster validation run wsl-validation-20261018-134816

Started 2026-10-18T13:48:16+00:00, finished 2026-10-18T19:24:46+05:30. Context `devops-admin@local-cluster`, timezone Asia/Kolkata.

kdash 4.12.0, live window 5 minute(s) per namespace, poll 5s, history sample 5s, terminal 170x50.

## Steps and logs

| Step | Log |
|---|---|
| 01-preinstall | `artifacts/wsl-validation-20261018-134816/logs/01-preinstall.log` |
| 02-uninstall-preview | `artifacts/wsl-validation-20261018-134816/logs/02-uninstall-preview.log` |
| 03-uninstall | `artifacts/wsl-validation-20261018-134816/logs/03-uninstall.log` |
| 04-uninstall-verification | `artifacts/wsl-validation-20261018-134816/logs/04-uninstall-verification.log` |
| 05-install | `artifacts/wsl-validation-20261018-134816/logs/05-install.log` |
| 06-install-verification | `artifacts/wsl-validation-20261018-134816/logs/06-install-verification.log` |
| 07-disclaimer-accept | `artifacts/wsl-validation-20261018-134816/logs/07-disclaimer-accept.log` |
| 08-oneshot-pods-text | `artifacts/wsl-validation-20261018-134816/logs/08-oneshot-pods-text.log` |
| 10-session-report-orders-service-e2e | `artifacts/wsl-validation-20261018-134816/logs/10-session-report-orders-service-e2e.log` |
| 10-session-report-gitops-core | `artifacts/wsl-validation-20261018-134816/logs/10-session-report-gitops-core.log` |
| 10-session-report-ml-service-prod | `artifacts/wsl-validation-20261018-134816/logs/10-session-report-ml-service-prod.log` |
| 11-snapshot-all-orders-service-e2e | `artifacts/wsl-validation-20261018-134816/logs/11-snapshot-all-orders-service-e2e.log` |
| 11-snapshot-all-gitops-core | `artifacts/wsl-validation-20261018-134816/logs/11-snapshot-all-gitops-core.log` |
| 11-snapshot-all-ml-service-prod | `artifacts/wsl-validation-20261018-134816/logs/11-snapshot-all-ml-service-prod.log` |
| 12-report-bundle-orders-service-e2e | `artifacts/wsl-validation-20261018-134816/logs/12-report-bundle-orders-service-e2e.log` |
| 12-report-bundle-gitops-core | `artifacts/wsl-validation-20261018-134816/logs/12-report-bundle-gitops-core.log` |
| 12-report-bundle-ml-service-prod | `artifacts/wsl-validation-20261018-134816/logs/12-report-bundle-ml-service-prod.log` |
| 13-audit-orders-service-e2e | `artifacts/wsl-validation-20261018-134816/logs/13-audit-orders-service-e2e.log` |
| 13-audit-gitops-core | `artifacts/wsl-validation-20261018-134816/logs/13-audit-gitops-core.log` |
| 13-audit-ml-service-prod | `artifacts/wsl-validation-20261018-134816/logs/13-audit-ml-service-prod.log` |
| 14-audit-report-orders-service-e2e | `artifacts/wsl-validation-20261018-134816/logs/14-audit-report-orders-service-e2e.log` |
| 14-audit-report-gitops-core | `artifacts/wsl-validation-20261018-134816/logs/14-audit-report-gitops-core.log` |
| 14-audit-report-ml-service-prod | `artifacts/wsl-validation-20261018-134816/logs/14-audit-report-ml-service-prod.log` |

## Namespaces

| Namespace | tmux session | exit | live seconds | recorded session | CLI captures | HTML reports |
|---|---|---|---|---|---|---|
| orders-service-e2e | kdash-validation-1 | 0 | 329 | `kdash_devops-admin_local-cluster_orders-service-e2e_20261018_191832` | 7 | 10 |
| ml-service-prod | kdash-validation-2 | 0 | 329 | `kdash_devops-admin_local-cluster_ml-service-prod_20261018_191832` | 7 | 10 |
| gitops-core | kdash-validation-3 | 0 | 329 | `kdash_devops-admin_local-cluster_gitops-core_20261018_191832` | 7 | 10 |

## HTML and table files produced

### orders-service-e2e

index.html	2563 bytes
kdash_devops-admin_local-cluster_orders-service-e2e_20261018_192416.html	93265 bytes
kdash_memory_dashboard_devops-admin_local-cluster_orders-service-e2e_20261018_192414.html	148422 bytes
kdash_namespace_ip_pool_devops-admin_local-cluster_orders-service-e2e_20261018_192414.html	108152 bytes
kdash_namespace_report_devops-admin_local-cluster_orders-service-e2e_20261018_192340.html	593817 bytes
kdash_namespace_report_devops-admin_local-cluster_orders-service-e2e_20261018_192402.html	573539 bytes
kdash_network_disk_io_devops-admin_local-cluster_orders-service-e2e_20261018_192414.html	101284 bytes
kdash_node_pools_worker_nodes_devops-admin_local-cluster_orders-service-e2e_20261018_192414.html	101433 bytes
kdash_pod_container_resources_devops-admin_local-cluster_orders-service-e2e_20261018_192414.html	201519 bytes
kdash_workloads_per_worker_node_devops-admin_local-cluster_orders-service-e2e_20261018_192414.html	139604 bytes

Audit files: audit_202610.log audit_202610.log.lock kdash_audit_20261018_192416.csv kdash_audit_20261018_192416.html 

### ml-service-prod

index.html	2495 bytes
kdash_devops-admin_local-cluster_ml-service-prod_20261018_192430.html	31781 bytes
kdash_memory_dashboard_devops-admin_local-cluster_ml-service-prod_20261018_192428.html	96534 bytes
kdash_namespace_ip_pool_devops-admin_local-cluster_ml-service-prod_20261018_192428.html	79279 bytes
kdash_namespace_report_devops-admin_local-cluster_ml-service-prod_20261018_192340.html	267373 bytes
kdash_namespace_report_devops-admin_local-cluster_ml-service-prod_20261018_192417.html	251593 bytes
kdash_network_disk_io_devops-admin_local-cluster_ml-service-prod_20261018_192428.html	74524 bytes
kdash_node_pools_worker_nodes_devops-admin_local-cluster_ml-service-prod_20261018_192428.html	97373 bytes
kdash_pod_container_resources_devops-admin_local-cluster_ml-service-prod_20261018_192428.html	91356 bytes
kdash_workloads_per_worker_node_devops-admin_local-cluster_ml-service-prod_20261018_192428.html	83344 bytes

Audit files: audit_202610.log audit_202610.log.lock kdash_audit_20261018_192431.csv kdash_audit_20261018_192431.html 

### gitops-core

index.html	2444 bytes
kdash_devops-admin_local-cluster_gitops-core_20261018_192445.html	41468 bytes
kdash_memory_dashboard_devops-admin_local-cluster_gitops-core_20261018_192443.html	104688 bytes
kdash_namespace_ip_pool_devops-admin_local-cluster_gitops-core_20261018_192443.html	82487 bytes
kdash_namespace_report_devops-admin_local-cluster_gitops-core_20261018_192340.html	315200 bytes
kdash_namespace_report_devops-admin_local-cluster_gitops-core_20261018_192431.html	297827 bytes
kdash_network_disk_io_devops-admin_local-cluster_gitops-core_20261018_192443.html	78493 bytes
kdash_node_pools_worker_nodes_devops-admin_local-cluster_gitops-core_20261018_192443.html	97396 bytes
kdash_pod_container_resources_devops-admin_local-cluster_gitops-core_20261018_192443.html	105924 bytes
kdash_workloads_per_worker_node_devops-admin_local-cluster_gitops-core_20261018_192443.html	95462 bytes

Audit files: audit_202610.log audit_202610.log.lock kdash_audit_20261018_192446.csv kdash_audit_20261018_192446.html 

## Failures

None.

## Integrity

```
controller-actions.json run-metadata.json 
411b59b2a9a09b00d40576123fabdd0ebe320f1d3169a53f7b8ee7c2fca34215  artifacts/wsl-validation-20261018-134816/orders-service-e2e/cli/01-pods.ansi
30426c8d703a3c349e59e4cd80d4d6270a7cb63da8676a1bd472f67823ff706b  artifacts/wsl-validation-20261018-134816/orders-service-e2e/cli/02-nodes.ansi
a03bc2da27cb023d2a1d4169c488d4b933e112ee02fe9a4b6020dc3d4fed3534  artifacts/wsl-validation-20261018-134816/orders-service-e2e/cli/03-workloads.ansi
05db50c4fcadfe1c854f32a88ff701ac542cd3b17171be9f52a27a9446c96f39  artifacts/wsl-validation-20261018-134816/orders-service-e2e/cli/04-ip.ansi
c7b9506d632b30100f805896775e0754b5048b50a4f9a8d7a5c13aa4ded3991d  artifacts/wsl-validation-20261018-134816/orders-service-e2e/cli/05-mem.ansi
fdb49e3edc838fb75b71f00f7024fa10910b9956f208382ee72cc9cfacd4036b  artifacts/wsl-validation-20261018-134816/orders-service-e2e/cli/06-io.ansi
3b40e05b9886d896d07fa9eacbf9c93fd17975a7b3693f0fc749a9aaa1dd3685  artifacts/wsl-validation-20261018-134816/orders-service-e2e/cli/07-alerts.ansi
438300ad919e5d49031f265f2375c01480cde159d820a1532061180dc82ad0a5  artifacts/wsl-validation-20261018-134816/ml-service-prod/cli/01-pods.ansi
4ef0f28f2fd24d7c6268742e8528bb4cd73ff39566852ce919672d02e2f79921  artifacts/wsl-validation-20261018-134816/ml-service-prod/cli/02-nodes.ansi
56fc3af0355a6a12673532a00461ae967f9dd1110d4c392bb7b24cf5acd0857a  artifacts/wsl-validation-20261018-134816/ml-service-prod/cli/03-workloads.ansi
fef05dc7b77a079c315af8c440bb19638cb2f46e276ef501e71a9ffb9443b739  artifacts/wsl-validation-20261018-134816/ml-service-prod/cli/04-ip.ansi
0df0a9ff97e349f9f3d241c15a7ccba4a9eabf2685515dd4a5ec8b3e4091bf66  artifacts/wsl-validation-20261018-134816/ml-service-prod/cli/05-mem.ansi
1c4311a65cdd8ead8d88c6e415440e6a3e0b68b0dc0eaaa8511d35c53bf45a25  artifacts/wsl-validation-20261018-134816/ml-service-prod/cli/06-io.ansi
665dba4cd0f18b37e9213c7fd355e766630b88dd22c28db799c599650c3cd73e  artifacts/wsl-validation-20261018-134816/ml-service-prod/cli/07-alerts.ansi
89b37c95f557997237907599f8d92de84cf3be7814caba11c9f3fd3e23b690c2  artifacts/wsl-validation-20261018-134816/gitops-core/cli/01-pods.ansi
964668be628a6ba8939688b2d265b527204f74ba180929cecc2e0fb3bd500641  artifacts/wsl-validation-20261018-134816/gitops-core/cli/02-nodes.ansi
f4191602caa5fdccc58fd0d7fa8e7fd9b239d7d67901bfb82dc93137ac415e5d  artifacts/wsl-validation-20261018-134816/gitops-core/cli/03-workloads.ansi
03c6a9b9459d9bae3ca5490708bb20c76057c4e6731256a6faa4f7aeb4a8a81c  artifacts/wsl-validation-20261018-134816/gitops-core/cli/04-ip.ansi
c59b3c91f8ebe8119030c232c12986de025bfad5aacd95dc195b4dfd06451136  artifacts/wsl-validation-20261018-134816/gitops-core/cli/05-mem.ansi
956bf67de387cb1774940eeaa092d9c7a38231c86989b61719cc76bb10d38108  artifacts/wsl-validation-20261018-134816/gitops-core/cli/06-io.ansi
212ae300c5b683b602c69af40104c7cba0a96932e9b47feb6e0b3eaf23a1f8c9  artifacts/wsl-validation-20261018-134816/gitops-core/cli/07-alerts.ansi
```
