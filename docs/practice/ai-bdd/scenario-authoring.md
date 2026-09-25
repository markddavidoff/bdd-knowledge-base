---
title: AI-Assisted Scenario Authoring
description: Using LLMs to draft Gherkin scenarios — effective prompting strategies, reviewing AI output against Three Amigos criteria, and iterative refinement.
sources:
  - git-playwright-bdd-repo-docs-writing-features-chatgpt-chatgpt
  - git-playwright-bdd-repo-docs-cli-bddgen-export
  - git-playwright-bdd-repo-docs-getting-started-agent-skill-usage
  - web-monday-bdd-guide-the-future-of-bdd-ai-and-automation-trends
---

# AI-Assisted Scenario Authoring

LLMs can produce well-formed Gherkin from a user story description in seconds. The quality of the output depends almost entirely on the quality of the context you supply. Without constraints, LLMs invent step text and vocabulary that sound natural but have no implementation. With the right context, they produce usable first drafts that significantly reduce the time Three Amigos sessions spend on phrasing.

## Effective Prompting Strategies

### 1. Constrain to Available Steps

The single most important context item is the step export from `bddgen export`. It tells the LLM exactly which steps exist and prevents invented vocabulary:

```
Generate BDD scenarios in Gherkin for this user story:

As a billing admin, I want to apply a discount code to a subscription
so that customers can receive promotional pricing.

Constraints:
- Use ONLY the following step definitions. Do not invent new step text.
- If a behavior requires a step that does not exist, write [MISSING STEP: description].
- Output a single .feature file.
- Use Background for steps common to all scenarios.

Available steps:
* Given I am logged in as {user-role}
* Given a {org-plan} organization exists
* When I navigate to the billing settings page
* When I apply discount code {string}
* When I submit the billing form
* Then the subscription shows {string} pricing
* Then I see an error message {string}
* Then the billing settings page shows the active discount
```

See [Exporting Steps](exporting-steps.md) for how to generate this list from your codebase.

### 2. Include the Ubiquitous Language Glossary

Domain terms that your team uses should appear in scenarios using your team's vocabulary, not the LLM's best guess. Supply a glossary:

```
Domain vocabulary for this project:
- "billing admin": a user with the BILLING_ADMIN role, can modify subscription settings
- "org-plan": one of "free", "pro", or "enterprise" — controls feature access
- "discount code": a promo code applied at checkout; format is 8 uppercase alphanumeric characters
- "subscription shows X pricing": the monthly invoice line item reflects the discounted rate
```

### 3. Include Existing Scenarios as Examples

The LLM calibrates its output style (altitude, verbosity, vocabulary) to the examples you provide. Include 2-3 existing scenarios from your codebase:

```
Match the style of these existing scenarios:

Feature: Subscription management

  Background:
    Given I am logged in as "billing_admin"
    And a "pro" organization exists

  Scenario: Admin upgrades to enterprise plan
    When I navigate to the billing settings page
    And I select the "enterprise" plan
    And I submit the billing form
    Then the subscription shows "enterprise" pricing
```

### 4. Specify Domain Context

Tell the LLM about the system being tested, especially edge cases the LLM would not know about:

```
System context:
- Discount codes can only be applied once per organization
- Codes expire after the date in the YYYY-MM-DD suffix (e.g., "PROMO2026-12-31")
- Applying an expired code shows the error "This discount code has expired"
- Applying a code already used shows the error "This code has already been applied to your account"
```

## Reviewing AI-Generated Scenarios

AI output must be reviewed before it becomes a specification. Use this checklist as a Three Amigos review protocol for AI-generated scenarios:

### Three Amigos Checklist for AI Output

**Product Owner review:**
- [ ] Does each scenario describe a real business rule or user need?
- [ ] Are the examples realistic (not just "happy path + one error")?
- [ ] Is the domain vocabulary correct? (Names, states, transitions)
- [ ] Are there missing scenarios — error paths, permission checks, boundary conditions?

**Developer review:**
- [ ] Do all steps exist in the step export? (No invented step text)
- [ ] Are parameter values valid? (No impossible states, no string values where custom types are used)
- [ ] Is the test data described declaratively? (Named resources, not inline IDs)
- [ ] Are there any implementation details leaking into the Gherkin?

**Tester review:**
- [ ] Is each scenario atomic? (One behavior per scenario)
- [ ] Are scenarios independent? (No reliance on execution order)
- [ ] Are there edge cases the LLM missed? (Boundary values, concurrent access, race conditions)
- [ ] Are error scenarios adequately covered?

## Common AI Mistakes

### Imperative Steps

LLMs default to imperative style because UI interaction language ("click", "fill in", "navigate to") appears frequently in training data.

```gherkin
# BAD — imperative (what the AI often produces)
Scenario: Apply discount code
  When I click the "Billing" link in the sidebar
  And I scroll to the "Promotions" section
  And I type "SAVE20" in the discount code input field
  And I click the "Apply" button
  Then the price changes to reflect the discount

# GOOD — declarative (what you want)
Scenario: Apply a valid discount code
  When I apply discount code "SAVE20"
  Then the subscription shows "pro" pricing with a 20% discount applied
```

Add explicit instructions to avoid imperative language:

```
Write scenarios at a behavioral level. Use business language, not UI actions.
Do not use words like "click", "navigate", "scroll", "type", "fill in".
Instead describe what the user intends and what they observe.
```

### Invented Vocabulary

Even with step constraints, LLMs sometimes generate steps that "almost" match but have slight variations:

```
# Invented (not in step export)
When I apply the discount code "SAVE20"

# Correct (from step export)
When I apply discount code "SAVE20"
```

Post-process AI output by running `bddgen --dry-run`. Any undefined step is vocabulary that must be corrected or implemented.

### Missing Error Paths

LLMs tend to cover the happy path thoroughly and add only 1-2 error cases. Prompt explicitly for error coverage:

```
For each scenario you write, also write the corresponding failure scenario:
- What happens when the operation fails due to invalid input?
- What happens when the user lacks permission?
- What happens when the resource does not exist?
```

## Iterative Refinement Workflow

Treat AI scenario authoring as a dialogue, not a one-shot generation:

```
Round 1:  "Generate scenarios for the discount code feature"
          → LLM produces 3-4 happy-path scenarios

Round 2:  "Add scenarios for: expired codes, already-used codes, invalid format codes"
          → LLM adds error path scenarios

Round 3:  "Change all steps to match this exact vocabulary: [paste step export]"
          → LLM corrects invented step text

Round 4:  "Rewrite to use Background for the common login step"
          → LLM extracts background

Human review: Three Amigos checklist on the final output
```

!!! example "Full prompt template"
    ```
    Generate BDD scenarios in Gherkin for this user story:
    [USER STORY]

    Domain vocabulary:
    [GLOSSARY]

    Match the style of these existing scenarios:
    [EXAMPLES]

    Available steps (use ONLY these):
    [bddgen export output]

    Coverage requirements:
    - Happy path
    - At least 2 error/failure paths
    - Edge cases: [list known edge cases]

    Format:
    - Single .feature file
    - Use Background for common Given steps
    - No imperative UI actions in step text
    - If a step is missing, write [MISSING STEP: description]
    ```

## See Also

- [Exporting Steps](exporting-steps.md) — generating the step list for prompts
- [Step Scaffolding](step-scaffolding.md) — generating step defs for [MISSING STEP] items
- [Drift Detection](drift-detection.md) — checking that accepted scenarios stay aligned with implementation
- [Three Amigos](../methodology/three-amigos.md) — the conversation this prompt workflow supports
