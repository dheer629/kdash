# kdash 4.32.0 live WSL terminal captures

Run `live-e2e-v4320` records **199 passed live checks**, **23 passed browser checks** and **96 CLI terminal screenshots**, with companion ANSI replays, from the installed kdash 4.32.0 in namespace `kdash-e2e`.
The original [results](../../artifacts/live-e2e-v4320/results.json), [checks](../../artifacts/live-e2e-v4320/checks.tsv),
[cluster inventory](../../artifacts/live-e2e-v4320/inventory.json) and [capture manifest](../../artifacts/live-e2e-v4320/captures.tsv)
retain the evidence behind each image. Context: `vcluster-docker_dev`.
The [browser results](../../artifacts/live-e2e-v4320/browser-results.json) cover the generated report controls.

The published PNGs are faithful ANSI replays of live terminal captures. Native
xterm screenshots remain in the private validation workspace.
The operator identity, host and context are redacted for publication. Test workload
names and measured values are preserved.
The published audit-log bytes are redacted, so their original hash chain cannot
be verified from this public copy.

The companion replay PNGs render actual `tmux capture-pane -e -p` screens with
[`capture-terminal.py`](../../scripts/capture-terminal.py), using the dimensions in
the manifest. The dashboard supplied every value and character. These are faithful
terminal renders, separate from any private native screenshots. Text/ANSI sources
remain linked below so the visible result can be inspected and reproduced.

The dedicated local `kdash-e2e` namespace contains real workload and diagnostic
cases. The run exercises views, filters, pickers, inspector and logs, interactive
shell/file actions, formatting modes and exports; the check list records what was
asserted. A capture proves the visible screen at that moment, while action and byte
checks establish outcomes. Unknown or unavailable measurements remain visible.

