#!/usr/bin/env bats

@test "no stale old-product-name references remain" {
  # Exclude this test file (it necessarily contains the search pattern).
  run bash -c "grep -rnE 'gherkin-kb' README.md CONTRIBUTING.md docs/AGENT.md scripts tests 2>/dev/null | grep -vE '#|//' | grep -v 'tests/naming.bats'"
  [ "$status" -ne 0 ]
}
