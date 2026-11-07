# Security policy

## What kdash does with your cluster

kdash is **read-only by default**. Interactive mode is an explicit exception for
container shells and file transfers:

* the kubectl read guard allows only `get`, `top`, `describe`, `logs`, `version`,
  `api-resources`, `auth can-i`, `auth whoami` and the read-only `config`
  subcommands. `exec` and `cp` are allowed only with interactive mode
  enabled (`-X`, `--allow-interactive`, `--shell-picker`, `KDASH_ALLOW_INTERACTIVE=1`,
  or confirmation of the `X` key). Other mutating verbs (`delete`, `apply`,
  `patch`, `config set-context`, ...) are refused with exit code 126 and recorded;
* command arguments are passed as arrays. Shell and transfer operations run fixed
  scripts inside the container with paths and identity passed as positional
  arguments; container metadata is not interpolated into executable commands;
* it needs no cluster-side component: no agent, no CRD, no service account of
  its own. It runs with your `kubeconfig` and your permissions, and sees exactly
  what you can see;
* every run is audited locally (`~/kdash_reports/audit`), centrally when
  `/var/log/kdash` exists, and through syslog, with a hash chain over the log.

Runbooks (`R`, `--runbook`) print both investigation steps and separately marked
`CHANGE` commands. kdash does not execute those change commands. Instant check
(`K`, `--check`) collects findings; `--check --run N` executes only that finding's
read commands through fixed handlers.

## Login helpers and local credentials

kdash uses the selected kubeconfig's credential helper for authentication and
reads helper metadata and cache expiry without exporting cached tokens or
private keys. During login it displays the helper's stderr, including sign-in
URLs and device codes. Third-party helpers control that output; kdash does not
sanitize arbitrary plugin messages.

On Linux, best-effort cleanup checks the exact helper command, UID, run tag and
process birth time through procfs before signalling stale helpers owned by this
run. A separate attempt tag protects active login helpers, including detached
ones, during completion checks. There is no broad process-name fallback when
procfs is unavailable. Helpers that discard inherited tags can remain running.
Choosing `c` to continue without login pauses background reads and automatic
retries until `L`.

The repository ignores kubeconfigs, credential stores, private-key files,
PKCS#12 containers (`*.p12`, `*.pfx`), `.ssh/` and common SSH private-key names
(`id_rsa`, `id_dsa`, `id_ecdsa`, `id_ed25519`). Ignore rules do not inspect file
contents or make reports safe to publish; review the actual files before adding
them to Git.

## Interactive mode and file transfers

`kdx` starts the dashboard with interactive mode enabled; `kdsh` opens the shell
picker. `X` toggles the mode during a run, asking before enabling it. The title
bar identifies the current mode. An interactive shell has the permissions of the
container user and can change or delete data. This is not a sandbox or a
read-only shell. Authorization comes from the current kubeconfig and RBAC
(`pods/exec`), not from the local mode toggle.

The file browser lists and previews remote files through `kubectl exec`. Transfers
stream tar through `exec`, with `kubectl cp` as a typed-path fallback. Uploads can
overwrite container files after confirmation. Downloads write to the launch
directory by default; the summary lets you choose another destination or format.
Cancellation does not roll back files already written. Plain-file downloads are
the default; optional ZIP and tar.gz archives depend on available host tools.

Read calls are bounded by the request and command timeouts. Interactive `exec` and
`cp` streams omit these caps so a shell or transfer can finish normally. The guard
runs through Bash so it also works on hosts whose temporary directory is mounted
`noexec`.

The audit records attachment metadata, paths (with credential-looking paths
masked), outcomes and `WRITE` calls. It does not record the commands typed inside
the shell, shell output, or transferred file contents. Transfer staging files are
temporary; transferred content is not added to dashboard reports, recorded
sessions or evidence exports. Treat downloaded files and reports as sensitive
according to their actual contents.

## Reporting a vulnerability

Please do not open a public issue for a security problem. Report it privately to
the maintainer, [@dheer629](https://github.com/dheer629), through GitHub's
private vulnerability reporting ("Security" tab, "Report a vulnerability") or a
direct message on GitHub. Include:

* the kdash version (`kdash --version`) and the commit you used;
* what you did, what you expected and what happened;
* the smallest reproduction you can manage, with secrets removed.

You will get an acknowledgement, an assessment of whether it is exploitable in
the default configuration, and a fix or a documented decision. Please give the
maintainer a reasonable window to publish a fix before writing about it.

## What is out of scope

* the permissions of the account you run kdash with: reads, shells and transfers
  run with that account's cluster permissions and the container user's rights;
* the contents of the reports and screenshots you publish - they contain cluster
  metadata (context, namespace, pod, workload and image names, addresses, node
  names, operator and timestamps). Review before publishing. Historical evidence
  identifies the substitutions made with `scripts/redact-run.sh`; versioned live
  runs preserve real local cluster metadata and measurements. See each run's
  provenance and [artifacts/README.md](artifacts/README.md);
* a redacted audit log no longer verifying its hash chain - redaction changes the
  bytes a chain covers. That is documented in
  [artifacts/README.md](artifacts/README.md);
* vulnerabilities in `kubectl`, the cluster or the terminal.

## Supported versions

The `main` branch and the latest released version are supported. Fixes are made
on `main` first; the changelog says what changed and when.
