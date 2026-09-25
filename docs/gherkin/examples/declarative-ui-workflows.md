---
title: Declarative UI Workflows — Gherkin Examples
description: High-altitude Gherkin for e-commerce checkout and multi-step wizard flows, contrasted with the imperative version to show what declarative means in practice.
sources:
  - web-itsadeliverything-declarative-imperative-imperative-style-of-gherkin-scenarios
  - web-itsadeliverything-declarative-imperative-declarative-style-of-gherkin-scenarios
  - git-gherkin-best-practices-repo-readme-write-declarative-features-instead-of-imperative-fe
  - web-testquality-best-practices-practical-gherkin-implementation-case-examples
  - web-automation-panda-writing-good-gherkin-phrasing-steps
---

# Declarative UI Workflows — Gherkin Examples

UI workflows are where the declarative vs. imperative distinction matters most. Every click, form fill, and page navigation is a potential maintenance burden. Declarative steps compress multi-step UI mechanics into a single step phrase, making the scenario stable across UI redesigns.

## The Imperative Version (What to Avoid)

A checkout flow written imperatively:

```gherkin
# BAD — imperative UI workflow. Do not copy.
Scenario: Customer completes a purchase
  Given I am on the home page
  When I click "Shop" in the navigation bar
  And I click on the product "Bluetooth Headphones"
  And I click "Add to Cart"
  And I click the cart icon in the top right
  And I click "Proceed to Checkout"
  And I fill in "First Name" with "Alice"
  And I fill in "Last Name" with "Smith"
  And I fill in "Address" with "123 Main St"
  And I fill in "City" with "Springfield"
  And I select "IL" from "State"
  And I fill in "ZIP" with "62701"
  And I fill in "Card Number" with "4111111111111111"
  And I fill in "Expiry" with "12/27"
  And I fill in "CVV" with "123"
  And I click "Place Order"
  Then I see "Order Confirmed"
```

Seventeen steps. The first twelve have nothing to do with the business rule being verified — they are navigation mechanics. A UI redesign that moves the cart icon will break this scenario even though the purchase flow itself is unchanged.

---

## The Declarative Version

```gherkin
@checkout @smoke
Feature: E-commerce purchase flow
  Customers can browse products and complete purchases using saved payment methods.

  Scenario: A customer completes a purchase with a saved payment method
    Given a registered customer named "Alice" with a saved payment method
    And the catalog contains the product "Bluetooth Headphones" priced at $89.99
    When Alice adds "Bluetooth Headphones" to her cart
    And Alice completes checkout
    Then Alice receives an order confirmation
    And Alice's order history includes "Bluetooth Headphones"
    And Alice's saved payment method was charged $89.99
```

Eight steps instead of seventeen. The step definition for "Alice completes checkout" drives the full checkout form — shipping address, payment selection, and order submission. If the checkout form gains a phone number field, only the step definition changes.

---

## Checkout — Multiple Scenarios

```gherkin
@checkout
Feature: E-commerce purchase flow
  Customers can browse products and complete purchases.

  Background:
    Given a registered customer named "Alice"
    And the catalog contains the product "Bluetooth Headphones" priced at $89.99

  @smoke @happy-path
  Scenario: A customer completes a purchase with a saved payment method
    Given Alice has a saved payment method
    When Alice adds "Bluetooth Headphones" to her cart
    And Alice completes checkout
    Then Alice receives an order confirmation

  @happy-path
  Scenario: A customer completes a purchase with a new card
    When Alice adds "Bluetooth Headphones" to her cart
    And Alice completes checkout with a new Visa card
    Then Alice receives an order confirmation

  @error-path
  Scenario: Checkout fails when the cart is empty
    When Alice attempts to begin checkout with an empty cart
    Then checkout is blocked
    And Alice sees the message "Your cart is empty"

  @error-path
  Scenario: Checkout fails when the payment is declined
    Given Alice has a payment method that will be declined
    When Alice adds "Bluetooth Headphones" to her cart
    And Alice completes checkout
    Then checkout fails at the payment step
    And Alice sees the message "Your payment was declined"
    And Alice's order is not placed
```

---

## Multi-Step Wizard

Onboarding wizards and multi-step forms are another common UI pattern. High-altitude steps name the wizard stage, not the individual fields within it.

```gherkin
@onboarding @smoke
Feature: Organization onboarding wizard
  New accounts complete a multi-step onboarding to configure their workspace.

  Scenario: An admin completes the full onboarding wizard
    Given a new organization account for "Acme Corp"
    And Carol is the admin for "Acme Corp"
    When Carol completes the workspace setup step
    And Carol completes the team invitations step
    And Carol completes the billing setup step
    Then "Acme Corp" is fully onboarded
    And Carol is taken to the main dashboard
    And Carol sees the onboarding completion message

  Scenario: An admin skips optional onboarding steps
    Given a new organization account for "Acme Corp"
    And Carol is the admin for "Acme Corp"
    When Carol completes the workspace setup step
    And Carol skips the team invitations step
    And Carol completes the billing setup step
    Then "Acme Corp" is fully onboarded
    And Carol can invite team members later from Settings
```

Each "step" in the wizard is a single Gherkin step. The step definition drives the form within that wizard stage. The feature file reads like a business process description, not a UI test script.

---

## Step Naming Heuristic

When writing UI workflow steps, apply the "1922 rule" from the Cucumber documentation: imagine the feature existed in 1922, before computers. Would the step make sense?

| Imperative (fail the 1922 test) | Declarative (pass) |
|---|---|
| `When I click the "Add to Cart" button` | `When Alice adds "Headphones" to her cart` |
| `When I navigate to /checkout` | `When Alice proceeds to checkout` |
| `When I fill in "Card Number" with "4111..."` | `When Alice pays with her saved Visa card` |
| `Then the URL is /order-confirmation` | `Then Alice receives an order confirmation` |

!!! example "The 1922 rule"
    In 1922 you could still "add an item to a cart" at a physical store, "proceed to checkout" at a cash register, and "receive an order confirmation" in the mail. You could not "click a button" or "navigate to a URL." If the step phrase requires a computer to parse, it is probably too imperative.

For the TypeScript step definitions using Page Object Models (POM) that back declarative UI steps, see [Declarative UI Workflows (TypeScript)](../../practice/examples/declarative-ui-workflows.md).
