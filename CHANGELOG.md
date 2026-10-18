# Changelog

All notable changes to kdash are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), the project uses
[Semantic Versioning](https://semver.org/spec/v2.0.0.html), and the README keeps
the detailed per-release notes.

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
