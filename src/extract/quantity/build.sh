#!/bin/sh
# Build the quantity family answerer binary from the checked HOL export.
#
# Precondition: the Isabelle session has passed check-native (that is where the
# theorems are proved and the code is generated); this script never builds
# Isabelle sessions. It
#   1. reads the generated SML out of the session database (isabelle export -n,
#      no build) while holding the shared native build lock,
#   2. compiles generated kernel + untrusted recognizer + driver with the MLton
#      that ships inside Isabelle,
#   3. writes var/quantity/bin/quantity and prints its size.
set -eu
REPO=$(cd "$(dirname "$0")/../../.." && pwd)
ISABELLE_APP=${ISABELLE_APP:-/Applications/Isabelle2026-RC1.app}
MLTON=$(ls -d "$ISABELLE_APP"/contrib/mlton-*/*/bin/mlton | head -n 1)
SRC=$REPO/src/extract/quantity
OUT=$REPO/var/quantity
cd "$REPO"
mkdir -p "$OUT/bin" "$OUT/build"

# GENERATED_SML pins a successful remote receipt; otherwise export into a new
# directory so an old session export cannot be mistaken for this invocation.
GEN=${GENERATED_SML:-}
if [ -z "$GEN" ]; then
EXPORT_DIR=$(mktemp -d "$OUT/export.XXXXXX")
REPO="$REPO" ISABELLE_APP="$ISABELLE_APP" OUT="$OUT" EXPORT_DIR="$EXPORT_DIR" python3 -B - <<'EOF'
import fcntl, os, subprocess
repo, app, out = os.environ["REPO"], os.environ["ISABELLE_APP"], os.environ["OUT"]
with open(os.path.join(repo, "var/native-scaffold/build.lock"), "a") as lock:
    fcntl.flock(lock, fcntl.LOCK_EX)
    env = dict(os.environ, USER_HOME=os.path.join(repo, "var/native-scaffold/user-state"))
    subprocess.run([os.path.join(app, "bin/isabelle"), "export", "-n", "-d", "src/extract/quantity", "-d", "src/extract/commons",
                    "-O", os.environ["EXPORT_DIR"], "-x", "*:code/**", "Veri7vn_Quantity"],
                   check=True, env=env, cwd=repo)
EOF
GEN=$(find "$EXPORT_DIR" -type f -name 'quantity*' | head -n 1)
fi
[ -n "$GEN" ] && [ -f "$GEN" ] || { echo "no generated SML file: $GEN" >&2; exit 1; }
cp "$GEN" "$OUT/build/quantity_generated.sml"

cat > "$OUT/build/quantity.mlb" <<EOF
\$(SML_LIB)/basis/basis.mlb
quantity_generated.sml
$SRC/../commons/commons.sml
$SRC/../commons/numeric.sml
$REPO/src/extract/commons/measured_input.sml
$SRC/recognizer.sml
$SRC/main.sml
EOF
"$REPO/tools/dev/native-compile" --family quantity --compiler "$MLTON" -- \
  -output "$OUT/bin/quantity" "$OUT/build/quantity.mlb"
ls -l "$OUT/bin/quantity"
shasum -a 256 "$OUT/build/quantity_generated.sml" "$OUT/bin/quantity"
