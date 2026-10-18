#!/bin/sh
# Compile the current recognizer/driver with a successfully checked remote HOL
# export. Does not build Isabelle or remove previous exports. The receipt must
# identify the same Stores theories and ROOT currently in the checkout.
set -eu
REPO=$(cd "$(dirname "$0")/../../.." && pwd)
ISABELLE_APP=${ISABELLE_APP:-/Applications/Isabelle2026-RC1.app}
MLTON=$(ls -d "$ISABELLE_APP"/contrib/mlton-*/*/bin/mlton | head -n 1)
SRC=$REPO/src/extract/stores
OUT=$REPO/var/stores
cd "$REPO"
mkdir -p "$OUT/bin" "$OUT/build"
REPO="$REPO" python3 -B - <<'PY'
import hashlib
import json
import os
from pathlib import Path
import shutil
root = Path(os.environ['REPO'])
source = root / 'src/extract/stores'
out = root / 'var/stores/build'
needed = [source/'ROOT', *source.rglob('*.thy')]
matched = None
for receipt_path in sorted((root/'var/stores/remote-attempts').glob('*/receipt.json'), reverse=True):
    receipt = json.loads(receipt_path.read_text())
    if receipt.get('remote',{}).get('exit_code') != 0 or not receipt.get('exports_published'):
        continue
    hashes = json.loads(receipt_path.with_name('source-sha256.json').read_text())
    if any(hashes.get(str(p.relative_to(root))) != hashlib.sha256(p.read_bytes()).hexdigest() for p in needed):
        continue
    gen = receipt_path.parent/'results/export/Veri7vn_Stores/Veri7vn_Stores.Stores_Export/code/stores.ML'
    expected = receipt.get('export_sha256',{}).get('Veri7vn_Stores.Stores_Export/code/stores.ML')
    if gen.is_file() and hashlib.sha256(gen.read_bytes()).hexdigest() == expected:
        matched = gen
        break
if matched is None:
    raise SystemExit('No successful remote export matches these Stores theories. Run tools/dev/remote-build first.')
shutil.copyfile(matched, out/'stores_generated.sml')
(out/'config.sml').write_text('structure Config = struct val repo = '+json.dumps(str(root))+' end\n')
(out/'stores.mlb').write_text('$(SML_LIB)/basis/basis.mlb\nstores_generated.sml\nconfig.sml\n'+
    str(source.parent/'commons/commons.sml')+'\n'+''.join(str(source/n)+'\n' for n in ('json.sml','recognizer.sml','main.sml')))
print('Checked export:', matched)
PY
"$MLTON" -output "$OUT/build/stores.next" "$OUT/build/stores.mlb"
mv "$OUT/build/stores.next" "$OUT/bin/stores"
ls -l "$OUT/bin/stores"
shasum -a 256 "$OUT/build/stores_generated.sml" "$OUT/bin/stores"
