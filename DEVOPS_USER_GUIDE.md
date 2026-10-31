# kdash DevOps user guide

This guide describes the kdash 4.19.2 source in this repository. kdash is a Bash terminal dashboard that reads Kubernetes objects and metrics through `kubectl`. Its reports preserve observations so an operator can investigate and decide what to do next. Container shells and file transfers are explicit exceptions to the default read-only guard (`-X` / `--allow-interactive`, `--shell-picker`, or the `X` key). They run with your permissions, are counted as writes and keep their output out of automatic reports. They can change files and application state inside a container.

The current source can be installed with `git clone https://github.com/dheer629/kdash.git`,
`cd kdash`, `sha256sum -c SHA256SUMS`, then `bash kdash-bundle.sh`.
Run `exec bash -l` to load shell shortcuts and completion. Versioned downloads in
[RELEASES.md](RELEASES.md) describe already published releases; committing 4.19.2 source
does not itself publish new release assets.

## What the recorded run actually produced

The captured validation run below used 4.12.0; the later feature galleries used
4.13.1 and 4.14.0. They remain evidence of those versions and do not validate the
4.19.2 terminal layout or interactive browser against a live cluster.

The following evidence table describes the exercise on 2026-10-18 in the WSL Ubuntu distribution as user `demo`, against the local vcluster context `devops-admin@local-cluster` (one visible node, `dev`, v1.30.4), with kdash 4.12.0 whose sha256 is `2213bf63f5a6c9c21be49e084fea1cce77e5b9e223acfed6b1e85c7972bd7dc0` both installed and in the repository. The recorded run is `artifacts/wsl-validation-20261018-134816/`; `artifacts/latest-run.txt` names it.

| Step | Measured result | Evidence |
|---|---|---|
| Inventory | Ubuntu 24.04 on WSL2, bash 5.2.21, tmux 3.4, kubectl client v1.30.4, gawk 5.2.1, 15 namespaces | `logs/01-preinstall.log` |
| Uninstall | `.bashrc` block removed (backup written), completion, shell integration and `~/.local/bin/kdash` removed; a login shell no longer finds kdash | `logs/02-uninstall-preview.log`, `logs/03-uninstall.log`, `logs/04-uninstall-verification.log` |
| Data kept by the uninstall | configuration, disclaimer acceptance, reports, sessions, audit log (`28469` bytes, 101 events, chain intact), startup backups | `logs/04-uninstall-verification.log` |
| Reinstall | installer self-check passed, `--check` OK, a fresh login shell runs 4.12.0, installed sha256 equals the repository file's | `logs/05-install.log`, `logs/06-install-verification.log` |
| Live run | `orders-service-e2e` (27 pods), `ml-service-prod` (4 pods), `gitops-core` (7 pods) each ran live for 329 measured seconds and exited 0 | `run-metadata.json`, `RUN_INVENTORY.md` |
| CLI evidence | views 1-7 captured for every namespace (21 screens, 50x170 each) as ANSI plus plain text | `<namespace>/cli/0N-*.ansi` and `.txt` |
| HTML evidence | 10 HTML reports per namespace: the live all-tabs namespace report, six one-shot view snapshots plus index, the combined report, and the audit report with CSV | `<namespace>/reports/`, `<namespace>/audit/` |
| Session records | one recorded session per namespace with 5-second history samples and the model tables | `<namespace>/reports/sessions/` |

`artifacts/` holds that raw evidence, `samples/cli_419/` holds the 55 screens of the **current 4.19.2 interface and what it does** (screens 01-31: all nine views, `E` events, `!` explanations, the command palette, the doctor, the inspector with find and only-matches, the `?` help, two 100-column layouts and the opt-in interactive mode; screens 32-55: the dashboard controls, the HTML/report/bundle/audit exports and the one-shot modes) with their raw captures in `artifacts/view-screens-20261031-051739/` and `artifacts/operation-screens-20261031-062953/`, `samples/html419/` holds the HTML those runs produced with browser screenshots of its pages, `samples/cli/` holds rendered screenshots of the seven 4.12.0 CLI views per namespace, `samples/cli_413/` holds the 22 screens of the 4.13.1 views and inspector (services, storage, events, explanations, doctor, find, container picker) with their raw captures in `artifacts/feature-screens-*`, and `samples/html/` holds the HTML reports with checksums. `samples/cli_419/` follows this source; the other galleries support the historical observations.

