---
title: Named Test Data Catalog (Object Mother + Gherkin)
description: How to implement the Object Mother and Test Data Builder patterns in playwright-bdd using defineParameterType, creating a team-shared vocabulary of named canonical fixtures.
sources:
  - web-martinfowler-object-mother-content
  - web-taciomcosta-test-data-builder-content
  - web-given-bdd-seriously-object-mother-martin-fowler-s-object-mother-pattern-revisited
  - web-thegreenreport-custom-parameter-types-the-green-report-https-www-thegreenreport-blog
  - git-cucumber-expressions-readme-parameter-types
---

# Named Test Data Catalog (Object Mother + Gherkin)

The Named Test Data Catalog is the bridge between two classic testing patterns — Object Mother and Test Data Builder — and Gherkin's custom parameter types. The result is a vocabulary of well-known, team-familiar names that appear directly in `.feature` files and resolve to canonical fixture configurations at runtime.

## Object Mother (Fowler / Schuh, 2002)

An Object Mother is a factory that produces pre-configured test objects by name. Rather than constructing objects inline in every test, you ask the mother for a known variant:

```typescript
// Without Object Mother — construction details leak into tests
const user = { email: 'admin@example.com', role: 'admin', plan: 'pro', seatLimit: 50 };

// With Object Mother — named, canonical, team-familiar
const user = UserMother.admin();
const user = UserMother.guestOnFree();
```

The names (`admin`, `guestOnFree`) become part of team vocabulary. When a developer says "the Alice scenario," everyone knows what state that implies. The coupling risk is real: if `admin()` returns too many fields that scenarios don't care about, tests become brittle. Manage this by combining Object Mother with Test Data Builder.

## Test Data Builder (Freeman / Pryce, GOOS ch. 22)

A Test Data Builder wraps an Object Mother's defaults with fluent `With...()` methods that override individual fields. This separates "sensible defaults" (Mother) from "scenario-specific variation" (Builder):

```typescript
// Object Mother provides defaults; Builder adds variation
const user = UserMother.admin()
  .withEmail('custom@example.com')
  .withPlan('enterprise')
  .build();
```

The builder's value is encapsulation: when the `User` schema gains a new required field, only the Mother's default needs updating — not every test that creates users.

## Implementing as Gherkin Custom Parameter Types

In playwright-bdd, the Object Mother interface is expressed as a `defineParameterType`. The parameter type name appears in step text; the transformer function is the Mother — it returns a plain configuration object (no I/O).

```typescript
// parameters.ts — the vocabulary registry
import { defineParameterType } from 'playwright-bdd';

type OrgPlan = {
  plan: 'free' | 'pro' | 'enterprise';
  seatLimit: number;
  billingEnabled: boolean;
};

defineParameterType({
  name: 'org-plan',
  regexp: /free|pro|enterprise/,
  transformer(planName: string): OrgPlan {
    const catalog: Record<string, OrgPlan> = {
      free:       { plan: 'free',       seatLimit: 3,   billingEnabled: false },
      pro:        { plan: 'pro',        seatLimit: 25,  billingEnabled: true  },
      enterprise: { plan: 'enterprise', seatLimit: 500, billingEnabled: true  },
    };
    return catalog[planName];
  },
});
```

The Gherkin step uses `{org-plan}` as a token:

```gherkin
Feature: Plan enforcement

  Scenario: Pro plan enforces seat limit
    Given a pro organization
    When the admin invites a 26th member
    Then the invitation is rejected with "seat limit reached"

  Scenario: Enterprise organizations allow bulk invites
    Given an enterprise organization
    When the admin bulk-invites 100 members
    Then all invitations are accepted
```

The step definition receives the resolved `OrgPlan` object, not the raw string `"pro"`:

```typescript
// steps/org.steps.ts
import { createBdd } from 'playwright-bdd';
import { test } from '../fixtures';

const { Given } = createBdd(test);

Given('a {org-plan} organization', async ({ orgApi }, plan: OrgPlan) => {
  // plan is already { plan: 'pro', seatLimit: 25, billingEnabled: true }
  await orgApi.create(plan);
});
```

