---
title: Behave (Python)
description: Behave BDD runner for Python — decorator-based step definitions, the context object, and step file conventions, with concept mapping to playwright-bdd.
sources:
  - web-playwright-bdd-vs-cucumber-cucumber-js-vs-playwright-bdd-comparison
  - git-gherkin-parser-python-readme-readme
---

# Behave (Python)

Behave is the dominant BDD framework for Python. Like all Cucumber-family runners, it reads standard Gherkin `.feature` files. Teams that operate Python microservices alongside a TypeScript frontend often maintain both a Behave suite (for backend API behavior) and a playwright-bdd suite (for UI behavior). This page helps those teams understand the differences and share feature file vocabulary.

## The Same Feature File

```gherkin
Feature: Invoice generation

  Scenario: Generating an invoice for a pro organization
    Given Acme Corp is on the "pro" plan
    And Acme Corp has 3 active users this billing period
    When the billing cycle closes
    Then an invoice for $297.00 is created for Acme Corp
    And the invoice is sent to billing@acme.example
```

## Step Definitions in Python/Behave

Behave uses Python decorators. Step files live in a `steps/` directory by convention:

```python
# steps/billing_steps.py
from behave import given, when, then
from decimal import Decimal

@given('Acme Corp is on the "{plan}" plan')
def step_acme_on_plan(context, plan):
    context.org = context.api.create_org("Acme Corp", plan=plan)

@given('Acme Corp has {count:d} active users this billing period')
def step_acme_active_users(context, count):
    context.api.set_active_users(context.org.id, count)

@when('the billing cycle closes')
def step_billing_cycle_closes(context):
    context.invoice = context.billing.close_cycle(context.org.id)

@then('an invoice for ${amount:g} is created for Acme Corp')
def step_invoice_created(context, amount):
    assert context.invoice is not None
    assert context.invoice.total == Decimal(str(amount))

@then('the invoice is sent to {email}')
def step_invoice_sent(context, email):
    assert context.email_service.last_sent_to == email
```

Key observations:
- **`@given`, `@when`, `@then`** are decorator imports from `behave`
- The **`context` object** is the first argument of every step function — this is Behave's equivalent of the World
- **Format specifiers** (`:d` for integer, `:g` for float) are embedded in step patterns using Python's `parse` library
- Step files can be named anything; Behave loads all `.py` files in the `steps/` directory

## The Context Object

`context` is an object that Behave creates fresh for each scenario. You can attach any attribute to it:

```python
# features/environment.py  (Behave's hooks file)
from myapp.api import ApiClient
from myapp.billing import BillingService
from myapp.email import EmailService

def before_scenario(context, scenario):
    context.api = ApiClient(base_url=context.config.userdata['api_url'])
    context.billing = BillingService(context.api)
    context.email_service = EmailService()

def after_scenario(context, scenario):
    context.api.cleanup()
```

The `environment.py` file (Behave's hooks module) is equivalent to CucumberJS's `Before`/`After` hooks or playwright-bdd's fixtures. Context attributes set in `before_scenario` are available in all steps.

## Custom Type Parsing

Behave uses Python's `parse` library for type coercion. Register custom type parsers in `environment.py`:

```python
# features/environment.py
import parse

@parse.with_pattern(r'free|pro|enterprise')
def parse_org_plan(text):
    plans = {
        'free':       {'billing_enabled': False, 'seat_limit': 5},
        'pro':        {'billing_enabled': True,  'seat_limit': 50},
        'enterprise': {'billing_enabled': True,  'seat_limit': None},
    }
    return plans[text]

def before_all(context):
    context.config.userdata.setdefault('api_url', 'http://localhost:8080')

# Register the parser
register_type(OrgPlan=parse_org_plan)
```

Then use it in step patterns with `{plan:OrgPlan}`.

## Step File Conventions

```
features/
  billing.feature
  users.feature
  environment.py      # hooks and fixtures
steps/
  billing_steps.py
  user_steps.py
  shared_steps.py
```

Behave discovers all `.py` files in `steps/` automatically. Unlike playwright-bdd's scoped step definitions, Behave step definitions are global by default.

## Running Behave

```bash
# Run all features
behave

# Run with tags
behave --tags=@smoke

# Run a specific feature
behave features/billing.feature

# Dry run (check steps are defined)
behave --dry-run
```

## Concept Mapping: Behave → playwright-bdd

| Behave concept | playwright-bdd equivalent |
|---------------|--------------------------|
| `@given` decorator | `Given()` from `createBdd()` |
| `context` object | Fixture parameter (`{ myFixture }`) |
| `environment.py` | `fixtures.ts` + `Before`/`After` hooks |
| `before_scenario` / `after_scenario` | `Before` / `After` hooks |
| `parse` type parser | `defineParameterType` transformer |
| `steps/` directory | Step files loaded via `steps` config |
| `behave --tags=@smoke` | `npx playwright test --grep @smoke` |

## When Teams Cross From Behave

Behave and playwright-bdd share the same Gherkin vocabulary — feature files can often be copied unchanged. The conceptual shift:

1. **`context` → fixtures**: Attributes you set on `context` in `environment.py` become Playwright fixtures. The fixture system is more compositional but requires more explicit wiring.
2. **`parse` patterns → Cucumber Expressions**: Behave's `{count:d}` style maps to `{int}` in Cucumber Expressions.
3. **`environment.py` → hooks + fixtures**: Split `before_scenario` into `Before` hooks (for per-scenario side effects) and fixtures (for injected state).

!!! note "Python backend + TypeScript frontend"
    Teams running both stacks often maintain **shared vocabulary**: the same parameter names (`{org-plan}`, `{user-role}`) across Behave and playwright-bdd suites. The `.feature` files can even be identical when both suites test the same behavior through different layers (API vs. UI).
