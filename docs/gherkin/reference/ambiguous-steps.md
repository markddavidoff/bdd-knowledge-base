---
title: Ambiguous Steps
description: Understand what causes AmbiguousError, how Cucumber resolves step conflicts, and how to design vocabulary that prevents ambiguity.
sources:
  - web-cucumber-js-api-defineparametertype-api-reference
  - git-cucumber-expressions-readme-parameter-types
  - web-thegreenreport-custom-parameter-types-the-green-report-https-www-thegreenreport-blog
---

# Ambiguous Steps

An `AmbiguousError` means Cucumber found two or more step definitions that match the same step text and cannot decide which one to run. It fails immediately rather than picking arbitrarily.

## What causes AmbiguousError

Ambiguity arises when two patterns overlap for the same input string:

```typescript
// steps/auth.steps.ts
Given(/the user is (.+)/, async ({}, state: string) => { /* ... */ });

// steps/admin.steps.ts
Given(/the user is (admin|moderator)/, async ({}, role: string) => { /* ... */ });
```

For the step `Given the user is admin`, both patterns match. Cucumber cannot choose; it raises:

```
Error: Multiple step definitions match:
  /the user is (.+)/    -- steps/auth.steps.ts:3
  /the user is (admin|moderator)/ -- steps/admin.steps.ts:3
```

The same conflict can arise with Cucumber Expressions if you define two `{string}` patterns that overlap with a specific custom type:

```typescript
// Matches anything in quotes
Given('the plan is {string}', ...);

// Also matches "pro" and "enterprise" in quotes
Given('the plan is {org-plan}', ...);
```

## How Cucumber resolves ambiguity

Cucumber does **not** implement a "most specific match wins" rule. If two patterns match and neither is explicitly preferred, it is an error. The resolution mechanisms are:

1. **Distinct patterns** — the correct fix in most cases. Redesign step text or patterns so they do not overlap.
2. **`preferForRegexpMatch`** — a parameter type flag that gives that type priority over plain regexp step patterns (not over other named types).
3. **Vocabulary discipline** — a named parameter type (`{org-plan}`) is never ambiguous with another named type because their `regexp` values are disjoint by design.

## The `preferForRegexpMatch` flag

`preferForRegexpMatch` is a tiebreaker when a custom parameter type's `regexp` overlaps with a plain regex step definition:

```typescript
defineParameterType({
  name: 'user-role',
  regexp: /admin|user|guest/,
  transformer: (r) => r as UserRole,
  preferForRegexpMatch: true,   // wins over /(.+)/ catch-all steps
});
```

!!! warning "Scope of `preferForRegexpMatch`"
    This flag only resolves conflicts between a **custom parameter type** and a **regexp step definition**. It has no effect when two custom parameter types overlap, or when two Cucumber Expression steps overlap. In those cases, you must fix the patterns.

## The `useForSnippets` flag

When Cucumber encounters an undefined step, it generates a snippet suggesting how to define it. If a custom parameter type's `regexp` is broad (e.g., matches general words), the generated snippets become cluttered:

```typescript
defineParameterType({
  name: 'payment-method',
  regexp: /credit card|paypal|invoice/,
  transformer: (m) => m as PaymentMethod,
  useForSnippets: false,  // omit from snippet generation
});
```

Set `useForSnippets: false` for any type whose regexp is likely to match step text that isn't actually a parameter of that type. The type still works at runtime; it just won't appear in `--dry-run` snippet output.

## Diagnosing ambiguous steps in CI

When a build fails with `AmbiguousError`:

```bash
# Dry-run to see all matches without executing
npx playwright test --config=playwright.config.ts -- --dry-run 2>&1 | grep -A5 "Multiple step"

# Or with @cucumber/cucumber directly
npx cucumber-js --dry-run 2>&1 | grep -A5 "Ambiguous"
```

!!! tip "Use bddgen for playwright-bdd"
    Run `npx bddgen` (dry run) before `playwright test` in CI. It surfaces undefined and ambiguous step errors at the code-generation phase, before any browser is launched.

```yaml
# .github/workflows/test.yml
- name: Check steps
  run: npx bddgen --dry-run

- name: Run tests
  run: npx playwright test
```

## Prevention: vocabulary design

Most ambiguity is a symptom of imprecise vocabulary. These patterns prevent it:

### Use named parameter types instead of catch-all regexp

A catch-all step like `Given(.+)` fights every other definition for the same text. Replace broad regexp steps with Cucumber Expression steps and named types:

```typescript
// Fragile — matches anything, collides with everything
Given(/the (\w+) is (\w+)/, async ({}, entity, state) => { /* ... */ });

// Precise — only fires for known roles
Given('the user is a {user-role}', async ({}, role: UserRole) => { /* ... */ });
```

### Keep type `regexp` values disjoint

Two custom parameter types that share any matching string will collide:

```typescript
// Collision: both can match "admin"
defineParameterType({ name: 'role',  regexp: /admin|user/ });
defineParameterType({ name: 'level', regexp: /admin|senior/ });
```

Design your regexp values to cover non-overlapping vocabularies. A vocabulary registry in `parameters.ts` makes overlaps visible at a glance.

### Scope step files by domain

playwright-bdd supports directory-based step scoping. Steps in `features/billing/` only match feature files in the same directory tree. This naturally prevents a billing step from colliding with an auth step that uses similar language:

```
features/
  billing/
    steps/plan-steps.ts   # {org-plan} steps
  auth/
    steps/role-steps.ts   # {user-role} steps
```

!!! note "Identical step text is always an error"
    Even with scoping, two step definitions with identical text in the same scope is always an error. Scoping limits blast radius; it doesn't excuse duplicate definitions.

## See also

- [Custom Parameter Types](../reference/custom-parameter-types.md) — `preferForRegexpMatch` and `useForSnippets` in context
- [Cucumber Expressions](../reference/cucumber-expressions.md) — how built-in types match and when to use regexp instead
