---
title: Doc Strings
description: Reference for Gherkin doc strings — the triple-quote delimiter, content type annotation, use cases, and defineDocStringType transformers.
sources:
  - git-playwright-bdd-repo-docs-writing-steps-doc-strings-doc-strings
  - git-playwright-bdd-repo-docs-writing-steps-doc-strings-using-content
  - git-playwright-bdd-repo-docs-writing-steps-doc-strings-using-media-types
  - git-gherkin-parser-testdata-good-docstrings-feature-feature-docstring-variations
---

# Doc Strings

A **doc string** (also called a "py string" in older Cucumber literature) attaches a verbatim multi-line block of text to a single Gherkin step. It is the right tool when a step needs structured text — a JSON payload, a YAML config snippet, an expected email body — that would be awkward to express as inline parameters or a table.

---

## Syntax

Doc strings are delimited by triple double-quotes (`"""`). Everything between the opening and closing delimiters is passed verbatim to the step definition as a `string`. Leading whitespace that is common to all lines (up to the indentation of the opening delimiter) is stripped.

```gherkin
Feature: API request body

  Scenario: Create a user via the API
    When I POST to "/users" with body:
      """
      {
        "name": "Alice",
        "role": "admin",
        "plan": "enterprise"
      }
      """
    Then the response status is 201
```

The step receives the content between the delimiters as a plain `string` argument — it is the **last positional argument** after any Cucumber Expression captures.

```ts
import { createBdd } from 'playwright-bdd';

const { When } = createBdd();

When(
  'I POST to {string} with body:',
  async ({ request }, path: string, body: string) => {
    const response = await request.post(path, {
      data: JSON.parse(body),
    });
    expect(response.ok()).toBeTruthy();
  }
);
```

---

## Content type annotation

Append a **media type** immediately after the opening `"""` to signal what format the content is in:

```gherkin
Scenario: Validate a YAML config upload
  When I upload the configuration:
    """yaml
    database:
      host: localhost
      port: 5432
    cache:
      ttl: 300
    """
```

playwright-bdd exposes the declared media type via the `$step.docStringType` property. The content itself is still passed as a raw `string` — parsing is the step definition's responsibility.

```ts
import { createBdd } from 'playwright-bdd';
import * as yaml from 'js-yaml';

const { When } = createBdd();

When(
  'I upload the configuration:',
  async ({ configService, $step }, rawDoc: string) => {
    if ($step.docStringType === 'yaml') {
      const config = yaml.load(rawDoc);
      await configService.upload(config);
    } else if ($step.docStringType === 'json') {
      await configService.upload(JSON.parse(rawDoc));
    } else {
      throw new Error(`Unsupported doc string type: ${$step.docStringType}`);
    }
  }
);
```

!!! note "Version requirement"
    `$step.docStringType` is available in playwright-bdd **8.6.0 and later**. Earlier versions receive only the raw string with no type metadata.

Common media type annotations:

| Annotation | Typical use |
|---|---|
| `json` | REST request/response bodies |
| `yaml` | Configuration, OpenAPI snippets |
| `xml` | SOAP payloads, HTML fragments |
| `graphql` | GraphQL query strings |
| (none) | Plain text, free-form prose |

---

## `defineDocStringType` — custom transformers

Register a `defineDocStringType` to automatically transform the raw string before it reaches the step definition. This is the doc string equivalent of `defineParameterType`.

```ts
import { defineDocStringType } from 'playwright-bdd';

// Automatically parse JSON doc strings into objects
defineDocStringType({
  typeName: 'json',
  transform(docString: string) {
    return JSON.parse(docString);
  },
});
```

With this registered, a step expecting an `object` instead of a `string` receives the parsed value directly:

```ts
When(
  'I POST to {string} with body:',
  async ({ request }, path: string, body: object) => {
    const response = await request.post(path, { data: body });
    expect(response.ok()).toBeTruthy();
  }
);
```

!!! tip "Keep transformers pure"
    Doc string transformers should be synchronous and side-effect-free. Parsing JSON or YAML is the right job here; making HTTP calls or touching the DB is not.

---

## Use cases

### JSON API payloads

The most common use. The doc string carries the exact request body, making the scenario readable as a mini API specification:

```gherkin
Scenario: Reject a user creation request missing required fields
  When I POST to "/users" with body:
    """json
    {
      "name": "Bob"
    }
    """
  Then the response status is 422
  And the response body contains:
    """json
    {
      "error": "role is required"
    }
    """
```

### Multi-line expected output

Use a doc string in a `Then` step to assert on multi-line console output, email content, or rendered text:

```gherkin
Then the welcome email body is:
  """
  Hello Alice,

  Your enterprise account is ready.
  Login at https://app.example.com

  The Team
  """
```

### Multi-line configuration

When a scenario tests configuration ingestion, a doc string expresses the config naturally:

```gherkin
Given the rate-limit policy is:
  """yaml
  window: 60s
  max_requests: 100
  burst: 20
  """
```

---

## Escaping the delimiter

If the content itself contains `"""`, use backticks as an alternative delimiter (three backticks: ` ``` `). This is a Gherkin parser feature — the outer delimiter and the content delimiter must differ.

---

## Doc strings vs. data tables

| Use doc strings when… | Use data tables when… |
|---|---|
| Content is free-form or structured text (JSON, YAML, prose) | Content is clearly tabular (multiple entities, key-value pairs) |
| Preserving exact formatting matters | You need iteration over rows |
| The payload is opaque to Gherkin | Fields have semantic meaning in the scenario |

---

## Cross-references

- [Data Tables](data-tables.md) — structured tabular input
- [Custom Parameter Types](custom-parameter-types.md) — type transformers for inline step parameters
