#!/bin/sh
# Build the chemistry family answerer binary from the checked HOL export.
#
# Precondition: the Isabelle session has passed check-native (that is where the
# theorems are proved and the code is generated); this script never builds
# Isabelle sessions. It
#   1. reads the generated SML out of the session database (isabelle export -n,
#      no build) while holding the shared native build lock,
#   2. compiles generated kernel + untrusted recognizer + driver with the MLton
#      that ships inside Isabelle,
#   3. writes var/chemistry/bin/chemistry and prints its size.
set -eu
REPO=$(cd "$(dirname "$0")/../../.." && pwd)
ISABELLE_APP=${ISABELLE_APP:-/Applications/Isabelle2026-RC1.app}
MLTON=$(ls -d "$ISABELLE_APP"/contrib/mlton-*/*/bin/mlton | head -n 1)
SRC=$REPO/src/extract/chemistry
OUT=$REPO/var/chemistry
cd "$REPO"
mkdir -p "$OUT/bin" "$OUT/build"

# CHEM_GEN=<path to chemistry.ML> uses a remote build's export (var/chemistry/export-remote/...) and skips the local export.
if [ -n "${CHEM_GEN:-}" ]; then
  GEN=$CHEM_GEN
else
rm -rf "$OUT/export"
REPO="$REPO" ISABELLE_APP="$ISABELLE_APP" OUT="$OUT" python3 - <<'EOF'
import fcntl, os, subprocess
repo, app, out = os.environ["REPO"], os.environ["ISABELLE_APP"], os.environ["OUT"]
with open(os.path.join(repo, "var/native-scaffold/build.lock"), "a") as lock:
    fcntl.flock(lock, fcntl.LOCK_EX)
    env = dict(os.environ, USER_HOME=os.path.join(repo, "var/native-scaffold/user-state"))
    subprocess.run([os.path.join(app, "bin/isabelle"), "export", "-n", "-d", "src/extract/chemistry", "-d", "src/extract/commons",
                    "-O", os.path.join(out, "export"), "-x", "*:code/**", "Veri7vn_Chemistry"],
                   check=True, env=env, cwd=repo)
EOF
GEN=$(find "$OUT/export" -type f -name 'chemistry*' | head -n 1)
fi
[ -n "$GEN" ] || { echo "no generated SML found under $OUT/export" >&2; exit 1; }
cp "$GEN" "$OUT/build/chemistry_generated.sml"

cat > "$OUT/build/chemistry.mlb" <<EOF
\$(SML_LIB)/basis/basis.mlb
chemistry_generated.sml
$SRC/../commons/commons.sml
$SRC/../commons/numeric.sml
$SRC/recognizer.sml
$SRC/main.sml
EOF
"$REPO/tools/dev/native-compile" --family chemistry --compiler "$MLTON" -- -output "$OUT/bin/chemistry" "$OUT/build/chemistry.mlb"
ls -l "$OUT/bin/chemistry"
shasum -a 256 "$OUT/build/chemistry_generated.sml" "$OUT/bin/chemistry"
