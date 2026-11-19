# kdash 4.37.0 feature validation

This checklist records the 2026-11-20 local WSL validation refresh. Run
`live-e2e-v4370` finished with 303 live checks (200 baseline plus 103 extension),
30 Secrets checks, 33 browser checks, all 19 fixture suites and 125 published
terminal screenshots. Every row below is backed by current-version evidence; the
limits that remain are recorded at the end. Check names are the actual test
identifiers or their explicitly marked families.

The test namespace is `kdash-e2e`, context `kdash-local`, on the existing local
cluster. Workloads, service endpoints, PVCs, Events, certificate fixtures and
container logs provide real data. Fixture creation and container file writes
stay within the validation resources. The runner uses an isolated kubeconfig,
configuration, audit directory and tmux socket.

The published CLI gallery includes actual live xterm screenshots and separately
labelled ANSI replays, with hashes for each image type. Actual cluster context,
workload and namespace names, metrics, addresses and timestamps are preserved;
personal workstation paths are removed where needed.

Evidence entry points:

- [Installed CLI results and per-check details](../artifacts/live-e2e-v4370/results.json),
  [check table](../artifacts/live-e2e-v4370/checks.tsv) and
  [capture manifest](../artifacts/live-e2e-v4370/captures.tsv).
- [Extended feature results](../artifacts/live-e2e-v4370/extended/results.json)
  and [checks](../artifacts/live-e2e-v4370/extended/checks.tsv).
- [Secrets-map checks](../artifacts/live-e2e-v4370/secrets/results.json).
- [Browser results](../artifacts/live-e2e-v4370/browser-results.json).
- [CLI gallery](../samples/cli_4370/README.md) and
  [generated HTML reports and browser images](../samples/html4370/README.md).

## Source, installation and command handling

| Functionality | Current check or fixture coverage | Visual/command evidence | Result |
|---|---|---|---|
| Authoritative bundle import; module/core/uninstaller byte synchronization | `scripts/build.sh --from-bundle`, `--check`; `tests/test-build.sh` | build log; package hashes | PASS |
| Installed binary is the tested source version | `installed-source-identical`, `version` | `results.json` source/installed SHA-256; `logs/version.log` | PASS |
| Installer prefix, shell integration, Bash completion, shortcut handling and uninstall retention | `tests/test-build.sh`, `tests/test-uninstall.sh`; `completion` | installer self-check, `logs/completion.log` | PASS |
| Disclaimer acceptance, audit requirements and guarded kubectl verbs | `tests/test-runtime.sh`, `tests/test-interactive.sh`; `about`, `audit-*` | `logs/about.log`; audit report | PASS |
| Help, version, invalid arguments and empty pod selection | `help`, `version`, `invalid-option`, `empty-filter` | respective `logs/*.log` | PASS |
| Explicit context, kubeconfig, namespace, all-namespace and comparison scope | `all-namespaces`, `compare`; runtime fixtures | `logs/all-namespaces.log`, `logs/compare.log` | PASS |
| API timeout, partial/denied reads and unavailable metrics remain visible | `tests/test-runtime.sh`, `tests/test-health.sh`; `doctor`, `no-cluster-metrics-io` | `33-doctor`; coverage/status text | PASS |

## Resource views and diagnostics

Each listed `view-*` check runs the installed CLI with `--once`. Live dashboard
screens are separate checks named `capture-<stem>`.

