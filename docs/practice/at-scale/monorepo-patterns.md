---
title: Monorepo Patterns for playwright-bdd
description: Directory scoping, shared step packages, root playwright.config.ts with multiple BDD projects, and Turborepo/Nx task sequencing for bddgen→test.
sources:
  - git-playwright-bdd-repo-docs-configuration-multiple-projects-different-feature-files
  - git-playwright-bdd-repo-docs-configuration-multiple-projects-shared-feature-files
  - git-playwright-bdd-repo-docs-guides-usage-with-nx-usage-with-nx
  - git-playwright-bdd-repo-docs-writing-steps-scoped-scoped
---

# Monorepo Patterns for playwright-bdd

playwright-bdd's `defineBddProject()` helper and Playwright's multi-project configuration compose naturally with monorepo structures. This page covers the canonical layout, configuration patterns, and build-tool integration for Turborepo and Nx.

## Canonical Monorepo Layout

```
/
├── packages/
│   └── shared/
│       ├── steps/
│       │   ├── auth.steps.ts       # Shared authentication steps
│       │   └── navigation.steps.ts
│       └── parameters/
│           └── index.ts            # Shared parameter types
├── apps/
│   ├── checkout/
│   │   └── e2e/
│   │       ├── features/
│   │       │   └── checkout.feature
│   │       └── steps/
│   │           └── checkout.steps.ts
│   └── billing/
│       └── e2e/
│           ├── features/
│           │   └── billing.feature
│           └── steps/
│               └── billing.steps.ts
├── playwright.config.ts
└── package.json  (workspaces)
```

Shared steps live in `packages/shared/steps/` and are accessible to all apps via workspace package imports. Team-owned steps live inside each app's `e2e/steps/` directory.

## Root playwright.config.ts with Multiple BDD Projects

Use `defineBddProject()` to configure each domain as a separate Playwright project. Each project gets its own `outputDir` to avoid generated file conflicts.

```typescript
// playwright.config.ts
import { defineConfig } from '@playwright/test';
import { defineBddProject } from 'playwright-bdd';

export default defineConfig({
  // Default timeout and retry settings apply to all projects
  timeout: 30_000,
  retries: process.env.CI ? 2 : 0,

  projects: [
    {
      ...defineBddProject({
        name: 'checkout',
        features: 'apps/checkout/e2e/features/**/*.feature',
        steps: [
          'packages/shared/steps/**/*.ts',     // Shared steps
          'apps/checkout/e2e/steps/**/*.ts',   // Checkout-specific steps
        ],
        import: ['packages/shared/parameters/index.ts'],
      }),
      use: { baseURL: 'http://localhost:3001' },
    },
    {
      ...defineBddProject({
        name: 'billing',
        features: 'apps/billing/e2e/features/**/*.feature',
        steps: [
          'packages/shared/steps/**/*.ts',
          'apps/billing/e2e/steps/**/*.ts',
        ],
        import: ['packages/shared/parameters/index.ts'],
      }),
      use: { baseURL: 'http://localhost:3002' },
    },
  ],
});
```

!!! note "`defineBddProject()` sets `outputDir` automatically"
    `defineBddProject()` creates a unique `outputDir` derived from the project name (e.g., `.features-gen/checkout`). If you use `defineBddConfig()` manually, set `outputDir` explicitly per project to avoid generated file collisions.

## Shared Steps Import Pattern

Shared step files export `Given`/`When`/`Then` bound to a shared test fixture:

```typescript
// packages/shared/steps/auth.steps.ts
import { createBdd } from 'playwright-bdd';
import { test } from '../fixtures';  // Shared fixture with apiClient, etc.

const { Given, When } = createBdd(test);

Given('Alice has a {user-role} account', async ({ apiClient }, role) => {
  await apiClient.users.create({ email: 'alice@example.com', role });
});

Given('Alice is logged in as {user-role}', async ({ page, apiClient }, role) => {
  await apiClient.auth.loginAs(page, 'alice@example.com', role);
});
```

Team step files import team-specific fixtures and extend the shared fixture:

```typescript
// apps/checkout/e2e/steps/checkout.steps.ts
import { createBdd } from 'playwright-bdd';
import { test } from './fixtures';  // Extends shared fixture

const { Given, When, Then } = createBdd(test);

Given('the cart contains {string}', async ({ cartPage }, productName: string) => {
  await cartPage.addItem(productName);
});
```

## Scoped Step Definitions for Domain Isolation

When two apps have steps with the same text but different implementations, use `tags` to scope:

```typescript
// apps/checkout/e2e/steps/checkout.steps.ts
When('I click the PLAY button', { tags: '@checkout' }, async ({ page }) => {
  await page.getByTestId('checkout-play').click();
});
```

```gherkin
@checkout
Feature: Checkout flow
  Scenario: ...
    When I click the PLAY button
```

Tags-from-path can automate this scoping — see [Scoped Step Definitions](../playwright-bdd/scoped-steps.md).

## Turborepo Task Sequencing

`bddgen` must complete before `playwright test`. In Turborepo, express this as a dependency chain in `turbo.json`:

```json
{
  "tasks": {
    "bddgen": {
      "outputs": [".features-gen/**"],
      "inputs": ["e2e/features/**/*.feature", "e2e/steps/**/*.ts"]
    },
    "e2e": {
      "dependsOn": ["bddgen", "^build"],
      "outputs": ["test-results/**"],
      "cache": false
    }
  }
}
```

Run from the root:

```bash
# Generate and test a single app
npx turbo run e2e --filter=checkout

# Generate and test all apps in parallel
npx turbo run e2e
```

Turborepo caches `bddgen` output based on feature file and step file inputs — if neither changes, the generation step is skipped.

## Nx Task Sequencing

With Nx and `@nx/playwright`, configure `dependsOn` in `project.json`:

```json
{
  "targets": {
    "bddgen": {
      "command": "bddgen",
      "options": { "cwd": "{projectRoot}" }
    },
    "e2e": {
      "executor": "@nx/playwright:playwright",
      "dependsOn": ["bddgen"],
      "options": { "config": "{projectRoot}" }
    }
  }
}
```

Or set defaults for all projects in `nx.json`:

```json
{
  "targetDefaults": {
    "bddgen": {
      "command": "bddgen",
      "options": { "cwd": "{projectRoot}" }
    },
    "e2e": {
      "executor": "@nx/playwright:playwright",
      "dependsOn": ["bddgen"]
    }
  }
}
```

```bash
# Run a single app
npx nx e2e checkout

# Run all apps
npx nx run-many -t e2e -p checkout billing
```

## CI Pipeline Pattern

```yaml
# .github/workflows/e2e.yml
jobs:
  e2e:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        project: [checkout, billing]
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: 20 }
      - run: npm ci
      - run: npx playwright install --with-deps chromium
      - run: npx bddgen          # Generate .spec.ts from .feature
      - run: npx playwright test --project=${{ matrix.project }}
```

!!! tip "Generated files and CI"
    Commit `.gitignore` entries for `.features-gen/` if you generate at CI time. Alternatively, commit generated files and treat `bddgen` as a linter (fail CI if generated output differs from committed output). Both approaches work; the commit approach enables `git diff` reviews of generated test files in PRs.
