---
title: Fixtures
description: Built-in Playwright fixtures, extending with custom fixtures, fixture scope (test/worker), and sharing fixture state across step files in playwright-bdd.
sources:
  - git-playwright-bdd-repo-docs-getting-started-add-fixtures-add-fixtures
  - git-playwright-bdd-repo-docs-writing-steps-hooks-fixtures-fixtures
  - git-playwright-bdd-repo-docs-writing-steps-bdd-fixtures-bdd-fixtures
  - git-playwright-bdd-repo-docs-writing-steps-bdd-fixtures-step
  - git-playwright-bdd-repo-docs-writing-steps-bdd-fixtures-tags
---

# Fixtures

Fixtures are the primary mechanism for dependency injection in playwright-bdd. They replace hooks (`Before`/`After`) for most setup and teardown tasks, and they are the correct way to share state between step definitions.

---

## Built-In Playwright Fixtures

playwright-bdd step definitions have access to all built-in Playwright fixtures out of the box:

| Fixture | Type | Description |
|---------|------|-------------|
| `page` | `Page` | A new browser page, scoped to the test |
| `browser` | `Browser` | The browser instance (shared across tests in the same worker) |
| `context` | `BrowserContext` | A new browser context per test |
| `request` | `APIRequestContext` | For API testing without a browser page |

```ts
import { createBdd } from 'playwright-bdd';

const { Given, When, Then } = createBdd();

// page fixture — available automatically
Given('I navigate to {string}', async ({ page }, url: string) => {
  await page.goto(url);
});

// request fixture — for pure API steps
Given('the user exists via API', async ({ request }) => {
  await request.post('/api/users', {
    data: { name: 'Alice', role: 'admin' }
  });
});
```

---

## playwright-bdd Built-In BDD Fixtures

playwright-bdd adds its own set of fixtures, all prefixed with `$` to avoid naming collisions:

| Fixture | Type | Description |
|---------|------|-------------|
| `$test` | `TestType` | The current Playwright test instance |
| `$testInfo` | `TestInfo` | Test metadata, title, status, retry count |
| `$tags` | `string[]` | Tags applied to the current scenario |
| `$step` | `BddStepInfo` | Current step title and error state |

```ts
// Accessing tags to skip based on environment
Given('I am logged in', async ({ page, $tags }) => {
  if ($tags.includes('@mock')) {
    // skip actual login in mock mode
    return;
  }
  await page.goto('/login');
  // ... perform login
});

// Accessing step title for conditional logic
Then('element {string} should( not) be visible', async ({ page, $step }, selector: string) => {
  const negate = /should not/.test($step.title);
  const locator = page.locator(selector);
  if (negate) {
    await expect(locator).toBeHidden();
  } else {
    await expect(locator).toBeVisible();
  }
});
```

---

## Extending with Custom Fixtures

When built-in fixtures are not enough, extend the base `test` with `test.extend<T>()`. The type parameter `T` declares the shape of your custom fixtures.

### Recommended Setup

Define your custom fixtures in a central `fixtures.ts` file. Export both the extended `test` instance and the `Given/When/Then` registrars. Step files import from this file, not from `playwright-bdd` directly.

```ts
// fixtures.ts
import { test as base, createBdd } from 'playwright-bdd';
import { DatabaseClient } from './support/database.js';
import { ApiClient } from './support/api-client.js';

interface MyFixtures {
  db: DatabaseClient;
  apiClient: ApiClient;
  authenticatedPage: Page;
}

export const test = base.extend<MyFixtures>({
  db: async ({}, use) => {
    const db = await DatabaseClient.connect(process.env.DATABASE_URL!);
    await use(db);
    await db.disconnect();
  },

  apiClient: async ({ request }, use) => {
    // apiClient depends on the built-in 'request' fixture
    const client = new ApiClient(request);
    await use(client);
  },

  authenticatedPage: async ({ page }, use) => {
    await page.goto('/login');
    await page.fill('[name=email]', 'test@example.com');
    await page.fill('[name=password]', 'secret');
    await page.click('[type=submit]');
    await page.waitForURL('/dashboard');
    await use(page);
  },
});

export const { Given, When, Then } = createBdd(test);
```

```ts
// steps/user.steps.ts
import { Given, When, Then } from '../fixtures.js';

Given('a user exists in the database', async ({ db }) => {
  await db.users.create({ name: 'Alice', email: 'alice@example.com' });
});

Given('I am authenticated', async ({ authenticatedPage: page }) => {
  // page is already logged in — the fixture handled it
  await expect(page).toHaveURL('/dashboard');
});
```

---

## Fixture Scope

Every fixture has a scope that determines its lifecycle:

### Test Scope (default)

A new fixture instance is created for each test (scenario). This is the correct scope for anything that holds per-scenario state.

