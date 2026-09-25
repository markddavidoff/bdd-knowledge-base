---
title: Gherkin Keywords
description: Complete reference for all Gherkin primary and secondary keywords, their aliases, and a full feature file example showing every keyword in use.
sources:
  - web-cucumber-gherkin-reference-keywords
  - git-gherkin-best-practices-repo-readme-use-meaningful-feature-and-scenario-names
  - git-gherkin-parser-testdata-good-tags-feature-rule
---

# Gherkin Keywords

Gherkin is a structured natural-language format for writing executable specifications. Every non-blank line must begin with a Gherkin keyword followed by free-form text — the only exceptions are the description blocks placed immediately beneath `Feature`, `Rule`, `Background`, `Scenario`, and `Scenario Outline`.

## Primary Keywords

| Keyword | Alias(es) | Gherkin Version | Purpose |
|---------|-----------|-----------------|---------|
| `Feature` | — | 1+ | Declares a feature and groups related scenarios |
| `Rule` | — | 6+ | Groups scenarios by business rule within a Feature |
| `Scenario` | `Example` | 1+ / 6+ alias | A single executable specification |
| `Background` | — | 1+ | Steps shared by all scenarios in a Feature or Rule |
| `Scenario Outline` | `Scenario Template` | 1+ / 6+ alias | Data-driven scenario with an Examples table |
| `Examples` | `Scenarios` | 1+ | Table of input rows for a Scenario Outline |
| `Given` | — | 1+ | Establishes context / preconditions |
| `When` | — | 1+ | Triggers an action or event |
| `Then` | — | 1+ | Asserts an expected outcome |
| `And` | — | 1+ | Continues the previous step type |
| `But` | — | 1+ | Continuation step, typically used for negative conditions |
| `*` | — | 1+ | Wildcard — acts as the previous step type |

## Secondary Keywords

| Symbol | Role |
|--------|------|
| `"""` | Doc String delimiter |
| `\|` | Data Table cell delimiter |
| `@` | Tag prefix |
| `#` | Line comment |

## Keyword Aliases

Several Gherkin 6 keywords have exact synonyms. The runner treats them identically; choose whichever reads more naturally.

- **`Example`** is an alias for **`Scenario`**. Use `Example` when the scenario illustrates a concrete case; use `Scenario` when describing a more general workflow.
- **`Scenario Template`** is an alias for **`Scenario Outline`**.
- **`Scenarios`** is an alias for **`Examples`**.

!!! note "Aliases in generated output"
    playwright-bdd and CucumberJS report the keyword exactly as written in the `.feature` file, so alias choice affects how tests appear in HTML and Allure reports. Pick the alias that is most readable for the business stakeholder who reads the output.

## The `*` Wildcard

The asterisk (`*`) can substitute for any step keyword. The runner assigns it the same semantic role as the previous keyword in the sequence. It reads well when you have a list of setup items where the repeated `Given`/`And` phrasing feels awkward:

```gherkin
Scenario: Weekly report includes all transactions
  Given the current user is a finance manager
  * there are transactions from Monday
  * there are transactions from Wednesday
  * there are transactions from Friday
  When the weekly report is generated
  Then the report shows 3 transaction days
```

## Complete Feature File Example

The following file uses every primary keyword:

```gherkin
@billing
Feature: Subscription management
  As a billing administrator
  I want to manage user subscriptions
  So that customers have access to the right plan features

  Background:
    Given the billing service is available
    And the product catalog is loaded

  Rule: Free plan users cannot access premium features

    Background:
      Given a user on the free plan

    Example: Free user is blocked from premium report
      When the user requests the premium usage report
      Then access is denied with "Upgrade required"

    Example: Free user can access basic dashboard
      When the user views the main dashboard
      Then the dashboard is displayed without restriction

  Rule: Pro plan users can access all standard features

    Scenario: Pro user downloads an invoice
      Given a user on the pro plan
      When the user downloads invoice "INV-2024-001"
      Then the PDF invoice is returned

  Scenario Outline: Plan upgrade confirmation email
    Given a user on the <current_plan> plan
    When the user upgrades to the <new_plan> plan
    Then a confirmation email is sent with subject "<email_subject>"

    Examples:
      | current_plan | new_plan   | email_subject                  |
      | free         | pro        | Welcome to Pro!                |
      | pro          | enterprise | Your Enterprise plan is active |
```

## How Cucumber Matches Step Keywords

!!! warning "Keywords are not part of step matching"
    The keyword (`Given`, `When`, `Then`, etc.) is **not** considered when Cucumber looks for a matching step definition. A step definition registered as `Given('the user is logged in', ...)` will also match `When the user is logged in` or `Then the user is logged in`. This means you cannot have two steps with identical text even if they use different keywords.

    Use distinct, unambiguous step text instead of relying on keyword differences.

## Localization

Gherkin supports 70+ spoken languages. Add a `# language: <code>` comment as the first line of a `.feature` file to enable localized keywords. For example, `# language: fr` enables French keywords (`Fonctionnalité`, `Scénario`, `Étant donné`, etc.).

See [Localization](localization.md) for the full language list and usage guide.

## Cross-References

- [Step Types](step-types.md) — detailed semantics for Given / When / Then / And / But / `*`
- [Scenario Outline](scenario-outline.md) — `<placeholder>` syntax and Examples tables
- [Background](background.md) — when to use Background and anti-patterns
- [Rules](rules.md) — Rule keyword deep-dive and Rule-level Background
- [Feature Files](feature-files.md) — file encoding, indentation, and description blocks
