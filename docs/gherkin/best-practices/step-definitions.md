---
title: Step Phrasing and Vocabulary
description: How to write step text that is reusable, domain-driven, and implementation-free — covering voice, tense, granularity, and abstraction layering.
sources:
  - web-automation-panda-writing-good-gherkin-phrasing-steps
  - git-gherkin-best-practices-repo-readme-define-the-actor-that-will-use-the-system
  - git-gherkin-best-practices-repo-readme-refactor-and-reuse-step-definitions
  - git-gherkin-best-practices-repo-readme-organize-the-test-code-in-layers
  - web-automation-panda-writing-good-gherkin-less-is-more
  - web-itsadeliverything-declarative-imperative-declarative-style-of-gherkin-scenarios
---

# Step Phrasing and Vocabulary

This page covers how to phrase individual step text — the prose that appears after `Given`, `When`, `Then`, `And`, and `But`. Step phrasing has a direct effect on reusability, readability, and the long-term maintainability of your test suite.

!!! note "Scope of this page"
    This page covers step **text** (the Gherkin side). For step **implementation** code quality — thin translation layer, abstraction layers, avoiding direct `page.locator()` calls — see [Step Definition Design](step-definition-design.md).

## Step Text as Domain Language

Every step is a sentence in the [ubiquitous language](ubiquitous-language.md) of your domain. The test for a well-phrased step: could a domain expert write this step without knowing what technology stack runs under it?

```gherkin
# Step leaks implementation
When a POST request is sent to /api/v1/invoices with { "period": "2024-Q1" }

# Step uses domain language
When the billing admin generates an invoice for Q1 2024
```

The domain-language version is stable across API version changes, endpoint renames, and payload schema evolution. The implementation-leak version requires updating the Gherkin every time the API changes.

## Voice, Tense, and Person

Three rules govern step phrasing mechanics:

**Use third-person.** `When the user logs in` is preferable to `When I log in`. First-person is ambiguous in multi-actor scenarios, and it creates confusion when the step is read without knowing who "I" refers to. Pick one convention for the whole project and hold it.

**Use present tense throughout.** This applies to all three step types:

| Step type | Tense guidance | Example |
|---|---|---|
| Given | Present state (stative) | `the account **is** on the Free plan` |
| When | Present action | `the user **requests** a plan upgrade` |
| Then | Present result (assertive) | `the account **has** Pro-tier access` |

Past tense in When (`the user entered`) implies the action has already happened — but When steps are meant to trigger the action now. Future tense in Then (`the page will show`) treats the scenario as a time sequence rather than a behavioral specification.

**Use subject-predicate phrases.** Every step must have a clear subject and predicate. Partial phrases — especially in `And`/`But` continuations — become ambiguous when reused.

```gherkin
# BAD — missing subject, ambiguous
Then links related to "panda" are shown
And image links for "panda"          # What about them? Shown? Not shown?
And video links for "panda"

# GOOD — full subject-predicate
Then links related to "panda" are shown on the results page
And image results for "panda" are visible
And video results for "panda" are visible
```

## First-Person vs. Third-Person: A Practical Decision

Modern BDD teams generally prefer third-person because most applications are multi-user. When a scenario involves two actors — `Alice` (admin) and `Bob` (member) — first-person "I" has no clear referent.

```gherkin
# First-person — ambiguous with two actors
Given I am an admin
And I am viewing Bob's account
When I revoke Bob's access
Then I see a confirmation

# Third-person — clear
Given Alice is an admin viewing Bob's account
When she revokes his access
Then she sees a confirmation
And Bob can no longer access the workspace
```

Third-person also reads more naturally when the scenario title uses behavioral language about "the user" or a named persona.

## Designing Steps for Reuse

Step reuse is not an afterthought — it is a design activity. Before writing a new step, ask whether an existing step can serve the same purpose. Over time, you accumulate a reusable vocabulary that makes new scenarios faster to write and easier to read.

Patterns for reusable steps:

**Parameterize with Cucumber Expressions.** Replace magic strings with typed parameters:

```gherkin
# Reusable across plan types
Given the account is on the {plan} plan
When she upgrades to {plan}
```

**Use named personas instead of inline credentials.** `Given Alice is logged in` is reusable across dozens of scenarios; `Given a user "alice@example.com" with password "secret" is logged in` is single-use and fragile.

**Prefer named states over construction steps.** `Given an active Pro subscription exists` is more reusable than `Given a subscription is created with status "active" and plan "pro" and renewal_date "2025-01-01"`.

## Step Granularity

Steps should operate at the level of domain actions, not UI interactions. The right granularity is one meaningful business action per step.

