---
title: Start Here — BDD, Gherkin, and playwright-bdd
description: A newcomer's guide explaining what BDD is, what Gherkin is, what playwright-bdd is, and how they relate — with a recommended reading order.
sources:
  - web-cucumber-bdd-overview-what-is-bdd
  - web-cucumber-bdd-overview-three-practices
  - web-bdd-living-documentation-what-is-behavior-driven-development
  - web-automation-panda-gherkin-language-introducing-gherkin
  - web-monday-bdd-guide-bdd-vs-tdd-choosing-the-right-approach
  - web-playwright-bdd-vs-cucumber-cucumber-js-vs-playwright-bdd-comparison
---

# Start Here

If you are new to BDD or Gherkin, read this page before anything else. It defines three concepts that the rest of this knowledge base assumes you know, and explains how they fit together.

---

## What is BDD?

**Behavior-Driven Development (BDD)** is a collaborative practice — not primarily a testing technique. It closes the gap between business stakeholders and technical implementers by grounding every feature discussion in **concrete, real-world examples** of how the system should behave.

The core idea: before writing code, the team agrees on *examples* of behavior in a shared format that both humans and automated tools can read. Those examples become:

1. The **acceptance criteria** for the feature.
2. The **automated tests** that verify the feature was built correctly.
3. **Living documentation** that stays accurate because it is checked on every CI run.

BDD is an extension of TDD but operates at a different altitude. TDD focuses on code design at the unit level. BDD focuses on behavior at the feature level, using language everyone on the team shares.

| Aspect | BDD | TDD |
|--------|-----|-----|
| Focus | User behavior | Code design |
| Language | Business English | Programming language |
| Audience | Everyone (product, dev, QA) | Developers |
| Scope | Feature / acceptance level | Unit level |

!!! note "BDD is a process, not a tool"
    You can do BDD without Gherkin, and you can write Gherkin without doing BDD. The value comes from the **collaboration and shared understanding**, not from the syntax. This knowledge base covers both — the practice and the tooling.

---

## BDD in 3 Steps

The daily BDD cycle has three phases (Cucumber's canonical names):

**1. Discovery** — Talk before you type.
Bring together the business expert, a developer, and a tester (the [Three Amigos](../practice/methodology/three-amigos.md)). Use [Example Mapping](../practice/methodology/example-mapping.md) to uncover the real rules and edge cases of a feature *before* anyone opens an editor.

**2. Formulation** — Write it down in Gherkin.
Turn the agreed examples into `.feature` files using `Given / When / Then` syntax. This is the step where Gherkin enters the picture. The document serves as both the spec and the automated test driver.

**3. Automation** — Connect Gherkin to code.
Wire each step to a step definition function. The feature file drives the test run. When tests pass, the documentation is verified.

```gherkin
# formulation output — a .feature file
Feature: Subscription upgrade
  Scenario: Upgrading from free to pro
    Given Alice has a free plan account
    When she upgrades to the pro plan
    Then her billing cycle starts today
    And she can access pro-only features
```

---

## What is Gherkin?

**Gherkin** is the domain-specific language for writing BDD scenarios. It is plain text stored in `.feature` files. It has a small, fixed vocabulary of keywords: `Feature`, `Scenario`, `Given`, `When`, `Then`, `And`, `But`, `Background`, `Rule`, `Scenario Outline`, `Examples`, `@tags`.

Gherkin is deliberately not a programming language. The goal is that a product manager, a business analyst, or a domain expert can read and critique a scenario without needing to understand code.

Key properties:
- **Human-readable first.** If a non-technical stakeholder cannot understand a scenario, the scenario is wrong.
- **Executable.** Each step is matched to a step definition function that Playwright runs.
- **Declarative, not imperative.** Scenarios describe *what* the system should do, not *how* to click buttons. See [Declarative vs. Imperative](best-practices/declarative-vs-imperative.md).

!!! tip "Gherkin is the specification, not the test"
    The `.feature` file is the authoritative description of behavior. The step definitions are plumbing — they should be invisible to anyone reading the spec.

---

## What is playwright-bdd?

**playwright-bdd** is the TypeScript library that connects Gherkin `.feature` files to the Playwright test runner. It works in two phases:

1. `bddgen` — a CLI tool that reads your `.feature` files and generates `.spec.ts` test files from them.
2. `playwright test` — runs those generated spec files exactly like any other Playwright test.

Step definitions are written with `createBdd()` — a function that gives you type-safe access to Playwright fixtures inside your step implementations:

```typescript
// steps/auth.steps.ts
import { createBdd } from 'playwright-bdd';
import { test } from './fixtures'; // your custom fixture extensions

const { Given, When, Then } = createBdd(test);

Given('Alice has a free plan account', async ({ page, db }) => {
  await db.users.create({ email: 'alice@example.com', plan: 'free' });
});

When('she upgrades to the pro plan', async ({ page }) => {
  await page.getByRole('button', { name: 'Upgrade to Pro' }).click();
  await page.getByRole('button', { name: 'Confirm' }).click();
});

Then('her billing cycle starts today', async ({ page }) => {
  await expect(page.getByTestId('billing-start')).toContainText(
    new Date().toLocaleDateString()
  );
});
```

playwright-bdd sits on top of Playwright Test. You get the full Playwright ecosystem — trace viewer, parallelism, sharding, fixtures, `storageState` auth — and Gherkin on top.

---

## How the Three Fit Together

```
Business conversation
        ↓
   Example Mapping
        ↓
  .feature file (Gherkin)       ← shared spec, version-controlled
        ↓
  bddgen (playwright-bdd CLI)
        ↓
  generated .spec.ts             ← do not edit these
        ↓
  playwright test                ← runs in CI, produces HTML report
        ↓
  Living documentation
```

The `.feature` file is the **single source of truth**. It is written before code, reviewed like code, and checked in CI like tests. When it passes, it proves the system does what the spec says.

---

## Recommended Reading Order

Follow this sequence if you are new to the stack:

1. **This page** — you are here. Get the mental model first.
2. [BDD vs. Plain Playwright](bdd-vs-playwright.md) — decide if BDD is right for your situation before going deeper.
3. [Gherkin Reference: Keywords](reference/keywords.md) — the syntax reference. Focus on `Feature`, `Scenario`, `Given/When/Then`, `Background`, `Scenario Outline`.
4. [Declarative vs. Imperative](best-practices/declarative-vs-imperative.md) — the most important quality principle. Read this before writing your first real scenario.
5. [Step Definitions](best-practices/step-definitions.md) — how to write the TypeScript wiring.
6. [Test Data Strategy](best-practices/test-data-strategy.md) — how to manage state across scenarios.
7. [Examples: Hello World](examples/hello-world.md) — a complete, runnable starter.

!!! warning "Avoid the most common mistake"
    Many teams skip the collaboration practices (Discovery, Three Amigos, Example Mapping) and write Gherkin alone, after the fact. This produces "Cucumber theater" — feature files that look like BDD but deliver none of its value. See [Anti-Patterns](best-practices/anti-patterns.md) for the full failure mode taxonomy.