## 1. Open the correct environment

In PowerShell:

```powershell
wsl --list --verbose
wsl -d Ubuntu
```

In Ubuntu WSL, enter this checkout:

```bash
cd '/workspace/kdash'
```

The runtime needs Bash 4 or newer, `kubectl`, `awk`, and coreutils. The dashboard itself does not require Python or `jq`. A direct Prometheus URL additionally needs `curl`. Metrics, network counters, and cluster-wide comparisons depend on APIs and permissions, not just installed commands.

```bash
bash --version | head -n 1
command -v kubectl awk sha256sum
kubectl version --client
kubectl config get-contexts
```

Inspect context names without dumping credentials or the full kubeconfig. Use an explicit context in commands instead of relying on whichever context another tool last selected:

```bash
ctx='devops-admin@local-cluster'
ns='orders-service-e2e'
kubectl --context "$ctx" get namespaces
kubectl --context "$ctx" -n "$ns" get pods -o wide
kubectl --context "$ctx" -n "$ns" top pods
```

A vcluster only exposes the nodes, objects, metrics, and proxy endpoints configured for that virtual cluster. Its node and capacity views should be interpreted within that visibility; they are not automatically a complete account of the underlying host cluster.

## 2. Uninstall an existing copy, preserve evidence, then install

Find how the current shell resolves the command and preview the selected installation:

```bash
type -a kdash || true
bash kdash-uninstall.sh --dry-run
```

The default non-root prefix is `~/.local/bin`. For an installation in a different prefix, pass the same `--prefix DIR` to both removal and installation. A separate system installation in `/usr/local/bin` belongs to the root install path and is not removed by the default user uninstall.

For a normal user reinstall, save the command output and preserve the exit status of commands piped through `tee`:

```bash
set -o pipefail
mkdir -p artifacts/reinstall-logs
bash kdash-uninstall.sh --dry-run 2>&1 | tee artifacts/reinstall-logs/uninstall-preview.log
bash kdash-uninstall.sh 2>&1 | tee artifacts/reinstall-logs/uninstall.log
bash kdash-bundle.sh 2>&1 | tee artifacts/reinstall-logs/install.log
bash kdash-bundle.sh --check 2>&1 | tee artifacts/reinstall-logs/install-check.log
bash -lc 'type -a kdash; kdash --version'
```

Run the installer only after the uninstall exits successfully. The uninstaller removes the selected binary, its completion, and matching shell integration. It backs up shell startup files before removing setup blocks. It retains configuration, disclaimer acceptance, reports, recorded sessions, audit logs, old-binary backups, and startup backups. Existing dashboard processes continue until they exit. Keep those prior records in their original location when collecting evidence; copy only the relevant records into the run artifacts.

Open a fresh Ubuntu terminal, or run `exec bash -l`, after reinstalling. A previously loaded function, alias, or command cache can otherwise make the shell report an old command. The installer check uses a fresh login shell to verify resolution. `--no-shell` installs or removes the binary without replacing the current user's shell setup; it is useful for managed environments that maintain their own startup files.

The separate test suite exercises uninstall behavior in temporary home directories and uses a stub `kubectl`:

```bash
bash tests/test-uninstall.sh
```

### Run the whole cycle automatically (what produced artifacts/)

`scripts/wsl-validation.sh` performs steps 1-5 of this guide in one command on WSL Ubuntu: it inventories the host and cluster, previews and runs the uninstall, verifies that the binary is gone and the data survived, reinstalls and verifies, then runs kdash live in one tmux session per namespace for the requested number of minutes while capturing views 1-7, exporting the all-tabs HTML with `x`, quitting with `q`, and finally writing the session rebuild, the one-shot snapshots, the evidence bundle and the audit report for each namespace.

```bash
cd '/workspace/kdash'
bash scripts/wsl-env-probe.sh                    # read-only inventory, nothing changes
bash scripts/wsl-validation.sh --minutes 5 \
  --namespaces "orders-service-e2e ml-service-prod gitops-core"
```

It writes `artifacts/wsl-validation-<timestamp>/` with `logs/` (one log per step), `run.log`, `<namespace>/{launch.sh,terminal.raw.log,cli/,reports/,audit/}`, `controller-actions.json`, `run-metadata.json`, `RUN_INVENTORY.md` and `status.txt` (`RUNNING`, `DONE`, `DONE_WITH_FAILURES` or `ABORTED`). It is safe to re-run and never modifies the checkout. Long runs should be detached, because a terminal that closes stops a foreground process:

