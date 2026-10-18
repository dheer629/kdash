#!/usr/bin/env bash
# live kdash run: namespace orders-service-e2e, context devops-admin@local-cluster, 5 minute observation window
export TZ='Asia/Kolkata' TERM=xterm-256color
export KDASH_REPORT_DIR='/workspace/kdash/artifacts/wsl-validation-20261018-134816/orders-service-e2e/reports'
export KDASH_AUDIT_DIR='/workspace/kdash/artifacts/wsl-validation-20261018-134816/orders-service-e2e/audit'
export KDASH_ACCEPT_DISCLAIMER=1
export KDASH_COLUMNS=170 KDASH_LINES=50 KDASH_SAMPLE_EVERY=5
date +%s > '/workspace/kdash/artifacts/wsl-validation-20261018-134816/orders-service-e2e/started.epoch'; date -Is > '/workspace/kdash/artifacts/wsl-validation-20261018-134816/orders-service-e2e/started.iso'
kdash -c 'devops-admin@local-cluster' -n 'orders-service-e2e' -i 5
rc=$?
printf '%s\n' "$rc" > '/workspace/kdash/artifacts/wsl-validation-20261018-134816/orders-service-e2e/exit-status.txt'
date +%s > '/workspace/kdash/artifacts/wsl-validation-20261018-134816/orders-service-e2e/ended.epoch'; date -Is > '/workspace/kdash/artifacts/wsl-validation-20261018-134816/orders-service-e2e/ended.iso'
exit "$rc"
