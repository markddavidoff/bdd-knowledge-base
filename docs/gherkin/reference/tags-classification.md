---
title: Tags — Classification
description: Reference for classification tags in Gherkin — smoke, regression, e2e, integration, api, ui, happy-path, error-path — plus tag placement, inheritance, tag expressions, and CLI filtering.
sources:
  - web-cucumber-api-reference-tags
  - git-gherkin-best-practices-repo-readme-use-tags-to-organize-your-features-and-scenarios
  - git-cucumber-js-docs-filtering-tags
  - git-playwright-bdd-repo-docs-configuration-options-tags
  - git-playwright-bdd-repo-docs-writing-steps-bdd-fixtures-tags
  - git-gherkin-parser-testdata-good-tags-feature-tags-feature
---

# Tags — Classification

Tags organize scenarios into named groups that can be targeted by CI pipelines, local filtering, and hook conditions. Classification tags describe **what kind** of test a scenario is; they are stable, long-lived, and meaningful outside a single sprint.

---

## Tag syntax and placement

A tag is any `@`-prefixed word with no spaces:

```gherkin
@smoke @regression
Feature: Payment processing

  @happy-path @api
  Scenario: Successful card charge

  @error-path @api
  Scenario: Declined card returns 402
```

Tags can be placed above:

- `Feature`
- `Rule`
- `Scenario` / `Scenario Outline`
- `Examples` (inside a Scenario Outline)

Tags **cannot** be placed above `Background` blocks or individual `Given`/`When`/`Then` steps.

Multiple tags on one element are space-separated and can wrap across lines:

```gherkin
@billing
@regression @e2e
Scenario: Subscription renewal flow
```

---

## Tag inheritance

Tags placed on a parent element are **inherited** by all child elements. A tag on `Feature` applies to every scenario in the file. A tag on `Scenario Outline` applies to every `Examples` table row.

```gherkin
@integration
Feature: User service API

  # All scenarios below implicitly carry @integration
  Scenario: Create user        # effective tags: @integration @happy-path
    @happy-path
    ...
```

This means you should not repeat a parent tag on every child — inheritance handles it.

---

## Classification tag reference

These are the conventional tags used across BDD projects. Define what each means in your team's tag taxonomy document (see [Tag Governance](../best-practices/tag-taxonomy.md)).

### Scope / layer tags

| Tag | Meaning |
|---|---|
| `@e2e` | Full end-to-end flow through the real stack; typically slowest |
| `@integration` | Multi-component test; some real infrastructure, some mocked |
| `@api` | Tests via HTTP API only; no browser |
| `@ui` | Browser-driven test via Playwright |
| `@component` | Single component in isolation (unit-level BDD) |

### Suite tags

| Tag | Meaning |
|---|---|
| `@smoke` | Minimal set confirming the system is alive; run on every deploy |
| `@regression` | Full suite guarding against regressions; run nightly or on release |

!!! warning "Define @smoke explicitly"
    "@smoke" is meaningless unless documented. Teams frequently add scenarios tagged `@smoke` without a shared understanding of scope. Define it as: "the smallest set of scenarios that confirms the critical path is unbroken." Enforce the definition in PR review.

### Path tags

| Tag | Meaning |
|---|---|
| `@happy-path` | Primary success flow; inputs are valid, system behaves nominally |
| `@error-path` | Error and rejection flows; invalid inputs, system errors, edge cases |

### Environment tags

| Tag | Meaning |
|---|---|
| `@live-only` | Requires real external integrations; cannot run against mocks |
| `@mock-only` | Requires mock infrastructure; not valid against live services |
| `@slow` | Expected execution time >30 s; excluded from fast feedback loops |
| `@fast` | Confirmed fast (<5 s); safe to include in pre-commit gates |

---

## Tag expressions

Tag expressions are infix boolean expressions used to select which scenarios to run. Supported operators: `and`, `or`, `not`, and parentheses.

| Expression | Selects |
|---|---|
| `@smoke` | All scenarios tagged `@smoke` |
| `@smoke and @api` | Scenarios tagged both `@smoke` and `@api` |
| `@regression and not @slow` | Regression suite excluding slow scenarios |
| `@smoke or @e2e` | Either smoke or e2e |
| `(@smoke or @ui) and not @slow` | Smoke or UI, but never slow |

---

## CLI filtering

### playwright-bdd

Pass a tag expression to `bddgen` or `playwright test` via the `--grep` flag (Playwright's tag filter):

```bash
# Run only smoke tests
npx bddgen --tags "@smoke"

# Run regression but skip slow tests
npx playwright test --grep "@regression" --grep-invert "@slow"
```

Or set the expression in `playwright.config.ts` for a specific project:

```ts
import { defineBddConfig } from 'playwright-bdd';

const smokeDir = defineBddConfig({
  tags: '@smoke and not @slow',
  paths: ['features/**/*.feature'],
  importTestFrom: 'steps/fixtures.ts',
});
```

### CucumberJS

```bash
npx cucumber-js --tags "@smoke and @api"
npx cucumber-js --tags "@regression and not @slow"
```

Multiple `--tags` flags are combined with `and`:

```bash
npx cucumber-js --tags "@smoke" --tags "not @slow"
# equivalent to: @smoke and not @slow
```

---

## Tag-driven hook filtering

Tags also gate hooks in step definition files. In playwright-bdd, access current scenario tags via the `$tags` fixture:

```ts
import { createBdd } from 'playwright-bdd';

const { Before } = createBdd();

// Only seed the payment DB for billing-tagged scenarios
Before({ tags: '@billing' }, async ({ db }) => {
  await db.payments.seed();
});
```

You can also read `$tags` inside step definitions for conditional logic:

```ts
Given('I perform an action', async ({ $tags, apiClient }) => {
  if ($tags.includes('@live-only')) {
    // Skip mock setup
  }
});
```

---

## Tag sprawl and governance

Tags accumulate over time. Without governance, a project ends up with dozens of overlapping tags that no one understands. Recommendations:

1. Maintain a **tag taxonomy document** listing all approved tags and their definitions.
2. Enforce allowed tags with [`gherkin-lint`](../../practice/tooling/gherkin-linter.md) using the `allowed-tags` rule.
3. Review new tags in the PR checklist — every new tag needs a definition.
4. Audit quarterly: remove tags no one uses; merge overlapping synonyms.

---

## Cross-references

- [Tags — Lifecycle](tags-lifecycle.md) — `@wip`, `@skip`, `@quarantine`, `@only`
- [Tag Governance](../best-practices/tag-taxonomy.md) — designing and enforcing a tag taxonomy
- [CI Integration](../../practice/spec-lifecycle/ci-running.md) — tag-based CI pipeline recipes
