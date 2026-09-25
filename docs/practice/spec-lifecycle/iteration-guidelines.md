---
title: Iteration Guidelines
description: Rules for when to add, modify, or delete scenarios as behavior changes, and PR conventions for feature file changes.
sources:
  - web-automation-panda-writing-good-gherkin-proper-behavior
  - web-cucumber-antipatterns-1-writing-the-scenario-after-you-ve-written-the-code
  - git-gherkin-best-practices-repo-readme-write-the-scenario-before-writing-the-code
  - web-testquality-best-practices-maintaining-consistency-in-gherkin-syntax
---

# Iteration Guidelines

Feature files are living specifications, not static documentation. They must change when behavior changes. These guidelines tell you _when_ to change them and _how_ to manage those changes in PRs.

## When to Add a Scenario

Add a scenario when a **new behavior** is being introduced — a new story, acceptance criterion, or business rule that didn't previously exist.

Rules for deciding to add:

- There is no existing scenario that already specifies this behavior
- The behavior represents a distinct outcome (not just a new data value for an existing flow)
- The Three Amigos have agreed on the Gherkin before implementation starts

!!! note "Add before coding"
    Adding a scenario is the trigger for implementation, not the record of it. If someone says "I'll write the Gherkin after I'm done coding," that is the spec-code decoupling anti-pattern.

```gherkin
# New scenario added for a new business rule:
# "Guest users can browse but cannot place orders"

  Scenario: Guest user cannot place an order
    Given I am browsing as a guest
    And my cart contains "Wireless Keyboard" with quantity 1
    When I attempt to place the order
    Then I am prompted to sign in or create an account
    And no order is created
```

## When to Modify a Scenario

Modify an existing scenario when **behavior changes** — when the existing scenario no longer correctly specifies what the system should do.

Do not modify a scenario to match what the code currently does after a bug was introduced. That is masking a failure. Scenarios specify intended behavior; a gap between scenario and code is a failing test that should be fixed in the code.

Signs that modification is correct:

- The product owner has explicitly changed the acceptance criteria for a story
- A business rule was updated (e.g., inventory threshold changed from 1 to 5)
- The UX copy changed in a way that affects the expected message in a `Then` step

When modifying step text, check all step definitions that use that text. The `bddgen` dry-run will catch undefined references after a rename.

```gherkin
# Before: old business rule — reject when out of stock
  Scenario: Order rejected when item is out of stock
    Given "Wireless Keyboard" has no available inventory
    When I place the order
    Then I see the message "Item is no longer available"

# After: behavior change — now rejects when inventory < 5
  Scenario: Order rejected when inventory is below threshold
    Given "Wireless Keyboard" has 3 units of available inventory
    When I place the order
    Then I see the message "Low stock — order cannot be placed"
```

## When to Delete a Scenario

Delete a scenario when the **behavior it specifies has been removed** from the product. Do not leave dead scenarios in place — they become maintenance burden and false documentation.

Delete triggers:

- A feature has been sunset or deprecated
- A business rule was eliminated (not changed — eliminated)
- A scenario describes behavior superseded by a broader scenario

!!! warning "Do not delete a failing scenario to make CI green"
    A failing scenario signals that the implementation diverged from the spec. Delete only if the product owner confirms the behavior is no longer required. Otherwise, fix the code.

## Versioning Scenarios With the Code They Specify

Feature files live in the same repository as the code they specify. When a scenario changes and the step definition changes in the same commit, the repo maintains traceability from requirement to implementation.

Commit discipline:

- A PR that adds a new scenario must also add the step definitions
- A PR that changes a scenario must also update the corresponding step definitions and any affected application code
- Do not merge a PR where `bddgen` reports undefined steps

The feature file diff in a PR is the acceptance criteria signal. Reviewers read the Gherkin diff to understand exactly what behavior is being added, changed, or removed.

## PR Conventions for Feature File Changes

!!! example "PR checklist for `.feature` file changes"

    **Adding a scenario:**
    - [ ] Three Amigos review completed before the PR was opened
    - [ ] New scenario committed alongside (not after) the implementation
    - [ ] Step definitions implemented; `bddgen` reports no undefined steps
    - [ ] CI passes with the new scenario included (not tagged `@skip`)

    **Modifying a scenario:**
    - [ ] Reason for the change documented in the PR description (which AC changed?)
    - [ ] All step definitions affected by renamed step text have been updated
    - [ ] `bddgen` dry-run passes
    - [ ] Product owner has approved the new wording

    **Deleting a scenario:**
    - [ ] Product owner confirmed the behavior is no longer required
    - [ ] Orphaned step definitions have been removed or audited
    - [ ] No other scenario depended on the deleted step text

## Who Reviews Feature File Changes

The same Three Amigos rule that applies to writing applies to changes:

- **Product/Business** must approve any behavior change — feature files are acceptance criteria
- **Development** must confirm the implementation matches the updated spec
- **Quality/Testing** must confirm no coverage gaps are introduced by deletions

A feature file change reviewed only by developers has lost the collaboration discipline that makes BDD effective.

## Cross-references

- [Writing Your First Spec](writing-first-spec.md) — the initial authoring process
- [CI Enforcement](ci-enforcement.md) — how undefined steps are caught automatically
- [Maintenance](maintenance.md) — identifying and pruning stale scenarios over time
