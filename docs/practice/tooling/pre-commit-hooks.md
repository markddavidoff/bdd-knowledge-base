---
title: Pre-Commit Hooks
description: Setting up husky and lint-staged to automatically format and lint .feature files on commit, with bddgen dry-run as a pre-push gate.
sources:
  - git-gherkin-utils-readme-usage
  - git-gherkin-lint-readme-readme
  - git-playwright-bdd-repo-docs-writing-features-auto-formatting-auto-formatting
  - git-playwright-bdd-repo-docs-cli-bddgen-test-or-just-bddgen
---

# Pre-Commit Hooks

Pre-commit hooks enforce Gherkin quality automatically, without relying on developers to remember to run formatters and linters manually. The recommended setup uses **husky** for hook management and **lint-staged** to run tools only on staged files (not the entire project on every commit).

## Prerequisites

```bash
npm install --save-dev husky lint-staged
```

## Husky Setup

Initialize husky:

```bash
npx husky init
```

This creates a `.husky/` directory and adds a `prepare` script to `package.json`:

```json
{
  "scripts": {
    "prepare": "husky"
  }
}
```

The `prepare` script runs on `npm install`, so new team members get hooks automatically after cloning.

## Commit Hook: Format + Lint

Create `.husky/pre-commit`:

```bash
#!/usr/bin/env sh
. "$(dirname -- "$0")/_/husky.sh"

npx lint-staged
```

Configure lint-staged in `package.json`:

```json
{
  "lint-staged": {
    "**/*.feature": [
      "npx @cucumber/gherkin-utils format",
      "npx gherkin-lint"
    ],
    "**/*.ts": [
      "npx tsc --noEmit"
    ]
  }
}
```

!!! warning "Order matters"
    Format runs before lint. The linter's `indentation` rule will report false positives on files the formatter would have fixed. If you reverse the order, you will get spurious lint failures on valid files that just needed formatting.

### What Happens on `git commit`

1. lint-staged identifies all staged `.feature` files.
2. `gherkin-utils format` runs on each staged file and re-stages the formatted version.
3. `gherkin-lint` runs on the (now-formatted) staged files and fails the commit if any rule is violated.
4. If both pass, the commit proceeds.

If a `.feature` file has a syntax error, `gherkin-utils format` will fail with a parse error and the commit is blocked before the linter even runs.

## Push Hook: `bddgen` Dry-Run

The pre-commit hook catches formatting and linting issues. The pre-push hook catches a more expensive problem: step definitions that exist in your feature files but have no TypeScript implementation yet.

Create `.husky/pre-push`:

```bash
#!/usr/bin/env sh
. "$(dirname -- "$0")/_/husky.sh"

echo "Running bddgen dry-run to check for undefined steps..."
npx bddgen --dry-run
if [ $? -ne 0 ]; then
  echo ""
  echo "ERROR: bddgen found undefined steps. Add step definitions before pushing."
  exit 1
fi
```

`bddgen --dry-run` (or `npx bddgen` with `missingSteps: 'fail'` in config) generates the test file manifest without running tests. It exits with code 1 if any step in a `.feature` file has no matching TypeScript step definition.

!!! tip "Pre-push is slower, but worth it"
    The dry-run takes a second or two. It is faster than a failed CI run plus the round-trip of pushing a fix. Make it a pre-push (not pre-commit) hook so it does not slow down every local save-and-test cycle.

## TypeScript Type Check as Pre-Push

Combine the `bddgen` check with a TypeScript type-check to catch type errors in step definitions before they reach CI:

```bash
#!/usr/bin/env sh
. "$(dirname -- "$0")/_/husky.sh"

echo "Running TypeScript type check..."
npx tsc --noEmit
if [ $? -ne 0 ]; then
  echo "ERROR: TypeScript type errors found. Fix before pushing."
  exit 1
fi

echo "Running bddgen dry-run..."
npx bddgen --dry-run
if [ $? -ne 0 ]; then
  echo "ERROR: Undefined steps found. Add step definitions before pushing."
  exit 1
fi
```

## Complete Configuration Example

### `.husky/pre-commit`

```bash
#!/usr/bin/env sh
. "$(dirname -- "$0")/_/husky.sh"
npx lint-staged
```

### `.husky/pre-push`

```bash
#!/usr/bin/env sh
. "$(dirname -- "$0")/_/husky.sh"

npx tsc --noEmit && npx bddgen --dry-run
```

### `package.json` (relevant sections)

```json
{
  "scripts": {
    "prepare": "husky"
  },
  "lint-staged": {
    "**/*.feature": [
      "npx @cucumber/gherkin-utils format",
      "npx gherkin-lint"
    ]
  },
  "devDependencies": {
    "@cucumber/gherkin-utils": "^9.0.0",
    "gherkin-lint": "^5.0.0",
    "husky": "^9.0.0",
    "lint-staged": "^15.0.0"
  }
}
```

### `.gherkin-lintrc`

```json
{
  "no-dupe-feature-names": "on",
  "no-unused-variables": "on",
  "no-unnamed-features": "on",
  "no-unnamed-scenarios": "on",
  "no-trailing-spaces": "on",
  "no-homogenous-tags": "on",
  "allowed-tags": ["on", {
    "tags": ["@smoke", "@regression", "@wip", "@skip", "@slow", "@quarantine"],
    "patterns": ["^@issue-[0-9]+$"]
  }],
  "max-scenarios-per-file": ["on", { "maxScenarios": 15 }],
  "keywords-in-logical-order": "on"
}
```

## Bypassing Hooks

Hooks can be skipped with `--no-verify` for legitimate emergencies (e.g., fixing a broken main branch under time pressure):

```bash
git commit --no-verify -m "emergency: revert bad deploy"
git push --no-verify
```

!!! warning "Document --no-verify skips"
    When you skip hooks, leave a note in the commit message or PR description. Skipping means the CI must be trusted to catch what the hook would have found — which is slower and more expensive.

## CI Redundancy

Pre-commit hooks are a developer convenience, not a security gate. Team members can skip them. Your CI pipeline must also run format checks and linting independently:

```yaml
# .github/workflows/ci.yml
- name: Format check
  run: |
    npx @cucumber/gherkin-utils format "features/**/*.feature"
    git diff --exit-code

- name: Lint Gherkin
  run: npx gherkin-lint "features/**/*.feature"

- name: Generate and test
  run: npx bddgen && npx playwright test
```

## See Also

- [Gherkin Formatter](gherkin-formatter.md) — formatter details and library API
- [Gherkin Linter](gherkin-linter.md) — rule configuration reference
- [CI Integration](../spec-lifecycle/ci-running.md) — full CI pipeline setup
