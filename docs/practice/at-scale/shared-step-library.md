---
title: Shared Step Library as an npm Package
description: When and how to extract playwright-bdd step definitions into a versioned internal npm package — package structure, API stability, semver, and consumer import patterns.
sources:
  - git-playwright-bdd-repo-docs-writing-steps-playwright-style-custom-fixtures
  - git-playwright-bdd-repo-docs-writing-steps-reusing-step-fn-reusing-step-fn
  - git-playwright-bdd-repo-docs-writing-steps-scoped-scoped
---

# Shared Step Library as an npm Package

When three or more teams write feature files that share vocabulary and automation steps, copying step definitions between repos becomes untenable. The solution is to extract shared steps into a versioned npm package published to an internal registry.

## When to Extract

Extraction adds overhead (versioning, publishing, changelog, consumer upgrade cycles). Apply these thresholds before deciding:

- **3+ teams** consume the same step text (e.g., `Given Alice has a {user-role} account`)
- **200+ scenarios** depend on the shared step — breakage at this scale blocks everyone
- **The step vocabulary is stable**: volatile steps belong in team repos until they settle
- **Step text has become a de-facto public API** that other teams test against

Do not extract too early. Premature extraction freezes a vocabulary that is still evolving.

## Package Structure

```
@acme/bdd-steps/
  package.json
  tsconfig.json
  src/
    steps/
      auth.steps.ts       # Authentication steps
      navigation.steps.ts # Common navigation steps
      index.ts            # Barrel export
    parameters/
      index.ts            # All defineParameterType calls
      org-plan.ts
      user-role.ts
    fixtures/
      index.ts            # Shared test fixtures
      api-client.ts
  dist/                   # Compiled output
```

The three exported modules have distinct roles:

- **`steps/`**: Step definitions using `createBdd()`. These are the public API.
- **`parameters/`**: `defineParameterType` registrations. Must be loaded before steps.
- **`fixtures/`**: Playwright `test.extend` calls that consumer `fixtures.ts` files compose from.

## Package Contents

### fixtures/api-client.ts

```typescript
// @acme/bdd-steps/src/fixtures/api-client.ts
import { test as base } from 'playwright-bdd';
import { ApiClient } from '@acme/api-client';

export type SharedFixtures = {
  apiClient: ApiClient;
};

export const test = base.extend<SharedFixtures>({
  apiClient: async ({ request }, use) => {
    const client = new ApiClient({ request, baseURL: process.env.API_URL! });
    await use(client);
    await client.cleanup();
  },
});
```

### parameters/org-plan.ts

```typescript
// @acme/bdd-steps/src/parameters/org-plan.ts
import { defineParameterType } from 'playwright-bdd';

export type OrgPlan = {
  name: 'free' | 'pro' | 'enterprise';
  billingEnabled: boolean;
  seatLimit: number;
};

defineParameterType({
  name: 'org-plan',
  regexp: /free|pro|enterprise/,
  transformer(planName: string): OrgPlan {
    const plans: Record<string, OrgPlan> = {
      free:       { name: 'free',       billingEnabled: false, seatLimit: 5 },
      pro:        { name: 'pro',        billingEnabled: true,  seatLimit: 50 },
      enterprise: { name: 'enterprise', billingEnabled: true,  seatLimit: 9999 },
    };
    return plans[planName];
  },
});
```

### steps/auth.steps.ts

```typescript
// @acme/bdd-steps/src/steps/auth.steps.ts
import { createBdd } from 'playwright-bdd';
import { test } from '../fixtures';

const { Given, When, Then } = createBdd(test);

Given('Alice has a {user-role} account', async ({ apiClient }, role: UserRole) => {
  await apiClient.users.create({ email: 'alice@example.com', role });
});

Given('Alice is logged in', async ({ page, apiClient }) => {
  const token = await apiClient.auth.login('alice@example.com');
  await page.evaluate((t) => localStorage.setItem('token', t), token);
});
```

## Versioning and API Stability

Step text is the public API. Treat it with semver discipline:

| Change | Semver bump |
|--------|------------|
| Adding a new step | Patch (non-breaking for existing consumers) |
| Adding a new parameter type | Minor |
| Changing step text (rename) | **Major** — breaks all feature files using the old text |
| Changing parameter type regexp (wider) | Minor |
| Changing parameter type regexp (narrower — may break) | **Major** |
| Changing transformer return shape | **Major** |

Maintain a `CHANGELOG.md` that lists step text changes explicitly, not just code diffs.

## Publishing to an Internal Registry

```json
// package.json
{
  "name": "@acme/bdd-steps",
  "version": "2.4.1",
  "main": "dist/index.js",
  "types": "dist/index.d.ts",
  "files": ["dist/", "src/"],
  "publishConfig": {
    "registry": "https://registry.acme.internal"
  }
}
```

Options for hosting:
- **Verdaccio**: Self-hosted npm registry, zero cost, easy to run in Docker
- **GitHub Packages**: Integrated with GitHub Actions; requires `--registry` flag or `.npmrc`
- **Artifactory / Nexus**: Enterprise artifact management, LDAP integration

## Consumer Import Pattern

In consumer repos, install the package and compose fixtures:

```typescript
// apps/billing/e2e/fixtures.ts
import { test as sharedTest, SharedFixtures } from '@acme/bdd-steps/fixtures';
import { test as base } from 'playwright-bdd';

type BillingFixtures = {
  billingPage: BillingPage;
};

// Compose: shared fixtures + billing-specific fixtures
export const test = sharedTest.extend<BillingFixtures>({
  billingPage: async ({ page }, use) => {
    await use(new BillingPage(page));
  },
});

export const { Given, When, Then } = createBdd(test);
```

Import shared steps in playwright.config.ts:

```typescript
// apps/billing/playwright.config.ts
import { defineBddConfig } from 'playwright-bdd';

export default defineConfig({
  testDir: defineBddConfig({
    features: 'e2e/features/**/*.feature',
    steps: [
      '@acme/bdd-steps/steps',  // Shared steps from package
      'e2e/steps/**/*.ts',       // Billing-specific steps
    ],
    import: ['@acme/bdd-steps/parameters'], // Load parameter types first
  }),
});
```

## The Heavy Coupling Risk

Shared step libraries are a double-edged sword. Every team that imports the package is now **tightly coupled** to its vocabulary and fixtures. A major version bump requires coordinated upgrades across all consumers.

Mitigate this:
- Keep the shared library surface area small — only steps that are genuinely cross-team
- Prefer team-owned steps that call shared **helper functions** over shared steps directly
- Design step text to be durable — avoid baking in implementation details

!!! warning "Vocabulary freeze"
    Once a step text is in a shared package with active consumers, changing it is a coordinated multi-team effort. Design step text carefully before publishing. When in doubt, keep the step in the team repo until the vocabulary has stabilized across at least two independent feature files.
