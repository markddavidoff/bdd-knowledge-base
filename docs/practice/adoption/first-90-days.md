---
title: First 90 Days (Greenfield BDD)
description: A phased plan for introducing BDD to a new project — from the first Three Amigos session through a stable, CI-enforced scenario suite.
sources:
  - web-monday-bdd-guide-5-steps-to-implement-bdd-in-your-organization
  - web-cucumber-bdd-overview-three-practices
  - web-cucumber-antipatterns-1-writing-the-scenario-after-you-ve-written-the-code
  - web-cucumberstudio-best-practices-content
  - git-gherkin-best-practices-repo-readme-write-the-scenario-before-writing-the-code
  - web-testquality-best-practices-implementing-gherkin-best-practices-in-your-organization
---

# First 90 Days (Greenfield BDD)

Starting BDD from scratch is easier than retrofitting it into an existing codebase, but it still requires discipline to avoid the failure modes that kill most adoptions. This guide walks through three phases with concrete goals, traps to avoid, and success signals for each.

The core principle: **do the collaboration before the automation**. Teams that skip to tooling configuration first almost always end up with [Cucumber theater](why-bdd-fails.md#7-cucumber-theater).

---

## Phase 1 — Weeks 1–2: One Story, One Feature File

### Goal

Run one full Discovery → Formulation → Automation cycle with the whole team present. The deliverable is a single `.feature` file with at least one passing step definition in CI.

### How

**Day 1–3: Run your first Three Amigos session.** Pick the simplest upcoming user story — not the most important, the simplest. Bring a product person, a developer, and a QA engineer into the same room (or call) for 60 minutes. Use [Example Mapping](../methodology/example-mapping.md) to surface concrete examples. Ask "what if?" to find edge cases.

**Day 4–5: Write the feature file together.** Turn the agreed examples into Gherkin. Do not let one person write it alone. Decisions about vocabulary made here will echo for months — choose words that match how the business actually talks.

```gherkin
# features/billing/upgrade.feature
Feature: Plan upgrade
  As a free plan user
  I want to upgrade to pro
  So that I can access advanced features

  Scenario: Upgrade from free to pro
    Given Alice has a free plan account
    When she upgrades to the pro plan
    Then her account shows the pro plan
    And she can access the export feature
```

**Day 5–10: Wire up the step definitions.** Use `createBdd()` with playwright-bdd. The goal is one green scenario in CI, not a complete suite.

```typescript
// steps/billing.steps.ts
import { createBdd } from 'playwright-bdd';
import { test } from '../fixtures';

const { Given, When, Then } = createBdd(test);

Given('Alice has a free plan account', async ({ db }) => {
  await db.users.create({ email: 'alice@example.com', plan: 'free' });
});

When('she upgrades to the pro plan', async ({ page }) => {
  await page.getByRole('button', { name: 'Upgrade to Pro' }).click();
  await page.getByRole('button', { name: 'Confirm upgrade' }).click();
});

Then('her account shows the pro plan', async ({ page }) => {
  await expect(page.getByTestId('plan-name')).toHaveText('Pro');
});

Then('she can access the export feature', async ({ page }) => {
  await expect(page.getByTestId('export-button')).toBeVisible();
});
```

### Success Signal

One feature file, all steps green, CI running (even if not blocking yet).

### Common Trap

Spending week 1 configuring Allure, setting up monorepo step scoping, or debating tag naming conventions. Defer all of that. One green scenario first.

---

## Phase 2 — Weeks 3–6: CI Enforcement and the Step Definition Foundation

### Goal

BDD blocks merges. Build a vocabulary foundation that the rest of the team can extend. Add new scenarios only from new stories — no retrofitting.

### How

**Get CI passing and blocking.** Add `bddgen --dry-run` as a required check. This prevents undefined steps from being merged and forces formulation before implementation.

```yaml
# .github/workflows/bdd.yml
name: BDD
on: [push, pull_request]
jobs:
  bdd:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '20' }
      - run: npm ci
      - name: Check undefined steps
        run: npx bddgen --dry-run
      - name: Run BDD suite
        run: npx playwright test --project=bdd
```

**Build the step definition foundation.** Identify the 5–10 step patterns that will appear in most scenarios for your domain. Extract them into shared step files. Create your first fixture extensions for common setup (auth state, seeded users).

**Choose your vocabulary.** The words you use for actor names, resource states, and actions become your team's ubiquitous language. Write them down. Aim for consistency — avoid synonyms for the same concept.

!!! tip "Vocabulary over quantity"
    10 well-named, reusable steps are more valuable than 50 narrowly specific ones. Invest time here.

### Three Amigos as a Ritual

By the end of phase 2, Three Amigos sessions should be a regular part of story kickoff — not an occasional event. Every story that involves user-visible behavior gets a session before anyone opens an editor.

### Common Trap

Retrofitting existing code with Gherkin. The temptation to write scenarios for features already built is strong — it feels productive. Resist it. New scenarios for new behavior only. Backfill, if it ever happens, is lower priority than new coverage.

---

## Phase 3 — Weeks 7–12: Parameter Type Registry and Vocabulary Standardization

### Goal

Your team has a working vocabulary. Now codify it. Add a [custom parameter type registry](../../gherkin/reference/custom-parameter-types.md) so named test resources are typed, reusable, and self-documenting. Continue expanding coverage to new stories.

### How

**Create `parameters.ts`.** Move named personas, plan configurations, and resource states into `defineParameterType` calls. This makes the vocabulary explicit and gives TypeScript type checking on step parameters.

```typescript
// steps/parameters.ts
import { defineParameterType } from 'playwright-bdd';

defineParameterType({
  name: 'user',
  regexp: /Alice|Bob|Charlie/,
  transformer(name: string) {
    const users: Record<string, { email: string; role: string }> = {
      Alice:   { email: 'alice@example.com',   role: 'admin' },
      Bob:     { email: 'bob@example.com',     role: 'member' },
      Charlie: { email: 'charlie@example.com', role: 'viewer' },
    };
    return users[name];
  },
});

defineParameterType({
  name: 'plan',
  regexp: /free|pro|enterprise/,
  transformer: (s: string) => s as 'free' | 'pro' | 'enterprise',
});
```

**Standardize step vocabulary.** Run a session with the team to review all step text written so far. Identify synonyms, merge them, and update the step definitions. This is your first refactor cycle.

**Document your vocabulary.** Write a brief team glossary: what does "Alice" mean in tests? What are the canonical plan names? This becomes the reference for new team members.

### Walking Skeleton Approach

By the end of week 12, you should have a "walking skeleton" BDD suite: a small number of well-structured scenarios covering your most important business flows, green in CI on every PR, with a parameter type registry that makes new scenarios fast to write.

!!! note "Success does not mean coverage"
    Do not measure success by the number of scenarios. Measure it by whether new features get scenarios *before* code is written, and whether those scenarios are reviewed by someone who doesn't write code.

### Success Metrics for 90 Days

| Metric | Target |
|--------|--------|
| Scenarios passing in CI | 100% |
| New stories with Three Amigos sessions | ≥ 80% |
| Undefined steps in any PR | 0 (blocked by CI) |
| Feature files readable by product owner | Yes |
| Parameter type registry exists | Yes |

---

## Cross-References

- [Three Amigos](../methodology/three-amigos.md) — the discovery session format
- [Example Mapping](../methodology/example-mapping.md) — structuring the discovery conversation
- [Custom Parameter Types](../../gherkin/reference/custom-parameter-types.md) — building the vocabulary registry
- [CI Integration](../spec-lifecycle/ci-running.md) — enforcement pipeline details
- [Why BDD Fails](why-bdd-fails.md) — the failure modes this plan is designed to prevent
- [Brownfield Adoption](brownfield.md) — if you are starting with an existing codebase
