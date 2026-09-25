---
title: Team Patterns for BDD
description: Roles, responsibilities, feature file ownership models, and cross-team vocabulary alignment in a BDD team.
sources:
  - web-cucumber-antipatterns-1-ba-product-owner-creating-scenarios-in-isolation
  - git-gherkin-best-practices-repo-readme-do-not-write-scenarios-in-isolation
  - web-cucumberstudio-best-practices-content
  - web-monday-bdd-guide-5-steps-to-implement-bdd-in-your-organization
  - web-monday-bdd-guide-7-key-benefits-of-bdd-for-development-teams
  - web-testquality-best-practices-implementing-gherkin-best-practices-in-your-organization
---

# Team Patterns for BDD

BDD requires no new roles. It does require a change in *when* people collaborate and *who* is in the room. The most common failure mode is organizational rather than technical: someone writes scenarios alone, the rest of the team ignores them, and BDD becomes a QA-only artifact.

This page covers the structural patterns that make BDD work across different team configurations.

---

## Roles in a BDD Team

BDD depends on three perspectives being present when scenarios are written — not necessarily three people, but three viewpoints:

| Perspective | Typical role | Contribution |
|-------------|-------------|-------------|
| Business | Product owner, business analyst | Defines what the feature is for; catches scenarios that miss the business intent |
| Development | Engineer, tech lead | Identifies implementation constraints; catches scenarios that are untestable |
| Quality | QA engineer, SDET | Identifies edge cases, error paths, and boundary conditions |

In small teams, one person often covers two perspectives. That is acceptable. What is not acceptable is writing scenarios without all three perspectives being represented at all.

!!! warning "The isolation trap"
    If a product owner writes all the Gherkin in JIRA tickets and hands them to developers to implement, you will get scenarios that cannot be automated without modification — and once they are modified, the product owner no longer recognizes them as theirs. The scenarios stop being shared artifacts and become something that "belongs to the testers."

---

## Feature File Ownership

The question "who owns the `.feature` files?" has two valid answers depending on team structure.

### Team-Owned (Recommended for Single Teams)

The whole team owns the feature files. No one person has editorial authority. Changes to feature files go through PR review like code changes — and the product owner is a required reviewer, not optional.

This model works when the team is small enough that Three Amigos sessions are easy to schedule and the product owner is engaged.

### Shared with a BDD Guild (Cross-Team)

When multiple teams contribute to the same codebase, a "BDD guild" model can work: each team owns the feature files for their domain area, but a shared guild (or chapter) maintains cross-team conventions, the parameter type registry, and the vocabulary glossary.

This is addressed more fully in the [BDD at Scale](../at-scale/index.md) section. For teams just starting out, team-owned is the right default.

---

## BDD with an Embedded QA Engineer

The most common model in modern product teams: a QA engineer is embedded in the feature team alongside developers and a product owner. In this configuration:

- QA leads the Three Amigos session (facilitating, not dictating).
- QA writes the first draft of the feature file during or immediately after the session.
- Developer reviews the draft for automability and flags any terms that map poorly to the codebase.
- Product owner approves the scenarios as acceptance criteria before work begins.
- Developer implements and wires up step definitions.
- QA reviews step definitions for coverage completeness.

```gherkin
# features/access-control/permissions.feature
Feature: Role-based access control

  Scenario: Viewer cannot access admin settings
    Given Charlie has a viewer role account
    When he navigates to the admin settings page
    Then he sees an access denied message
    And the settings form is not visible
```

```typescript
// steps/access-control.steps.ts
import { createBdd } from 'playwright-bdd';
import { test } from '../fixtures';

const { Given, When, Then } = createBdd(test);

Given('{user} has a {string} role account', async ({ db }, user, role: string) => {
  await db.users.upsert({ ...user, role });
});

When('he navigates to the admin settings page', async ({ page }) => {
  await page.goto('/admin/settings');
});

Then('he sees an access denied message', async ({ page }) => {
  await expect(page.getByRole('alert')).toContainText('Access denied');
});

Then('the settings form is not visible', async ({ page }) => {
  await expect(page.getByTestId('admin-settings-form')).not.toBeVisible();
});
```

The embedded QA model is highly effective because QA sits in the same team rituals as developers. Three Amigos happens naturally within the sprint ceremony.

---

## BDD with a Separate QA Team

Some organizations have a dedicated QA team that works across multiple product teams. In this model, BDD requires more deliberate coordination:

- QA attends Three Amigos sessions for each product team, which requires calendar management.
- Feature files may be reviewed asynchronously (PR comment) rather than synchronously (in-session).
- The QA team often becomes the de facto vocabulary arbiter — a role that should be made explicit, not accidental.

!!! tip "Async Three Amigos"
    When synchronous sessions are impractical, a written Example Map (cards in a shared doc) reviewed asynchronously within 24 hours can approximate a live session. The key is that scenarios are not finalized until all three perspectives have weighed in — not just the product owner and one technical person.

The risk in the separate QA model is that BDD drifts toward [BDD-as-QA-only](why-bdd-fails.md#1-bdd-as-qa-only). Counter it by making developer sign-off on the feature file an explicit step before any implementation starts.

---

## Cross-Team Vocabulary Alignment

When more than one team writes BDD scenarios in the same product domain, vocabulary drift is the main hazard: Team A writes `Given a pro organization` and Team B writes `Given the organization is on the pro plan`. These refer to the same concept but have separate step definitions and separate maintenance burdens.

The basic pattern for small-scale vocabulary alignment:

1. **Single `parameters.ts` file** at the monorepo root or shared package, owned by consensus.
2. **Named personas are global** — Alice, Bob, and Charlie mean the same thing across all feature files.
3. **Plan and role names are canonical** — the step `{plan}` matches exactly `free|pro|enterprise` everywhere.
4. **New shared vocabulary goes through a brief review** — at minimum, a PR that any other team's BDD practitioner can comment on.

```typescript
// shared/parameters.ts — imported by all step files
import { defineParameterType } from 'playwright-bdd';

// This file is the single source of truth for shared test vocabulary.
// Changes require review from the BDD guild.

defineParameterType({
  name: 'plan',
  regexp: /free|pro|enterprise/,
  transformer: (s: string) => ({ name: s, billingEnabled: s !== 'free' }),
});
```

For deeper vocabulary governance patterns — changelog processes, shared step library packages, and monorepo scoping — see [BDD at Scale](../at-scale/index.md).

---

## Checklist: Organizational Readiness

Before running your first Three Amigos session, verify:

- [ ] Product owner (or proxy) can commit 60 minutes per story for a pre-kickoff session.
- [ ] Developer and QA can both attend that same session.
- [ ] Feature file changes are reviewed in PRs like code changes.
- [ ] At least one person on the team has read [Why BDD Fails](why-bdd-fails.md).
- [ ] CI will run the BDD suite on every PR (even if not blocking yet).

---

## Cross-References

- [Three Amigos](../methodology/three-amigos.md) — the collaboration session this page assumes
- [Why BDD Fails](why-bdd-fails.md) — particularly the BDD-as-QA-only failure mode
- [First 90 Days](first-90-days.md) — the rollout plan for a single team
- [Brownfield Adoption](brownfield.md) — applying this in an existing codebase
- [BDD at Scale](../at-scale/index.md) — multi-team vocabulary governance and shared step libraries
