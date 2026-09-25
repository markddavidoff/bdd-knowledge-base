---
title: Gherkin Anti-Patterns
description: Catalog of common BDD and Gherkin anti-patterns — what they look like, why they are harmful, and how to fix them.
sources:
  - web-cucumber-antipatterns-1-adding-pointless-scenario-descriptions
  - web-cucumber-antipatterns-1-incidental-details
  - web-cucumber-antipatterns-1-testing-several-rules-at-the-same-time
  - web-cucumber-antipatterns-1-ba-product-owner-creating-scenarios-in-isolation
  - web-cucumber-antipatterns-1-writing-the-scenario-after-you-ve-written-the-code
  - git-gherkin-best-practices-repo-readme-avoid-overuse-of-scenario-outline
  - git-gherkin-best-practices-repo-readme-avoid-using-conjunctive-steps
  - git-gherkin-best-practices-repo-readme-make-scenarios-independent-and-deterministic
---

# Gherkin Anti-Patterns

Anti-patterns in BDD fall into two categories: process failures (how the team uses BDD) and authoring failures (how scenarios are written). Both erode value. This catalog covers both, with diagnosis and fixes.

---

## Process Anti-Patterns

### BDD as QA-Only

**What it looks like:** Testers write all the Gherkin after developers have finished coding. Product owners never read the feature files.

**Why it's harmful:** BDD's value is in the pre-implementation conversation — the Three Amigos session that surfaces misunderstandings before code is written. If scenarios are written after the code, they describe the implementation rather than the intended behavior. Bugs baked in during development pass as "expected behavior."

**Fix:** Write the feature file before writing any code. The scenario is the acceptance criterion. A PR with code changes but no feature file changes for a new behavior is a process failure.

---

### Spec-Code Decoupling

**What it looks like:** Feature files exist and step definitions are implemented, but scenarios drift from the actual application behavior. Tests pass because step definitions are mocked or overly permissive.

**Why it's harmful:** The feature file claims to document behavior, but it no longer does. The "living documentation" is dead. Stakeholders make decisions based on scenarios that don't reflect reality.

**Fix:** Enforce CI execution — scenarios must execute against the real application, not mocks (or clearly tagged as `@mock-only`). Run `bddgen` dry-run in CI to catch undefined steps.

---

### Cucumber Theater

**What it looks like:** The team has hundreds of feature files, a CI badge, and metrics. But no product owner has read a feature file in six months. Scenarios are written to satisfy a process requirement, not to communicate behavior.

**Why it's harmful:** All the cost of BDD (tooling, Three Amigos time, step maintenance) with none of the benefit (shared understanding, living documentation).

**Fix:** If a feature file change doesn't trigger a conversation with a non-technical stakeholder at least occasionally, BDD isn't being practiced — you're writing automated tests with extra syntax. Return to the Three Amigos process.

---

### Writing Scenarios After the Code

**What it looks like:** "Write the test first" is ignored. Scenarios are retrofitted to describe existing behavior.

**Why it's harmful:** Retrofitting scenarios produces coverage of what was built, not necessarily what was intended. It's also more expensive than writing scenarios first, because the implementation constrains what you can describe.

**Fix:** Include `.feature` file changes in every story's Definition of Done, before the PR is opened. Treat a PR that adds behavior without a feature file update as incomplete.

---

## Authoring Anti-Patterns

### Imperative Style (UI-Bound Scenarios)

**What it looks like:**

```gherkin
# Imperative — describes how, not what
Scenario: User logs in
  Given I navigate to "https://example.com/login"
  When I fill in "#email" with "alice@example.com"
  And I fill in "#password" with "password123"
  And I click "#submit-button"
  Then I see "Welcome, Alice"
```

**Why it's harmful:** Scenarios coupled to UI implementation details break every time the markup changes, even if the behavior is unchanged. Non-technical stakeholders can't read them.

**Fix:**

```gherkin
# Declarative — describes what, not how
Scenario: Authenticated user sees the dashboard
  Given Alice is logged in
  Then she sees the dashboard
```

See [Declarative vs. Imperative](declarative-vs-imperative.md) for the full treatment.

---

### Incidental Details

**What it looks like:**

```gherkin
Given I sign up as "Matt"
And my password is "password"
And my password confirmation is "password"
And I have deposited "$60" in my account
And I have deposited "$40" in my account
When I check my bank balance
Then my bank balance is "$100"
```

**Why it's harmful:** The password fields are irrelevant to the behavior under test (balance calculation). Including them makes the scenario longer, noisier, and harder to understand. It signals the scenario was written as a scripted manual test, not as a behavioral specification.

**Fix:** Include only the details that are essential to the behavior. The password is incidental — move it to a `Given Alice is logged in` step that handles authentication silently.

---

### Testing Several Rules at the Same Time

