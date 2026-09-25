---
title: Rule
description: The Rule keyword (Gherkin 6+) — grouping scenarios by business rule, Rule-level Background, scope inheritance, and when to use Rule vs. restructuring feature files.
sources:
  - web-cucumber-gherkin-reference-keywords
  - git-gherkin-parser-testdata-good-tags-feature-rule
  - web-cucumber-antipatterns-1-testing-several-rules-at-the-same-time
---

# Rule

The `Rule` keyword (introduced in Gherkin 6) groups related scenarios under a named business rule within a `Feature`. It provides a middle level of organization between the Feature and its individual Scenarios, without requiring a separate feature file.

## Syntax

```gherkin
Feature: Highlander immortality rules

  Rule: There can be only One

    Example: More than one immortal alive — battle commences
      Given there are 3 immortals alive
      When 2 immortals meet
      Then they will fight to the death
      And there is one fewer immortal

    Example: Only one immortal remains
      Given there is only 1 immortal alive
      Then they will live forever

  Rule: The Prize is granted to the last survivor

    Example: Last survivor claims the Prize
      Given there is 1 immortal alive
      And all others have been defeated
      Then the immortal receives the Prize
```

A `Rule` block can contain:

- A description block (free-form text, same as Feature descriptions)
- A `Background` section
- Any number of `Scenario`, `Example`, or `Scenario Outline` blocks

## When to Use Rule

Use `Rule` when a single feature has **multiple distinct business rules**, each with its own set of illustrating examples, and those rules are too related to split into separate feature files.

**Good fit for `Rule`:**

- A checkout feature with separate rules for discount application, shipping calculation, and payment validation
- An access control feature with separate rules for each user role
- A billing feature with rules for plan upgrades, downgrades, and cancellation

**Overkill — prefer a flat scenario list:**

- Features with 2–4 scenarios that cover a single coherent behavior
- Cases where adding a `Rule` header would just repeat the Feature title in different words

!!! tip "The litmus test"
    If you find yourself writing comments like `# -- Happy path scenarios --` and `# -- Error scenarios --` to group scenarios within a feature, consider replacing those comments with `Rule:` blocks.

## Rule + Background Pattern

`Rule` unlocks a powerful pattern: a Background scoped to a specific rule. This avoids polluting the feature-level Background with context that only a subset of scenarios needs.

```gherkin
Feature: Overdue task notifications

  Background:
    Given the notification service is available

  Rule: Users are notified about overdue tasks on first daily login

    Background:
      Given the user has overdue tasks

    Example: First login of the day shows notification
      Given the user last logged in yesterday
      When the user logs in
      Then a notification banner shows "You have overdue tasks"

    Example: Second login the same day does not repeat notification
      Given the user already logged in today
      When the user logs in again
      Then no notification banner is shown

  Rule: Completed tasks are never flagged as overdue

    Example: Completed task is excluded from overdue check
      Given a task "Write report" completed yesterday
      When the overdue check runs
      Then "Write report" does not appear in overdue notifications
```

### Background Inheritance

When both a Feature-level and a Rule-level `Background` exist, **both** run — Feature-level first, then Rule-level. This composes naturally:

- Feature Background: `Given the notification service is available` (applies to all scenarios)
- Rule Background: `Given the user has overdue tasks` (applies only to scenarios in that Rule)

The net effect for scenarios inside the Rule is:

1. Feature Background steps
2. Rule Background steps
3. The scenario's own steps

## Rule Scope

A `Rule` does not create isolation between scenarios. Scenarios inside a `Rule` are still executed independently (in random order when parallelism is enabled). `Rule` is organizational, not a grouping mechanism for shared execution state.

Tags placed on a `Rule` are inherited by all scenarios within it:

```gherkin
@billing
Feature: Plan management

  @happy-path
  Rule: Users can upgrade their plan at any time

    @smoke
    Example: Upgrade from free to pro
      Given a user on the free plan
      When the user upgrades to pro
      Then the user has pro-level access

    Example: Upgrade from pro to enterprise
      Given a user on the pro plan
      When the user upgrades to enterprise
      Then the user has enterprise-level access
```

In the example above:
- The "Upgrade from free to pro" scenario carries tags: `@billing`, `@happy-path`, `@smoke`
- The "Upgrade from pro to enterprise" scenario carries tags: `@billing`, `@happy-path`

## Rule Descriptions

Like `Feature`, a `Rule` can have a free-form description block. Use it to explain the business rationale for the rule, reference policies, or note exceptions:

```gherkin
Rule: Refunds are only permitted within 30 days of purchase

  This policy applies to all digital products. Physical products
  follow a separate 60-day return window governed by the returns feature.
  See: Refund Policy v2.3 (internal wiki link).

  Example: Refund within the 30-day window is approved
    Given a purchase made 15 days ago
    When the customer requests a refund
    Then the refund is approved

  Example: Refund after 30 days is rejected
    Given a purchase made 45 days ago
    When the customer requests a refund
    Then the refund is rejected with "Outside return window"
```

## Rule vs. Restructuring into Multiple Feature Files

| Situation | Use `Rule` | Split into Files |
|-----------|-----------|-----------------|
| Rules are closely related; same domain, same team | Yes | No |
| Rules are tested by different teams or CI jobs | No | Yes |
| Feature file exceeds ~8–10 scenarios | Consider | Yes |
| Rules need separate reporting or tag suites | No | Yes |

!!! warning "God features"
    A `Feature` with many `Rule` blocks may indicate that the feature is doing too much. If the feature file exceeds 200 lines or ~12 scenarios, evaluate whether the rules belong in separate feature files under domain-organized directories.

## Complete Example: Feature with Multiple Rules

```gherkin
Feature: User account access control

  As a platform administrator
  I want fine-grained access control per user role
  So that data is accessible only to authorized users

  Background:
    Given the authorization service is running

  Rule: Guests can only view public content

    Example: Guest views public landing page
      Given an unauthenticated visitor
      When the visitor loads the home page
      Then the page is displayed without login prompt

    Example: Guest is redirected when accessing protected route
      Given an unauthenticated visitor
      When the visitor navigates to "/dashboard"
      Then the visitor is redirected to the login page

  Rule: Standard users access their own data only

    Background:
      Given a standard user "alice" is logged in

    Example: Alice views her own profile
      When Alice views the profile page for "alice"
      Then the full profile is displayed

    Example: Alice cannot view another user's private data
      When Alice views the profile page for "bob"
      Then access is denied with status 403

  Rule: Administrators can access all user data

    Background:
      Given an administrator "admin-carol" is logged in

    Example: Admin views any user's profile
      When admin-carol views the profile page for "alice"
      Then the full profile is displayed

    @audit
    Example: Admin access is logged
      When admin-carol views the profile page for "alice"
      Then an audit log entry is created for the access
```

## Cross-References

- [Background](background.md) — Rule-level Background and scope details
- [Keywords](keywords.md) — full keyword table with Gherkin version notes
- [Feature Files](feature-files.md) — Feature-level organization and file structure
- [Tags — Classification](tags-classification.md) — tag inheritance from Rule blocks
