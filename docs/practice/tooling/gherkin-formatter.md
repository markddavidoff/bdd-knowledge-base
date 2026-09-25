---
title: Gherkin Formatter
description: Using @cucumber/gherkin-utils to format .feature files — CLI usage, .feature.md conversion, pre-commit hook setup, and the GherkinDocumentWalker library API.
sources:
  - git-gherkin-utils-readme-features
  - git-gherkin-utils-readme-usage
  - git-gherkin-utils-readme-readme
  - git-playwright-bdd-repo-docs-writing-features-auto-formatting-auto-formatting
---

# Gherkin Formatter

`@cucumber/gherkin-utils` is the canonical Cucumber-maintained formatter for `.feature` files. It normalizes indentation, spacing, and keyword alignment without touching step text or reordering content.

## Installation

```bash
npm install --save-dev @cucumber/gherkin-utils
```

## CLI Usage

### Formatting Feature Files

```bash
# Format a single file (in-place)
npx @cucumber/gherkin-utils format features/login.feature

# Format multiple files
npx @cucumber/gherkin-utils format features/login.feature features/checkout.feature

# Format all .feature files in a directory
npx @cucumber/gherkin-utils format features/*.feature

# Format recursively (all subdirectories)
npx @cucumber/gherkin-utils format "features/**/*.feature"
```

The formatter normalizes:

- **Indentation** — Feature at 0, Scenario at 2 spaces, Steps at 4 spaces, Examples rows at 6 spaces
- **Blank lines** — one blank line between scenarios; blank line after Feature description
- **Data table alignment** — columns padded to equal width
- **Trailing whitespace** — removed on all lines

### What the Formatter Fixes

Before formatting:
```gherkin
Feature:User Login
Scenario: successful login
Given I am on the login page
When I enter   "alice@example.com" and "secret"
Then   I am redirected to the dashboard
```

After formatting:
```gherkin
Feature: User Login

  Scenario: successful login
    Given I am on the login page
    When I enter "alice@example.com" and "secret"
    Then I am redirected to the dashboard
```

!!! note "Non-destructive"
    The formatter never changes step text, reorders content, or modifies Feature/Scenario titles. It only adjusts whitespace.

## Gherkin Markdown Conversion

`@cucumber/gherkin-utils` supports `.feature.md` — Gherkin embedded in Markdown code fences. This format allows feature files to live alongside prose documentation.

```bash
# Convert .feature → .feature.md (Markdown with Gherkin)
npx @cucumber/gherkin-utils format --to-syntax=markdown features/login.feature

# Convert .feature.md → .feature (classic Gherkin)
npx @cucumber/gherkin-utils format --to-syntax=gherkin features/login.feature.md
```

A `.feature.md` file looks like this:

```markdown
# User Login

## Scenario: Successful login

```gherkin
Given I am on the login page
When I enter "alice@example.com" and "secret"
Then I am redirected to the dashboard
` ` `
```

!!! tip "Mixing formats"
    Most teams use classic `.feature` files. `.feature.md` is useful when you want feature content to render natively on GitHub or in documentation sites without a Gherkin parser.

## Pre-Commit Hook Setup

Run the formatter automatically on every commit using husky and lint-staged. See [Pre-Commit Hooks](pre-commit-hooks.md) for the full setup. The key `lint-staged` entry:

```json
{
  "lint-staged": {
    "**/*.feature": [
      "npx @cucumber/gherkin-utils format"
    ]
  }
}
```

## CI Formatting Enforcement

To block PRs that contain unformatted feature files, run the formatter in check mode and diff:

```yaml
# .github/workflows/ci.yml
- name: Check Gherkin formatting
  run: |
    npx @cucumber/gherkin-utils format "features/**/*.feature"
    git diff --exit-code -- "*.feature"
```

If the formatter changes any file, `git diff --exit-code` returns a non-zero exit code and the CI step fails. The diff output shows exactly what was wrong.

Alternatively, format then check with `git status`:

```bash
npx @cucumber/gherkin-utils format "features/**/*.feature"
if ! git diff --quiet; then
  echo "Feature files are not formatted. Run: npx @cucumber/gherkin-utils format features/**/*.feature"
  git diff
  exit 1
fi
```

## Library API

### `pretty()` Function

Use the `pretty()` function when you need to format Gherkin programmatically — for example, in a script that generates feature files or transforms an AST:

```typescript
import { AstBuilder, GherkinClassicTokenMatcher, Parser } from '@cucumber/gherkin';
import { pretty } from '@cucumber/gherkin-utils';
import { IdGenerator } from '@cucumber/messages';

const uuidFn = IdGenerator.uuid();
const builder = new AstBuilder(uuidFn);
const matcher = new GherkinClassicTokenMatcher();
const parser = new Parser(builder, matcher);

const rawFeature = `Feature:
Scenario:
Given step text`;

const gherkinDocument = parser.parse(rawFeature);

// Format as classic Gherkin
const formatted = pretty(gherkinDocument);
// → "Feature:\n\n  Scenario:\n    Given step text\n\n"

// Format as Gherkin Markdown
const markdown = pretty(gherkinDocument, 'markdown');
// → "# Feature:\n\n## Scenario:\n\n```gherkin\nGiven step text\n```\n"
```

### `GherkinDocumentWalker`

`GherkinDocumentWalker` is a visitor-pattern API for traversing the Gherkin AST. Use it to build custom tooling — for example, extracting all step texts from a feature file or validating custom naming conventions:

```typescript
import { GherkinDocumentWalker } from '@cucumber/gherkin-utils';
import type { messages } from '@cucumber/messages';

class StepCollector extends GherkinDocumentWalker {
  readonly steps: string[] = [];

  override handleStep(step: messages.Step): void {
    this.steps.push(`${step.keyword}${step.text}`);
  }
}

const collector = new StepCollector();
collector.walkGherkinDocument(gherkinDocument);
console.log(collector.steps);
// → ["Given I am on the login page", "When I enter ...", "Then I am redirected ..."]
```

The walker visits every node in the AST. Override the `handle*` methods for the nodes you care about.

!!! example "Custom tooling use case"
    The `GherkinDocumentWalker` API is how you would build a script that validates all `Then` steps contain an assertion verb, or reports which features use a deprecated step pattern — without writing a regex parser for `.feature` files.

## See Also

- [Gherkin Linter](gherkin-linter.md) — semantic rule enforcement (run after formatting)
- [Pre-Commit Hooks](pre-commit-hooks.md) — wiring format + lint into git hooks
- [Gherkin Grammar and AST](../../gherkin/reference/gherkin-ast.md) — understanding the AST the formatter walks
