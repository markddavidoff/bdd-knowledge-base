#!/usr/bin/env python3
"""Build kb.manifest.json from SOURCES.json (Task 4, phase1 plan).

Versions specs and tools separately, backfilling each git source's version from
its pinned commit — no re-scrape. Version resolution:
  1. If the pinned commit is exactly a tag's target, use that tag name.
  2. Otherwise fall back to `untagged@<short-sha>` (honest: the pin sits between
     releases; branch=None on all our pins, so most are mid-development SHAs).

`coverage.pages` is read from the docs tree, not hardcoded — a fact check.
"""
from __future__ import annotations

import datetime as dt
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCES = ROOT / "SOURCES.json"
MANIFEST = ROOT / "kb.manifest.json"
DOCS = ROOT / "docs"

KB_VERSION = "1.0.0"

# The two sources that ARE the specs (vs. tools that implement/lint them).
SPECS = {
    "gherkin-parser": "gherkin",
    "cucumber-expressions": "cucumber-expressions",
}

_GH_URL = re.compile(r"github\.com/([^/\s]+)/([^/\s#?]+)")


def owner_repo(entry: dict) -> tuple[str, str] | None:
    m = _GH_URL.search(entry.get("url", "") or "")
    return (m.group(1), m.group(2)) if m else None


def resolve_version(owner: str, repo: str, commit: str) -> str:
    """Exact tag at the pinned commit, else untagged@<short-sha>."""
    short = commit[:12]
    try:
        out = subprocess.run(
            ["gh", "api", "--paginate",
             f"repos/{owner}/{repo}/tags", "--jq", ".[] | .name + \" \" + .commit.sha"],
            capture_output=True, text=True, timeout=45,
        )
    except (OSError, subprocess.TimeoutExpired) as e:  # pragma: no cover
        print(f"  ! gh tags {owner}/{repo}: {e}", file=sys.stderr)
        return f"untagged@{short}"
    if out.returncode != 0:
        print(f"  ! gh tags {owner}/{repo} exit {out.returncode}: {out.stderr.strip()[:100]}",
              file=sys.stderr)
        return f"untagged@{short}"
    for line in out.stdout.splitlines():
        name, _, sha = line.partition(" ")
        if sha.startswith(commit) or commit.startswith(sha):
            return name
    return f"untagged@{short}"


def git_entry(key: str, v: dict) -> dict:
    orn = owner_repo(v)
    commit = v["commit"]
    version = resolve_version(*orn, commit) if orn else f"untagged@{commit[:12]}"
    print(f"  {key}: {version}")
    return {
        "version": version,
        "commit": commit,
        "commit_date": v.get("commit_date"),
        "license": v["license"],
        "url": v.get("url"),
    }


def main() -> int:
    d = json.loads(SOURCES.read_text())

    specs, tools = {}, {}
    for key, v in d.items():
        if "commit" not in v:
            continue
        if key in SPECS:
            specs[SPECS[key]] = git_entry(key, v)
        else:
            # tool name = repo name
            orn = owner_repo(v)
            name = orn[1] if orn else key
            tools[name] = git_entry(key, v)

    # web-source fetch window
    fetched = sorted(v["fetched_at"] for v in d.values() if v.get("fetched_at"))
    web_window = f"{fetched[0]} .. {fetched[-1]}" if fetched else None

    pages = sum(1 for _ in DOCS.rglob("*.md"))
    deep_pages = sum(1 for _ in (DOCS / "practice" / "playwright-bdd").rglob("*.md"))

    manifest = {
        "kb_version": KB_VERSION,
        "built_at": dt.date.today().isoformat(),
        "specs": specs,
        "tools_examined": tools,
        "web_sources_fetched": web_window,
        "coverage": {
            "pages": pages,
            "deep_stack": "playwright-bdd",
            "deep_stack_pages": deep_pages,
        },
    }
    MANIFEST.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n")
    print(f"\nwrote {MANIFEST.name}: {len(specs)} specs, {len(tools)} tools, {pages} pages")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
