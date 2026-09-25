---
title: Allure Report
description: Rich BDD test reports with history, trends, retries, and stakeholder dashboards using allure-playwright and the Allure CLI.
sources:
  - git-playwright-bdd-repo-docs-reporters-allure-allure
  - git-playwright-bdd-repo-docs-reporters-cucumber-cucumber
  - web-bdd-living-documentation-the-power-of-living-documentation
---

# Allure Report

Allure is a separate open-source reporting framework that produces rich, interactive HTML reports with historical trend data. For playwright-bdd projects, it integrates via the `allure-playwright` adapter — not `allure-cucumberjs`. The result is a stakeholder-grade report that shows pass rates over time, categorized failures, retry analysis, and per-step screenshots.

## What Allure Adds Over Cucumber HTML

| Capability | Cucumber HTML | Allure |
|------------|--------------|--------|
| Single-run results | Yes | Yes |
| History across runs | No | Yes |
| Trend graphs | No | Yes |
| Retry tracking | No | Yes |
| Failure categories | No | Yes (configurable) |
| Attachments | Yes | Yes |
| Self-hosted server | Not needed | Optional (Allure TestOps) |

## Installation

**Step 1** — Install the Allure CLI (requires Java 11+):

```bash
# macOS
brew install allure

# or via npm wrapper
npm install --save-dev allure-commandline
```

**Step 2** — Install the Playwright reporter:

```bash
npm install --save-dev allure-playwright
```

**Step 3** — Configure `playwright.config.ts`:

```typescript
import { defineConfig } from '@playwright/test';
import { defineBddConfig } from 'playwright-bdd';

const testDir = defineBddConfig({
  features: 'features/**/*.feature',
  steps: 'steps/**/*.ts',
});

export default defineConfig({
  testDir,
  reporter: [
    ['list'],                    // terminal output
    ['allure-playwright', {      // Allure results dir
      detail: true,
      outputFolder: 'allure-results',
      suiteTitle: false,
    }],
  ],
});
```

## Running and Generating the Report

```bash
# Generate BDD specs and run tests
npx bddgen && npx playwright test

# Generate the HTML report from raw results
allure generate allure-results --clean -o allure-report

# Open the report in a browser
allure open allure-report
```

!!! note "Two-step process"
    Allure separates *results collection* (JSON files written during the test run) from *report generation* (converting those files to HTML). The `allure-results/` directory is the raw output; `allure-report/` is the rendered HTML. This separation is what enables historical trend data — each run appends to the results history.

## History and Trends

To enable trend tracking, preserve the history directory between runs:

```bash
# Before each run, copy previous history into the results dir
cp -r allure-report/history allure-results/history 2>/dev/null || true

# Run tests
npx bddgen && npx playwright test

# Generate new report with history
allure generate allure-results --clean -o allure-report
```

In CI, this is typically done by caching `allure-report/history` between pipeline runs (see the CI section below).

## Failure Categories

Create `categories.json` in the project root to classify failures automatically:

```json
[
  {
    "name": "Infrastructure failures",
    "messageRegex": ".*net::ERR.*|.*ECONNREFUSED.*",
    "matchedStatuses": ["broken"]
  },
  {
    "name": "Assertion failures",
    "messageRegex": ".*expect.*",
    "matchedStatuses": ["failed"]
  }
]
```

Move this file to `allure-results/` before generating the report. Allure uses it to group failures into categories on the report's Behaviors tab.

## CI Integration

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

      - name: Restore Allure history
        uses: actions/cache@v4
        with:
          path: allure-report/history
          key: allure-history-${{ github.ref }}
          restore-keys: allure-history-

      - name: Seed history into results dir
        run: |
          mkdir -p allure-results
          cp -r allure-report/history allure-results/history 2>/dev/null || true

      - name: Generate BDD specs
        run: npx bddgen

      - name: Run BDD tests
        run: npx playwright test

      - name: Generate Allure report
        if: always()
        run: allure generate allure-results --clean -o allure-report

      - name: Upload Allure report
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: allure-report-${{ github.run_number }}
          path: allure-report/
          retention-days: 90
```

!!! tip "Allure TestOps"
    For teams that want a hosted dashboard without managing a server, Allure TestOps is the commercial SaaS offering from the same vendor. It ingests `allure-results` directly via the CLI and provides a persistent web UI, role-based access, and Jira integration. The `allure-playwright` adapter works identically for both the CLI and TestOps targets.

## Pros and Cons

**Pros:**

- History and trend graphs show whether quality is improving or degrading over sprints
- Retry tracking distinguishes genuine failures from transient flakiness
- Categories tab groups failures for faster diagnosis
- Stakeholder-ready: executive summary on the Overview tab
- Open source CLI is free; no mandatory SaaS dependency

**Cons:**

- Requires Java 11+ or the `allure-commandline` npm wrapper
- Two-step workflow (run → generate) adds friction locally and in CI
- History requires explicit caching/copying between runs — not automatic
- Allure TestOps (the managed option) is a paid product

## When to Use

Use Allure when:

- The team wants to track trend data over multiple sprints
- You need to distinguish infrastructure failures from genuine assertion failures
- Stakeholders ask "is the test suite getting healthier?" rather than just "did today's run pass?"
- You can afford the added CI complexity of managing history artifacts

## Example Feature with Allure Labels

Allure supports labeling scenarios for better organization in the report. Labels are added as tags:

```gherkin
Feature: Billing

  @allure.label.epic:Payments
  @allure.label.story:Subscription
  Scenario: Upgrade from free to pro
    Given Alice has a free account
    When she upgrades to the "Pro Plan"
    Then her subscription status is "pro"
    And billing is enabled on her account
```

These tags appear as Epics and Stories in the Allure Behaviors tab, giving the report a business-feature navigation structure.

## Cross-References

- [Living Documentation Overview](./index.md) — tool comparison table
- [Cucumber HTML Reporter](./cucumber-html.md) — simpler starting point, no history
- [CI Publishing](./ci-publishing.md) — GitHub Pages deployment strategy
- [Stakeholder Reporting](./stakeholder-reporting.md) — what the Allure Overview tab communicates
