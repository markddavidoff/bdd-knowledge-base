---
title: Stakeholder Reporting
description: What non-technical stakeholders actually need to see from BDD results, which reporter views are safe to share, and how to avoid the "green = done" trap.
sources:
  - web-bdd-living-documentation-aligning-stakeholders-through-collaboration
  - web-bdd-living-documentation-behavior-driven-development-aligning-stakeholders-through-living-documentation
  - web-bdd-living-documentation-measuring-success
  - web-bdd-living-documentation-best-practices-for-living-documentation
  - web-bdd-living-documentation-common-pitfalls-and-how-to-avoid-them
---

# Stakeholder Reporting

The purpose of living documentation is to align every stakeholder — product owner, business analyst, developer, QA — on what the system currently does. But not all reporter output is equally readable by a non-technical audience. Choosing the wrong view for the wrong audience creates confusion rather than confidence.

## What Stakeholders Actually Need

Non-technical stakeholders (product owners, business analysts, programme managers) need to answer three questions:

1. **Does the system do what we agreed it should do?** — Not "did the tests pass" but "which behaviors are confirmed working."
2. **Is the suite getting healthier or sicker over time?** — A single green run tells you today is fine. A trend tells you whether the project is accumulating risk.
3. **Where are the gaps?** — Which behaviors are specified but not yet implemented? Which are implemented but not specified?

A raw test run log answers none of these questions well. A well-configured Allure Overview tab or a Serenity/JS narrative view can answer all three.

## Which Reporter Views Are Stakeholder-Safe

### Allure — Overview Tab

The Allure Overview tab is the most immediately stakeholder-ready view in the self-hosted world. It shows:

- Total scenarios: passed / failed / broken / skipped counts
- Suite donut chart: at-a-glance health
- Trend widget: pass rate over the last N runs

!!! tip "Share the Overview URL, not the full report"
    Send stakeholders a direct link to the Overview page. The Behaviors tab (step-level details) and the Timeline tab (parallel execution) are useful for developers but tend to overwhelm POs.

### Serenity/JS — Narrative View

The Serenity/JS report is the most complete stakeholder view. The requirements page shows each stated capability with evidence counts: how many scenarios specify it, how many pass. This answers "does the system do what we agreed?" directly.

The narrative scenario view reads like a specification: "Alice navigates to checkout, completes payment, sees the confirmation." This is legible to a business stakeholder without any BDD or testing background.

### Cucumber HTML — Not Directly Stakeholder-Safe

The Cucumber HTML report shows step-level pass/fail for each scenario. It is useful for a PO who wants to verify a specific feature, but it is not suitable as a sprint health summary. There is no summary view, no trend data, and the step granularity can feel like implementation detail.

Use Cucumber HTML for: developer review, debugging, and quick local verification. Use Allure or Serenity/JS for: sprint reviews, stakeholder demos, and programme reporting.

### Testomat.io — Built-In Stakeholder View

Testomat.io's web dashboard includes a separate stakeholder-oriented view with coverage metrics and trend graphs. Share the project URL with the relevant access level.

## What a Sprint Test Summary Should Look Like

A product owner reviewing test results at the end of a sprint does not need to read step definitions. They need a summary that maps to the stories and acceptance criteria they wrote.

A useful sprint summary for a PO:

```
Sprint 23 — Test Results Summary
=================================
Stories with all acceptance criteria passing:  14 / 17
Stories with ≥1 failing scenario:              3 / 17

Failing stories:
  - US-441: Invoice PDF generation (1 scenario failing — rendering timeout)
  - US-452: Bulk user import (2 scenarios failing — CSV parser edge cases)
  - US-461: Webhook retry logic (1 scenario @wip — spec agreed, not yet implemented)

Trend: 14-day pass rate moved from 78% → 88%. Three regressions introduced and
fixed during the sprint. Zero open @quarantine scenarios.
```

This format:
- Maps to stories the PO owns
- Distinguishes failures (regressions) from `@wip` (in-progress)
- Reports a trend, not just a point in time
- Is short enough to read in 30 seconds

!!! note "Generate this from CI"
    No BDD reporter produces this summary format automatically. Generate it from the JSON output of your reporter (Allure JSON, Cucumber JSON) using a small script, or use Testomat.io's project dashboard which approximates this view.

## The "Green = Done" Trap

A passing test suite does not mean a complete or correct system. The "green = done" trap occurs when stakeholders interpret a green CI build as confirmation that all agreed behaviors are implemented.

Three ways it manifests:

1. **Scenarios cover happy paths only.** The suite is green because no one wrote scenarios for the error paths, edge cases, or rollback behaviors.
2. **The spec lags the story.** The story was refined in Three Amigos, but the feature file was never updated to reflect the refined acceptance criteria. The old, looser scenarios pass.
3. **`@skip` inflation.** Scenarios that would fail are silently excluded. The suite is green but the exclusion list is growing.

Counter-measures:

- Track `@wip` + `@skip` + `@quarantine` counts as a health metric alongside pass rate. A rising quarantine count is a warning signal even if the "main" suite is green.
- Include negative-path and edge-case scenarios in the Definition of Done.
- Review the feature file diff in every PR that touches behavior — the scenario is the acceptance criterion.

## Reporting on Scenario Health Trends

Pass/fail at a point in time is the minimum. Health trends over time are what enable confident decision-making.

Metrics worth tracking per sprint:

| Metric | Why it matters |
|--------|---------------|
| 14-day pass rate | Distinguishes a one-off failure from a degrading suite |
| `@quarantine` count | Measures flakiness accumulation |
| Mean time to green (after failure) | Indicates how fast regressions are addressed |
| Coverage: scenarios per story | Reveals under-specified areas |
| Undefined step count | Detects spec-code drift early |

Allure's trend widget provides the 14-day pass rate automatically if history is preserved between runs (see [Allure Report](./allure.md) for history setup). The other metrics require either Testomat.io or a custom script over the JSON output.

## Making BDD Results Consumable Enough to Justify the Investment

BDD has a real overhead cost: writing feature files, maintaining step definitions, running Three Amigos sessions. Teams lose confidence in the investment when the output is a report that only developers read.

The payoff becomes visible to stakeholders when:

- The sprint review includes a results URL, not a verbal "tests passed"
- The PO can verify their own acceptance criteria passed without asking a developer
- A regression is caught before release and the failing scenario names the exact story affected
- New team members onboard by reading the feature files, not by asking colleagues how the system works

The reporting tool is a vehicle for making these outcomes visible. Choose the tool that best fits your team's reporting needs — but in every case, ensure the reports are actually shared with stakeholders, not just produced and archived.

## Cross-References

- [Living Documentation Overview](./index.md) — what living documentation means and the tool comparison table
- [Allure Report](./allure.md) — Overview tab and trend configuration
- [Serenity/JS](./serenity-js.md) — narrative view for stakeholder review
- [Testomat.io](./testomat.md) — managed stakeholder dashboard
- [CI Publishing](./ci-publishing.md) — making reports accessible via a URL
- [Three Amigos](../three-amigos.md) — the collaboration that produces acceptance criteria
