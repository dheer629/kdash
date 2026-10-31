# kdash validation artifacts

These captures cover three interfaces: the **current 4.19.2 utility** in
`view-screens-20261031-051739/`, and the historical 4.12.0, 4.13.1 and 4.14.0 runs
below. Each one is kept with the version it was captured from and its own checksums;
the 4.19.2 capture is the one that shows this source's interface. Run
`bash scripts/validate-all.sh` for the current source, bundle, fixture and
publication checks, and see `latest-run.txt` for the recorded five-minute validation
cycle (4.12.0).

Raw, unedited evidence of one kdash 4.12.0 validation cycle on the local Ubuntu WSL
distribution against the local vcluster context `devops-admin@local-cluster`.
`latest-run.txt` names the run directory this README describes.

A second, smaller run lives next to it: `feature-screens-20261029-151233/` holds the raw
screens of the **kdash 4.13.1** views that did not exist in 4.12.0 (8 SERVICES, 9 STORAGE,
Events, explanations, DOCTOR) and of the inspector (find, only matches, container picker,
help). It is the source of `../samples/cli_413/`: 22 captures at `170x50` and `100x40`,
each `.ansi` (with colours) and `.txt` (plain text), listed in `captures.tsv`. It was
captured live against the same kind of local vcluster and rendered with the same
`../scripts/capture-terminal.py`. It is not a five-minute validation cycle, so it makes
no claim about long-run behaviour. Like the run above it was redacted with
`../scripts/redact-run.sh` and a private mapping (context as `devops-admin@local-cluster`,
personal paths as `/home/demo`, host as `node`, the shared cluster's other tenants as
`ml-service-prod`, `ml-service-dev`, `gitops-core`), and the images were re-rendered from
the redacted captures afterwards.

The run was produced by `../scripts/wsl-validation.sh`, which is the reproducible
form of the manual steps in `../DEVOPS_USER_GUIDE.md`. Nothing in this directory was
edited by hand: every log, capture, report and checksum was written by the run.

## The current interface: `view-screens-20261031-051739/`

31 raw screens of **kdash 4.19.2** - the file this repository ships - captured live
against a local WSL vcluster (namespace `default`, 5 s poll) with
`../scripts/capture-view-screens.sh`: every view (1-9 plus `E` events and `!`
explanations), the `:` command palette, DOCTOR, the inspector (pod picker, summary,
previous logs, `/` find, `&` only matches, `c` container picker, `?` key map), the
dashboard help, two `100x40` layouts and the opt-in interactive mode (`S` refused,
the `X` gate, the shell picker, a real shell inside the container, and the `D` / `U`
browsers). Each screen is kept as `.ansi` (with colours) and `.txt` (plain text) and
listed in `captures.tsv`; `../scripts/render-captures.ps1` rendered them into
`../samples/cli_419/`, which carries their checksums. It was redacted with
`../scripts/redact-run.sh` and the same private mapping as the other runs, and the
images were re-rendered from the redacted captures afterwards. It is one screen per
view, not a five-minute cycle, so it makes no claim about long-run behaviour.

## Operations, exports and one-shots: `operation-screens-20261031-062953/`

24 raw screens of the same 4.19.2 build showing what the utility *does*, captured with
`../scripts/capture-operation-screens.sh`: the dashboard controls (namespace picker,
pod filter, structured filter prompt, detail lines, pods-only, sort and reverse, pause
and poll interval, colour theme, all-vs-hosting nodes, true scale, chart window), the
`e` HTML menu and the all-tabs report being written, the inspector's `w` export, the
session close summary, the one-shot modes (`-V`, `-h`, `--snapshot all`, `--report`,
`--audit`, `--audit-verify`, `--about`, `--audit-report`) and the first-run disclaimer
gate - captured with a private `XDG_CONFIG_HOME`, so no acceptance of this user was
touched.

The run also produced the files those modes write - `<ns>/reports/*.html`, the evidence
bundle's TSV and CSV, `reports/inspector/`, and `<ns>/audit/*.html|.csv` - and its
`README.txt` names each one, so a screen can be checked against the artifact it claims.
Rendered into `../samples/cli_419/` (32-55) and collected into `../samples/html419/`
with `../scripts/render-captures.ps1` and `../scripts/collect-html-samples.ps1`, after
the same redaction as the other runs.

## What the 4.12.0 run did

1. inventoried the host, the installed kdash and the cluster (read-only)
2. previewed and ran `kdash-uninstall.sh`, keeping every line of output
3. verified that the binary, completion and shell integration were gone and that
   configuration, reports, sessions and audit logs survived
4. reinstalled with `kdash-bundle.sh` and verified with `--check` plus a login shell
5. ran kdash live for five minutes per namespace in three namespaces at the same
   time (separate tmux sessions of 170x50), captured views 1-7 of each namespace,
   exported the all-tabs HTML with `x`, quit with `q`, and recorded the exit status
   and the measured live duration
6. rebuilt the HTML from the recorded session and wrote the one-shot snapshots, the
   text/TSV/CSV evidence bundle and the audit report per namespace
7. wrote `run-metadata.json`, `controller-actions.json` and `RUN_INVENTORY.md`

## Read in this order

