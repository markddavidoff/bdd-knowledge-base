---
title: AI Integration
description: Use playwright-bdd's built-in AI features — step export for LLM context, Fix with AI in the HTML reporter, and the agent skill for AI coding agents.
sources:
  - git-playwright-bdd-repo-docs-cli-bddgen-export
  - git-playwright-bdd-repo-docs-guides-fix-with-ai-fix-with-ai
  - git-playwright-bdd-repo-docs-guides-fix-with-ai-how-to-enable
  - git-playwright-bdd-repo-docs-guides-fix-with-ai-limitations
  - git-playwright-bdd-repo-docs-guides-fix-with-ai-prompt-customization
  - git-playwright-bdd-repo-docs-getting-started-agent-skill-agent-skill
  - git-playwright-bdd-repo-docs-getting-started-agent-skill-installation
  - git-playwright-bdd-repo-docs-getting-started-agent-skill-usage
  - git-playwright-bdd-repo-docs-getting-started-agent-skill-supported-agents
  - git-playwright-bdd-repo-index-bdd-in-the-era-of-ai
---

# AI Integration

playwright-bdd provides three distinct AI integration points: a CLI command to export step definitions for LLM context injection, a "Fix with AI" feature that generates repair prompts for failing scenarios, and an agent skill for AI coding agents that writes BDD tests grounded in your actual project steps.

---

## Exporting Step Definitions for AI Tools

The `bddgen export` command prints all registered step definitions to stdout, ready to be pasted into an LLM chat or injected into an agent's system prompt:

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

This is the foundational input for asking an LLM to generate new Gherkin scenarios that use _your_ existing vocabulary — not invented step text the LLM hallucinated.

### Injecting into LLM context

Capture the export and include it in your prompt:

```bash
STEPS=$(npx bddgen export)
```

Then in your LLM prompt:

```
You are a BDD scenario author. Write Gherkin scenarios for the following user story,
using ONLY the step definitions listed below. Do not invent new steps.

Step definitions:
${STEPS}

User story:
As a shopper, I want to view my order history so I can track past purchases.
```

To export only _unused_ step definitions (orphan detection):

```bash
npx bddgen export --unused-steps
```

---

## "Fix with AI" in the HTML Reporter

Available since playwright-bdd v8.1.0 and Playwright v1.49+, "Fix with AI" attaches a pre-generated repair prompt to any failing scenario in the HTML report.

### How to enable

Add `aiFix.promptAttachment: true` to your `defineBddConfig()`:

```ts
// playwright.config.ts
import { defineConfig } from '@playwright/test';
import { defineBddConfig, cucumberReporter } from 'playwright-bdd';

const testDir = defineBddConfig({
  features: 'features/**/*.feature',
  steps: 'features/steps/**/*.ts',
  aiFix: {
    promptAttachment: true,
  },
});

export default defineConfig({
  testDir,
  reporter: [
    cucumberReporter('html', { outputFile: 'cucumber-report/index.html' }),
  ],
});
```

Run the tests normally. When a scenario fails, open the HTML report. Each failing scenario shows a "Fix with AI" attachment with a prompt you can copy directly into ChatGPT, Claude, or any LLM chat.

### What the prompt contains

The auto-generated prompt includes:

- The error message
- The Gherkin scenario steps
- A code snippet from the generated `.spec.ts` file
- An ARIA snapshot of the page at the point of failure

This gives the LLM enough context to diagnose selector issues, step mismatches, and timing problems without you having to assemble the context manually.

### Customizing the prompt template

```ts
const testDir = defineBddConfig({
  aiFix: {
    promptAttachment: true,
    promptTemplate: `You are an expert in Playwright BDD testing.
Fix the failing scenario below. Prefer role-based locators (getByRole, getByLabel).

Scenario: {scenarioName}
{steps}

Error: {error}

{snippet}

Page ARIA snapshot:
{ariaSnapshot}`,
  },
});
```

Available placeholders: `{scenarioName}`, `{steps}`, `{error}`, `{snippet}`, `{ariaSnapshot}`.

### Limitations

The prompt is not generated when:

- The error occurred in a hook (before `page` was initialized)
- The test does not use the `page` fixture (e.g., pure API tests)

In those cases, the failure happened outside the browser context, so there is no ARIA snapshot to include.

---

## Agent Skill for AI Coding Agents

playwright-bdd ships an [agent skill](https://skills.sh/) that equips AI coding agents with a structured BDD workflow grounded in your project's actual step definitions.

### Installation

```bash
npx skills add vitalets/playwright-bdd
```

### Supported agents

GitHub Copilot, Claude Code, Cursor, Cline, Windsurf, and other agents that support the [skills.sh](https://skills.sh/) protocol.

### How it works

Once installed, the agent follows a three-phase BDD workflow:

1. **Planning** — Drafts Gherkin scenarios grounded in your existing step vocabulary. You review and iterate before any code is written.
2. **Implementation** — Builds the feature and wires step definitions matching your existing code style.
3. **Verification** — Runs the generated tests with `npx bddgen && npx playwright test` to confirm everything passes.

The skill uses `bddgen export` internally to ground scenario generation in your actual registered steps, preventing hallucinated step text.

!!! example "Example agent workflow"
    ```
    User: Add a scenario for the checkout flow

    Agent (Planning phase):
    Based on your registered steps, I propose:

    Feature: Checkout
      Scenario: Guest completes checkout with a single item
        Given I am on the product page for "Widget Pro"
        When I add the item to my cart
        And I proceed to checkout as a guest
        Then I see the order confirmation page

    Does this match the intended behavior? Should I add error paths?
    ```

---

## AI-Generated Scenario Review Process

AI-generated scenarios can be syntactically correct Gherkin while describing behaviorally wrong or incomplete specifications. The review process cannot be skipped.

### Why AI scenarios need review

| Risk | Example |
|------|---------|
| Missing edge cases | AI writes happy path only; skips payment failure |
| Wrong vocabulary | AI invents step text not in your step definitions |
| Overly imperative | AI writes "click the Submit button" instead of "submit the form" |
| Redundant coverage | AI generates scenarios already covered by existing features |
| Ambiguous Then steps | AI writes "Then the page is updated" — meaningless assertion |

### Review checklist

- [ ] All steps match registered step definitions (run `npx bddgen` to verify)
- [ ] Scenarios are declarative — no UI mechanism in step text
- [ ] Negative / error paths are covered, not just happy path
- [ ] No duplicate coverage with existing scenarios
- [ ] Three Amigos review: product owner, developer, and QA all sign off

!!! warning "Three Amigos is still required"
    An LLM cannot replace the Three Amigos conversation. The LLM generates candidate scenarios; the team validates whether they describe the correct, agreed-upon behavior. Merging AI-generated scenarios without a product owner review produces unvalidated requirements in executable form.

---

## Cross-references

- [Sync and Hygiene](sync-and-hygiene.md) — detecting undefined steps generated by AI
- [vs. @cucumber/cucumber Runner](vs-cucumber-runner.md) — how the raw runner compares on AI tooling support
