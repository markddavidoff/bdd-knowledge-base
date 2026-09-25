---
title: Hello World — Minimal Feature File
description: The minimal complete Gherkin feature file, then grown step-by-step to show Background, a second Scenario, and tags.
sources:
  - web-cucumber-gherkin-reference-keywords
  - web-automation-panda-writing-good-gherkin-style-and-structure
  - git-gherkin-best-practices-repo-readme-use-backgrounds-to-reduce-the-number-of-steps
  - git-gherkin-best-practices-repo-readme-use-tags-to-organize-your-features-and-scenarios
---

# Hello World — Minimal Feature File

The smallest valid Gherkin feature file has four lines: `Feature`, `Scenario`, and one step of each of `Given`, `When`, and `Then`. Start here before adding anything.

## Step 1 — Absolute Minimum

```gherkin
Feature: Greeting

  Scenario: A user receives a welcome message
    Given a registered user named "Alice"
    When Alice signs in
    Then Alice sees the message "Welcome back, Alice"
```

This is complete and executable. It specifies one piece of behavior in its simplest form.

**What each line does:**

| Line | Role |
|------|------|
| `Feature: Greeting` | Names the capability under test. One per file. |
| `Scenario: ...` | Names one concrete behavior to verify. |
| `Given ...` | Establishes initial context (state that already exists). |
| `When ...` | Triggers the action being tested. |
| `Then ...` | Asserts the observable outcome. |

!!! note "Present tense throughout"
    All steps use present tense: "Alice **signs** in", "Alice **sees**". Past tense in Given ("a user **existed**") and future tense in Then ("will **show**") are both common mistakes. Present tense reads like a live specification, not a historical log.

---

## Step 2 — Add a Feature Description

```gherkin
Feature: Greeting
  As a returning user
  I want to see a personalized welcome message
  So that I know the system recognizes me

  Scenario: A user receives a welcome message
    Given a registered user named "Alice"
    When Alice signs in
    Then Alice sees the message "Welcome back, Alice"
```

The `As a / I want / So that` narrative is free-form text under `Feature`. Cucumber ignores it at runtime but reporting tools render it. It anchors the feature in user value.

---

## Step 3 — Add a Background

When a second scenario shares the same setup, extract it into `Background`.

```gherkin
Feature: Greeting
  As a returning user
  I want to see a personalized welcome message
  So that I know the system recognizes me

  Background:
    Given a registered user named "Alice"

  Scenario: A user receives a welcome message on sign-in
    When Alice signs in
    Then Alice sees the message "Welcome back, Alice"

  Scenario: A user receives a welcome message on the dashboard
    Given Alice is signed in
    When Alice navigates to the dashboard
    Then the dashboard header shows "Welcome back, Alice"
```

`Background` runs before **each** scenario in the feature. It is scoped to the `Feature` (or `Rule`) it belongs to — not the entire file.

!!! warning "Background anti-pattern"
    Keep `Background` short — four steps or fewer. A lengthy Background that sets up complicated state not relevant to every scenario is a smell. If scenarios need substantially different setups, use separate feature files or [Rule-scoped Backgrounds](background-and-rules.md).

---

## Step 4 — Add Tags

```gherkin
@authentication @smoke
Feature: Greeting
  As a returning user
  I want to see a personalized welcome message
  So that I know the system recognizes me

  Background:
    Given a registered user named "Alice"

  @happy-path
  Scenario: A user receives a welcome message on sign-in
    When Alice signs in
    Then Alice sees the message "Welcome back, Alice"

  @happy-path
  Scenario: A user receives a welcome message on the dashboard
    Given Alice is signed in
    When Alice navigates to the dashboard
    Then the dashboard header shows "Welcome back, Alice"
```

Tags placed on `Feature` are inherited by all scenarios beneath. Scenario-level tags add classification without overriding the feature tags.

Run only the smoke suite:
```bash
npx playwright test --grep @smoke
```

Exclude work-in-progress:
```bash
npx playwright test --grep-invert @wip
```

!!! tip "Tag naming conventions"
    Use lowercase, hyphen-separated tag names: `@happy-path`, `@error-path`, `@smoke`, `@regression`. Avoid tags like `@AUTOMATE`, `@Sprint32`, or `@test` — they are noise. See [Tag Taxonomy](../reference/tags-classification.md) for the full taxonomy.

---

## Common Mistakes at This Level

| Mistake | Fix |
|---------|-----|
| `When I clicked the button` (past tense) | `When the user clicks the submit button` |
| `Then the page will show...` (future tense) | `Then the page shows...` |
| Mixing "I" and "the user" in one scenario | Pick one person-perspective and stay consistent |
| `Given I am on the login page` (imperative) | `Given a registered user named "Alice"` (declarative) |

For next steps, see [Authentication](authentication.md) for realistic multi-scenario feature files, or [Data-Driven](data-driven.md) for Scenario Outline patterns.
