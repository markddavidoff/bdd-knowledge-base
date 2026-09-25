---
title: Serenity/JS
description: Full living documentation framework that generates narrative HTML reports from Gherkin scenarios and step results, designed for teams where documentation is the primary deliverable.
sources:
  - web-bdd-living-documentation-behavior-driven-development-aligning-stakeholders-through-living-documentation
  - web-bdd-living-documentation-the-power-of-living-documentation
  - web-bdd-living-documentation-aligning-stakeholders-through-collaboration
---

# Serenity/JS

Serenity/JS is a full living documentation framework, not just a reporter. Where Allure adds history to test results and Cucumber HTML renders a single run, Serenity/JS is designed from the ground up to produce documentation that tells the story of what the system does — using Gherkin scenarios and step-level outcomes as its source material.

The output is a narrative HTML report that reads like a specification document rather than a test run log.

## What Makes It Different

Most BDD reporters treat the feature file as metadata attached to a test run. Serenity/JS inverts this: the scenario is the document, and the test execution is evidence that the document is accurate.

Practical differences:

- **Screenplay pattern** — Serenity/JS encourages the Screenplay pattern for step definitions, where actors perform tasks and ask questions about the system. This produces more readable step-level output in the report.
- **Narrative output** — each scenario renders as a human-readable story with actor names, actions, and outcomes, not raw assertion logs.
- **Business-layer navigation** — reports are organized by capability, feature, and story (not just file paths), making them navigable for product owners.
- **Requirement coverage** — the framework maps scenarios to requirements, giving a view of what percentage of stated requirements have passing evidence.

## Installation

Serenity/JS integrates with Playwright via the `@serenity-js/playwright` and `@serenity-js/cucumber` packages:

```bash
npm install --save-dev \
  @serenity-js/core \
  @serenity-js/playwright \
  @serenity-js/serenity-bdd \
  @serenity-js/web \
  @serenity-js/assertions
```

You also need the Serenity BDD CLI (requires Java 11+) to render the HTML report:

```bash
npx serenity-bdd update   # downloads the CLI jar on first use
```

## Configuration

Serenity/JS is configured via a `serenity.config.ts` file (or inline in `playwright.config.ts`):

```typescript
// serenity.config.ts
import { defineConfig } from '@playwright/test';
import { defineBddConfig } from 'playwright-bdd';
import {
  SerenityBDDReporter,
  StageCrewMemberBuilder,
} from '@serenity-js/serenity-bdd';
import { ArtifactArchiver } from '@serenity-js/core';

const testDir = defineBddConfig({
  features: 'features/**/*.feature',
  steps: 'steps/**/*.ts',
});

export default defineConfig({
  testDir,
  reporter: [
    ['@serenity-js/playwright/reporter', {
      crew: [
        ArtifactArchiver.storingArtifactsAt('./target/site/serenity'),
        new SerenityBDDReporter(),
      ],
    }],
  ],
});
```

!!! note "Output directory"
    By convention Serenity/JS writes to `target/site/serenity/`. The raw JSON artifacts go there first; the CLI renders them into HTML. Add `target/` to `.gitignore`.

## Running and Generating the Report

```bash
# Generate BDD specs and run tests
npx bddgen && npx playwright test

# Render the HTML report from collected artifacts
npx serenity-bdd run --features ./features

# Open the report
open target/site/serenity/index.html
```

The rendered report opens to a dashboard showing requirements, test results by capability, and a scenario-level narrative view.

## Example: Screenplay-Style Step Definition

Serenity/JS step definitions use actor-based language that produces readable report output:

```typescript
import { Given, When, Then } from '@cucumber/cucumber';
import { actorCalled } from '@serenity-js/core';
import { Navigate, Page } from '@serenity-js/web';
import { Ensure, equals } from '@serenity-js/assertions';

Given('{actor} has navigated to the checkout page', async (actor) => {
  await actor.attemptsTo(
    Navigate.to('/checkout'),
  );
});

When('{actor} completes payment with their saved card', async (actor) => {
  await actor.attemptsTo(
    // Payment.withSavedCard() is a custom Interaction
    Payment.withSavedCard(),
  );
});

Then('{actor} should see the order confirmation', async (actor) => {
  await actor.attemptsTo(
    Ensure.that(
      Page.current().title(),
      equals('Order Confirmed')
    ),
  );
});
```

In the rendered report, this appears as: "Alice navigates to the checkout page → completes payment with her saved card → sees the order confirmation." The actor's name and task names become the narrative.

## Example Feature File

```gherkin
Feature: Checkout

  As a returning customer
  I want to complete a purchase using my saved payment method
  So that I can check out quickly without re-entering card details

  Scenario: Successful purchase with a saved card
    Given Alice has navigated to the checkout page
    When Alice completes payment with their saved card
    Then Alice should see the order confirmation
```

## Pros and Cons

**Pros:**

- Most complete "living specification" output of any option in this comparison
- Reports read like requirements documents, not test logs — suitable for PO review
- Requirement coverage view shows what percentage of stated behaviors have passing evidence
- Screenplay pattern enforces clean, readable step definitions
- Open source, no SaaS dependency

**Cons:**

- Heaviest integration of the four tools — requires Java, Serenity CLI, and adopting the Screenplay pattern
- Screenplay pattern has a significant learning curve
- Configuration is more complex than `cucumberReporter('html', ...)`
- Serenity/JS maintains its own conventions that can conflict with Playwright-native patterns
- Smaller ecosystem than Allure; fewer community examples for playwright-bdd specifically

## When to Use

Use Serenity/JS when:

- Documentation is the primary deliverable — e.g., regulated industries where audit trails matter, or consulting engagements where the client receives the report
- The team can invest in learning the Screenplay pattern
- You want requirement coverage metrics, not just pass/fail counts
- The product owner or business stakeholder needs to read the report directly, not just receive a summary

!!! warning "Heavy investment"
    Serenity/JS is the most powerful living documentation option here, but also the most expensive to adopt and maintain. If your team's primary goal is catching regressions quickly, Allure or Cucumber HTML achieves that at a fraction of the setup cost. Serenity/JS pays off when the report itself has external value — to a client, auditor, or compliance reviewer.

## CI Integration

```yaml
- name: Generate BDD specs
  run: npx bddgen

- name: Run BDD tests
  run: npx playwright test

- name: Generate Serenity report
  if: always()
  run: npx serenity-bdd run --features ./features

- name: Upload Serenity report
  if: always()
  uses: actions/upload-artifact@v4
  with:
    name: serenity-report-${{ github.run_number }}
    path: target/site/serenity/
    retention-days: 90
```

## Cross-References

- [Living Documentation Overview](./index.md) — tool comparison table
- [Allure Report](./allure.md) — lighter alternative with history and trends
- [Stakeholder Reporting](./stakeholder-reporting.md) — what stakeholders need to see
- [CI Publishing](./ci-publishing.md) — GitHub Pages deployment
