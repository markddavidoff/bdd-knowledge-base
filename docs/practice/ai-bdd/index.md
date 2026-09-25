---
title: AI-Assisted BDD
description: Overview of AI-assisted BDD — the three use cases, current state of the art, and why Three Amigos remains required even when AI drafts scenarios.
sources:
  - git-playwright-bdd-repo-docs-index-bdd-in-the-era-of-ai
  - git-playwright-bdd-repo-readme-bdd-in-the-era-of-ai
  - git-playwright-bdd-repo-docs-getting-started-agent-skill-agent-skill
  - git-playwright-bdd-repo-docs-getting-started-agent-skill-usage
  - web-monday-bdd-guide-the-future-of-bdd-ai-and-automation-trends
---

# AI-Assisted BDD

BDD feature files occupy a unique position in a software project: they are simultaneously **human-readable specifications** and **executable tests**. That dual nature makes them especially valuable as AI context — an LLM can read a `.feature` file as a requirements document, use it to understand expected behavior, and then generate or verify code against it.

As of 2026, AI assists with BDD in three distinct use cases, each with different maturity levels.

## The Three Use Cases

### 1. Scenario Authoring

An LLM drafts Given-When-Then scenarios from a user story or feature description. You supply the story text and a list of available step definitions; the LLM produces a `.feature` file that uses only existing steps.

**Maturity:** Production-ready as a drafting tool. The output requires human review against Three Amigos criteria before acceptance. See [Scenario Authoring](scenario-authoring.md).

### 2. Step Scaffolding

Given a feature file with new steps that have no TypeScript implementation, an LLM generates `createBdd()` step definition stubs. You supply the feature file and the existing step export; the LLM produces typed TypeScript that matches playwright-bdd's style.

**Maturity:** Useful for boilerplate reduction. The LLM cannot know your fixture graph, so fixture types always require human adjustment. See [Step Scaffolding](step-scaffolding.md).

### 3. Drift Detection

Over time, the code drifts away from what the feature file specifies. `bddgen --dry-run` catches undefined steps (structural drift), but semantic drift — steps that still match but no longer describe current behavior — requires a different approach. An LLM can review feature file + implementation and flag mismatches.

**Maturity:** Experimental. Useful as a quarterly review prompt, not a continuous gate. See [Drift Detection](drift-detection.md).

## What AI Does Well

- **Generating well-formed Gherkin** — Given/When/Then structure, Background, proper keyword use.
- **Reusing existing steps** — when given the step export, LLMs are good at sticking to available vocabulary.
- **Producing first drafts quickly** — turning a paragraph user story into 3-5 scenarios in seconds.
- **Explaining existing scenarios** — asking an LLM "what does this scenario test?" is a good way to check whether a scenario is clear enough.

## What AI Does Poorly

- **Inventing vocabulary** — without explicit step constraints, LLMs write steps that sound natural but do not match any step definition.
- **Business rule completeness** — LLMs tend to write happy-path scenarios and miss error paths, edge cases, and the "what if the user is not logged in?" category.
- **Domain grounding** — without your ubiquitous language glossary, LLMs use generic terms that do not match your domain.
- **Authorization and security scenarios** — these require understanding your permission model, which the LLM does not have unless explicitly supplied.

!!! warning "Three Amigos is still required"
    AI generates drafts. A product owner, developer, and tester must still review every scenario against business intent before it is accepted as a specification. The Three Amigos session does not go away — it moves to reviewing LLM output instead of writing from scratch. This is faster, but the conversation cannot be skipped.

## The playwright-bdd AI Workflow

playwright-bdd has first-class AI support through two mechanisms:

1. **`bddgen export`** — prints all available step definitions in a format suitable for LLM prompts. Paste the export into a prompt to constrain the LLM to your existing vocabulary.

2. **Agent Skill** — a structured skill that guides AI coding agents (Claude Code, Cursor, etc.) through the full BDD workflow: draft scenarios → human approval → implement step defs → verify.

3. **Fix with AI** — when a test fails, playwright-bdd generates a pre-filled prompt containing the error, scenario steps, and an ARIA snapshot of the page. Paste it into any LLM to get fix suggestions.

## This KB as AI Context

This knowledge base is designed to be used as LLM context. The normalized chunks under `dataset/normalized/` follow a consistent frontmatter schema (chunk_id, title, source_type, content_hash) and are sized for retrieval (one H2 section per file, ~500-1000 words). When asking an LLM about BDD, inject the relevant chunks to ground its answers in documented best practices rather than training data.

See [KB as Context](kb-as-context.md) for chunk selection heuristics and a sample system prompt template.

## Pages in This Section

| Page | What you will find |
|------|--------------------|
| [Corpus Design](corpus-design.md) | How this KB is structured for machine readability |
| [Exporting Steps](exporting-steps.md) | `bddgen export` — format, usage, CI sync |
| [Scenario Authoring](scenario-authoring.md) | Prompting strategies for LLM-drafted scenarios |
| [KB as Context](kb-as-context.md) | Using this KB as RAG context for LLM tasks |
| [Step Scaffolding](step-scaffolding.md) | Generating TypeScript step defs from feature files |
| [Drift Detection](drift-detection.md) | Detecting and reviewing spec-implementation divergence |
