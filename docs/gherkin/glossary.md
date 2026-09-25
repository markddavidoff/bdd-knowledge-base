---
title: Glossary
description: Definitions of every key term used across the BDD/Gherkin knowledge base — from Gherkin syntax to design patterns to methodology concepts.
sources:
  - web-cucumber-bdd-overview-what-is-bdd
  - web-cucumber-bdd-overview-three-practices
  - web-cucumber-gherkin-reference-keywords
  - web-automation-panda-gherkin-language-introducing-gherkin
  - web-bdd-living-documentation-what-is-behavior-driven-development
  - web-monday-bdd-guide-bdd-vs-tdd-choosing-the-right-approach
  - web-bdd-living-documentation-aligning-stakeholders-through-collaboration
---

# Glossary

Definitions for every term used across this knowledge base. Terms are grouped thematically; use your browser's find (`Ctrl+F` / `⌘F`) to locate a specific word.

---

## Core BDD Concepts

**BDD (Behavior-Driven Development)**
A software development practice — originated by Dan North in 2006 — in which teams use concrete examples of system behavior to align business and technical perspectives before coding begins. BDD extends TDD by operating at the acceptance level and using business language throughout. Collaboration comes first; automation is a side effect. See [Start Here](start-here.md).

**ATDD (Acceptance Test-Driven Development)**
A closely related practice in which acceptance tests are written before implementation begins. BDD can be thought of as ATDD with extra emphasis on the *language* used and the *collaboration process* that produces the tests. The two terms are often used interchangeably in practice.

**Specification by Example**
A technique (described by Gojko Adzic) for capturing requirements as concrete, real-world examples rather than abstract rules. The examples become the acceptance tests. BDD's Three Amigos + Example Mapping workflow is one way to practice Specification by Example.

**Living Documentation**
Documentation that is automatically verified against the system's actual behavior on every CI run. Gherkin feature files connected to automated tests produce living documentation. If a scenario passes, the documentation is accurate. If it fails, the documentation or the code is wrong — not just the test. See [practice/methodology/living-documentation](../practice/methodology/living-documentation/index.md).

**Three Amigos**
A structured conversation involving three roles: a business expert (product owner or BA), a developer, and a tester. The three amigos discuss a user story *before* development starts, using concrete examples to reach shared understanding and uncover edge cases. The output is a set of agreed examples ready for formulation as Gherkin scenarios. See [Three Amigos](../practice/methodology/three-amigos.md).

**Example Mapping**
A facilitation technique (by Matt Wynne) for running a Three Amigos session. Rules (business rules), Examples (concrete scenarios), and Questions (open unknowns) are written on color-coded index cards. A story is ready for development when the map has few questions left. See [Example Mapping](../practice/methodology/example-mapping.md).

**Ubiquitous Language**
A term from Domain-Driven Design (Eric Evans). A shared vocabulary, agreed by the whole team, that is used consistently in conversations, code, and Gherkin scenarios. When the Gherkin uses the same words as the product spec and the codebase, the team has achieved ubiquitous language. See [Ubiquitous Language](best-practices/ubiquitous-language.md).

**Cucumber Theater**
An anti-pattern where a team writes Gherkin feature files but without the collaboration practices (Three Amigos, Example Mapping). The result looks like BDD but delivers none of its value — scenarios are written after the fact, step definitions are imperative, and no stakeholder reads the reports. See [Anti-Patterns](best-practices/anti-patterns.md).

---

## Gherkin Language

**Gherkin**
The domain-specific language for writing BDD scenarios. Stored in `.feature` files (plain text, UTF-8). Gherkin has a fixed keyword vocabulary (`Feature`, `Scenario`, `Given`, `When`, `Then`, `And`, `But`, `Background`, `Rule`, `Scenario Outline`, `Examples`, `@tags`). Maintained as part of the Cucumber project. See [Reference: Keywords](reference/keywords.md).

**Feature**
The top-level Gherkin keyword. Each `.feature` file contains exactly one `Feature` block. The feature title and optional description (including the Connextra "As a / In order to / So that" narrative) are documentation only — Cucumber ignores them at runtime.

```gherkin
Feature: Subscription management
  As a paying customer
  I want to manage my subscription plan
  So that I can control my billing
```

**Scenario** (alias: `Example`)
A single concrete example of system behavior. Each scenario is a test case consisting of `Given`, `When`, and `Then` steps. `Scenario` and `Example` are synonyms in Gherkin 6+. Aim for 3–5 steps per scenario. See [Reference: Keywords](reference/keywords.md).

**Scenario Outline** (alias: `Scenario Template`)
A parameterized scenario that runs once for each row in an `Examples` table. Placeholders in the step text (`<column-name>`) are replaced with values from the table. Use when the same behavior needs to be verified across multiple data combinations. See [Reference: Scenario Outline](reference/scenario-outline.md).

```gherkin
Scenario Outline: Plan upgrade pricing
  Given a user on the <from_plan> plan
  When they upgrade to <to_plan>
  Then the price difference is <charge>

  Examples:
    | from_plan | to_plan    | charge |
    | free      | pro        | $12.00 |
    | pro       | enterprise | $38.00 |
```

**Background**
A sequence of `Given` steps placed before the first `Scenario` in a `Feature` (or `Rule`). Runs before each scenario in scope. Use only for setup that is *essential context* for every scenario in the block — avoid putting incidental details here. See [Reference: Background](reference/background.md).

**Rule**
A Gherkin 6+ keyword that groups related scenarios under a named business rule. Useful for large feature files where different rules govern different behaviors. A `Rule` can have its own `Background`. See [Reference: Rules](reference/rules.md).

