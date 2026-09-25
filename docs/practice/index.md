---
title: BDD in Practice
description: Landing page for the BDD in Practice tab — methodology, adoption, spec lifecycle, and tooling guidance for teams using BDD with playwright-bdd.
sources:
  - web-cucumber-bdd-overview-what-is-bdd
  - web-cucumber-bdd-overview-three-practices
  - web-monday-bdd-guide-what-is-behavior-driven-development
  - web-bdd-living-documentation-behavior-driven-development-aligning-stakeholders-through-living-documentation
---

# BDD in Practice

This tab covers the human side of BDD: how teams discover requirements through conversation, how examples become specifications, and how the whole process holds together over time. It complements the [Gherkin reference](../gherkin/index.md) (which covers syntax) and the [playwright-bdd](playwright-bdd/index.md) section (which covers tooling).

## What is in this tab

| Section | What you will find |
|---|---|
| **Methodology** | The three phases (Discovery, Formulation, Automation), Three Amigos, Example Mapping, Specification by Example |
| **Adoption** | Getting started greenfield or brownfield, why adoptions fail, team patterns |
| **Spec Lifecycle** | Writing, updating, and pruning scenarios over the life of a feature |
| **At Scale** | Shared step libraries, monorepo scoping, vocabulary governance, CI at 500+ scenarios |

## Who this tab is for

### Newcomer to BDD

Start with the methodology overview, then move to the adoption guides:

1. [What BDD Is](methodology/bdd-overview.md) — collaboration first, automation second
2. [Discovery → Automation](methodology/discovery-to-automation.md) — the three phases in depth
3. [Why BDD Adoptions Fail](adoption/why-bdd-fails.md) — avoid the most common traps before you start
4. [First 90 Days](adoption/first-90-days.md) — a concrete rollout plan

### TypeScript developer integrating playwright-bdd

You probably already have Playwright tests. The key question is whether Gherkin adds value to your workflow:

1. [BDD vs. Playwright](methodology/bdd-vs-playwright.md) — the real trade-off, decision framework
2. [Discovery to Automation](methodology/discovery-to-automation.md) — understand the process your feature files should reflect
3. [playwright-bdd setup](playwright-bdd/index.md) — once you have decided to proceed

### Team lead or product owner

You need to understand what BDD asks of your team and how to make it stick:

1. [Three Amigos](methodology/three-amigos.md) — who is in the room, when, and what comes out
2. [Example Mapping](methodology/example-mapping.md) — how to run a discovery session
3. [Specification by Example](methodology/specification-by-example.md) — the long-term destination
4. [Adoption Patterns](adoption/team-patterns.md) — roles, ownership, and organizational fit

## The core idea

BDD works when the conversation happens before the code. The feature file is a record of a shared understanding that was reached before anyone opened an editor. When teams skip the conversation and write Gherkin directly from a ticket, they get automation without the collaboration benefit — sometimes called "Cucumber theater."

```gherkin
# This is a record of a conversation, not a test script.
Feature: Account suspension
  Rule: Suspended accounts cannot log in

    Example: Suspended user is denied access
      Given Alice's account has been suspended by an administrator
      When Alice attempts to log in with her credentials
      Then she sees the message "Your account has been suspended"
      And she is not redirected to the dashboard
```

The scenario above came from a Three Amigos session. The product owner provided the business rule. The tester asked "what does she see?" The developer asked "is the suspension immediate?" Those questions were answered in the meeting, not in a Jira comment three days later.

!!! tip "Start with the conversation"
    If your team is new to BDD, run one Example Mapping session on one upcoming story before writing any Gherkin. The map is the deliverable — Gherkin can follow.