```ts
export const test = base.extend<{ cart: ShoppingCart }>({
  cart: async ({}, use) => {
    // created fresh for every scenario
    const cart = new ShoppingCart();
    await use(cart);
    cart.clear();
  },
});
```

### Worker Scope

A worker-scoped fixture is initialized **once per Playwright worker process** and shared across all tests that run in that worker. This is the correct scope for expensive one-time operations like database seeding.

```ts
import { test as base } from 'playwright-bdd';

interface WorkerFixtures {
  seedDatabase: void;
}

export const test = base.extend<{}, WorkerFixtures>({
  seedDatabase: [
    async ({}, use) => {
      // runs once per worker — not once per scenario
      await seedTestDatabase();
      await use();
      await clearTestDatabase();
    },
    { scope: 'worker' }
  ],
});
```

!!! warning "Worker-scoped fixtures and scenario isolation"
    Because worker-scoped fixtures are shared, scenarios that depend on them must treat the seeded data as read-only. Mutations in one scenario will affect subsequent scenarios in the same worker. Use test-scoped fixtures for any state that changes during a scenario.

### Project Scope

Project-scoped fixtures are initialized once per Playwright project configuration (e.g., once for Chromium, once for Firefox). Rarely needed in BDD setups.

---

## Fixture Dependency Injection

Fixtures can depend on other fixtures. Playwright resolves the dependency graph automatically:

```ts
export const test = base.extend<{
  authToken: string;
  apiClient: AuthenticatedApiClient;
}>({
  authToken: async ({ request }, use) => {
    const response = await request.post('/auth/token', {
      data: { username: 'testuser', password: 'testpass' }
    });
    const { token } = await response.json();
    await use(token);
  },

  apiClient: async ({ request, authToken }, use) => {
    // authToken fixture is resolved first, automatically
    const client = new AuthenticatedApiClient(request, authToken);
    await use(client);
  },
});
```

---

## Sharing Fixture State Across Step Files

When multiple step files need the same fixture state (e.g., a "current user" object created in a Given step and accessed in a Then step), the correct pattern is to store it in a fixture, not in a module-level variable.

**Anti-pattern — module-level state:**

```ts
// WRONG: shared module state breaks parallel execution
let currentUser: User;

Given('a user named {string} exists', async ({ db }, name: string) => {
  currentUser = await db.users.create({ name });
});

Then('the user profile shows {string}', async ({ page }, name: string) => {
  // currentUser is undefined if another scenario ran in between
  await page.goto(`/users/${currentUser.id}`);
});
```

**Correct pattern — fixture-based state:**

```ts
// fixtures.ts
interface ScenarioState {
  createdUser?: User;
}

export const test = base.extend<{ scenarioState: ScenarioState }>({
  scenarioState: async ({}, use) => {
    // Fresh object per scenario — no leakage between tests
    const state: ScenarioState = {};
    await use(state);
  },
});

export const { Given, When, Then } = createBdd(test);
```

```ts
// steps/user.steps.ts
import { Given, Then } from '../fixtures.js';

Given('a user named {string} exists', async ({ db, scenarioState }, name: string) => {
  scenarioState.createdUser = await db.users.create({ name });
});

Then('the user profile shows {string}', async ({ page, scenarioState }, name: string) => {
  const { createdUser } = scenarioState;
  if (!createdUser) throw new Error('No user created in this scenario');
  await page.goto(`/users/${createdUser.id}`);
  await expect(page.getByHeading(name)).toBeVisible();
});
```

The `scenarioState` fixture is created fresh for each scenario, ensuring complete isolation between tests even in parallel execution.

---

## Fixtures vs. Hooks

Playwright's fixture model is strictly more capable than `Before`/`After` hooks for most use cases:

| Concern | Hooks | Fixtures |
|---------|-------|----------|
| Setup/teardown | Before + After (separate blocks) | Single fixture function (before and after `use()`) |
| Conditional execution | Requires tag check | Fixture only runs when explicitly requested |
| Reuse across feature files | Requires shared import | Automatic — fixtures available wherever the extended `test` is imported |
| Dependency between setups | Manual ordering | Automatic dependency graph resolution |
| TypeScript typing | Manual | Automatic from `test.extend<T>()` |

!!! note "When hooks are still appropriate"
    Use `Before`/`After` for cross-cutting concerns that apply to every scenario without needing to be requested (e.g., resetting a global counter). For everything where setup is conditional on what the scenario does, use fixtures.

---

## See Also

- [Writing Steps](writing-steps.md) — using fixtures in step definitions
- [TypeScript Configuration](typescript-config.md) — the `test.extend<T>()` type parameter
- [Test Isolation](test-isolation.md) — database isolation strategies for parallel BDD suites