| Screenshot | Live screen | Geometry | ANSI source |
|---|---|---|---|
| [ANSI replay](01-pods.png) | kdash 4.32.0 / PODS live requests, limits and measured usage | 170 x 50 | [capture](../../artifacts/live-e2e-v4320/raw/01-pods.ansi) |
| [ANSI replay](02-nodes.png) | kdash 4.32.0 / NODE POOLS real allocatable capacity and namespace share | 170 x 50 | [capture](../../artifacts/live-e2e-v4320/raw/02-nodes.ansi) |
| [ANSI replay](03-workloads.png) | kdash 4.32.0 / WORKLOADS live replicas and placement | 170 x 50 | [capture](../../artifacts/live-e2e-v4320/raw/03-workloads.ansi) |
| [ANSI replay](04-ip.png) | kdash 4.32.0 / IP POOL real pod, node and service addresses | 170 x 50 | [capture](../../artifacts/live-e2e-v4320/raw/04-ip.ansi) |
| [ANSI replay](05-mem.png) | kdash 4.32.0 / MEMORY live history and pod usage | 170 x 50 | [capture](../../artifacts/live-e2e-v4320/raw/05-mem.ansi) |
| [ANSI replay](06-io.png) | kdash 4.32.0 / NETWORK AND DISK IO capability and live samples | 170 x 50 | [capture](../../artifacts/live-e2e-v4320/raw/06-io.ansi) |
| [ANSI replay](07-alerts.png) | kdash 4.32.0 / ALERTS real unhealthy fixture workloads | 170 x 50 | [capture](../../artifacts/live-e2e-v4320/raw/07-alerts.ansi) |
| [ANSI replay](08-services.png) | kdash 4.32.0 / SERVICES ingress, ready endpoints and missing backend | 170 x 50 | [capture](../../artifacts/live-e2e-v4320/raw/08-services.ansi) |
| [ANSI replay](09-storage.png) | kdash 4.32.0 / STORAGE bound volume and pending claim | 170 x 50 | [capture](../../artifacts/live-e2e-v4320/raw/09-storage.ansi) |
| [ANSI replay](10-events.png) | kdash 4.32.0 / EVENTS real Kubernetes scheduler and kubelet events | 170 x 50 | [capture](../../artifacts/live-e2e-v4320/raw/10-events.ansi) |
| [ANSI replay](11-explain.png) | kdash 4.32.0 / INCIDENT EVIDENCE from actual failing workloads | 170 x 50 | [capture](../../artifacts/live-e2e-v4320/raw/11-explain.ansi) |
| [ANSI replay](12-namespace-picker.png) | kdash 4.32.0 / Framed namespace picker with access and persistent default controls | 170 x 50 | [capture](../../artifacts/live-e2e-v4320/raw/12-namespace-picker.ansi) |
| [ANSI replay](13-namespace-filter.png) | kdash 4.32.0 / Live namespace search and context-sensitive action panel | 170 x 50 | [capture](../../artifacts/live-e2e-v4320/raw/13-namespace-filter.ansi) |
| [ANSI replay](67-namespace-saved-default.png) | kdash 4.32.0 / A subsequent launch opens the namespace saved with d | 170 x 50 | [capture](../../artifacts/live-e2e-v4320/raw/67-namespace-saved-default.ansi) |
| [ANSI replay](68-namespace-typed.png) | kdash 4.32.0 / t opens an explicitly typed namespace | 170 x 50 | [capture](../../artifacts/live-e2e-v4320/raw/68-namespace-typed.ansi) |
| [ANSI replay](14-pod-picker.png) | kdash 4.32.0 / Framed live pod picker with CPU, memory, restarts and attention state | 170 x 50 | [capture](../../artifacts/live-e2e-v4320/raw/14-pod-picker.ansi) |
| [ANSI replay](15-pod-picker-help.png) | kdash 4.32.0 / Pod picker navigation, filters and action keys | 170 x 50 | [capture](../../artifacts/live-e2e-v4320/raw/15-pod-picker-help.ansi) |
| [ANSI replay](16-container-picker.png) | kdash 4.32.0 / Framed multi-container picker with resource/state columns | 170 x 50 | [capture](../../artifacts/live-e2e-v4320/raw/16-container-picker.ansi) |
| [ANSI replay](17-inspector-summary.png) | kdash 4.32.0 / Inspector summary of a real running pod | 170 x 50 | [capture](../../artifacts/live-e2e-v4320/raw/17-inspector-summary.ansi) |
| [ANSI replay](75-detail-shell-blocked.png) | kdash 4.32.0 / Read-only inspector refuses shell actions and explains X | 170 x 50 | [capture](../../artifacts/live-e2e-v4320/raw/75-detail-shell-blocked.ansi) |
| [ANSI replay](76-detail-confirmation.png) | kdash 4.32.0 / X opens confirmation directly from pod detail | 170 x 50 | [capture](../../artifacts/live-e2e-v4320/raw/76-detail-confirmation.ansi) |
| [ANSI replay](77-detail-cancel.png) | kdash 4.32.0 / Declining keeps pod detail read-only | 170 x 50 | [capture](../../artifacts/live-e2e-v4320/raw/77-detail-cancel.ansi) |
| [ANSI replay](78-detail-interactive-on.png) | kdash 4.32.0 / Whole yes answer enables the inspector without leaking keys | 170 x 50 | [capture](../../artifacts/live-e2e-v4320/raw/78-detail-interactive-on.ansi) |
| [ANSI replay](79-detail-shell.png) | kdash 4.32.0 / Actual container shell opened after enabling X in detail | 170 x 50 | [capture](../../artifacts/live-e2e-v4320/raw/79-detail-shell.ansi) |
| [ANSI replay](80-detail-interactive-off.png) | kdash 4.32.0 / X disables interactive actions immediately in the inspector | 170 x 50 | [capture](../../artifacts/live-e2e-v4320/raw/80-detail-interactive-off.ansi) |
| [ANSI replay](81-detail-shell-blocked-again.png) | kdash 4.32.0 / Shell is refused again after disabling X | 170 x 50 | [capture](../../artifacts/live-e2e-v4320/raw/81-detail-shell-blocked-again.ansi) |
| [ANSI replay](18-inspector-logs.png) | kdash 4.32.0 / Bounded timestamped logs from the live app container | 170 x 50 | [capture](../../artifacts/live-e2e-v4320/raw/18-inspector-logs.ansi) |
| [ANSI replay](62-inspector-expand.png) | kdash 4.32.0 / Expanded bounded log read from the live container | 170 x 50 | [capture](../../artifacts/live-e2e-v4320/raw/62-inspector-expand.ansi) |
| [ANSI replay](63-inspector-all.png) | kdash 4.32.0 / All available live container logs within the byte cap | 170 x 50 | [capture](../../artifacts/live-e2e-v4320/raw/63-inspector-all.ansi) |
| [ANSI replay](64-inspector-nowrap.png) | kdash 4.32.0 / Unwrapped logs with horizontal navigation | 170 x 50 | [capture](../../artifacts/live-e2e-v4320/raw/64-inspector-nowrap.ansi) |
| [ANSI replay](65-inspector-json.png) | kdash 4.32.0 / Readable JSON log formatting enabled | 170 x 50 | [capture](../../artifacts/live-e2e-v4320/raw/65-inspector-json.ansi) |
| [ANSI replay](66-inspector-follow.png) | kdash 4.32.0 / Live follow periodically refreshes actual container logs | 170 x 50 | [capture](../../artifacts/live-e2e-v4320/raw/66-inspector-follow.ansi) |
| [ANSI replay](19-inspector-find.png) | kdash 4.32.0 / Log search highlighting with context retained | 170 x 50 | [capture](../../artifacts/live-e2e-v4320/raw/19-inspector-find.ansi) |
| [ANSI replay](20-inspector-only-matches.png) | kdash 4.32.0 / Only matching warning lines from real logs | 170 x 50 | [capture](../../artifacts/live-e2e-v4320/raw/20-inspector-only-matches.ansi) |
| [ANSI replay](21-inspector-help.png) | kdash 4.32.0 / Inspector help for log filtering and export | 170 x 50 | [capture](../../artifacts/live-e2e-v4320/raw/21-inspector-help.ansi) |
| [ANSI replay](22-inspector-export.png) | kdash 4.32.0 / Visible log pane exported locally | 170 x 50 | [capture](../../artifacts/live-e2e-v4320/raw/22-inspector-export.ansi) |
| [ANSI replay](32-command-palette.png) | kdash 4.32.0 / Fixed-command palette | 170 x 50 | [capture](../../artifacts/live-e2e-v4320/raw/32-command-palette.ansi) |
| [ANSI replay](33-doctor.png) | kdash 4.32.0 / Live connection, TLS, RBAC and metrics checks | 170 x 50 | [capture](../../artifacts/live-e2e-v4320/raw/33-doctor.ansi) |
| [ANSI replay](34-pod-filter.png) | kdash 4.32.0 / Dashboard pod regular expression applied | 170 x 50 | [capture](../../artifacts/live-e2e-v4320/raw/34-pod-filter.ansi) |
| [ANSI replay](35-structured-filters.png) | kdash 4.32.0 / Atomic label, status, node, workload and unhealthy filters | 170 x 50 | [capture](../../artifacts/live-e2e-v4320/raw/35-structured-filters.ansi) |
| [ANSI replay](36-detail-lines.png) | kdash 4.32.0 / Toggle container detail lines | 170 x 50 | [capture](../../artifacts/live-e2e-v4320/raw/36-detail-lines.ansi) |
| [ANSI replay](37-pods-only.png) | kdash 4.32.0 / Pod totals without container rows | 170 x 50 | [capture](../../artifacts/live-e2e-v4320/raw/37-pods-only.ansi) |
| [ANSI replay](38-sort-order.png) | kdash 4.32.0 / Sort key and reverse direction | 170 x 50 | [capture](../../artifacts/live-e2e-v4320/raw/38-sort-order.ansi) |
| [ANSI replay](39-paused-interval.png) | kdash 4.32.0 / Paused collection and changed polling interval | 170 x 50 | [capture](../../artifacts/live-e2e-v4320/raw/39-paused-interval.ansi) |
| [ANSI replay](40-theme-dark.png) | kdash 4.32.0 / Dark colour theme | 170 x 50 | [capture](../../artifacts/live-e2e-v4320/raw/40-theme-dark.ansi) |
| [ANSI replay](41-theme-light.png) | kdash 4.32.0 / Light colour theme | 170 x 50 | [capture](../../artifacts/live-e2e-v4320/raw/41-theme-light.ansi) |
| [ANSI replay](42-theme-mono.png) | kdash 4.32.0 / Monochrome colour theme | 170 x 50 | [capture](../../artifacts/live-e2e-v4320/raw/42-theme-mono.ansi) |
| [ANSI replay](43-node-scale.png) | kdash 4.32.0 / Node scope and true-scale resource bars | 170 x 50 | [capture](../../artifacts/live-e2e-v4320/raw/43-node-scale.ansi) |
| [ANSI replay](44-history-window.png) | kdash 4.32.0 / Memory history with changed chart window | 170 x 50 | [capture](../../artifacts/live-e2e-v4320/raw/44-history-window.ansi) |
| [ANSI replay](45-html-menu.png) | kdash 4.32.0 / Local HTML report selection menu | 170 x 50 | [capture](../../artifacts/live-e2e-v4320/raw/45-html-menu.ansi) |
| [ANSI replay](46-html-report-written.png) | kdash 4.32.0 / All-tabs report generated from live session | 170 x 50 | [capture](../../artifacts/live-e2e-v4320/raw/46-html-report-written.ansi) |
| [ANSI replay](47-dashboard-help.png) | kdash 4.32.0 / Dashboard navigation and interactive controls | 170 x 50 | [capture](../../artifacts/live-e2e-v4320/raw/47-dashboard-help.ansi) |
| [ANSI replay](48-session-summary.png) | kdash 4.32.0 / Completed live session and retained history | 170 x 50 | [capture](../../artifacts/live-e2e-v4320/raw/48-session-summary.ansi) |
| [ANSI replay](23-interactive-blocked.png) | kdash 4.32.0 / Shell refused while interactive mode is disabled | 170 x 50 | [capture](../../artifacts/live-e2e-v4320/raw/23-interactive-blocked.ansi) |
| [ANSI replay](24-interactive-confirmation.png) | kdash 4.32.0 / Explicit interactive-mode confirmation | 170 x 50 | [capture](../../artifacts/live-e2e-v4320/raw/24-interactive-confirmation.ansi) |
| [ANSI replay](25-shell-picker.png) | kdash 4.32.0 / Shell-mode pod picker and action panel | 170 x 50 | [capture](../../artifacts/live-e2e-v4320/raw/25-shell-picker.ansi) |
| [ANSI replay](26-shell-inside.png) | kdash 4.32.0 / Actual shell inside the live app container | 170 x 50 | [capture](../../artifacts/live-e2e-v4320/raw/26-shell-inside.ansi) |
| [ANSI replay](27-upload-browser.png) | kdash 4.32.0 / Local framed file browser with enabled upload actions | 170 x 50 | [capture](../../artifacts/live-e2e-v4320/raw/27-upload-browser.ansi) |
| [ANSI replay](28-upload-destination.png) | kdash 4.32.0 / Remote destination browser before any transfer | 170 x 50 | [capture](../../artifacts/live-e2e-v4320/raw/28-upload-destination.ansi) |
| [ANSI replay](29-upload-review.png) | kdash 4.32.0 / Upload preflight checks and explicit review | 170 x 50 | [capture](../../artifacts/live-e2e-v4320/raw/29-upload-review.ansi) |
| [ANSI replay](30-upload-result.png) | kdash 4.32.0 / Real upload result with source and destination hashes | 170 x 50 | [capture](../../artifacts/live-e2e-v4320/raw/30-upload-result.ansi) |
| [ANSI replay](70-directory-upload-review.png) | kdash 4.32.0 / Directory upload preflight and recursive checksum checks | 170 x 50 | [capture](../../artifacts/live-e2e-v4320/raw/70-directory-upload-review.ansi) |
| [ANSI replay](71-directory-upload-result.png) | kdash 4.32.0 / Actual directory upload with recursive fingerprints | 170 x 50 | [capture](../../artifacts/live-e2e-v4320/raw/71-directory-upload-result.ansi) |
| [ANSI replay](31-download-browser.png) | kdash 4.32.0 / Remote framed file browser with selection and preview keys | 170 x 50 | [capture](../../artifacts/live-e2e-v4320/raw/31-download-browser.ansi) |
| [ANSI replay](49-download-review.png) | kdash 4.32.0 / Download preflight, selected format and name conflict checks | 170 x 50 | [capture](../../artifacts/live-e2e-v4320/raw/49-download-review.ansi) |
| [ANSI replay](50-download-result.png) | kdash 4.32.0 / Real download result and per-item hash verification | 170 x 50 | [capture](../../artifacts/live-e2e-v4320/raw/50-download-result.ansi) |
| [ANSI replay](55-download-keep-review.png) | kdash 4.32.0 / Download preflight, selected format and name conflict checks | 170 x 50 | [capture](../../artifacts/live-e2e-v4320/raw/55-download-keep-review.ansi) |
| [ANSI replay](56-download-keep-result.png) | kdash 4.32.0 / Real download result and per-item hash verification | 170 x 50 | [capture](../../artifacts/live-e2e-v4320/raw/56-download-keep-result.ansi) |
| [ANSI replay](57-directory-download-review.png) | kdash 4.32.0 / Download preflight, selected format and name conflict checks | 170 x 50 | [capture](../../artifacts/live-e2e-v4320/raw/57-directory-download-review.ansi) |
| [ANSI replay](58-directory-download-result.png) | kdash 4.32.0 / Real download result and per-item hash verification | 170 x 50 | [capture](../../artifacts/live-e2e-v4320/raw/58-directory-download-result.ansi) |
| [ANSI replay](59-download-zip-review.png) | kdash 4.32.0 / Download preflight, selected format and name conflict checks | 170 x 50 | [capture](../../artifacts/live-e2e-v4320/raw/59-download-zip-review.ansi) |
| [ANSI replay](60-download-zip-result.png) | kdash 4.32.0 / Real download result and per-item hash verification | 170 x 50 | [capture](../../artifacts/live-e2e-v4320/raw/60-download-zip-result.ansi) |
| [ANSI replay](61-download-tgz-review.png) | kdash 4.32.0 / Download preflight, selected format and name conflict checks | 170 x 50 | [capture](../../artifacts/live-e2e-v4320/raw/61-download-tgz-review.ansi) |
| [ANSI replay](69-download-tgz-result.png) | kdash 4.32.0 / Real download result and per-item hash verification | 170 x 50 | [capture](../../artifacts/live-e2e-v4320/raw/69-download-tgz-result.ansi) |
| [ANSI replay](51-pods-100col.png) | kdash 4.32.0 / PODS at 100 columns | 100 x 40 | [capture](../../artifacts/live-e2e-v4320/raw/51-pods-100col.ansi) |
| [ANSI replay](52-picker-100col.png) | kdash 4.32.0 / Framed pod picker at 100 columns | 100 x 40 | [capture](../../artifacts/live-e2e-v4320/raw/52-picker-100col.ansi) |
| [ANSI replay](53-namespace-100col.png) | kdash 4.32.0 / Namespace picker and action panel at 100 columns | 100 x 40 | [capture](../../artifacts/live-e2e-v4320/raw/53-namespace-100col.ansi) |
| [ANSI replay](51-pods-80col.png) | kdash 4.32.0 / PODS at 80 columns | 80 x 30 | [capture](../../artifacts/live-e2e-v4320/raw/51-pods-80col.ansi) |
| [ANSI replay](82-mode-confirmation-80col.png) | kdash 4.32.0 / Confirmation remains usable in an 80-column terminal | 80 x 30 | [capture](../../artifacts/live-e2e-v4320/raw/82-mode-confirmation-80col.ansi) |
| [ANSI replay](83-mode-enabled-80col.png) | kdash 4.32.0 / Uppercase Y plus Enter enables interactive mode at 80 columns | 80 x 30 | [capture](../../artifacts/live-e2e-v4320/raw/83-mode-enabled-80col.ansi) |
| [ANSI replay](52-picker-80col.png) | kdash 4.32.0 / Framed pod picker at 80 columns | 80 x 30 | [capture](../../artifacts/live-e2e-v4320/raw/52-picker-80col.ansi) |
| [ANSI replay](53-namespace-80col.png) | kdash 4.32.0 / Namespace picker and action panel at 80 columns | 80 x 30 | [capture](../../artifacts/live-e2e-v4320/raw/53-namespace-80col.ansi) |
| [ANSI replay](54-ascii-picker.png) | kdash 4.32.0 / ASCII framed picker with colour disabled | 170 x 50 | [capture](../../artifacts/live-e2e-v4320/raw/54-ascii-picker.ansi) |
| [ANSI replay](84-certs.png) | kdash 4.32.0 / CERTIFICATES AND LOGINS real TLS and kubeconfig expiry evidence | 170 x 50 | [capture](../../artifacts/live-e2e-v4320/raw/84-certs.ansi) |
| [ANSI replay](85-runbook.png) | kdash 4.32.0 / RUNBOOK printed etcd recovery procedure with live cluster inventory | 170 x 50 | [capture](../../artifacts/live-e2e-v4320/raw/85-runbook.ansi) |
| [ANSI replay](87-runbook-topic.png) | kdash 4.32.0 / RUNBOOK next topic displays certificate rotation instructions | 170 x 50 | [capture](../../artifacts/live-e2e-v4320/raw/87-runbook-topic.ansi) |
| [ANSI replay](86-check.png) | kdash 4.32.0 / CHECK NOW actual unhealthy workloads and numbered read-only next commands | 170 x 50 | [capture](../../artifacts/live-e2e-v4320/raw/86-check.ansi) |
| [ANSI replay](88-fmea.png) | kdash 4.32.0 / FMEA real failure modes, priority scores and read visibility | 170 x 50 | [capture](../../artifacts/live-e2e-v4320/raw/88-fmea.ansi) |
| [ANSI replay](89-access.png) | kdash 4.32.0 / ACCESS real kubectl auth identity and permission checks | 170 x 50 | [capture](../../artifacts/live-e2e-v4320/raw/89-access.ansi) |
| [ANSI replay](90-fmea-kind.png) | kdash 4.32.0 / FMEA kind filter on actual worksheet rows | 170 x 50 | [capture](../../artifacts/live-e2e-v4320/raw/90-fmea-kind.ansi) |
| [ANSI replay](91-fmea-sort.png) | kdash 4.32.0 / FMEA worksheet sorted by risk priority number | 170 x 50 | [capture](../../artifacts/live-e2e-v4320/raw/91-fmea-sort.ansi) |

