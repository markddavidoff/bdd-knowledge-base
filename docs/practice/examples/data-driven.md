---
title: Data-Driven Scenarios — playwright-bdd
description: Complete playwright-bdd patterns for Scenario Outline with Examples tables and defineDataTableType for structured row-to-domain-object transformation.
sources:
  - web-thegreenreport-custom-parameter-types-the-green-report-https-www-thegreenreport-blog
  - git-playwright-bdd-repo-docs-writing-steps-playwright-style-custom-fixtures
---

# Data-Driven Scenarios — playwright-bdd

playwright-bdd supports both data-driven approaches from Gherkin:

- **Scenario Outline + Examples** — one scenario template, many rows, each row becomes a separate test.
- **Data Tables + `defineDataTableType`** — structured multi-column input passed to a single step, transformed into typed objects.

## Scenario Outline with Examples

Each row in the `Examples` table generates an independent test. playwright-bdd names them by row values automatically.

### Feature file

```gherkin
Feature: Pricing calculator

  Scenario Outline: Monthly cost for each plan
    Given I am on the pricing page
    When I select the <plan> plan with <seats> seats
    Then the monthly total is <expected-total>

    Examples:
      | plan       | seats | expected-total |
      | free       | 1     | $0.00          |
      | pro        | 5     | $149.75        |
      | pro        | 10    | $299.50        |
      | enterprise | 50    | $2,500.00      |

  @error-path
  Scenario Outline: Invalid seat counts are rejected
    Given I am on the pricing page
    When I enter <seats> seats for the <plan> plan
    Then I see the error "<error>"

    Examples:
      | plan | seats | error                          |
      | free | 4     | Free plan is limited to 3 seats |
      | pro  | 0     | Seat count must be at least 1   |
```

### Step definitions

```typescript
// features/steps/pricing.steps.ts
import { expect } from '@playwright/test';
import { createBdd } from 'playwright-bdd';

const { Given, When, Then } = createBdd();

Given('I am on the pricing page', async ({ page }) => {
  await page.goto('/pricing');
});

When(
  'I select the {word} plan with {int} seats',
  async ({ page }, plan: string, seats: number) => {
    await page.getByRole('tab', { name: plan }).click();
    await page.getByLabel('Number of seats').fill(String(seats));
    await page.getByRole('button', { name: 'Calculate' }).click();
  }
);

Then(
  'the monthly total is {string}',
  async ({ page }, expectedTotal: string) => {
    await expect(
      page.getByRole('region', { name: 'Total' }).getByRole('heading')
    ).toHaveText(expectedTotal);
  }
);

When(
  'I enter {int} seats for the {word} plan',
  async ({ page }, seats: number, plan: string) => {
    await page.getByRole('tab', { name: plan }).click();
    await page.getByLabel('Number of seats').fill(String(seats));
    await page.getByRole('button', { name: 'Calculate' }).click();
  }
);

Then('I see the error {string}', async ({ page }, error: string) => {
  await expect(page.getByRole('alert')).toHaveText(error);
});
```

!!! note "Each row is an independent test"
    playwright-bdd generates a separate `.spec.ts` test for each Examples row. Failures in one row do not block other rows. You can run a single row with `--grep "pro | 5"`.

## Data Tables + defineDataTableType

Use `defineDataTableType` when a step receives a structured table and you want to transform each row into a typed domain object automatically.

### Feature file

```gherkin
Feature: Bulk user import

  Scenario: Import users from a CSV-like table
    Given the following users are imported:
      | name          | email                   | role   |
      | Alice Johnson | alice@example.com       | editor |
      | Bob Smith     | bob@example.com         | viewer |
      | Carol Chen    | carol@example.com       | admin  |
    Then 3 users appear in the directory
    And "Alice Johnson" has the editor role

  Scenario: Import with invalid data shows errors
    Given the following users are imported:
      | name | email        | role    |
      | Dan  | not-an-email | invalid |
    Then 2 validation errors are reported
```

### Define the type transformer

