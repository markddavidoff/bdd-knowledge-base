---
title: Localization
description: Write Gherkin feature files in any of 70+ supported languages using the # language declaration and translated keywords.
sources:
  - web-cucumber-gherkin-localization-content
  - web-cucumber-gherkin-reference-spoken-languages
  - git-playwright-bdd-repo-docs-configuration-options-language
  - git-gherkin-best-practices-repo-readme-use-your-native-language-to-write-scenarios
---

# Localization

Gherkin supports 70+ human languages. When your team writes feature files in a language other than English, declare the language at the top of the file and use the translated keyword set for that locale.

## The `# language:` declaration

Place the language comment on the first line of the file, before the `Feature` keyword:

```gherkin
# language: fr
Fonctionnalité: Gestion des abonnements

  Scénario: Un utilisateur pro peut accéder à la facturation
    Sachant que l'organisation est en plan pro
    Quand la facturation est déclenchée
    Alors la facture est générée
```

The parser reads the `# language:` directive and switches its keyword set accordingly. If omitted, Gherkin defaults to English (`en`).

!!! note "Parser strict mode"
    Some runners enforce UTF-8 encoding and will reject a file with a `# language:` tag that doesn't match the actual content encoding. Always save non-English feature files as UTF-8.

## Language examples — top 10

| Language | Code | `Feature` | `Given` | `When` | `Then` |
|---|---|---|---|---|---|
| English | `en` | `Feature` | `Given` | `When` | `Then` |
| French | `fr` | `Fonctionnalité` | `Sachant que` / `Soit` | `Quand` | `Alors` |
| German | `de` | `Funktionalität` | `Angenommen` | `Wenn` | `Dann` |
| Spanish | `es` | `Característica` | `Dado` / `Dada` | `Cuando` | `Entonces` |
| Portuguese | `pt` | `Funcionalidade` | `Dado` / `Dada` | `Quando` | `Então` |
| Japanese | `ja` | `フィーチャ` | `前提` | `もし` | `ならば` |
| Chinese (Simplified) | `zh-CN` | `功能` | `假如` / `假设` | `当` | `那么` |
| Russian | `ru` | `Функция` | `Допустим` / `Дано` | `Когда` | `Тогда` |
| Italian | `it` | `Funzionalità` | `Dato` / `Data` | `Quando` | `Allora` |
| Dutch | `nl` | `Functionaliteit` | `Gegeven` / `Stel` | `Als` | `Dan` |

### French example (full)

```gherkin
# language: fr
Fonctionnalité: Authentification

  Contexte:
    Sachant que la base de données utilisateurs est initialisée

  Scénario: Connexion réussie
    Quand l'utilisateur se connecte avec les identifiants valides
    Alors il est redirigé vers le tableau de bord

  Scénario: Mot de passe incorrect
    Quand l'utilisateur saisit un mot de passe erroné
    Alors il voit le message "Identifiants incorrects"
```

### German example

```gherkin
# language: de
Funktionalität: Benutzerverwaltung

  Szenario: Administrator erstellt Benutzer
    Angenommen der Administrator ist eingeloggt
    Wenn er einen neuen Benutzer mit der Rolle "user" erstellt
    Dann erscheint der Benutzer in der Benutzerliste
```

### Japanese example

```gherkin
# language: ja
フィーチャ: 請求管理

  シナリオ: プロプランは請求が有効
    前提 組織はプロプランに登録している
    もし 請求処理が実行される
    ならば 請求書が生成される
```

## Keywords in common non-English languages

Every language has translations for all Gherkin structural keywords. Below is a compact reference for the six most-used:

### Background

| Language | `Background` |
|---|---|
| French | `Contexte` |
| German | `Grundlage` / `Hintergrund` |
| Spanish | `Antecedentes` |
| Japanese | `背景` |
| Chinese (Simplified) | `背景` |
| Russian | `Предыстория` / `Контекст` |

### Scenario Outline / Examples

| Language | `Scenario Outline` | `Examples` |
|---|---|---|
| French | `Plan du scénario` | `Exemples` |
| German | `Szenariogrundriss` | `Beispiele` |
| Spanish | `Esquema del escenario` | `Ejemplos` |
| Japanese | `シナリオアウトライン` | `例` |
| Chinese (Simplified) | `场景大纲` | `例子` |

### The `*` wildcard

The asterisk (`*`) is accepted as a step keyword in every language — it acts as a language-neutral continuation keyword equivalent to `And`. It never needs translation.

## Mixing languages

!!! warning "Do not mix languages within a project"
    Each `.feature` file must use a single language — the `# language:` declaration at the top applies to the entire file, not individual scenarios. Running two languages in the same project is possible but strongly discouraged:

    - Reviewers unfamiliar with one language can't read cross-language PRs.
    - Step definitions are language-agnostic (they match against the extracted step text), but vocabulary governance becomes impossible when the same concept appears in two languages.
    - IDE extensions (VS Code Cucumber, WebStorm) may fail to provide autocomplete across mixed-language projects.

    If your team has native speakers of multiple languages, choose one language for feature files and use translation tools or comments for stakeholder communication.

## The authoritative language list: `gherkin/languages.json`

The complete, up-to-date list of all supported languages and their keyword translations is maintained in the Cucumber monorepo:

```
https://github.com/cucumber/gherkin/blob/main/gherkin-languages.json
```

This JSON file is the single source of truth consumed by all Gherkin parsers across all language bindings (JavaScript, Java, Ruby, Go, Elixir, etc.). To add or correct a translation, open a PR against that file.

Each entry maps a language code to a keyword table. Example (French, abbreviated):

```json
{
  "fr": {
    "name": "French",
    "native": "français",
    "feature": ["Fonctionnalité"],
    "background": ["Contexte"],
    "scenario": ["Scénario", "Exemple"],
    "scenarioOutline": ["Plan du scénario", "Plan du Scénario"],
    "examples": ["Exemples"],
    "given": ["* ", "Soit ", "Sachant que ", "Sachant qu'", "Etant donné que ", "Étant donné que "],
    "when": ["* ", "Quand ", "Lorsque ", "Lorsqu'"],
    "then": ["* ", "Alors ", "Donc "],
    "and": ["* ", "Et que ", "Et qu'", "Et "],
    "but": ["* ", "Mais que ", "Mais qu'", "Mais "]
  }
}
```

Multiple translations per keyword are common — parsers accept any of the listed strings.

## Configuring the language in playwright-bdd

playwright-bdd infers the language from the `# language:` declaration in each file. No additional configuration is required in `playwright.config.ts` for mixed-language projects; each file declares its own language.

For projects that use a single non-English language throughout and want to omit the per-file declaration, check the `language` option in `defineBddConfig` (if available in your version), or rely on the per-file declaration as the canonical approach.

## See also

- [Feature Files](../reference/feature-files.md) — the `Feature` keyword and file structure
- [Keywords and Step Types](../reference/keywords.md) — full keyword reference for English
