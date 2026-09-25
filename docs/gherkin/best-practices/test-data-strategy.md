---
title: Test Data Strategy
description: How to classify and manage the three types of test data in BDD — test case values, configuration data, and ready state — with tradeoffs between API, DB, and UI setup approaches.
sources:
  - web-automation-panda-test-data-types-of-test-data
  - web-automation-panda-test-data-ready-state
  - web-automation-panda-test-data-configuration-data
  - web-automation-panda-writing-good-gherkin-handling-test-data
  - git-gherkin-best-practices-repo-readme-make-scenarios-independent-and-deterministic
---

# Test Data Strategy

"Test data" is an overloaded term. Before deciding how to manage it, clarify which category you're dealing with — the right technique differs for each.

## The Three Categories

### 1. Test Case Values

Input and expected output values specific to the behavior under test. These belong in Gherkin because they communicate the intent of the scenario.

```gherkin
Scenario: Pro plan enforces seat limit
  Given a pro organization with a 10-seat limit
  When the admin invites an 11th member
  Then the invitation should be rejected with "seat limit reached"
```

The `10` and `11` are test case values. They belong in the scenario because the seat limit boundary is the behavior being specified.

**Rule:** If removing a value makes the scenario meaningless, it's a test case value — keep it in Gherkin.

### 2. Configuration Data

Environment-specific settings: base URLs, credentials, feature flag overrides, third-party API keys. These must **never** appear in Gherkin.

```typescript
// playwright.config.ts — config data lives here, not in .feature files
export default defineConfig({
  use: {
    baseURL: process.env.BASE_URL ?? 'http://localhost:3000',
  },
});
```

Load configuration in `Before` hooks or fixtures so all scenarios in a run share the same environment settings. A test that hardcodes `https://staging.example.com` in a step will break when run against production. Configuration data enables the same test procedure to run in any environment without modifying the feature file.

### 3. Ready State

The initial system state a scenario requires: user accounts, organization records, seeded products, historical transactions. This is the most complex category and the one that trips up most teams.

!!! note "The isolation contract"
    Every scenario must start from a known, controlled state and leave no observable side-effects for subsequent scenarios. Violation of this contract causes ordering dependencies and parallel-run failures.

## Approaches to Ready-State Setup

### API-Based Setup (Preferred)

Create state via your application's own API before the test. This is the most realistic setup method — if your API can create an organization, use it.

```typescript
// fixtures.ts
import { test as base } from 'playwright-bdd';
import { ApiClient } from '../support/api-client';

type Fixtures = { api: ApiClient; org: { id: string; name: string } };

export const test = base.extend<Fixtures>({
  api: async ({ request }, use) => {
    await use(new ApiClient(request));
  },
  org: async ({ api }, use) => {
    const org = await api.orgs.create({ name: 'Test Org', plan: 'pro' });
    await use(org);
    await api.orgs.delete(org.id);  // cleanup
  },
});
```

**Advantages:** Exercises your API contracts. State is realistic (goes through validation). No schema coupling.

**Disadvantages:** Requires a running application. Slower than direct DB writes for large data volumes.

### Direct DB Seeding (Fast, Schema-Coupled)

Insert rows directly via a database client or migration helper. Use this for worker-scoped fixtures that seed reference data once per worker process.

```typescript
// worker-scoped fixture — runs once per worker, not per test
org: [async ({ db }, use) => {
  await db.query(`INSERT INTO organizations (name, plan) VALUES ('Seed Org', 'pro')`);
  const [org] = await db.query(`SELECT * FROM organizations WHERE name = 'Seed Org'`);
  await use(org);
  await db.query(`DELETE FROM organizations WHERE id = $1`, [org.id]);
}, { scope: 'worker' }],
```

**Advantages:** Very fast. No HTTP overhead.

**Disadvantages:** Tightly coupled to DB schema. Schema migrations break fixtures. Bypasses application-layer validation.

!!! warning "Schema coupling risk"
    Direct DB seeding is acceptable for stable reference data (e.g., lookup tables, plan tiers). Avoid it for domain objects whose shape changes frequently.

### UI Setup Flows (Slow, Brittle — Last Resort)

Driving the UI to create test state is the most expensive option: it requires a working browser session, is slow, and fails when UI navigation changes. Reserve this for state that can only be created through the UI (e.g., a wizard with no API equivalent).

```gherkin
# Avoid this pattern — setup via UI is brittle
Background:
  Given I am logged in as admin
  And I navigate to the "Create Organization" page
  And I fill in the organization name as "Test Org"
  And I click "Create"
```

If you find yourself writing Background steps that drive the UI to set up preconditions, that's a signal to build an API endpoint or a seeding helper.

## Equivalence Classes and Descriptive Values

Use named equivalence classes rather than raw magic values:

```gherkin
# Magic string — what does "password123" test?
Given I log in with password "password123"

# Descriptive — communicates the class being tested
Given I log in with a valid password
Given I log in with an expired password
```

Named custom parameter types are the formal mechanism for this. See [Named Test Data Catalog](named-test-data-catalog.md) for the full pattern.

**Avoid randomization.** Random test data produces non-deterministic failures. `faker.name()` in a step definition makes the scenario undebugable on CI. Use fixed, well-named values instead.

## Cleanup Strategies

| Strategy | When to use | Notes |
|---|---|---|
| Delete in `After` hook | Per-scenario DB records | Runs even on test failure |
| Transaction rollback | Fast in-process isolation | Limits what behaviors you can test |
| Worker-scoped teardown | Shared reference data | Runs once at end of worker |
| Truncate + re-seed per run | Full environment reset | Only feasible for fast DB ops |

!!! warning "Never use Then steps for cleanup"
    `Then` steps verify outcomes. Cleanup in a `Then` step is skipped if the test fails before reaching it. All cleanup belongs in `After` hooks.

## Summary: What Goes Where

| Data type | Location | Example |
|---|---|---|
| Test case values | Gherkin steps / Examples tables | Seat count, error message text |
| Configuration | `playwright.config.ts`, env vars | Base URL, auth credentials |
| Ready state | API fixture, DB seed, `Before` hook | User account, organization record |
| Cleanup | `After` hook, fixture teardown | Delete created records |
