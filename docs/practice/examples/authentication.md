---
title: Authentication — playwright-bdd
description: Complete playwright-bdd authentication pattern using storageState, a setup project for multi-role auth, and dynamic per-step login via context.setStorageState().
sources:
  - git-playwright-bdd-repo-docs-guides-authentication-authentication
  - git-playwright-bdd-repo-docs-guides-authentication-static-authentication
  - git-playwright-bdd-repo-docs-guides-authentication-dynamic-authentication-in-steps
  - git-playwright-bdd-repo-examples-auth-readme-readme
  - git-playwright-bdd-repo-examples-auth-in-steps-readme-readme
---

# Authentication — playwright-bdd

playwright-bdd supports two authentication approaches that match Playwright's own auth patterns:

1. **Static** — one shared account, authenticated once before the suite via a setup project.
2. **Dynamic** — login happens inside a BDD step (`Given I am logged in as "admin"`), allowing different roles per scenario.

## Static authentication (single account)

Use this when most tests share one user. A non-BDD "setup" project logs in once and saves `storageState` to a file. Every BDD scenario loads that state automatically.

### playwright.config.ts

```typescript
import { defineConfig } from '@playwright/test';
import { defineBddConfig } from 'playwright-bdd';

export const AUTH_FILE = 'playwright/.auth/user.json';

export default defineConfig({
  projects: [
    {
      name: 'auth',
      testDir: 'features/auth',
      testMatch: /setup\.ts/,
    },
    {
      name: 'chromium',
      testDir: defineBddConfig({
        features: 'features/**/*.feature',
        steps: 'features/steps/**/*.ts',
      }),
      use: {
        storageState: AUTH_FILE,
      },
      dependencies: ['auth'],
    },
  ],
});
```

### features/auth/setup.ts

```typescript
import { test as setup, expect } from '@playwright/test';
import { AUTH_FILE } from '../../playwright.config';

setup('authenticate', async ({ page }) => {
  await page.goto('/login');
  await page.getByLabel('Email').fill('admin@example.com');
  await page.getByLabel('Password').fill('s3cr3t');
  await page.getByRole('button', { name: 'Log In' }).click();
  await expect(page.getByRole('link', { name: 'Sign Out' })).toBeVisible();

  await page.context().storageState({ path: AUTH_FILE });
});
```

### Handling unauthenticated scenarios

Tag guest scenarios with `@noauth` and override the `storageState` fixture:

```gherkin
Feature: Login page

  @noauth
  Scenario: Guest can see the login form
    Given I am on the login page
    Then the "Log In" button is visible
```

```typescript
// features/steps/fixtures.ts
import { test as base, createBdd } from 'playwright-bdd';
import { AUTH_FILE } from '../../playwright.config';

export const test = base.extend<object>({
  storageState: async ({ $tags, storageState }, use) => {
    if ($tags.includes('@noauth')) {
      await use({ cookies: [], origins: [] });
    } else {
      await use(storageState);
    }
  },
});

export const { Given, When, Then } = createBdd(test);
```

## Dynamic authentication (multi-role)

Use this when scenarios specify which user to log in as. Since Playwright 1.59, `context.setStorageState()` lets you load auth state into the running browser context from inside a step.

### Feature file

```gherkin
Feature: Role-based access

  Scenario: Admin sees the management panel
    Given I am logged in as "admin"
    When I navigate to the dashboard
    Then I see the "User Management" panel

  Scenario: Regular user sees restricted view
    Given I am logged in as "user"
    When I navigate to the dashboard
    Then I do not see the "User Management" panel
```

### Setup project — save per-role auth files

```typescript
// features/auth/setup.ts
import { test as setup } from '@playwright/test';

const AUTH_FILE = (role: string) => `playwright/.auth/${role}.json`;

setup.describe.configure({ mode: 'parallel' });

for (const role of ['admin', 'user']) {
  setup(`authenticate ${role}`, async ({ page }) => {
    await page.goto('/login');
    await page.getByLabel('Email').fill(`${role}@example.com`);
    await page.getByLabel('Password').fill('password');
    await page.getByRole('button', { name: 'Log In' }).click();
    await page.context().storageState({ path: AUTH_FILE(role) });
  });
}
```

### Step definitions

```typescript
// features/steps/steps.ts
import { expect } from '@playwright/test';
import { createBdd } from 'playwright-bdd';

const { Given, When, Then } = createBdd();

Given('I am logged in as {string}', async ({ context }, role: string) => {
  // context.setStorageState() available since Playwright 1.59
  await (context as any).setStorageState(
    `playwright/.auth/${role}.json`
  );
});

When('I navigate to the dashboard', async ({ page }) => {
  await page.goto('/dashboard');
});

Then('I see the {string} panel', async ({ page }, panelName: string) => {
  await expect(page.getByRole('region', { name: panelName })).toBeVisible();
});

Then('I do not see the {string} panel', async ({ page }, panelName: string) => {
  await expect(page.getByRole('region', { name: panelName })).toBeHidden();
});
```

!!! warning "Playwright version requirement"
    `context.setStorageState()` requires Playwright >= 1.59. For older versions, create a new `BrowserContext` with the desired `storageState` and expose the resulting `page` via a custom fixture.

## Which approach to choose

| Situation | Approach |
|---|---|
| All scenarios use one account | Static (`storageState` in config) |
| Scenarios test different roles | Dynamic (`context.setStorageState()` in step) |
| Some scenarios need no auth | Static + `@noauth` fixture override |
| Admin and user interact simultaneously | [Multi-Actor pattern](multi-actor.md) |

## Related

- [Multi-Actor Scenarios](multi-actor.md) — two browser contexts in one scenario
- [Auth Patterns reference](../playwright-bdd/auth-patterns.md) — deeper discussion of tradeoffs
- [Fixtures and State](fixtures-and-state.md) — worker-scoped fixture alternatives
