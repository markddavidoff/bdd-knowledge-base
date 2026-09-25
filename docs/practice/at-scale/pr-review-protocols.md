---
title: PR Review Protocols for Feature Files
description: Who reviews .feature file changes, how to assess shared step impact, automated downstream detection, and the Three Amigos enforcement rule in PRs.
sources:
  - git-gherkin-best-practices-repo-readme-write-the-scenario-before-writing-the-code
  - git-gherkin-best-practices-repo-readme-do-not-write-scenarios-in-isolation
  - git-playwright-bdd-repo-docs-writing-steps-scoped-scoped
---

# PR Review Protocols for Feature Files

A `.feature` file is a specification, not just a test. Reviewing it requires a different lens than reviewing a `.ts` implementation file. At scale — multiple teams, hundreds of scenarios — ad hoc review produces inconsistent quality and allows vocabulary drift, imperative style, and scope creep to accumulate unnoticed.

This page defines explicit review protocols to enforce: who reviews what, what they look for, and how to automate the mechanical parts of impact assessment.

## The Two Types of Feature File Changes

### Type 1: New or modified scenario (behavioral change)

A PR that adds, modifies, or removes a Gherkin scenario specifies new, changed, or removed behavior. This requires Three Amigos sign-off:

- **Domain expert (product/BA)**: Is this the right behavior? Does the vocabulary match the domain?
- **Developer**: Is this testable? Does the step vocabulary exist or need to be created?
- **QA**: Does this cover the right paths? Are edge cases represented?

### Type 2: Shared step definition change

A PR that changes a step definition that is used by scenarios across multiple feature files has **downstream impact** beyond what is visible in the PR diff. This requires:

- **Affected team review**: Any team whose scenarios use the modified step must be notified
- **Impact assessment**: Which scenarios are now affected?
- **Regression signal**: Does the CI suite pass on the changed step?

## The "No Feature File Change Without Three Amigos" Rule

Encode this rule in your PR template:

```markdown
<!-- .github/pull_request_template.md -->
## Change type
- [ ] New scenario (behavioral change)
- [ ] Modified scenario (behavioral change)
- [ ] New/modified step definition
- [ ] Infrastructure only (config, fixtures, tooling)

## For behavioral changes
- [ ] Three Amigos session held (or async equivalent in PR comments)
- [ ] Domain expert has reviewed the Gherkin text
- [ ] Step vocabulary aligns with the shared registry
```

For async teams, the Three Amigos requirement can be met via PR comments: the product/BA leaves a comment confirming the behavior is correct; QA leaves a comment on edge case coverage; the developer confirms implementability. All three must appear before merge.

## Feature File Diff as the Acceptance Signal

In a PR that implements a feature, the `.feature` file change is the ground truth of what behavior was agreed upon. Review the feature diff before reviewing the implementation:

1. Does the scenario title describe behavior, not mechanism?
2. Are step phrasings declarative (no "click", "navigate", "fill in")?
3. Is the vocabulary consistent with the shared registry?
4. Are all Happy Path and key error paths covered?
5. Is each scenario independent (no ordering dependencies)?

If the feature file is wrong, the implementation is wrong by definition — no amount of clean code fixes an incorrect specification.

## Shared Step Change Review: Downstream Impact

### Manual Impact Detection

Before merging a shared step text change, find all scenarios that use it:

```bash
# Find all feature files containing this step text
grep -rl 'Alice has a {user-role} account' e2e/features/
grep -rl 'Alice has a' e2e/features/ | xargs grep -l 'user-role'

# Count unique scenarios using a step
grep -rh 'the cart is empty' e2e/features/ | wc -l
```

### Automated Impact Detection in CI

Add a CI check that identifies which scenarios use a modified step and comments on the PR:

```javascript
// scripts/step-impact.js
// Usage: node scripts/step-impact.js "the cart is empty"
const { execSync } = require('child_process');
const stepText = process.argv[2];

const files = execSync(`grep -rl "${stepText}" e2e/features/`)
  .toString()
  .trim()
  .split('\n')
  .filter(Boolean);

console.log(`Step "${stepText}" is used in ${files.length} feature file(s):`);
files.forEach(f => console.log(`  - ${f}`));
```

Integrate with GitHub Actions to auto-comment on step-change PRs:

```yaml
- name: Check step impact
  if: contains(github.event.pull_request.changed_files, 'steps/')
  run: |
    node scripts/step-impact.js "${{ env.CHANGED_STEP_TEXT }}" > impact.txt
    gh pr comment ${{ github.event.pull_request.number }} --body-file impact.txt
```

## Checklist for Step Definition Change PRs

When a step definition changes (text or behavior):

```
[ ] What is the step text? (exact text, checked for partial matches)
[ ] How many feature files use this step? (run grep -rl)
[ ] Is this a text change (renaming step) or behavior change?
[ ] If text change: all feature files updated to new text?
[ ] CI passes with the change?
[ ] Teams owning affected feature files notified?
[ ] CHANGELOG updated if this is in a shared package?
```

## Vocabulary Review Checklist

Every PR touching `.feature` files should pass this vocabulary check:

```
[ ] No synonyms introduced (check against REGISTRY.md for existing terms)
[ ] Parameter type names match shared registry ({org-plan}, not {plan})
[ ] No implementation language in step text (no "click", "POST", "database")
[ ] Scenario title is a behavioral statement, not a test description
[ ] Step text reads naturally in English
```

## Automating PR Checks with gherkin-lint

Run `gherkin-lint` as a required CI check on every `.feature` file change:

```yaml
# .github/workflows/gherkin-lint.yml
name: Gherkin Lint
on:
  pull_request:
    paths: ['**/*.feature']

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm ci
      - run: npx gherkin-lint 'e2e/features/**/*.feature'
```

Configure allowed tags to catch vocabulary drift at the lint level:

```json
{
  "allowed-tags": ["smoke", "regression", "slow", "wip", "skip"],
  "no-dupe-feature-names": true,
  "no-unused-variables": true
}
```

!!! note "The PR diff IS the specification"
    Train reviewers to treat the `.feature` file diff as the primary artifact to review — not the implementation code. A clean implementation of a wrong specification is worthless. The habit of reading the feature diff first, asking "is this the right behavior?", and only then reviewing the code is the highest-leverage review practice for BDD teams.
