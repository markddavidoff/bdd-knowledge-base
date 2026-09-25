---
title: Spec Lifecycle
description: How BDD specifications evolve from first draft through CI enforcement, maintenance, and retirement.
---

# Spec Lifecycle

A BDD specification isn't written once — it evolves with the behavior it describes. This section covers the full lifecycle of a feature file, from the first draft through iteration, CI integration, and long-term maintenance.

## In this section

| Page | What it covers |
|---|---|
| [Writing Your First Spec](writing-first-spec.md) | Starting from a user story, drafting in plain language, Three Amigos review |
| [Iteration Guidelines](iteration-guidelines.md) | When to add, modify, or delete scenarios; PR conventions |
| [BDD Without a Browser](bdd-without-browser.md) | Applying BDD to API-only services; tool selection |
| [Flaky Test Management](flaky-tests.md) | Quarantine patterns, retry strategies, flakiness KPIs |
| [CI: Running Specs](ci-running.md) | Pipeline setup, sharding, artifacts, GitHub Actions YAML |
| [CI: Enforcement](ci-enforcement.md) | Hard-failing on undefined steps, tag convention enforcement, branch protection |
| [Maintenance](maintenance.md) | Identifying stale scenarios, pruning, step text refactoring |
| [Feature Flags in Specs](feature-flags.md) | Tagging strategies for flagged behavior, deprecation |
| [Environment-Specific Scenarios](env-specific.md) | @staging/@production tagging, secrets, smoke suites |

## The lifecycle at a glance

```
Story → Example Mapping → Draft Gherkin → Three Amigos review
  → Step definitions → CI green → Merge
  → Maintained as behavior evolves
  → Pruned when behavior is retired
```

The most common failure is treating feature files as write-once artifacts. Scenarios that aren't updated when behavior changes become **rotten documentation** — they pass (or are skipped) but no longer reflect reality.

!!! tip "CI enforcement is non-negotiable"
    A suite that isn't enforced in CI provides false confidence. See [CI: Enforcement](ci-enforcement.md) for the minimum viable gate.
