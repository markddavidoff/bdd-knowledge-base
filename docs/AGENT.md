# BDD KB — Agent Index

Quick-reference for Claude Code agents. Full docs under `docs/` (132 pages, 2 tabs).

## What's Here

**Gherkin tab** (`docs/gherkin/`): Language reference (keywords, step types, scenario outline, data tables, custom parameter types, Gherkin AST/Messages), best practices (declarative vs. imperative, ubiquitous language, named test data catalog, anti-patterns), and 13 feature file examples.

**BDD in Practice tab** (`docs/practice/`): Methodology (Example Mapping, Three Amigos, living documentation), adoption (why BDD fails, first 90 days, brownfield), spec lifecycle (CI running + enforcement, flaky tests, maintenance), playwright-bdd v8.4 (installation through at-scale patterns), implementation examples with full TypeScript + feature file pairs, tooling (gherkin-utils, gherkin-lint, pre-commit hooks), AI-assisted BDD, related ecosystem (CucumberJS, SpecFlow, Behave), and BDD at scale.

## 8 Highest-Value Pages (read first for a new BDD project)

1. `docs/gherkin/best-practices/declarative-vs-imperative.md` — the fundamental design principle: describe behavior, not mechanism
2. `docs/practice/playwright-bdd/typescript-config.md` — ESM/CJS pitfalls, `createBdd<Fixtures>()` type parameter
3. `docs/gherkin/reference/custom-parameter-types.md` — `defineParameterType`, Object Mother pattern in Gherkin
4. `docs/practice/playwright-bdd/writing-steps.md` — three step styles (createBdd, World/legacy, decorator)
5. `docs/practice/playwright-bdd/test-isolation.md` — N-worker DB strategies, fixture scopes, BeforeFeature gap
6. `docs/gherkin/best-practices/named-test-data-catalog.md` — Object Mother + Builder pattern in Gherkin
7. `docs/practice/playwright-bdd/fixtures.md` — fixture injection, worker scope, anti-patterns
8. `docs/gherkin/best-practices/anti-patterns.md` — 15 anti-patterns with fixes

## Task → Page Map (mirrors `bdd-kb` skill routing)

| Task type | Pages to read |
|---|---|
| `scenario-authoring` | `docs/gherkin/best-practices/declarative-vs-imperative.md`, `docs/gherkin/best-practices/scenario-structure.md`, `docs/gherkin/best-practices/ubiquitous-language.md`, `docs/gherkin/examples/hello-world.md` |
| `step-definitions` | `docs/practice/playwright-bdd/writing-steps.md`, `docs/practice/playwright-bdd/fixtures.md`, `docs/gherkin/reference/custom-parameter-types.md` |
| `playwright-bdd-setup` | `docs/practice/playwright-bdd/installation.md`, `docs/practice/playwright-bdd/configuration.md`, `docs/practice/playwright-bdd/typescript-config.md` |
| `test-isolation` | `docs/practice/playwright-bdd/test-isolation.md`, `docs/practice/playwright-bdd/parallelism.md`, `docs/practice/playwright-bdd/fixtures.md` |
| `ci` | `docs/practice/spec-lifecycle/ci-running.md`, `docs/practice/spec-lifecycle/ci-enforcement.md`, `docs/practice/playwright-bdd/sync-and-hygiene.md` |
| `debugging` | `docs/practice/playwright-bdd/debugging.md`, `docs/practice/playwright-bdd/sync-and-hygiene.md`, `docs/practice/playwright-bdd/typescript-config.md` |
| `parameter-types` | `docs/gherkin/reference/custom-parameter-types.md`, `docs/gherkin/best-practices/named-test-data-catalog.md`, `docs/practice/examples/domain-parameter-registry.md` |

## Chunk Prefix → Topic Map (for direct `dataset/normalized/` access)

| Prefix | Content |
|---|---|
| `git-playwright-bdd-repo-docs-*` | playwright-bdd v8.4 official docs |
| `git-cucumber-js-docs-*` | CucumberJS API + step definitions |
| `web-cucumber-gherkin-reference-*` | Gherkin language spec |
| `web-automation-panda-*` | BDD best practices (Andy Knight) |
| `issue-playwright-bdd-issues-*` | Real-world gotchas, workarounds, undocumented behaviors |
| `web-martinfowler-*` | Object Mother, DDD concepts |
| `git-cucumber-expressions-*` | Cucumber Expressions + parameter types |
| `git-gherkin-lint-*` | gherkin-lint rules + configuration |
| `git-gherkin-utils-*` | gherkin-utils formatter + GherkinDocumentWalker |

## 5 Things Agents Get Wrong About playwright-bdd

1. **ESM/CJS mismatch** — `"type": "module"` in `package.json` requires `"module": "NodeNext"` in `tsconfig.json` AND `.js` extensions on all relative imports
2. **Missing type parameter** — `createBdd()` not `createBdd<MyFixtures>()` loses all fixture type safety; TypeScript won't catch missing fixtures at compile time
3. **Arrow functions in Cucumber style** — Cucumber-style steps (`Given`, `When`, `Then` from `@cucumber/cucumber`) REQUIRE `function` keyword (not arrow functions) to access `this` World; `createBdd()` style uses arrow functions
4. **`defineParameterType` in decorator mode** — vitalets/playwright-bdd#112: custom parameter types must be imported separately when using decorator-style steps; cannot be defined in the same file as `@Fixture`/`@Given`/etc.
5. **`BeforeFeature`/`AfterFeature` gap** — playwright-bdd has no per-feature lifecycle hooks; use worker-scoped fixtures with lazy initialization (`let initialized = false`) instead

## 3 Most Common Gherkin Anti-Patterns

1. **Imperative UI steps** — "When I click the submit button" instead of "When I submit the form." Fix: define vocabulary at the domain level; hide UI mechanics in step definitions.
2. **Magic string test data** — `Given a user with email "test@example.com"` is brittle and non-semantic. Fix: use named resources via `defineParameterType` (`Given a pro organization`).
3. **Spec-code decoupling** — feature files not updated when behavior changes → "rotten documentation." Fix: `npx bddgen --dry-run` in CI hard-fails on undefined steps, catching drift immediately.
