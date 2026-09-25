---
title: Drift Detection
description: Detecting and reviewing spec-implementation drift in BDD — structural drift via bddgen dry-run, semantic drift via LLM review, and quarterly cadence recommendations.
sources:
  - git-playwright-bdd-repo-docs-cli-bddgen-test-or-just-bddgen
  - git-playwright-bdd-repo-docs-cli-bddgen-export
  - git-playwright-bdd-repo-docs-guides-fix-with-ai-fix-with-ai
  - web-monday-bdd-guide-the-future-of-bdd-ai-and-automation-trends
---

# Drift Detection

Spec-implementation drift is the gradual divergence between what Gherkin scenarios describe and what the code actually does. It is one of the most insidious BDD failure modes: tests continue to pass, so nothing alerts the team that the living documentation has become fiction.

Drift takes two forms:

| Type | What it means | Detection method |
|------|---------------|-----------------|
| **Structural drift** | A step in a `.feature` file has no matching TypeScript step definition | `bddgen --dry-run` |
| **Semantic drift** | Steps match and pass, but the behavior described no longer reflects the actual business rule | Human review + LLM-assisted review |

## Structural Drift: `bddgen --dry-run`

Structural drift is the easiest to detect because `bddgen` will catch it automatically.

```bash
npx bddgen --dry-run
```

If any step in a `.feature` file has no matching step definition, `bddgen` exits with code 1 and reports:

```
Error: Step "I apply discount code {string}" is not defined.

Suggestions:
  Add the following step definition:

  When('I apply discount code {string}', async ({  }, arg) => {
    // TODO
  });
```

### Enforcing in CI

```yaml
# .github/workflows/ci.yml
- name: Check for undefined steps
  run: npx bddgen --dry-run
```

This gate should be mandatory for every PR that changes `.feature` files. A PR that introduces new step text without an implementation must not merge.

### Pre-Push Hook

```bash
# .husky/pre-push
npx bddgen --dry-run
```

See [Pre-Commit Hooks](../tooling/pre-commit-hooks.md) for the complete hook configuration.

### Finding Orphaned Step Definitions

The inverse of undefined steps: step definitions that are no longer called from any feature file.

```bash
npx bddgen export --unused-steps
```

Orphaned step definitions are not a test failure, but they are technical debt. Periodic cleanup keeps the step library coherent.

## Semantic Drift: When Steps Pass But Behavior Changed

Semantic drift is harder. Consider this scenario:

```gherkin
Feature: User authentication

  Scenario: Suspended user cannot log in
    Given Alice's account has been suspended
    When Alice attempts to log in
    Then she sees the message "Your account has been suspended"
    And she is not redirected to the dashboard
```

This scenario passes. But if the engineering team changed the suspension message to "Account suspended. Contact support." and the step definition uses a flexible `toContainText` assertion, the test still passes while the Gherkin says something different from the actual behavior. The feature file now documents the old behavior.

### LLM-Assisted Semantic Drift Review

An LLM can review feature file + step implementation pairs and flag likely mismatches. The workflow:

**Step 1: Collect the feature file and its step definitions**

```bash
# Get the step export to identify which step files to include
npx bddgen export

# Collect relevant files
cat features/auth/suspension.feature
cat features/steps/auth.steps.ts
```

**Step 2: Prompt the LLM**

```
I need you to review whether this Gherkin scenario accurately describes the
TypeScript step implementation. Flag any mismatches.

Gherkin scenario:
```gherkin
Scenario: Suspended user cannot log in
  Given Alice's account has been suspended
  When Alice attempts to log in
  Then she sees the message "Your account has been suspended"
  And she is not redirected to the dashboard
```

TypeScript step implementations:
```typescript
Then('she sees the message {string}', async ({ page }, message: string) => {
  await expect(page.getByRole('alert')).toContainText(message);
});

Then('she is not redirected to the dashboard', async ({ page }) => {
  await expect(page).not.toHaveURL('/dashboard');
});
```

Questions:
1. Does the step implementation match what the Gherkin describes?
2. Are there assertions that are weaker than the scenario implies?
   (e.g., toContainText vs. exact text match)
3. Is there behavior described in Gherkin that has no assertion in the step?
4. Is there behavior asserted in the step that is not described in the Gherkin?

Reply with a list of mismatches, or "No mismatches found" if the implementation
matches the specification.
```

**Typical LLM response:**

```
Potential mismatch found:

Step: "Then she sees the message 'Your account has been suspended'"
Implementation: `toContainText(message)` — partial match

The Gherkin implies the exact message is displayed. `toContainText` would pass
even if the message were "Your account has been suspended for policy violation"
or any other string that contains the expected text.

Recommendation: If the exact message text is a business requirement, use
`toHaveText(message)` (exact match) instead of `toContainText`.

No other mismatches found.
```

!!! note "LLM review is not a test"
    The LLM cannot run the code. It can only reason about the relationship between the Gherkin description and the assertion logic. It may miss runtime behavior (e.g., a redirect that happens after a 2-second delay and is not awaited). Use this as a review aid, not a gate.

## The "Fix with AI" Feature

playwright-bdd v8.1.0+ includes a "Fix with AI" feature that generates a pre-filled prompt when a test fails. It bundles:

- The failing scenario's Gherkin steps
- The error message
- An ARIA snapshot of the page at failure time
- The step code snippet

Enable it in your BDD config:

```typescript
// playwright.config.ts
const testDir = defineBddConfig({
  aiFix: {
    promptAttachment: true,
  },
});
```

When a test fails, the HTML report shows a copy button for the AI prompt. Paste it into ChatGPT or any LLM to get fix suggestions. This is reactive drift detection: the test caught the mismatch, the LLM helps diagnose it.

## Cadence: Quarterly Drift Review

Structural drift is caught automatically on every CI run. Semantic drift requires periodic human attention.

**Recommended cadence:**

| Trigger | Action |
|---------|--------|
| Every PR touching `.feature` files | `bddgen --dry-run` in CI (structural) |
| Every failing test in CI | Use "Fix with AI" prompt (reactive semantic) |
| Monthly | `bddgen export --unused-steps` → clean up orphans |
| Quarterly | LLM-assisted review of stable feature areas |

For the quarterly review, target features that are:
- Marked `@regression` (core behavior that rarely changes)
- Older than 6 months without a `.feature` file modification
- In high-churn code areas where implementation evolves but specs are not updated

```bash
# Find feature files not modified in 90 days
git log --since="90 days ago" --name-only --diff-filter=M -- "features/**/*.feature" |
  grep -v "^$" | sort -u > recently-modified.txt

find features -name "*.feature" | sort > all-features.txt

comm -23 all-features.txt recently-modified.txt > candidates-for-drift-review.txt
```

!!! example "Quarterly review prompt"
    For each file in `candidates-for-drift-review.txt`, run:
    ```
    Review this feature file and its step implementations for semantic drift.
    The feature file has not been modified in the last 90 days but the
    codebase has changed significantly in that period.

    [paste feature file + relevant step defs]

    Flag any steps where the assertion in the step definition seems weaker
    than what the Gherkin describes, or where the step name no longer
    accurately describes what the step actually checks.
    ```

## See Also

- [Pre-Commit Hooks](../tooling/pre-commit-hooks.md) — `bddgen --dry-run` as a pre-push hook
- [CI Integration](../spec-lifecycle/ci-running.md) — `bddgen --dry-run` in the CI pipeline
- [Scenario Authoring](scenario-authoring.md) — writing scenarios that age well
- [Spec Lifecycle Maintenance](../spec-lifecycle/maintenance.md) — broader spec hygiene practices