| Functionality | Current live checks | CLI screenshots / output | Result |
|---|---|---|---|
| `1` PODS: pod/container resources, readiness, restarts, grouping and history | `view-pods`, `real-data-pods`, `flat-pods` | `01-pods`, `36-detail-lines`, `37-pods-only`, `38-sort-order` | PASS |
| `2` NODE POOLS: namespace/cluster share, nodes, hosting-only and scale | `view-nodes`, `compare` | `02-nodes`, `43-node-scale` | PASS |
| `3` WORKLOADS: replica readiness, pod placement and spread | `view-workloads` | `03-workloads` | PASS |
| `4` IP POOL: pod/service IPs, node/subnet joins and anomalies | `view-ip` | `04-ip` | PASS |
| `5` MEMORY: CPU/memory samples, time window, OOM evidence and forecast | `view-mem` | `05-mem`, `44-history-window`; HTML `mem`, `history` | PASS |
| `6` NET & DISK IO: counter samples, rates and missing-source handling | `view-io`; health/runtime fixture cases | `06-io`; `logs/view-io.log` | PASS |
| `7` ALERTS: severity, trends, findings and suggested commands | `view-alerts`, `all-views` | `07-alerts`; HTML overview/actions | PASS |
| `8` SERVICES: ingress/service/EndpointSlice/pod joins | `view-services`, `real-data-services` | `08-services`; `logs/view-services.log` | PASS |
| `9` STORAGE: PVC/PV/class, mounts and unavailable usage | `view-storage`, `real-data-storage` | `09-storage`; `logs/view-storage.log` | PASS |
| `E` EVENTS: actual Events and filters | `view-events`, `events`; `tests/test-events.sh` | `10-events` | PASS |
| `!` EXPLAIN: evidence-backed hypotheses and read commands | `view-explain`, `explain`; event fixtures | `11-explain` | PASS |
| Doctor: API/TLS/RBAC/metrics/report diagnostics | `doctor` | `33-doctor` | PASS |
| `C` CERTIFICATES: API/client/CA, readable node/host/webhook/ingress sources | `certs`; health fixtures | `84-certs`; `logs/certs.log` | PASS |
| `C` Secret certificate expiry and usage addition | extended certificate/Secret check; Secrets fixtures retained for the check | extended capture manifest; certificate output | PASS |
| `R` RUNBOOKS: etcd-restore, cert-rotate, node-notready, api-unreachable, oidc-login | `runbook-*`, `runbook-real-node-inventory`, `runbook-topic-cycle` | `85-runbook`, `87-runbook-topic` | PASS |
| `K` CHECK NOW: current findings and guarded numbered reads | `check-summary`, `check-real-finding-selected`, `check-run-finding`, `check-ui-real-findings` | `86-check`; check logs and saved command output | PASS |
| `M` FMEA: scores, action priority, kind filtering, sort, site overrides and unknown coverage | `fmea-summary`, `fmea-json-real-rows`; `tests/test-fmea.sh` | `88-fmea`, `90-fmea-kind`, `91-fmea-sort` | PASS |
| FMEA CSV/TSV/JSON/HTML, trend, gate and numbered confirming reads | `csv-fmea`, `tsv-fmea`, `fmea-json`, `fmea-html`, `fmea-fail-on-high`, `fmea-trend`, `fmea-run-finding`, `fmea-run-read-commands-only` | FMEA report and CLI logs | PASS |
| ACCESS identity, per-resource permissions, coverage and suggested read RBAC | `fmea-access`; FMEA access fixtures | `89-access`; `logs/fmea-access.log` | PASS |
| `Y` SECRETS MAP: inventory, public certificates, usage, findings and non-value handling | `secrets-json-schema-and-inventory`, `secrets-fixture-public-certificate-and-consumer`, `secrets-default-does-not-fetch-private-key`, `secrets-exports-exclude-value-canary-and-private-pem` | Secrets capture manifest and API safety trace | PASS |
| Secrets CSV/TSV/JSON/HTML, fail gates, confirming reads and optional key match check | Secrets command/structured-schema checks; `secrets-keycheck-valid`, `secrets-keycheck-mismatch` when generated key-check fixtures are supplied | Secrets reports and logs | PASS |
| Secrets dedicated timeout, Helm-history exclusion and UTC date formatting | extended checks and Secrets fixtures | extended/Secrets output and captures | PASS |

## Navigation, search and pod inspection

