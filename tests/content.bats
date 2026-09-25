#!/usr/bin/env bats

@test "no internal superpowers pages shipped" {
  run bash -c "find docs -path '*superpowers*' | wc -l | tr -d ' '"
  [ "$output" = "0" ]
}

@test "gherkin core present (45)" {
  run bash -c "find docs/gherkin -name '*.md' | wc -l | tr -d ' '"
  [ "$output" = "45" ]
}

@test "practice/ layout kept as-is: playwright-bdd stays deep, related/ present" {
  run bash -c "find docs/practice/playwright-bdd -name '*.md' | wc -l | tr -d ' '"
  [ "$output" = "21" ]                        # NOT moved to docs/stacks/
  [ -d docs/practice/related ]                # light runner overviews shipped as-is
  [ ! -d docs/stacks ]                        # no reorg happened
}
