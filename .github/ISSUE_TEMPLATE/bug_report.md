---
name: Bug report
about: A wrong value, a crash, a broken layout or a command that does not work
title: ''
labels: bug
assignees: ''
---

**What happened**
<!-- What you saw, and what you expected instead. -->

**How to reproduce**
1. command you ran, for example `kdash -n my-namespace -v pods`
2. key you pressed, if it happened in the dashboard
3. what the screen showed

**Environment**
- kdash version (`kdash --version`):
- operating system and shell (`uname -sr`, `bash --version | head -1`):
- terminal (`echo $TERM`, columns x rows) and whether you use tmux or screen:
- `awk --version | head -1` (gawk, mawk or busybox):
- `kubectl version --client | head -1`:
- Kubernetes version and whether it is a managed cluster or a vcluster:

**What the evidence says**
<!-- A text export is worth more than a description:
     kdash -v pods --once > out.txt   (or -o tsv / -o csv)  -->
```text

```

**Anything else**
<!-- Screenshots are welcome, but redact context, namespace, host and IP names
     if you cannot share them. -->
