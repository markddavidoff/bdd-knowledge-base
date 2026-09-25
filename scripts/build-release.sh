#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
NAME="bdd-knowledge-base"
VER="$(python3 -c "import json;print(json.load(open('kb.manifest.json'))['kb_version'])")"
OUT="$NAME-$VER.tar.gz"
# docs/ already contains AGENT.md; ship docs + manifests + license. Exclude tooling.
tar --exclude='./.git' --exclude='./scripts' --exclude='./tests' \
    -czf "$OUT" docs kb.manifest.json SOURCES.json LICENSE
shasum -a 256 "$OUT" | tee "$OUT.sha256"
echo "built $OUT"