```typescript
// features/support/data-table-types.ts
import { defineDataTableType } from 'playwright-bdd';

export interface ImportedUser {
  name: string;
  email: string;
  role: 'admin' | 'editor' | 'viewer';
}

defineDataTableType({
  name: 'importedUser',
  from: {
    // Maps each table row (object with string values) to an ImportedUser
    tableEntry(entry: Record<string, string>): ImportedUser {
      const role = entry.role as ImportedUser['role'];
      if (!['admin', 'editor', 'viewer'].includes(role)) {
        throw new Error(`Unknown role: "${role}"`);
      }
      return {
        name: entry.name,
        email: entry.email,
        role,
      };
    },
  },
});
```

### fixtures.ts — import the type file

```typescript
// features/steps/fixtures.ts
import { test as base, createBdd } from 'playwright-bdd';

// Import to register the DataTableType before any step runs
import '../support/data-table-types';

type Fixtures = {
  importResults: { imported: number; errors: string[] } | null;
};

export const test = base.extend<Fixtures>({
  importResults: async ({}, use) => {
    await use(null);
  },
});

export const { Given, When, Then } = createBdd(test);
```

### Step definitions using the transformer

```typescript
// features/steps/import.steps.ts
import { expect } from '@playwright/test';
import { Given, Then } from './fixtures';
import type { ImportedUser } from '../support/data-table-types';

Given(
  'the following users are imported:',
  async ({ page, importResults }, users: ImportedUser[]) => {
    // 'users' is already an array of ImportedUser objects — no manual parsing
    await page.goto('/admin/import');

    for (const user of users) {
      await page.getByRole('button', { name: 'Add row' }).click();
      const lastRow = page.getByRole('row').last();
      await lastRow.getByLabel('Name').fill(user.name);
      await lastRow.getByLabel('Email').fill(user.email);
      await lastRow.getByLabel('Role').selectOption(user.role);
    }

    await page.getByRole('button', { name: 'Import' }).click();

    // Capture results for subsequent steps
    const statusText = await page.getByRole('status').textContent();
    const importedMatch = statusText?.match(/(\d+) imported/);
    const errorMatch = statusText?.match(/(\d+) errors/);

    Object.assign(importResults!, {
      imported: parseInt(importedMatch?.[1] ?? '0', 10),
      errors: [],  // simplified — in practice parse the error list
    });
  }
);

Then('{int} users appear in the directory', async ({ page }, count: number) => {
  await page.goto('/admin/users');
  const rows = page.getByRole('row').filter({ hasNot: page.getByRole('columnheader') });
  await expect(rows).toHaveCount(count);
});

Then(
  '{string} has the editor role',
  async ({ page }, name: string) => {
    await page.goto('/admin/users');
    const row = page.getByRole('row', { name });
    await expect(row.getByRole('cell', { name: 'editor' })).toBeVisible();
  }
);

Then('{int} validation errors are reported', async ({ page }, count: number) => {
  const errors = page.getByRole('listitem').filter({ hasText: 'Error' });
  await expect(errors).toHaveCount(count);
});
```

## Comparison: Outline vs. DataTable

| | Scenario Outline | Data Table |
|---|---|---|
| Each row is... | A separate test | Input to one scenario |
| Best for | Same behavior, different parameter values | Bulk/batch operations, list setup |
| Failures | Per-row independence | All-or-nothing (one scenario) |
| Gherkin readability | High when rows are short | High when columns model a record |
| playwright-bdd generation | One `.spec` test per row | One test total |

!!! tip "Avoid combinatorial explosion"
    Scenario Outline rows multiply your test count. 3 parameters × 4 values each = 64 rows if you use all combinations. Only include rows that represent distinct equivalence classes, not every possible value.

## Related

- [Scenario Outline reference](../../gherkin/reference/scenario-outline.md)
- [Data Tables reference](../../gherkin/reference/data-tables.md)
- [Gherkin data-driven examples](../../gherkin/examples/data-driven.md) — feature file only
