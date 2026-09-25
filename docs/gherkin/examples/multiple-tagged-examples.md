---
title: Multiple Tagged Examples Tables — Gherkin Examples
description: A single Scenario Outline with separate @smoke and @regression Examples tables, each with different data and tags, including the playwright-bdd # title-format: extension.
sources:
  - web-cucumber-gherkin-reference-keywords
  - git-gherkin-best-practices-repo-readme-use-tags-to-organize-your-features-and-scenarios
  - web-testquality-best-practices-advanced-gherkin-features-for-complex-testing-needs
  - git-gherkin-best-practices-repo-readme-avoid-overuse-of-scenario-outline
---

# Multiple Tagged Examples Tables — Gherkin Examples

A `Scenario Outline` can have more than one `Examples` block. Each block has its own tag(s) and its own set of rows. This pattern is the idiomatic way to separate smoke test data from regression test data within one outline, without duplicating the scenario template.

## Anatomy of Multiple Examples Tables

```gherkin
Scenario Outline: <template using <placeholders>>
  Given ...
  When ...
  Then ...

  @tag-a
  Examples: Name of first group
    | col1 | col2 |
    | ...  | ...  |

  @tag-b
  Examples: Name of second group
    | col1 | col2 |
    | ...  | ...  |
```

- Tags on an `Examples` block apply only to the scenarios generated from that block's rows.
- Tags on the `Scenario Outline` itself apply to all generated scenarios regardless of which `Examples` block they come from.
- The text after `Examples:` is a title used in test reports.

---

## Canonical Example — Password Validation

```gherkin
@registration
Feature: Password validation
  Passwords must meet security requirements before an account is created.

  Scenario Outline: Password acceptance at registration
    Given no account exists for "newuser@example.com"
    When a visitor registers with password "<password>"
    Then <outcome>

    @smoke @happy-path
    Examples: Valid passwords
      | password             | outcome                           |
      | Correct-Horse-9!     | the account is created            |
      | $uper$ecure42        | the account is created            |
      | Long-But-Valid-Pass1 | the account is created            |

    @regression @error-path
    Examples: Passwords that fail validation
      | password    | outcome                                                       |
      | short1!     | registration fails with "Password must be at least 8 chars"  |
      | alllower1!  | registration fails with "Password needs an uppercase letter"  |
      | ALLUPPER1!  | registration fails with "Password needs a lowercase letter"  |
      | NoSpecial1  | registration fails with "Password needs a special character"  |
      | NoNumber!!  | registration fails with "Password needs a number"             |
      |             | registration fails with "Password is required"                |
```

Running only the smoke subset:
```bash
npx playwright test --grep @smoke
```

Running the full regression suite for registration:
```bash
npx playwright test --grep "@registration"
```

---

## Separate @smoke and @regression with Different Column Sets

Each `Examples` block can have a different column set, as long as all placeholders used in the outline template are present. This allows smoke rows to be minimal while regression rows carry extra fields for error assertion.

```gherkin
@pricing
Feature: Discount code redemption
  Customers can apply valid discount codes at checkout.

  Scenario Outline: Discount code redemption outcome
    Given a customer named "Alice" with a cart total of $100.00
    When Alice applies the discount code "<code>"
    Then <outcome>

    @smoke @happy-path
    Examples: Valid discount codes
      | code        | outcome                            |
      | SAVE10      | the cart total becomes $90.00      |
      | WELCOME20   | the cart total becomes $80.00      |
      | HALFOFF     | the cart total becomes $50.00      |

    @regression @error-path
    Examples: Invalid discount codes
      | code        | outcome                                              |
      | EXPIRED01   | discount is rejected with "This code has expired"    |
      | WRONGSTORE  | discount is rejected with "Code not valid for this store" |
      | NOTACODE    | discount is rejected with "Invalid discount code"    |
      |             | discount is rejected with "Please enter a discount code" |
```

---

## playwright-bdd — `# title-format:` Extension

By default, playwright-bdd names generated tests by combining the outline title with the row values. For tables with many columns this produces unwieldy test names. The `# title-format:` comment overrides the generated name using column placeholders.

```gherkin
@registration
Feature: Password validation

  Scenario Outline: Password acceptance at registration
    Given no account exists for "newuser@example.com"
    When a visitor registers with password "<password>"
    Then <outcome>

    # title-format: valid password: <password>
    @smoke @happy-path
    Examples: Valid passwords
      | password             | outcome                |
      | Correct-Horse-9!     | the account is created |
      | $uper$ecure42        | the account is created |

    # title-format: invalid password: <password> → <error>
    @regression @error-path
    Examples: Passwords that fail validation
      | password    | error                                  | outcome                                          |
      | short1!     | Password must be at least 8 chars      | registration fails with "<error>"                |
      | alllower1!  | Password needs an uppercase letter     | registration fails with "<error>"                |
```

The `# title-format:` comment must appear immediately above the `Examples:` keyword. In the generated Playwright test file, each row gets a test name like `"invalid password: short1! → Password must be at least 8 chars"` instead of the default row-index name.

!!! note "playwright-bdd only"
    `# title-format:` is a playwright-bdd extension. It has no effect with other Gherkin runners. Standard CucumberJS uses the row values in order as the test title suffix.

---

## Tag Inheritance Diagram

```
@registration                         ← inherited by ALL generated scenarios
Feature: Password validation

  Scenario Outline: ...               ← no additional outline-level tag here

    @smoke @happy-path                ← only scenarios from this Examples block
    Examples: Valid passwords
      | ... |

    @regression @error-path           ← only scenarios from this Examples block
    Examples: Invalid passwords
      | ... |
```

A scenario generated from the "Valid passwords" table has tags: `@registration @smoke @happy-path`.
A scenario generated from the "Invalid passwords" table has tags: `@registration @regression @error-path`.

For more on tag taxonomy and filtering, see [Tag Reference](../reference/tags-classification.md). For the base data-driven patterns (single table, DataTable), see [Data-Driven](data-driven.md).
