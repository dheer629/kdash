# Contributing to kdash

Thanks for wanting to help. kdash is a free, MIT-licensed utility and it stays
useful only if it keeps working on real clusters, so reports from other
environments are as valuable as code.

## How this repository is maintained

kdash is a single-maintainer project. The maintainer ([@dheer629](https://github.com/dheer629))
owns the code, the releases and the published evidence:

* **`main` is protected.** Nobody, including the maintainer's own automation,
  pushes directly to it: changes arrive through a pull request that the
  maintainer reviews and merges. Only the maintainer can merge or force-push.
* **Fork freely.** The MIT licence lets you copy, change and redistribute kdash
  under your own name. What it does not do is let anyone change *this*
  repository: that is what the branch protection and `CODEOWNERS` are for.
* Issues, bug reports, feature ideas and pull requests are welcome from anyone.
  A pull request is a proposal - it becomes part of kdash when the maintainer
  merges it.

## What to send

| You want to | Do this |
|---|---|
| Report a wrong value, a crash or a display bug | open an issue with the template; include kdash version (`kdash --version`), shell, `awk --version`, `kubectl version --client`, the view and, if you can, a text export (`kdash -v <view> --once > out.txt`) |
| Ask for a feature | open an issue describing the question you want answered, not only the key you want added |
| Fix or extend something | fork, branch, keep the style below, run the tests, open a pull request |
| Report a security problem | do **not** open a public issue - see [SECURITY.md](SECURITY.md) |

## Ground rules for code

1. **Read-only, always.** kdash must never create, change or delete a cluster
   object. Every `kubectl` call goes through the read-only wrapper; a new verb
   needs a very good reason and a test.
2. **No new runtime dependency** beyond Bash 4+, `kubectl`, `awk` and coreutils.
   No `jq`, no Python, no build step, no compiled binary.
3. **Portability.** It must run on busybox `awk` and on old terminals: avoid
   `%*s`, `\x` escapes and glyphs a PuTTY font cannot draw (use `--glyphs ascii`
   paths where in doubt).
4. **Bash style.** Four-space indent, `local` for function variables, quoted
   expansions, `set -uo pipefail` in scripts, no `eval` on data.
5. **Keep the installer and the CLI in step.** `kdash-bundle.sh` embeds `kdash`
   byte for byte. The runtime, Events, service/storage and inspector code lives in
   `src/*.sh`; edit those, then run `bash scripts/build.sh`, which regenerates the
   marked module block in `kdash` and re-embeds it in `kdash-bundle.sh`. Never edit
   the generated block between `# BEGIN KDASH MODULES` and `# END KDASH MODULES`.
6. **Never commit environment data.** No kubeconfig, no tokens, no host names,
   no internal namespace or product names, no personal paths. The published
   screenshots and evidence must stay generic - `scripts/redact-run.sh` and
   `scripts/redact-history.sh` exist for exactly that, and the mapping files
   stay outside the repository.

## Before you open a pull request

```bash
bash scripts/validate-all.sh
```

That one command checks the Bash syntax of every shipped script, that the
installer embeds `kdash` byte for byte, every fixture test under `tests/` (the 11
uninstall tests plus runtime, events, health, inspector and interactive; none needs a cluster),
every checksum (root, `samples/`, `samples/html/`, `samples/cli_413/`), the recorded
run and its captures, the feature-screen run and its 22 captures plus manifest, the
published samples, that no environment, product, site or personal name and no
credential is in the tree, that every README reference resolves, that the README keeps
a direct download link for each published version, and that the working tree is clean.
CI runs the same script ([.github/workflows/ci.yml](.github/workflows/ci.yml)), so a red
build there means the pull request is not ready.

## For the maintainer: how "nobody else can change it" is enforced

The MIT licence makes kdash free to use, fork and change *your own copy*. Keeping
*this* repository under one person's control is a repository setting, not a
licence term, and it is set up like this on GitHub (Settings -> Branches ->
branch protection rule for `main`):

* Require a pull request before merging - 1 approval, dismiss stale approvals,
  require review from **CODEOWNERS** (`.github/CODEOWNERS` lists `@dheer629` for
  every path), require approval of the most recent push;
* Require conversation resolution before merging;
* Do not allow bypassing the above settings (so it applies to administrators too);
* Restrict who can push to matching branches - only the maintainer;
* Do not allow force pushes and do not allow deletions;
* Require the `ci` workflow to pass before merging (add the check name from the
  Actions tab once the workflow has run at least once).

Command line equivalent (`gh` authenticated as the owner):

```bash
gh api -X PUT repos/dheer629/kdash/branches/main/protection \
  -H 'Accept: application/vnd.github+json' --input - <<'JSON'
{
  "required_status_checks": null,
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": true,
    "required_approving_review_count": 1,
    "require_last_push_approval": true
  },
  "restrictions": { "users": ["dheer629"], "teams": [], "apps": [] },
  "allow_force_pushes": false,
  "allow_deletions": false,
  "required_conversation_resolution": true,
  "lock_branch": false
}
JSON
```

Two more settings that keep it maintainer-only: the repository has **no other
collaborators** (so nobody else has write access at all), and *Settings ->
Actions -> General* keeps the default `GITHUB_TOKEN` read-only, so a workflow
cannot push to `main` either.


## Licence of contributions

By opening a pull request you agree that your contribution is licensed under the
MIT licence of this project (inbound = outbound), and that the maintainer may
merge, reword or decline it.
