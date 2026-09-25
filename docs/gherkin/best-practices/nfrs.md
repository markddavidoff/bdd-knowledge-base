---
title: Non-Functional Requirements in Gherkin
description: Which NFRs belong in Gherkin (behavioral security, accessibility, data integrity) and which do not (performance benchmarks, SAST, uptime monitoring), with the test to tell them apart.
sources:
  - git-gherkin-best-practices-repo-readme-readme
  - web-automation-panda-writing-good-gherkin-handling-test-data
  - web-cucumber-antipatterns-1-incidental-details
---

# Non-Functional Requirements in Gherkin

Not all NFRs belong in Gherkin. The deciding test is simple: **does this describe system behavior, or does it measure a threshold?** Behavioral NFRs belong in Gherkin. Threshold measurements belong in dedicated tooling.

## The Test: Behavior vs. Measurement

Ask of each NFR: "If a non-technical stakeholder read this scenario, would they understand what the system does or doesn't do?"

- **Behavior**: "Unauthenticated users cannot access admin endpoints" — yes, this describes what the system does.
- **Measurement**: "The homepage loads in under 200ms at p99" — no, this is a performance threshold. A stakeholder reads it and learns nothing about what the system does; they learn how fast it currently does it.

Measurements belong in load testing tools (k6, Artillery), SAST/DAST pipelines, and SLA monitoring — not in Gherkin.

## Behavioral NFRs: Belong in Gherkin

### Security Behaviors: Auth Denial and Permission Enforcement

Security that can be expressed as "user of role X cannot do action Y" is behavioral. Write it in Gherkin.

```gherkin
Feature: API access control

  Scenario: Unauthenticated requests are rejected
    Given an unauthenticated API client
    When the client requests GET /api/admin/users
    Then the response status is 401
    And the response body contains "Authentication required"

  Scenario: Members cannot delete organization resources
    Given Alice is a member of the "Acme" organization
    When Alice sends DELETE /api/orgs/acme
    Then the response status is 403
    And the resource is not deleted
```

```typescript
// steps/access-control.steps.ts
import { createBdd } from 'playwright-bdd';
import { test } from '../fixtures';

const { Given, When, Then } = createBdd(test);

Given('an unauthenticated API client', async ({ ctx }) => {
  ctx.authToken = null;
});

When('the client requests GET {string}', async ({ request, ctx }, path: string) => {
  ctx.response = await request.get(path, {
    headers: ctx.authToken ? { Authorization: `Bearer ${ctx.authToken}` } : {},
  });
});

Then('the response status is {int}', async ({ ctx }, status: number) => {
  expect(ctx.response.status()).toBe(status);
});
```

### Accessibility: No Violations Assertions

Accessibility requirements describe behavior a screen reader or keyboard user experiences. They are testable assertions, not thresholds.

```gherkin
Feature: Accessibility compliance

  @smoke @accessibility
  Scenario: The login page has no critical accessibility violations
    Given I am on the login page
    Then the page has no critical accessibility violations

  Scenario: The dashboard is keyboard navigable
    Given I am logged in as a standard user
    When I navigate the dashboard using only the keyboard
    Then every interactive element is reachable and activatable
```

```typescript
// steps/accessibility.steps.ts
import AxeBuilder from '@axe-core/playwright';

Then('the page has no critical accessibility violations', async ({ page }) => {
  const results = await new AxeBuilder({ page })
    .withTags(['wcag2a', 'wcag2aa'])
    .analyze();
  expect(results.violations.filter(v => v.impact === 'critical')).toHaveLength(0);
});
```

!!! tip "Axe-core impact levels"
    Use `impact === 'critical'` or `impact === 'serious'` as your Gherkin threshold. Informational and moderate violations may be acceptable and can be tracked separately. Hard-failing on all violations often produces too much noise on first adoption.

### Data Integrity: Consistency Guarantees

Behaviors that describe how data remains consistent after an operation are behavioral:

```gherkin
Scenario: Deleting an organization removes all member associations
  Given an organization with 3 active members
  When the organization is deleted
  Then no member retains membership in the deleted organization
  And all pending invitations for that organization are cancelled
```

This describes what the system does (cascading cleanup). It is not a performance measurement.

## Measurement NFRs: Do Not Belong in Gherkin

### Performance Benchmarks

```gherkin
# Wrong — do not write this
Scenario: Homepage loads fast
  When I open the homepage
  Then it should load in less than 2 seconds
```

This is a threshold measurement. Page load time is non-deterministic in a test environment, affected by network variability, CI runner load, and caching state. False failures erode trust in the suite. Use k6, Lighthouse CI, or Playwright's performance APIs in a dedicated performance suite.

### Security Scanning (SAST/DAST)

Static analysis and dynamic application security testing scan code or running services for vulnerability patterns. These are pipeline stages, not behavioral scenarios. Add them to your CI pipeline using tools like Semgrep, Snyk, or OWASP ZAP — not as Gherkin steps.

### Uptime and Reliability

```gherkin
# Wrong — do not write this
Scenario: The service achieves 99.9% uptime
  Given the service has been running for 30 days
  Then it was unavailable for less than 44 minutes
```

Uptime is measured by monitoring systems (Datadog, PagerDuty, Uptime Robot), not by test suites. A scenario cannot make this assertion meaningfully in a CI run.

## Quick Reference

| NFR type | Belongs in Gherkin? | Where instead |
|---|---|---|
| Auth denial (401/403) | Yes | Feature file |
| Permission enforcement | Yes | Feature file |
| Accessibility assertions (axe) | Yes | Feature file + axe-core |
| Data integrity / cascading | Yes | Feature file |
| Page load time benchmarks | No | k6, Lighthouse CI |
| SAST / dependency scanning | No | Snyk, Semgrep in CI |
| Uptime / availability SLA | No | Monitoring (Datadog, etc.) |
| Penetration testing | No | Dedicated security tooling |
| API rate limits (enforcement) | Yes | Feature file |
| API rate limits (capacity) | No | Load testing (k6) |

!!! note "Rate limits: a useful edge case"
    "When the client exceeds 100 requests per minute, the API returns 429" is a behavior scenario — it describes what the system does when the limit is hit. "The system handles 10,000 requests per second" is a capacity measurement — it belongs in a load test.