```gherkin
# Too granular — imperative, one step per UI interaction
When the user scrolls to the submit button
And the user clicks the submit button
And the confirmation modal appears
And the user clicks "Confirm" in the modal

# Right granularity — one domain action
When the user confirms the cancellation
```

The "right granularity" test: if removing a step from the scenario would leave the behavior under-specified, the step is at the right level. If removing it would make no difference to what the scenario is saying, it is too granular.

## Calling Steps from Steps

playwright-bdd and CucumberJS allow step definitions to invoke other steps via a `Step()` helper. This is occasionally useful for shared setup sequences, but it should be used sparingly.

```typescript
// steps/auth.steps.ts
import { createBdd } from 'playwright-bdd';
import { test } from '../fixtures';

const { Given, When, Then, Step } = createBdd(test);

Given('Alice is logged in as a Pro subscriber', async ({ page, request }) => {
  // Prefer: set up state directly via API or fixture
  // Avoid: calling other step definitions here
  await setupProSubscriber(request, 'alice@example.com');
  await loginAs(page, 'alice@example.com');
});
```

The problem with step-calls-step patterns is that they create implicit coupling between step definitions and make failure messages harder to diagnose. Prefer composing via fixtures rather than via step invocation:

```typescript
// fixtures.ts — compose state setup here, not in step defs
export const test = base.extend<{ aliceProSession: Page }>({
  aliceProSession: async ({ browser, request }, use) => {
    const context = await browser.newContext();
    await setupProSubscriber(request, 'alice@example.com');
    await loginInContext(context, 'alice@example.com');
    await use(await context.newPage());
  },
});
```

## Step Abstraction Layers

Step definitions should be thin. They translate Gherkin prose into calls to support code — page objects, API clients, domain helpers — but they should not contain that support code themselves.

```typescript
// THIN — correct
When('the user requests a plan upgrade to {plan}', async ({ page, planPage }, plan: Plan) => {
  await planPage.upgradeTo(plan);
});

// FAT — incorrect: logic belongs in POM, not the step
When('the user requests a plan upgrade to {plan}', async ({ page }, plan: Plan) => {
  await page.goto('/account/billing');
  await page.locator('[data-testid="plan-selector"]').click();
  await page.locator(`[data-plan="${plan.id}"]`).click();
  await page.locator('[data-testid="confirm-upgrade"]').click();
  await page.waitForSelector('[data-testid="upgrade-success"]');
});
```

The fat step creates coupling between the Gherkin vocabulary and the DOM structure. A UI refactor requires editing the step definition file. The thin step delegates to a page object that owns the DOM knowledge — only the page object needs to change.

## Common Step Phrasing Pitfalls

| Pitfall | Example | Fix |
|---|---|---|
| Action in Given | `Given the user navigates to the login page` | `Given the login page is displayed` |
| No assertion in Then | `Then the page reloads` | `Then the dashboard is displayed with the updated plan` |
| Future tense in Then | `Then the invoice will be sent` | `Then an invoice is sent to the user's email` |
| Conjunctive step | `Then the modal closes and a toast appears` | Split into two Then steps |
| Magic strings | `Given a user with role "adm1n"` | `Given Alice is an admin user` |
| Implementation leak | `When a PUT request hits /api/subscriptions` | `When the user downgrades their plan` |

## playwright-bdd Step Definition Example

```typescript
// steps/billing.steps.ts
import { createBdd } from 'playwright-bdd';
import { test } from '../fixtures';
import type { Plan } from '../parameters';

const { Given, When, Then } = createBdd(test);

Given('the {string} account is on the {plan} plan', async ({ billingApi }, name: string, plan: Plan) => {
  await billingApi.setAccountPlan(name, plan.id);
});

When('the billing admin upgrades to {plan}', async ({ billingPage }, plan: Plan) => {
  await billingPage.upgradeTo(plan);
});

Then('the account has {plan} access', async ({ billingApi, accountName }, plan: Plan) => {
  const current = await billingApi.getAccountPlan(accountName);
  expect(current.id).toBe(plan.id);
});
```

Each step is a single call to support code. No locators, no loops, no conditional logic in the step body.

## Cross-References

- [Ubiquitous Language](ubiquitous-language.md) — where step vocabulary comes from
- [Declarative vs. Imperative](declarative-vs-imperative.md) — how step altitude affects phrasing choices
- [Step Definition Design](step-definition-design.md) — the code-quality rules for step implementation bodies
- [Custom Parameter Types](../reference/custom-parameter-types.md) — typed parameters that encode domain vocabulary in step patterns
