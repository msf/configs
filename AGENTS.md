# Config repository workflow

- Before diagnosing or editing shared configuration, inspect `git status -sb`, fetch `origin`, and check upstream divergence. Reconcile stale checkout state first. If existing changes have unclear intent or ownership, stop and ask; never discard or sweep them into your commit.
- Every completed config change or iteration must end with relevant validation and a small, coherent commit. Stage explicit paths. This repository authorizes these local commits as part of editing; do not leave changes uncommitted between iterations or handoffs. Keep secrets and machine-generated state out of commits.
- Before reporting completion, verify `git status --porcelain` is empty in the canonical `~/configs` checkout. If safe cleanup is blocked, name the remaining paths and blocker. Push only when requested; after an authorized rebase/push, verify the checkout matches upstream.
- For managed agent resources, follow `ai-agents/tools/README.md` and `ai-agents/tools/manifest.txt`, then run `tools/apply.sh --verify` from `ai-agents/` and the `pi-skill-import` audit. Repository commits do not prove live deployment; report those checks separately.
