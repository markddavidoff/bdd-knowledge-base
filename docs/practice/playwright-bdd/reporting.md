---
title: Reporting
description: Configure HTML, Allure, Testomat.io, and JSON reporters for playwright-bdd, with screenshot/video/trace on failure and GitHub Pages publishing.
sources:
  - git-playwright-bdd-repo-docs-reporters-cucumber-cucumber
  - git-playwright-bdd-repo-docs-reporters-cucumber-html
  - git-playwright-bdd-repo-docs-reporters-cucumber-json
  - git-playwright-bdd-repo-docs-reporters-allure-allure
  - git-playwright-bdd-repo-docs-reporters-playwright-playwright
  - git-playwright-bdd-repo-docs-reporters-cucumber-merge-reports
---

# Reporting

playwright-bdd supports two reporter families: **Cucumber reporters** (BDD-aware, show feature/scenario structure) and **Playwright reporters** (full Playwright tooling integration). You configure reporters inside `playwright.config.ts`; the `bddgen` + `playwright test` two-phase run feeds results into whichever reporters you enable.

---

## Cucumber HTML Reporter

The Cucumber HTML reporter produces a single self-contained HTML file grouped by feature and scenario — the most BDD-appropriate default.

```ts
// playwright.config.ts
import { defineConfig } from '@playwright/test';
import { defineBddConfig, cucumberReporter } from 'playwright-bdd';

const testDir = defineBddConfig({
  features: 'features/**/*.feature',
  steps: 'features/steps/**/*.ts',
});

export default defineConfig({
  testDir,
  reporter: [
    cucumberReporter('html', { outputFile: 'cucumber-report/index.html' }),
  ],
});
```

Run and then open the report:

```bash
npx bddgen && npx playwright test
npx http-server ./cucumber-report -c-1 -a localhost -o index.html
```

!!! tip "Open on http:// not file://"
    The trace viewer embedded inside the HTML report requires an HTTP origin. Launch a local server (`npx http-server`) rather than opening the file directly — otherwise traces won't load.

### Embedding Screenshots, Videos, and Traces

playwright-bdd automatically attaches Playwright's screenshots, videos, and traces to Cucumber reports. Enable capture in `playwright.config.ts`:

```ts
export default defineConfig({
  use: {
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
    trace: 'on-first-retry',
  },
  reporter: [
    cucumberReporter('html', {
      outputFile: 'cucumber-report/index.html',
      externalAttachments: true, // stores attachments in data/ subdirectory
    }),
  ],
});
```

Use `skipAttachments` to trim report size when you don't need all attachment types:

```ts
cucumberReporter('html', {
  outputFile: 'cucumber-report/index.html',
  skipAttachments: ['video/webm', 'application/zip'], // drop video + traces
})
```

---

## Allure Reporter

Allure provides trend charts, history, categories, and a richer stakeholder dashboard. Use the `allure-playwright` adapter — not `allure-cucumberjs`.

```ts
import { defineConfig } from '@playwright/test';
import { defineBddConfig } from 'playwright-bdd';

const testDir = defineBddConfig({ /* BDD config */ });

export default defineConfig({
  testDir,
  reporter: 'allure-playwright',
});
```

Install the CLI and generate the report after the run:

```bash
npm install -D allure-playwright allure-commandline
npx bddgen && npx playwright test
npx allure generate allure-results --clean -o allure-report
npx allure open allure-report
```

!!! note "Trend data requires persistence"
    Allure trend charts need an `allure-results/history/` folder from the previous run. In CI, cache or archive that folder between runs to preserve trend history.

---

## JSON Output for Dashboards

The JSON reporter feeds results into third-party dashboards and CI systems:

```ts
reporter: [
  cucumberReporter('json', {
    outputFile: 'cucumber-report/report.json',
    addMetadata: 'list',           // attach Project + Browser metadata
    addProjectToFeatureName: true, // useful for multi-project runs
  }),
]
```

!!! note "Attachments skipped by default (v9+)"
    From v9, the JSON reporter skips screenshots/video/traces by default (`skipAttachments: true`) to avoid oversized files. Set `skipAttachments: false` to re-enable.

Third-party consumers for the Cucumber JSON format:

- [WasiqB/multiple-cucumber-html-reporter](https://github.com/WasiqB/multiple-cucumber-html-reporter)
- [gkushang/cucumber-html-reporter](https://github.com/gkushang/cucumber-html-reporter)

---

## Testomat.io

Testomat.io reads the Cucumber JSON report to link scenario results back to their Gherkin source, display coverage analytics, and track history over time. Generate the JSON report and upload it using their reporter CLI:

```bash
# Generate tests and run
npx bddgen && npx playwright test

# Upload results
npx @testomatio/reporter cucumber-json ./cucumber-report/report.json
```

Set your API key in the environment before uploading:

```bash
TESTOMATIO=<your-api-key> npx @testomatio/reporter cucumber-json ./report.json
```

---

## Merging Shard Reports

When running tests across CI shards, use Playwright's blob reporter to collect per-shard results, then merge into a single Cucumber report:

```ts
const isShardRun = process.argv.some((a) => a.startsWith('--shard'));

export default defineConfig({
  testDir,
  reporter: isShardRun
    ? 'blob'
    : [cucumberReporter('html', { outputFile: 'report.html' })],
});
```

```bash
# Run shards in parallel
npx bddgen && npx playwright test --shard 1/3
npx bddgen && npx playwright test --shard 2/3
npx bddgen && npx playwright test --shard 3/3

# Merge blob reports into a single Cucumber HTML report
npx playwright merge-reports --config playwright.config.ts ./blob-report
```

---

## Publishing to GitHub Pages

```yaml
# .github/workflows/bdd.yml
name: BDD Tests
on: [push]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '20' }
      - run: npm ci
      - run: npx playwright install --with-deps
      - run: npx bddgen && npx playwright test
      - uses: actions/upload-artifact@v4
        if: always()
        with:
          name: cucumber-report
          path: cucumber-report/
      - name: Deploy to GitHub Pages
        if: github.ref == 'refs/heads/main'
        uses: peaceiris/actions-gh-pages@v3
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          publish_dir: ./cucumber-report
```

!!! warning "Keep the Pages URL on http://"
    GitHub Pages serves over HTTPS, which satisfies the trace viewer's origin requirement. No extra steps needed for embedded traces.

---

## Choosing a Reporter

| Reporter | BDD-aware | History/Trends | External Service | Best for |
|----------|-----------|----------------|------------------|----------|
| Cucumber HTML | Yes | No | No | Small teams, quick feedback |
| Allure | Partial | Yes | Optional (TestOps SaaS) | Stakeholder dashboards |
| Testomat.io | Yes | Yes | Yes (SaaS) | Zero-ops reporting |
| Playwright HTML | No | No | No | Playwright-native debugging |
| JSON | Yes (raw) | No | Via third party | CI dashboards, custom tools |

!!! tip "Cross-ref: living documentation tool comparison"
    For a deeper comparison of Allure, Serenity/JS, Testomat.io, and the built-in HTML reporter as living documentation platforms, see [Living Documentation](../methodology/living-documentation/index.md).
