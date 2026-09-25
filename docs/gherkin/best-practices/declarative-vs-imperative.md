---
title: Declarative vs. Imperative Gherkin
description: The altitude spectrum in Gherkin authoring — how to write scenarios that describe behavior rather than UI procedure, and when the exception applies.
sources:
  - web-itsadeliverything-declarative-imperative-imperative-style-of-gherkin-scenarios
  - web-itsadeliverything-declarative-imperative-declarative-style-of-gherkin-scenarios
  - web-itsadeliverything-declarative-imperative-comment-on-abstraction
  - git-gherkin-best-practices-repo-readme-write-declarative-features-instead-of-imperative-fe
  - git-gherkin-best-practices-repo-readme-avoid-testing-through-the-ui
  - web-automation-panda-writing-good-gherkin-less-is-more
---

# Declarative vs. Imperative Gherkin

The most common Gherkin quality problem is altitude: scenarios written at the level of UI interaction rather than business behavior. This page defines the spectrum, shows the canonical examples, and explains the one legitimate exception.

## The Altitude Spectrum

"Imperative" and "declarative" are not binary categories — they describe a spectrum of abstraction. Every step sits somewhere on that spectrum. The question is always: _does this step describe **what** the system does, or **how** it does it?_

| Altitude | Description | Example step |
|---|---|---|
| Too imperative | Raw UI mechanics | `When I fill in "email" with "alice@example.com"` |
| Intermediate | Named action, UI implied | `When I sign in with valid credentials` |
| Declarative | Pure behavior | `When Alice logs in` |
| Declarative + precise | Named domain resource | `When Alice logs in as a Pro subscriber` |

The goal is the bottom row. As Liz Keogh observes, the line is not absolute — it is always relative to the abstraction level the domain experts naturally speak in. If your domain experts _are_ talking about form fields (e.g., you are building a form-builder product), then "fill in the email field" might be the right altitude. Otherwise, it is noise.

## The Wynne/Hellesøy Canonical Example

The Cucumber Book (Wynne & Hellesøy, 2012) provides the definitive before/after. The imperative version reads like a QA script:

```gherkin
# Imperative — from the Cucumber Book
Scenario: Redirect user to originally requested page after logging in
  Given a User "dave" exists with password "secret"
  And I am not logged in
  When I navigate to the home page
  Then I am redirected to the login form
  When I fill in "Username" with "dave"
  And I fill in "Password" with "secret"
  And I press "Login"
  Then I should be on the home page
```

The UI details — navigating to a URL, filling in labeled fields, pressing a button — are incidental to the behavior being described. They will change when the UI is redesigned. The business rule (logged-in users reach their originally-requested page) will not.

The declarative rewrite:

```gherkin
# Declarative
Scenario: Redirect user to originally requested page after logging in
  Given Alice is an unauthenticated guest with a valid account
  And she attempts to access a restricted page
  When she logs in
  Then she is on the page she originally requested
```

Seven steps become four. A product manager can read and validate this. The step definitions — not the feature file — handle the navigation, form interaction, and button clicks.

!!! tip "The product owner test"
    Show your feature file to a product owner who has never seen it. If they need a glossary of UI terms to understand it, the altitude is too low.

## Why Declarative Needs Richer Vocabulary

The hidden cost of declarative style is that "when she logs in" must be implemented somewhere. The step definition must know _how_ to log in. This moves complexity from the Gherkin into step definitions and support code — which is exactly where it belongs.

This is why declarative style and [ubiquitous language](ubiquitous-language.md) are inseparable. You cannot write `When Alice logs in` unless your step vocabulary has a named concept called `Alice` (a persona) and an action called `logs in` (a domain verb). The vocabulary must be built first; the declarative step is the payoff.

[Custom parameter types](../reference/custom-parameter-types.md) are the primary mechanism for encoding this vocabulary in playwright-bdd:

```typescript
// parameters.ts
import { defineParameterType } from 'playwright-bdd';

defineParameterType({
  name: 'user',
  regexp: /Alice|Bob|Charlie/,
  transformer: (name) => ({
    name,
    email: `${name.toLowerCase()}@example.com`,
    role: name === 'Alice' ? 'admin' : 'member',
  }),
});
```

With this type registered, `When Alice logs in` becomes a declarative step backed by a precise domain object — not a magic string.

## The "Protocol Is the Behavior" Exception

Not every reference to a mechanism is wrong. When the protocol _is_ the behavior under test, naming it is correct.

```gherkin
# Correct — the HTTP signature IS what we are testing
Scenario: Webhook delivery is rejected when the signature is invalid
  Given a configured webhook endpoint
  When the platform delivers an event with an invalid HMAC-SHA256 signature
  Then the endpoint returns 401 and the event is not processed
```

This scenario is testing the security contract of the webhook protocol. Naming the signature algorithm is not implementation leakage — it is the specification. Similarly, API contract tests that assert specific status codes or response shapes are correctly precise about those details because the protocol is the subject, not the means.

The test: if you replaced the implementation (say, switching HMAC libraries), would this scenario still describe the correct behavior? If yes, the detail belongs. If no, it is incidental.

## Common "False Declarative" Patterns

These patterns look declarative but are not:

**Renamed UI verbs.** `When the user submits the login form` is still imperative. "Submit" is a form verb. Replace with a behavior verb: `When the user authenticates`.

**Scenario-level narratives masking step-level detail.** Giving the scenario a good title does not fix imperative steps inside it.

**Abstracted Given, imperative When.** The context can be declarative while the action remains low-level. Every step must be evaluated independently.

**Named parameters hiding mechanism.** `When I log in as "<email>" with password "<password>"` is still UI-level even with parameterization. The mechanism (email field, password field) is still explicit.

!!! warning "False declarative and RAG retrieval"
    For AI step matching: if your step text contains UI widget names (button, field, form, dropdown, link, checkbox), selector-style language (click, navigate, fill, type, scroll, press), or HTTP primitives (POST, GET, endpoint, payload) in a non-protocol-testing context, the step is almost certainly too imperative regardless of how the scenario is titled.

## Side-by-Side Reference

```gherkin
Feature: Subscription management

  # Too imperative
  Scenario: Upgrade plan
    Given I navigate to "/account/billing"
    When I click the "Upgrade" button
    And I select "Pro" from the plan dropdown
    And I click "Confirm"
    Then I see "You are now on the Pro plan"

  # Declarative
  Scenario: Subscriber upgrades to Pro
    Given Alice is on a Free plan
    When she upgrades to Pro
    Then her account reflects Pro-tier access
```

The declarative version survives a complete UI redesign. The imperative version does not.

## Cross-References

- [Ubiquitous Language](ubiquitous-language.md) — how to build the step vocabulary that makes declarative style possible
- [Custom Parameter Types](../reference/custom-parameter-types.md) — the TypeScript API for encoding domain vocabulary
- [Step Definitions](step-definitions.md) — how to phrase steps once altitude is right
- [Anti-Patterns](anti-patterns.md) — imperative style and UI-bound scenarios
