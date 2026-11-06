# kdash 4.24.1 live WSL terminal captures

Run `live-e2e-20261106-183122` records **166 passed live checks**, **17 passed browser checks** and **83 native WSL terminal screenshots**, with companion ANSI replays, from the installed kdash 4.24.1 in namespace `kdash-e2e`.
The original [results](../../artifacts/live-e2e-20261106-183122/results.json), [checks](../../artifacts/live-e2e-20261106-183122/checks.tsv),
[cluster inventory](../../artifacts/live-e2e-20261106-183122/inventory.json) and [capture manifest](../../artifacts/live-e2e-20261106-183122/captures.tsv)
retain the evidence behind each image. Context: `kdash-local`.
The [browser results](../../artifacts/live-e2e-20261106-183122/browser-results.json) cover the generated report controls.

The `native/` images are actual xterm window screenshots taken while this installed
CLI runs in WSL on a private local Xvfb display. Companion images replay the saved
ANSI screen cell by cell. `results.json` records both image provenance and raw
capture hashes. Actual local namespace names and measurements are unchanged.

The companion replay PNGs render actual `tmux capture-pane -e -p` screens with
[`capture-terminal.py`](../../scripts/capture-terminal.py), using the dimensions in
the manifest. The dashboard supplied every value and character. These are faithful
terminal renders, separate from the native window screenshots. Text/ANSI sources remain linked
below so the visible result can be inspected and reproduced.

The dedicated local `kdash-e2e` namespace contains real workload and diagnostic
cases. The run exercises views, filters, pickers, inspector and logs, interactive
shell/file actions, formatting modes and exports; the check list records what was
asserted. A capture proves the visible screen at that moment, while action and byte
checks establish outcomes. Unknown or unavailable measurements remain visible.

