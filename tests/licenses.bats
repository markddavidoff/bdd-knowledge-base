#!/usr/bin/env bats

@test "every source has a license field" {
  run python3 -c "import json; d=json.load(open('SOURCES.json')); import sys; sys.exit(0 if all('license' in v for v in d.values()) else 1)"
  [ "$status" -eq 0 ]
}

@test "no source is left as REVIEW" {
  run python3 -c "import json; d=json.load(open('SOURCES.json')); import sys; sys.exit(1 if any(v.get('license')=='REVIEW' for v in d.values()) else 0)"
  [ "$status" -eq 0 ]
}

@test "H3: no inbound license forbids CC-BY-ND-outbound synthesis" {
  run python3 - <<'PY'
import json, sys
d = json.load(open('SOURCES.json'))
OK = {"MIT","Apache-2.0","BSD-2-Clause","BSD-3-Clause","ISC","CC-BY-4.0","CC0-1.0","Unlicense",
      "site-terms (synthesized, cited)"}
BAD_SUB = ("GPL","AGPL","LGPL","-NC","-ND","NonCommercial","NoDeriv","all rights reserved","ARR")
bad = []
for k, v in d.items():
    lic = (v.get("license") or "").strip()
    if lic in OK:
        continue
    if any(s.lower() in lic.lower() for s in BAD_SUB) or lic == "":
        bad.append((k, lic))
    else:
        bad.append((k, lic + " (not on the compatible allow-list — review)"))
if bad:
    for k, lic in bad: print(f"INCOMPATIBLE: {k} -> {lic}", file=sys.stderr)
    sys.exit(1)
PY
  [ "$status" -eq 0 ]
}
