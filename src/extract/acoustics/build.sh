#!/bin/sh
# Build the acoustics answerer binary from the checked HOL export.
#
# Precondition: the Isabelle session has passed check-native (that is where the
# theorems are proved and the code is generated); this script never builds
# Isabelle sessions. It
#   1. reads the generated SML out of the session database (isabelle export -n,
#      no build) while holding the shared native build lock,
#   2. compiles generated kernel + untrusted recognizer + driver with the MLton
#      that ships inside Isabelle,
#   3. writes var/acoustics/bin/acoustics and prints its size.
set -eu
REPO=$(cd "$(dirname "$0")/../../.." && pwd)
ISABELLE_APP=${ISABELLE_APP:-/Applications/Isabelle2026-RC1.app}
MLTON=$(ls -d "$ISABELLE_APP"/contrib/mlton-*/*/bin/mlton | head -n 1)
SRC=$REPO/src/extract/acoustics
OUT=$REPO/var/acoustics
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
    subprocess.run([os.path.join(app, "bin/isabelle"), "export", "-n", "-d", "src/extract/acoustics", "-d", "src/extract/commons",
                    "-O", os.environ["EXPORT_DIR"], "-x", "*:code/**", "Veri7vn_Acoustics"],
                   check=True, env=env, cwd=repo)
EOF
GEN=$(find "$EXPORT_DIR" -type f -name 'acoustics*' | head -n 1)
fi
[ -n "$GEN" ] && [ -f "$GEN" ] || { echo "no generated SML file: $GEN" >&2; exit 1; }
cp "$GEN" "$OUT/build/acoustics_generated.sml"

cat > "$OUT/build/acoustics.mlb" <<EOF
\$(SML_LIB)/basis/basis.mlb
acoustics_generated.sml
$SRC/../commons/commons.sml
$SRC/recognizer.sml
$SRC/main.sml
EOF
BIN_TEMP=$(mktemp "$OUT/bin/.acoustics.XXXXXX")
"$MLTON" -output "$BIN_TEMP" "$OUT/build/acoustics.mlb"
mv "$BIN_TEMP" "$OUT/bin/acoustics"
ls -l "$OUT/bin/acoustics"
shasum -a 256 "$OUT/build/acoustics_generated.sml" "$OUT/bin/acoustics"
