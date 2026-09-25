---
title: Step Types — Given, When, Then, And, But, *
description: Semantics and ordering rules for all Gherkin step keywords, including conjunction steps, the asterisk wildcard, and common misuse anti-patterns.
sources:
  - web-cucumber-gherkin-reference-keywords
  - git-gherkin-best-practices-repo-readme-no-clear-separation-between-given-when-then
  - git-gherkin-best-practices-repo-readme-use-and-and-but-instead-of-repeating-the-same-keywo
  - git-gherkin-best-practices-repo-readme-avoid-using-conjunctive-steps
  - git-playwright-bdd-example-repo-agents-skills-playwright-bdd-skill-example-step-definition
---

# Step Types — Given, When, Then, And, But, *

Gherkin provides six step keywords. Five carry semantic meaning (`Given`, `When`, `Then`, `And`, `But`); one is a universal wildcard (`*`). Together they form the Given-When-Then structure that turns a scenario into a behavioral specification.

## The Ordering Contract

Scenarios follow a three-phase structure:

| Phase | Keyword | Temporal metaphor | Role |
|-------|---------|------------------|------|
| Context | `Given` | Past | Put the system in a known state |
| Action | `When` | Present | Trigger the event under test |
| Outcome | `Then` | Near future | Assert what the system did |

This ordering is a convention, not an enforced parser rule. The runner will execute steps in whatever order you write them. Treat the ordering contract as a readability discipline: readers scan the keyword column to understand the structure of a scenario instantly.

## Given — Establishing Context

`Given` steps describe the system state **before** the action happens. Think of them as preconditions or fixtures.

```gherkin
Given a user account exists for "alice@example.com"
Given the user has a balance of £100
Given the store has 5 units of "Wireless Headphones" in stock
```

The step definition behind a `Given` step typically seeds a database, creates objects, or configures the system. Avoid describing user interactions in `Given` steps — that is the role of `When`.

!!! tip "Prefer declarative Given steps"
    `Given I am logged in as an admin` is better than `Given I navigate to /login and enter credentials`. The second form is imperative; it exposes implementation details. The step definition handles navigation; the scenario declares intent.

## When — The Action

`When` steps describe the event or action that triggers the behavior under test. This is what the system (or user) does.

```gherkin
When the user requests a refund for order "ORD-001"
When the payment gateway returns a timeout
When the nightly billing job runs
```

There is typically only one `When` step per scenario. Multiple `When` steps are a sign that a scenario is testing more than one behavior — consider splitting it.

!!! note "The 1922 heuristic"
    When writing a `When` step, imagine it is 1922 — before computers. Can you describe the action without referencing UI elements or HTTP verbs? `When the customer returns the item` ages better than `When POST /api/returns is called with payload {...}`.

## Then — Asserting the Outcome

`Then` steps describe **observable** outcomes: what the user sees, what the system returns, what state is visible to an outside observer.

```gherkin
Then the order status is "Refunded"
Then the user receives a confirmation email
Then the account balance is £80
```

Step definitions behind `Then` steps should call assertions. Resist the temptation to query the database directly — prefer outcomes observable through the public interface (UI, API response, email).

!!! warning "Anti-pattern: Then steps that do not assert"
    A `Then` step that only navigates or triggers another action is a misuse of the keyword. If your `Then` does not contain an assertion, rename it to `When` and add a real assertion step.

## And and But — Continuation Steps

When a phase requires multiple steps, use `And` and `But` instead of repeating the same primary keyword:

```gherkin
# Repetitive (avoid)
Given the account is active
Given the user has admin role
Given the two-factor authentication is disabled

# Fluent (preferred)
Given the account is active
And the user has admin role
And two-factor authentication is disabled
```

`But` is semantically identical to `And`. Use it when the continuation step expresses a negative condition, which reads more naturally:

```gherkin
Then the dashboard is displayed
And the welcome banner shows "Hello, Alice"
But the billing section is not visible
```

## The * Wildcard

`*` (asterisk) acts as whichever keyword the previous step used. It is useful when a list of similar items makes repeated `And` phrasing feel mechanical:

```gherkin
Scenario: Report covers all active regions
  Given the following regions are active:
  * North America
  * Europe
  * Asia-Pacific
  When the global report is generated
  Then all 3 regions appear in the summary
```

!!! tip "Use * sparingly"
    `*` improves readability for bullet-list-style context setup. It becomes confusing in mixed-phase sections where the "current keyword" is ambiguous at a glance.

## Conjunction Steps (Anti-Pattern)

A conjunction step embeds two actions in a single step using "and":

```gherkin
# Anti-pattern
Then I see the "Welcome" message and the logout button
```

Break it into two steps:

```gherkin
Then I see the "Welcome" message
And the logout button is visible
```

Conjunction steps reduce reusability — the combined step cannot be reused alone — and make the scenario harder to diagnose when it fails.

## Multiple Step Aliases (Same Step Definition)

A single step definition can match multiple step texts. In playwright-bdd with `createBdd()`, register the same function under multiple aliases:

```typescript
import { createBdd } from 'playwright-bdd';

const { Given, When, Then } = createBdd(test);

// Two aliases for the same action
Given('the user is logged in as {string}', async ({ page }, role: string) => {
  await page.goto(`/auth/login?role=${role}`);
  await page.getByRole('button', { name: 'Sign in' }).click();
});

// In feature files, both of these now match the same step def:
// Given the user is logged in as "admin"
// Given the user is logged in as "viewer"
```

This works because step matching is text-based, not keyword-based. The `Given` keyword in the step definition registration is irrelevant to matching — only the text pattern matters.

## Step Keyword Rules Summary

| Rule | Rationale |
|------|-----------|
| One `When` per scenario (ideal) | Multiple triggers = multiple scenarios |
| `Given` steps should not describe interactions | Interactions belong in `When` |
| `Then` steps must contain assertions | Else they are `When` steps in disguise |
| Use `And`/`But` for continuation | Avoids repeated primary keyword noise |
| Do not rely on keywords to disambiguate step text | The runner ignores keywords during matching |

## Cross-References

- [Keywords](keywords.md) — full keyword table including aliases
- [Scenario Outline](scenario-outline.md) — step parameterization with `<placeholder>`
- [Background](background.md) — shared `Given` steps across all scenarios
- [Anti-Patterns](../best-practices/anti-patterns.md) — full catalogue of step misuse patterns