| File | What it tells you |
|---|---|
| `RUN_INVENTORY.md` | generated summary: steps, logs, per-namespace results, produced files, failures, capture hashes |
| `run-metadata.json` | machine-readable run parameters and per-namespace exit status plus measured duration |
| `run.log` | the full console transcript of the run, in order |
| `status.txt` | `DONE`, `DONE_WITH_FAILURES` or `ABORTED` |
| `controller-actions.json` | every view key sent and every capture/export taken, with timestamps |
| `logs/01-preinstall.log` | host, tools, installed kdash version and sha256, contexts, nodes, namespaces, pod counts, permissions |
| `logs/02-uninstall-preview.log` | the uninstall plan, with no file changed |
| `logs/03-uninstall.log` | the actual removal, including the startup-file backup name |
| `logs/04-uninstall-verification.log` | binary gone, no setup block left, kept audit log still verifies, login shell no longer resolves kdash |
| `logs/05-install.log`, `logs/06-install-verification.log` | reinstall, `--check`, login-shell resolution, installed sha256 versus the repository file |
| `logs/07-disclaimer-accept.log` | one-shot frame with `KDASH_ACCEPT_DISCLAIMER=1` (accepts the disclaimer and exits) |
| `logs/08-oneshot-pods-text.log` | a one-shot TSV frame, as an example of a non-live export |
| `logs/10..14-*` | per namespace: session rebuild, snapshot set, evidence bundle, audit listing and chain verification, audit report |
| `<namespace>/launch.sh` | the exact environment and command that ran kdash for that namespace |
| `<namespace>/terminal.raw.log.gz` | the raw tmux pane output of the whole live run, gzip -9 compressed (see `RAW-TERMINAL-SHA256.txt` for the sha256 of each file before compression; read one with `zcat <namespace>/terminal.raw.log.gz`) |
| `<namespace>/cli/0N-<view>.ansi` and `.txt` | the saved screen and the plain text of each view |
| `<namespace>/exit-status.txt`, `started.epoch`, `ended.epoch` | exit code and the measured live duration |
| `<namespace>/reports/` | the HTML reports and the recorded session (history samples and model tables) |
| `<namespace>/audit/` | the audit log of that namespace, plus the CSV/HTML audit export |

The three raw terminal captures were 8 MB each (24 MB in total) because a live TUI
redraws continuously; `../scripts/compress-raw-captures.sh` compressed them to about
80 KB each after recording the sha256 of every file in `RAW-TERMINAL-SHA256.txt`.
Nothing else in this directory was modified after the run, and the captures, text
files, reports, sessions and audit logs are exactly as kdash wrote them.

## Redaction: the names here are placeholders

Before publication, the cluster context, the namespaces and the pod prefixes
derived from them were replaced with generic names by `../scripts/redact-run.sh`
and a private mapping (the mapping itself is deliberately not in this repository,
because it holds the names being removed):

| Published as | Replaces |
|---|---|
| context `devops-admin@local-cluster` | the original kubeconfig context |
| namespaces `orders-service-e2e`, `ml-service-prod`, `gitops-core` | the three namespaces that were observed |
| pod / workload prefix `orders-` | the prefix the original namespace implied |
| `ops-monitor`, `validation-demo-ns`, `demo-app` | the other namespaces that appear in the all-namespaces listing |
| operator `demo`, host `node`, `/home/demo`, `/workspace/kdash` | the operator name, the host name and the home-directory paths |
| `platform namespaces`, `platform CLI`, `management host`, `example.com/nodepool`, `shared_reports`, `self-contained HTML report` | product, organisation and site wording in the tool, the installer and the documentation |

Consequences, stated plainly:

  * the audit logs are redacted as well, so **their hash chain no longer verifies**:
    a chain covers the bytes as recorded, and redaction changes bytes. It verified
    before redaction - `logs/13-audit-<namespace>.log` records "chain intact" for
    each namespace - and that result cannot be reproduced from these copies.
  * `RAW-TERMINAL-SHA256.txt` lists the sha256 of the uncompressed captures
    **after** redaction, so the published `.gz` files can still be checked against it.
  * the CLI screenshots were re-rendered from the redacted captures and the HTML
    reports were re-copied after redaction, so text and images agree.
  * not redacted: the node name, the standard cluster namespaces (`kube-system`,
    `cert-manager`, `kube-flannel`, `local-path-storage`, `default`), the pod and
    workload names of the run, and every address, size, timestamp and measured
    value. The tool's own author credit (`Dheeraj V`, printed by kdash in every
    header and named in the README) is kept on purpose: it is the utility's
    attribution, not operator data.

## Integrity

`RUN_INVENTORY.md` lists the sha256 of every CLI capture. The audit log is
hash-chained; verify it with `kdash --audit-verify` (the run's own verification
output is in `logs/13-audit-<namespace>.log`). A chain proves continuity inside the
file it is in: removing whole lines from the end of a file cannot be detected from
that file alone, which is why a central and a syslog copy exist in a production
setup.

## What is deliberately not here

No kubeconfig, no token, no client key, no credential store, no unrelated shell or
application log. Reports do contain cluster metadata (context, namespace, pod,
workload and image names, IP addresses, node names, operator, timestamps) - review
before publishing.

## Limits of this evidence

One five-minute window per namespace at five-second sampling, one vcluster with one
visible node, and the permissions of one credential. Whole-node usage and
cluster-wide comparison depend on node metrics and on cluster-wide read permission.
IO requires a Prometheus/cAdvisor source; where none is reachable it is reported as
unavailable rather than as zero. Treat the numbers as a diagnostic snapshot of the
moment they were taken, and read the coverage notes in each report.
