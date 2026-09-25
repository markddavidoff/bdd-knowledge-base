---
title: Related BDD Ecosystem
description: Overview of the BDD runner landscape across languages and frameworks, with orientation for teams migrating to or from playwright-bdd.
sources:
  - web-playwright-bdd-vs-cucumber-cucumber-js-vs-playwright-bdd-comparison
  - web-playwright-bdd-vs-cucumber-which-should-you-choose
  - web-playwright-bdd-vs-cucumber-feature-differences-by-test-runner
  - git-playwright-bdd-repo-docs-index-index
---

# Related BDD Ecosystem

This section orients developers who arrive at this KB from other stacks, or who need to choose between BDD runners. This KB's primary focus is **TypeScript + playwright-bdd**, but the Gherkin specification language is shared across all BDD frameworks.

## Gherkin is Portable

The `.feature` file you write for playwright-bdd is valid for every runner listed here. The syntax — `Feature:`, `Scenario:`, `Given`/`When`/`Then`, `Background:`, `Rule:`, `Scenario Outline:`, tags, data tables, doc strings — is defined once in the [Gherkin specification](https://cucumber.io/docs/gherkin/) and implemented identically across languages.

```gherkin
Feature: Account registration

  Scenario: New user registers with valid email
    Given no account exists for "alex@example.com"
    When Alex registers with email "alex@example.com" and password "Secret123"
    Then Alex's account is active
    And a welcome email is sent to "alex@example.com"
```

This feature file runs unchanged in CucumberJS, SpecFlow, Behave, pytest-bdd, Cucumber-JVM, and playwright-bdd.

## What Differs Between Runners

The `.feature` file is the same; everything in step definitions diverges:

| Dimension | playwright-bdd | @cucumber/cucumber | SpecFlow (C#) | Behave (Python) | pytest-bdd (Python) | Cucumber-JVM (Java) |
|-----------|---------------|-------------------|---------------|-----------------|---------------------|---------------------|
| Step imports | `createBdd()` | `Given/When/Then` from `@cucumber/cucumber` | `[Given]` attributes | `@given` decorator | `@given` decorator | `@Given` annotation |
| State model | Playwright fixtures (`{ page, ... }`) | World object (`this`) | DI container | `context` object | pytest fixtures (by name) | DI / Spring |
| Arrow functions | Yes | No (World requires `function`) | N/A | N/A | N/A | N/A |
| Parameter types | `defineParameterType` from `playwright-bdd` | `defineParameterType` from `@cucumber/cucumber` | Value Retrievers | `@register_type` | `parsers.parse` | `@ParameterType` |
| Runner features | Playwright Test (sharding, trace, VRT) | Cucumber runner | NUnit / xUnit | pytest | pytest | JUnit / TestNG |

## Choosing a Runner

**Choose playwright-bdd when:**

- Your project uses a browser (UI testing is any part of the suite)
- You want Playwright fixtures, trace viewer, sharding, and `toHaveScreenshot()` without extra setup
- You are starting a new TypeScript project

**Choose `@cucumber/cucumber` when:**

- You are testing pure API/backend services with no browser automation needed
- You have an existing large CucumberJS codebase
- You need specific CucumberJS ecosystem reporters or plugins

**Choose a non-JS runner when:**

- Your implementation language is C#, Python, or Java and your team's expertise is there
- You are integrating with a test infrastructure already built for that stack

## Migration Guide Cross-References

If you are moving from another runner to playwright-bdd, see [Migration Paths](../playwright-bdd/migration.md). The feature files need no changes; only step definitions require rewriting.

## Pages in This Section

- [CucumberJS (@cucumber/cucumber)](cucumber-js.md) — the JS/TS runner this KB compares most directly
- [SpecFlow (C#)](specflow.md) — for teams crossing from .NET
- [Behave (Python)](behave.md) — for Python backend teams
- [pytest-bdd (Python)](pytest-bdd.md) — pytest-native BDD with a different state model
- [Cucumber-JVM (Java)](cucumber-jvm.md) — for Java/Spring teams
- [Alternatives](alternatives.md) — BDD-style approaches that skip `.feature` files entirely

!!! note
    All runner-specific pages follow the same structure: a reference feature file, the runner's step definition implementation, and a migration map for the key concepts that differ from playwright-bdd.
