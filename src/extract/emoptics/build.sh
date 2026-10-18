#!/bin/sh
# Build the emoptics family answerer binary from the checked HOL export.
#
# Precondition: a managed Isabelle receipt matches the current proof sources
# and generated export; this script never builds
# Isabelle sessions. It
#   1. reads the generated SML out of the session database (isabelle export -n,
#      no build) while holding the shared native build lock,
#   2. freezes the generated kernel, untrusted recognizer and driver before
#      compiling with the MLton that ships inside Isabelle,
#   3. publishes var/emoptics/bin/emoptics atomically and records the consumed
#      inputs in var/emoptics/build/compile-inputs.json.
set -eu
REPO=$(cd "$(dirname "$0")/../../.." && pwd)
ISABELLE_APP=${ISABELLE_APP:-/Applications/Isabelle2026-RC1.app}
MLTON=$(ls -d "$ISABELLE_APP"/contrib/mlton-*/*/bin/mlton | head -n 1)
SRC=$REPO/src/extract/emoptics
OUT=$REPO/var/emoptics
cd "$REPO"
mkdir -p "$OUT/bin" "$OUT/build"

# A successful remote attempt supplies its exact exported file. Local export
# gets a fresh directory; do not remove another session's export cache.
GEN=${GENERATED_SML:-${EMOPTICS_GEN:-}}
if [ -n "$GEN" ]; then
  :
else
EXPORT_DIR="$OUT/export-local-$$"
mkdir -p "$EXPORT_DIR"
REPO="$REPO" ISABELLE_APP="$ISABELLE_APP" OUT="$OUT" EXPORT_DIR="$EXPORT_DIR" python3 -B - <<'EOF'
import fcntl, os, subprocess
repo, app, out = os.environ["REPO"], os.environ["ISABELLE_APP"], os.environ["OUT"]
with open(os.path.join(repo, "var/native-scaffold/build.lock"), "a") as lock:
    fcntl.flock(lock, fcntl.LOCK_EX)
    env = dict(os.environ, USER_HOME=os.path.join(repo, "var/native-scaffold/user-state"))
    subprocess.run([os.path.join(app, "bin/isabelle"), "export", "-n", "-d", "src/extract/emoptics", "-d", "src/extract/commons",
                    "-O", os.environ["EXPORT_DIR"], "-x", "*:code/**", "Veri7vn_Emoptics"],
                   check=True, env=env, cwd=repo)
EOF
GEN=$(find "$EXPORT_DIR" -type f -name 'emoptics*' | head -n 1)
fi
[ -n "$GEN" ] || { echo "no generated SML found under $OUT/export" >&2; exit 1; }
cp "$GEN" "$OUT/build/emoptics_generated.sml"

cat > "$OUT/build/emoptics.mlb" <<EOF
\$(SML_LIB)/basis/basis.mlb
emoptics_generated.sml
$SRC/../commons/commons.sml
$SRC/../commons/numeric.sml
$SRC/../commons/measured_input.sml
$SRC/optical_recognizer.sml
$SRC/recognizer.sml
$SRC/main.sml
EOF
"$REPO/tools/dev/native-compile" --family emoptics --compiler "$MLTON" -- \
  -output "$OUT/bin/emoptics" "$OUT/build/emoptics.mlb"
ls -l "$OUT/bin/emoptics"
shasum -a 256 "$OUT/build/emoptics_generated.sml" "$OUT/bin/emoptics"
