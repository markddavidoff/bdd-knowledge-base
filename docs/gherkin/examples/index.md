---
title: Gherkin Examples Library
description: Curated, runnable Gherkin feature file examples covering foundational patterns, data-driven techniques, domain behaviors, and advanced vocabulary patterns.
sources:
  - git-gherkin-best-practices-repo-readme-readme
  - web-automation-panda-writing-good-gherkin-style-and-structure
  - web-cucumber-gherkin-reference-keywords
  - git-playwright-bdd-example-repo-agents-skills-playwright-bdd-skill-example-feature-file
---

# Gherkin Examples Library

This section contains a curated library of complete, runnable `.feature` file examples. Every page contains real Gherkin — no pseudocode, no placeholder steps, no prose-only explanations.

## Design Philosophy

**Pure Gherkin only.** This library shows `.feature` file syntax. It does not include TypeScript step definitions or playwright-bdd configuration — those belong in the [Implementation Examples](../../practice/examples/index.md) section. The separation is deliberate: a well-written feature file should be readable and verifiable by product owners and domain experts who do not write code.

**Runnable means complete.** Each example can be dropped into a project with matching step definitions and executed. Keywords, indentation, table alignment, and tag placement are all correct.

**AI retrieval and human learning.** These examples serve two audiences simultaneously: AI agents performing RAG retrieval over the KB (they need clean, parseable Gherkin without noise), and human TypeScript developers learning BDD patterns (they need context and commentary).

---

## Section 3.1 — Foundational

| Page | What it shows |
|------|--------------|
| [Hello World](hello-world.md) | The minimal complete feature file, then grown step-by-step: Background, second Scenario, tags |
| [Authentication](authentication.md) | Login (happy path), logout, session expiry, wrong credentials, MFA flow — declarative vocabulary |
| [CRUD Operations](crud-operations.md) | Create, Read, Update, Delete with Background setup and Scenario Outline for multiple values |

## Section 3.2 — Data-Driven Patterns

| Page | What it shows |
|------|--------------|
| [Data-Driven](data-driven.md) | Scenario Outline with single Examples table; multiple tagged Examples tables; DataTable for structured input |
| [Multiple Tagged Examples](multiple-tagged-examples.md) | A single Scenario Outline with `@smoke` and `@regression` tables; `# title-format:` extension |
| [Error Handling](error-handling.md) | Negative paths: permission denied, not found, validation errors — the `When X / Then I see error Y` pattern |

## Section 3.3 — Domain Behavior Patterns

| Page | What it shows |
|------|--------------|
| [API Testing](api-testing.md) | REST and GraphQL declarative scenarios that hide HTTP mechanics behind step vocabulary |
| [Declarative UI Workflows](declarative-ui-workflows.md) | E-commerce checkout, multi-step wizard — high-altitude steps hiding UI mechanics; imperative comparison |
| [Background and Rules](background-and-rules.md) | A Feature with two Rules, each with its own scoped Background |

## Section 3.4 — Advanced Vocabulary Patterns

| Page | What it shows |
|------|--------------|
| [Named Resources](named-resources.md) | The named test data catalog pattern: `{org-plan}`, `{user}` personas, base fixture + variation table |
| [Multi-Actor](multi-actor.md) | Two actors (admin and customer) in one scenario; multi-context pattern |
| [Environment-Specific](environment-specific.md) | `@staging` / `@production` / `@dev-only` tagging; smoke suite pattern |

---

## Conventions Used Throughout

```gherkin
# Tags use lowercase-hyphenated names
@happy-path @smoke

# Steps are in third-person, present tense
Given a customer has a pro subscription
When the customer requests a usage report
Then the report shows current billing cycle data

# Named resources replace magic values
Given the user Alice is logged in        # not: Given user ID 42 is authenticated
Given a pro organization                 # not: Given an org with billingEnabled=true
```

!!! tip "Cross-references"
    The step definitions that back these feature files are in [Implementation Examples (TypeScript)](../../practice/examples/index.md). [Custom Parameter Types](../reference/custom-parameter-types.md) explains how named resource tokens like `{org-plan}` and `{user}` resolve to domain objects.
