---
title: Using This KB as LLM Context
description: How to select and inject chunks from this BDD knowledge base into LLM prompts — chunk selection heuristics, sample system prompt, and RAG setup.
sources:
  - git-playwright-bdd-repo-docs-index-bdd-in-the-era-of-ai
  - git-playwright-bdd-repo-docs-getting-started-agent-skill-agent-skill
  - git-playwright-bdd-repo-docs-getting-started-agent-skill-usage
---

# Using This KB as LLM Context

This knowledge base is designed for two reading modes: humans browsing documentation, and AI agents consuming chunks as retrieval context. The normalized chunks in `dataset/normalized/` are sized, structured, and tagged to support retrieval-augmented generation (RAG) for BDD-related tasks.

## Which Chunks to Select by Task

Different BDD tasks benefit from different subsets of the corpus. The heuristic: match the task's domain to the chunk's `topics` or filename prefix.

| Task | Recommended chunk prefixes |
|------|---------------------------|
| Writing new scenarios | `web-cucumber-*`, `git-cucumber-js-docs-*`, best-practices pages |
| Debugging undefined steps | `git-playwright-bdd-repo-docs-cli-*`, `git-playwright-bdd-repo-docs-getting-started-*` |
| Configuring playwright-bdd | `git-playwright-bdd-repo-docs-configuration-*` |
| Step definition design | `git-playwright-bdd-repo-docs-writing-steps-*` |
| Linting and formatting | `git-gherkin-lint-*`, `git-gherkin-utils-*` |
| AI scenario authoring | `git-playwright-bdd-repo-docs-writing-features-chatgpt-*`, `git-playwright-bdd-repo-docs-cli-bddgen-export` |
| Custom parameter types | `git-cucumber-expressions-*`, `git-playwright-bdd-repo-docs-writing-steps-playwright-style-*` |
| Tag governance | `git-gherkin-lint-readme-available-rules`, `git-gherkin-lint-readme-rule-configuration` |

## Sample System Prompt Template

This template is a starting point for an LLM assistant configured to help with playwright-bdd projects:

```
You are a BDD and playwright-bdd expert assistant. You help TypeScript developers
write Gherkin scenarios, step definitions, and configure playwright-bdd.

Core rules:
1. Scenarios describe behavior, not implementation. Avoid imperative UI actions.
2. Step definitions use createBdd() style with fixture injection (not World/this).
3. Undefined steps are always caught by `npx bddgen --dry-run`. Recommend running it.
4. Tags must follow the team's allowed-tags taxonomy. Ask if unknown.

Reference documentation (use this before answering from training data):

--- BEGIN KB CHUNKS ---
[PASTE SELECTED CHUNKS HERE]
--- END KB CHUNKS ---

Available project step definitions:
[PASTE bddgen export OUTPUT HERE]

Answer questions using the KB chunks first. If the chunks do not cover the question,
say "This is not in the KB" and answer from general knowledge with a disclaimer.
```

## Chunk Selection Heuristics

### Manual Selection (Small Context Window)

When context is limited (e.g., 8K tokens), be selective. Load 3-5 chunks that directly address the user's question:

1. Read the task description.
2. Identify the key concept (e.g., "custom parameter types", "bddgen dry-run", "allowed-tags rule").
3. Find chunks whose `chunk_id` or `title` contains those terms.
4. Load the matched chunks plus one adjacent chunk for context (e.g., if loading `configuration-file`, also load `rule-configuration`).

### RAG Setup (Large Corpus)

For a full RAG pipeline over the entire corpus:

**Step 1: Build the index**

```python
import os
import yaml
from pathlib import Path
from sentence_transformers import SentenceTransformer

model = SentenceTransformer('all-MiniLM-L6-v2')
chunks = []

for chunk_file in Path('dataset/normalized').glob('*.md'):
    content = chunk_file.read_text()
    # Strip YAML frontmatter
    _, frontmatter, body = content.split('---', 2)
    meta = yaml.safe_load(frontmatter)
    chunks.append({
        'chunk_id': meta['chunk_id'],
        'title': meta['title'],
        'body': body.strip(),
        'embedding': model.encode(body.strip()),
    })
```

**Step 2: Retrieve at query time**

```python
import numpy as np

def retrieve(query: str, chunks: list, top_k: int = 5) -> list:
    query_embedding = model.encode(query)
    scores = [
        np.dot(query_embedding, chunk['embedding']) /
        (np.linalg.norm(query_embedding) * np.linalg.norm(chunk['embedding']))
        for chunk in chunks
    ]
    ranked = sorted(zip(scores, chunks), reverse=True)
    return [chunk for _, chunk in ranked[:top_k]]

# Usage
relevant = retrieve("how to configure allowed-tags gherkin-lint", chunks)
context = "\n\n---\n\n".join(c['body'] for c in relevant)
```

**Step 3: Inject into prompt**

```python
prompt = f"""
Answer this BDD question using the reference documentation below.

Question: {user_question}

Reference documentation:
{context}
"""
```

!!! note "Embedding model choice"
    `all-MiniLM-L6-v2` is a good starting point (fast, 384-dim). For better retrieval on technical content, consider `text-embedding-3-small` (OpenAI) or `voyage-code-2` (Voyage AI), which score higher on code-heavy corpora.

## KB Page Sources as Ground Truth

Every KB documentation page (under `docs/`) carries a `sources:` frontmatter listing which normalized chunks were used to write it. This is a ground-truth relevance signal:

```yaml
---
title: Gherkin Linter
sources:
  - git-gherkin-lint-readme-available-rules
  - git-gherkin-lint-readme-configuration-file
  - git-gherkin-lint-readme-rule-configuration
---
```

To use this as training data for a custom retriever:

```python
# Collect (page_topic, cited_chunk_ids) pairs for training
from pathlib import Path
import yaml

pairs = []
for page in Path('docs').rglob('*.md'):
    content = page.read_text()
    if content.startswith('---'):
        _, frontmatter, _ = content.split('---', 2)
        meta = yaml.safe_load(frontmatter)
        if meta.get('sources'):
            pairs.append({
                'page': str(page),
                'topic': meta.get('title', ''),
                'positive_chunks': meta['sources'],
            })
```

## Keeping Context Fresh

KB chunks reflect the state of upstream documentation at extraction time. The `content_hash` and `extracted_at` fields enable freshness checking. Before using a chunk in a production RAG pipeline, verify:

1. The source repo/page still exists at `source_url`.
2. The current content hash matches the stored `content_hash`.
3. For web sources: `extracted_at` is within an acceptable freshness window (e.g., 90 days).

Stale chunks can produce confident-sounding but outdated answers — especially for rapidly evolving tools like playwright-bdd.

## See Also

- [Corpus Design](corpus-design.md) — frontmatter schema and chunk sizing rationale
- [Exporting Steps](exporting-steps.md) — combining KB context with step export for scenario authoring
- [Scenario Authoring](scenario-authoring.md) — full prompting workflow using KB chunks
