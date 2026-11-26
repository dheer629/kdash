# kdash 4.39.0 live WSL terminal captures

Run `live-e2e-v4390` records **324 passed live checks**, **33 passed browser checks** and **136 CLI terminal screenshots**, with companion ANSI replays, from the installed kdash 4.39.0 in namespace `kdash-e2e`.
The original [results](../../artifacts/live-e2e-v4390/results.json), [checks](../../artifacts/live-e2e-v4390/checks.tsv),
[cluster inventory](../../artifacts/live-e2e-v4390/inventory.json) and [capture manifest](../../artifacts/live-e2e-v4390/captures.tsv)
retain the evidence behind each image. Context: `kdash-local`.
The [browser results](../../artifacts/live-e2e-v4390/browser-results.json) cover the generated report controls.

The gallery includes actual live xterm screenshots in `native/` and companion
ANSI replays. Test workload names, cluster context and measured values are
preserved. Personal paths are removed from public text evidence where needed;
the original audit verification result records the check before publication.

The companion replay PNGs render actual `tmux capture-pane -e -p` screens with
[`capture-terminal.py`](../../scripts/capture-terminal.py), using the dimensions in
the manifest. The dashboard supplied every value and character. These are faithful
terminal renders, separate from the native screenshots. Text/ANSI sources
remain linked below so the visible result can be inspected and reproduced.

The dedicated local `kdash-e2e` namespace contains real workload and diagnostic
cases. The run exercises views, filters, pickers, inspector and logs, interactive
shell/file actions, formatting modes and exports; the check list records what was
asserted. A capture proves the visible screen at that moment, while action and byte
checks establish outcomes. Unknown or unavailable measurements remain visible.