**What it looks like:** A single scenario that tests password validation AND balance checking AND UI layout.

**Why it's harmful:** When the scenario fails, you can't tell which rule was violated. It also makes the scenario unusable as documentation — a non-technical reader can't explain what the scenario is testing.

**Fix:** One scenario, one behavior. Extract each rule into its own scenario with a clear title.

---

### Conjunctive Steps

**What it looks like:**

```gherkin
Then I see the "Welcome User" message and the logout button
```

**Why it's harmful:** A conjunctive step is really two assertions. If the first fails, the second isn't checked. The failure message is ambiguous. The step can't be reused for either assertion independently.

**Fix:**

```gherkin
Then I see the "Welcome User" message
And the logout button is visible
```

---

### Then Steps That Don't Assert

**What it looks like:**

```gherkin
Then the record is saved
```

...where the step definition just calls `// TODO` or logs a message.

**Why it's harmful:** A `Then` step without an assertion is silent. The scenario passes regardless of application behavior. This is "green theater" — CI is green, but nothing is verified.

**Fix:** Every `Then` step must contain at least one `expect()` call. Failing that, it must throw an exception on mismatch.

---

### Given Steps That Are Really When Steps

**What it looks like:**

```gherkin
Given I submit the registration form
```

**Why it's harmful:** `Given` establishes context; `When` triggers an action. A form submission is an action. Misusing `Given` for actions makes the scenario's structure misleading and breaks the "Given → When → Then" mental model.

**Fix:** Reserve `Given` for state that already exists. Use `When` for user actions and system events.

---

### Scenario Outline Overuse

**What it looks like:** A Scenario Outline with 20 rows testing every combination of inputs, creating a slow combinatorial explosion.

**Why it's harmful:** Scenario Outlines are valuable for testing equivalence classes — a small set of representative inputs. Using them to enumerate every possible combination defeats the purpose of BDD as specification and produces a slow, expensive suite.

**Fix:** Use Scenario Outlines for 3–7 rows that represent distinct equivalence classes, not exhaustive permutations. Reserve combinatorial testing for unit tests or property-based tests.

---

### God Feature Files

**What it looks like:** `billing.feature` has 50 scenarios covering upgrades, downgrades, invoices, payment methods, trial periods, and refunds.

**Why it's harmful:** The feature file scope is too broad to serve as documentation for any single behavior. Step definitions for all these behaviors inevitably overlap, and changes to shared steps affect unrelated scenarios.

**Fix:** Split by behavior subtype. See [Organizing Feature Files](organization.md) for directory and Rule-based splitting strategies.

---

### Duplicate Step Definitions

**What it looks like:** Two step definition files each define `Given I am logged in as {string}` with different implementations, causing ambiguity errors or silent shadowing.

**Why it's harmful:** Cucumber/playwright-bdd throw an ambiguity error (correctly). If you suppress it with scope, you may silently use the wrong implementation.

**Fix:** Extract shared steps to `shared.steps.ts` and import once. Use scoped steps only when two areas genuinely need different behavior for the same phrase.

---

### Hard-Coded Magic Strings

**What it looks like:**

```gherkin
Given a user with ID "usr_1234abc" exists in the database
When I delete user "usr_1234abc"
```

**Why it's harmful:** The ID is meaningless to a non-technical reader, breaks if the seed data changes, and ties the scenario to a specific DB state.

**Fix:** Use named, descriptive references:

```gherkin
Given Alice's account exists
When I delete Alice's account
```

See [Named Test Data Catalog](named-test-data-catalog.md) for the Object Mother pattern.

---

### Shared Mutable State Between Scenarios

**What it looks like:** Scenario 1 creates a user; Scenario 2 assumes that user exists. Scenarios pass when run in order, fail when run in parallel or in a different order.

**Why it's harmful:** Test suite reliability degrades to "it depends on execution order." Parallel runs are impossible.

**Fix:** Every scenario must be fully self-contained. Each scenario creates its own state in `Given` steps or fixtures and cleans up in `After` hooks. See [Test Data Strategy](test-data-strategy.md) for cleanup patterns.

---

### No CI Enforcement

**What it looks like:** The BDD suite runs locally and on demand but is not part of the mandatory CI pipeline. PRs can merge with failing or undefined scenarios.

**Why it's harmful:** Without CI enforcement, the suite rots. Undefined steps accumulate. Step definitions that don't match feature files go undetected. The "living" in "living documentation" disappears.

**Fix:** Make the BDD suite a required CI check. Run `bddgen` dry-run as a pre-push hook to catch undefined steps before they reach CI. Fail the build on any undefined step.

```yaml
# .github/workflows/ci.yml
- name: Check undefined steps
  run: npx bddgen --dry-run
- name: Run BDD suite
  run: npx playwright test
```
