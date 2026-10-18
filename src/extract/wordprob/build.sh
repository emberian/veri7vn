#!/bin/sh
# Build the word-problem organ answerer binary from the checked HOL export.
#
# Precondition: the Isabelle session Veri7vn_Wordprob has passed remotely
# (tools/dev/remote-build, which is where the theorems are proved and the code
# generated); this script never builds Isabelle sessions. It
#   1. copies the generated SML from the remote-build export if present,
#      otherwise reads it out of the local session database (isabelle export -n,
#      no build) while holding the shared native build lock,
#   2. compiles generated kernel + untrusted recognizer + driver with the MLton
#      that ships inside Isabelle,
#   3. writes var/wordprob/bin/wordprob and prints its size.
set -eu
HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../../.." && pwd)
ISABELLE_APP=${ISABELLE_APP:-/Applications/Isabelle2026-RC1.app}
MLTON=$(ls -d "$ISABELLE_APP"/contrib/mlton-*/*/bin/mlton | head -n 1)
SRC=$HERE
OUT=$REPO/var/wordprob
cd "$REPO"
mkdir -p "$OUT/bin" "$OUT/build"

GEN=""
for f in "$OUT"/export-remote/Veri7vn_Wordprob/*/code/wordprob* \
         "$OUT"/export-remote/Veri7vn_Wordprob/code/wordprob*; do
  [ -f "$f" ] && GEN=$f && break
done
if [ -z "$GEN" ]; then
  rm -rf "$OUT/export"
  REPO="$REPO" ISABELLE_APP="$ISABELLE_APP" OUT="$OUT" python3 - <<'EOF'
import fcntl, os, subprocess
repo, app, out = os.environ["REPO"], os.environ["ISABELLE_APP"], os.environ["OUT"]
with open(os.path.join(repo, "var/native-scaffold/build.lock"), "a") as lock:
    fcntl.flock(lock, fcntl.LOCK_EX)
    env = dict(os.environ, USER_HOME=os.path.join(repo, "var/native-scaffold/user-state"))
    subprocess.run([os.path.join(app, "bin/isabelle"), "export", "-n", "-d", "src/extract/wordprob",
                    "-O", os.path.join(out, "export"), "-x", "*:code/**", "Veri7vn_Wordprob"],
                   check=True, env=env, cwd=repo)
EOF
  GEN=$(find "$OUT/export" -type f -name 'wordprob*' | head -n 1)
fi
[ -n "$GEN" ] || { echo "no generated SML found under $OUT" >&2; exit 1; }
cp "$GEN" "$OUT/build/wordprob_generated.sml"

cat > "$OUT/build/wordprob.mlb" <<EOF
\$(SML_LIB)/basis/basis.mlb
wordprob_generated.sml
$SRC/regex.sml
$SRC/recognizer.sml
$SRC/main.sml
EOF
"$MLTON" -output "$OUT/bin/wordprob" "$OUT/build/wordprob.mlb"
ls -l "$OUT/bin/wordprob"
shasum -a 256 "$OUT/build/wordprob_generated.sml" "$OUT/bin/wordprob"
