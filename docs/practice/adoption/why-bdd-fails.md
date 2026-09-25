---
title: Why BDD Adoptions Fail
description: The canonical failure modes that kill BDD adoption — and how to recognize and fix each one before it takes hold.
sources:
  - web-cucumber-antipatterns-1-ba-product-owner-creating-scenarios-in-isolation
  - web-cucumber-antipatterns-1-writing-the-scenario-after-you-ve-written-the-code
  - web-cucumber-antipatterns-1-incidental-details
  - web-cucumber-antipatterns-1-next-time
  - web-monday-bdd-guide-how-to-overcome-common-bdd-challenges
  - web-cucumberstudio-best-practices-content
  - web-cucumber-bdd-overview-three-practices
---

# Why BDD Adoptions Fail

Most BDD adoptions fail not because of the tooling but because of one of a small set of repeating organizational and process mistakes. Each failure mode has a characteristic smell, a root cause, and a fix. The sooner you recognize them, the less painful the course correction.

---

## 1. BDD-as-QA-Only

**What it looks like:** Developers write code first. QA writes the Gherkin afterward to describe what was built. The `.feature` files live in a separate repo owned by the test team. Developers rarely open them.

**Why it happens:** Teams treat BDD as a testing technique rather than a collaboration practice. The path of least resistance is "QA automates the acceptance tests in Gherkin" — it feels like progress without requiring anyone to change how stories are discussed.

**Early warning signs:** Developers say "I don't touch the feature files." Scenarios are written in a sprint *after* the code is merged. Product owners have no idea what Gherkin is.

**Fix:** Gherkin must be written *before* code — and by the team together in a [Three Amigos session](../methodology/three-amigos.md). The `.feature` file is the acceptance criterion, not the audit trail.

---

## 2. Spec-Code Decoupling

**What it looks like:** Feature files pass locally but describe behavior that no longer matches the implementation. Steps are vague enough that they "pass" even when the product breaks. Or scenarios quietly go `@skip`ped and are never revisited.

**Why it happens:** Step definitions become resilient to a fault — they pass even when the system behavior changes. Nobody has a process to review whether scenarios still describe reality.

**Early warning signs:** The CI run is always green but bugs still reach production. Scenarios say "user can access dashboard" but the actual assertion just checks for a `200` status code.

**Fix:** Step definitions must make meaningful assertions. CI must fail on regressions. Run `bddgen --dry-run` to catch undefined steps. See [CI Enforcement](../spec-lifecycle/ci-running.md) for pipeline gating.

---

## 3. No CI Enforcement

**What it looks like:** BDD tests exist but are run manually ("when someone remembers to"). Or they run in CI but on a separate optional job that never blocks a merge. Broken scenarios accumulate.

**Why it happens:** Getting BDD into CI is slightly more work than getting unit tests in, and teams deprioritize it. Without enforcement, the suite drifts.

**Early warning signs:** "We'll fix the BDD tests next sprint." Undefined steps in the repo. `@skip` proliferation.

**Fix:** BDD must block merges. Run `bddgen` as a required CI step. Gate on undefined steps with `--dry-run`. See [CI Integration](../spec-lifecycle/ci-running.md).

```yaml
# .github/workflows/bdd.yml (excerpt)
- name: Check for undefined steps
  run: npx bddgen --dry-run

- name: Run BDD suite
  run: npx playwright test --project=bdd
```

---

## 4. Unrealistic Examples (Hardcoded IDs and Magic Strings)

**What it looks like:** Scenarios reference database IDs, magic strings, or setup state that only exists in a specific environment. `Given the order with ID 40123 is pending`. The tests only pass if you run them in the right sequence against the right database.

**Why it happens:** Scenarios are authored by thinking about the existing test environment rather than about the behavior. Step definitions do direct DB lookups by literal ID.

**Early warning signs:** Tests pass locally but not in CI. Steps contain raw integers. Test setup is hidden in Before hooks no one maintains.

**Fix:** Name your test data. Use [custom parameter types](../../gherkin/reference/custom-parameter-types.md) to give canonical fixtures human-readable names (`Given Alice has a pending order`). Each scenario should own its own setup.

---

## 5. Gherkin-as-Documentation (No Step Definitions)

**What it looks like:** Scenarios are written in planning sessions and checked in. They read beautifully. But no step definitions exist. Cucumber reports every step as `pending`. The feature files become design artifacts — useful at first, gradually ignored.

**Why it happens:** Teams nail the formulation phase and never complete automation. Often the scenarios were written by someone without TypeScript access.

**Early warning signs:** Large numbers of pending steps. Feature files in a `docs/` directory rather than next to step definitions. No BDD section in CI output.

**Fix:** Every scenario must be wired up to run. Use `bddgen --dry-run` in CI as a gate. Scenarios with no implementation are either deleted or given a `@wip` tag with a deadline.

---

## 6. Too Much Tooling, Too Little Conversation

**What it looks like:** The team spends weeks configuring playwright-bdd, setting up reporting pipelines, and debating tag taxonomy. One sprint in, nobody has had a Three Amigos session. The Gherkin is written by one person.

**Why it happens:** Tooling setup is satisfying and measurable. Changing how conversations happen is hard and uncomfortable.

**Early warning signs:** Elaborate Playwright configuration before a single `.feature` file with step definitions exists. Long Slack threads about formatting rules before any scenarios run.

**Fix:** Start with the conversation, not the config. [Three Amigos](../methodology/three-amigos.md) in week one. One feature file, one passing scenario, then configure.

---

## 7. "Cucumber Theater"

**What it looks like:** Everything looks right. There are feature files, step definitions, a CI job, and HTML reports. But the scenarios were written after the code, never read by the product owner, and test implementation details rather than observable behavior. The whole thing is technically correct and completely valueless.

```gherkin
# Cucumber theater — looks like BDD, delivers none of it
Scenario: POST /api/v1/users returns 201
  Given the database is connected
  When I send a POST request to "/api/v1/users" with body '{"email":"x@x.com"}'
  Then the response status code is 201
  And the "id" field in the response is not null
```

**Why it happens:** A team was told to adopt BDD, adopted the syntax, and missed the point. The tool was installed without the practice.

**Fix:** The fix is cultural. Scenarios must be written before code, in language a product owner can read and verify. If a non-technical stakeholder cannot tell you what the scenario is testing, the scenario needs to be rewritten.

!!! warning "The #1 symptom"
    If your product owner has never read a `.feature` file, you are doing Cucumber theater.

---

## Cross-References

- [First 90 Days](first-90-days.md) — how to avoid these failure modes from day one
- [Three Amigos](../methodology/three-amigos.md) — the collaboration practice that prevents most of the above
- [Anti-Patterns](../../gherkin/best-practices/anti-patterns.md) — Gherkin-level anti-patterns (step quality, scenario structure)
- [CI Integration](../spec-lifecycle/ci-running.md) — enforcement pipelines