| Functionality | Current live checks or fixture coverage | Screenshots / output | Result |
|---|---|---|---|
| Namespace list/filter, typed name, default save/clear and next launch | `namespace-save-default`, `namespace-default-next-launch`, `namespace-clear-default`, `namespace-typed-name`; runtime fixtures | `12-namespace-picker`, `13-namespace-filter`, `67-namespace-saved-default`, `68-namespace-typed` | PASS |
| Dashboard whole-view `/` search, next/previous, invalid regex and Tab pod filter | `extended-dashboard-live-search/navigation`; baseline `filter-regex` | extended capture manifest; `34-pod-filter` | PASS |
| Label/status/node/workload/unhealthy filters, report filter propagation | `filter-label`, `filter-status`, `filter-workload`, `filter-unhealthy`; runtime fixtures | `35-structured-filters`; relevant CLI logs | PASS |
| Scroll/page/pan/top/bottom, sort/reverse, grouping/detail, poll pause/interval | dashboard controls; runtime/visual fixtures | `36`–`44` control captures | PASS |
| Command palette and per-view help | baseline controls; `tests/test-inspector.sh` | `32-command-palette`, `47-dashboard-help` | PASS |
| Pod picker, attention/filter/sort/navigation and action return | live pod picker; inspector fixtures | `14-pod-picker`, `15-pod-picker-help` | PASS |
| Container inventory, init/debug visibility, state and container selection | `inspect-summary`; inspector fixtures | `16-container-picker`, `17-inspector-summary` | PASS |
| Summary, describe, Events and explanation panes | `inspect-summary`, inspector fixtures and extended pane exports | `17-inspector-summary`; extended pane captures | PASS |
| Current and previous timestamped log reads | `inspect-logs`, `inspect-previous` | `18-inspector-logs`; CLI log output | PASS |
| Log search/highlighting/context, case handling, only matches, n/N and levels | `extended-only-matches-export`; inspector fixtures | `19-inspector-find`, `20-inspector-only-matches`, `21-inspector-help` | PASS |
| Tail expansion/all lines, byte/time caps and truthful incomplete status | `extended-log-coverage-truthful`; inspector fixtures | `62-inspector-expand`, `63-inspector-all` | PASS |
| Wrap/pan, readable JSON and follow refresh | inspector fixtures; live toggles | `64-inspector-nowrap`, `65-inspector-json`, `66-inspector-follow` | PASS |
| `F` log search for pod/workload/namespace, timestamp merging and previous instance | `extended-log-scope-pod/workload/namespace`, `extended-log-search-previous-instance` | extended capture manifest, matched-log output | PASS |
| Older kubelet-rotated logs, gzip/CRI decoding, limits and denied/disabled access | extended live node-proxy check plus deterministic inspector fixtures | extended result explicitly states whether the cluster has retained rotated files | PASS |
| Prompt arrow editing, erase/cancel and per-prompt session history | `extended-line-editor-insert-arrow`; inspector fixtures | extended search/prompt captures | PASS |
| Inspector explicit filtered `w` export | `inspector-export-artifact`; extended content assertions | `22-inspector-export`; saved pane | PASS |
| `>` quick export of 17 views, namespace/pod/container lists, panes and local/remote file lists | `extended-quick-export-*` families | extended capture manifest and generated `.log` files | PASS |
| Export mode/content, no escape codes, full rows, aggregate session log and latest link | `extended-session-export-aggregation`, `extended-latest-export-link`; quick-export assertions | extended export evidence | PASS |
| Safe/dark/light/mono, ANSI-16, ASCII and narrow geometry | `extended-theme-*`, `extended-legacy-render-fallbacks`; `ascii-no-color`; visuals fixtures | `40`–`42`, `51`–`54`, `82`–`83`; extended captures | PASS |
| Changed-line redraw, scroll-region fallback, quiet refresh, view cache, model/API parallelism | extended fallback checks; runtime/visual fixtures | default live run plus explicit legacy-fallback output | PASS |

## Guarded shell and file operations

| Functionality | Current live checks or fixture coverage | Screenshots / output | Result |
|---|---|---|---|
| Read-only shell refusal, X confirm/cancel/on/off from dashboard and inspector | `tests/test-mode-switch.sh`, `tests/test-interactive.sh`; live mode flows | `23`–`24`, `75`–`83` | PASS |
| Real container shell, chosen container, exit/return and related-pod switch | live shell flows; interactive fixtures | `25-shell-picker`, `26-shell-inside`, `79-detail-shell` | PASS |
| Local and remote file browsing, filtering, directories, typed path, preview and marking | live transfer flow; transfer fixtures | `27-upload-browser`, `28-upload-destination`, `31-download-browser` | PASS |
| Upload review, confirmation, cancellation and single-file bytes | `upload-roundtrip-bytes`; transfer progress/upload regression fixtures | `29-upload-review`, `30-upload-result` | PASS |
| Directory upload with recursive content and metadata | `directory-upload-bytes`; live transfer verification | `70-directory-upload-review`, `71-directory-upload-result` | PASS |
| Plain download, explicit replace, keep-both and preservation on failure | `download-default-plain-replace`, `download-keep-both`; download regression fixtures | `49`–`50`, `55`–`56` | PASS |
| Directory, ZIP and tar.gz downloads with independent recovered-byte checks | `directory-download-replace`, `download-zip-bytes`, `download-tgz-bytes` | `57`–`61`, `69`; archive verification output | PASS |
| Spaces, symlinks, hardlinks, empty dirs, corruption detection and BusyBox /bin | `scripts/test-transfer-live.sh --bin`; all `tests/test-transfer*.sh` | `transfer-live/results.txt`, fingerprint/verification tables | PASS |
| OIDC needed/continue/success/failure, helper URLs, cleanup and no-TTY exit | `tests/test-login-flow.sh`, `tests/test-login-cleanup.sh`; controlled-helper PTY checks | fixture logs; local cluster auth is certificate based | PASS (fixture PTY; certificate-auth cluster) |

