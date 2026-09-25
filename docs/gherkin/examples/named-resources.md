---
title: Named Resources — Gherkin Examples
description: The named test data catalog pattern in pure Gherkin — personas, org plans, and base fixture plus variation table — with annotations on what each parameter type resolves to.
sources:
  - web-martinfowler-object-mother-content
  - web-given-bdd-seriously-object-mother-manage-test-fixtures-for-fast-and-reliable-in-memory-tests
  - web-cucumber-gherkin-reference-keywords
  - web-automation-panda-writing-good-gherkin-handling-test-data
---

# Named Resources — Gherkin Examples

Named resources are human-readable tokens in step text that resolve to fully-configured domain objects via [Custom Parameter Types](../reference/custom-parameter-types.md). Instead of inline magic values (`user_id=42`, `plan="pro"`, `email="alice@..."`) the feature file uses stable names that belong to the team's shared vocabulary.

This is the Object Mother pattern (Fowler, 2002) expressed in Gherkin: a registry of canonical named fixtures, each with a name the team agrees on and uses consistently.

---

## User Personas

A `{user}` parameter type matches named personas. The transformer returns a canonical user object — email, role, subscription tier, organizational membership — all pre-configured.

```gherkin
@permissions
Feature: Role-based access control
  Access to administrative functions depends on the user's role.

  # {user} resolves to: { name, email, role, orgId, ... }
  # "Alice" → admin user in the Acme Corp org
  # "Bob"   → regular member in the Acme Corp org
  # "Carol" → billing admin in the Acme Corp org

  Scenario: An admin can access the admin dashboard
    Given Alice is signed in
    When Alice navigates to the admin dashboard
    Then Alice sees the admin dashboard

  Scenario: A regular member cannot access the admin dashboard
    Given Bob is signed in
    When Bob attempts to navigate to the admin dashboard
    Then Bob is redirected to his member dashboard
    And Bob sees the message "You don't have permission to access that page"

  Scenario: A billing admin can view invoices but not manage users
    Given Carol is signed in
    When Carol views the invoices page
    Then Carol sees the invoice history
    When Carol attempts to navigate to user management
    Then Carol is redirected to her dashboard
```

The Gherkin uses "Alice", "Bob", "Carol" — not "user with role admin", not "user ID 42". The step definition resolves each name to a fixture object, which may create a DB record or load a stored state file.

---

## Organization Plans

A `{org-plan}` parameter type matches plan names. The transformer returns the full plan configuration object.

```gherkin
@billing
Feature: Plan-based feature access
  Organizations on different plans have access to different features.

  # {org-plan} resolves to: { plan, billingEnabled, seatLimit, apiRateLimit, ... }
  # "free"       → { plan: 'free', seatLimit: 5, apiRateLimit: 100 }
  # "pro"        → { plan: 'pro', seatLimit: 25, apiRateLimit: 10000 }
  # "enterprise" → { plan: 'enterprise', seatLimit: null, apiRateLimit: null }

  Scenario: A free organization is limited to 5 seats
    Given a free organization named "Starter Co"
    When the admin of "Starter Co" invites a 6th member
    Then the invitation fails
    And the admin sees "Your plan allows a maximum of 5 seats"

  Scenario: A pro organization can invite up to 25 members
    Given a pro organization named "Growth Co"
    When the admin of "Growth Co" invites a 25th member
    Then the invitation succeeds

  Scenario: An enterprise organization has no seat limit
    Given an enterprise organization named "BigCo"
    When the admin of "BigCo" invites a 100th member
    Then the invitation succeeds
```

"A free organization" and "a pro organization" are named resource tokens. The step definition creates an organization seeded with the appropriate plan configuration — no magic numbers, no inline `{ seatLimit: 5 }`.

---

## Base Fixture + Variation Table

The most powerful pattern combines a named base fixture with a DataTable of overrides. The base resource provides the canonical starting state; the table provides scenario-specific variation without repeating the entire configuration.

```gherkin
@notifications
Feature: Notification preferences
  Users can configure which events trigger notifications.

  Scenario: A user enables email notifications for all events
    # "Alice" is the base persona — fully onboarded, default preferences
    Given the user Alice with notification preferences:
      | preference          | enabled |
      | email_on_order      | true    |
      | email_on_shipment   | true    |
      | email_on_delivery   | true    |
    When an order is placed for Alice
    Then Alice receives an order confirmation email

  Scenario: A user with email disabled receives no emails
    Given the user Alice with notification preferences:
      | preference          | enabled |
      | email_on_order      | false   |
      | email_on_shipment   | false   |
      | email_on_delivery   | false   |
    When an order is placed for Alice
    Then Alice does not receive any emails
```

The step definition takes the "Alice" base object from the parameter type and merges the DataTable overrides on top of it. This is the Builder pattern — the named resource is the Object Mother, the DataTable provides the `With...()` overrides.

---

## Step Text Annotations

Annotate named resources in feature files with a comment block above the `Scenario` or in the `Feature` description. This is the self-documenting property of the vocabulary registry:

```gherkin
@subscriptions
Feature: Subscription management
  Subscription behavior by plan tier.

  # Named user personas used in this feature:
  #   Alice — free-tier member, no payment method on file
  #   Bob   — pro-tier member, Visa card on file, 3 months remaining
  #   Carol — enterprise admin, annual contract, multiple seats

  Scenario: A free member cannot access pro features
    Given Alice is signed in
    When Alice attempts to use the API export feature
    Then Alice is shown an upgrade prompt

  Scenario: A pro member can use the API export feature
    Given Bob is signed in
    When Bob requests an API export
    Then the export is generated and emailed to Bob
```

---

## Named Resources vs. Inline Values

| Use named resources when... | Use inline values when... |
|-----------------------------|--------------------------|
| The name itself is domain vocabulary | The exact value is the behavior under test |
| The resource has multiple properties that all matter | Only one property matters |
| The same resource appears in multiple scenarios | The resource is used once |
| Setup involves multiple DB writes | Setup is a single field |

```gherkin
# Named resource — "Alice" → canonical user fixture (many properties)
Given Alice is signed in

# Inline value — the exact email IS the behavior under test
When a visitor registers with the email "alice+test@example.com"
Then the confirmation is sent to "alice+test@example.com"
```

For the TypeScript `defineParameterType` implementation that backs these patterns, see [Custom Parameter Types](../reference/custom-parameter-types.md) and [Domain Parameter Registry (TypeScript)](../../practice/examples/domain-parameter-registry.md).
