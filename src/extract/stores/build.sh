#!/bin/sh
# Build the stores family answerer binary from the checked HOL export.
#
# Precondition: the Isabelle session Veri7vn_Stores has passed check-native
# (theorems proved, code generated); this script never builds Isabelle
# sessions. It
#   1. reads the generated SML out of the session database (isabelle export -n,
#      no build) while holding the shared native build lock,
#   2. compiles generated kernel + untrusted JSON, regex, recognizer and driver
#      with the MLton that ships inside Isabelle,
#   3. writes var/stores/bin/stores and prints its size.
# (Lane G's src/extract/quantity/build.sh, with this family's files.)
set -eu
REPO=$(cd "$(dirname "$0")/../../.." && pwd)
ISABELLE_APP=${ISABELLE_APP:-/Applications/Isabelle2026-RC1.app}
MLTON=$(ls -d "$ISABELLE_APP"/contrib/mlton-*/*/bin/mlton | head -n 1)
SRC=$REPO/src/extract/stores
OUT=$REPO/var/stores
cd "$REPO"
mkdir -p "$OUT/bin" "$OUT/build"

rm -rf "$OUT/export"
REPO="$REPO" ISABELLE_APP="$ISABELLE_APP" OUT="$OUT" python3 - <<'PY'
import fcntl, os, subprocess
repo, app, out = os.environ["REPO"], os.environ["ISABELLE_APP"], os.environ["OUT"]
with open(os.path.join(repo, "var/native-scaffold/build.lock"), "a") as lock:
    fcntl.flock(lock, fcntl.LOCK_EX)
    env = dict(os.environ, USER_HOME=os.path.join(repo, "var/native-scaffold/user-state"))
    subprocess.run([os.path.join(app, "bin/isabelle"), "export", "-n", "-d", "src/extract/stores",
                    "-O", os.path.join(out, "export"), "-x", "*:code/**", "Veri7vn_Stores"],
                   check=True, env=env, cwd=repo)
PY
GEN=$(find "$OUT/export" -type f -name 'stores*' | head -n 1)
[ -n "$GEN" ] || { echo "no generated SML found under $OUT/export" >&2; exit 1; }
cp "$GEN" "$OUT/build/stores_generated.sml"
printf 'structure Config = struct val repo = "%s" end\n' "$REPO" > "$OUT/build/config.sml"

cat > "$OUT/build/stores.mlb" <<MLB
\$(SML_LIB)/basis/basis.mlb
stores_generated.sml
config.sml
$SRC/json.sml
$SRC/regex.sml
$SRC/recognizer.sml
$SRC/main.sml
MLB
"$MLTON" -output "$OUT/bin/stores" "$OUT/build/stores.mlb"
ls -l "$OUT/bin/stores"
shasum -a 256 "$OUT/build/stores_generated.sml" "$OUT/bin/stores"
