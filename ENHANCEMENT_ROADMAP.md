**kdash: the next 10 enhancements for DevOps**

**Status (kdash 4.13.0):** items 1-5 below are implemented: doctor and resilient refresh, the pod inspector with command palette and structured filters, Events and evidence-backed explanations, the service/backend map and storage health. The `-A` ordering, stale-empty-snapshot and blocking-collection defects are fixed and covered by `tests/test-runtime.sh`. Items 6-10 remain proposals. The text of each item is kept as originally written; the "Current foundation" notes describe 4.12.0.

Reviewed on 2026-10-29 against the repository's 4.12.0 implementation. Items 6-10 are proposed additions, not implemented functionality. The ranking weighs daily operator usefulness, time saved during incidents, trust in the output, and fit with the existing project. Effort is relative: S = contained change, M = a new workflow or collector, L = multiple collectors or substantial interaction/history work. It is not a delivery estimate.

kdash already offers seven views, actionable alerts, namespace switching, filtering, themes, pause, memory forecasts, recorded sessions, HTML/CSV/TSV reports, and auditing. Its next step should connect observations, evidence, and the next useful troubleshooting action. The reviewed foundations are the [CLI](kdash), [README](README.md), [DevOps guide](DEVOPS_USER_GUIDE.md), [contribution rules](CONTRIBUTING.md), [security policy](SECURITY.md), [tests](tests/test-uninstall.sh), and [CI](.github/workflows/ci.yml).

| Rank | Proposed enhancement | Question it should answer | Effort |
|---|---|---|---|
| 1 | Guided doctor and resilient connections | Why can I not connect, and which data can I trust? | M |
| 2 | Selectable resource inspector and command palette | Can I investigate this pod without leaving the dashboard? | L |
| 3 | Kubernetes Events and evidence-backed incident explanations | What is failing, what might explain it, and what should I check next? | L |
| 4 | Service and backend health map | Why is the application unreachable when its pods look healthy? | L |
| 5 | Storage and volume health | Is storage preventing startup or approaching capacity? | M |
| 6 | Deployment changes and release diagnosis | What changed before the failure, and why is the rollout stuck? | L |
| 7 | Saved workspaces across contexts | How can I move between environments without losing my place? | M |
| 8 | Resource, scaling, and resilience advisor | Why will this workload not scale, and where is capacity wasted? | L |
| 9 | Configurable alert policies and automated health checks | Which signals need attention for this particular workload? | M |
| 10 | Offline incident replay and reviewed handoff bundles | Can another engineer reconstruct what happened without cluster access? | L |

**1. Guided doctor and resilient connections**

