---
title: Gherkin — Overview
description: Landing page for the Gherkin language and BDD foundations section of this knowledge base.
sources:
  - web-cucumber-bdd-overview-what-is-bdd
  - web-automation-panda-gherkin-language-introducing-gherkin
  - web-cucumber-gherkin-reference-keywords
---

# Gherkin

This section covers the **Gherkin language** — the structured plain-English format used to write executable specifications — and the **BDD foundations** that give it meaning. Whether you are picking up Gherkin for the first time or looking for a precise reference on a specific keyword, this is where to start.

## What's in this section

| Page | Who it's for |
|------|--------------|
| [Start Here](start-here.md) | Newcomers — defines BDD, Gherkin, and playwright-bdd and how they connect |
| [BDD vs. Plain Playwright](bdd-vs-playwright.md) | Teams deciding whether Gherkin is the right tool for their situation |
| [Glossary](glossary.md) | Quick definitions of every term used across this knowledge base |
| [Reference →](reference/keywords.md) | Deep reference on Gherkin keywords, syntax, and advanced features |
| [Best Practices →](best-practices/index.md) | Opinionated guidance on writing good scenarios |
| [Examples →](examples/index.md) | Working `.feature` files and step definitions you can copy |

## Who this is for

This knowledge base is written for two audiences simultaneously:

- **Human TypeScript developers** adopting playwright-bdd in a real project, who need both conceptual grounding and working code examples.
- **AI coding agents** (e.g. Claude Code) using this corpus as a RAG source to generate or review Gherkin scenarios and playwright-bdd step definitions. Every page follows a consistent structure that makes it machine-readable without sacrificing human readability.

## How to navigate

If you are **new to BDD**, read [Start Here](start-here.md) first. It gives you the mental model before you read anything else.

If you are **evaluating BDD** and not sure whether to adopt it, read [BDD vs. Plain Playwright](bdd-vs-playwright.md) next.

Once you have the foundations, the [Reference](reference/keywords.md) section is a precise lookup for syntax questions. The [Best Practices](best-practices/index.md) section covers the harder judgment calls — how to write scenarios that stay useful over time.

!!! tip "Quick orientation"
    Gherkin is the **language**. BDD is the **process**. playwright-bdd is the **toolchain** that connects Gherkin `.feature` files to Playwright tests. You need all three concepts to understand how they fit together — [Start Here](start-here.md) walks through exactly this.

```gherkin
# A minimal feature file — the atom of everything in this section
Feature: User authentication
  Scenario: Successful login
    Given a registered user "alice@example.com"
    When she logs in with valid credentials
    Then she sees her dashboard
```
