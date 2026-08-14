---
name: simplified-technical-english
description: Use when writing or editing technical docs where plainness and non-ambiguity matter, especially when adapting STE discipline to RFCs, technical design docs, tech memos, ADRs, runbooks, migrations, and rollout procedures for SaaS/PaaS, databases, and distributed systems.
---

# Simplified Technical English for software design docs

## Scope and status

Use this skill as an adaptation of ASD-STE100 Issue 9, dated 2025-01-15. Do not claim that the result complies with ASD-STE100.

Classifications mean:
- **TRANSFERS AS-IS:** Keep the source requirement in this domain.
- **TRANSFERS WITH MODIFICATION:** Keep its purpose, but apply the stated software-specific change.
- **DOES NOT TRANSFER:** Do not enforce it in this domain. The reason is stated.

Do not alter literal code, SQL, API names, schema names, configuration keys, commands, logs, or quoted text. Apply the rules to the prose around them.

## The controlled dictionary decision

Do not adopt the Part 2 dictionary literally. Its 875 approved words, approved meanings, parts of speech, forms, and 1,274 non-approved words target STE and aerospace-oriented technical writing. A software startup needs terms such as `shard`, `tenant`, `backfill`, `failover`, and product names.

Use a company glossary or terminology database instead. Rule 1.8 explicitly defers technical nouns to the company, industry, or subject field. Rule 1.11 requires one technical noun for one item. Record each important term, its exact meaning, preferred spelling, allowed abbreviations, and, where ambiguity matters, whether it is a noun or verb.

This substitution loses STE's approved core vocabulary. It cannot enforce one approved meaning, part of speech, or form for ordinary words. It also loses the dictionary's approved alternatives and some machine-checkable consistency and translation predictability.

## Procedural and descriptive writing

Classify each part before editing it:
- **Procedural writing** tells the reader how to do a task. Runbooks, migration steps, backfills, failovers, recovery steps, and rollout or rollback procedures are procedural. Apply Section 5.
- **Descriptive writing** gives information, not instructions. RFC context, system design, invariants, data models, trade-offs, ADR decisions, and consequences are descriptive. Apply Section 6.

A document can contain both types. Keep them in separate paragraphs and do not mix them in one vertical list.

## How to apply this to an RFC, design doc, or ADR

1. **Rule 1.11:** Use one term for each component, state, operation, and data concept. Synonym rotation creates false distinctions.
2. **Rule 3.6:** Name the actor or owner. This exposes missing ownership and unclear system boundaries.
3. **Rule 4.1:** Give one clear idea per sentence. Split coupled claims before reviewers debate them.
4. **Rule 5.2:** Put one action in each rollout, migration, or recovery step. This makes execution and verification safer.
5. **Rule 1.8:** Use glossary-approved domain terms. Define a new term before it carries a design decision.

Then separate procedural from descriptive passages, check terminology, split noun stacks, and review every local relaxation marked below.

## Section 1 – Words

- **Rule 1.1 | TRANSFERS WITH MODIFICATION.** The STE dictionary cannot be the startup's core vocabulary.
  Source:
  > Use words that are:
  > - Approved in the dictionary
  > - Technical nouns
  > - Technical verbs.
  Adaptation: Use plain ordinary words plus technical nouns and verbs from the company glossary. Do not imply STE lexical compliance.