| Screenshot | Live screen | Geometry | ANSI source |
|---|---|---|---|
| [native](native/01-pods.png) / [ANSI replay](01-pods.png) | kdash 4.39.0 / PODS live requests, limits and measured usage | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/01-pods.ansi) |
| [native](native/02-nodes.png) / [ANSI replay](02-nodes.png) | kdash 4.39.0 / NODE POOLS real allocatable capacity and namespace share | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/02-nodes.ansi) |
| [native](native/03-workloads.png) / [ANSI replay](03-workloads.png) | kdash 4.39.0 / WORKLOADS live replicas and placement | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/03-workloads.ansi) |
| [native](native/04-ip.png) / [ANSI replay](04-ip.png) | kdash 4.39.0 / IP POOL real pod, node and service addresses | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/04-ip.ansi) |
| [native](native/05-mem.png) / [ANSI replay](05-mem.png) | kdash 4.39.0 / MEMORY live history and pod usage | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/05-mem.ansi) |
| [native](native/06-io.png) / [ANSI replay](06-io.png) | kdash 4.39.0 / NETWORK AND DISK IO capability and live samples | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/06-io.ansi) |
| [native](native/07-alerts.png) / [ANSI replay](07-alerts.png) | kdash 4.39.0 / ALERTS real unhealthy fixture workloads | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/07-alerts.ansi) |
| [native](native/08-services.png) / [ANSI replay](08-services.png) | kdash 4.39.0 / SERVICES ingress, ready endpoints and missing backend | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/08-services.ansi) |
| [native](native/09-storage.png) / [ANSI replay](09-storage.png) | kdash 4.39.0 / STORAGE bound volume and pending claim | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/09-storage.ansi) |
| [native](native/10-events.png) / [ANSI replay](10-events.png) | kdash 4.39.0 / EVENTS real Kubernetes scheduler and kubelet events | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/10-events.ansi) |
| [native](native/11-explain.png) / [ANSI replay](11-explain.png) | kdash 4.39.0 / INCIDENT EVIDENCE from actual failing workloads | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/11-explain.ansi) |
| [native](native/12-namespace-picker.png) / [ANSI replay](12-namespace-picker.png) | kdash 4.39.0 / Framed namespace picker with access and persistent default controls | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/12-namespace-picker.ansi) |
| [native](native/13-namespace-filter.png) / [ANSI replay](13-namespace-filter.png) | kdash 4.39.0 / Live namespace search and context-sensitive action panel | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/13-namespace-filter.ansi) |
| [native](native/67-namespace-saved-default.png) / [ANSI replay](67-namespace-saved-default.png) | kdash 4.39.0 / A subsequent launch opens the namespace saved with d | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/67-namespace-saved-default.ansi) |
| [native](native/68-namespace-typed.png) / [ANSI replay](68-namespace-typed.png) | kdash 4.39.0 / t opens an explicitly typed namespace | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/68-namespace-typed.ansi) |
| [native](native/14-pod-picker.png) / [ANSI replay](14-pod-picker.png) | kdash 4.39.0 / Framed live pod picker with CPU, memory, restarts and attention state | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/14-pod-picker.ansi) |
| [native](native/15-pod-picker-help.png) / [ANSI replay](15-pod-picker-help.png) | kdash 4.39.0 / Pod picker navigation, filters and action keys | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/15-pod-picker-help.ansi) |
| [native](native/16-container-picker.png) / [ANSI replay](16-container-picker.png) | kdash 4.39.0 / Framed multi-container picker with resource/state columns | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/16-container-picker.ansi) |
| [native](native/17-inspector-summary.png) / [ANSI replay](17-inspector-summary.png) | kdash 4.39.0 / Inspector summary of a real running pod | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/17-inspector-summary.ansi) |
| [native](native/75-detail-shell-blocked.png) / [ANSI replay](75-detail-shell-blocked.png) | kdash 4.39.0 / Read-only inspector refuses shell actions and explains X | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/75-detail-shell-blocked.ansi) |
| [native](native/76-detail-confirmation.png) / [ANSI replay](76-detail-confirmation.png) | kdash 4.39.0 / X opens confirmation directly from pod detail | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/76-detail-confirmation.ansi) |
| [native](native/77-detail-cancel.png) / [ANSI replay](77-detail-cancel.png) | kdash 4.39.0 / Declining keeps pod detail read-only | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/77-detail-cancel.ansi) |
| [native](native/78-detail-interactive-on.png) / [ANSI replay](78-detail-interactive-on.png) | kdash 4.39.0 / Whole yes answer enables the inspector without leaking keys | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/78-detail-interactive-on.ansi) |
| [native](native/79-detail-shell.png) / [ANSI replay](79-detail-shell.png) | kdash 4.39.0 / Actual container shell opened after enabling X in detail | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/79-detail-shell.ansi) |
| [native](native/80-detail-interactive-off.png) / [ANSI replay](80-detail-interactive-off.png) | kdash 4.39.0 / X disables interactive actions immediately in the inspector | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/80-detail-interactive-off.ansi) |
| [native](native/81-detail-shell-blocked-again.png) / [ANSI replay](81-detail-shell-blocked-again.png) | kdash 4.39.0 / Shell is refused again after disabling X | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/81-detail-shell-blocked-again.ansi) |
| [native](native/18-inspector-logs.png) / [ANSI replay](18-inspector-logs.png) | kdash 4.39.0 / Bounded timestamped logs from the live app container | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/18-inspector-logs.ansi) |
| [native](native/62-inspector-expand.png) / [ANSI replay](62-inspector-expand.png) | kdash 4.39.0 / Expanded bounded log read from the live container | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/62-inspector-expand.ansi) |
| [native](native/63-inspector-all.png) / [ANSI replay](63-inspector-all.png) | kdash 4.39.0 / All available live container logs within the byte cap | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/63-inspector-all.ansi) |
| [native](native/64-inspector-nowrap.png) / [ANSI replay](64-inspector-nowrap.png) | kdash 4.39.0 / Unwrapped logs with horizontal navigation | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/64-inspector-nowrap.ansi) |
| [native](native/65-inspector-json.png) / [ANSI replay](65-inspector-json.png) | kdash 4.39.0 / Readable JSON log formatting enabled | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/65-inspector-json.ansi) |
| [native](native/66-inspector-follow.png) / [ANSI replay](66-inspector-follow.png) | kdash 4.39.0 / Live follow periodically refreshes actual container logs | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/66-inspector-follow.ansi) |
| [native](native/19-inspector-find.png) / [ANSI replay](19-inspector-find.png) | kdash 4.39.0 / Log search highlighting with context retained | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/19-inspector-find.ansi) |
| [native](native/20-inspector-only-matches.png) / [ANSI replay](20-inspector-only-matches.png) | kdash 4.39.0 / Only matching warning lines from real logs | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/20-inspector-only-matches.ansi) |
| [native](native/21-inspector-help.png) / [ANSI replay](21-inspector-help.png) | kdash 4.39.0 / Inspector help for log filtering and export | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/21-inspector-help.ansi) |
| [native](native/22-inspector-export.png) / [ANSI replay](22-inspector-export.png) | kdash 4.39.0 / Visible log pane exported locally | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/22-inspector-export.ansi) |
| [native](native/32-command-palette.png) / [ANSI replay](32-command-palette.png) | kdash 4.39.0 / Fixed-command palette | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/32-command-palette.ansi) |
| [native](native/33-doctor.png) / [ANSI replay](33-doctor.png) | kdash 4.39.0 / Live connection, TLS, RBAC and metrics checks | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/33-doctor.ansi) |
| [native](native/34-pod-filter.png) / [ANSI replay](34-pod-filter.png) | kdash 4.39.0 / Dashboard pod regular expression applied | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/34-pod-filter.ansi) |
| [native](native/35-structured-filters.png) / [ANSI replay](35-structured-filters.png) | kdash 4.39.0 / Atomic label, status, node, workload and unhealthy filters | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/35-structured-filters.ansi) |
| [native](native/36-detail-lines.png) / [ANSI replay](36-detail-lines.png) | kdash 4.39.0 / Toggle container detail lines | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/36-detail-lines.ansi) |
| [native](native/37-pods-only.png) / [ANSI replay](37-pods-only.png) | kdash 4.39.0 / Pod totals without container rows | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/37-pods-only.ansi) |
| [native](native/38-sort-order.png) / [ANSI replay](38-sort-order.png) | kdash 4.39.0 / Sort key and reverse direction | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/38-sort-order.ansi) |
| [native](native/39-paused-interval.png) / [ANSI replay](39-paused-interval.png) | kdash 4.39.0 / Paused collection and changed polling interval | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/39-paused-interval.ansi) |
| [native](native/40-theme-dark.png) / [ANSI replay](40-theme-dark.png) | kdash 4.39.0 / Dark colour theme | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/40-theme-dark.ansi) |
| [native](native/41-theme-light.png) / [ANSI replay](41-theme-light.png) | kdash 4.39.0 / Light colour theme | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/41-theme-light.ansi) |
| [native](native/42-theme-mono.png) / [ANSI replay](42-theme-mono.png) | kdash 4.39.0 / Monochrome colour theme | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/42-theme-mono.ansi) |
| [native](native/43-node-scale.png) / [ANSI replay](43-node-scale.png) | kdash 4.39.0 / Node scope and true-scale resource bars | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/43-node-scale.ansi) |
| [native](native/44-history-window.png) / [ANSI replay](44-history-window.png) | kdash 4.39.0 / Memory history with changed chart window | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/44-history-window.ansi) |
| [native](native/45-html-menu.png) / [ANSI replay](45-html-menu.png) | kdash 4.39.0 / Local HTML report selection menu | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/45-html-menu.ansi) |
| [native](native/46-html-report-written.png) / [ANSI replay](46-html-report-written.png) | kdash 4.39.0 / All-tabs report generated from live session | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/46-html-report-written.ansi) |
| [native](native/47-dashboard-help.png) / [ANSI replay](47-dashboard-help.png) | kdash 4.39.0 / Dashboard navigation and interactive controls | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/47-dashboard-help.ansi) |
| [native](native/48-session-summary.png) / [ANSI replay](48-session-summary.png) | kdash 4.39.0 / Completed live session and retained history | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/48-session-summary.ansi) |
| [native](native/23-interactive-blocked.png) / [ANSI replay](23-interactive-blocked.png) | kdash 4.39.0 / Shell refused while interactive mode is disabled | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/23-interactive-blocked.ansi) |
| [native](native/24-interactive-confirmation.png) / [ANSI replay](24-interactive-confirmation.png) | kdash 4.39.0 / Explicit interactive-mode confirmation | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/24-interactive-confirmation.ansi) |
| [native](native/25-shell-picker.png) / [ANSI replay](25-shell-picker.png) | kdash 4.39.0 / Shell-mode pod picker and action panel | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/25-shell-picker.ansi) |
| [native](native/26-shell-inside.png) / [ANSI replay](26-shell-inside.png) | kdash 4.39.0 / Actual shell inside the live app container | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/26-shell-inside.ansi) |
| [native](native/27-upload-browser.png) / [ANSI replay](27-upload-browser.png) | kdash 4.39.0 / Local framed file browser with enabled upload actions | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/27-upload-browser.ansi) |
| [native](native/28-upload-destination.png) / [ANSI replay](28-upload-destination.png) | kdash 4.39.0 / Remote destination browser before any transfer | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/28-upload-destination.ansi) |
| [native](native/29-upload-review.png) / [ANSI replay](29-upload-review.png) | kdash 4.39.0 / Upload preflight checks and explicit review | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/29-upload-review.ansi) |
| [native](native/30-upload-result.png) / [ANSI replay](30-upload-result.png) | kdash 4.39.0 / Real upload result with source and destination hashes | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/30-upload-result.ansi) |
| [native](native/70-directory-upload-review.png) / [ANSI replay](70-directory-upload-review.png) | kdash 4.39.0 / Directory upload preflight and recursive checksum checks | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/70-directory-upload-review.ansi) |
| [native](native/71-directory-upload-result.png) / [ANSI replay](71-directory-upload-result.png) | kdash 4.39.0 / Actual directory upload with recursive fingerprints | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/71-directory-upload-result.ansi) |
| [native](native/31-download-browser.png) / [ANSI replay](31-download-browser.png) | kdash 4.39.0 / Remote framed file browser with selection and preview keys | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/31-download-browser.ansi) |
| [native](native/49-download-review.png) / [ANSI replay](49-download-review.png) | kdash 4.39.0 / Download preflight, selected format and name conflict checks | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/49-download-review.ansi) |
| [native](native/50-download-result.png) / [ANSI replay](50-download-result.png) | kdash 4.39.0 / Real download result and per-item hash verification | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/50-download-result.ansi) |
| [native](native/55-download-keep-review.png) / [ANSI replay](55-download-keep-review.png) | kdash 4.39.0 / Download preflight, selected format and name conflict checks | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/55-download-keep-review.ansi) |
| [native](native/56-download-keep-result.png) / [ANSI replay](56-download-keep-result.png) | kdash 4.39.0 / Real download result and per-item hash verification | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/56-download-keep-result.ansi) |
| [native](native/57-directory-download-review.png) / [ANSI replay](57-directory-download-review.png) | kdash 4.39.0 / Download preflight, selected format and name conflict checks | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/57-directory-download-review.ansi) |
| [native](native/58-directory-download-result.png) / [ANSI replay](58-directory-download-result.png) | kdash 4.39.0 / Real download result and per-item hash verification | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/58-directory-download-result.ansi) |
| [native](native/59-download-zip-review.png) / [ANSI replay](59-download-zip-review.png) | kdash 4.39.0 / Download preflight, selected format and name conflict checks | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/59-download-zip-review.ansi) |
| [native](native/60-download-zip-result.png) / [ANSI replay](60-download-zip-result.png) | kdash 4.39.0 / Real download result and per-item hash verification | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/60-download-zip-result.ansi) |
| [native](native/61-download-tgz-review.png) / [ANSI replay](61-download-tgz-review.png) | kdash 4.39.0 / Download preflight, selected format and name conflict checks | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/61-download-tgz-review.ansi) |
| [native](native/69-download-tgz-result.png) / [ANSI replay](69-download-tgz-result.png) | kdash 4.39.0 / Real download result and per-item hash verification | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/69-download-tgz-result.ansi) |
| [native](native/51-pods-100col.png) / [ANSI replay](51-pods-100col.png) | kdash 4.39.0 / PODS at 100 columns | 100 x 40 | [capture](../../artifacts/live-e2e-v4390/raw/51-pods-100col.ansi) |
| [native](native/52-picker-100col.png) / [ANSI replay](52-picker-100col.png) | kdash 4.39.0 / Framed pod picker at 100 columns | 100 x 40 | [capture](../../artifacts/live-e2e-v4390/raw/52-picker-100col.ansi) |
| [native](native/53-namespace-100col.png) / [ANSI replay](53-namespace-100col.png) | kdash 4.39.0 / Namespace picker and action panel at 100 columns | 100 x 40 | [capture](../../artifacts/live-e2e-v4390/raw/53-namespace-100col.ansi) |
| [native](native/51-pods-80col.png) / [ANSI replay](51-pods-80col.png) | kdash 4.39.0 / PODS at 80 columns | 80 x 30 | [capture](../../artifacts/live-e2e-v4390/raw/51-pods-80col.ansi) |
| [native](native/82-mode-confirmation-80col.png) / [ANSI replay](82-mode-confirmation-80col.png) | kdash 4.39.0 / Confirmation remains usable in an 80-column terminal | 80 x 30 | [capture](../../artifacts/live-e2e-v4390/raw/82-mode-confirmation-80col.ansi) |
| [native](native/83-mode-enabled-80col.png) / [ANSI replay](83-mode-enabled-80col.png) | kdash 4.39.0 / Uppercase Y plus Enter enables interactive mode at 80 columns | 80 x 30 | [capture](../../artifacts/live-e2e-v4390/raw/83-mode-enabled-80col.ansi) |
| [native](native/52-picker-80col.png) / [ANSI replay](52-picker-80col.png) | kdash 4.39.0 / Framed pod picker at 80 columns | 80 x 30 | [capture](../../artifacts/live-e2e-v4390/raw/52-picker-80col.ansi) |
| [native](native/53-namespace-80col.png) / [ANSI replay](53-namespace-80col.png) | kdash 4.39.0 / Namespace picker and action panel at 80 columns | 80 x 30 | [capture](../../artifacts/live-e2e-v4390/raw/53-namespace-80col.ansi) |
| [native](native/54-ascii-picker.png) / [ANSI replay](54-ascii-picker.png) | kdash 4.39.0 / ASCII framed picker with colour disabled | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/54-ascii-picker.ansi) |
| [native](native/84-certs.png) / [ANSI replay](84-certs.png) | kdash 4.39.0 / CERTIFICATES AND LOGINS real TLS and kubeconfig expiry evidence | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/84-certs.ansi) |
| [native](native/85-runbook.png) / [ANSI replay](85-runbook.png) | kdash 4.39.0 / RUNBOOK printed etcd recovery procedure with live cluster inventory | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/85-runbook.ansi) |
| [native](native/87-runbook-topic.png) / [ANSI replay](87-runbook-topic.png) | kdash 4.39.0 / RUNBOOK next topic displays certificate rotation instructions | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/87-runbook-topic.ansi) |
| [native](native/86-check.png) / [ANSI replay](86-check.png) | kdash 4.39.0 / CHECK NOW actual unhealthy workloads and numbered read-only next commands | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/86-check.ansi) |
| [native](native/88-fmea.png) / [ANSI replay](88-fmea.png) | kdash 4.39.0 / FMEA real failure modes, priority scores and read visibility | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/88-fmea.ansi) |
| [native](native/89-access.png) / [ANSI replay](89-access.png) | kdash 4.39.0 / ACCESS real kubectl auth identity and permission checks | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/89-access.ansi) |
| [native](native/90-fmea-kind.png) / [ANSI replay](90-fmea-kind.png) | kdash 4.39.0 / FMEA kind filter on actual worksheet rows | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/90-fmea-kind.ansi) |
| [native](native/91-fmea-sort.png) / [ANSI replay](91-fmea-sort.png) | kdash 4.39.0 / FMEA worksheet sorted by risk priority number | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/91-fmea-sort.ansi) |
| [native](native/100-dashboard-search.png) / [ANSI replay](100-dashboard-search.png) | kdash 4.39.0 / In-place dashboard search counts real matching lines | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/100-dashboard-search.ansi) |
| [native](native/101-search-other-view.png) / [ANSI replay](101-search-other-view.png) | kdash 4.39.0 / Search retained while switching to live workloads | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/101-search-other-view.ansi) |
| [native](native/102-export-searched-workloads.png) / [ANSI replay](102-export-searched-workloads.png) | kdash 4.39.0 / Quick export includes the screen and every workload line | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/102-export-searched-workloads.ansi) |
| [native](native/103-invalid-search.png) / [ANSI replay](103-invalid-search.png) | kdash 4.39.0 / Invalid search expressions remain editable | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/103-invalid-search.ansi) |
| [native](native/104-search-no-match.png) / [ANSI replay](104-search-no-match.png) | kdash 4.39.0 / A valid unmatched search reports zero matching lines | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/104-search-no-match.ansi) |
| [native](native/105-search-history.png) / [ANSI replay](105-search-history.png) | kdash 4.39.0 / Shared editor recalls this session's earlier search | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/105-search-history.ansi) |
| [native](native/106-search-editor-delete.png) / [ANSI replay](106-search-editor-delete.png) | kdash 4.39.0 / Cursor Home/Delete/End/Backspace leaves the intended search text | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/106-search-editor-delete.ansi) |
| [native](native/107-export-access.png) / [ANSI replay](107-export-access.png) | kdash 4.39.0 / Access view exports its complete permission review | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/107-export-access.ansi) |
| [native](native/108-export-namespaces.png) / [ANSI replay](108-export-namespaces.png) | kdash 4.39.0 / Namespace picker quick export retains every namespace name | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/108-export-namespaces.ansi) |
| [native](native/109-export-pods.png) / [ANSI replay](109-export-pods.png) | kdash 4.39.0 / Pod picker quick export retains full names and resource columns | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/109-export-pods.ansi) |
| [native](native/110-container-find.png) / [ANSI replay](110-container-find.png) | kdash 4.39.0 / Container picker finds a real sidecar by name | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/110-container-find.ansi) |
| [native](native/111-export-containers.png) / [ANSI replay](111-export-containers.png) | kdash 4.39.0 / Container picker exports every regular container and image | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/111-export-containers.ansi) |
| [native](native/112-whole-log-coverage.png) / [ANSI replay](112-whole-log-coverage.png) | kdash 4.39.0 / Whole current log displays read coverage and node proxy capability | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/112-whole-log-coverage.ansi) |
| [native](native/113-log-find-in-place.png) / [ANSI replay](113-log-find-in-place.png) | kdash 4.39.0 / Whole log search counts case-insensitive real warnings | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/113-log-find-in-place.ansi) |
| [native](native/114-log-search-scope.png) / [ANSI replay](114-log-search-scope.png) | kdash 4.39.0 / Full log search offers this pod, workload and namespace scopes | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/114-log-search-scope.ansi) |
| [native](native/115-log-search-invalid-pattern.png) / [ANSI replay](115-log-search-invalid-pattern.png) | kdash 4.39.0 / Invalid full-log search patterns can be corrected before reads begin | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/115-log-search-invalid-pattern.ansi) |
| [native](native/116-log-search-pod.png) / [ANSI replay](116-log-search-pod.png) | kdash 4.39.0 / Merged timestamped matching lines from real pod container logs | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/116-log-search-pod.ansi) |
| [native](native/117-log-search-workload.png) / [ANSI replay](117-log-search-workload.png) | kdash 4.39.0 / Merged timestamped matching lines from real workload container logs | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/117-log-search-workload.ansi) |
| [native](native/118-log-search-namespace.png) / [ANSI replay](118-log-search-namespace.png) | kdash 4.39.0 / Merged timestamped matching lines from real namespace container logs | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/118-log-search-namespace.ansi) |
| [native](native/119-whole-previous-log.png) / [ANSI replay](119-whole-previous-log.png) | kdash 4.39.0 / Full previous instance of a real restarted container | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/119-whole-previous-log.ansi) |
| [native](native/120-certs-secret-public-certificate.png) / [ANSI replay](120-certs-secret-public-certificate.png) | kdash 4.39.0 / Certificate view includes real generated Secret public certificate expiry | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/120-certs-secret-public-certificate.ansi) |
| [native](native/121-certs-secret-search.png) / [ANSI replay](121-certs-secret-search.png) | kdash 4.39.0 / Certificate search finds the generated Secret certificate | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/121-certs-secret-search.ansi) |
| [native](native/122-theme-safe.png) / [ANSI replay](122-theme-safe.png) | kdash 4.39.0 / Live dashboard theme safe | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/122-theme-safe.ansi) |
| [native](native/123-theme-dark.png) / [ANSI replay](123-theme-dark.png) | kdash 4.39.0 / Live dashboard theme dark | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/123-theme-dark.ansi) |
| [native](native/124-theme-light.png) / [ANSI replay](124-theme-light.png) | kdash 4.39.0 / Live dashboard theme light | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/124-theme-light.ansi) |
| [native](native/125-theme-mono.png) / [ANSI replay](125-theme-mono.png) | kdash 4.39.0 / Live dashboard theme mono | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/125-theme-mono.ansi) |
| [native](native/126-fallback-16-colours.png) / [ANSI replay](126-fallback-16-colours.png) | kdash 4.39.0 / Live compatibility mode with sequential reads and 16 ANSI colours | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/126-fallback-16-colours.ansi) |
| [native](native/127-export-local-files.png) / [ANSI replay](127-export-local-files.png) | kdash 4.39.0 / Quick export from the actual local files browser | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/127-export-local-files.ansi) |
| [native](native/128-export-remote-files.png) / [ANSI replay](128-export-remote-files.png) | kdash 4.39.0 / Quick export from the actual remote files browser | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/128-export-remote-files.ansi) |
| [native](native/129-sticky-pod-header.png) / [ANSI replay](129-sticky-pod-header.png) | kdash 4.39.0 / Pod column header stays visible while scrolling the live pod table | 140 x 24 | [capture](../../artifacts/live-e2e-v4390/raw/129-sticky-pod-header.ansi) |
| [native](native/130-dashboard-help-first-page.png) / [ANSI replay](130-dashboard-help-first-page.png) | kdash 4.39.0 / Coloured pod view help on the first page of a 24-row terminal | 140 x 24 | [capture](../../artifacts/live-e2e-v4390/raw/130-dashboard-help-first-page.ansi) |
| [native](native/131-dashboard-help-next-page.png) / [ANSI replay](131-dashboard-help-next-page.png) | kdash 4.39.0 / Dashboard help continues on a second page with back navigation | 140 x 24 | [capture](../../artifacts/live-e2e-v4390/raw/131-dashboard-help-next-page.ansi) |
| [native](native/132-command-palette-style.png) / [ANSI replay](132-command-palette-style.png) | kdash 4.39.0 / Coloured command names and column headings in the command palette | 140 x 24 | [capture](../../artifacts/live-e2e-v4390/raw/132-command-palette-style.ansi) |
| [native](native/133-inspector-summary-tables.png) / [ANSI replay](133-inspector-summary-tables.png) | kdash 4.39.0 / Pod conditions, resources and container state in coloured tables | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/133-inspector-summary-tables.ansi) |
| [native](native/134-inspector-describe.png) / [ANSI replay](134-inspector-describe.png) | kdash 4.39.0 / Restyled describe pane for a live pod | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/134-inspector-describe.ansi) |
| [native](native/135-inspector-events.png) / [ANSI replay](135-inspector-events.png) | kdash 4.39.0 / Restyled events pane for a live pod | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/135-inspector-events.ansi) |
| [native](native/136-inspector-why.png) / [ANSI replay](136-inspector-why.png) | kdash 4.39.0 / Restyled why pane for a live pod | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/136-inspector-why.ansi) |
| [native](native/137-inspector-log-level-colour.png) / [ANSI replay](137-inspector-log-level-colour.png) | kdash 4.39.0 / Live warning lines use a distinct severity colour | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/137-inspector-log-level-colour.ansi) |
| [native](native/138-inspector-empty-level.png) / [ANSI replay](138-inspector-empty-level.png) | kdash 4.39.0 / Empty ERROR filter explains why no log lines are displayed | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/raw/138-inspector-empty-level.ansi) |
| [native](native/139-audit-terminal-wrapped.png) / [ANSI replay](139-audit-terminal-wrapped.png) | kdash 4.39.0 / Narrow terminal audit table with wrapped details from the live run (identities masked) | 100 x 30 | [capture](../../artifacts/live-e2e-v4390/raw/139-audit-terminal-wrapped.ansi) |