| Screenshot | Live screen | Geometry | ANSI source |
|---|---|---|---|
| [native](native/01-pods.png) / [ANSI replay](01-pods.png) | kdash 4.24.1 / PODS live requests, limits and measured usage | 170 x 50 | [capture](../../artifacts/live-e2e-20261106-183122/raw/01-pods.ansi) |
| [native](native/02-nodes.png) / [ANSI replay](02-nodes.png) | kdash 4.24.1 / NODE POOLS real allocatable capacity and namespace share | 170 x 50 | [capture](../../artifacts/live-e2e-20261106-183122/raw/02-nodes.ansi) |
| [native](native/03-workloads.png) / [ANSI replay](03-workloads.png) | kdash 4.24.1 / WORKLOADS live replicas and placement | 170 x 50 | [capture](../../artifacts/live-e2e-20261106-183122/raw/03-workloads.ansi) |
| [native](native/04-ip.png) / [ANSI replay](04-ip.png) | kdash 4.24.1 / IP POOL real pod, node and service addresses | 170 x 50 | [capture](../../artifacts/live-e2e-20261106-183122/raw/04-ip.ansi) |
| [native](native/05-mem.png) / [ANSI replay](05-mem.png) | kdash 4.24.1 / MEMORY live history and pod usage | 170 x 50 | [capture](../../artifacts/live-e2e-20261106-183122/raw/05-mem.ansi) |
| [native](native/06-io.png) / [ANSI replay](06-io.png) | kdash 4.24.1 / NETWORK AND DISK IO capability and live samples | 170 x 50 | [capture](../../artifacts/live-e2e-20261106-183122/raw/06-io.ansi) |
| [native](native/07-alerts.png) / [ANSI replay](07-alerts.png) | kdash 4.24.1 / ALERTS real unhealthy fixture workloads | 170 x 50 | [capture](../../artifacts/live-e2e-20261106-183122/raw/07-alerts.ansi) |
| [native](native/08-services.png) / [ANSI replay](08-services.png) | kdash 4.24.1 / SERVICES ingress, ready endpoints and missing backend | 170 x 50 | [capture](../../artifacts/live-e2e-20261106-183122/raw/08-services.ansi) |
| [native](native/09-storage.png) / [ANSI replay](09-storage.png) | kdash 4.24.1 / STORAGE bound volume and pending claim | 170 x 50 | [capture](../../artifacts/live-e2e-20261106-183122/raw/09-storage.ansi) |
| [native](native/10-events.png) / [ANSI replay](10-events.png) | kdash 4.24.1 / EVENTS real Kubernetes scheduler and kubelet events | 170 x 50 | [capture](../../artifacts/live-e2e-20261106-183122/raw/10-events.ansi) |
| [native](native/11-explain.png) / [ANSI replay](11-explain.png) | kdash 4.24.1 / INCIDENT EVIDENCE from actual failing workloads | 170 x 50 | [capture](../../artifacts/live-e2e-20261106-183122/raw/11-explain.ansi) |
| [native](native/12-namespace-picker.png) / [ANSI replay](12-namespace-picker.png) | kdash 4.24.1 / Framed namespace picker with access and persistent default controls | 170 x 50 | [capture](../../artifacts/live-e2e-20261106-183122/raw/12-namespace-picker.ansi) |
| [native](native/13-namespace-filter.png) / [ANSI replay](13-namespace-filter.png) | kdash 4.24.1 / Live namespace search and context-sensitive action panel | 170 x 50 | [capture](../../artifacts/live-e2e-20261106-183122/raw/13-namespace-filter.ansi) |
| [native](native/67-namespace-saved-default.png) / [ANSI replay](67-namespace-saved-default.png) | kdash 4.24.1 / A subsequent launch opens the namespace saved with d | 170 x 50 | [capture](../../artifacts/live-e2e-20261106-183122/raw/67-namespace-saved-default.ansi) |
| [native](native/68-namespace-typed.png) / [ANSI replay](68-namespace-typed.png) | kdash 4.24.1 / t opens an explicitly typed namespace | 170 x 50 | [capture](../../artifacts/live-e2e-20261106-183122/raw/68-namespace-typed.ansi) |
| [native](native/14-pod-picker.png) / [ANSI replay](14-pod-picker.png) | kdash 4.24.1 / Framed live pod picker with CPU, memory, restarts and attention state | 170 x 50 | [capture](../../artifacts/live-e2e-20261106-183122/raw/14-pod-picker.ansi) |
| [native](native/15-pod-picker-help.png) / [ANSI replay](15-pod-picker-help.png) | kdash 4.24.1 / Pod picker navigation, filters and action keys | 170 x 50 | [capture](../../artifacts/live-e2e-20261106-183122/raw/15-pod-picker-help.ansi) |
| [native](native/16-container-picker.png) / [ANSI replay](16-container-picker.png) | kdash 4.24.1 / Framed multi-container picker with resource/state columns | 170 x 50 | [capture](../../artifacts/live-e2e-20261106-183122/raw/16-container-picker.ansi) |
| [native](native/17-inspector-summary.png) / [ANSI replay](17-inspector-summary.png) | kdash 4.24.1 / Inspector summary of a real running pod | 170 x 50 | [capture](../../artifacts/live-e2e-20261106-183122/raw/17-inspector-summary.ansi) |
| [native](native/75-detail-shell-blocked.png) / [ANSI replay](75-detail-shell-blocked.png) | kdash 4.24.1 / Read-only inspector refuses shell actions and explains X | 170 x 50 | [capture](../../artifacts/live-e2e-20261106-183122/raw/75-detail-shell-blocked.ansi) |
| [native](native/76-detail-confirmation.png) / [ANSI replay](76-detail-confirmation.png) | kdash 4.24.1 / X opens confirmation directly from pod detail | 170 x 50 | [capture](../../artifacts/live-e2e-20261106-183122/raw/76-detail-confirmation.ansi) |
| [native](native/77-detail-cancel.png) / [ANSI replay](77-detail-cancel.png) | kdash 4.24.1 / Declining keeps pod detail read-only | 170 x 50 | [capture](../../artifacts/live-e2e-20261106-183122/raw/77-detail-cancel.ansi) |
| [native](native/78-detail-interactive-on.png) / [ANSI replay](78-detail-interactive-on.png) | kdash 4.24.1 / Whole yes answer enables the inspector without leaking keys | 170 x 50 | [capture](../../artifacts/live-e2e-20261106-183122/raw/78-detail-interactive-on.ansi) |
| [native](native/79-detail-shell.png) / [ANSI replay](79-detail-shell.png) | kdash 4.24.1 / Actual container shell opened after enabling X in detail | 170 x 50 | [capture](../../artifacts/live-e2e-20261106-183122/raw/79-detail-shell.ansi) |
| [native](native/80-detail-interactive-off.png) / [ANSI replay](80-detail-interactive-off.png) | kdash 4.24.1 / X disables interactive actions immediately in the inspector | 170 x 50 | [capture](../../artifacts/live-e2e-20261106-183122/raw/80-detail-interactive-off.ansi) |
| [native](native/81-detail-shell-blocked-again.png) / [ANSI replay](81-detail-shell-blocked-again.png) | kdash 4.24.1 / Shell is refused again after disabling X | 170 x 50 | [capture](../../artifacts/live-e2e-20261106-183122/raw/81-detail-shell-blocked-again.ansi) |
| [native](native/18-inspector-logs.png) / [ANSI replay](18-inspector-logs.png) | kdash 4.24.1 / Bounded timestamped logs from the live app container | 170 x 50 | [capture](../../artifacts/live-e2e-20261106-183122/raw/18-inspector-logs.ansi) |
| [native](native/62-inspector-expand.png) / [ANSI replay](62-inspector-expand.png) | kdash 4.24.1 / Expanded bounded log read from the live container | 170 x 50 | [capture](../../artifacts/live-e2e-20261106-183122/raw/62-inspector-expand.ansi) |
| [native](native/63-inspector-all.png) / [ANSI replay](63-inspector-all.png) | kdash 4.24.1 / All available live container logs within the byte cap | 170 x 50 | [capture](../../artifacts/live-e2e-20261106-183122/raw/63-inspector-all.ansi) |
| [native](native/64-inspector-nowrap.png) / [ANSI replay](64-inspector-nowrap.png) | kdash 4.24.1 / Unwrapped logs with horizontal navigation | 170 x 50 | [capture](../../artifacts/live-e2e-20261106-183122/raw/64-inspector-nowrap.ansi) |
| [native](native/65-inspector-json.png) / [ANSI replay](65-inspector-json.png) | kdash 4.24.1 / Readable JSON log formatting enabled | 170 x 50 | [capture](../../artifacts/live-e2e-20261106-183122/raw/65-inspector-json.ansi) |
| [native](native/66-inspector-follow.png) / [ANSI replay](66-inspector-follow.png) | kdash 4.24.1 / Live follow periodically refreshes actual container logs | 170 x 50 | [capture](../../artifacts/live-e2e-20261106-183122/raw/66-inspector-follow.ansi) |
| [native](native/19-inspector-find.png) / [ANSI replay](19-inspector-find.png) | kdash 4.24.1 / Log search highlighting with context retained | 170 x 50 | [capture](../../artifacts/live-e2e-20261106-183122/raw/19-inspector-find.ansi) |
| [native](native/20-inspector-only-matches.png) / [ANSI replay](20-inspector-only-matches.png) | kdash 4.24.1 / Only matching warning lines from real logs | 170 x 50 | [capture](../../artifacts/live-e2e-20261106-183122/raw/20-inspector-only-matches.ansi) |
| [native](native/21-inspector-help.png) / [ANSI replay](21-inspector-help.png) | kdash 4.24.1 / Inspector help for log filtering and export | 170 x 50 | [capture](../../artifacts/live-e2e-20261106-183122/raw/21-inspector-help.ansi) |
| [native](native/22-inspector-export.png) / [ANSI replay](22-inspector-export.png) | kdash 4.24.1 / Visible log pane exported locally | 170 x 50 | [capture](../../artifacts/live-e2e-20261106-183122/raw/22-inspector-export.ansi) |
| [native](native/32-command-palette.png) / [ANSI replay](32-command-palette.png) | kdash 4.24.1 / Fixed-command palette | 170 x 50 | [capture](../../artifacts/live-e2e-20261106-183122/raw/32-command-palette.ansi) |
| [native](native/33-doctor.png) / [ANSI replay](33-doctor.png) | kdash 4.24.1 / Live connection, TLS, RBAC and metrics checks | 170 x 50 | [capture](../../artifacts/live-e2e-20261106-183122/raw/33-doctor.ansi) |
| [native](native/34-pod-filter.png) / [ANSI replay](34-pod-filter.png) | kdash 4.24.1 / Dashboard pod regular expression applied | 170 x 50 | [capture](../../artifacts/live-e2e-20261106-183122/raw/34-pod-filter.ansi) |
| [native](native/35-structured-filters.png) / [ANSI replay](35-structured-filters.png) | kdash 4.24.1 / Atomic label, status, node, workload and unhealthy filters | 170 x 50 | [capture](../../artifacts/live-e2e-20261106-183122/raw/35-structured-filters.ansi) |
| [native](native/36-detail-lines.png) / [ANSI replay](36-detail-lines.png) | kdash 4.24.1 / Toggle container detail lines | 170 x 50 | [capture](../../artifacts/live-e2e-20261106-183122/raw/36-detail-lines.ansi) |
| [native](native/37-pods-only.png) / [ANSI replay](37-pods-only.png) | kdash 4.24.1 / Pod totals without container rows | 170 x 50 | [capture](../../artifacts/live-e2e-20261106-183122/raw/37-pods-only.ansi) |
| [native](native/38-sort-order.png) / [ANSI replay](38-sort-order.png) | kdash 4.24.1 / Sort key and reverse direction | 170 x 50 | [capture](../../artifacts/live-e2e-20261106-183122/raw/38-sort-order.ansi) |
| [native](native/39-paused-interval.png) / [ANSI replay](39-paused-interval.png) | kdash 4.24.1 / Paused collection and changed polling interval | 170 x 50 | [capture](../../artifacts/live-e2e-20261106-183122/raw/39-paused-interval.ansi) |
| [native](native/40-theme-dark.png) / [ANSI replay](40-theme-dark.png) | kdash 4.24.1 / Dark colour theme | 170 x 50 | [capture](../../artifacts/live-e2e-20261106-183122/raw/40-theme-dark.ansi) |
| [native](native/41-theme-light.png) / [ANSI replay](41-theme-light.png) | kdash 4.24.1 / Light colour theme | 170 x 50 | [capture](../../artifacts/live-e2e-20261106-183122/raw/41-theme-light.ansi) |
| [native](native/42-theme-mono.png) / [ANSI replay](42-theme-mono.png) | kdash 4.24.1 / Monochrome colour theme | 170 x 50 | [capture](../../artifacts/live-e2e-20261106-183122/raw/42-theme-mono.ansi) |
| [native](native/43-node-scale.png) / [ANSI replay](43-node-scale.png) | kdash 4.24.1 / Node scope and true-scale resource bars | 170 x 50 | [capture](../../artifacts/live-e2e-20261106-183122/raw/43-node-scale.ansi) |
| [native](native/44-history-window.png) / [ANSI replay](44-history-window.png) | kdash 4.24.1 / Memory history with changed chart window | 170 x 50 | [capture](../../artifacts/live-e2e-20261106-183122/raw/44-history-window.ansi) |
| [native](native/45-html-menu.png) / [ANSI replay](45-html-menu.png) | kdash 4.24.1 / Local HTML report selection menu | 170 x 50 | [capture](../../artifacts/live-e2e-20261106-183122/raw/45-html-menu.ansi) |
| [native](native/46-html-report-written.png) / [ANSI replay](46-html-report-written.png) | kdash 4.24.1 / All-tabs report generated from live session | 170 x 50 | [capture](../../artifacts/live-e2e-20261106-183122/raw/46-html-report-written.ansi) |
| [native](native/47-dashboard-help.png) / [ANSI replay](47-dashboard-help.png) | kdash 4.24.1 / Dashboard navigation and interactive controls | 170 x 50 | [capture](../../artifacts/live-e2e-20261106-183122/raw/47-dashboard-help.ansi) |
| [native](native/48-session-summary.png) / [ANSI replay](48-session-summary.png) | kdash 4.24.1 / Completed live session and retained history | 170 x 50 | [capture](../../artifacts/live-e2e-20261106-183122/raw/48-session-summary.ansi) |
| [native](native/23-interactive-blocked.png) / [ANSI replay](23-interactive-blocked.png) | kdash 4.24.1 / Shell refused while interactive mode is disabled | 170 x 50 | [capture](../../artifacts/live-e2e-20261106-183122/raw/23-interactive-blocked.ansi) |
| [native](native/24-interactive-confirmation.png) / [ANSI replay](24-interactive-confirmation.png) | kdash 4.24.1 / Explicit interactive-mode confirmation | 170 x 50 | [capture](../../artifacts/live-e2e-20261106-183122/raw/24-interactive-confirmation.ansi) |
| [native](native/25-shell-picker.png) / [ANSI replay](25-shell-picker.png) | kdash 4.24.1 / Shell-mode pod picker and action panel | 170 x 50 | [capture](../../artifacts/live-e2e-20261106-183122/raw/25-shell-picker.ansi) |
| [native](native/26-shell-inside.png) / [ANSI replay](26-shell-inside.png) | kdash 4.24.1 / Actual shell inside the live app container | 170 x 50 | [capture](../../artifacts/live-e2e-20261106-183122/raw/26-shell-inside.ansi) |
| [native](native/27-upload-browser.png) / [ANSI replay](27-upload-browser.png) | kdash 4.24.1 / Local framed file browser with enabled upload actions | 170 x 50 | [capture](../../artifacts/live-e2e-20261106-183122/raw/27-upload-browser.ansi) |
| [native](native/28-upload-destination.png) / [ANSI replay](28-upload-destination.png) | kdash 4.24.1 / Remote destination browser before any transfer | 170 x 50 | [capture](../../artifacts/live-e2e-20261106-183122/raw/28-upload-destination.ansi) |
| [native](native/29-upload-review.png) / [ANSI replay](29-upload-review.png) | kdash 4.24.1 / Upload preflight checks and explicit review | 170 x 50 | [capture](../../artifacts/live-e2e-20261106-183122/raw/29-upload-review.ansi) |
| [native](native/30-upload-result.png) / [ANSI replay](30-upload-result.png) | kdash 4.24.1 / Real upload result with source and destination hashes | 170 x 50 | [capture](../../artifacts/live-e2e-20261106-183122/raw/30-upload-result.ansi) |
| [native](native/70-directory-upload-review.png) / [ANSI replay](70-directory-upload-review.png) | kdash 4.24.1 / Directory upload preflight and recursive checksum checks | 170 x 50 | [capture](../../artifacts/live-e2e-20261106-183122/raw/70-directory-upload-review.ansi) |
| [native](native/71-directory-upload-result.png) / [ANSI replay](71-directory-upload-result.png) | kdash 4.24.1 / Actual directory upload with recursive fingerprints | 170 x 50 | [capture](../../artifacts/live-e2e-20261106-183122/raw/71-directory-upload-result.ansi) |
| [native](native/31-download-browser.png) / [ANSI replay](31-download-browser.png) | kdash 4.24.1 / Remote framed file browser with selection and preview keys | 170 x 50 | [capture](../../artifacts/live-e2e-20261106-183122/raw/31-download-browser.ansi) |
| [native](native/49-download-review.png) / [ANSI replay](49-download-review.png) | kdash 4.24.1 / Download preflight, selected format and name conflict checks | 170 x 50 | [capture](../../artifacts/live-e2e-20261106-183122/raw/49-download-review.ansi) |
| [native](native/50-download-result.png) / [ANSI replay](50-download-result.png) | kdash 4.24.1 / Real download result and per-item hash verification | 170 x 50 | [capture](../../artifacts/live-e2e-20261106-183122/raw/50-download-result.ansi) |
| [native](native/55-download-keep-review.png) / [ANSI replay](55-download-keep-review.png) | kdash 4.24.1 / Download preflight, selected format and name conflict checks | 170 x 50 | [capture](../../artifacts/live-e2e-20261106-183122/raw/55-download-keep-review.ansi) |
| [native](native/56-download-keep-result.png) / [ANSI replay](56-download-keep-result.png) | kdash 4.24.1 / Real download result and per-item hash verification | 170 x 50 | [capture](../../artifacts/live-e2e-20261106-183122/raw/56-download-keep-result.ansi) |
| [native](native/57-directory-download-review.png) / [ANSI replay](57-directory-download-review.png) | kdash 4.24.1 / Download preflight, selected format and name conflict checks | 170 x 50 | [capture](../../artifacts/live-e2e-20261106-183122/raw/57-directory-download-review.ansi) |
| [native](native/58-directory-download-result.png) / [ANSI replay](58-directory-download-result.png) | kdash 4.24.1 / Real download result and per-item hash verification | 170 x 50 | [capture](../../artifacts/live-e2e-20261106-183122/raw/58-directory-download-result.ansi) |
| [native](native/59-download-zip-review.png) / [ANSI replay](59-download-zip-review.png) | kdash 4.24.1 / Download preflight, selected format and name conflict checks | 170 x 50 | [capture](../../artifacts/live-e2e-20261106-183122/raw/59-download-zip-review.ansi) |
| [native](native/60-download-zip-result.png) / [ANSI replay](60-download-zip-result.png) | kdash 4.24.1 / Real download result and per-item hash verification | 170 x 50 | [capture](../../artifacts/live-e2e-20261106-183122/raw/60-download-zip-result.ansi) |
| [native](native/61-download-tgz-review.png) / [ANSI replay](61-download-tgz-review.png) | kdash 4.24.1 / Download preflight, selected format and name conflict checks | 170 x 50 | [capture](../../artifacts/live-e2e-20261106-183122/raw/61-download-tgz-review.ansi) |
| [native](native/69-download-tgz-result.png) / [ANSI replay](69-download-tgz-result.png) | kdash 4.24.1 / Real download result and per-item hash verification | 170 x 50 | [capture](../../artifacts/live-e2e-20261106-183122/raw/69-download-tgz-result.ansi) |
| [native](native/51-pods-100col.png) / [ANSI replay](51-pods-100col.png) | kdash 4.24.1 / PODS at 100 columns | 100 x 40 | [capture](../../artifacts/live-e2e-20261106-183122/raw/51-pods-100col.ansi) |
| [native](native/52-picker-100col.png) / [ANSI replay](52-picker-100col.png) | kdash 4.24.1 / Framed pod picker at 100 columns | 100 x 40 | [capture](../../artifacts/live-e2e-20261106-183122/raw/52-picker-100col.ansi) |
| [native](native/53-namespace-100col.png) / [ANSI replay](53-namespace-100col.png) | kdash 4.24.1 / Namespace picker and action panel at 100 columns | 100 x 40 | [capture](../../artifacts/live-e2e-20261106-183122/raw/53-namespace-100col.ansi) |
| [native](native/51-pods-80col.png) / [ANSI replay](51-pods-80col.png) | kdash 4.24.1 / PODS at 80 columns | 80 x 30 | [capture](../../artifacts/live-e2e-20261106-183122/raw/51-pods-80col.ansi) |
| [native](native/82-mode-confirmation-80col.png) / [ANSI replay](82-mode-confirmation-80col.png) | kdash 4.24.1 / Confirmation remains usable in an 80-column terminal | 80 x 30 | [capture](../../artifacts/live-e2e-20261106-183122/raw/82-mode-confirmation-80col.ansi) |
| [native](native/83-mode-enabled-80col.png) / [ANSI replay](83-mode-enabled-80col.png) | kdash 4.24.1 / Uppercase Y plus Enter enables interactive mode at 80 columns | 80 x 30 | [capture](../../artifacts/live-e2e-20261106-183122/raw/83-mode-enabled-80col.ansi) |
| [native](native/52-picker-80col.png) / [ANSI replay](52-picker-80col.png) | kdash 4.24.1 / Framed pod picker at 80 columns | 80 x 30 | [capture](../../artifacts/live-e2e-20261106-183122/raw/52-picker-80col.ansi) |
| [native](native/53-namespace-80col.png) / [ANSI replay](53-namespace-80col.png) | kdash 4.24.1 / Namespace picker and action panel at 80 columns | 80 x 30 | [capture](../../artifacts/live-e2e-20261106-183122/raw/53-namespace-80col.ansi) |
| [native](native/54-ascii-picker.png) / [ANSI replay](54-ascii-picker.png) | kdash 4.24.1 / ASCII framed picker with colour disabled | 170 x 50 | [capture](../../artifacts/live-e2e-20261106-183122/raw/54-ascii-picker.ansi) |

Verify the image bytes with `sha256sum -c SHA256SUMS` in this directory.
See the [generated HTML reports](../html4241/README.md), [sample index](../README.md)
and [operating guide](../../DEVOPS_USER_GUIDE.md) for workflows and coverage limits.
Earlier captures retain their original version: [4.13.1](../cli_413/README.md), [4.14.0](../cli_414/README.md), [4.19.2](../cli_419/README.md), [4.23.1](../cli_423/README.md).
