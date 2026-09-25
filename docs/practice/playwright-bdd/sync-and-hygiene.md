---
title: Sync and Hygiene
description: Keep feature files and step definitions in sync using bddgen dry-run, undefined step detection, orphaned step detection, and safe step refactoring.
sources:
  - git-playwright-bdd-repo-docs-cli-bddgen-test-or-just-bddgen
  - git-playwright-bdd-repo-docs-configuration-options-missingsteps
  - git-playwright-bdd-repo-docs-blog-whats-new-in-v8-other-changes
  - git-playwright-bdd-repo-docs-cli-bddgen-export
---

# Sync and Hygiene

The gap between `.feature` files and step definitions is where BDD suites rot. A renamed step in a feature file becomes an undefined step; a deleted scenario leaves a step definition that matches nothing; a refactored step silently diverges. playwright-bdd gives you tools to detect all three at generation time — before the test runner is ever invoked.

---

## `bddgen` Dry-Run in CI

`bddgen` runs as a mandatory pre-step before `npx playwright test`. If any step in any feature file has no matching definition, `bddgen` exits non-zero and prints code snippets for the missing steps:

```bash
npx bddgen && npx playwright test
```

To validate feature-step sync without running tests, use `bddgen` without the test runner and check the exit code:

```bash
# Dry-run: generate only, no test execution
npx bddgen
echo "Exit code: $?"
```

Use it as a cheap CI gate on pull requests that only touch `.feature` files:

```yaml
# .github/workflows/bdd-check.yml
- name: Validate feature-step sync
  run: npx bddgen
```

!!! tip "Run as a pre-push hook"
    Add `npx bddgen` to your pre-push hook (husky or lefthook) to catch sync failures before they reach CI:

    ```bash
    # .husky/pre-push
    npx bddgen
    ```

---

## Undefined Step Detection and Hard-Fail

By default (`missingSteps: 'fail-on-gen'`), any undefined step causes `bddgen` to exit with an error and display a ready-to-paste snippet:

```
Some steps are without definition!

// 1. Missing step definition for "features/checkout.feature:18:5"
When('the user places an order for {string}', async ({}, product: string) => {
  // TODO: implement
});

Missing step definitions: 1.
Use snippets above to create them.
```

This is the correct default for CI — it prevents broken `.spec.ts` files from reaching the test runner.

You can tune the behavior per project:

```ts
// playwright.config.ts
const testDir = defineBddConfig({
  features: 'features/**/*.feature',
  steps: 'features/steps/**/*.ts',
  missingSteps: 'fail-on-gen',    // default: block at generation
  // missingSteps: 'fail-on-run', // allow generation, fail at runtime
  // missingSteps: 'skip-scenario', // mark affected scenarios as fixme
});
```

!!! warning "`skip-scenario` hides broken scenarios"
    `missingSteps: 'skip-scenario'` is useful during a migration but should not be the permanent CI setting. A skipped scenario that nobody notices is a silent regression.

---

## Orphaned Step Definition Detection

Orphaned step definitions — step definitions that exist in `.ts` files but match no `.feature` file step — accumulate over time as scenarios are deleted or renamed. Use `bddgen export --unused-steps` to surface them:

```bash
npx bddgen export --unused-steps
```

Example output:

```
Using config: playwright.config.ts
Unused steps (2):

* When the user clicks the "legacy" button
* Then the deprecated modal is displayed
```

!!! example "CI enforcement"
    To fail CI on unused steps, check the count:

    ```bash
    UNUSED=$(npx bddgen export --unused-steps 2>&1 | grep -c "^\*" || echo 0)
    if [ "$UNUSED" -gt 0 ]; then
      echo "Found $UNUSED unused step definitions. Remove them or update feature files."
      exit 1
    fi
    ```

---

## Step Text Refactoring Safety

Renaming a step in a feature file immediately creates an undefined step (caught by `bddgen`). Renaming the TypeScript step definition text without updating the feature file creates an orphan (caught by `--unused-steps`). Together these two checks make step text refactoring safe:

**Workflow for renaming a step:**

1. Update the step text in the `.feature` file(s).
2. Run `npx bddgen` — confirms the old text in `.ts` is now orphaned and the new text is missing.
3. Update the step text in the `.ts` file(s) to match the feature file.
4. Run `npx bddgen` again — both checks pass.

```gherkin
# features/auth.feature — BEFORE
When the user submits the registration form

# features/auth.feature — AFTER (clearer intent)
When the user completes registration
```

```ts
// steps/auth.steps.ts — must match feature file exactly
// BEFORE:
When('the user submits the registration form', async ({ page }) => { ... });

// AFTER:
When('the user completes registration', async ({ page }) => { ... });
```

---

## Commit vs. Ignore Generated `.spec.ts` Files

The `bddgen` command writes generated `.spec.ts` files to `outputDir` (default: `.features-gen/`). Whether to commit them is a team decision:

| Strategy | Pros | Cons |
|----------|------|------|
| **Gitignore** (recommended) | No merge conflicts; single source of truth in `.feature` + `.ts` | CI must run `bddgen` before tests |
| **Commit** | Generated tests visible in PR diff; faster CI (skip generation) | Merge conflicts; easy to forget to re-run `bddgen` |

The standard approach is to gitignore:

```gitignore
# .gitignore
.features-gen/
```

And always run `bddgen` as the first CI step:

```bash
npx bddgen && npx playwright test
```

---

## Full CI Hygiene Checklist

```yaml
steps:
  - name: Validate step sync
    run: npx bddgen

  - name: Check for orphaned steps
    run: |
      UNUSED=$(npx bddgen export --unused-steps 2>&1 | grep -c "^\*" || echo 0)
      [ "$UNUSED" -eq 0 ] || (echo "Orphaned steps: $UNUSED" && exit 1)

  - name: Run BDD tests
    run: npx playwright test
```

See [Debugging](debugging.md) for diagnosing "step not found" errors at runtime, and [CI Integration](../spec-lifecycle/ci-running.md) for full pipeline recipes.
