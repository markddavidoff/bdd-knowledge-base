---
title: BDD at Scale
description: When and why BDD creates coordination problems at scale — heuristics for identifying scale challenges and an overview of the solutions covered in this section.
sources:
  - git-playwright-bdd-repo-docs-configuration-multiple-projects-multiple-projects
  - git-playwright-bdd-repo-docs-writing-steps-scoped-scoped
  - git-cucumber-js-docs-parallel-parallel
---

# BDD at Scale

A BDD practice that works smoothly for one team with 80 scenarios can become a coordination problem at 200+ scenarios across 3+ teams. This section covers the patterns that address scale — not as premature optimization, but as targeted responses to specific pain points you will encounter as your BDD suite grows.

## When Is "Scale" a Problem?

Use these heuristics to decide when to apply the patterns in this section:

| Signal | Threshold to watch | Pattern to apply |
|--------|-------------------|-----------------|
| Scenario count | 200+ scenarios | [Suite partitioning](suite-partitioning.md), [Shared step library](shared-step-library.md) |
| Team count | 3+ teams writing feature files | [Vocabulary governance](vocabulary-governance.md), [PR review protocols](pr-review-protocols.md) |
| CI wall-clock time | >10 minutes for the full suite | [Suite partitioning](suite-partitioning.md) |
| Step name collisions | Multiple definitions for the same step text | [Scoped steps](../playwright-bdd/scoped-steps.md), [Vocabulary governance](vocabulary-governance.md) |
| Vocabulary drift | Two teams using different names for the same concept | [Vocabulary governance](vocabulary-governance.md) |
| Flakiness rate | >1% of scenarios flaky on main | [Suite health](suite-health.md) |

## The Four Core Scale Challenges

### 1. Step Library Ownership

When multiple teams write step definitions into a shared pool, questions arise: who owns a step that teams A, B, and C all depend on? Who reviews changes? Who is responsible when it breaks?

The answer is usually a **shared step library as an npm package** — explicit versioning, explicit ownership, and a semver contract between producers and consumers. See [Shared Step Library](shared-step-library.md).

### 2. Vocabulary Drift

Two teams independently solving similar problems will independently invent parameter type names. Team A calls it `{org-plan}`; Team B calls it `{org-config}`. Both return the same business concept but with different names, different transformer logic, and different sets of allowed values.

Vocabulary drift is a slow poison: it silently fragments your ubiquitous language. The fix is a **vocabulary governance process** with a shared parameter type registry and a lightweight approval protocol for new types. See [Vocabulary Governance](vocabulary-governance.md).

### 3. Suite Partition Time

When a CI run takes 15 minutes, developers stop running it locally. When it takes 20 minutes, they merge before the suite passes. CI time is a **forcing function** for test discipline — once it slips above 10 minutes, suite health deteriorates faster than it improves.

The solutions are tag-based sharding, Playwright's `--shard N/M` option, and project-based splitting. See [Suite Partitioning](suite-partitioning.md).

### 4. Review Protocols

A `.feature` file is a specification, not just a test. Reviewing it requires domain expertise (is this the right behavior?), developer judgment (is this testable?), and QA perspective (does this cover the right paths?). Without explicit protocols, feature file changes get reviewed only by developers and miss the collaboration that gives BDD its value.

See [PR Review Protocols](pr-review-protocols.md).

## Monorepo Considerations

Most large TypeScript codebases are monorepos. playwright-bdd's directory-based step scoping maps naturally onto monorepo structure:

```
packages/
  shared/
    steps/         # Shared steps available to all apps
    parameters/    # Shared parameter types
  app-auth/
    e2e/
      features/    # Auth-specific feature files
      steps/       # Auth-specific step definitions
  app-billing/
    e2e/
      features/
      steps/
playwright.config.ts  # Root config with multiple projects
```

See [Monorepo Patterns](monorepo-patterns.md) for the full configuration.

## Suite Health as a Practice

At scale, suite health can no longer be a manual concern — there are too many scenarios, too many contributors, and too much velocity. You need **automated health metrics**: pass rate trend, flakiness rate, duration trend, undefined step count, vocabulary registry freshness. See [Suite Health](suite-health.md).

!!! tip "Start with one problem, not all four"
    Apply scale patterns one at a time, triggered by a specific pain point. Extracting a shared step library before vocabulary drift is a real problem adds maintenance overhead without benefit. Use the thresholds table above to decide which pattern to reach for first.

## Pages in This Section

- [Shared Step Library](shared-step-library.md) — extracting steps into a versioned npm package
- [Monorepo Patterns](monorepo-patterns.md) — playwright-bdd configuration for monorepos
- [Vocabulary Governance](vocabulary-governance.md) — preventing parameter type drift across teams
- [Suite Partitioning](suite-partitioning.md) — keeping CI under 10 minutes at 500+ scenarios
- [PR Review Protocols](pr-review-protocols.md) — who reviews what, and how to automate impact detection
- [Suite Health](suite-health.md) — metrics, KPIs, and dashboards for a large BDD suite
