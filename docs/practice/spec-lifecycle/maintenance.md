---
title: Spec Maintenance
description: Identifying stale scenarios, pruning redundant coverage, refactoring step text safely, and keeping the parameter type registry current.
sources:
  - web-automation-panda-writing-good-gherkin-style-and-structure
  - web-testquality-best-practices-maintaining-consistency-in-gherkin-syntax
  - git-playwright-bdd-repo-docs-cli-bddgen-test-or-just-bddgen
  - git-gherkin-lint-readme-available-rules
  - git-cucumber-js-docs-dryrun-dry-run
---

# Spec Maintenance

A feature file that was accurate when written can become misleading over time. The vocabulary shifts, behaviors are removed or redesigned, and step definitions accumulate dead code. Maintenance keeps the spec honest.

## Identifying Stale Scenarios

A scenario that has not failed in six or more months is a signal worth investigating — not celebrating. Three interpretations:

1. The behavior is well-implemented and stable (healthy)
2. The scenario never actually runs (broken setup, excluded tag)
3. The scenario tests something trivial that cannot realistically fail

Distinguish these by checking whether the scenario is in the active tag set (not `@skip`, `@quarantine`, or excluded by a `grep` filter). If a scenario that should run has not failed in six months and its coverage is duplicated elsewhere, it is a candidate for deletion.

!!! note "Track coverage, not just pass/fail"
    A scenario that always passes is not automatically healthy. Audit whether it actually exercises the code path it claims to — especially if the underlying feature has been refactored without corresponding Gherkin updates.

## Pruning Redundant Scenarios

Redundant scenarios are two or more scenarios that verify the same behavior. This happens when:

- A feature is expanded and a new scenario subsumes an older, narrower one
- Multiple developers independently wrote similar scenarios without a shared vocabulary
- A Scenario Outline was later replaced with individual scenarios and the outline was never deleted

To identify redundancy: sort all scenario titles in a feature and look for semantic duplicates. Also grep step definitions for similar transformer logic — two steps that call the same underlying helper are likely testing the same thing.

```bash
# Find duplicate scenario names across all features
grep -r "Scenario:" features/ | sort -k2 | uniq -d -f1
```

When pruning:

1. Confirm with the product owner that both scenarios cover the same behavior
2. Keep the one with the more precise or informative title
3. Delete the other and check for orphaned steps with `bddgen --dry-run`

## Refactoring Step Text Safely

Renaming a step's text in the Gherkin without updating the step definition creates an undefined step. This is why step text changes must always be made in the step definition file simultaneously.

Safe refactoring workflow:

```bash
# Step 1: Change the step text in the .feature file
# Step 2: Update the step definition to match the new text
# Step 3: Verify with bddgen dry-run — must report zero undefined steps
npx bddgen --dry-run

# Step 4: Run the affected feature file in isolation to confirm it passes
npx bddgen && npx playwright test --grep "Order placement"
```

For bulk renames (a step used across many feature files), use a codemod or global find-replace in your editor, then run the dry-run on the entire suite:

```bash
# Global rename check
npx bddgen --dry-run && echo "All steps defined"
```

!!! warning "Vocabulary drift"
    The vocabulary drift problem: Team A uses `{org-plan}` parameter type; Team B starts writing `{org-config}` for the same concept. Over time, synonyms accumulate in the step registry. Regular audits of `parameters.ts` (or equivalent) should identify synonyms and consolidate them. Vocabulary governance belongs in the team's Three Amigos process, not in a retrospective.

## Feature File Age as a Health Indicator

Use git history to find feature files that haven't been touched in a long time:

```bash
# Find feature files not modified in 6+ months
git log --format="%ai %ar" -- features/ | \
  awk '$3 > "2025-12-01"' | head -20

# More directly: list files by last commit date
git ls-files features/ | while read f; do
  echo "$(git log -1 --format='%ar' -- "$f") $f"
done | sort
```

Old feature files are not inherently bad — stable features exist. But an old feature file covering a recently-refactored area is a red flag. Cross-reference git history on the corresponding source code directory.

## Keeping the Parameter Type Registry Current

Custom parameter types (defined in `parameters.ts`) encode the team's vocabulary. They accumulate debt:

- Types added for features that were later removed
- Types whose regexp no longer matches the values used in practice
- Duplicate types for the same domain concept

Quarterly maintenance tasks for the parameter type registry:

```typescript
// parameters.ts — example of a type that needs cleanup
// 'org-plan-legacy' was added during migration and is now unused
defineParameterType({
  name: 'org-plan-legacy',     // <- grep features/ for '{org-plan-legacy}'; if zero hits, delete
  regexp: /basic|standard/,
  transformer: (s) => legacyPlanConfig(s),
});
```

Audit process:

```bash
# Find which parameter types are actually used in feature files
grep -r '{org-plan}' features/ | wc -l      # 12 uses - keep
grep -r '{org-plan-legacy}' features/ | wc -l  # 0 uses - delete
```

Unused parameter types that remain in the registry mislead AI agents reading the schema and add maintenance overhead when the domain model changes.

## Maintenance Cadence

Suggested maintenance checkpoints:

| Cadence | Task |
|---|---|
| Every sprint | Delete `@quarantine` scenarios that have been fixed or abandoned |
| Monthly | Audit feature files with zero CI failures in 30 days — investigate, don't assume health |
| Quarterly | Prune parameter type registry; consolidate vocabulary synonyms |
| On each feature refactor | Update Gherkin to match the new domain model before merging |

## Cross-references

- [Iteration Guidelines](iteration-guidelines.md) — when to add, modify, or delete
- [CI Enforcement](ci-enforcement.md) — `bddgen --dry-run` for undefined step detection
- [Flaky Tests](flaky-tests.md) — quarantine lifecycle
- [BDD at Scale: Vocabulary Governance](../at-scale/vocabulary-governance.md)
