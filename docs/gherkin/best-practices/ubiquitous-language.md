---
title: Ubiquitous Language in Gherkin
description: How to derive step vocabulary from domain experts rather than UI or implementation, and maintain it as a living team glossary encoded in executable specifications.
sources:
  - web-martinfowler-ddd-ubiquitous-language-further-reading
  - git-gherkin-best-practices-repo-readme-refactor-and-reuse-step-definitions
  - git-gherkin-best-practices-repo-readme-avoid-testing-through-the-ui
  - git-gherkin-best-practices-repo-readme-organize-the-test-code-in-layers
  - web-itsadeliverything-declarative-imperative-declarative-style-of-gherkin-scenarios
---

# Ubiquitous Language in Gherkin

Eric Evans introduced Ubiquitous Language in _Domain-Driven Design_ (2003) as the practice of building a shared vocabulary between domain experts and developers — one that is used consistently in code, documentation, and conversation. Gherkin is the most direct path to making that vocabulary _executable_: the same terms that appear in team conversations appear verbatim in the test suite.

## Where Vocabulary Comes From

Step text should come from domain experts, not from the UI and not from the implementation.

**Wrong source — UI:**
```gherkin
When the user clicks the "Upgrade" button in the billing sidebar
```

**Wrong source — implementation:**
```gherkin
When a PUT request is sent to /api/v2/subscriptions with body { "plan": "pro" }
```

**Right source — domain:**
```gherkin
When the customer upgrades to a Pro subscription
```

The domain version uses the words a product manager, sales engineer, or customer success rep would use. Those words already exist in your team's vocabulary — the job is to capture them, not invent them.

!!! tip "Vocabulary elicitation technique"
    Before writing a scenario, listen to how a domain expert describes the behavior in conversation. Write down the nouns and verbs they use. Those are your step terms. If your steps use different words than the domain expert, you have an alignment problem.

## Named Domain Nouns vs. Mechanisms

Ubiquitous Language in Gherkin is primarily about **named nouns** — the entities that actors operate on. Prefer named domain concepts over mechanisms:

| Mechanism (avoid) | Domain noun (prefer) |
|---|---|
| `a database record with plan="pro"` | `a Pro subscription` |
| `a row in the users table with role="admin"` | `an admin user` |
| `an entry in the audit_log table` | `an audit trail entry` |
| `a JWT with scope="billing:write"` | `billing write access` |

Named domain nouns become the vocabulary of your [Custom Parameter Types](../reference/custom-parameter-types.md), which then become the reusable vocabulary of your entire test suite.

## Avoiding Synonyms

One concept, one name. Ubiquitous Language breaks down when a team uses multiple words for the same thing:

```gherkin
# Drift — three words for the same concept
Given a customer is on a free tier       # feature A
Given a user has a basic plan            # feature B
Given the account uses the starter plan  # feature C
```

This drift creates false distinctions in readers' minds and prevents step reuse. Pick one term — ideally the one your domain experts use most — and refactor the others to match.

```gherkin
# Consistent
Given the account is on the Free plan
```

Maintain a living glossary (see below) that records the canonical term for each concept and lists the synonyms to avoid.

## Bounded Context and Step Vocabulary

In large systems, the same noun may mean different things in different contexts. DDD calls these **bounded contexts**. Gherkin should respect them:

- A `user` in the authentication context may mean an authentication principal with credentials
- A `user` in the billing context may mean a billing account holder with payment methods
- A `user` in the product context may mean a person with a role and a workspace

When contexts overlap in a feature file, qualify the noun:

```gherkin
Scenario: Billing admin cancels a team subscription
  Given Alice is the billing admin for the Acme workspace
  And the workspace has an active Pro subscription
  When Alice cancels the subscription
  Then the workspace downgrades to Free at the end of the billing period
  And all workspace members retain read-only access until then
```

The step vocabulary here draws from both the billing context (`billing admin`, `subscription`, `billing period`) and the product context (`workspace`, `workspace members`, `read-only access`). These terms are explicit in the Gherkin because they are the meaningful distinction in this behavior.

## When Vocabulary Changes, Refactor Steps

A domain model evolves. When product experts rename a concept — "accounts" become "workspaces," "packages" become "plans" — the Gherkin must follow. Stale vocabulary is a form of documentation rot.

The refactoring procedure:

1. Update the canonical term in the team glossary
2. Update the `defineParameterType` regexp and transformer in `parameters.ts`
3. Run a global find-and-replace on the old step text across all `.feature` files
4. Run `bddgen` to confirm no undefined steps were introduced
5. Commit the feature file changes and step definition changes together

!!! warning "Step text refactoring is a breaking change"
    Step text changes require simultaneous updates to both the `.feature` files and the step definitions. Use `bddgen --dry-run` in CI to catch any undefined steps before they reach the main branch. See [Feature-Step Sync](../../practice/playwright-bdd/sync-and-hygiene.md) for CI setup.

## Building a Team Glossary

The team glossary is the authoritative mapping from domain concepts to the step vocabulary used in Gherkin. It should live alongside the codebase — not in a separate wiki where it will drift.

A practical format: make `parameters.ts` the canonical source, with comments that document synonyms to avoid:

```typescript
// parameters.ts — vocabulary registry
// This file IS the team glossary for Gherkin parameter types.
// Canonical terms and their synonyms are documented here.
// Before adding a new {type}, check if a synonym already exists.

// CANONICAL: "subscription plan"
// SYNONYMS TO AVOID: tier, package, account type, plan level
defineParameterType({
  name: 'plan',
  regexp: /Free|Pro|Enterprise/,
  transformer: (name): Plan => planCatalog[name],
});

// CANONICAL: "workspace member role"
// SYNONYMS TO AVOID: user type, permission level, access role
defineParameterType({
  name: 'member-role',
  regexp: /admin|member|viewer/,
  transformer: (role): MemberRole => role as MemberRole,
});
```

This makes `parameters.ts` a machine-readable glossary that is enforced at test time. Any step that uses a term not in the registry will fail with an undefined step error.

## Gherkin as Executable Ubiquitous Language

When the vocabulary discipline is maintained, each `.feature` file becomes a living specification written in the team's shared language. The specification is not documentation that might be wrong — it is executable, and it fails when the implementation diverges.

```gherkin
Feature: Workspace subscription management
  Subscriptions are managed at the workspace level.
  Only billing admins can upgrade, downgrade, or cancel.

  Rule: Only billing admins can modify a subscription

    Scenario: Billing admin upgrades the workspace plan
      Given Alice is the billing admin for the Acme workspace
      And the workspace is on the Free plan
      When she upgrades to Pro
      Then the workspace has Pro-tier access
      And an invoice is issued for the Pro plan

    Scenario: Regular member cannot upgrade the plan
      Given Bob is a member (not admin) of the Acme workspace
      When he attempts to upgrade to Pro
      Then he is shown a permission denied message
      And the workspace plan remains Free
```

A domain expert can read this, validate it against their mental model of the system, and confirm that the tests are testing the right thing. That is what ubiquitous language in Gherkin achieves.

## Cross-References

- [Declarative vs. Imperative](declarative-vs-imperative.md) — why ubiquitous language and declarative altitude are inseparable
- [Custom Parameter Types](../reference/custom-parameter-types.md) — the TypeScript mechanism for encoding vocabulary
- [Named Test Data Catalog](named-test-data-catalog.md) — Object Mother pattern as vocabulary registry
- [Step Definitions](step-definitions.md) — how vocabulary consistency applies to step phrasing choices
