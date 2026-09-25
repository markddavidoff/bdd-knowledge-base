---
title: Error Handling — Gherkin Examples
description: Negative path Gherkin patterns — permission denied, not found, validation errors — using the When X / Then I see error Y structure.
sources:
  - web-itsadeliverything-declarative-imperative-declarative-style-of-gherkin-scenarios
  - web-cucumber-gherkin-reference-keywords
  - web-automation-panda-writing-good-gherkin-phrasing-steps
  - git-gherkin-best-practices-repo-readme-avoid-testing-several-rules-at-the-same-time
---

# Error Handling — Gherkin Examples

Error paths are first-class behavior specifications. A system that fails gracefully with a clear error message is behaving correctly — that behavior deserves a scenario. Writing error-path Gherkin cleanly is a skill: the `When X / Then I see error Y` structure is the core pattern.

## The Core Pattern

```gherkin
When <actor attempts something that should fail>
Then <the attempt fails>
And <the actor sees an informative error message>
```

The key is two separate assertions:
1. The operation fails (the system rejected the request)
2. The error message is correct (the system communicated helpfully)

Combining them into one step ("Then the operation fails with message X") hides both assertions behind a single step name and makes it harder to pinpoint which part failed.

---

## Permission Denied

```gherkin
@authorization
Feature: Content access control
  Content visibility is controlled by subscription tier and user role.

  @error-path
  Scenario: A free-tier user cannot access premium content
    Given a free-tier user named "Alice"
    And a premium article titled "Advanced BDD Patterns"
    When Alice attempts to read the article "Advanced BDD Patterns"
    Then the article is not shown
    And Alice sees the message "This content is for Pro subscribers"
    And Alice is shown a link to upgrade her subscription

  @error-path
  Scenario: A guest (unauthenticated) user cannot access any member content
    Given an unauthenticated visitor
    And a member article titled "Getting Started"
    When the visitor attempts to read the article "Getting Started"
    Then the visitor is redirected to the sign-in page
    And the visitor sees the message "Please sign in to read this article"
```

Note that the two scenarios produce different outcomes even though both are access denials. Free-tier users see an upgrade prompt; unauthenticated visitors get a sign-in redirect. Separate scenarios capture separate business rules.

---

## Not Found

```gherkin
@content
Feature: Article retrieval
  Members can read published articles by their slug.

  @error-path
  Scenario: Requesting a non-existent article shows a not-found page
    Given no article exists with the slug "this-article-does-not-exist"
    When Alice requests the article "this-article-does-not-exist"
    Then Alice sees a not-found page
    And Alice sees the message "We couldn't find that article"
    And the page suggests related articles

  @error-path
  Scenario: Requesting a deleted article shows a gone notice
    Given an article titled "Deleted Article" that has been removed
    When Alice requests the article "Deleted Article"
    Then Alice sees a notice that the article has been removed
    And the notice includes the removal date
```

!!! note "Not Found vs. Gone"
    These are distinct business rules — a missing resource vs. a permanently removed resource — and deserve separate scenarios even though both are "error paths." The distinction matters for SEO (HTTP 404 vs. 410), caching, and user messaging.

---

## Validation Errors

```gherkin
@forms
Feature: User profile editing
  Users can update their profile information within defined constraints.

  @error-path
  Scenario: Display name update fails when the name is too short
    Given Alice is signed in
    When Alice attempts to set her display name to "A"
    Then the update is rejected
    And Alice sees the error "Display name must be at least 2 characters"
    And Alice's current display name is unchanged

  @error-path
  Scenario: Display name update fails when the name contains invalid characters
    Given Alice is signed in
    When Alice attempts to set her display name to "Alice<script>"
    Then the update is rejected
    And Alice sees the error "Display name contains invalid characters"

  @error-path
  Scenario Outline: Email update fails for malformed addresses
    Given Alice is signed in
    When Alice attempts to change her email to "<bad_email>"
    Then the update is rejected
    And Alice sees the error "Please enter a valid email address"

    Examples:
      | bad_email       |
      | notanemail      |
      | @nodomain.com   |
      | two@@signs.com  |
```

The "Alice's current display name is unchanged" assertion in the first scenario matters — it verifies that a failed validation does not partially mutate state.

---

## Concurrent Conflict

```gherkin
@concurrency
Feature: Inventory management
  Inventory quantities reflect real-time stock levels.

  @error-path
  Scenario: Adding an out-of-stock item to cart is rejected
    Given a product "Wireless Charger" with 0 units in stock
    And Alice is signed in
    When Alice attempts to add "Wireless Charger" to her cart
    Then the add-to-cart fails
    And Alice sees the message "Wireless Charger is currently out of stock"
    And Alice's cart remains unchanged

  @error-path
  Scenario: Checkout fails when stock runs out between add-to-cart and payment
    Given a product "Wireless Charger" with 1 unit in stock
    And Alice has "Wireless Charger" in her cart
    And the last unit of "Wireless Charger" has since been purchased by Bob
    When Alice completes checkout
    Then checkout fails with "One or more items in your cart are no longer available"
    And Alice is returned to her cart to review the unavailable items
```

---

## Rate Limiting

```gherkin
@security
Feature: API rate limiting
  The API enforces per-client request limits to prevent abuse.

  @error-path
  Scenario: Requests beyond the rate limit are rejected
    Given Alice has an active API session
    And Alice has made 100 requests in the last minute
    When Alice makes another request
    Then the request is rejected with "rate limit exceeded"
    And the response includes a "retry after 60 seconds" indicator
```

---

## Summary: Error-Path Checklist

For every error scenario, verify:

| Check | Example assertion |
|-------|------------------|
| Operation failed | `Then the update is rejected` |
| Correct error message shown | `And Alice sees the error "..."` |
| State unchanged (if applicable) | `And Alice's current display name is unchanged` |
| Recovery path indicated (if applicable) | `And Alice is shown a link to upgrade` |

See [Authentication](authentication.md) for auth-specific error paths and [API Testing](api-testing.md) for HTTP-level rejection scenarios.
