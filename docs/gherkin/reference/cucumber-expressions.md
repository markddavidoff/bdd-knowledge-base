---
title: Cucumber Expressions
description: Complete reference for Cucumber Expressions — built-in parameter types, optional text, alternatives, escaping, anchoring, and when to use Cucumber Expressions vs. regular expressions.
sources:
  - git-cucumber-expressions-readme-introduction
  - git-cucumber-expressions-readme-parameter-types
  - git-cucumber-expressions-readme-optional-text
  - git-cucumber-expressions-readme-alternative-text
  - git-cucumber-expressions-readme-escaping
  - git-cucumber-js-docs-supportfiles-stepdefinitions-cucumber-expressions
  - git-playwright-bdd-repo-docs-writing-steps-data-tables-data-tables
---

# Cucumber Expressions

A **Cucumber Expression** is the string pattern used in a step definition to match Gherkin step text and extract typed arguments. It is the default pattern format in all modern Cucumber implementations, replacing raw regular expressions for most uses.

```gherkin
Given I have 42 cucumbers in my belly
```

```ts
import { createBdd } from 'playwright-bdd';

const { Given } = createBdd();

Given('I have {int} cucumbers in my belly', async ({}, count: number) => {
  // count === 42
});
```

---

## Built-in parameter types

Text between curly braces is an **output parameter** — it is matched, extracted, and type-converted before being passed to the step function.

| Type | Pattern | TypeScript type | Notes |
|---|---|---|---|
| `{int}` | Integers: `42`, `-7` | `number` | No decimal point; negative supported |
| `{float}` | Floats: `3.14`, `.5`, `-9.2` | `number` | Includes integers when decimal-point optional |
| `{word}` | Single unquoted word: `banana` | `string` | No whitespace; stops at first space |
| `{string}` | Quoted string: `"hello"` or `'hello'` | `string` | Quotes stripped; supports both `"` and `'` |
| `{}` | Anything | `string` | Anonymous: matches `/.*/`; greedy |

### `{string}` — quoted strings

`{string}` matches text in **double or single quotes**. The quotes are consumed by the matcher and not passed to the function:

```gherkin
When I open url "https://playwright.dev"
When I open url 'https://playwright.dev'
```

```ts
When('I open url {string}', async ({ page }, url: string) => {
  // url === 'https://playwright.dev'  (no quotes)
  await page.goto(url);
});
```

### `{int}` — integers

```gherkin
Given the cart has {int} item(s)
```

Matches `1`, `0`, `-3`. Does **not** match `3.5`. The value arrives as a JavaScript `number`.

### `{float}` — floating-point numbers

```gherkin
Then the total is {float} USD
```

Matches `9.99`, `0.5`, `-1.00`. Also matches integers (e.g., `10` is valid).

### `{word}` — single unquoted word

```gherkin
Given the user has {word} status
```

Matches `active`, `suspended`, `pending`. Stops at whitespace — does not match `"very active"`.

### `{}` — anonymous

The anonymous parameter matches anything and is passed as a `string`. Prefer named parameters for clarity; use anonymous only when a more specific type genuinely does not exist.

```gherkin
Then the response contains {}
```

---

## Optional text

Wrap text in parentheses to make it **optional**. The match succeeds whether or not the optional text appears:

```gherkin
I have {int} cucumber(s) in my belly
```

This matches both:
- `I have 1 cucumber in my belly`
- `I have 42 cucumbers in my belly`

!!! note "Parentheses mean optional, not capture groups"
    In regular expressions, `()` creates a capture group. In Cucumber Expressions, `()` means optional text. This is a deliberate difference to keep expressions readable.

---

## Alternative text

Use `/` to offer alternative word choices at the same position:

```gherkin
I have {int} cucumber(s) in my belly/stomach
```

This matches all four combinations:
- `I have 1 cucumber in my belly`
- `I have 42 cucumbers in my belly`
- `I have 1 cucumber in my stomach`
- `I have 42 cucumbers in my stomach`

!!! warning "No whitespace around /"
    Alternative text only works when there is no whitespace between the alternatives. `belly / stomach` is a literal `/`, not an alternative.

---

## Escaping special characters

To match a literal `{`, `}`, `(`, `)`, or `/`, escape the opening character with a backslash:

```
I have {int} \{what} cucumber(s) in my belly \(amazing!)
```

Matches:
- `I have 1 {what} cucumber in my belly (amazing!)`
- `I have 42 {what} cucumbers in my belly (amazing!)`

In most languages you need to double-escape for string literals:

```ts
Given('I have {int} \\{what} cucumber(s) in my belly \\(amazing!)', ...)
```

To match a literal `/`, use `\/`.

---

## Cucumber Expressions vs. regular expressions

Both are valid step patterns. Choose based on readability and complexity.

| Situation | Prefer |
|---|---|
| Simple typed extraction (`{int}`, `{string}`) | Cucumber Expression |
| Named domain types (`{user-role}`, `{org-plan}`) | Cucumber Expression + `defineParameterType` |
| Complex multi-group pattern | Regular expression |
| Unicode or locale-specific matching | Regular expression |
| Migration from legacy Cucumber suite | Regular expression (defer refactor) |

### Anchoring behaviour

Cucumber Expressions have **implicit anchoring** — the pattern must match the entire step text, as if surrounded by `^` and `$`. You do not (and should not) add explicit anchors.

Regular expressions in step definitions also have implicit anchoring in most Cucumber implementations, but the behavior can vary by runner.

### Snippet generation

When a step has no matching definition, Cucumber generates a code snippet. Cucumber Expressions produce cleaner snippets than regular expressions:

```
# Cucumber Expression snippet
Given('I have {int} cucumber(s)', async ({}, count: number) => { ... });

# RegExp snippet
Given(/^I have (\d+) cucumbers?$/, async ({}, count: string) => { ... });
```

With Cucumber Expressions, the argument type is inferred from the built-in parameter type. With regular expressions, arguments arrive as `string` and must be cast manually.

---

## Full example with multiple types

The following step definition uses `{int}`, `{string}`, and `{float}` together, demonstrating how Cucumber Expressions handle multiple typed captures in a single step:

```gherkin
Feature: Order pricing

  Scenario: Apply discount to a single-item order
    When I order {int} "Acme Widget" at {float} USD each with a {int}% discount
    Then the line total should be {float} USD
```

```ts
import { createBdd } from 'playwright-bdd';

const { When, Then } = createBdd();

When(
  'I order {int} {string} at {float} USD each with a {int}% discount',
  async ({ orderBuilder }, qty: number, name: string, unitPrice: number, discountPct: number) => {
    const lineTotal = qty * unitPrice * (1 - discountPct / 100);
    orderBuilder.addLine({ name, qty, unitPrice, lineTotal });
  }
);

Then(
  'the line total should be {float} USD',
  async ({ orderBuilder }, expected: number) => {
    expect(orderBuilder.lastLineTotal()).toBeCloseTo(expected, 2);
  }
);
```

!!! tip "Use {string} for names, not {word}"
    Product names, user names, and other domain strings often contain spaces. Use `{string}` (requires quotes in the Gherkin) rather than `{word}` (breaks on whitespace). The quotes in the feature file signal to readers that the value is a significant label.

---

## Cross-references

- [Custom Parameter Types](custom-parameter-types.md) — defining `{user-role}`, `{org-plan}`, and other domain types
- [Step Types](step-types.md) — Given, When, Then and how step text is matched
- [Named Test Data Catalog](../best-practices/named-test-data-catalog.md) — parameter types as Object Mother interface
