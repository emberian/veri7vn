#!/bin/sh
# Compile the checked explanatory export and a frozen wrapper.
# Usage: sh tools/document/build_anchors.sh path/to/remote-attempt/receipt.json
set -eu
cd "$(dirname "$0")/../.."
RECEIPT=${1:-${VERI7VN_DOCUMENT_ANCHORS_RECEIPT:-}}
[ -n "$RECEIPT" ] || { echo "pass the fresh Document_Anchors proof receipt" >&2; exit 1; }
GEN=$(python3 -B - "$RECEIPT" <<'PY'
from pathlib import Path
import sys
paths = list((Path(sys.argv[1]).resolve().parent / 'results/export/Veri7vn_Document_Anchors').rglob('document_anchors.ML'))
if len(paths) != 1: raise SystemExit('receipt must have exactly one document_anchors.ML export')
print(paths[0])
PY
)
MLTON=$(ls /Applications/Isabelle2026-RC1.app/contrib/mlton-20241230-1/*/bin/mlton | head -1)
mkdir -p var/document_anchors/bin var/document_anchors/build
printf '$(SML_LIB)/basis/basis.mlb\n%s\n%s\n' "$GEN" "$PWD/tools/document/anchor_main.sml" > var/document_anchors/build/document_anchors.mlb
python3 -B tools/dev/native-compile --family document-anchors --session Veri7vn_Document_Anchors \
  --compiler "$MLTON" --from-receipt "$RECEIPT" -- \
  -output "$PWD/var/document_anchors/bin/document_anchors" "$PWD/var/document_anchors/build/document_anchors.mlb"
var/document_anchors/bin/document_anchors </dev/null