- **Rule 1.2 | DOES NOT TRANSFER.** No company-wide approved list assigns one part of speech to each ordinary word.
- **Rule 1.3 | TRANSFERS WITH MODIFICATION.** Source: “Use approved words only with their approved meanings.” Adaptation: Use glossary terms only with their recorded meanings, and correct accidental overloading.
- **Rule 1.4 | DOES NOT TRANSFER.** The startup has no STE-style list of approved verb and adjective forms.
- **Rule 1.5 | TRANSFERS AS-IS.** Source: “You can use words that you can include in a technical noun category.” Adaptation: Software, database, networking, mathematical, document, and legal terms fit the source categories.
- **Rule 1.6 | DOES NOT TRANSFER.** Without the Part 2 approved-word baseline, its exception for non-approved words has no boundary.
- **Rule 1.7 | TRANSFERS AS-IS.** Source: “Do not use words that are technical nouns as verbs.” Adaptation: Use a glossary noun only as a noun unless the glossary separately approves it as a technical verb, as the rule body permits.
- **Rule 1.8 | TRANSFERS AS-IS.** Source: “Use technical nouns that are approved in your company, industry, or subject field.” Adaptation: Treat the company glossary and established public protocol terminology as authoritative.
- **Rule 1.9 | TRANSFERS AS-IS.** Source: “When you must select a technical noun, use one which is short and easy to understand.” Adaptation: Prefer no more than three words, as the rule body specifies, unless an official name already exists.
- **Rule 1.10 | TRANSFERS AS-IS.** Source: “Do not use regional, slang, or jargon words as technical nouns.” Adaptation: Replace team-local slang with a well-known term. Put necessary domain terms, not slang, in the glossary.
- **Rule 1.11 | TRANSFERS AS-IS.** Source: “Do not use different technical nouns for the same item.” Adaptation: Do not rotate names for a service, table, state, operation, or concept.
- **Rule 1.12 | TRANSFERS AS-IS.** Source: “You can use verbs that you can include in a technical verb category.” Adaptation: Software operations fit the source's computer-process category. Use the precise contextual verb, not a vague technical verb.
- **Rule 1.13 | TRANSFERS AS-IS.** Source: “Do not use technical verbs as nouns.” Adaptation: Use a glossary verb only as a verb unless the glossary separately approves the same word as a technical noun, as the rule body permits.
- **Rule 1.14 | TRANSFERS AS-IS.** Source: “Use American English spelling unless other official directives tell you differently.” Adaptation: Follow the company style guide when it specifies a different spelling, and preserve quoted or literal spelling.

## Section 2 – Multi-word nouns

- **Rule 2.1 | TRANSFERS AS-IS.** Source: “Write multi-word nouns of no more than three words.” Adaptation: Unpack longer prose noun stacks with prepositions or clauses. Rule 2.2 covers official technical names.
- **Rule 2.2 | TRANSFERS AS-IS.** Official software terms need the source's full-name and short-name method.
  Source:
  > When a technical noun has more than three words, write it in full.
  > Then, you can use one of these methods to make the technical noun clear:
  > - Give a shorter form of the technical noun.
  > - Use hyphens (-) between words that you use as one unit.
  Adaptation: First give the exact service, API, schema, or protocol name. Then define a short prose name or approved abbreviation. Never add hyphens inside a literal identifier.

## Section 3 - Verbs

- **Rule 3.1 | DOES NOT TRANSFER.** The company glossary does not provide an STE-style approved-form list for ordinary verbs.
- **Rule 3.2 | TRANSFERS WITH MODIFICATION.** The source's absolute tense restriction conflicts with precise timelines in design analysis.
  Source:
  > Use only these verb forms and tenses of verbs:
  > - The infinitive form
  > - The imperative form (command form)
  > - The simple present tense
  > - The simple past tense
  > - The simple future tense
  > - The past participle form (as an adjective).
  Adaptation: Prefer these simple forms. Use a progressive or perfect tense only when it expresses an important duration or ordering that a simple tense would lose.
- **Rule 3.3 | TRANSFERS AS-IS.** Source: “Use the past participle form as an adjective.” Adaptation: Use it to state a condition, such as “the replicated table,” not to hide an action or actor.
- **Rule 3.4 | TRANSFERS WITH MODIFICATION.** Source: “Do not use auxiliary verbs to make complex verb constructions.” Adaptation: Prefer a simple construction, but retain auxiliaries that express necessary modality or time ordering.
- **Rule 3.5 | TRANSFERS WITH MODIFICATION.** Source: “Use the “-ing” form of a verb only as a technical noun or as a modifier in a technical noun.” Adaptation: Avoid ambiguous `-ing` chains, but permit a gerund or progressive form when Rule 3.2's local exception applies.
- **Rule 3.6 | TRANSFERS WITH MODIFICATION.** Source: “Use the active voice. In descriptive writing, you can use the passive voice only if the agent is unknown.” Adaptation: Prefer active voice and name the actor. The narrow source exception conflicts with normal design-doc practice, so also permit passive voice when the actor is deliberately irrelevant and the object or outcome is the topic.
- **Rule 3.7 | TRANSFERS WITH MODIFICATION.** Source: “Use an approved verb to describe an action, not a noun or other parts of speech.” Adaptation: Use a direct action verb instead of a nominalization. Select it from ordinary English or the glossary, not Part 2.

## Section 4 – Sentences

