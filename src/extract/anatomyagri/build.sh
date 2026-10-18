#!/bin/sh
# Compile from an explicit checked export, binding the proof closure and every
# actual compiler input through the shared immutable native build driver.
set -eu
REPO=$(cd "$(dirname "$0")/../../.." && pwd)
ISABELLE_APP=${ISABELLE_APP:-/Applications/Isabelle2026-RC1.app}
MLTON=$(ls -d "$ISABELLE_APP"/contrib/mlton-*/*/bin/mlton | head -n 1)
SRC=$REPO/src/extract/anatomyagri
OUT=$REPO/var/anatomyagri
cd "$REPO"
mkdir -p "$OUT/bin" "$OUT/build"
GEN=${VERI7VN_GENERATED:?set VERI7VN_GENERATED to the successful attempt generated ML file}
[ -f "$GEN" ] || { echo "generated ML does not exist: $GEN" >&2; exit 1; }
cp "$GEN" "$OUT/build/anatomyagri_generated.sml"
cat > "$OUT/build/anatomyagri.mlb" <<EOF
\$(SML_LIB)/basis/basis.mlb
anatomyagri_generated.sml
$SRC/../commons/commons.sml
$SRC/recognizer.sml
$SRC/main.sml
EOF
set -- --family anatomyagri --compiler "$MLTON"
if [ -n "${VERI7VN_RECEIPT:-}" ]; then
  set -- "$@" --from-receipt "$VERI7VN_RECEIPT"
fi
exec "$REPO/tools/dev/native-compile" "$@" -- -output "$OUT/bin/anatomyagri" "$OUT/build/anatomyagri.mlb"
