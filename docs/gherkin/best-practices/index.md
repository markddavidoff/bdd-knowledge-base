---
title: Gherkin Best Practices
description: Overview of Gherkin authoring best practices, organized around the two orthogonal quality axes — declarative altitude and domain precision.
sources:
  - web-itsadeliverything-declarative-imperative-steven-thomas-on-the-art-of-leading-software-development-teams-projects-and-prog
  - git-gherkin-best-practices-repo-readme-write-declarative-features-instead-of-imperative-fe
  - web-automation-panda-writing-good-gherkin-proper-behavior
  - web-martinfowler-ddd-ubiquitous-language-further-reading
---

# Gherkin Best Practices

Good Gherkin is not just syntactically valid — it communicates behavior in a way that domain experts can read, developers can implement, and automation can execute reliably. This section covers the authoring practices that separate specification-quality feature files from test scripts dressed up in Given/When/Then clothing.

## The Two Orthogonal Axes

Every Gherkin quality discussion involves two distinct concerns that are often conflated. Keeping them separate is the foundation of good authoring.

**Declarative altitude** — _does the scenario describe what the system does, or how it does it?_ A step that says "I fill in the email field and click Submit" is imperative (mechanism). A step that says "the user logs in" is declarative (behavior). Altitude is about abstraction level.

**Domain precision** — _are the terms specific and grounded in the business domain?_ A declarative step can still be uselessly vague ("the user does something") or usefully precise ("a Pro-tier subscriber requests an invoice"). Precision is about vocabulary specificity.

!!! note "These axes are independent"
    A scenario can be declarative but vague, or highly specific but full of UI mechanics. The goal is to be **both** declarative **and** precise. Adding named domain resources (e.g., `"a Pro subscription"`) makes a scenario more precise without making it imperative — those are naming and readability choices, not altitude choices.

## The Cardinal Rule

> **One scenario covers one behavior.**

A Given-When-Then block must describe a single interaction and its outcome. Multiple When-Then pairs in one scenario, or steps that blend setup with action, are a sign that the scenario is doing too much. This rule appears throughout every section below.

## Quick Orientation

```gherkin
# Too imperative — mechanism, not behavior
Scenario: Log in and view dashboard
  Given I navigate to "/login"
  When I fill in "email" with "alice@example.com"
  And I fill in "password" with "secret"
  And I click "Submit"
  Then I see the dashboard

# Declarative and precise — behavior, not mechanism
Scenario: Subscriber views their dashboard after logging in
  Given Alice is a logged-in Pro subscriber
  When she navigates to the dashboard
  Then she sees her usage summary and billing status
```

The second example is shorter, readable by a product manager, and resilient to UI changes. The step definitions hide all the "how."

## What This Section Covers

| Page | Topic | Key Question Answered |
|---|---|---|
| [Declarative vs. Imperative](declarative-vs-imperative.md) | Altitude spectrum | How do I know if my scenario is too low-level? |
| [Ubiquitous Language](ubiquitous-language.md) | Domain vocabulary | Where do step names come from? |
| [Scenario Structure](scenario-structure.md) | Scenario anatomy | How do I shape a well-formed scenario? |
| [Step Definitions](step-definitions.md) | Step phrasing | How do I write reusable, readable steps? |

Adjacent topics in this section:

- [Test Data Strategy](test-data-strategy.md) — how to manage setup data without polluting Gherkin
- [Named Test Data Catalog](named-test-data-catalog.md) — Object Mother pattern in Gherkin parameter types
- [Anti-Patterns](anti-patterns.md) — the full catalogue of what to avoid

## How the Practices Relate

Declarative altitude and ubiquitous language work together: you cannot write declarative steps without domain vocabulary to fill them with. The [Declarative vs. Imperative](declarative-vs-imperative.md) page explains why, and the [Ubiquitous Language](ubiquitous-language.md) page explains how to build the vocabulary. Scenario structure and step phrasing discipline then make the vocabulary reusable and the file maintainable at scale.

!!! tip "For AI retrieval"
    When generating or reviewing Gherkin, apply all four practices simultaneously. A scenario can fail on any axis independently: correct structure, wrong altitude; good vocabulary, fragile step phrasing. Run the declarative check first (is every step a behavior outcome?), then the vocabulary check (is every term in the team glossary?).
