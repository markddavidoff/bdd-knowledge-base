---
title: CRUD Operations — playwright-bdd
description: Complete playwright-bdd pattern for create/read/update/delete flows using API-seeded test data, worker fixtures for expensive DB setup, and After hook cleanup.
sources:
  - git-playwright-bdd-repo-docs-writing-steps-playwright-style-custom-fixtures
  - git-playwright-bdd-repo-docs-getting-started-add-fixtures-add-fixtures
  - git-playwright-bdd-repo-docs-writing-steps-hooks-fixtures-fixtures
---

# CRUD Operations — playwright-bdd

Testing create/read/update/delete flows requires reliable test data. The recommended approach: seed data via your application's API (not the UI, not direct DB calls) and clean up in `After` hooks or fixture teardown.

## Feature file

```gherkin
Feature: User management

  Background:
    Given I am logged in as an admin

  Scenario: Create a new user
    When I create a user with email "newuser@example.com" and role "editor"
    Then the user "newuser@example.com" appears in the user list
    And the user "newuser@example.com" has the role "editor"

  Scenario: Update a user's role
    Given a user "target@example.com" exists with role "viewer"
    When I change the role of "target@example.com" to "editor"
    Then the user "target@example.com" has the role "editor"

  Scenario: Delete a user
    Given a user "todelete@example.com" exists with role "viewer"
    When I delete the user "todelete@example.com"
    Then the user "todelete@example.com" does not appear in the user list
```

## API client helper

```typescript
// support/api-client.ts
import type { APIRequestContext } from '@playwright/test';

export interface UserRecord {
  id: string;
  email: string;
  role: string;
}

export class ApiClient {
  constructor(private request: APIRequestContext) {}

  async createUser(email: string, role: string): Promise<UserRecord> {
    const res = await this.request.post('/api/users', {
      data: { email, role },
    });
    expect(res.ok()).toBeTruthy();
    return res.json() as Promise<UserRecord>;
  }

  async deleteUser(id: string): Promise<void> {
    await this.request.delete(`/api/users/${id}`);
  }

  async listUsers(): Promise<UserRecord[]> {
    const res = await this.request.get('/api/users');
    return res.json() as Promise<UserRecord[]>;
  }

  async updateUser(id: string, patch: Partial<UserRecord>): Promise<UserRecord> {
    const res = await this.request.patch(`/api/users/${id}`, {
      data: patch,
    });
    return res.json() as Promise<UserRecord>;
  }
}
```

## fixtures.ts — extending test with API client and state tracking

```typescript
// features/steps/fixtures.ts
import { test as base, createBdd } from 'playwright-bdd';
import { expect } from '@playwright/test';
import { ApiClient, type UserRecord } from '../../support/api-client';

type Fixtures = {
  api: ApiClient;
  createdUsers: UserRecord[];
};

export const test = base.extend<Fixtures>({
  api: async ({ request }, use) => {
    await use(new ApiClient(request));
  },

  // Tracks users created during a scenario so the After hook can clean them up.
  createdUsers: async ({}, use) => {
    const users: UserRecord[] = [];
    await use(users);
    // teardown: delete every user created in this scenario
    // (After hooks run automatically; fixture teardown runs after them)
  },
});

export const { Given, When, Then, Before, After } = createBdd(test);
```

## Step definitions

