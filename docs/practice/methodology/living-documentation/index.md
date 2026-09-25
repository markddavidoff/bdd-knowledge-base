---
title: Living Documentation
description: How BDD turns Gherkin scenarios and passing tests into always-current documentation that CI enforces automatically.
sources:
  - web-bdd-living-documentation-behavior-driven-development-aligning-stakeholders-through-living-documentation
  - web-bdd-living-documentation-the-power-of-living-documentation
  - web-bdd-living-documentation-best-practices-for-living-documentation
  - web-bdd-living-documentation-common-pitfalls-and-how-to-avoid-them
  - web-bdd-living-documentation-aligning-stakeholders-through-collaboration
---

# Living Documentation

Living documentation is the end state that BDD is working toward: a body of specification that is simultaneously human-readable, machine-executable, and guaranteed to describe the system as it actually behaves right now. When the CI pipeline is green, the docs are true. When a scenario fails, the docs signal a lie.

## What "Living" Means

Traditional requirements documents are written before development begins and then forgotten. They accumulate inaccuracy silently — there is no mechanism to detect when the prose diverges from the code.

BDD inverts this. The specification exists as Gherkin scenarios that are executed on every commit. A failing scenario is not a test failure; it is a documentation inconsistency. The system enforces its own accuracy.

Three properties make documentation "living":

1. **Executable** — scenarios are backed by automated step definitions. A green build means the documentation is factually correct.
2. **Up to date** — every CI run re-validates the spec. Drift is detected automatically, not in a quarterly review.
3. **Readable** — written in Gherkin (plain language with structure), the docs are legible to product owners, designers, and QA without a technical translation layer.

## The Sync Contract

The sync contract is the agreement that makes living documentation work:

> **Gherkin scenarios + passing step definitions = current truth about system behavior.**

This contract has two sides:

- **Developers** must not change behavior without updating the feature file. A scenario that passes but no longer reflects the real behavior is rotten documentation.
- **CI must hard-fail** on undefined steps and on test failures. Skipped or soft-ignored failures break the contract.

The contract is not aspirational — it must be enforced mechanically. Tooling that lets tests pass while scenarios are skipped or pending defeats the entire purpose.

## The "Rotten Documentation" Failure Mode

Rotten documentation occurs when tests pass but the Gherkin no longer describes what the system actually does. Common causes:

- Behavior changed, scenario not updated ("we'll fix the spec later")
- Scenarios marked `@skip` or `@wip` indefinitely
- Step definitions that always pass regardless of application state (empty assertions)
- Scenarios that cover removed features never deleted

Rotten docs are worse than no docs: they provide false confidence to stakeholders and mislead new team members.

!!! warning "The skip trap"
    `@skip` is a quarantine tag for flaky tests under active repair — not a way to silence inconvenient failures. Any scenario that has been `@skip`-ped for more than one sprint should be treated as a documentation gap and escalated.

## CI as the Enforcer

CI is what transforms the sync contract from a social agreement into a hard guarantee. The pipeline enforces liveness by:

1. Running `bddgen` to detect undefined steps — failing the build if any exist
2. Running all scenarios — failing the build on any failure
3. Publishing the HTML report as a build artifact so the current spec is always accessible

```yaml
# Minimal GitHub Actions enforcement
- name: Generate BDD specs
  run: npx bddgen

- name: Run scenarios
  run: npx playwright test

- name: Upload report
  uses: actions/upload-artifact@v4
  with:
    name: cucumber-report
    path: cucumber-report/
```

See [CI Publishing](./ci-publishing.md) for a complete workflow with GitHub Pages deployment.

## Tool Comparison

Choosing a reporting tool determines how living the documentation feels to stakeholders. The options differ significantly in complexity, hosting requirements, and what they show.

| Tool | Complexity | Hosting | History / Trends | Cost | Best for |
|------|-----------|---------|-----------------|------|----------|
| [Cucumber HTML](./cucumber-html.md) | Zero | CI artifact or static host | None — single run only | Free | Small teams, getting started |
| [Allure Report](./allure.md) | Medium | Self-hosted CLI or Allure TestOps SaaS | Yes — history, trends, retries | Free CLI; TestOps paid | Teams wanting trend analysis |
| [Serenity/JS](./serenity-js.md) | High | Self-hosted HTML output | Partial — narrative per run | Free (open source) | Teams where docs ARE the deliverable |
| [Testomat.io](./testomat.md) | Low (SaaS) | Managed | Yes — coverage over time | Paid SaaS | Zero-ops teams |

!!! tip "Start simple"
    Begin with Cucumber HTML. It requires zero additional infrastructure and produces an immediately readable report. Upgrade to Allure or Testomat.io once the team has established the BDD habit and wants historical trends.

## What Living Documentation Is Not

- It is not a wiki. Wikis go stale; living docs cannot (if CI is enforced).
- It is not a test report. A test report tells you pass/fail counts. Living documentation tells you what the system *does*.
- It is not coverage. 100% scenario coverage does not mean 100% behavior coverage. Scenarios must be written to specify meaningful behaviors, not to hit coverage numbers.

## Cross-References

- [Stakeholder Reporting](./stakeholder-reporting.md) — what to show non-technical readers and how
- [CI Publishing](./ci-publishing.md) — full GitHub Actions workflow for publishing reports
- [Cucumber HTML Reporter](./cucumber-html.md) — zero-config starting point
- [Allure Report](./allure.md) — history and trend analysis
- [Serenity/JS](./serenity-js.md) — full living specification framework
- [Testomat.io](./testomat.md) — managed SaaS option
- [Three Amigos](../three-amigos.md) — the collaboration that produces the scenarios
- [Example Mapping](../example-mapping.md) — the discovery technique before writing scenarios
