---
title: Gherkin AST
description: The Gherkin Abstract Syntax Tree (AST) structure, the Pickle compiled representation, and the GherkinDocumentWalker API for custom tooling.
sources:
  - git-gherkin-utils-readme-scenario
  - git-gherkin-utils-readme-usage
  - git-gherkin-utils-readme-features
  - git-playwright-bdd-repo-docs-pickles-pickles
  - git-gherkin-parser-elixir-readme-pretty-printing-to-ndjson
---

# Gherkin AST

When the Gherkin parser reads a `.feature` file it produces an **Abstract Syntax Tree (AST)** — a structured in-memory representation of the document. This AST is the foundation for test runners, formatters, linters, and all other tooling that works with feature files.

## The AST structure

A parsed Gherkin document has the following hierarchy:

```
GherkinDocument
└── Feature
    ├── Background (0 or 1)
    │   └── Step[]
    ├── Scenario[]
    │   ├── Step[]
    │   └── Tag[]
    └── Rule[]
        ├── Background (0 or 1)
        └── Scenario[]
            ├── Step[]
            └── Tag[]
```

Each node carries identity metadata (`id`, `location`) and the text extracted from the feature file.

### Parsing a document in JavaScript/TypeScript

```typescript
import {
  AstBuilder,
  GherkinClassicTokenMatcher,
  Parser,
} from '@cucumber/gherkin';
import { IdGenerator } from '@cucumber/messages';

const uuidFn = IdGenerator.uuid();
const builder = new AstBuilder(uuidFn);
const matcher = new GherkinClassicTokenMatcher();
const parser = new Parser(builder, matcher);

const source = `Feature: Billing

  Scenario: Pro plan allows invoices
    Given the organization is on the pro plan
    When billing is triggered
    Then an invoice is generated
`;

const gherkinDocument = parser.parse(source);
// gherkinDocument.feature.children[0].scenario.name
// => "Pro plan allows invoices"
```

## The Pickle: the compiled test unit

The AST is the raw parse tree; **Pickles** are the compiled, runner-ready form that test frameworks actually execute.

The `PickleCompiler` (part of `@cucumber/gherkin`) transforms a `GherkinDocument` into an array of `Pickle` objects by:

1. **Expanding Background steps** — each scenario's Pickle includes the Background steps prepended to its own steps.
2. **Expanding Scenario Outline rows** — each Examples row produces a separate Pickle with placeholders substituted.

### Example: Background + Scenario Outline expansion

Given this feature file:

```gherkin
Feature: feature 1

  Background:
    Given step A

  Scenario: scenario 1
    Given step B

  Scenario Outline: scenario 2
    Given step C

  Examples:
    | x |
    | 1 |
    | 2 |
```

The compiler produces **3 Pickles**:

```
Pickle 1  (scenario 1)
  PickleStep 1.1  ->  step A  (from Background)
  PickleStep 1.2  ->  step B

Pickle 2  (scenario 2, row 1, x=1)
  PickleStep 2.1  ->  step A  (from Background)
  PickleStep 2.2  ->  step C  (with x=1 substituted)

Pickle 3  (scenario 2, row 2, x=2)
  PickleStep 3.1  ->  step A  (from Background)
  PickleStep 3.2  ->  step C  (with x=2 substituted)
```

!!! note "Why Pickles exist"
    The Gherkin AST faithfully mirrors the file structure — it has one `Scenario Outline` node, not one node per row. Test runners need one runnable unit per test case. Pickles provide that flat, self-contained representation. Each Pickle has a `name`, an ordered `steps` array, and `tags` (inherited from Feature, Rule, Scenario, and Examples table).

### Pickle `astNodeIds`

Every Pickle and PickleStep carries `astNodeIds` — references back to the AST nodes they originated from. This is how reporters link a test result back to the line number in the feature file.

## The GherkinDocumentWalker

`@cucumber/gherkin-utils` ships a `GherkinDocumentWalker` class for traversing and filtering the AST. It produces a deep copy of the document, optionally with scenarios or steps filtered out.

```typescript
import { GherkinDocumentWalker, rejectAllFilters } from '@cucumber/gherkin-utils';

// Filter: keep only scenarios whose name contains "billing"
const billingFilter = new GherkinDocumentWalker({
  ...rejectAllFilters,
  acceptScenario: (scenario) => scenario.name.toLowerCase().includes('billing'),
});

const filteredDoc = billingFilter.walkGherkinDocument(gherkinDocument);
```

### Handler callbacks

Walkers also accept handler callbacks that are called for each node — useful for collecting data rather than filtering:

```typescript
const scenarioNames: string[] = [];

const nameFinder = new GherkinDocumentWalker(
  {},  // no filters — accept everything
  {
    handleScenario: (scenario) => {
      scenarioNames.push(scenario.name);
    },
  }
);

nameFinder.walkGherkinDocument(gherkinDocument);
// scenarioNames now contains every scenario title in the document
```

The walker respects the structural invariants of Gherkin: a Background, if present, is always included in the result even when filtering scenarios, because removing it would change the meaning of the remaining scenarios.

## The `pretty()` function

`@cucumber/gherkin-utils` also exports a `pretty()` function that serialises a `GherkinDocument` back to canonical Gherkin text or Markdown:

```typescript
import { pretty } from '@cucumber/gherkin-utils';

const canonical = pretty(gherkinDocument);
// Returns correctly-indented Gherkin text

const markdown = pretty(gherkinDocument, 'markdown');
// Returns .feature.md format
```

This is the function used by `npx @cucumber/gherkin-utils format` under the hood.

## When to use the AST API

The AST API is not needed for ordinary BDD test authoring — playwright-bdd and @cucumber/cucumber handle the parse-to-run pipeline internally. Use it when building:

- **Custom linters** — walk the AST to enforce project-specific rules (e.g., maximum scenarios per file, required tags on every scenario)
- **Reporters and dashboards** — collect scenario names and tags from all feature files without running tests
- **Code generators** — produce step definition skeletons from feature file analysis
- **Step coverage tools** — match step text against existing step definitions to find gaps
- **Feature file formatters** — normalise indentation, sort steps, convert to Markdown

!!! tip "Use the NDJSON stream for large corpora"
    For processing many feature files, the Gherkin CLI outputs one `GherkinDocument` message per file as NDJSON. This stream-based approach is more memory-efficient than parsing each file in isolation:

    ```bash
    npx @cucumber/gherkin-utils format --format=ndjson features/**/*.feature
    ```

    Each line is a `messages.Envelope` containing a `GherkinDocument`, `Pickle`, or `Source` message.

## See also

- [Gherkin Messages](../reference/gherkin-messages.md) — the NDJSON wire format that wraps GherkinDocument, Pickle, and test results
- [Scenario Outline](../reference/scenario-outline.md) — how Examples rows become Pickles
- [Background](../reference/background.md) — Background step inclusion in Pickles
