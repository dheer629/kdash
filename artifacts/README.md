# kdash validation artifacts

Raw, unedited evidence of one kdash 4.12.0 validation cycle on the local Ubuntu WSL
distribution against the local vcluster context `devops-admin@local-cluster`.
`latest-run.txt` names the run directory this README describes.

The run was produced by `../scripts/wsl-validation.sh`, which is the reproducible
form of the manual steps in `../DEVOPS_USER_GUIDE.md`. Nothing in this directory was
edited by hand: every log, capture, report and checksum was written by the run.

## What the run did

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
