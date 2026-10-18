#!/bin/sh
# Build the mechanics family answerer binary from the checked HOL export.
#
# Precondition: the Isabelle session has passed check-native (that is where the
# theorems are proved and the code is generated); this script never builds
# Isabelle sessions. It
#   1. consumes a checked remote export (or GENERATED_SML), falling back to
#      isabelle export -n under the shared native build lock,
#   2. compiles generated kernel + untrusted recognizer + driver with the MLton
#      that ships inside Isabelle,
#   3. writes var/mechanics/bin/mechanics and prints its size.
set -eu
REPO=$(cd "$(dirname "$0")/../../.." && pwd)
ISABELLE_APP=${ISABELLE_APP:-/Applications/Isabelle2026-RC1.app}
MLTON=$(ls -d "$ISABELLE_APP"/contrib/mlton-*/*/bin/mlton | head -n 1)
SRC=$REPO/src/extract/mechanics
OUT=$REPO/var/mechanics
cd "$REPO"
mkdir -p "$OUT/bin" "$OUT/build"

GEN=${GENERATED_SML:-}
if [ -z "$GEN" ]; then
  for f in "$OUT"/export-remote/Veri7vn_Mechanics/*/code/mechanics* \
           "$OUT"/export-remote/Veri7vn_Mechanics/code/mechanics*; do
    [ -f "$f" ] && GEN=$f && break
  done
fi
if [ -z "$GEN" ]; then
EXPORT_DIR=$(mktemp -d "$OUT/export.XXXXXX")
EXPORT_DIR="$EXPORT_DIR" REPO="$REPO" ISABELLE_APP="$ISABELLE_APP" OUT="$OUT" python3 - <<'EOF'
import fcntl, os, subprocess
repo, app, out = os.environ["REPO"], os.environ["ISABELLE_APP"], os.environ["OUT"]
with open(os.path.join(repo, "var/native-scaffold/build.lock"), "a") as lock:
    fcntl.flock(lock, fcntl.LOCK_EX)
    env = dict(os.environ, USER_HOME=os.path.join(repo, "var/native-scaffold/user-state"))
    subprocess.run([os.path.join(app, "bin/isabelle"), "export", "-n", "-d", "src/extract/mechanics", "-d", "src/extract/commons",
                    "-O", os.environ["EXPORT_DIR"], "-x", "*:code/**", "Veri7vn_Mechanics"],
                   check=True, env=env, cwd=repo)
EOF
GEN=$(find "$EXPORT_DIR" -type f -name 'mechanics*' | head -n 1)
[ -n "$GEN" ] || { echo "no generated SML found under $EXPORT_DIR" >&2; exit 1; }
fi
[ -f "$GEN" ] || { echo "generated SML not found: $GEN" >&2; exit 1; }
cp "$GEN" "$OUT/build/mechanics_generated.sml"

cat > "$OUT/build/mechanics.mlb" <<EOF
\$(SML_LIB)/basis/basis.mlb
mechanics_generated.sml
$SRC/../commons/commons.sml
$SRC/../commons/numeric.sml
$SRC/recognizer.sml
$SRC/main.sml
EOF
python3 "$REPO/tools/dev/native-compile" --family mechanics --compiler "$MLTON" -- \
  -output "$OUT/bin/mechanics" "$OUT/build/mechanics.mlb"
ls -l "$OUT/bin/mechanics"
shasum -a 256 "$OUT/bin/mechanics"
