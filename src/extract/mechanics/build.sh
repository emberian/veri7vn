#!/bin/sh
# Build the mechanics family answerer binary from the checked HOL export.
#
# Precondition: the Isabelle session has passed check-native (that is where the
# theorems are proved and the code is generated); this script never builds
# Isabelle sessions. It
#   1. reads the generated SML out of the session database (isabelle export -n,
#      no build) while holding the shared native build lock,
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

rm -rf "$OUT/export"
REPO="$REPO" ISABELLE_APP="$ISABELLE_APP" OUT="$OUT" python3 - <<'EOF'
import fcntl, os, subprocess
repo, app, out = os.environ["REPO"], os.environ["ISABELLE_APP"], os.environ["OUT"]
with open(os.path.join(repo, "var/native-scaffold/build.lock"), "a") as lock:
    fcntl.flock(lock, fcntl.LOCK_EX)
    env = dict(os.environ, USER_HOME=os.path.join(repo, "var/native-scaffold/user-state"))
    subprocess.run([os.path.join(app, "bin/isabelle"), "export", "-n", "-d", "src/extract/mechanics",
                    "-O", os.path.join(out, "export"), "-x", "*:code/**", "Veri7vn_Mechanics"],
                   check=True, env=env, cwd=repo)
EOF
GEN=$(find "$OUT/export" -type f -name 'mechanics*' | head -n 1)
[ -n "$GEN" ] || { echo "no generated SML found under $OUT/export" >&2; exit 1; }
cp "$GEN" "$OUT/build/mechanics_generated.sml"

cat > "$OUT/build/mechanics.mlb" <<EOF
\$(SML_LIB)/basis/basis.mlb
mechanics_generated.sml
$SRC/regex.sml
$SRC/recognizer.sml
$SRC/main.sml
EOF
"$MLTON" -output "$OUT/bin/mechanics" "$OUT/build/mechanics.mlb"
ls -l "$OUT/bin/mechanics"
shasum -a 256 "$OUT/build/mechanics_generated.sml" "$OUT/bin/mechanics"
