---
title: Suite Partitioning at Scale
description: Strategies for keeping CI under 10 minutes at 500+ scenarios — tag-based sharding, Playwright project splitting, --shard N/M, and selective re-running.
sources:
  - git-cucumber-js-docs-parallel-parallel
  - git-playwright-bdd-repo-docs-configuration-multiple-projects-different-feature-files
  - git-cucumber-js-docs-configuration-options
---

# Suite Partitioning at Scale

CI suite time is a forcing function for test discipline. Teams that wait 20 minutes for a suite to pass often merge before it does — defeating the purpose of the suite. The target for a BDD suite is **under 10 minutes on the critical path**. At 500+ scenarios, this requires deliberate partitioning.

## Why 10 Minutes Is the Threshold

Developer psychology follows a simple rule: if feedback arrives before the next context switch (typically 10–15 minutes), developers wait for it. If it arrives after, they have already moved on and a failure becomes an interrupt rather than an in-flow correction. 10 minutes is not a hard technical limit — it is a behavioral threshold.

## Strategy 1: Playwright's --shard Option

Playwright's `--shard N/M` flag splits tests across N machines automatically. With playwright-bdd, scenarios map to `.spec.ts` tests after `bddgen`, so sharding works without any additional configuration.

```bash
# Machine 1 of 3
npx playwright test --shard=1/3

# Machine 2 of 3
npx playwright test --shard=2/3

# Machine 3 of 3
npx playwright test --shard=3/3
```

In GitHub Actions, use a matrix:

```yaml
jobs:
  e2e:
    strategy:
      matrix:
        shard: [1, 2, 3]
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm ci
      - run: npx playwright install --with-deps chromium
      - run: npx bddgen
      - run: npx playwright test --shard=${{ matrix.shard }}/3
      - uses: actions/upload-artifact@v4
        with:
          name: blob-report-${{ matrix.shard }}
          path: blob-report/
```

Merge reports after all shards complete:

```bash
npx playwright merge-reports ./all-blob-reports --reporter html
```

## Strategy 2: Tag-Based Filtering

Tags let you run specific subsets of scenarios based on classification:

```bash
# Run only smoke tests (fast, critical path)
npx playwright test --grep "@smoke"

# Run everything except slow scenarios
npx playwright test --grep-invert "@slow"

# Run UI tests on PR, API tests nightly
npx playwright test --grep "@api" --grep-invert "@ui"
```

Tag strategy for partitioning:

```gherkin
@smoke @checkout
Scenario: Guest user completes purchase
  ...

@regression @checkout @slow
Scenario: Purchasing with split payment across 3 cards
  ...
```

CI pipeline with tiered execution:

```yaml
- name: Smoke suite (blocks merge)
  run: npx playwright test --grep "@smoke"

- name: Regression suite (nightly only)
  if: github.event_name == 'schedule'
  run: npx playwright test --grep "@regression"
```

## Strategy 3: Playwright Project-Based Splitting

For a monorepo with distinct domains, separate Playwright projects naturally partition the suite:

```typescript
// playwright.config.ts
export default defineConfig({
  projects: [
    {
      ...defineBddProject({
        name: 'checkout',
        features: 'apps/checkout/e2e/features/**/*.feature',
        steps:    'apps/checkout/e2e/steps/**/*.ts',
      }),
    },
    {
      ...defineBddProject({
        name: 'billing',
        features: 'apps/billing/e2e/features/**/*.feature',
        steps:    'apps/billing/e2e/steps/**/*.ts',
      }),
    },
    {
      ...defineBddProject({
        name: 'auth',
        features: 'apps/auth/e2e/features/**/*.feature',
        steps:    'apps/auth/e2e/steps/**/*.ts',
      }),
    },
  ],
});
```

Run a single domain:

```bash
npx playwright test --project=checkout
```

Combine with sharding for large domains:

```bash
npx playwright test --project=checkout --shard=1/2
npx playwright test --project=checkout --shard=2/2
```

## Strategy 4: Selective Re-Running on Changed Files

When only checkout-related features changed in a PR, running the billing suite provides no signal. Detect changed feature files and scope the run:

```bash
# Get changed feature files in this PR
CHANGED=$(git diff --name-only origin/main...HEAD | grep '\.feature$')

if [ -z "$CHANGED" ]; then
  echo "No feature files changed, skipping BDD suite"
  exit 0
fi

# Find which Playwright projects are affected
# (custom script that maps feature paths to project names)
PROJECTS=$(node scripts/affected-projects.js $CHANGED)

npx bddgen
npx playwright test --project=$PROJECTS
```

A simple `affected-projects.js` script:

```javascript
// scripts/affected-projects.js
const changedFiles = process.argv.slice(2);
const projectMap = {
  'apps/checkout': 'checkout',
  'apps/billing':  'billing',
  'apps/auth':     'auth',
};

const affected = new Set();
for (const file of changedFiles) {
  for (const [prefix, project] of Object.entries(projectMap)) {
    if (file.startsWith(prefix)) affected.add(project);
  }
}

console.log([...affected].join(','));
```

## Strategy 5: Worker Count Tuning

Playwright's default worker count is half the available CPU cores. For I/O-heavy BDD scenarios (browser + API calls), more workers than cores is often beneficial:

```typescript
// playwright.config.ts
export default defineConfig({
  workers: process.env.CI ? 4 : undefined,  // 4 workers in CI, auto-detect locally
  // ...
});
```

Profile your suite to understand where time goes:

```bash
# Output timing per test
npx playwright test --reporter=list 2>&1 | grep -E "✓|✗|→" | sort -t" " -k2 -rn | head -20
```

## Measuring Partition Effectiveness

Track these metrics per partition over time:

| Metric | Target |
|--------|--------|
| Wall-clock time per shard | <8 minutes |
| Longest single test | <2 minutes |
| Scenario count per shard | ±20% of average (balanced) |
| Flakiness rate | <1% |

!!! tip "Duration distribution analysis"
    Run `npx playwright test --reporter=json` and parse the output to find the slowest 10% of scenarios. These are the primary candidates for parallelism optimization — either split them across shards or investigate why they are slow (missing network mocks, unoptimized setup).
