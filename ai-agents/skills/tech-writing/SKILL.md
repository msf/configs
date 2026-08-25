---
name: tech-writing
description: >
  Write technical design docs in Miguel's voice and structure: RFCs/TDDs,
  Tech Memos (TMDs), and ADRs. Use whenever drafting, restructuring, or
  reviewing a design/architecture document, or when asked to "write this like
  me" / "make this sound less like an LLM" / "de-slop this doc".
---

# Technical writing: Miguel's structures and voice

## 1. Three forms. Pick the lightest that holds.

| Form | What it is |
|---|---|
| **RFC / TDD** | A proposal for a full system or something genuinely complex. The same form; RFC is the older name (all RFCs are 2022, TDDs start 2023). |
| **Tech Memo (TMD)** | Defined by what it isn't: not a strict ADR, and lighter than a full design doc. One problem, one scope, loose shape. |
| **ADR** | A Tech Memo that prescribes a specific approach, in fixed 3-section form, numbered and kept next to the code it describes. |

From *TMD: Tech Debt & Entering 2025*:

> Be pragmatic, a short ADR or TMD is better than no document and it is even better than a
> 10-page TDD.

Most engineers reach one form too high, write ten pages, and get no reviewers. Escalate only
when the lighter form visibly fails. Anything else in the corpus (problem-scope memo, handoff
memo, org memo, project proposal, live log) is a one-off shape. Write those ad hoc, don't
template them.

The medium is orthogonal to the form. Draft wherever the review actually happens, and expect a
document to move: an RFC that settles can get trimmed into a numbered ADR beside the code.
Same content, same voice, new vessel. Only the ADR has a location as part of its definition.

Titles: `RFC - NN - Title`, `TDD - Title`, `TMD: Title`, `ADR-NN-kebab-title`.

## 2. Skeletons

Sections are load-bearing. **Delete any section that would be empty.** A section that exists
because the template had it is the clearest LLM tell in a design doc.

`n=` below is how many corpus documents actually show the pattern. Treat low counts as
"available technique", not "required section".

### 2.1 RFC / TDD

```
# RFC - NN - <system name>
Date / Author(s) / Status: wip | review | completed / Reviewers
Related: <parent doc, supersedes / superseded by>

## Summary                  <- one paragraph explaining the proposal
## Goals                    <- numbered, each independently checkable   (n=6/10)
## Non-Goals                <- includes "we accept unknown-unknowns here" (n=5/10)
## <Design sections>        <- named after the thing, never "Overview"
## Options / Alternatives   <- Option A / Option B, each with its why-not
## Milestones / Next Steps
## Appendix
```

Open on a *specific* failure a reader can go look at, not on an abstraction: *"The primary
dashboard doesn't work on mobile and consumes 1.8 GB of RAM on desktop."*

Two optional review devices, both real but rare:
- **Reviewer table** (n=2, one TDD + one TMD): `Reviewer | Status | Notes`, plus
  `Mandatory Reviewers:` and `Must Review By Date:` in the header. Reviewers fill their own
  row; dissent stays in the doc in their words instead of being resolved away. The RAPID
  variant (Recommend / Agree / Perform / Input / Decide) names owners before the argument.
