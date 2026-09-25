---
title: pytest-bdd (Python)
description: pytest-bdd's Gherkin subset, pytest fixture injection model, and how it differs fundamentally from context/World-based runners like Behave.
sources:
  - web-playwright-bdd-vs-cucumber-cucumber-js-vs-playwright-bdd-comparison
  - git-gherkin-parser-python-readme-readme
---

# pytest-bdd (Python)

pytest-bdd is a BDD plugin for pytest. It shares the Gherkin syntax but diverges from Behave and CucumberJS on the most fundamental design point: **there is no World or context object**. State flows between steps through pytest fixtures — the same mechanism pytest uses for all other tests.

This makes pytest-bdd the closest conceptual cousin to playwright-bdd's fixture-first design, but the two are still distinct: playwright-bdd uses TypeScript and Playwright Test; pytest-bdd uses Python and pytest.

## A Note on Gherkin Subset

pytest-bdd supports most of Gherkin but historically has had limitations:

- `Background` is supported
- `Rule` keyword was added in later versions — verify against your installed version
- `Scenario Outline` is supported as `Scenario Template` (or `Scenario Outline` in newer versions)
- Tag filtering delegates to pytest's `-k` expression, not a `--tags` expression

Always test with your installed version:

```bash
pip show pytest-bdd
```

## The Same Feature File

```gherkin
Feature: Payment processing

  Scenario: Successful payment with a valid card
    Given Sam has a "pro" subscription
    And Sam's payment method is "visa-ending-4242"
    When Sam triggers a manual billing run
    Then the payment succeeds
    And Sam's subscription renews for 30 days
```

## Step Definitions in pytest-bdd

In pytest-bdd, steps are functions decorated with `@given`, `@when`, `@then` from `pytest_bdd`. State is shared by **yielding fixtures**, not by attaching to a context object.

```python
# tests/conftest.py
import pytest
from pytest_bdd import given, when, then, parsers
from myapp.api import ApiClient

@pytest.fixture
def api_client():
    return ApiClient(base_url='http://localhost:8080')

@pytest.fixture
def payment_result():
    # A mutable container for sharing state across steps
    return {}
```

```python
# tests/test_payment.py
from pytest_bdd import scenario, given, when, then, parsers
from myapp.models import Subscription

@scenario('features/payment.feature', 'Successful payment with a valid card')
def test_successful_payment():
    pass  # The scenario decorator does all the work

@given(parsers.parse('Sam has a "{plan}" subscription'))
def sam_subscription(api_client, plan):
    sub = api_client.create_subscription('sam@example.com', plan=plan)
    return sub  # Returned value becomes a fixture

@given(parsers.parse('Sam\'s payment method is "{method}"'), target_fixture='payment_method')
def sam_payment_method(api_client, method):
    return api_client.get_payment_method(method)

@when("Sam triggers a manual billing run", target_fixture='payment_result')
def trigger_billing(api_client, sam_subscription, payment_method):
    return api_client.charge(sam_subscription.id, payment_method.id)

@then("the payment succeeds")
def payment_succeeds(payment_result):
    assert payment_result['status'] == 'succeeded'

@then("Sam's subscription renews for 30 days")
def subscription_renewed(api_client, sam_subscription):
    sub = api_client.get_subscription(sam_subscription.id)
    assert sub.days_remaining == 30
```

## The Key Difference: Fixtures, Not Context

This is the most important architectural distinction:

| Pattern | Behave | pytest-bdd | playwright-bdd |
|---------|--------|-----------|----------------|
| State model | `context` object | pytest fixtures by name | Playwright fixtures by parameter |
| State sharing | `context.foo = bar` | `target_fixture='foo'` | fixture yielded in `test.extend` |
| Step signature | `(context, param)` | `(fixture_name, param)` | `({ fixtureName }, param)` |
| Setup/teardown | `environment.py` | `conftest.py` | `fixtures.ts` + hooks |

In pytest-bdd, a `@given` step can **return a value** (or yield for teardown). That value becomes a pytest fixture available to subsequent steps by name. This is closer to how playwright-bdd fixtures work than Behave's context pattern.

## Registering Scenarios

Unlike Behave (which auto-discovers feature files), pytest-bdd requires each scenario to be explicitly bound to a test function:

```python
@scenario('features/payment.feature', 'Successful payment with a valid card')
def test_successful_payment():
    pass
```

For bulk registration, use `scenarios()`:

```python
from pytest_bdd import scenarios

scenarios('features/')  # Registers all scenarios in the directory
```

## Running pytest-bdd

```bash
# Run all BDD tests
pytest tests/

# Run with a tag filter (pytest -k expression)
pytest tests/ -k "smoke"

# Run a specific feature
pytest tests/ --feature features/payment.feature

# Verbose output
pytest tests/ -v
```

## Concept Mapping: pytest-bdd → playwright-bdd

| pytest-bdd concept | playwright-bdd equivalent |
|-------------------|--------------------------|
| `@given` decorator | `Given()` from `createBdd()` |
| `target_fixture='name'` | Fixture yielded in `test.extend` |
| `conftest.py` fixtures | `fixtures.ts` with `test.extend` |
| `parsers.parse('{int:d}')` | `{int}` Cucumber Expression |
| `@scenario(...)` | No equivalent (auto-discovery) |
| `scenarios('features/')` | `features: 'features/**/*.feature'` in config |
| `pytest -k "smoke"` | `npx playwright test --grep @smoke` |

## When to Use pytest-bdd

- **Existing pytest infrastructure**: Database fixtures, mocked services, and shared test helpers already exist as pytest fixtures — pytest-bdd reuses them directly
- **Python microservices**: Testing service behavior through its Python API, not through a browser
- **pytest ecosystem preference**: pytest plugins (coverage, hypothesis, fixtures) that your team already relies on

!!! note "pytest-bdd vs. Behave"
    Choose **pytest-bdd** when your team already uses pytest heavily and wants BDD scenarios to feel like regular pytest tests. Choose **Behave** when you want a standalone BDD runner without pytest coupling, or when the `context` object model feels more natural to your team.
