#!/bin/sh
# Compile var/rel-novels/bin/decide from the HOL export and the untrusted I/O driver decide_main.sml,
# with the MLton that ships inside Isabelle2026-RC1. The export (var/rel-novels/gen/Novel_Reader_Code.ML)
# is written by the Veri7vn_Novel_Reader session build on the remote host; fetch it after remote-build:
#   scp persvati:veri7vn-builds/rel-novels/var/rel-novels/gen/Novel_Reader_Code.ML var/rel-novels/gen/
# Its SHA-1 must equal the VERI7VN_NOVEL code sha1 marker in var/rel-novels/remote-build.log.
set -eu
REPO=$(cd "$(dirname "$0")/../.." && pwd)
MLTON=$(ls -d /Applications/Isabelle2026-RC1.app/contrib/mlton-20241230-1/*/bin/mlton | head -n 1)
GEN="$REPO/var/rel-novels/gen/Novel_Reader_Code.ML"
OUT="$REPO/var/rel-novels/bin"
mkdir -p "$OUT"
test -f "$GEN" || { echo "missing $GEN (see the comment at the top of this file)" >&2; exit 1; }
printf '$(SML_LIB)/basis/basis.mlb\n%s\n%s\n' "$GEN" "$REPO/tools/reader-novels/decide_main.sml" > "$OUT/decide.mlb"
"$MLTON" -output "$OUT/decide" "$OUT/decide.mlb"
shasum "$GEN" "$OUT/decide"
