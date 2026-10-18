#!/bin/sh
# Compile the exact generated checker from a successful managed proof receipt.
set -eu
REPO=$(cd "$(dirname "$0")/../../.." && pwd)
RECEIPT=${1:?usage: build.sh proof-receipt}
OUT=$REPO/var/codeorgan
mkdir -p "$OUT/build" "$OUT/bin"
GEN=$(python3 - "$RECEIPT" <<'PY'
import sys
from pathlib import Path
p=Path(sys.argv[1]).resolve()
exports=list(p.parent.rglob('codekernel.ML'))
if len(exports)!=1: raise SystemExit('need exactly one generated codekernel.ML in proof attempt')
print(exports[0])
PY
)
cp "$GEN" "$OUT/build/codekernel_generated.sml"
cat > "$OUT/build/codeorgan.mlb" <<MLB
\$(SML_LIB)/basis/basis.mlb
codekernel_generated.sml
$REPO/src/extract/commons/commons.sml
$REPO/src/extract/codeorgan/main.sml
MLB
MLTON=$(ls -d /Applications/Isabelle2026-RC1.app/contrib/mlton-*/*/bin/mlton | head -1)
cd "$REPO"
"$REPO/tools/dev/native-compile" --family codeorgan --session Veri7vn_CodeOrgan --compiler "$MLTON" --from-receipt "$RECEIPT" -- \
  -output "$OUT/bin/codeorgan-kernel" "$OUT/build/codeorgan.mlb"
