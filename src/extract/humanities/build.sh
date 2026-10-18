#!/bin/sh
# Build the humanities family answerer binary from the checked HOL export.
#
# Precondition: the Isabelle session has passed check-native (that is where the
# theorems are proved and the code is generated); this script never builds
# Isabelle sessions. It
#   1. reads the generated SML from a completed remote build export,
#   2. compiles generated kernel + untrusted recognizer + driver with the MLton
#      that ships inside Isabelle,
#   3. writes var/humanities/bin/humanities and prints its size.
set -eu
REPO=$(cd "$(dirname "$0")/../../.." && pwd)
ISABELLE_APP=${ISABELLE_APP:-/Applications/Isabelle2026-RC1.app}
MLTON=$(ls -d "$ISABELLE_APP"/contrib/mlton-*/*/bin/mlton | head -n 1)
SRC=$REPO/src/extract/humanities
OUT=$REPO/var/humanities
cd "$REPO"
mkdir -p "$OUT/bin" "$OUT/build"

# Use the checked remote export; an explicit path pins an immutable receipt.
GEN=${HUMANITIES_GEN:-$OUT/export-remote/Veri7vn_Humanities/Veri7vn_Humanities.Humanities_Export/code/humanities.ML}
[ -f "$GEN" ] || { echo "missing checked export: $GEN (run remote-build first)" >&2; exit 1; }
cp "$GEN" "$OUT/build/humanities_generated.sml"

cat > "$OUT/build/humanities.mlb" <<EOF
\$(SML_LIB)/basis/basis.mlb
humanities_generated.sml
$SRC/../commons/commons.sml
$SRC/rules.sml
$SRC/recognizer.sml
$SRC/main.sml
EOF
# Bind the frozen inputs actually consumed by MLton to a passed proof receipt.
if [ -n "${HUMANITIES_RECEIPT:-}" ]; then
  "$REPO/tools/dev/native-compile" --family humanities --compiler "$MLTON" --from-receipt "$HUMANITIES_RECEIPT" -- -output "$OUT/bin/humanities" "$OUT/build/humanities.mlb"
else
  "$REPO/tools/dev/native-compile" --family humanities --compiler "$MLTON" -- -output "$OUT/bin/humanities" "$OUT/build/humanities.mlb"
fi
ls -l "$OUT/bin/humanities"
shasum -a 256 "$OUT/build/humanities_generated.sml" "$OUT/bin/humanities"
