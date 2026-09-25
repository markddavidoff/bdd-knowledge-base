---
title: Installation
description: Install playwright-bdd, configure playwright.config.ts with defineBddConfig(), and run your first BDD test.
sources:
  - git-playwright-bdd-repo-docs-getting-started-installation-installation
  - git-playwright-bdd-repo-docs-getting-started-installation-npm
  - git-playwright-bdd-repo-docs-getting-started-write-first-test-write-first-test
  - git-playwright-bdd-repo-docs-configuration-index-index
  - git-playwright-bdd-repo-docs-guides-ide-integration-vs-code
  - git-playwright-bdd-repo-docs-faq-faq
---

# Installation

## Prerequisites

- Node.js 18+
- `@playwright/test` (installed automatically if you follow the steps below)

---

## Step 1 — Install Packages

**New project (no Playwright yet):**

```bash
npm install -D @playwright/test playwright-bdd
npx playwright install
```

**Existing Playwright project:**

```bash
npm install -D playwright-bdd
```

pnpm and Yarn equivalents:

```bash
# pnpm
pnpm add -D @playwright/test playwright-bdd

# Yarn
yarn add -D @playwright/test playwright-bdd
```

---

## Step 2 — Create `playwright.config.ts`

playwright-bdd is configured through `defineBddConfig()` inside your Playwright config. The function returns the `testDir` path where generated `.spec.ts` files will be written.

```ts
// playwright.config.ts
import { defineConfig } from '@playwright/test';
import { defineBddConfig } from 'playwright-bdd';

const testDir = defineBddConfig({
  features: 'features/**/*.feature',
  steps: 'features/steps/**/*.ts',
});

export default defineConfig({
  testDir,
  reporter: 'html',
});
```

!!! note "All paths are relative to the config file"
    `features`, `steps`, and `outputDir` are all resolved relative to the location of `playwright.config.ts`.

---

## Step 3 — Create a Feature File

```gherkin
# features/home.feature
Feature: Playwright site

  Scenario: Check get started link
    Given I am on home page
    When I click link "Get started"
    Then I see in title "Installation"
```

---

## Step 4 — Implement Step Definitions

```ts
// features/steps/home.steps.ts
import { expect } from '@playwright/test';
import { createBdd } from 'playwright-bdd';

const { Given, When, Then } = createBdd();

Given('I am on home page', async ({ page }) => {
  await page.goto('https://playwright.dev');
});

When('I click link {string}', async ({ page }, name) => {
  await page.getByRole('link', { name }).click();
});

Then('I see in title {string}', async ({ page }, keyword) => {
  await expect(page).toHaveTitle(new RegExp(keyword));
});
```

The first argument to each step function is the **fixture object** — an object destructuring pattern that gives you access to Playwright built-ins (`page`, `browser`, `context`, `request`) and any custom fixtures you define.

---

## Step 5 — Run Tests

```bash
npx bddgen && npx playwright test
```

This runs both phases: generation then execution. On success you will see:

```
Running 1 test using 1 worker
1 passed (2.0s)
```

To view the HTML report:

```bash
npx playwright show-report
```

---

## VS Code Step Autocomplete

Install the [Cucumber (Gherkin) Full Support](https://marketplace.visualstudio.com/items?itemName=alexkrechik.cucumberautocomplete) extension, then add to `.vscode/settings.json`:

```json
{
  "cucumberautocomplete.steps": ["features/steps/*.{ts,js}"],
  "cucumberautocomplete.strictGherkinCompletion": false,
  "cucumberautocomplete.strictGherkinValidation": false,
  "cucumberautocomplete.smartSnippets": true,
  "cucumberautocomplete.onTypeFormat": true,
  "editor.quickSuggestions": {
    "comments": false,
    "strings": true,
    "other": true
  }
}
```

!!! warning "Don't enable both Cucumber extensions"
    The `Cucumber (Gherkin) Full Support` and the `Official Cucumber extension` conflict in VS Code. Enable only one.

The Official Playwright extension also picks up the generated `.features-gen/` files and lets you run or debug individual scenarios by clicking the play button next to each test.

---

## Common Setup Errors

| Error | Cause | Fix |
|-------|-------|-----|
| `No test files found` | Wrong `testDir` or `bddgen` not run | Run `npx bddgen` before `playwright test` |
| `Step not found: "Given I am on…"` | Step file not matched by `steps` glob | Check the glob pattern in `defineBddConfig()` |
| `Cannot find module 'playwright-bdd'` | Package not installed | `npm install -D playwright-bdd` |
| `SyntaxError: Cannot use import statement` | ESM not configured | See [TypeScript Configuration](typescript-config.md) |
| ESLint `no-empty-pattern` on `{}` | ESLint rule conflict | Disable `no-empty-pattern` for step files — `{}` is required by Playwright |

---

## Next Steps

- [Configuration](configuration.md) — full `defineBddConfig()` options reference
- [TypeScript Configuration](typescript-config.md) — ESM setup and type safety
- [Writing Steps](writing-steps.md) — step definition styles
- [Fixtures](fixtures.md) — extending with custom fixtures
