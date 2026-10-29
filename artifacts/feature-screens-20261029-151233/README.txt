kdash 4.13.1 feature screens - raw captures

What this is
  22 saved terminal screens of kdash 4.13.1, taken live against a local WSL vcluster
  (namespace default) to document the views that did not exist in 4.12.0 and the
  inspector: 8 SERVICES, 9 STORAGE, E Events, ! explanations, DOCTOR, the inspector
  pod picker, its find / only-matches / container-picker / help screens, plus the
  tab bar in view 1 and two 100-column layouts.

Files
  raw/<screen>.ansi   tmux capture-pane -e -p - the screen with colours, exactly as
                      tmux had it (one file per screen, 170x50 or 100x40)
  raw/<screen>.txt    the same screen as plain text, for grepping and diffing
  captures.tsv        file, columns, rows, title, rendered png
  The PNGs themselves live in ../../samples/cli_413/ and are listed, with checksums,
  in that directory.

How it was produced
  1. tmux -L kdfeat new-session -d -s kdfeat -x 170 -y 50 \
       "bash -l /tmp/kdash-run.sh"                    # the installed 4.13.1 against the vcluster
  2. one capture per screen, in this order: 1..9, E, !, `:` doctor, Enter (pick a pod),
     Enter (summary), p (previous logs), / + pattern, & + pattern, c, ?, q, q, ?
  3. tmux capture-pane -e -p > raw/<screen>.ansi and tmux capture-pane -p > raw/<screen>.txt
  4. bash scripts/redact-run.sh --map <private map> artifacts/feature-screens-<stamp>
  5. python scripts/capture-terminal.py raw/<screen>.ansi samples/cli_413/<screen>.png \
       --columns <n> --rows <n> --title "<title>"

Redaction
  The captures were rewritten with scripts/redact-run.sh and a private mapping that is
  not in this repository: the context is published as devops-admin@local-cluster, the
  personal paths as /home/demo, the host as node, and the other tenants of the shared
  development cluster as ml-service-prod, ml-service-dev and gitops-core. The images in
  samples/cli_413/ were re-rendered from the redacted captures, so text and pixels agree.

Scope and limits
  This is not a five-minute validation run: it shows one moment per view, so it says
  nothing about long-run behaviour, and it is viewport evidence - a table longer than
  50 rows continues below the visible area. Values are the cluster's own.