```typescript
// features/steps/steps.ts
import { expect } from '@playwright/test';
import { Given, When, Then, Before, After } from './fixtures';

// Track users created in this scenario for cleanup
const created: string[] = [];

After(async ({ api }) => {
  for (const id of created.splice(0)) {
    await api.deleteUser(id).catch(() => {
      // ignore 404 if already deleted by the scenario
    });
  }
});

// ---- Given steps ----

Given('I am logged in as an admin', async ({ page }) => {
  await page.goto('/login');
  await page.getByLabel('Email').fill('admin@example.com');
  await page.getByLabel('Password').fill('admin-password');
  await page.getByRole('button', { name: 'Log In' }).click();
  await expect(page.getByRole('navigation')).toBeVisible();
});

Given(
  'a user {string} exists with role {string}',
  async ({ api }, email: string, role: string) => {
    const user = await api.createUser(email, role);
    created.push(user.id);
  }
);

// ---- When steps ----

When(
  'I create a user with email {string} and role {string}',
  async ({ page, api }, email: string, role: string) => {
    await page.goto('/admin/users/new');
    await page.getByLabel('Email').fill(email);
    await page.getByLabel('Role').selectOption(role);
    await page.getByRole('button', { name: 'Create User' }).click();
    // Track for cleanup — read the new ID from the URL or API response
    const users = await api.listUsers();
    const created_user = users.find((u) => u.email === email);
    if (created_user) created.push(created_user.id);
  }
);

When(
  'I change the role of {string} to {string}',
  async ({ page }, email: string, newRole: string) => {
    await page.goto('/admin/users');
    await page.getByRole('row', { name: email }).getByRole('link', { name: 'Edit' }).click();
    await page.getByLabel('Role').selectOption(newRole);
    await page.getByRole('button', { name: 'Save' }).click();
  }
);

When('I delete the user {string}', async ({ page }, email: string) => {
  await page.goto('/admin/users');
  await page
    .getByRole('row', { name: email })
    .getByRole('button', { name: 'Delete' })
    .click();
  await page.getByRole('button', { name: 'Confirm' }).click();
});

// ---- Then steps ----

Then(
  'the user {string} appears in the user list',
  async ({ page }, email: string) => {
    await page.goto('/admin/users');
    await expect(page.getByRole('cell', { name: email })).toBeVisible();
  }
);

Then(
  'the user {string} has the role {string}',
  async ({ page }, email: string, role: string) => {
    await page.goto('/admin/users');
    const row = page.getByRole('row', { name: email });
    await expect(row.getByRole('cell', { name: role })).toBeVisible();
  }
);

Then(
  'the user {string} does not appear in the user list',
  async ({ page }, email: string) => {
    await page.goto('/admin/users');
    await expect(page.getByRole('cell', { name: email })).toBeHidden();
  }
);
```

## Worker fixture for expensive DB seeding

When seed data is expensive to create (e.g. a full organization with subscriptions), use a `worker`-scoped fixture so it runs once per worker rather than once per scenario:

```typescript
// features/steps/fixtures.ts
import { test as base, createBdd } from 'playwright-bdd';
import { ApiClient } from '../../support/api-client';

type WorkerFixtures = {
  seedOrg: { id: string; name: string };
};

export const test = base.extend<object, WorkerFixtures>({
  // scope: 'worker' — runs once per Playwright worker process
  seedOrg: [
    async ({ request }, use) => {
      const api = new ApiClient(request);
      const org = await api.createOrg({ name: 'Test Org', plan: 'pro' });

      await use(org);

      // teardown: runs once after the worker finishes all its scenarios
      await api.deleteOrg(org.id);
    },
    { scope: 'worker' },
  ],
});

export const { Given, When, Then } = createBdd(test);
```

!!! tip "API setup, never UI setup"
    Always seed test data through your API or a dedicated seeding endpoint. UI-driven setup is slow, brittle, and couples your test scaffolding to the UI under test. API seeding is an order of magnitude faster and does not add scenarios to your failure surface.

!!! warning "After hook cleanup vs. fixture teardown"
    `After` hooks run after each scenario. Fixture teardown (code after `await use(...)`) runs in the same order but is slightly more reliable for resource cleanup because Playwright guarantees it runs even if the scenario throws. Prefer fixture teardown for resource management; use `After` when you need access to step-level state.

## Related

- [Fixtures and State](fixtures-and-state.md) — deep dive on worker vs. test scope, lazy init
- [API Testing — playwright-bdd](api-testing-playwright-bdd.md) — browser-free API testing
- [Test data strategy](../../gherkin/best-practices/scenario-structure.md)
