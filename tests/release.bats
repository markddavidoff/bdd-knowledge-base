#!/usr/bin/env bats

@test "release tarball builds, extracts, and carries the manifest + docs" {
  bash scripts/build-release.sh >/dev/null
  ver="$(python3 -c "import json;print(json.load(open('kb.manifest.json'))['kb_version'])")"
  tmp="$(mktemp -d)"; tar -xzf "bdd-knowledge-base-$ver.tar.gz" -C "$tmp"
  [ -f "$tmp/kb.manifest.json" ]
  [ -d "$tmp/docs/gherkin" ]
  [ -d "$tmp/docs/practice/playwright-bdd" ]
  [ -f "$tmp/docs/AGENT.md" ]
  [ ! -d "$tmp/scripts" ]
}

@test "sha256 sidecar is produced" {
  ver="$(python3 -c "import json;print(json.load(open('kb.manifest.json'))['kb_version'])")"
  [ -f "bdd-knowledge-base-$ver.tar.gz.sha256" ]
}
