---
name: simplified-technical-english
description: Use when writing or editing technical docs where plainness and non-ambiguity matter, especially RFCs, technical design docs, tech memos, ADRs, runbooks, migrations, and rollout procedures for SaaS/PaaS, databases, and distributed systems.
---

# Simplified technical English for software docs

Make technical prose easy to understand and hard to misread. Optimize for accurate engineering communication, reviewability, and safe execution.

Do not alter literal code, SQL, API names, schema names, configuration keys, commands, logs, or quoted text. Apply these guidelines to the prose around them.

When an edit could change the technical meaning, flag the passage for the author instead of guessing.

## Start with the type of writing

Treat each passage as one of these types:

- **Procedural writing** tells the reader how to do a task. Examples include runbooks, migrations, backfills, failovers, recovery steps, and rollout or rollback procedures.
- **Descriptive writing** explains a system or decision. Examples include context, constraints, designs, invariants, data models, trade-offs, decisions, and consequences.

A document can contain both types. Keep them in separate paragraphs and do not mix instructions with descriptions in one list.

## Terminology

- Use plain words and established technical terms.
- Use one term for each component, state, operation, and data concept. Synonym rotation creates false distinctions.
- Use glossary terms only with their recorded meaning, spelling, capitalization, and part of speech.
- Define unfamiliar terms and abbreviations on first use. Write the expansion before the abbreviation.
- Prefer short technical names. Break prose noun stacks longer than three words into a phrase or clause.
- Preserve official service, API, schema, protocol, and product names. Define a shorter prose name when the official name is long.
- Avoid team-local slang, regional expressions, and vague jargon. Add necessary domain terms to the glossary.
- Use a technical noun as a verb only when that use is established or separately defined.
- Follow the company style guide for spelling. Preserve spelling in literals and quotations.

## Verbs and voice

- Prefer active voice and name the actor or owner: `The coordinator retries the request`, not `The request is retried`.
- Use passive voice when the actor is unknown, deliberately irrelevant, or less important than the result.
- Use a direct verb instead of a nominalization: `the worker validates the block`, not `block validation is performed by the worker`.
- Prefer simple verb forms. Use progressive or perfect forms when they express an important duration or ordering.
- Keep auxiliaries that express necessary modality, obligation, possibility, or time ordering.
- Avoid ambiguous `-ing` chains and idiomatic phrasal verbs. Established terms such as `roll back` and `fail over` are fine when their meaning is clear.

## Sentences

- Give one clear idea per descriptive sentence and one direct action per procedural sentence.
- Keep the subject, verb, articles, and other words required for complete meaning.
- Put conditions and qualifiers next to the claim or action they constrain.
- Make cause, contrast, sequence, and result explicit.
- Aim for no more than 20 words in an instruction and 25 words in a descriptive sentence. Keep a longer sentence when splitting it would detach a required condition or qualifier.
- Use familiar contractions when they are unambiguous.
- Prefer two sentences when a semicolon joins claims that can stand independently.
- Rewrite the full sentence when a word substitution harms grammar, precision, or meaning.

## Lists

- Use a vertical list when it makes complex or parallel information easier to scan.
- End the lead-in with a colon and make every item complete the lead-in.
- Use consistent grammar, capitalization, and punctuation across items.
- Use periods for full-sentence items.
- Do not mix actions and descriptive facts in one list.
- Count the lead-in and each list item separately when reviewing sentence length.

## Procedures

- Start each step with an imperative verb.
- Put one sequential action in each numbered step.
- Keep simultaneous actions together only when the reader must perform them together.
- Put preconditions, version gates, and state checks before the action.
- State the expected result or verification where it helps the operator detect failure.
- Put every required action, limit, acceptance condition, and data-safety condition in the procedure. Do not hide required work in notes.
- Use notes only for supporting information.

## Descriptive writing

- Present information in a useful order: context, constraints, design, and consequences.
- Introduce one subject at a time.
- Keep each paragraph on one topic. Start a new paragraph when the topic or logical role changes.
- Use stable key terms and explicit links between related claims.
- State decisions directly and distinguish measured facts, assumptions, estimates, and hypotheses.
- State the conditions behind decision-driving numbers.
- Define provisional decisions with a time or condition for reconsideration.

## Risks and operational warnings

- Use the organization's reliability, security, incident, and risk taxonomy.
- Start an operational-risk callout with the preventive action or required condition.
- State the concrete result, such as irreversible data loss, an outage, security exposure, or unexpected cost.
- Do not use vague warnings such as `be careful` without naming the failure mode.

## Review checklist

- Does each term identify one concept consistently?
- Are unfamiliar terms and abbreviations defined?
- Does each sentence contain one clear idea or action?
- Are actors and owners named where they matter?
- Are conditions next to the claims or actions they constrain?
- Are instructions separated from descriptions?
- Does each procedure step contain one action and an observable result where needed?
- Is required work present in the procedure rather than hidden in notes?
- Does each paragraph cover one topic?
- Did the edit preserve the technical meaning and all literal identifiers?

## Appendix: provenance and design choices

This guide is a practical adaptation of ASD-STE100 Issue 9, dated 2025-01-15. It is not a claim of ASD-STE100 compliance.

It was created for a small SaaS/PaaS engineering organization that writes design documents and operational procedures without a controlled-English dictionary, a translation program, or a dedicated technical-publication team. The goal is clearer engineering decisions and safer operations, not aerospace documentation certification.

The adaptation makes these deliberate choices:

- A company glossary and established industry terminology replace the formal controlled dictionary.
- Sentence lengths are review targets, not compliance limits.
- Necessary tense, modality, passive voice, contractions, and semicolons remain available when they improve precision.
- Software risk taxonomy replaces physical warning and caution categories.
- Formal word-count mechanics are omitted because they add review cost without improving this use case.

This appendix exists for maintainers who revise or reprocess the skill. It is not part of the writing workflow.
