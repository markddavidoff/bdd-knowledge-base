---
title: vs. @cucumber/cucumber Runner
description: Architectural comparison of playwright-bdd and the raw @cucumber/cucumber runner — when to use each, feature gaps, and performance differences.
sources:
  - web-playwright-bdd-vs-cucumber-introduction
  - web-playwright-bdd-vs-cucumber-cucumber-js-vs-playwright-bdd-comparison
  - web-playwright-bdd-vs-cucumber-feature-differences-by-test-runner
  - web-playwright-bdd-vs-cucumber-conclusion
  - git-playwright-bdd-repo-docs-faq-faq
  - git-playwright-bdd-repo-docs-blog-whats-new-in-v8-whats-new-in-v8
---

# vs. `@cucumber/cucumber` Runner

Both playwright-bdd and the raw `@cucumber/cucumber` runner execute Gherkin feature files. The core difference is the **test runner** — and that difference ripples through parallelism, fixtures, reporters, TypeScript support, and ecosystem integration.

---

## Architectural Difference

### `@cucumber/cucumber` (raw runner)

Cucumber is the test runner. Playwright is called imperatively from inside step definitions. The typical pattern:

```ts
// steps.ts — CucumberJS style
import { Given, When, Then } from '@cucumber/cucumber';
import { chromium, Browser, Page } from '@playwright/test';

let browser: Browser;
let page: Page;

Before(async () => {
  browser = await chromium.launch();
  page = await browser.newPage();
});

After(async () => {
  await browser.close();
});

Given('I am on the home page', async () => {
  await page.goto('/');
});
```

Cucumber manages the test lifecycle; you manage the browser lifecycle.

### playwright-bdd

Playwright Test is the test runner. playwright-bdd generates `.spec.ts` files from your feature files, then Playwright Test executes them. The `page` fixture is injected automatically:

```ts
// steps.ts — playwright-bdd style
import { createBdd } from 'playwright-bdd';

const { Given, When, Then } = createBdd();

Given('I am on the home page', async ({ page }) => {
  await page.goto('/');
});
```

playwright-bdd manages the browser lifecycle; you declare what you need as fixtures.

---

## Feature Comparison

| Feature | playwright-bdd | `@cucumber/cucumber` + Playwright |
|---------|----------------|-----------------------------------|
| Gherkin syntax | Full | Full |
| Test runner | Playwright Test | Cucumber runner |
| Playwright fixtures | Built-in | Via World object (manual) |
| Page Object Model integration | Decorator + fixture | World object only |
| `toHaveScreenshot()` (VRT) | Built-in | Requires separate setup |
| `toMatchSnapshot()` | Built-in | Requires separate setup |
| Trace Viewer | Built-in | Requires separate setup |
| HTML reporter (Playwright) | Built-in | Not available |
| Cucumber HTML/JSON reporter | Via `cucumberReporter()` | Built-in |
| UI Mode (`--ui`) | Built-in | Not available |
| Test sharding | Built-in | Not available |
| TypeScript type safety for fixtures | Strong (generics) | Weak (untyped World) |
| Parallelism model | Worker-based (configurable) | Worker-based (separate config) |
| AI tooling (`bddgen export`) | Built-in | Not available |
| "Fix with AI" prompt | Built-in (v8.1+) | Not available |

---

## Parallelism Model

**playwright-bdd** inherits Playwright Test's worker model: each worker runs scenarios in isolation with its own browser context. Sharding across machines is a single CLI flag:

```bash
npx bddgen && npx playwright test --shard 1/4
npx bddgen && npx playwright test --shard 2/4
```

**@cucumber/cucumber** supports parallel execution via its own parallel option in `cucumber.js`, but test sharding across machines requires external tooling or manual script splitting. The fixture model means you must manage browser lifecycle explicitly in `Before`/`After` hooks.

---

## When to Use the Raw `@cucumber/cucumber` Runner

The raw runner is the better choice when:

1. **No browser involved.** Pure API testing, backend service BDD, CLI tool testing. The raw runner has no Playwright dependency weight and runs faster.

2. **Existing large CucumberJS suite.** Migrating a mature CucumberJS suite to playwright-bdd requires rewriting all step definitions. If the suite works, migration cost may not be justified.

3. **SpecFlow / Behave parity.** Teams who also maintain C# or Python BDD suites may prefer the consistent Cucumber ecosystem API across languages.

4. **Specific Cucumber formatters.** If your reporting pipeline depends on a formatter that has no playwright-bdd equivalent.

!!! example "API testing with raw CucumberJS"
    ```ts
    // steps.ts — raw CucumberJS for API testing
    import { Given, When, Then, Before } from '@cucumber/cucumber';
    import supertest from 'supertest';

    let app: supertest.SuperTest<supertest.Test>;
    let response: supertest.Response;

    Before(() => { app = supertest('http://localhost:3000'); });

    When('I request GET {string}', async (path: string) => {
      response = await app.get(path);
    });

    Then('the response status is {int}', (status: number) => {
      expect(response.status).toBe(status);
    });
    ```

---

## When playwright-bdd Wins

playwright-bdd is the better choice when:

1. **UI testing with Playwright.** You get the full Playwright ecosystem — fixtures, trace viewer, UI mode, VRT — without manual browser lifecycle management.

2. **TypeScript-first team.** playwright-bdd's fixture system provides end-to-end type safety from feature file to step definition to page object.

3. **Full Playwright tooling.** VS Code extension test running, `--debug` step-through, `--ui` watch mode, and built-in sharding all work out of the box.

4. **AI integration.** `bddgen export` and "Fix with AI" are playwright-bdd-specific features.

5. **Mixed UI + API test suite.** playwright-bdd can use Playwright's `APIRequestContext` for API steps alongside browser steps in the same step definition files, with the same fixture injection model.

---

## Performance Comparison

In a typical UI test suite (50-200 scenarios):

- **playwright-bdd** adds a `bddgen` pre-step (~1-3s for most suites). Test execution speed is identical since both ultimately call Playwright's browser engine.
- **@cucumber/cucumber** avoids the pre-step but requires you to manage browser pooling yourself. Without careful `Before`/`After` hook design, you may end up launching a new browser per scenario.

For pure API suites, the raw CucumberJS runner is meaningfully faster because it carries no Playwright browser engine overhead.

---

## Summary

```
Is this a UI test that needs Playwright?
  YES → playwright-bdd

Is this a pure API / backend test with no browser?
  NO BROWSER → @cucumber/cucumber (lighter, no Playwright weight)

Do you have a large existing CucumberJS suite?
  LARGE EXISTING SUITE → stay on @cucumber/cucumber unless you have
  a compelling reason to migrate (see [Migration Paths](migration.md))

Do you want Playwright trace viewer, VRT, or UI mode?
  YES → playwright-bdd only (not available in raw runner)
```

See [Migration Paths](migration.md) if you're moving from the raw runner to playwright-bdd.