## Secrets map

| Screenshot | Live screen | Geometry | ANSI source |
|---|---|---|---|
| [native](secrets/native/92-secrets.png) / [ANSI replay](secrets/92-secrets.png) | kdash 4.39.0 / Live Secrets map: certificate expiry and access | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/secrets/raw/92-secrets.ansi) |
| [native](secrets/native/93-secrets-pan.png) / [ANSI replay](secrets/93-secrets-pan.png) | kdash 4.39.0 / Secrets map scroll and horizontal pan | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/secrets/raw/93-secrets-pan.ansi) |
| [native](secrets/native/94-secrets-help.png) / [ANSI replay](secrets/94-secrets-help.png) | kdash 4.39.0 / Secrets map help and read-only behavior | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/secrets/raw/94-secrets-help.ansi) |
| [native](secrets/native/95-secrets-run-prompt.png) / [ANSI replay](secrets/95-secrets-run-prompt.png) | kdash 4.39.0 / Secrets finding read-command prompt | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/secrets/raw/95-secrets-run-prompt.ansi) |
| [native](secrets/native/96-secrets-export.png) / [ANSI replay](secrets/96-secrets-export.png) | kdash 4.39.0 / Secrets map in a namespace HTML report exported from the dashboard | 170 x 50 | [capture](../../artifacts/live-e2e-v4390/secrets/raw/96-secrets-export.ansi) |

Verify the image bytes with `sha256sum -c SHA256SUMS` in this directory.
See the [generated HTML reports](../html4390/README.md), [sample index](../README.md)
and [operating guide](../../DEVOPS_USER_GUIDE.md) for workflows and coverage limits.
Earlier captures retain their original version: [4.13.1](../cli_413/README.md), [4.14.0](../cli_414/README.md), [4.19.2](../cli_419/README.md), [4.23.1](../cli_423/README.md), [4.24.1](../cli_4241/README.md), [4.27.3](../cli_4273/README.md), [4.27.4](../cli_4274/README.md), [4.32.0](../cli_4320/README.md), [4.37.0](../cli_4370/README.md).
