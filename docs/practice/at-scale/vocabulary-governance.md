---
title: Vocabulary Governance
description: Preventing parameter type drift across teams — shared parameter type registries, approval processes, changelog practices, and migration paths for breaking changes.
sources:
  - git-playwright-bdd-repo-docs-writing-steps-playwright-style-custom-fixtures
  - git-playwright-bdd-repo-docs-writing-steps-scoped-scoped
---

# Vocabulary Governance

Ubiquitous language is the engine of BDD's communication value. When Team A calls it `{org-plan}` and Team B calls it `{org-config}`, both returning slightly different shapes for the same concept, you have vocabulary drift. Over time, vocabulary drift fragments the team's shared mental model: scenarios become ambiguous, step definitions proliferate, and the "living documentation" becomes unreliable.

Vocabulary governance is the practice of maintaining the shared vocabulary as a first-class artifact with the same care as a public API.

## The Vocabulary Drift Problem

The problem compounds gradually:

1. Team A defines `{org-plan}` with values `free|pro|enterprise` returning `{ seatLimit, billingEnabled }`
2. Team B, unaware, defines `{subscription-tier}` with values `starter|growth|enterprise` returning `{ maxUsers, trialDays }`
3. Team C defines `{plan-name}` because neither of the above names appears in their domain expert's vocabulary

Now three separate parameter types represent overlapping concepts. Scenarios written by different teams are not interoperable. A step definition from Team A's library cannot be reused by Team B's scenarios without vocabulary translation.

## The Shared Parameter Type Registry

The solution is a **single package** that owns all cross-team parameter type registrations:

```
@acme/bdd-vocabulary/
  package.json
  src/
    types/
      org-plan.ts         # {org-plan} parameter type
      user-role.ts        # {user-role} parameter type
      payment-method.ts   # {payment-method} parameter type
    index.ts              # Registers all types; consumers import this
  CHANGELOG.md
  REGISTRY.md             # Human-readable list of all types + allowed values
```

### Example Registry Entry

```typescript
// src/types/org-plan.ts
import { defineParameterType } from 'playwright-bdd';

export type OrgPlan = {
  name: 'free' | 'pro' | 'enterprise';
  billingEnabled: boolean;
  seatLimit: number;
  trialDays: number;
};

const ORG_PLANS: Record<string, OrgPlan> = {
  free: {
    name:           'free',
    billingEnabled: false,
    seatLimit:      5,
    trialDays:      14,
  },
  pro: {
    name:           'pro',
    billingEnabled: true,
    seatLimit:      50,
    trialDays:      0,
  },
  enterprise: {
    name:           'enterprise',
    billingEnabled: true,
    seatLimit:      9999,
    trialDays:      0,
  },
};

defineParameterType({
  name: 'org-plan',
  regexp: /free|pro|enterprise/,
  transformer(planName: string): OrgPlan {
    const plan = ORG_PLANS[planName];
    if (!plan) throw new Error(`Unknown org-plan: "${planName}"`);
    return plan;
  },
});
```

### Barrel Export

```typescript
// src/index.ts
// Importing this file registers all parameter types
export * from './types/org-plan';
export * from './types/user-role';
export * from './types/payment-method';
```

Consumer `playwright.config.ts`:

```typescript
testDir: defineBddConfig({
  features: 'e2e/features/**/*.feature',
  steps:    'e2e/steps/**/*.ts',
  import:   ['@acme/bdd-vocabulary'], // Loads all parameter types
}),
```

## Governance Process: Who Approves New Types

### RFC-Based Approval (for large organizations)

1. Engineer files a PR to `@acme/bdd-vocabulary` with the new type
2. PR includes: parameter name, regexp, transformer, example Gherkin usage, and rationale
3. A quorum of reviewers from at least 2 teams must approve (ensures cross-team legibility)
4. Domain expert (product/BA) signs off on the vocabulary choice

### Lightweight PR Quorum (for smaller organizations)

1. Engineer files a PR with the new type
2. Minimum 2 approvals required, at least 1 from a different team
3. Change is documented in `REGISTRY.md`

### The REGISTRY.md Document

Maintain a human-readable registry so non-developers can audit the vocabulary:

```markdown
# BDD Vocabulary Registry

## {org-plan}
**Values:** `free`, `pro`, `enterprise`
**Returns:** `OrgPlan` object with `billingEnabled`, `seatLimit`, `trialDays`
**Used in:** checkout, billing, onboarding suites
**Owner:** Platform team
**Added:** 2025-08-12, v1.0.0

## {user-role}
**Values:** `admin`, `editor`, `viewer`, `billing-manager`
**Returns:** `UserRole` string (validated)
**Used in:** auth, settings suites
**Owner:** Identity team
**Added:** 2025-09-03, v1.2.0
```

## Semantic Versioning for the Registry

Apply semver based on impact:

| Change | Version bump | Reason |
|--------|-------------|--------|
| Add a new parameter type | Minor | Non-breaking for existing consumers |
| Add a new allowed value to existing type | Minor | Potentially non-breaking |
| Remove an allowed value | **Major** | Breaks feature files using the removed value |
| Rename a parameter type | **Major** | Breaks all feature files using the old name |
| Change the transformer return shape | **Major** | Breaks step definitions consuming the type |
| Widen the regexp to accept more text | Minor | Non-breaking |
| Narrow the regexp | **Major** | May break feature files |

## Breaking Changes: Migration Path

When a major version bump is unavoidable:

1. **Deprecate, don't delete immediately**: Add a deprecation comment to the old type. Keep it functional in the next major version's deprecation period.
2. **Provide a migration guide** in `CHANGELOG.md` with before/after Gherkin examples:

```markdown
## [3.0.0] - 2026-01-15

### Breaking Changes

#### {org-plan} allowed values changed
The `starter` value has been renamed to `free` to align with the product team's terminology.

**Before:**
```gherkin
Given Acme Corp is on the "starter" plan
```
**After:**
```gherkin
Given Acme Corp is on the "free" plan
```

Find and replace in all feature files:
```bash
grep -rl '"starter"' e2e/features/ | xargs sed -i 's/"starter"/"free"/g'
```
```

3. **Automate migration where possible**: Provide a codemod script or grep-and-replace recipe
4. **Coordinate upgrade across teams**: File issues in all consumer repos; don't release without a migration timeline

!!! tip "Additive changes are almost always safe"
    Most vocabulary evolution is additive — new values, new types. Resist the temptation to rename or restructure existing types. The vocabulary's primary consumers are human-readable Gherkin files, and renaming creates friction for non-developers reviewing the diff.
