---
name: k8s-debug
description: Navigate and diagnose Kubernetes problems across clusters, namespaces, workloads, and GitOps sources. Use this whenever the user mentions `kubectl`, pods, deployments, Flux, Helm, ingress, DNS, crash loops, pending workloads, or wants to map a live object back to code under `~/dune/`.
compatibility: opencode
---

## What I do
- Turn a Kubernetes symptom into a short, ordered triage.
- Identify the owning context, namespace, workload, and repo.
- Map live objects back to manifests, charts, overlays, or infra code under `~/dune/`.
- Separate cluster-state issues from application issues and rollout drift.

## Workspace model
- Canonical repos live at `~/dune/<repo>`.
- Worktrees live at `~/dune/_worktrees/<repo>-<topic>`.
- Prefer the canonical repo when locating deployment sources.
- Use a worktree only when the user is debugging a branch-specific rollout or uncommitted manifest change.

## Start with identity
Always establish:
- kube context and cluster
- namespace
- workload type: Deployment, StatefulSet, DaemonSet, Job, CronJob, HelmRelease, Kustomization
- ownership chain: pod -> ReplicaSet/Controller -> Service -> Ingress/Gateway -> repo

If any of those are unknown, resolve them before theorizing.

## Triage order
1. Status: pod phase, restart count, ready condition, rollout status.
2. Events: scheduling failures, image pulls, probe failures, PVC issues, admission rejections.
3. Logs: current and previous container logs for the failing container.
4. Spec: image, args, env, probes, resources, volumes, service account, node selectors, tolerations.
5. Wiring: Service endpoints, DNS, ingress/gateway rules, network policy, secret/config references.
6. Ownership: manifest source in `k8s/`, `helm/`, `charts/`, `deploy/`, `infra/`, or GitOps directories.

## Failure classes
- Scheduling: taints, tolerations, selectors, resource requests, quotas, autoscaler lag.
- Startup: bad image, bad entrypoint, missing env/secret/config, init container failure.
- Probes: wrong path, port, timeout, startup threshold, dependency too slow.
- Networking: DNS, service selector mismatch, missing endpoints, ingress route, TLS, policy blocks.
- Storage: PVC pending, mount error, permissions, volume expansion, stale state.
- Auth/RBAC: service account mismatch, token mount assumptions, cloud IAM integration, denied verbs.
- GitOps drift: source revision mismatch, failed reconciliation, chart values mismatch, manual cluster edits.

## Repo mapping heuristics
When tracing a live object back to source, search in this order:
- App repo: `k8s/`, `deploy/`, `helm/`, `charts/`, `manifests/`
- Infra repo: `flux/`, `clusters/`, `apps/`, `environments/`, Terraform or platform overlays
- CI entrypoints: `.github/workflows/`, `Makefile`, `Taskfile`, release scripts

Do not stop at the first manifest match; verify it is the one feeding the live cluster.

## GitOps rules
- If Flux or another reconciler is present, treat the cluster as a rendered outcome, not the source of truth.
- Prefer finding the owning Kustomization, HelmRelease, or chart values before suggesting edits.
- Distinguish reconciliation failure from healthy reconciliation of bad config.

## Resource sizing
Size around memory certainty and CPU burstability:
- Set the memory limit ~10-15% above request for non-heap overhead (goroutine stacks, runtime internals); source `GOMEMLIMIT` from `requests.memory` as the GC soft target.
- Keep CPU requests frugal and avoid CPU limits; cap Go parallelism with `GOMAXPROCS`. Sanity-check reservations against measured usage and fleet ratios before reserving more.
- When reasoning about memory, separate node-free, pod-envelope, heap, and non-heap headroom explicitly and check the arithmetic.
- Exception: when the intent is full-node dedication or strict reservation symmetry, keep `request=limit` unless asked otherwise.

## Output format
When using this skill, return:
1. Diagnosis in one sentence.
2. Evidence from status, events, logs, or wiring.
3. Owning object chain and likely source repo/path.
4. Smallest fix or next command that reduces uncertainty fastest.
5. What remains inferred versus verified.