```bash
setsid nohup timeout 2700 bash scripts/wsl-validation.sh >/tmp/kdash-validation.log 2>&1 </dev/null &
```

Two behaviours of this version are worth knowing before you script it yourself:

* `--accept-disclaimer` only records the acceptance and then continues into the live dashboard, so it does not exit on its own. For unattended runs, accept through `KDASH_ACCEPT_DISCLAIMER=1` together with a mode that terminates (`--once`, `--snapshot`, `--report`), or accept once interactively.
* a detached tmux server keeps the geometry and configuration it was started with, so a run that needs 170x50 panes must start its own server. The script ends a leftover server and waits for it to disappear first; otherwise captures include a status line and the wrong height.

On the Windows side, two helper scripts turn the saved evidence into the published samples:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/render-cli-samples.ps1  -RunDirectory artifacts/<run-id>
powershell -ExecutionPolicy Bypass -File scripts/collect-html-samples.ps1 -RunDirectory artifacts/<run-id> -Screenshot
```

The first replays every saved ANSI capture into a PNG under `samples/cli/<namespace>/` (it needs Python with `pyte` and `Pillow`; the images are renders of the captured screen, not operating-system window screenshots). The second copies the HTML reports byte for byte into `samples/html/<namespace>/`, writes `samples/html/SHA256SUMS`, and optionally takes real browser screenshots of the main pages with Microsoft Edge in headless mode.

### Publishing a run without your environment names

`scripts/redact-run.sh` replaces environment-specific names - the kubeconfig
context, the namespaces and the pod prefixes derived from them - across a run, its
samples and the documentation, using a private mapping file that stays outside the
repository:

```bash
printf 'old-context\tnew-context\nold-namespace\tnew-namespace\n' > /tmp/map.tsv
bash scripts/redact-run.sh --check --map /tmp/map.tsv artifacts samples README.md
bash scripts/redact-run.sh         --map /tmp/map.tsv artifacts samples README.md
```

It rewrites text files, gzip-compressed captures, and the names of files and
directories. Images carry names as pixels, so re-render them afterwards
(`render-cli-samples.ps1`, `collect-html-samples.ps1`, `make-sample-gallery.ps1`),
refresh the raw-capture hash manifest and regenerate the checksums.

Two things to state when publishing a redacted run:

* an audit hash chain no longer verifies once its bytes change, so record the
  verification result **before** redacting (the run's own `logs/13-audit-*.log`
  does that) and say that the published copies are redacted;
* the script rewrites text files, gzip captures and file and directory names, but
  it cannot rewrite an image: re-render the screenshots from the redacted captures
  afterwards. Anything not in your mapping stays as it is - the standard cluster
  namespaces, the node name, addresses and measured values - so decide explicitly
  whether those may be published.

## 3. Start a namespace session

From a fresh Ubuntu shell:

```bash
ctx='devops-admin@local-cluster'
ns='orders-service-e2e'
export TZ=Asia/Calcutta
export KDASH_REPORT_DIR="$PWD/samples/$ns"
export KDASH_SAMPLE_EVERY=5
mkdir -p "$KDASH_REPORT_DIR"
kdash -c "$ctx" -n "$ns" -i 5 -R 30
```

Read and accept the disclaimer on the first interactive run. For an unattended run after accepting its terms, `--accept-disclaimer` supplies that acceptance explicitly. `-i 5` polls usage every five seconds; `-R 30` reloads object specifications every thirty seconds. `KDASH_SAMPLE_EVERY=5` records history at approximately five-second intervals. API latency and collection work can make the actual cadence longer.

Keep the session running for at least five minutes of recorded observations. Visit views `1` through `7`; press `x` near the end to export history, then `q` to exit cleanly. Confirm the first and last sample timestamps in the saved session rather than assuming a five-minute process timeout guarantees five minutes of samples.

Repeat with `ns='ml-service-prod'` and `ns='gitops-core'`, or run them in separate terminals using a separate `KDASH_REPORT_DIR` for each. Separate sessions make the histories easy to attribute. Pressing `n` changes namespace interactively and begins a new history session for the selected namespace.

**Version note:** kdash 4.12.0 had a kubectl argument-order defect on the all-namespaces `-A` route, so use `-n NAME` there. It is fixed in 4.13.0 (`kdash -A` now runs `get pods --all-namespaces`). On any version, do not interpret a failed `-A` command as evidence that every namespace is empty or inaccessible; run `kdash --doctor` first. Some older README/help examples also say that `--snapshot all` generates five files; the implementation now generates six standalone view reports.

## 4. Read the CLI views

| Key / `-v` name | What to inspect | How to interpret it |
|---|---|---|
| `1` / `pods` | Pod/container status, readiness, restarts, measured CPU and memory, requests and limits | Use container rows to identify which part of a pod is consuming resources. A pod total can hide one container near its limit. A restart count is cumulative; compare successive observations and events for recent change. |
| `2` / `nodes` | Namespace usage/request share per pool and node, allocatable capacity, other namespace usage, node state | Namespace usage and whole-node usage have different denominators. Read the legend and data-coverage notes. Auto zoom can enlarge a small bar visually while its percentage remains unchanged; `Z` selects true scale. |
| `3` / `workloads` | Desired/ready replicas, rollout state, pod placement and spread | `HA_RISK` flags two or more replicas concentrated on one node. `SKEWED` marks uneven placement. These signals need context about node count, scheduling constraints, and intended topology. A local single-node cluster cannot demonstrate multi-node resilience. |
| `4` / `ip` | Pod IPs, service addresses, per-node/subnet distribution, no-IP, host-network and duplicate signals | Pending pods may legitimately have no IP yet. Host-network pods can share a node address. Investigate duplicates in context before concluding that the network is broken. |
| `5` / `mem` | Namespace CPU/memory charts, request/limit lines, pod risk, memory by node/workload, OOMKilled history, growth forecast | A past OOMKilled observation is historical evidence, not proof of a current OOM. Forecasts extrapolate recent samples; they are not a guarantee that a pod will hit its limit. Five minutes is a short diagnostic window. |
| `6` / `io` | Network ingress/egress, disk read/write and IOPS, node totals and namespace/pod shares | Rates need two counter samples. The source is Prometheus/cAdvisor, not metrics-server. A missing source or denied proxy is unavailable data, not zero traffic. A pod's large share of very small traffic may be operationally harmless. |
| `7` / `alerts` | Overall verdict, section health, active/cleared alerts, age, trend and suggested investigation commands | Start here for triage, then use the detailed views. Warnings include missing limits and topology concentration. `HEALTHY` means no rule fired on visible data; it is not a complete service health test. Suggested commands are displayed for an operator to inspect and run. |
| `8` / `services` | Ingress, Service, EndpointSlice and pod relationships | Selectors and readiness are configuration evidence; they do not prove DNS or end-to-end connectivity. Denied reads give unknown coverage. |
| `9` / `storage` | PVC, PV, StorageClass, mounts and storage Events | Declared capacity is allocation. Measured usage is available only when the metrics source supplies it. |
| `E` / `events`, `!` / `explain` | Kubernetes Events and possible explanations with next checks | Events can expire or be incomplete; a hypothesis is not a proven cause. |

Use `kdash --doctor` for read-only connection and capability checks. Services,
storage, Events, explanations and doctor use tables fitted to the terminal width.
Their status colours distinguish failures, warnings, unknown coverage and healthy
observations. The shared title bar shows context, namespace and the current mode.

Structured filters (`F` or `--selector`, `--status`, `--node`, `--workload`,
`--unhealthy`) are AND-combined with the pod regex. Status uses the effective value
shown in the table: `Terminating`, `Evicted`, waiting reasons and `NotReady` all
match. Node is exact, including `(unscheduled)`. Workload accepts an extended regex
against a name or `Kind/name`, with Deployment/CronJob ownership resolved from pod
owners. A workload-only filter can still show a matching workload scaled to zero.
`--unhealthy` excludes ready Running and successfully completed pods. Labels require
a fresh API read; other filter changes reuse the retained inventory and rebuild the
model. Active filter descriptions appear in headers and generated reports.

### Requests, limits, usage, and missing values

Requests are declared resources used for scheduling. Limits are configured caps. Usage is a measurement obtained through the metrics API. They answer different questions and can legitimately differ.

CPU values such as `250m` mean 250 millicores, or 0.25 of a CPU core. Memory uses binary units such as MiB and GiB; exported numeric memory tables use MiB. A percentage labelled `%LIM` divides usage by the configured limit. A percentage labelled `%al` divides namespace usage by node or pool allocatable capacity. Compare matching labels and units.

`-`, an empty exported field, or a coverage warning can mean unknown, unset, not sampled, or not permitted. Do not replace these with zero. A missing memory limit means that this limit-based risk calculation is unavailable; it does not mean unlimited physical memory is available. High CPU relative to its limit indicates potential throttling pressure; it does not measure throttling events directly. Memory near its limit signals risk, while OOMKilled status or events provide stronger evidence of a kill.

## 5. Keyboard reference

| Key | Action |
|---|---|
| `1`-`9`, `E`, `!`, `Tab` | Choose or cycle the CLI view |
| `?` | Explain the current view |
| `j` / `k`, arrows; `space` / `b`; `g` / `G` | Scroll, page down/up, jump to top/bottom |
| `h` / `l`, left/right arrows; `0` | Pan horizontally; return to the first column |
| `s`, `o` | Cycle sort key; reverse sort order |
| `/` | Change the pod-name regular expression; empty restores all matches |
| `F`, `:` | Structured filters; fixed-command palette (`shell [FILTER]` opens shell mode) |
| `Enter`, `i` | Live pod list and inspector: summary, containers, Events, describe, bounded logs |
| `p`, `d`, `w` | Pod totals only, detail lines, grouped/flat pod listing |
| `r`, `n` | Re-read specifications; choose another namespace |
| `a`, `Z` | In Node Pools: all/hosting nodes; auto zoom/true scale |
| `P`, `+`, `-` | Pause/resume data refresh; adjust the poll interval |
| `T`, `z` | Cycle theme; select chart time window |
| `x`, `e` | Export an all-tabs namespace report; open the export menu |
| `X` | Enable interactive mode after `y` confirmation, or disable it immediately |
| `S`, `U`, `D` | In interactive mode: shell, upload, download |
| `q`, `Q` | `q` quits the dashboard or returns from a picker; `Q` quits kdash from navigation screens and finalizes session/audit records |

Screenshots capture only the visible viewport. For long tables, scroll for extra captures or use the complete text/HTML export. The report and raw tables provide the evidence beyond the terminal frame.

## 6. Export HTML, text, tables, and history

Use the same `ctx`, `ns`, `KDASH_REPORT_DIR`, and time zone as the live session. One namespace per report directory prevents `latest` from selecting a different namespace's newest session.

```bash
# Six standalone HTML reports: Pods, Nodes, Workloads, IP, Memory, IO.
kdash -c "$ctx" -n "$ns" --io-wait 20 --snapshot all

