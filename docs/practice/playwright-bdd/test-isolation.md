---
title: Test Isolation and State Management
description: Strategies for keeping BDD scenarios independent in parallel playwright-bdd runs, including database isolation patterns and the BeforeFeature gap.
sources:
  - issue-playwright-bdd-issues-219
  - git-playwright-bdd-repo-docs-writing-steps-hooks-worker-hooks-beforeworker-beforeall
  - git-playwright-bdd-repo-docs-writing-steps-hooks-running-hook-once-running-hook-once
  - git-playwright-bdd-repo-docs-writing-steps-hooks-scenario-hooks-beforescenario-before
  - git-playwright-bdd-repo-docs-writing-steps-passing-data-between-steps-passing-data-between
  - web-playwright-flakiness-docs-serial-mode
---

# Test Isolation and State Management

Test isolation is the requirement that any scenario can run alone, in any order, on any worker, and produce the same result. It is the single most important correctness property of a parallel BDD suite. Violations produce flakiness that is difficult to reproduce and diagnose.

This page documents the core problem, four database isolation strategies with trade-offs, worker fixture patterns, workarounds for the BeforeFeature gap, and how to detect state leakage.

## The Core Problem

In a parallel run, Playwright assigns feature files to workers. Two workers may be executing scenarios simultaneously against the same database. Scenario A creates a record. Scenario B — in a different worker, with no knowledge of A — reads the same table and finds unexpected data. B fails intermittently.

The fix is never to serialize the suite (which defeats the purpose of parallelism). The fix is to ensure each scenario operates on data that is private to it, or that data is always cleaned up before another scenario can observe it.

## Database Isolation Strategies

### Strategy 1: One Database per Worker

Each worker gets its own database instance. Workers never share data.

```
Worker 0 → postgres://localhost:5432/testdb_0
Worker 1 → postgres://localhost:5432/testdb_1
Worker 2 → postgres://localhost:5432/testdb_2
Worker 3 → postgres://localhost:5432/testdb_3
```

Implementation with a worker-scoped fixture:

```ts
// fixtures.ts
import { test as base, createBdd } from 'playwright-bdd';

export const test = base.extend<{}, { db: DatabaseConnection }>({
  db: [async ({ $workerInfo }, use) => {
    const dbName = `testdb_${$workerInfo.workerIndex}`;
    const db = await connectToDatabase(dbName);
    await db.migrate();
    await use(db);
    await db.truncateAll();
    await db.disconnect();
  }, { scope: 'worker' }],
});

export const { Given, When, Then } = createBdd(test);
```

- **Isolation**: complete — no shared state possible
- **Cost**: high — N database instances in docker-compose, more memory, slower startup
- **Best for**: suites where tests write heavily and cleanup is unreliable

### Strategy 2: Schema per Worker (PostgreSQL)

One PostgreSQL instance, but each worker operates in a separate schema. Objects with the same name (`users`, `orders`) exist independently in each schema.

```ts
export const test = base.extend<{}, { db: DatabaseConnection }>({
  db: [async ({ $workerInfo }, use) => {
    const schema = `worker_${$workerInfo.workerIndex}`;
    const db = await connectToDatabase('testdb', { schema });
    await db.createSchemaIfNotExists(schema);
    await db.migrate();
    await use(db);
    await db.dropSchema(schema);
    await db.disconnect();
  }, { scope: 'worker' }],
});
```

- **Isolation**: good — schemas are logically separate; cross-schema queries are possible but unlikely in test code
- **Cost**: medium — one database instance, but migration must run per schema
- **Best for**: teams already on PostgreSQL who want isolation without orchestrating multiple databases

### Strategy 3: Transaction Rollback per Scenario

Wrap each scenario in a database transaction. Roll back instead of committing at the end. The database appears clean for the next scenario.

```ts
export const test = base.extend<{ db: DatabaseConnection }>({
  db: async ({ $workerInfo }, use) => {
    const db = await connectToDatabase('testdb');
    await db.beginTransaction();
    await use(db);
    await db.rollback(); // always roll back — never commit
    await db.disconnect();
  },
});
```

