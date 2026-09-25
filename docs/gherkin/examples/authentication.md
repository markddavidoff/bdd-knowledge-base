---
title: Authentication — Gherkin Examples
description: Feature file examples for login (happy path), logout, session expiry, wrong credentials, and MFA using declarative vocabulary.
sources:
  - web-itsadeliverything-declarative-imperative-declarative-style-of-gherkin-scenarios
  - web-itsadeliverything-declarative-imperative-imperative-style-of-gherkin-scenarios
  - git-gherkin-best-practices-repo-readme-write-declarative-features-instead-of-imperative-fe
  - web-cucumber-gherkin-reference-keywords
  - git-gherkin-best-practices-repo-readme-use-backgrounds-to-reduce-the-number-of-steps
---

# Authentication — Gherkin Examples

Authentication is the canonical example for learning declarative Gherkin. The imperative version — navigating to `/login`, filling in fields, pressing buttons — is what every first-time Gherkin author writes. The declarative version is what survives production.

## The Imperative Version (What to Avoid)

```gherkin
# BAD — imperative style. Do not copy.
Scenario: Login with valid credentials
  Given I am on the login page
  When I type "alice@example.com" in the email field
  And I type "correct-horse-battery-staple" in the password field
  And I press the "Sign In" button
  Then I see "Welcome back, Alice" on the home page
```

This is brittle. Any UI change (field name, button label, page route) breaks every scenario touching login. The email and password are incidental detail the business does not care about.

---

## Happy Path — Login

```gherkin
@authentication @smoke
Feature: User authentication
  Users must authenticate before accessing protected content.
  Authentication state is maintained for the duration of a session.

  Scenario: A registered user signs in with valid credentials
    Given a registered user named "Alice"
    When Alice signs in
    Then Alice is taken to her dashboard
    And Alice sees the greeting "Welcome back, Alice"
```

The step "When Alice signs in" hides the mechanism entirely — HTTP POST, form submission, OAuth redirect — all invisible to the feature file. If the login mechanism changes, only the step definition changes; the feature file stays stable.

---

## Logout

```gherkin
  Scenario: A signed-in user can sign out
    Given Alice is signed in
    When Alice signs out
    Then Alice is redirected to the sign-in page
    And Alice's session is no longer active
```

!!! note "Observable outcome"
    "Alice's session is no longer active" is verified by attempting to access a protected page and seeing the redirect. Resist writing `Then the sessions table has no row for Alice` — that is an implementation detail, not an observable behavior.

---

## Wrong Credentials — Error Path

```gherkin
  @error-path
  Scenario: Sign-in fails with an unrecognized email address
    Given no account exists for "unknown@example.com"
    When a visitor attempts to sign in as "unknown@example.com"
    Then sign-in is denied
    And the visitor sees the error "We couldn't find an account with that email"

  @error-path
  Scenario: Sign-in fails with the wrong password
    Given a registered user named "Alice"
    When Alice attempts to sign in with an incorrect password
    Then sign-in is denied
    And Alice sees the error "Incorrect password"
    And Alice's account remains unlocked
```

Two separate scenarios for two distinct business rules: unknown email vs. wrong password. They may share a UI but they are different behaviors with different observable outcomes.

---

## Session Expiry

```gherkin
  @error-path
  Scenario: An expired session requires re-authentication
    Given Alice has a session that expired 30 minutes ago
    When Alice attempts to access her dashboard
    Then Alice is redirected to the sign-in page
    And Alice sees the message "Your session has expired. Please sign in again."
    And the originally requested page is remembered for after sign-in
```

The "30 minutes ago" value is meaningful business data (the session TTL policy), not implementation noise. It belongs in the Gherkin.

---

## Multi-Factor Authentication

```gherkin
  @mfa @happy-path
  Scenario: A user with MFA enabled completes two-factor sign-in
    Given a registered user named "Bob" with MFA enabled
    When Bob signs in with valid credentials
    Then Bob is prompted for his second factor
    When Bob submits a valid MFA code
    Then Bob is taken to his dashboard

  @mfa @error-path
  Scenario: An invalid MFA code is rejected
    Given a registered user named "Bob" with MFA enabled
    And Bob has provided valid sign-in credentials
    When Bob submits an invalid MFA code
    Then sign-in is denied
    And Bob sees the error "Invalid authentication code"
    And Bob's primary credentials remain valid
```

!!! tip "Named personas hide credentials"
    `"Bob" with MFA enabled` is a named test data resource. The step definition resolves "Bob" to a canonical user fixture — email, password, TOTP secret — all configured out of view. See [Named Resources](named-resources.md) for this pattern in full.

---

## Complete Feature File

```gherkin
@authentication
Feature: User authentication
  Users must authenticate before accessing protected content.

  Scenario: A registered user signs in
    Given a registered user named "Alice"
    When Alice signs in
    Then Alice is taken to her dashboard

  Scenario: A signed-in user can sign out
    Given Alice is signed in
    When Alice signs out
    Then Alice is redirected to the sign-in page

  @error-path
  Scenario: Sign-in fails with an unrecognized email address
    Given no account exists for "unknown@example.com"
    When a visitor attempts to sign in as "unknown@example.com"
    Then sign-in is denied
    And the visitor sees the error "We couldn't find an account with that email"

  @error-path
  Scenario: Sign-in fails with the wrong password
    Given a registered user named "Alice"
    When Alice attempts to sign in with an incorrect password
    Then sign-in is denied
    And Alice sees the error "Incorrect password"

  @error-path
  Scenario: An expired session requires re-authentication
    Given Alice has a session that expired 30 minutes ago
    When Alice attempts to access her dashboard
    Then Alice is redirected to the sign-in page

  @mfa @happy-path
  Scenario: A user with MFA enabled completes two-factor sign-in
    Given a registered user named "Bob" with MFA enabled
    When Bob signs in with valid credentials
    Then Bob is prompted for his second factor
    When Bob submits a valid MFA code
    Then Bob is taken to his dashboard

  @mfa @error-path
  Scenario: An invalid MFA code is rejected
    Given a registered user named "Bob" with MFA enabled
    And Bob has provided valid sign-in credentials
    When Bob submits an invalid MFA code
    Then sign-in is denied
    And Bob sees the error "Invalid authentication code"
```

For the TypeScript step definitions backing these scenarios, see [Authentication Examples (TypeScript)](../../practice/examples/authentication.md). For admin + customer in one test, see [Multi-Actor](multi-actor.md).
