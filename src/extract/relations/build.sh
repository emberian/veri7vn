#!/bin/sh
# Compile var/relations/bin/decide from the HOL export and the untrusted I/O driver main.sml, with the MLton
# that ships inside Isabelle2026-RC1. The export is the file the remote build returned:
#   tools/dev/remote-build persvati src/extract/relations Veri7vn_Relations --expect 'VERI7VN_RELATIONS PASS'
# leaves it under var/relations/export-remote/Veri7vn_Relations/. Nothing is copied by hand.
set -eu
REPO=$(cd "$(dirname "$0")/../../.." && pwd)
MLTON=$(ls -d /Applications/Isabelle2026-RC1.app/contrib/mlton-20241230-1/*/bin/mlton | head -n 1)
GEN=$(find "$REPO/var/relations/export-remote/Veri7vn_Relations" -type f -name relation_reader.ML | head -n 1)
OUT="$REPO/var/relations/bin"
mkdir -p "$OUT"
test -n "$GEN" && test -f "$GEN" || { echo "no export under var/relations/export-remote (see the comment at the top of this file)" >&2; exit 1; }
printf '$(SML_LIB)/basis/basis.mlb\n%s\n%s\n' "$GEN" "$REPO/src/extract/relations/main.sml" > "$OUT/decide.mlb"
"$MLTON" -output "$OUT/decide" "$OUT/decide.mlb"
shasum "$GEN" "$OUT/decide"
