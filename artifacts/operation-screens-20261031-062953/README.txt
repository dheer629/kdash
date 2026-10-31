run            operation-screens-20261031-062953
context        vcluster-docker_dev
namespace      default
version        kdash 4.19.2
sha256         3a95e6edb029bf88bdafa81af754fb9ab57d1c3d23a4c0f67a32a0e88bcd2844
terminal       170x50
screens        24 (32-46 dashboard operations, 47-53 one-shot modes,
               54 the disclaimer gate, 55 the audit report)
gallery        samples/cli_419

What the screens prove
  32,33   n opens the namespace picker (Enter picks the highlighted one);
          / filters the view to the matching pods; the same key with .*
          matches every pod again
  34      F opens the structured pod filter prompt (label, status, node,
          workload, unhealthy; Enter keeps, "clear" resets)
  35,36   d toggles the detail lines; p reduces the view to pod totals
  37      s cycles the sort key, o reverses the order (header shows both)
  38      P pauses the refresh and + changes the poll interval
  39      T changes the colour theme
  40,41   2 NODE POOLS: a shows every node, Z switches to true-scale bars
  42      5 MEMORY: z moves the chart window
  43,44   e opens the HTML menu; Enter writes the all-tabs report and names it
  45      w in the inspector exported the visible log pane
  46      q printed the session close summary (context, namespace, duration
          and the retained session history)
  47,48   the CLI version and the first page of -h
  49      --snapshot all wrote the every-view HTML and said where
  50      --report wrote the text + TSV + CSV evidence bundle
  51,52   --audit lists the recorded events; --audit-verify checks the chain
  53      --about prints the author, the disclaimer and the audit locations
  54      a first run asks for the disclaimer before reading the cluster
  55      --audit-report wrote the audit log as HTML and CSV

