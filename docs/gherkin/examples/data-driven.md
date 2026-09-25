---
title: Data-Driven Scenarios — Gherkin Examples
description: Scenario Outline with single Examples table, multiple tagged Examples tables, and DataTable for structured input.
sources:
  - web-cucumber-gherkin-reference-keywords
  - git-gherkin-best-practices-repo-readme-avoid-overuse-of-scenario-outline
  - web-testquality-best-practices-advanced-gherkin-features-for-complex-testing-needs
  - web-automation-panda-writing-good-gherkin-style-and-structure
---

# Data-Driven Scenarios — Gherkin Examples

Gherkin offers three mechanisms for data-driven testing: `Scenario Outline` with an `Examples` table for row-per-test parameterization, multiple tagged `Examples` tables for separating valid from invalid inputs, and `DataTable` for passing structured data to a single step.

---

## Scenario Outline — Single Examples Table

`Scenario Outline` is the right tool when the same behavior must hold across a range of representative inputs.

```gherkin
@pricing @smoke
Feature: Volume discount pricing
  Orders above certain quantities qualify for volume discounts.

  Scenario Outline: Volume discount is applied for qualifying order sizes
    Given a product priced at $10.00 per unit
    When a customer orders <quantity> units
    Then the order total is $<expected_total>

    Examples:
      | quantity | expected_total |
      | 1        | 10.00          |
      | 9        | 90.00          |
      | 10       | 85.00          |
      | 50       | 400.00         |
      | 100      | 750.00         |
```

Each row in `Examples` produces one independent test. The `<quantity>` and `<expected_total>` placeholders are replaced before the step is matched against a step definition.

!!! warning "Scenario Outline overuse"
    Each row is a separate test execution. A 20-row Scenario Outline in a browser-driven suite is 20 browser sessions. Use Scenario Outline when the data variation genuinely tests different boundary conditions — at the discount tier boundary (9 vs. 10 units above) — not just to avoid writing two scenarios that cover the same boundary. See the topic tree section 1.3 for the overuse anti-pattern.

---

## Multiple Tagged Examples Tables

When a Scenario Outline covers both valid and invalid inputs, split them into separate `Examples` tables with different tags. This lets the CI pipeline run `@smoke` (valid inputs only) without running the full `@error-path` suite, and lets reports distinguish happy-path from negative-path results.

```gherkin
@registration
Feature: User registration
  Visitors can create an account with a valid email and password.

  Scenario Outline: Account registration outcome by input
    Given no account exists for "<email>"
    When a visitor registers with email "<email>" and password "<password>"
    Then <outcome>

    @smoke @happy-path
    Examples: Valid registration inputs
      | email                 | password          | outcome                                 |
      | alice@example.com     | S3cur3P@ssword!   | the account is created successfully     |
      | bob+test@example.com  | Another$ecure1    | the account is created successfully     |

    @error-path
    Examples: Invalid registration inputs
      | email                 | password          | outcome                                              |
      | not-an-email          | S3cur3P@ssword!   | registration fails with "Invalid email address"      |
      | alice@example.com     | short             | registration fails with "Password is too short"      |
      | alice@example.com     | alllowercase1!    | registration fails with "Password needs a capital"   |
      | alice@example.com     |                   | registration fails with "Password is required"       |
```

Running only the smoke suite:
```bash
npx playwright test --grep @smoke
```

Running only error paths:
```bash
npx playwright test --grep @error-path
```

!!! tip "Table titles"
    The text after `Examples:` (e.g., `Valid registration inputs`) becomes part of the test name in reports. Make it descriptive. In playwright-bdd you can override with the `# title-format:` extension — see [Multiple Tagged Examples](multiple-tagged-examples.md) for that pattern.

---

## DataTable — Structured Input to a Single Step

`DataTable` passes a table to one step rather than parameterizing the whole scenario. Use it when a single step requires multiple fields that would be awkward as inline parameters.

```gherkin
@onboarding
Feature: Organization setup
  Administrators configure their organization during onboarding.

  Scenario: An administrator configures organization settings
    Given a new organization named "Acme Corp"
    And Carol is the admin for "Acme Corp"
    When Carol configures the organization with:
      | setting            | value              |
      | display_name       | Acme Corporation   |
      | timezone           | America/Chicago    |
      | default_language   | en-US              |
      | billing_email      | billing@acme.com   |
    Then the organization settings are saved
    And the organization displays as "Acme Corporation"
```

The `|` delimited table is passed to the step definition as a `DataTable` object. The step definition calls `table.hashes()` to get an array of `{setting, value}` objects, or `table.rowsHash()` to get a plain key-value map.

---

## DataTable — Header Row as Keys

A header-row table (`table.hashes()`) is the most common DataTable pattern: the first row names the fields, subsequent rows are instances.

```gherkin
  Scenario: An admin imports multiple products at once
    Given Carol is signed in as an administrator
    When Carol imports the following products:
      | name                   | price  | sku      | category    |
      | Bluetooth Headphones   | 89.99  | BT-001   | Electronics |
      | Mechanical Keyboard    | 149.99 | MK-002   | Electronics |
      | Ergonomic Mouse        | 59.99  | EM-003   | Electronics |
    Then 3 products appear in the catalog
    And each product has its correct price and SKU
```

---

## DataTable — Two-Column Key-Value (`rowsHash`)

A two-column table without a header is useful for configuration-style data where each row is a named property:

```gherkin
  Scenario: A user updates their notification preferences
    Given Alice is signed in
    When Alice sets her notification preferences to:
      | email_on_order     | true  |
      | email_on_shipment  | true  |
      | sms_on_delivery    | false |
      | weekly_digest      | false |
    Then Alice's notification preferences are saved
```

The step definition calls `table.rowsHash()` to get `{ email_on_order: 'true', email_on_shipment: 'true', ... }`.

---

## Doc Strings — Multi-Line Payloads

For steps that require a multi-line string (email body, JSON template, SQL query), use Doc Strings delimited by `"""`:

```gherkin
  Scenario: A user receives a well-formed welcome email
    Given a registered user named "Alice"
    When the welcome email is sent to Alice
    Then Alice receives an email with the body:
      """
      Dear Alice,

      Welcome to the platform. Your account is ready.

      Sign in at https://app.example.com

      The Team
      """
```

The content between `"""` is passed to the step definition as a raw string. For JSON or YAML, annotate the opening delimiter: `"""json` or `"""yaml` — some step definition frameworks use this to automatically parse the content.

For the TypeScript step definitions handling `DataTable` and Doc Strings, see [Data-Driven Examples (TypeScript)](../../practice/examples/data-driven.md).
