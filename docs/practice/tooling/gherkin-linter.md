---
title: Gherkin Linter
description: Using gherkin-lint to enforce semantic rules on .feature files — configuration, key rules, CI integration, pre-commit hooks, and custom rule writing.
sources:
  - git-gherkin-lint-readme-readme
  - git-gherkin-lint-readme-available-rules
  - git-gherkin-lint-readme-configuration-file
  - git-gherkin-lint-readme-rule-configuration
  - git-gherkin-lint-readme-custom-rules
  - git-gherkin-lint-readme-installation
---

# Gherkin Linter

`gherkin-lint` parses `.feature` files using the official Gherkin parser and checks them against a configurable set of semantic rules. It goes beyond formatting — it catches duplicate names, unused variables, forbidden tags, and structural anti-patterns before they reach CI.

## Installation

```bash
npm install --save-dev gherkin-lint
```

## Basic Usage

```bash
# Lint all feature files
npx gherkin-lint features/**/*.feature

# Lint with a specific config file
npx gherkin-lint -c .gherkin-lintrc features/**/*.feature

# Lint with a custom rules directory
npx gherkin-lint --rulesdir ./lint-rules features/**/*.feature
```

## Configuration File

Create `.gherkin-lintrc` in your project root. The file is JSON (comments are allowed):

```json
{
  // Structural rules — always on (cannot be disabled)
  // no-tags-on-backgrounds, one-feature-per-file, etc.

  // Naming and uniqueness
  "no-dupe-feature-names": "on",
  "no-dupe-scenario-names": ["on", "in-feature"],
  "no-unnamed-features": "on",
  "no-unnamed-scenarios": "on",

  // Data integrity
  "no-unused-variables": "on",
  "no-empty-background": "on",
  "no-empty-file": "on",
  "no-files-without-scenarios": "on",

  // Style enforcement
  "no-trailing-spaces": "on",
  "no-multiple-empty-lines": "on",
  "new-line-at-eof": ["on", "yes"],
  "use-and": "on",

  // Tag governance
  "allowed-tags": ["on", {
    "tags": ["@smoke", "@regression", "@wip", "@skip", "@slow"],
    "patterns": ["^@issue-[0-9]+$"]
  }],
  "no-homogenous-tags": "on",

  // File size limits
  "max-scenarios-per-file": ["on", { "maxScenarios": 15 }],

  // Step ordering
  "keywords-in-logical-order": "on",
  "only-one-when": "on",

  // Indentation
  "indentation": ["on", {
    "Feature": 0,
    "Scenario": 2,
    "Step": 4,
    "Examples": 2,
    "example": 4
  }]
}
```

!!! note "Always-on rules"
    Rules marked with `*` in the documentation (e.g., `one-feature-per-file`, `no-tags-on-backgrounds`, `no-multiline-steps`, `up-to-one-background-per-file`) detect Gherkin constructs that crash the parser. They cannot be turned off. They run regardless of your config.

## Key Rules Explained

### `no-dupe-feature-names`

Prevents two `.feature` files from declaring the same Feature title. Duplicates are common after copy-paste and make HTML reports ambiguous.

### `no-unused-variables`

Catches `<placeholder>` tokens in Scenario Outline step text that have no corresponding column in the Examples table:

```gherkin
# BAD — <role> is never defined in Examples
Scenario Outline: <role> can view the dashboard
  Given I am logged in as <role>
  Examples:
    | username |
    | alice    |
```

### `allowed-tags`

Enforces a closed tag taxonomy. Any tag not in the allowed list (or matching an allowed pattern) causes a lint error:

```json
"allowed-tags": ["on", {
  "tags": ["@smoke", "@regression", "@wip", "@skip", "@quarantine", "@slow", "@fast"],
  "patterns": ["^@issue-[0-9]+$", "^@feature-[a-z-]+$"]
}]
```

This prevents tag sprawl — new tags cannot be introduced without updating the config (which requires a PR review).

### `no-homogenous-tags`

Flags scenarios where every scenario in a feature carries the same tag — a sign the tag belongs on the Feature, not individual scenarios:

```gherkin
# BAD — @smoke on every scenario; should be on Feature
Feature: Login
  @smoke
  Scenario: Successful login ...
  @smoke
  Scenario: Failed login ...
```

### `max-scenarios-per-file`

Keeps feature files focused. Large files (15+ scenarios) are usually signs of a Feature that should be split:

```json
"max-scenarios-per-file": ["on", {
  "maxScenarios": 15,
  "countOutlineExamples": false
}]
```

Set `countOutlineExamples: false` to count a Scenario Outline as one scenario regardless of how many example rows it has.

### `no-restricted-patterns`

Bans specific phrases from appearing in Feature/Scenario names or steps. Useful for blocking implementation vocabulary from leaking into Gherkin:

```json
"no-restricted-patterns": ["on", {
  "Global": ["TODO", "FIXME"],
  "Feature": ["validate", "verify", "test that"],
  "Scenario": ["click the", "navigate to", "fill in"]
}]
```

The last two patterns catch imperative step language before it reaches code review.

### `required-tags`

Ensures every scenario carries a required tag (e.g., a ticket reference):

```json
"required-tags": ["on", {
  "tags": ["^@issue-[0-9]+$"],
  "ignoreUntagged": false
}]
```

## CI Integration

Add a lint step to your CI pipeline after the format check:

```yaml
# .github/workflows/ci.yml
- name: Lint Gherkin
  run: npx gherkin-lint "features/**/*.feature"
```

The linter exits with code `1` if any rule is violated, causing the CI step to fail.

### Running Format Before Lint

Always run the formatter before the linter. The linter's `indentation` rule will report false positives on files the formatter would have corrected:

```bash
# Correct order
npx @cucumber/gherkin-utils format "features/**/*.feature"
npx gherkin-lint "features/**/*.feature"
```

## Pre-Commit Hook

In `package.json` with lint-staged:

```json
{
  "lint-staged": {
    "**/*.feature": [
      "npx @cucumber/gherkin-utils format",
      "npx gherkin-lint"
    ]
  }
}
```

The formatter runs first, then the linter sees clean files. See [Pre-Commit Hooks](pre-commit-hooks.md) for the complete husky setup.

## Writing Custom Rules

Custom rules live in their own directory and are loaded with `--rulesdir`:

```bash
npx gherkin-lint --rulesdir ./lint-rules "features/**/*.feature"
```

A custom rule is a CommonJS module that exports a `{ name, run }` object. The `run` function receives the parsed AST and returns an array of error objects:

```javascript
// lint-rules/no-wip-in-production.js
module.exports = {
  name: 'no-wip-in-production',
  run({ feature }) {
    const errors = [];
    if (!feature) return errors;

    const allTags = [
      ...(feature.tags || []),
      ...(feature.children || []).flatMap(child =>
        (child.scenario?.tags || [])
      ),
    ];

    const hasWip = allTags.some(tag => tag.name === '@wip');
    if (hasWip && process.env.CI) {
      errors.push({
        message: '@wip tag is not allowed in CI builds',
        rule: 'no-wip-in-production',
        line: 1,
      });
    }

    return errors;
  },
};
```

!!! tip "Start with `no-empty-file`"
    The `no-empty-file` rule in the `gherkin-lint` source tree is the simplest example of a well-structured rule. Read it before writing your own.

## See Also

- [Gherkin Formatter](gherkin-formatter.md) — run before linting
- [Pre-Commit Hooks](pre-commit-hooks.md) — hook configuration
- [Tag Taxonomy Design](../../gherkin/reference/tags-classification.md) — designing the tag set that `allowed-tags` enforces
