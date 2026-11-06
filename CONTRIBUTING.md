# Contributing to kdash

Thanks for wanting to help. kdash is a free, MIT-licensed utility and it stays
useful only if it keeps working on real clusters, so reports from other
environments are as valuable as code.

## How this repository is maintained

kdash is a single-maintainer project. The maintainer ([@dheer629](https://github.com/dheer629))
owns the code, the releases and the published evidence:

* **The maintainer controls `main`.** Outside contributions arrive through pull
  requests for review. The protection settings below are a recommended setup;
  their presence must be checked in GitHub rather than inferred from this file.
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

1. **Read-only by default.** Every `kubectl` call goes through the audited guard.
   Only explicit interactive mode permits `exec` and `cp` for container shells and
   file transfers. Keep that opt-in boundary and write auditing intact; cluster
   mutations such as `apply`, `patch` and `delete` remain refused. Add regression
   coverage for changes to this boundary.
2. **No new runtime dependency** beyond Bash 4+, `kubectl`, `awk` and coreutils.
   No `jq`, no mandatory Python, no runtime build step, no compiled binary.
   Transfer archives may use optional `zip` or Python 3 when installed, with plain-file downloads as the default and tar.gz available.
   File verification uses SHA-256 when possible, a labelled MD5 fallback, or a
   labelled size-only result when checksum tools are absent. Document optional tools and container requirements.
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
   If importing an updated bundle, run `bash scripts/build.sh --from-bundle`
   **first**: it extracts the CLI and modules from that bundle. Running the normal
   build first would replace its new code with the old local sources. Use
   `bash scripts/build.sh --check` to verify synchronization without rewriting files.
   The standalone `kdash-uninstall.sh` must also match the installer's uninstaller.
6. **Never commit environment data.** No kubeconfig, no tokens, no host names,
   no internal namespace or product names, no personal paths. The published
   screenshots and evidence must stay generic - `scripts/redact-run.sh` and
   `scripts/redact-history.sh` exist for exactly that, and the mapping files
   stay outside the repository.

## Before you open a pull request

```bash
bash scripts/build.sh --check
bash scripts/update-checksums.sh
KDASH_VALIDATE_ALLOW_DIRTY=1 bash scripts/validate-all.sh
# After committing and pushing, run the strict publication check:
bash scripts/validate-all.sh
```

That one command checks the Bash syntax of every shipped script, that the
installer embeds `kdash` and the uninstaller byte for byte, source-module and version
synchronization, and every fixture test under `tests/` (none needs a cluster),
every checksum (root, `samples/`, `samples/html/`, the current `samples/cli_423/` and `samples/html423/`, and historical galleries), the recorded
run and its captures, the feature-screen run and its 22 captures plus manifest, the
published samples, that no environment, product, site or personal name and no
credential is in the tree, that every README reference resolves, that the README keeps
a direct download link for each published version, and that the working tree is clean.
CI runs the same script ([.github/workflows/ci.yml](.github/workflows/ci.yml)), so a red
build there means the pull request is not ready.

## Live feature and screenshot validation

Use [`scripts/live-e2e.py`](scripts/live-e2e.py) with the installed binary and a
private kubeconfig for the local WSL cluster. The harness uses a dedicated
`kdash-e2e` namespace and isolated tmux socket, preserving unrelated sessions.
Its `checks.tsv`/`results.json` describe the assertions and limitations, while
`captures.tsv` connects every live ANSI screen to its image and terminal size.
Keep the kubeconfig and private credentials outside the published evidence.

For native screenshots, the validation environment also needs tmux, Xvfb, xterm,
xwininfo, ImageMagick, Python Pillow and pyte. Run the installed CLI with a private
`KUBECONFIG` and `python3 scripts/live-e2e.py --repo "$PWD" --setup
--context CONTEXT --native-screenshots`. Setup creates only the explicitly named
test resources; the CLI keeps its normal dependency-light runtime.

The optional browser checks use Playwright and an installed Chrome executable:
`node scripts/validate-html.mjs --run artifacts/RUN --module PLAYWRIGHT_MODULE
--browser CHROME_EXECUTABLE`. They exercise the real generated HTML and save
`browser-results.json` plus browser screenshots. `python3 scripts/publish-live-samples.py`
copies report bytes and updates current galleries from the successful run.
Finally regenerate checksums and run the full publication validator. CI verifies
the saved evidence and hashes without requiring cluster or browser access.

For UI changes, cover narrow widths, ASCII and theme modes, selected rows, long
names, wrapped key hints and the actual action result. Exercise transfers against
disposable pod files and verify destination bytes; a browser screenshot alone
does not prove a copy succeeded. Run fixture tests for denied/missing capabilities
that the live cluster cannot supply. Keep older screenshots under their capture
version and add the new gallery, rather than renaming old images.

## For the maintainer: how "nobody else can change it" is enforced

The MIT licence makes kdash free to use, fork and change *your own copy*. Keeping
*this* repository under one person's control is a repository setting, not a
licence term. To enforce review in GitHub, configure Settings -> Branches ->
branch protection rule for `main`:

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

For maintainer-only write access, keep the collaborator list limited to the
maintainer and choose a read-only default `GITHUB_TOKEN` in Settings -> Actions ->
General. Workflows that publish release assets request their own explicit
`contents: write` permission.


## Licence of contributions

By opening a pull request you agree that your contribution is licensed under the
MIT licence of this project (inbound = outbound), and that the maintainer may
merge, reword or decline it.
