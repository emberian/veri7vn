#!/bin/sh
# Build the variants answerer binary (densities-r2, units-v2, units-v3-r2 plus
# the base quantity ids). Lane G's checked export and recognizer are reused;
# nothing under src/extract/quantity is edited and no Isabelle session is built.
# RecognizerBase is lane G's recognizer.sml with its structure renamed and three
# functions added to its signature (sed below). Regex and Json come from
# src/extract/commons/commons.sml, as in lane G's own build.
set -eu
REPO=$(cd "$(dirname "$0")/../../.." && pwd)
ISABELLE_APP=${ISABELLE_APP:-/Applications/Isabelle2026-RC1.app}
MLTON=$(ls -d "$ISABELLE_APP"/contrib/mlton-*/*/bin/mlton | head -n 1)
Q=$REPO/src/extract/quantity
SRC=$REPO/src/extract/variants
OUT=$REPO/var/variants
cd "$REPO"
mkdir -p "$OUT/bin" "$OUT/build"

# GENERATED_SML pins a successful remote receipt; otherwise export into a new
# directory so an old session export cannot be mistaken for this invocation.
GEN=${GENERATED_SML:-}
if [ -z "$GEN" ]; then
EXPORT_DIR=$(mktemp -d "$OUT/export.XXXXXX")
REPO="$REPO" ISABELLE_APP="$ISABELLE_APP" OUT="$OUT" EXPORT_DIR="$EXPORT_DIR" python3 -B - <<'PY'
import fcntl, os, subprocess
repo, app, out = os.environ["REPO"], os.environ["ISABELLE_APP"], os.environ["OUT"]
with open(os.path.join(repo, "var/native-scaffold/build.lock"), "a") as lock:
    fcntl.flock(lock, fcntl.LOCK_EX)
    env = dict(os.environ, USER_HOME=os.path.join(repo, "var/native-scaffold/user-state"))
    subprocess.run([os.path.join(app, "bin/isabelle"), "export", "-n", "-d", "src/extract/quantity", "-d", "src/extract/commons",
                    "-O", os.environ["EXPORT_DIR"], "-x", "*:code/**", "Veri7vn_Quantity"],
                   check=True, env=env, cwd=repo)
PY
GEN=$(find "$EXPORT_DIR" -type f -name 'quantity*' | head -n 1)
fi
[ -n "$GEN" ] && [ -f "$GEN" ] || { echo "no generated SML file: $GEN" >&2; exit 1; }
cp "$GEN" "$OUT/build/quantity_generated.sml"

sed -e 's/^structure Recognizer :/structure RecognizerBase :/' \
    -e 's/^  val organs : string list$/  val organs : string list\n  val densities : string -> Quantity.request option\n  val unitsV2 : string -> Quantity.request option\n  val unitsV3 : string -> Quantity.request option/' \
    "$Q/recognizer.sml" > "$OUT/build/recognizer_base.sml"
grep -q '^structure RecognizerBase' "$OUT/build/recognizer_base.sml"
grep -q 'val unitsV2 :' "$OUT/build/recognizer_base.sml"

cat > "$OUT/build/variants.mlb" <<EOM
\$(SML_LIB)/basis/basis.mlb
quantity_generated.sml
$REPO/src/extract/commons/commons.sml
$REPO/src/extract/commons/numeric.sml
recognizer_base.sml
$SRC/variants.sml
$Q/main.sml
EOM
"$REPO/tools/dev/native-compile" --family variants --compiler "$MLTON" -- \
  -output "$OUT/bin/variants" "$OUT/build/variants.mlb"
ls -l "$OUT/bin/variants"
shasum -a 256 "$OUT/build/quantity_generated.sml" "$OUT/bin/variants"
