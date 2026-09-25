---
title: Multi-Actor Scenarios — playwright-bdd
description: Complete playwright-bdd pattern for scenarios involving two simultaneous browser contexts (e.g., admin and customer), with actor fixtures and shared state coordination.
sources:
  - git-playwright-bdd-repo-docs-writing-steps-playwright-style-custom-fixtures
  - git-playwright-bdd-repo-docs-guides-authentication-authentication
  - git-gherkin-best-practices-repo-readme-define-the-actor-that-will-use-the-system
---

# Multi-Actor Scenarios — playwright-bdd

Some behaviors only emerge when two users interact simultaneously — an admin approves a request while the customer is waiting, or a seller posts an item while the buyer is browsing. Multi-actor scenarios run two independent `BrowserContext` instances in the same test, each carrying its own auth state and page.

## When to use multi-actor scenarios

Use multi-actor scenarios only when the behavior under test genuinely requires simultaneous actors. They are slower to write and maintain than single-actor scenarios. If you can test the same behavior by running two separate single-actor scenarios in sequence (setup state via API, then assert), do that instead.

Good candidates:
- Real-time features: notifications, live updates, collaborative editing
- Approval workflows: actor A submits, actor B approves, actor A sees the result
- Permission verification: admin grants access, user immediately can access

## Feature file

```gherkin
Feature: Approval workflow

  Scenario: Admin approves a pending request and customer sees the update
    Given a customer "alice@example.com" has submitted a refund request for order "ORD-9001"
    And an admin is reviewing the pending requests
    When the admin approves the refund for "ORD-9001"
    Then the customer sees the refund status as "Approved"
    And the customer receives a notification

  Scenario: Admin revokes access and user is immediately logged out
    Given a user "bob@example.com" is signed in to the dashboard
    And an admin is on the user management page
    When the admin revokes access for "bob@example.com"
    Then the user's session is terminated
    And the user sees the "Your access has been revoked" message
```

## Actor fixtures

Each actor gets their own `BrowserContext` and `Page`. The fixture creates these from the base `browser` fixture (not from `page`, which is already bound to the default context):

```typescript
// features/steps/fixtures.ts
import { test as base, createBdd } from 'playwright-bdd';
import type { BrowserContext, Page } from '@playwright/test';

interface Actor {
  context: BrowserContext;
  page: Page;
}

type Fixtures = {
  adminActor: Actor;
  customerActor: Actor;
  // Shared state between actors — passed by reference
  sharedState: {
    targetOrderId: string | null;
    targetUserId: string | null;
  };
};

export const test = base.extend<Fixtures>({
  sharedState: async ({}, use) => {
    await use({ targetOrderId: null, targetUserId: null });
  },

  adminActor: async ({ browser }, use) => {
    // Load admin's saved auth state
    const context = await browser.newContext({
      storageState: 'playwright/.auth/admin.json',
    });
    const page = await context.newPage();

    await use({ context, page });

    // Teardown
    await page.close();
    await context.close();
  },

  customerActor: async ({ browser }, use) => {
    // Customer context starts unauthenticated — login happens in a Given step
    const context = await browser.newContext();
    const page = await context.newPage();

    await use({ context, page });

    await page.close();
    await context.close();
  },
});

export const { Given, When, Then } = createBdd(test);
```

## Step definitions

