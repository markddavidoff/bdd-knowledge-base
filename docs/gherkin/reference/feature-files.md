---
title: Feature Files
description: Conventions for .feature and .feature.md files — encoding, indentation, comment syntax, the Feature keyword, narrative format, and the Gherkin Markdown dialect.
sources:
  - web-cucumber-gherkin-reference-keywords
  - git-gherkin-parser-markdownwithgherkin-markdown-with-gherkin
  - git-gherkin-utils-readme-features
  - git-gherkin-best-practices-repo-readme-features-are-not-user-stories
  - git-gherkin-best-practices-repo-readme-use-meaningful-feature-and-scenario-names
---

# Feature Files

A feature file is the primary artifact in a BDD workflow. It contains one `Feature` and any number of `Scenario`, `Background`, `Rule`, or `Scenario Outline` blocks. Feature files are the executable specification: they drive both the test runner and the living documentation.

## File Conventions

| Convention | Value |
|------------|-------|
| Extension | `.feature` (or `.feature.md` for Gherkin Markdown) |
| Encoding | UTF-8 (required) |
| Line ending | LF or CRLF — both accepted |
| Indentation | Two spaces (conventional; parser is flexible) |
| One Feature per file | Yes — a file may contain exactly one `Feature` |
| Comment character | `#` — the entire line is ignored by the parser |

```gherkin
# This is a comment — ignored at runtime but useful for team notes.
# The parser treats any line beginning with # as a comment.

Feature: Password reset
```

!!! warning "Parser flexibility does not mean team flexibility"
    The Gherkin parser accepts inconsistent indentation, but your team should agree on a standard (two spaces is the ecosystem default) and enforce it with `@cucumber/gherkin-utils` as a pre-commit formatter. See [Gherkin Formatter](../../practice/tooling/gherkin-formatter.md).

## The Feature Keyword

`Feature` is the top-level keyword. It provides a title and optional free-form description. The parser ignores the description at runtime; it appears in HTML reports and living documentation output.

```gherkin
Feature: Subscription billing

  Users are charged on the first of each month.
  Failed payments are retried up to three times before the subscription lapses.

  Scenario: Successful monthly charge
    Given a user with a valid payment method
    When the monthly billing job runs
    Then the user is charged the plan amount
    And the invoice is marked "paid"
```

### Title Requirements

The title immediately follows the `Feature:` keyword on the same line. Keep it short (5–8 words), noun-phrase or verb-phrase, describing the domain capability — not the implementation:

- Good: `Subscription billing`, `Password reset`, `Multi-factor authentication`
- Avoid: `Test the billing endpoint`, `Verify that the reset email is sent`

### The Description Block

Any lines between the `Feature:` line and the first `Background`, `Rule`, or `Scenario` keyword are treated as the description. The description can contain Markdown — HTML reporters render it. Use this space for:

- The business context or problem statement
- Links to related acceptance criteria or tickets
- A brief list of in-scope business rules

```gherkin
Feature: Invoice generation

  ## Business Context
  Finance requires PDF invoices for every completed order.
  Invoices must be generated within 60 seconds of order completion.

  **In scope:** PDF generation, email delivery, audit log entry.
  **Out of scope:** Payment processing (see `payment.feature`).

  Scenario: Invoice generated on order completion
    ...
```

## The "As a / In order to / So that" Narrative

A common convention places a user-story narrative in the Feature description:

```gherkin
Feature: Expense reporting

  As a finance manager
  In order to track department spending
  So that I can produce accurate monthly reports

  Scenario: ...
```

This format originated with the Connextra user-story template. It documents the persona, motivation, and benefit — useful when the feature file also serves as a requirements artifact.

!!! tip "When to skip the narrative"
    Teams that track user stories in an external tool (Linear, Jira, Notion) often skip the narrative to avoid duplication. If the feature file will be read primarily by developers and CI pipelines rather than business stakeholders, the narrative adds noise without value. Focus on keeping scenario titles expressive instead.

## Feature Files Are Not User Stories

A user story is a slice of delivery scope; a feature file is a behaviorally-grouped collection of scenarios. One feature often spans multiple user stories. Do not create a new feature file for each user story — instead, add scenarios to the relevant existing feature file and improve existing scenarios when behavior changes.

## The `.feature.md` Gherkin Markdown Format

Gherkin Markdown (MDG) is a dialect that embeds Gherkin in standard Markdown. Files use the `.feature.md` extension and are parsed by the same Gherkin parser. MDG is a strict superset of GitHub Flavored Markdown (GFM), meaning any GFM renderer displays it correctly.

**Parsing rules:**

- Gherkin block keywords (`Feature`, `Scenario`, `Background`, `Rule`, `Scenario Outline`, `Examples`) must be preceded by one or more `#` Markdown heading markers.
- Step keywords (`Given`, `When`, `Then`, `And`, `But`) must be preceded by `-` or `*` (Markdown list item).
- Data Tables and Examples tables use GFM table syntax and must be indented 2–5 spaces.
- Doc Strings use GFM fenced code blocks.
- Tags are wrapped in single backticks: `` `@tagname` ``.

```markdown
# Feature: User authentication

`@smoke`
## Scenario: Successful login

  * Given the user has an account with email "alice@example.com"
  * When the user signs in with valid credentials
  * Then the dashboard is displayed
  * And a session cookie is set

## Scenario Outline: Failed login messages

  * Given a login attempt with username "<username>" and password "<password>"
  * Then the error message is "<message>"

  | username          | password       | message                     |
  | ----------------- | -------------- | --------------------------- |
  | alice@example.com | wrongpassword  | Invalid email or password   |
  | notauser@x.com    | anything       | Invalid email or password   |
```

### Converting Between Formats

`@cucumber/gherkin-utils` provides CLI commands for format conversion:

```bash
# Format a .feature file in-place
npx @cucumber/gherkin-utils format features/login.feature

# Convert .feature to .feature.md
npx @cucumber/gherkin-utils --toMarkdown features/login.feature > features/login.feature.md
```

!!! note "Tool support for .feature.md"
    IDEs vary in `.feature.md` support. VS Code with the official Cucumber extension recognizes the format. For teams where the Markdown rendering benefit (GitHub preview, Notion embeds) outweighs IDE autocompletion, `.feature.md` is a good choice.

## Cross-References

- [Keywords](keywords.md) — all Gherkin keywords and their roles
- [Background](background.md) — shared steps within a feature file
- [Rules](rules.md) — organizing scenarios by business rule
- [Localization](localization.md) — `# language: fr` and non-English keywords
- [Gherkin Formatter](../../practice/tooling/gherkin-formatter.md) — auto-formatting and CI enforcement
