---
title: Environment-Specific Scenarios — Gherkin Examples
description: Tagging scenarios for @staging, @production, @dev-only environments, writing environment-gated tests, and composing smoke suites per environment.
sources:
  - git-gherkin-best-practices-repo-readme-use-tags-to-organize-your-features-and-scenarios
  - web-testquality-best-practices-advanced-gherkin-features-for-complex-testing-needs
  - web-cucumber-gherkin-reference-keywords
---

# Environment-Specific Scenarios — Gherkin Examples

Some behaviors only exist in certain environments. A staging environment may have test payment processors. A production smoke suite must run against live infrastructure. A `@dev-only` scenario tests behavior that is intentionally disabled in production.

Environment-specific tagging is a first-class Gherkin pattern — not a workaround.

---

## Core Tagging Strategy

```
@dev-only       — runs in local development only; not in CI or production
@staging        — runs in staging CI pipeline; not against production
@production     — runs in production smoke suite only
@smoke          — the minimal set that must pass in every environment
@regression     — the full suite; runs in CI on staging; excluded from production smoke
```

A scenario can carry more than one environment tag if it should run in multiple environments but not all:

```gherkin
@staging @production  # runs in both staging and production
@dev-only @smoke      # local dev only, but considered part of the smoke set
```

---

## Smoke Suite — Runs in All Environments

```gherkin
@smoke
Feature: Critical path smoke tests
  The minimum set of behaviors that must pass in every environment
  before traffic is allowed.

  @smoke
  Scenario: The application responds to health checks
    When the health endpoint is requested
    Then the application reports healthy

  @smoke
  Scenario: A user can sign in
    Given a registered user named "Alice"
    When Alice signs in
    Then Alice is taken to her dashboard

  @smoke
  Scenario: The home page loads for unauthenticated visitors
    Given an unauthenticated visitor
    When the visitor opens the home page
    Then the home page renders within 3 seconds
    And the main navigation is present
```

Run the smoke suite in any environment:
```bash
npx playwright test --grep @smoke
```

---

## Staging-Only Scenarios

Staging has test payment processors, synthetic user accounts, and may have feature flags enabled that are not yet in production:

```gherkin
@payments @staging
Feature: Payment processing (staging)
  Payment flows verified against the test payment processor.
  These scenarios use test card numbers that only work in staging.

  Background:
    Given a registered customer named "Alice"
    And the Stripe test processor is active

  @staging @smoke
  Scenario: A test card payment succeeds
    Given Alice has the test Visa card "4242 4242 4242 4242" on file
    When Alice places an order for $50.00
    Then the payment succeeds
    And Alice receives an order confirmation

  @staging @error-path
  Scenario: A declined test card is handled gracefully
    Given Alice has the test card "4000 0000 0000 0002" on file
    When Alice places an order for $50.00
    Then the payment is declined
    And Alice sees "Your card was declined. Please use a different payment method."
```

!!! warning "Test cards in staging only"
    Stripe test card numbers only work against the Stripe test API. The `@staging` tag ensures these scenarios are never run against the production payment processor. The step definition reads the environment configuration to select the correct API key.

---

## Production Smoke Suite

Production smoke tests verify live systems with real accounts and real infrastructure, but must not create side effects (no test orders placed, no emails sent to real users):

```gherkin
@production
Feature: Production smoke verification
  Minimal behavioral verification against live production infrastructure.
  These scenarios are read-only — they do not mutate production data.

  @production @smoke
  Scenario: The sign-in page is accessible
    Given an unauthenticated visitor
    When the visitor opens the sign-in page
    Then the sign-in page renders successfully
    And the sign-in form is present

  @production @smoke
  Scenario: A smoke test account can authenticate
    Given the smoke test account "smoke-test@internal.example.com"
    When the smoke test account signs in
    Then authentication succeeds
    And the dashboard renders successfully

  @production @smoke
  Scenario: The public API responds to authenticated requests
    Given the smoke test API token
    When the API health endpoint is requested with the token
    Then the API reports healthy
    And the response time is under 2 seconds
```

!!! note "Smoke test accounts"
    Production smoke tests use dedicated synthetic accounts that are excluded from analytics, billing, and marketing workflows. Never use real customer accounts in automated tests.

---

## Dev-Only Scenarios

Some behaviors exist only in development: debug endpoints, test seeding APIs, feature flags that are off in all other environments:

```gherkin
@dev-only
Feature: Development utilities
  Behaviors available only in local development environments.
  These scenarios are never run in CI or production.

  @dev-only
  Scenario: The database seed endpoint resets test data
    When the seed endpoint is called with the "clean-slate" preset
    Then the database is reset to a known state
    And 10 test users exist
    And 5 test products exist

  @dev-only
  Scenario: Debug mode exposes additional diagnostic headers
    Given the application is running in debug mode
    When any API request is made
    Then the response includes the "X-Debug-Request-Id" header
    And the response includes the "X-Debug-DB-Queries" header
```

---

## Per-Environment CI Configuration

playwright-bdd reads tag filter from the `playwright.config.ts` project configuration. One project per environment:

```typescript
// playwright.config.ts — excerpt showing environment-specific tag filtering
export default defineConfig({
  projects: [
    {
      name: 'staging',
      grep: /(@smoke|@staging)/,
      grepInvert: /@dev-only|@production/,
      use: { baseURL: process.env.STAGING_URL },
    },
    {
      name: 'production-smoke',
      grep: /@production/,
      grepInvert: /@dev-only|@staging/,
      use: { baseURL: process.env.PROD_URL },
    },
  ],
});
```

Run the staging project:
```bash
npx playwright test --project=staging
```

Run the production smoke suite:
```bash
npx playwright test --project=production-smoke
```

---

## Feature Flags — Related Pattern

When a feature is behind a flag that is active in staging but not production, tag it:

```gherkin
@feature-flag-new-checkout @staging
Scenario: New checkout flow processes payment correctly
  Given Alice has a saved payment method
  And the new checkout flag is enabled for Alice's account
  When Alice completes checkout using the new flow
  Then Alice receives an order confirmation
```

Remove `@feature-flag-new-checkout` from all scenarios once the flag is removed from code. See Section 6.6 (Feature Flags in Specs) for the full lifecycle pattern.

For tag taxonomy governance including allowed-tag enforcement in CI, see [Tag Reference](../reference/tags-classification.md). For the environment configuration in playwright-bdd, see [playwright-bdd Configuration](../../practice/playwright-bdd/installation.md).
