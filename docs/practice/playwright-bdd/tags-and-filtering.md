---
title: Tags and Filtering
description: Run subsets of BDD scenarios using tag expressions in the Playwright CLI, playwright.config.ts, and CI pipelines.
sources:
  - git-playwright-bdd-repo-docs-writing-features-special-tags-special-tags
  - git-playwright-bdd-repo-docs-configuration-options-tags
  - git-playwright-bdd-repo-docs-writing-steps-scoped-scoped
  - git-playwright-bdd-repo-docs-blog-whats-new-in-v8-tagging-enhancements
  - git-playwright-bdd-repo-docs-writing-steps-scoped-tags-from-path
---

# Tags and Filtering

Tags are the primary mechanism for selecting which scenarios to run. playwright-bdd passes tag expressions to Playwright's built-in `--grep` flag, so the full power of Playwright's filtering applies to BDD scenarios.

## Tag Placement and Inheritance

Tags are placed above the keyword they annotate and are inherited downward:

```gherkin
@smoke @regression
Feature: User authentication

  @happy-path
  Scenario: Successful login
    Given I am on the login page
    When I log in with valid credentials
    Then I am redirected to the dashboard

  @error-path @slow
  Scenario: Login with wrong password
    Given I am on the login page
    When I log in with incorrect credentials
    Then I see an error message
```

In this example, the `Successful login` scenario carries `@smoke`, `@regression`, and `@happy-path`. The `Login with wrong password` scenario carries `@smoke`, `@regression`, `@error-path`, and `@slow`.

## CLI Filtering with --grep

Run only scenarios matching a tag using the `--grep` flag (which accepts a regular expression):

```bash
# Run all @smoke scenarios
npx playwright test --grep @smoke

# Run all @happy-path scenarios
npx playwright test --grep @happy-path

# Exclude @slow scenarios
npx playwright test --grep-invert @slow
```

For AND logic (all tags must be present), use a look-ahead regex:

```bash
# Run scenarios tagged @smoke AND NOT @slow
npx playwright test --grep "(?=.*@smoke)(?!.*@slow)"
```

!!! note
    Playwright's `--grep` takes a JavaScript regex, not a Cucumber tag expression. For complex filtering, use the `tags` option in `playwright.config.ts` (see below) which accepts proper tag expression syntax.

## Tag Expressions in playwright.config.ts

The `tags` option in `defineBddConfig()` accepts the full Cucumber tag expression syntax (AND, OR, NOT, parentheses):

```ts
// playwright.config.ts
import { defineConfig } from '@playwright/test';
import { defineBddConfig } from 'playwright-bdd';

export default defineConfig({
  projects: [
    {
      name: 'smoke',
      testDir: defineBddConfig({
        features: 'features/**/*.feature',
        steps: 'steps/**/*.ts',
        tags: '@smoke and not @slow',  // Cucumber tag expression
      }),
    },
  ],
});
```

This filters scenario generation itself — only matching scenarios appear in the generated `.spec.ts` files. Combine it with `--grep` for runtime filtering on top of generation-time filtering.

## Tag-Based Project Configuration

Use separate Playwright projects to run different tag subsets with different settings:

```ts
// playwright.config.ts
export default defineConfig({
  projects: [
    {
      name: 'smoke-fast',
      testDir: defineBddConfig({
        features: 'features/**/*.feature',
        steps: 'steps/**/*.ts',
        tags: '@smoke and not @slow',
      }),
      use: { headless: true },
      retries: 0,
    },
    {
      name: 'regression-full',
      testDir: defineBddConfig({
        features: 'features/**/*.feature',
        steps: 'steps/**/*.ts',
        tags: '@regression',
      }),
      use: { headless: true },
      retries: 2,
    },
    {
      name: 'e2e-staging',
      testDir: defineBddConfig({
        features: 'features/**/*.feature',
        steps: 'steps/**/*.ts',
        tags: '@e2e and @staging',
      }),
      use: {
        headless: false,
        baseURL: process.env.STAGING_URL,
      },
    },
  ],
});
```

