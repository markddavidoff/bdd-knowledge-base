---
title: BDD vs. Plain Playwright Tests
description: When to use Gherkin and playwright-bdd versus plain Playwright tests — honest tradeoffs, the ice-cream-cone anti-pattern, and a decision checklist.
sources:
  - web-cucumber-bdd-overview-what-is-bdd
  - web-cucumber-bdd-overview-three-practices
  - web-monday-bdd-guide-bdd-vs-tdd-choosing-the-right-approach
  - web-bdd-living-documentation-common-pitfalls-and-how-to-avoid-them
  - web-playwright-bdd-vs-cucumber-cucumber-js-vs-playwright-bdd-comparison
  - git-playwright-bdd-example-repo-agents-skills-playwright-bdd-skill-phase-0-bdd-necessity-c
---

# BDD vs. Plain Playwright Tests

BDD with Gherkin is not the right choice for every project or every test. This page gives you an honest accounting of the tradeoffs so you can make an informed decision — and introduces the "Should I use BDD?" checklist you can run before starting any new feature.

---

## What plain Playwright tests look like

Without BDD, a Playwright test is a TypeScript file written directly against the Playwright API:

```typescript
// tests/upgrade.spec.ts — plain Playwright, no Gherkin
import { test, expect } from '@playwright/test';

test('upgrading from free to pro starts billing today', async ({ page }) => {
  // arrange
  await page.goto('/login');
  await page.fill('[name=email]', 'alice@example.com');
  await page.fill('[name=password]', 'secret');
  await page.click('button[type=submit]');

  // act
  await page.click('text=Upgrade to Pro');
  await page.click('text=Confirm');

  // assert
  await expect(page.getByTestId('billing-start')).toContainText(
    new Date().toLocaleDateString()
  );
});
```

This is clean, fast, and familiar. The question is whether the added structure of Gherkin is worth the overhead for your context.

---

## When BDD adds value

BDD delivers its strongest returns when **all three** of these conditions are true:

1. **Non-technical stakeholders need to read or approve the specs.** Product managers, compliance officers, or domain experts who cannot read TypeScript but can read `Given / When / Then` in natural language.

2. **The business rules are complex and need collaborative refinement.** Example Mapping sessions uncover edge cases and ambiguities before code is written. If the requirements are simple and stable, this upfront investment has diminishing returns.

3. **Living documentation matters.** The team wants a report that non-developers can read after every CI run to see exactly which behaviors are verified and which are failing. Gherkin + the Cucumber HTML reporter or Allure provides this out of the box.

!!! example "Strong BDD signal"
    You are building a payment or subscription system with multiple plan tiers, discount rules, proration logic, and regional tax behavior. A product manager needs to sign off on the acceptance criteria, and compliance needs auditable evidence that the billing rules work correctly. This is BDD's home territory.

---

## When NOT to use BDD

BDD adds overhead. The `.feature` → `bddgen` → `.spec.ts` → `playwright test` pipeline means an extra layer of indirection for every test. That overhead is worth paying when BDD's benefits apply, but not when they don't.

**Skip BDD when:**

- The test covers an **infrastructure concern** (database migrations, health checks, retry logic). These have no business-language description.
- **Only developers will ever read the scenario.** If the "living documentation" audience is just your own team and you are comfortable reading TypeScript, there is no net gain.
- The behavior is **trivial and stable** — a single, obvious happy-path with no edge cases to discover.
- You are writing **unit tests or component tests**. BDD operates at the acceptance layer, not the unit layer. See the test pyramid below.
- The test is highly **implementation-coupled** — it verifies a specific API response shape or DOM structure, not observable user behavior. Step definitions should describe behavior, not implementation.

