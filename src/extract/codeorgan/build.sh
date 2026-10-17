#!/bin/sh
# Build the codeorgan prototype binary from the checked HOL export.
#
# Precondition: the remote session has passed and its export pulled back:
#   tools/dev/remote-build hbox src/extract/codeorgan Veri7vn_Codeorgan \
#     --expect 'VERI7VN_CODEORGAN PASS'
# This script only compiles: generated checker + untrusted driver, with the
# MLton that ships inside Isabelle. Writes var/codeorgan/bin/codeorgan.
set -eu
REPO=$(cd "$(dirname "$0")/../../.." && pwd)
ISABELLE_APP=${ISABELLE_APP:-/Applications/Isabelle2026-RC1.app}
MLTON=$(ls -d "$ISABELLE_APP"/contrib/mlton-*/*/bin/mlton | head -n 1)
SRC=$REPO/src/extract/codeorgan
OUT=$REPO/var/codeorgan

GEN=$(find "$OUT/export-remote/Veri7vn_Codeorgan" -type f -name 'codeorgan.ML' | head -n 1)
[ -n "$GEN" ] || { echo "no generated SML under $OUT/export-remote; run remote-build first" >&2; exit 1; }

mkdir -p "$OUT/build" "$OUT/bin"
cp "$GEN" "$OUT/build/codeorgan_generated.sml"
cat > "$OUT/build/codeorgan.mlb" <<EOF
\$(SML_LIB)/basis/basis.mlb
codeorgan_generated.sml
$SRC/main.sml
EOF
"$MLTON" -output "$OUT/bin/codeorgan" "$OUT/build/codeorgan.mlb"
ls -l "$OUT/bin/codeorgan"
shasum -a 256 "$OUT/build/codeorgan_generated.sml" "$OUT/bin/codeorgan"
