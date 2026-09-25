---
title: Tag Taxonomy Design and Governance
description: How to design a classification tag taxonomy upfront, distinguish classification from lifecycle tags, prevent tag sprawl, and enforce allowed tags with gherkin-lint.
sources:
  - git-gherkin-best-practices-repo-readme-use-tags-to-organize-your-features-and-scenarios
  - git-playwright-bdd-repo-docs-writing-features-special-tags-special-tags
  - git-playwright-bdd-repo-docs-configuration-options-tags
  - git-gherkin-best-practices-repo-readme-readme
---

# Tag Taxonomy Design and Governance

Tags are powerful, but an unmanaged tag namespace becomes meaningless within months. The question "what does `@smoke` actually include?" signals a governance failure. Design your taxonomy before your first feature file, document it, and enforce it in CI.

## Two Tag Classes

### Classification Tags

Classification tags describe what a scenario is. They are permanent (they don't change with the scenario's lifecycle) and drive CI pipeline configuration.

| Tag | Meaning |
|---|---|
| `@smoke` | Critical path — runs on every deploy, must pass in under 5 min |
| `@regression` | Full regression suite — runs nightly or on release branches |
| `@api` | Exercises only API layer, no browser required |
| `@ui` | Requires a browser |
| `@integration` | Touches external services (may require mocking in some environments) |
| `@slow` | Expected to run > 30 seconds |
| `@happy-path` | Success path for a behavior |
| `@error-path` | Error and rejection behaviors |
| `@live-only` | Requires a live external service; skip in mock environments |

### Lifecycle Tags

Lifecycle tags describe the scenario's current state. They are temporary by design — a scenario should not stay `@wip` forever.

| Tag | Meaning | Enforcement |
|---|---|---|
| `@wip` | Work in progress; may not pass | Excluded from CI main suite |
| `@skip` | Known skip with documented reason | Always accompanied by a comment |
| `@quarantine` | Flaky; isolated while being fixed | Runs separately, failures don't block merge |
| `@manual` | No automation; documents a manual test case | Never executed |

!!! warning "Danger zone tags"
    `@only` and `@focus` filter to a single scenario when running locally. **These tags must never be committed.** Enforce this with a pre-commit hook or gherkin-lint rule.

## The `@smoke` Documentation Problem

Every project invents `@smoke`, and within six months no one agrees on what it means:

- Is it every feature's critical path?
- Is it the scenarios that run before a deploy?
- Is it the scenarios a new developer runs to check their environment?

These are different sets. Resolve ambiguity by writing the definition in your tag taxonomy document before tagging the first scenario. Example:

```
@smoke: The minimal set of scenarios that verify the application is alive and capable
        of processing the core user journey. Target: < 5 min on CI. Includes login,
        create-org, invite-member, and checkout. Excludes all @slow and @error-path
        scenarios.
```

Store this definition in `docs/tag-taxonomy.md` and link to it from your PR template.

## Example Taxonomy (Team Reference Table)

```gherkin
# Usage examples
@smoke @happy-path
Scenario: User can log in and view their dashboard

@regression @error-path
Scenario: Invalid password shows a clear error message

@api @integration @live-only
Scenario: Webhook delivery retries on a 5xx response

@wip
# TODO: complete payment retry logic — see KB-4521
Scenario: Payment retry succeeds on second attempt
```

## Tag Sprawl: How It Happens and How to Prevent It

Tag sprawl occurs when:

1. Tags are added ad hoc without consulting the taxonomy
2. Tags are never removed after their reason expires
3. Multiple tags mean the same thing (`@e2e`, `@end-to-end`, `@full-flow`)
4. Feature files accumulate tags from multiple authors over time

**Prevention checklist:**

- Define allowed tags in `.gherkin-lintrc` (see below)
- Include "does this need a new tag?" in the PR review checklist
- Run a quarterly audit: `grep -r '@' features/ | grep -oP '@\w+' | sort | uniq -c | sort -rn`
- Delete `@wip` tags when work is complete; delete `@quarantine` tags when fixed

## Enforcing Allowed Tags with gherkin-lint

Install `gherkin-lint` and define the allowed tag set:

```json
// .gherkin-lintrc
{
  "allowed-tags": [
    "error",
    {
      "tags": [
        "@smoke", "@regression", "@api", "@ui", "@integration",
        "@slow", "@happy-path", "@error-path", "@live-only",
        "@wip", "@skip", "@quarantine", "@manual"
      ]
    }
  ],
  "no-restricted-tags": [
    "error",
    { "tags": ["@only", "@focus", "@debug"] }
  ]
}
```

Add to your CI pipeline:

```yaml
# .github/workflows/ci.yml
- name: Lint Gherkin
  run: npx gherkin-lint features/**/*.feature
```

And as a pre-commit hook:

```bash
# .husky/pre-commit
npx gherkin-lint features/**/*.feature
```

## Tag Review in PR Checklist

Add a tag section to your pull request template:

```markdown
## Feature file checklist
- [ ] New tags match the [approved taxonomy](docs/tag-taxonomy.md)
- [ ] No `@only` or `@focus` tags committed
- [ ] `@wip` tags removed before merge (or PR is draft)
- [ ] `@smoke` scenarios still run in under 5 minutes total
```

## playwright-bdd Special Tags

playwright-bdd reserves a set of tags for test control. These are not part of your classification taxonomy — they are framework-level directives:

| Tag | Effect |
|---|---|
| `@skip` | Skip this scenario |
| `@fixme` | Mark as known failure (passes even when failing) |
| `@only` | Run only this scenario (dangerous — never commit) |
| `@slow` | Apply 3× timeout multiplier |
| `@fail` | Expect failure |
| `@retries(n)` | Retry up to n times |
| `@timeout(ms)` | Override timeout for this scenario |
| `@mode:serial` | Run in serial mode (disables parallelism for this feature) |

See the [playwright-bdd special tags reference](../../practice/playwright-bdd/tags-and-filtering.md) for full details.
