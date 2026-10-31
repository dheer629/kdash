# kdash 4.19.2 HTML reports

The HTML that the 4.19.2 operation run produced, copied **byte for byte** from
[`../../artifacts/operation-screens-20261031-062953/default/`](../../artifacts/operation-screens-20261031-062953).
Nothing inside a report was edited or retyped; the run had already been redacted
before the files were copied.

| File | What it is |
|---|---|
| `default/kdash_namespace_report_*.html` | the live all-tabs namespace report with the recorded history (the `e` menu, Enter) |
| `default/kdash_*_*.html` | the `--snapshot all` one-shot: every view in one HTML, plus the combined report |
| `default/index.html` | the bundle index |
| `default/kdash_audit_*.html`, `.csv` | the audit log as HTML and CSV (`--audit-report`) |
| `default/screenshots/*.png` | browser screenshots (Microsoft Edge, headless) of the report and the index |

The text and table side of the same run - 11 text views, 17 TSV and 15 CSV files -
is in `artifacts/operation-screens-20261031-062953/default/reports/kdash_*/`, where
the bundle's own `SHA256SUMS` covers it.

Placeholders are the same as everywhere in `samples/`: the context appears as
`devops-admin@local-cluster`, the operator and host as `demo` / `node`, the personal
paths as `/home/demo`, and the other tenants as `ml-service-prod`, `ml-service-dev`,
`gitops-core` and `podinfo-demo` (see [`../README.md`](../README.md) and
[`../cli_419/README.md`](../cli_419/README.md)). Because redaction rewrites bytes, the
audit hash chain inside these files no longer verifies; it was checked **before**
publication - screen `52-audit-verify.png` in [`../cli_419/`](../cli_419) records
`(411 events, chain intact)`.

Verify the files are unchanged: `sha256sum -c SHA256SUMS` in this directory.
The 4.12.0 reports stay in [`../html/`](../html), labelled with their version.
