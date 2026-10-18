#!/usr/bin/env bash
export TZ=Asia/Kolkata TERM=xterm-256color
export KDASH_REPORT_DIR=/home/demo/OneDrive/Desktop/AI\ Projects/kdash/artifacts/feature-screens-20261018-135611/reports KDASH_AUDIT_DIR=/home/demo/OneDrive/Desktop/AI\ Projects/kdash/artifacts/feature-screens-20261018-135611/audit
export KDASH_COLUMNS=170 KDASH_LINES=50 KDASH_SAMPLE_EVERY=5
export KDASH_ACCEPT_DISCLAIMER=1
exec kdash -c devops-admin@local-cluster -n orders-service-e2e -i 5
