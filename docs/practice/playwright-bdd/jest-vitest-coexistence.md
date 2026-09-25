---
title: Jest/Vitest Coexistence
description: Run playwright-bdd BDD tests alongside existing Jest or Vitest unit tests in the same repo without module resolution conflicts.
sources:
  - git-playwright-bdd-repo-docs-configuration-index-index
  - git-playwright-bdd-repo-docs-configuration-options-steps
  - git-playwright-bdd-repo-docs-configuration-options-features
---

# Jest/Vitest Coexistence

The brownfield reality: most projects already have Jest or Vitest unit tests when they add playwright-bdd. These test frameworks overlap on glob patterns, TypeScript config, and script naming. This page shows how to isolate them cleanly so they coexist without interfering.

---

## The Problem

Jest, Vitest, and Playwright all have opinions about:

- Which files are test files (glob patterns)
- Which `tsconfig.json` to use
- How to handle ESM vs. CommonJS
- What test runner collects and executes tests

Without explicit separation, Playwright may try to run unit test files as E2E tests, or Jest may try to `require` Playwright step definitions and fail on the browser APIs.

---

## Separate TypeScript Configs

Create a TypeScript config for each test framework so each gets the correct `lib`, `types`, and `module` settings:

```json
// tsconfig.jest.json
{
  "extends": "./tsconfig.json",
  "compilerOptions": {
    "types": ["jest", "node"],
    "module": "commonjs",
    "moduleResolution": "node"
  },
  "include": ["src/**/*.ts", "src/**/*.test.ts"]
}
```

```json
// tsconfig.playwright.json
{
  "extends": "./tsconfig.json",
  "compilerOptions": {
    "types": ["node"],
    "module": "ESNext",
    "moduleResolution": "bundler"
  },
  "include": ["features/**/*.ts", "features/**/*.feature"]
}
```

```json
// jest.config.ts
export default {
  preset: 'ts-jest',
  globals: {
    'ts-jest': { tsconfig: 'tsconfig.jest.json' },
  },
  testMatch: ['<rootDir>/src/**/*.test.ts'],  // unit tests only
};
```

```ts
// playwright.config.ts
import { defineConfig } from '@playwright/test';
import { defineBddConfig } from 'playwright-bdd';

const testDir = defineBddConfig({
  features: 'features/**/*.feature',
  steps: 'features/steps/**/*.ts',
});

export default defineConfig({
  testDir,
  // Playwright only picks up files in testDir (.features-gen/)
});
```

!!! tip "Vitest config is equivalent"
    Replace `jest.config.ts` with `vitest.config.ts` using the same glob isolation. Vitest supports `include` patterns in `test.include`.

---

## Separate Test Globs

The critical rule: **no glob pattern should match files from both frameworks**.

| Framework | Glob | Example file |
|-----------|------|--------------|
| Jest/Vitest | `src/**/*.test.ts` | `src/services/cart.test.ts` |
| playwright-bdd | `features/**/*.feature` | `features/checkout.feature` |
| playwright-bdd steps | `features/steps/**/*.ts` | `features/steps/checkout.steps.ts` |
| Generated (playwright-bdd) | `.features-gen/**/*.spec.ts` | `.features-gen/checkout.spec.ts` |

By convention, keep all BDD assets under `features/` and all unit/integration test assets under `src/`:

```
my-project/
├── src/
│   ├── services/
│   │   ├── cart.ts
│   │   └── cart.test.ts          ← Jest/Vitest
├── features/
│   ├── checkout.feature           ← playwright-bdd
│   └── steps/
│       └── checkout.steps.ts      ← playwright-bdd step defs
└── .features-gen/                 ← generated, gitignored
    └── checkout.spec.ts
```

---

## Separate npm Scripts

Define distinct scripts so each runner is invoked independently:

```json
{
  "scripts": {
    "test:unit": "jest",
    "test:unit:watch": "jest --watch",
    "test:bdd": "npx bddgen && npx playwright test",
    "test:bdd:headed": "npx bddgen && npx playwright test --headed",
    "test": "npm run test:unit && npm run test:bdd"
  }
}
```

In CI, you may want to run these in parallel:

```yaml
jobs:
  unit-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm ci
      - run: npm run test:unit

  bdd-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm ci
      - run: npx playwright install --with-deps
      - run: npm run test:bdd
```

---

## Avoiding Module Resolution Conflicts

### Problem: Playwright types bleed into unit test files

If your root `tsconfig.json` includes `"types": ["@playwright/test"]`, Jest may load Playwright type definitions and conflict with Jest's own globals (`describe`, `it`, `expect`).

**Fix:** Move `@playwright/test` types to `tsconfig.playwright.json` only. Keep the root `tsconfig.json` type-free or limited to `"node"`.

### Problem: Step definition files imported by Jest

If Jest's `testMatch` accidentally includes `features/steps/**/*.ts`, it will try to run step files as tests and fail.

**Fix:** Use an explicit `testPathIgnorePatterns`:

```ts
// jest.config.ts
export default {
  testMatch: ['<rootDir>/src/**/*.test.ts'],
  testPathIgnorePatterns: ['/node_modules/', '/features/'],
};
```

### Problem: ESM step definitions fail in Jest (CommonJS)

playwright-bdd step files use ESM imports. Jest in CommonJS mode cannot import them.

**Fix:** Keep the two worlds separate — do not import step definition files from unit tests. If you need shared utilities, extract them into a neutral `src/test-utils/` directory that both can import.

---

## Monorepo Configuration

In a monorepo, scope each tool to its workspace:

```
packages/
├── web/
│   ├── src/           ← Vitest unit tests
│   ├── features/      ← playwright-bdd BDD tests
│   └── playwright.config.ts
├── api/
│   ├── src/           ← Jest unit tests
│   └── jest.config.ts
└── package.json       ← workspace root scripts
```

```json
// package.json (root)
{
  "scripts": {
    "test:unit": "turbo run test:unit",
    "test:bdd": "turbo run test:bdd"
  }
}
```

Each package defines its own `test:unit` or `test:bdd` script. Turborepo (or nx) runs them in dependency order.

!!! warning "Shared tsconfig in monorepos"
    If packages extend a shared `tsconfig.base.json`, be careful not to add `@playwright/test` types to the base config — it will bleed into packages that run under Jest.

---

## Checklist

- [ ] `tsconfig.jest.json` and `tsconfig.playwright.json` both extend the root but set their own `types` and `module`
- [ ] Jest `testMatch` only includes `src/**/*.test.ts` (not `features/`)
- [ ] Playwright `testDir` points to `.features-gen/` (generated by `bddgen`)
- [ ] `.features-gen/` is in `.gitignore`
- [ ] No shared glob pattern between Jest and Playwright
- [ ] `npm run test:unit` and `npm run test:bdd` are separate scripts
