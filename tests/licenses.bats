#!/usr/bin/env bats

@test "every source has a license field" {
  run python3 -c "import json; d=json.load(open('SOURCES.json')); import sys; sys.exit(0 if all('license' in v for v in d.values()) else 1)"
  [ "$status" -eq 0 ]
}

# Attribution metadata completeness. The H3 inbound/outbound license-compatibility gate was
# retired (third-party sources are used with the author's permission); the license field is kept
# as attribution metadata, so we still assert it is fully populated.
@test "no source is left as REVIEW" {
  run python3 -c "import json; d=json.load(open('SOURCES.json')); import sys; sys.exit(1 if any(v.get('license')=='REVIEW' for v in d.values()) else 0)"
  [ "$status" -eq 0 ]
}
