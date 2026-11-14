#!/usr/bin/env python3
"""Validate an installed kdash against a real cluster and save live tmux screens.

Run inside WSL with an isolated KUBECONFIG, for example:
  python3 scripts/live-e2e.py --namespace kdash-e2e --setup

Only --setup creates Kubernetes resources, all in the named test namespace except
the explicitly named test PV. Interactive checks write only the fixture pod's
/tmp/kdash-transfer directory and this run's work directory. The tmux server has
a private socket; existing user sessions are never stopped. Companion PNGs are
faithful ANSI replays. --native-screenshots also saves actual live xterm windows
on an isolated Xvfb display. Results retain hashes for both image types.
"""
from __future__ import annotations

import argparse
import concurrent.futures
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import sys
import time
import zipfile


class LiveE2E:
    def __init__(self, args):
        self.args = args
        self.repo = Path(os.path.abspath(args.repo))
        self.binary = Path(os.path.abspath(Path(args.binary).expanduser()))
        self.stamp = time.strftime("%Y%m%d-%H%M%S")
        self.out = Path(os.path.abspath(args.output or self.repo / "artifacts" / ("live-e2e-" + self.stamp)))
        # The audit chain is append-only and hash-linked, so a log left behind by
        # an earlier run (or rewritten in transit by a cloud-sync client on a 9p
        # mount) would make --audit-verify report a broken chain before this run
        # writes anything. Every run starts its own audit directory.
        shutil.rmtree(self.out / "audit", ignore_errors=True)
        for child in ("logs", "raw", "reports", "audit", "config", "work"):
            (self.out / child).mkdir(parents=True, exist_ok=True)
        self.env = os.environ.copy()
        self.env.update({
            "KDASH_ACCEPT_DISCLAIMER": "1", "KDASH_AUDIT_SYSLOG": "0",
            "KDASH_AUDIT_DIR": str(self.out / "audit"),
            "KDASH_AUDIT_CENTRAL": str(self.out / "unused-central"),
            "KDASH_REPORT_DIR": str(self.out / "reports"),
            "XDG_CONFIG_HOME": str(self.out / "config"), "TERM": "xterm-256color",
            "KDASH_SAMPLE_EVERY": "2", "TZ": "Asia/Kolkata",
            "LANG": "C.UTF-8", "LC_ALL": "C.UTF-8",
        })
        self.kc = ["kubectl"] + (["--context", args.context] if args.context else [])
        self.base = [str(self.binary)] + (["-c", args.context] if args.context else []) + ["-n", args.namespace]
        self.checks = []
        self.captures = []
        self.socket = "kdash-e2e-" + str(os.getpid())
        self.sizes = {}
        self.sessions = []
        self.xserver = None
        self.display = None
        if args.native_screenshots:
            for number in range(177, 200):
                if not Path(f"/tmp/.X11-unix/X{number}").exists():
                    self.display = f":{number}"
                    break
            if self.display is None:
                raise RuntimeError("No unused local X display for native screenshots")
            self.xserver = subprocess.Popen(["Xvfb", self.display, "-screen", "0", "1920x1200x24", "-nolisten", "tcp"],
                                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            time.sleep(0.5)
        self.version = subprocess.check_output([str(self.binary), "-V"], env=self.env, text=True).strip().split()[-1]
        self.source_sha256 = hashlib.sha256((self.repo / "kdash").read_bytes()).hexdigest()
        self.installed_sha256 = hashlib.sha256(self.binary.read_bytes()).hexdigest()
        self.completed = False
        self.payload = b"kdash live WSL upload/download verification\nline with spaces and unicode: Kubernetes \xe2\x9c\x93\n"
        (self.out / "work" / "upload.txt").write_bytes(self.payload)
        tree = self.out / "work" / "upload-tree"
        (tree / "nested").mkdir(parents=True, exist_ok=True)
        (tree / "a").write_text("first real directory file\n")
        (tree / "longer-name.txt").write_text("second real directory file\n")
        (tree / "nested" / "child.txt").write_bytes(self.payload)

    def log(self, value):
        print(time.strftime("%H:%M:%S"), value, flush=True)

    def record(self, name, passed, detail="", **extra):
        item = {"name": name, "status": "PASS" if passed else "FAIL", "detail": detail, **extra}
        self.checks.append(item)
        self.log(item["status"] + " " + name + (": " + detail if detail else ""))
        self.save()
        return passed

    def save(self):
        data = {
            "version": self.version, "namespace": self.args.namespace,
            "context": self.args.context or "current", "started": self.stamp,
            "phase": self.args.phase, "completed": self.completed,
            "cli_workers": self.args.workers,
            "sha256": self.source_sha256, "installed_sha256": self.installed_sha256,
            "binary_sha256": self.installed_sha256,
            "capture_source_sha256": self.source_sha256,
            "status": "FAIL" if any(c["status"] == "FAIL" for c in self.checks) else ("PASS" if self.completed else "RUNNING"),
            "checks": self.checks, "captures": self.captures,
            "failures": [c["name"] for c in self.checks if c["status"] == "FAIL"],
        }
        (self.out / "results.json").write_text(json.dumps(data, indent=2) + "\n")
        (self.out / "checks.tsv").write_text("check\tstatus\tdetail\n" + "".join(
            f'{c["name"]}\t{c["status"]}\t{c["detail"].replace(chr(9), " ").replace(chr(10), " ")}\n'
            for c in self.checks))
        (self.out / "captures.tsv").write_text("file\tcolumns\trows\ttitle\tpng\n" + "".join(
            f'{c["file"]}\t{c["columns"]}\t{c["rows"]}\t{c["title"]}\t{c["png"]}\n'
            for c in self.captures))

    def call(self, argv, timeout=120, input=None):
        return subprocess.run(argv, input=input, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                              text=True, env=self.env, cwd=self.out / "work", timeout=timeout)

    def cli(self, name, options, expect=(), codes=(0,), scoped=True, timeout=120):
        argv = (self.base if scoped else [str(self.binary)]) + options
        start = time.monotonic()
        try:
            p = self.call(argv, timeout=timeout)
            body, rc = p.stdout, p.returncode
        except subprocess.TimeoutExpired as ex:
            body = (ex.stdout or b"").decode(errors="replace") if isinstance(ex.stdout, bytes) else (ex.stdout or "")
            rc = 124
        (self.out / "logs" / (name + ".log")).write_text(body)
        passed = rc in codes and all(re.search(pattern, body, re.I) for pattern in expect)
        if name.startswith(("csv-", "tsv-")):
            import csv
            delimiter = "," if name.startswith("csv-") else "\t"
            rows = list(csv.reader((line for line in body.splitlines() if line and not line.startswith("# ")), delimiter=delimiter))
            passed = passed and bool(rows) and any(len(row) > 1 for row in rows) and "│" not in body and "┌" not in body
        if name.startswith("tsv-"):
            passed = passed and "\t" in body and not re.search("[┌┬│]", body)
        if name.startswith("csv-"):
            passed = passed and "," in body and not re.search("[┌┬│]", body)
        return {"name": name, "passed": passed, "detail": f"exit {rc}; {len(body.encode())} bytes",
                "command": shlex.join(["kdash"] + argv[1:]), "exit_code": rc,
                "seconds": round(time.monotonic() - start, 2), "log": "logs/" + name + ".log"}

    def finish_cli(self, result):
        self.record(result.pop("name"), result.pop("passed"), result.pop("detail"), **result)

    def setup(self):
        ns = self.args.namespace
        if not re.fullmatch(r"kdash-e2e(?:-[a-z0-9-]+)?", ns):
            raise RuntimeError("--setup requires an explicit kdash-e2e test namespace")
        doc = f'''apiVersion: v1
kind: Namespace
metadata:
  name: {ns}
  labels: {{app.kubernetes.io/part-of: kdash-validation}}
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: {ns}-data
spec:
  capacity: {{storage: 64Mi}}
  accessModes: [ReadWriteMany]
  persistentVolumeReclaimPolicy: Retain
  storageClassName: ""
  hostPath: {{path: /tmp/{ns}-data, type: DirectoryOrCreate}}
  claimRef: {{namespace: {ns}, name: app-data}}
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata: {{name: app-data, namespace: {ns}}}
spec:
  accessModes: [ReadWriteMany]
  resources: {{requests: {{storage: 64Mi}}}}
  storageClassName: ""
  volumeName: {ns}-data
---
apiVersion: apps/v1
kind: Deployment
metadata: {{name: app-server, namespace: {ns}}}
spec:
  replicas: 2
  selector: {{matchLabels: {{app: kdash-e2e, role: server}}}}
  template:
    metadata: {{labels: {{app: kdash-e2e, role: server}}}}
    spec:
      containers:
      - name: app
        image: busybox:1.36
        command: [sh, -c]
        args:
        - |
          mkdir -p /tmp/kdash-transfer /data
          printf 'live Kubernetes dashboard validation\\n' > /data/index.html
          printf 'seed file from a real running container\\n' > /tmp/kdash-transfer/seed.txt
          httpd -p 8080 -h /data
          i=0
          while :; do
            echo "$(date -Iseconds) INFO request=$i service=app-server healthy=true"
            echo "$(date -Iseconds) WARN request=$i demonstration warning from live workload"
            i=$((i+1)); sleep 2
          done
        ports: [{{containerPort: 8080}}]
        resources:
          requests: {{cpu: 20m, memory: 8Mi}}
          limits: {{cpu: 200m, memory: 64Mi}}
        readinessProbe: {{httpGet: {{path: /, port: 8080}}, periodSeconds: 3}}
        volumeMounts: [{{name: data, mountPath: /data}}]
      - name: sidecar
        image: busybox:1.36
        command: [sh, -c, 'while :; do echo "$(date -Iseconds) INFO sidecar heartbeat"; sleep 3; done']
        resources:
          requests: {{cpu: 5m, memory: 4Mi}}
          limits: {{cpu: 50m, memory: 32Mi}}
      volumes: [{{name: data, persistentVolumeClaim: {{claimName: app-data}}}}]
---
apiVersion: v1
kind: Service
metadata: {{name: app-server, namespace: {ns}}}
spec:
  selector: {{app: kdash-e2e, role: server}}
  ports: [{{port: 80, targetPort: 8080}}]
---
apiVersion: v1
kind: Service
metadata: {{name: missing-backend, namespace: {ns}}}
spec:
  selector: {{app: does-not-exist}}
  ports: [{{port: 80, targetPort: 8080}}]
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata: {{name: app-server, namespace: {ns}}}
spec:
  rules:
  - host: kdash.test
    http:
      paths:
      - path: /
        pathType: Prefix
        backend: {{service: {{name: app-server, port: {{number: 80}}}}}}
---
apiVersion: v1
kind: Pod
metadata: {{name: z-crash, namespace: {ns}, labels: {{app: kdash-e2e, role: failure}}}}
spec:
  containers:
  - name: crash
    image: busybox:1.36
    command: [sh, -c, 'echo "ERROR intentional validation failure exit=42"; sleep 3; exit 42']
    resources:
      requests: {{cpu: 5m, memory: 4Mi}}
      limits: {{cpu: 50m, memory: 32Mi}}
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata: {{name: z-unbound, namespace: {ns}}}
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: kdash-e2e-intentionally-missing
  resources: {{requests: {{storage: 32Mi}}}}
---
apiVersion: v1
kind: Pod
metadata: {{name: z-pending, namespace: {ns}, labels: {{app: kdash-e2e, role: pending}}}}
spec:
  containers:
  - name: pending
    image: busybox:1.36
    command: [sh, -c, 'sleep 86400']
    volumeMounts: [{{name: missing, mountPath: /data}}]
    resources:
      requests: {{cpu: 5m, memory: 4Mi}}
      limits: {{cpu: 50m, memory: 32Mi}}
  volumes: [{{name: missing, persistentVolumeClaim: {{claimName: z-unbound}}}}]
---
apiVersion: batch/v1
kind: Job
metadata: {{name: completed-check, namespace: {ns}}}
spec:
  template:
    metadata: {{labels: {{app: kdash-e2e, role: job}}}}
    spec:
      restartPolicy: Never
      containers:
      - name: check
        image: busybox:1.36
        command: [sh, -c, 'echo "INFO completed live validation job"']
        resources:
          requests: {{cpu: 5m, memory: 4Mi}}
          limits: {{cpu: 50m, memory: 32Mi}}
'''
        (self.out / "fixture.yaml").write_text(doc)
        applied = self.call(self.kc + ["apply", "-f", "-"], input=doc)
        (self.out / "logs" / "fixture-apply.log").write_text(applied.stdout)
        self.record("fixture-apply", applied.returncode == 0, "isolated namespace, healthy and failing workloads, services, ingress, bound/unbound PVC")
        ready = self.call(self.kc + ["-n", ns, "rollout", "status", "deployment/app-server", "--timeout=180s"], timeout=190)
        (self.out / "logs" / "fixture-ready.log").write_text(ready.stdout)
        self.record("fixture-ready", ready.returncode == 0, ready.stdout.strip())
        if ready.returncode:
            raise RuntimeError("fixture deployment did not become ready")

    def inventory(self):
        p = self.call(self.kc + ["-n", self.args.namespace, "get", "pods,services,pvc,ingress,deployments,jobs", "-o", "json"])
        if p.returncode:
            raise RuntimeError(p.stdout)
        obj = json.loads(p.stdout)
        # Kubernetes objects can include last-applied annotations; keep only real
        # observable inventory fields rather than copying arbitrary annotations.
        inventory = [{"kind": o["kind"], "name": o["metadata"]["name"], "status": o.get("status", {})} for o in obj["items"]]
        (self.out / "inventory.json").write_text(json.dumps(inventory, indent=2) + "\n")
        self.pod = next(o["metadata"]["name"] for o in obj["items"] if o["kind"] == "Pod" and o["metadata"].get("labels", {}).get("role") == "server")
        self.record("real-cluster-inventory", True, f'{len(inventory)} Kubernetes objects; pod {self.pod}')

    def cli_checks(self):
        tasks = []
        for view in ("pods", "nodes", "workloads", "ip", "mem", "io", "alerts", "services", "storage", "events", "explain"):
            tasks.append(("view-" + view, ["--once", "-v", view] + (["--io-wait", "16"] if view == "io" else []), ()))
        for fmt in ("tsv", "csv"):
            for view in ("pods", "nodes", "workloads", "ip", "mem", "services", "storage", "events", "explain"):
                tasks.append((f"{fmt}-{view}", ["--once", "-v", view, "-o", fmt], ()))
        tasks.extend([
            ("all-views", ["--once", "-v", "all"], ("app-server", "z-crash", "missing-backend")),
            ("doctor", ["--doctor"], ("DOCTOR", "connection|API")),
            ("events", ["--events"], ("z-crash|z-pending|app-server",)),
            ("explain", ["--explain", "z-crash"], ("z-crash",)),
            ("inspect-summary", ["--inspect", self.pod], (self.pod, "CONTAINERS")),
            ("inspect-logs", ["--inspect", self.pod, "--container", "app", "--logs", "current"], ("INFO request",)),
            ("filter-label", ["--once", "--selector", "role=server"], ("app-server",)),
            ("filter-status", ["--once", "--status", "Running"], ("app-server",)),
            ("filter-workload", ["--once", "--workload", "app-server"], ("app-server",)),
            ("filter-unhealthy", ["--once", "--unhealthy"], ("z-crash|z-pending",)),
            ("filter-regex", ["app-server", "--once"], ("app-server",)),
            ("ascii-no-color", ["--once", "--ascii", "--no-color"], ("app-server",)),
            ("flat-pods", ["--once", "--flat", "--pods-only", "--sort", "name", "--reverse"], ("app-server",)),
            ("no-cluster-metrics-io", ["--once", "--no-cluster", "--no-node-metrics", "--no-io"], ("app-server",)),
            ("compare", ["--once", "-v", "nodes", "--compare", self.args.namespace + ",default"], ()),
            ("snapshot-combined", ["--snapshot"], ("html",)),
            ("snapshot-all", ["--snapshot", "all"], ("html",)),
            ("snapshot-selection", ["--snapshot", "25"], ("html",)),
            ("report-bundle", ["--report"], ("html",)),
        ])
        # Keep request pressure modest and avoid overlapping report writers.
        reports = [t for t in tasks if t[0].startswith(("snapshot", "report-"))]
        tasks = [t for t in tasks if t not in reports]
        with concurrent.futures.ThreadPoolExecutor(max_workers=self.args.workers) as pool:
            futures = [pool.submit(self.cli, name, opts, expect) for name, opts, expect in tasks]
            for f in concurrent.futures.as_completed(futures):
                self.finish_cli(f.result())
        previous_args = ["--inspect", "z-crash", "--container", "crash", "--logs", "previous"]
        previous = self.cli("inspect-previous", previous_args, ("intentional validation failure",))
        retries = 0
        while not previous["passed"] and retries < 10 and \
                "unable to retrieve container logs" in (self.out / "logs/inspect-previous.log").read_text().lower():
            time.sleep(1)
            retries += 1
            previous = self.cli("inspect-previous", previous_args, ("intentional validation failure",))
        previous["detail"] += f"; previous-log retries={retries}"
        self.finish_cli(previous)
        for name, opts, expect in reports:
            self.finish_cli(self.cli(name, opts, expect))
        self.finish_cli(self.cli("all-namespaces", ["--once", "-v", "pods", "-A", "--no-cluster", "--selector", "app=kdash-e2e"], ("app-server",)))
        self.finish_cli(self.cli("empty-filter", ["^no-pod-can-match-this$", "--once"], codes=(3,)))
        self.finish_cli(self.cli("invalid-option", ["--not-a-kdash-option"], codes=(2,), scoped=False))
        self.finish_cli(self.cli("version", ["-V"], (re.escape(self.version),), scoped=False))
        self.finish_cli(self.cli("help", ["--help"], ("SELECT|TARGETING", "INTERACTIVE"), scoped=False))
        self.finish_cli(self.cli("completion", ["--completion", "bash"], ("complete",), scoped=False))
        self.finish_cli(self.cli("about", ["--about"], ("author", "audit"), scoped=False))
        for view in ("pods", "services", "storage"):
            body = (self.out / "logs" / ("view-" + view + ".log")).read_text()
            expected = {"pods": "app-server", "services": "missing-backend", "storage": "z-unbound"}[view]
            self.record("real-data-" + view, expected in body, f"observed {expected} in installed CLI output")
        self.toolkit_cli_checks()

    def toolkit_cli_checks(self):
        """Validate certificate evidence, printed runbooks and guarded check reads."""
        self.finish_cli(self.cli("certs", ["--certs"],
            ("CERTIFICATES AND LOGINS", "EXPIRY", r"cluster CA|client certificate", r"20\d\d-\d\d-\d\d"),
            codes=(0, 1, 2), timeout=180))
        check_patterns = ("CHECK NOW", "AREAS", "FINDINGS", "z-crash", "z-pending")
        result = self.cli("check-summary", ["--check"], check_patterns, codes=(1, 2), timeout=180)
        # The crashing fixture briefly becomes Running/ready between restarts.
        # Retain that snapshot and retry the identical assertion once in backoff.
        first_body = (self.out / result["log"]).read_text()
        if not result["passed"] and result["exit_code"] in (1, 2) and "z-pending" in first_body and "z-crash" not in first_body:
            first = dict(result)
            first["log"] = "logs/check-summary-attempt1.log"
            (self.out / first["log"]).write_text(first_body)
            deadline = time.monotonic() + 45
            while time.monotonic() < deadline:
                state = self.call(self.kc + ["-n", self.args.namespace, "get", "pod", "z-crash", "--request-timeout=10s",
                    "-o", "jsonpath={.status.containerStatuses[0].state.waiting.reason}"], timeout=15)
                if state.returncode == 0 and state.stdout == "CrashLoopBackOff":
                    result = self.cli("check-summary", ["--check"], check_patterns, codes=(1, 2), timeout=180)
                    result["attempts"] = [first, dict(result)]
                    result["retry_reason"] = "initial snapshot saw the intentional crash fixture between restarts"
                    break
                time.sleep(1)
        self.finish_cli(result)
        summary = (self.out / "logs" / "check-summary.log").read_text()
        finding = re.search(r"(?m)^\s*#(\d+)\s+[^\n]*\bz-(?:crash|pending)\b", summary)
        if self.record("check-real-finding-selected", bool(finding),
                       "selected a numbered unhealthy fixture finding from actual --check output"):
            number = finding.group(1)
            expect = (r"instant check - finding #" + number, "read-only commands", r"\$ kubectl",
                      r"(?m)^Name:\s+z-(?:crash|pending)\b", r"(?m)^Namespace:\s+" + re.escape(self.args.namespace))
            result = self.cli("check-run-finding", ["--check", "--run", number], expect, timeout=180)
            # The crash fixture restarts every ~30s, so the finding numbering can
            # shift between the summary and the run. Re-read the summary and retry once.
            if not result["passed"]:
                fresh = self.call(self.base + ["--check"], timeout=180)
                m = re.search(r"(?m)^\s*#(\d+)\s+[^\n]*\bz-(?:crash|pending)\b", fresh.stdout)
                if m and m.group(1) != number:
                    number = m.group(1)
                    expect = (r"instant check - finding #" + number, "read-only commands", r"\$ kubectl",
                              r"(?m)^Name:\s+z-(?:crash|pending)\b", r"(?m)^Namespace:\s+" + re.escape(self.args.namespace))
                    result = self.cli("check-run-finding", ["--check", "--run", number], expect, timeout=180)
                    result["retry_reason"] = "finding numbering shifted with the crash fixture restart"
            self.finish_cli(result)
            body = (self.out / "logs" / "check-run-finding.log").read_text()
            commands = re.findall(r"(?m)^\$ (.+)$", body)
            allowed = r"\b(?:get|describe|logs|top|explain|events|version|cluster-info|api-resources|whoami|can-i|history|status)\b"
            self.record("check-run-read-commands-only", bool(commands) and all(
                command.startswith("kubectl ") and re.search(allowed, command) and not re.search(
                    r"\b(?:apply|delete|patch|replace|create|cordon|uncordon|drain|scale|restart|exec|cp)\b", command)
                for command in commands), "captured finding executed only guarded kubectl reads")
        for topic in ("etcd-restore", "cert-rotate", "node-notready", "api-unreachable", "oidc-login"):
            self.finish_cli(self.cli("runbook-" + topic, ["--runbook", topic],
                ("RUNBOOK - " + re.escape(topic), "WHEN TO USE", "CHANGE", "never runs them"), timeout=120))
        body = (self.out / "logs" / "runbook-node-notready.log").read_text()
        nodes = self.call(self.kc + ["get", "nodes", "-o", "jsonpath={.items[*].metadata.name}"], timeout=90)
        names = nodes.stdout.split() if nodes.returncode == 0 else []
        self.record("runbook-real-node-inventory", bool(names) and all(
            re.search(r"(?m)(?:^|[│|])\s*" + re.escape(name) + r"\s+(?:[│|]|server|agent)", body) for name in names),
                    "node runbook includes the actual cluster node inventory")
        if tuple(int(n) for n in self.version.split('.')) >= (4, 28, 1):
            self.fmea_cli_checks()

    def fmea_cli_checks(self):
        self.finish_cli(self.cli("fmea-summary", ["--fmea"], ("WORKSHEET", "Action Priority", "visible", "z-pending"), timeout=180))
        for fmt in ("csv", "tsv"):
            self.finish_cli(self.cli(fmt + "-fmea", ["--fmea", "-o", fmt], ("RPN", "FAILURE_MODE", "z-pending"), timeout=180))
        result = self.cli("fmea-json", ["--fmea", "-o", "json"], timeout=180)
        self.finish_cli(result)
        try:
            data = json.loads((self.out / "logs/fmea-json.log").read_text())
            valid = data["namespace"] == self.args.namespace and len(data["rows"]) >= 40 and all(
                row["ap"] in ("H", "M", "L") and 1 <= row["s"] <= 10 and row["rpn"] == row["s"] * row["o"] * row["d"]
                for row in data["rows"])
        except (ValueError, KeyError, TypeError):
            valid = False
        self.record("fmea-json-real-rows", valid, "real worksheet rows retain numeric scores, AP, access and namespace")
        self.finish_cli(self.cli("fmea-html", ["--fmea", "-o", "html"], (r"fmea_.*\.html",), timeout=180))
        self.finish_cli(self.cli("fmea-access", ["--access"], ("ACCESS", "PERMISSIONS", "COVERAGE", "read verbs only"), timeout=180))
        self.finish_cli(self.cli("fmea-fail-on-high", ["--fmea", "--fail-on", "high"], ("HIGH",), codes=(2,), timeout=180))
        self.finish_cli(self.cli("fmea-trend", ["--fmea", "--since", "30d"], ("FMEA TREND", "PER DAY"), timeout=180))
        summary = (self.out / "logs/fmea-summary.log").read_text()
        finding = re.search(r"(?m)^\s*#(\d+)\s+[^\n]*\bz-(?:crash|pending)\b", summary)
        if self.record("fmea-real-finding-selected", bool(finding), "selected a real failing pod row's numbered read commands"):
            self.finish_cli(self.cli("fmea-run-finding", ["--fmea", "--run", finding.group(1)],
                ("read-only commands", r"\$ kubectl", r"(?m)^Name:\s+z-(?:crash|pending)\b"), timeout=180))
            commands = re.findall(r"(?m)^\$ (.+)$", (self.out / "logs/fmea-run-finding.log").read_text())
            self.record("fmea-run-read-commands-only", bool(commands) and all(
                command.startswith("kubectl ") and not re.search(r"\b(?:apply|delete|patch|replace|create|drain|scale|exec|cp)\b", command)
                for command in commands), "FMEA row execution ran only the captured guarded reads")

    def toolkit_ui_checks(self):
        """Capture existing C/R/K tools from the live cluster in a private session."""
        s = self.start_dashboard("toolkit")
        self.key(s, "C", delay=3)
        self.wait(s, "EXPIRES UTC", timeout=150)
        self.capture(s, "84-certs", "CERTIFICATES AND LOGINS real TLS and kubeconfig expiry evidence", "EXPIRES UTC")
        self.key(s, "R", delay=3)
        self.wait(s, "WHEN TO USE", timeout=90)
        self.capture(s, "85-runbook", "RUNBOOK printed etcd recovery procedure with live cluster inventory", "RUNBOOK - etcd-restore")
        self.key(s, "]", delay=2)
        self.capture(s, "87-runbook-topic", "RUNBOOK next topic displays certificate rotation instructions", "RUNBOOK - cert-rotate")
        self.key(s, "[", delay=2)
        self.record("runbook-topic-cycle", "RUNBOOK - etcd-restore" in self.screen(s),
                    "right bracket selects the next procedure and left bracket returns")
        self.key(s, "K", delay=3)
        self.wait(s, "FINDINGS", timeout=120)
        self.capture(s, "86-check", "CHECK NOW actual unhealthy workloads and numbered read-only next commands", "CHECK NOW")
        body = self.screen(s)
        if "z-crash" not in body:
            # The crash fixture briefly becomes Running between restarts; re-read once.
            self.key(s, "r", delay=3)
            self.wait(s, "FINDINGS", timeout=60)
            body = self.screen(s)
        self.record("check-ui-real-findings", "z-crash" in body and "z-pending" in body,
                    "instant-check view shows the real crashing and pending fixture pods")
        if tuple(int(n) for n in self.version.split('.')) >= (4, 28, 1):
            self.key(s, "M", delay=3)
            self.wait(s, "WORKSHEET", timeout=150)
            self.capture(s, "88-fmea", "FMEA real failure modes, priority scores and read visibility", "WORKSHEET")
            self.key(s, ":", delay=2)
            self.text(s, "access")
            self.wait(s, "PERMISSIONS", timeout=120)
            self.capture(s, "89-access", "ACCESS real kubectl auth identity and permission checks", "PERMISSIONS")
            self.key(s, "M", delay=2)
            self.key(s, "t", delay=1)
            self.capture(s, "90-fmea-kind", "FMEA kind filter on actual worksheet rows", "showing kind")
            self.key(s, "s", delay=1)
            self.capture(s, "91-fmea-sort", "FMEA worksheet sorted by risk priority number", "WORKSHEET")
        self.key(s, "Q", delay=1)

    def tm(self, *argv, check=True):
        p = subprocess.run(["tmux", "-L", self.socket, *argv], stdout=subprocess.PIPE,
                           stderr=subprocess.PIPE, text=True, env=self.env)
        if check and p.returncode:
            raise RuntimeError("tmux " + shlex.join(argv) + ": " + p.stderr)
        return p.stdout

    def launch(self, name, extra=(), columns=170, rows=50, env=None, bare=False):
        variables = dict(self.env)
        variables.update({"KDASH_COLUMNS": str(columns), "KDASH_LINES": str(rows)})
        variables.update(env or {})
        command = ([str(self.binary)] if bare else self.base) + list(extra)
        # Only task-specific values are supplied in the shell command; credentials
        # remain in the inherited process environment and never enter captures.
        assignments = [f"{key}={value}" for key, value in variables.items()
                       if key.startswith("KDASH_") or key in ("XDG_CONFIG_HOME", "TZ", "TERM", "LANG", "LC_ALL")]
        shell = "cd " + shlex.quote(str(self.out / "work")) + "; exec " + shlex.join(["env", *assignments, *command])
        self.tm("new-session", "-d", "-s", name, "-x", str(columns), "-y", str(rows), shell)
        self.tm("set-option", "-t", name, "remain-on-exit", "on")
        self.tm("set-option", "-t", name, "status", "off")
        self.tm("set-option", "-t", name, "history-limit", "10000")
        self.sizes[name] = (columns, rows)
        self.sessions.append(name)
        return name

    def screen(self, session):
        return self.tm("capture-pane", "-p", "-t", session)

    def wait(self, session, pattern, timeout=35):
        until = time.monotonic() + timeout
        while time.monotonic() < until:
            body = self.screen(session)
            if re.search(pattern, body, re.I):
                return body
            if re.search(r"unbound variable|syntax error|Traceback", body):
                raise RuntimeError(body)
            time.sleep(0.4)
        raise RuntimeError(f"{session}: did not show {pattern!r}\n" + self.screen(session))

    def key(self, session, *keys, delay=1):
        self.tm("send-keys", "-t", session, *keys)
        time.sleep(delay)

    def text(self, session, value, enter=True, delay=1):
        self.tm("send-keys", "-t", session, "C-u")
        self.tm("send-keys", "-l", "-t", session, value)
        if enter:
            self.tm("send-keys", "-t", session, "Enter")
        time.sleep(delay)

    def capture(self, session, stem, title, expect=None):
        if expect:
            self.wait(session, expect)
        native = None
        if self.args.native_screenshots:
            columns, rows = self.sizes[session]
            native = self.repo / self.args.gallery / "native" / (stem + ".png")
            native.parent.mkdir(parents=True, exist_ok=True)
            xenv = {**self.env, "DISPLAY": self.display}
            terminal = subprocess.Popen(["xterm", "-title", "kdash-e2e-" + stem,
                "-geometry", f"{columns}x{rows}+0+0", "-fa", "DejaVu Sans Mono", "-fs", "9",
                "-bg", "#0d1117", "-fg", "#e6edf3", "-e", "tmux", "-L", self.socket,
                "attach-session", "-r", "-t", session], env=xenv,
                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            try:
                for _ in range(30):
                    probe = subprocess.run(["xwininfo", "-name", "kdash-e2e-" + stem], env=xenv,
                                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                    if probe.returncode == 0:
                        break
                    time.sleep(0.1)
                time.sleep(0.5)
                # A busy X server can make a single window grab slow; retry rather
                # than losing the whole run to one screenshot. The native grab is
                # best-effort: the ANSI replay PNG is still produced for every view.
                for attempt in range(3):
                    try:
                        subprocess.run(["import", "-window", "kdash-e2e-" + stem, str(native)], env=xenv,
                                       check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, timeout=120)
                        break
                    except (subprocess.TimeoutExpired, subprocess.CalledProcessError):
                        if attempt == 2:
                            native = None
                            break
                        time.sleep(1)
            finally:
                terminal.terminate()
                terminal.wait(timeout=10)
        ansi = self.tm("capture-pane", "-e", "-p", "-t", session)
        plain = self.screen(session)
        (self.out / "raw" / (stem + ".ansi")).write_text(ansi)
        (self.out / "raw" / (stem + ".txt")).write_text(plain)
        columns, rows = self.sizes[session]
        self.captures.append({"file": "raw/" + stem + ".ansi", "columns": columns, "rows": rows,
                              "title": "kdash " + self.version + " | " + title,
                              "png": self.args.gallery + "/" + stem + ".png",
                              "sha256": hashlib.sha256(ansi.encode()).hexdigest()})
        if native:
            self.captures[-1].update(native_png=native.relative_to(self.repo).as_posix(),
                                    native_sha256=hashlib.sha256(native.read_bytes()).hexdigest())
        self.record("capture-" + stem, len(plain.strip()) > 40 and not re.search(
            r"unbound variable|syntax error|Traceback|\ufffd", plain), title)

    def start_dashboard(self, name, extra=(), columns=170, rows=50):
        self.launch(name, ["-i", "2", *extra], columns, rows)
        self.wait(name, "app-server", timeout=50)
        time.sleep(2)
        return name

    def ui_checks(self):
        s = self.start_dashboard("views")
        for key, stem, title in [
            ("1", "01-pods", "PODS live requests, limits and measured usage"),
            ("2", "02-nodes", "NODE POOLS real allocatable capacity and namespace share"),
            ("3", "03-workloads", "WORKLOADS live replicas and placement"),
            ("4", "04-ip", "IP POOL real pod, node and service addresses"),
            ("5", "05-mem", "MEMORY live history and pod usage"),
            ("6", "06-io", "NETWORK AND DISK IO capability and live samples"),
            ("7", "07-alerts", "ALERTS real unhealthy fixture workloads"),
            ("8", "08-services", "SERVICES ingress, ready endpoints and missing backend"),
            ("9", "09-storage", "STORAGE bound volume and pending claim"),
            ("E", "10-events", "EVENTS real Kubernetes scheduler and kubelet events"),
            ("!", "11-explain", "INCIDENT EVIDENCE from actual failing workloads"),
        ]:
            self.key(s, key, delay=3)
            if key == "8":
                self.wait(s, "missing-backend", timeout=90)
            elif key == "9":
                self.wait(s, "z-unbound", timeout=90)
            elif key == "E":
                self.wait(s, "FailedScheduling|BackOff|Unhealthy", timeout=90)
            self.capture(s, stem, title)
        self.key(s, "1", "n", delay=3)
        self.capture(s, "12-namespace-picker", "Framed namespace picker with access and persistent default controls", "SELECT NAMESPACE")
        self.key(s, "/")
        self.text(s, self.args.namespace, enter=False)
        self.capture(s, "13-namespace-filter", "Live namespace search and context-sensitive action panel", "filter|Enter keep")
        self.key(s, "Escape", "q", delay=2)
        self.namespace_checks(s)
        self.key(s, "Enter", delay=3)
        self.capture(s, "14-pod-picker", "Framed live pod picker with CPU, memory, restarts and attention state", "SELECT POD")
        self.key(s, "?")
        self.capture(s, "15-pod-picker-help", "Pod picker navigation, filters and action keys", "SELECT POD.*KEYS")
        self.key(s, "x")
        self.key(s, "/")
        self.text(s, self.pod)
        self.key(s, "c", delay=3)
        self.capture(s, "16-container-picker", "Framed multi-container picker with resource/state columns", "SELECT CONTAINER|CONTAINER")
        self.key(s, "Enter", delay=3)
        self.capture(s, "17-inspector-summary", "Inspector summary of a real running pod", "SUMMARY|CONDITIONS")
        self.key(s, "S")
        self.capture(s, "75-detail-shell-blocked", "Read-only inspector refuses shell actions and explains X", "interactive actions are off")
        self.key(s, "X")
        self.capture(s, "76-detail-confirmation", "X opens confirmation directly from pod detail", "Turn on interactive mode")
        self.text(s, "n")
        self.capture(s, "77-detail-cancel", "Declining keeps pod detail read-only", "READ-ONLY")
        self.key(s, "X")
        self.text(s, "yes", delay=2)
        self.capture(s, "78-detail-interactive-on", "Whole yes answer enables the inspector without leaking keys", "INTERACTIVE / audited")
        self.key(s, "S", delay=2)
        if "SELECT CONTAINER" in self.screen(s):
            self.key(s, "Enter", delay=3)
        self.text(s, "printf 'KDASH_DETAIL_MODE_OK\\n'; id", delay=1)
        self.capture(s, "79-detail-shell", "Actual container shell opened after enabling X in detail", r"uid=\d+.*gid=")
        self.text(s, "exit", delay=3)
        self.key(s, "X")
        self.capture(s, "80-detail-interactive-off", "X disables interactive actions immediately in the inspector", "READ-ONLY")
        self.key(s, "S")
        self.capture(s, "81-detail-shell-blocked-again", "Shell is refused again after disabling X", "interactive actions are off")
        self.key(s, "l", delay=3)
        self.capture(s, "18-inspector-logs", "Bounded timestamped logs from the live app container", "INFO request")
        for key, stem, title in [
            ("+", "62-inspector-expand", "Expanded bounded log read from the live container"),
            ("A", "63-inspector-all", "All available live container logs within the byte cap"),
            ("W", "64-inspector-nowrap", "Unwrapped logs with horizontal navigation"),
            ("J", "65-inspector-json", "Readable JSON log formatting enabled"),
            ("f", "66-inspector-follow", "Live follow periodically refreshes actual container logs"),
        ]:
            self.key(s, key, delay=3)
            self.capture(s, stem, title)
        self.key(s, "f", "W", "J", delay=2)
        self.key(s, "/")
        self.text(s, "WARN")
        self.capture(s, "19-inspector-find", "Log search highlighting with context retained", "WARN")
        self.key(s, "&")
        self.text(s, "WARN")
        self.capture(s, "20-inspector-only-matches", "Only matching warning lines from real logs", "WARN")
        self.key(s, "?")
        self.capture(s, "21-inspector-help", "Inspector help for log filtering and export", "KEYS|HELP")
        self.key(s, "x", "w", delay=2)
        self.capture(s, "22-inspector-export", "Visible log pane exported locally")
        self.key(s, "q", "q", delay=2)
        self.controls(s)
        self.file_checks()
        self.narrow_checks()
        self.toolkit_ui_checks()

    def namespace_checks(self, s):
        self.key(s, "n", delay=2)
        self.key(s, "/")
        self.text(s, self.args.namespace)
        self.key(s, "d", delay=3)
        conf = self.out / "config" / "kdash.conf"
        self.record("namespace-save-default", conf.exists() and self.args.namespace in conf.read_text(),
                    "d writes the selected namespace into the isolated user's context mapping")
        bare = self.launch("saved-default", ["-c", self.args.context, "-i", "2"], bare=True)
        self.wait(bare, "app-server", timeout=45)
        self.capture(bare, "67-namespace-saved-default", "A subsequent launch opens the namespace saved with d")
        self.record("namespace-default-next-launch", self.args.namespace in self.screen(bare),
                    "new process with no -n selected the persisted namespace")
        self.key(bare, "n", delay=2)
        # Clear only takes effect from inside the namespace picker; give the
        # picker time to open so x cannot race the dashboard key handler.
        self.wait(bare, "SELECT NAMESPACE", timeout=20)
        self.key(bare, "x", delay=3)
        self.record("namespace-clear-default", conf.exists() and (self.args.context + "=" + self.args.namespace) not in conf.read_text(),
                    "x removes the saved mapping without changing other settings")
        self.key(bare, "t")
        self.text(bare, self.args.namespace, delay=3)
        self.capture(bare, "68-namespace-typed", "t opens an explicitly typed namespace")
        self.record("namespace-typed-name", "app-server" in self.screen(bare), "typed namespace opened the real workload")
        self.key(bare, "Q", delay=1)

    def controls(self, s):
        operations = [
            (("1", ":"), "32-command-palette", "Fixed-command palette"),
        ]
        for keys, stem, title in operations:
            self.key(s, *keys)
            self.capture(s, stem, title)
        self.text(s, "doctor", delay=5)
        self.capture(s, "33-doctor", "Live connection, TLS, RBAC and metrics checks", "DOCTOR")
        self.key(s, "1", "/")
        self.text(s, "app-server", delay=3)
        self.capture(s, "34-pod-filter", "Dashboard pod regular expression applied")
        self.key(s, "/")
        self.text(s, ".*", delay=2)
        self.key(s, "F")
        self.capture(s, "35-structured-filters", "Atomic label, status, node, workload and unhealthy filters")
        self.key(s, "Enter")
        for keys, stem, title in [
            (("d",), "36-detail-lines", "Toggle container detail lines"),
            (("d", "p"), "37-pods-only", "Pod totals without container rows"),
            (("p", "s", "o"), "38-sort-order", "Sort key and reverse direction"),
            (("P", "+"), "39-paused-interval", "Paused collection and changed polling interval"),
            (("P", "T"), "40-theme-dark", "Dark colour theme"),
            (("T",), "41-theme-light", "Light colour theme"),
            (("T",), "42-theme-mono", "Monochrome colour theme"),
            (("T", "2", "a", "Z"), "43-node-scale", "Node scope and true-scale resource bars"),
            (("5", "z"), "44-history-window", "Memory history with changed chart window"),
            (("1", "e"), "45-html-menu", "Local HTML report selection menu"),
        ]:
            self.key(s, *keys, delay=2)
            self.capture(s, stem, title)
        self.key(s, "Enter", delay=8)
        self.capture(s, "46-html-report-written", "All-tabs report generated from live session")
        self.key(s, "?", delay=1)
        self.capture(s, "47-dashboard-help", "Dashboard navigation and interactive controls")
        self.key(s, "x", "q", delay=3)
        self.capture(s, "48-session-summary", "Completed live session and retained history")

    def file_checks(self):
        s = self.start_dashboard("files", ["--container", "app"])
        self.key(s, "S", delay=2)
        self.capture(s, "23-interactive-blocked", "Shell refused while interactive mode is disabled", "interactive.*off|Press X")
        # A refusal may be shown in the pod picker; return to dashboard first.
        if "SELECT POD" in self.screen(s):
            self.key(s, "q")
        self.key(s, "X")
        self.capture(s, "24-interactive-confirmation", "Explicit interactive-mode confirmation", "Turn on interactive mode")
        self.key(s, "y", "Enter", delay=2)
        self.key(s, "S", delay=2)
        self.capture(s, "25-shell-picker", "Shell-mode pod picker and action panel", "SELECT POD")
        self.key(s, "/")
        self.text(s, self.pod)
        self.key(s, "Enter", delay=4)
        self.text(s, "printf 'KDASH_E2E_SHELL_OK\\n'; id; pwd", delay=2)
        self.capture(s, "26-shell-inside", "Actual shell inside the live app container", r"uid=\d+.*gid=")
        self.text(s, "exit", delay=3)
        # A fresh session starts with an empty picker filter. Reusing the shell
        # session keeps its filter, and the C-u that clears it is only handled while
        # the filter is being edited, so the pod name could be appended to the old
        # value and match nothing.
        self.tm("kill-session", "-t", s)
        # Uploads must exercise the real copy rather than stop at a name-conflict
        # left by an earlier run. Reset only the documented fixture directory.
        reset = self.call(self.kc + ["-n", self.args.namespace, "exec", self.pod, "-c", "app", "--", "sh", "-c",
                                     "rm -rf -- /tmp/kdash-transfer && mkdir -p -- /tmp/kdash-transfer"])
        self.record("transfer-destination-reset", reset.returncode == 0,
                    "private fixture upload destination starts empty for the real copy and result capture")
        s = self.transfer_browser("files-upload", "U")
        self.capture(s, "27-upload-browser", "Local framed file browser with enabled upload actions", "THIS HOST|SELECT LOCAL FILES")
        self.key(s, "/")
        self.text(s, "upload.txt")
        self.key(s, "u", delay=3)
        self.capture(s, "28-upload-destination", "Remote destination browser before any transfer", "DESTINATION|step 2")
        self.key(s, "p")
        self.text(s, "/tmp/kdash-transfer", delay=2)
        self.key(s, "u", delay=3)
        self.capture(s, "29-upload-review", "Upload preflight checks and explicit review", "UPLOAD|confirm")
        self.key(s, "Enter", delay=5)
        self.capture(s, "30-upload-result", "Real upload result with source and destination hashes", "UPLOAD.*RESULT|SAVED")
        actual = self.call(self.kc + ["-n", self.args.namespace, "exec", self.pod, "-c", "app", "--", "cat", "/tmp/kdash-transfer/upload.txt"])
        self.record("upload-roundtrip-bytes", actual.returncode == 0 and actual.stdout.encode() == self.payload,
                    "uploaded file read independently through kubectl exec and compared byte for byte")
        self.tm("kill-session", "-t", s)
        self.directory_upload()
        work = self.out / "work"
        # Reset transfer artifacts so a re-run starts from a known local state:
        # stale archives or "upload (2).txt" would otherwise satisfy the name
        # checks without exercising them.
        for leftover in ("upload.txt", "upload (2).txt", "upload (3).txt",
                         "upload-tree.zip", "upload-tree.tar.gz"):
            (work / leftover).unlink(missing_ok=True)
        (work / "upload.txt").write_text("local value before replace\n")
        self.download("download-replace", "upload.txt", conflict="r", stems=("31-download-browser", "49-download-review", "50-download-result"))
        self.record("download-default-plain-replace", (work / "upload.txt").read_bytes() == self.payload,
                    "default plain-file download replaced the existing local file after explicit r")
        retained = b"local value preserved by keep both\n"
        (work / "upload.txt").write_bytes(retained)
        self.download("download-keep", "upload.txt", conflict="k", stems=(None, "55-download-keep-review", "56-download-keep-result"))
        self.record("download-keep-both", (work / "upload.txt").read_bytes() == retained and
                    (work / "upload (2).txt").read_bytes() == self.payload,
                    "explicit k preserved the old file and created upload (2).txt with real container bytes")
        (work / "upload-tree" / "nested" / "child.txt").write_text("local directory value before replace\n")
        self.download("download-dir", "upload-tree", conflict="r", stems=(None, "57-directory-download-review", "58-directory-download-result"))
        self.record("directory-download-replace", (work / "upload-tree" / "nested" / "child.txt").read_bytes() == self.payload,
                    "directory replacement restored nested file bytes from the real container")
        self.download("download-zip", "upload-tree", formats=1, stems=(None, "59-download-zip-review", "60-download-zip-result"))
        self.download("download-tgz", "upload-tree", formats=2, stems=(None, "61-download-tgz-review", "69-download-tgz-result"))
        recovered_zip, recovered_tgz = [], []
        for path in (self.out / "work").glob("*.zip"):
            with zipfile.ZipFile(path) as z:
                recovered_zip.extend(z.read(n) for n in z.namelist() if n.endswith("child.txt"))
        for path in (self.out / "work").glob("*.tar.gz"):
            import tarfile
            with tarfile.open(path) as t:
                recovered_tgz.extend(t.extractfile(n).read() for n in t.getmembers() if n.isfile() and n.name.endswith("child.txt"))
        self.record("download-zip-bytes", self.payload in recovered_zip,
                    "ZIP archive opened independently; nested file matches uploaded source bytes")
        self.record("download-tgz-bytes", self.payload in recovered_tgz,
                    "tar.gz archive opened independently; nested file matches uploaded source bytes")

    def transfer_browser(self, name, direction):
        s = self.start_dashboard(name, ["-X", "--container", "app"])
        self.key(s, direction, delay=2)
        self.key(s, "/")
        self.text(s, self.pod)
        self.key(s, "Enter", delay=3)
        self.wait(s, "THIS HOST|CONTAINER|DOWNLOAD|SELECT LOCAL FILES", timeout=90)
        return s

    def directory_upload(self):
        s = self.transfer_browser("upload-directory", "U")
        self.key(s, "/")
        self.text(s, "upload-tree")
        self.key(s, "u", delay=3)
        self.key(s, "p")
        self.text(s, "/tmp/kdash-transfer", delay=2)
        self.key(s, "u", delay=3)
        self.capture(s, "70-directory-upload-review", "Directory upload preflight and recursive checksum checks", "UPLOAD")
        self.key(s, "Enter", delay=5)
        self.capture(s, "71-directory-upload-result", "Actual directory upload with recursive fingerprints", "UPLOAD.*RESULT|SAVED")
        actual = self.call(self.kc + ["-n", self.args.namespace, "exec", self.pod, "-c", "app", "--", "cat", "/tmp/kdash-transfer/upload-tree/nested/child.txt"])
        self.record("directory-upload-bytes", actual.returncode == 0 and actual.stdout.encode() == self.payload,
                    "independent kubectl read confirms the uploaded nested file bytes")
        self.tm("kill-session", "-t", s)

    def download(self, name, item, formats=0, conflict=None, stems=(None, None, None)):
        s = self.transfer_browser(name, "D")
        if stems[0]:
            self.capture(s, stems[0], "Remote framed file browser with selection and preview keys", "CONTAINER|DOWNLOAD")
        self.key(s, "p")
        self.text(s, "/tmp/kdash-transfer", delay=2)
        self.key(s, "/")
        self.text(s, item)
        self.key(s, "d", delay=3)
        for _ in range(formats):
            self.key(s, "f", delay=1)
        if stems[1]:
            self.capture(s, stems[1], "Download preflight, selected format and name conflict checks", "DOWNLOAD")
        self.key(s, "Enter", delay=1)
        # A previous run can leave the destination file behind, which makes the
        # real kdash name-check prompt appear. Answer it when it shows, and fall
        # back to a plain wait when the destination is clean.
        try:
            self.wait(s, "r replace|keep both", timeout=6)
            self.key(s, conflict or "r", delay=5)
        except RuntimeError:
            time.sleep(4)
        if stems[2]:
            self.capture(s, stems[2], "Real download result and per-item hash verification", "DOWNLOAD.*RESULT|SAVED")
        self.tm("kill-session", "-t", s)

    def narrow_checks(self):
        for columns, rows, suffix in ((100, 40, "100col"), (80, 30, "80col")):
            s = self.start_dashboard("narrow" + str(columns), columns=columns, rows=rows)
            self.capture(s, "51-pods-" + suffix, f"PODS at {columns} columns")
            if columns == 80:
                self.key(s, "X")
                self.capture(s, "82-mode-confirmation-80col", "Confirmation remains usable in an 80-column terminal", "Enter confirms")
                self.text(s, "Y")
                self.capture(s, "83-mode-enabled-80col", "Uppercase Y plus Enter enables interactive mode at 80 columns", "INTERACTIVE")
                self.key(s, "X")
            self.key(s, "Enter", delay=2)
            self.capture(s, "52-picker-" + suffix, f"Framed pod picker at {columns} columns", "SELECT POD")
            self.key(s, "q", "n", delay=2)
            self.capture(s, "53-namespace-" + suffix, f"Namespace picker and action panel at {columns} columns", "SELECT NAMESPACE")
            self.key(s, "Q", delay=2)
        s = self.start_dashboard("ascii", ["--ascii", "--no-color"])
        self.key(s, "Enter", delay=2)
        self.capture(s, "54-ascii-picker", "ASCII framed picker with colour disabled", "SELECT POD")
        self.key(s, "Q", delay=2)

    def artifact_checks(self):
        sessions = list((self.out / "reports" / "sessions").glob("*/meta.env"))
        if sessions:
            self.finish_cli(self.cli("session-report", ["--session-report", str(sessions[-1].parent)], ("html",), scoped=False))
        else:
            self.record("session-history", False, "no live session metadata written")
        for name, opts, expected in [
            ("audit-events", ["--audit", "40"], ("START|END|KEY",)),
            ("audit-grep", ["--audit", "--audit-grep", "CP_UP|CP_DOWN|EXEC"], ("CP_UP|CP_DOWN|EXEC",)),
            ("audit-verify", ["--audit-verify"], ("chain intact",)),
            ("audit-export", ["--audit-report", str(self.out / "reports")], ("html",)),
        ]:
            self.finish_cli(self.cli(name, opts, expected, scoped=False))
        htmls = list((self.out / "reports").glob("*.html"))
        csvs = list((self.out / "reports").glob("**/*.csv"))
        tsvs = list((self.out / "reports").glob("**/*.tsv"))
        self.record("export-artifacts", len(htmls) >= 7 and len(csvs) >= 3 and len(tsvs) >= 3,
                    f"{len(htmls)} HTML reports, {len(csvs)} CSV files, {len(tsvs)} TSV files")
        self.record("inspector-export-artifact", bool(list((self.out / "reports" / "inspector").glob("*"))),
                    "visible inspector log pane saved locally")
        combined = [p for p in htmls if "namespace_report" in p.name]
        self.record("html-real-data", any("app-server" in p.read_text() and "z-crash" in p.read_text() for p in combined),
                    "combined HTML contains the actual healthy and crashing fixture pod names")

    def render(self, captures=None, check_name="screenshots-rendered"):
        selected = self.captures if captures is None else captures
        images = []
        for c in selected:
            target = self.repo / c["png"]
            p = subprocess.run([sys.executable, str(self.repo / "scripts" / "capture-terminal.py"),
                                str(self.out / c["file"]), str(target), "--columns", str(c["columns"]),
                                "--rows", str(c["rows"]), "--font-size", "13", "--title", c["title"]],
                               stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
            if p.returncode:
                self.record("render-" + target.stem, False, p.stdout)
            else:
                images.append(target)
        if images:
            # An extension can render new captures without replacing checksums
            # for the already verified screenshots in the same gallery.
            gallery_images = sorted((self.repo / self.args.gallery).glob("*.png"))
            (self.repo / self.args.gallery / "SHA256SUMS").write_text("".join(
                hashlib.sha256(p.read_bytes()).hexdigest() + "  " + p.name + "\n" for p in gallery_images))
        self.record(check_name, len(images) == len(selected),
                    f"{len(images)} PNGs faithfully rendered from live tmux ANSI captures")

    def run(self):
        try:
            self.record("installed-source-identical", self.installed_sha256 == self.source_sha256,
                        "installed binary and repository CLI have the same SHA-256")
            if self.args.setup:
                self.setup()
            self.inventory()
            if self.args.phase in ("all", "cli"):
                self.cli_checks()
            if self.args.phase in ("all", "ui"):
                self.ui_checks()
            self.tm("kill-server", check=False)
            if self.args.phase in ("all", "ui"):
                self.artifact_checks()
            if not self.args.no_render:
                self.render()
        except Exception as ex:
            self.record("harness-exception", False, str(ex))
        finally:
            self.tm("kill-server", check=False)
            if self.xserver:
                self.xserver.terminate()
                self.xserver.wait(timeout=10)
            self.completed = True
            self.save()
        failures = [c for c in self.checks if c["status"] == "FAIL"]
        if not failures and self.args.phase == "all":
            (self.repo / "artifacts" / "latest-e2e.txt").write_text(self.out.name + "\n")
        (self.out / "status.txt").write_text("FAIL\n" if failures else "DONE\n")
        self.log(f"{len(self.checks) - len(failures)}/{len(self.checks)} passed; {len(self.captures)} captures; {self.out.name}")
        return bool(failures)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--repo", type=Path, default=Path(__file__).resolve().parent.parent)
    parser.add_argument("--binary", default="~/.local/bin/kdash")
    parser.add_argument("--namespace", default="kdash-e2e")
    parser.add_argument("--context")
    parser.add_argument("--output", type=Path)
    parser.add_argument("--gallery", default="samples/cli_4232")
    parser.add_argument("--setup", action="store_true", help="create the isolated, intentionally healthy/unhealthy fixture resources")
    parser.add_argument("--phase", choices=("all", "cli", "ui"), default="all")
    parser.add_argument("--workers", type=int, default=1, help="CLI checks run one by one by default")
    parser.add_argument("--no-render", action="store_true")
    parser.add_argument("--native-screenshots", action="store_true", help="also capture actual xterm windows on an isolated local Xvfb display")
    args = parser.parse_args()
    if args.workers < 1 or args.workers > 4:
        parser.error("--workers must be between 1 and 4")
    raise SystemExit(LiveE2E(args).run())


if __name__ == "__main__":
    main()
