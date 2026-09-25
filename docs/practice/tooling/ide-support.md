---
title: IDE Support
description: VS Code and IntelliJ/WebStorm setup for Gherkin authoring — step autocomplete, go-to-definition, undefined step highlighting, and debug launch configuration.
sources:
  - git-playwright-bdd-repo-docs-guides-ide-integration-ide-integration
  - git-playwright-bdd-repo-docs-guides-ide-integration-vs-code
---

# IDE Support

playwright-bdd's pre-generation approach means generated `.spec.ts` files are ordinary Playwright test files. This lets every Playwright IDE integration work without special plugins. The Gherkin authoring layer — step autocomplete, go-to-definition, undefined step warnings — is handled by a separate Cucumber extension.

## VS Code

### Recommended Extensions

Two VS Code extensions support Gherkin authoring. Install **one**, not both — they conflict when both are active.

| Extension | Publisher | Notes |
|-----------|-----------|-------|
| Cucumber (Gherkin) Full Support | `alexkrechik` | Community, feature-rich autocomplete |
| Official Cucumber extension | `CucumberOpen` | Official, newer, fewer config options |

!!! warning "Do not enable both"
    If both `alexkrechik.cucumberautocomplete` and `CucumberOpen.cucumber-official` are enabled simultaneously, VS Code does not handle them correctly. Disable one before enabling the other.

### Cucumber (Gherkin) Full Support — Configuration

Add to `.vscode/settings.json` in your project root:

```json
{
  "cucumberautocomplete.steps": ["features/steps/*.{ts,js}"],
  "cucumberautocomplete.strictGherkinCompletion": false,
  "cucumberautocomplete.strictGherkinValidation": false,
  "cucumberautocomplete.smartSnippets": true,
  "cucumberautocomplete.onTypeFormat": true,
  "editor.quickSuggestions": {
    "comments": false,
    "strings": true,
    "other": true
  }
}
```

**Key settings:**

- `cucumberautocomplete.steps` — glob patterns pointing to your step definition files. Adjust to match your project layout (e.g., `"e2e/steps/**/*.ts"` for a monorepo).
- `strictGherkinCompletion: false` — allows partial step matches during typing; set to `true` only if you want completion to fail on any non-exact match.
- `strictGherkinValidation: false` — prevents red underlines on steps that the extension cannot resolve (useful when step defs use dynamic parameter types).
- `smartSnippets: true` — inserts tab stops for step parameters like `{string}` when autocompleting.
- `onTypeFormat: true` — auto-indents as you type keywords.

With this configuration you get:

- **Autocomplete** — typing `When I` shows matching `When` steps from your step files.
- **Go-to-definition** — `Ctrl+Click` (or `F12`) on a step navigates to its TypeScript implementation.
- **Undefined step warnings** — steps with no matching definition appear underlined.

### Official Cucumber Extension

The Official Cucumber extension (`CucumberOpen.cucumber-official`) requires minimal configuration for most projects. You may need to add feature and step file locations in settings:

```json
{
  "cucumber.features": ["features/**/*.feature"],
  "cucumber.glue": ["features/steps/**/*.ts"]
}
```

### Playwright Extension Integration

The [Official Playwright extension](https://marketplace.visualstudio.com/items?itemName=ms-playwright.playwright) is fully compatible with playwright-bdd. It picks up the generated test files from `.features-gen/` (or your configured `outputDir`) automatically. Use it to:

- Run individual scenarios via the test sidebar
- Debug scenarios with the Playwright Inspector
- View trace files inline

### Debugging Feature Files in VS Code

To debug a scenario with breakpoints in step definitions, create `.vscode/launch.json`:

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "type": "node",
      "request": "launch",
      "name": "Debug BDD Scenario",
      "runtimeExecutable": "npx",
      "runtimeArgs": [
        "playwright",
        "test",
        "--headed",
        "--workers=1"
      ],
      "env": {
        "PWDEBUG": "1"
      },
      "console": "integratedTerminal",
      "internalConsoleOptions": "neverOpen"
    }
  ]
}
```

Set breakpoints in your TypeScript step definition files, then launch via `F5`. The Playwright Inspector opens alongside VS Code's debugger.

!!! tip "Use --workers=1 when debugging"
    Parallel workers can interleave output and confuse debugger step-through. Always set `--workers=1` in debug launch configs.

## IntelliJ IDEA / WebStorm

### Built-in Cucumber Plugin

JetBrains IDEs ship with a Cucumber plugin that activates automatically when `.feature` files are present. For TypeScript projects with playwright-bdd, the plugin provides:

- **Step navigation** — `Ctrl+B` on a step text jumps to the TypeScript step definition.
- **Undefined step inspection** — unresolved steps appear with a warning gutter icon.
- **Gherkin completion** — step text completion based on discovered step definitions.

### Configuration

IntelliJ typically auto-discovers step definitions. If your project uses non-standard paths, configure the Cucumber plugin under **Preferences → Languages & Frameworks → Cucumber.js**:

- **Glue paths** — point to your step definition directories.
- **Feature file paths** — point to your `features/` directory.

For playwright-bdd projects, also set up a **Run/Debug Configuration** of type **Node.js** pointing to `npx playwright test` so you can run scenarios from the IDE test runner.

!!! note "IntelliJ Aqua"
    IntelliJ Aqua (the JetBrains test automation IDE) has first-class Playwright support including a dedicated Playwright run configuration type. It integrates with playwright-bdd's generated files and provides a visual scenario explorer.

## Recommended Project Settings

These files should be committed to keep the developer experience consistent across the team:

```
.vscode/
  settings.json     # Cucumber extension config + editor preferences
  launch.json       # Debug configurations
  extensions.json   # Recommended extensions
```

`.vscode/extensions.json` ensures teammates are prompted to install the same extensions:

```json
{
  "recommendations": [
    "alexkrechik.cucumberautocomplete",
    "ms-playwright.playwright"
  ]
}
```

!!! tip "Cross-reference"
    For the full playwright-bdd setup including `playwright.config.ts`, see [playwright-bdd Setup](../playwright-bdd/installation.md). For pre-commit hooks that complement IDE tooling, see [Pre-Commit Hooks](pre-commit-hooks.md).
