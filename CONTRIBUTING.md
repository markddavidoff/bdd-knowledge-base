# Maintaining gherkin-kb

This is a **personal, source-available project** (CC BY-ND 4.0). It is **not open to external
pull requests** — there is no PR funnel and no support SLA. This file documents how the content is
maintained, so the provenance and quality bar are transparent.

## How pages are produced

- Every page is **synthesized from primary sources**, never copied. Provenance for each source
  (url, type, license, and commit/fetch date) lives in `SOURCES.json`; each page's front-matter
  lists the `sources` it draws on.
- Adding or changing a page means adding or updating the corresponding `SOURCES.json` entry.

## Gates every change must pass

- **License compatibility (H3).** No source whose license forbids synthesis/redistribution
  (copyleft, NC, ND, or all-rights-reserved) may back shipped prose. Permissive inbound licenses
  (MIT/Apache/BSD/CC-BY) and genuinely-synthesized site-terms content are fine.
- **Verbatim-excerpt audit.** `scripts/audit-excerpts.py` flags long contiguous matches against the
  cached raw sources. The release gate is **0 unresolved RED (long verbatim run against an
  all-rights-reserved source) and every YELLOW reviewed** — rewrite the passage or, for legitimately
  unavoidable canonical text (e.g. Gherkin keywords), allowlist it with a justification.

## Layout

- `docs/gherkin/` — stack-agnostic core (language, best practices, examples).
- `docs/practice/` — methodology, adoption, scaling, lifecycle, AI-BDD, plus `playwright-bdd/`
  (the one deep runner guide) and `related/` (light overviews of other runners).

Content ships in this layout as-is.
