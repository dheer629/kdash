# kdash WSL vcluster validation run wsl-validation-20261018-115201

Started 2026-10-18T11:52:01+00:00, finished 2026-10-18T17:28:27+05:30. Context `devops-admin@local-cluster`, timezone Asia/Kolkata.

kdash 4.12.0, live window 5 minute(s) per namespace, poll 5s, history sample 5s, terminal 170x50.

## Steps and logs

| Step | Log |
|---|---|
| 01-preinstall | `artifacts/wsl-validation-20261018-115201/logs/01-preinstall.log` |
| 02-uninstall-preview | `artifacts/wsl-validation-20261018-115201/logs/02-uninstall-preview.log` |
| 03-uninstall | `artifacts/wsl-validation-20261018-115201/logs/03-uninstall.log` |
| 04-uninstall-verification | `artifacts/wsl-validation-20261018-115201/logs/04-uninstall-verification.log` |
| 05-install | `artifacts/wsl-validation-20261018-115201/logs/05-install.log` |
| 06-install-verification | `artifacts/wsl-validation-20261018-115201/logs/06-install-verification.log` |
| 07-disclaimer-accept | `artifacts/wsl-validation-20261018-115201/logs/07-disclaimer-accept.log` |
| 08-oneshot-pods-text | `artifacts/wsl-validation-20261018-115201/logs/08-oneshot-pods-text.log` |
| 10-session-report-orders-service-e2e | `artifacts/wsl-validation-20261018-115201/logs/10-session-report-orders-service-e2e.log` |
| 10-session-report-gitops-core | `artifacts/wsl-validation-20261018-115201/logs/10-session-report-gitops-core.log` |
| 10-session-report-ml-service-prod | `artifacts/wsl-validation-20261018-115201/logs/10-session-report-ml-service-prod.log` |
| 11-snapshot-all-orders-service-e2e | `artifacts/wsl-validation-20261018-115201/logs/11-snapshot-all-orders-service-e2e.log` |
| 11-snapshot-all-gitops-core | `artifacts/wsl-validation-20261018-115201/logs/11-snapshot-all-gitops-core.log` |
| 11-snapshot-all-ml-service-prod | `artifacts/wsl-validation-20261018-115201/logs/11-snapshot-all-ml-service-prod.log` |
| 12-report-bundle-orders-service-e2e | `artifacts/wsl-validation-20261018-115201/logs/12-report-bundle-orders-service-e2e.log` |
| 12-report-bundle-gitops-core | `artifacts/wsl-validation-20261018-115201/logs/12-report-bundle-gitops-core.log` |
| 12-report-bundle-ml-service-prod | `artifacts/wsl-validation-20261018-115201/logs/12-report-bundle-ml-service-prod.log` |
| 13-audit-orders-service-e2e | `artifacts/wsl-validation-20261018-115201/logs/13-audit-orders-service-e2e.log` |
| 13-audit-gitops-core | `artifacts/wsl-validation-20261018-115201/logs/13-audit-gitops-core.log` |
| 13-audit-ml-service-prod | `artifacts/wsl-validation-20261018-115201/logs/13-audit-ml-service-prod.log` |
| 14-audit-report-orders-service-e2e | `artifacts/wsl-validation-20261018-115201/logs/14-audit-report-orders-service-e2e.log` |
| 14-audit-report-gitops-core | `artifacts/wsl-validation-20261018-115201/logs/14-audit-report-gitops-core.log` |
| 14-audit-report-ml-service-prod | `artifacts/wsl-validation-20261018-115201/logs/14-audit-report-ml-service-prod.log` |

## Namespaces

| Namespace | tmux session | exit | live seconds | recorded session | CLI captures | HTML reports |
|---|---|---|---|---|---|---|
| orders-service-e2e | kdash-validation-1 | 0 | 325 | `kdash_devops-admin_local-cluster_orders-service-e2e_20261018_172217` | 7 | 10 |
| ml-service-prod | kdash-validation-2 | 0 | 325 | `kdash_devops-admin_local-cluster_ml-service-prod_20261018_172217` | 7 | 10 |
| gitops-core | kdash-validation-3 | 0 | 325 | `kdash_devops-admin_local-cluster_gitops-core_20261018_172217` | 7 | 10 |

