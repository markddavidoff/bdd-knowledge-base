---
title: CRUD Operations — Gherkin Examples
description: Create, Read, Update, Delete feature file examples using Background for setup, Scenario Outline for multiple values, and declarative vocabulary.
sources:
  - git-gherkin-best-practices-repo-readme-use-backgrounds-to-reduce-the-number-of-steps
  - git-gherkin-best-practices-repo-readme-avoid-overuse-of-scenario-outline
  - web-cucumber-gherkin-reference-keywords
  - web-automation-panda-writing-good-gherkin-phrasing-steps
  - git-gherkin-best-practices-repo-readme-make-scenarios-independent-and-deterministic
---

# CRUD Operations — Gherkin Examples

CRUD scenarios test the four fundamental data operations. They also demonstrate two key structural patterns: `Background` for shared setup, and `Scenario Outline` for testing the same operation with multiple values.

## Declarative Vocabulary Rule

The HTTP method is never mentioned in the step text. `"When I create a product named 'Widget'"` — not `"When I POST to /api/products with body {name: 'Widget'}"`. The feature file describes business behavior; the step definition chooses the transport.

---

## Create

```gherkin
@products @smoke
Feature: Product management
  Administrators can create and manage products in the catalog.

  Background:
    Given an administrator named "Carol" is signed in

  Scenario: An administrator creates a new product
    When Carol creates a product named "Widget" priced at $29.99
    Then the product "Widget" appears in the catalog
    And the product "Widget" has price $29.99

  Scenario: Product creation fails when the name is already taken
    Given a product named "Widget" already exists
    When Carol creates a product named "Widget" priced at $29.99
    Then the product creation fails
    And Carol sees the error "A product with that name already exists"
```

The `Background` step runs before both scenarios. It provides the shared precondition (Carol is signed in) without repeating it.

---

## Read

```gherkin
  Scenario: An administrator views a product's details
    Given a product named "Widget" priced at $29.99
    When Carol views the product "Widget"
    Then Carol sees the product name "Widget"
    And Carol sees the price $29.99
    And Carol sees the product status "Active"

  Scenario: Viewing a non-existent product shows a not-found message
    Given no product named "Gadget" exists
    When Carol views the product "Gadget"
    Then Carol sees the message "Product not found"
```

---

## Update — Scenario Outline for Multiple Values

When the same operation must succeed for a range of valid inputs, `Scenario Outline` avoids copying scenarios.

```gherkin
  Scenario Outline: An administrator updates a product's price
    Given a product named "Widget" priced at $<original_price>
    When Carol updates the "Widget" price to $<new_price>
    Then the product "Widget" has price $<new_price>

    Examples:
      | original_price | new_price |
      | 29.99          | 39.99     |
      | 39.99          | 9.99      |
      | 9.99           | 0.01      |
```

!!! warning "Scenario Outline overuse"
    Scenario Outline is tempting but each row becomes a separate test. A Scenario Outline with 20 rows in a UI-driven test suite is 20 browser sessions. Use it for cases where the data variation genuinely tests different boundary conditions, not to avoid writing two similar scenarios. See [Data-Driven](data-driven.md) for tagged multi-table patterns.

---

## Update — Validation Errors

```gherkin
  @error-path
  Scenario Outline: Price update fails for invalid amounts
    Given a product named "Widget" priced at $29.99
    When Carol attempts to update the "Widget" price to <invalid_price>
    Then the price update is rejected
    And Carol sees the error "<error_message>"

    Examples:
      | invalid_price | error_message                    |
      | -5.00         | Price must be greater than zero  |
      | 0.00          | Price must be greater than zero  |
      | 99999.99      | Price exceeds the maximum limit  |
```

---

## Delete

```gherkin
  Scenario: An administrator deletes a product
    Given a product named "Widget" exists in the catalog
    When Carol deletes the product "Widget"
    Then the product "Widget" no longer appears in the catalog
    And existing orders containing "Widget" are unaffected

  @error-path
  Scenario: Deleting a non-existent product shows a not-found error
    Given no product named "Gadget" exists
    When Carol attempts to delete the product "Gadget"
    Then the deletion fails
    And Carol sees the message "Product not found"
```

Note "existing orders containing 'Widget' are unaffected" — this is a business rule assertion, not just a confirmation of deletion. When deleting catalog items in real systems, cascade behavior matters.

---

## Complete Feature File

```gherkin
@products
Feature: Product management
  Administrators can create and manage products in the catalog.

  Background:
    Given an administrator named "Carol" is signed in

  @smoke
  Scenario: An administrator creates a new product
    When Carol creates a product named "Widget" priced at $29.99
    Then the product "Widget" appears in the catalog
    And the product "Widget" has price $29.99

  @error-path
  Scenario: Product creation fails when the name is already taken
    Given a product named "Widget" already exists
    When Carol creates a product named "Widget" priced at $29.99
    Then the product creation fails
    And Carol sees the error "A product with that name already exists"

  Scenario: An administrator views a product's details
    Given a product named "Widget" priced at $29.99
    When Carol views the product "Widget"
    Then Carol sees the product name "Widget"
    And Carol sees the price $29.99

  Scenario Outline: An administrator updates a product's price
    Given a product named "Widget" priced at $<original_price>
    When Carol updates the "Widget" price to $<new_price>
    Then the product "Widget" has price $<new_price>

    Examples:
      | original_price | new_price |
      | 29.99          | 39.99     |
      | 9.99           | 0.01      |

  @error-path
  Scenario Outline: Price update fails for invalid amounts
    Given a product named "Widget" priced at $29.99
    When Carol attempts to update the "Widget" price to <invalid_price>
    Then the price update is rejected
    And Carol sees the error "<error_message>"

    Examples:
      | invalid_price | error_message                    |
      | -5.00         | Price must be greater than zero  |
      | 0.00          | Price must be greater than zero  |

  Scenario: An administrator deletes a product
    Given a product named "Widget" exists in the catalog
    When Carol deletes the product "Widget"
    Then the product "Widget" no longer appears in the catalog
    And existing orders containing "Widget" are unaffected
```

For TypeScript step definitions using `APIRequestContext` for product setup, see [CRUD Examples (TypeScript)](../../practice/examples/crud-operations.md). For managing named products as catalog resources, see [Named Resources](named-resources.md).
