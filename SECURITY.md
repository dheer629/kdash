# Security policy

## What kdash does with your cluster

kdash is a **read-only** tool and that is a design rule, not a promise:

* every `kubectl` call goes through a wrapper that allows only `get`, `top`,
  `describe`, `logs`, `version`, `api-resources`, `auth can-i` and the read-only
  `config` subcommands. Any other verb (`delete`, `apply`, `patch`,
  `config set-context`, ...) is refused with exit code 126 and recorded;
* the wrapper does not shell out to a shell, so a pod name or namespace cannot
  turn into a command;
* it needs no cluster-side component: no agent, no CRD, no service account of
  its own. It runs with your `kubeconfig` and your permissions, and sees exactly
  what you can see;
* every run is audited locally (`~/kdash_reports/audit`), centrally when
  `/var/log/kdash` exists, and through syslog, with a hash chain over the log.

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

* the permissions of the account you run kdash with: kdash can only read what
  that account may read;
* the contents of the reports and screenshots you publish - they contain cluster
  metadata (context, namespace, pod, workload and image names, addresses, node
  names, operator and timestamps). Review before publishing; the repository's own
  evidence is redacted by `scripts/redact-run.sh`;
* a redacted audit log no longer verifying its hash chain - redaction changes the
  bytes a chain covers. That is documented in
  [artifacts/README.md](artifacts/README.md);
* vulnerabilities in `kubectl`, the cluster or the terminal.

## Supported versions

The `main` branch and the latest released version are supported. Fixes are made
on `main` first; the changelog says what changed and when.
