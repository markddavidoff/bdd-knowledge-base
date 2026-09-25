---
title: Environment-Specific Scenarios
description: Tagging patterns for environment-specific scenarios, environment config in playwright.config.ts, secrets management, and smoke suites per environment.
sources:
  - git-playwright-bdd-repo-docs-guides-env-vars-env-vars
  - git-playwright-bdd-repo-docs-guides-env-variables-env-variables
  - git-playwright-bdd-repo-docs-writing-features-special-tags-skip-fixme
  - git-playwright-bdd-repo-docs-cli-bddgen-test-or-just-bddgen
---

# Environment-Specific Scenarios

Not every scenario can run in every environment. Production restricts destructive operations. Staging may have test-only debug endpoints. Dev has services that don't exist elsewhere. Environment tagging makes these constraints explicit and enforceable.

## Tagging Patterns

Use environment tags at the scenario (or feature) level to communicate intent:

```gherkin
Feature: Order management

  # Runs everywhere
  Scenario: Customer views their order history
    Given I am a registered customer with 3 past orders
    When I view my order history
    Then I see 3 orders in reverse chronological order

  # Only meaningful in staging — uses a test data seeding endpoint
  @staging-only
  Scenario: Test data is seeded for load testing
    Given the test data seed endpoint is available
    When I request 1000 test orders be created
    Then the system confirms the seed job has been queued

  # Runs in production as a smoke check — read-only
  @production-only
  Scenario: Product catalog is accessible to anonymous users
    Given I am not logged in
    When I view the product catalog
    Then at least 10 products are listed

  # Dev environment only — local mock service available
  @dev-only
  Scenario: Payment gateway mock returns configurable responses
    Given the payment mock is configured to decline all cards
    When I place an order with a valid card
    Then the order is rejected with reason "payment declined"
```

## Environment Configuration in playwright.config.ts

Map environment tags to a `DEPLOY_ENV` variable or similar:

```typescript
// playwright.config.ts
import { defineConfig } from '@playwright/test';
import { defineBddConfig } from 'playwright-bdd';
import 'dotenv/config';

const env = process.env.DEPLOY_ENV ?? 'staging';

// Build grep pattern based on environment
function buildGrepPattern(env: string): RegExp | undefined {
  const exclusions: string[] = [];

  if (env !== 'staging') exclusions.push('@staging-only');
  if (env !== 'production') exclusions.push('@production-only');
  if (env !== 'dev') exclusions.push('@dev-only');

  if (exclusions.length === 0) return undefined;

  const pattern = exclusions.map(t => `.*${t}`).join('|');
  return new RegExp(`^(?!.*(?:${pattern}))`);
}

const testDir = defineBddConfig({
  features: 'features/**/*.feature',
  steps: 'steps/**/*.steps.ts',
});

export default defineConfig({
  testDir,
  grep: buildGrepPattern(env),
  use: {
    baseURL: process.env.BASE_URL ?? 'http://localhost:3000',
  },
});
```

Alternatively, apply tag filtering at the `bddgen` level so environment-inappropriate scenarios never generate test files at all:

```bash
# Staging CI
DEPLOY_ENV=staging npx bddgen --tags "not @production-only and not @dev-only" && \
  npx playwright test

# Production smoke
DEPLOY_ENV=production npx bddgen --tags "@production-only or @smoke" && \
  npx playwright test
```

## Dynamic Base URL Configuration

Never hardcode the base URL. Read it from the environment:

```typescript
// playwright.config.ts
export default defineConfig({
  use: {
    baseURL: process.env.BASE_URL,
  },
});
```

In step definitions, use Playwright's relative URL resolution:

```typescript
Given('I am on the home page', async ({ page }) => {
  // baseURL is set by playwright.config.ts — no hardcoded URL here
  await page.goto('/');
});

Given('I view the product catalog', async ({ page }) => {
  await page.goto('/catalog');
});
```

CI invocation per environment:

```bash
# Staging
BASE_URL=https://staging.example.com npx bddgen && npx playwright test

# Production smoke
BASE_URL=https://www.example.com npx bddgen --tags "@smoke" && npx playwright test
```

## Secrets Management

**Never put credentials, API keys, or tokens in Gherkin.** Feature files are committed to source control and may be read by many people. Secrets live in environment variables and are injected into step definitions via fixtures.

```gherkin
# WRONG — credential in Gherkin
  Scenario: Admin accesses the management dashboard
    Given I log in as admin with password "Sup3rS3cr3t!"
    When I navigate to the dashboard
    Then I see the management panel

# RIGHT — credential in environment variable, resolved in step definition
  Scenario: Admin accesses the management dashboard
    Given I am logged in as an admin
    When I navigate to the dashboard
    Then I see the management panel
```

Step definition reads the secret from the environment:

```typescript
Given('I am logged in as an admin', async ({ page }) => {
  await page.goto('/login');
  await page.getByLabel('Email').fill(process.env.ADMIN_EMAIL!);
  await page.getByLabel('Password').fill(process.env.ADMIN_PASSWORD!);
  await page.getByRole('button', { name: 'Log in' }).click();
});
```

Load secrets in `playwright.config.ts` using dotenv, keeping `.env` out of source control:

```typescript
// playwright.config.ts
import 'dotenv/config'; // loads .env file if present
```

```
# .env (gitignored)
ADMIN_EMAIL=admin@example.com
ADMIN_PASSWORD=hunter2

# CI: these are set as repository secrets / environment variables
# Never in .env.example or any committed file
```

## Smoke Suites Per Environment

A smoke suite is the minimal set of scenarios that confirms an environment is healthy. It runs after every deployment.

Design principles:

- Read-only operations only for production smoke (no data mutation)
- Cover the most critical user paths (login, core feature access, key API endpoints)
- Must complete in under 2 minutes
- Must not require test-specific infrastructure (no seed endpoints, no mocks)

```gherkin
@smoke
Feature: Smoke — core user journey

  Scenario: Registered user can log in and view their dashboard
    Given I am a registered customer
    When I log in
    Then I see my account dashboard

  @smoke @production-only
  Scenario: Product catalog loads for anonymous users
    Given I am not logged in
    When I view the product catalog
    Then at least 1 product is listed

  @smoke
  Scenario: Health check endpoint responds
    When I request the system health status
    Then the status is "healthy"
```

Post-deploy CI step:

```yaml
- name: Run smoke suite against production
  run: |
    npx bddgen --tags "@smoke and not @staging-only" && \
    npx playwright test
  env:
    BASE_URL: https://www.example.com
    DEPLOY_ENV: production
```

!!! tip "Smoke suite failure = rollback trigger"
    If your deployment pipeline can act on CI exit codes, a failing smoke suite can automatically trigger a rollback. This makes the `@smoke` tag a deployment gate, not just a convenience filter.

## Cross-references

- [Feature Flags in Specs](feature-flags.md) — `@staging-only` and `@feature-flag-X` interaction
- [CI Enforcement](ci-enforcement.md) — registering environment tags in `allowed-tags`
- [CI Running](ci-running.md) — multi-environment pipeline configuration