## Object Lifecycle: Transformer Must Be Pure

!!! warning "Critical constraint"
    The transformer function must be **pure, synchronous, and side-effect-free**. It returns a plain configuration object. It does not make HTTP calls, touch the database, or reference fixtures.

The split is intentional:

1. **Transformer** (pure): `"pro"` → `{ plan: 'pro', seatLimit: 25, ... }`
2. **Step or fixture** (effectful): takes the config, calls `orgApi.create(plan)`

This keeps the parameter type registry a simple data dictionary and makes it testable without a browser.

## Cross-Step Sharing via Fixture Reference

Created resources must flow between steps via fixtures, not module-level variables:

```typescript
// fixtures.ts — extend test with a mutable context object
export const test = base.extend<{ ctx: { orgId?: string } }>({
  ctx: async ({}, use) => {
    await use({});
  },
});

// steps/org.steps.ts
Given('a {org-plan} organization', async ({ orgApi, ctx }, plan: OrgPlan) => {
  const org = await orgApi.create(plan);
  ctx.orgId = org.id;           // store for later steps
});

When('the admin invites a 26th member', async ({ orgApi, ctx }) => {
  await orgApi.inviteMember(ctx.orgId!, { email: 'new@example.com' });
});
```

!!! warning "Anti-pattern: module-level state"
    `let currentOrgId: string;` at the top of a step file is shared mutable state. It causes interference between parallel workers and is impossible to clean up reliably. Always use fixture context.

## Base Fixture + Variation Table (Object Mother + Builder in One Step)

Combine the Object Mother base with a Data Table to override specific fields — the full Builder pattern in Gherkin:

```gherkin
Scenario: Custom plan configuration
  Given a pro organization with overrides:
    | seatLimit      | 10    |
    | billingEnabled | false |
  When a new member joins
  Then the join is rejected
```

```typescript
Given('a {org-plan} organization with overrides:', async ({ orgApi }, plan: OrgPlan, table) => {
  const overrides = table.rowsHash();
  const config = {
    ...plan,
    seatLimit: overrides.seatLimit ? parseInt(overrides.seatLimit) : plan.seatLimit,
    billingEnabled: overrides.billingEnabled === 'true',
  };
  await orgApi.create(config);
});
```

## The Vocabulary Registry (`parameters.ts`)

All `defineParameterType` calls live in a single `parameters.ts` file. This is the team's living glossary — every named resource the test suite knows about is registered here:

```
tests/
├── parameters.ts          # vocabulary registry — import once
├── fixtures.ts            # fixture extensions
└── steps/
    ├── auth.steps.ts
    ├── billing.steps.ts
    └── org.steps.ts
```

Import `parameters.ts` in your `playwright.config.ts` via the `require` or `import` option so it loads before any step files:

```typescript
// playwright.config.ts
export default defineConfig({
  ...defineBddConfig({
    importTestFrom: 'tests/fixtures.ts',
    require: ['tests/parameters.ts'],
  }),
});
```

## Durability Contract

When your domain schema changes — say, `seatLimit` becomes `maxMembers` — only the transformer in `parameters.ts` changes. Every feature file that uses `{org-plan}` continues to work without modification. This is the key maintainability benefit of the pattern.

!!! tip "RAG retrieval note"
    For AI agents: `{org-plan}`, `{user-role}`, and similar tokens in step patterns are Object Mother references implemented via `defineParameterType`. The transformer is the Mother; it returns a config struct. The step or fixture creates DB state from that struct.

## Related Pages

- [Custom Parameter Types](../reference/custom-parameter-types.md) — the full `defineParameterType` API reference
- [Test Data Strategy](test-data-strategy.md) — choosing between API, DB, and UI setup
- [Step Definition Design](step-definition-design.md) — thin translation layer principle
