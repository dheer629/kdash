#!/usr/bin/env bash
export TZ=Asia/Kolkata TERM=xterm-256color
export KDASH_REPORT_DIR=/home/demo/OneDrive/Desktop/AI\ Projects/kdash/artifacts/feature-screens-20261018-123152/reports KDASH_AUDIT_DIR=/home/demo/OneDrive/Desktop/AI\ Projects/kdash/artifacts/feature-screens-20261018-123152/audit
export KDASH_COLUMNS=170 KDASH_LINES=50 KDASH_SAMPLE_EVERY=5
export XDG_CONFIG_HOME=/home/demo/OneDrive/Desktop/AI\ Projects/kdash/artifacts/feature-screens-20261018-123152/xdg
exec kdash -c devops-admin@local-cluster -n orders-service-e2e -i 5
