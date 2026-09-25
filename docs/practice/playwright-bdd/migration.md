---
title: Migration Paths
description: Migrate to playwright-bdd from @cucumber/cucumber + raw Playwright, Cypress + cypress-cucumber-preprocessor, or older playwright-bdd versions (v7/v8 → v9).
sources:
  - git-playwright-bdd-repo-docs-guides-migration-v7-migration-v7
  - git-playwright-bdd-repo-docs-guides-migration-v7-all-users
  - git-playwright-bdd-repo-docs-guides-migration-v7-actions-for-cucumber-style
  - git-playwright-bdd-repo-docs-guides-migration-v9-migration-v9
  - git-playwright-bdd-repo-docs-guides-migration-v9-required-actions
  - git-playwright-bdd-repo-docs-guides-migration-v9-behavior-changes
---

# Migration Paths

This page covers three migration paths into playwright-bdd: from `@cucumber/cucumber` + raw Playwright, from Cypress + `cypress-cucumber-preprocessor`, and from older playwright-bdd versions (v7 → v8 → v9).

---

## From `@cucumber/cucumber` + Raw Playwright

### Architectural difference

In a raw CucumberJS setup, `@cucumber/cucumber` is the runner and Playwright is called imperatively inside step definitions via `chromium.launch()` or a shared `page` on the World object. In playwright-bdd, Playwright Test is the runner and the `page` fixture is injected automatically.

### Step 1: Install playwright-bdd, remove @cucumber/cucumber

```bash
npm uninstall @cucumber/cucumber
npm install -D playwright-bdd@latest
```

### Step 2: Replace `Given/When/Then` imports

**Before (CucumberJS):**
```ts
import { Given, When, Then } from '@cucumber/cucumber';

Given('I am on home page', async function () {
  await this.page.goto('/');
});
```

**After (playwright-bdd, Playwright style):**
```ts
import { createBdd } from 'playwright-bdd';

const { Given, When, Then } = createBdd();

Given('I am on home page', async ({ page }) => {
  await page.goto('/');
});
```

Key changes:
- Arrow functions replace `function` keyword (no `this`)
- `page` comes from fixture destructuring, not `this.page`
- `createBdd()` replaces direct imports from `@cucumber/cucumber`

### Step 3: Map World to Fixtures

If your CucumberJS World held shared state, replace it with Playwright fixtures:

```ts
// fixtures.ts
import { test as base, createBdd } from 'playwright-bdd';

export const test = base.extend<{ cart: Cart }>({
  cart: async ({}, use) => {
    const cart = new Cart();
    await use(cart);
    await cart.cleanup();
  },
});

export const { Given, When, Then } = createBdd(test);
```

```ts
// steps.ts
import { Given, Then } from './fixtures';

Given('the user has items in their cart', async ({ cart }) => {
  await cart.addItem('widget');
});
```

### Step 4: Update playwright.config.ts

Replace your `cucumber.js` config with `defineBddConfig()` inside `playwright.config.ts`:

```ts
import { defineConfig } from '@playwright/test';
import { defineBddConfig } from 'playwright-bdd';

const testDir = defineBddConfig({
  features: 'features/**/*.feature',  // replaces 'paths'
  steps: 'steps/**/*.ts',            // replaces 'require' / 'import'
});

export default defineConfig({ testDir });
```

!!! note "No more cucumber.js config file"
    playwright-bdd v7+ does not load `cucumber.js`. All configuration lives in `defineBddConfig()`.

### Step 5: Replace DataTable and defineParameterType imports

```ts
// Before
import { DataTable, defineParameterType } from '@cucumber/cucumber';

// After
import { DataTable, defineParameterType } from 'playwright-bdd';
```

---

## From Cypress + `cypress-cucumber-preprocessor`

### Architectural differences

| Concern | Cypress + preprocessor | playwright-bdd |
|---------|------------------------|----------------|
| Runner | Cypress | Playwright Test |
| Step syntax | `Given/When/Then` (global) | `createBdd(test)` (fixture-injected) |
| State sharing | `cy.wrap()` / aliases | Playwright fixtures |
| Parallelism | Cypress Cloud | Playwright sharding |
| Browser support | Chromium + Firefox (limited) | All major browsers |

### Feature file migration

Feature files themselves are valid Gherkin and require no changes. Only step definitions need updating.

**Before (Cypress):**
```ts
import { Given, When, Then } from '@badeball/cypress-cucumber-preprocessor';

Given('I visit the homepage', () => {
  cy.visit('/');
});

Then('I see the title {string}', (title: string) => {
  cy.title().should('include', title);
});
```

**After (playwright-bdd):**
```ts
import { createBdd } from 'playwright-bdd';
const { Given, Then } = createBdd();

Given('I visit the homepage', async ({ page }) => {
  await page.goto('/');
});

Then('I see the title {string}', async ({ page }, title: string) => {
  await expect(page).toHaveTitle(new RegExp(title));
});
```

### Configuration

Replace `cypress.config.ts` + preprocessor config with `playwright.config.ts` + `defineBddConfig()`. See [Installation](installation.md) for the full config setup.

---

## From Older playwright-bdd Versions

### v7 → v8: CucumberJS independence

v7 removed the dependency on `@cucumber/cucumber` as a runner. The key changes:

- `require` and `import` options → unified `steps` glob
- `paths` → `features` glob
- `importTestFrom` is now auto-detected (can usually be omitted)
- `cucumber.js` config file is no longer loaded
- `DataTable` and `defineParameterType` now imported from `playwright-bdd`, not `@cucumber/cucumber`

```ts
// Before v7
const testDir = defineBddConfig({
  paths: ['features/*.feature'],
  require: ['steps/*.ts'],
  importTestFrom: 'steps/fixtures.ts',
});

// v7+
const testDir = defineBddConfig({
  features: 'features/**/*.feature',
  steps: 'steps/**/*.ts',
  // importTestFrom auto-detected
});
```

### v8 → v9: Node.js 20+, API cleanup

v9 makes smaller breaking changes:

1. **Node.js 20+ required** (was 18):
   ```bash
   node --version  # must be >= 20
   ```

2. **Remove `enrichReporterData` option** (deprecated in v7, removed in v9):
   ```ts
   // Remove this line:
   enrichReporterData: true,
   ```

3. **JUnit reporter naming changed** — new default is Cucumber-compatible naming. If your CI pipeline uses JUnit test names for filtering, add `nameFormat: 'playwright'` to restore old behavior:
   ```ts
   cucumberReporter('junit', {
     outputFile: 'report.xml',
     nameFormat: 'playwright', // restore pre-v9 behavior
   })
   ```

4. **Stricter arity validation** — step functions must now declare the correct number of arguments. Fix arity mismatches or opt out per-step:
   ```ts
   Given('I have {int} items', ({ page }, count: number) => { ... }); // correct
   ```

---

## Dual-Mode Operation During Migration

If you're migrating a large suite, run the old and new suites in parallel for a sprint:

```json
{
  "scripts": {
    "test:legacy": "cucumber-js",
    "test:bdd": "npx bddgen && npx playwright test",
    "test:all": "npm run test:legacy && npm run test:bdd"
  }
}
```

Migrate feature by feature, verifying parity before retiring each legacy step file. Once all features pass under playwright-bdd, remove the CucumberJS config and scripts.

!!! tip "Cross-ref: vs. raw CucumberJS runner"
    For a full architectural comparison of playwright-bdd vs. `@cucumber/cucumber` as a runner, see [vs. @cucumber/cucumber Runner](vs-cucumber-runner.md).
