#!/bin/sh
# Build the shared relation-organ decide binary: the exported verified decision
# (var/relorgan/gen/Relation_Organ_Code.ML, written by Relation_Organ_Export.thy on the
# remote build) + the untrusted JSON-lines I/O (decide_main.sml), compiled with the MLton
# that ships inside Isabelle. The export's SHA-1 must equal the remote build's marker line.
set -eu
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/../.." && pwd)
GEN="$ROOT/var/relorgan/gen/Relation_Organ_Code.ML"
MLTON=$(ls /Applications/Isabelle2026-RC1.app/contrib/mlton-20241230-1/*/bin/mlton | head -1)
OUT="$ROOT/var/relorgan/decide-organ"
[ -f "$GEN" ] || { echo "build_decide_organ: missing $GEN (run remote-build first, then scp the gen file)"; exit 1; }
echo "export sha1: $(shasum "$GEN" | cut -d' ' -f1)"
"$MLTON" -output "$OUT" "$GEN" "$HERE/decide_main.sml"
echo "built $OUT"