## HTML and table files produced

### orders-service-e2e

index.html	2563 bytes
kdash_devops-admin_local-cluster_orders-service-e2e_20261018_172757.html	93271 bytes
kdash_memory_dashboard_devops-admin_local-cluster_orders-service-e2e_20261018_172755.html	148426 bytes
kdash_namespace_ip_pool_devops-admin_local-cluster_orders-service-e2e_20261018_172755.html	108166 bytes
kdash_namespace_report_devops-admin_local-cluster_orders-service-e2e_20261018_172721.html	598199 bytes
kdash_namespace_report_devops-admin_local-cluster_orders-service-e2e_20261018_172743.html	576107 bytes
kdash_network_disk_io_devops-admin_local-cluster_orders-service-e2e_20261018_172755.html	101055 bytes
kdash_node_pools_worker_nodes_devops-admin_local-cluster_orders-service-e2e_20261018_172755.html	101446 bytes
kdash_pod_container_resources_devops-admin_local-cluster_orders-service-e2e_20261018_172755.html	201524 bytes
kdash_workloads_per_worker_node_devops-admin_local-cluster_orders-service-e2e_20261018_172755.html	139606 bytes

Audit files: audit_202610.log audit_202610.log.lock kdash_audit_20261018_172757.csv kdash_audit_20261018_172757.html 

### ml-service-prod

index.html	2495 bytes
kdash_devops-admin_local-cluster_ml-service-prod_20261018_172811.html	31781 bytes
kdash_memory_dashboard_devops-admin_local-cluster_ml-service-prod_20261018_172810.html	96763 bytes
kdash_namespace_ip_pool_devops-admin_local-cluster_ml-service-prod_20261018_172810.html	79279 bytes
kdash_namespace_report_devops-admin_local-cluster_ml-service-prod_20261018_172721.html	267279 bytes
kdash_namespace_report_devops-admin_local-cluster_ml-service-prod_20261018_172758.html	251382 bytes
kdash_network_disk_io_devops-admin_local-cluster_ml-service-prod_20261018_172810.html	74461 bytes
kdash_node_pools_worker_nodes_devops-admin_local-cluster_ml-service-prod_20261018_172810.html	97384 bytes
kdash_pod_container_resources_devops-admin_local-cluster_ml-service-prod_20261018_172810.html	91358 bytes
kdash_workloads_per_worker_node_devops-admin_local-cluster_ml-service-prod_20261018_172810.html	83344 bytes

Audit files: audit_202610.log audit_202610.log.lock kdash_audit_20261018_172812.csv kdash_audit_20261018_172812.html 

### gitops-core

index.html	2444 bytes
kdash_devops-admin_local-cluster_gitops-core_20261018_172826.html	41468 bytes
kdash_memory_dashboard_devops-admin_local-cluster_gitops-core_20261018_172824.html	104688 bytes
kdash_namespace_ip_pool_devops-admin_local-cluster_gitops-core_20261018_172824.html	82487 bytes
kdash_namespace_report_devops-admin_local-cluster_gitops-core_20261018_172721.html	314898 bytes
kdash_namespace_report_devops-admin_local-cluster_gitops-core_20261018_172812.html	298063 bytes
kdash_network_disk_io_devops-admin_local-cluster_gitops-core_20261018_172824.html	78010 bytes
kdash_node_pools_worker_nodes_devops-admin_local-cluster_gitops-core_20261018_172824.html	97395 bytes
kdash_pod_container_resources_devops-admin_local-cluster_gitops-core_20261018_172824.html	106022 bytes
kdash_workloads_per_worker_node_devops-admin_local-cluster_gitops-core_20261018_172824.html	95462 bytes

Audit files: audit_202610.log audit_202610.log.lock kdash_audit_20261018_172826.csv kdash_audit_20261018_172826.html 

## Failures

None.

## Integrity

