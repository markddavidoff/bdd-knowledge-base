---
title: BDD Alternatives and Adjacent Approaches
description: BDD-style testing without .feature files — talewright, playwright-magic-steps, and the "BDD without Gherkin" school, with trade-off analysis.
sources:
  - git-playwright-bdd-repo-readme-other-playwright-tools
  - web-playwright-bdd-vs-cucumber-which-should-you-choose
  - git-playwright-bdd-repo-docs-index-index
---

# BDD Alternatives and Adjacent Approaches

Not every team that wants behavior-driven development wants Gherkin `.feature` files. Some prefer to keep all specification in code, others want lighter-weight prose. This page covers the main alternatives and when each trade-off makes sense.

## talewright: BDD Syntax Inside TypeScript

[talewright](https://github.com/nicholasgasior/talewright) provides a BDD-style Given/When/Then API directly in TypeScript test files — no `.feature` files, no code generation step. Scenarios are defined in `.spec.ts` files alongside regular Playwright tests.

```typescript
// checkout.spec.ts
import { tale } from 'talewright';

tale('User completes checkout', async ({ given, when, then }) => {
  await given('the cart contains "Mechanical Keyboard"', async ({ page }) => {
    await page.goto('/cart');
    await page.getByText('Mechanical Keyboard').waitFor();
  });

  await when('the user proceeds to checkout', async ({ page }) => {
    await page.getByRole('button', { name: 'Checkout' }).click();
  });

  await then('the order confirmation is shown', async ({ page }) => {
    await expect(page.getByRole('heading', { name: 'Order Confirmed' })).toBeVisible();
  });
});
```

**Gains over plain Playwright tests:**

- Enforces Given/When/Then structure as a discipline
- Test output uses the prose labels
- No context-switching between `.feature` files and `.ts` files

**Losses compared to playwright-bdd:**

- No step reuse: steps are closures local to each `tale()` call; there is no shared step library
- No stakeholder-readable specification: product owners cannot read or edit `.spec.ts` files
- No living documentation: without a separate feature file, there is nothing to publish as a living spec
- No Gherkin tooling: no linting, no IDE step autocomplete, no `bddgen` dry-run

**When talewright makes sense:**

- Small teams where developers own the full specification
- Projects where stakeholders do not participate in feature authoring
- Codebases already structured around Playwright tests that want some BDD discipline without the Gherkin ceremony

## playwright-magic-steps: Steps From Comments

[playwright-magic-steps](https://github.com/vitalets/playwright-magic-steps) auto-transforms JavaScript/TypeScript comments into Playwright steps:

```typescript
// checkout.spec.ts
import { test } from '@playwright/test';

test('User completes checkout', async ({ page }) => {
  // Given the cart contains "Mechanical Keyboard"
  await page.goto('/cart');
  await page.getByText('Mechanical Keyboard').waitFor();

  // When the user proceeds to checkout
  await page.getByRole('button', { name: 'Checkout' }).click();

  // Then the order confirmation is shown
  await expect(page.getByRole('heading', { name: 'Order Confirmed' })).toBeVisible();
});
```

Comments become the step labels shown in the Playwright HTML reporter and trace viewer. The test code itself is unmodified Playwright — the magic is purely in reporting.

**Gains:**

- Zero new syntax to learn; any Playwright test can adopt it
- Step labels appear in trace viewer and HTML report
- No build step or code generation

**Losses:**

- Comments are not executable specification: you cannot grep a feature file, enforce vocabulary, or link to a story
- No shared step library: the same behavior is re-implemented in each test
- Steps are invisible to stakeholders and non-developers
- No tag filtering, no Cucumber Expressions, no parameter types

**When magic-steps makes sense:**

- Annotating existing Playwright tests for better trace viewer output without a full BDD migration
- Teams that want readable test output but have no stakeholder requirement for shared vocabulary
- As a stepping stone before adopting playwright-bdd

## The "BDD Without Gherkin" School

Some experienced BDD practitioners argue that Gherkin is optional — what matters is the collaboration and the discipline of specifying behavior before implementation, not the `.feature` file format. This position is associated with names like Dan North (originator of BDD) and Liz Keogh.

The argument:

1. **Gherkin introduces ceremony**: Two files (`.feature` + step defs) instead of one; a code-generation step; IDE plugin dependencies
2. **Living documentation requires process discipline**: A `.feature` file only stays "live" if the team enforces it in CI. If that discipline breaks, the file becomes misleading
3. **Developer-readable code can be the spec**: Well-named test functions with structured Given/When/Then comments achieve the same goal without a DSL

The counter-argument:

1. **Shared authoring**: A `.feature` file can be written and reviewed by product owners, BAs, and QA without code literacy. A `.spec.ts` file cannot
2. **Cross-tool portability**: Gherkin is runner-agnostic; switching from playwright-bdd to Behave for a new service costs zero feature file rewrites
3. **Tooling investment**: IDE autocomplete, linting, and `bddgen env` step export exist because the format is standardized

## Decision Guide

| If you need... | Consider... |
|----------------|------------|
| Stakeholders authoring or reviewing specs | playwright-bdd (Gherkin required) |
| Living documentation published to a dashboard | playwright-bdd + Allure or Cucumber HTML reporter |
| Zero new ceremony on an existing Playwright suite | playwright-magic-steps |
| BDD structure without a feature file DSL | talewright |
| Maximum flexibility for a developer-only team | Structured plain Playwright with comment conventions |

!!! warning "The reuse gap"
    Both talewright and magic-steps lack shared step libraries. Once you have more than ~30 test scenarios, the inability to reuse step logic becomes a maintenance problem. If you anticipate growth, plaintiff playwright-bdd's step library investment pays off earlier than it appears.

## See Also

- [playwright-bdd vs @cucumber/cucumber](cucumber-js.md) — when to use the raw CucumberJS runner
- [playwright-bdd Architecture](../playwright-bdd/index.md) — how playwright-bdd's two-phase workflow works
