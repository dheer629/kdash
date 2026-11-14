#!/usr/bin/env python3
"""Serial, opt-in Secrets map checks against a real local Kubernetes namespace.

Default: read existing metadata/public certificates only. --setup adds three
synthetic Secrets and one consumer Pod/Service in an explicit kdash-e2e namespace;
only those labeled fixtures are removed afterwards. --screenshots also captures
real tmux/xterm screens through the existing live harness. No existing private
key or opaque Secret value is fetched by this validator.
"""
from __future__ import annotations

import argparse
import base64
import csv
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import tempfile
import time

CANARY = "KDASH_SYNTHETIC_VALUE_DO_NOT_EXPORT_4f9e2"
LABEL = "kdash.validation/secrets-live"
PREFIX = "kdash-secrets-live"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, default=Path(__file__).resolve().parent.parent)
    parser.add_argument("--binary", default="~/.local/bin/kdash")
    parser.add_argument("--context", default="vcluster-docker_dev")
    parser.add_argument("--namespace", default="kdash-e2e")
    parser.add_argument("--output", type=Path)
    parser.add_argument("--gallery", default="samples/cli_4320/secrets")
    parser.add_argument("--setup", action="store_true")
    parser.add_argument("--keep-fixtures", action="store_true")
    parser.add_argument("--screenshots", action="store_true")
    parser.add_argument("--keycheck-namespace", help="existing namespace containing generated TLS fixtures only")
    args = parser.parse_args()
    args.repo = args.repo.resolve()
    args.output = (args.output or args.repo / "artifacts/live-e2e-v4320/secrets").resolve()
    args.output.mkdir(parents=True, exist_ok=True)
    if args.setup and not re.fullmatch(r"kdash-e2e(?:-[a-z0-9-]+)?", args.namespace):
        parser.error("--setup requires a named kdash-e2e test namespace")
    spec = importlib.util.spec_from_file_location("kdash_live_e2e", args.repo / "scripts/live-e2e.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    args.phase = "secrets"; args.native_screenshots = args.screenshots
    args.no_render = False; args.workers = 1
    live = module.LiveE2E(args)
    live.env.update(KDASH_SECRETS_KEYCHECK="0", KDASH_LOGIN_CHECK="0", KDASH_CERT_CHECK="0")
    real_kubectl = shutil.which("kubectl")
    if not real_kubectl:
        parser.error("kubectl must be installed in the selected WSL shell")
    kc = [real_kubectl, "--context", args.context, "-n", args.namespace]
    created = []
    all_checks_finished = False
    wrapper = args.output / "work/bin"
    wrapper.mkdir(parents=True, exist_ok=True)
    kubectl_calls = args.output / "kubectl-calls.jsonl"
    kubectl_calls.write_text("")
    (wrapper / "kubectl").write_text(
        "#!/usr/bin/env python3\nimport json,os,sys\n"
        "with open(os.environ['SECRETS_LIVE_CALLS'],'a') as f: f.write(json.dumps(sys.argv[1:])+chr(10))\n"
        "os.execv(os.environ['SECRETS_LIVE_KUBECTL'],[os.environ['SECRETS_LIVE_KUBECTL'],*sys.argv[1:]])\n")
    (wrapper / "kubectl").chmod(0o755)
    live.env.update(PATH=str(wrapper) + os.pathsep + live.env["PATH"],
                    SECRETS_LIVE_CALLS=str(kubectl_calls), SECRETS_LIVE_KUBECTL=real_kubectl)

    def record(name, passed, detail=""):
        live.record("secrets-" + name, passed, detail)

    def command(name, extra, codes=(0,), expect=(), env=None, timeout=120):
        previous = live.env.copy()
        live.env.update(env or {})
        try:
            result = live.cli(name, extra, expect=expect, codes=codes, timeout=timeout)
            live.finish_cli(result)
            return (args.output / "logs" / (name + ".log")).read_text()
        finally:
            live.env = previous

    def apply_fixture(obj, namespace=None):
        namespace = namespace or args.namespace
        scoped_kc = [real_kubectl, "--context", args.context, "-n", namespace]
        name = obj["metadata"]["name"]; kind = obj["kind"].lower()
        prior = subprocess.run(scoped_kc + ["get", kind, name, "-o", "jsonpath={.metadata.labels.kdash\\.validation/secrets-live}"],
                               stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        if prior.returncode == 0 and prior.stdout != "true":
            raise RuntimeError(f"refusing to replace existing unlabeled fixture {kind}/{name}")
        obj["metadata"].update(namespace=namespace, labels={LABEL: "true", "app": PREFIX})
        applied = subprocess.run(scoped_kc + ["apply", "-f", "-"], input=json.dumps(obj),
                                 stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        if applied.returncode:
            raise RuntimeError(f"cannot apply named {kind}/{name}: {applied.stderr}")
        created.append((namespace, kind, name))

    def setup():
        if args.keycheck_namespace:
            if not re.fullmatch(r"kdash-e2e-secrets-keycheck(?:-[a-z0-9-]+)?", args.keycheck_namespace):
                raise RuntimeError("generated keycheck fixtures need a named kdash-e2e-secrets-keycheck namespace")
            namespace_obj = {"apiVersion": "v1", "kind": "Namespace", "metadata": {
                "name": args.keycheck_namespace, "labels": {LABEL: "true"}}}
            prior = subprocess.run([real_kubectl, "--context", args.context, "get", "namespace", args.keycheck_namespace,
                                    "-o", "jsonpath={.metadata.labels.kdash\\.validation/secrets-live}"],
                                   stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            if prior.returncode == 0 and prior.stdout != "true":
                raise RuntimeError("refusing to replace an unlabeled keycheck namespace")
            subprocess.run([real_kubectl, "--context", args.context, "apply", "-f", "-"], input=json.dumps(namespace_obj),
                           check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            created.append((None, "namespace", args.keycheck_namespace))
        with tempfile.TemporaryDirectory(prefix="kdash-secrets-certs-") as tmp:
            tmp = Path(tmp)
            for stem in ("match", "other"):
                subprocess.run(["openssl", "req", "-x509", "-newkey", "ec", "-pkeyopt", "ec_paramgen_curve:P-256",
                                "-nodes", "-days", "2", "-subj", f"/CN={PREFIX}-{stem}.example.invalid",
                                "-addext", f"subjectAltName=DNS:{PREFIX}-{stem}.example.invalid",
                                "-keyout", str(tmp / (stem + ".key")), "-out", str(tmp / (stem + ".crt"))],
                               check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
            cert = base64.b64encode((tmp / "match.crt").read_bytes()).decode()
            for suffix, key in (("valid", "match"), ("mismatch", "other")):
                obj = {"apiVersion": "v1", "kind": "Secret", "metadata": {"name": PREFIX + "-" + suffix},
                       "type": "kubernetes.io/tls", "data": {"tls.crt": cert,
                       "tls.key": base64.b64encode((tmp / (key + ".key")).read_bytes()).decode()}}
                apply_fixture(obj)
                if args.keycheck_namespace:
                    apply_fixture(json.loads(json.dumps(obj)), args.keycheck_namespace)
            apply_fixture({"apiVersion": "v1", "kind": "Secret", "metadata": {"name": PREFIX + "-opaque"},
                           "type": "Opaque", "stringData": {"canary": CANARY}})
        apply_fixture({"apiVersion": "v1", "kind": "Pod", "metadata": {"name": PREFIX + "-consumer"}, "spec": {
            "containers": [{"name": "consumer", "image": "busybox:1.36", "command": ["sleep", "3600"],
                            "env": [{"name": "SYNTHETIC_SECRET", "valueFrom": {"secretKeyRef": {
                                "name": PREFIX + "-opaque", "key": "canary"}}}],
                            "volumeMounts": [{"name": "public-tls", "mountPath": "/fixture/tls", "readOnly": True}]}],
            "volumes": [{"name": "public-tls", "secret": {"secretName": PREFIX + "-valid"}}]}})
        apply_fixture({"apiVersion": "v1", "kind": "Service", "metadata": {"name": PREFIX}, "spec": {
            "selector": {"app": PREFIX}, "ports": [{"name": "http", "port": 80, "targetPort": 8080}]}})
        ready = subprocess.run(kc + ["wait", "--for=condition=Ready", "pod/" + PREFIX + "-consumer", "--timeout=90s"],
                               stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        record("fixture-pod-ready", ready.returncode == 0, "isolated labeled consumer Pod, TLS volume and env reference")

    try:
        record("installed-source-identical", live.installed_sha256 == live.source_sha256,
               "installed binary and repository CLI have the same SHA-256")
        if args.setup:
            setup()
        metadata = subprocess.run(kc + ["get", "secrets", "-o", "custom-columns=NAME:.metadata.name,TYPE:.type", "--no-headers"],
                                  check=True, stdout=subprocess.PIPE, text=True).stdout
        (args.output / "inventory-metadata.txt").write_text(metadata)
        names = {row.split()[0] for row in metadata.splitlines() if row.strip()}
        raw = command("secrets-json", ["--secrets", "-o", "json"])
        data = json.loads(raw)
        record("json-schema-and-inventory", data.get("secrets_access") == "ok" and
               {item["name"] for item in data["secrets"]} == names,
               "JSON parses and matches the live names-only Secret inventory")
        for fmt, delimiter in (("csv", ","), ("tsv", "\t")):
            text = command("secrets-" + fmt, ["--secrets", "-o", fmt])
            rows = list(csv.DictReader(io.StringIO(text), delimiter=delimiter))
            record(fmt + "-schema-and-inventory", bool(rows) and {row["SECRET"] for row in rows} == names and
                   all(len(row) == 28 for row in rows), "28-column export matches live Secret names")
        text = command("secrets-text", ["--secrets", "--ascii", "--no-color"],
                       expect=("CERTIFICATES IN SECRETS", "WHERE EACH SECRET IS USED", "ALL SECRETS", "FINDINGS"))
        command("secrets-alias", ["--secret-map", "-o", "json"], expect=('"secrets_access":"ok"',))
        command("secrets-view-alias", ["--once", "-v", "secrets", "-o", "tsv"], expect=("NAMESPACE", "SECRET"))
        html_output = command("secrets-html", ["--secrets", "-o", "html"])
        html_path = Path(html_output.strip().splitlines()[-1])
        html = html_path.read_text()
        record("html-semantics", all(token in html.lower() for token in ("<html", "secrets map", "certificates", "where")),
               str(html_path.relative_to(args.output)))
        default_calls = [json.loads(row) for row in kubectl_calls.read_text().splitlines()]
        record("default-does-not-fetch-private-key", not any('go-template={{index .data "tls.key"}}' in row for call in default_calls for row in call),
               "real kubectl invocation trace contains no private-key value request")
        exposed = any(token in (raw + text + html) for token in
                      (CANARY, base64.b64encode(CANARY.encode()).decode(), "-----BEGIN PRIVATE KEY-----", "-----BEGIN EC PRIVATE KEY-----"))
        record("exports-exclude-value-canary-and-private-pem", not exposed,
               "only names, types, key names/sizes and public certificate metadata appear")
        critical = any("CRIT" in finding["severity"] for finding in data["findings"])
        warning = any("WARN" in finding["severity"] for finding in data["findings"])
        for level in ("high", "medium", "low"):
            expected = 2 if critical else 1 if warning and level != "high" else 0
            command("secrets-fail-on-" + level, ["--secrets", "--fail-on", level], codes=(expected,))
        if data["findings"]:
            command("secrets-run-finding", ["--secrets", "--run", "1"],
                    expect=("READ|CHECK|COMMAND|read commands",), codes=(0, 1), timeout=180)
        command("secrets-run-invalid", ["--secrets", "--run", "999999"], codes=(1,), expect=("no read|not found|no commands|does not exist",))
        if args.setup:
            lookup = {secret["name"]: secret for secret in data["secrets"]}
            valid = lookup[PREFIX + "-valid"]
            certificate = any(cert["subject"] == PREFIX + "-match.example.invalid"
                              for cert in valid["certificates"])
            consumer = any(use["workload"] == "pod/" + PREFIX + "-consumer" and
                           use["pod"] == PREFIX + "-consumer" and
                           use["container"] == "consumer" and
                           use["path_in_container"] == "/fixture/tls/{tls.crt,tls.key}" and
                           bool(use["node"]) for use in valid["used_by"])
            record("fixture-public-certificate-and-consumer", certificate and consumer,
                   "live certificate subject, projected file paths, workload and node are mapped")
        if args.keycheck_namespace:
            safety = subprocess.run([real_kubectl, "--context", args.context, "-n", args.keycheck_namespace,
                "get", "secrets", "-o", "custom-columns=NAME:.metadata.name", "--no-headers"],
                check=True, stdout=subprocess.PIPE, text=True).stdout.split()
            if not safety or any(not name.startswith(PREFIX + "-") for name in safety):
                raise RuntimeError("keycheck namespace must contain generated test fixtures only")
            keyed = json.loads(command("secrets-keycheck", ["-n", args.keycheck_namespace, "--secrets", "-o", "json"],
                                        env={"KDASH_SECRETS_KEYCHECK": "1"}))
            lookup = {secret["name"]: secret for secret in keyed["secrets"]}
            record("keycheck-valid", any(cert["private_key"] == "tls.key matches" for cert in lookup[PREFIX + "-valid"]["certificates"]),
                   "generated fixture private key matches its public certificate")
            record("keycheck-mismatch", any("DOES NOT MATCH" in cert["private_key"] for cert in lookup[PREFIX + "-mismatch"]["certificates"]),
                   "generated mismatched fixture key is detected")
        if args.screenshots:
            session = live.start_dashboard("secrets", extra=("--no-io",), columns=170, rows=50)
            live.key(session, "Y", delay=5)
            live.capture(session, "92-secrets", "Live Secrets map: certificate expiry and access", "CERTIFICATES IN SECRETS")
            live.key(session, "j", "j", "l", delay=1)
            live.capture(session, "93-secrets-pan", "Secrets map scroll and horizontal pan")
            live.key(session, "0", "g", "?", delay=1)
            live.capture(session, "94-secrets-help", "Secrets map help and read-only behavior", "SECRETS MAP")
            live.key(session, "x", "Enter", delay=1)
            live.capture(session, "95-secrets-run-prompt", "Secrets finding read-command prompt", "finding|commands")
            live.key(session, "Escape", "x", delay=2)
            live.key(session, "Y", "e", delay=1)
            live.text(session, "c", delay=3)
            live.capture(session, "96-secrets-export", "Secrets map HTML export from the live dashboard")
            live.key(session, "Q", delay=1)
            live.render()
        all_checks_finished = True
    except Exception as error:
        record("harness-exception", False, str(error))
    except KeyboardInterrupt:
        record("harness-interrupted", False, "validation interrupted before all checks finished")
    finally:
        live.tm("kill-server", check=False)
        if live.xserver:
            live.xserver.terminate(); live.xserver.wait(timeout=10)
        if created and not args.keep_fixtures:
            for namespace, kind, name in reversed(created):
                cleanup_kc = [real_kubectl, "--context", args.context] + (["-n", namespace] if namespace else [])
                subprocess.run(cleanup_kc + ["delete", kind, name, "--ignore-not-found=true", "--wait=false"],
                               stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        live.completed = all_checks_finished; live.save()
        failures = [check for check in live.checks if check["status"] != "PASS"]
        (args.output / "status.txt").write_text("DONE\n" if all_checks_finished and not failures else "FAIL\n")
        print(f"{len(live.checks) - len(failures)}/{len(live.checks)} Secrets checks passed", flush=True)
    return bool(failures)


if __name__ == "__main__":
    raise SystemExit(main())
