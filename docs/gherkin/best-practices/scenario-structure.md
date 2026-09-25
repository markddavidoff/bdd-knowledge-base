---
title: Scenario Structure
description: Rules for shaping well-formed Gherkin scenarios — atomicity, independence, step counts, meaningful titles, and common structural anti-patterns.
sources:
  - web-automation-panda-writing-good-gherkin-proper-behavior
  - web-automation-panda-writing-good-gherkin-good-titles
  - web-automation-panda-writing-good-gherkin-less-is-more
  - git-gherkin-best-practices-repo-readme-avoid-using-conjunctive-steps
  - git-gherkin-best-practices-repo-readme-make-scenarios-independent-and-deterministic
  - git-gherkin-best-practices-repo-readme-limit-the-number-of-steps-per-scenario
  - git-gherkin-best-practices-repo-readme-avoid-testing-several-rules-at-the-same-time
  - git-gherkin-best-practices-repo-readme-add-good-scenario-descriptions
---

# Scenario Structure

A well-structured scenario is atomic, independent, and reads like a sentence. This page covers the structural rules that govern a single scenario — how many steps, how to title it, what belongs in each step type, and what to avoid.

## The Cardinal Rule: One Behavior Per Scenario

> **One scenario covers one behavior.**

A behavior is a single When-Then pair: one triggering action and one outcome assertion. Multiple When-Then pairs in a single scenario indicate multiple behaviors, and they should be split.

```gherkin
# BAD — two behaviors in one scenario
Scenario: Search and then filter results
  Given a web browser is at the Google home page
  When the user enters "panda" into the search bar
  Then links related to "panda" are shown
  When the user clicks on the "Images" link
  Then images related to "panda" are shown
```

```gherkin
# GOOD — two atomic scenarios
Scenario: Search from the search bar
  Given a web browser is at the Google home page
  When the user enters "panda" into the search bar
  Then links related to "panda" are shown on the results page

Scenario: Filter search results to images
  Given search results for "panda" are shown
  When the user filters by Images
  Then images related to "panda" are shown on the results page
```

The second scenario's Given step declares the state it needs declaratively without re-running the first scenario's steps. This is the correct pattern for sequential behaviors: each scenario sets up its own context independently.

## Scenario Independence

Scenarios must not depend on each other's state. There must be no ordering dependency between scenarios — any scenario must be runnable in isolation and in any order, including in parallel.

```gherkin
# BAD — scenario 2 depends on scenario 1 having run
Scenario: Create a user account
  When a new account is registered for "alice@example.com"
  Then the account is active

Scenario: Log in to the created account
  When "alice@example.com" logs in with their password
  Then the dashboard is displayed
```

The second scenario silently requires the first to have inserted a database row. If execution order changes or scenarios run in parallel, it fails non-deterministically.

Fix: make each scenario self-contained by establishing all required state in the Given steps.

```gherkin
Scenario: Log in to an existing account
  Given an active account exists for "alice@example.com"
  When she logs in with her password
  Then the dashboard is displayed
```

!!! note "Worker fixtures and shared state"
    In playwright-bdd, expensive state (seeded databases, authentication tokens) can be shared via worker-scoped fixtures without creating scenario ordering dependencies. The fixture runs once per worker and provides a known state to each scenario independently. See [Test Isolation](../../practice/playwright-bdd/test-isolation.md).

## The 5-Step Heuristic

Aim for scenarios under five steps (not counting `And`/`But`). A single-digit step count is the target; more than eight steps is a warning sign.

Long scenarios are almost always caused by one of three problems:

1. **Imperative style** — UI mechanics inflating the step count. Fix: raise the altitude. See [Declarative vs. Imperative](declarative-vs-imperative.md).
2. **Multiple behaviors** — the scenario is doing too much. Fix: split it.
3. **Incidental detail** — setup information that is not relevant to the behavior. Fix: push setup into Given step definitions or fixtures.

## Meaningful Titles

The scenario title is a one-line behavioral specification. It must communicate what behavior is being described without reading the steps.

```gherkin
# BAD titles — too vague or procedure-focused
Scenario: Test login
Scenario: User does stuff on the dashboard
Scenario: Check the error message

# GOOD titles — behavior-specific
Scenario: Subscriber sees their current usage on the dashboard
Scenario: Login attempt with an expired password prompts a reset
Scenario: Guest user is redirected to login when accessing a protected page
```

