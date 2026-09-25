---
title: Feature Flags in Specs
description: Strategies for representing feature-flagged behavior in Gherkin — tagging conventions, playwright.config.ts integration, two-scenario vs. parameterized approaches, and flag deprecation.
sources:
  - git-playwright-bdd-repo-docs-guides-env-variables-env-variables
  - git-playwright-bdd-repo-docs-guides-env-vars-env-vars
  - git-playwright-bdd-repo-docs-writing-features-special-tags-skip-fixme
  - web-automation-panda-writing-good-gherkin-proper-behavior
---

# Feature Flags in Specs

Feature flags create a tension in Gherkin: the same code path can exhibit different behavior depending on runtime flag state. The spec is supposed to describe a single, agreed behavior — but now there are two.

## The Dilemma

A feature flag means two versions of a behavior exist simultaneously:

- **Flag off**: the existing behavior (already specified by an existing scenario)
- **Flag on**: the new behavior (the one being built)

The wrong approach: modify the existing scenario to describe the new behavior before the flag is fully rolled out. This makes the spec inaccurate for the flag-off state.

The right approach: write **two scenarios** — one for each flag state — and tag them appropriately.

## Tagging Strategy

Use a descriptive tag that names the flag and makes its intent obvious:

```gherkin
Feature: Checkout flow

  Scenario: Standard checkout with legacy payment form
    Given I have items in my cart
    When I proceed to checkout
    Then I see the legacy payment form with credit card fields

  @feature-flag-checkout-v2
  Scenario: Streamlined checkout with new payment widget
    Given I have items in my cart
    When I proceed to checkout
    Then I see the new payment widget with saved payment methods
```

The untagged scenario runs in all environments. The `@feature-flag-checkout-v2` scenario only runs when the flag is active. This keeps the spec accurate for both states.

## Environment Configuration in playwright.config.ts

Read the flag state from an environment variable and filter scenarios accordingly:

```typescript
// playwright.config.ts
import { defineConfig } from '@playwright/test';
import { defineBddConfig } from 'playwright-bdd';

const checkoutV2Enabled = process.env.FEATURE_CHECKOUT_V2 === 'true';

const testDir = defineBddConfig({
  features: 'features/**/*.feature',
  steps: 'steps/**/*.steps.ts',
});

export default defineConfig({
  testDir,
  // When flag is enabled, also run @feature-flag-checkout-v2 scenarios
  // When flag is disabled, exclude them
  grep: checkoutV2Enabled
    ? undefined  // run everything
    : /^(?!.*@feature-flag-checkout-v2)/,
});
```

Alternatively, use `bddgen` tag filtering to control which scenarios are generated:

```bash
# Flag off (default CI)
npx bddgen --tags "not @feature-flag-checkout-v2" && npx playwright test

# Flag on (staging with flag enabled)
npx bddgen && npx playwright test
```

## Two Scenarios vs. One Parameterized Scenario

**Two scenarios** (recommended for most cases):

```gherkin
  Scenario: Legacy checkout — payment form visible
    ...

  @feature-flag-checkout-v2
  Scenario: New checkout — payment widget visible
    ...
```

Pros: clear intent for each state; easy to delete the legacy scenario when the flag is removed; step definitions don't need flag-awareness.

Cons: some duplication in setup steps.

**One parameterized scenario** (use when flag changes a value, not behavior structure):

```gherkin
  Scenario Outline: Checkout displays correct payment UI
    Given the checkout-v2 flag is <flag_state>
    When I proceed to checkout
    Then I see the <expected_ui>

    Examples:
      | flag_state | expected_ui              |
      | disabled   | legacy payment form      |
      | enabled    | new payment widget       |
```

Pros: single scenario to maintain; explicitly documents both states.

Cons: requires `flag_state` step to manipulate the flag at runtime, which couples the test to flag implementation. Step definitions become more complex. The Scenario Outline can be confusing to non-technical reviewers.

!!! tip "Prefer two scenarios when the behaviors differ structurally"
    If the flag changes _what_ the user sees (a different component, a different flow), use two scenarios. If the flag changes a configuration value (a threshold, a limit, a label), a Scenario Outline is appropriate.

## Staging-Only Scenarios

Some behavior only exists in non-production environments. Use `@staging-only` tags and exclude from production runs:

```gherkin
  @staging-only
  Scenario: Admin can reset user password via debug endpoint
    Given I am logged in as an admin
    When I reset the password for "alice@example.com" via the debug endpoint
    Then the user receives a password reset email
```

In `playwright.config.ts` for production runs:

```typescript
grep: /^(?!.*@staging-only)(?!.*@feature-flag-)/,
```

## Deprecating Feature Flag Tags When Flags Are Removed

When a feature flag is permanently enabled (rolled out to 100%), the lifecycle is:

1. Delete the legacy scenario (flag-off behavior no longer exists)
2. Remove the `@feature-flag-X` tag from the new-behavior scenario
3. Remove the tag from `.gherkin-lintrc`'s `allowed-tags` list
4. Remove the environment variable check from `playwright.config.ts`
5. Delete the corresponding environment variable from CI secrets

!!! warning "The permanent feature flag trap"
    Feature flag tags that are never removed become permanent fixture of the Gherkin vocabulary. Treat every `@feature-flag-X` tag as technical debt with a target removal date. When the flag ships to production permanently, there is a 1-sprint window to clean up the Gherkin before the tag fossilizes.

Teams that skip cleanup end up with `@feature-flag-checkout-v2` tags still present two years after v2 shipped, with no one able to safely delete them. Add flag cleanup to the definition of done for each rollout.

## Cross-references

- [Environment-Specific Scenarios](env-specific.md) — `@staging`, `@production` tagging patterns
- [CI Enforcement](ci-enforcement.md) — `allowed-tags` in gherkin-lint to govern flag tag vocabulary
- [Tag Taxonomy Design](../../gherkin/reference/tags-classification.md) — overall tag governance
