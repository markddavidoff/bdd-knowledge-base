---
title: Step Definition Design
description: How to write thin, maintainable step definitions that delegate to support code — the translation-layer principle, abstraction layers, smell detection, and organization at scale.
sources:
  - git-gherkin-best-practices-repo-readme-refactor-and-reuse-step-definitions
  - git-gherkin-best-practices-repo-readme-organize-the-test-code-in-layers
  - web-cucumber-gherkin-step-organization-grouping-step-definitions
  - git-playwright-bdd-example-repo-agents-skills-playwright-bdd-skill-example-step-definition
  - git-playwright-bdd-repo-docs-writing-steps-bdd-fixtures-bdd-fixtures
---

# Step Definition Design

A step definition has one job: **translate a Gherkin phrase into a call to support code**. The moment a step definition does real work — parsing locators, constructing SQL, orchestrating multiple assertions — it becomes a maintenance liability that is invisible to non-technical stakeholders and untestable in isolation.

## The Thin Translation Layer Principle

The body of a step definition should be 1–3 lines. Those lines delegate to a Page Object Model (POM), an API client, a domain helper, or a fixture method. The actual logic lives in those support objects, which are testable without Gherkin.

```typescript
// Good — thin translation layer
import { createBdd } from 'playwright-bdd';
import { test } from '../fixtures';

const { Given, When, Then } = createBdd(test);

Given('a {org-plan} organization named {string}', async ({ orgApi }, plan, name) => {
  await orgApi.create({ plan, name });
});

When('the admin downgrades to the free plan', async ({ orgPage }) => {
  await orgPage.downgradePlan('free');
});

Then('the organization should be on the free plan', async ({ orgPage }) => {
  await orgPage.assertCurrentPlan('free');
});
```

Each step is 1–2 lines. `orgApi` and `orgPage` are fixtures that encapsulate implementation details.

## Abstraction Layers

Well-structured playwright-bdd projects use three layers:

| Layer | What lives here | Examples |
|---|---|---|
| **Gherkin** | Behavior specification | `.feature` files |
| **Step definitions** | Phrase → support call | `steps/billing.ts` |
| **Support code** | Actual automation logic | POMs, API clients, DB helpers, fixtures |

Step definitions span the boundary between Gherkin and support code. They should contain no automation logic of their own.

!!! tip "Rule of thumb"
    If you find yourself writing `await page.locator(...)` inside a step definition body, extract it to a Page Object. Step definitions receive POMs via fixtures, not raw `page` objects.

## Diagnosing Step Definition Smell

### Too Long (> ~10 lines)

Long step bodies are a sign that support code hasn't been extracted. Create a helper class or method and call it.

```typescript
// Smells — 15 lines of setup logic in step body
Given('a user account is set up with billing', async ({ page, request }) => {
  await request.post('/api/users', { data: { email: 'test@example.com' } });
  const resp = await request.get('/api/users?email=test@example.com');
  const user = await resp.json();
  await request.post('/api/billing', { data: { userId: user.id, plan: 'pro' } });
  await page.goto('/login');
  await page.fill('[name=email]', 'test@example.com');
  await page.fill('[name=password]', 'password123');
  await page.click('[type=submit]');
  // ...
});
```

Fix: create a `UserFactory` fixture and a `LoginPage` POM. The step becomes two lines.

### Direct `page.locator()` in Step Body

Locator strings in step definitions couple your tests to markup. When the HTML changes, you hunt through step files instead of POMs.

```typescript
// Smells
Then('the error message should appear', async ({ page }) => {
  await expect(page.locator('[data-testid="error-banner"]')).toBeVisible();
});

// Better — POM hides the selector
Then('the error message should appear', async ({ errorPage }) => {
  await errorPage.assertErrorVisible();
});
```

### Direct DB Access in Step Body

Database queries belong in fixture helpers or DB clients, not in step bodies. This is especially important for test isolation — centralized DB helpers can enforce cleanup contracts.

### Multiple Assertions in One Step

A `Then` step with three `expect()` calls is really three assertions bundled together. If one fails, the failure message is ambiguous. Split into separate steps or create an assertion helper that gives a clear failure label.

## Avoiding Duplication

Two step definitions with functionally identical bodies but different phrasing are a duplication hazard. The fix depends on the cause:

- **Synonym problem**: choose one canonical phrasing and update all feature files. Use step aliases (`Given/When/Then` decorating the same function) sparingly.
- **Same logic, different parameters**: generalize with a custom parameter type. See [Custom Parameter Types](../reference/custom-parameter-types.md).
- **Shared setup across domains**: move common logic into a shared fixture or support helper.

!!! note
    Grep for similar transformer logic, not similar step text. Two steps with different text can share the same underlying call — that's the duplication that matters.

## Organization at Scale

### One File Per Domain Area

```
steps/
├── auth.steps.ts         # login, logout, session
├── billing.steps.ts      # plan upgrades, invoices, payment methods
├── user.steps.ts         # user CRUD, profile, roles
├── org.steps.ts          # organization setup, members, settings
└── shared.steps.ts       # generic navigation, assertions used across domains
```

This mirrors the directory pattern recommended by Cucumber for any language: one step file per major domain object. It also avoids the [feature-coupled step definitions](anti-patterns.md#duplicate-step-definitions) anti-pattern, where each feature file has its own step file with no reuse.

### Shared vs. Scoped Steps in playwright-bdd

playwright-bdd supports directory-based step scoping: steps in `features/@billing/steps.ts` are automatically scoped to scenarios in `features/@billing/`. Use scoping when two domains have genuinely conflicting step phrasings:

```
features/
├── shared.steps.ts            # global steps
├── @billing/
│   ├── billing.feature
│   └── steps.ts               # billing-scoped steps
└── @admin/
    ├── admin.feature
    └── steps.ts               # admin-scoped steps
```

See [Organizing Feature Files](organization.md) for the full directory strategy.

## Testing Step Definitions

Do not write unit tests for step definition files. The feature file is already the test. What you should unit-test is the **support code** — Page Objects, API clients, DB helpers — independently of Gherkin.

!!! warning "Common mistake"
    Writing Jest tests that import and call step definition functions directly. This bypasses the Gherkin parsing layer and tests an implementation detail. Test the POM methods directly instead.

```typescript
// Test the support code, not the step wrapper
describe('OrgPage', () => {
  it('asserts current plan from the billing page', async () => {
    // ...test OrgPage.assertCurrentPlan() directly
  });
});
```
