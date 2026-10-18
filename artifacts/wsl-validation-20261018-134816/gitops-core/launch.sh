#!/usr/bin/env bash
# live kdash run: namespace gitops-core, context devops-admin@local-cluster, 5 minute observation window
export TZ='Asia/Kolkata' TERM=xterm-256color
export KDASH_REPORT_DIR='/workspace/kdash/artifacts/wsl-validation-20261018-134816/gitops-core/reports'
export KDASH_AUDIT_DIR='/workspace/kdash/artifacts/wsl-validation-20261018-134816/gitops-core/audit'
export KDASH_ACCEPT_DISCLAIMER=1
export KDASH_COLUMNS=170 KDASH_LINES=50 KDASH_SAMPLE_EVERY=5
date +%s > '/workspace/kdash/artifacts/wsl-validation-20261018-134816/gitops-core/started.epoch'; date -Is > '/workspace/kdash/artifacts/wsl-validation-20261018-134816/gitops-core/started.iso'
kdash -c 'devops-admin@local-cluster' -n 'gitops-core' -i 5
rc=$?
printf '%s\n' "$rc" > '/workspace/kdash/artifacts/wsl-validation-20261018-134816/gitops-core/exit-status.txt'
date +%s > '/workspace/kdash/artifacts/wsl-validation-20261018-134816/gitops-core/ended.epoch'; date -Is > '/workspace/kdash/artifacts/wsl-validation-20261018-134816/gitops-core/ended.iso'
exit "$rc"
