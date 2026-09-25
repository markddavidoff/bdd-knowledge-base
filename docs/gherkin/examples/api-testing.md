---
title: API Testing — Gherkin Examples
description: Declarative REST and GraphQL feature file examples that hide HTTP mechanics behind domain-language step vocabulary.
sources:
  - web-cucumber-gherkin-reference-keywords
  - git-gherkin-best-practices-repo-readme-write-declarative-features-instead-of-imperative-fe
  - web-automation-panda-writing-good-gherkin-phrasing-steps
  - web-itsadeliverything-declarative-imperative-declarative-style-of-gherkin-scenarios
---

# API Testing — Gherkin Examples

BDD applies cleanly to API-only systems. The key principle is the same as for UI: the step text describes *what the system does* — never the HTTP method, endpoint path, or JSON payload shape. Those are implementation details that belong in step definitions.

## The Wrong Way — Exposing Transport

```gherkin
# BAD — imperative, endpoint-coupled. Do not copy.
Scenario: Fetch user profile
  Given I have a valid API token for user 42
  When I send a GET request to /api/users/42
  Then the response status is 200
  And the response body contains "email": "alice@example.com"
```

This is a test script, not a behavior specification. It will break if the endpoint moves, the user ID changes, or the API version increments.

---

## REST API — Happy Path

```gherkin
@api @smoke
Feature: User profile
  Authenticated users can retrieve and update their own profile data.

  Background:
    Given a registered user named "Alice"
    And Alice has an active API session

  Scenario: A user retrieves their own profile
    When Alice requests her profile
    Then the profile shows her name "Alice"
    And the profile shows her email "alice@example.com"

  Scenario: A user updates their display name
    When Alice updates her display name to "Alicia"
    Then Alice's profile shows the display name "Alicia"
```

"When Alice requests her profile" hides `GET /api/v2/users/me` with the Bearer token and Accept header. The feature file is stable across API version changes.

---

## REST API — Error Responses

```gherkin
  @error-path
  Scenario: Accessing the profile without authentication is rejected
    Given no API session is active
    When a client requests the profile endpoint
    Then the request is rejected with "unauthorized"
    And the response indicates valid credentials are required

  @error-path
  Scenario: A user cannot retrieve another user's private profile
    Given a registered user named "Bob"
    And Alice has an active API session
    When Alice requests Bob's private profile
    Then the request is rejected with "forbidden"

  @error-path
  Scenario: Requesting a non-existent user profile returns not-found
    Given no user exists with the identifier "ghost-user"
    When Alice requests the profile for "ghost-user"
    Then the request is rejected with "not found"
```

!!! tip "Error vocabulary over status codes"
    `"rejected with 'unauthorized'"` is more readable than `"the response status is 401"`. The status code is an implementation detail; the authorization denial is the behavior. The step definition maps the domain term to the HTTP status.

---

## REST API — Pagination

```gherkin
  Scenario: Profile listing returns paginated results
    Given 25 registered users exist
    When Alice requests the first page of users with page size 10
    Then Alice sees 10 user profiles
    And the response indicates a next page is available

  Scenario: The final page has no next-page indicator
    Given 25 registered users exist
    When Alice requests the third page of users with page size 10
    Then Alice sees 5 user profiles
    And the response indicates no further pages exist
```

---

## GraphQL API

GraphQL uses a single endpoint — all operations are POST to `/graphql`. This makes imperative Gherkin especially noisy. Declarative steps hide the query shape entirely.

```gherkin
@api @graphql
Feature: Content retrieval via GraphQL
  Clients can query published articles and their associated metadata.

  Background:
    Given a registered user named "Alice"
    And Alice has an active API session

  Scenario: A client queries a published article
    Given a published article titled "Getting Started with BDD"
    When Alice queries the article "Getting Started with BDD"
    Then the article title is "Getting Started with BDD"
    And the article body is present
    And the article has a published timestamp

  @error-path
  Scenario: Querying a draft article without author permissions is denied
    Given a draft article titled "Work in Progress"
    When Alice queries the article "Work in Progress"
    Then the query returns no article
    And Alice sees a "not authorized" error in the response
```

!!! note "GraphQL errors in 200 responses"
    GraphQL always returns HTTP 200 even for logical errors — errors appear in the `errors` array. The step `"Alice sees a 'not authorized' error in the response"` abstracts this correctly. The step definition inspects `response.errors[0].message`, not the HTTP status.

---

## API Scenario with DataTable for Request Body

When a request involves multiple fields, a DataTable communicates structured input readably without embedding JSON.

```gherkin
  Scenario: A user updates multiple profile fields at once
    When Alice updates her profile with:
      | field        | value              |
      | display_name | Alicia             |
      | bio          | BDD practitioner   |
      | timezone     | America/Chicago    |
    Then Alice's profile reflects all three updates
```

The step definition reads the table as key-value pairs and constructs the request body. The Gherkin shows the *what* (three fields updated), not the *how* (PATCH request with JSON body).

---

## Complete Feature File

```gherkin
@api
Feature: User profile API
  Authenticated users can retrieve and update their own profile data.

  Background:
    Given a registered user named "Alice"
    And Alice has an active API session

  @smoke
  Scenario: A user retrieves their own profile
    When Alice requests her profile
    Then the profile shows her name "Alice"
    And the profile shows her email "alice@example.com"

  Scenario: A user updates their display name
    When Alice updates her display name to "Alicia"
    Then Alice's profile shows the display name "Alicia"

  @error-path
  Scenario: Accessing the profile without authentication is rejected
    Given no API session is active
    When a client requests the profile endpoint
    Then the request is rejected with "unauthorized"

  @error-path
  Scenario: A user cannot retrieve another user's private profile
    Given a registered user named "Bob"
    When Alice requests Bob's private profile
    Then the request is rejected with "forbidden"
```

For TypeScript step definitions using `APIRequestContext`, see [API Testing Examples (TypeScript)](../../practice/examples/api-testing-playwright-bdd.md). For error path patterns across all domain areas, see [Error Handling](error-handling.md).
