---
title: Discovery to Automation — The Three Phases
description: How BDD's three phases (Discovery, Formulation, Automation) work together, where teams commonly fail, and how to execute each phase effectively.
sources:
  - web-cucumber-bdd-overview-three-practices
  - web-monday-bdd-guide-the-phases-of-bdd-discovery-formulation-and-automation
  - web-monday-bdd-guide-5-steps-to-implement-bdd-in-your-organization
  - web-monday-bdd-guide-how-to-overcome-common-bdd-challenges
  - web-bdd-living-documentation-the-power-of-living-documentation
  - web-example-mapping-intro-benefits
---

# Discovery to Automation — The Three Phases

BDD's three phases — Discovery, Formulation, and Automation — are not a linear pipeline. They form an iterative loop: each phase feeds back to the one before when new information surfaces. Understanding how they interact, and where teams commonly break them, is the foundation of effective BDD practice.

```
     [Discovery]
      ↓       ↑
  [Formulation] ↑
      ↓       ↑
  [Automation]──┘
```

New information at any phase triggers a return to the conversation.

## Phase 1: Discovery

> "The hardest single part of building a software system is deciding precisely what to build."
> — Fred Brooks, *The Mythical Man-Month*

Discovery is structured conversation. Its output is not a document or a ticket update — it is shared understanding that lives in the heads of the people who participated. No amount of written documentation substitutes for the team having genuinely thought through a feature together.

### What happens in Discovery

- A [Three Amigos](three-amigos.md) session (business, development, testing perspectives) discusses a story
- [Example Mapping](example-mapping.md) provides structure: rules, concrete examples, and open questions
- Edge cases surface: "what if the user has no billing address?", "what happens if this times out?"
- Questions are captured and answered — or flagged as blockers before development starts

### What Discovery produces

- Agreed-upon examples that represent the expected behavior
- A list of rules that govern the feature
- A set of open questions to resolve before coding begins
- Shared vocabulary — the team uses the same words to describe the same things

### Common failure: skipping Discovery

Teams under delivery pressure skip Discovery and write Gherkin directly from a ticket. The result:

- Scenarios describe what the developer assumed the requirement meant
- Business rules that were never discussed get implemented incorrectly
- Edge cases discovered during QA trigger last-minute scope changes

!!! warning "The most expensive skip"
    Skipping Discovery is the single most common cause of BDD failure. Teams who write Gherkin without running a discovery session are doing documentation, not BDD. They pay the overhead of Gherkin without getting the alignment benefit.

## Phase 2: Formulation

Formulation is the act of writing the discovered examples in a form that can be automated and reviewed. In most BDD teams, this means Gherkin.

### What happens in Formulation

- The developer and tester draft Gherkin scenarios from the examples agreed in Discovery
- They choose vocabulary carefully: the step text should use terms the product person would use, not technical terms
- The product person reviews the draft: "Is that how you would have written it?"
- Vocabulary disagreements surface ("we call that 'deactivated', not 'suspended'") and are resolved

### The vocabulary alignment check

This is the most underrated step in Formulation. When the product owner reviews a draft scenario and says "that's not what I meant," that is the process working correctly. Better to surface the misunderstanding in a ten-minute review than after a week of development.

```gherkin
# Draft after Example Mapping session
# Sent to product owner for review before automation begins

Feature: Membership expiry

  Scenario: Expired member loses access to premium content
    Given Marie has an active premium membership
    And her membership expired 3 days ago
    When she navigates to a premium article
    Then she sees the "Renew your membership" prompt
    And the article content is not visible

  # Product owner feedback: "Marie" is fine, but "premium article" is our term.
  # We call it "member-exclusive content" in the UI. Please update.
```

The review catches a vocabulary mismatch before it propagates into step definitions, UI copy, and stakeholder communications.

### The Three Amigos review of draft scenarios

For stories with complex rules, the Three Amigos reconvene briefly to review the drafted Gherkin. This is usually 15 minutes, not a full session. The questions to answer:

- Does this scenario match what we agreed in Discovery?
- Is the vocabulary consistent with what the product owner uses?
- Are there examples we agreed on that are not yet captured?
- Are there scenarios here that were not discussed — where did they come from?