Good titles:
- State the actor (who), the action or condition (what), and the outcome (result)
- Use domain vocabulary, not UI vocabulary
- Are unique within their feature file — duplicate titles indicate duplicate scenarios

!!! tip "Title format as a test"
    A title that reads like "Test X" or "Check Y" is almost certainly too vague. Replace with a complete behavioral statement: "[Actor] [does something] [in context] / [outcome]."

## Context-Action-Outcome Clarity

Each keyword has a semantic role that must be respected:

| Keyword | Role | Tense / form |
|---|---|---|
| `Given` | Establish state — preconditions | Present state: "Alice **is** a Pro subscriber" |
| `When` | Trigger a behavior | Present action: "she **requests** an invoice" |
| `Then` | Assert an outcome | Present result: "an invoice **is sent** to her email" |

**Given steps must not contain actions.** `Given the user navigates to the login page` is wrong — it is a When in disguise. The correct form is `Given the login page is displayed`, which establishes state without describing an action.

**Then steps must assert.** A Then that calls an action without asserting anything is incorrect. Verify that every Then step has an observable, checkable outcome.

**Negation in Given is a smell.** `Given I am not logged in` is technically valid but typically reflects the absence of setup rather than an explicit state. Prefer positive preconditions: `Given I am an unauthenticated guest`.

## Avoiding Conjunctive Steps

Steps joined with "and" in a single step line are conjunctive steps, and they reduce reusability:

```gherkin
# BAD — conjunctive Then
Then I see the "Welcome" message and the logout button is visible
```

Split into two assertions:

```gherkin
Then I see the "Welcome" message
And the logout button is visible
```

Each assertion is now independently reusable and independently reportable in test results. A failing test tells you exactly which assertion failed.

The same rule applies to When steps with multiple actions:

```gherkin
# BAD — conjunctive When
When the user fills in the form and clicks Submit

# GOOD — or better yet, declarative
When the user submits the registration form
```

## Symmetry Between Given and Then

The Given and Then steps of a scenario should address the same domain concepts. If you set up `a Pro subscription` in the Given, the Then should assert something about `Pro-tier access` or `the subscription status` — not about an unrelated part of the system.

Asymmetry is often a sign that the scenario is testing more than one behavior, or that setup includes state the scenario does not actually exercise.

## Avoiding Incidental Detail

Incidental detail is information in the Gherkin that is required for the step definitions to work but is not relevant to the behavior being described.

```gherkin
# Incidental detail in Given
Given a user "alice@example.com" exists with password "C0rrectH0rse" and role "admin" and created_at "2024-01-01"
```

The email, password, date, and role are all implementation details of the user fixture, not behavioral distinctions. A named persona hides this noise:

```gherkin
Given Alice is an admin user
```

The step definition creates Alice with all necessary attributes. The Gherkin records only what is behaviorally relevant.

## Good vs. Bad Scenario Structure — Full Example

```gherkin
Feature: Invoicing

  # BAD — long, imperative, multiple behaviors, incidental detail
  Scenario: Invoice test
    Given I navigate to "/login"
    And I fill in "email" with "admin@acme.com"
    And I fill in "password" with "secret123"
    And I click "Login"
    When I navigate to "/billing/invoices"
    And I click "Generate Invoice"
    Then I see "Invoice generated" on the page
    And the page title is "Invoices - Acme"

  # GOOD — declarative, atomic, well-titled
  Scenario: Billing admin generates an invoice for the current period
    Given Alice is logged in as the billing admin for Acme
    And the current billing period has ended
    When she generates an invoice
    Then an invoice is created for the current period
    And Alice receives the invoice by email
```

## Cross-References

- [Declarative vs. Imperative](declarative-vs-imperative.md) — how to eliminate imperative steps that inflate scenarios
- [Step Definitions](step-definitions.md) — how to phrase individual steps within a well-structured scenario
- [Anti-Patterns](anti-patterns.md) — conjunctive steps, shared mutable state, God features
- [Scenario Outline](../reference/scenario-outline.md) — when to parameterize instead of duplicating structure
