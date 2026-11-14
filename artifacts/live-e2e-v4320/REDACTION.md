# Publication redaction

Captured text, reports, logs and the audit copy were redacted before publication.
The workstation home, user and repository paths were replaced with generic
placeholders. Terminal images under `samples/cli_4320/` are re-rendered from
these redacted captures. Native xterm grabs remain in the private validation
workspace because pixels cannot be redacted safely.

The audit chain verified intact before redaction (see
`audit-verify-before-redaction.txt`); redaction changes bytes, so the published
copy's hash chain is not expected to verify.
