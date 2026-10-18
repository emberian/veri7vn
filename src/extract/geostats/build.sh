#!/bin/sh
# Build the geostats family answerer binary from the checked HOL export.
#
# Precondition: the Isabelle session has passed check-native (that is where the
# theorems are proved and the code is generated); this script never builds
# Isabelle sessions. It
#   1. reads the generated SML out of the session database (isabelle export -n,
#      no build) while holding the shared native build lock,
#   2. compiles generated kernel + untrusted recognizer + driver with the MLton
#      that ships inside Isabelle,
#   3. writes var/geostats/bin/geostats and prints its size.
set -eu
REPO=$(cd "$(dirname "$0")/../../.." && pwd)
ISABELLE_APP=${ISABELLE_APP:-/Applications/Isabelle2026-RC1.app}
MLTON=$(ls -d "$ISABELLE_APP"/contrib/mlton-*/*/bin/mlton | head -n 1)
SRC=$REPO/src/extract/geostats
OUT=$REPO/var/geostats
cd "$REPO"
mkdir -p "$OUT/bin" "$OUT/build"

GEN=${1:-}
if [ -z "$GEN" ]; then
EXPORT="$OUT/export-$(date +%Y%m%d%H%M%S)-$$"
export EXPORT
REPO="$REPO" ISABELLE_APP="$ISABELLE_APP" OUT="$OUT" python3 - <<'EOF'
import fcntl, os, subprocess
repo, app, out = os.environ["REPO"], os.environ["ISABELLE_APP"], os.environ["OUT"]
with open(os.path.join(repo, "var/native-scaffold/build.lock"), "a") as lock:
    fcntl.flock(lock, fcntl.LOCK_EX)
    env = dict(os.environ, USER_HOME=os.path.join(repo, "var/native-scaffold/user-state"))
    subprocess.run([os.path.join(app, "bin/isabelle"), "export", "-n", "-d", "src/extract/geostats", "-d", "src/extract/commons",
                    "-O", os.environ["EXPORT"], "-x", "*:code/**", "Veri7vn_GeoStats"],
                   check=True, env=env, cwd=repo)
EOF
GEN=$(find "$EXPORT" -type f -name 'geostats*' | head -n 1)
fi
[ -n "$GEN" ] && [ -f "$GEN" ] || { echo "pass a checked exported SML file as the first argument" >&2; exit 1; }
cp "$GEN" "$OUT/build/geostats_generated.sml"

cat > "$OUT/build/geostats.mlb" <<EOF
\$(SML_LIB)/basis/basis.mlb
geostats_generated.sml
$SRC/../commons/commons.sml
$SRC/../commons/numeric.sml
$SRC/../commons/measured_input.sml
$SRC/recognizer.sml
$SRC/main.sml
EOF
"$REPO/tools/dev/native-compile" --family geostats --compiler "$MLTON" -- -output "$OUT/bin/geostats" "$OUT/build/geostats.mlb"
ls -l "$OUT/bin/geostats"
shasum -a 256 "$OUT/build/geostats_generated.sml" "$OUT/bin/geostats"
