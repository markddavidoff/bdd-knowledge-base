---
title: "@cucumber/cucumber (CucumberJS)"
description: Step definition style, World object, configuration, and parameter types for the @cucumber/cucumber runner — with side-by-side comparison to playwright-bdd.
sources:
  - web-playwright-bdd-vs-cucumber-cucumber-js-vs-playwright-bdd-comparison
  - web-playwright-bdd-vs-cucumber-which-should-you-choose
  - web-playwright-bdd-vs-cucumber-feature-differences-by-test-runner
  - git-cucumber-js-docs-faq-the-world-instance-isn-t-available-in-my-hooks-or-step-defin
  - git-cucumber-js-docs-configuration-options
  - git-playwright-bdd-repo-docs-writing-steps-cucumber-style-cucumber-style
---

# @cucumber/cucumber (CucumberJS)

`@cucumber/cucumber` is the official Cucumber runner for JavaScript and TypeScript. It is the most direct sibling of playwright-bdd: both parse Gherkin, both run in Node.js, and both share the `cucumber-expressions` library for step matching. The fundamental difference is the **test runner**: CucumberJS is its own runner, while playwright-bdd delegates to Playwright Test.

## The Same Feature File

Both runners consume identical `.feature` files:

```gherkin
Feature: Shopping cart

  Scenario: Adding an item to an empty cart
    Given the cart is empty
    When Alex adds "Mechanical Keyboard" to the cart
    Then the cart contains 1 item
    And the cart total is $129.99
```

## Step Definitions: CucumberJS Style

In `@cucumber/cucumber`, `Given`, `When`, and `Then` are imported directly from the package. The World object is accessed via `this`, which means **arrow functions are forbidden** when you need World access.

```typescript
// steps/cart.steps.ts
import { Given, When, Then } from '@cucumber/cucumber';

Given('the cart is empty', async function () {
  // `this` is the World instance
  this.cart = await this.api.clearCart();
});

When('Alex adds {string} to the cart', async function (productName: string) {
  this.cart = await this.api.addItem(productName);
});

Then('the cart contains {int} item', async function (count: number) {
  expect(this.cart.items).toHaveLength(count);
});

Then('the cart total is ${float}', async function (total: number) {
  expect(this.cart.total).toBe(total);
});
```

!!! warning "Arrow functions and `this`"
    CucumberJS binds the World to `this` using `Function.prototype.apply`. Arrow functions ignore `apply`, so `this` is undefined inside them. Always use the `function` keyword when your step needs World access. This is the most common migration footgun when moving from CucumberJS to playwright-bdd, which uses arrow functions and fixture injection instead.

## Defining the World

The World is a class that holds shared state across steps within a single scenario. Register it with `setWorldConstructor`:

```typescript
// support/world.ts
import { setWorldConstructor, World } from '@cucumber/cucumber';
import { chromium, Browser, Page } from '@playwright/test';

class CustomWorld extends World {
  browser!: Browser;
  page!: Page;
  cart: any;

  async openBrowser() {
    this.browser = await chromium.launch();
    this.page = await this.browser.newPage();
  }

  async closeBrowser() {
    await this.browser.close();
  }
}

setWorldConstructor(CustomWorld);
```

Hooks set up and tear down the browser around each scenario:

```typescript
// support/hooks.ts
import { Before, After } from '@cucumber/cucumber';

Before(async function () {
  await this.openBrowser();
});

After(async function () {
  await this.closeBrowser();
});
```

## CucumberJS Configuration

Configuration lives in `cucumber.json`, `.cucumber.js`, or `.cucumber.cjs` at the project root:

```json
{
  "default": {
    "paths": ["features/**/*.feature"],
    "import": ["support/**/*.ts", "steps/**/*.ts"],
    "format": ["progress-bar", ["html", "reports/cucumber.html"]],
    "parallel": 4,
    "strict": true
  }
}
```

For TypeScript projects, add a transpile loader:

```json
{
  "default": {
    "loader": ["ts-node/esm"],
    "paths": ["features/**/*.feature"],
    "import": ["support/**/*.ts", "steps/**/*.ts"]
  }
}
```

## Parameter Types in CucumberJS

`defineParameterType` is imported from `@cucumber/cucumber` (not from `playwright-bdd`):

```typescript
// support/parameters.ts
import { defineParameterType } from '@cucumber/cucumber';

defineParameterType({
  name: 'org-plan',
  regexp: /free|pro|enterprise/,
  transformer(planName: string) {
    const plans: Record<string, object> = {
      free:       { billingEnabled: false, seatLimit: 5 },
      pro:        { billingEnabled: true,  seatLimit: 50 },
      enterprise: { billingEnabled: true,  seatLimit: Infinity },
    };
    return plans[planName];
  },
});
```

The API is identical to playwright-bdd's `defineParameterType` — this is one of the portable patterns across all Cucumber-family runners.

## Side-by-Side Comparison

| Concept | @cucumber/cucumber | playwright-bdd |
|---------|-------------------|----------------|
| Step imports | `import { Given } from '@cucumber/cucumber'` | `const { Given } = createBdd(test)` |
| State sharing | `this.someValue` (World) | `{ myFixture }` (first argument) |
| Function style | `function` keyword required | Arrow functions |
| Parameter types | `defineParameterType` from `@cucumber/cucumber` | `defineParameterType` from `playwright-bdd` |
| Parallelism | `--parallel N` (worker threads) | Playwright's worker model |
| Sharding | Not built-in | `--shard N/M` |
| Trace viewer | Not available | Built-in |
| Visual regression | Separate setup required | `toHaveScreenshot()` built-in |

## When to Choose CucumberJS

- **Pure API or backend testing**: No browser needed, no Playwright overhead
- **Existing CucumberJS codebase**: Step definitions and World already written; migration cost outweighs the benefits
- **Cross-language team knowledge**: If your team also maintains Java or Python suites, the Cucumber World model is consistent across all of them
- **Specific CucumberJS formatters**: If your reporting pipeline relies on Cucumber's message format or cloud publish integration

!!! tip "Migrating to playwright-bdd"
    Feature files are unchanged. Step definition bodies can usually be ported directly — the main surgery is replacing `this.xxx` references with fixture parameters and converting `function` to arrow functions. See [Migration Paths](../playwright-bdd/migration.md).
