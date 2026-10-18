#!/bin/sh
# Compile only a successful managed proof's generated export; no Isabelle build.
set -eu
REPO=$(cd "$(dirname "$0")/../../.." && pwd)
RECEIPT=${1:?usage: build.sh proof-receipt}
OUT=$REPO/var/converse
mkdir -p "$OUT/build" "$OUT/bin"
GEN=$(python3 - "$RECEIPT" <<'PY'
import json,sys
from pathlib import Path
p=Path(sys.argv[1]).resolve()
r=json.loads(p.read_text())
for f in p.parent.rglob('converse.ML'):
 print(f); break
else:
 for f in p.parent.rglob('converse.sml'):
  print(f); break
 else: raise SystemExit('generated converse export missing from selected proof receipt directory')
PY
)
cp "$GEN" "$OUT/build/converse_generated.sml"
cat > "$OUT/build/converse.mlb" <<MLB
\$(SML_LIB)/basis/basis.mlb
converse_generated.sml
$REPO/src/extract/commons/commons.sml
$REPO/src/extract/converse/main.sml
MLB
MLTON=$(ls -d /Applications/Isabelle2026-RC1.app/contrib/mlton-*/*/bin/mlton | head -1)
cd "$REPO"
"$REPO/tools/dev/native-compile" --family converse --session Veri7vn_Converse --compiler "$MLTON" --from-receipt "$RECEIPT" -- \
  -output "$OUT/bin/converse" "$OUT/build/converse.mlb"
