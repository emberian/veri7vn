#!/bin/sh
# Build the conversation-layer binary from the checked HOL export.
#
# Precondition: the Isabelle session has been built remotely (remote-build
# prints VERI7VN_CONVERSE PASS; that is where the theorems are proved and the
# code is generated); this script never builds Isabelle sessions. It compiles
# the generated kernel + untrusted regex engine + untrusted recognizer + driver
# with the MLton that ships inside Isabelle, and writes var/converse/bin/converse.
set -eu
REPO=$(cd "$(dirname "$0")/../../.." && pwd)
ISABELLE_APP=${ISABELLE_APP:-/Applications/Isabelle2026-RC1.app}
MLTON=$(ls -d "$ISABELLE_APP"/contrib/mlton-*/*/bin/mlton | head -n 1)
SRC=$REPO/src/extract/converse
OUT=$REPO/var/converse
cd "$REPO"
mkdir -p "$OUT/bin" "$OUT/build"

GEN=$(find "$OUT/export-remote/Veri7vn_Converse" -type f -name 'converse*' | head -n 1)
[ -n "$GEN" ] || { echo "no generated SML under $OUT/export-remote (run remote-build first)" >&2; exit 1; }
cp "$GEN" "$OUT/build/converse_generated.sml"

cat > "$OUT/build/converse.mlb" <<EOF
\$(SML_LIB)/basis/basis.mlb
converse_generated.sml
$SRC/regex.sml
$SRC/recognizer.sml
$SRC/main.sml
EOF
"$MLTON" -output "$OUT/bin/converse" "$OUT/build/converse.mlb"
ls -l "$OUT/bin/converse"
shasum -a 256 "$OUT/build/converse_generated.sml" "$OUT/bin/converse"
