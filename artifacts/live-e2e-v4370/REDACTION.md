# Publication redaction

The validation host ran kdash under a personal operator identity. Published text
evidence replaces that identity with `operator@validation-host`. Cluster context,
namespace, workload names, timestamps, addresses and measured values are unchanged.

The hash-chained audit log (`audit/audit_202611.log`) did not contain the personal
identity and is published unchanged. `audit-verify-before-redaction.txt` records
the chain result from the run. Generated `--audit` views and report pages were
redacted; they are not the chain file.