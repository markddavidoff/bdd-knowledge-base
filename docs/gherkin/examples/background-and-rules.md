---
title: Background and Rules — Gherkin Examples
description: Feature file with two Rule blocks, each with its own scoped Background, showing how Background scoping works at the Rule level.
sources:
  - web-cucumber-gherkin-reference-keywords
  - git-gherkin-best-practices-repo-readme-use-backgrounds-to-reduce-the-number-of-steps
  - git-gherkin-best-practices-repo-readme-avoid-testing-several-rules-at-the-same-time
---

# Background and Rules — Gherkin Examples

`Rule` (introduced in Gherkin 6) groups scenarios that test the same business rule. Critically, each `Rule` block can have its own `Background`, which only applies to scenarios within that rule. This solves the problem of having wildly different setups for different behavioral subsets within one feature file.

## Background Scoping

Without `Rule`, there is one `Background` per feature, which must serve all scenarios equally:

```gherkin
Feature: Content access

  Background:
    # This runs before EVERY scenario in the feature
    Given a registered user named "Alice"

  Scenario: Free subscribers see free articles
    ...

  Scenario: Paid subscribers see all articles
    ...
```

With `Rule`, each business rule gets its own pre-scenario context:

```gherkin
Feature: Content access

  Rule: Free subscribers see only free articles
    Background:
      # Runs before every scenario within this Rule only
      Given Alice has a free subscription

    Scenario: ...

  Rule: Paid subscribers see all articles
    Background:
      # Different setup — only runs for scenarios in this Rule
      Given Alice has a paid subscription

    Scenario: ...
```

---

## Full Example — Subscription-Based Content Access

```gherkin
@content @subscriptions
Feature: Content access by subscription tier
  Article visibility depends on the subscriber's plan.
  Free subscribers access free articles only.
  Paid subscribers access all articles.

  Rule: Free subscribers can only read free articles

    Background:
      Given a registered user named "Alice" with a free subscription
      And the content catalog contains:
        | title                      | tier  |
        | Intro to BDD               | free  |
        | Advanced Testing Patterns  | paid  |

    @smoke @happy-path
    Scenario: A free subscriber reads a free article
      When Alice reads the article "Intro to BDD"
      Then Alice sees the full article content

    @error-path
    Scenario: A free subscriber is blocked from a paid article
      When Alice attempts to read the article "Advanced Testing Patterns"
      Then Alice is shown a preview of the first paragraph
      And Alice sees the message "Upgrade to access this article"
      And Alice is shown the Pro plan upgrade offer

  Rule: Paid subscribers can read all articles

    Background:
      Given a registered user named "Alice" with a paid subscription
      And the content catalog contains:
        | title                      | tier  |
        | Intro to BDD               | free  |
        | Advanced Testing Patterns  | paid  |

    @smoke @happy-path
    Scenario: A paid subscriber reads a paid article
      When Alice reads the article "Advanced Testing Patterns"
      Then Alice sees the full article content

    Scenario: A paid subscriber can also read free articles
      When Alice reads the article "Intro to BDD"
      Then Alice sees the full article content
```

Note that both rules share the same catalog setup in their `Background`. This is fine — `Background` runs before each scenario within the rule, so each test starts with a clean known state.

---

## Full Example — Order Fulfillment Rules

A more complex example with two unrelated business rules in one feature:

```gherkin
@orders
Feature: Order fulfillment
  Orders are fulfilled based on stock availability and shipping preferences.

  Rule: In-stock orders ship within 24 hours

    Background:
      Given a customer named "Alice"
      And a product "Widget" with 10 units in stock

    @smoke
    Scenario: An in-stock order is queued for same-day dispatch
      When Alice places an order for 1 unit of "Widget"
      Then the order status is "processing"
      And the estimated dispatch date is today

    Scenario: An order for multiple in-stock units ships together
      When Alice places an order for 5 units of "Widget"
      Then the order status is "processing"
      And the order ships as a single shipment

  Rule: Back-ordered items extend the fulfillment timeline

    Background:
      Given a customer named "Alice"
      And a product "Gadget" with 0 units in stock
      And "Gadget" has a restock date of next Monday

    Scenario: A back-ordered item shows the restock date as estimated ship date
      When Alice places an order for 1 unit of "Gadget"
      Then the order status is "back-ordered"
      And the estimated dispatch date is next Monday
      And Alice receives a back-order confirmation email

    @error-path
    Scenario: Ordering more units than will restock is not permitted
      Given "Gadget" will restock with only 3 units
      When Alice attempts to place an order for 5 units of "Gadget"
      Then the order is rejected
      And Alice sees the message "Only 3 units will be available at restock"
```

---

## When to Use Rule vs. Separate Feature Files

| Situation | Use |
|-----------|-----|
| Two distinct business rules about the same capability | `Rule` within one feature file |
| Two completely different capabilities | Separate `.feature` files |
| One rule needs a very different setup from another | `Rule` with separate `Background` blocks |
| Rules have 8+ scenarios each | Split into separate files to keep file size manageable |

!!! tip "Rule descriptions"
    The text after `Rule:` is a free-form business rule statement, not a scenario name. Write it as a business rule: "Free subscribers can only read free articles" — not as a test label: "Free subscriber content access tests".

!!! warning "One Background per scope"
    You can have one `Background` per `Feature` and one per `Rule`. If you need a `Feature`-level Background and a `Rule`-level Background in the same feature, the `Feature`-level Background runs first, then the `Rule`-level Background, before each scenario in that rule.

For the step definitions that implement these scenarios, see [Background and Rules (TypeScript)](../../gherkin/examples/background-and-rules.md). For error-path scenarios across all domain areas, see [Error Handling](error-handling.md).
