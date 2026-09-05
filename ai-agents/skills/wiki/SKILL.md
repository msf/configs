---
name: wiki
description: Read and write the personal knowledge graph and TODO board at /srv/selfhost/wiki/. Use whenever you need to record, look up, cross-reference, or organize anything durable — local LLM internals (models, llama.cpp flags, MTP, spec-decoding, KV cache, SWA, quantisation), self-hosted infra, multi-session TODOs, or any [[wikilink]]-referenced topic. Also use when working in /srv/selfhost/ and a useful fact or in-flight task surfaces that isn't already captured. Triggers on phrases like "wiki", "add to wiki", "todo", "track this", "note this", "write this down", "where do we capture this", "look up <topic>", "what do we know about <topic>", "/wiki ...".
tools: Read, Glob, Grep, Bash, Edit, Write
---

# wiki

A skill for reading and maintaining the personal knowledge graph at
**`/srv/selfhost/wiki/`**. The graph is plain markdown — one node per file,
linked with `[[slug]]`, metadata in YAML frontmatter. Humans grep it; this
skill keeps it consistent.

`/srv/selfhost/wiki/README.md` is the authoritative spec. Read it first when
operating here.

## You are not alone

This wiki is **shared with other agents** (hermes, qwen running locally,
miguel, and possibly other claude sessions). Before editing a node:

1. Read the existing body in full. Don't skim.
2. Check `author:` and `updated:` in the frontmatter. If a different
   agent touched this node in the last hour, prefer appending to
   `## Discussion` over editing the body.
3. Set `author:` to the model you're running as (`claude` if you're
   Claude; the environment lists the exact model ID). Bump `updated:`.

When writing or expanding:

- **Additive.** Don't delete another agent's claims. If you disagree,
  add a `## Discussion` entry with your reasoning and a measurement.
- **Cite yourself.** Each Discussion entry: `**YYYY-MM-DD @<agent>:** ...`
- **Mark `status: contested`** if the body holds two views you can't
  reconcile.
- **Mark `status: draft`** if you wrote something without a fresh
  verification against current code/logs.

The full protocol is in `/srv/selfhost/wiki/README.md` under
*Multi-agent protocol*. Re-read it if you haven't this session.

## The graph is version-controlled

`/srv/selfhost/wiki` is **its own git repo** (local, no remote). It is separate
from `/srv/selfhost`, which is public and gitignores `wiki/`.

Commit after a coherent batch of edits — not per file:

```bash
git -C /srv/selfhost/wiki add <paths>   # explicit paths, never -A
git -C /srv/selfhost/wiki commit -m "<domain>: <what changed>"
```

History is what makes the shared-write protocol below recoverable. An edit that
loses another agent's paragraph is a `git diff` away from being spotted, and a
`git revert` away from being undone.

## A human may be editing at the same time

The same files are served by a web editor (SilverBullet, `/srv/selfhost/silverbullet`),
so Miguel can edit from a browser while you work. Two consequences:

- **Re-read a node immediately before writing it**, even if you read it earlier
  in the session. Your copy may be stale by minutes.
- **Never create a page called `CONTAINER_BOOT`.** The container's entrypoint
  executes `/space/CONTAINER_BOOT.md` as a bash script on every start.

The editor resolves `[[links]]` by **path**, not by bare slug — a node at
`llm/concepts/foo.md` is the page `llm/concepts/foo`. Whether a bare `[[foo]]`
still resolves in the browser is unconfirmed; it makes no difference to grep,
which is how you should keep reading the graph.

## When to use this skill

**Read mode** — answering "what do we know about X":
1. `grep -rln '\bX\b' /srv/selfhost/wiki/` for matches.
2. If a node exists, read it. Surface contradictions with current code/logs.
3. If no node exists but adjacent ones do, suggest creating one and offer a draft.

**Write mode** — recording new knowledge:
1. The fact must be **durable** (still useful in 6 months). Skip transient
   debugging state, in-flight tasks, conversation context.
