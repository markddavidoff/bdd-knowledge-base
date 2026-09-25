---
title: Debugging
description: Debug playwright-bdd scenarios using Playwright Inspector, trace viewer, VS Code extension, and targeted CLI flags.
sources:
  - git-playwright-bdd-repo-docs-guides-debugging-debugging
  - git-playwright-bdd-repo-docs-guides-debugging-run-tests-with-debug-flag
  - git-playwright-bdd-repo-docs-guides-debugging-run-tests-with-ui-flag
  - git-playwright-bdd-repo-docs-faq-faq
  - git-playwright-bdd-repo-docs-configuration-options-missingsteps
---

# Debugging

Because playwright-bdd generates standard Playwright `.spec.ts` files from your feature files, every Playwright debugging method works without modification. This page covers the techniques most useful in a BDD context.

---

## Playwright Inspector (`--debug`)

The `--debug` flag opens a browser window with the Playwright Inspector, which lets you step through each BDD step individually, inspect selectors, and replay the test action-by-action.

```bash
npx bddgen && npx playwright test --debug
```

To debug a single scenario, add a `--grep` filter:

```bash
npx bddgen && npx playwright test --debug --grep "User can log in"
```

!!! tip "Set a breakpoint in step code"
    You can also add `await page.pause()` directly inside a step definition body to pause at that specific step. The Inspector will open automatically.

---

## UI Mode (`--ui`)

UI mode gives you a watchable test runner with a side-by-side feature-and-trace view. Scenarios appear in the left panel labelled by their Gherkin title:

```bash
npx bddgen && npx playwright test --ui
```

Changes to `.feature` files are not picked up automatically in watch mode — re-run `npx bddgen` after editing feature files, then use the "re-run" button in the UI.

---

## Trace Viewer for Failed Scenarios

Enable trace recording on failure in `playwright.config.ts`:

```ts
export default defineConfig({
  use: {
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
  },
});
```

After a failure, open the trace:

```bash
npx playwright show-report          # opens HTML report with embedded traces
# or directly:
npx playwright show-trace trace.zip
```

The trace shows the full browser timeline synchronized to each Gherkin step, making it easy to see which step caused the failure and what the page looked like at that moment.

---

## VS Code Playwright Extension

The official [Playwright VS Code extension](https://marketplace.visualstudio.com/items?itemName=ms-playwright.playwright) integrates with the generated `.spec.ts` files. You can:

- Run or debug an individual scenario by clicking the play button in the gutter
- Set breakpoints inside step definition files and step through them
- View pass/fail status inline in the editor

!!! warning "Feature file navigation requires the Cucumber extension"
    The Playwright extension runs tests from generated `.spec.ts` files, not directly from `.feature` files. To navigate from a Gherkin step to its step definition, install the [Cucumber (Gherkin) Full Support](https://marketplace.visualstudio.com/items?itemName=alexkrechik.cucumberautocomplete) extension alongside it.

---

## `--headed` Flag

Run tests in a visible browser without the full Inspector:

```bash
npx bddgen && npx playwright test --headed
```

Useful for quickly verifying what the browser is doing without pausing execution.

---

## Common Configuration Errors

### "Step not found" Errors

```
Some steps are without definition!

// 1. Missing step definition for "features/auth.feature:12:5"
Given('the user {string} is logged in', async ({}, username: string) => {
  // ...
});
```

This error fires during `bddgen` generation. The output shows a **code snippet** for the missing step. Copy it into your step definition file and implement it.

**Common causes:**

| Symptom | Cause | Fix |
|---------|-------|-----|
| All steps missing | `steps` glob doesn't match your files | Check the glob in `defineBddConfig({ steps: '...' })` |
| One step missing | Typo in step text or parameter pattern mismatch | Diff step text in `.feature` vs. step definition |
| Steps missing after rename | Step text changed in feature file | Update step text in `.ts` file to match |

You can control what `bddgen` does when steps are missing:

```ts
const testDir = defineBddConfig({
  features: 'features/**/*.feature',
  steps: 'features/steps/**/*.ts',
  missingSteps: 'fail-on-gen',  // default: hard-fail at generation time
  // missingSteps: 'fail-on-run',    // generate files but fail at runtime
  // missingSteps: 'skip-scenario',  // mark affected scenarios as fixme
});
```

### Fixture Injection Failures

```
Error: "myFixture" fixture is not defined.
```

**Cause:** A step definition destructures a custom fixture that isn't in scope.

**Fix checklist:**

1. Confirm `test.extend<{ myFixture: MyType }>({...})` is in your fixture file
2. Confirm `createBdd(test)` uses the extended `test` — not the base `import { test } from '@playwright/test'`
3. Confirm the fixture file path is included in the `steps` glob pattern

```ts
// fixtures.ts
import { test as base, createBdd } from 'playwright-bdd';

export const test = base.extend<{ myFixture: string }>({
  myFixture: async ({}, use) => { await use('hello'); },
});

export const { Given, When, Then } = createBdd(test);
```

```ts
// steps.ts — must import from fixtures.ts, not @playwright/test
import { Given } from './fixtures';

Given('I use my fixture', async ({ myFixture }) => {
  console.log(myFixture); // 'hello'
});
```

### ESLint `no-empty-pattern` on `{}`

When a step doesn't use fixtures, Playwright requires the first argument to be `{}`:

```ts
Given('step with no fixtures', async ({}, name: string) => { ... });
```

ESLint's `no-empty-pattern` flags this. Disable the rule for step files:

```js
// eslint.config.mjs
export default [
  {
    files: ['features/steps/**'],
    rules: { 'no-empty-pattern': 'off' },
  },
];
```

---

## Debug Workflow Summary

```bash
# 1. Regenerate after any .feature file change
npx bddgen

# 2. Run a single failing scenario with full debug
npx playwright test --debug --grep "scenario title"

# 3. If the issue is in a hook or setup, check the trace
npx playwright show-report

# 4. For CI failures, download the trace artifact and open locally
npx playwright show-trace ./downloaded-trace.zip
```
