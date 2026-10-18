#!/bin/sh
# Compile a fresh checked HOL export with the untrusted recognizer and framing.
# Set VERI7VN_GENERATED to the .ML file in a successful remote-build attempt.
# This command does not run Isabelle or delete previously exported artifacts.
set -eu
REPO=$(cd "$(dirname "$0")/../../.." && pwd)
ISABELLE_APP=${ISABELLE_APP:-/Applications/Isabelle2026-RC1.app}
MLTON=$(ls -d "$ISABELLE_APP"/contrib/mlton-*/*/bin/mlton | head -n 1)
SRC=$REPO/src/extract/trades
OUT=$REPO/var/trades
cd "$REPO"
mkdir -p "$OUT/bin" "$OUT/build"

# Pass the fresh checked export explicitly; never silently use a stale local heap.
GEN=${VERI7VN_GENERATED:-}
[ -n "$GEN" ] || { echo "set VERI7VN_GENERATED to the fresh checked trades.ML export" >&2; exit 1; }
cp "$GEN" "$OUT/build/trades_generated.sml"

cat > "$OUT/build/trades.mlb" <<EOF
\$(SML_LIB)/basis/basis.mlb
trades_generated.sml
$SRC/../commons/commons.sml
$SRC/recognizer.sml
$SRC/main.sml
EOF
"$MLTON" -output "$OUT/bin/trades" "$OUT/build/trades.mlb"
ls -l "$OUT/bin/trades"
shasum -a 256 "$OUT/build/trades_generated.sml" "$OUT/bin/trades"
