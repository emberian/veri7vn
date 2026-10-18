#!/bin/sh
# Compile var/rel-novels/bin/decide from the HOL export and the untrusted I/O driver decide_main.sml,
# with the MLton that ships inside Isabelle2026-RC1. The export is returned by the remote build:
#   tools/dev/remote-build hbox src/extract/rel-novels Veri7vn_Novel_Reader --expect 'VERI7VN_NOVELS PASS'
# which leaves it under var/rel-novels/export-remote/Veri7vn_Novel_Reader/. Nothing is copied by hand.
set -eu
REPO=$(cd "$(dirname "$0")/../.." && pwd)
MLTON=$(ls -d /Applications/Isabelle2026-RC1.app/contrib/mlton-20241230-1/*/bin/mlton | head -n 1)
GEN=$(find "$REPO/var/rel-novels/export-remote/Veri7vn_Novel_Reader" -type f -name novel_reader.ML | head -n 1)
OUT="$REPO/var/rel-novels/bin"
mkdir -p "$OUT"
test -n "$GEN" && test -f "$GEN" || { echo "no export under var/rel-novels/export-remote (see the comment at the top of this file)" >&2; exit 1; }
printf '$(SML_LIB)/basis/basis.mlb\n%s\n%s\n' "$GEN" "$REPO/tools/reader-novels/decide_main.sml" > "$OUT/decide.mlb"
"$MLTON" -output "$OUT/decide" "$OUT/decide.mlb"
shasum "$GEN" "$OUT/decide"
