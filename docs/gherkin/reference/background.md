---
title: Background
description: The Background keyword — feature-level and rule-level scope, what belongs in Background, anti-patterns for overuse, and comparison with Before hooks.
sources:
  - web-cucumber-gherkin-reference-keywords
  - git-gherkin-best-practices-repo-readme-use-backgrounds-to-reduce-the-number-of-steps
  - web-testquality-best-practices-using-background-elements-effectively
  - web-given-bdd-seriously-object-mother-background
---

# Background

`Background` is a block of `Given` steps that runs before **every** scenario in its enclosing `Feature` or `Rule`. Use it to eliminate repeated setup that is common to all scenarios but would clutter each one individually.

## Syntax and Placement

```gherkin
Feature: Blog publishing

  Background:
    Given a global administrator named "Greg"
    And a blog named "Greg's anti-tax rants"
    And a user named "Dr. Bill"
    And a blog named "Expensive Therapy" owned by "Dr. Bill"

  Scenario: Blog owner posts to their own blog
    Given I am logged in as Dr. Bill
    When I try to post to "Expensive Therapy"
    Then I should see "Your article was published."

  Scenario: User tries to post to someone else's blog
    Given I am logged in as Dr. Bill
    When I try to post to "Greg's anti-tax rants"
    Then I should see "Hey! That's not your blog!"
```

The `Background` block is placed immediately before the first `Scenario` or `Rule` in the feature file, at the same indentation level as the scenarios. There can be only **one** `Background` per `Feature` (and one per `Rule`).

Background steps execute **after** any `Before` hooks and **before** each scenario's first step.

## Feature-Level vs. Rule-Level Scope

`Background` can appear at two levels:

### Feature-level Background

Applies to every scenario in the entire feature file, including scenarios inside `Rule` blocks.

```gherkin
Feature: Task management

  Background:
    Given the task service is running

  Scenario: Create a task
    When a task "Write docs" is created
    Then the task list contains "Write docs"

  Rule: Overdue tasks are flagged

    Scenario: Task past due date is flagged
      Given a task "Old report" due 2 days ago
      When the overdue check runs
      Then the task "Old report" is marked overdue
```

### Rule-level Background

Applies only to scenarios within that specific `Rule` block. When a Rule has its own Background and the Feature also has a Background, **both** execute — feature-level first, then rule-level.

```gherkin
Feature: Overdue task notifications

  Background:
    Given the notification service is available

  Rule: Users are notified about overdue tasks on first daily use

    Background:
      Given the user has overdue tasks

    Example: First use of the day triggers notification
      Given the user last used the app yesterday
      When the user opens the app
      Then the user is notified about overdue tasks

    Example: Repeated use the same day does not re-notify
      Given the user last used the app earlier today
      When the user opens the app
      Then no overdue notification is shown

  Rule: Completed tasks are never flagged as overdue

    Scenario: Completed task is not included in overdue check
      Given a task that was completed yesterday
      When the overdue check runs
      Then the task is not flagged
```

## What Belongs in Background

Background is correct for context that:

- **Applies to every scenario in the feature** — if even one scenario doesn't need it, it does not belong in Background.
- **Is genuinely incidental** — the scenario descriptions should make sense without reading the Background. If a scenario's meaning depends on what's in Background, the scenario title should hint at it.
- **Is concise** — 1 to 4 steps. More than 4 is a signal that the feature file is doing too much.

!!! example "Good Background: shared infrastructure state"
    ```gherkin
    Background:
      Given the payment gateway is available
      And the product catalog contains standard products
    ```
    These are infrastructure preconditions relevant to every scenario in a payment feature.

!!! warning "Anti-pattern: overcrowded Background"
    ```gherkin
    Background:
      Given I am on the login page
      And I fill in "Email" with "alice@example.com"
      And I fill in "Password" with "password123"
      And I click "Sign in"
      And I navigate to the account settings page
      And I click "Billing"
    ```
    This is an imperative UI walkthrough, not a shared precondition. Extract it into a single declarative step: `Given I am viewing my billing settings as alice@example.com`.

## Common Anti-Patterns

### Too Many Steps in Background

A Background with 5+ steps forces readers to scroll up and remember state before they can understand any scenario. Consolidate into higher-level steps backed by a step definition that calls helpers or fixtures.

### Steps That Don't Apply to Every Scenario

If even one scenario in a feature doesn't need a Background step, the step doesn't belong in Background. Use `Given` directly in the scenario, or split the feature file.

### Imperative UI Navigation in Background

Background steps should declare **state**, not **actions**. `Given I am on the billing page` is acceptable. `Given I click Settings, then Billing, then Payment Methods` is not — it leaks UI structure into the specification and breaks when the navigation changes.

### Vivid Names Help Readability

Use real, meaningful names in Background steps rather than generic identifiers:

```gherkin
# Generic (harder to follow)
Background:
  Given User A exists
  And User B exists
  And Blog 1 belongs to User A

# Vivid (better)
Background:
  Given a blogger named "Maria" with an active account
  And a reader named "Tom" with no subscription
```

The human brain tracks stories better than abstract labels. Named characters carry context across the scenarios that follow.

## Background vs. Before Hooks

Both `Background` and `Before` hooks run before each scenario, but they serve different purposes:

| | Background | Before Hook |
|--|------------|-------------|
| Location | Feature file (visible to business) | Step definition / support file (invisible to business) |
| Purpose | Domain-visible preconditions | Technical setup (auth tokens, DB seeding, mocks) |
| Appears in reports | Yes — as steps in the scenario trace | No — hooks appear only on failure |
| Tag filtering | No — runs for all scenarios in scope | Yes — `Before({ tags: '@admin' }, ...)` |
| Appropriate for | Setting up named domain objects | Resetting DB, configuring page fixtures, loading auth state |

!!! tip "Decision rule"
    If a business stakeholder reading the scenario needs to know about the precondition to understand the scenario's meaning, put it in Background. If it is pure technical infrastructure (resetting a database, loading a Playwright `storageState`), put it in a `Before` hook.

## playwright-bdd: Background in Generated Tests

playwright-bdd translates `Background` steps into Playwright `test.beforeEach()` calls in the generated `.spec.ts` file. You do not need to write `beforeEach` manually — the code generator handles the mapping.

```typescript
// Generated output (do not edit) — simplified illustration
test.beforeEach(async ({ page, fixtures }) => {
  // Background steps are inlined here
  await step('Given the payment gateway is available', ...);
  await step('And the product catalog contains standard products', ...);
});
```

## Cross-References

- [Rules](rules.md) — Rule-level Background and scope inheritance
- [Keywords](keywords.md) — Background in the full keyword reference
- [Feature Files](feature-files.md) — placement within the file structure
- [playwright-bdd Hooks](../../practice/playwright-bdd/writing-steps.md) — `Before`/`After` hook API
