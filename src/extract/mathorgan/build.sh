#!/bin/sh
# Build the mathorgan answerer binary from the checked HOL export.
#
# Precondition: the Isabelle session Veri7vn_MathOrgan has been built (the
# theorems are proved and the self test asserted there) - remotely with
#   tools/dev/remote-build hbox|persvati src/extract/mathorgan Veri7vn_MathOrgan \
#     --expect 'VERI7VN_MATHORGAN PASS'
# whose generated SML lands in var/mathorgan/export-remote/Veri7vn_MathOrgan/.
# This script never builds Isabelle sessions; it
#   1. takes the generated mathkernel SML from that export,
#   2. compiles generated kernel + untrusted recognizer + driver with the
#      MLton that ships inside Isabelle,
#   3. writes var/mathorgan/bin/mathorgan and prints its size.
set -eu
REPO=$(cd "$(dirname "$0")/../../.." && pwd)
ISABELLE_APP=${ISABELLE_APP:-/Applications/Isabelle2026-RC1.app}
MLTON=$(ls -d "$ISABELLE_APP"/contrib/mlton-*/*/bin/mlton | head -n 1)
SRC=$REPO/src/extract/mathorgan
OUT=$REPO/var/mathorgan
cd "$REPO"

GEN=$(find "$OUT/export-remote" -type f -name 'mathkernel.ML' 2>/dev/null | head -n 1)
if [ -z "$GEN" ]; then
  echo "no generated SML under $OUT/export-remote - run remote-build first:" >&2
  echo "  tools/dev/remote-build hbox src/extract/mathorgan Veri7vn_MathOrgan --expect 'VERI7VN_MATHORGAN PASS'" >&2
  exit 1
fi

mkdir -p "$OUT/bin" "$OUT/build"
cp "$GEN" "$OUT/build/mathkernel_generated.sml"

cat > "$OUT/build/mathorgan.mlb" <<EOF
\$(SML_LIB)/basis/basis.mlb
mathkernel_generated.sml
$SRC/regex.sml
$SRC/recognizer.sml
$SRC/main.sml
EOF
"$MLTON" -output "$OUT/bin/mathorgan" "$OUT/build/mathorgan.mlb"
ls -l "$OUT/bin/mathorgan"
shasum -a 256 "$OUT/build/mathkernel_generated.sml" "$OUT/bin/mathorgan"