### Common failure: Formulation without Discovery

When Formulation happens without prior Discovery, the Gherkin reflects a developer's interpretation of a ticket. It may be technically precise and grammatically correct Gherkin — but it may not capture the actual business intent.

## Phase 3: Automation

Automation connects the Gherkin specification to the running system. This is where step definitions are written and CI integration is set up.

### What happens in Automation

- Each scenario step is connected to code via step definitions
- The step definitions call into the application (via browser, API, or directly) to execute and verify behavior
- The first run fails (the behavior does not exist yet) — this is expected
- Development proceeds until all scenarios pass
- Automation runs in CI on every commit, keeping the specification live

```typescript
// Step definitions are infrastructure — they connect Gherkin to the app.
// The business logic lives in the application; the step definitions are thin.
import { createBdd } from 'playwright-bdd';
import { expect } from '@playwright/test';

const { Given, When, Then } = createBdd();

Given('Marie has an active premium membership', async ({ api, fixtures }) => {
  fixtures.member = await api.memberships.create({
    user: 'Marie',
    plan: 'premium',
    status: 'active',
  });
});

Given('her membership expired {int} days ago', async ({ api, fixtures }, days: number) => {
  const expiredAt = new Date();
  expiredAt.setDate(expiredAt.getDate() - days);
  await api.memberships.update(fixtures.member.id, { expiredAt });
});

When('she navigates to a premium article', async ({ page }) => {
  await page.goto('/articles/member-exclusive-content');
});

Then('she sees the {string} prompt', async ({ page }, promptText: string) => {
  await expect(page.getByRole('dialog', { name: promptText })).toBeVisible();
});

Then('the article content is not visible', async ({ page }) => {
  await expect(page.getByTestId('article-body')).not.toBeVisible();
});
```

### Keeping automation invisible

A key principle of BDD automation: the step definitions are infrastructure, not the specification. The `.feature` file is the specification. The step definitions are the plumbing that connects that specification to the application.

Consequences of this principle:

- Step definitions should be thin (1-3 lines delegating to page objects or API helpers)
- Infrastructure concerns (how to authenticate, how to seed the database) live in fixtures and support code, not in the Gherkin
- Scenario text should change only when the business behavior changes — not when implementation details change

### Common failure: going straight to automation

The most common shortcut teams take is writing step definitions first, then writing Gherkin to match. This produces:

- Scenarios that describe implementation steps, not business behavior
- Imperative style ("click the Submit button") instead of declarative ("submits the form")
- Feature files that change every time a UI element changes, not when behavior changes

!!! tip "The automation phase is the last, not the first"
    If someone on your team is writing step definitions before a Three Amigos session has happened, the phases are reversed. Stop. Run the discovery session. Write the scenarios. Then automate.

## How the phases connect

The three phases form a feedback loop:

| Phase | Produces | Feeds back to |
|---|---|---|
| Discovery | Shared understanding, examples, vocabulary | — |
| Formulation | Gherkin scenarios (executable specification) | Discovery (when review surfaces new questions) |
| Automation | Running tests, CI integration | Formulation (when automation reveals impossible scenarios) |

New behavior is discovered → discussed in Discovery → formulated in Gherkin → automated with step definitions → verified in CI → feedback to team.

## Signs the loop is working

- Scenarios change when business rules change, not when implementation changes
- The product owner reviews and approves scenario changes in PRs
- CI fails when a scenario is not yet automated — no silent gaps
- Developers ask "did we have a Three Amigos session on this?" before starting work

## Signs the loop is broken

- Scenarios are written after code is already working
- Product owners do not review feature file changes in PRs
- CI passes with undefined steps (no enforcement)
- Vocabulary in step text does not match vocabulary in the product UI

## Cross-references

- [Three Amigos](three-amigos.md) — running the Discovery phase
- [Example Mapping](example-mapping.md) — the structured Discovery technique
- [BDD Overview](bdd-overview.md) — what BDD is and where each phase fits
- [Specification by Example](specification-by-example.md) — the framework that formalizes this loop
- [Why BDD Fails](../adoption/why-bdd-fails.md) — the failure modes in depth
