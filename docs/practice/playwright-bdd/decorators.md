---
title: Decorator Step Definitions
description: Use TypeScript v5 class decorators to co-locate BDD step definitions with Page Object Models in playwright-bdd.
sources:
  - git-playwright-bdd-repo-docs-writing-steps-decorators-decorators
  - git-playwright-bdd-repo-docs-writing-steps-decorators-accessing-bdd-fixtures
  - git-playwright-bdd-repo-docs-writing-steps-decorators-inheritance
  - git-playwright-bdd-repo-docs-writing-steps-decorators-multiple-decorators-per-method
---

# Decorator Step Definitions

playwright-bdd supports [TypeScript v5 decorators](https://www.typescriptlang.org/docs/handbook/release-notes/typescript-5-0.html#decorators) as a way to define steps directly inside Page Object Models (POMs). Instead of maintaining separate step files that import your POMs, the class itself carries the step definitions.

## Core Syntax

Import the four decorators from `playwright-bdd/decorators`:

```ts
import { Fixture, Given, When, Then } from 'playwright-bdd/decorators';
```

Apply `@Fixture` to the class to bind it to a Playwright fixture name. Apply `@Given`, `@When`, and `@Then` to individual methods:

```ts
// TodoPage.ts
import { Page, expect } from '@playwright/test';
import { Fixture, Given, When, Then } from 'playwright-bdd/decorators';

export @Fixture('todoPage') class TodoPage {
  constructor(public page: Page) {}

  @Given('I am on todo page')
  async open() {
    await this.page.goto('https://demo.playwright.dev/todomvc/');
  }

  @When('I add todo {string}')
  async addToDo(text: string) {
    await this.page.locator('input.new-todo').fill(text);
    await this.page.locator('input.new-todo').press('Enter');
  }

  @Then('visible todos count is {int}')
  async checkVisibleTodosCount(count: number) {
    await expect(this.page.getByTestId('todo-item')).toHaveCount(count);
  }
}
```

## Registering the Fixture

The decorator-annotated class must be registered with Playwright as a regular fixture:

```ts
// fixtures.ts
import { test as base } from 'playwright-bdd';
import { TodoPage } from './TodoPage';

export const test = base.extend<{ todoPage: TodoPage }>({
  todoPage: ({ page }, use) => use(new TodoPage(page)),
});
```

Then add `fixtures.ts` to the `steps` config so playwright-bdd picks up the registered steps:

```ts
// playwright.config.ts
const testDir = defineBddConfig({
  features: 'features/todo.feature',
  steps: 'fixtures.ts',
});
```

The feature file now matches the decorator-annotated method signatures directly:

```gherkin
# features/todo.feature
Feature: Todo Page

  Scenario: Adding todos
    Given I am on todo page
    When I add todo "foo"
    And I add todo "bar"
    Then visible todos count is 2
```

## Accessing BDD Fixtures from Decorators

Decorator methods only receive step parameters — they cannot accept Playwright fixtures directly. To use BDD fixtures such as `$tags` or `$test`, pass them through the POM constructor:

```ts
// TodoPage.ts
import { Fixture, Given } from 'playwright-bdd/decorators';
import { test } from './fixtures';

export @Fixture<typeof test>('todoPage') class TodoPage {
  constructor(
    public page: Page,
    protected $tags: string[],
    protected $test: typeof test,
  ) {}

  @Given('I am on todo page')
  async open() {
    if (this.$tags.includes('@firefox')) {
      this.$test.skip();
    }
    await this.page.goto('https://demo.playwright.dev/todomvc/');
  }
}
```

Then inject those fixtures in the fixture factory:

```ts
// fixtures.ts
export const test = base.extend<{ todoPage: TodoPage }>({
  todoPage: ({ page, $tags, $test }, use) => {
    const todoPage = new TodoPage(page, $tags, $test as typeof test);
    await use(todoPage);
  },
});
```

## Inheritance

When one POM inherits from another, playwright-bdd automatically selects the most specific fixture for a scenario that uses steps from both classes:

```ts
export @Fixture('todoPage') class TodoPage {
  @Given('I am on todo page')
  async open() { /* ... */ }
}

export @Fixture('adminTodoPage') class AdminTodoPage extends TodoPage {
  @When('I add todo {string}')
  async addToDo(text: string) { /* ... */ }
}
```

In a scenario that uses both `Given I am on todo page` and `When I add todo "foo"`, playwright-bdd uses a single `AdminTodoPage` fixture rather than instantiating both. You can override this with the special `@fixture:name` tag:

```gherkin
@fixture:adminTodoPage
Feature: Admin view

  Scenario: Adding todos
    Given I am on todo page
    When I add todo "foo"
```

## Multiple Decorators per Method

Apply several step decorators to the same method to support natural language variations without duplicating logic:

```ts
export @Fixture('todoPage') class TodoPage {
  @When('a item {string} exists')
  @When('a item called {string} is added')
  async addItem(itemName: string) {
    await this.page.locator('input.new-todo').fill(itemName);
    await this.page.locator('input.new-todo').press('Enter');
  }
}
```

You can also mix keywords across a single method to make a setup step usable as both a `Given` (context) and a `When` (action):

```ts
@Given('I have item {string}')
@When('I add item {string}')
async setupItem(itemName: string) {
  await this.addItem(itemName);
}
```

## Trade-offs vs. createBdd()

| | Decorator style | createBdd() style |
|---|---|---|
| **Pattern** | Class-based POM | Arrow functions |
| **State sharing** | `this` in the class | fixture injection |
| **Type safety** | Slightly weaker (no fixture-type inference on params) | Full TypeScript inference |
| **Co-location** | Steps live with the POM | Steps in separate files |
| **Requires** | `experimentalDecorators: true` in tsconfig | No extra tsconfig flags |
| **VS Code autocomplete** | Needs `strictGherkinCompletion: false` | Works by default |

!!! tip
    Enable VS Code step autocomplete for decorators by setting `"cucumberautocomplete.strictGherkinCompletion": false` in `.vscode/settings.json`.

!!! note
    Decorator support requires TypeScript v5 and `"experimentalDecorators": true` (or TS 5.0+ stage-3 decorators without the flag). Check your `tsconfig.json` before starting.

## Cross-references

- [Writing Step Definitions](writing-steps.md) — createBdd() style comparison
- [Fixtures](fixtures.md) — fixture scoping and dependency injection
- [Scoped Step Definitions](scoped-steps.md) — limiting decorator steps to specific features
