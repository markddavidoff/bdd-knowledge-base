---
title: Domain Parameter Registry
description: Complete Object Mother + defineParameterType pattern in playwright-bdd — a central parameters.ts file that maps named domain resources to typed config objects consumed by fixtures and steps.
sources:
  - web-thegreenreport-custom-parameter-types-the-green-report-https-www-thegreenreport-blog
  - web-cucumber-js-api-defineparametertype-api-reference
  - git-playwright-bdd-repo-docs-writing-steps-playwright-style-custom-fixtures
---

# Domain Parameter Registry

The **domain parameter registry** combines two patterns:

- **Object Mother** (Fowler, 2002) — named canonical test objects with team-familiar names like `"admin"` or `"pro"`.
- **`defineParameterType`** — transforms those names directly in Gherkin step text into typed TypeScript objects.

The result: step text reads like domain vocabulary, and step code receives fully typed config objects — no string parsing, no switch statements scattered across step files.

## The pattern in one sentence

> A central `parameters.ts` file defines each domain concept as a named parameter type. The transformer returns a plain config object (no I/O). A fixture uses that config to create real DB state.

## parameters.ts — the central registry

```typescript
// features/support/parameters.ts
import { defineParameterType } from 'playwright-bdd';

// ─── User Role ─────────────────────────────────────────────────────────────

export interface UserRoleConfig {
  role: 'admin' | 'editor' | 'viewer';
  canManageUsers: boolean;
  canPublish: boolean;
  defaultDashboard: string;
}

const USER_ROLE_CATALOG: Record<string, UserRoleConfig> = {
  admin: {
    role: 'admin',
    canManageUsers: true,
    canPublish: true,
    defaultDashboard: '/admin',
  },
  editor: {
    role: 'editor',
    canManageUsers: false,
    canPublish: true,
    defaultDashboard: '/editor',
  },
  viewer: {
    role: 'viewer',
    canManageUsers: false,
    canPublish: false,
    defaultDashboard: '/home',
  },
};

defineParameterType({
  name: 'user-role',
  regexp: /admin|editor|viewer/,
  transformer(role: string): UserRoleConfig {
    const config = USER_ROLE_CATALOG[role];
    if (!config) throw new Error(`Unknown user role: "${role}"`);
    return config;
  },
});

// ─── Org Plan ──────────────────────────────────────────────────────────────

export interface OrgPlanConfig {
  plan: 'free' | 'pro' | 'enterprise';
  billingEnabled: boolean;
  seatLimit: number;
  features: string[];
}

const ORG_PLAN_CATALOG: Record<string, OrgPlanConfig> = {
  free: {
    plan: 'free',
    billingEnabled: false,
    seatLimit: 3,
    features: ['basic-reporting'],
  },
  pro: {
    plan: 'pro',
    billingEnabled: true,
    seatLimit: 25,
    features: ['basic-reporting', 'advanced-reporting', 'api-access'],
  },
  enterprise: {
    plan: 'enterprise',
    billingEnabled: true,
    seatLimit: Infinity,
    features: ['basic-reporting', 'advanced-reporting', 'api-access', 'sso', 'audit-log'],
  },
};

defineParameterType({
  name: 'org-plan',
  regexp: /free|pro|enterprise/,
  transformer(plan: string): OrgPlanConfig {
    const config = ORG_PLAN_CATALOG[plan];
    if (!config) throw new Error(`Unknown org plan: "${plan}"`);
    return config;
  },
});

// ─── Payment Method ─────────────────────────────────────────────────────────

export interface PaymentMethodConfig {
  type: 'card' | 'invoice' | 'bank-transfer';
  requiresCvv: boolean;
  supportsRefunds: boolean;
  processingDays: number;
}

const PAYMENT_METHOD_CATALOG: Record<string, PaymentMethodConfig> = {
  card: { type: 'card', requiresCvv: true, supportsRefunds: true, processingDays: 0 },
  invoice: { type: 'invoice', requiresCvv: false, supportsRefunds: false, processingDays: 30 },
  'bank-transfer': { type: 'bank-transfer', requiresCvv: false, supportsRefunds: true, processingDays: 3 },
};

defineParameterType({
  name: 'payment-method',
  regexp: /card|invoice|bank-transfer/,
  transformer(method: string): PaymentMethodConfig {
    const config = PAYMENT_METHOD_CATALOG[method];
    if (!config) throw new Error(`Unknown payment method: "${method}"`);
    return config;
  },
});
```

!!! note "Transformers must be pure"
    The transformer function must be synchronous and must not perform I/O (no DB calls, no HTTP requests). It returns a plain config object. The fixture or step creates actual DB state using that config.

## Feature file using named resources

