#!/usr/bin/env bats

@test "no docs/stacks reorg happened; practice layout intact" {
  [ ! -d docs/stacks ]
  [ -d docs/practice/playwright-bdd ]
  [ -d docs/practice/related ]
}

@test "CONTRIBUTING.md exists and states the maintenance posture" {
  [ -f CONTRIBUTING.md ]
  run grep -qiE 'provenance|source-available|primary sources' CONTRIBUTING.md
  [ "$status" -eq 0 ]
}
