#!/bin/sh
# UNTRUSTED build adapter. Compile only a published, receipt-checked export;
# never start Isabelle or choose a stale local session database implicitly.
set -eu
REPO=$(cd "$(dirname "$0")/../../.." && pwd)
ISABELLE_APP=${ISABELLE_APP:-/Applications/Isabelle2026-RC1.app}
SRC=$REPO/src/extract/discrete-certificate
OUT=$REPO/var/discrete-certificate
MLTON=$(ls -d "$ISABELLE_APP"/contrib/mlton-*/*/bin/mlton | head -n 1)
[ -x "$MLTON" ] || { echo 'no bundled MLton found' >&2; exit 1; }
mkdir -p "$OUT/bin" "$OUT/build"
GEN=$(find "$OUT/export-remote/Veri7vn_Discrete_Certificate" -type f -name 'mst_certificate*')
[ -n "$GEN" ] && [ "$(printf '%s\n' "$GEN" | wc -l | tr -d ' ')" = 1 ] || {
  echo 'expected exactly one published mst_certificate export; run the managed proof build first' >&2
  exit 1
}
cp "$GEN" "$OUT/build/mst_certificate_generated.sml"
cat > "$OUT/build/mst_certificate.mlb" <<MLB
\$(SML_LIB)/basis/basis.mlb
mst_certificate_generated.sml
$SRC/main.sml
MLB
cd "$REPO"
python3 -B tools/dev/native-compile --family discrete-certificate \
  --session Veri7vn_Discrete_Certificate --compiler "$MLTON" \
  -- -output "$OUT/bin/mst-certificate" "$OUT/build/mst_certificate.mlb"
