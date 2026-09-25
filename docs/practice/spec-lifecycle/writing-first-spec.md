---
title: Writing Your First Spec
description: How to write a first BDD feature file starting from a user story, splitting it into scenarios, drafting in plain language, and performing a Three Amigos review.
sources:
  - web-automation-panda-writing-good-gherkin-proper-behavior
  - web-automation-panda-writing-good-gherkin-style-and-structure
  - web-cucumber-antipatterns-1-writing-the-scenario-after-you-ve-written-the-code
  - git-gherkin-best-practices-repo-readme-write-the-scenario-before-writing-the-code
  - web-testquality-best-practices-maintaining-consistency-in-gherkin-syntax
---

# Writing Your First Spec

The most important rule in BDD: **write the scenario before writing the code**. Scenarios are tests of your shared understanding of the problem domain. Once everyone agrees on the Gherkin, you have permission to start implementing.

## Start From a User Story

Use a Connextra-format story as your entry point:

```
As a registered customer
I want to place an order for an item in my cart
So that the item is shipped to my address
```

A story is not a scenario. One story typically covers several distinct behaviors. Your job in the first spec session is to discover those behaviors, not to automate them.

## Split the Story Into Scenarios

Ask the question: "What are the different ways this story can go?" For the order story above:

- Happy path: order placed successfully, confirmation shown
- Out-of-stock item: order rejected with a clear message
- Invalid payment: order rejected, inventory not decremented
- Duplicate submission: second request is idempotent

Each outcome is a separate scenario. The Cardinal Rule of BDD is **one scenario, one behavior**. Resist the urge to combine multiple When-Then pairs into one scenario — that is a procedure-driven test disguised as a spec.

## Draft in Plain Language First

Before opening your editor, write the scenarios in plain English sentences. No keywords, no Gherkin structure yet:

```
Setup: a registered customer with one item in their cart and a valid payment method on file

Action: the customer places the order

Expected: the order appears in the customer's order history with status "confirmed" and the item inventory decreases by one
```

This plain-language draft surfaces vocabulary disagreements early. "Confirmed" vs. "Placed" vs. "Accepted" — the team decides which term maps to the domain before it gets baked into step text.

## Three Amigos Review

The Three Amigos is the pre-implementation review. The three perspectives are:

- **Product/Business**: Does this scenario describe the right behavior? Are the examples realistic?
- **Development**: Is this implementable? Are the preconditions achievable in the test environment?
- **Quality/Testing**: What edge cases are missing? Can this scenario be automated as written?

Run the Three Amigos _before_ anyone writes step definitions. The output is an agreed feature file, not an assignment to automate something already built. Writing scenarios after the code is an anti-pattern — it skips the collaboration that makes BDD valuable.

## Convert to Gherkin

Now translate the plain-language draft into Gherkin. Use declarative steps that describe outcomes, not mechanism:

```gherkin
Feature: Order placement
  As a registered customer
  I want to place an order for items in my cart
  So that items are shipped to my address

  Background:
    Given I am a registered customer
    And I have a valid payment method on file

  Scenario: Successful order from a single in-stock item
    Given my cart contains "Wireless Keyboard" with quantity 1
    When I place the order
    Then my order history shows "Wireless Keyboard" with status "confirmed"
    And the available inventory for "Wireless Keyboard" decreases by 1

  Scenario: Order rejected when item is out of stock
    Given my cart contains "Wireless Keyboard" with quantity 1
    And "Wireless Keyboard" has no available inventory
    When I place the order
    Then I see the message "Item is no longer available"
    And my order history is unchanged
```

!!! tip "Declarative wins"
    "When I place the order" — not "When I click the Place Order button" and not "When I POST to /api/orders". The mechanism is in the step definition, not in the Gherkin.

## Vocabulary Choices That Last

Vocabulary chosen now becomes load-bearing. Step text is shared across the team and referenced in PRs, reports, and conversations.

- Prefer the domain term used by the business, not the UI label or the API endpoint name
- Pick a single verb for each action and stick to it ("place an order" not "submit an order" or "checkout")
- Names like "Wireless Keyboard" or user personas like "Alice" are Object Mother entries — they imply specific pre-configured state
- Document ambiguous terms in a team glossary before committing to them

## The First Feature File Checklist

Before merging the first feature file for a story:

- [ ] Scenario titles are complete sentences describing a behavior, not a test case number
- [ ] Each scenario has exactly one `When` step
- [ ] `Given` steps establish state only — no actions
- [ ] `Then` steps assert outcomes — no side effects
- [ ] No bare URLs, raw SQL, or HTML element selectors in any step text
- [ ] The vocabulary matches the domain terms used by the product team
- [ ] At least one Three Amigos review has happened before any step definitions are written
- [ ] The feature file has been committed alongside a corresponding ticket/story reference

!!! warning "The premature automation trap"
    The most common mistake is writing the scenario _after_ the feature is built, then retrofitting step definitions. This defeats the collaboration purpose and produces scenarios that describe the implementation rather than the behavior.

## Cross-references

- [Iteration Guidelines](iteration-guidelines.md) — when to modify or delete a scenario
- [BDD Without a Browser](bdd-without-browser.md) — applying this process to API-only services
- [Gherkin Best Practices: Declarative vs. Imperative](../../gherkin/best-practices/)
