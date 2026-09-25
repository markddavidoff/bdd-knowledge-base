---
title: Specification by Example
description: Gojko Adzic's key process patterns for using concrete examples as a single source of truth — from deriving scope through goal to living documentation.
sources:
  - web-bdd-living-documentation-behavior-driven-development-aligning-stakeholders-through-living-documentation
  - web-bdd-living-documentation-the-power-of-living-documentation
  - web-bdd-living-documentation-aligning-stakeholders-through-collaboration
  - web-bdd-living-documentation-best-practices-for-living-documentation
  - web-bdd-living-documentation-common-pitfalls-and-how-to-avoid-them
  - web-cucumber-bdd-overview-three-practices
  - web-monday-bdd-guide-7-key-benefits-of-bdd-for-development-teams
---

# Specification by Example

Specification by Example (SBE) is the practice framework described by Gojko Adzic in his 2011 book of the same name. It formalizes the idea that teams should define requirements through concrete examples rather than abstract prose, and that those examples should become the single authoritative source of truth — from initial discovery through to production verification.

BDD is one implementation of Specification by Example. The Gherkin language, Three Amigos sessions, and Example Mapping are all techniques in service of SBE's goals.

## The single source of truth ideal

In traditional software development, requirements live in one place, code lives in another, and tests live in a third. These three artifacts drift apart over time. Requirements describe what was originally intended; code describes what was actually built; tests (if they exist) describe what was tested at one point in time. None of them agree with each other after six months.

Specification by Example aims at a different state: **one artifact that is simultaneously the requirement, the test, and the documentation**. In BDD terms, that artifact is the feature file — but only if the three conditions below are met:

1. The scenarios were written through structured collaboration before development started (not after)
2. The scenarios are executable and run in CI on every commit
3. When the code changes, the scenarios change with it — they are never bypassed or deleted silently

When these conditions hold, the feature file is always accurate by construction. A green build means the documentation is true. A failing scenario means the code has diverged from the agreed specification.

## Key process patterns

Adzic identifies six key patterns that distinguish teams who succeed with SBE from teams who fail:

### 1. Deriving scope from goals

Instead of starting with a feature list, start with a business goal. Then work backward: what is the minimum scope that achieves this goal? Examples help teams discover what is essential and what can be deferred.

The [Example Mapping](example-mapping.md) technique implements this directly: the session starts with the business goal (the yellow story card), then finds rules (blue), then examples (green). Questions (red) mark gaps in scope understanding.

### 2. Specifying collaboratively

The specification is not written by one person and handed to others. It is written by all three perspectives together (business, development, testing) in the same room at the same time. This is the [Three Amigos](three-amigos.md) pattern.

The collaboration has a specific purpose: to surface misunderstandings before they become code. Two people can read the same sentence and understand different things. A concrete example forces both people to agree on a specific case.

### 3. Illustrating using examples

Abstract statements ("the system should handle expired accounts correctly") are replaced by concrete examples ("when a user whose account expired 3 days ago tries to log in, they see the renewal prompt and cannot access their content").

Examples are unambiguous. "Correctly" means something different to every person who reads it. A specific example means the same thing to everyone.

```gherkin
# Abstract (ambiguous):
# The system should handle expired accounts correctly.

# Concrete example (unambiguous):
Scenario: Expired member cannot access premium content
  Given Marie has a premium membership that expired 3 days ago
  When she navigates to a member-exclusive article
  Then she sees the "Renew membership" prompt
  And the article body is hidden
```

### 4. Refining the specification

Draft scenarios are reviewed by all parties before development begins. The product owner reads the Gherkin and asks: "Is that what I meant?" This check transfers the understanding built in the discovery conversation into a written form that everyone agrees represents the behavior.

This is the Formulation phase of BDD — see [Discovery to Automation](discovery-to-automation.md).

### 5. Automating validation

Once the specification is agreed upon, it is automated: step definitions connect the Gherkin to the running application. The scenarios become executable tests. The automation is infrastructure — it should be transparent to the business and developer readers of the feature file.

