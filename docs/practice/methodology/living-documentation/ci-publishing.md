---
title: CI Publishing
description: GitHub Actions workflows for publishing BDD HTML reports as artifacts and deploying them to GitHub Pages with versioned archives and badge generation.
sources:
  - git-playwright-bdd-repo-docs-reporters-cucumber-html
  - git-playwright-bdd-repo-docs-reporters-cucumber-cucumber
  - web-bdd-living-documentation-best-practices-for-living-documentation
---

# CI Publishing

Running BDD tests in CI is the minimum viable living documentation setup. Publishing the resulting HTML report to a persistent URL — not just an ephemeral artifact — completes the loop: stakeholders can bookmark it, developers can share it in Slack, and the PO can check it without logging into CI.

This page covers GitHub Actions workflows for:

1. Artifact upload per run (always-on, quick to set up)
2. GitHub Pages deployment (persistent URL, indexed history)
3. Versioned report archives
4. Status badge generation
5. Access control considerations

## Prerequisite: Generate a Report

All publishing strategies require a report to publish. The examples below use the Cucumber HTML reporter (zero config), but the same patterns apply to Allure or Serenity/JS output directories.

```typescript
// playwright.config.ts
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
  ],
});
```

## Pattern 1: Artifact Upload

The simplest approach: upload the report directory as a GitHub Actions artifact after every run.

```yaml
# .github/workflows/bdd.yml
name: BDD Tests

on:
  push:
    branches: [main, 'feature/**']
  pull_request:

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Install Playwright browsers
        run: npx playwright install --with-deps chromium

      - name: Generate BDD specs
        run: npx bddgen

      - name: Run BDD tests
        run: npx playwright test

      - name: Upload BDD report
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: bdd-report-${{ github.run_number }}
          path: cucumber-report/
          retention-days: 30
```

The `if: always()` condition is critical — you want the report uploaded even when tests fail, because a failing report is the most useful one to inspect.

## Pattern 2: GitHub Pages Deployment

For a persistent URL that always shows the latest report from the main branch, deploy to GitHub Pages after every push to `main`.

**Repository setup required:**

1. In the GitHub repo settings, set Pages source to "GitHub Actions" (not a branch)
2. The workflow uses the `actions/deploy-pages` action directly

```yaml
# .github/workflows/bdd-pages.yml
name: BDD Tests and Pages Deploy

on:
  push:
    branches: [main]
  pull_request:

permissions:
  contents: read
  pages: write
  id-token: write

concurrency:
  group: pages
  cancel-in-progress: false

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Install Playwright browsers
        run: npx playwright install --with-deps chromium

      - name: Generate BDD specs
        run: npx bddgen

      - name: Run BDD tests
        run: npx playwright test

      - name: Upload report artifact
        if: always() && github.ref == 'refs/heads/main'
        uses: actions/upload-pages-artifact@v3
        with:
          path: cucumber-report/

  deploy:
    needs: test
    if: always() && github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    steps:
      - name: Deploy to GitHub Pages
        id: deployment
        uses: actions/deploy-pages@v4
```

After deployment, the report is available at `https://<org>.github.io/<repo>/`.

!!! note "Pages only on main"
    The `github.ref == 'refs/heads/main'` condition restricts Pages deployment to the main branch. Pull request runs still upload artifacts (for PR review) but do not overwrite the public Pages URL.

## Pattern 3: Versioned Report Archives

To keep a history of reports rather than overwriting the latest, publish each run under a versioned path. This requires a repository to store the archive.

```yaml
- name: Create versioned report directory
  run: |
    mkdir -p public/reports/${{ github.run_number }}
    cp -r cucumber-report/* public/reports/${{ github.run_number }}/
    # Update the root index to redirect to latest
    echo '<meta http-equiv="refresh" content="0; url=reports/${{ github.run_number }}/index.html">' > public/index.html

- name: Upload versioned archive
  uses: actions/upload-pages-artifact@v3
  with:
    path: public/
```

With this structure, `https://<org>.github.io/<repo>/` always redirects to the latest run, while `https://<org>.github.io/<repo>/reports/42/` is the permanent URL for run 42.

!!! warning "Repository size"
    Versioned archives accumulate over time. If your reports are large (screenshots, traces embedded), this can exhaust repository space quickly. Use `skipAttachments` in the Cucumber HTML config, or limit the archive to the last N runs with a cleanup step.

## Pattern 4: Status Badge

Add a test result badge to your README to make health visible at a glance.

GitHub Actions provides a built-in badge URL:

```markdown
![BDD Tests](https://github.com/<org>/<repo>/actions/workflows/bdd.yml/badge.svg)
```

For more control, use `anuraghazra/github-readme-stats` or generate a custom badge from the Cucumber JSON output:

```bash
# Parse JSON report and generate a Shields.io badge URL
PASSED=$(cat cucumber-report/results.json | jq '[.[] | .elements[] | select(.status == "passed")] | length')
TOTAL=$(cat cucumber-report/results.json | jq '[.[] | .elements[]] | length')
LABEL="BDD scenarios"
COLOR=$([ "$PASSED" = "$TOTAL" ] && echo "brightgreen" || echo "red")
echo "https://img.shields.io/badge/${LABEL}-${PASSED}%2F${TOTAL}-${COLOR}"
```

!!! tip "Cucumber JSON for badge data"
    Add `cucumberReporter('json', { outputFile: 'cucumber-report/results.json' })` alongside the HTML reporter to get machine-readable output for badge generation and downstream tooling without changing the human-readable report.

## Access Control Considerations

GitHub Pages is public by default for public repositories. For internal projects:

- **Private repository + GitHub Pages** — Pages is accessible only to users with repository access (GitHub Teams/Enterprise feature)
- **Artifact download** — artifacts require GitHub login by default, which may be sufficient for internal teams
- **Internal hosting** — for stricter control, publish to an internal server (S3 + CloudFront, Nginx) via the same artifact upload and a separate deploy step

!!! warning "Never embed secrets in reports"
    Playwright screenshots and traces may capture sensitive data from the application under test. Review what your test scenarios touch before making reports publicly accessible. Use `skipAttachments` to exclude traces from public-facing reports.

## Complete Reference: Inputs and Outputs

| Input | Tool | Config |
|-------|------|--------|
| Feature files | playwright-bdd | `features/**/*.feature` |
| Step definitions | playwright-bdd | `steps/**/*.ts` |
| HTML report | cucumberReporter | `outputFile: 'cucumber-report/index.html'` |
| JSON report | cucumberReporter | `outputFile: 'cucumber-report/results.json'` |

| Output | Where | When |
|--------|-------|------|
| CI artifact | GitHub Actions artifacts tab | Every run (`if: always()`) |
| Pages URL | `https://<org>.github.io/<repo>/` | Pushes to `main` only |
| Badge | README | Static URL, reflects latest workflow status |

## Cross-References

- [Living Documentation Overview](./index.md) — why CI is the enforcer of liveness
- [Cucumber HTML Reporter](./cucumber-html.md) — the reporter this workflow publishes
- [Allure Report](./allure.md) — alternative output with history, same artifact/Pages patterns
- [Stakeholder Reporting](./stakeholder-reporting.md) — making the published report useful to non-technical readers
