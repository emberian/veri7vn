#!/bin/sh
# Compile the exact checked export and a frozen wrapper through native-compile.
# Usage: sh tools/document/build.sh path/to/remote-attempt/receipt.json
set -eu
cd "$(dirname "$0")/../.."
RECEIPT=${1:-${VERI7VN_DOCUMENT_RECEIPT:-}}
[ -n "$RECEIPT" ] || { echo "pass the fresh Document proof receipt" >&2; exit 1; }
GEN=$(python3 -B - "$RECEIPT" <<'PY'
from pathlib import Path
import sys
paths = list((Path(sys.argv[1]).resolve().parent / 'results/export/Veri7vn_Document').rglob('document_route.ML'))
if len(paths) != 1: raise SystemExit('receipt must have exactly one document_route.ML export')
print(paths[0])
PY
)
MLTON=$(ls /Applications/Isabelle2026-RC1.app/contrib/mlton-20241230-1/*/bin/mlton | head -1)
mkdir -p var/document/build var/document/bin
printf '$(SML_LIB)/basis/basis.mlb\n%s\n%s\n' "$GEN" "$PWD/tools/document/document_main.sml" > var/document/build/document.mlb
python3 -B tools/dev/native-compile --family document --session Veri7vn_Document \
  --compiler "$MLTON" --from-receipt "$RECEIPT" -- \
  -output "$PWD/var/document/bin/document" "$PWD/var/document/build/document.mlb"
var/document/bin/document </dev/null
