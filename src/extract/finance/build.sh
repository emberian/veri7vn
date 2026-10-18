#!/bin/sh
# Build the finance family answerer binary from the checked HOL export.
#
# Precondition: the Isabelle session has passed check-native (that is where the
# theorems are proved and the code is generated); this script never builds
# Isabelle sessions. It
#   1. reads the explicitly supplied generated SML from a successful scoped build,
#   2. compiles generated kernel + untrusted recognizer + driver with the MLton
#      that ships inside Isabelle,
#   3. writes var/finance/bin/finance and prints its size.
set -eu
REPO=$(cd "$(dirname "$0")/../../.." && pwd)
ISABELLE_APP=${ISABELLE_APP:-/Applications/Isabelle2026-RC1.app}
MLTON=$(ls -d "$ISABELLE_APP"/contrib/mlton-*/*/bin/mlton | head -n 1)
SRC=$REPO/src/extract/finance
OUT=$REPO/var/finance
cd "$REPO"
mkdir -p "$OUT/bin" "$OUT/build"

# Require the export from a successful build receipt; never consume a stale local heap.
GEN=${VERI7VN_GENERATED:-}
[ -n "$GEN" ] && [ -f "$GEN" ] || { echo "set VERI7VN_GENERATED to a fresh checked finance.ML export" >&2; exit 1; }
cp "$GEN" "$OUT/build/finance_generated.sml"

cat > "$OUT/build/finance.mlb" <<EOF
\$(SML_LIB)/basis/basis.mlb
finance_generated.sml
$SRC/../commons/commons.sml
$SRC/recognizer.sml
$SRC/main.sml
EOF
"$MLTON" -output "$OUT/bin/finance" "$OUT/build/finance.mlb"
ls -l "$OUT/bin/finance"
shasum -a 256 "$OUT/build/finance_generated.sml" "$OUT/bin/finance"
