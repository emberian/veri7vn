#!/bin/sh
# Build the earth family answerer binary from the checked HOL export.
#
# Precondition: the Isabelle session has passed check-native (that is where the
# theorems are proved and the code is generated); this script never builds
# Isabelle sessions. It
#   1. reads the generated SML out of the session database (isabelle export -n,
#      no build) while holding the shared native build lock,
#   2. compiles generated kernel + untrusted recognizer + driver with the MLton
#      that ships inside Isabelle,
#   3. writes var/earth/bin/earth and prints its size.
set -eu
REPO=$(cd "$(dirname "$0")/../../.." && pwd)
ISABELLE_APP=${ISABELLE_APP:-/Applications/Isabelle2026-RC1.app}
MLTON=$(ls -d "$ISABELLE_APP"/contrib/mlton-*/*/bin/mlton | head -n 1)
SRC=$REPO/src/extract/earth
OUT=$REPO/var/earth
cd "$REPO"
mkdir -p "$OUT/bin" "$OUT/build"

# the generated SML comes from the remote build (tools/dev/remote-build hbox src/extract/earth Veri7vn_Earth)
EXP="$OUT/export-remote/Veri7vn_Earth"
GEN=$(find "$EXP" -type f -name 'earth*.ML' | head -n 1)
[ -n "$GEN" ] || { echo "no generated SML found under $EXP" >&2; exit 1; }
cp "$GEN" "$OUT/build/earth_generated.sml"

cat > "$OUT/build/earth.mlb" <<EOF
\$(SML_LIB)/basis/basis.mlb
earth_generated.sml
$SRC/regex.sml
$SRC/recognizer.sml
$SRC/main.sml
EOF
"$MLTON" -output "$OUT/bin/earth" "$OUT/build/earth.mlb"
ls -l "$OUT/bin/earth"
shasum -a 256 "$OUT/build/earth_generated.sml" "$OUT/bin/earth"
