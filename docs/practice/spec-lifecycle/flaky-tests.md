---
title: Flaky Tests
description: Defining flakiness in BDD suites, the quarantine pattern, retry strategies, flakiness rate KPIs, root causes, and prevention.
sources:
  - web-playwright-flakiness-docs-retries
  - web-playwright-flakiness-docs-failures
  - web-playwright-flakiness-docs-introduction
  - git-playwright-bdd-repo-docs-writing-features-special-tags-retries-n
  - git-playwright-bdd-repo-docs-writing-features-special-tags-skip-fixme
---

# Flaky Tests

A flaky scenario is one that **passes and fails without any change to the code or test**. Flakiness is a trust problem: when developers can't tell if a failure is real, they start ignoring failures — and the entire suite loses its value as a safety net.

## Defining Flakiness

Playwright categorizes test results into three outcomes:

- **passed** — passed on the first attempt
- **flaky** — failed on the first attempt, passed on a retry
- **failed** — failed on first attempt and all retries

A scenario that is "flaky" by Playwright's definition does not indicate a bug in the application — it indicates a problem in the test itself. The two must be treated differently.

## The Quarantine Pattern

When a scenario is identified as flaky, **quarantine it immediately**. The quarantine pattern isolates the flaky scenario from the main suite so it cannot block CI while a fix is investigated.

```gherkin
Feature: Order placement

  # Quarantined 2026-06-01 - timing issue in payment confirmation step
  # Backlog ticket: PROJ-1234
  @quarantine
  Scenario: Payment confirmation appears within 3 seconds
    Given I have a valid payment method on file
    When I place the order
    Then the payment confirmation banner is visible

  Scenario: Successful order from a single in-stock item
    Given my cart contains "Wireless Keyboard" with quantity 1
    When I place the order
    Then my order history shows "Wireless Keyboard" with status "confirmed"
```

In `playwright.config.ts`, exclude quarantined scenarios from the default run:

```typescript
// playwright.config.ts
import { defineConfig } from '@playwright/test';
import { defineBddConfig } from 'playwright-bdd';

const testDir = defineBddConfig({
  features: 'features/**/*.feature',
  steps: 'steps/**/*.steps.ts',
});

export default defineConfig({
  testDir,
  // Default: exclude quarantine
  grep: /^(?!.*@quarantine)/,
});
```

Run quarantined scenarios separately on a schedule (nightly or manually) to track whether they stabilize:

```bash
npx bddgen --tags "@quarantine" && npx playwright test
```

!!! warning "Quarantine is not a dumping ground"
    Every `@quarantine` tag must have a backlog ticket with a target resolution date. If a scenario stays quarantined for more than two sprints without investigation, it should be deleted — it is not providing value.

## Flakiness Rate KPI

Track the ratio of flaky outcomes to total scenario runs. Target: **less than 1% flaky rate** across the suite. Above 2% indicates a systemic isolation problem that must be addressed before the suite is useful.

Use Playwright's built-in retry report to extract flakiness data. The HTML report marks flaky scenarios distinctly. For trend tracking, pipe JSON output to a dashboard.

## Retry Strategies

Retries are a mitigation, not a fix. Use them for timing and network variability that cannot be eliminated, not as a substitute for proper test isolation.

### Global retry configuration

```typescript
// playwright.config.ts
export default defineConfig({
  retries: process.env.CI ? 2 : 0, // only retry in CI
});
```

Running locally with retries obscures isolation bugs. Disable them during development.

### Per-scenario retry with playwright-bdd tags

playwright-bdd supports a special `@retries:N` tag that overrides the global setting for individual scenarios:

```gherkin
Feature: Payment processing

  # This scenario depends on a third-party payment gateway in staging
  # Allow 2 retries for network variance
  @retries:2
  Scenario: Card payment processed by external gateway
    Given I have a valid Visa card on file
    When I place the order
    Then the payment is marked as processed by the gateway
```

!!! tip "When retries help vs. mask problems"
    **Retries help with:** transient network errors to external services, timing issues with async UI updates that can't be resolved with explicit waits, race conditions in third-party services outside your control.

    **Retries mask problems with:** shared mutable state between scenarios, missing explicit waits (retrying is slower and less reliable than a proper `waitFor`), non-deterministic test data.

## Root Causes of Flakiness

**1. Shared mutable state**
Scenarios that modify shared database rows, caches, or files without cleanup will collide in parallel runs. Each scenario must own its state.

**2. Timing assumptions**
Hardcoded `sleep()` calls or assertions that fire before an async operation completes. Replace with `expect(locator).toBeVisible()` or `waitFor()` calls.

**3. External service dependency**
Scenarios that call live external APIs (payment gateways, email services, third-party APIs) will fail when those services are unavailable or rate-limit the test suite. Mock external services in unit/integration tiers; only test the real integration in a dedicated, appropriately-tagged scenario.

**4. Test data collisions**
Two parallel workers that both try to create a user with the same email. Use unique identifiers per worker (e.g., `worker-${workerId}-user@example.com`).

**5. Worker process restarts**
When a scenario fails, Playwright discards the entire worker process and starts a new one. If `beforeAll` setup is expensive and not idempotent, this can cause cascading failures that look like flakiness.

## Prevention Checklist

- [ ] Every scenario creates its own test data — no dependence on data created by another scenario
- [ ] No hardcoded `sleep()` calls — use `waitFor` or Playwright's auto-waiting assertions
- [ ] External services are mocked at the step definition level for non-integration scenarios
- [ ] Worker-scoped fixtures are idempotent (safe to run multiple times)
- [ ] CI uses `--retries 2` to distinguish true failures from flakes, but flakes are still tracked and fixed
- [ ] `@quarantine` tag is paired with a backlog ticket on every use

## Cross-references

- [CI Running](ci-running.md) — `--retries` flag in CI pipelines
- [CI Enforcement](ci-enforcement.md) — excluding quarantine from branch protection
- [playwright-bdd: Special Tags](../playwright-bdd/tags-and-filtering.md)