Run a specific project:

```bash
npx playwright test --project smoke-fast
npx playwright test --project regression-full
```

## playwright-bdd Special Tags

playwright-bdd defines several built-in tags that control test execution behavior:

| Tag | Effect |
|-----|--------|
| `@skip` | Skip the scenario (marks as skipped in report) |
| `@fixme` | Mark as expected failure |
| `@only` | Run only this scenario (like `.only` in Playwright) |
| `@slow` | Triple the default timeout |
| `@fail` | Expect the scenario to fail |
| `@retries:N` | Override retry count for this scenario |
| `@timeout:N` | Override timeout in milliseconds |
| `@mode:serial` | Run the feature's scenarios serially in one worker |
| `@mode:parallel` | Run the feature's scenarios in parallel across workers |

```gherkin
Feature: Payment processing

  @smoke
  Scenario: Successful payment
    Given I have a valid credit card
    When I complete checkout
    Then my order is confirmed

  @skip
  Scenario: PayPal checkout
    # Skipped until PayPal integration is complete

  @slow @retries:3
  Scenario: Checkout under network degradation
    Given the network is throttled to 3G
    When I complete checkout
    Then my order is confirmed within 30 seconds
```

## Environment-Specific Filtering

Combine environment variables with tag filtering for environment-specific test runs:

```ts
// playwright.config.ts
const env = process.env.TEST_ENV || 'dev';

export default defineConfig({
  projects: [
    {
      name: 'bdd',
      testDir: defineBddConfig({
        features: 'features/**/*.feature',
        steps: 'steps/**/*.ts',
        tags: `@${env} or @all-envs`,
      }),
    },
  ],
});
```

Feature files tag scenarios with the environments where they should run:

```gherkin
@all-envs
Scenario: Health check endpoint returns 200
  Given the API is reachable
  Then the response status is 200

@staging
Scenario: Feature flag X is enabled
  Given I am on the features page
  Then I see the experimental toggle
```

```bash
TEST_ENV=staging npx playwright test
TEST_ENV=production npx playwright test
```

## CI Configuration

A typical CI pipeline runs multiple tag-filtered passes:

```yaml
# .github/workflows/test.yml
jobs:
  smoke:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm ci
      - run: npx playwright test --project smoke-fast
      - uses: actions/upload-artifact@v4
        with:
          name: smoke-report
          path: playwright-report/

  regression:
    runs-on: ubuntu-latest
    needs: smoke
    steps:
      - uses: actions/checkout@v4
      - run: npm ci
      - run: npx playwright test --project regression-full
      - uses: actions/upload-artifact@v4
        with:
          name: regression-report
          path: playwright-report/
```

!!! tip
    Run `@smoke` scenarios first in CI. If smoke fails, fail fast — skip the full regression run until smoke is green again. This is enforced by `needs: smoke` in GitHub Actions.

!!! warning
    Avoid `@only` in committed code. playwright-bdd will run only that scenario and silently skip all others, which will mislead CI into thinking all tests passed. Consider adding a lint rule to prevent `@only` in feature files.

## Tag Governance

Tags only add value if the team agrees on their meaning. Document the classification taxonomy in your project wiki or in a `docs/tag-taxonomy.md`:

- `@smoke` — critical path, run on every commit, must pass in <5 min
- `@regression` — full coverage, run on PR merge, can take up to 30 min
- `@e2e` — full browser, requires staging environment
- `@api` — API-level only, no browser
- `@slow` — expected runtime >30 seconds, excluded from smoke

See [Tag Taxonomy Design](../../gherkin/best-practices/tag-taxonomy.md) for governance patterns.

## Cross-references

- [Scoped Step Definitions](scoped-steps.md) — using tags to scope step definitions to features
- [Parallelism](parallelism.md) — tag-based sharding across CI machines
- [Test Isolation](test-isolation.md) — worker hooks filtered by tag
