---
title: CI Enforcement
description: Hard-failing CI on undefined steps, coverage gating, branch protection, tag convention enforcement with gherkin-lint, and formatting enforcement.
sources:
  - git-playwright-bdd-repo-docs-cli-bddgen-test-or-just-bddgen
  - git-cucumber-js-docs-dryrun-dry-run
  - git-gherkin-lint-readme-readme
  - git-gherkin-lint-readme-available-rules
  - git-playwright-bdd-repo-docs-writing-features-auto-formatting-auto-formatting
---

# CI Enforcement

Running scenarios in CI is necessary but not sufficient. Without enforcement gates, a suite accumulates undefined steps, stale tags, and formatting inconsistencies that erode its value. Enforcement makes the spec a hard contract, not a suggestion.

## Detecting Undefined Steps with bddgen Dry-Run

The most important gate: **CI must fail if any scenario has undefined steps**. An undefined step means the Gherkin describes behavior that has no automation. The spec and the code have diverged.

playwright-bdd's `bddgen` catches undefined steps during code generation. Run it as a pre-flight check:

```bash
# Dry-run: parse features and check step definitions without running tests
npx bddgen --dry-run
```

If any step is undefined, `bddgen` exits with a non-zero code and prints the undefined steps. The CI job fails before any test runs.

In a GitHub Actions workflow, this is a mandatory gate before the test step:

```yaml
- name: Check for undefined steps (dry-run)
  run: npx bddgen --dry-run

- name: Generate BDD test files
  run: npx bddgen

- name: Run tests
  run: npx playwright test
```

!!! warning "Hard-fail, never soft-fail"
    An undefined step check that only warns is worthless. Teams learn to ignore warnings. The dry-run must be a hard failure — the PR cannot merge if undefined steps exist.

## Tag Convention Enforcement with gherkin-lint

gherkin-lint enforces structural and vocabulary rules on `.feature` files. The `allowed-tags` rule prevents tag sprawl by whitelisting the approved tag vocabulary.

Install and configure:

```bash
npm install -D gherkin-lint
```

`.gherkin-lintrc`:

```json
{
  "allowed-tags": {
    "tags": [
      "smoke",
      "regression",
      "e2e",
      "api",
      "ui",
      "slow",
      "quarantine",
      "skip",
      "wip",
      "staging-only",
      "production-only",
      "feature-flag-checkout-v2",
      "retries:1",
      "retries:2",
      "retries:3"
    ]
  },
  "no-dupe-scenario-names": "on",
  "no-duplicate-tags": "on",
  "no-empty-file": "on",
  "no-unnamed-features": "on",
  "no-unnamed-scenarios": "on",
  "keywords-in-logical-order": "on",
  "only-one-when": "on",
  "scenario-size": {
    "steps-per-scenario": 8,
    "steps-per-background": 4
  }
}
```

Run in CI:

```bash
npx gherkin-lint features/**/*.feature
```

!!! tip "Add new tags through a PR, not in the feature file"
    The `allowed-tags` list in `.gherkin-lintrc` is the authoritative tag registry. To use a new tag, it must be added to the allowlist first — which requires a PR, a team discussion, and documentation of what the tag means.

## Formatting Enforcement with Prettier

Inconsistent formatting creates noisy diffs and makes Gherkin harder to read. Use `prettier-plugin-gherkin` as a pre-commit hook and CI check:

```bash
npm install -D prettier prettier-plugin-gherkin
```

`prettier.config.mjs`:

```js
export default {
  plugins: ['prettier-plugin-gherkin'],
};
```

CI formatting check:

```bash
npx prettier --check "features/**/*.feature"
```

Pre-commit hook (`.husky/pre-commit`):

```bash
#!/bin/sh
npx prettier --write "features/**/*.feature"
npx gherkin-lint features/**/*.feature
```

## Branch Protection: Required Status Checks

Configure the following as **required** status checks on the main branch:

| Check | Enforcement level |
|---|---|
| `bddgen --dry-run` (undefined step detection) | Required — blocks merge |
| `gherkin-lint` (tag and structure rules) | Required — blocks merge |
| `prettier --check` (formatting) | Required — blocks merge |
| Full BDD suite | Required — blocks merge |
| `@quarantine` suite | Informational — does not block |

The `@quarantine` suite runs on a separate schedule and does not block PRs. Its purpose is tracking, not enforcement.

## Shard Result Aggregation

When using sharding, all shards must pass before the merge is allowed. In GitHub Actions, use a merge job as the required check:

```yaml
check-bdd:
  name: BDD suite passed
  needs: bdd          # the matrix job
  runs-on: ubuntu-latest
  if: always()
  steps:
    - name: Verify all shards passed
      run: |
        if [ "${{ needs.bdd.result }}" != "success" ]; then
          echo "BDD suite failed or was cancelled"
          exit 1
        fi
```

Register `BDD suite passed` (the aggregation job) as the required check — not the individual shard jobs. This avoids needing to register dynamic matrix job names.

## Required vs. Informational Suites

Not all scenarios should block merge. Design your suite tiers:

| Suite | Run trigger | Blocks merge? |
|---|---|---|
| Smoke (`@smoke`) | Every PR | Yes |
| Full regression (`@regression`) | Every PR | Yes |
| Slow / extended (`@slow`) | Nightly | No |
| Quarantine (`@quarantine`) | Nightly | No |
| Production-only (`@production-only`) | Post-deploy | No |
| WIP (`@wip`) | Local only — excluded from CI | N/A |

The `@wip` tag must never appear in a merged feature file. Enforce this with gherkin-lint's `no-restricted-tags` rule if needed.

## Cross-references

- [CI Running](ci-running.md) — the full multi-stage pipeline setup
- [Flaky Tests](flaky-tests.md) — quarantine strategy and retry configuration
- [Tooling: gherkin-lint](../tooling/gherkin-linter.md)
