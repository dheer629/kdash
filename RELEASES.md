# Releases and downloads

The current version is **4.27.3**, which adds runbooks (the `R` key,
`-v runbook`, `--runbook [NAME]`: `etcd-restore`, `cert-rotate`, `node-notready`,
`api-unreachable`, `oidc-login`, printed with this cluster's own node, namespace
and pod names already filled in), the instant check (`K`, `-v check`,
`--check [--run N]`: every finding right now with the read commands that confirm
it, and `--run N` runs one finding's read commands), and OIDC login handling
(`L`, plus a start-up check that exits `4` instead of blocking when there is no
terminal). It retains certificate and login expiry (`C`, `-v certs`, `--certs`)
with the header badge and scriptable exit codes, interactive-mode switching from
pod details and logs, framed pickers, saved namespace defaults, expandable
bounded logs and checked file transfers. Its live WSL evidence is indexed by
[`artifacts/latest-e2e.txt`](artifacts/latest-e2e.txt), with terminal and report
galleries in [`samples/cli_4273/`](samples/cli_4273/README.md) and
[`samples/html4273/`](samples/html4273/README.md) - the newest complete capture,
made from 4.27.3 and the first to include the runbook, check, certificates and
OIDC-login screens.
Published versions have their own immutable GitHub Releases, so you can download
an exact historical release at any time:
<https://github.com/dheer629/kdash/releases>

| Version | Tag | What it adds | Download |
|---|---|---|---|
| 4.27.3 | `v4.27.3` | runbooks (`R`, `--runbook`), instant check (`K`, `--check [--run N]`), OIDC login handling (`L`, exit 4), certificate and login expiry (`C`, `--certs`) | [release](https://github.com/dheer629/kdash/releases/tag/v4.27.3) |
| 4.24.1 | `v4.24.1` | certificate and login expiry (`C`, `-v certs`, `--certs`), header badge, scriptable exit codes | [release](https://github.com/dheer629/kdash/releases/tag/v4.24.1) |
| 4.23.2 | `v4.23.2` | interactive mode from pod details and logs; responsive inspector toggle/quit and whole-line confirmation; separate current WSL evidence | [release](https://github.com/dheer629/kdash/releases/tag/v4.23.2) |
| 4.23.1 | `v4.23.1` | framed pickers and diagnostic tables, saved defaults, expanded logs, verified transfers; native WSL screenshots and current e2e evidence | [release](https://github.com/dheer629/kdash/releases/tag/v4.23.1) |
| 4.14.0 | `v4.14.0` | opt-in shell in a container (`S`), upload (`U`) and download (`D`), audited as writes | [release](https://github.com/dheer629/kdash/releases/tag/v4.14.0) |
| 4.13.1 | `v4.13.1` | installer summary names every view and key (no code change to the CLI) | [release](https://github.com/dheer629/kdash/releases/tag/v4.13.1) |
| 4.13.0 | `v4.13.0` | doctor, inspector, command palette, Events and explanations, services, storage, `-A` fix, inspector find/containers/export | [release](https://github.com/dheer629/kdash/releases/tag/v4.13.0) |
| 4.12.0 | `v4.12.0` | ALERTS view (kept for reference; the `-A` limitation applies) | [source archive](https://github.com/dheer629/kdash/archive/refs/tags/v4.12.0.tar.gz) |

4.12.0 was tagged before this release workflow existed, so its tag gives you the source
archive: run the workflow manually (Actions -> Versioned downloads -> Run workflow, source
ref `v4.12.0`) to build the same files as the versions above. The tag itself already makes
that version permanently downloadable, which is the point of versioned releases.

## Install the current source

```bash
git clone https://github.com/dheer629/kdash.git
cd kdash
sha256sum -c SHA256SUMS
bash kdash-bundle.sh
exec bash -l
kdash --version                              # kdash 4.24.1
```

For an existing checkout, update it without discarding local changes, then verify
the checksums and run the installer again. To pin a source revision, check out the
desired commit before installing. `kdash-bundle.sh` is self-contained; installing
does not require building or connecting to a cluster.

## What each release contains

| File | Purpose |
|---|---|
| `kdash` | the whole CLI, one Bash file |
| `kdash-bundle.sh` | installer (embeds `kdash` byte for byte) |
| `kdash-uninstall.sh` | standalone uninstaller |
| `README.md`, `LICENSE` | documentation and licence for that version |
| `CHANGELOG.md`, `RELEASES.md`, `DEVOPS_USER_GUIDE.md` | release changes, version selection and operating instructions |
| `VALIDATION.json`, `BROWSER_VALIDATION.json`, `SCREENSHOTS.tsv` | exact installed/source hashes, live CLI/browser checks and screenshot provenance for current releases |
| `kdash-<version>.tar.gz` | all of the above in one archive |
| `SHA256SUMS` | checksums of every file in the release |

## Download and verify a specific version

```bash
v=4.24.1
base=https://github.com/dheer629/kdash/releases/download/v$v
curl -fsSLO "$base/kdash-$v.tar.gz" -O "$base/SHA256SUMS"
sha256sum --ignore-missing -c SHA256SUMS      # must print: kdash-4.24.1.tar.gz: OK
tar -xzf "kdash-$v.tar.gz"
bash kdash-bundle.sh                           # installs to ~/.local/bin
kdash --version
```

To go back to an older release, set `v` to that version and repeat. Installation
replaces the selected destination; copies older than v4 elsewhere on PATH are moved
aside when writable. Keep a source/archive copy if you need to restore the replaced
version. `bash kdash-uninstall.sh` removes the matching installation while retaining
configuration, reports and audit history.

## How a version is published (maintainer)

1. For normal changes, edit `src/*.sh` and the core in `kdash`, then run
   `bash scripts/build.sh` to assemble the module block and synchronize the installer.
   If only a new authoritative `kdash-bundle.sh` was supplied, import it first with
   `bash scripts/build.sh --from-bundle` to synchronize the CLI, uninstaller and all
   five modules; do not run the normal build over it first.
2. Set `KDASH_VERSION` in `kdash` for a new version and run the normal build again.
   `bash scripts/build.sh --check` must confirm the CLI, modules and installer agree.
3. Update the documentation and run `bash scripts/update-checksums.sh`, then
   `KDASH_VALIDATE_ALLOW_DIRTY=1 bash scripts/validate-all.sh` before committing.
4. Commit and publish the change through the repository's configured branch rules.
   Run `bash scripts/validate-all.sh` again on the clean, published checkout.
5. Only when publishing a release, tag that commit, for example
   `git tag -a v4.27.3 -m "kdash 4.27.3" && git push origin v4.27.3`.

Pushing the tag runs [.github/workflows/release.yml](.github/workflows/release.yml). It
validates the tree, packages that commit with `scripts/package-release.sh`, and creates
the Release. It refuses a tag that disagrees with the version inside `kdash`, and it
never replaces assets of a release that already exists.
After that release succeeds, add its actual download links to the release tables;
keep older version links and label old screenshots with their capture version.

To publish a version that was committed earlier (for example 4.12.0), run the workflow
manually (Actions -> Versioned downloads -> Run workflow) and enter its commit or tag.
To build the same files locally: `bash scripts/package-release.sh <commit-or-tag> dist`.
