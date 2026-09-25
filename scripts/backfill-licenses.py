#!/usr/bin/env python3
"""Backfill a `license` field onto every source in SOURCES.json.

Resolution strategy (Task 3, phase1 plan):
  - GitHub-hosted sources (a github.com repo can be derived from `url` or the
    `repo` field): resolve the SPDX id via `gh api repos/{owner}/{repo}/license`.
    The license is read at repo HEAD; the pinned commit is recorded elsewhere
    (SOURCES.json already carries `commit`), and a repo's license rarely changes
    across the pinned window — noted, not re-resolved per-SHA.
  - Everything else (documentation sites, issue threads without a clean repo,
    gists): cannot be auto-detected → write "REVIEW" so tests/licenses.bats
    forces a human decision (Step 4).

Writes SOURCES.json in place, preserving key order. Idempotent: an entry that
already has a non-REVIEW license is left untouched unless --force is given.
"""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

SOURCES = Path(__file__).resolve().parent.parent / "SOURCES.json"

# github.com/<owner>/<repo>[/...]; also matches raw/gist? no — gists are not repos.
_GH_URL = re.compile(r"github\.com/([^/\s]+)/([^/\s#?]+)")


def github_owner_repo(entry: dict) -> tuple[str, str] | None:
    """Derive (owner, repo) for a GitHub-hosted source, or None."""
    repo = entry.get("repo")
    if repo and "/" in repo:
        owner, name = repo.split("/", 1)
        return owner, name.rstrip("/")
    url = entry.get("url", "") or ""
    # gists live on gist.github.com and are not license-resolvable repos.
    if "gist.github.com" in url:
        return None
    m = _GH_URL.search(url)
    if not m:
        return None
    owner, name = m.group(1), m.group(2)
    if owner in {"issues", "pull"}:  # defensive; shouldn't happen
        return None
    return owner, name


def resolve_spdx(owner: str, repo: str) -> str | None:
    """Return the SPDX id via gh, or None if gh reports no license."""
    try:
        out = subprocess.run(
            ["gh", "api", f"repos/{owner}/{repo}/license", "--jq", ".license.spdx_id"],
            capture_output=True, text=True, timeout=30,
        )
    except (OSError, subprocess.TimeoutExpired) as e:  # pragma: no cover
        print(f"  ! gh failed for {owner}/{repo}: {e}", file=sys.stderr)
        return None
    if out.returncode != 0:
        print(f"  ! gh api {owner}/{repo} exit {out.returncode}: {out.stderr.strip()[:120]}",
              file=sys.stderr)
        return None
    spdx = out.stdout.strip()
    # gh returns "NOASSERTION" when a LICENSE exists but SPDX is undetermined.
    if not spdx or spdx in {"null", "NOASSERTION"}:
        return None
    return spdx


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--force", action="store_true",
                    help="re-resolve even entries that already have a license")
    args = ap.parse_args()

    data = json.loads(SOURCES.read_text())
    resolved = review = kept = 0
    for key, entry in data.items():
        if "license" in entry and entry["license"] != "REVIEW" and not args.force:
            kept += 1
            continue
        gh = github_owner_repo(entry)
        if gh:
            spdx = resolve_spdx(*gh)
            if spdx:
                entry["license"] = spdx
                resolved += 1
                print(f"  resolved {key}: {spdx}")
                continue
        entry["license"] = "REVIEW"
        review += 1
        print(f"  REVIEW  {key}")

    SOURCES.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")
    print(f"\nresolved={resolved}  review={review}  kept={kept}  total={len(data)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