# CLI view 7 is represented by the namespace HTML overview/action table.
kdash -c "$ctx" -n "$ns" --snapshot 7

# All-tabs namespace HTML. During a live run it can include its history.
kdash -c "$ctx" -n "$ns" --snapshot

# Rebuild from the most recent recorded session after the live run exits.
kdash --session-report latest

# For reproducible selection, substitute the exact recorded session path.
kdash --session-report /absolute/path/to/recorded/session

# Combined HTML and text/TSV/CSV evidence bundle.
kdash -c "$ctx" -n "$ns" --io-wait 20 --report "$KDASH_REPORT_DIR/bundle"

# A plain text frame or an alert table suitable for a ticket.
kdash -c "$ctx" -n "$ns" -v pods --once -N > "$KDASH_REPORT_DIR/pods.txt"
kdash -c "$ctx" -n "$ns" -v alerts --once -o csv > "$KDASH_REPORT_DIR/alerts.csv"
```

`--snapshot all` writes views 1-6 plus an index; it does not create a seventh standalone Alerts page. `--snapshot 7` writes the namespace report whose Overview contains the summary and action table. In the all-tabs HTML, the numbering is **0 Overview, 1-6 detailed views, 7 History**. HTML tab 7 is therefore different from CLI key 7. The all-tabs report is self-contained and can be opened locally; its tables offer search, sorting, CSV downloads, JSON export, theme selection, and time-zone controls.

A one-shot export without a recorded session cannot create a five-minute history. Prefer the exact session directory when rebuilding evidence after multiple runs. A session report loads saved `meta.env` and model files; treat session folders as trusted input from this utility, and do not execute reports from unknown session folders.

Live sessions are stored beneath `$KDASH_REPORT_DIR/sessions/`. The main files are `ns.tsv` (namespace totals), `nodes.tsv`, `pods.tsv`, `events.tsv`, and the latest saved model. The default history sample period is 15 seconds and the default retention is 30 sessions. This exercise uses five-second sampling. Retained histories can be compacted when the configured size limit is exceeded.

### Where each output belongs

```text
artifacts/wsl-validation-<run-id>/
  logs/01-preinstall.log ... 14-audit-report-<ns>.log   one log per step, exit status included
  run.log  status.txt  run-metadata.json  controller-actions.json  RUN_INVENTORY.md
  <namespace>/
    launch.sh              the exact command and environment that ran kdash
    terminal.raw.log       raw tmux pane output of the whole live run
    started.iso/ended.iso  wall-clock start and end
    started.epoch/ended.epoch/exit-status.txt   measured duration and kdash exit code
    cli/01-pods.{ansi,txt} ... 07-alerts.{ansi,txt}   views 1-7 as saved screens and text
    reports/               namespace report, snapshots, evidence bundle, sessions/
    audit/                 audit_YYYYMM.log (+ CSV and HTML audit export)
