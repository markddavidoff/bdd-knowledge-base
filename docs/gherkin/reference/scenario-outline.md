---
title: Scenario Outline
description: Data-driven scenarios using Scenario Outline (alias Scenario Template), <placeholder> syntax, single and multiple Examples tables, tagged Examples, and playwright-bdd title formatting.
sources:
  - web-cucumber-gherkin-reference-keywords
  - git-gherkin-best-practices-repo-readme-avoid-overuse-of-scenario-outline
  - web-testquality-best-practices-using-background-elements-effectively
  - git-gherkin-parser-testdata-good-tags-feature-scenario-outline-minimalistic-outline
  - git-playwright-bdd-repo-docs-configuration-options-examplestitleformat
---

# Scenario Outline

`Scenario Outline` (alias `Scenario Template`) is the Gherkin construct for data-driven testing: the same scenario structure is executed once for each row in an `Examples` table.

## Basic Syntax

```gherkin
Scenario Outline: Subscription plan limits
  Given a user on the <plan> plan
  When the user attempts to add user number <attempt>
  Then the result is <outcome>

  Examples:
    | plan       | attempt | outcome    |
    | free       | 2       | blocked    |
    | pro        | 10      | allowed    |
    | enterprise | 100     | allowed    |
```

Every cell value between `|` delimiters in the header row defines a placeholder name. Placeholders appear in step text wrapped in `<` and `>`. Before matching a step, the runner substitutes each `<placeholder>` with the corresponding cell value from the row being executed.

This produces three separate test executions — one per data row — without requiring three copy-pasted `Scenario` blocks.

## Keyword Alias

`Scenario Template` is an exact synonym for `Scenario Outline`. Use whichever reads more naturally in your team's vocabulary. The runner treats them identically. `Scenarios` is also an alias for the `Examples` keyword.

## <placeholder> Syntax Rules

- Placeholder names must match a column header exactly, including case.
- Placeholders can appear in step text, Doc String content, and `Scenario Outline` description lines.
- A placeholder that does not match any column header is left as literal text.
- Column names become Cucumber Expression parameter names when the row is expanded — they must not contain `<`, `>`, or `|`.

```gherkin
Scenario Outline: Email validation
  Given a registration form
  When the user submits email "<email_address>"
  Then the validation result is "<result>"

  Examples:
    | email_address         | result  |
    | alice@example.com     | valid   |
    | not-an-email          | invalid |
    | missing@domain        | invalid |
```

## Multiple Examples Tables

A single `Scenario Outline` can have more than one `Examples` table. This is useful for grouping related but conceptually distinct data sets:

```gherkin
Scenario Outline: Authentication outcomes
  Given a user with username "<username>"
  When the user authenticates with password "<password>"
  Then the result is "<outcome>"

  Examples: Valid credentials
    | username  | password        | outcome |
    | alice     | correct-horse   | success |
    | bob       | battery-staple  | success |

  Examples: Invalid credentials
    | username  | password   | outcome            |
    | alice     | wrongpass  | invalid_credentials |
    | unknown   | anything   | invalid_credentials |
```

Each `Examples` table generates its own independent set of test runs. The table title (the text after `Examples:`) is optional but recommended for documentation clarity.

## Tagged Examples Tables

Individual `Examples` tables can carry tags. This is the canonical way to partition a data set for different run environments or test suites:

```gherkin
Scenario Outline: Payment processing
  Given an order totalling <amount>
  When the payment is processed with <method>
  Then the transaction status is <status>

  @smoke
  Examples: Happy path
    | amount | method      | status    |
    | 10.00  | credit_card | approved  |
    | 25.00  | paypal      | approved  |

  @regression
  Examples: Edge cases
    | amount  | method      | status   |
    | 0.01    | credit_card | approved |
    | 9999.99 | credit_card | approved |

  @regression @error-path
  Examples: Decline scenarios
    | amount | method       | status   |
    | 10.00  | expired_card | declined |
    | 10.00  | insufficient | declined |
```

Run only the smoke examples:

```bash
npx playwright test --grep "@smoke"
```

!!! tip "Tag inheritance"
    Tags on the `Scenario Outline` itself are inherited by all its `Examples` tables. Tags on an individual `Examples` table apply only to that table's rows.

## Title Format Override (playwright-bdd)

playwright-bdd generates a test name for each `Examples` row. By default the generated name is `Example #<index>` (configurable via `examplesTitleFormat` in `playwright.config.ts`). You can override the title per-outline by placing a comment immediately above the `Examples` keyword:

```gherkin
Scenario Outline: Plan upgrade confirmation
  Given a user on the <from_plan> plan
  When the user upgrades to <to_plan>
  Then a confirmation email is sent

  # title-format: Upgrade from <from_plan> to <to_plan>
  Examples:
    | from_plan | to_plan    |
    | free      | pro        |
    | pro       | enterprise |
```

The generated Playwright tests will be named `Upgrade from free to pro` and `Upgrade from pro to enterprise`. This makes the HTML report and trace viewer titles readable without digging into the Examples table.

!!! note "# title-format: is a playwright-bdd extension"
    This comment directive is recognized only by playwright-bdd's code generator. It is ignored by `@cucumber/cucumber` and other runners. The `#` makes it invisible to those parsers since `#` is a Gherkin comment.

## When to Use Scenario Outline vs. Multiple Scenarios

Use `Scenario Outline` when:

- The same behavior applies to several data combinations
- The data set has 3+ rows (fewer rows usually read better as separate `Scenario` blocks)
- You need to run a subset of the data in CI (using tagged `Examples`)

Use separate `Scenario` blocks when:

- Each case has meaningfully different context or outcome semantics
- You have only 2 cases — two scenarios are often more readable than an outline
- The step text would require many placeholders, making it hard to read

!!! warning "Scenario Outline overuse"
    Overuse of `Scenario Outline` leads to large Examples tables where individual rows lose their meaning. Each row should represent a distinct business case, not a brute-force combinatorial sweep. If the table has more than ~8 rows, ask whether all cases need to be tested at the UI/E2E layer, or whether unit tests cover the permutations more efficiently.

```gherkin
# Prefer two named scenarios over a two-row outline when context matters

# Good — explicit scenarios
Scenario: Free user is blocked from premium content
  Given a user on the free plan
  When the user requests a premium report
  Then access is denied

Scenario: Pro user can access premium content
  Given a user on the pro plan
  When the user requests a premium report
  Then the report is returned

# Acceptable — outline when the behavior is identical and data-driven
Scenario Outline: Supported currencies display correctly
  Given the user's locale is <locale>
  When the pricing page loads
  Then the price shows as <currency_symbol>19.99

  Examples:
    | locale | currency_symbol |
    | en-US  | $               |
    | en-GB  | £               |
    | de-DE  | €               |
    | ja-JP  | ¥               |
```

## Cross-References

- [Keywords](keywords.md) — full keyword table including `Scenario Template` and `Scenarios` aliases
- [Tags — Classification](tags-classification.md) — tag syntax and filtering
- [Data Tables](data-tables.md) — structured data within a single step (not Outline examples)
- [Background](background.md) — shared context that applies to each Outline row