- **Rule 4.1 | TRANSFERS AS-IS.** Source: “Write short and clear sentences.” Adaptation: Give one accurate idea per descriptive sentence and one direct action per procedural sentence.
- **Rule 4.2 | TRANSFERS WITH MODIFICATION.** Source: “Do not omit words or use contractions to make your sentences shorter.” Adaptation: Keep subjects, verbs, articles, and other necessary words. The startup deliberately permits familiar, unambiguous contractions such as “don't” and “isn't”. This conflicts with STE.
- **Rule 4.3 | TRANSFERS AS-IS.** Source: “Use a vertical list for complex text.” Adaptation: End the lead-in with a colon, mark items consistently, and start them uppercase. Use periods for full sentences and the final item, not commas or semicolons. Make each item connect to the lead-in, and do not mix procedural and descriptive items.
- **Rule 4.4 | TRANSFERS AS-IS.** Source: “Use connecting words and connecting phrases to connect sentences that contain related topics.” Adaptation: Make cause, contrast, sequence, and result explicit between design claims.
- **Rule 4.5 | TRANSFERS AS-IS.** Source: “When applicable, use an article (the, a, an) or a demonstrative adjective (this, these) before a noun or a multi-word noun.” Adaptation: Do not drop these words in prose merely to sound terse.

## Section 5 - Procedural writing

Procedures tell readers how to do a task. Use these rules for runbooks, migrations, backfills, failovers, recovery, and rollout or rollback steps.

- **Rule 5.1 | TRANSFERS WITH MODIFICATION.** Source: “Write short sentences. Use a maximum of 20 words in each sentence.” Adaptation: The hard source ceiling conflicts with some precise procedures, so treat 20 words as a strong review target. Keep a longer sentence if splitting would separate a required condition, scope, or exact literal. Notes use STE's 25-word descriptive limit.
- **Rule 5.2 | TRANSFERS AS-IS.** Source: “Write only one instruction in each sentence unless two or more actions occur at the same time.” Adaptation: Give each sequential action its own numbered step. Keep simultaneous actions or an immediate result with the action.
- **Rule 5.3 | TRANSFERS AS-IS.** Source: “Write instructions in the imperative (command) form.” Adaptation: Start each procedure step with the action. Do not add “must” to an imperative unless it expresses a critical condition.
- **Rule 5.4 | TRANSFERS AS-IS.** Source: “When there is a condition that the reader must know about first, start the instruction with a descriptive statement. Then, divide that descriptive statement from the command with a comma.” Adaptation: Put preconditions, version gates, and state checks before the action.
- **Rule 5.5 | TRANSFERS AS-IS.** Source: “Write notes only to give information, not instructions.” Adaptation: Put every required action, limit, acceptance result, and data-safety condition in the procedure. A reader must be able to complete it without notes.

## Section 6 - Descriptive writing

Descriptive writing gives information, not instructions. Use these rules for context, design, invariants, data models, alternatives, trade-offs, decisions, and consequences.

- **Rule 6.1 | TRANSFERS AS-IS.** Source: “Give information gradually.” Adaptation: Move from context to constraints to design to consequences, and introduce one subject at a time.
- **Rule 6.2 | TRANSFERS AS-IS.** Source: “Use key words and key phrases to give your text a logical structure.” Adaptation: Repeat stable design terms and use explicit links for contrast, cause, sequence, and result.
- **Rule 6.3 | TRANSFERS WITH MODIFICATION.** Source: “Write short sentences. Use a maximum of 25 words in each sentence.” Adaptation: The hard source ceiling conflicts with some precise design prose, so treat 25 words as a strong review target. Keep a longer sentence when a split would detach a qualifier from its claim.
- **Rule 6.4 | TRANSFERS AS-IS.** Source: “Use paragraphs to show related information.” Adaptation: Start with a topic sentence, keep related detail together, and start a new paragraph when the topic or logical role changes.
- **Rule 6.5 | TRANSFERS AS-IS.** Source: “Make sure that each paragraph has only one topic.” Adaptation: Give each paragraph a topic sentence that would work in an outline.
- **Rule 6.6 | TRANSFERS WITH MODIFICATION.** Source: “Make sure that no paragraph has more than six sentences.” Adaptation: Use six sentences as a review threshold, not a hard cap. Split when a second topic or a clearer boundary exists. This relaxes STE's mandatory cap.

## Section 7 - Safety instructions

The source defines a warning as risk of injury or death and a caution as risk of damage to objects. SaaS design docs have no clean equivalent risk scale. Do not relabel reliability, security, cost, or data-integrity risks as STE safety instructions.