- **Paired advocacy** (n=2, RFC-04 / RFC-05): when two paths genuinely compete and two people
  can each take a side, write two one-sided docs, each declaring its slant (*"Its main focus
  is to steelman the organic evolution of the current codebase"*). Two honest one-sided docs
  beat one doc pretending to be neutral.

### 2.2 Tech Memo (TMD)

There is no fixed skeleton, and inventing one would misrepresent the form: across 14 memos, no
section appears in more than half. The looseness is the point. What recurs:

```
# TMD: <thing>            (or "Technical Memo on <question>")
Author(s) / Date / Status / Reviewers / Previous docs

## Context | Problem | Status Quo | Description of the problem   (n=6/14, pick one label)
   Open cold on the forcing function. No preamble, no restating the title.
## Goals                                                         (n=5/14)
## Non-Goals                                                     (n=2/14)
## Proposal | Options | Proposal A / Proposal B                  (n=6/14)
## Risks                                                         (n=3/14)
## Appendix                                                      (n=4/14)
```

When a memo carries several discrete sub-decisions, labelling them makes it scannable
(n=1; a good habit, not a rule):

> **Decision:** only in-process workers initially.
> **Rationale:** Simpler, less APIs to support, less "options", less code, no real need at this point.

Rationale is one or two sentences naming the property that decided it. It does not re-argue
the case.

### 2.3 ADR

```
# ADR-NN <title>
Date / Author / Status

## Context (or Problem Statement)
## Decision (or Proposed Solution)
## Consequences (or Trade-offs)
## <other sections as needed>
```

The corpus chooses this over heavier ADR templates: *"The goal is to have a very simple schema
to start with, and iterate on it as needed without needing to go read and ponder about specific
templates or projects that love to over-engineer things."*

Two live variants:
- **Documentation record**: same file, different job, how a system works *today* and why. Say
  so in the opening line and date it in the body, because this one rots.
  One example opens: *"This Arch Decision Record is instead an Arch DOCUMENTATION record."*
  Include a worked concrete example.
- **Reference record**: a schema or layout dump (`ADR-01-FDB-Schema.md`): prose foreword, then
  one section per entity, then tables. Very low prose density, which is correct here.

## 3. Voice

1. **`we` for the team and the system. `I` only for judgment**: "I propose", "I think we
   should", "I myself don't follow ADRs all the time". Never `I` for a system's behaviour.
2. **Asides go in parentheses or after a colon, never between dashes.** This is the single
   highest-signal difference from LLM prose. See §4.
3. **Contractions yes.** Precise, not stiff.
4. **Questions as headings.** 116 across the corpus: *What is the query router? · How does the
   worker pool work? · How do workers process jobs from queues? · Why this database and not X*.
   The title is the question the reader already has.
5. **ALLCAPS for the one word carrying the emphasis**, sparingly: *"a high level overview of HOW
   and WHY we fast tracked the query engine"*, *"this is NOT a goal"*. In requirement-style docs
   this becomes `MUST` / `SHOULD` throughout. Rate is 0-3 per document outside those, so it
   lands on the word that actually carries the point, not as a habit. Bold and ALLCAPS are
   interchangeable here: pick one per document and use it that sparingly.
6. **Label certainty.** proven / measured / *this is a heuristic* / *estimates assume 25 GbE* /
   *plausible but unproven*. Own the weak parts in a named section instead of hedging every
   adjective.
7. **Bound provisional decisions in time.** "initially", "for now", "worth revisiting once
   unification is done, not before". Name the condition that would reopen it.
8. **Real IDL over prose about IDL.** Paste the actual `.proto`, Go struct, or SQL DDL with
   inline comments. Never describe a schema in a paragraph.
9. **Cite tickets and paths** (`ISSUE-123`, `cmd/scheduler`, PR links) when they make a claim
   durable. Don't fabricate one to satisfy a template.
10. **Decision-driving numbers state their measurement condition.** `~64% of submissions execute
    inside <30s AND <2 GiB scanned` beats "most queries are fast". This applies to numbers that
    decide something; don't manufacture evidence for qualitative statements.
11. **End pointing forward**: Next Steps, Milestones, Open Questions, Status. Exactly one
    document in the corpus has a concluding-summary heading and it is meeting minutes. Design
    docs don't restate themselves.

Rates from the hand-written corpus (descriptive, not quotas): parentheses 13.3/1k words,
mid-sentence colon 9.1/1k, semicolon 1.6/1k, `we` 18.8/1k, `I` 4.4/1k, contractions 3.5/1k,
em-dash 0.

Bullets run 22-74% of lines with no clean split. Don't target a ratio: paragraphs for causal
argument, bullets and tables for parallel facts, requirements, and comparisons.

Vocabulary observed in the corpus, offered as recognition and not as a palette to reach for:
blast radius · failure mode · invariant · deliberately · out of scope · empirically ·
non-trivial · KISS · over-engineer · steelman · capricious (of a schema) · from first principles.

## 4. Slop: what to strip

**The em-dash is the top tell.** Miguel does not type `—`. Of 36 exported Google Docs, 33 have
zero; the exceptions are two known AI-assisted docs and one pasted reviewer comment by someone
else. Every hand-written repo ADR has zero. When de-slopping, convert every em-dash into a
parenthesis or a colon first: that alone does most of the work.

Then, in order of signal:
1. **Empty template sections**: a Non-Goals that says nothing, generic Risks, an Appendix with
   one link.
2. **A `Decision:` / `Rationale:` pair after every trivial choice.** Reserve for real forks.
3. **Uniform bullet rhythm**: every bullet the same length with a bolded lead-in.
4. **Verdict-first on every document.** A TL;DR is fine when there is one decision; most corpus
   docs open on the forcing function and build to the proposal.
5. **Section titles that say nothing**: Overview, Details, Summary, Conclusion.
6. **`I` used for anything but a judgment.**

Verified absent from the corpus, so safe to ban: `delve` · `game-changing` · `it's important to
note` · `in today's fast-paced` · `let's dive in` · "not just X, but Y" as a rhythm device ·
rule-of-three flourishes · hype adjectives on your own design · praise of the reader or the idea.

Verified *present*, so do not ban: `leverage` (15), `robust` (11), `unlock` (8), `journey` (3),
`seamless` (2). Ordinary technical words. Use them when they are the precise word.

## 5. Conventions borrowed from RFC 7322 (IETF RFC Style Guide)

Most of RFC 7322 is boilerplate, page layout, and IANA process. Six conventions transfer:

1. **Expand an abbreviation on first use, expansion first, abbreviation in parentheses.**
   "Query Routing Control Plane (QRCP)", then `QRCP` thereafter. Exception: terms the intended
   readership recognises instantly (S3, gRPC, SQL, k8s). Weigh obscurity against clutter. The
   corpus does this inconsistently, and design docs are often dense with project codenames, so
   this is the highest-value borrowed rule.
2. **The summary must stand alone, and the body must stand without the summary.** RFC 7322 bans
   citations in the Abstract for exactly this reason: it gets read in isolation. Some duplication
   between summary and opening section is correct, not sloppy.
3. **One name per thing: one term, one spelling, one capitalisation, across the document and its
   siblings.** Not `job runner` / `JobRunner` / `job-runner` for the same component, and no
   rotating synonyms for a service, table, state, or operation: a second name reads as a second
   concept.
   Cheap to fix, and a common LLM failure.
4. **Cross-reference by section name or anchor, never by position.** "see Section 3", not "see
   above" or "as mentioned earlier": text moves.
5. **Say `Updates:` / `Obsoletes:` in the header.** The corpus already does this ad hoc
   (`Deprecates: RFC-04`, `Deprecated by: RFC-05`). Make it a header field, so the supersession
   chain is machine-findable.
6. **If you use MUST / SHOULD as requirement levels, define them once and use them sparingly.**
   Three corpus docs use them heavily and none define them. RFC 2119's own caution applies:
   use them only where behaviour genuinely must be constrained, never to impose a preferred
   method.

Also worth stealing, and directed at whoever edits rather than whoever writes: RFC 7322's
**prime directive is that editing must not change the intended meaning.** When an unclear
passage can't be fixed without risking the technical meaning, flag it for the author instead of
rewriting it. That applies directly to an agent co-editing these docs: fix clarity, consistency,
and structure freely; surface anything that would alter a technical claim.

## 6. Sentence-level discipline (adapted from ASD-STE100)

The full adaptation is the `simplified-technical-english` skill; load it when a document needs a
line-by-line pass. What is worth carrying by default:

1. **Separate instructions from description, and treat them differently.** Every doc in the
   corpus drops numbered imperative steps into design prose (5 to 142 step-like lines per doc)
   with no change of register. Design prose explains and can carry qualifiers; a step is
   something a person executes at 3am. In procedural text: one action per step, imperative form,
   precondition before the command ("Once the flag is on, restart the workers"), and **no
   required action hidden in a note**. A reader must be able to finish the procedure without
   reading the notes.
2. **Name the actor, prefer active voice.** The corpus leans on `be used` (37), `is stored`,
   `is required`. Passive prose hides ownership, which is exactly what a design review needs to
   see. Keep passive only when the actor is genuinely unknown or irrelevant.
3. **Break noun stacks longer than three words.** "tenant sync failure alerting policy" becomes
   "the policy for alerts on failed tenant syncs". Exception: an official identifier, which you
   give in full once and then shorten (see §5.1).
4. **An action is a verb, not a noun.** "the worker validates the block" over "block validation
   is performed by the worker".
5. **Vertical lists: the lead-in ends in a colon, every item completes it, and instructions are
   never mixed with description in one list.**
6. **When a word swap breaks the sentence, rewrite the sentence.** Aimed at an agent editing
   these docs: mechanical synonym substitution is how meaning drifts.

**Deliberately rejected**, measured against the hand-written corpus: STE bans semicolons (corpus:
158, 1.9/1k) and contractions (695, 8.3/1k), restricts tense and auxiliary verbs that design docs
need for modality and ordering, and caps sentences at 20/25 words with paragraphs at six
sentences. Ignore those here. STE's controlled dictionary and its warning/caution taxonomy do not
apply to this domain at all.

## 7. Review checklist (for mentoring)

1. Is this the lightest of the three forms that holds?
2. Does it open on the forcing function, a specific checkable failure, rather than an abstraction?
3. Can the reader find the actual decision, stated flat in one sentence somewhere?
4. Does each consequential decision name the property that decided it?
5. Do decision-driving numbers state their measurement condition?
6. Is scope bounded: is it clear what this does *not* solve?
7. Is the rejected option represented by its strongest form?
8. Are the unknowns in a named section, or smuggled into hedged adjectives?
9. Does every section carry information, or is some of it template ceremony?
10. Does each section title say something specific?
11. Does it end pointing forward?
12. Is it dated, so a reader in 12 months knows when it was true?
13. Is every abbreviation expanded on first use, and every term named one way throughout?
14. Are instructions separated from description, one action per step, with nothing required
    buried in a note?
15. Is the actor named where ownership matters, rather than hidden in passive voice?
16. Zero em-dashes?

## Appendix: corpus and method

Derived from 28 hand-written design documents (2022-2026, 68k words) plus 11 in-repo ADRs.
The private source corpus is not required at runtime.

**AI-assisted documents were excluded from all voice measurement**, using em-dash presence as
the detector (verified: the split is clean, 0 vs 7-93 occurrences per doc). Those documents
remain useful as **structure** references. They are not voice samples.

The Docs corpus also contains meeting minutes, weekly notes, roadmaps and some co-authored
docs; those are excluded from the voice numbers but informed the taxonomy. When learning from
the raw exports, ignore export noise: `[a]`-style comment anchors, reviewer prose, and the
duplicated Docs/repo copies of the same document.

This file obeys its own rules: the single em-dash in it is the one naming the character itself (§4).
