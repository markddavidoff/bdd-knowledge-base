---
title: Cucumber HTML Reporter
description: The zero-config, single-file HTML reporter built into playwright-bdd — the fastest path from BDD scenarios to a readable report.
sources:
  - git-playwright-bdd-repo-docs-reporters-cucumber-html
  - git-playwright-bdd-repo-docs-reporters-cucumber-cucumber
  - git-playwright-bdd-repo-github-skills-debug-cucumber-html-report-skill-skill
---

# Cucumber HTML Reporter

The Cucumber HTML reporter is the simplest way to produce a human-readable report from your BDD scenarios. It is built into playwright-bdd via the `cucumberReporter` adapter — no additional packages, no external service, no CLI step required.

## What It Produces

A single self-contained `index.html` file that shows:

- Each feature and scenario, organized by feature file
- Step-level pass/fail status with duration
- Embedded screenshots, videos, and Playwright traces (when enabled)
- Project names (when using multiple Playwright projects like `chromium` / `firefox`)

The report is a single file you can open directly in a browser, email to a colleague, or upload as a CI artifact.

## Configuration

Add the `cucumberReporter` call to your `playwright.config.ts`:

```typescript
import { defineConfig } from '@playwright/test';
import { defineBddConfig, cucumberReporter } from 'playwright-bdd';

const testDir = defineBddConfig({
  features: 'features/**/*.feature',
  steps: 'steps/**/*.ts',
});

export default defineConfig({
  testDir,
  reporter: [
    ['list'],  // terminal output during the run
    cucumberReporter('html', { outputFile: 'cucumber-report/index.html' }),
  ],
});
```

Run as usual:

```bash
npx bddgen && npx playwright test
```

The report is written to `cucumber-report/index.html` after the run completes.

## Reporter Options

| Option | Type | Default | Purpose |
|--------|------|---------|---------|
| `outputFile` | `string` | — | Path for the generated HTML file |
| `skipAttachments` | `boolean \| string[]` | `false` | Exclude attachment types to reduce file size |
| `externalAttachments` | `boolean` | `false` | Store attachments in a `data/` subdirectory |
| `attachmentsBaseURL` | `string` | — | Override base URL when data dir is uploaded separately |

### Reducing Report Size

For large test suites with screenshots and traces, the report file can become very large. Exclude heavy attachments:

```typescript
cucumberReporter('html', {
  outputFile: 'cucumber-report/index.html',
  skipAttachments: ['video/webm', 'application/zip'],  // keep screenshots, skip video+trace
})
```

### Trace Viewer Integration

Enable `externalAttachments` to embed the Playwright trace viewer directly in the HTML report. This lets you click into a failing step and see the full network/DOM trace:

```typescript
cucumberReporter('html', {
  outputFile: 'cucumber-report/index.html',
  externalAttachments: true,
})
```

!!! note "Trace viewer requires HTTP"
    The embedded trace viewer only works when the report is served over `http://` or `https://`. Open it locally with:
    ```bash
    npx http-server ./cucumber-report -c-1 -a localhost -o index.html
    ```
    Add this to `package.json` scripts as `"report"` for quick access.

## Pros and Cons

**Pros:**

- Zero additional dependencies — `cucumberReporter` ships with playwright-bdd
- Produces output immediately after `npx playwright test` completes
- Self-contained file is easy to share, archive, or publish
- Supports multiple Playwright projects in a single report
- Trace viewer integration available

**Cons:**

- No history — each run overwrites the previous report
- No trend analysis — you cannot see whether failures are increasing over time
- Ephemeral by default — the file is deleted on the next run unless you save it
- Not a stakeholder dashboard — it shows raw step-level data, not executive summaries

## When to Use

Use Cucumber HTML when:

- Your team is getting started with BDD and does not yet need historical data
- You want a zero-ops solution with no external service dependency
- You are publishing reports as CI artifacts for short-term inspection
- Your team is small and the PO/BA can open a link directly

!!! tip "GitHub Pages for persistence"
    Even though the report has no built-in history, you can preserve each run's report by publishing to GitHub Pages with a versioned path. See [CI Publishing](./ci-publishing.md) for a complete workflow.

## CI Artifact Upload

The minimal CI approach: upload the report as an artifact on every run.

```yaml
# .github/workflows/bdd.yml
name: BDD Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install dependencies
        run: npm ci

      - name: Install Playwright browsers
        run: npx playwright install --with-deps chromium

      - name: Generate BDD specs
        run: npx bddgen

      - name: Run BDD tests
        run: npx playwright test

      - name: Upload Cucumber HTML report
        if: always()   # upload even on failure
        uses: actions/upload-artifact@v4
        with:
          name: cucumber-report-${{ github.run_number }}
          path: cucumber-report/
          retention-days: 30
```

The `if: always()` ensures the report is uploaded even when tests fail — which is exactly when you most want to inspect it.

## Example: Feature File and Config Together

```gherkin
# features/checkout.feature
Feature: Checkout

  Scenario: Successful purchase with a saved card
    Given Alice has a pro account with a saved payment method
    When she completes checkout for the "Annual Plan"
    Then her subscription status is "active"
    And she receives a confirmation email
```

With the config above, this scenario appears in `cucumber-report/index.html` with pass/fail status per step, any attached screenshots, and the Playwright project name if multiple browsers are configured.

## Cross-References

- [Living Documentation Overview](./index.md) — context and tool comparison table
- [CI Publishing](./ci-publishing.md) — GitHub Pages deployment for persistent reports
- [Allure Report](./allure.md) — upgrade path when you need history and trends
