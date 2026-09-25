---
title: BDD Without a Browser
description: How to apply BDD to API-only and backend services using playwright-bdd APIRequestContext or the @cucumber/cucumber + supertest approach.
sources:
  - git-playwright-bdd-repo-examples-api-testing-readme-readme
  - git-playwright-bdd-repo-docs-writing-steps-playwright-style-playwright-style
  - git-playwright-bdd-repo-docs-getting-started-write-first-test-write-first-test
  - web-automation-panda-writing-good-gherkin-proper-behavior
---

# BDD Without a Browser

BDD is a collaboration methodology, not a UI testing framework. Any service with observable behavior and stakeholder-agreed acceptance criteria is a candidate for Gherkin scenarios — regardless of whether a browser is involved.

## When BDD Applies to API-Only Services

BDD is appropriate for a backend service when:

- Business stakeholders or product owners care about the behavior (not just developers)
- The service has defined contracts that encode business rules (not just CRUD pass-through)
- Failure modes carry business significance (rejected orders, permission denials, rate limiting)
- The team practices Three Amigos on story definition for backend work

It is less valuable when the service is purely internal infrastructure with no business-rule logic (e.g., a data migration script or a cache warmer).

## The Two Tool Approaches

### Approach 1: playwright-bdd with APIRequestContext (fixtures-first, TypeScript)

Use this when your project already uses playwright-bdd, or when you have mixed UI+API scenarios in the same suite.

playwright-bdd's `createBdd()` works with the built-in `request` fixture from Playwright. No browser is launched. The fixture handles HTTP client setup; steps use it just like they use `page`.

```gherkin
# features/orders/order-placement.feature

Feature: Order placement API

  Scenario: Successful order from a single in-stock item
    Given the catalog contains "Wireless Keyboard" with 10 units available
    When I place an order for "Wireless Keyboard" as customer "alice@example.com"
    Then the order status is "confirmed"
    And the available inventory for "Wireless Keyboard" is 9
```

```typescript
// steps/orders/order-placement.steps.ts

import { expect } from '@playwright/test';
import { createBdd } from 'playwright-bdd';

const { Given, When, Then } = createBdd();

Given(
  'the catalog contains {string} with {int} units available',
  async ({ request }, productName: string, units: number) => {
    await request.post('/admin/inventory', {
      data: { product: productName, quantity: units },
    });
  }
);

When(
  'I place an order for {string} as customer {string}',
  async ({ request }, productName: string, email: string) => {
    const response = await request.post('/api/orders', {
      data: { product: productName, customerEmail: email },
    });
    expect(response.ok()).toBeTruthy();
    // store response in a fixture for subsequent steps
  }
);

Then('the order status is {string}', async ({ request }, status: string) => {
  const orders = await request.get('/api/orders?email=alice@example.com');
  const body = await orders.json();
  expect(body[0].status).toBe(status);
});
```

The `playwright.config.ts` for API-only testing disables browser launch:

```typescript
// playwright.config.ts
import { defineConfig } from '@playwright/test';
import { defineBddConfig } from 'playwright-bdd';

const testDir = defineBddConfig({
  features: 'features/**/*.feature',
  steps: 'steps/**/*.steps.ts',
});

export default defineConfig({
  testDir,
  use: {
    baseURL: process.env.API_BASE_URL ?? 'http://localhost:3000',
  },
  // No browser projects needed for pure API testing
});
```

### Approach 2: @cucumber/cucumber + supertest (World object, function keyword)

Use this for **pure backend services** with no browser scenarios anywhere in the suite. The Cucumber runner is lighter — no Playwright binary required.

Step definitions use `function` keyword (required for `this` World access) and `supertest` for HTTP:

```typescript
// steps/orders/order-placement.steps.ts

import { Given, When, Then, IWorld } from '@cucumber/cucumber';
import request from 'supertest';
import { app } from '../../src/app';

Given(
  'the catalog contains {string} with {int} units available',
  async function (this: IWorld, productName: string, units: number) {
    await request(app).post('/admin/inventory')
      .send({ product: productName, quantity: units });
  }
);

When(
  'I place an order for {string} as customer {string}',
  async function (this: IWorld, productName: string, email: string) {
    const response = await request(app).post('/api/orders')
      .send({ product: productName, customerEmail: email });
    this.lastResponse = response;
  }
);

Then('the order status is {string}', function (this: IWorld, status: string) {
  expect(this.lastResponse.body.status).toBe(status);
});
```

!!! note "Key language difference"
    playwright-bdd uses arrow functions with fixture injection as the first parameter. @cucumber/cucumber uses `function` keyword with `this` as the World context. You cannot mix these styles in the same step definition file.

## Gherkin Vocabulary for API Behavior

The declarative vs. imperative rule applies to API scenarios just as much as UI scenarios. Write steps that describe **business intent**, not HTTP mechanics.

| Imperative (avoid) | Declarative (use) |
|---|---|
| `When I POST to /api/orders with body {...}` | `When I place an order for "Wireless Keyboard"` |
| `Then the response status is 200` | `Then the order is confirmed` |
| `Then the JSON body has "status": "created"` | `Then the order status is "created"` |
| `When I send a GET request to /api/users/42` | `When I view my account profile` |

The endpoint path, HTTP method, and response format are step definition concerns, not Gherkin concerns. A product owner reading the feature file should not need to know what HTTP verb is used.

## Decision Guide: Which Approach to Use

| Situation | Recommendation |
|---|---|
| Mixed UI + API suite | playwright-bdd (`createBdd()` + `request` fixture) |
| Pure backend service, no browser | `@cucumber/cucumber` + supertest (lighter) |
| Team is new to BDD, starting with UI | playwright-bdd first, add API later with same tooling |
| Need Playwright's trace/video on API failures | playwright-bdd |
| Node/npm footprint must be minimal | `@cucumber/cucumber` + supertest |

## Cross-references

- [CI Running](ci-running.md) — `bddgen` pipeline for playwright-bdd API suites
- [Examples: API Testing](../examples/api-testing-playwright-bdd.md) — full worked examples for both approaches
- [playwright-bdd: Playwright Style Steps](../playwright-bdd/writing-steps.md)
