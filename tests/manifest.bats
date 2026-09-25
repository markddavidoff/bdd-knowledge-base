#!/usr/bin/env bats

@test "manifest has kb_version and tools with versions" {
  run python3 -c "import json;m=json.load(open('kb.manifest.json'));import sys;sys.exit(0 if m['kb_version'] and all('version' in t for t in m['tools_examined'].values()) else 1)"
  [ "$status" -eq 0 ]
}

@test "coverage page count matches the tree" {
  actual="$(find docs -name '*.md' | wc -l | tr -d ' ')"
  run python3 -c "import json;m=json.load(open('kb.manifest.json'));print(m['coverage']['pages'])"
  [ "$output" = "$actual" ]
}
