#!/bin/sh
# Build the climate family answerer binary from the checked HOL export.
#
# Precondition: the Isabelle session has passed check-native (that is where the
# theorems are proved and the code is generated); this script never builds
# Isabelle sessions. It
#   1. reads the generated SML out of the session database (isabelle export -n,
#      no build) while holding the shared native build lock,
#   2. compiles generated kernel + untrusted recognizer + driver with the MLton
#      that ships inside Isabelle,
#   3. writes var/climate/bin/climate and prints its size.
set -eu
REPO=$(cd "$(dirname "$0")/../../.." && pwd)
ISABELLE_APP=${ISABELLE_APP:-/Applications/Isabelle2026-RC1.app}
MLTON=$(ls -d "$ISABELLE_APP"/contrib/mlton-*/*/bin/mlton | head -n 1)
SRC=$REPO/src/extract/climate
OUT=$REPO/var/climate
cd "$REPO"
mkdir -p "$OUT/bin" "$OUT/build"

# Only consume the checked remote export. Never remove another session's export.
EXP="$OUT/export-remote/Veri7vn_Climate"
GEN=$(find "$EXP" -type f -name 'climate*.ML' | head -n 1)
[ -n "$GEN" ] || { echo "no generated SML found under $EXP" >&2; exit 1; }
cp "$GEN" "$OUT/build/climate_generated.sml"

cat > "$OUT/build/climate.mlb" <<EOF
\$(SML_LIB)/basis/basis.mlb
climate_generated.sml
$SRC/../commons/commons.sml
$SRC/recognizer.sml
$SRC/main.sml
EOF
"$MLTON" -output "$OUT/bin/climate" "$OUT/build/climate.mlb"
ls -l "$OUT/bin/climate"
shasum -a 256 "$OUT/build/climate_generated.sml" "$OUT/bin/climate"
