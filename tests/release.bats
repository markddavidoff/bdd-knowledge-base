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

@test "build is byte-reproducible (two builds produce identical sha256)" {
  ver="$(python3 -c "import json;print(json.load(open('kb.manifest.json'))['kb_version'])")"
  out="bdd-knowledge-base-$ver.tar.gz"
  bash scripts/build-release.sh >/dev/null
  sha1="$(shasum -a 256 "$out" | awk '{print $1}')"
  sleep 1                                    # ensure any wall-clock nondeterminism would surface
  bash scripts/build-release.sh >/dev/null
  sha2="$(shasum -a 256 "$out" | awk '{print $1}')"
  [ "$sha1" = "$sha2" ]
}

@test "sha256 sidecar matches the tarball it names" {
  ver="$(python3 -c "import json;print(json.load(open('kb.manifest.json'))['kb_version'])")"
  out="bdd-knowledge-base-$ver.tar.gz"
  bash scripts/build-release.sh >/dev/null
  recorded="$(awk '{print $1}' "$out.sha256")"
  actual="$(shasum -a 256 "$out" | awk '{print $1}')"
  [ "$recorded" = "$actual" ]
}
