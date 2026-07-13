---
name: log-investigator
description: Investigate application failures from logs in local processes, containers, and Kubernetes. Use this whenever the user mentions logs, `stern`, `kubectl logs`, error bursts, missing traces, or wants to correlate a failure across services or repos under `~/dune/`, especially when the owning repo or worktree is unclear.
compatibility: opencode
---

## What I do
- Turn a vague symptom into a bounded investigation.
- Map a service or binary back to the owning repo under `~/dune/`.
- Correlate failures across services with stable identifiers, not guesswork.
- Separate hard evidence from hypotheses and next checks.

## Workspace model
- Canonical repos live at `~/dune/<repo>`.
- Worktrees live at `~/dune/_worktrees/<repo>-<topic>`.
- Do not treat every top-level directory in `~/dune/` as a primary repo.
- Prefer the canonical repo for ownership and architecture questions.
- Prefer the active worktree only when the issue is branch-specific or involves uncommitted changes.

## Scope first
Establish these before diving into logs:
- Runtime: local process, container, Kubernetes workload, CI job, or batch job.
- Time window: exact failure time or the smallest safe window around it.
- Identity: service, deployment, pod, job, worker, chain, tenant, or endpoint.
- Correlation keys: `trace_id`, `request_id`, `job_id`, `query_id`, `block_number`, `tx_hash`, `chain`, `pod`, `namespace`.

If the owning component is unclear, identify it first from config, deployment names, binary names, or import paths, then inspect logs.

## Investigation order
1. Start from the first user-visible symptom, not the loudest downstream error.
2. Pull logs closest to the failing component first.
3. Check previous-container logs when restarts or crash loops are involved.
4. Correlate upstream and downstream services over the same time window.
5. Cross-check the code path in the owning repo after the failing boundary is clear.
6. Use metrics and traces to confirm scope, rate, or blast radius, not as a substitute for evidence.

## Log reading rules
- Prefer structured logs over free text.
- Anchor on stable fields and exact timestamps.
- Filter probe, readiness, and other repetitive noise early.
- Distinguish the trigger from the cascade: first error, then follow-on errors.
- Track retries, backoff, and timeout patterns; repeated noise often hides the first useful line.
- When multiple pods disagree, note which pod, revision, and node produced the evidence.

## Common failure classes
- Startup/config errors: bad env, missing secret, invalid flag, incompatible config.
- Dependency failures: DNS, TLS, auth, pool exhaustion, upstream timeout, circuit breaker.
- Rollout drift: new code talking to old schema, old worker consuming new event shape, bad canary.
- Resource pressure: OOM, CPU starvation, queue buildup, consumer lag, disk pressure.
- Data-triggered failures: malformed input, poison message, chain-specific edge case, one bad tenant.

## Repo crossover
Once the failing component is known, inspect the smallest relevant code surface:
- Entrypoint or server wiring.
- Handler/use-case for the failing operation.
- Downstream client or DB adapter.
- Related migrations, schemas, manifests, or feature flags.
- Tests covering the failing path or its assumptions.

Always say whether the code evidence came from the canonical repo, a worktree, or both.

## Output format
When using this skill, return:
1. Likely root cause in one sentence.
2. Evidence: the specific log pattern or correlated signals.
3. Scope: which service, runtime, repo, and revision/worktree are implicated.
4. Remaining unknowns.
5. Next checks or the smallest concrete fix.
