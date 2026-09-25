#!/usr/bin/env bats

@test "declarative page carries the two-orthogonal-axes doctrine" {
  f=docs/gherkin/best-practices/declarative-vs-imperative.md
  run grep -qi 'orthogonal' "$f"; [ "$status" -eq 0 ]
  run grep -qi 'named' "$f"; [ "$status" -eq 0 ]
}
