#!/bin/sh
# Compile the identity-preserving kernel from one passed managed proof receipt.
# Usage: build.sh var/identity/remote-attempts/ATTEMPT/receipt.json [OUTPUT]
# The shared helper freezes the actual generated ML and driver, checks the proof
# dependency closure and atomically publishes the native binary with its receipt.
set -eu
REPO=$(cd "$(dirname "$0")/../../.." && pwd)
MLTON=$(ls -d /Applications/Isabelle2026-RC1.app/contrib/mlton-20241230-1/*/bin/mlton | head -n 1)
test "$#" -ge 1 || { echo "usage: $0 PASSED_RECEIPT [OUTPUT]" >&2; exit 2; }
RECEIPT=$(cd "$(dirname "$1")" && pwd)/$(basename "$1")
GEN="$(dirname "$RECEIPT")/results/export/Veri7vn_Relation_Identity/Veri7vn_Relation_Identity.Relation_Identity_Export/code/relation_reader.ML"
OUT="$REPO/var/relations/bin"
mkdir -p "$OUT"
test -f "$GEN" || { echo "identity-preserving export absent from receipt" >&2; exit 1; }
printf '$(SML_LIB)/basis/basis.mlb\n%s\n%s\n' "$GEN" "$REPO/src/extract/relations/main.sml" > "$OUT/decide.mlb"
"$REPO/tools/dev/native-compile" --family relations --session Veri7vn_Relation_Identity \
  --compiler "$MLTON" --from-receipt "$RECEIPT" -- -output "${2:-$OUT/decide}" "$OUT/decide.mlb"
