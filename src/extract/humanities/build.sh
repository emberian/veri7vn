#!/bin/sh
# Build the humanities family answerer binary from the checked HOL export.
#
# Precondition: the Isabelle session has passed check-native (that is where the
# theorems are proved and the code is generated); this script never builds
# Isabelle sessions. It
#   1. reads the generated SML from a completed remote build export,
#   2. compiles generated kernel + untrusted recognizer + driver with the MLton
#      that ships inside Isabelle,
#   3. writes var/humanities/bin/humanities and prints its size.
set -eu
REPO=$(cd "$(dirname "$0")/../../.." && pwd)
ISABELLE_APP=${ISABELLE_APP:-/Applications/Isabelle2026-RC1.app}
MLTON=$(ls -d "$ISABELLE_APP"/contrib/mlton-*/*/bin/mlton | head -n 1)
SRC=$REPO/src/extract/humanities
OUT=$REPO/var/humanities
cd "$REPO"
mkdir -p "$OUT/bin" "$OUT/build"

# Use the checked remote export; an explicit path pins an immutable receipt.
GEN=${HUMANITIES_GEN:-$OUT/export-remote/Veri7vn_Humanities/Veri7vn_Humanities.Humanities_Export/code/humanities.ML}
[ -f "$GEN" ] || { echo "missing checked export: $GEN (run remote-build first)" >&2; exit 1; }
cp "$GEN" "$OUT/build/humanities_generated.sml"

cat > "$OUT/build/humanities.mlb" <<EOF
\$(SML_LIB)/basis/basis.mlb
humanities_generated.sml
$SRC/../commons/commons.sml
$SRC/rules.sml
$SRC/recognizer.sml
$SRC/main.sml
EOF
"$MLTON" -output "$OUT/bin/humanities" "$OUT/build/humanities.mlb"
ls -l "$OUT/bin/humanities"
shasum -a 256 "$OUT/build/humanities_generated.sml" "$OUT/bin/humanities"

REPO="$REPO" SRC="$SRC" OUT="$OUT" GEN="$GEN" python3 -B - <<'PYREC'
import hashlib, json, os
from pathlib import Path
src, out, repo, gen = map(Path, (os.environ[k] for k in ('SRC','OUT','REPO','GEN')))
def digest(p): return hashlib.sha256(p.read_bytes()).hexdigest()
inputs = [gen, repo/'src/extract/commons/commons.sml', *sorted(src.glob('*.sml'))]
theories = [src/'ROOT', *sorted(src.rglob('*.thy'))]
record = {'binary_sha256':digest(out/'bin'/src.name),
          'generated_export':str(gen.resolve()),
          'inputs_sha256':{str(p.resolve()):digest(p) for p in inputs},
          'theories_sha256':{str(p.relative_to(repo)):digest(p) for p in theories},
          'note':'Compilation inputs; proof evidence remains the completed remote Isabelle receipt.'}
(out/'build/compile-inputs.json').write_text(json.dumps(record,indent=2)+'\n')
PYREC
