#!/bin/sh
# Build the facts family answerer binary from the checked HOL export.
#
# Precondition: the Isabelle session has passed check-native (that is where the
# theorems are proved and the code is generated); this script never builds
# Isabelle sessions. It
#   1. reads the generated SML from a completed remote build export,
#   2. compiles generated kernel + untrusted recognizer + driver with the MLton
#      that ships inside Isabelle,
#   3. writes var/facts/bin/facts and prints its size.
set -eu
REPO=$(cd "$(dirname "$0")/../../.." && pwd)
ISABELLE_APP=${ISABELLE_APP:-/Applications/Isabelle2026-RC1.app}
MLTON=$(ls -d "$ISABELLE_APP"/contrib/mlton-*/*/bin/mlton | head -n 1)
SRC=$REPO/src/extract/facts
OUT=$REPO/var/facts
cd "$REPO"
mkdir -p "$OUT/bin" "$OUT/build"

# Use the checked remote export; an explicit path pins an immutable receipt.
GEN=${FACTS_GEN:-$OUT/export-remote/Veri7vn_Facts/Veri7vn_Facts.Facts_Export/code/facts.ML}
[ -f "$GEN" ] || { echo "missing checked export: $GEN (run remote-build first)" >&2; exit 1; }
cp "$GEN" "$OUT/build/facts_generated.sml"

cat > "$OUT/build/facts.mlb" <<EOF
\$(SML_LIB)/basis/basis.mlb
facts_generated.sml
$SRC/../commons/commons.sml
$SRC/recognizer.sml
$SRC/main.sml
EOF
# Freeze the actual flat MLB inputs and bind their generated export to a passed
# proof receipt before compilation. FACTS_RECEIPT pins an immutable proof job;
# otherwise the shared driver selects a matching passed receipt.
if [ -n "${FACTS_RECEIPT:-}" ]; then
  "$REPO/tools/dev/native-compile" --family facts --compiler "$MLTON" --from-receipt "$FACTS_RECEIPT" -- -output "$OUT/bin/facts" "$OUT/build/facts.mlb"
else
  "$REPO/tools/dev/native-compile" --family facts --compiler "$MLTON" -- -output "$OUT/bin/facts" "$OUT/build/facts.mlb"
fi
ls -l "$OUT/bin/facts"
shasum -a 256 "$OUT/build/facts_generated.sml" "$OUT/bin/facts"
