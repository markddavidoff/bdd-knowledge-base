---
title: Scoped Step Definitions
description: Restrict playwright-bdd step definitions to specific features or domains using tag-based scoping and @-prefixed directory conventions.
sources:
  - git-playwright-bdd-repo-docs-writing-steps-scoped-scoped
  - git-playwright-bdd-repo-docs-writing-steps-scoped-default-tags
  - git-playwright-bdd-repo-docs-writing-steps-scoped-tags-from-path
  - git-playwright-bdd-repo-docs-blog-whats-new-in-v8-tagging-enhancements
---

# Scoped Step Definitions

By default, playwright-bdd step definitions are global — they apply to every feature file in the project. This follows the Cucumber design of reusable steps, but in large suites it creates friction: two features can share a step phrase that has different implementations, and playwright-bdd will error on the ambiguity.

Scoped step definitions solve this by binding a step to a tag expression, so it only applies to features or scenarios carrying a matching tag.

## The Problem: Step Collision

Imagine a game domain and a video-player domain both defining a `When I click the PLAY button` step with different implementations:

```
Error: Multiple definitions matched scenario step!
Step: When I click the PLAY button # game.feature:6:5
  - When 'I click the PLAY button' # game.steps.ts:5
  - When 'I click the PLAY button' # video-player.steps.ts:5
```

Renaming one of the steps to avoid collision forces the Gherkin to diverge from its natural phrasing. Scoping keeps the natural language intact.

## Tag-Based Scoping

Pass a `tags` option as the second argument to a step definition:

```ts
// game.steps.ts
import { createBdd } from 'playwright-bdd';
import { test } from './fixtures';

const { When } = createBdd(test);

When('I click the PLAY button', { tags: '@game' }, async ({ page }) => {
  await page.getByRole('button', { name: 'Play' }).click();
});
```

```ts
// video-player.steps.ts
const { When } = createBdd(test);

When('I click the PLAY button', { tags: '@video-player' }, async ({ page }) => {
  await page.locator('.player-controls .play').click();
});
```

Tag the corresponding feature files to activate the right implementation:

```gherkin
@game
Feature: Game

  Scenario: Start playing
    When I click the PLAY button
```

```gherkin
@video-player
Feature: Video Player

  Scenario: Start playing
    When I click the PLAY button
```

Each feature now uses its own step implementation without conflict.

## Default Tags via createBdd()

When an entire step file belongs to one domain, set default tags on the `createBdd()` call instead of repeating them on every step:

```ts
// game.steps.ts
const { Given, When, Then } = createBdd(test, { tags: '@game' });

// All steps in this file are automatically scoped to @game
When('I click the PLAY button', async ({ page }) => {
  // game implementation
});

Given('the game is loaded', async ({ page }) => {
  // game implementation
});
```

```ts
// video-player.steps.ts
const { Given, When, Then } = createBdd(test, { tags: '@video-player' });

When('I click the PLAY button', async ({ page }) => {
  // different implementation — no conflict
});
```

This is the recommended approach for domain-specific step files — it prevents accidentally forgetting the scope on individual steps.

## Tags from Path: @-Prefixed Directories

playwright-bdd v8+ supports automatic tag assignment through `@`-prefixed directory names. This eliminates all manual tagging for scoping:

```
features/
├── @game/
│   ├── game.feature        # automatically has @game tag
│   └── steps.ts            # all steps automatically scoped to @game
└── @video-player/
    ├── video-player.feature
    └── steps.ts
```

Steps in `@game/steps.ts` need no explicit tags — the directory name provides the scope:

```ts
// @game/steps.ts — no tags needed
const { When } = createBdd(test);

When('I click the PLAY button', async ({ page }) => {
  // only applies to @game features by virtue of the directory
});
```

You can also use `@`-prefixed filenames to keep features and steps in separate trees:

```
features/
├── @game.feature
└── @video-player.feature
steps/
├── @game.ts
└── @video-player.ts
```

## Shared Steps Pattern

Steps that genuinely apply across domains belong in a shared file with no scope restriction:

```
features/
├── @checkout/
│   ├── checkout.feature
│   └── steps.ts            # scoped to @checkout
├── @catalog/
│   ├── catalog.feature
│   └── steps.ts            # scoped to @catalog
└── shared-steps.ts         # global — applies everywhere
```

`shared-steps.ts` uses `createBdd()` without tags:

```ts
// shared-steps.ts
const { Given, Then } = createBdd(test);

Given('I am logged in as {string}', async ({ page }, role: string) => {
  // available in all features
});

Then('I see a success message', async ({ page }) => {
  await expect(page.getByRole('alert')).toHaveText(/success/i);
});
```

## Monorepo Application

In a monorepo, combine scoped directories with per-project `importTestFrom` configuration:

```ts
// playwright.config.ts
export default defineConfig({
  projects: [
    {
      name: 'checkout',
      testDir: defineBddConfig({
        features: 'features/@checkout/**/*.feature',
        steps: ['features/@checkout/steps.ts', 'features/shared-steps.ts'],
        importTestFrom: 'features/fixtures.ts',
      }),
    },
    {
      name: 'catalog',
      testDir: defineBddConfig({
        features: 'features/@catalog/**/*.feature',
        steps: ['features/@catalog/steps.ts', 'features/shared-steps.ts'],
        importTestFrom: 'features/fixtures.ts',
      }),
    },
  ],
});
```

Each project loads only its scoped steps plus the shared ones, keeping the global step namespace clean and preventing cross-domain step pollution.

!!! tip
    In large suites, prefer `@`-prefixed directories over per-step `tags` options. Directory scoping is automatic and eliminates the bug class where a step file grows to include un-scoped steps that collide elsewhere.

!!! warning
    Scoped steps only fire for features/scenarios that match the tag expression. If you omit the required tag from a feature file, playwright-bdd reports an undefined step rather than silently using the wrong implementation — check your feature file tags when this happens.

!!! note
    Tag expressions in step scopes support the full Cucumber tag expression syntax: `@foo and not @bar`, `@foo or @baz`, and nested parentheses. A single implementation can cover multiple domains: `{ tags: '@checkout or @cart' }`.

## Cross-references

- [Tags and Filtering](tags-and-filtering.md) — running subsets of scenarios by tag at execution time
- [Decorators](decorators.md) — the `@fixture:name` tag for controlling POM fixture selection
- [Writing Steps](writing-steps.md) — createBdd() API and fixture injection