Add a read-only `kdash --doctor` that identifies the selected kubeconfig/context, endpoint reachability, TLS/authentication failures, relevant RBAC permissions, Metrics API availability, IO sources, and writable local report/audit directories. Show a useful next check for each failure. A missing Metrics API should produce a capability explanation while structural views remain available. Kubernetes documents CPU/memory resource metrics as a separate pipeline, so their absence should be diagnosed separately from object access. [Kubernetes monitoring documentation](https://kubernetes.io/docs/tasks/debug/debug-cluster/resource-usage-monitoring/).

During a session, retain the last complete snapshot with a conspicuous age and source status, retry failed reads with bounded backoff, and recover when the same endpoint becomes available. WSL/vcluster guidance should help users repair their existing connection without silently changing their default kubeconfig or starting infrastructure.

Current foundation: error classification is broad at [kdash:798](kdash#L798), collection is synchronous at [kdash:961](kdash#L961), and troubleshooting currently requires separate commands in the [guide](DEVOPS_USER_GUIDE.md#9-troubleshooting). The earlier local launch encountered an inactive endpoint, TLS mismatch, unavailable metrics, and a transient container startup failure; those observations motivate this feature but do not establish their frequency elsewhere.

Acceptance: a refused endpoint, denied pods access, and unavailable metrics each produce distinct guidance; retries do not freeze keyboard input; every retained source shows its last successful read; a recovered source clears its stale state.

**2. Selectable resource inspector and command palette**

Add a selected row and an Enter action that opens pod/container details, bounded current and previous logs, describe output, and related events. Preserve the selected object and scroll position when returning. Show full names, explicit context/namespace, exit reason/code/time, and a container picker. Fetch expensive detail on demand. Current and previous container logs are standard Kubernetes debugging inputs. [Kubernetes pod debugging](https://kubernetes.io/docs/tasks/debug/debug-application/debug-running-pod/#examining-pod-logs).

Add a searchable command palette, visible shortcut hints, an Escape/back path, and structured filters for labels, status, workload, node, and unhealthy resources. Extend the existing compact terminal layouts to the inspector and command palette. Retain the existing pod-regex filter. Shortcut assignments should be designed around current bindings rather than taking them over.

Current foundation: `j`/`k` move the viewport at [kdash:5477](kdash#L5477); `/` filters pod names at [kdash:5516](kdash#L5516). The wrapper already permits `logs` and `describe` at [kdash:162](kdash#L162), but alert rows currently print suggested commands at [kdash:2631](kdash#L2631). Resource navigation and log inspection are established interaction patterns in [K9s commands](https://k9scli.io/topics/commands/); the proposal adapts them to kdash's existing read-only workflow.

Acceptance: an operator can select a crashing container, inspect its previous log, and return to the same row using the keyboard. Log reads have time/size limits; logs are excluded from shared reports unless explicitly selected.

**3. Kubernetes Events and evidence-backed incident explanations**

Collect actual Kubernetes Events, including reason, message, object identity, count, and first/last observation. Correlate `FailedScheduling`, `FailedMount`, image-pull failures, and probe failures with the selected workload, restart changes, and existing charts. Deduplicate repeated events and show event coverage gaps.

Extend Alerts with a plain-language explanation containing observed facts, possible causes, contrary or missing evidence, and the next read-only check. Example: "Pod is Pending; the scheduler reports an unbound claim; PVC data is Pending. Check its storage class and provisioner events." Start with deterministic rules that work offline and require no external service. Label a hypothesis as a hypothesis; time proximity alone does not prove a cause.

Current foundation: the alert engine already has severity, commands, ages, trends, and hysteresis at [kdash:2596](kdash#L2596). Existing session events are changes inferred between polls at [kdash:2817](kdash#L2817), while the [guide](DEVOPS_USER_GUIDE.md#7-follow-a-read-only-triage-workflow) sends operators outside kdash to read Kubernetes Events.

Acceptance: every explanation links to timestamped object/event evidence; an absent Events permission shows unknown coverage; an application rollout does not automatically become the asserted cause of every later failure.

**4. Service and backend health map**

Show Ingress -> Service -> EndpointSlice -> ready backend pods, with selectors, service ports, target ports, and availability at each step. Flag absent references, selector mismatches, missing named target ports, no ready backends, and pending LoadBalancer addresses. Support selectorless and ExternalName services as distinct cases.

Surface relevant NetworkPolicy configuration and DNS component health where visible. Describe these as configuration evidence; actual end-to-end reachability requires information beyond an object relationship map. Kubernetes' service debugging workflow checks selectors, target ports, and EndpointSlices. [Kubernetes service debugging](https://kubernetes.io/docs/tasks/debug/debug-application/debug-service/).

Current foundation: IP Pool already shows service addresses and ports; the [service template](kdash#L784) lacks selectors and target ports, and the [collectors](kdash#L804) do not fetch EndpointSlices or Ingress objects.

Acceptance: a Service selecting zero pods explains the mismatch; pods that exist but are unready produce a different finding; denied EndpointSlice access does not become a zero-backend assertion.

**5. Storage and volume health**

Add Pod -> PVC -> PV relationships, storage class, claim phase, requested/provisioned capacity, access modes, relevant binding conditions, and mount/attach events. Identify which workloads depend on a problematic claim. Interpret delayed binding and missing permissions explicitly.

When an existing permitted kubelet/Prometheus source exposes volume statistics, add used/free bytes and growth. Keep provisioned capacity separate from measured filesystem usage. An unbound claim is a concrete storage state; Kubernetes documents that unmatched claims can remain unbound. [Kubernetes persistent volumes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/).

Current foundation: the current disk view measures container filesystem IO, described at [kdash:3028](kdash#L3028); it does not establish PVC binding health or volume fullness. The current structural [collectors](kdash#L804) have no PVC/PV collection.

Acceptance: a selected pod reveals its claims and binding/mount evidence; volume usage stays unavailable when only capacity is known; an inaccessible cluster-scoped PV still permits useful namespace-scoped PVC reporting.

**6. Deployment changes and release diagnosis**

Record changes to image references/resolved image IDs, pod templates, replicas, requests/limits, and probe configuration. Show a before/after summary next to readiness, restart, and metric changes. Add Deployment conditions/reasons, old/new ReplicaSet counts, init-container blockers, and Job/CronJob execution outcomes.

Answer: "The image changed at 10:42; readiness dropped at 10:43; the Deployment reports a progress deadline failure; new pods report failed readiness probes." State that the sequence is evidence to investigate. Keep chart history attached to object identities so replacement pods are distinguished from earlier instances.

Current foundation: rollout counts, generations, image names, and CronJob schedules already exist in [WL_TPL](kdash#L794). New work is richer conditions, Jobs/ReplicaSets, template differences, resolved image identity, and their connection to the [recorded history](kdash#L2848).

Acceptance: an image rollout produces a reviewable diff with an observation time; its failed revision can be distinguished from healthy older replicas; the UI distinguishes kdash observation time from an authoritative API timestamp.

**7. Saved workspaces across contexts**

Add an in-app context picker, favorites, environment labels, and saved workspace settings: context, namespace, view, filters, sort, and interval. Keep a prominent environment banner that remains clear without color. Switch using explicit per-process contexts, preserving the user's default kubeconfig context.

Follow with an opt-in overview of selected contexts: reachability, health, data age, and coverage. Apply strict concurrency and request budgets so fleet navigation does not multiply background API traffic without bounds.

Current foundation: explicit context selection is handled at [kdash:705](kdash#L705); there is already a namespace picker with recent namespaces at [kdash:5243](kdash#L5243). A live context picker and persisted whole-workspace state would extend that workflow.

Acceptance: switching between two contexts restores each workspace's namespace/filter/view, makes the environment immediately obvious, and leaves the default kubeconfig current-context unchanged.

**8. Resource, scaling, and resilience advisor**

Combine existing usage/request/limit history with HPA conditions and limits, ResourceQuota, LimitRange, PDB disruption allowances, and placement constraints. Explain blocked scaling using the scheduler and controller's actual reasons. Show which settings need examination before a drain or scale change.

Offer resource suggestions only from sufficient representative samples, displaying the time window, coverage, percentiles, peaks, and relevant restarts. A short local session is insufficient for production sizing. Use actual throttling counters from an existing permitted metrics source when available; high CPU utilization alone should be described as pressure or risk. Keep suggestions advisory. Kubernetes HPA behavior depends on readiness, missing metrics, and stabilization, which an explanation panel should preserve. [Kubernetes HPA documentation](https://kubernetes.io/docs/concepts/workloads/autoscaling/horizontal-pod-autoscale/).

Current foundation: requests/limits, forecasts, HA risk, and node comparisons already exist. The [collectors](kdash#L804) do not collect HPA/PDB/quota/LimitRange resources; current scheduling alerts suggest an external Events check at [kdash:2663](kdash#L2663).

Acceptance: the UI explains an HPA metric failure separately from a max-replica ceiling; PDB restrictions are shown as disruption policy; no sizing suggestion appears when history is missing or inadequate. Capacity hints never claim to reproduce the scheduler's full decision process.

**9. Configurable alert policies and automated health checks**

Build on the current alert engine with declarative per-environment/workload thresholds, minimum breach durations, startup grace periods, deduplication by workload, expiring mutes, and links to team runbooks. Show which policy produced a signal and make muted findings discoverable.

Add a proposed `--check` mode with a stable, versioned machine-readable result and documented exit statuses for healthy, warning, critical, and incomplete/unknown observations. This lets existing CI or monitoring tools consume kdash findings without creating a notification dependency. Use the same evaluation logic for terminal views, reports, and headless checks.

Current foundation: alerts already include age, actions, trends, and [hysteresis](kdash#L2607); the extension is configurable policies and a stable headless health contract. Current [validation](scripts/validate-all.sh#L44) runs uninstall integration tests, so alert fixtures are a prerequisite.

Acceptance: a brief expected startup delay is handled differently from a sustained outage; missing metrics never produce an unqualified all-clear; a machine result contains policy identity, scope, evidence age, and coverage.

**10. Offline incident replay and reviewed handoff bundles**

Extend saved sessions into an offline viewer with a timeline cursor, playback, before/after comparisons, operator notes, and captured Kubernetes Events/change records. Show only the evidence retained for each time; identify gaps and sampling intervals.

Provide a handoff export containing a concise incident narrative, affected workloads, selected evidence, relevant policy settings, missing sources, version, timestamps, and checksums. Add a redaction preview that writes a separate derivative bundle, omits logs by default, and preserves original audit records. Generate a local Markdown ticket/postmortem draft for an operator to review and send.

Current foundation: [session recording](kdash#L2788), [report reconstruction](kdash#L4746), and [redaction scripts](scripts/redact-run.sh) already exist. The new work is interactive replay, richer time-indexed evidence, and a guided sharing workflow. The [guide](DEVOPS_USER_GUIDE.md#8-audit-evidence) explains that altering audit bytes breaks their original hash chain.

Acceptance: another operator can open a captured incident without cluster credentials, inspect the retained timeline, and distinguish original evidence from a redacted derivative. The replay reader treats imported session metadata as data rather than executable shell input.

**Foundation work that should accompany the roadmap**

The following findings come from the inspected source and documented behavior. They are not claims that a complete runtime regression suite was executed during this review.

| Finding | Evidence | Required improvement |
|---|---|---|
| All-namespace startup can fail because scope flags precede the subcommand. | [kdash:736](kdash#L736), [kdash:806](kdash#L806), [guide limitation](DEVOPS_USER_GUIDE.md#3-start-a-namespace-session); also observed during the earlier local launch. | Centralize command construction and test exact argument ordering for startup, namespace switching, reports, and metrics. |
| A successful empty pod result can leave earlier pods displayed. | [kdash:810](kdash#L810) retains a previous nonempty spec instead of accepting a later successful empty snapshot. This is a source-derived risk. | Replace successful snapshots even when empty; retain previous data only on failures and mark it stale. |
| Slow reads can delay keyboard handling. | [fetch](kdash#L961) runs synchronously before the next key read in the [live loop](kdash#L5467); several core calls have no explicit request timeout. This is inferred from the control flow. | Use bounded background collection, atomic snapshot publication, cached capabilities, and request budgets. |
| Some signal names are stronger than their measurements. | [CPU_THROTTLE](kdash#L2636) is triggered by usage relative to a limit. | Label that as utilization/pressure risk; reserve measured throttling for actual counter evidence. |
| Automated behavior coverage is concentrated on uninstall. | [test-uninstall.sh](tests/test-uninstall.sh), [validation entry](scripts/validate-all.sh#L44), [CI](.github/workflows/ci.yml). Recorded live evidence is valuable but does not exercise every future edge case. | Add deterministic kubectl fixtures for RBAC, missing metrics, empty/deleted pods, outages, unit conversions, alert rules, reports, and the read-only guard; exercise supported awk implementations and representative clients. |

Keep the published [project rules](CONTRIBUTING.md#ground-rules-for-code): read-only cluster access, Bash/kubectl/awk/coreutils runtime, portable terminals, and a synchronized self-contained installer. Collect optional resources only when supported and permitted; fetch logs/detail on demand. Added Kubernetes permissions should be documented by capability. Build-time source separation may help maintenance while preserving one deployable Bash file. New configuration should use a constrained data format rather than execute user-provided expressions.

**Suggested delivery order**

First, fix command ordering, empty/stale data handling, collection bounds, and dashboard behavior tests. Ship the doctor and inspector next, followed by actual Kubernetes Events and incident explanations. These give operators a complete path from a failing startup or alert to useful evidence.

Then add service, storage, and release diagnosis using the shared inspector and event collection. Finish with saved workspaces, the scaling advisor, policy-driven checks, and richer replay/handoff. Introduce each new collector with explicit coverage states, request budgets, and matching terminal/report output.

The first release should be considered useful when an operator can diagnose a connection problem or investigate a failed pod from inside kdash, with explicit context, timestamped evidence, responsive navigation, and an accurate account of unavailable data.
