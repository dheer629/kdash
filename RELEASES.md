# Releases and downloads

Every kdash version is published as its own immutable GitHub Release, so you can
download the exact version you want, or an older one, at any time:
<https://github.com/dheer629/kdash/releases>

| Version | Tag | What it adds |
|---|---|---|
| 4.13.1 | `v4.13.1` | installer summary names every view and key (no code change to the CLI) |
| 4.13.0 | `v4.13.0` | doctor, inspector, command palette, Events and explanations, services, storage, `-A` fix, inspector find/containers/export |
| 4.12.0 | `v4.12.0` | ALERTS view (kept for reference; the `-A` limitation applies) |

## What each release contains

| File | Purpose |
|---|---|
| `kdash` | the whole CLI, one Bash file |
| `kdash-bundle.sh` | installer (embeds `kdash` byte for byte) |
| `kdash-uninstall.sh` | standalone uninstaller |
| `README.md`, `LICENSE` | documentation and licence for that version |
| `kdash-<version>.tar.gz` | all of the above in one archive |
| `SHA256SUMS` | checksums of every file in the release |

## Download and verify a specific version

```bash
v=4.13.0
base=https://github.com/dheer629/kdash/releases/download/v$v
curl -fsSLO "$base/kdash-$v.tar.gz" -O "$base/SHA256SUMS"
sha256sum --ignore-missing -c SHA256SUMS      # must print: kdash-4.13.0.tar.gz: OK
tar -xzf "kdash-$v.tar.gz"
bash kdash-bundle.sh                           # installs to ~/.local/bin
kdash --version
```

To go back to an older version, set `v` to that version and repeat. The installer
moves a different kdash aside rather than deleting it, and `bash kdash-uninstall.sh`
removes the install.

## How a version is published (maintainer)

1. Change the code in `src/`, then `bash scripts/build.sh` (this rewrites `kdash` and
   `kdash-bundle.sh`; never edit the generated region by hand).
2. Raise `KDASH_VERSION` in `kdash`, then run `bash scripts/build.sh` again so the
   installer reports the same version.
3. `bash scripts/update-checksums.sh`, then `bash scripts/validate-all.sh`.
4. Commit, open a pull request, merge to `main`.
5. Tag the merge commit: `git tag -a v4.13.0 -m "kdash 4.13.0" && git push origin v4.13.0`.

Pushing the tag runs [.github/workflows/release.yml](.github/workflows/release.yml). It
validates the tree, packages that commit with `scripts/package-release.sh`, and creates
the Release. It refuses a tag that disagrees with the version inside `kdash`, and it
never replaces assets of a release that already exists.

To publish a version that was committed earlier (for example 4.12.0), run the workflow
manually (Actions -> Versioned downloads -> Run workflow) and enter its commit or tag.
To build the same files locally: `bash scripts/package-release.sh <commit-or-tag> dist`.
