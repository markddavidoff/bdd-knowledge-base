---
title: What BDD Is (and Isn't)
description: BDD is a collaboration technique that uses concrete examples to build shared understanding — automation is a valuable side effect, not the goal.
sources:
  - web-cucumber-bdd-overview-what-is-bdd
  - web-cucumber-bdd-overview-three-practices
  - web-monday-bdd-guide-what-is-behavior-driven-development
  - web-monday-bdd-guide-bdd-vs-tdd-choosing-the-right-approach
  - web-liz-keogh-bdd-blog-what-is-bdd-https-lizkeogh-com-2015-03-27-what-is-bdd
  - web-bdd-living-documentation-aligning-stakeholders-through-collaboration
---

# What BDD Is (and Isn't)

Behavior-Driven Development is a way for software teams to close the gap between business people and technical people. The word "Development" in BDD is important: this is a development methodology, not a testing framework. Automated tests are a valuable side effect of BDD done well, but they are not the goal.

The goal is **shared understanding** — reached through structured conversations that happen before any code is written.

## BDD vs. TDD

BDD and Test-Driven Development solve different problems at different altitudes. They work best together rather than as alternatives:

| Aspect | BDD | TDD |
|---|---|---|
| Focus | User-observable behavior | Internal code design |
| Language | Plain English (Gherkin) | Programming language |
| Primary audience | Whole team (business + technical) | Developers |
| Scope | Feature / acceptance level | Unit / component level |
| When to use | Defining what to build | Designing how to build it |

A BDD scenario answers "does the system do the right thing?" A TDD test answers "does this function work correctly?" Both questions matter. Many teams use BDD at the acceptance layer and TDD inside the implementation — BDD drives the outer loop, TDD drives the inner loop.

## BDD vs. ATDD

Acceptance Test-Driven Development (ATDD) predates BDD and shares the same core principle: write acceptance criteria before writing code. BDD is a refined version of ATDD that adds:

- A specific emphasis on **conversation** before automation
- The **Given-When-Then** structure as a shared vocabulary
- The **Three Amigos** collaboration pattern
- A named discovery technique (Example Mapping)

The terms are sometimes used interchangeably; BDD is the more commonly used name in modern practice.

## BDD vs. Gherkin

Gherkin is a specific language implementation that many BDD teams use to write down their examples. It is not BDD itself. You can practice BDD without Gherkin (using plain-text specifications, mind maps, or conversation alone). You can also write Gherkin without practicing BDD (just writing test scripts in Given-When-Then syntax without any discovery conversation).

!!! warning "Gherkin without BDD"
    Teams that write feature files without running discovery sessions are practicing "Cucumber theater": they get the syntax overhead without the collaboration benefit. The Gherkin is only as good as the conversation that produced it.

## The three phases

BDD activity follows three iterative phases:

```
Discovery → Formulation → Automation
     ↑_______________|
```

Each phase feeds back to the previous one when new information surfaces.

### Discovery: What it *could* do

The hardest part of building software is deciding precisely what to build. Discovery is structured conversation around concrete, real-world examples of the system from the user's perspective. The output is not a document — it is shared understanding in the heads of the people who were in the room.

Techniques: [Three Amigos sessions](three-amigos.md), [Example Mapping](example-mapping.md), [discovery workshops](https://cucumber.io/docs/bdd/discovery-workshop/).

### Formulation: What it *should* do

Once examples are agreed on, they are written down in a form that can be automated. Gherkin is the most common medium: it can be read by both humans and machines, and the act of writing it together surfaces vocabulary disagreements before they become code bugs.

The written specification is checked with the product person: "Is that how you would have said it?"

### Automation: What it *actually* does

The documented examples are connected to the running system as automated tests. When a scenario passes, it means the code does what the specification says. When a scenario fails, the system has diverged from the agreed specification — or the specification needs to change.

```gherkin
Feature: User registration

  Scenario: New user completes email verification
    Given a visitor has submitted the registration form with a valid email address
    When the visitor clicks the verification link in their email
    Then their account is activated
    And they are redirected to the onboarding flow
```

This scenario records what was agreed in discovery. Automation connects it to the real application.

## Why the collaboration aspect gets lost

Most BDD failures happen at the Discovery phase, not the Automation phase. There are three common failure modes:

**"BDD as QA-only"** — the development team writes feature files without involving the product owner. Scenarios reflect technical assumptions, not business rules.

**"After-the-fact Gherkin"** — developers implement first, then write Gherkin to match. The scenarios describe the implementation, not the agreed behavior. They provide no protection against building the wrong thing.

**"Specification debt"** — scenarios are written during initial development but never updated when behavior changes. The feature files become incorrect documentation that misleads the team.

### How to preserve the collaboration

- Run [Three Amigos sessions](three-amigos.md) before any story starts development
- Use [Example Mapping](example-mapping.md) as the structured format for those sessions
- Require the product owner to review and approve draft scenarios before automation begins
- Fail CI when scenarios are undefined — if the spec and the code diverge, the build breaks

!!! tip "The real deliverable of Discovery"
    The point of a discovery session is not to produce a Gherkin file. It is to ensure that every person who was in the room understands what "done" looks like for this story. Gherkin is the written record of that understanding.

## Cross-references

- [Discovery to Automation — the three phases in depth](discovery-to-automation.md)
- [Three Amigos](three-amigos.md) — running the collaboration session
- [Example Mapping](example-mapping.md) — the card-based discovery technique
- [Specification by Example](specification-by-example.md) — the Gojko Adzic framework
- [Why BDD Adoptions Fail](../adoption/why-bdd-fails.md) — the patterns that derail teams
