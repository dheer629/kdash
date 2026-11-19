# Releases and downloads

The current source version is **4.37.0**. It adds whole-view dashboard search,
cross-container log searches, kubelet-rotated log reads when permitted, and a
`>` quick export from dashboard views, pod panes and selection lists. Search
boxes and prompts support cursor editing and session history. Fixed colour
roles, changed-line redraws, parallel API reads and background model builds
improve terminal use over slower connections. The Certificates view now includes
certificates in Secrets; the Secrets scan has its own timeout and prints UTC
expiry dates. Live combined HTML reports add FMEA and Secrets tabs and bundles
include the corresponding worksheets. It retains the nine resource views, Events and explanations,
FMEA/access review, runbooks, instant checks, OIDC handling, guarded container
shells and verified file transfers, HTML/history reports and audit trail.

Current validation is indexed by
[`artifacts/latest-e2e.txt`](artifacts/latest-e2e.txt), with versioned terminal
and report galleries in [`samples/cli_4370/`](samples/cli_4370/README.md) and
[`samples/html4370/`](samples/html4370/README.md). The prior
[4.32.0 terminal gallery](samples/cli_4320/README.md),
[HTML reports](samples/html4320/README.md) and earlier versions remain available.
The local cluster uses certificate authentication; controlled OIDC helpers test
the login flow separately.
The 2026-11-19 local validation run (`live-e2e-v4370`) passed 303 live checks,
30 Secrets checks, 33 browser checks and all 19 fixture suites; 125 CLI
screenshots and the combined HTML reports are published in the galleries above.
See `docs/VALIDATION-4.37.0.md` for the row-by-row evidence and limits.
Published versions have their own immutable GitHub Releases, so you can download
an exact historical release at any time:
<https://github.com/dheer629/kdash/releases>

Version **4.37.0** is prepared for publication; its links become available when
that release is published. The published **4.27.4** release and assets remain
available. Versions 4.28.1 and 4.32.0 have source snapshots; their release assets
were not published. Use the exact source commits or archives below.

| Version | Tag / commit | What it adds | Download |
|---|---|---|---|
| 4.37.0 | `v4.37.0` | whole-view search, cross-container and rotated logs, quick exports, terminal performance and certificate coverage | [release (pending publication)](https://github.com/dheer629/kdash/releases/tag/v4.37.0) |
| 4.32.0 | [`195a0f1`](https://github.com/dheer629/kdash/tree/195a0f107ab9f26400ef0ef064df99f571488efa) | secrets map (`Y`, `--secrets`): certificates, keys, expiry, usage and rotation restart paths, never reads secrets | [source commit](https://github.com/dheer629/kdash/tree/195a0f107ab9f26400ef0ef064df99f571488efa) · [source archive](https://github.com/dheer629/kdash/archive/195a0f107ab9f26400ef0ef064df99f571488efa.tar.gz) |
| 4.28.1 | [`0e61c53`](https://github.com/dheer629/kdash/tree/0e61c539ae8827c12d5028bcf61b3e6c104d7a6d) | FMEA worksheet, RBAC access review, S/O/D Action Priority, trends, site overrides and structured exports | [source commit](https://github.com/dheer629/kdash/tree/0e61c539ae8827c12d5028bcf61b3e6c104d7a6d) · [source archive](https://github.com/dheer629/kdash/archive/0e61c539ae8827c12d5028bcf61b3e6c104d7a6d.tar.gz) |
| 4.27.4 | `v4.27.4` | scoped OIDC helper cleanup, protected active login, persistent continue-without-login pause, issuer discovery hints | [release](https://github.com/dheer629/kdash/releases/tag/v4.27.4) |
| 4.27.3 | [`2834ee7`](https://github.com/dheer629/kdash/tree/2834ee72eb431f3cebaf6d10f2196e86c234c3a3) | runbooks (`R`, `--runbook`), instant check (`K`, `--check [--run N]`), OIDC login handling (`L`, exit 4), certificate and login expiry (`C`, `--certs`) | [source archive](https://github.com/dheer629/kdash/archive/2834ee72eb431f3cebaf6d10f2196e86c234c3a3.tar.gz) |
| 4.24.1 | [`04767fa`](https://github.com/dheer629/kdash/tree/04767faef0946e3b06ddec3574162bb2f6cfda4c) | certificate and login expiry (`C`, `-v certs`, `--certs`), header badge, scriptable exit codes | [source archive](https://github.com/dheer629/kdash/archive/04767faef0946e3b06ddec3574162bb2f6cfda4c.tar.gz) |
| 4.23.2 | [`396eda3`](https://github.com/dheer629/kdash/tree/396eda345e1b738de5972fb603dc0458c57decd0) | interactive mode from pod details and logs; responsive inspector toggle/quit and whole-line confirmation; separate current WSL evidence | [source archive](https://github.com/dheer629/kdash/archive/396eda345e1b738de5972fb603dc0458c57decd0.tar.gz) |
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
kdash --version                              # kdash 4.37.0
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
v=4.27.4
base=https://github.com/dheer629/kdash/releases/download/v$v
curl -fsSLO "$base/kdash-$v.tar.gz" -O "$base/SHA256SUMS"
sha256sum --ignore-missing -c SHA256SUMS      # must print: kdash-4.27.4.tar.gz: OK
tar -xzf "kdash-$v.tar.gz"
bash kdash-bundle.sh                           # installs to ~/.local/bin
kdash --version
```

For a source snapshot, download its archive or check out the exact commit above,
verify the checkout's `SHA256SUMS`, and run `bash kdash-bundle.sh` there.

To go back to an older published release, set `v` to that version and repeat. Installation
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
   `git tag -a v4.37.0 -m "kdash 4.37.0" && git push origin v4.37.0`.

Pushing the tag runs [.github/workflows/release.yml](.github/workflows/release.yml). It
validates the tree, packages that commit with `scripts/package-release.sh`, and creates
the Release. It refuses a tag that disagrees with the version inside `kdash`, and it
never replaces assets of a release that already exists.
After that release succeeds, add its actual download links to the release tables;
keep older version links and label old screenshots with their capture version.

To publish a version that was committed earlier (for example 4.12.0), run the workflow
manually (Actions -> Versioned downloads -> Run workflow) and enter its commit or tag.
To build the same files locally: `bash scripts/package-release.sh <commit-or-tag> dist`.
