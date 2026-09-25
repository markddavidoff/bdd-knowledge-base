---
title: playwright-bdd Overview
description: playwright-bdd integrates Gherkin BDD scenarios with the Playwright test runner via a two-phase generate-then-run workflow.
sources:
  - git-playwright-bdd-repo-docs-index-index
  - git-playwright-bdd-repo-docs-index-how-playwright-bdd-works
  - git-playwright-bdd-repo-docs-index-why-playwright-runner
  - git-playwright-bdd-repo-docs-blog-whats-new-in-v8-whats-new-in-v8
  - git-playwright-bdd-repo-docs-faq-faq
---

# playwright-bdd Overview

playwright-bdd is a library that runs BDD tests written in Gherkin with the **Playwright test runner**. It is not a standalone runner — it acts as a bridge that converts `.feature` files into native Playwright test files, so you retain full access to all Playwright tooling.

Current stable version: **v8.x** (released December 2024). Since v7, playwright-bdd no longer depends on CucumberJS at runtime; it ships its own Gherkin parser and expression engine.

---

## Two-Phase Workflow

Every playwright-bdd test run has two distinct phases:

```bash
npx bddgen && npx playwright test
```

### Phase 1 — `bddgen`

`bddgen` reads your `.feature` files and generates `.spec.ts` files in the `.features-gen/` directory. For example, this feature:

```gherkin
Feature: Playwright Home Page

  Scenario: Check title
    Given I am on Playwright home page
    When I click link "Get started"
    Then I see in title "Installation"
```

Becomes:

```ts
// .features-gen/features/home.feature.spec.ts  (do not edit)
import { test } from 'playwright-bdd';

test.describe('Playwright Home Page', () => {
  test('Check title', async ({ Given, When, Then }) => {
    await Given('I am on Playwright home page');
    await When('I click link "Get started"');
    await Then('I see in title "Installation"');
  });
});
```

### Phase 2 — `playwright test`

The second command runs the generated files with the Playwright runner. Step definitions receive Playwright fixtures (`page`, `browser`, `context`, custom fixtures) as their first argument:

```ts
import { createBdd } from 'playwright-bdd';

const { Given, When, Then } = createBdd();

Given('I am on Playwright home page', async ({ page }) => {
  await page.goto('https://playwright.dev');
});

When('I click link {string}', async ({ page }, name) => {
  await page.getByRole('link', { name }).click();
});

Then('I see in title {string}', async ({ page }, keyword) => {
  await expect(page).toHaveTitle(new RegExp(keyword));
});
```

!!! note "Generated files are read-only"
    Never edit `.spec.ts` files in `.features-gen/`. They are regenerated on every `bddgen` run. Your source of truth is the `.feature` file and the step definitions.

---

## Why playwright-bdd Over `@cucumber/cucumber`?

Playwright can technically be used as a browser library with the CucumberJS runner, but the experience is degraded: you lose auto-waiting, VS Code test integration, UI mode, trace viewer, and Playwright's fixture system.

playwright-bdd converts BDD scenarios into **native Playwright tests**, which means you get all Playwright runner features automatically:

- Automatic browser setup and cleanup per test
- Auto-waiting for page elements (no explicit waits needed)
- Auto-capture of screenshots, videos, and traces on failure
- Parallel execution and sharding with zero config
- Built-in HTML reporter with step-level results
- Playwright fixtures for dependency injection
- VS Code Playwright extension: run/debug individual scenarios with a click

!!! tip "CucumberJS-independent since v7 (2024)"
    You do not need `@cucumber/cucumber` in your dependencies. playwright-bdd v7+ ships its own Gherkin parser. The only peer dependency is `@playwright/test`.

---

## Key Concepts

| Concept | Description |
|---------|-------------|
| `.feature` files | Gherkin source — the human-readable specification you author |
| Step definitions | TypeScript functions that implement each step |
| `createBdd()` | Returns `Given/When/Then` bound to your fixture set |
| `defineBddConfig()` | Configures playwright-bdd inside `playwright.config.ts` |
| `.features-gen/` | Output directory for generated `.spec.ts` files |
| `bddgen` | CLI that runs generation phase |

---

## In This Section

- [Installation](installation.md) — package setup, minimal working example
- [Configuration](configuration.md) — `defineBddConfig()` options reference
- [TypeScript Configuration](typescript-config.md) — ESM, `tsconfig.json`, and type safety
- [Writing Steps](writing-steps.md) — Playwright style, Cucumber style, and Decorator style
- [Fixtures](fixtures.md) — built-in fixtures and custom fixture patterns

---

## When Not to Use playwright-bdd

- **Pure API / backend services** with no browser: use `@cucumber/cucumber` with `supertest` or `node-fetch` — the Playwright runner adds overhead that isn't justified without a browser. See [vs. @cucumber/cucumber Runner](vs-cucumber-runner.md).
- **Component testing** in isolation (though playwright-bdd does have component test support via Playwright's experimental CT mode).

!!! warning "BDD is a collaboration technique first"
    playwright-bdd is the automation layer. The value of BDD comes from writing scenarios collaboratively with business, QA, and developers before implementation begins — not from the tooling itself.
