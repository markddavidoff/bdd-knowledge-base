---
title: Tags — Lifecycle
description: Reference for lifecycle tags in Gherkin — @wip, @skip, @quarantine, and @only/@focus — including the quarantine workflow and PR conventions.
sources:
  - web-cucumber-api-reference-tags
  - git-playwright-bdd-repo-docs-writing-features-special-tags-skip-fixme
  - git-playwright-bdd-repo-docs-writing-features-special-tags-only
  - git-playwright-bdd-repo-docs-writing-features-special-tags-special-tags
  - git-cucumber-js-docs-filtering-tags
---

# Tags — Lifecycle

Lifecycle tags signal the **status of a scenario in the development process** — whether it is being written, deliberately skipped, isolated from the suite, or temporarily focused. They are transient: every lifecycle tag should have a documented exit condition and should not stay on a scenario indefinitely.

---

## `@wip` — work in progress

Marks a scenario that is being actively written or whose step definitions are not yet implemented. A `@wip` scenario is expected to fail; it should never appear green in CI on the main branch.

```gherkin
@wip
Scenario: Refund a cancelled subscription
  Given a "pro" organization with a cancelled subscription
  When the billing system processes the monthly run
  Then the prorated refund is issued within 24 hours
```

**Convention:**
- `@wip` scenarios are excluded from the main CI run by default (`not @wip` in your tag filter).
- A separate CI job or pre-push hook may run `@wip` scenarios in "pending" mode to confirm they are *still* failing (not accidentally passing due to incidental coverage).
- Remove `@wip` before merging — treat it as a PR checklist item.

!!! warning "Don't let @wip age"
    A `@wip` scenario older than one sprint is a red flag. Either the scenario was abandoned (delete it), or it is blocked (add a ticket reference and convert to `@skip` with a reason).

---

## `@skip` / `@fixme` — known intentional skip

Marks a scenario that should be **excluded from the current run** with a documented reason. Unlike `@wip`, a `@skip` scenario is assumed to be otherwise complete — it is deliberately bypassed.

```gherkin
# Skipped until JIRA-4421 is resolved: Stripe webhook signature changes
@skip
Scenario: Webhook signature validation on payment confirmation
  Given a valid Stripe webhook arrives
  When the system processes it
  Then the order status updates to "paid"
```

**playwright-bdd behaviour:**

`@skip` causes playwright-bdd to mark the scenario as skipped in Playwright's test runner (equivalent to `test.skip()`). `@fixme` has the same runtime effect but signals "known broken" rather than "intentionally bypassed."

```gherkin
@fixme
Scenario: Multi-currency rounding edge case
  # Tracked in JIRA-5001 — rounding logic incorrect for JPY
  Given a cart with 3 items priced in JPY
  When checkout completes
  Then the total is rounded correctly
```

**PR convention:**
- Every `@skip` or `@fixme` must have a comment explaining *why* and a ticket reference.
- CI should report the count of skipped scenarios; an increase requires justification.

---

## `@quarantine` — flaky, isolated from the suite

A quarantined scenario is one that **fails intermittently** due to timing, external dependencies, or non-deterministic test data. Rather than deleting a valuable scenario or letting it poison the CI signal, quarantine isolates it.

```gherkin
@quarantine
Scenario: Send welcome email within 5 seconds of signup
  # Flaky under load: email delivery is non-deterministic in staging
  # Quarantined 2026-03-14 — tracked in JIRA-6102
  Given a new user signs up
  Then the welcome email is received within 5 seconds
```

### The quarantine workflow

1. **Identify the flaky scenario.** Consistent failure rate >5% across 10 runs qualifies.
2. **Tag it `@quarantine`.** Add a comment with the date, reason, and ticket.
3. **Exclude from the main CI run** (`not @quarantine` in your tag expression).
4. **Create a separate quarantine CI job** that runs `@quarantine` scenarios on a schedule (e.g., nightly). This confirms the scenario is still valid and may reveal when the flakiness resolves.
5. **Fix the root cause.** Flakiness usually indicates a real problem: a missing wait, a shared state leak, or a brittle timing assertion.
6. **Remove `@quarantine`** once the fix is verified across 20+ consecutive green runs.

!!! warning "Quarantine is not permanent parking"
    A quarantined scenario older than 30 days without a fix in progress should trigger a team discussion: fix it, rewrite it, or delete it. Quarantine queues grow silently and become invisible technical debt.

### What makes a scenario flaky?

Common causes:
- Missing `await` on async operations
- Time-dependent assertions (use fixed fixtures rather than wall-clock time)
- Shared DB state between parallel scenarios (see [Test Isolation](../../practice/playwright-bdd/test-isolation.md))
- External service rate limits or latency spikes in staging
- Race conditions between UI updates and assertions

---

## `@only` / `@focus` — local-run filter (danger zone)

`@only` (playwright-bdd) or `@focus` (some runners) restricts the test run to **only** the tagged scenario or feature. It is a local development accelerator — equivalent to `test.only()` in Playwright.

```gherkin
@only
Scenario: Debug the specific broken flow
  Given I am on the checkout page
  When I apply an invalid coupon
  Then an error message appears
```

!!! warning "@only committed to a branch = CI failure"
    If `@only` is committed and pushed, your CI pipeline runs only the tagged scenario — silently passing everything else. This is a footgun that makes PRs appear green when they are not. **Every project must enforce `not @only` in its main CI tag expression**, and ideally fail the pipeline if `@only` appears in any checked-in feature file.

    Add this to your CI configuration:
    ```bash
    # Fail fast if @only appears in any feature file
    grep -r "@only" features/ && echo "ERROR: @only tag found in feature files" && exit 1
    ```

**When `@only` is acceptable:**
- Local debugging only, never committed.
- In a throwaway branch that will be squash-merged with the tag removed.

**Safer alternative:** Use Playwright's `--grep` filter to run a single scenario by name instead of tagging the file.

```bash
npx playwright test --grep "Debug the specific broken flow"
```

---

## Summary: lifecycle tags at a glance

| Tag | Who adds it | CI behaviour | Exit condition |
|---|---|---|---|
| `@wip` | Developer actively writing | Excluded from main run | Remove before merge |
| `@skip` | Developer/triage | Excluded; shown as skipped | Remove when ticket resolves |
| `@fixme` | Developer | Excluded; shown as fixme | Remove when bug is fixed |
| `@quarantine` | Team, after repeated flakiness | Excluded from main; separate nightly run | Remove after 20 clean runs |
| `@only` | Developer for local debug | **Must never reach CI** | Remove before commit |

---

## Cross-references

- [Tags — Classification](tags-classification.md) — `@smoke`, `@regression`, `@e2e`, etc.
- [Tag Governance](../best-practices/tag-taxonomy.md) — enforcing tag conventions
- [CI Integration](../../practice/spec-lifecycle/ci-running.md) — filtering expressions in CI config
