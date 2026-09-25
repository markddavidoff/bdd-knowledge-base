---
title: Brownfield BDD Adoption
description: How to introduce BDD into an existing codebase — where to start, how to run two suites in parallel, and how to avoid coverage inflation.
sources:
  - web-cucumber-antipatterns-1-writing-the-scenario-after-you-ve-written-the-code
  - web-monday-bdd-guide-how-to-overcome-common-bdd-challenges
  - web-testquality-best-practices-common-pitfalls-when-implementing-gherkin
  - web-testquality-best-practices-implementing-gherkin-best-practices-in-your-organization
  - web-cucumberstudio-best-practices-content
  - web-cucumber-bdd-overview-three-practices
---

# Brownfield BDD Adoption

Introducing BDD into a codebase that already has existing tests — Playwright specs, Jest integration tests, or a legacy Cypress suite — is the most common adoption scenario. The good news: you do not need to replace anything. The bad news: the temptation to backfill will consume the team if you let it.

---

## The Core Rule: New Stories Over Retrofitting

The single most important decision in a brownfield adoption is where the BDD boundary begins. The answer is: **new stories only**.

Write BDD scenarios for behavior that does not exist yet. Do not write scenarios for code that is already working and already tested. This rule has three benefits:

1. It keeps BDD attached to the collaboration practice (Three Amigos before code) rather than becoming a documentation exercise.
2. It avoids the "coverage inflation" trap — writing Gherkin for behavior that is already validated elsewhere.
3. It limits the scope of the initial investment, making the adoption demonstrably feasible.

!!! warning "Backfill is a trap"
    Retroactively writing Gherkin for existing code feels productive but delivers almost none of the value of BDD. The scenarios cannot surface disagreements (the code already exists), they cannot guide implementation (it is done), and they often end up describing implementation details rather than behavior. Reserve backfill for truly critical flows where living documentation has strategic value.

---

## The Hybrid State: Two Suites Running in Parallel

In a brownfield adoption, you will run two test suites side by side for an extended period:

- **Existing suite** — whatever was there before (Playwright specs, Jest, Cypress, etc.). Keep it. Do not delete tests.
- **New BDD suite** — playwright-bdd powered, covering only new stories written with Three Amigos.

Configure them as separate Playwright projects so they can be filtered independently:

```typescript
// playwright.config.ts
import { defineConfig } from '@playwright/test';
import { defineBddConfig } from 'playwright-bdd';

const bddConfig = defineBddConfig({
  paths: ['features/**/*.feature'],
  require: ['steps/**/*.ts'],
});

export default defineConfig({
  projects: [
    {
      name: 'existing',
      testMatch: 'tests/**/*.spec.ts',
    },
    {
      name: 'bdd',
      testMatch: '.features-gen/**/*.spec.ts',
      ...bddConfig,
    },
  ],
});
```

Run both in CI. The existing suite catches regressions in established behavior; the BDD suite catches regressions in new behavior and serves as living documentation.

!!! note "Convergence is long"
    In a mature codebase, the two suites may run in parallel for 12–18 months or more before BDD coverage reaches the level where retiring the existing suite makes sense. That is normal. The goal is not to replace everything — it is to have new behavior land in BDD from now on.

---

## Where to Start: Choosing the First Story

Pick a story that is:

- **Genuinely new behavior** — not an enhancement to deeply entangled existing code.
- **Small** — ideally one or two scenarios cover the full story.
- **Visible to non-technical stakeholders** — so you can run a real Three Amigos session.
- **Not blocking** — brownfield codebases have legacy constraints. The first story should not require untangling a complex existing module.

A good first story is often an addition to a flow rather than a change to an existing one: a new filter option, a new report type, a new user role.

```gherkin
# features/reports/export.feature
Feature: Report export
  Scenario: Export report as CSV
    Given Alice is a pro plan user
    And she has a saved report named "Q2 Pipeline"
    When she exports the report as CSV
    Then a CSV file is downloaded
    And it contains the pipeline data
```

---

## Step Definition Conventions That Match Existing Code

Brownfield step definitions must coexist with the existing codebase's patterns. A few conventions help:

**Match existing Page Object naming.** If your existing Playwright tests use `DashboardPage`, `ReportsPage`, and so on, import those same objects in your step definitions rather than creating parallel abstractions. BDD is a layer on top, not a replacement.

```typescript
// steps/reports.steps.ts
import { createBdd } from 'playwright-bdd';
import { test } from '../fixtures';
import { ReportsPage } from '../pages/reports.page'; // same POM as existing tests

const { Given, When, Then } = createBdd(test);

Given('she has a saved report named {string}', async ({ page }, reportName: string) => {
  const reports = new ReportsPage(page);
  await reports.createReport({ name: reportName, type: 'pipeline' });
});

When('she exports the report as CSV', async ({ page }) => {
  const reports = new ReportsPage(page);
  await reports.exportAs('csv');
});
```

**Reuse existing fixture setup helpers.** If your existing test suite has a `createUser()` helper or a `seedDatabase()` function, use those in BDD Before hooks rather than duplicating the logic.

---

## Avoiding Coverage Inflation

Coverage inflation occurs when teams write Gherkin for behavior already covered by existing tests, creating duplicate coverage without new value. The symptoms:

- Scenarios that are clearly derived from existing test cases, not from Three Amigos sessions.
- Step definitions that call the same assertion helpers as the existing unit/integration tests.
- A growing BDD suite with no corresponding increase in detected defects or shared understanding.

**The test:** would this scenario have caught a bug that the existing tests missed? If not, it is probably inflation.

The right answer to "should we BDD this existing feature?" is almost always no, unless:

- The behavior is genuinely underdocumented and stakeholders are confused about it.
- You are about to make a major change and want to lock in the current behavior as a spec before refactoring.
- The existing tests are fragile and you are retiring them as part of a broader quality improvement.

---

## Realistic Timelines

| Timeline | What to expect |
|----------|---------------|
| Month 1 | First Three Amigos ritual established. One feature file with passing CI. |
| Month 3 | 10–20 scenarios covering 3–5 new features. Two suites stable in CI. |
| Month 6 | BDD is the default for new feature work. Team no longer thinks of it as "the new thing." |
| Month 12+ | Legacy suite starts shrinking as coverage overlaps. BDD suite covers most new behavior. |

!!! tip "Declare a clean slate date"
    Pick a date (typically 1–2 sprints out) after which every new story gets BDD treatment. Do not try to grandfather all existing stories — just move the starting line forward.

---

## Cross-References

- [First 90 Days](first-90-days.md) — the greenfield version of this plan
- [Why BDD Fails](why-bdd-fails.md) — failure modes that apply in brownfield contexts too
- [Three Amigos](../methodology/three-amigos.md) — required for every new story
- [CI Integration](../spec-lifecycle/ci-running.md) — running two suites in the same pipeline
- [Anti-Patterns](../../gherkin/best-practices/anti-patterns.md) — scenario quality issues common in backfill work
