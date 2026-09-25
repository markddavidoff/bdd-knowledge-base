---
title: API Testing — @cucumber/cucumber + supertest
description: REST API testing using @cucumber/cucumber runner with supertest, demonstrating the World object and function keyword style as an alternative to playwright-bdd.
sources:
  - web-cucumber-js-api-defineparametertype-api-reference
  - git-cucumber-js-docs-javascriptapi-concepts
  - git-cucumber-js-docs-faq-the-world-instance-isn-t-available-in-my-hooks-or-step-defin
---

# API Testing — @cucumber/cucumber + supertest

This page implements the same REST scenario from [API Testing — playwright-bdd](api-testing-playwright-bdd.md) using the raw `@cucumber/cucumber` runner with `supertest`. No Playwright, no browser.

Use this approach for **pure backend or API services** where you have no UI to test. It avoids pulling in the full Playwright dependency and produces a lighter test binary.

## Install

```bash
npm install -D @cucumber/cucumber supertest
npm install -D ts-node @types/supertest
```

## Feature file (identical to the playwright-bdd version)

```gherkin
Feature: Posts API

  Scenario: Create a post and retrieve it
    Given the posts API is available
    When I create a post with title "Hello BDD" and body "Testing with playwright-bdd"
    Then the response status is 201
    And the returned post has title "Hello BDD"

  Scenario: Retrieve a known post
    When I retrieve post 1
    Then the response status is 200
    And the returned post has title "sunt aut facere repellat provident occaecati excepturi optio reprehenderit"

  Scenario: Delete a non-existent post returns 404
    When I delete post 9999
    Then the response status is 404
```

## World object (replaces fixtures)

In `@cucumber/cucumber`, shared state lives on `this` — the World instance. Define it with `setWorldConstructor`:

```typescript
// features/support/world.ts
import { setWorldConstructor, World, IWorldOptions } from '@cucumber/cucumber';
import type { Response } from 'supertest';

interface PostRecord {
  id: number;
  title: string;
  body: string;
  userId: number;
}

export class ApiWorld extends World {
  lastResponse: Response | null = null;
  lastPost: PostRecord | null = null;

  constructor(options: IWorldOptions) {
    super(options);
  }
}

setWorldConstructor(ApiWorld);
```

## Step definitions

!!! warning "Use function keyword, not arrow functions"
    Arrow functions capture `this` from the enclosing scope, breaking World access. Always use the `function` keyword in @cucumber/cucumber step definitions that need `this`.

```typescript
// features/step_definitions/posts.steps.ts
import { Given, When, Then } from '@cucumber/cucumber';
import request from 'supertest';
import { strict as assert } from 'assert';
import type { ApiWorld } from '../support/world';

const BASE_URL = 'https://jsonplaceholder.typicode.com';

Given('the posts API is available', async function (this: ApiWorld) {
  const res = await request(BASE_URL).get('/posts/1');
  assert.ok(res.status < 400, `Expected API to be available, got ${res.status}`);
});

When(
  'I create a post with title {string} and body {string}',
  async function (this: ApiWorld, title: string, body: string) {
    const res = await request(BASE_URL)
      .post('/posts')
      .send({ title, body, userId: 1 })
      .set('Content-Type', 'application/json');

    this.lastResponse = res;
    this.lastPost = res.body;
  }
);

When(
  'I retrieve post {int}',
  async function (this: ApiWorld, postId: number) {
    const res = await request(BASE_URL).get(`/posts/${postId}`);
    this.lastResponse = res;
    if (res.status === 200) {
      this.lastPost = res.body;
    }
  }
);

When(
  'I delete post {int}',
  async function (this: ApiWorld, postId: number) {
    const res = await request(BASE_URL).delete(`/posts/${postId}`);
    this.lastResponse = res;
  }
);

Then('the response status is {int}', function (this: ApiWorld, status: number) {
  assert.strictEqual(this.lastResponse?.status, status);
});

Then(
  'the returned post has title {string}',
  function (this: ApiWorld, expectedTitle: string) {
    assert.strictEqual(this.lastPost?.title, expectedTitle);
  }
);
```

## cucumber.js configuration

```javascript
// cucumber.js
module.exports = {
  default: {
    require: ['features/support/**/*.ts', 'features/step_definitions/**/*.ts'],
    requireModule: ['ts-node/register'],
    format: ['progress', 'html:reports/cucumber-report.html'],
  },
};
```

## Side-by-side comparison

| Aspect | playwright-bdd (`createBdd()`) | @cucumber/cucumber (World) |
|---|---|---|
| Shared state | Injected via fixtures | `this` (World object) |
| Function style | Arrow functions | `function` keyword required |
| HTTP client | `request` fixture (Playwright) | `supertest` or `node-fetch` |
| Browser support | Yes (same project) | No (separate runner needed) |
| Dependency size | Larger (Playwright) | Lighter |
| Step file imports | `import { Given } from './fixtures'` | `import { Given } from '@cucumber/cucumber'` |
| TypeScript state typing | Fixture interface | `setWorldConstructor` class |

## When to choose which

Choose **playwright-bdd** when:
- Your project already has playwright-bdd UI tests and you want one runner and one report.
- You want to share `baseURL`, auth headers, or fixture infrastructure with UI tests.
- You use Playwright's built-in retry, trace, and screenshot capabilities.

Choose **@cucumber/cucumber + supertest** when:
- You are testing a pure backend service with no UI.
- You want to minimize dependencies in a microservice repo.
- Your team is more comfortable with the Cucumber World pattern from other languages (Ruby Cucumber, SpecFlow, Behave).

!!! tip "Mixing runners in a monorepo"
    In a monorepo it is valid to use playwright-bdd for the frontend package and @cucumber/cucumber for backend service packages, as long as the `.feature` file vocabulary stays consistent across them.

## Related

- [API Testing — playwright-bdd](api-testing-playwright-bdd.md) — same scenario with fixtures
- [playwright-bdd vs. @cucumber/cucumber runner](../playwright-bdd/vs-cucumber-runner.md)
- [BDD without a browser](../spec-lifecycle/bdd-without-browser.md)