- **Isolation**: fast and complete — rollback is instantaneous
- **Cost**: low — one database, one connection per test
- **Limitation**: cannot test behavior that spans transactions (e.g., testing that a second transaction reads committed data from the first), and does not work well with ORMs that manage their own connection pools
- **Best for**: unit-style BDD tests that exercise one transaction at a time

### Strategy 4: External State API (State-Provisioning Service)

Workers call a shared HTTP service that provisions and tears down named state sets. The service manages database state on behalf of workers, handling contention itself.

```ts
const { BeforeScenario, AfterScenario } = createBdd(test);

BeforeScenario(async ({ request, $testInfo }) => {
  const stateKey = `scenario-${$testInfo.testId}`;
  await request.post('http://localhost:9000/state/provision', {
    data: { key: stateKey, preset: 'default-catalog' },
  });
  // state service creates isolated data set keyed by stateKey
});

AfterScenario(async ({ request, $testInfo }) => {
  const stateKey = `scenario-${$testInfo.testId}`;
  await request.delete(`http://localhost:9000/state/${stateKey}`);
});
```

- **Isolation**: highest — the service can implement any isolation model
- **Cost**: highest — requires building and running the state service
- **Best for**: large teams sharing a test environment where database-level isolation is not feasible; monorepo suites with multiple apps sharing state

## Strategy Selection Guide

| Scenario | Recommended strategy |
|----------|---------------------|
| Small suite, PostgreSQL, CI only | Schema per worker |
| Tests are lightweight, unit-style | Transaction rollback |
| Heavy write workload, containers available | One DB per worker |
| Multi-app shared test environment | External state API |
| Legacy suite, cannot change DB setup | Serial mode (last resort) |

## Worker Fixture Patterns

### Scope: Worker for Expensive Setup

Fixtures with `scope: 'worker'` run once per worker rather than per scenario. Use them for database connections, seeded reference data, and auth tokens that are safe to share across scenarios:

```ts
export const test = base.extend<{}, { workerDb: DatabaseConnection, seedData: SeedData }>({
  workerDb: [async ({ $workerInfo }, use) => {
    const db = await connectToDatabase(`testdb_${$workerInfo.workerIndex}`);
    await use(db);
    await db.disconnect();
  }, { scope: 'worker' }],

  seedData: [async ({ workerDb }, use) => {
    const data = await workerDb.seed({
      categories: ['electronics', 'clothing'],
      roles: ['admin', 'user', 'guest'],
    });
    await use(data);
    // no teardown needed — workerDb teardown drops all rows
  }, { scope: 'worker' }],
});
```

Scenarios receive the `seedData` fixture and read from it — but must not mutate it. Mutations belong in per-scenario setup using a test-scoped fixture:

```ts
export const test = base.extend<{ scenarioDb: ScenarioContext }>({
  scenarioDb: async ({ workerDb }, use) => {
    // Create a transaction or schema for this scenario
    const ctx = await workerDb.beginScenario();
    await use(ctx);
    await ctx.rollback();
  },
});
```

### Lazy Initialization

If a worker-scoped fixture is expensive to initialize and not all scenarios need it, use lazy initialization:

```ts
export const test = base.extend<{}, { adminToken: string }>({
  adminToken: [async ({}, use) => {
    let token: string | null = null;

    const getToken = async () => {
      if (!token) {
        token = await fetchAdminToken(); // only fetched when first requested
      }
      return token;
    };

    await use(await getToken());
  }, { scope: 'worker' }],
});
```

## The BeforeFeature / AfterFeature Gap

playwright-bdd has no native `BeforeFeature` / `AfterFeature` hooks. This is a deliberate design choice: the runner distributes scenarios, not features, so there is no guaranteed point where "all scenarios in feature X have finished on this worker."

Three workarounds are available:

### Workaround 1: Tagged BeforeWorker (v8+)

Since playwright-bdd v8, `BeforeAll` / `BeforeWorker` accepts a `tags` option. A worker hook with `@feature-x` runs only when the worker executes a scenario from that feature. This is the closest equivalent to `BeforeFeature`:

```ts
const { BeforeWorker, AfterWorker } = createBdd(test);