samples/
  cli/<namespace>/01-pods.png ... 07-alerts.png   rendered screenshots of views 1-7 (4.12.0 run)
  cli_419/01-pods.png ... 31-upload-prompt.png    the current 4.19.2 interface: every view,
                                                  the palette, doctor, the inspector, the
                                                  help, narrow layouts and the opt-in
                                                  interactive mode, from
                                                  artifacts/view-screens-*/raw/*.ansi
  cli_413/01-pods.png ... 22-services-100col.png  the 4.13.1 views and the inspector, from
                                                  artifacts/feature-screens-*/raw/*.ansi
  html/<namespace>/       the HTML reports, byte for byte, plus screenshots/ and SHA256SUMS
  <historical images>     earlier samples kept from the repository history
```

Use `artifacts/` for the raw evidence and `samples/` for what you publish. Pair every screenshot with its context, namespace, view number, capture time and the underlying text or session file. These are operational samples from one observation window, not fixed benchmark results.

## 7. Follow a read-only triage workflow

Check view `7`, then inspect the relevant detailed view. Confirm the observation using an explicit context and namespace:

```bash
kubectl --context "$ctx" -n "$ns" get pods -o wide
kubectl --context "$ctx" -n "$ns" get events --sort-by=.metadata.creationTimestamp
kubectl --context "$ctx" -n "$ns" get deployment,statefulset,daemonset
kubectl --context "$ctx" -n "$ns" top pods --containers
```

For a specific affected pod, replace the example name and inspect the evidence:

```bash
pod='replace-with-pod-name'
kubectl --context "$ctx" -n "$ns" describe pod "$pod"
kubectl --context "$ctx" -n "$ns" logs "$pod" --all-containers --tail=100
kubectl --context "$ctx" -n "$ns" logs "$pod" --all-containers --previous --tail=100
```

Previous-container logs may not exist. Application logs may contain sensitive data; inspect locally and include only relevant reviewed excerpts in tickets or shared artifacts. Compare restart changes, readiness, events, measured usage, and rollout state before deciding whether an alert requires a change. Save the report before making any separately approved operational changes.

## 8. Audit evidence

The utility audits run start/end, the operator and context, namespace changes, view and export actions, alerts, failures, and a summary of kubectl calls. Its kubectl wrapper refuses mutation verbs, with `exec` / `cp` allowed only in explicit interactive mode and counted as writes. This is utility activity logging; it is not a replacement for Kubernetes API server auditing or application logs.

```bash
kdash --about
kdash --audit 100
kdash --audit-grep 'NS_SWITCH|REPORT|END'
kdash --audit-verify
kdash --audit-report "$KDASH_REPORT_DIR/audit-export"
journalctl -t kdash --since today
```

By default the local log is `$KDASH_REPORT_DIR/audit/audit_YYYYMM.log`, unless `KDASH_AUDIT_DIR` is set separately. The central copy uses `/var/log/kdash` only if available and writable. Syslog uses `logger -t kdash`; successful emission does not guarantee a persistent journal exists in every WSL distribution. Record unavailable sources as unavailable.

Logs are hash-chained. `--audit-verify` detects broken links in the available file; removal of the file's trailing records cannot be detected from that file alone. Verify original files before preparing redacted copies. Redaction changes bytes and invalidates the original chain, so label such copies and retain the original verification result with the private source. Exported reports have hashes recorded in the audit trail.

## 9. Troubleshooting

| Symptom | Next check |
|---|---|
| Wrong version after reinstall | Run `type -a kdash`, open a new login shell, then run `bash kdash-bundle.sh --check`. Look for another prefix or a shell alias. |
| Cannot connect to the vcluster | Run `kubectl --context "$ctx" get namespaces`. Check that the existing local vcluster connection and credentials are valid. kdash does not create or reconnect a vcluster. |
| Usage is `-` | Try `kubectl --context "$ctx" -n "$ns" top pods`. Check metrics-server availability and permissions. Structural requests/limits can remain visible without usage. |
| Nodes or whole-cluster comparison missing | Inspect coverage notes and `kubectl --context "$ctx" auth can-i list nodes`. `--no-cluster` can skip cluster-wide pod reads when deliberately limiting scope. |
| IO is missing | Wait for two samples; use `--io-wait 20` for one-shot reports. Check the stated source and proxy permission. `--prom-svc namespace/service:port` or `--prom-url URL` selects an existing source. Do not invent traffic values. |
| `-A` fails | On 4.12.0 use explicit `-n NAME` runs (known argument-order defect, fixed in 4.13.0). On the current source run `kdash --doctor`: check cluster-wide list RBAC and the reported connection failures. |
| Nothing loads, or the header says `STALE` | Run `kdash --doctor`. It separates an unreachable endpoint, TLS, expired credentials, RBAC and a missing Metrics API, and prints the next read-only check for each. kdash keeps the last good pods on screen and retries by itself. |
| CPU / memory show `-` | The Metrics API is not answering. This is a capability gap, not an outage: requests, limits, readiness, services, storage and Events are still read. `--doctor` reports it as `INFO metrics`. |
| A pod is failing and you want evidence | Select it with `Enter` / `i` (summary, containers, Events, describe, opt-in logs), or `kdash --explain POD -n NS`. Inside the inspector: `/` finds in the pane (`n`/`N` jump between matches, `&` shows only matching lines), `L` filters by log level, `f` follows a log pane, `c` switches container, `w` exports what you see for a ticket. Explanations are hypotheses with their supporting Event; they do not prove a cause. |
| Service has no backends, or a claim is Pending | View `8` (selector mismatch / unready / missing named port) and view `9` (claim, PV, StorageClass, mounts, storage Events). A denied read is shown as unknown, never as zero. |
| Session report has no trend | Check the selected session path and sample count. A new one-shot invocation or the wrong `latest` directory may not contain the intended history. |
| Terminal is narrow or glyphs look broken | Enlarge the terminal, pan with `h`/`l`, or use `--ascii`. Use `--theme light` for light terminals and `-N` for plain text. |
| Export fails | Verify the selected report directory is writable and has space. Preserve stderr and the exit code. |
| Audit verification fails | Retain the original file, identify the reported line/session, and compare available central/syslog evidence. Do not edit it merely to make validation pass. |
| You need a shell or a file out of a pod | Use `kdx`, `kdash -X`, or press `X` and confirm. `kdsh [FILTER]` opens the shell-mode pod list. `S` / `U` / `D` open shell / upload / download flows; the kubectl guard refuses `exec` / `cp` until interactive mode is enabled. |

Exit codes: `0` success, `1` runtime failure, `2` usage error, `3` no pods matched, `5` disclaimer not accepted, `6` required audit file not writable. The kubectl read-only wrapper returns `126` for refused verbs. A supervising `timeout` normally returns `124` when its deadline expires, even when kdash handles the signal and finalizes its own logs; distinguish the supervisor status from the dashboard's audit `END` record.

## Shell in a container and file copy (opt-in, audited writes)

kdash reads the cluster by default. Shells and file transfers require explicit
interactive mode. Use `X` and confirm `y` during a run, or start with:

```bash
kdx -k /path/kubeconfig -c my-context -n default     # dashboard, interactive mode on
kdsh api --container app -n default                # shell list; one matching pod attaches
kdash --allow-interactive -n default                # same as -X
KDASH_ALLOW_INTERACTIVE=1 kdash            # or KDASH_ALLOW_INTERACTIVE=1 in kdash.conf
```

`S` selects a pod and opens a shell; `U` / `D` select the same pod/container and
open the file browser. Container inventory is refreshed for each pod. A remembered
container belongs to that pod, and is highlighted for confirmation when several are
available. An explicit `--container NAME` skips that list if the name exists.

The pod list refreshes when idle. `/` matches all typed words against pod, status or
node; `u` keeps pods needing attention, `s` sorts, digits jump to rows and `?` shows
the keys. `kdsh` and `: shell FILTER` use shell mode: Enter attaches and a single
match opens directly. Leaving the shell returns to this list or the inspector.

In a container with Bash, a pinned identity panel shows context, namespace, pod,
container, node and the metrics observed at attachment time. It is not refreshed
cluster telemetry. `exit` / Ctrl-D returns to kdash, `kdswitch` returns to related
pods of the same workload, and `kdquit` leaves kdash. Without Bash the `sh` fallback
prints a one-time header and has no `kdswitch` / `kdquit` helpers.

For an upload, browse local files and directories (starting in the launch directory),
mark with Space, press `u`, select the container destination and review the summary.
It asks before overwriting existing destination names. For a download, browse the
container, mark items and press `d`. Review the output directory and format: ZIP,
tar.gz or plain files. ZIP uses host `zip`, or optional `python3`; otherwise tar.gz
is the default. Local output starts in the launch directory; `KDASH_LAUNCH_DIR`
overrides it. `/` filters names, Enter opens directories, `h` / Backspace goes up,
`p` accepts a path and `v` previews the first 64 KiB of a file. Marks are scoped to
one directory. Summaries let you go back or cancel before copying.

Browsed copies stream `tar` through `kubectl exec`; remote listings, previews and
size checks also use `exec`. When the browser cannot run, kdash falls back to the
typed-path `kubectl cp` dialog. Transfers show bytes/rate and accept `q` to cancel.
Cancelled downloads discard the partial stream; already-uploaded files remain in
the container. Upload verification compares `du` sizes with a filesystem tolerance,
not hashes; archive downloads display a local SHA256 checksum.

What to expect, and what to record:

1. **Permission first.** `kubectl auth can-i create pods/exec` must say yes; `cp` also
   needs a `tar` inside the image. The browser also needs `sh`. Images without those
   tools cannot use these flows; reading permitted logs in the inspector remains an option.
2. **The terminal is handed over.** kdash leaves its screen, kubectl gets the real
   terminal (so `-it` and job control work, inside tmux as well), and the dashboard
   repaints when you leave the shell with `exit` or Ctrl-D. Interactive streams run
   without the read-request timeout or the 12-second read-command cap.
3. **It is your identity, not kdash's read-only path.** Everything you do in that shell
   happens with your RBAC and is not covered by the read-only guarantee. Treat it like
   any other `kubectl exec` session and record it in the change/incident notes.
4. **The audit log is the record.** `EXEC` and `EXEC_END` (pod, container), `CP_UP` and
   `CP_DOWN` (pod, container, direction, both paths, with credential-looking paths masked)
   and `CP_END` (bytes, exit code) are written to the local log, the central log when
   configured, and syslog. The `KUBECTL` summary line counts every `exec` / `cp`
   invocation as a write, including browser reads. Mode switches record
   `INTERACTIVE_ON` / `INTERACTIVE_OFF`; cancelling in a transfer summary records
   `CP_CANCEL`. Verify with `kdash --audit-grep 'EXEC|CP_|INTERACTIVE_'`.
5. **Nothing else is kept.** No shell output, no copied file, no command history of the
   session enters the model, a report, a bundle, a session directory or an export. The
   automatic evidence bundle still contains no logs.
6. **You can turn it off again.** `X` disables interactive mode immediately and records
   the change. The keys and the flag remain visible, and the guard
   refuses `exec` and `cp` with exit 126 and a hint, and a refusal is audited. Do not
   enable the mode for a run that must stay provably read-only.

## 10. Share and commit the evidence

Reports contain context and namespace names, pod/workload names, IPs, image names, operators, and timestamps. Review the artifacts intended for publication. Keep kubeconfig files, tokens, client keys, authentication files, credential-store exports, and unrelated shell/application logs out of Git. Do not place credentials in dashboard arguments or report commands. Use the existing credential manager or approved WSL authentication for Git operations without printing its contents.

Preserve filenames and relative links when sharing an HTML set. Include an inventory, the exact utility version, context/namespace scope, observation window and zone, exit statuses, known missing sources, audit verification outcome, and checksums. Distinguish raw records from rendered screenshots and from any redacted publication copy. Stage only the reviewed documentation and artifact paths, inspect `git diff --cached --stat`, and commit them with a description of what was actually observed and validated.
