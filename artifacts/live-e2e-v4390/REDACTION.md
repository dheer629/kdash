# Publication redaction for the kdash 4.39.0 live evidence

The run was executed by the maintainer on the local WSL workstation. Published
text replaces the host operator identity and home path; cluster data, checks and
captures are unchanged.

| Original | Published |
|---|---|
| `<account>@<host>` | `operator@validation-host` |
| `/home/<account>` | `/var/tmp/kdash-validation-home` |
| `Users\<account>` | `Users/operator` |

What was rewritten: generated HTML reports, the audit export, the audit
command logs and the plain-text logs under `logs/`. The JSON result files,
capture manifests, checksum manifests and the raw ANSI captures were not
rewritten, so every recorded hash still describes the published file.

The hash-chained audit log in `audit/` was not modified, so its chain still
verifies; `audit-verify.txt` records the result. Report bundles carry their own
`SHA256SUMS` manifests, which were regenerated from the redacted bytes so
`sha256sum -c` works in place.

The isolated kdash configuration directory (disclaimer acceptance, default
namespace, recent namespaces) is not published: it records the local account.
Screenshots were re-rendered after redaction where their text changed, and the
browser checks were re-run against the redacted reports so the recorded report
hash and the browser screenshots match the published bytes.