**Given / When / Then**
The three core step keywords. `Given` establishes preconditions (system state before the action). `When` describes the action or event under test. `Then` asserts the observable outcome. `And` and `But` are continuation keywords — they repeat the role of the previous primary keyword. The asterisk (`*`) can replace any step keyword when a list-style format reads more naturally.

**Step Definition**
A TypeScript (or other language) function that implements a Gherkin step. Matched to step text via a Cucumber Expression or regular expression. The step definition is the bridge between the human-readable spec and the automation code. See [Best Practices: Step Definitions](best-practices/step-definitions.md).

**Tag**
A label attached to a `Feature`, `Rule`, `Scenario`, or `Examples` table with the `@` prefix (e.g., `@smoke`, `@regression`, `@wip`). Tags are used to filter which scenarios run (`--grep @smoke`), configure hooks conditionally, and classify test suites. Tags inherit downward (a tag on `Feature` applies to all its scenarios). See [Reference: Tags](reference/tags-classification.md).

**Tag Expression**
A boolean expression combining tags with `and`, `or`, `not`, and parentheses, used in CLI filters. Example: `@smoke and not @slow`. See [Reference: Tags (lifecycle)](reference/tags-lifecycle.md).

---

## Patterns and Techniques

**Declarative vs. Imperative**
The most important Gherkin quality axis. *Imperative* steps describe mechanism (`click the login button`, `fill in the email field`). *Declarative* steps describe intent (`log in as Alice`, `view the account dashboard`). Declarative scenarios survive UI changes; imperative ones break every time the UI changes. See [Declarative vs. Imperative](best-practices/declarative-vs-imperative.md).

**BRIEF Principle**
A five-property quality heuristic for scenarios: **B**usiness language (no tech jargon), **R**ealistic (uses real-world values), **I**ntent-revealing (the purpose is clear), **E**ssential (every step is needed), **F**ocused (one behavior per scenario). Apply these as a review checklist before merging a feature file.

**Object Mother**
A design pattern (Fowler / Schuh, 2002) for test data. An Object Mother provides named, canonical instances of domain objects — pre-configured, team-familiar, and ready to use. In Gherkin, Object Mothers are implemented as custom parameter types: `{user-role}` matching `admin|editor|viewer` returns a canonical user configuration by name. See [Named Test Data Catalog](best-practices/named-test-data-catalog.md).

**Test Data Builder**
A fluent builder pattern (Freeman / Pryce, *Growing Object-Oriented Software*) for creating test data with small, targeted variations from an Object Mother baseline. Step definitions combine an Object Mother base with a Data Table of overrides:

```gherkin
Given an organization with the following overrides:
  | plan    | seat_limit |
  | pro     | 50         |
```

See [Named Test Data Catalog](best-practices/named-test-data-catalog.md).

**Parameter Type**
A custom type registered with `defineParameterType` that matches a named token in a Cucumber Expression (e.g., `{org-plan}`) and transforms the matched string into a domain object. Parameter types are the mechanism that makes declarative, named-resource Gherkin possible. See [Reference: Custom Parameter Types](reference/custom-parameter-types.md).

---

## Tooling

**Cucumber**
The open-source project that maintains the Gherkin language standard and multiple test runners (CucumberJS for Node.js, Cucumber-JVM for Java, Behave for Python, SpecFlow for C#). This knowledge base focuses on the TypeScript/Node.js ecosystem.

**playwright-bdd**
A library by Vitaliy Potapov that integrates Gherkin feature files with the Playwright Test runner. Provides `createBdd()` for writing fixture-based step definitions, and the `bddgen` CLI that generates `.spec.ts` files from `.feature` files. See [practice/playwright-bdd](../practice/playwright-bdd/index.md).

```typescript
// playwright-bdd step definition pattern
import { createBdd } from 'playwright-bdd';
const { Given, When, Then } = createBdd(test);

Given('a registered user {string}', async ({ page }, email: string) => {
  // implementation
});
```

**Fixture**
In Playwright Test (and playwright-bdd), a fixture is a dependency injected into a test function via function parameters. Fixtures replace the `World` object from CucumberJS. `page`, `request`, and `browser` are built-in Playwright fixtures; teams extend them with custom fixtures for shared state (e.g., `authenticatedPage`, `db`). See [practice/playwright-bdd: Fixtures](../practice/playwright-bdd/fixtures.md).

**bddgen**
The `playwright-bdd` CLI command that parses `.feature` files and generates corresponding `.spec.ts` test files. Run as a pre-step before `playwright test` in CI. Running `bddgen` in dry-run mode detects undefined steps without executing any tests.

**Cucumber Expression**
A string-based matching syntax for step definitions, simpler than regular expressions. Built-in parameter types include `{string}`, `{int}`, `{float}`, `{word}`. Supports optional text (`(s)`) and alternatives (`free/paid`). See [Reference: Cucumber Expressions](reference/cucumber-expressions.md).

---

## Process and Organization

**Discovery / Formulation / Automation**
Cucumber's three-phase model of the BDD cycle. Discovery = collaborative conversation about examples. Formulation = writing those examples as Gherkin. Automation = connecting Gherkin steps to running code. All three phases are required for BDD to deliver value; skipping Discovery produces Cucumber Theater.

**Vocabulary Registry**
A `parameters.ts` file (or equivalent module) that registers all custom parameter types for a project. Acts as a living glossary of named test resources — every domain concept that appears in step text as a named token has an entry here. The registry is the team's canonical reference for what named values like `"a pro organization"` or `"Alice"` mean in test context.