BeforeWorker({ tags: '@checkout' }, async () => {
  await setupCheckoutTestData();
});

AfterWorker({ tags: '@checkout' }, async () => {
  await cleanupCheckoutTestData();
});
```

Feature file:

```gherkin
@checkout
Feature: Checkout flow

  Scenario: Add item and checkout
    Given I have an item in my cart
    When I complete checkout
    Then my order is confirmed
```

**Caveat**: if the feature is split across multiple workers (possible with `fullyParallel: true`), the hook runs once per worker that handles at least one matching scenario, not once per feature.

### Workaround 2: Global Setup File

For setup that must run exactly once before any scenario in the suite, use Playwright's global setup:

```ts
// global-setup.ts
import { chromium } from '@playwright/test';

export default async function globalSetup() {
  await provisionSharedReferenceData();
}
```

```ts
// playwright.config.ts
export default defineConfig({
  globalSetup: './global-setup.ts',
  globalTeardown: './global-teardown.ts',
  // ...
});
```

Global setup runs once before any worker starts and is guaranteed to complete before scenarios execute. Use it for data that is read-only during the test run.

### Workaround 3: Run-Once Cache

Use `@global-cache/playwright` to run per-feature setup exactly once across all workers:

```ts
import { BeforeWorker } from './fixtures';
import { globalCache } from '@global-cache/playwright';

BeforeWorker({ tags: '@checkout' }, async () => {
  await globalCache.get('checkout-seed-data', async () => {
    await seedCheckoutData(); // runs once across all workers
  });
});
```

## Hook Ordering

When multiple `BeforeScenario` hooks match the same scenario (e.g., one from a global hook file and one from a domain-specific file), execution order is determined by load order — the order in which step files are imported. This is **not guaranteed** to be stable across runs.

Mitigation: do not rely on ordering between hooks in different files. If hook A must run before hook B, put both in the same file or make B's logic idempotent (safe to run even if A has not run yet).

## Error Handling in Hooks

When a `BeforeScenario` hook throws, the scenario is marked as failed before any step runs. The `AfterScenario` hook still executes (Playwright guarantees this), which means cleanup code in `After` runs even when `Before` fails.

This matters for database cleanup: even if seeding fails, the `AfterScenario` cleanup that rolls back the transaction or drops the scenario-specific schema will still run.

In CI output, a hook failure appears with the hook name in the stack trace. Look for `BeforeScenario` or `BeforeWorker` in the error to distinguish hook failures from step failures.

## Detecting State Leakage

State leakage manifests as intermittent failures that:
- Pass when run in isolation (`--workers 1`)
- Pass when the scenario is run alone (`npx playwright test --grep "scenario name"`)
- Fail inconsistently in `--workers 4` runs
- Fail consistently only when a specific other scenario runs first

Diagnosis process:

1. Run the full suite with `--repeat-each 3` to amplify intermittent failures
2. Run with `--workers 1` — if failures disappear, the bug is ordering/state
3. Add `--reporter list` to see execution order and correlate failures with specific preceding scenarios
4. Search step definitions for global variables, module-level state, or shared database tables that are written in `When` steps
5. Add a `BeforeScenario` hook that asserts the database is in the expected starting state

!!! warning
    The most common source of state leakage in playwright-bdd suites is module-level variables used to pass data between steps. Replace them with the `ctx` fixture (a test-scoped empty object) — it is re-created per scenario and cannot leak between scenarios.

!!! tip
    Run your CI suite with `fullyParallel: true` even if you plan to disable it for production runs. Full parallelism is the fastest way to surface latent isolation bugs before they start failing customers.

## Cross-references

- [Parallelism](parallelism.md) — worker model, sharding, and serial mode
- [Fixtures](fixtures.md) — worker-scoped vs. test-scoped fixture lifecycles
- [Auth Patterns](auth-patterns.md) — auth state isolation across parallel scenarios
