# Pull request

## What this changes

<!-- One or two sentences. Link the issue it fixes: "Fixes #12". -->

## Why

<!-- The question the change answers, or the bug it removes. -->

## How it was tested

<!-- Paste the commands you ran and their result. -->

```bash
bash -n kdash kdash-bundle.sh kdash-uninstall.sh scripts/*.sh
bash tests/test-uninstall.sh
sed -n '347,5894p' kdash-bundle.sh > /tmp/payload && cmp /tmp/payload kdash
bash scripts/update-checksums.sh && sha256sum -c SHA256SUMS
```

## Checklist

- [ ] kdash stays read-only: no new `kubectl` verb that can change a cluster object
- [ ] no new runtime dependency (Bash 4+, `kubectl`, `awk`, coreutils only)
- [ ] works on busybox `awk` and on a plain terminal (`--glyphs ascii` in doubt)
- [ ] `kdash-bundle.sh` still embeds `kdash` byte for byte
- [ ] no environment data, credentials, host names, internal names or personal
      paths added - screenshots and evidence stay generic
- [ ] `CHANGELOG.md` updated under `Unreleased` when the change is user-visible
- [ ] checksums regenerated when a shipped file changed
