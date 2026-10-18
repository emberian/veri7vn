#!/bin/sh
# Compile the explicitly selected successful remote export into the answerer.
# VERI7VN_GENERATED names its ML file from an immutable passed build receipt.
# This script never builds Isabelle or falls back to an older exported kernel.
set -eu
REPO=$(cd "$(dirname "$0")/../../.." && pwd)
ISABELLE_APP=${ISABELLE_APP:-/Applications/Isabelle2026-RC1.app}
MLTON=$(ls -d "$ISABELLE_APP"/contrib/mlton-*/*/bin/mlton | head -n 1)
SRC=$REPO/src/extract/life
OUT=$REPO/var/life
cd "$REPO"
mkdir -p "$OUT/bin" "$OUT/build"

# Name the generated ML file from this attempt's successful immutable receipt.
# No fallback to canonical exports: those can survive a later failed build.
GEN=${VERI7VN_GENERATED:?set VERI7VN_GENERATED to the successful attempt generated ML file}
[ -f "$GEN" ] || { echo "generated ML does not exist: $GEN" >&2; exit 1; }
cp "$GEN" "$OUT/build/life_generated.sml"

cat > "$OUT/build/life.mlb" <<EOF
\$(SML_LIB)/basis/basis.mlb
life_generated.sml
$SRC/../commons/commons.sml
$SRC/recognizer.sml
$SRC/main.sml
EOF
"$MLTON" -output "$OUT/bin/life" "$OUT/build/life.mlb"
ls -l "$OUT/bin/life"
shasum -a 256 "$OUT/build/life_generated.sml" "$OUT/bin/life"
