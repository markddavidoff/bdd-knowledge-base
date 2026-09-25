---
title: Fixtures and State — playwright-bdd
description: Complete patterns for worker-scoped fixtures, lazy initialization, fixture dependency injection, and sharing fixture state across multiple step definition files in playwright-bdd.
sources:
  - git-playwright-bdd-repo-docs-writing-steps-playwright-style-custom-fixtures
  - git-playwright-bdd-repo-docs-getting-started-add-fixtures-add-fixtures
  - git-playwright-bdd-repo-docs-writing-steps-hooks-fixtures-fixtures
---

# Fixtures and State — playwright-bdd

Playwright fixtures are the correct mechanism for managing test state in playwright-bdd. They replace Before/After hooks for most use cases and are strictly superior for resource management: they run only when needed, are typed, and compose cleanly.

## Fixture scopes

| Scope | Lifetime | Use for |
|---|---|---|
| `'test'` (default) | One scenario | Per-scenario state, page objects, API clients |
| `'worker'` | One worker process (many scenarios) | Expensive DB seeding, auth setup, test org creation |

## Basic test-scoped fixture

```typescript
// features/steps/fixtures.ts
import { test as base, createBdd } from 'playwright-bdd';
import { ApiClient } from '../../support/api-client';
import { SettingsPage } from '../../support/pages/settings-page';

type Fixtures = {
  api: ApiClient;
  settingsPage: SettingsPage;
};

export const test = base.extend<Fixtures>({
  // api: created fresh for each scenario, torn down after
  api: async ({ request }, use) => {
    await use(new ApiClient(request));
  },

  // settingsPage: depends on api fixture via dependency injection
  settingsPage: async ({ page, api }, use) => {
    await use(new SettingsPage(page, api));
  },
});

export const { Given, When, Then } = createBdd(test);
```

Fixtures declared inside `extend` receive other fixtures as their first argument. Playwright resolves the dependency graph automatically — `settingsPage` will always receive an initialized `api`.

## Worker-scoped fixture for expensive setup

```typescript
// features/steps/fixtures.ts
import { test as base, createBdd } from 'playwright-bdd';
import { ApiClient } from '../../support/api-client';

interface SeedOrg {
  id: string;
  name: string;
  plan: 'pro';
  adminEmail: string;
}

type TestFixtures = {
  api: ApiClient;
};

type WorkerFixtures = {
  seedOrg: SeedOrg;
};

export const test = base.extend<TestFixtures, WorkerFixtures>({
  // test-scoped
  api: async ({ request }, use) => {
    await use(new ApiClient(request));
  },

  // worker-scoped: runs ONCE per worker, shared across all scenarios in that worker
  seedOrg: [
    async ({ request }, use) => {
      const api = new ApiClient(request);

      // Setup: create the org once
      const org = await api.createOrg({
        name: 'Seed Org',
        plan: 'pro',
        adminEmail: 'seed-admin@example.com',
      });

      console.log(`[worker] seeded org ${org.id}`);

      await use({
        id: org.id,
        name: org.name,
        plan: 'pro',
        adminEmail: 'seed-admin@example.com',
      });

      // Teardown: runs once after the worker finishes all scenarios
      console.log(`[worker] cleaning up org ${org.id}`);
      await api.deleteOrg(org.id);
    },
    { scope: 'worker' },
  ],
});

export const { Given, When, Then } = createBdd(test);
```

!!! warning "Worker fixtures cannot access page or browser"
    `scope: 'worker'` fixtures run outside the browser context. You have access to `request` (an `APIRequestContext`) but not to `page`, `browser`, or `context`. Use worker fixtures for API-based seeding only.

## Lazy initialization pattern

Sometimes a fixture is expensive to create and not every scenario needs it. Use lazy initialization to defer creation until the first access:

```typescript
// features/steps/fixtures.ts
import { test as base, createBdd } from 'playwright-bdd';

interface LazyOrg {
  id: string | null;
  getOrCreate: (api: ApiClient) => Promise<string>;
}

export const test = base.extend<{ lazyOrg: LazyOrg }>({
  lazyOrg: async ({}, use) => {
    let orgId: string | null = null;

    await use({
      id: null,
      async getOrCreate(api) {
        if (!orgId) {
          const org = await api.createOrg({ name: 'Lazy Org', plan: 'free' });
          orgId = org.id;
        }
        return orgId!;
      },
    });

    // Teardown: only runs cleanup if the org was actually created
    // (orgId is captured via closure)
    if (orgId) {
      // Can't call api here — use a global request context or skip
    }
  },
});
```

## Sharing fixture state across step files

When your project splits steps across multiple files (one per domain area), all files must import `Given`, `When`, `Then` from the same `fixtures.ts`. Never import directly from `playwright-bdd` in step files:

```
features/
├── steps/
│   ├── fixtures.ts          # <-- single source of truth
│   ├── auth.steps.ts        # imports from ./fixtures
│   ├── profile.steps.ts     # imports from ./fixtures
│   └── billing.steps.ts     # imports from ./fixtures
```

```typescript
// features/steps/auth.steps.ts
import { Given } from './fixtures';  // NOT from 'playwright-bdd'

Given('I am signed in as {string}', async ({ page }, email: string) => {
  // ...
});
```

```typescript
// features/steps/billing.steps.ts
import { When, Then } from './fixtures';  // NOT from 'playwright-bdd'
import type { ApiClient } from '../../support/api-client';

When('I upgrade to the pro plan', async ({ api, page }) => {
  // Both api (from fixtures.ts) and page (built-in) are available
  await api.upgradePlan('pro');
  await page.reload();
});
```

This works because `createBdd(test)` in `fixtures.ts` binds `Given`, `When`, `Then` to your extended `test` instance. All step files that import from `fixtures.ts` share the same fixture definitions.

## Fixture dependency injection chain

```typescript
// Dependency chain: request → apiClient → currentUser → profilePage
export const test = base.extend<{
  apiClient: ApiClient;
  currentUser: UserRecord;
  profilePage: ProfilePage;
}>({
  apiClient: async ({ request }, use) => {
    await use(new ApiClient(request));
  },

  currentUser: async ({ apiClient }, use) => {
    const user = await apiClient.getCurrentUser();
    await use(user);
  },

  profilePage: async ({ page, currentUser }, use) => {
    const pg = new ProfilePage(page, currentUser.id);
    await pg.goto();
    await use(pg);
  },
});
```

Playwright resolves this chain automatically. If a scenario only uses `currentUser`, `apiClient` is created and torn down without `profilePage` ever being instantiated.

## Before/After hooks vs. fixture teardown

Both achieve lifecycle management. Prefer fixtures for new code:

```typescript
// Hook style — works but couples to step file load order
Before('@needs-org', async ({ api }) => {
  // ...
});

After('@needs-org', async ({ api }) => {
  // ...
});

// Fixture style — preferred
export const test = base.extend({
  orgFixture: async ({ api }, use) => {
    const org = await api.createOrg(/* ... */);
    await use(org);
    await api.deleteOrg(org.id);  // guaranteed cleanup
  },
});
```

Fixture teardown (code after `await use(...)`) is guaranteed to run even if the scenario throws, which makes it more reliable than `After` hooks for cleanup.

## Related

- [CRUD Operations](crud-operations.md) — worker fixture for DB seeding in action
- [playwright-bdd Fixtures reference](../playwright-bdd/fixtures.md)
- [Test Isolation](../playwright-bdd/test-isolation.md) — strategies for parallel isolation
