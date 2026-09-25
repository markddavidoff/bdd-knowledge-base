---
title: Writing Steps
description: Three step definition styles in playwright-bdd — Playwright style (createBdd), Cucumber style (BddWorld), and Decorator style (@Fixture/@Given/@When/@Then).
sources:
  - git-playwright-bdd-repo-docs-getting-started-write-first-test-write-first-test
  - git-playwright-bdd-repo-docs-getting-started-add-fixtures-add-fixtures
  - git-playwright-bdd-repo-docs-writing-steps-cucumber-style-cucumber-style
  - git-playwright-bdd-repo-docs-writing-steps-cucumber-style-step-patterns
  - git-playwright-bdd-repo-docs-writing-steps-decorators-decorators
  - git-playwright-bdd-repo-docs-writing-steps-decorators-multiple-decorators-per-method
  - git-playwright-bdd-repo-docs-writing-steps-decorators-accessing-bdd-fixtures
  - git-playwright-bdd-repo-docs-faq-faq
---

# Writing Steps

playwright-bdd supports three step definition styles. Each is appropriate in different circumstances. This page describes all three, with complete examples showing the same scenario implemented in each style, and a comparison table to guide which to choose.

---

## The Scenario Used in All Examples

```gherkin
# features/todo.feature
Feature: Todo App

  Scenario: Adding a todo item
    Given I am on the todo page
    When I add todo "Buy milk"
    Then the todo list has 1 item
```

---

## Style 1 — Playwright Style (`createBdd()`)

This is the **canonical modern approach** and the one playwright-bdd was designed around. Step definitions are arrow functions whose first argument is a fixture destructuring pattern. No `this`, no classes, no world object.

```ts
// fixtures.ts
import { test as base, createBdd } from 'playwright-bdd';

export const test = base.extend<{}>({});  // extend with your custom fixtures
export const { Given, When, Then } = createBdd(test);
```

```ts
// steps/todo.steps.ts
import { expect } from '@playwright/test';
import { Given, When, Then } from '../fixtures.js';

Given('I am on the todo page', async ({ page }) => {
  await page.goto('https://demo.playwright.dev/todomvc/');
});

When('I add todo {string}', async ({ page }, text: string) => {
  await page.locator('input.new-todo').fill(text);
  await page.locator('input.new-todo').press('Enter');
});

Then('the todo list has {int} item', async ({ page }, count: number) => {
  await expect(page.getByTestId('todo-item')).toHaveCount(count);
});
```

**Key characteristics:**

- Arrow functions — no `this` binding issues
- First argument is always the fixture object (`{ page }`, `{ page, myCustomFixture }`, etc.)
- Step parameters follow the fixture object: `async ({ page }, text: string)`
- Type-safe: TypeScript enforces that only declared fixtures are requested
- State shared between steps via fixtures, not module-level variables

!!! tip "No fixture needed? Use `{}`"
    When a step uses no fixtures, the first argument must still be an empty destructuring pattern:

    ```ts
    Given('the app is running', async ({}, version: string) => {
      // no fixtures needed here
    });
    ```

    ESLint's `no-empty-pattern` rule flags `{}`. Disable it for step files — Playwright enforces this syntax.

---

## Style 2 — Cucumber Style (Legacy / Migration)

Cucumber-style steps are compatible with CucumberJS step definitions. They use a `World` object (accessible via `this`) instead of fixture injection. Step functions **must be declared with `function` keyword** — arrow functions break `this` binding.

This style is useful when:
- Migrating an existing CucumberJS test suite to playwright-bdd
- Your team is more familiar with the CucumberJS world model
- You prefer class-based state management

```ts
// world.ts
import { Page } from '@playwright/test';

export class MyWorld {
  constructor(public page: Page) {}

  async openTodoPage() {
    await this.page.goto('https://demo.playwright.dev/todomvc/');
  }
}
```

```ts
// fixtures.ts
import { test as base, createBdd } from 'playwright-bdd';
import { MyWorld } from './world.js';

export const test = base.extend<{ world: MyWorld }>({
  world: async ({ page }, use) => {
    const world = new MyWorld(page);
    await use(world);
  },
});

export const { Given, When, Then } = createBdd(test, {
  worldFixture: 'world',
});
```