## Reports, audit, publication and dependency regression

| Functionality | Current live/browser checks or fixture coverage | Evidence | Result |
|---|---|---|---|
| CLI text, CSV, TSV for resource and toolkit views | `view-*`, `csv-*`, `tsv-*`, `all-views` | `logs/`; generated raw tables | PASS |
| Combined snapshot, six standalone snapshots and selected-view snapshots | `snapshot-combined`, `snapshot-all`, `snapshot-selection` | `reports/`; HTML gallery | PASS |
| Full report bundle, live session history and offline session regeneration | `report-bundle`, `session-report`, `export-artifacts`, `html-real-data` | `45-html-menu`, `46-html-report-written`, `48-session-summary` | PASS |
| Combined report FMEA/Secrets additions, associated bundle worksheets and opt-out | extended report checks and browser tab checks | FMEA/Secrets tables, worksheet files; offline rebuild excludes live extras | PASS |
| HTML Overview, Pods, Nodes, Workloads, IP, Memory, IO, History, FMEA and Secrets tabs | `html-real-workloads`, `html-tab-*`, `html-history-charts` | browser screenshots for all ten live tabs | PASS |
| HTML search, sort, theme, time zone, CSV/JSON download and script errors | `html-search`, `html-sort`, `html-theme`, `html-timezone`, `html-csv-download`, `html-json-download`, `html-no-script-errors` | `browser-results.json`; download logs | PASS |
| Separate FMEA and Secrets HTML semantics, data and script safety | `html-fmea-*`, `html-secrets-*` | FMEA/Secrets browser captures | PASS |
| Audit show/filter, integrity and HTML/CSV export; action coverage | `audit-events`, `audit-grep`, `audit-verify`, `audit-export` | logs, audit HTML/CSV, chain result before any redaction | PASS |
| Full fixture regression after fixes | every `tests/*.sh`, bounded per-suite execution | fixture suite logs, exit statuses and final source hash | PASS |
| Changed functionality rerun on exact final installed source | installed/source SHA comparison, affected live scenarios and browser checks | final results hashes and run timestamps | PASS |
| Source/docs/gallery links, checksums and publication completeness | `scripts/validate-all.sh`, `scripts/validate-publication.py` | validation log; committed evidence | PASS |
| Commit, push, version tag, release assets and download checksums | exact remote commit/tag plus downloaded asset comparison | GitHub source commit/push; release assets not published | PASS (push; assets not published) |

## Final result

- Baseline installed-CLI run: 200/200 checks and 91 captures.
- 4.37 extension run: 103/103 checks and 29 captures, merged into the same run.
- Secrets map: 30/30 checks and 5 captures, including key-match and mismatch.
- Browser: 33/33 checks over all ten report tabs, FMEA, Secrets and downloads.
- Fixtures: 19/19 suites, including 22 rotated-log and 198 mode-switch checks.
- Installed and source SHA-256: `9f17258a0e73023b3046b13a934b26cc30bf755ec1b48aa7923446137e16fc44`.
- Rotated live read: one older kubelet file plus the current file, 103,840 lines
  and 11.1 MiB, with matches merged in timestamp order.
- Combined report used by the browser checks:
  `reports/kdash_namespace_report_kdash-local_kdash-e2e_20261120_004235.html`.
- Representative quick exports are under `reports/exports/`; the multi-megabyte
  full-log search dumps are identified by the extension checks and raw captures.

## Limits to record with final results

The local cluster has one visible node: displayed placement and metrics can be
tested, while real multi-node failover cannot. A missing metric remains unknown.
The local provisioner may omit measured volume usage. OIDC tests use controlled
helpers because the cluster authenticates with certificates. The live log read
did include one kubelet-rotated file from node `dev` (103,840 lines, 11.1 MiB,
current plus rotated); byte caps, gzip, denied access and incomplete reads are
covered by `tests/test-log-history.sh` fixtures. The generated two-day Secret
certificates correctly produce CRITICAL findings, so `--certs` exits 2 in that
check. Multi-megabyte full-log search exports are recorded in the check details
and raw terminal captures; only representative exports below 1 MiB are committed
to keep the repository manageable. Published text replaces the host operator identity with
`operator@validation-host`. The hash-chained audit log did not contain that
identity and is published unchanged; `audit-verify-before-redaction.txt` records
the chain result. Manual runbook recovery commands are printed and reviewed;
destructive recovery is outside this validation exercise.
