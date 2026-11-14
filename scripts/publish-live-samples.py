"""Finalize documentation from the successful live run after report publication."""
from pathlib import Path
import argparse
import shutil
import csv
import json
import re

root = Path(__file__).resolve().parent.parent
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--run', help='Run directory; defaults to artifacts/latest-e2e.txt')
parser.add_argument('--gallery', help='Terminal gallery directory relative to repository root')
parser.add_argument('--html-gallery', help='HTML gallery directory relative to repository root')
args = parser.parse_args()
run = (root / args.run).resolve() if args.run else root / 'artifacts' / (root / 'artifacts/latest-e2e.txt').read_text(encoding='utf8').strip()
if run.parent != root / 'artifacts':
    raise SystemExit('Run must be a direct child of artifacts/')
run_name = run.name
results = json.loads((run / 'results.json').read_text(encoding='utf8'))
if not results.get('completed') or results.get('status') != 'PASS' or results.get('failures'):
    raise SystemExit('Refusing to document a run that still has failures')
rows = list(csv.DictReader((run / 'captures.tsv').open(encoding='utf8'), delimiter='\t'))
if not rows:
    raise SystemExit('Run has no captures')
passed = sum(c['status']=='PASS' for c in results['checks'])
browser = json.loads((run / 'browser-results.json').read_text(encoding='utf8'))
assert browser['status'] == 'PASS'
browser_passed = sum(c['status']=='PASS' for c in browser['checks'])
secret_results_path = run / 'secrets' / 'results.json'
secret_results = json.loads(secret_results_path.read_text(encoding='utf8')) if secret_results_path.is_file() else {}
secret_captures = secret_results.get('captures', [])
image_description = f'**{len(rows) + len(secret_captures)} CLI terminal screenshots**'
version = results['version'].removeprefix('kdash ')
if not re.fullmatch(r'\d+\.\d+\.\d+', version):
    raise SystemExit(f'Invalid release version: {version}')
gallery_paths = {str(Path(row['png']).parent).replace('\\', '/') for row in rows}
if len(gallery_paths) != 1:
    raise SystemExit('Captures must share one terminal gallery directory')
gallery_path = args.gallery or gallery_paths.pop()
html_paths = {str(Path(row['file']).parent.parent).replace('\\', '/') for row in browser.get('screenshots', [])}
if len(html_paths) > 1:
    raise SystemExit('Browser screenshots must share one HTML gallery directory')
html_path = args.html_gallery or (html_paths.pop() if html_paths else 'samples/html' + version.replace('.', ''))

def gallery_directory(value):
    directory = (root / value).resolve()
    if directory.parent != root / 'samples':
        raise SystemExit(f'Gallery must be a direct child of samples/: {value}')
    directory.mkdir(exist_ok=True)
    return directory

gallery = gallery_directory(gallery_path)
html = gallery_directory(html_path)

def previous_galleries(pattern, current):
    links = []
    for readme in sorted((root / 'samples').glob(pattern)):
        if readme.parent == current:
            continue
        heading = readme.read_text(encoding='utf8').splitlines()[0]
        recorded = re.search(r'\b(\d+\.\d+\.\d+)\b', heading)
        label = recorded.group(1) if recorded else readme.parent.name
        links.append(f'[{label}](../{readme.parent.name}/README.md)')
    return ', '.join(links)

summary = f'Run `{run_name}` records **{passed} passed live checks**, **{browser_passed} passed browser checks** and {image_description}, with companion ANSI replays, from the installed kdash {version} in namespace `{results["namespace"]}`.'
src = '../../artifacts/' + run_name

