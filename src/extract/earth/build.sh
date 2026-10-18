#!/bin/sh
# Build the earth family answerer binary from the checked HOL export.
#
# Precondition: tools/dev/remote-build passed the Earth proof marker and published
# its fresh checked SML under var/earth/export-remote. This script never builds
# Isabelle sessions. It compiles that kernel with the untrusted recognizer and
# driver, then prints binary size and both kernel and binary hashes.
set -eu
REPO=$(cd "$(dirname "$0")/../../.." && pwd)
ISABELLE_APP=${ISABELLE_APP:-/Applications/Isabelle2026-RC1.app}
MLTON=$(ls -d "$ISABELLE_APP"/contrib/mlton-*/*/bin/mlton | head -n 1)
SRC=$REPO/src/extract/earth
OUT=$REPO/var/earth
cd "$REPO"
mkdir -p "$OUT/bin" "$OUT/build"

# The generated SML comes from a successful scoped remote proof build.
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
"$REPO/tools/dev/native-compile" --family earth --compiler "$MLTON" -- -output "$OUT/bin/earth" "$OUT/build/earth.mlb"
ls -l "$OUT/bin/earth"
shasum -a 256 "$OUT/build/earth_generated.sml" "$OUT/bin/earth"