## Secrets map

| Screenshot | Live screen | Geometry | ANSI source |
|---|---|---|---|
| [ANSI replay](secrets/92-secrets.png) | kdash 4.32.0 / Live Secrets map: certificate expiry and access | 170 x 50 | [capture](../../artifacts/live-e2e-v4320/secrets/raw/92-secrets.ansi) |
| [ANSI replay](secrets/93-secrets-pan.png) | kdash 4.32.0 / Secrets map scroll and horizontal pan | 170 x 50 | [capture](../../artifacts/live-e2e-v4320/secrets/raw/93-secrets-pan.ansi) |
| [ANSI replay](secrets/94-secrets-help.png) | kdash 4.32.0 / Secrets map help and read-only behavior | 170 x 50 | [capture](../../artifacts/live-e2e-v4320/secrets/raw/94-secrets-help.ansi) |
| [ANSI replay](secrets/95-secrets-run-prompt.png) | kdash 4.32.0 / Secrets finding read-command prompt | 170 x 50 | [capture](../../artifacts/live-e2e-v4320/secrets/raw/95-secrets-run-prompt.ansi) |
| [ANSI replay](secrets/96-secrets-export.png) | kdash 4.32.0 / Secrets map HTML export from the live dashboard | 170 x 50 | [capture](../../artifacts/live-e2e-v4320/secrets/raw/96-secrets-export.ansi) |

Verify the image bytes with `sha256sum -c SHA256SUMS` in this directory.
See the [generated HTML reports](../html4320/README.md), [sample index](../README.md)
and [operating guide](../../DEVOPS_USER_GUIDE.md) for workflows and coverage limits.
Earlier captures retain their original version: [4.13.1](../cli_413/README.md), [4.14.0](../cli_414/README.md), [4.19.2](../cli_419/README.md), [4.23.1](../cli_423/README.md), [4.24.1](../cli_4241/README.md), [4.27.3](../cli_4273/README.md), [4.27.4](../cli_4274/README.md).
