---
title: Configuration
description: Complete reference for defineBddConfig() options — features, steps, featuresRoot, outputDir, missingSteps, and multiple-project setups.
sources:
  - git-playwright-bdd-repo-docs-configuration-index-index
  - git-playwright-bdd-repo-docs-configuration-options-features
  - git-playwright-bdd-repo-docs-configuration-options-steps
  - git-playwright-bdd-repo-docs-configuration-options-featuresroot
  - git-playwright-bdd-repo-docs-configuration-options-outputdir
  - git-playwright-bdd-repo-docs-configuration-options-importtestfrom
  - git-playwright-bdd-repo-docs-configuration-options-missingsteps
  - git-playwright-bdd-repo-docs-configuration-multiple-projects-multiple-projects
  - git-playwright-bdd-repo-docs-configuration-multiple-projects-different-feature-files
  - git-playwright-bdd-repo-docs-configuration-multiple-projects-shared-feature-files
  - git-playwright-bdd-repo-docs-guides-ignore-generated-files-ignore-generated-files
  - git-playwright-bdd-repo-docs-blog-whats-new-in-v8-improved-configuration-options
---

# Configuration

playwright-bdd is configured inside `playwright.config.ts` using `defineBddConfig()`. The function validates your options, registers the BDD configuration, and returns the path to the `outputDir` where generated `.spec.ts` files will be written. You pass this return value as Playwright's `testDir`.

```ts
// playwright.config.ts
import { defineConfig } from '@playwright/test';
import { defineBddConfig } from 'playwright-bdd';

const testDir = defineBddConfig({
  features: 'features/**/*.feature',
  steps: 'steps/**/*.ts',
});

export default defineConfig({
  testDir,
});
```

All relative paths in `defineBddConfig()` are resolved from the directory containing `playwright.config.ts`.

---

## Core Options

### `features`

- **Type:** `string | string[]`
- **Default:** `undefined` (derived from `featuresRoot` when set)

Glob pattern(s) pointing to your `.feature` files.

```ts
features: 'features/**/*.feature'
// or an array:
features: ['features/auth/**/*.feature', 'features/checkout/**/*.feature']
```

If you omit the file extension, playwright-bdd defaults to `*.feature`.

### `steps`

- **Type:** `string | string[]`
- **Default:** `undefined` (derived from `featuresRoot` when set)

Glob pattern(s) pointing to step definition files.

```ts
steps: 'features/steps/**/*.ts'
```

Accepts `*.{js,mjs,cjs,ts,mts,cts}` when no extension is specified.

### `featuresRoot` (v8+, recommended)

- **Type:** `string`
- **Default:** config file directory

A single base directory that serves as the root for both `features` and `steps`. Using `featuresRoot` alone is the most concise configuration for projects that co-locate features and steps:

```ts
// Before v8:
const testDir = defineBddConfig({
  features: './features/**/*.feature',
  steps: './features/steps/**/*.js',
  featuresRoot: './features',
});

// Since v8 — equivalent, shorter:
const testDir = defineBddConfig({
  featuresRoot: './features',
});
```

`featuresRoot` also controls how the generated output path is constructed — it strips the root prefix from the source path, so `features/auth/login.feature` becomes `.features-gen/auth/login.feature.spec.ts` (not `.features-gen/features/auth/login.feature.spec.ts`).

### `outputDir`

- **Type:** `string`
- **Default:** `.features-gen`

Directory where playwright-bdd writes generated `.spec.ts` files. Rarely needs changing unless you have multiple BDD projects and need separate output directories.

### `importTestFrom`

- **Type:** `string`
- **Default:** auto-detected from step definitions (since v7)

Path to the file that exports your custom `test` instance. Since v7, playwright-bdd auto-detects this from the `createBdd(test)` call in your step files, so you usually don't need to set it manually.

---

## Behavior Options

### `missingSteps` (v8+)

