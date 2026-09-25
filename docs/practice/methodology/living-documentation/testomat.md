---
title: Testomat.io
description: Managed SaaS living documentation platform with Gherkin source linking, coverage tracking, and a playwright-bdd integration for zero-ops BDD reporting.
sources:
  - web-bdd-living-documentation-behavior-driven-development-aligning-stakeholders-through-living-documentation
  - web-bdd-living-documentation-measuring-success
  - git-playwright-bdd-repo-docs-reporters-cucumber-cucumber
---

# Testomat.io

Testomat.io is a managed SaaS platform that stores test results, links them to Gherkin source, tracks scenario coverage over time, and provides a stakeholder-ready web dashboard — without requiring you to host or maintain any reporting infrastructure.

For playwright-bdd teams that want living documentation without operational overhead, it is the most direct path: push results to Testomat.io, share a URL.

## What Testomat.io Provides

- **Gherkin-linked results** — each test result is associated with its source scenario, so you can click from a result back to the feature file
- **Coverage tracking** — see which scenarios have been run, which are passing, and which have never been executed
- **Historical trends** — pass rates over time, without managing history files yourself
- **Team collaboration** — multiple users can view reports, comment on failures, and assign issues
- **Stakeholder view** — role-based access means POs see the summary view without raw test output

## Integration with playwright-bdd

Testomat.io provides a reporter package that integrates with the Playwright test runner. Install it alongside playwright-bdd:

```bash
npm install --save-dev @testomatio/reporter
```

Configure `playwright.config.ts` to use both the Testomat.io reporter and (optionally) the Cucumber HTML reporter for local inspection:

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
    ['list'],
    cucumberReporter('html', { outputFile: 'cucumber-report/index.html' }),
    ['@testomatio/reporter/lib/adapter/playwright.js', {
      apiKey: process.env.TESTOMATIO_API_KEY,
    }],
  ],
});
```

!!! warning "Check current status"
    The playwright-bdd native integration with Testomat.io was on the roadmap as of mid-2026. Confirm the current state of the `@testomatio/reporter` package with playwright-bdd before committing to this integration in a production project. The Testomat.io docs and the playwright-bdd GitHub issues are the authoritative sources.

## Environment Variable Setup

The API key is the only required configuration:

```bash
# .env.local (never commit this)
TESTOMATIO_API_KEY=your-api-key-here

# Optional: specify the project
TESTOMATIO=your-project-id
```

In CI, add `TESTOMATIO_API_KEY` as a repository secret:

```yaml
- name: Run BDD tests
  env:
    TESTOMATIO_API_KEY: ${{ secrets.TESTOMATIO_API_KEY }}
  run: npx bddgen && npx playwright test
```

No additional steps are required — the reporter sends results to Testomat.io during the test run.

## Syncing Gherkin Scenarios

Testomat.io can import your feature files to build a test repository that maps to results. Use the Testomat.io CLI to sync:

```bash
# Install the CLI
npm install --save-dev @testomatio/check-tests

# Sync feature files to Testomat.io
npx check-tests Playwright 'features/**/*.feature' --import
```

After syncing, each Gherkin scenario appears in the Testomat.io UI with its source text. When tests run, results attach to those source scenarios — giving you the Gherkin-to-result link.

## Example: Full CI Step

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

      - name: Run BDD tests and report to Testomat.io
        env:
          TESTOMATIO_API_KEY: ${{ secrets.TESTOMATIO_API_KEY }}
        run: npx playwright test

      - name: Upload local report (fallback)
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: cucumber-report
          path: cucumber-report/
```

## Pros and Cons

**Pros:**

- Zero hosting infrastructure — no server to maintain, no Java, no CLI artifacts
- Coverage analytics show which scenarios are running and which are dead code
- Historical trends are automatic — no history file management required
- Stakeholder view is built in — share a URL, not a file
- Issue tracking integration (Jira, GitHub Issues)

**Cons:**

- SaaS dependency — your test data leaves your infrastructure
- Cost — Testomat.io is a paid product beyond the free tier
- Network dependency — CI must have outbound access to Testomat.io's API
- Roadmap dependency — the playwright-bdd native integration depth depends on both projects' release cadences
- Vendor lock-in risk for long-running projects

## When to Use

Use Testomat.io when:

- The team has no appetite for hosting and maintaining a reporting server
- Stakeholders need a shared web dashboard, not a file to download
- Coverage analytics (which scenarios are exercised, which are not) are a priority
- The cost is acceptable and data residency is not a constraint

!!! tip "Free tier starting point"
    Testomat.io offers a free tier suitable for evaluating the integration. Start there before committing to a paid plan — the free tier is sufficient to validate whether the Gherkin-linked results view meets your team's needs.

## Comparison with Self-Hosted Options

| Concern | Testomat.io | Allure CLI | Serenity/JS |
|---------|------------|-----------|------------|
| Hosting burden | None (SaaS) | Low (CI artifact) | Low (CI artifact) |
| Historical data | Automatic | Manual (cache) | Manual (artifact) |
| Data control | External | You own it | You own it |
| Setup time | Minutes | 30–60 min | Several hours |
| Cost | Paid (free tier) | Free | Free |

## Cross-References

- [Living Documentation Overview](./index.md) — tool comparison table
- [Cucumber HTML Reporter](./cucumber-html.md) — zero-cost local alternative
- [Allure Report](./allure.md) — self-hosted history and trends
- [CI Publishing](./ci-publishing.md) — self-hosted GitHub Pages approach
- [Stakeholder Reporting](./stakeholder-reporting.md) — what the dashboard communicates
