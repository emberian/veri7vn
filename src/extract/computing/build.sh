#!/bin/sh
# Compile a checked HOL export with the current untrusted recognizer and driver.
# Optional argument: exact managed receipt. The shared compiler freezes all MLB
# inputs and rejects receipts that do not match current proof dependencies.
set -eu
REPO=$(cd "$(dirname "$0")/../../.." && pwd)
ISABELLE_APP=${ISABELLE_APP:-/Applications/Isabelle2026-RC1.app}
MLTON=$(ls -d "$ISABELLE_APP"/contrib/mlton-*/*/bin/mlton | head -n 1)
SRC=$REPO/src/extract/computing
OUT=$REPO/var/computing
EXPORT=$OUT/export-remote/Veri7vn_Computing
cd "$REPO"
if [ "$#" -gt 1 ]; then
  echo "usage: sh src/extract/computing/build.sh [managed-receipt.json]" >&2
  exit 2
fi
if [ "$#" -eq 1 ]; then
  RECEIPT=$1
  EXPORT=$(dirname "$RECEIPT")/results/export/Veri7vn_Computing
  set -- --from-receipt "$RECEIPT"
fi
GEN=$(find "$EXPORT" -type f -name 'computing*' | head -n 1)
[ -n "$GEN" ] || { echo "no checked computing export available" >&2; exit 1; }
mkdir -p "$OUT/bin" "$OUT/build"
BUILD=$(mktemp -d "$OUT/build/recipe-XXXXXXXX")
cp "$GEN" "$BUILD/computing_generated.sml"
cat > "$BUILD/computing.mlb" <<EOF
\$(SML_LIB)/basis/basis.mlb
computing_generated.sml
$SRC/../commons/commons.sml
$SRC/recognizer.sml
$SRC/main.sml
EOF
python3 -B tools/dev/native-compile --family computing --session Veri7vn_Computing \
  --compiler "$MLTON" "$@" -- -output "$OUT/bin/computing" "$BUILD/computing.mlb"
