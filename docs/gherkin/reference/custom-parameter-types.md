---
title: Custom Parameter Types
description: Define domain-specific parameter types with defineParameterType to transform step arguments into rich TypeScript objects and build a team vocabulary registry.
sources:
  - web-thegreenreport-custom-parameter-types-the-green-report-https-www-thegreenreport-blog
  - web-cucumber-js-api-defineparametertype-api-reference
  - git-cucumber-expressions-readme-parameter-types
  - issue-playwright-bdd-issues-112
---

# Custom Parameter Types

Custom parameter types extend Cucumber Expressions with domain-specific tokens. Instead of extracting a raw string with `{string}`, you define a named type that matches a pattern and hands a typed object to the step definition. This is the primary mechanism for building a team vocabulary registry and encoding the ubiquitous language into your step definitions.

## The `defineParameterType` API

```typescript
import { defineParameterType } from 'playwright-bdd'; // or '@cucumber/cucumber'

defineParameterType({
  name: 'org-plan',
  regexp: /free|pro|enterprise/,
  transformer(value: string): OrgPlan {
    const plans: Record<string, OrgPlan> = {
      free:       { plan: 'free',       billingEnabled: false, seatLimit: 5  },
      pro:        { plan: 'pro',        billingEnabled: true,  seatLimit: 50 },
      enterprise: { plan: 'enterprise', billingEnabled: true,  seatLimit: Infinity },
    };
    return plans[value];
  },
  useForSnippets: false,      // don't flood snippet suggestions
  preferForRegexpMatch: false, // default; set true to win ambiguous regexp matches
});
```

### Field reference

| Field | Default | Purpose |
|---|---|---|
| `name` | required | Token used in curly-brace syntax: `{org-plan}` |
| `regexp` | required | One `RegExp`, a pattern string, or an array of `RegExp` |
| `transformer` | identity (string passthrough) | Sync or async function; return value is passed to the step |
| `useForSnippets` | `true` | If `false`, this type won't appear in auto-generated step snippets |
| `preferForRegexpMatch` | `false` | If `true`, wins ambiguous matches against plain regexp patterns |

!!! warning "Arrow functions and `this`"
    In `@cucumber/cucumber`, `this` inside a transformer refers to the World object — but only when using a regular `function`, not an arrow function. In playwright-bdd the transformer has no access to fixtures; keep it pure and synchronous.

## Built-in types and their limits

Cucumber ships four built-in parameter types:

- `{int}` — integer (no float, no hex)
- `{float}` — floating-point number
- `{string}` — single- or double-quoted string; quotes stripped
- `{word}` — a single whitespace-free token

These cover simple scalar values but have no concept of your domain. When a step needs to convey domain meaning — a subscription tier, a user role, a named configuration — define a custom type.

## Enum / constrained parameters

Constrained parameters match only a closed set of values. Validation is free because an unrecognised value simply won't match the regexp, failing the step with a "no matching step" error rather than a runtime crash.

```typescript
// {user-role} matching admin|user|guest
defineParameterType({
  name: 'user-role',
  regexp: /admin|user|guest/,
  transformer: (role: string) => role as UserRole,
  useForSnippets: true,
});
```

```gherkin
Given Alice is logged in as admin
When she visits the admin dashboard
Then she sees the user management panel
```

## Domain object transformers

A transformer can return any type — the step definition receives the fully constructed object:

```typescript
interface OrgPlan {
  plan: string;
  billingEnabled: boolean;
  seatLimit: number;
}

defineParameterType({
  name: 'org-plan',
  regexp: /free|pro|enterprise/,
  transformer(tier: string): OrgPlan {
    return {
      free:       { plan: 'free',       billingEnabled: false, seatLimit: 5        },
      pro:        { plan: 'pro',        billingEnabled: true,  seatLimit: 50       },
      enterprise: { plan: 'enterprise', billingEnabled: true,  seatLimit: Infinity },
    }[tier]!;
  },
});
```

The step definition then works with the typed object directly:

```typescript
const { Given, When, Then } = createBdd(test);

Given('the organization is on the {org-plan} plan', async ({ db }, plan: OrgPlan) => {
  await db.organizations.seed({ plan: plan.plan, billing: plan.billingEnabled });
});
```

!!! tip "Transformer must stay pure"
    The transformer runs before fixtures are injected. Do not perform async I/O (database writes, API calls) inside a transformer. Return a plain config object; let the step definition or fixture do the I/O using that config.