2. Pick the right `type` and `domain` (see README).
3. If a draft node already exists, **update** it (don't fork). Bump `updated:`.
4. Cross-link generously with `[[slug]]`. Unresolved links are fine — they
   are markers for future work, not errors.

**Audit mode** — periodic hygiene:
- `find /srv/selfhost/wiki -name '*.md' -mtime +90` for stale.
- `grep -rohE '\[\[[a-z0-9-]+\]\]' /srv/selfhost/wiki/ | sort -u` then check
  which referenced slugs don't have a corresponding file.

## Decision rules

### "Is this wiki-worthy?"

Yes:
- A measurement with a date, a procedure, a flag's observed effect, a model's
  characteristics, an experiment with hypothesis → result.
- Cross-cutting concepts that show up in more than one place (KV cache, SWA,
  GTT eviction, spec-decoding…).
- An external reference (URL, PR, paper) you'll want to find again.

No:
- Stuff already captured in `~/.claude/lessons.md` rules-form — the wiki is
  for the **explanation behind** the rule, not the rule itself. Lessons.md
  rules can `[[link]]` into the wiki for depth.
- Active task state ("right now hermes is hung on X"). Use TaskCreate.
- Code that lives in a file — link to the file instead.
- Re-stating what `git log` or a README already says.

### "Where does this node live?"

Path = `wiki/<domain>/<type>/<slug>.md`.

- **Domain** mirrors the area: `llm/`, `infra/`, `blockchain/`, `tooling/`,
  `meta/`. Add a new domain freely if existing ones don't fit.
- **Type**: `concepts/` (timeless explanation), `flags/` (a CLI flag or env
  var), `models/` (a specific model identity), `experiments/` (dated probe),
  `references/` (pointer to an external resource).
- **Slug** = filename without `.md`. kebab-case. Stable forever once anything
  links to it. If you rename, leave an alias node.

### "Is there already a node for this?"

Before creating, search:
```bash
# By slug (exact)
ls /srv/selfhost/wiki/**/$SLUG.md 2>/dev/null

# By title or topic (fuzzy)
grep -rEi "^title:.*\b$TOPIC\b" /srv/selfhost/wiki/
grep -rln "\b$TOPIC\b" /srv/selfhost/wiki/

# By tag
grep -rE "^tags:.*\b$TAG\b" /srv/selfhost/wiki/
```

If a near-match exists, prefer updating it over creating a new file.

## Writing a node

Use this template. Required fields: `title`, `slug`, `type`, `domain`,
`created`, `updated`. `tags` and `related` optional but encouraged.

```markdown
---
title: <human-readable title>
slug: <kebab-case-slug>
type: concept | flag | model | experiment | reference
domain: llm | infra | blockchain | tooling | meta
tags: [tag1, tag2]
related: [[other-slug]], [[another-slug]]
created: YYYY-MM-DD
updated: YYYY-MM-DD
---

# <title>

<one-line summary — what this node IS, not what it does>

## <free sections>

Cross-link with [[slug]]. Cite measurements with a date and source (log line,
benchmark run, PR). Stale numbers are worse than no numbers.
```

For **`experiments/`**, slug pattern is `YYYY-MM-DD-<topic>`. Include:
- **Hypothesis** (what we expected before running it).
- **Setup** (config, flags, commit/build, dataset).
- **Measurement** (numbers + how they were captured).
- **Conclusion** (what changed in our mental model).
- When the conclusion stabilises across multiple experiments, promote a
  `concepts/` node and link the experiments to it.

## Update etiquette

- Bump `updated:` on any content change (not for typos / formatting).
- Adding a `[[link]]` from A → B: if B exists, consider editing B's
  `related:` to include A — but only when the link is bidirectional in
  meaning. (e.g. concept ↔ concept yes; concept → dated experiment, no need.)
- When a node grows past ~300 lines, split it. Pick the natural seam, leave
  cross-links.

## Pulling knowledge from existing sources

When you arrive at the wiki cold, you may need to seed nodes from already-
written material in the repo:

- `/srv/selfhost/llm/AGENTS.md`, `RUNBOOK.md`, `README.md` — operations.
- `/srv/selfhost/llm/triage/*.md` — dated incident reports map cleanly to
  `wiki/llm/experiments/` (rename by adding the date prefix if missing).
- `/srv/selfhost/llm/llama-swap.yaml` — inline comments hold per-model
  numbers and per-flag rationale; harvest them into `wiki/llm/models/` and
  `wiki/llm/flags/`.
- `~/.claude/lessons.md` — short rules; link from there into the wiki for
  the long explanation.

Don't bulk-import without the user asking. Seed on demand: when a topic
comes up, check the wiki; if missing, offer to create the node and draft it
from the source material.

## Anti-patterns

- **Mirror docs.** Don't duplicate AGENTS.md / RUNBOOK.md into the wiki.
  Link to them. The wiki is for **reusable knowledge** that doesn't fit in
  the operational docs.
- **Living TODO lists.** If a node turns into a list of in-flight tasks,
  it's the wrong place. Move tasks elsewhere.
- **Stale measurements without dates.** Every number gets a date and a
  source line, or it gets removed.
- **Renaming slugs.** Don't, once anything references them. Add an alias.

## Quick commands

```bash
# Find anything mentioning <term>
grep -rln "<term>" /srv/selfhost/wiki/

# Find unresolved [[wikilinks]]
comm -23 \
  <(grep -rohE '\[\[[a-z0-9-]+\]\]' /srv/selfhost/wiki/ | tr -d '[]' | sort -u) \
  <(find /srv/selfhost/wiki -name '*.md' -printf '%f\n' | sed 's/\.md$//' | sort -u)

# List all nodes by domain
find /srv/selfhost/wiki -mindepth 3 -name '*.md' | sort

# Recently updated
grep -rE '^updated:' /srv/selfhost/wiki/ | sort -t: -k3 -r | head
```
