---
title: API Testing — playwright-bdd
description: Complete playwright-bdd pattern for browser-free API testing using APIRequestContext, with declarative REST and GraphQL examples and TypeScript response types.
sources:
  - git-playwright-bdd-repo-examples-api-testing-readme-readme
  - git-playwright-bdd-repo-docs-writing-steps-playwright-style-custom-fixtures
  - git-playwright-bdd-repo-docs-getting-started-add-fixtures-add-fixtures
---

# API Testing — playwright-bdd

playwright-bdd can test APIs without a browser. The `request` fixture from Playwright provides an `APIRequestContext` that makes HTTP requests directly. No `page`, no browser launch overhead.

!!! note "When to use this approach vs. @cucumber/cucumber + supertest"
    Use playwright-bdd for API testing when: (a) your project already has playwright-bdd for UI tests, or (b) you want one unified test runner and report. For pure backend services with no UI tests at all, see [API Testing — Cucumber](api-testing-cucumber.md) for a lighter-weight alternative.

## REST API example

### Feature file

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

### TypeScript types

```typescript
// support/types.ts
export interface Post {
  id: number;
  userId: number;
  title: string;
  body: string;
}

export interface ApiState {
  lastResponse: import('@playwright/test').APIResponse | null;
  lastPost: Post | null;
}
```

### fixtures.ts

```typescript
// features/steps/fixtures.ts
import { test as base, createBdd } from 'playwright-bdd';
import type { ApiState } from '../../support/types';

export const test = base.extend<{ apiState: ApiState }>({
  apiState: async ({}, use) => {
    await use({ lastResponse: null, lastPost: null });
  },
});

export const { Given, When, Then } = createBdd(test);
```

### Step definitions

```typescript
// features/steps/posts.steps.ts
import { expect } from '@playwright/test';
import { Given, When, Then } from './fixtures';
import type { Post } from '../../support/types';

const BASE_URL = 'https://jsonplaceholder.typicode.com';

Given('the posts API is available', async ({ request }) => {
  const res = await request.get(`${BASE_URL}/posts/1`);
  expect(res.ok()).toBeTruthy();
});

When(
  'I create a post with title {string} and body {string}',
  async ({ request, apiState }, title: string, body: string) => {
    const res = await request.post(`${BASE_URL}/posts`, {
      data: { title, body, userId: 1 },
    });
    apiState.lastResponse = res;
    apiState.lastPost = await res.json() as Post;
  }
);

When('I retrieve post {int}', async ({ request, apiState }, postId: number) => {
  const res = await request.get(`${BASE_URL}/posts/${postId}`);
  apiState.lastResponse = res;
  if (res.ok()) {
    apiState.lastPost = await res.json() as Post;
  }
});

When('I delete post {int}', async ({ request, apiState }, postId: number) => {
  const res = await request.delete(`${BASE_URL}/posts/${postId}`);
  apiState.lastResponse = res;
});

Then('the response status is {int}', async ({ apiState }, status: number) => {
  expect(apiState.lastResponse?.status()).toBe(status);
});

Then(
  'the returned post has title {string}',
  async ({ apiState }, expectedTitle: string) => {
    expect(apiState.lastPost?.title).toBe(expectedTitle);
  }
);
```

## GraphQL example

GraphQL uses a single endpoint. A 200 response can still contain errors in the body — always check `data.errors`.

### Feature file

```gherkin
Feature: Posts GraphQL API

  Scenario: Query a post by ID
    When I query post 1 via GraphQL
    Then the GraphQL response contains a post with userId 1

  Scenario: An invalid query returns a GraphQL error
    When I send an invalid GraphQL query
    Then the GraphQL response contains an error
```

### Step definitions

```typescript
// features/steps/graphql.steps.ts
import { expect } from '@playwright/test';
import { When, Then } from './fixtures';

const GQL_URL = 'https://graphqlzero.almansi.me/api';

interface GqlResponse<T = unknown> {
  data?: T;
  errors?: Array<{ message: string }>;
}

interface PostData {
  post: { id: string; title: string; user: { id: string } };
}

// shared state — in production use a fixture for isolation
let gqlResponse: GqlResponse = {};

When('I query post {int} via GraphQL', async ({ request }, postId: number) => {
  const res = await request.post(GQL_URL, {
    data: {
      query: `
        query GetPost($id: ID!) {
          post(id: $id) {
            id
            title
            user { id }
          }
        }
      `,
      variables: { id: String(postId) },
    },
  });
  // GraphQL always returns 200, even for errors
  expect(res.status()).toBe(200);
  gqlResponse = (await res.json()) as GqlResponse<PostData>;
});

When('I send an invalid GraphQL query', async ({ request }) => {
  const res = await request.post(GQL_URL, {
    data: { query: '{ notARealField }' },
  });
  expect(res.status()).toBe(200);
  gqlResponse = (await res.json()) as GqlResponse;
});

Then(
  'the GraphQL response contains a post with userId {int}',
  async ({}, userId: number) => {
    expect(gqlResponse.errors).toBeUndefined();
    const data = gqlResponse.data as PostData;
    expect(data.post.user.id).toBe(String(userId));
  }
);

Then('the GraphQL response contains an error', async ({}) => {
  expect(gqlResponse.errors).toBeDefined();
  expect(gqlResponse.errors!.length).toBeGreaterThan(0);
});
```

!!! warning "GraphQL error-in-200 pattern"
    GraphQL servers return HTTP 200 even when the query fails. **Always** check `response.errors` in your Then step. A bare `expect(res.ok()).toBeTruthy()` will pass even for a failed query.

## playwright.config.ts for API-only tests

When running browser-free, you can disable browser download entirely:

```typescript
// playwright.config.ts
import { defineConfig } from '@playwright/test';
import { defineBddConfig } from 'playwright-bdd';

export default defineConfig({
  testDir: defineBddConfig({
    features: 'features/**/*.feature',
    steps: 'features/steps/**/*.ts',
  }),
  // no 'use.browserName' — defaults to chromium but request fixture
  // works without launching a browser page
  use: {
    baseURL: 'https://jsonplaceholder.typicode.com',
    extraHTTPHeaders: {
      Accept: 'application/json',
      'Content-Type': 'application/json',
    },
  },
});
```

## Related

- [API Testing — Cucumber](api-testing-cucumber.md) — same REST scenario via @cucumber/cucumber + supertest
- [CRUD Operations](crud-operations.md) — API seeding for UI tests
- [Network Mocking](network-mocking.md) — intercept API calls from the browser
