---
title: Suite Health Metrics and KPIs
description: Pass rate, flakiness rate, duration trend, undefined step count, scenario growth — health metrics for a large BDD suite, with reporting and alerting patterns.
sources:
  - git-playwright-bdd-repo-docs-reporters-allure-allure
  - git-playwright-bdd-repo-docs-reporters-cucumber-html
  - git-cucumber-js-docs-configuration-options
---

# Suite Health Metrics and KPIs

At scale, a BDD suite can degrade faster than individual contributors notice. Flakiness accumulates test by test. Duration creeps by seconds per scenario. Undefined steps pile up when refactors break step text. Suite health metrics make this degradation visible before it becomes a crisis.

## The Six Core Health Metrics

### 1. Pass Rate on Main

**Target: >99% green on `main`**

A BDD suite that is not green on `main` is not living documentation — it is broken documentation. Track the rolling 7-day pass rate:

```
Pass rate = (passing scenarios / total scenarios) × 100
```

A pass rate below 99% indicates one of:
- Genuine production regression (fix immediately)
- Flaky tests that are not quarantined (apply `@quarantine` and file a ticket)
- Environment issues (investigate and document)

### 2. Flakiness Rate

**Target: <1% of scenarios**

Flakiness rate is the percentage of scenarios that have failed at least once in the last N runs on `main` without a corresponding code change. Flakiness erodes trust: once developers learn to "re-run and it'll pass," they stop trusting failure signals.

Detection: a scenario that passes on retry is flaky.

```typescript
// playwright.config.ts — surface flakiness in CI output
export default defineConfig({
  retries: process.env.CI ? 2 : 0,
  reporter: [
    ['html'],
    ['json', { outputFile: 'test-results/results.json' }],
  ],
});
```

Parse the JSON report to count retried-then-passed scenarios:

```bash
node -e "
const r = require('./test-results/results.json');
const flaky = r.suites.flatMap(s => s.specs)
  .filter(s => s.tests.some(t => t.results.length > 1 && t.results.at(-1).status === 'passed'));
console.log('Flaky count:', flaky.length);
flaky.forEach(s => console.log(' -', s.title));
"
```

### 3. Suite Duration Trend

**Target: <10 minutes on the critical path; trend not increasing >5% per sprint**

Track wall-clock time per CI run over time. A duration increase of more than 5% per sprint without a corresponding scenario count increase signals a performance problem in individual scenarios.

```bash
# Extract duration from Playwright JSON report
node -e "
const r = require('./test-results/results.json');
const durationMs = r.stats.duration;
console.log('Suite duration:', Math.round(durationMs / 1000), 'seconds');
" >> duration-history.log
```

Commit `duration-history.log` to track the trend (or push to a time-series database).

### 4. Undefined Step Count

**Target: 0 in CI**

An undefined step means a feature file references a step pattern for which no step definition exists. This is the equivalent of a broken link in documentation. Zero tolerance on `main`.

Enforce in CI with `bddgen`'s strict mode:

```bash
npx bddgen --dry-run  # Exits non-zero if any steps are undefined
```

Or detect via the Playwright output:

```bash
npx playwright test 2>&1 | grep -c "Not implemented"
# Must be 0 for a passing health check
```

### 5. Scenario Count Growth Rate

**Target: positive but not unconstrained**

Track the number of scenarios per sprint. A healthy BDD practice adds scenarios when new behavior is added and removes scenarios when behavior is removed. Monotonic growth without any deletion is a smell — it suggests scenarios are not being maintained as specifications but are accumulating as tests.

```bash
# Count scenarios across all feature files
grep -r "Scenario:" e2e/features/ | wc -l
grep -r "Scenario Outline:" e2e/features/ | wc -l
```

### 6. Vocabulary Registry Freshness

**Target: all parameter types in use; none referenced but unregistered**

Audit the vocabulary registry against active usage quarterly:

```bash
# Find parameter type names defined in parameters.ts
grep "name:" packages/shared/parameters/index.ts | awk '{print $2}'

# Find parameter type references in feature files
grep -rh '{[a-z-]*}' e2e/features/ | grep -oP '\{[a-z-]+\}' | sort | uniq -c | sort -rn
```

Cross-reference: any type defined but not used in any feature file is a candidate for removal. Any type used in feature files but not registered in the registry is an undefined parameter type (will silently match as a string).

## Health Dashboard Setup

### Option 1: Allure with Historical Tracking

Allure stores test history and renders trend charts out of the box:

```typescript
// playwright.config.ts
export default defineConfig({
  reporter: [
    ['allure-playwright', {
      detail: true,
      outputFolder: 'allure-results',
      suiteTitle: false,
    }],
  ],
});
```

```bash
# Generate and open Allure report with history
npx allure generate allure-results --clean -o allure-report
npx allure open allure-report
```

### Option 2: GitHub Actions Summary Dashboard

Write health metrics to the GitHub Actions job summary:

```yaml
- name: Compute suite health
  run: |
    node scripts/health-report.js >> $GITHUB_STEP_SUMMARY
```

```javascript
// scripts/health-report.js
const results = require('./test-results/results.json');
const { stats } = results;
const passRate = ((stats.expected / stats.total) * 100).toFixed(1);
const flaky = results.suites.flatMap(s => s.specs)
  .filter(s => s.tests.some(t => t.results.length > 1 && t.results.at(-1).status === 'passed'));

console.log(`## Suite Health Report`);
console.log(`| Metric | Value | Target |`);
console.log(`|--------|-------|--------|`);
console.log(`| Pass rate | ${passRate}% | ≥99% |`);
console.log(`| Flaky scenarios | ${flaky.length} | 0 |`);
console.log(`| Duration | ${Math.round(stats.duration / 1000)}s | <600s |`);
console.log(`| Total scenarios | ${stats.total} | — |`);
```

## Alerting on Health Degradation

Fail CI on health threshold violations:

```bash
# health-gate.sh
PASS_RATE=$(node -e "
const r = require('./test-results/results.json');
console.log((r.stats.expected / r.stats.total * 100).toFixed(1));
")

if (( $(echo "$PASS_RATE < 99" | bc -l) )); then
  echo "FAIL: Pass rate $PASS_RATE% is below 99% threshold"
  exit 1
fi

DURATION=$(node -e "
const r = require('./test-results/results.json');
console.log(Math.round(r.stats.duration / 1000));
")

if [ "$DURATION" -gt 600 ]; then
  echo "WARN: Suite duration ${DURATION}s exceeds 600s target"
fi

echo "Suite health OK: pass rate $PASS_RATE%, duration ${DURATION}s"
```

## Reporting to Stakeholders

Stakeholders care about different metrics than developers. A monthly health report for non-technical stakeholders:

```
BDD Suite Health — June 2026
----------------------------
✅ Behavior coverage: 247 scenarios (up from 231 last month)
✅ Suite reliability: 99.7% pass rate on main (target: ≥99%)
⚠️  3 scenarios quarantined for flakiness (filed for Q3 sprint)
✅ CI time: 8.2 minutes average (target: <10 minutes)
✅ Undefined steps: 0 (all scenarios have implementations)
```

This connects the engineering health metrics to business value: coverage growth shows the spec is alive; high pass rate shows the suite is trustworthy; CI time shows the team is not bottlenecked.

!!! warning "The quarantine trap"
    `@quarantine` is a parking lot, not a solution. A quarantined scenario is a behavior that the team cannot reliably verify. Set a policy: quarantined scenarios must be fixed or deleted within one sprint. A growing quarantine backlog is a leading indicator of suite health collapse.
