# Maintaining bdd-knowledge-base

This is a **personal, source-available project** (CC BY-ND 4.0). It is **not open to external
pull requests** — there is no PR funnel and no support SLA. This file documents how the content is
maintained, so the provenance and quality bar are transparent.

## How pages are produced

- Every page draws on **primary sources used with the author's permission**. Provenance for each
  source (url, type, license, and commit/fetch date) lives in `SOURCES.json`; each page's
  front-matter lists the `sources` it draws on.
- Adding or changing a page means adding or updating the corresponding `SOURCES.json` entry.

## The gate every change must pass

- **No client- or customer-confidential content.** The one hard rule: nothing tied to a specific
  client or engagement ships here — no proprietary domain vocabulary, schema shapes, fixtures, real
  names, internal hostnames/URLs, or private issue references. Examples use invented or public
  domains only. This is checked by a confidential-content review (grep sweeps + secret scanning +
  a manual read) before release.

## Layout

- `docs/gherkin/` — stack-agnostic core (language, best practices, examples).
- `docs/practice/` — methodology, adoption, scaling, lifecycle, AI-BDD, plus `playwright-bdd/`
  (the one deep runner guide) and `related/` (light overviews of other runners).

Content ships in this layout as-is.
