#!/bin/sh
# Compile a fresh checked HOL export with the untrusted recognizer and framing.
# Set VERI7VN_GENERATED to the .ML file in a successful remote-build attempt.
# This command does not run Isabelle or delete previously exported artifacts.
set -eu
REPO=$(cd "$(dirname "$0")/../../.." && pwd)
ISABELLE_APP=${ISABELLE_APP:-/Applications/Isabelle2026-RC1.app}
MLTON=$(ls -d "$ISABELLE_APP"/contrib/mlton-*/*/bin/mlton | head -n 1)
SRC=$REPO/src/extract/materials
OUT=$REPO/var/materials
cd "$REPO"
mkdir -p "$OUT/bin" "$OUT/build"

# Pass the fresh checked export explicitly; never silently use a stale local heap.
GEN=${VERI7VN_GENERATED:-}
[ -n "$GEN" ] || { echo "set VERI7VN_GENERATED to the fresh checked materials.ML export" >&2; exit 1; }
cp "$GEN" "$OUT/build/materials_generated.sml"

cat > "$OUT/build/materials.mlb" <<EOF
\$(SML_LIB)/basis/basis.mlb
materials_generated.sml
$SRC/../commons/commons.sml
$SRC/../commons/numeric.sml
$SRC/recognizer.sml
$SRC/main.sml
EOF
"$REPO/tools/dev/native-compile" --family materials --compiler "$MLTON" -- -output "$OUT/bin/materials" "$OUT/build/materials.mlb"
ls -l "$OUT/bin/materials"
shasum -a 256 "$OUT/build/materials_generated.sml" "$OUT/bin/materials"
