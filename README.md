# bdd-knowledge-base

A knowledge base for **Gherkin** and **Behaviour-Driven Development** — the language,
best practices, worked examples, and BDD methodology — synthesized from primary sources
with provenance recorded in `SOURCES.json`.

## What's here

- **`docs/gherkin/`** — the stack-agnostic core: language reference, best practices, examples.
- **`docs/practice/`** — BDD methodology, adoption, scaling, spec lifecycle, AI-assisted BDD,
  and one deep runner guide (`practice/playwright-bdd/`). `practice/related/` carries light
  overviews of other runners (cucumber-js, cucumber-jvm, pytest-bdd, behave, specflow).

Each release ships a versioned `kb.manifest.json` (specs + tools examined, separately versioned)
and an `ATTRIBUTION.md` naming every source.

## How to use

Two ways to consume the reference:

- **Via the plugin (recommended):** install `bdd-knowledge-base` from the
  [bdd-workflow](https://github.com/markddavidoff/bdd-workflow) marketplace. Its `bdd-kb` skill
  fetches this dataset (pinned and sha256-verified) and answers BDD/Gherkin questions from it.
- **Manually:** download the release tarball, verify its sha256 against the published `.sha256`
  sidecar, extract it, and either point the plugin at it with `GHERKIN_KB_PATH=/path/to/kb` or read
  the Markdown under `docs/` directly.

## Releases

Each release is versioned and built **reproducibly** — a byte-identical rebuild produces the same
archive — so the published tarball's sha256 matches its sidecar and the plugin's pinned value. That
pin is what lets the plugin fetch the KB and trust it without a central index.

## License

Content is licensed **CC BY-ND 4.0** (Attribution — NoDerivatives). You may share and use it
with attribution; you may not distribute modified versions. See `LICENSE`.

## Status

A personal project, **source-available** (not open-source): usable as-is, with attribution.
Not affiliated with SmartBear, the Cucumber project, or Microsoft. No warranty. See
`CONTRIBUTING.md` for how the content is maintained.
