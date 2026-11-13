#!/usr/bin/env python3
"""Verify README links and that current screenshots came from this installed CLI.

This validates saved evidence without connecting to a cluster. It does not turn a
historical run into a new live test: source and installed hashes must match the
current checkout, and a successful, completed live run must already be present.
Only Python's standard library is required.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
from pathlib import Path
import re
import struct
import subprocess
import sys
from urllib.parse import unquote, urlsplit


class PublicationError(ValueError):
    pass


def require(condition: bool, message: str) -> None:
    if not condition:
        raise PublicationError(message)


def within(base: Path, relative: str) -> Path:
    """Resolve a published relative path, rejecting absolute paths and traversal."""
    name = Path(relative)
    require(not name.is_absolute(), f"absolute evidence path: {relative}")
    path = (base / name).resolve()
    require(path.is_relative_to(base.resolve()), f"evidence path escapes its directory: {relative}")
    return path


def utf8(path: Path) -> str:
    try:
        text = path.read_text(encoding="utf-8")
    except (OSError, UnicodeError) as ex:
        raise PublicationError(f"cannot read UTF-8 file {path}: {ex}") from ex
    require("\ufffd" not in text, f"replacement character in {path}")
    return text


def readmes(repo: Path) -> list[Path]:
    found = subprocess.run(
        ["git", "ls-files", "-z", "--cached", "--others", "--exclude-standard"],
        cwd=repo, check=True, stdout=subprocess.PIPE,
    ).stdout.decode("utf-8").split("\0")
    return sorted({repo / name for name in found if name and Path(name).name.lower() == "readme.md"})


def markdown_targets(text: str):
    # Current documentation uses ordinary inline destinations and HTML image
    # sources. Accept angle-bracket destinations and optional link titles too.
    for match in re.finditer(r"!?\[[^\]]*\]\(\s*(<[^>]+>|[^\s)]+)(?:\s+[^)]*)?\)", text):
        yield match.group(1).strip("<>")
    for match in re.finditer(r"<img\b[^>]*?\bsrc\s*=\s*([\"'])(.*?)\1", text, re.IGNORECASE | re.DOTALL):
        yield match.group(2)
    for match in re.finditer(r"^\s*\[[^\]]+\]:\s*(<[^>]+>|\S+)", text, re.MULTILINE):
        yield match.group(1).strip("<>")


def validate_readmes(repo: Path) -> tuple[int, int]:
    documents = readmes(repo)
    require(bool(documents), "no README.md files found")
    count = 0
    failures = []
    for document in documents:
        for target in markdown_targets(utf8(document)):
            parsed = urlsplit(target)
            if parsed.scheme or parsed.netloc or not parsed.path:
                continue
            path = (document.parent / unquote(parsed.path)).resolve()
            if not path.exists():
                failures.append(f"{document.relative_to(repo)}: missing {target}")
            count += 1
    require(not failures, "broken README references:\n  " + "\n  ".join(failures))
    return len(documents), count


def table(path: Path) -> list[dict[str, str]]:
    with path.open(encoding="utf-8", newline="") as source:
        return list(csv.DictReader(source, delimiter="\t"))


def validate_png(path: Path) -> None:
    require(path.is_file(), f"missing screenshot {path}")
    data = path.read_bytes()
    require(len(data) >= 24 and data[:8] == b"\x89PNG\r\n\x1a\n", f"invalid PNG {path}")
    width, height = struct.unpack(">II", data[16:24])
    require(width > 0 and height > 0, f"empty PNG geometry {path}")


def validate_e2e(repo: Path) -> tuple[str, str, int, int]:
    pointer = utf8(repo / "artifacts/latest-e2e.txt").strip()
    require(bool(pointer) and len(Path(pointer).parts) == 1, "latest-e2e must name one run directory")
    run = within(repo / "artifacts", pointer)
    require(run.is_dir(), f"missing current live run {pointer}")
    require(utf8(run / "status.txt").strip() == "DONE", "current live run did not finish successfully")
    covered = set()
    for line in utf8(run / "SHA256SUMS").splitlines():
        digest, relative = line.split("  ", 1)
        file = within(run, relative)
        require(file.is_file() and hashlib.sha256(file.read_bytes()).hexdigest() == digest,
                f"live evidence checksum differs: {relative}")
        covered.add(file)
    actual = {p.resolve() for p in run.rglob("*") if p.is_file() and p != run / "SHA256SUMS"}
    require(covered == actual, "live checksum manifest does not cover the entire evidence directory")
    results = json.loads(utf8(run / "results.json"))
    require(results.get("status") == "PASS", "current live results are incomplete or failed")
    require(results.get("failures") == [], "current live run has failures or no failure summary")
    require(results.get("phase", "all") == "all", "current evidence must include CLI and interactive checks")

    cli = (repo / "kdash").read_bytes()
    versions = re.findall(rb'^KDASH_VERSION="([^"]+)"\r?$', cli, re.MULTILINE)
    require(len(versions) == 1, "CLI must declare exactly one version")
    version = versions[0].decode("ascii")
    require(results.get("version") in (version, "kdash " + version), "live evidence version differs from the CLI")
    source_sha = hashlib.sha256(cli).hexdigest()
    for key in ("sha256", "installed_sha256", "binary_sha256", "capture_source_sha256"):
        require(results.get(key) == source_sha, f"live {key} differs from the current CLI")

    checks = results.get("checks", [])
    require(bool(checks) and all(c.get("status") == "PASS" for c in checks), "live checks are empty or not all passing")
    names = [c["name"] for c in checks]
    require(len(names) == len(set(names)), "duplicate live check names")
    require("installed-source-identical" in names, "no installed/source identity assertion")
    recorded = table(run / "checks.tsv")
    require([(c["check"], c["status"]) for c in recorded] == [(c["name"], c["status"]) for c in checks],
            "checks.tsv disagrees with results.json")
    require((run / "inventory.json").is_file(), "missing real cluster inventory")
    require(bool(json.loads(utf8(run / "inventory.json"))), "cluster inventory is empty")
    inventory = json.loads(utf8(run / "inventory.json"))
    claim_states = {o.get("status", {}).get("phase") for o in inventory if o.get("kind") == "PersistentVolumeClaim"}
    require({"Bound", "Pending"}.issubset(claim_states), "live storage coverage lacks Bound and Pending claims")
    require(re.search(r"metrics[= ]available", utf8(run / "logs/view-pods.log")), "live CPU/memory metrics were unavailable")
    io = utf8(run / "logs/view-io.log")
    require(bool(re.search(r"namespace\s+in\s+\d", io)) and "rates between the last two samples" in io,
            "live I/O validation lacks measured two-sample rates")

    captures = results.get("captures", [])
    manifest = table(run / "captures.tsv")
    require(bool(captures) and len(captures) == len(manifest), "empty or inconsistent capture manifest")
    indexed = {c["file"]: c for c in captures}
    require(len(indexed) == len(captures), "duplicate capture paths")
    pngs = set()
    galleries = set()
    for row in manifest:
        require(row["file"] in indexed, f"unverified manifest capture {row['file']}")
        capture = indexed[row["file"]]
        for key in ("file", "columns", "rows", "title", "png"):
            require(str(row[key]) == str(capture[key]), f"manifest metadata differs for {row['file']}: {key}")
        require(1 <= int(row["columns"]) <= 1000 and 1 <= int(row["rows"]) <= 1000,
                f"invalid terminal geometry: {row['file']}")
        ansi = within(run, row["file"])
        require(ansi.suffix == ".ansi", f"unexpected capture extension: {row['file']}")
        require(ansi.is_file() and ansi.stat().st_size > 0, f"missing or empty ANSI screen {ansi}")
        require(hashlib.sha256(ansi.read_bytes()).hexdigest() == capture.get("sha256"),
                f"raw capture SHA-256 differs: {row['file']}")
        utf8(ansi)
        plain = ansi.with_suffix(".txt")
        require(bool(utf8(plain).strip()), f"empty plain-text capture {plain}")
        png = within(repo, row["png"])
        require(png.is_relative_to(repo / "samples"), f"screenshot is outside samples: {row['png']}")
        require(png not in pngs, f"duplicate screenshot target: {row['png']}")
        validate_png(png)
        native_rel = capture.get("native_png")
        if native_rel:
            native = within(repo, native_rel)
            require(native.is_relative_to(repo / "samples"), "native screenshot outside sample gallery")
            validate_png(native)
            require(hashlib.sha256(native.read_bytes()).hexdigest() == capture.get("native_sha256"),
                    f"native screenshot SHA-256 differs: {row['file']}")
        pngs.add(png)
        galleries.add(png.parent)
    actual_pngs = {p.resolve() for gallery in galleries for p in gallery.glob("*.png")}
    require(actual_pngs == pngs, "gallery PNG files differ from the current capture manifest")
    actual_ansi = {p.resolve() for p in (run / "raw").glob("*.ansi")}
    expected_ansi = {within(run, c["file"]) for c in captures}
    require(actual_ansi == expected_ansi, "raw ANSI files differ from the capture manifest")
    if tuple(int(n) for n in version.split('.')) >= (4, 23, 2):
        required = {
            '75-detail-shell-blocked': 'interactive actions are off',
            '76-detail-confirmation': 'Enter confirms',
            '77-detail-cancel': 'READ-ONLY',
            '78-detail-interactive-on': 'INTERACTIVE / audited',
            '79-detail-shell': 'uid=',
            '80-detail-interactive-off': 'READ-ONLY',
            '81-detail-shell-blocked-again': 'interactive actions are off',
            '82-mode-confirmation-80col': 'Enter confirms',
            # The dashboard keeps the mode in its status line; the uppercase word
            # only ever appeared in static help text, which proves nothing.
            '83-mode-enabled-80col': 'interactive mode ON',
        }
        for name, text in required.items():
            require(text in utf8(run / 'raw' / (name + '.txt')), f'mode-switch evidence missing: {name}')
        require(bool(re.search(r'PASS: [0-9]+ mode-switch terminal checks', utf8(run / 'mode-regression.log'))),
                'mode-switch corner-case regression was not recorded')
    if tuple(int(n) for n in version.split('.')) >= (4, 27, 4):
        toolkit = {'certs', 'check-summary', 'check-run-finding', 'check-run-read-commands-only',
                   'runbook-real-node-inventory', 'runbook-topic-cycle', 'check-ui-real-findings'}
        toolkit.update('runbook-' + topic for topic in
                       ('etcd-restore', 'cert-rotate', 'node-notready', 'api-unreachable', 'oidc-login'))
        require(toolkit.issubset(names), 'live certificate/runbook/check coverage is incomplete')
        for name, text in {'84-certs': 'EXPIRES UTC', '85-runbook': 'RUNBOOK - etcd-restore',
                           '86-check': 'CHECK NOW', '87-runbook-topic': 'RUNBOOK - cert-rotate'}.items():
            require(text in utf8(run / 'raw' / (name + '.txt')), f'toolkit evidence missing: {name}')
        for file, pattern in [('login-cleanup-regression.log', r'PASS: [0-9]+ login-cleanup checks'),
                              ('login-flow-regression.log', r'PASS: [0-9]+ login-flow PTY checks')]:
            require(bool(re.search(pattern, utf8(run / file))), f'login regression was not recorded: {file}')
    if tuple(int(n) for n in version.split('.')) >= (4, 28, 1):
        require({'fmea-summary', 'csv-fmea', 'tsv-fmea', 'fmea-json', 'fmea-json-real-rows',
                 'fmea-html', 'fmea-access', 'fmea-fail-on-high', 'fmea-trend',
                 'fmea-real-finding-selected', 'fmea-run-finding', 'fmea-run-read-commands-only'}.issubset(names),
                'live FMEA coverage is incomplete')
        for name, text in {'88-fmea': 'WORKSHEET', '89-access': 'PERMISSIONS',
                           '90-fmea-kind': 'showing kind', '91-fmea-sort': 'WORKSHEET'}.items():
            require(text in utf8(run / 'raw' / (name + '.txt')), f'FMEA evidence missing: {name}')
        require(bool(re.search(r'PASS: [0-9]+ FMEA (?:fixture )?checks', utf8(run / 'fmea-regression.log'))),
                'FMEA regression was not recorded')
    browser = json.loads(utf8(run / "browser-results.json"))
    require(browser.get("status") == "PASS" and browser.get("source_sha256") == source_sha,
            "browser validation failed or tested another CLI")
    require(browser.get("checks") and all(c.get("status") == "PASS" for c in browser["checks"]),
            "browser functionality checks incomplete")
    report = within(run, browser["report"])
    require(hashlib.sha256(report.read_bytes()).hexdigest() == browser["report_sha256"], "tested HTML report changed")
    for extra in browser.get('additional_reports', []):
        require(hashlib.sha256(within(run, extra['report']).read_bytes()).hexdigest() == extra['sha256'],
                'additional tested HTML report changed')
    if tuple(int(n) for n in version.split('.')) >= (4, 28, 1):
        require('html-fmea-real-rows' in {c['name'] for c in browser['checks']} and browser.get('additional_reports'),
                'FMEA HTML browser coverage is missing')
    for shot in browser["screenshots"]:
        file = within(repo, shot["file"])
        validate_png(file)
        require(hashlib.sha256(file.read_bytes()).hexdigest() == shot["sha256"], "browser screenshot bytes changed")
    return pointer, version, len(checks), len(actual_pngs)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, default=Path(__file__).resolve().parent.parent)
    args = parser.parse_args()
    repo = args.repo.resolve()
    try:
        documents, links = validate_readmes(repo)
        run, version, checks, pngs = validate_e2e(repo)
    except (PublicationError, OSError, ValueError, KeyError, TypeError, subprocess.CalledProcessError) as ex:
        print(f"FAIL  publication: {ex}", file=sys.stderr)
        return 1
    print(f"PASS  {documents} README files: {links} local links/image references resolve")
    print(f"PASS  kdash {version}: {run}, {checks} checks, {pngs} verified live screenshots; source and installed SHA-256 match")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
