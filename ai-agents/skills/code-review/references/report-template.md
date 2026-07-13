# Report Template

Use this structure when summarizing reviews back to the user.

Analysis-turn rule: when no GitHub mutation has happened yet, phrase recommendations as pending actions, not completed actions. Include both `My suggestion is ...` and `NEED YOUR APPROVAL TO SUBMIT` in the report.

Do not pad the report. If a section is empty, omit it unless it communicates an important absence of proof.

```text
PR #<n> - <title>
- Context: <PR | Linear MCP | dune-explore | coding | go-development | CI logs | ...>
- Verdict: <approved | approved, with suggestions | changes requested | significant issues>

My suggestion is: <approve | approve with suggestions | request changes | leave comments only>

Bar-raiser result:
  - Guidelines: <loaded/missing skills and impact>
  - Simplification: <passed | issue>
  - Idioms/readability: <passed | issue>
  - Call-flow/API semantics: <verified | unclear | issue>
  - Proof: <tests/CI/runtime evidence or gap>

Blockers:
  - <principle>: <issue + why it blocks + minimal fix + file:line>

Suggestions:
  - <principle>: <high-value non-blocking improvement + why it matters + better pattern + file:line>

Questions:
  - <blocking or non-blocking question, marked clearly>

Draft comments:
  - <severity>: <exact comment text>

Unverified:
  - <what you couldn't prove>

NEED YOUR APPROVAL TO SUBMIT
```

For stacked PRs:

```text
Stack summary
- <base PR>: <verdict>
- <child PR>: <verdict>
- Cross-stack risks: <shared dependency or contract issue>
```

Rules:
- Approval is earned, not the default. Recommend approval only when the bar-raiser checks pass.
- A blocker must explain the concrete risk and the smallest acceptable fix.
- Style is a blocker when it violates loaded guidelines, hides semantics, or makes the code materially harder to maintain.
- Extra branches, arg/mode/type variants, nil checks, fallbacks, retries, or compatibility paths may be YAGNI/overengineering when the current product path cannot produce them. Verify whether the state is truly supported; otherwise simplify and keep cyclomatic complexity low.
- Suggestions should be few and high-value. Do not include a `Nits` section by default.
- Praise is optional and should be limited to materially good decisions, not morale padding.
- Questions are for uncertainty. Never assert what you cannot prove.
- If a concern is already addressed or scoped in the PR discussion, omit it unless you have new evidence; if you keep it, explain why the discussion does not resolve it.
- For compatibility risks, request changes only when you can point to a concrete unmanaged consumer or rollout failure mode.
- Draft comments are optional. Zero is fine when the PR is actually clean.
