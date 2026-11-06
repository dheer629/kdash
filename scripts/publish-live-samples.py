"""Finalize documentation from the successful live run after report publication."""
from pathlib import Path
import shutil
import csv
import json

root = Path(__file__).resolve().parent.parent
run_name = (root / 'artifacts/latest-e2e.txt').read_text(encoding='utf8').strip()
run = root / 'artifacts' / run_name
results = json.loads((run / 'results.json').read_text(encoding='utf8'))
if results.get('failures'):
    raise SystemExit('Refusing to document a run that still has failures')
rows = list(csv.DictReader((run / 'captures.tsv').open(encoding='utf8'), delimiter='\t'))
passed = sum(c['status']=='PASS' for c in results['checks'])
browser = json.loads((run / 'browser-results.json').read_text(encoding='utf8'))
assert browser['status'] == 'PASS'
browser_passed = sum(c['status']=='PASS' for c in browser['checks'])
version = results['version'].removeprefix('kdash ')
assert version == '4.23.1', version
summary = f'Run `{run_name}` records **{passed} passed live checks**, **{browser_passed} passed browser checks** and **{len(rows)} native WSL terminal screenshots**, with companion ANSI replays, from the installed kdash {version} in namespace `{results["namespace"]}`.'
src = '../../artifacts/' + run_name

t = f'''# kdash {version} live WSL terminal captures

{summary}
The original [results]({src}/results.json), [checks]({src}/checks.tsv),
[cluster inventory]({src}/inventory.json) and [capture manifest]({src}/captures.tsv)
retain the evidence behind each image. Context: `{results['context']}`.
The [browser results]({src}/browser-results.json) cover the generated report controls.

The `native/` images are actual xterm window screenshots taken while this installed
CLI runs in WSL on a private local Xvfb display. Companion images replay the saved
ANSI screen cell by cell. `results.json` records both image provenance and raw
capture hashes. Actual local namespace names and measurements are unchanged.

The companion replay PNGs render actual `tmux capture-pane -e -p` screens with
[`capture-terminal.py`](../../scripts/capture-terminal.py), using the dimensions in
the manifest. The dashboard supplied every value and character. These are faithful
terminal renders, separate from the native window screenshots. Text/ANSI sources remain linked
below so the visible result can be inspected and reproduced.

The dedicated local `kdash-e2e` namespace contains real workload and diagnostic
cases. The run exercises views, filters, pickers, inspector and logs, interactive
shell/file actions, formatting modes and exports; the check list records what was
asserted. A capture proves the visible screen at that moment, while action and byte
checks establish outcomes. Unknown or unavailable measurements remain visible.

| Screenshot | Live screen | Geometry | ANSI source |
|---|---|---|---|
'''
for row in rows:
    png = Path(row['png']).name
    native = 'native/' + png
    assert (root / row['png']).exists(), row['png']
    t += f'| [native]({native}) / [ANSI replay]({png}) | {row["title"].replace("|", "/")} | {row["columns"]} x {row["rows"]} | [capture]({src}/{row["file"]}) |\n'
t += '''
Verify the image bytes with `sha256sum -c SHA256SUMS` in this directory.
See the [generated HTML reports](../html423/README.md), [sample index](../README.md)
and [operating guide](../../DEVOPS_USER_GUIDE.md) for workflows and coverage limits.
Earlier captures retain their original version in [4.19.2](../cli_419/README.md),
[4.14.0](../cli_414/README.md) and [4.13.1](../cli_413/README.md).
'''
(root / 'samples/cli_423/README.md').write_text(t,encoding='utf8',newline='\n')

html = root / 'samples/html423'
html.mkdir(exist_ok=True)
shutil.copytree(run / 'reports', html, dirs_exist_ok=True,
                ignore=shutil.ignore_patterns('sessions', 'inspector', '*.lock'))
t = f'''# kdash {version} live WSL HTML reports

The files in this directory come from the generated reports of
[`{run_name}`]({src}), running the installed kdash {version} against local WSL
Kubernetes. The [results]({src}/results.json) and [checks]({src}/checks.tsv)
record export validation; the [terminal gallery](../cli_423/README.md) records
the corresponding live interface.

The namespace report includes Overview, six resource tabs and recorded History.
CLI Alerts appear in the Overview; Services, Storage, Events and explanations are
preserved in the evidence bundle's diagnostic text/tables rather than extra
namespace HTML tabs. Missing metrics remain unavailable instead of becoming zero.
Reports are self-contained for local viewing and include table search/sort,
CSV/JSON export, themes, timezone selection and chart controls where data exists.

| File | Bytes |
|---|---:|
'''
for p in sorted(html.rglob('*')):
    if not p.is_file() or p.suffix.lower() not in ('.html','.csv','.png'):
        continue
    rel = p.relative_to(html).as_posix()
    t += f'| [{rel}]({rel}) | {p.stat().st_size} |\n'
t+='''
Verify the published bytes with `sha256sum -c SHA256SUMS` in this directory.
Keep the relative filenames together when sharing. Review operational metadata
before distributing reports. Historical [4.19.2 reports](../html419/README.md)
and [4.12.0 reports](../html/) retain their original capture version.
'''
(html / 'README.md').write_text(t,encoding='utf8',newline='\n')

for name in ('README.md','DEVOPS_USER_GUIDE.md','samples/README.md','artifacts/README.md'):
    p=root/name
    t=p.read_text(encoding='utf8')
    marker='<!-- CURRENT_LIVE_RESULT -->'
    if marker in t:
        start=t.index(marker)
        end=t.index('<!-- END_CURRENT_LIVE_RESULT -->',start)+len('<!-- END_CURRENT_LIVE_RESULT -->')
        t=t[:start]+t[end:]
    if name=='README.md':
        idx=t.index('## Screenshots\n')+len('## Screenshots\n')
    elif name=='DEVOPS_USER_GUIDE.md':
        title='## Current 4.23.1 validation and visual changes\n'
        idx=t.index(title)+len(title)
    else:
        idx=t.index('\n')+1
    prefix={'README.md':'artifacts/','DEVOPS_USER_GUIDE.md':'artifacts/','samples/README.md':'../artifacts/','artifacts/README.md':''}[name]
    text=f'\n{marker}\n{summary}\n[Inspect the recorded checks]({prefix}{run_name}/checks.tsv).\n<!-- END_CURRENT_LIVE_RESULT -->\n'
    t=t[:idx]+text+t[idx:]
    p.write_text(t,encoding='utf8',newline='\n')
print(summary)
