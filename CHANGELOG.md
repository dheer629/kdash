# Changelog

All notable changes to kdash are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), the project uses
[Semantic Versioning](https://semver.org/spec/v2.0.0.html), and the README keeps
the detailed per-release notes.

## [4.19.2] - Unreleased

This is the current source version. A source commit does not publish a GitHub
Release or its download assets; the published 4.14.0 and older releases remain
available separately.

### Added
- `kdx` (`kdash -X`) and `kdsh [FILTER]` (`kdash -X --shell-picker`) commands beside
  the installed binary, plus shell integration and completion for the new options.
  `kdsh` and the fixed command palette's `shell [FILTER]` open the live shell-mode
  pod list; one matching pod attaches directly.
- A live pod picker with word search across pod/status/node, attention filtering,
  status/restart/resource sorting, numeric row jumps, resize handling and shortcuts
  into inspector panes or interactive actions.
- Runtime `X` toggles interactive mode, confirming before enabling it and auditing
  `INTERACTIVE_ON` / `INTERACTIVE_OFF`. `Q` exits from navigation screens.
- Container Bash identity panel and `kdswitch` / `kdquit` helpers; the panel survives
  clear and resize and shows the pod/container identity and resource values observed
  at attachment. The `sh` fallback prints connection information once.
- Local and container file browsers for multi-file/directory transfers, name
  filtering, file previews, path navigation, destination review and overwrite
  confirmation. Downloads offer ZIP, tar.gz or plain files in the launch directory
  (`KDASH_LAUNCH_DIR` overrides it); ZIP uses `zip` or optional `python3` on the host.
- Transfer progress and cancellation, partial-download cleanup, local archive
  checksums and upload verification by `du` size comparison with a filesystem
  tolerance. Typed-path `kubectl cp` remains the fallback if browsing is unavailable.
- Shared title bars and width-aware diagnostic tables for doctor, services,
  storage, Kubernetes Events and explanations; a session-close summary with
  context, namespace, duration and the retained report location.
- `scripts/build.sh --from-bundle` imports an updated authoritative bundle into
  the standalone CLI and source modules; `--check` verifies synchronization.

### Changed
- Installer shell shortcuts preserve occupied aliases/functions/commands, report
  skipped names and retain a user's `kdash` alias. Marked `kdx` / `kdsh` commands
  are managed with the matching installation and removed by uninstall.
- Container selection is refreshed for each pod and remembered per pod. Multiple
  attachable containers require confirmation unless `--container NAME` supplies
  an existing name explicitly.
- Browsed transfers use `kubectl exec` with a tar stream. Remote browser listings,
  previews and size checks also count as writes under the interactive guard.
- Source, build/release helpers and documentation are synchronized with 4.19.2;
  historical 4.12.0, 4.13.1 and 4.14.0 screenshots retain their recorded versions.

### Fixed
- Status filters now use the model's effective status, including Terminating,
  Evicted, waiting reasons and Running-but-NotReady. Workload filters resolve
  Deployment/CronJob ownership, accept `Kind/name`, and preserve regex escapes.
- Filter changes rebuild the retained model immediately; only label selectors
  force a new specification read. Headers and exports show all active filters,
  and workload-only selection keeps matching workloads with zero pods.
- Interactive streams remove `--request-timeout` as well as the read-command
  timeout, preventing a shell or transfer from ending after a few seconds.
- The kubectl guard runs through Bash so a `noexec` temporary directory does not
  prevent guarded reads. Worker cancellation also stops child processes before
  temporary directories are removed.

## [4.14.0] - 2026-10-29

### Added
- Opt-in interactive attachments: `S` opens a shell in a container (`bash` when the image
  has it, else `sh`), `U` uploads a file into a container, `D` downloads a file out of
  one. They work from the pod list (pick a pod, then its container when it has several),
  from the inspector (the pod and container on screen) and from the container picker.
  Enabled with `--allow-interactive` / `-X` / `KDASH_ALLOW_INTERACTIVE=1`.
- The kubectl guard gained exactly two exceptions: `exec` and `cp`, only while
  interactive mode is on, running without the 12 s command cap, recorded as
  `WRITE ...` and counted as `writes` in the `KUBECTL` audit summary. While the mode is
  off both are refused with exit 126 and a hint, and the attempt is audited as
  `INTERACTIVE_BLOCKED`.
- New audit events for an attachment: `EXEC`, `EXEC_END`, `CP_UP`, `CP_DOWN`, `CP_END`
  with pod, container, direction, paths (credential-looking paths masked), bytes and exit
  code. Shell output and copied files never enter the model, a report, a bundle, a session
  or an export.
- `tests/test-interactive.sh`: the guard on and off, the exact kubectl argv of a shell, an
  upload and a download, write accounting, the timeout difference between a read and an
  attachment, the default remote path, the overwrite prompt, credential-path masking,
  relative-path and control-byte rejection, and the published flag, keys and help.
- README section "Shell and file copy (opt-in)": the exact commands kdash runs and the
  caveats (`pods/exec`, `tar` for `cp`, distroless images, what is audited).
- `?` help, the inspector key map, the footers and the status bar advertise the three keys.

### Changed
- The disclaimer now says that kdash only reads the cluster unless interactive mode is
  enabled explicitly, and that an attachment runs with the user's rights and is not
  read-only.

## [4.13.1] - 2026-10-29

### Fixed
- The installer's closing summary listed only views 1-7. It now names every key,
  including 8 SERVICES, 9 STORAGE, `E` Events, `!` explanations, `Enter`/`i` inspect,
  `:` command palette and `F` filters.

### Added
- Versioned downloads in the README: every release with its own immutable GitHub
  Release, per-version direct links (`kdash`, `kdash-bundle.sh`, `kdash-<version>.tar.gz`,
  `SHA256SUMS`) and a one-command install of one exact version.
- Fresh 4.13.1 screenshots: 22 saved live screens of the new views and the inspector in
  `samples/cli_413/`, with the raw `.ansi` / `.txt` captures and manifest in
  `artifacts/feature-screens-20261029-151233/`, checksummed in
  `samples/cli_413/SHA256SUMS`. `scripts/validate-all.sh` now verifies that set and its
  manifest; `scripts/update-checksums.sh` regenerates both.
- The 4.13.1 captures were redacted with `scripts/redact-run.sh` (context, personal
  paths, host and the other tenants of that shared development cluster) and re-rendered
  so text and pixels agree; the mapping stays private, as in `samples/README.md`.

## [4.13.0] - 2026-10-29

### Added
- `kdash --doctor` and a `doctor` view: read-only checks of the kubeconfig, context,
  endpoint, pods, nodes, services, EndpointSlices, PVCs, Events and the Metrics API.
  Failures are classified (RBAC, authentication, TLS, unreachable, timeout) and a missing
  Metrics API is reported as a capability gap, not as an outage.
- Pod inspector (`Enter` / `i`, `--inspect POD`): summary, containers, Events, `describe`
  and opt-in, bounded current / previous logs. Logs never reach reports or sessions.
- Inspector find and drill-down: `/` finds in the current pane (context kept, matches
  highlighted, count in the header), `n`/`N` jump between matches, `&` keeps only the
  matching lines, `L` filters by log level, `f` follows a log pane, and `w` exports the
  pane you are looking at to `$KDASH_REPORT_DIR/inspector/`.
- Container picker (`c`): every container including init/debug with readiness, restarts,
  state, last exit reason and image; `1`-`9` opens one directly, `l`/`p` opens its logs.
  The header shows the selected container's live state.
- Command palette (`:`) with fixed handlers, and structured pod filters (`F`,
  `--selector`, `--status`, `--node`, `--workload`, `--unhealthy`).
- Kubernetes Events (`E`, `--events`) and evidence-backed explanations (`!`, `--explain`):
  observed fact, possible explanation and the next read-only check; coverage gaps are
  shown as unknown.
- Views **8 SERVICES** (Ingress -> Service -> EndpointSlice -> ready pods) and
  **9 STORAGE** (Pod -> PVC -> PV -> StorageClass, measured usage only when a metrics
  source exists).
- `src/` modules, `scripts/build.sh` (assembles `kdash` and the installer),
  `scripts/package-release.sh` and `.github/workflows/release.yml` (versioned downloads),
  `RELEASES.md`.
- Tests: `test-runtime.sh`, `test-events.sh`, `test-health.sh`, `test-inspector.sh`, all
  fixture-only (no cluster, no kubeconfig).

### Changed
- Cluster reads run in a background worker; a snapshot is adopted only when complete, so a
  slow API call no longer blocks the keyboard. Failed reads keep the last good inventory,
  back off and recover automatically; the header shows data age and `STALE`.
- The tab bar lists the newer views too (`8 SVCS  9 STOR  E EVENTS  ! WHY`, full names from
  200 columns) and the panel views share the standard header and status bar, so every view
  shows the tab bar, the clock, the health line and the `AUDITED` marker. The author credit
  yields to the tab bar instead of wrapping the header line, and the status bar hint reads
  `1-9 view`.
- A first background read now reports `collecting` instead of `not collected`, and an
  invalidated spec shows `spec re-reading` instead of seconds since the epoch.
- `scripts/validate-all.sh` runs every test under `tests/`, counts checksum entries from
  the files themselves and compares against the matching remote branch.

### Fixed
- `-A` / `--all-namespaces` was placed before the kubectl verb and was rejected; it now
  follows the resource.
- A successful read that returned no pods kept the previous pods on screen.
- Slow collection could block key handling.
- Service selectors and PVC access modes no longer print a trailing comma.
- `-v <unknown>` now lists every view in its error message.

## [Unreleased]

### Added
- `docs/` folder: the DevOps user guide and the explainer that describes how to
  read each view and its evidence.
- Open-source project files: `LICENSE`, `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`,
  `SECURITY.md`, `CHANGELOG.md`, issue and pull-request templates, `CODEOWNERS`,
  a CI workflow, `.editorconfig` and `.gitignore`.
- `scripts/redact-run.sh` and `scripts/redact-history.sh`: replace
  environment-specific names (cluster context, namespaces, product and site
  wording, operator, host and home paths) across a run, the samples and the
  documentation, and across already-committed history, using a private mapping
  that is never committed.
- `scripts/capture-feature-screens.sh`, `scripts/make-sample-gallery.ps1`,
  `scripts/collect-html-samples.ps1`, `scripts/render-cli-samples.ps1`,
  `scripts/compress-raw-captures.sh` and `scripts/update-checksums.sh`: capture
  the screens, build the published samples and keep the checksums honest.
- `scripts/wsl-validation.sh` and `scripts/wsl-env-probe.sh`: one command that
  inventories the host, uninstalls, verifies the removal, reinstalls, runs kdash
  live for N minutes per namespace, captures views 1-7, exports the HTML reports
  and writes a run inventory.
- `scripts/validate-all.sh`: one command that checks everything the repository
  publishes - Bash syntax, the embedded installer payload, the uninstall tests,
  every checksum, the recorded run and its captures, the samples, the absence of
  environment, product, site or personal names and of credentials, the README
  references and the git state. CI runs the same script.
- `artifacts/` and `samples/`: a complete, redacted validation run with its logs,
  raw captures, recorded sessions, reports and audit trail, plus the screenshots
  published in the README.

### Changed
- The PowerShell helpers no longer hard-code a Python path: they look for an
  interpreter that has `pyte` and `Pillow`, or take `-Python PATH`.
- `.gitattributes` pins the Bash entry points to LF so a checkout on Windows
  cannot break execution under WSL.

### Fixed
- `scripts/redact-run.sh` did not escape replacement text, so a mapping whose
  replacement contained `/` produced an invalid rule set that silently changed
  nothing; the rules are now validated before anything is touched.
- The same script could replace a gzip-compressed capture with an empty archive
  when the rewrite failed; a capture is now only replaced when the rewrite
  produced content.
- `scripts/redact-history.sh` gained `--detect`, so a mapping that also rewrites
  text kept on purpose (an author credit, for example) no longer marks the tip
  commit as pre-redaction and strips its screenshots.

## [4.12.0]

### Added
- View **7 ALERTS**: one live page with the verdict (CRITICAL / WARNING /
  HEALTHY), a health line per section, and every critical and warning signal with
  its age, live value, trend and the `kubectl` action to run under it, followed by
  the live top consumers and recent events.

## [4.11.0]

### Added
- Session recorder: a live run keeps namespace totals, per-node and per-pod
  samples and change events (added / removed / status / restarts / OOMKilled /
  rescheduled / OOM risk / node state) on disk.
- Namespace report: one HTML file with every tab plus the recorded history.

## [4.10.0]

### Added
- View **6 NET & DISK IO**: network in / out and disk read / write and IOPS over
  time, per worker node and per pod, with this namespace's share of each node.

## [4.9.0]

### Added
- `--report` evidence bundle (text, TSV, CSV and a combined HTML dashboard).
- `--snapshot [all|1-6|names]`: one standalone HTML report per view, plus
  `index.html`.

## [4.8.0]

### Added
- Colours that stay readable on light and dark terminals, and glyph sets that
  survive PuTTY and MobaXterm fonts.

## [4.7.0]

### Added
- Per-pod detail lines: node, pool, pod IP, owning workload, QoS class, status,
  last exit reason and container waiting reasons.

## [4.6.0]

### Added
- Filter (`/`), pan (`h`/`l`), sort cycling (`s`/`o`) and a pinned header and
  footer with a scrolling body.

## [4.5.0]

### Added
- HTML export of the view on screen (`e`, then `c`) with filter, sort and per
  table CSV.

## [4.4.0]

### Added
- Views **4 IP POOL** and **5 MEMORY** (live charts, OOM risk, growth forecast).

## [4.3.0]

### Added
- View **3 WORKLOADS**: replicas, rollout, per-pod placement and the
  pods-per-node matrix that shows HA risk.

## [4.2.0]

### Added
- View **2 NODE POOLS** redesigned: namespace and cluster summary, comparison
  graphs per pool, every node listed, `PODS ns/all` and `clReq%` columns.

## [4.1.0]

### Added
- Session history and the all-tabs namespace report (`x`), plus
  `--session-report` to rebuild it after kdash exits.

## [4.0.0]

### Added
- The read-only `kubectl` wrapper, the audit trail with its hash chain, the
  standalone uninstaller, `-v/--view`, `-o tsv|csv`, and the installer that
  replaces older copies and verifies a login shell.
