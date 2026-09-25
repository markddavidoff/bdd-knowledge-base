---
title: Authentication Patterns
description: Static and dynamic authentication strategies for playwright-bdd using storageState, setup projects, and role-scoped fixtures.
sources:
  - git-playwright-bdd-repo-docs-guides-authentication-authentication
  - git-playwright-bdd-repo-docs-guides-authentication-static-authentication
  - git-playwright-bdd-repo-docs-guides-authentication-dynamic-authentication-in-steps
  - git-playwright-bdd-repo-examples-auth-readme-readme
  - git-playwright-bdd-repo-docs-writing-steps-hooks-fixtures-fixtures
---

# Authentication Patterns

playwright-bdd supports two authentication strategies, matching the two main patterns in Playwright's auth documentation:

1. **Static** — a single shared account authenticated once before the test run via a setup project
2. **Dynamic** — authentication happens inside BDD steps, e.g. `Given I am logged in as "admin"`

Choose static when most scenarios share the same user. Choose dynamic when scenarios need to authenticate as different roles within the same suite.

## Static Authentication: Setup Project Pattern

The setup project pattern runs authentication once, saves the browser session to disk, and reuses it for all BDD scenarios.

### Configuration

Create a separate non-BDD project that runs `setup.ts` before the BDD project runs:

```ts
// playwright.config.ts
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
        storageState: AUTH_FILE,  // load saved auth state for all scenarios
      },
      dependencies: ['auth'],     // run setup project first
    },
  ],
});
```

### Setup File

The setup file performs the login once and persists the session to `AUTH_FILE`:

```ts
// features/auth/setup.ts
import { test as setup, expect } from '@playwright/test';
import { AUTH_FILE } from '../../playwright.config';

setup('authenticate', async ({ page }) => {
  await page.goto('https://example.com/login');
  await page.getByLabel('Email').fill('user@example.com');
  await page.getByLabel('Password').fill('password');
  await page.getByRole('button', { name: 'Log In' }).click();
  await expect(page.getByRole('link', { name: 'Sign Out' })).toBeVisible();

  await page.context().storageState({ path: AUTH_FILE });
});
```

### Handling Unauthenticated Scenarios

Tag scenarios that must run without auth, then override the `storageState` fixture to clear it when the tag is present:

```gherkin
@noauth
Scenario: Login page is accessible to guests
  Given I am on the login page
  Then I see the "Log In" button
```

```ts
// features/steps/fixtures.ts
import { test as base, createBdd } from 'playwright-bdd';

export const test = base.extend({
  storageState: async ({ $tags, storageState }, use) => {
    if ($tags.includes('@noauth')) {
      storageState = { cookies: [], origins: [] };
    }
    await use(storageState);
  },
});

export const { Given, When, Then } = createBdd(test);
```

## Dynamic Authentication: Role-Based in Steps

Use this approach when different scenarios must authenticate as different users specified by step parameters.

```gherkin
Scenario: Admin sees the full dashboard
  Given I am logged in as "admin"
  When I navigate to the dashboard
  Then I see the admin panel

Scenario: Regular user sees limited menu
  Given I am logged in as "user1"
  When I navigate to the dashboard
  Then I do not see the admin panel
```

### Multi-Role Setup Project

Save a separate auth file per user role:

```ts
// features/auth/setup.ts
import { test as setup } from '@playwright/test';

export const AUTH_FILE = 'playwright/.auth/{user}.json';

setup.describe.configure({ mode: 'parallel' });

setup('authenticate admin', async ({ page }) => {
  await authenticate(page, 'admin');
});

setup('authenticate user1', async ({ page }) => {
  await authenticate(page, 'user1');
});

async function authenticate(page, userName: string) {
  await page.goto('https://example.com/login');
  await page.getByLabel('Email').fill(`${userName}@example.com`);
  await page.getByLabel('Password').fill('password');
  await page.getByRole('button', { name: 'Log In' }).click();
  await page.context().storageState({ path: AUTH_FILE.replace('{user}', userName) });
}
```

### Loading Auth in the Step Definition

Since Playwright 1.59, `context.setStorageState()` loads auth into the existing browser context mid-test. Use this in the login step:

```ts
// features/steps/auth.steps.ts
import { createBdd } from 'playwright-bdd';
import { test } from '@playwright/test';
import { AUTH_FILE } from '../../playwright.config';

const { Given } = createBdd(test);

Given('I am logged in as {string}', async ({ context }, userName: string) => {
  const storageStatePath = AUTH_FILE.replace('{user}', userName);
  await context.setStorageState({ path: storageStatePath });
  // All pages opened from this context are now authenticated as userName
});
```

!!! note
    `context.setStorageState()` is available from Playwright 1.59+. For older versions, create a new `BrowserContext` manually with the desired `storageState` and pass the resulting page through a custom fixture.

## Auth via Fixtures (Recommended Pattern)

For most suites, expressing auth as a fixture produces cleaner, more composable code than managing it in step definitions directly. The fixture handles sign-in before the test and sign-out after:

```ts
// fixtures.ts
import { test as base, createBdd } from 'playwright-bdd';

type AuthUser = { username: string; role: string };

export const test = base.extend<{ auth: AuthUser }>({
  auth: async ({ page }, use) => {
    await page.goto('https://example.com/login');
    await page.getByLabel('Email').fill('user@example.com');
    await page.getByLabel('Password').fill('password');
    await page.getByRole('button', { name: 'Log In' }).click();

    await use({ username: 'user@example.com', role: 'user' });

    // teardown: sign out
    await page.getByRole('link', { name: 'Sign Out' }).click();
  },
});

export const { Given, When, Then } = createBdd(test);
```

```ts
// steps.ts
import { Given } from './fixtures';

Given('I am an authorized user', async ({ auth }) => {
  // The auth fixture already completed sign-in.
  // This step just confirms we have the context.
  console.log('logged in as', auth.username);
});
```

Playwright executes fixture setup before the first step that requests `auth`, and teardown after the scenario finishes — no `Before`/`After` hooks needed.

## Session Management: Caching Auth Across Workers

In fully parallel or sharded runs, re-authenticating per worker is expensive. Use `@global-cache/playwright` to cache the auth state and reuse it across workers:

```ts
import { test as base, createBdd } from 'playwright-bdd';
import { globalCache } from '@global-cache/playwright';

export const test = base.extend({
  storageState: async ({ storageState, browser }, use, testInfo) => {
    if (testInfo.tags.includes('@noauth')) return use(storageState);

    const authState = await globalCache.get('auth-state', { ttl: '1 hour' }, async () => {
      const loginPage = await browser.newPage();
      await loginPage.goto('https://example.com/login');
      // ... complete login
      return loginPage.context().storageState();
    });

    await use(authState);
  },
});
```

!!! tip
    Prefer fixtures over `Before` hooks for auth. A fixture is only instantiated when a step actually requests it — no tag-based `{ tags: '@auth' }` guards needed. Fixtures also compose cleanly when you need multiple auth states in one test.

!!! warning
    Never store credentials in feature files or step parameters. Auth credentials belong in environment variables or secrets management, loaded via `process.env` in the setup project or fixture.

## Cross-references

- [Fixtures](fixtures.md) — fixture scoping, worker fixtures, and dependency injection
- [Test Isolation](test-isolation.md) — managing auth state safely in parallel runs
- [Tags and Filtering](tags-and-filtering.md) — using @noauth and similar lifecycle tags
