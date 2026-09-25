#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
NAME="bdd-knowledge-base"
VER="$(python3 -c "import json;print(json.load(open('kb.manifest.json'))['kb_version'])")"
OUT="$NAME-$VER.tar.gz"

# Byte-reproducible build: the tarball's sha256 is the pin that sync-kb.sh verifies against
# the published release asset, so two builds of the same content MUST produce identical bytes.
# Plain `tar -czf` is not reproducible (gzip embeds a timestamp; tar embeds per-file mtimes,
# owner/group, and filesystem traversal order). We normalize all of that:
#   - stage a copy so we never mutate the working tree
#   - clamp every mtime to a fixed epoch (portable; bsdtar lacks GNU's --mtime)
#   - fix owner/group metadata and the archive format
#   - feed a byte-sorted (LC_ALL=C) file list for deterministic member ordering
#   - `gzip -n` strips the embedded name + timestamp from the gzip header
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT
for p in docs kb.manifest.json SOURCES.json LICENSE; do cp -R "$p" "$STAGE/"; done
find "$STAGE" -exec touch -t 200001010000.00 {} +
(
  cd "$STAGE"
  find . \( -type f -o -type l \) | LC_ALL=C sort \
    | tar -cf - --uid 0 --gid 0 --uname '' --gname '' --format ustar -T -
) | gzip -n -9 > "$OUT"

shasum -a 256 "$OUT" | tee "$OUT.sha256"
echo "built $OUT (reproducible)"