- **Type:** `'fail-on-gen' | 'fail-on-run' | 'skip-scenario'`
- **Default:** `'fail-on-gen'`

Controls what happens when `bddgen` encounters a step with no matching step definition:

| Value | Behavior |
|-------|----------|
| `fail-on-gen` | Generation fails immediately, prints code snippets for missing steps |
| `fail-on-run` | Generation succeeds, test run fails when the missing step is reached |
| `skip-scenario` | Generation succeeds, scenario is marked `fixme` and skipped |

!!! tip "Use `fail-on-gen` in CI"
    The default (`fail-on-gen`) is the strictest and safest for CI — a missing step breaks the build before any tests run.

### `matchKeywords` (v8+)

- **Type:** `boolean`
- **Default:** `false`

When `false` (default), a step definition registered with `Given` matches `Given`, `When`, and `Then` in feature files. When `true`, keywords are matched strictly.

---

## Multiple Playwright Projects

### Shared Feature Files (same features, multiple browsers)

When all projects run the same feature files — e.g., running in Chromium, Firefox, and WebKit — define one `testDir` at the root level:

```ts
import { defineConfig, devices } from '@playwright/test';
import { defineBddConfig } from 'playwright-bdd';

const testDir = defineBddConfig({
  features: 'features/**/*.feature',
  steps: 'steps/**/*.ts',
});

export default defineConfig({
  testDir,
  projects: [
    { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
    { name: 'firefox', use: { ...devices['Desktop Firefox'] } },
    { name: 'webkit', use: { ...devices['Desktop Safari'] } },
  ],
});
```

### Different Feature Files per Project

When projects have distinct feature sets, each project needs its own `testDir` and a unique `outputDir` to avoid conflicts:

```ts
import { defineConfig } from '@playwright/test';
import { defineBddProject } from 'playwright-bdd';

export default defineConfig({
  projects: [
    {
      ...defineBddProject({
        name: 'admin',
        features: 'features/admin/**/*.feature',
        steps: 'features/admin/steps/**/*.ts',
      }),
    },
    {
      ...defineBddProject({
        name: 'customer',
        features: 'features/customer/**/*.feature',
        steps: 'features/customer/steps/**/*.ts',
      }),
    },
  ],
});
```

`defineBddProject()` is a helper that sets `outputDir` automatically based on the project name (`.features-gen/<name>`), and returns `{ name, testDir }` ready for spread into the project config.

!!! warning "Each project must have a unique `outputDir`"
    Multiple BDD projects sharing the same `outputDir` will overwrite each other's generated files. `defineBddProject()` handles this automatically; if you use `defineBddConfig()` directly, set `outputDir` explicitly for each project.

---

## Generated Files — Commit or Ignore?

Two strategies exist:

**Option A — Add to `.gitignore` (default advice)**

```gitignore
**/.features-gen/**/*.spec.ts
```

This keeps the repo clean. CI must run `npx bddgen` before `npx playwright test`.

**Option B — Commit generated files**

Committing `.features-gen/` means CI skips the generation step and runs `npx playwright test` directly. This is useful when generation is slow or when you want diffs of generated files visible in PRs.

!!! tip "Recommended: commit generated files"
    Committing the generated files makes CI simpler (one command instead of two) and makes it trivially obvious when a feature file change produces no generated-file diff — a potential sign that `bddgen` wasn't re-run.

If you commit generated files, note that Playwright stores visual comparison snapshots next to the `.spec.ts` files by default. You may want to relocate snapshots to keep them out of `.features-gen/`:

```ts
export default defineConfig({
  snapshotPathTemplate:
    '__snapshots__/{testFileDir}/{testFileName}-snapshots/{arg}{-projectName}{ext}',
});
```

---

## See Also

- [Installation](installation.md) — full setup walkthrough
- [TypeScript Configuration](typescript-config.md) — ESM, `tsconfig.json`, and type safety
- [Scoped Steps](scoped-steps.md) — directory-based step scoping across multiple projects
