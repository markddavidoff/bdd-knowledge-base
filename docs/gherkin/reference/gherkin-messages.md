---
title: Gherkin Messages
description: The Cucumber Messages protocol — an NDJSON wire format that carries GherkinDocument, Pickle, and test execution events consumed by all formatters and reporters.
sources:
  - git-playwright-bdd-repo-docs-reporters-cucumber-message
  - git-gherkin-parser-elixir-readme-pretty-printing-to-ndjson
  - git-gherkin-utils-javascript-test-messages-readme-readme
  - git-playwright-bdd-repo-docs-pickles-pickles
---

# Gherkin Messages

The **Cucumber Messages** protocol is a structured, language-independent wire format for communicating everything that happens during a Gherkin-based test run. It is the plumbing that connects the parser, the test runner, and every formatter and reporter in the Cucumber ecosystem.

## Format: NDJSON envelopes

Messages are emitted as **Newline-Delimited JSON (NDJSON)** — one JSON object per line, each wrapped in an `Envelope`:

```json
{"source":{"uri":"features/billing.feature","data":"Feature: Billing\n...","mediaType":"text/x.cucumber.gherkin+plain"}}
{"gherkinDocument":{"uri":"features/billing.feature","feature":{"name":"Billing","children":[...]}}}
{"pickle":{"id":"abc-123","uri":"features/billing.feature","name":"Pro plan allows invoices","steps":[...]}}
{"testRunStarted":{"timestamp":{"seconds":"1719500000","nanos":0}}}
{"testCaseStarted":{"id":"def-456","pickleId":"abc-123","attempt":0,"timestamp":{...}}}
{"testStepStarted":{"testCaseStartedId":"def-456","testStepId":"step-1","timestamp":{...}}}
{"testStepFinished":{"testCaseStartedId":"def-456","testStepId":"step-1","testStepResult":{"status":"PASSED","duration":{...}}}}
{"testCaseFinished":{"testCaseStartedId":"def-456","timestamp":{...},"willBeRetried":false}}
{"testRunFinished":{"success":true,"timestamp":{...}}}
```

Each line is a self-contained JSON object. Tools consume the stream line-by-line, accumulating state as events arrive.

## Message types

The [Cucumber Messages specification](https://github.com/cucumber/messages/blob/main/messages.md) defines the following envelope types:

### Parse-time messages

| Type | Description |
|---|---|
| `Source` | Raw source text of the `.feature` file |
| `GherkinDocument` | Full AST of the parsed feature file |
| `Pickle` | Compiled, flat test unit (Background expanded, Outline rows expanded) |
| `ParseError` | Parse failure with location information |

### Runtime messages

| Type | Description |
|---|---|
| `TestRunStarted` | Emitted once before any test cases run |
| `TestCaseStarted` | Emitted when a Pickle begins execution (includes attempt number for retries) |
| `TestStepStarted` | Emitted before each step in a Pickle |
| `TestStepFinished` | Emitted after each step completes; carries `status` (PASSED, FAILED, PENDING, SKIPPED, UNDEFINED) and duration |
| `TestCaseFinished` | Emitted when all steps in a Pickle complete |
| `TestRunFinished` | Emitted once after all test cases; carries overall `success` flag |
| `Attachment` | Screenshots, logs, and arbitrary binary data attached during execution |

### Meta messages

| Type | Description |
|---|---|
| `Meta` | Runtime environment: Cucumber version, OS, CPU, runtime |
| `StepDefinition` | Registered step definitions (pattern + location) |
| `ParameterType` | Registered custom parameter types |
| `UndefinedParameterType` | Parameter type referenced in a step but not defined |

## Why Messages matter

Before the Messages protocol, each Cucumber reporter had to re-implement its own parsing logic. Messages centralise all test lifecycle events into one stream. Consequences:

- **All formatters are equal** — the HTML reporter, JUnit reporter, JSON reporter, and any custom reporter all consume the same stream; none has privileged access.
- **Language independence** — a Java test run can produce a Messages stream consumed by a JavaScript formatter.
- **Replay** — because the stream is a file, you can replay a test run through a different formatter without re-running the tests.
- **Tooling composability** — tools like Allure, Testomat.io, and Serenity/JS all ingest Messages streams.

## How playwright-bdd emits Messages

Enable the `message` reporter in `playwright.config.ts`:

```typescript
import { defineConfig } from '@playwright/test';
import { defineBddConfig, cucumberReporter } from 'playwright-bdd';

const testDir = defineBddConfig({
  features: ['features/**/*.feature'],
  steps: ['steps/**/*.ts'],
});

export default defineConfig({
  testDir,
  reporter: [
    ['html'],  // Playwright's own HTML reporter (optional)
    cucumberReporter('message', {
      outputFile: 'cucumber-report/report.ndjson',
    }),
  ],
});
```

After a test run, `cucumber-report/report.ndjson` contains the full Messages stream for that run.

!!! warning "Unsupported message types in playwright-bdd"
    As of current releases, playwright-bdd does not emit the following message types:

    - `parameterType`
    - `stepDefinition`
    - `undefinedParameterType`
    - `parseError`

    If your downstream tooling requires these, open an issue at the playwright-bdd repository. All other message types (GherkinDocument, Pickle, test lifecycle events, Attachment) are supported.

### Reporter options

| Option | Type | Default | Description |
|---|---|---|---|
| `outputFile` | `string` | required | Path to the output NDJSON file |
| `skipAttachments` | `boolean \| string[]` | `false` | Skip all attachments, or skip by MIME type |

## Using the Messages output for custom tooling

### Feeding a standard reporter

Any reporter that accepts a Cucumber Messages file works directly with the NDJSON output:

```bash
# Generate HTML report from NDJSON (using @cucumber/react-components)
npx @cucumber/html-formatter < cucumber-report/report.ndjson > report.html

# Or pipe directly from a test run
npx playwright test 2>&1 | npx @cucumber/html-formatter > report.html
```

### Writing a custom consumer in Node.js

```typescript
import * as fs from 'fs';
import * as readline from 'readline';
import { Envelope } from '@cucumber/messages';

const rl = readline.createInterface({
  input: fs.createReadStream('cucumber-report/report.ndjson'),
});

const failures: string[] = [];

for await (const line of rl) {
  const envelope: Envelope = JSON.parse(line);

  if (envelope.testStepFinished) {
    const { testStepResult } = envelope.testStepFinished;
    if (testStepResult.status === 'FAILED') {
      failures.push(testStepResult.message ?? 'unknown failure');
    }
  }
}

console.log(`${failures.length} failed steps`);
```

!!! tip "Use the `@cucumber/messages` package for TypeScript types"
    The `@cucumber/messages` npm package exports TypeScript type definitions for every message type:

    ```bash
    npm install --save-dev @cucumber/messages
    ```

    This gives you full type safety when consuming or producing Messages streams.

### NDJSON stream from the Gherkin parser directly

The Gherkin parser itself can emit a Messages stream without running any tests, useful for static analysis:

```bash
# Parse feature files and emit GherkinDocument + Pickle messages
npx @cucumber/gherkin features/**/*.feature

# Output looks like:
# {"source": {...}}
# {"gherkinDocument": {...}}
# {"pickle": {...}}
# {"pickle": {...}}
```

This is the same stream shape as a test run, minus the execution events — enabling the same tooling to work at parse time or run time.

## See also

- [Gherkin AST](../reference/gherkin-ast.md) — the `GherkinDocument` structure that appears in the Messages stream
- [Reporting](../../practice/playwright-bdd/reporting.md) — Allure, HTML, and Testomat.io reporters that consume Messages
