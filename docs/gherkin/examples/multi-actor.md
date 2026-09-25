---
title: Multi-Actor Scenarios — Gherkin Examples
description: Gherkin scenarios involving two actors (admin and customer) in one scenario, showing the multi-context pattern and coordinated shared state.
sources:
  - git-gherkin-best-practices-repo-readme-define-the-actor-that-will-use-the-system
  - web-cucumber-gherkin-reference-keywords
  - web-itsadeliverything-declarative-imperative-declarative-style-of-gherkin-scenarios
  - git-gherkin-best-practices-repo-readme-make-scenarios-independent-and-deterministic
---

# Multi-Actor Scenarios — Gherkin Examples

Some behaviors only exist in the interaction between two actors. An admin must see what a customer did. A customer's action must be visible to support staff. A collaborative tool requires two users acting on shared state. These scenarios require two distinct authenticated contexts in one test.

## The Pattern

In multi-actor Gherkin, each actor is named consistently throughout the scenario. Steps clearly attribute actions to specific actors using third-person phrasing: "Alice does X", "Bob sees Y". This is clearer than "the admin does X" (which actor is the admin?) and avoids the single-person "I" pronoun entirely.

```gherkin
Given Alice is signed in as <role>
And Bob is signed in as <role>
When <actor> <action>
Then <actor> <outcome>
```

---

## Admin and Customer — Order Visibility

```gherkin
@orders @multi-actor
Feature: Order visibility across roles
  Customer orders are visible to admins for fulfillment management.
  Customers can only see their own orders.

  Scenario: An admin can see a customer's order in the admin dashboard
    Given Alice is signed in as an admin
    And Bob is signed in as a customer
    When Bob places an order for "Bluetooth Headphones"
    Then Alice can see Bob's order in the admin dashboard
    And Alice sees the order status as "processing"
    And Alice sees the order items including "Bluetooth Headphones"

  Scenario: A customer cannot see another customer's orders
    Given Alice is signed in as a customer
    And Bob is signed in as a customer
    When Bob places an order for "Bluetooth Headphones"
    Then Alice cannot see Bob's order in her order history
    And Alice's order history shows only her own orders
```

---

## Collaborative Editing

```gherkin
@documents @multi-actor @collaboration
Feature: Collaborative document editing
  Multiple team members can work on documents simultaneously.
  Changes made by one member are visible to others viewing the document.

  Background:
    Given a shared document titled "Q3 Planning" in the "Acme Corp" workspace

  Scenario: One team member sees another's edit in real time
    Given Alice is viewing the document "Q3 Planning"
    And Bob is viewing the document "Q3 Planning"
    When Bob adds the section "Budget Allocation"
    Then Alice sees the section "Budget Allocation" appear in the document
    And Alice's cursor position is preserved

  Scenario: A document lock prevents simultaneous conflicting edits
    Given Alice is editing the section "Goals" in "Q3 Planning"
    And Bob attempts to edit the section "Goals" in "Q3 Planning"
    Then Bob sees the notice "Alice is currently editing this section"
    And Bob's edit is queued for when Alice saves
```

---

## Customer Support — Impersonation

```gherkin
@support @multi-actor
Feature: Customer support impersonation
  Support agents can view a customer's account to diagnose issues.
  Impersonation is always visible to the customer and logged for audit.

  Scenario: A support agent views a customer account to diagnose a billing issue
    Given Alice is a support agent
    And Bob is a customer with a billing dispute open
    When Alice starts an impersonation session for Bob's account
    Then Alice sees Bob's account dashboard as Bob would see it
    And Bob's account shows a banner: "A support agent is viewing your account"
    And the impersonation session is recorded in the audit log

  @error-path
  Scenario: A regular member cannot impersonate another user
    Given Alice is a regular member (not a support agent)
    When Alice attempts to start an impersonation session for Bob's account
    Then the request is rejected with "forbidden"
    And Alice sees the error "You don't have permission to impersonate users"
```

---

## Message Passing Between Actors

```gherkin
@messaging @multi-actor
Feature: In-app messaging
  Team members can send messages to each other within the platform.

  Scenario: A member sends a message and the recipient receives it
    Given Alice is signed in as a team member
    And Bob is signed in as a team member
    When Alice sends Bob the message "Are you available for a call?"
    Then Bob sees a new message notification
    And Bob sees Alice's message "Are you available for a call?" in his inbox
    And Alice's sent message shows the "delivered" status

  Scenario: A message sent to an inactive user is still delivered on sign-in
    Given Alice is signed in as a team member
    And Bob has been signed out for 2 hours
    When Alice sends Bob the message "Meeting notes are ready"
    And Bob signs in
    Then Bob sees 1 unread message from Alice
    And Bob sees the message "Meeting notes are ready"
```

---

## Actor Naming Conventions

| Convention | Rationale |
|------------|-----------|
| Use proper names (Alice, Bob, Carol) | More memorable and human than "User A", "User B" |
| Assign consistent roles to names | "Alice" is always the admin in this feature; "Bob" is always the customer |
| State roles explicitly on first use | `Given Alice is signed in as an admin` |
| Use role shorthand after introduction | `Then Alice can see Bob's order` (no need to repeat "the admin") |
| Never mix "I" with named actors | Pick one convention per feature file |

!!! tip "Named personas"
    Use the [Named Resources](named-resources.md) pattern to give Alice and Bob canonical fixture definitions. `"Alice is signed in as an admin"` resolves to a specific user object with a known role, email, and org membership — no magic configuration in the step.

For the TypeScript step definitions managing two `BrowserContext` instances in one test, see [Multi-Actor Examples (TypeScript)](../../practice/examples/multi-actor.md).