t = f'''# kdash {version} live WSL terminal captures

{summary}
The original [results]({src}/results.json), [checks]({src}/checks.tsv),
[cluster inventory]({src}/inventory.json) and [capture manifest]({src}/captures.tsv)
retain the evidence behind each image. Context: `{results['context']}`.
The [browser results]({src}/browser-results.json) cover the generated report controls.

The published PNGs are faithful ANSI replays of live terminal captures. Native
xterm screenshots remain in the private validation workspace.
The operator identity, host and context are redacted for publication. Test workload
names and measured values are preserved.
The published audit-log bytes are redacted, so their original hash chain cannot
be verified from this public copy.

The companion replay PNGs render actual `tmux capture-pane -e -p` screens with
[`capture-terminal.py`](../../scripts/capture-terminal.py), using the dimensions in
the manifest. The dashboard supplied every value and character. These are faithful
terminal renders, separate from any private native screenshots. Text/ANSI sources
remain linked below so the visible result can be inspected and reproduced.

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
    if (root / row['png']).parent.resolve() != gallery:
        shutil.copy2(root / row['png'], gallery / png)
        (gallery / 'native').mkdir(exist_ok=True)
        shutil.copy2((root / row['png']).parent / native, gallery / native)
    # The native xterm grab is best-effort; link it only when the file exists.
    native_link = f'[native]({native}) / ' if (gallery / native).exists() else ''
    t += f'| {native_link}[ANSI replay]({png}) | {row["title"].replace("|", "/")} | {row["columns"]} x {row["rows"]} | [capture]({src}/{row["file"]}) |\n'
if secret_captures:
    t += '\n## Secrets map\n\n| Screenshot | Live screen | Geometry | ANSI source |\n|---|---|---|---|\n'
    for capture in secret_captures:
        image = Path(capture['png'])
        if image.is_absolute():
            image = image.relative_to(root)
        relative_image = image.relative_to(Path(gallery_path)).as_posix()
        assert (root / capture['png']).exists(), capture['png']
        t += (f'| [ANSI replay]({relative_image}) | {capture["title"].replace("|", "/")} | '
              f'{capture["columns"]} x {capture["rows"]} | '
              f'[capture]({src}/secrets/{capture["file"]}) |\n')
t += f'''
Verify the image bytes with `sha256sum -c SHA256SUMS` in this directory.
See the [generated HTML reports](../{html.name}/README.md), [sample index](../README.md)
and [operating guide](../../DEVOPS_USER_GUIDE.md) for workflows and coverage limits.
Earlier captures retain their original version: {previous_galleries('cli_*/README.md', gallery)}.
'''
(gallery / 'README.md').write_text(t,encoding='utf8',newline='\n')

shutil.copytree(run / 'reports', html, dirs_exist_ok=True,
                ignore=shutil.ignore_patterns('sessions', 'inspector', '*.lock'))
fmea_note = ''
if (run / 'logs/fmea-json.log').is_file():
    (html / 'fmea').mkdir(exist_ok=True)
    for source, target in [('csv-fmea.log', 'worksheet.csv'), ('tsv-fmea.log', 'worksheet.tsv'),
                           ('fmea-json.log', 'worksheet.json')]:
        shutil.copy2(run / 'logs' / source, html / 'fmea' / target)
    fmea_note = '\nFMEA has a separate static HTML worksheet and CSV, TSV and JSON exports in\n`fmea/`; it is separate from the namespace report tabs. The browser checks\ninclude its real worksheet rows and screenshot.\n'
secrets_note = ''
secrets_reports = run / 'secrets' / 'reports'
if secrets_reports.is_dir():
    shutil.copytree(secrets_reports, html / 'secrets', dirs_exist_ok=True,
                    ignore=shutil.ignore_patterns('sessions', 'inspector', '*.lock'))
    secrets_note = '\nThe Secrets map is a separate static HTML report under `secrets/`. Its live\n' \
                   'fixture and browser checks verify certificate metadata and workload usage;\n' \
                   'secret values and private-key material are not included.\n'
for screenshot in browser.get('screenshots', []):
    source = root / screenshot['file']
    target = html / 'screenshots' / source.name
    if source.resolve() != target.resolve():
        target.parent.mkdir(exist_ok=True)
        shutil.copy2(source, target)
t = f'''# kdash {version} live WSL HTML reports

The files in this directory come from the generated reports of
[`{run_name}`]({src}), running the installed kdash {version} against local WSL
Kubernetes. The [results]({src}/results.json) and [checks]({src}/checks.tsv)
record export validation; the [terminal gallery](../{gallery.name}/README.md) records
the corresponding live interface.
The operator identity, host and context are redacted; measured workload data is preserved.

The namespace report includes Overview, six resource tabs and recorded History.
CLI Alerts appear in the Overview; Services, Storage, Events and explanations are
preserved in the evidence bundle's diagnostic text/tables rather than extra
namespace HTML tabs. Missing metrics remain unavailable instead of becoming zero.
{fmea_note}
{secrets_note}
Reports are self-contained for local viewing and include table search/sort,
CSV/JSON export, themes, timezone selection and chart controls where data exists.

| File | Bytes |
|---|---:|
'''
for p in sorted(html.rglob('*')):
    if not p.is_file() or p.suffix.lower() not in ('.html','.csv','.tsv','.json','.png'):
        continue
    rel = p.relative_to(html).as_posix()
    t += f'| [{rel}]({rel}) | {p.stat().st_size} |\n'
t+=f'''
Verify the published bytes with `sha256sum -c SHA256SUMS` in this directory.
Keep the relative filenames together when sharing. Review operational metadata
before distributing reports. Historical reports retain their original capture
version: {previous_galleries('html*/README.md', html)}, [4.12.0](../html/).
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
        heading=re.search(r'^## Current [^\n]+ validation and visual changes\n', t, re.MULTILINE)
        if not heading:
            raise SystemExit('Operating guide is missing current-validation heading')
        t=t[:heading.start()]+f'## Current {version} validation and visual changes\n'+t[heading.end():]
        heading=re.search(r'^## Current [^\n]+ validation and visual changes\n', t, re.MULTILINE)
        idx=heading.end()
    else:
        idx=t.index('\n')+1
    prefix={'README.md':'artifacts/','DEVOPS_USER_GUIDE.md':'artifacts/','samples/README.md':'../artifacts/','artifacts/README.md':''}[name]
    text=f'\n{marker}\n{summary}\n[Inspect the recorded checks]({prefix}{run_name}/checks.tsv).\n<!-- END_CURRENT_LIVE_RESULT -->\n'
    t=t[:idx]+text+t[idx:]
    p.write_text(t,encoding='utf8',newline='\n')
print(summary)
