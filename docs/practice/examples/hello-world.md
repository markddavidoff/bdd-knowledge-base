---
title: Hello World — playwright-bdd
description: Minimal complete playwright-bdd TypeScript project showing the three required files — playwright.config.ts, a feature file, and a step definition using createBdd().
sources:
  - git-playwright-bdd-repo-docs-configuration-index-index
  - git-playwright-bdd-repo-examples-basic-cjs-readme-basic-usage-of-playwright-bdd-in-typescr
  - git-playwright-bdd-repo-docs-writing-steps-playwright-style-custom-fixtures
  - git-playwright-bdd-repo-docs-getting-started-add-fixtures-add-fixtures
---

# Hello World — playwright-bdd

The minimum viable playwright-bdd project is three files: a config, a feature file, and a step definition. This page shows all three, fully wired together.

## Project structure

```
my-project/
├── playwright.config.ts
├── features/
│   ├── steps/
│   │   └── steps.ts
│   └── homepage.feature
└── package.json
```

## Step 1 — Install

```bash
npm install -D playwright-bdd @playwright/test
npx playwright install chromium
```

## Step 2 — playwright.config.ts

```typescript
// playwright.config.ts
import { defineConfig } from '@playwright/test';
import { defineBddConfig } from 'playwright-bdd';

const testDir = defineBddConfig({
  features: 'features/**/*.feature',
  steps: 'features/steps/**/*.ts',
});

export default defineConfig({
  testDir,
  use: {
    baseURL: 'https://playwright.dev',
  },
});
```

`defineBddConfig()` scans your feature and step files and returns the path to a generated `testDir` where playwright-bdd writes `.spec.ts` files. You never edit those generated files.

## Step 3 — Feature file

```gherkin
# features/homepage.feature
Feature: Playwright homepage

  Scenario: Title is visible
    Given I open the Playwright homepage
    Then the page title contains "Playwright"

  Scenario: Docs link is present
    Given I open the Playwright homepage
    Then I see a "Docs" link in the navigation
```

## Step 4 — Step definitions

```typescript
// features/steps/steps.ts
import { expect } from '@playwright/test';
import { createBdd } from 'playwright-bdd';

const { Given, When, Then } = createBdd();

Given('I open the Playwright homepage', async ({ page }) => {
  await page.goto('/');
});

Then('the page title contains {string}', async ({ page }, text: string) => {
  await expect(page).toHaveTitle(new RegExp(text));
});

Then('I see a {string} link in the navigation', async ({ page }, label: string) => {
  await expect(
    page.getByRole('link', { name: label })
  ).toBeVisible();
});
```

!!! note "createBdd() with no arguments"
    When you have no custom fixtures, `createBdd()` with no arguments gives you `Given`, `When`, `Then` bound to the default Playwright `test` object. The `page` fixture is available in every step automatically.

## Step 5 — Run

```bash
npx bddgen          # generates .spec.ts files
npx playwright test # runs the generated specs
```

Or combine both in a single command (common in `package.json`):

```bash
npx bddgen && npx playwright test
```

## Adding a custom fixture

Once you need state beyond `page`, extend `test` and pass it to `createBdd()`:

```typescript
// features/steps/fixtures.ts
import { test as base, createBdd } from 'playwright-bdd';

type Fixtures = {
  apiToken: string;
};

export const test = base.extend<Fixtures>({
  apiToken: async ({}, use) => {
    // fetch or generate a token before the test
    await use('Bearer test-token-abc123');
  },
});

export const { Given, When, Then } = createBdd(test);
```

```typescript
// features/steps/steps.ts
import { expect } from '@playwright/test';
import { Given, Then } from './fixtures';

Given('I am authenticated via API', async ({ page, apiToken }) => {
  await page.setExtraHTTPHeaders({ Authorization: apiToken });
  await page.goto('/dashboard');
});

Then('the dashboard is visible', async ({ page }) => {
  await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible();
});
```

!!! tip "Always export `test` from fixtures.ts"
    The generated `.spec.ts` files import `test` from the path you give `defineBddConfig`. If you forget to export it, `bddgen` will warn you and the run will fail.

## Next steps

- [Authentication](authentication.md) — add a setup project and `storageState`
- [Fixtures and State](fixtures-and-state.md) — worker-scoped and shared fixtures
- [playwright-bdd configuration reference](../playwright-bdd/configuration.md)
