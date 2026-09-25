---
title: TypeScript Configuration
description: How to configure TypeScript for playwright-bdd — ESM vs CJS, tsconfig.json settings, and the createBdd<Fixtures>() type parameter pattern.
sources:
  - git-playwright-bdd-repo-docs-configuration-esm-esm
  - git-playwright-bdd-repo-docs-getting-started-add-fixtures-add-fixtures
  - git-playwright-bdd-repo-docs-faq-faq
  - git-playwright-bdd-repo-docs-configuration-index-index
  - git-playwright-bdd-repo-docs-writing-steps-bdd-fixtures-bdd-fixtures
---

# TypeScript Configuration

TypeScript configuration is the **single most common source of new-project failures** with playwright-bdd. The root cause is almost always an ESM/CJS mismatch — the wrong module format causes `bddgen` or `playwright test` to fail with cryptic import errors before a single step runs.

This page explains the two module modes, when to use each, and provides a minimum-viable configuration for both.

---

## ESM vs. CJS — Which Do You Have?

Your project is running **ESM** if either of these is true:

- `package.json` contains `"type": "module"`
- `tsconfig.json` has `"module": "ESNext"` or `"module": "NodeNext"`

Your project is running **CJS** if neither condition is true (the Node.js default).

!!! warning "The #1 new-project failure mode"
    Mixing ESM and CJS — for example, `"type": "module"` in `package.json` but `"module": "CommonJS"` in `tsconfig.json`, or vice versa — produces errors like `SyntaxError: Cannot use import statement in a module` or `ERR_REQUIRE_ESM`. Fix the mismatch first before debugging any playwright-bdd error.

---

## CJS Configuration (Simpler, Recommended for New Projects)

If you do not have `"type": "module"` in your `package.json`, use CJS. This is the path of least resistance:

**`tsconfig.json`:**

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "CommonJS",
    "moduleResolution": "Node",
    "strict": true,
    "esModuleInterop": true,
    "experimentalDecorators": true,
    "emitDecoratorMetadata": false,
    "outDir": "dist",
    "rootDir": "."
  },
  "include": ["**/*.ts"],
  "exclude": ["node_modules", ".features-gen"]
}
```

**`playwright.config.ts`:**

```ts
import { defineConfig } from '@playwright/test';
import { defineBddConfig } from 'playwright-bdd';

const testDir = defineBddConfig({
  featuresRoot: './features',
});

export default defineConfig({
  testDir,
});
```

No special `require`/`loader` configuration needed. Run with:

```bash
npx bddgen && npx playwright test
```

---

## ESM Configuration

Use ESM if your project or dependencies require it. Since playwright-bdd v7 and Playwright v1.41, ESM works with the standard run command.

**`package.json`:**

```json
{
  "type": "module",
  "devDependencies": {
    "@playwright/test": "^1.41.0",
    "playwright-bdd": "^8.0.0"
  }
}
```

**`tsconfig.json`:**

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "NodeNext",
    "moduleResolution": "NodeNext",
    "strict": true,
    "esModuleInterop": true,
    "experimentalDecorators": true,
    "emitDecoratorMetadata": false
  },
  "include": ["**/*.ts"],
  "exclude": ["node_modules", ".features-gen"]
}
```

!!! warning "ESM import extensions"
    With `module: NodeNext`, TypeScript requires explicit `.js` extensions on relative imports — even when the source file is `.ts`. This is the Node.js ESM resolution contract:

    ```ts
    // CORRECT in ESM (NodeNext):
    import { Given } from './fixtures.js';

    // WRONG — will fail at runtime:
    import { Given } from './fixtures';
    ```

    This is counterintuitive but required. Your editor shows `.ts` files, but Node.js resolves extensions literally against compiled `.js` output.

---

## The `createBdd<Fixtures>()` Type Parameter

`createBdd()` returns typed `Given`, `When`, `Then` step registrars. When you pass a custom `test` instance (created with `test.extend<T>()`), TypeScript enforces that every fixture used in a step is declared in the fixture type.

