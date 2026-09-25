---
title: Organizing Feature Files
description: Naming conventions, directory structures, and step scoping strategies for organizing Gherkin feature files in playwright-bdd projects, including monorepo layouts.
sources:
  - web-cucumber-gherkin-step-organization-grouping-step-definitions
  - git-playwright-bdd-example-repo-agents-skills-playwright-bdd-skill-scoped-step-definitions
  - git-gherkin-best-practices-repo-readme-limit-the-number-of-scenarios-per-feature
  - git-gherkin-best-practices-repo-readme-use-meaningful-feature-and-scenario-names
---

# Organizing Feature Files

A well-organized feature file tree makes it easy to find scenarios, understand coverage, and scope step definitions without conflicts. Poor organization leads to naming collisions, unscoped global steps, and feature files that are too broad to serve as documentation.

## Naming Conventions

### Feature files

- Use kebab-case: `billing-upgrade.feature`, `user-invitation.feature`
- Name after the domain capability, not the implementation: `checkout.feature`, not `stripe-payment-flow.feature`
- Avoid verbs in file names: `cart.feature` not `add-to-cart.feature` (the scenarios carry the verb)

### Scenario titles

Use the sentence form that answers "what behavior does this describe?":

```gherkin
# Good — behavior-first, specific
Scenario: Pro plan blocks invite when seat limit is reached
Scenario: Free plan users cannot access the analytics dashboard
Scenario: Admin can reassign organization ownership

# Avoid — vague or test-oriented
Scenario: Test invite limit
Scenario: Check dashboard access
Scenario: Ownership transfer happy path
```

### Feature titles

The Feature title is a noun phrase for the capability, not a test category:

```gherkin
Feature: Organization membership
Feature: Billing plan management
Feature: Authentication
```

## Directory Structure Options

### By Feature Area (Recommended for most projects)

Group feature files by the bounded context or product area they describe. Step definitions live alongside or adjacent to their feature files.

```
features/
├── auth/
│   ├── login.feature
│   ├── logout.feature
│   └── mfa.feature
├── billing/
│   ├── plan-upgrade.feature
│   ├── invoice-history.feature
│   └── payment-methods.feature
├── org/
│   ├── membership.feature
│   └── settings.feature
└── shared.steps.ts       # steps used across areas
```

### By User Flow (For journey-oriented suites)

Useful when scenarios describe multi-step user journeys that cross domain boundaries:

```
features/
├── onboarding/
│   ├── signup.feature
│   └── first-org-creation.feature
├── daily-use/
│   ├── invite-member.feature
│   └── view-analytics.feature
└── offboarding/
    └── cancel-account.feature
```

### By Entity (For API-centric or CRUD-heavy suites)

```
features/
├── users/
├── organizations/
├── products/
└── orders/
```

!!! tip "Which structure to choose"
    Start with **by feature area** unless your suite is primarily API CRUD tests. Journey-based organization makes sense when your stakeholders think in flows, not entities.

## The `features/` Conventional Root

The `features/` directory at the project root is the conventional location for `.feature` files in all Gherkin frameworks. playwright-bdd's `defineBddConfig` `paths` option points here:

```typescript
// playwright.config.ts
export default defineConfig({
  ...defineBddConfig({
    paths: ['features/**/*.feature'],
    importTestFrom: 'features/fixtures.ts',
  }),
});
```

## Subdirectory-Based Step Scoping in playwright-bdd

playwright-bdd supports automatic step scoping based on `@`-prefixed directory names. Steps defined in `features/@billing/steps.ts` are scoped to scenarios in `features/@billing/` — no explicit tag filter needed:

```
features/
├── fixtures.ts
├── shared.steps.ts            # available to all features
├── @billing/
│   ├── billing.feature
│   └── steps.ts               # billing-scoped only
├── @admin/
│   ├── admin.feature
│   └── steps.ts               # admin-scoped only
└── @public/
    ├── public.feature
    └── steps.ts               # public-scoped only
```

Use scoping when two feature areas have steps with the same phrasing but different implementations. For example, `"I should see the dashboard"` might mean different things for admin users vs. regular users.

```typescript
// features/@admin/steps.ts
const { Then } = createBdd(test);

// This "see the dashboard" step only matches in @admin features
Then('I should see the dashboard', async ({ adminPage }) => {
  await adminPage.assertAdminDashboardVisible();
});
```

See the [playwright-bdd scoped steps documentation](https://vitalets.github.io/playwright-bdd/#/writing-steps/scoped) for configuration options.

## How Many Scenarios Per Feature File

Keep feature files focused. When a file grows beyond 10–15 scenarios, consider splitting by behavior subtype or Rule:

```gherkin
# billing.feature is getting long — split it
# billing-upgrades.feature
Feature: Billing plan upgrades
  Rule: Upgrades take effect immediately
    ...
  Rule: Prorated billing applies to mid-cycle upgrades
    ...

# billing-cancellation.feature
Feature: Billing cancellation
  ...
```

The `Rule` keyword (Gherkin 6+) helps before you need to split. Use `Rule` blocks to group scenarios that share a business rule within a single feature file.

!!! note
    There is no hard limit, but a feature file that scrolls for minutes is a sign that the scope is too broad. A good smell test: can a non-technical stakeholder read the file and understand the complete behavior in under 5 minutes?

## Monorepo Organization

In a monorepo with multiple applications, scope feature files by app, and share vocabulary (parameter types, common fixtures) via a workspace package:

```
apps/
├── web-app/
│   └── tests/
│       ├── features/
│       └── playwright.config.ts
├── admin-app/
│   └── tests/
│       ├── features/
│       └── playwright.config.ts
packages/
└── test-support/
    ├── parameters.ts          # shared vocabulary registry
    ├── fixtures.ts            # shared base fixtures
    └── api-client.ts          # shared API helpers
```

Each app imports from `@acme/test-support` and extends the shared fixtures with app-specific concerns. See [BDD at Scale](../../practice/at-scale/shared-step-library.md) for the full monorepo pattern.
