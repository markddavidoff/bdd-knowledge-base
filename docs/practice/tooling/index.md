---
title: Tooling Ecosystem
description: Overview of the BDD tooling ecosystem — IDE support, formatting, linting, reporting, and pre-commit hooks for Gherkin feature files.
sources:
  - git-gherkin-utils-readme-features
  - git-gherkin-utils-readme-readme
  - git-gherkin-lint-readme-readme
  - git-playwright-bdd-repo-docs-guides-ide-integration-ide-integration
  - git-playwright-bdd-repo-docs-writing-features-auto-formatting-auto-formatting
---

# Tooling Ecosystem

Good tooling keeps Gherkin files consistent without relying on every author remembering the rules. This section covers the tools that sit around your `.feature` files — editors, formatters, linters, and the pre-commit hooks that wire them together.

## Categories

### IDE Support

Your editor can do most of the heavy lifting for Gherkin authoring:

- **Step autocomplete** — as you type a step, the editor suggests matching step definitions from your codebase.
- **Go-to-definition** — click a step text in a `.feature` file and jump to its TypeScript implementation.
- **Undefined step highlighting** — steps with no matching definition are underlined before you run any tests.

The two main options are the **VS Code Cucumber (Gherkin) Full Support** extension (community, feature-rich) and the **Official Cucumber extension** (Cucumber Open). IntelliJ and WebStorm ship a built-in Cucumber plugin that works out of the box for JVM languages and has reasonable support for TypeScript.

See [IDE Support](ide-support.md) for configuration details.

### Gherkin Formatter

The canonical formatter is `@cucumber/gherkin-utils`. Running `npx @cucumber/gherkin-utils format` on a `.feature` file normalizes:

- Indentation (2-space steps under Feature / Scenario)
- Blank lines between scenarios
- Data table column alignment
- Trailing whitespace

It also handles `.feature.md` (Gherkin Markdown) format conversion in both directions. The formatter is non-destructive — it never changes keywords or step text, only whitespace.

See [Gherkin Formatter](gherkin-formatter.md) for CLI usage, pre-commit setup, and the `pretty()` library API.

### Gherkin Linter

`gherkin-lint` goes beyond whitespace. It checks semantic rules:

- `no-dupe-feature-names` — duplicate Feature titles are a sign of copy-paste drift
- `no-unused-variables` — Scenario Outline `<placeholders>` with no matching Examples column
- `allowed-tags` — enforces your team's agreed tag taxonomy
- `max-scenarios-per-file` — keeps feature files focused
- `required-tags` — ensures classification tags are not forgotten

The linter is configured via `.gherkin-lintrc` (JSON). Rules that detect parser-crashing constructs are always on; semantic rules are opt-in.

See [Gherkin Linter](gherkin-linter.md) for rule reference and CI integration.

### Reporting

Reporting tools translate test execution results back into the living documentation that stakeholders can read. Options range from the built-in Playwright HTML reporter to Allure (with history and trends) to Serenity/JS (full living documentation output). See [Living Documentation](../methodology/living-documentation/index.md) for tool comparisons and CI publishing recipes.

### Pre-Commit Hooks

All of the above tools are most effective when they run automatically on every commit. A standard setup with husky and lint-staged runs:

1. `@cucumber/gherkin-utils format` on all staged `.feature` files (fail-fast on non-formattable syntax errors)
2. `gherkin-lint` on all staged `.feature` files (enforce tag taxonomy and semantic rules)
3. `bddgen --dry-run` as a pre-push hook (catch undefined steps before they reach CI)

See [Pre-Commit Hooks](pre-commit-hooks.md) for the complete husky + lint-staged configuration.

## How the Tools Fit Together

```
 Author edits .feature file
        │
        ▼
 IDE: step autocomplete + undefined step highlighting
        │
        ▼ (git commit)
 pre-commit: gherkin-utils format → gherkin-lint
        │
        ▼ (git push)
 pre-push: bddgen --dry-run
        │
        ▼ (CI)
 Format check + lint + bddgen + playwright test + reporter
```

!!! tip "Format before you lint"
    Always run the formatter before the linter. `gherkin-lint` will flag indentation errors that the formatter would have fixed automatically. Running them in the wrong order causes spurious failures.

!!! note "Prettier as an alternative formatter"
    The playwright-bdd docs suggest `prettier-plugin-gherkin` as a Prettier-based alternative. If your project already uses Prettier for TypeScript, adding the plugin gives you one unified format command. `@cucumber/gherkin-utils` remains the canonical Cucumber-maintained option.

## Quick Reference

| Tool | Install | Purpose |
|------|---------|---------|
| `@cucumber/gherkin-utils` | `npm i -D @cucumber/gherkin-utils` | Format `.feature` files |
| `gherkin-lint` | `npm i -D gherkin-lint` | Lint semantic rules |
| `husky` | `npm i -D husky` | Git hook runner |
| `lint-staged` | `npm i -D lint-staged` | Run tools on staged files only |
| VS Code extension | marketplace | Step autocomplete + go-to-def |
