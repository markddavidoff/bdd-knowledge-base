---
title: Exporting Steps for AI
description: Using bddgen export to produce a step list for LLM context — output format, injection strategies, and keeping the export in sync with CI.
sources:
  - git-playwright-bdd-repo-docs-cli-bddgen-export
  - git-playwright-bdd-repo-docs-writing-features-chatgpt-chatgpt
  - git-playwright-bdd-repo-docs-getting-started-agent-skill-usage
---

# Exporting Steps for AI

The most important constraint when asking an LLM to write BDD scenarios is preventing it from inventing step text that has no TypeScript implementation. Without a constraint, the LLM writes steps that sound natural but produce "undefined step" errors when `bddgen` runs.

`bddgen export` solves this by printing a list of every step definition discovered in your project — in a format designed for paste-into-prompt injection.

## Running the Export

```bash
npx bddgen export
```

Example output:

```
Using config: playwright.config.ts
List of all steps (4):

* Given I am on todo page
* When I add todo {string}
* When I remove todo {string}
* Then visible todos count is {int}
```

The export reads your `playwright.config.ts` to discover step definition files, loads them, and prints every `Given`, `When`, and `Then` pattern it finds. It does not run any tests.

### Options

```bash
# Use a specific config file
npx bddgen export --config path/to/playwright.config.ts

# Show only steps not referenced by any feature file
npx bddgen export --unused-steps
```

`--unused-steps` is useful for identifying orphaned step definitions — steps that are implemented but never called from any `.feature` file.

## Injecting into LLM Context

### Direct Prompt Injection

Paste the export output directly into your prompt:

```
Generate BDD scenarios in Gherkin for the following user story:

As a user, I want to manage my todo list so that I can track what needs to be done.

Constraints:
- Format output as a single .feature file
- Include user story text in the Feature description
- Use Background for steps common to all scenarios
- Use "And" for repeated keyword sequences
- STRICTLY use only these step definitions:

* Given I am on todo page
* When I add todo {string}
* When I remove todo {string}
* Then visible todos count is {int}
```

The `STRICTLY use only` constraint is important. Without explicit language telling the LLM not to invent steps, it will add variations like `When I click the add button` that have no implementation.

### System Prompt Injection

For workflows where the LLM has a persistent system prompt (e.g., an agent or IDE assistant), include the step export in the system context:

```
You are a BDD scenario author for this project. When writing Gherkin scenarios,
you MUST use ONLY the following step definitions. Do not invent new step text.

Available steps:
* Given I am on todo page
* When I add todo {string}
* When I remove todo {string}
* Then visible todos count is {int}

If a user story requires behavior that has no matching step, note the missing step
and write a [MISSING STEP] placeholder — do not invent step text.
```

The `[MISSING STEP]` convention is useful because it makes gaps visible without blocking the LLM from producing the rest of the scenario.

### RAG Retrieval at Query Time

For large codebases with hundreds of step definitions, injecting the full export may exceed context limits. Use retrieval instead:

1. Embed each step definition text at export time.
2. At scenario-authoring time, retrieve the top-N most semantically similar steps given the user story description.
3. Inject only the retrieved steps into the prompt.

```bash
# Export to file for embedding
npx bddgen export --config playwright.config.ts > steps.txt

# Or export as JSON for programmatic processing (if supported by your tooling)
```

!!! tip "More steps = better LLM behavior, up to a point"
    Injecting 50-100 steps usually produces better results than injecting 10, because the LLM has more vocabulary to choose from. Beyond ~200 steps, the prompt gets long enough that retrieval is worth implementing.

## Keeping the Export in Sync with CI

The step export reflects the current state of your TypeScript step definitions. If you cache it for use in prompts, it must be regenerated whenever step definitions change.

### CI-Triggered Export Update

```yaml
# .github/workflows/update-steps.yml
on:
  push:
    paths:
      - 'features/steps/**/*.ts'
      - 'playwright.config.ts'

jobs:
  update-steps:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
      - run: npm ci
      - run: npx bddgen export > .ai/steps.txt
      - uses: EndBug/add-and-commit@v9
        with:
          add: '.ai/steps.txt'
          message: 'chore: update step export for AI context'
```

Committing the step export as `.ai/steps.txt` means AI agents and developer workflows can read it without running `bddgen export` themselves.

### Pre-Push Validation

Alternatively, block pushes where the committed step export is out of date:

```bash
# .husky/pre-push
npx bddgen export > /tmp/steps-current.txt
if ! diff -q /tmp/steps-current.txt .ai/steps.txt > /dev/null; then
  echo "ERROR: .ai/steps.txt is out of date. Run: npx bddgen export > .ai/steps.txt"
  exit 1
fi
```

## Example: Full Workflow

```typescript
// features/steps/todo.steps.ts
import { createBdd } from 'playwright-bdd';
import { test } from './fixtures';

const { Given, When, Then } = createBdd(test);

Given('I am on todo page', async ({ page }) => {
  await page.goto('https://demo.playwright.dev/todomvc/');
});

When('I add todo {string}', async ({ page }, text: string) => {
  await page.locator('input.new-todo').fill(text);
  await page.locator('input.new-todo').press('Enter');
});

When('I remove todo {string}', async ({ page }, text: string) => {
  const todo = page.getByTestId('todo-item').filter({ hasText: text });
  await todo.hover();
  await todo.getByRole('button', { name: 'Delete' }).click();
});

Then('visible todos count is {int}', async ({ page }, count: number) => {
  await expect(page.getByTestId('todo-item')).toHaveCount(count);
});
```

Run `npx bddgen export` to get the step list, paste into a prompt, and the LLM will produce a valid feature file using exactly these four steps.

## See Also

- [Scenario Authoring](scenario-authoring.md) — full prompting strategy including ubiquitous language injection
- [Step Scaffolding](step-scaffolding.md) — the reverse: generating step defs from a feature file
- [KB as Context](kb-as-context.md) — combining step export with KB chunks for richer AI context