```gherkin
Feature: Subscription management

  Scenario: Pro org can access the API
    Given an organization on the pro plan
    And an admin user in that organization
    When the admin accesses the API
    Then the response is successful

  Scenario: Free org cannot access the API
    Given an organization on the free plan
    And an editor user in that organization
    When the editor accesses the API
    Then the response is 403 Forbidden

  Scenario: Enterprise org can pay by invoice
    Given an organization on the enterprise plan
    When the organization sets up invoice payment
    Then the invoice payment method is active
    And there is a 30-day processing delay

  Scenario Outline: Role permissions
    Given a <role> user in any organization
    Then the user can publish content: <can-publish>

    Examples:
      | role    | can-publish |
      | admin   | true        |
      | editor  | true        |
      | viewer  | false       |
```

## fixtures.ts — wiring config to DB state

```typescript
// features/steps/fixtures.ts
import { test as base, createBdd } from 'playwright-bdd';
import type { OrgPlanConfig, UserRoleConfig } from '../support/parameters';
import { ApiClient } from '../support/api-client';

// Import parameters.ts to register the custom types BEFORE any step runs
import '../support/parameters';

type Fixtures = {
  api: ApiClient;
  currentOrg: { id: string; config: OrgPlanConfig } | null;
  currentUser: { id: string; config: UserRoleConfig } | null;
};

export const test = base.extend<Fixtures>({
  api: async ({ request }, use) => {
    await use(new ApiClient(request));
  },

  currentOrg: async ({}, use) => {
    await use(null);
  },

  currentUser: async ({}, use) => {
    await use(null);
  },
});

export const { Given, When, Then } = createBdd(test);
```

## Step definitions

```typescript
// features/steps/subscription.steps.ts
import { expect } from '@playwright/test';
import { Given, When, Then } from './fixtures';
import type { OrgPlanConfig, UserRoleConfig, PaymentMethodConfig } from '../support/parameters';

Given(
  'an organization on the {org-plan} plan',
  async ({ api, currentOrg }, planConfig: OrgPlanConfig) => {
    // The transformer has already resolved "pro" → OrgPlanConfig
    const org = await api.createOrg({
      plan: planConfig.plan,
      billingEnabled: planConfig.billingEnabled,
      seatLimit: planConfig.seatLimit,
    });
    // Store for use in subsequent steps
    (currentOrg as any) = { id: org.id, config: planConfig };
  }
);

Given(
  'an {user-role} user in that organization',
  async ({ api, currentOrg, currentUser }, roleConfig: UserRoleConfig) => {
    const user = await api.createUser({
      orgId: currentOrg!.id,
      role: roleConfig.role,
      email: `${roleConfig.role}@example.com`,
    });
    (currentUser as any) = { id: user.id, config: roleConfig };
  }
);

When('the admin accesses the API', async ({ api, currentUser }) => {
  // step impl
});

Then('the response is successful', async ({ api }) => {
  // assertion
});

Then('the response is 403 Forbidden', async ({ api }) => {
  // assertion
});

When(
  'the organization sets up {payment-method} payment',
  async ({ api, currentOrg }, pmConfig: PaymentMethodConfig) => {
    await api.setPaymentMethod(currentOrg!.id, pmConfig.type);
  }
);

Then('the invoice payment method is active', async ({ api, currentOrg }) => {
  const billing = await api.getBilling(currentOrg!.id);
  expect(billing.method).toBe('invoice');
});

Then('there is a {int}-day processing delay', async ({ api, currentOrg }, days: number) => {
  const billing = await api.getBilling(currentOrg!.id);
  expect(billing.processingDays).toBe(days);
});

Given(
  'a {user-role} user in any organization',
  async ({ api }, roleConfig: UserRoleConfig) => {
    // create minimal org + user for the outline row
  }
);

Then(
  'the user can publish content: {word}',
  async ({ currentUser }, canPublishStr: string) => {
    const expected = canPublishStr === 'true';
    expect(currentUser?.config.canPublish).toBe(expected);
  }
);
```

## Base fixture + Data Table variation

For one-off scenario variation, combine the Object Mother base with a Data Table override:

```gherkin
Scenario: Pro org with custom seat limit
  Given an organization on the pro plan
    | seatLimit | 10 |
  Then the org has a seat limit of 10
```

```typescript
import type { DataTable } from '@playwright/test';

Given(
  'an organization on the {org-plan} plan',
  async ({ api }, planConfig: OrgPlanConfig, table?: DataTable) => {
    // Merge base config with any table overrides
    const overrides = table ? table.rowsHash() : {};
    const merged = {
      ...planConfig,
      ...Object.fromEntries(
        Object.entries(overrides).map(([k, v]) => [k, isNaN(Number(v)) ? v : Number(v)])
      ),
    };
    const org = await api.createOrg(merged);
  }
);
```

!!! tip "parameters.ts as living glossary"
    The registry is the team's canonical vocabulary. When a domain concept is renamed or restructured, you update the catalog object and the transformer in one place. Feature files and step definitions remain untouched.

## Related

- [Custom Parameter Types reference](../../gherkin/reference/custom-parameter-types.md)
- [Named Resources — pure Gherkin examples](../../gherkin/examples/named-resources.md)
- [Data Tables reference](../../gherkin/reference/data-tables.md)
