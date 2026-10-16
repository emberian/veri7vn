#!/bin/sh
# Compile var/reader/bin/decide from the HOL export (written by the Veri7vn_Reader session build) and the
# untrusted I/O driver decide_main.sml, with the MLton that ships inside Isabelle2026-RC1.
set -eu
REPO=$(cd "$(dirname "$0")/../.." && pwd)
MLTON=$(ls -d /Applications/Isabelle2026-RC1.app/contrib/mlton-20241230-1/*/bin/mlton | head -n 1)
GEN="$REPO/var/reader/gen/Relation_Reader_Code.ML"
OUT="$REPO/var/reader/bin"
mkdir -p "$OUT"
test -f "$GEN" || { echo "missing $GEN: build the Veri7vn_Reader session first" >&2; exit 1; }
printf '$(SML_LIB)/basis/basis.mlb\n%s\n%s\n' "$GEN" "$REPO/tools/reader/decide_main.sml" > "$OUT/decide.mlb"
"$MLTON" -output "$OUT/decide" "$OUT/decide.mlb"
shasum "$GEN" "$OUT/decide"