Artifacts this run produced (besides raw/ and captures.tsv)
default/audit/kdash_audit_20261031_120536.csv
default/audit/kdash_audit_20261031_120536.html
default/reports/index.html
default/reports/kdash_devops-admin@local-cluster_default_20261031_120431.html
default/reports/kdash_devops-admin@local-cluster_default_20261031_120431/csv/cluster_ns.csv
default/reports/kdash_devops-admin@local-cluster_default_20261031_120431/csv/containers.csv
default/reports/kdash_devops-admin@local-cluster_default_20261031_120431/csv/io_nodes.csv
default/reports/kdash_devops-admin@local-cluster_default_20261031_120431/csv/io_pods.csv
default/reports/kdash_devops-admin@local-cluster_default_20261031_120431/csv/ip.csv
default/reports/kdash_devops-admin@local-cluster_default_20261031_120431/csv/ipblocks.csv
default/reports/kdash_devops-admin@local-cluster_default_20261031_120431/csv/memory.csv
default/reports/kdash_devops-admin@local-cluster_default_20261031_120431/csv/meta.csv
default/reports/kdash_devops-admin@local-cluster_default_20261031_120431/csv/nodes.csv
default/reports/kdash_devops-admin@local-cluster_default_20261031_120431/csv/pods.csv
default/reports/kdash_devops-admin@local-cluster_default_20261031_120431/csv/pools.csv
default/reports/kdash_devops-admin@local-cluster_default_20261031_120431/csv/services.csv
default/reports/kdash_devops-admin@local-cluster_default_20261031_120431/csv/subnets.csv
default/reports/kdash_devops-admin@local-cluster_default_20261031_120431/csv/wl_node.csv
default/reports/kdash_devops-admin@local-cluster_default_20261031_120431/csv/workloads.csv
default/reports/kdash_devops-admin@local-cluster_default_20261031_120431/diagnostics/events.tsv
default/reports/kdash_devops-admin@local-cluster_default_20261031_120431/diagnostics/health-volume-usage.tsv
default/reports/kdash_devops-admin@local-cluster_default_20261031_120431/report.html
default/reports/kdash_devops-admin@local-cluster_default_20261031_120431/tsv/cluster_ns.tsv
default/reports/kdash_devops-admin@local-cluster_default_20261031_120431/tsv/containers.tsv
default/reports/kdash_devops-admin@local-cluster_default_20261031_120431/tsv/io_nodes.tsv
default/reports/kdash_devops-admin@local-cluster_default_20261031_120431/tsv/io_pods.tsv
default/reports/kdash_devops-admin@local-cluster_default_20261031_120431/tsv/ip.tsv
default/reports/kdash_devops-admin@local-cluster_default_20261031_120431/tsv/ipblocks.tsv
default/reports/kdash_devops-admin@local-cluster_default_20261031_120431/tsv/memory.tsv
default/reports/kdash_devops-admin@local-cluster_default_20261031_120431/tsv/meta.tsv
default/reports/kdash_devops-admin@local-cluster_default_20261031_120431/tsv/nodes.tsv
default/reports/kdash_devops-admin@local-cluster_default_20261031_120431/tsv/pods.tsv
default/reports/kdash_devops-admin@local-cluster_default_20261031_120431/tsv/pools.tsv
default/reports/kdash_devops-admin@local-cluster_default_20261031_120431/tsv/services.tsv
default/reports/kdash_devops-admin@local-cluster_default_20261031_120431/tsv/subnets.tsv
default/reports/kdash_devops-admin@local-cluster_default_20261031_120431/tsv/wl_node.tsv
default/reports/kdash_devops-admin@local-cluster_default_20261031_120431/tsv/workloads.tsv
default/reports/kdash_memory_dashboard_devops-admin@local-cluster_default_20261031_120404.html
default/reports/kdash_namespace_ip_pool_devops-admin@local-cluster_default_20261031_120404.html
default/reports/kdash_namespace_report_devops-admin@local-cluster_default_20261031_120239.html
default/reports/kdash_network_disk_io_devops-admin@local-cluster_default_20261031_120404.html
default/reports/kdash_node_pools_worker_nodes_devops-admin@local-cluster_default_20261031_120404.html
default/reports/kdash_pod_container_resources_devops-admin@local-cluster_default_20261031_120404.html
default/reports/kdash_workloads_per_worker_node_devops-admin@local-cluster_default_20261031_120404.html
default/reports/sessions/kdash_devops-admin@local-cluster_default_20261031_115956/events.tsv
default/reports/sessions/kdash_devops-admin@local-cluster_default_20261031_115956/model/cluster_ns.tsv
default/reports/sessions/kdash_devops-admin@local-cluster_default_20261031_115956/model/containers.tsv
default/reports/sessions/kdash_devops-admin@local-cluster_default_20261031_115956/model/io_nodes.tsv
default/reports/sessions/kdash_devops-admin@local-cluster_default_20261031_115956/model/io_pods.tsv
default/reports/sessions/kdash_devops-admin@local-cluster_default_20261031_115956/model/ip.tsv
default/reports/sessions/kdash_devops-admin@local-cluster_default_20261031_115956/model/ipblocks.tsv
default/reports/sessions/kdash_devops-admin@local-cluster_default_20261031_115956/model/memory.tsv
default/reports/sessions/kdash_devops-admin@local-cluster_default_20261031_115956/model/meta.tsv
default/reports/sessions/kdash_devops-admin@local-cluster_default_20261031_115956/model/nodes.tsv
default/reports/sessions/kdash_devops-admin@local-cluster_default_20261031_115956/model/pods.tsv
default/reports/sessions/kdash_devops-admin@local-cluster_default_20261031_115956/model/pools.tsv
default/reports/sessions/kdash_devops-admin@local-cluster_default_20261031_115956/model/services.tsv
default/reports/sessions/kdash_devops-admin@local-cluster_default_20261031_115956/model/subnets.tsv
default/reports/sessions/kdash_devops-admin@local-cluster_default_20261031_115956/model/wl_node.tsv
default/reports/sessions/kdash_devops-admin@local-cluster_default_20261031_115956/model/workloads.tsv
default/reports/sessions/kdash_devops-admin@local-cluster_default_20261031_115956/nodes.tsv
default/reports/sessions/kdash_devops-admin@local-cluster_default_20261031_115956/ns.tsv
default/reports/sessions/kdash_devops-admin@local-cluster_default_20261031_115956/pods.tsv
default/reports/sessions/kdash_devops-admin@local-cluster_default_20261031_115956/state.tsv
default/reports/sessions/kdash_devops-admin@local-cluster_default_20261031_125247/events.tsv
default/reports/sessions/kdash_devops-admin@local-cluster_default_20261031_125247/model/cluster_ns.tsv
default/reports/sessions/kdash_devops-admin@local-cluster_default_20261031_125247/model/containers.tsv
default/reports/sessions/kdash_devops-admin@local-cluster_default_20261031_125247/model/io_nodes.tsv
default/reports/sessions/kdash_devops-admin@local-cluster_default_20261031_125247/model/io_pods.tsv
default/reports/sessions/kdash_devops-admin@local-cluster_default_20261031_125247/model/ip.tsv
default/reports/sessions/kdash_devops-admin@local-cluster_default_20261031_125247/model/ipblocks.tsv
default/reports/sessions/kdash_devops-admin@local-cluster_default_20261031_125247/model/memory.tsv
default/reports/sessions/kdash_devops-admin@local-cluster_default_20261031_125247/model/meta.tsv
default/reports/sessions/kdash_devops-admin@local-cluster_default_20261031_125247/model/nodes.tsv
default/reports/sessions/kdash_devops-admin@local-cluster_default_20261031_125247/model/pods.tsv
default/reports/sessions/kdash_devops-admin@local-cluster_default_20261031_125247/model/pools.tsv
default/reports/sessions/kdash_devops-admin@local-cluster_default_20261031_125247/model/services.tsv
default/reports/sessions/kdash_devops-admin@local-cluster_default_20261031_125247/model/subnets.tsv
default/reports/sessions/kdash_devops-admin@local-cluster_default_20261031_125247/model/wl_node.tsv
default/reports/sessions/kdash_devops-admin@local-cluster_default_20261031_125247/model/workloads.tsv
default/reports/sessions/kdash_devops-admin@local-cluster_default_20261031_125247/nodes.tsv
default/reports/sessions/kdash_devops-admin@local-cluster_default_20261031_125247/ns.tsv
default/reports/sessions/kdash_devops-admin@local-cluster_default_20261031_125247/pods.tsv
default/reports/sessions/kdash_devops-admin@local-cluster_default_20261031_125247/state.tsv

Every screen was captured with tmux capture-pane -e -p while kdash was live
and rendered with ../../scripts/render-captures.ps1. The run was redacted with
../../scripts/redact-run.sh and a private mapping before publication.