## Named resource patterns (Object Mother in Gherkin)

Named parameter types are the Gherkin equivalent of the Object Mother pattern. Instead of inline construction in every step, the type name IS the canonical fixture reference:

```gherkin
Feature: Billing enforcement

  Scenario: Pro plan allows billing
    Given the organization "Acme" is on the pro plan
    When billing is triggered
    Then the invoice is generated

  Scenario: Free plan blocks billing
    Given the organization "Stark" is on the free plan
    When billing is triggered
    Then the user sees the upgrade prompt
```

The `{org-plan}` type acts as an Object Mother interface: the Gherkin step declares the *name* of the fixture; the step definition resolves it to the canonical DB state. Schema changes only require updating the transformer — all feature files remain untouched.

## Multiple regexp per type

A parameter type can match several alternative patterns with an array of `RegExp`:

```typescript
defineParameterType({
  name: 'status',
  regexp: [/active/, /inactive/, /pending approval/],
  transformer: (s: string) => s.replace(' ', '_') as Status,
});
```

## Async transformers

The `transformer` field accepts a function returning a `Promise`. However, because transformers run in the matching phase (before fixtures), async transformers can cause ordering issues. Prefer synchronous transformers that return config objects; delegate async work to the step body.

!!! warning "Async transformers in playwright-bdd"
    playwright-bdd does not inject Playwright fixtures into the transformer. If you need async setup (e.g. DB lookup), do it inside the step definition using the resolved config from the transformer as input.

## Custom types in playwright-bdd

Import `defineParameterType` from `playwright-bdd` (not from `@cucumber/cucumber`) when using playwright-bdd:

```typescript
import { defineParameterType } from 'playwright-bdd';

defineParameterType({
  name: 'payment-method',
  regexp: /credit card|paypal|invoice/,
  transformer: (method: string) => method as PaymentMethod,
});
```

The function is loaded automatically when the file is imported via your `steps` glob in `defineBddConfig`.

### Decorator mode (issue #112)

Before playwright-bdd v7, calling `defineParameterType` inside decorator-style step classes threw a "Cucumber isn't running" error. This was resolved in **v7** (released 2024-07-22). If you are on an earlier version:

- Use the `createBdd()` (non-decorator) style for files that call `defineParameterType`.
- Define parameter types in a dedicated `parameters.ts` file that is imported before any decorator class.

## The vocabulary registry pattern

Centralise all parameter type definitions in a single file:

```typescript
// src/test/parameters.ts
import { defineParameterType } from 'playwright-bdd';
import type { OrgPlan, UserRole, PaymentMethod } from '../types';

defineParameterType({
  name: 'org-plan',
  regexp: /free|pro|enterprise/,
  transformer: (t) => orgPlans[t],
});

defineParameterType({
  name: 'user-role',
  regexp: /admin|user|guest/,
  transformer: (r) => r as UserRole,
});

defineParameterType({
  name: 'payment-method',
  regexp: /credit card|paypal|invoice/,
  transformer: (m) => m as PaymentMethod,
});
```

Import it first in `playwright.config.ts`:

```typescript
// playwright.config.ts
import { defineBddConfig } from 'playwright-bdd';

const testDir = defineBddConfig({
  features: ['features/**/*.feature'],
  steps: [
    'src/test/parameters.ts',  // must load before step files
    'src/test/steps/**/*.ts',
  ],
});
```

This file serves as a living glossary: the set of names defined here is exactly the vocabulary available in feature files.

## The durability contract

When the shape of a domain object changes (new field, renamed property, different type), only the transformer function changes. Feature files and step definition signatures are unaffected. This is the key value proposition: the parameter type decouples the Gherkin vocabulary from the implementation details.

!!! example "Before and after a schema migration"
    Before: `{ plan: 'pro', billingEnabled: true, seatLimit: 50 }`
    After: `{ tier: 'pro', billing: { enabled: true }, seats: { max: 50 } }`

    Update the transformer in `parameters.ts`. The feature file still reads:
    `Given the organization is on the pro plan`

## See also

- [Cucumber Expressions](../reference/cucumber-expressions.md) — built-in `{string}`, `{int}`, `{word}` types
- [Ambiguous Steps](../reference/ambiguous-steps.md) — `preferForRegexpMatch` and resolving conflicts
- [Data Tables](../reference/data-tables.md) — `defineDataTableType` for table-to-object transforms
