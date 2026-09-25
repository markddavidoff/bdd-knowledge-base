---
title: Companion Libraries
description: Overview of libraries that work alongside playwright-bdd — playwright-magic-steps, playwright-network-cache, request-mocking-protocol, and talewright.
sources:
  - git-playwright-bdd-repo-docs-writing-features-special-tags-fail
  - git-playwright-bdd-repo-docs-configuration-index-index
  - git-playwright-bdd-repo-docs-reporters-playwright-playwright
---

# Companion Libraries

playwright-bdd sits at the center of a small ecosystem of companion libraries. Each solves a specific problem that playwright-bdd intentionally leaves out of scope. This page describes what each does, when to use it, and what trade-offs to weigh.

---

## `playwright-magic-steps`

**What it is:** BDD-style step definitions without `.feature` files. Steps are written as TypeScript comments directly above the code they describe, and the library interprets them at runtime.

```ts
// Given I am on the home page
await page.goto('/');

// When I click "Get started"
await page.getByRole('link', { name: 'Get started' }).click();

// Then I see "Installation" in the title
await expect(page).toHaveTitle(/Installation/);
```

**Trade-offs:**

| Benefit | Cost |
|---------|------|
| No `.feature` file, no step definition wiring | Non-business stakeholders cannot read the spec in a separate file |
| Zero boilerplate | No step reuse across tests |
| Familiar to developers used to comment-driven style | Steps are imperative by nature (hard to stay declarative) |
| Works directly in Playwright test files | No Gherkin tooling (linting, autocomplete, format checks) |

**When to use:** Exploratory tests, rapid prototyping, or developer-only test suites where the team has no product owner reading feature files. Not recommended when BDD's collaboration value matters.

---

## `playwright-network-cache`

**What it is:** A Playwright fixture that records and replays HTTP responses, similar to VCR cassettes. On first run it passes requests through; on subsequent runs it serves the cached response from disk.

```ts
// fixtures.ts
import { test as base } from '@playwright/test';
import { NetworkCache } from 'playwright-network-cache';

export const test = base.extend<{ networkCache: NetworkCache }>({
  networkCache: async ({ page }, use) => {
    const cache = new NetworkCache(page, { cacheDir: 'network-cache/' });
    await cache.activate();
    await use(cache);
  },
});
```

```ts
// steps.ts
import { createBdd } from 'playwright-bdd';
import { test } from './fixtures';

const { Given } = createBdd(test);

Given('I am viewing cached product data', async ({ networkCache, page }) => {
  await networkCache.useCache('product-catalog');
  await page.goto('/catalog');
});
```

**Trade-offs:**

| Benefit | Cost |
|---------|------|
| Consistent test data — no flakiness from API changes | Cache files must be committed or regenerated |
| Fast tests — no real network I/O in CI | Stale caches can hide real API regressions |
| Useful for third-party APIs you cannot control | Cache invalidation is a manual process |

**When to use:** Tests that depend on expensive or rate-limited external APIs. Not a substitute for `page.route()` when you need precise control over response shape — use `page.route()` directly for those cases (see [Network Mocking](network-mocking.md)).

---

## `request-mocking-protocol`

**What it is:** A structured protocol for defining mock HTTP responses using a declarative configuration object, rather than writing `page.route()` handlers by hand. It sits between your step definitions and Playwright's routing API.

```ts
Given('the payment API declines the card', async ({ page }) => {
  await setupMocks(page, [
    {
      url: '**/api/payments',
      method: 'POST',
      response: { status: 402, body: { error: 'card_declined' } },
    },
  ]);
});
```

**Trade-offs:**

| Benefit | Cost |
|---------|------|
| Declarative mock definitions — readable in step code | Extra dependency and API to learn |
| Consistent mock format across the team | Less flexible than raw `page.route()` for complex scenarios |
| Easier to generate mocks from OpenAPI specs | Requires the team to adopt the protocol uniformly |

**When to use:** Large teams where multiple developers write mocks and consistency matters. Overkill for small projects — reach for `page.route()` directly.

---

## `talewright`

**What it is:** A complete BDD framework for Playwright that does _not_ use Gherkin. Instead, tests are structured in a story/act/outcome format using TypeScript directly:

```ts
import { story, act, outcome } from 'talewright';

story('User registration', () => {
  act('the user fills in the registration form', async ({ page }) => {
    await page.getByLabel('Email').fill('user@example.com');
    await page.getByLabel('Password').fill('secret123');
    await page.getByRole('button', { name: 'Register' }).click();
  });

  outcome('the dashboard is shown', async ({ page }) => {
    await expect(page.getByRole('heading', { name: 'Dashboard' })).toBeVisible();
  });
});
```

**Trade-offs:**

| Benefit | Cost |
|---------|------|
| No Gherkin syntax to learn | Non-technical stakeholders cannot read it |
| No `.feature` file / step definition split | Loses the collaboration artifact that makes BDD valuable |
| Full TypeScript IDE support from the start | No Gherkin tooling ecosystem (linting, autocomplete, formatters) |
| Familiar structure for developers | Not executable specification in the BDD sense |

**When to use:** Teams that want structured test narratives and fixture injection but have no requirement for business-readable `.feature` files. If stakeholder collaboration over specs is a goal, stick with playwright-bdd.

---

## Decision Guide

```
Do stakeholders (PO, BA, QA) need to read/review the spec?
  YES → Use playwright-bdd with .feature files
  NO  → Consider talewright or playwright-magic-steps

Do you have expensive external APIs to mock consistently?
  YES → playwright-network-cache (caching) or page.route() (precise control)
  NO  → page.route() directly

Do multiple developers write mocks with varying styles?
  YES → request-mocking-protocol (standardizes format)
  NO  → page.route() directly
```

!!! warning "Don't introduce companions before you need them"
    Each companion library adds a dependency and a surface area for breakage. Start with playwright-bdd + `page.route()`. Add companions only when a specific pain is felt repeatedly.

!!! tip "Cross-ref: network mocking patterns"
    For `page.route()` patterns and fixture-based mock reuse, see [Network Mocking](network-mocking.md).
