---
title: Corpus Design
description: How this BDD knowledge base is structured as a machine-readable corpus — frontmatter schema, chunk sizing, manifest, and provenance metadata for AI retrieval.
sources:
  - git-gherkin-utils-readme-readme
  - git-playwright-bdd-repo-docs-index-bdd-in-the-era-of-ai
---

# Corpus Design

This knowledge base is built to serve two audiences simultaneously: human developers reading documentation, and AI agents using the content as retrieval context. The design decisions that make it useful for AI are described here.

## Frontmatter Schema

Every chunk in `dataset/normalized/` carries a standard YAML frontmatter block:

```yaml
---
chunk_id: git-playwright-bdd-repo-docs-writing-features-chatgpt-chatgpt
title: Chatgpt
source_type: git
source_url: 'https://github.com/vitalets/playwright-bdd'
source_file: docs/writing-features/chatgpt.md
content_hash: 'sha256:ab9cd28e35fae147'
---
```

| Field | Purpose |
|-------|---------|
| `chunk_id` | Stable, unique identifier for this chunk. Used in `sources:` frontmatter of KB pages to document provenance. |
| `title` | Human-readable name derived from the section heading. Used in search and retrieval display. |
| `source_type` | `git` (from a GitHub repo), `web` (from a crawled page), or `internal` (KB-authored content). |
| `source_url` | Canonical URL of the source repository or page. Enables citation and freshness checking. |
| `source_file` | Path within the repository, for `git` sources. Enables targeted freshness re-fetching. |
| `content_hash` | SHA-256 of the source content at extraction time. Used to detect when upstream content changes without a re-crawl. |

For web sources, additional fields appear:

```yaml
---
chunk_id: web-monday-bdd-guide-the-future-of-bdd-ai-and-automation-trends
title: 'The future of BDD: AI and automation trends'
source_type: web
source_url: 'https://monday.com/blog/rnd/behavior-driven-development/'
section_slug: the-future-of-bdd-ai-and-automation-trends
content_hash: 'sha256:15b6984e4406a37e'
extracted_at: '2026-06-27T14:43:17Z'
---
```

`extracted_at` timestamps web content so stale chunks can be prioritized for re-crawling.

## Chunk Sizing

Each file in `dataset/normalized/` represents one H2 section from a source document. Typical size is 300–1000 words.

**Why this size?**

- **Too small (< 100 words):** The chunk lacks enough context to be self-contained. A retriever might return it without the surrounding explanation.
- **Too large (> 2000 words):** The chunk covers multiple distinct concepts, making it hard to retrieve for a specific query without including irrelevant material.
- **300–1000 words:** Self-contained enough to answer a targeted question; small enough that embedding similarity is focused on a single concept.

!!! note "Section boundaries are semantic boundaries"
    Source documents are split at H2 headings because H2 sections in technical documentation typically correspond to one coherent concept. Splitting at arbitrary character counts would break concepts mid-explanation.

## What Makes a Chunk Retrieval-Friendly

### Dense Keywords

A chunk that will be retrieved for the query "how to configure gherkin-lint allowed-tags rule" must contain those exact terms. The `allowed-tags` chunk in this KB contains:

- The rule name `allowed-tags` multiple times
- The JSON configuration syntax
- The word "taxonomy" (a near-synonym that expands retrieval coverage)
- A concrete example configuration

Chunks that use vague language ("configure the rule as needed") score poorly against specific queries.

### Self-Contained Concepts

A chunk should make sense without requiring the reader to load adjacent chunks. This means:

- Key terms are defined or linked within the chunk, not assumed from a previous section.
- Code examples are complete (imports included, not truncated).
- The "why" is present alongside the "what."

### Concrete Examples

Chunks with runnable code examples are more useful than prose-only chunks for two reasons:

1. **Embedding similarity**: code tokens create distinct semantic signals that improve retrieval precision.
2. **LLM grounding**: the LLM can quote the example directly rather than generating code from memory.

## The `/examples/index.json` Manifest

The `dataset/` directory includes an `index.json` manifest listing all chunks with their metadata. AI agents use this manifest to select which chunks to retrieve before loading chunk content:

```json
[
  {
    "chunk_id": "git-gherkin-lint-readme-available-rules",
    "title": "Available rules",
    "source_type": "git",
    "source_url": "https://github.com/gherkin-lint/gherkin-lint",
    "topics": ["linting", "gherkin-lint", "rules", "configuration"]
  },
  {
    "chunk_id": "git-playwright-bdd-repo-docs-cli-bddgen-export",
    "title": "bddgen export",
    "source_type": "git",
    "source_url": "https://github.com/vitalets/playwright-bdd",
    "topics": ["playwright-bdd", "cli", "ai", "step-export"]
  }
]
```

An agent can load the manifest (small, fast), scan for relevant `topics`, then load only the 3-5 most relevant chunk files.

## Provenance for AI Grounding

Every KB documentation page (the MkDocs `.md` files under `docs/`) carries a `sources:` list in its frontmatter:

```yaml
---
title: Gherkin Linter
sources:
  - git-gherkin-lint-readme-available-rules
  - git-gherkin-lint-readme-configuration-file
  - git-gherkin-lint-readme-rule-configuration
---
```

This `sources:` list records which normalized chunks the page author read when writing the page. It serves two functions:

1. **Traceability** — a reader can verify a claim by reading the cited chunk.
2. **Freshness tracking** — when a source repo changes, the content hash in the chunk changes, and the pages that cite that chunk can be identified for review.

!!! tip "For AI agents building RAG pipelines"
    The `sources:` frontmatter in KB pages is a ground-truth relevance signal. If you are building a retriever over this corpus, use the `sources:` mappings to create training pairs: (page topic, cited chunk_ids) = positive retrieval pairs.

## Re-Fetching and Freshness

The `content_hash` field enables incremental re-fetching:

```bash
# Conceptual freshness check
for chunk in dataset/normalized/*.md; do
  chunk_id=$(grep 'chunk_id:' "$chunk" | awk '{print $2}')
  stored_hash=$(grep 'content_hash:' "$chunk" | awk '{print $2}')
  # Fetch current source, compute hash, compare
  # If different: re-normalize and update chunk
done
```

Web chunks include `extracted_at` to prioritize chunks older than a threshold for re-crawling, since web content changes without a visible hash difference.

## See Also

- [Exporting Steps](exporting-steps.md) — `bddgen export` for LLM context injection
- [KB as Context](kb-as-context.md) — chunk selection heuristics for specific tasks
- [Gherkin Grammar and AST](../../gherkin/reference/gherkin-ast.md) — the AST model that chunk extraction tools walk