```typescript
// features/steps/approval-workflow.steps.ts
import { expect } from '@playwright/test';
import { Given, When, Then } from './fixtures';

// ─── Given — set initial state for each actor ──────────────────────────────

Given(
  'a customer {string} has submitted a refund request for order {string}',
  async ({ customerActor, request, sharedState }, email: string, orderId: string) => {
    // Customer logs in
    await customerActor.page.goto('/login');
    await customerActor.page.getByLabel('Email').fill(email);
    await customerActor.page.getByLabel('Password').fill('customer-password');
    await customerActor.page.getByRole('button', { name: 'Log In' }).click();

    // Customer submits refund
    await customerActor.page.goto(`/orders/${orderId}`);
    await customerActor.page.getByRole('button', { name: 'Request refund' }).click();
    await customerActor.page.getByRole('button', { name: 'Submit' }).click();

    sharedState.targetOrderId = orderId;

    // Leave customer page on the order detail page — they'll poll for status
    await customerActor.page.goto(`/orders/${orderId}`);
  }
);

Given('an admin is reviewing the pending requests', async ({ adminActor }) => {
  await adminActor.page.goto('/admin/refunds?status=pending');
  await expect(adminActor.page.getByRole('heading', { name: 'Pending Refunds' })).toBeVisible();
});

Given(
  'a user {string} is signed in to the dashboard',
  async ({ customerActor }, email: string) => {
    await customerActor.page.goto('/login');
    await customerActor.page.getByLabel('Email').fill(email);
    await customerActor.page.getByLabel('Password').fill('user-password');
    await customerActor.page.getByRole('button', { name: 'Log In' }).click();
    await customerActor.page.goto('/dashboard');
    await expect(customerActor.page.getByRole('heading', { name: 'Dashboard' })).toBeVisible();
  }
);

Given(
  'an admin is on the user management page',
  async ({ adminActor }) => {
    await adminActor.page.goto('/admin/users');
  }
);

// ─── When — actor performs action ──────────────────────────────────────────

When(
  'the admin approves the refund for {string}',
  async ({ adminActor, sharedState }, orderId: string) => {
    const row = adminActor.page.getByRole('row', { name: orderId });
    await row.getByRole('button', { name: 'Approve' }).click();
    await adminActor.page.getByRole('button', { name: 'Confirm approval' }).click();
    await expect(adminActor.page.getByText('Refund approved')).toBeVisible();
  }
);

When(
  'the admin revokes access for {string}',
  async ({ adminActor }, email: string) => {
    const row = adminActor.page.getByRole('row', { name: email });
    await row.getByRole('button', { name: 'Revoke access' }).click();
    await adminActor.page.getByRole('button', { name: 'Yes, revoke' }).click();
  }
);

// ─── Then — assert from the customer's perspective ─────────────────────────

Then(
  'the customer sees the refund status as {string}',
  async ({ customerActor, sharedState }, expectedStatus: string) => {
    // Reload to pick up server-pushed state
    await customerActor.page.reload();
    await expect(
      customerActor.page.getByRole('status', { name: 'Refund status' })
    ).toHaveText(expectedStatus);
  }
);

Then('the customer receives a notification', async ({ customerActor }) => {
  await expect(
    customerActor.page.getByRole('alert', { name: 'Refund approved' })
  ).toBeVisible({ timeout: 10_000 }); // allow for async notification delivery
});

Then("the user's session is terminated", async ({ customerActor }) => {
  // Trigger a navigation to detect the forced logout
  await customerActor.page.reload();
  await expect(customerActor.page).toHaveURL(/\/login/);
});

Then(
  'the user sees the {string} message',
  async ({ customerActor }, message: string) => {
    await expect(customerActor.page.getByText(message)).toBeVisible();
  }
);
```

## Coordinating state between actors

The `sharedState` fixture is a plain object passed by reference to both actor steps. It acts as a lightweight message bus:

- One step writes to it (`sharedState.targetOrderId = orderId`)
- A later step reads from it (`When the admin approves the refund for orderId`)

This avoids module-level variables (which leak across scenarios) and avoids passing data through step parameters (which would couple step ordering).

!!! warning "Shared state must not persist between scenarios"
    The `sharedState` fixture has test scope (`scope: 'test'` by default), so it is recreated for each scenario. Never use a module-level variable for actor coordination — it will cause flakiness when tests run in parallel.

!!! tip "Keep actor contexts independent"
    Each actor's `context` is fully isolated at the browser level. Cookies, localStorage, and service worker registrations do not bleed between contexts. This makes multi-actor scenarios as isolation-safe as running two separate browser sessions.

## Related

- [Authentication](authentication.md) — pre-saved `storageState` per role
- [Fixtures and State](fixtures-and-state.md) — fixture dependency injection and scope
- [Gherkin multi-actor examples](../../gherkin/examples/multi-actor.md) — feature file only