```typescript
// Automation is invisible to the feature file reader.
// Step definitions translate Gherkin into application calls.
import { createBdd } from 'playwright-bdd';
import { expect } from '@playwright/test';

const { Given, When, Then } = createBdd();

Given('Marie has a premium membership that expired {int} days ago',
  async ({ api, fixtures }, days: number) => {
    const expiredAt = new Date();
    expiredAt.setDate(expiredAt.getDate() - days);
    fixtures.member = await api.memberships.create({
      name: 'Marie', plan: 'premium', expiredAt,
    });
  }
);

Then('she sees the {string} prompt', async ({ page }, promptText: string) => {
  await expect(page.getByRole('dialog', { name: promptText })).toBeVisible();
});
```

### 6. Validating frequently

Automated scenarios run on every commit in CI. This is the mechanism that keeps the documentation alive. If a code change breaks a scenario, the build fails and the team is notified immediately — before the divergence has time to grow into a documentation debt.

## Living documentation as the end state

Living documentation is the end state of a successful SBE implementation. The term means: documentation that is guaranteed to be accurate because it is also an executable test suite.

Properties of living documentation:

- **Accurate by construction**: a green build proves the documentation is true
- **Executable**: scenarios run as tests, not as prose
- **Digestible**: written in plain language readable by non-technical stakeholders
- **Versioned with code**: feature files change when behavior changes; they are kept in the same repository as the code they specify

!!! note "The sync contract"
    The sync contract is simple: if the code changes in a way that changes observable behavior, the feature file must change too. If a feature file is accurate today and the code changes tomorrow without updating the feature file, the living documentation is dead. CI enforcement (failing on undefined steps, treating scenario failures as build failures) is the mechanism that maintains the sync contract automatically.

## Traceability: story → scenario → test result

SBE provides a natural traceability chain:

1. A business requirement or user story is the starting point
2. The Three Amigos session produces concrete examples that operationalize the requirement
3. Those examples become Gherkin scenarios in a feature file
4. The scenarios run in CI and produce pass/fail results per scenario
5. A CI report links from scenario name back to feature file back to the original requirement

This chain is valuable in regulated industries (financial services, healthcare, defense) where audit trails from business requirement to test evidence are legally required.

## Examples vs. test cases

Specification by Example uses the term "examples" deliberately, not "test cases." The distinction matters:

| Examples | Test cases |
|---|---|
| Discovered in conversation | Written from specifications |
| Describe rules through concrete cases | Verify implementation details |
| Written before development | Often written after development |
| Business-readable | Often technical |
| Drive design | Verify design |

A test case verifies that something works. An example communicates what "working" means.

Not all examples become test cases. Some examples are too obvious to automate (the team agrees they are covered by general behavior). Some become manual exploratory test notes. The examples that represent agreed, non-obvious behavior are the ones worth automating.

## The "rotten documentation" failure mode

Documentation becomes rotten when it is no longer accurate but still looks authoritative. In traditional documentation, rotten docs are invisible until someone discovers the lie.

In SBE, rotten documentation breaks the build. A scenario that no longer matches the system's behavior causes a CI failure. This is not a problem with SBE — it is one of its core features. The team is forced to either update the scenario (the behavior changed intentionally) or fix the code (the behavior changed accidentally).

Teams that bypass this mechanism — by commenting out failing scenarios, using `@skip` tags without tracking them, or deleting scenarios that are hard to maintain — are accumulating specification debt that will eventually make the documentation untrustworthy.

## Cross-references

- [BDD Overview](bdd-overview.md) — the collaboration technique that SBE formalizes
- [Three Amigos](three-amigos.md) — the collaboration pattern (SBE pattern 2: specify collaboratively)
- [Example Mapping](example-mapping.md) — the discovery technique (SBE patterns 1 and 3)
- [Discovery to Automation](discovery-to-automation.md) — the three phases in SBE terms
- [Living Documentation](../methodology/living-documentation/index.md) — tooling for publishing the end state