- **Rule 7.1 | DOES NOT TRANSFER.** Its warning/caution levels classify physical harm and object damage, not software severity. Use the company's incident, security, and risk taxonomy instead.
- **Rule 7.2 | TRANSFERS WITH MODIFICATION.** Source: “Start a safety instruction with a clear and accurate command or condition.” Adaptation: For an operational-risk callout, start with the preventive command or precondition. Do not call the result an STE safety instruction.
- **Rule 7.3 | TRANSFERS WITH MODIFICATION.** Source: “Give an explanation to show the risk or possible result.” Adaptation: State the concrete software result, such as irreversible data loss, outage, security exposure, or unexpected cost.

## Section 8 - Punctuation and word count

- **Rule 8.1 | TRANSFERS WITH MODIFICATION.** Source: “You can use all standard English punctuation marks but not the semicolon (;).” Adaptation: Prefer two sentences when a semicolon joins independent technical claims. The startup permits a deliberate semicolon in otherwise clear prose. This conflicts with STE's prohibition.
- **Rule 8.2 | TRANSFERS AS-IS.** Source: “Use hyphens (-) to connect words that are directly related.” Adaptation: Use them in prose compound modifiers and approved technical terms. Do not change literal identifiers.
- **Rule 8.3 | TRANSFERS AS-IS.** The listed uses map directly to software documents.
  Source:
  > You can use parentheses:
  > - To make references to illustrations or text
  > - To include letters or numbers that identify items on an illustration or in a text
  > - To identify the work steps in a procedure
  > - To include abbreviations
  > - To give the singular and plural forms of a noun at the same time
  > - To explain words or a part of a sentence
  > - To include an alternative.
  Adaptation: Use these functions for diagram or section references, list identifiers, abbreviations, short explanations, and alternatives.
- **Rule 8.4 | TRANSFERS WITH MODIFICATION.** Source: “In a vertical list, a colon (:) has the same effect on word count as a period and shows the end of a sentence.” Adaptation: When checking the targets in Rules 5.1 and 6.3, count the lead-in and each list item separately.
- **Rule 8.5 | DOES NOT TRANSFER.** Counting parenthetical text as one word, while also counting it as a separate sentence, only serves formal STE ceiling checks.
- **Rule 8.6 | DOES NOT TRANSFER.** Counting each number, measurement, abbreviation, identifier, quotation, title, label, or proper noun as one word adds little value with soft targets.
- **Rule 8.7 | DOES NOT TRANSFER.** Formal treatment of every hyphenated group as one word is unnecessary without STE compliance counting. Rule 8.2 still governs hyphens.

## Section 9 - Writing practices

- **Rule 9.1 | TRANSFERS WITH MODIFICATION.** Source: “Use a different sentence construction to write a sentence when a word-for-word replacement is not sufficient.” Adaptation: Rewrite the full sentence when a terminology change would harm grammar, meaning, or precision. Do not mechanically swap synonyms.
- **Rule 9.2 | TRANSFERS WITH MODIFICATION.** Source: “Use each approved word correctly.” Adaptation: Apply this requirement to company-glossary terms. Ordinary words have no Part 2 approval status.
- **Rule 9.3 | TRANSFERS WITH MODIFICATION.** Source: “When you use two words together, do not make phrasal verbs.” Adaptation: Avoid idiomatic phrasal verbs whose combined meaning is unclear. Permit established software terms such as “roll back” or “fail over” when the glossary defines them. STE permits only its small approved set.
- **Rule 9.4 | TRANSFERS AS-IS.** Source: “When you select terminology or wording, always use a consistent style.” Adaptation: Use the same wording for the same operation, condition, decision status, and document structure.

## Source coverage

Verified against the local Issue 9 text:
- The full General introduction relevant to purpose, scope, and dictionary use
- Every rule summary and rule body in Part 1, Sections 1 through 9
- Section 9's GR-1 through GR-8, which the source explicitly calls recommendations, not STE rules
- The Part 2 introduction, including its counts, dictionary structure, word-selection guidance, recurring errors, and approved-verb list

Not read in full:
- Cover, administrative pages, change record, table of contents, and indexes. They are publication metadata or navigation, not Part 1 rules.
- The alphabetical Part 2 entries after its introduction, apart from spot checks. They are safe to omit here because this adaptation explicitly does not adopt the controlled word list.
- Illustrative examples were read with the rule bodies but are not reproduced as requirements. Examples show application and are not additional rules.