```
controller-actions.json run-metadata.json 
b360ae7ceaed022c37f9c00549fc98604eecc537ee288d437c2622860da67620  artifacts/wsl-validation-20261018-115201/orders-service-e2e/cli/01-pods.ansi
da7d9c0e3703a7920d1a2600d000163808f5ce05de80ae3cffbff5fc19dfbc42  artifacts/wsl-validation-20261018-115201/orders-service-e2e/cli/02-nodes.ansi
6725720cddda31367f77a11fc397fda69d6ef80061954345d270e7fcf2998b82  artifacts/wsl-validation-20261018-115201/orders-service-e2e/cli/03-workloads.ansi
c4676ecfb6cd2a87ac6be8d3dfa2c0e146171e1ca27c7afdc1ca193657a41c73  artifacts/wsl-validation-20261018-115201/orders-service-e2e/cli/04-ip.ansi
48ea74cf0460af7e4e19e9b0755918d36ac0a6fef6e12b4ff0106c7f58780355  artifacts/wsl-validation-20261018-115201/orders-service-e2e/cli/05-mem.ansi
9c217799b20c502cb220aa1161dc5080f32b1ec65e010f0b65943d5106a94efe  artifacts/wsl-validation-20261018-115201/orders-service-e2e/cli/06-io.ansi
456d69c1f0b08415166d7d7f29b3eb42d02479edad7153d8d78fe0c8d415ece6  artifacts/wsl-validation-20261018-115201/orders-service-e2e/cli/07-alerts.ansi
334bd2052decb7a2645f2ec9ddc02eed361af53f80ae248fc5cc6b8ef93b94c5  artifacts/wsl-validation-20261018-115201/ml-service-prod/cli/01-pods.ansi
6746ba149ba50ad1245a1c722fbf86669f811cdcfef667bc4186e941c7a59cdb  artifacts/wsl-validation-20261018-115201/ml-service-prod/cli/02-nodes.ansi
ced19b8a1852de1758c1ae2b83ab57e2a3520fd875ac454ffc20172900b2fd3e  artifacts/wsl-validation-20261018-115201/ml-service-prod/cli/03-workloads.ansi
3ee415e7dc92147e917370ec60cef3e15cae3e4cb0d315446a775b8eba957717  artifacts/wsl-validation-20261018-115201/ml-service-prod/cli/04-ip.ansi
8afaa4171dc0351e3c355c94cf0971e378e27d8b4f041f7b66084ca825f6e2b6  artifacts/wsl-validation-20261018-115201/ml-service-prod/cli/05-mem.ansi
a5df59d7d1440b818724f1c80e561bbe52189c301ab4d83b4b80e375aa4a43cf  artifacts/wsl-validation-20261018-115201/ml-service-prod/cli/06-io.ansi
752998548ae05a1ad0bb4d3a3c2931550c7fa15f8bdec22bab407a12447d0a3d  artifacts/wsl-validation-20261018-115201/ml-service-prod/cli/07-alerts.ansi
bb1ad6efa52c2462e42aac2b10f7b8fb6cd4aeceaf3ac0db5e9a4027a7f6a6fa  artifacts/wsl-validation-20261018-115201/gitops-core/cli/01-pods.ansi
b813f1527f416a6b05c35656d4e4503bd3355d4ec7e4e85f1056504abbd74ab3  artifacts/wsl-validation-20261018-115201/gitops-core/cli/02-nodes.ansi
e80f01ba45eedeb7237b396bda40acba575d16eddcc2a9e55d162d3ffa7d4c06  artifacts/wsl-validation-20261018-115201/gitops-core/cli/03-workloads.ansi
c49990a4efe5852657dd978da955f897fa48230658a8a58360f21449d2d021be  artifacts/wsl-validation-20261018-115201/gitops-core/cli/04-ip.ansi
8474d3515204cdf261fbfa9ab20877049a27bf5abe1bed5c8d53edded2213c04  artifacts/wsl-validation-20261018-115201/gitops-core/cli/05-mem.ansi
29c3e982eac881fdbf5119a4b03de8daebbe74db2cc7c41397510f9ff6643d90  artifacts/wsl-validation-20261018-115201/gitops-core/cli/06-io.ansi
4093dbbb2c70203f437ce7e28af60cff3bc2275cc651c4a88fb8ddb7b32c22f3  artifacts/wsl-validation-20261018-115201/gitops-core/cli/07-alerts.ansi
```
