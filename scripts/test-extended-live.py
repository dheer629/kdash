#!/usr/bin/env python3
"""Serial live checks for the search, log, export and rendering additions in 4.37.

Uses the existing kdash-e2e fixtures. No cluster resources are changed. Native
xterm screenshots and their ANSI captures are saved with the checked output.
--merge-to appends successful extension evidence to a matching baseline run.
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import stat
import tempfile


def merge(base: Path, output: Path):
    target = base / "results.json"
    data = json.loads(target.read_text())
    extension = json.loads((output / "results.json").read_text())
    if extension["status"] != "PASS" or not extension["completed"]:
        raise RuntimeError("refusing to merge an incomplete or failing extension")
    if data["sha256"] != extension["sha256"] or data["version"] != extension["version"]:
        raise RuntimeError("extension and baseline must test identical source bytes")
    prefix = output.relative_to(base).as_posix()
    data["checks"] = [c for c in data["checks"] if c.get("extension_source") != prefix]
    data["captures"] = [c for c in data["captures"] if c.get("extension_source") != prefix]
    for item in extension["checks"]:
        data["checks"].append({**item, "extension_source": prefix})
    for item in extension["captures"]:
        # The publication checker intentionally inventories the baseline raw/
        # directory. Keep the original extension evidence and copy these uniquely
        # numbered captures there so the unified manifest remains self-contained.
        for source in (output / item["file"], (output / item["file"]).with_suffix(".txt")):
            dest = base / "raw" / source.name
            if dest.exists() and dest.read_bytes() != source.read_bytes():
                raise RuntimeError(f"capture name collision: {dest}")
            shutil.copyfile(source, dest)
        data["captures"].append({**item, "file": "raw/" + Path(item["file"]).name, "extension_source": prefix})
    data["failures"] = [c["name"] for c in data["checks"] if c["status"] != "PASS"]
    data["status"] = "FAIL" if data["failures"] else "PASS" if data["completed"] else "RUNNING"
    data.setdefault("extensions", {})[prefix] = {
        "results": prefix + "/results.json",
        "sha256": hashlib.sha256((output / "results.json").read_bytes()).hexdigest(),
        "checks": len(extension["checks"]), "captures": len(extension["captures"]),
    }
    target.write_text(json.dumps(data, indent=2) + "\n")
    (base / "checks.tsv").write_text("check\tstatus\tdetail\n" + "".join(
        f'{c["name"]}\t{c["status"]}\t{c["detail"].replace(chr(9), " ").replace(chr(10), " ")}\n'
        for c in data["checks"]))
    (base / "captures.tsv").write_text("file\tcolumns\trows\ttitle\tpng\n" + "".join(
        f'{c["file"]}\t{c["columns"]}\t{c["rows"]}\t{c["title"]}\t{c["png"]}\n'
        for c in data["captures"]))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, default=Path(__file__).resolve().parent.parent)
    parser.add_argument("--binary", default="~/.local/bin/kdash")
    parser.add_argument("--context", default="kdash-local")
    parser.add_argument("--namespace", default="kdash-e2e")
    parser.add_argument("--output", type=Path)
    parser.add_argument("--gallery", default="samples/cli_4370")
    parser.add_argument("--native-screenshots", action="store_true")
    parser.add_argument("--require-rotated", action="store_true", help="fail unless a real rotated container log is read")
    parser.add_argument("--merge-to", type=Path)
    args = parser.parse_args()
    # Preserve the public /workspace/kdash mount alias in exported paths.
    args.repo = Path(os.path.abspath(args.repo))
    args.output = Path(os.path.abspath(args.output or args.repo / "artifacts/live-e2e-v4370/extended"))
    args.phase = "extended"; args.no_render = False; args.workers = 1
    spec = importlib.util.spec_from_file_location("kdash_live_e2e", args.repo / "scripts/live-e2e.py")
    module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
    live = module.LiveE2E(args)
    live.env.update(KDASH_LOGIN_CHECK="0", KDASH_CERT_CHECK="0",
                    KDASH_LOG_TAIL="20", KDASH_LOG_TIMEOUT="30")
    # POSIX modes cannot be measured on the Windows 9p checkout (it reports
    # every file as 0777). Verify the real umask on WSL's native filesystem,
    # then copy the tested bytes to the public evidence directory.
    native_exports = tempfile.TemporaryDirectory(prefix="kdash-extended-exports-", dir="/var/tmp")
    exports = Path(native_exports.name)
    live.env["KDASH_EXPORT_DIR"] = str(exports)
    finished = False
    screenshot = 100

    def record(name, passed, detail=""):
        live.record("extended-" + name, passed, detail)

    def capture(session, name, title, expect=None):
        nonlocal screenshot
        live.capture(session, str(screenshot) + "-" + name, title, expect)
        screenshot += 1

    def scenario(name, action):
        try:
            action()
        except Exception as error:
            record(name + "-exception", False, str(error))

    def exported(session, name, tokens, title=None):
        before = set(exports.glob("kdash_*.log")) if exports.exists() else set()
        live.key(session, ">", delay=2)
        after = set(exports.glob("kdash_*.log"))
        created = sorted(p for p in after - before if not p.name.startswith("kdash_session_"))
        body = created[-1].read_text() if created else ""
        passed = bool(created) and all(token in body for token in tokens) and "\x1b" not in body
        passed = passed and stat.S_IMODE(created[-1].stat().st_mode) == 0o600
        record("quick-export-" + name, passed,
               "reports/exports/" + created[-1].name if created else "no new export file")
        if title:
            capture(session, "export-" + name, title, "exported to")
        return body

    def open_detail(name="extended-detail", pod=None, container="app"):
        session = live.start_dashboard(name, extra=("--container", container, "--no-io"))
        live.key(session, "Enter", delay=2)
        live.wait(session, "SELECT POD")
        live.key(session, "/")
        live.text(session, pod or live.pod)
        live.key(session, "Enter", delay=3)
        live.wait(session, "SUMMARY|CONDITIONS")
        return session

    def dashboard_search():
        s = live.start_dashboard("extended-search", extra=("--no-io",))
        live.key(s, "/")
        live.text(s, "app-server", enter=False, delay=2)
        body = live.screen(s)
        record("dashboard-live-search", "matching line" in body and "app-server" in body,
               "in-place find counts matching lines before Enter")
        capture(s, "dashboard-search", "In-place dashboard search counts real matching lines", "matching line")
        live.key(s, "Enter", "n", "N", delay=2)
        record("dashboard-search-navigation", "matching line" in live.screen(s) and "SELECT NAMESPACE" not in live.screen(s),
               "n/N retain the search and navigate matches")
        live.key(s, "3", delay=2)
        capture(s, "search-other-view", "Search retained while switching to live workloads", "matching line")
        exported(s, "searched-workloads", ("THE WHOLE WORKLOADS VIEW", "app-server", "# end of export"),
                 "Quick export includes the screen and every workload line")
        live.key(s, "Escape", "1", "/")
        live.text(s, "[", enter=False, delay=1)
        capture(s, "invalid-search", "Invalid search expressions remain editable", "not a valid pattern")
        live.key(s, "C-u")
        live.text(s, "no-such-kdash-pod-4370", enter=False)
        capture(s, "search-no-match", "A valid unmatched search reports zero matching lines", "0 matching lines")
        live.key(s, "Escape", "/", "Tab")
        live.text(s, "app-server", delay=2)
        exported(s, "pod-filter", ("app-server", "pod filter app-server"))
        live.key(s, "/", "Tab")
        live.text(s, "", delay=2)
        live.key(s, "Q")

    def prompt_editor():
        s = live.start_dashboard("extended-edit", extra=("--no-io",))
        live.key(s, "/")
        live.text(s, "app-serer", enter=False)
        live.key(s, "Left", "Left")
        live.tm("send-keys", "-l", "-t", s, "v")
        live.key(s, "End", "Enter", delay=2)
        body = live.screen(s)
        record("line-editor-insert-arrow", "app-server" in body and "matching line" in body,
               "Left inserts a missing character inside the live search")
        exported(s, "editor-insertion", ("search /app-server", "app-server"))
        # Pace the keys: one write containing Esc followed by other keys can be
        # decoded as an Alt sequence by the terminal editor, and cursor keys sent
        # in the same write can be consumed before the repaint that follows them.
        live.key(s, "Escape", delay=1)
        live.key(s, "/", delay=1)
        live.key(s, "Up", delay=1)
        capture(s, "search-history", "Shared editor recalls this session's earlier search", "app-server")
        live.text(s, "xapp-serverz", enter=False)
        live.key(s, "Home", delay=1)
        live.key(s, "Delete", delay=1)
        live.key(s, "End", delay=1)
        live.key(s, "BSpace", delay=1)
        capture(s, "search-editor-delete", "Cursor Home/Delete/End/Backspace leaves the intended search text", "app-server")
        live.key(s, "Enter", delay=1)
        exported(s, "editor-delete", ("search /app-server", "app-server"))
        live.key(s, "Escape", "Q")

    def dashboard_exports():
        s = live.start_dashboard("extended-exports", extra=("--no-io",))
        views = [("1", "PODS"), ("2", "NODE POOLS"), ("3", "WORKLOADS"), ("4", "IP POOL"),
                 ("5", "MEMORY"), ("6", "NET & DISK IO"), ("7", "ALERTS"), ("8", "SERVICES"),
                 ("9", "STORAGE"), ("E", "EVENTS"), ("!", "WHY"), ("C", "CERTIFICATES"),
                 ("R", "RUNBOOKS"), ("K", "CHECK NOW"), ("M", "FMEA"), ("Y", "SECRETS MAP")]
        for key, view in views:
            live.key(s, key, delay=3)
            exported(s, "view-" + key.replace("!", "explain"), ("THE WHOLE " + view + " VIEW", "# end of export"))
        live.key(s, ":")
        live.text(s, "access", delay=4)
        exported(s, "access", ("THE WHOLE ACCESS VIEW", "# end of export"),
                 "Access view exports its complete permission review")
        live.key(s, "1", "n", delay=2)
        exported(s, "namespaces", ("THE WHOLE NAMESPACE LIST", args.namespace),
                 "Namespace picker quick export retains every namespace name")
        live.key(s, "q", "Enter", delay=2)
        exported(s, "pods", ("THE WHOLE POD LIST", live.pod),
                 "Pod picker quick export retains full names and resource columns")
        live.key(s, "q", "Q")

    def logs_and_containers():
        s = open_detail()
        exported(s, "summary", ("THE WHOLE SUMMARY PANE", "CONDITIONS"))
        live.key(s, "c", delay=2)
        live.wait(s, "SELECT CONTAINER")
        live.key(s, "/")
        live.text(s, "sidecar", enter=False)
        capture(s, "container-find", "Container picker finds a real sidecar by name", "sidecar")
        live.key(s, "Enter")
        exported(s, "containers", ("EVERY CONTAINER OF THE POD", "sidecar", "app"),
                 "Container picker exports every regular container and image")
        live.key(s, "q", "l", delay=3)
        live.wait(s, "INFO request")
        live.key(s, "A", delay=4)
        capture(s, "whole-log-coverage", "Whole current log displays read coverage and node proxy capability", "current file|whole log")
        body = exported(s, "current-log", ("THE WHOLE CURRENT PANE", "INFO request"))
        record("log-coverage-truthful", bool(re.search(r"read:.*(?:current file|whole log|INCOMPLETE)", body)),
               "export retains the actual coverage result; rotated files counted only when read")
        rotated = bool(re.search(r"whole log: [1-9][0-9]* rotated file", body))
        record("real-rotated-log-read", rotated or not args.require_rotated,
               "actual node-proxy read reports a positive rotated-file count" if rotated else
               "no rotated file read; --require-rotated makes this a coverage failure")
        live.key(s, "/", delay=3)
        live.text(s, "warn", enter=False, delay=2)
        capture(s, "log-find-in-place", "Whole log search counts case-insensitive real warnings", "warn|WARN")
        live.key(s, "Enter", "n", "N", delay=1)
        live.key(s, ">", delay=1)
        live.key(s, "&", delay=1)
        live.text(s, "warn", delay=2)
        body = exported(s, "matching-log", ("only matching lines", "WARN request"))
        record("only-matches-export", "INFO request=" not in body.split("THE WHOLE CURRENT PANE")[-1],
               "whole-pane export follows the chosen matching-lines filter")
        live.key(s, "/")
        live.text(s, "", delay=1)
        for key, pane, token in [("d", "DESCRIBE", live.pod), ("e", "EVENTS", live.pod), ("!", "EXPLAIN", "EVIDENCE")]:
            live.key(s, key, delay=3)
            exported(s, pane.lower(), ("THE WHOLE " + pane + " PANE", token))
        live.key(s, "Q")

    def previous_log():
        s = open_detail("extended-previous", pod="z-crash", container="crash")
        live.key(s, "p", delay=3)
        live.wait(s, "intentional validation failure", timeout=50)
        live.key(s, "A", delay=3)
        capture(s, "whole-previous-log", "Full previous instance of a real restarted container", "intentional validation failure")
        body = exported(s, "whole-previous", ("THE WHOLE PREVIOUS PANE", "ERROR intentional validation failure", "read:"))
        record("previous-log-coverage", "current file only" in body or "whole log" in body,
               "previous instance is read with the same explicit node-rotation capability reporting")
        live.key(s, "Q")

    def report_extras():
        bundle = live.out / "reports/with-extras"
        result = live.cli("extended-report-bundle", ["--report", str(bundle), "--no-io"], timeout=240)
        live.finish_cli(result)
        paths = {name: next(bundle.rglob(name), None) for name in
                 ("fmea.txt", "fmea.csv", "secrets.txt", "secrets.csv", "secrets.json")}
        for name, path in paths.items():
            body = path.read_text() if path else ""
            expected = "app-server" if name.startswith("fmea") else "kdash-secrets-live"
            record("bundle-" + name.replace(".", "-"), expected in body,
                   str(path.relative_to(live.out)) if path else "missing diagnostic export")
        if paths["secrets.json"]:
            data = json.loads(paths["secrets.json"].read_text())
            record("bundle-secrets-json-valid", isinstance(data.get("secrets"), list) and bool(data["secrets"]),
                   "report bundle's structured Secrets data parses")
        # The --report bundle is a static evidence page; the tabbed combined
        # namespace report is produced by --snapshot. Generate that report with
        # the same live extras so the check covers the user-facing tabs and IDs.
        snapshot_dir = live.out / "reports/with-extras-snapshot"
        previous = live.env.copy()
        try:
            live.env["KDASH_REPORT_DIR"] = str(snapshot_dir)
            result = live.cli("extended-report-with-extras-snapshot", ["--snapshot", "--no-io"], timeout=240)
            live.finish_cli(result)
        finally:
            live.env = previous
        combined = sorted(snapshot_dir.rglob("kdash_namespace_report*.html"))
        body = combined[-1].read_text() if combined else ""
        record("combined-extra-tab-data", all(token in body for token in
               ('data-tab="fmea"', 'data-tab="secrets"', "app-server", "kdash-secrets-live", "fmea_1", "sm_1")),
               "combined live snapshot embeds both populated, searchable/sortable diagnostic tables")
        previous = live.env.copy()
        try:
            live.env.update(KDASH_REPORT_EXTRAS="0", KDASH_REPORT_DIR=str(live.out / "reports/without-extras"))
            result = live.cli("extended-report-without-extras", ["--snapshot", "--no-io"], timeout=180)
            live.finish_cli(result)
        finally:
            live.env = previous
        combined = sorted((live.out / "reports/without-extras").rglob("kdash_namespace_report*.html"))
        body = combined[-1].read_text() if combined else ""
        record("combined-extra-tabs-opt-out", bool(body) and 'data-tab="fmea"' not in body and 'data-tab="secrets"' not in body,
               "KDASH_REPORT_EXTRAS=0 retains resource/history report tabs")

    def secret_certificates():
        # --certs exits 1 for a warning and 2 for a critical finding; the generated
        # two-day fixture certificates are deliberately critical in this test.
        result = live.cli("extended-certs-secret-certificates", ["--certs", "-o", "tsv"],
                          expect=("kdash-secrets-live", "Secret"), codes=(0, 1, 2))
        live.finish_cli(result)
        s = live.start_dashboard("extended-certs-secrets", extra=("--no-io",))
        live.key(s, "C", delay=2)
        # TLS handshakes and the Secrets scan run asynchronously: export only after
        # the real Secret rows have arrived, otherwise the screen is still collecting.
        live.wait(s, "kdash-secrets-live", timeout=120)
        capture(s, "certs-secret-public-certificate", "Certificate view includes real generated Secret public certificate expiry", "kdash-secrets-live")
        exported(s, "certs-secret-rows", ("THE WHOLE CERTIFICATES VIEW", "kdash-secrets-live"))
        live.key(s, "/")
        live.text(s, "kdash-secrets-live", delay=2)
        capture(s, "certs-secret-search", "Certificate search finds the generated Secret certificate", "matching line|kdash-secrets-live")
        live.key(s, "Q")

    def multi_log_search():
        s = open_detail("extended-multi-log")
        live.key(s, "F", delay=2)
        live.wait(s, "this pod")
        live.key(s, "Escape", delay=1)
        record("log-scope-cancel", "SUMMARY" in live.screen(s),
               "cancelling the scope picker returns to the same real pod detail")
        for key, name in [("p", "pod"), ("w", "workload"), ("n", "namespace")]:
            live.key(s, "F", delay=2)
            live.wait(s, "this pod")
            if key == "p":
                capture(s, "log-search-scope", "Full log search offers this pod, workload and namespace scopes", "the namespace")
            live.key(s, key, delay=1)
            if key == "p":
                live.text(s, "[", delay=1)
                capture(s, "log-search-invalid-pattern", "Invalid full-log search patterns can be corrected before reads begin", "not a valid regular expression")
            live.text(s, "INFO|WARN|ERROR", delay=3)
            live.wait(s, "FIND IN LOGS.*|logs read", timeout=80)
            # Progress and the completed pane share the title; wait for the pane action panel.
            live.wait(s, "PANES|prev logs", timeout=90)
            capture(s, "log-search-" + name, "Merged timestamped matching lines from real " + name + " container logs", "logs read")
            body = exported(s, "find-" + name, ("THE WHOLE FOUND PANE", "LOG", "Matching lines of all logs", "[" + live.pod + "/app]"))
            expected_logs = 2 if name == "pod" else 4 if name == "workload" else 4
            match = re.search(r": (\d+) of (\d+) logs read", body)
            record("log-scope-" + name, bool(match) and int(match[1]) == int(match[2]) and int(match[2]) >= expected_logs,
                   match.group(0) if match else "coverage summary absent")
            merged_lines = body.split("THE WHOLE FOUND PANE")[-1]
            timestamps = re.findall(r"^(\d{4}-\d\d-\d\dT\S+) \[[^\]]+\]", merged_lines, re.M)
            record("log-merge-order-" + name, bool(timestamps) and timestamps == sorted(timestamps),
                   f"{len(timestamps)} exported matching lines remain in timestamp order")
            if name == "namespace":
                record("log-search-previous-instance", "z-crash/crash (previous)" in body,
                       "restarted fixture contributes its previous container instance")
        live.key(s, "Q")

    def themes_and_fallback():
        s = live.start_dashboard("extended-themes", extra=("--no-io",))
        for theme in ("safe", "dark", "light", "mono"):
            capture(s, "theme-" + theme, "Live dashboard theme " + theme)
            ansi = live.tm("capture-pane", "-e", "-p", "-t", s)
            record("theme-" + theme, "app-server" in live.screen(s) and ("38;5;" in ansi if theme != "mono" else "38;5;" not in ansi),
                   "observed real ANSI output and retained workload data")
            live.key(s, "T", delay=1)
        live.key(s, "Q")
        live.launch("extended-legacy", extra=("--no-io",), env={"KDASH_COLORS": "16", "KDASH_BG_MODEL": "0",
                    "KDASH_PARALLEL_READS": "0", "KDASH_VIEW_CACHE": "0", "KDASH_REDRAW_MAX": "0"})
        live.wait("extended-legacy", "app-server", timeout=70)
        live.key("extended-legacy", "2", "1", delay=3)
        ansi = live.tm("capture-pane", "-e", "-p", "-t", "extended-legacy")
        record("legacy-render-fallbacks", "app-server" in live.screen("extended-legacy") and "38;5;" not in ansi,
               "16 colours, sequential reads, foreground model and no view cache remain usable")
        capture("extended-legacy", "fallback-16-colours", "Live compatibility mode with sequential reads and 16 ANSI colours")
        live.key("extended-legacy", "Q")

    def file_browser_exports():
        s = live.start_dashboard("extended-file-export", extra=("--container", "app", "--allow-interactive", "--no-io"))
        for direction, name, marker in [("U", "local-files", "EVERY ENTRY OF"), ("D", "remote-files", "EVERY ENTRY OF")]:
            live.key(s, direction, delay=2)
            if "SELECT POD" in live.screen(s):
                live.key(s, "/"); live.text(s, live.pod); live.key(s, "Enter", delay=3)
            live.wait(s, "SELECT LOCAL FILES|DOWNLOAD.*step 1|FILE BROWSER|THIS HOST|CONTAINER", timeout=40)
            exported(s, name, (marker, "# end of export", "upload.txt" if direction == "U" else "tmp"),
                     "Quick export from the actual " + name.replace("-", " ") + " browser")
            live.key(s, "q", delay=1)
            if "SELECT POD" in live.screen(s):
                live.key(s, "q")
        live.key(s, "Q")

    try:
        record("installed-source-identical", live.source_sha256 == live.installed_sha256,
               "extension tests the installed bytes that will be published")
        live.inventory()
        # The main run already records the shared inventory check; keep this
        # extension's later (fixture-inclusive) inventory distinct after merge.
        for check in live.checks:
            if check["name"] == "real-cluster-inventory":
                check["name"] = "extended-real-cluster-inventory"
        live.save()
        for name, action in [("dashboard-search", dashboard_search), ("prompt-editor", prompt_editor),
                             ("dashboard-exports", dashboard_exports), ("logs-and-containers", logs_and_containers),
                             ("multi-log-search", multi_log_search), ("previous-log", previous_log),
                             ("report-extras", report_extras), ("secret-certificates", secret_certificates),
                             ("themes", themes_and_fallback),
                             ("file-browser-exports", file_browser_exports)]:
            scenario(name, action)
        session_logs = list(exports.glob("kdash_session_*.log"))
        record("session-export-aggregation", bool(session_logs) and all("# end of export" in p.read_text() for p in session_logs),
               f"{len(session_logs)} session logs aggregate their explicit exports")
        record("latest-export-link", (exports / "latest.log").is_symlink() and (exports / "latest.log").exists(),
               "latest.log resolves to the newest individual export")
        live.render(check_name="extended-screenshots-rendered")
        finished = True
    finally:
        export_evidence = [{"file": "reports/exports/" + path.name,
                            "mode": oct(stat.S_IMODE(path.stat().st_mode)),
                            "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                            "symlink": path.is_symlink()}
                           for path in sorted(exports.glob("*.log"))]
        (live.out / "export-files.json").write_text(json.dumps(export_evidence, indent=2) + "\n")
        shutil.copytree(exports, live.out / "reports/exports", dirs_exist_ok=True)
        native_exports.cleanup()
        live.tm("kill-server", check=False)
        if live.xserver:
            live.xserver.terminate(); live.xserver.wait(timeout=10)
        live.completed = finished; live.save()
    failed = [c for c in live.checks if c["status"] != "PASS"]
    (live.out / "status.txt").write_text("DONE\n" if finished and not failed else "FAIL\n")
    print(f"{len(live.checks) - len(failed)}/{len(live.checks)} extended checks passed; {len(live.captures)} captures")
    if args.merge_to and finished and not failed:
        merge(Path(os.path.abspath(args.merge_to)), live.out)
    return bool(failed) or not finished


if __name__ == "__main__":
    raise SystemExit(main())