```ts
// steps/todo.steps.ts
import { expect } from '@playwright/test';
import { Given, When, Then } from '../fixtures.js';

Given('I am on the todo page', async function () {
  await this.openTodoPage();          // 'this' is the MyWorld instance
});

When('I add todo {string}', async function (text: string) {
  await this.page.locator('input.new-todo').fill(text);
  await this.page.locator('input.new-todo').press('Enter');
});

Then('the todo list has {int} item', async function (count: number) {
  await expect(this.page.getByTestId('todo-item')).toHaveCount(count);
});
```

!!! warning "Arrow functions break Cucumber style"
    `async () => { this.page ... }` will throw `TypeError: Cannot read properties of undefined (reading 'page')`. Always use `async function()` with Cucumber style.

---

## Style 3 — Decorator Style (POM Integration)

Decorator style embeds step definitions directly in Page Object Model classes using TypeScript 5 decorators. This keeps your POM and its step definitions co-located.

Requires `"experimentalDecorators": true` in `tsconfig.json`. See [TypeScript Configuration](typescript-config.md).

```ts
// pages/TodoPage.ts
import { Page, expect } from '@playwright/test';
import { Fixture, Given, When, Then } from 'playwright-bdd/decorators';

export @Fixture('todoPage') class TodoPage {
  constructor(public page: Page) {}

  @Given('I am on the todo page')
  async open() {
    await this.page.goto('https://demo.playwright.dev/todomvc/');
  }

  @When('I add todo {string}')
  async addTodo(text: string) {
    await this.page.locator('input.new-todo').fill(text);
    await this.page.locator('input.new-todo').press('Enter');
  }

  @Then('the todo list has {int} item')
  async checkCount(count: number) {
    await expect(this.page.getByTestId('todo-item')).toHaveCount(count);
  }
}
```

```ts
// fixtures.ts
import { test as base } from 'playwright-bdd';
import { TodoPage } from './pages/TodoPage.js';

export const test = base.extend<{ todoPage: TodoPage }>({
  todoPage: ({ page }, use) => use(new TodoPage(page)),
});
```

```ts
// playwright.config.ts
const testDir = defineBddConfig({
  features: 'features/**/*.feature',
  steps: 'fixtures.ts',  // fixtures.ts imports TodoPage which has decorators
});
```

**Decorator notes:**

- `@Fixture('todoPage')` binds the class to the `todoPage` Playwright fixture
- Each `@Given`, `@When`, `@Then` registers a step pointing to that method
- Multiple decorators per method are supported for natural language variations:

```ts
@When('I add todo {string}')
@When('I create a new todo {string}')
async addTodo(text: string) { ... }
```

- Decorator steps only receive step parameters — no fixture injection in the method signature. To access additional fixtures, pass them through the constructor and store on `this`. See [TypeScript Configuration](typescript-config.md) for the `@Fixture<typeof test>` typed pattern.

---

## Style Comparison

| | Playwright Style | Cucumber Style | Decorator Style |
|---|---|---|---|
| Function type | Arrow function | `function` keyword | Class method |
| State sharing | Fixtures (injected) | `this` (World object) | `this` (POM instance) |
| Fixture access | First argument | Via World properties | Via constructor args |
| Best for | New projects | CucumberJS migration | POM-heavy codebases |
| TypeScript safety | Full (typed fixtures) | Partial (World typed) | Partial (constructor typed) |
| Co-location with POM | No | No | Yes |
| Requires `experimentalDecorators` | No | No | Yes |

---

## Step Patterns

Both Playwright style and Cucumber style support the same step matching patterns:

**Cucumber Expressions** (recommended):

```ts
Given('I open url {string}', async ({ page }, url) => {
  await page.goto(url);
});
```

**Regular Expressions**:

```ts
Then(/I should see (success|error) message/, async ({ page }, status: string) => {
  await expect(page.getByRole('alert')).toHaveText(status);
});
```

See [Custom Parameter Types](../../gherkin/reference/custom-parameter-types.md) for defining domain-specific step parameters like `{user-role}` or `{org-plan}`.

---

## Choosing a Style

Start with **Playwright style** for all new projects. It is the most idiomatic approach for playwright-bdd, has the best TypeScript support, and avoids `this`-binding pitfalls.

Switch to **Cucumber style** only when migrating an existing CucumberJS suite and you want to minimize the diff.

Use **Decorator style** when your team has invested heavily in a POM architecture and wants step definitions co-located with page objects. It works well for large suites where keeping the POM as the single source of truth matters more than fixture purity.