### Minimal Pattern

```ts
// fixtures.ts
import { test as base, createBdd } from 'playwright-bdd';

interface MyFixtures {
  apiClient: ApiClient;
  authToken: string;
}

export const test = base.extend<MyFixtures>({
  apiClient: async ({}, use) => {
    const client = new ApiClient();
    await use(client);
    await client.dispose();
  },
  authToken: async ({ apiClient }, use) => {
    const token = await apiClient.getToken();
    await use(token);
  },
});

export const { Given, When, Then } = createBdd(test);
```

```ts
// steps/api.steps.ts
import { Given, When, Then } from '../fixtures.js';

// TypeScript knows { apiClient } is available because it's in MyFixtures:
Given('the API client is ready', async ({ apiClient }) => {
  await apiClient.connect();
});

// TypeScript error if you request a fixture not in MyFixtures:
Given('bad step', async ({ nonExistentFixture }) => { // <- compile error
  // ...
});
```

The type parameter on `test.extend<MyFixtures>()` is what makes this work. Every fixture requested in a step must appear in the interface. If it does not, you get a compile-time error rather than a runtime failure.

### Why This Matters

Without the type parameter, you learn about a missing fixture only when the test runs. With it, the TypeScript compiler catches the problem immediately:

```
Type error: Argument of type '{ nonExistentFixture: Foo }' is not assignable
  to parameter of type 'Fixtures & BddFixtures'.
```

---

## Type Inference on Step Parameters

Cucumber Expressions (`{string}`, `{int}`, `{float}`) are automatically typed in step function signatures:

```ts
// {string} -> string, {int} -> number
When('I set quantity to {int} for item {string}', async ({ page }, qty: number, name: string) => {
  // qty is typed as number, name as string — no manual casting needed
});
```

Custom parameter types defined with `defineParameterType` carry their transformer's return type into steps as well, giving you end-to-end type safety from Gherkin parameter to TypeScript variable.

---

## Decorator Style and `experimentalDecorators`

If you use the [Decorator step style](writing-steps.md#style-3-decorator-style-pom-integration), you need:

```json
{
  "compilerOptions": {
    "experimentalDecorators": true
  }
}
```

playwright-bdd uses TypeScript 5 decorators (`@Fixture`, `@Given`, `@When`, `@Then`), which require this flag. `emitDecoratorMetadata` is **not** required by playwright-bdd decorators.

---

## Full Working Example (ESM)

```ts
// playwright.config.ts
import { defineConfig } from '@playwright/test';
import { defineBddConfig } from 'playwright-bdd';

const testDir = defineBddConfig({
  featuresRoot: './features',
});

export default defineConfig({
  testDir,
  use: {
    baseURL: 'https://example.com',
    screenshot: 'only-on-failure',
    trace: 'retain-on-failure',
  },
});
```

```json
// tsconfig.json (ESM)
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "NodeNext",
    "moduleResolution": "NodeNext",
    "strict": true,
    "esModuleInterop": true,
    "experimentalDecorators": true
  },
  "include": ["**/*.ts"],
  "exclude": ["node_modules", ".features-gen"]
}
```

```json
// package.json (ESM)
{
  "type": "module",
  "scripts": {
    "test": "bddgen && playwright test"
  }
}
```

---

## Troubleshooting Checklist

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| `SyntaxError: Cannot use import statement` | CJS module receiving ESM output | Add `"type": "module"` or switch to `"module": "CommonJS"` |
| `ERR_REQUIRE_ESM` | CommonJS `require()` of an ESM-only package | Add `"type": "module"` to `package.json` |
| Missing `.js` extension errors | ESM with NodeNext but no `.js` on imports | Add `.js` extension to all relative imports |
| `createBdd()` fixture type error | Fixture not declared in `test.extend<T>()` | Add fixture to the interface passed to `test.extend<T>()` |
| Decorator errors at compile time | Missing `experimentalDecorators: true` | Add flag to `tsconfig.json` |