!!! warning "The ice-cream-cone anti-pattern"
    A healthy test suite is pyramid-shaped: many unit tests, fewer integration tests, even fewer E2E tests. The ice-cream-cone is the inverted failure: the entire suite is UI-level BDD scenarios, with no unit tests underneath.

    Writing a BDD scenario for every behavior, including things that should be unit tests, causes this. BDD belongs at the **top of the pyramid** (acceptance/E2E layer) — not throughout it. Fast unit tests that verify isolated functions should be plain test files, not Gherkin.

    ```
    # Healthy test pyramid
              ┌──────┐
              │  BDD │  ← acceptance / E2E (Gherkin + playwright-bdd)
             ─┼──────┼─
            ─ │  API │  ← integration (supertest or APIRequestContext)
           ─  ┼──────┼─
          ─── │ unit │  ← many, fast (vitest / jest)
         ─────┴──────┘─

    # Ice-cream-cone anti-pattern (avoid)
         ─────┬──────┐
        ─ BDD │      │  ← almost everything is a slow E2E Gherkin scenario
       ──     │      │
      ─       ┼──────┼
     ─        │ unit │  ← almost nothing at the bottom
    ──────────┴──────┘
    ```

---

## Honest tradeoffs

| Factor | Plain Playwright | BDD + playwright-bdd |
|--------|-----------------|----------------------|
| **Setup complexity** | Low — just TypeScript | Medium — bddgen config, step definition wiring |
| **Readability for devs** | High — familiar TypeScript | Medium — extra layer of indirection |
| **Readability for non-devs** | Low — cannot read TypeScript | High — Given/When/Then is approachable |
| **Living documentation** | None by default | Built-in with Cucumber HTML / Allure |
| **Collaboration support** | None | Three Amigos + Example Mapping integrations |
| **Refactoring cost** | Low — rename symbols directly | Higher — step text changes break `.feature` files |
| **Maintenance at scale** | Can get verbose | Step reuse reduces duplication |
| **IDE support** | Excellent | Good (VS Code Cucumber extension) |
| **Debugging** | Excellent (Playwright trace viewer) | Same (playwright-bdd uses Playwright's trace viewer) |

The **Gherkin overhead** — writing feature files, maintaining step definitions, running bddgen — is real. It pays for itself when the team is getting value from collaborative specification and living documentation. It does not pay for itself when it is used as a naming convention for TypeScript tests.

---

## The "Should I use BDD?" checklist

Run this checklist before starting a new feature or test suite:

- [ ] Will a non-developer (PM, QA, domain expert, compliance) read or review these scenarios?
- [ ] Are the business rules complex enough to benefit from an Example Mapping session?
- [ ] Will the scenario be run in CI and its result surfaced as living documentation?
- [ ] Is the behavior at the acceptance level — verifying observable user outcomes, not internal implementation?
- [ ] Does the team have (or plan to have) proper step definition abstractions so scenarios stay declarative?

**Score:**
- **4–5 checkmarks:** Use BDD. The collaboration and documentation overhead will pay off.
- **2–3 checkmarks:** Consider BDD for the feature-level acceptance tests only; write unit and integration tests as plain TypeScript.
- **0–1 checkmarks:** Skip BDD for this test. Write a plain Playwright test or a unit test.

!!! tip "The BDD necessity question"
    Before writing or modifying any feature file, ask: *Does this change genuinely need a BDD spec?* If the answer is no, skip the Gherkin workflow entirely. A plain Playwright test is not a compromise — for the right use case, it is the correct choice.

---

## playwright-bdd vs. @cucumber/cucumber runner

If you have decided BDD is right, you still need to choose the runner. For TypeScript projects using Playwright:

- **playwright-bdd** — use when you need Playwright fixtures, parallel execution, the Playwright trace viewer, or `storageState`-based auth. This is the recommended choice for browser tests.
- **@cucumber/cucumber (CucumberJS)** — use when the tests are API-only or backend-only, you are migrating from an existing Cucumber suite, or the team is already invested in CucumberJS tooling.

See [Gherkin Reference: Keywords](reference/keywords.md) and the [practice/playwright-bdd](../practice/playwright-bdd/index.md) section for setup guidance.
