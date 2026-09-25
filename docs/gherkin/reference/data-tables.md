---
title: Data Tables
description: Complete reference for Gherkin data tables — raw, hash, row, rowsHash, transposed — plus DataTableType transformers and the base-fixture + variation pattern.
sources:
  - git-playwright-bdd-repo-docs-writing-steps-data-tables-data-tables
  - git-cucumber-js-docs-supportfiles-datatableinterface-data-table-interface
  - web-cucumber-api-reference-data-tables
  - git-gherkin-parser-testdata-good-datatables-feature-feature-datatables
---

# Data Tables

A **data table** attaches structured tabular data to a single Gherkin step. Unlike a Scenario Outline (which multiplies a scenario for each row), a data table is passed to *one* step as an argument, letting that step iterate over or destructure the rows itself.

```gherkin
Feature: Bulk user import

  Scenario: Import multiple users
    Given the following users exist:
      | name    | role  | plan       |
      | Alice   | admin | enterprise |
      | Bob     | user  | pro        |
      | Charlie | user  | free       |
```

---

## Table access methods

The `DataTable` object passed to the step definition exposes five methods depending on whether the table has a header row.

### `hashes()` — header row as keys

Returns an array of objects. The **first row** becomes property names; subsequent rows become values. Use this when your table has a meaningful header.

```gherkin
When I fill the login form with:
  | label    | value    |
  | Username | vitalets |
  | Password | 12345    |
```

```ts
import { createBdd, DataTable } from 'playwright-bdd';

const { When } = createBdd();

When('I fill the login form with:', async ({ page }, table: DataTable) => {
  for (const row of table.hashes()) {
    // row = { label: 'Username', value: 'vitalets' }
    await page.getByLabel(row.label).fill(row.value);
  }
});
```

### `rows()` — with header, body only

Returns a 2-D array **excluding the first row**. Useful when you need column access but will destructure manually.

```ts
for (const [name, role, plan] of table.rows()) {
  await createUser({ name, role, plan });
}
```

### `raw()` — no header, everything as strings

Returns the entire table as a 2-D array including any header row. Use when the table carries no semantic header, or when you want to process all rows uniformly.

```gherkin
Given the allowed HTTP methods are:
  | GET  |
  | POST |
  | PUT  |
```

```ts
Given('the allowed HTTP methods are:', async ({}, table: DataTable) => {
  const methods = table.raw().flat(); // ['GET', 'POST', 'PUT']
  expect(methods).toContain('GET');
});
```

### `rowsHash()` — two-column key/value

Treats each row as a key → value pair (first column = key, second column = value). Useful for config-like structures or single-entity attribute lists.

```gherkin
Given the organization settings are:
  | plan           | enterprise |
  | seatLimit      | 500        |
  | billingEnabled | true       |
```

```ts
Given('the organization settings are:', ({}, table: DataTable) => {
  const settings = table.rowsHash();
  // { plan: 'enterprise', seatLimit: '500', billingEnabled: 'true' }
  expect(settings.plan).toBe('enterprise');
});
```

### `transpose()` — vertical tables

Returns a new `DataTable` with rows and columns swapped. Helpful when vertical orientation reads more naturally for wide attribute sets.

```gherkin
Given the product attributes are:
  | name     | Acme Widget |
  | price    | 9.99        |
  | category | hardware    |
```

```ts
// table.transpose().hashes() gives:
// [{ name: 'Acme Widget', price: '9.99', category: 'hardware' }]
```

---

## `DataTableType` — transforming tables to domain objects

Rather than calling `table.hashes()` inside every step, register a `DataTableType` to have Cucumber automatically convert a table into a typed domain object.

```ts
import { defineDataTableType } from 'playwright-bdd';

interface User {
  name: string;
  role: 'admin' | 'user';
  plan: string;
}

defineDataTableType({
  typeName: 'user',
  from: (row: Record<string, string>): User => ({
    name: row.name,
    role: row.role as 'admin' | 'user',
    plan: row.plan,
  }),
});
```

Once registered, any step that declares `User[]` as its last parameter receives the transformed objects directly:

```ts
Given('the following users exist:', async ({ db }, users: User[]) => {
  await db.users.createMany(users);
});
```

!!! tip "TableEntryTransformer vs. TableTransformer"
    `defineDataTableType` with a row-level `from` function is a **TableEntryTransformer** — it maps one row at a time. For whole-table logic (e.g., computing column aggregates), use a **TableTransformer** with `fromTable`.

---

## Base-fixture + variation table pattern

This pattern combines an Object Mother named fixture with a data table that overrides specific attributes. It keeps Gherkin readable while allowing per-scenario variation without verbose per-row detail.

```gherkin
Feature: Seat-limit enforcement

  Scenario: Enterprise plan allows 500 seats by default
    Given an "enterprise" organization exists
    And the following seat overrides apply:
      | seatLimit |
      | 10        |
    When a new member joins
    Then the member is accepted
```

```ts
import { createBdd, DataTable } from 'playwright-bdd';
import { orgMother } from '../support/org-mother';

const { Given } = createBdd();

Given(
  'an {string} organization exists',
  async ({ db, $testInfo }, planName: string) => {
    const base = orgMother(planName);       // canonical defaults from Object Mother
    $testInfo.attach('org-base', { body: JSON.stringify(base) });
    await db.orgs.create(base);
  }
);

Given(
  'the following seat overrides apply:',
  async ({ db }, table: DataTable) => {
    const overrides = table.hashes()[0];    // { seatLimit: '10' }
    await db.orgs.updateLatest({ seatLimit: Number(overrides.seatLimit) });
  }
);
```

!!! note "Why this pattern?"
    It avoids repeating every field for each scenario. The Object Mother supplies sensible defaults; the table expresses *only what matters* for the scenario's intent.

---

## When to use a table vs. inline parameters

| Situation | Prefer |
|---|---|
| 2–3 distinct values, unrelated fields | Inline `{string}` parameters |
| 4+ fields or repeated structure | Data table with `hashes()` |
| Multiple entities of the same type | Data table with `hashes()` or `DataTableType` |
| Config-like key/value pairs | Data table with `rowsHash()` |
| Single multi-attribute entity | `rowsHash()` or transposed table |

!!! warning "Tables make step text generic"
    A step that accepts a data table can't be read in isolation — the table is the data. Keep step text verb-focused ("the following users exist:") so the Gherkin sentence still reads naturally.

---

## Cross-references

- [Doc Strings](doc-strings.md) — for multi-line text payloads instead of structured data
- [Custom Parameter Types](custom-parameter-types.md) — for named domain objects in step text
- [Named Test Data Catalog](../best-practices/named-test-data-catalog.md) — Object Mother + Builder pattern
