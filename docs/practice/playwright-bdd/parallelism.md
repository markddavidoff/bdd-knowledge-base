---
title: Parallelism and Sharding
description: Run playwright-bdd scenarios in parallel across workers and shard them across CI machines for faster feedback.
sources:
  - git-cucumber-js-docs-parallel-parallel
  - git-cucumber-js-docs-sharding-sharding
  - git-cucumber-js-docs-sharding-ci-workflows
  - git-playwright-bdd-repo-docs-writing-steps-hooks-worker-hooks-beforeworker-beforeall
  - git-playwright-bdd-repo-docs-writing-steps-hooks-running-hook-once-running-hook-once
  - web-playwright-flakiness-docs-serial-mode
---

# Parallelism and Sharding

playwright-bdd inherits Playwright's worker model directly. Each Playwright worker runs a subset of generated `.spec.ts` files in a separate browser process. For BDD suites this means scenarios are distributed across workers automatically — no special configuration beyond standard Playwright settings.

## Worker Model with BDD

Playwright distributes test files across workers, not individual scenarios. Each generated `.spec.ts` corresponds to one feature file. By default:

- Multiple feature files can run simultaneously across workers
- Scenarios within a single feature file run serially within one worker
- With `fullyParallel: true`, individual scenarios within a feature file also run in separate workers

```ts
// playwright.config.ts
export default defineConfig({
  workers: 4,          // run up to 4 workers simultaneously
  fullyParallel: true, // distribute individual scenarios across workers
  
  projects: [
    {
      name: 'bdd',
      testDir: defineBddConfig({
        features: 'features/**/*.feature',
        steps: 'steps/**/*.ts',
      }),
    },
  ],
});
```

!!! warning
    `fullyParallel: true` requires every scenario to be fully independent — no shared mutable state, no ordering assumptions. See [Test Isolation](test-isolation.md) for strategies.

## Controlling Workers

Set worker count via config or CLI:

```bash
# Set in config
workers: process.env.CI ? 4 : 2

# Override on CLI
npx playwright test --workers 8

# Run serially (debugging)
npx playwright test --workers 1
```

## Scenario Isolation Requirements

Parallel runs expose hidden ordering dependencies. A scenario that silently relies on state left by a previous scenario will pass when run alone and fail intermittently in parallel. The rule is strict: **each scenario must be able to run in any order, on any worker, in any browser instance, and produce the same result**.

Common violations:

- Scenarios that assume a database record created by a prior scenario still exists
- Scenarios that depend on a previous scenario having logged in
- Scenarios that write to a shared file and read it back
- Global counters or sequence numbers that reset between workers but not between scenarios

See [Test Isolation](test-isolation.md) for database isolation strategies.

## Serial Mode for Dependent Scenarios

When a small group of scenarios genuinely must run in order (e.g., a multi-step purchase flow that cannot be restructured), use the `@mode:serial` special tag:

```gherkin
@mode:serial
Feature: Multi-step purchase flow

  Scenario: Add item to cart
    Given I am browsing the catalog
    When I add "Widget Pro" to my cart
    Then my cart shows 1 item

  Scenario: Complete checkout
    Given I have 1 item in my cart
    When I complete checkout
    Then my order is confirmed
```

With `@mode:serial`, all scenarios in the feature run in one worker sequentially. If an earlier scenario fails, later ones are skipped. This is a last resort — prefer independent scenarios wherever possible.

## Worker Hooks: Setup Per Worker

`BeforeWorker` (aliased as `BeforeAll`) runs once in each worker before any scenarios in that worker execute. Use it for expensive per-worker setup like database seeding:

```ts
// hooks.ts
import { createBdd } from 'playwright-bdd';
import { test } from './fixtures';

const { BeforeWorker, AfterWorker } = createBdd(test);

BeforeWorker(async ({ $workerInfo }) => {
  console.log(`Worker ${$workerInfo.workerIndex} starting`);
  await seedWorkerDatabase($workerInfo.workerIndex);
});

AfterWorker(async ({ $workerInfo }) => {
  await cleanupWorkerDatabase($workerInfo.workerIndex);
});
```

Since playwright-bdd v8, worker hooks accept `tags` to run only when specific feature tags are present:

```ts
BeforeWorker({ tags: '@requires-seeded-db' }, async () => {
  await seedDatabase();
});
```

## Running Setup Once Across All Workers

`BeforeWorker` runs once per worker, not once globally. If 4 workers each seed the same database, you waste time and risk race conditions. Use `@global-cache/playwright` to run setup exactly once:

```ts
import { BeforeWorker } from './fixtures';
import { globalCache } from '@global-cache/playwright';

BeforeWorker(async () => {
  await globalCache.get('seed-database', async () => {
    await seedDatabase(); // runs only once across all workers
  });
});
```

The cache is shared via a file-based lock across all worker processes. The first worker to request the key runs the function; subsequent workers receive the cached result.

## Sharding Across Machines

Sharding distributes the test suite across separate machines (separate CI jobs), each running a different slice of the total. This is horizontal scaling — more machines reduce wall-clock time proportionally.

Playwright's `--shard` flag takes `INDEX/TOTAL` format:

```bash
# Machine 1
npx playwright test --shard 1/4

# Machine 2
npx playwright test --shard 2/4

# Machine 3
npx playwright test --shard 3/4

# Machine 4
npx playwright test --shard 4/4
```

### GitHub Actions Matrix

```yaml
# .github/workflows/test.yml
jobs:
  test:
    strategy:
      matrix:
        shard: [1, 2, 3, 4]
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm ci
      - run: npx playwright install --with-deps chromium
      - run: npx playwright test --shard ${{ matrix.shard }}/4
      - uses: actions/upload-artifact@v4
        if: always()
        with:
          name: test-results-${{ matrix.shard }}
          path: test-results/
```

### Merging Shard Reports

Playwright generates a separate report per shard. Merge them in a follow-up job:

```yaml
  merge-reports:
    needs: test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm ci
      - uses: actions/download-artifact@v4
        with:
          pattern: test-results-*
          merge-multiple: true
          path: all-test-results/
      - run: npx playwright merge-reports --reporter html ./all-test-results
      - uses: actions/upload-artifact@v4
        with:
          name: merged-report
          path: playwright-report/
```

## Tuning Worker Count vs. Duration

Diminishing returns apply: doubling workers does not halve run time because scenarios are not evenly distributed across feature files, and browser startup overhead is real.

General guidance:
- Local development: 1–2 workers (reduce resource contention)
- CI with 8+ CPU cores: 4–8 workers
- Sharding: 2–4 shards × 4 workers each for suites >200 scenarios

Profile your specific suite — some scenarios are 2–3× longer than others, so the bottleneck is often the longest feature file, not the worker count.

## How Parallel Runs Surface State Leakage

The most practical benefit of parallel runs is that they surface hidden ordering bugs immediately. A scenario that passes reliably in serial mode but flakes in parallel is almost certainly reading state that was written by a different scenario. The fix is always the same: make the writing scenario also clean up its state, or make the reading scenario provision its own state.

See [Test Isolation](test-isolation.md) for the full taxonomy of database isolation strategies and patterns for detecting and resolving state leakage.

## Cross-references

- [Test Isolation](test-isolation.md) — database isolation strategies and worker fixture patterns (essential companion to this page)
- [Tags and Filtering](tags-and-filtering.md) — tag-based project splitting as an alternative to sharding
- [Fixtures](fixtures.md) — worker-scoped fixture patterns for expensive setup
