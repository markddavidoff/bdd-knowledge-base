---
title: Network Mocking — playwright-bdd
description: Complete playwright-bdd pattern for intercepting API calls with page.route(), building a mock fixture, and testing error response paths.
sources:
  - git-playwright-bdd-repo-docs-writing-steps-playwright-style-custom-fixtures
  - git-playwright-bdd-repo-docs-getting-started-add-fixtures-add-fixtures
---

# Network Mocking — playwright-bdd

Playwright's `page.route()` intercepts outgoing HTTP requests before they leave the browser. This lets you test UI behaviour against predictable API responses — including errors, slow responses, and edge cases that are hard to reproduce in a real API.

## When to use network mocking

| Use case | Recommended approach |
|---|---|
| Test UI loading state | Mock with a delayed response |
| Test error handling (500, 503) | Mock with error response |
| Test against third-party APIs you don't control | Mock the third-party endpoint |
| Test the API itself | Do **not** mock — use real API ([API Testing](api-testing-playwright-bdd.md)) |
| Isolate UI tests from flaky external services | Mock the service |

## Feature file

```gherkin
Feature: Payment processing UI

  Scenario: Successful payment shows confirmation
    Given the payment API returns a successful response
    When I submit a valid payment form
    Then I see the "Payment confirmed" message

  Scenario: Payment API failure shows user-friendly error
    Given the payment API returns a 503 error
    When I submit a valid payment form
    Then I see the "Service temporarily unavailable" message
    And I see a "Try again" button

  Scenario: Slow API shows loading indicator
    Given the payment API responds after a 3 second delay
    When I submit a valid payment form
    Then I see a loading spinner while the payment processes
    Then I see the "Payment confirmed" message
```

## Mock fixture

Encapsulate route setup in a fixture so any step file can reuse it without duplicating `page.route()` calls:

```typescript
// features/steps/fixtures.ts
import { test as base, createBdd } from 'playwright-bdd';

const PAYMENT_API_URL = '**/api/payments';

interface MockOptions {
  status: number;
  body: object;
  delayMs?: number;
}

type Fixtures = {
  mockPaymentApi: (options: MockOptions) => Promise<void>;
};

export const test = base.extend<Fixtures>({
  mockPaymentApi: async ({ page }, use) => {
    const routes: import('@playwright/test').Route[] = [];

    const mock = async (options: MockOptions) => {
      await page.route(PAYMENT_API_URL, async (route) => {
        routes.push(route);
        if (options.delayMs) {
          await new Promise((resolve) => setTimeout(resolve, options.delayMs));
        }
        await route.fulfill({
          status: options.status,
          contentType: 'application/json',
          body: JSON.stringify(options.body),
        });
      });
    };

    await use(mock);

    // Cleanup: remove all routes after the scenario
    await page.unrouteAll({ behavior: 'ignoreErrors' });
  },
});

export const { Given, When, Then, After } = createBdd(test);
```

## Step definitions

```typescript
// features/steps/payment.steps.ts
import { expect } from '@playwright/test';
import { Given, When, Then } from './fixtures';

// ─── Given — set up the mock ───────────────────────────────────────────────

Given(
  'the payment API returns a successful response',
  async ({ mockPaymentApi }) => {
    await mockPaymentApi({
      status: 200,
      body: { id: 'pay_abc123', status: 'succeeded', amount: 9900 },
    });
  }
);

Given('the payment API returns a 503 error', async ({ mockPaymentApi }) => {
  await mockPaymentApi({
    status: 503,
    body: { error: 'service_unavailable', message: 'Try again later' },
  });
});

Given(
  'the payment API responds after a {int} second delay',
  async ({ mockPaymentApi }, seconds: number) => {
    await mockPaymentApi({
      status: 200,
      body: { id: 'pay_delayed', status: 'succeeded', amount: 9900 },
      delayMs: seconds * 1000,
    });
  }
);

// ─── When ──────────────────────────────────────────────────────────────────

When('I submit a valid payment form', async ({ page }) => {
  await page.goto('/checkout');
  await page.getByLabel('Card number').fill('4242 4242 4242 4242');
  await page.getByLabel('Expiry').fill('12/26');
  await page.getByLabel('CVV').fill('123');
  await page.getByRole('button', { name: 'Pay Now' }).click();
});

// ─── Then ──────────────────────────────────────────────────────────────────

Then('I see the {string} message', async ({ page }, message: string) => {
  await expect(page.getByText(message)).toBeVisible();
});

Then('I see a {string} button', async ({ page }, label: string) => {
  await expect(page.getByRole('button', { name: label })).toBeVisible();
});

Then(
  'I see a loading spinner while the payment processes',
  async ({ page }) => {
    // Spinner should appear immediately after click
    await expect(page.getByRole('status', { name: 'Loading' })).toBeVisible();
  }
);
```

## Testing partial mocking (passthrough for some routes)

Sometimes you want to mock one endpoint while letting others pass through to the real server:

```typescript
Given('only the analytics API is mocked', async ({ page }) => {
  await page.route('**/api/analytics/**', (route) => {
    route.fulfill({
      status: 200,
      contentType: 'application/json',
      body: JSON.stringify({ events: [] }),
    });
  });
  // All other routes proceed normally — no route.abort() or route.fulfill()
});
```

## Inspecting request bodies in assertions

```typescript
Then(
  'the payment request includes the correct amount',
  async ({ page }) => {
    // Capture the outgoing request body before mocking it
    const [request] = await Promise.all([
      page.waitForRequest('**/api/payments'),
      page.getByRole('button', { name: 'Pay Now' }).click(),
    ]);
    const body = request.postDataJSON();
    expect(body.amount).toBe(9900);
    expect(body.currency).toBe('usd');
  }
);
```

!!! warning "Cleanup after mocking"
    Routes registered with `page.route()` persist until explicitly removed. The fixture above calls `page.unrouteAll()` in teardown. If you register routes manually in step definitions without cleanup, earlier scenarios' mocks can bleed into later scenarios.

!!! tip "playwright-network-cache for expensive third-party calls"
    For third-party APIs with rate limits or slow response times, consider [`playwright-network-cache`](../playwright-bdd/companion-libraries.md) to record real responses once and replay them in subsequent runs.

## Related

- [playwright-bdd network mocking reference](../playwright-bdd/network-mocking.md)
- [Fixtures and State](fixtures-and-state.md) — fixture teardown patterns
- [Companion Libraries](../playwright-bdd/companion-libraries.md) — playwright-network-cache
