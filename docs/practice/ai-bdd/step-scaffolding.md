---
title: Step Scaffolding
description: Generating playwright-bdd step definitions from a feature file using an LLM — workflow, createBdd() prompting, and fixture type review.
sources:
  - git-playwright-bdd-repo-docs-writing-features-chatgpt-chatgpt
  - git-playwright-bdd-repo-docs-cli-bddgen-export
  - git-playwright-bdd-repo-docs-writing-steps-playwright-style-playwright-style
  - git-playwright-bdd-repo-docs-writing-steps-playwright-style-custom-fixtures
---

# Step Scaffolding

Step scaffolding is the reverse of [scenario authoring](scenario-authoring.md): given a feature file with new or undefined steps, an LLM generates TypeScript step definition stubs. The LLM handles the boilerplate — file structure, imports, `createBdd()` call, function signatures, parameter extraction — leaving you to fill in the actual implementation logic and wire up fixtures.

## When to Use It

Step scaffolding is most useful when:

- You have accepted a feature file from Three Amigos and need to stub out the new steps before implementation.
- You are migrating from `@cucumber/cucumber` World-style steps to playwright-bdd `createBdd()` style.
- A large feature file introduces 10+ new steps and writing stubs by hand is tedious.

It is not a substitute for understanding what each step should do. The LLM generates structure; you provide behavior.

## The Workflow

### Step 1: Identify Undefined Steps

Run `bddgen` dry-run to find which steps are missing implementations:

```bash
npx bddgen --dry-run
```

Output (when steps are undefined):

```
Error: Step "I apply discount code {string}" is not defined.
Error: Step "the subscription shows {string} pricing with a {int}% discount applied" is not defined.

Run "npx bddgen export" to see all defined steps.
```

### Step 2: Collect Context for the Prompt

Gather three pieces of context:

1. **The feature file** (or just the undefined step texts)
2. **The step export** from `npx bddgen export` (shows existing steps and their style)
3. **An example existing step definition file** (shows your fixture graph and import style)

### Step 3: Prompt for `createBdd()` Step Definitions

```
Generate playwright-bdd step definitions in TypeScript for these undefined steps:

Feature file:
```gherkin
Feature: Discount codes

  Background:
    Given I am logged in as "billing_admin"
    And a "pro" organization exists

  Scenario: Apply a valid discount code
    When I apply discount code "SAVE20"
    Then the subscription shows "pro" pricing with a 20% discount applied

  Scenario: Apply an expired discount code
    When I apply discount code "EXPIRED2020-01-01"
    Then I see an error message "This discount code has expired"
```

Existing step definitions (for style reference):
```typescript
import { createBdd } from 'playwright-bdd';
import { test } from './fixtures';

const { Given, When, Then } = createBdd(test);

Given('I am logged in as {string}', async ({ page, auth }, role: string) => {
  await auth.loginAs(role);
});
```

Requirements:
- Use createBdd() style (not World/this)
- Arrow functions only (no function keyword)
- Import from './fixtures' for the test object
- Add a TODO comment where implementation logic is needed
- Preserve parameter types: {string} → string, {int} → number
- Include all necessary imports at the top
```

### Step 4: Review the Output

Typical LLM output:

```typescript
import { expect } from '@playwright/test';
import { createBdd } from 'playwright-bdd';
import { test } from './fixtures';

const { When, Then } = createBdd(test);

When('I apply discount code {string}', async ({ page }, code: string) => {
  // TODO: Navigate to billing settings and apply the discount code
  await page.getByTestId('discount-code-input').fill(code);
  await page.getByRole('button', { name: 'Apply' }).click();
});

Then(
  'the subscription shows {string} pricing with a {int}% discount applied',
  async ({ page }, plan: string, discount: number) => {
    // TODO: Verify the subscription pricing reflects the discount
    const priceElement = page.getByTestId('subscription-price');
    await expect(priceElement).toContainText(`${plan}`);
    await expect(page.getByTestId('discount-badge')).toContainText(`${discount}%`);
  }
);

Then('I see an error message {string}', async ({ page }, message: string) => {
  // TODO: Verify the error message is displayed
  await expect(page.getByRole('alert')).toContainText(message);
});
```

## Type Safety Review

The LLM does not know your fixture graph. After generating step stubs, review the fixture types before accepting:

### Check Fixture Availability

The `{ page }` fixture is always available. Custom fixtures must exist in your `test` object:

```typescript
// If your fixtures.ts exports:
export const test = base.extend<{
  auth: AuthFixture;
  billingPage: BillingPage;
}>({ ... });

// Then step defs can use:
When('I apply discount code {string}', async ({ page, billingPage }, code: string) => {
  await billingPage.applyDiscountCode(code);
});
```

If the LLM uses a fixture name that does not exist in your `test` export, TypeScript will catch it at compile time — but only after you add the correct import.

### Review Parameter Type Mapping

| Cucumber Expression | TypeScript type | LLM typically gets this right |
|--------------------|-----------------|-------------------------------|
| `{string}` | `string` | Yes |
| `{int}` | `number` | Yes |
| `{float}` | `number` | Yes |
| `{word}` | `string` | Yes |
| Custom `{user-role}` | Your custom type | No — LLM defaults to `string` |

For custom parameter types (e.g., `{org-plan}` → `OrgPlan` object), the LLM will type the parameter as `string`. Add a note in your prompt:

```
Custom parameter types in use:
- {user-role}: maps to type UserRole (import from '../types/user-role')
- {org-plan}: maps to type OrgPlan (import from '../types/org-plan')
```

!!! warning "Verify types compile before committing"
    Run `npx tsc --noEmit` after adding LLM-generated step defs. Type errors in fixture destructuring or parameter types are common and easy to miss in a quick visual review.

## Prompting for Style

### `createBdd()` vs. World Style

Explicitly specify which style you want. Without this, some LLMs default to the `@cucumber/cucumber` World style:

```typescript
// WRONG — World style (not playwright-bdd createBdd style)
import { Given, When, Then } from '@cucumber/cucumber';
When('I apply discount code {string}', function (code: string) {
  // this.page is not how playwright-bdd works
});

// CORRECT — createBdd() style
import { createBdd } from 'playwright-bdd';
const { When } = createBdd(test);
When('I apply discount code {string}', async ({ page }, code: string) => {
  // fixture injection, arrow function
});
```

Add to your prompt: "Use playwright-bdd createBdd() style. Do NOT use @cucumber/cucumber imports. Do NOT use World object or `this` context. Use arrow functions with fixture destructuring."

### Decorator Style

If your project uses the decorator style (`@Given`, `@When`, `@Then` on class methods), specify that instead:

```
Generate step definitions using playwright-bdd decorator style:
- Class-based with @Given, @When, @Then decorators
- Import decorators from 'playwright-bdd'
- Use the @Fixture() decorator on the class
```

## See Also

- [createBdd() Style](../playwright-bdd/writing-steps.md) — step definition style reference
- [Custom Fixtures](../playwright-bdd/fixtures.md) — fixture graph and type definitions
- [Exporting Steps](exporting-steps.md) — the companion: generating scenarios from steps
- [Scenario Authoring](scenario-authoring.md) — generating the feature file that step scaffolding fills in
