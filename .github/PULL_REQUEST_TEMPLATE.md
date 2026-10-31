# Pull request

## What this changes

<!-- One or two sentences. Link the issue it fixes: "Fixes #12". -->

## Why

<!-- The question the change answers, or the bug it removes. -->

## How it was tested

<!-- Paste the commands you ran and their result. -->

```bash
bash scripts/build.sh --check
bash scripts/update-checksums.sh
KDASH_VALIDATE_ALLOW_DIRTY=1 bash scripts/validate-all.sh
```

## Checklist

- [ ] kdash stays read-only by default; `exec` / `cp` require interactive opt-in and are audited
- [ ] no new mandatory runtime dependency; optional transfer tools have fallbacks
- [ ] works on busybox `awk` and on a plain terminal (`--glyphs ascii` in doubt)
- [ ] `kdash-bundle.sh` still embeds `kdash` byte for byte
- [ ] source modules, standalone uninstaller and embedded versions stay synchronized
- [ ] no environment data, credentials, host names, internal names or personal
      paths added - screenshots and evidence stay generic
- [ ] `CHANGELOG.md` updated under `Unreleased` when the change is user-visible
- [ ] checksums regenerated when a shipped file changed
