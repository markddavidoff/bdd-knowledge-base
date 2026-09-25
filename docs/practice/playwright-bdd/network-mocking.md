---
title: Network Mocking
description: Intercept and mock HTTP requests in playwright-bdd step definitions using page.route(), with patterns for error testing and cleanup.
sources:
  - git-playwright-bdd-repo-docs-writing-steps-playwright-style-playwright-style
  - git-playwright-bdd-repo-docs-writing-steps-playwright-style-custom-fixtures
  - git-playwright-bdd-repo-docs-writing-steps-hooks-fixtures-fixtures
  - git-playwright-bdd-repo-docs-writing-steps-passing-data-between-steps-passing-data-between
---

# Network Mocking

playwright-bdd inherits Playwright's full network interception API. Step definitions can intercept requests, return mocked responses, simulate errors, and clean up routes — all within the BDD scenario lifecycle.

## Basic Route Interception in Steps

Use `page.route()` inside a step definition to intercept network requests before they reach the server:

```ts
import { createBdd } from 'playwright-bdd';
import { test } from './fixtures';

const { Given, When, Then } = createBdd(test);

Given('the product API returns an empty catalog', async ({ page }) => {
  await page.route('**/api/products', (route) => {
    route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify([]),
    });
  });
});

When('I visit the product catalog page', async ({ page }) => {
  await page.goto('/catalog');
});

Then('I see the empty state message', async ({ page }) => {
  await expect(page.getByText('No products available')).toBeVisible();
});
```

The matching pattern accepts:
- Glob patterns: `**/api/products`, `https://example.com/api/**`
- Exact URLs: `'https://api.example.com/v2/products'`
- Regular expressions: `/\/api\/products\/\d+/`

## Feature File Example

```gherkin
Feature: Product catalog

  @mock-api
  Scenario: Empty catalog shows placeholder message
    Given the product API returns an empty catalog
    When I visit the product catalog page
    Then I see the empty state message

  @mock-api
  Scenario: API error shows friendly error page
    Given the product API returns a 503 error
    When I visit the product catalog page
    Then I see the service unavailable message

  Scenario: Live catalog loads real products
    When I visit the product catalog page
    Then I see at least one product listed
```

## Mocking Error Responses

Test how the UI handles upstream failures by returning HTTP error codes:

```ts
Given('the product API returns a 503 error', async ({ page }) => {
  await page.route('**/api/products', (route) => {
    route.fulfill({
      status: 503,
      contentType: 'application/json',
      body: JSON.stringify({ error: 'Service temporarily unavailable' }),
    });
  });
});

Given('the product API times out', async ({ page }) => {
  await page.route('**/api/products', async (route) => {
    // Abort the request — simulates a network timeout
    await route.abort('timedout');
  });
});

Given('the product API returns a malformed response', async ({ page }) => {
  await page.route('**/api/products', (route) => {
    route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: 'not valid json{{{',
    });
  });
});
```

## Route Fixtures for Reuse

When the same mock is needed across multiple step files, extract it into a fixture so it is automatically available and cleaned up:

```ts
// fixtures.ts
import { test as base, createBdd } from 'playwright-bdd';

type MockRoutes = {
  mockProductApi: (response: unknown, status?: number) => Promise<void>;
};

export const test = base.extend<MockRoutes>({
  mockProductApi: async ({ page }, use) => {
    let handler: ((r: any) => void) | null = null;

    const mock = async (response: unknown, status = 200) => {
      if (handler) await page.unroute('**/api/products', handler);
      handler = (route) => route.fulfill({
        status,
        contentType: 'application/json',
        body: JSON.stringify(response),
      });
      await page.route('**/api/products', handler);
    };

    await use(mock);

    // Teardown: remove any installed routes
    if (handler) await page.unroute('**/api/products', handler);
  },
});

export const { Given, When, Then } = createBdd(test);
```

Step definitions become concise:

```ts
import { Given } from './fixtures';

Given('the product API returns {int} products', async ({ mockProductApi }, count: number) => {
  const products = Array.from({ length: count }, (_, i) => ({
    id: i + 1,
    name: `Product ${i + 1}`,
    price: 9.99,
  }));
  await mockProductApi(products);
});

Given('the product API is unavailable', async ({ mockProductApi }) => {
  await mockProductApi({ error: 'Service unavailable' }, 503);
});
```

## Cleanup: Unrouting After a Scenario

Routes installed with `page.route()` persist for the lifetime of the page. In a scenario that installs a route, the next scenario on the same page (unusual but possible in serial mode) would inherit it. Clean up explicitly in an `After` hook or via fixture teardown:

```ts
import { createBdd } from 'playwright-bdd';
import { test } from './fixtures';

const { AfterScenario } = createBdd(test);

// If you installed routes directly in steps (no fixture), clean them up after
AfterScenario(async ({ page }) => {
  await page.unrouteAll({ behavior: 'ignoreErrors' });
});
```

When routes are managed through a fixture (as in the example above), the fixture's teardown runs automatically after each scenario — no explicit `After` hook is needed.

!!! tip
    Prefer fixtures over inline `page.route()` calls in steps. Fixture teardown is guaranteed to run even if the scenario fails mid-step, which prevents a failing scenario from leaving routes that corrupt subsequent scenarios.

## Passing Mock Data Between Steps

When one step sets up a mock and a later step needs to know what was mocked (e.g., to assert on it), use the `ctx` fixture for cross-step data sharing:

```ts
// fixtures.ts
export const test = base.extend<{ ctx: Record<string, any> }>({
  ctx: async ({}, use) => {
    await use({});
  },
});
```

```ts
Given('the search API returns {string} as the top result', async ({ page, ctx }, title: string) => {
  ctx.expectedTopResult = title;
  await page.route('**/api/search**', (route) => {
    route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({ results: [{ title }] }),
    });
  });
});

Then('the top result is shown', async ({ page, ctx }) => {
  await expect(page.getByTestId('top-result')).toHaveText(ctx.expectedTopResult);
});
```

## Testing With and Without Mocks in the Same Suite

Use tags to separate mocked and live scenarios:

```gherkin
@mock-api
Scenario: Empty state is shown when catalog is empty
  Given the product API returns an empty catalog
  When I visit the product catalog page
  Then I see the empty state message

@live-api
Scenario: Real catalog loads from production data
  When I visit the product catalog page
  Then I see at least one product listed
```

Configure the `@live-api` project to run against a real environment while `@mock-api` runs headlessly in CI without external dependencies:

```ts
export default defineConfig({
  projects: [
    {
      name: 'mocked',
      testDir: defineBddConfig({
        features: 'features/**/*.feature',
        steps: 'steps/**/*.ts',
        tags: '@mock-api',
      }),
    },
    {
      name: 'live',
      testDir: defineBddConfig({
        features: 'features/**/*.feature',
        steps: 'steps/**/*.ts',
        tags: '@live-api',
      }),
      use: { baseURL: process.env.STAGING_URL },
    },
  ],
});
```

!!! warning
    Mocked tests verify UI behavior given a specific API contract. They do not prove that the contract matches what the real API returns. Run `@live-api` scenarios against real environments in a separate CI stage to catch contract drift.

## Cross-references

- [Tags and Filtering](tags-and-filtering.md) — separating mocked and live scenarios with tags
- [Fixtures](fixtures.md) — fixture lifecycle and teardown guarantees
- [Test Isolation](test-isolation.md) — preventing route state leakage between parallel scenarios
