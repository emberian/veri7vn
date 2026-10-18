#!/bin/sh
# Build the precision-guard replay binary from the checked HOL export.
#
# Precondition: the Isabelle session has passed check-native / remote-build
# (that is where the theorems are proved and the code is generated); this
# script never builds Isabelle sessions. It
#   1. reads the generated SML (from the last remote build's export under
#      var/guards/export-remote/, or, with REMOTE=0, out of the session
#      database via isabelle export -n while holding the shared native lock),
#   2. compiles generated kernel + untrusted recognizer + driver with the
#      MLton that ships inside Isabelle,
#   3. writes var/guards/bin/guards and prints its size.
set -eu
REPO=$(cd "$(dirname "$0")/../../.." && pwd)
ISABELLE_APP=${ISABELLE_APP:-/Applications/Isabelle2026-RC1.app}
MLTON=$(ls -d "$ISABELLE_APP"/contrib/mlton-*/*/bin/mlton | head -n 1)
SRC=$REPO/src/extract/guards
OUT=$REPO/var/guards
cd "$REPO"
mkdir -p "$OUT/bin" "$OUT/build"

if [ "${REMOTE:-1}" = 1 ] && [ -d "$OUT/export-remote/Veri7vn_Guards" ]; then
  GEN=$(find "$OUT/export-remote/Veri7vn_Guards" -type f -name 'guards.ML' | head -n 1)
  [ -n "$GEN" ] || { echo "no remote export under $OUT/export-remote; run remote-build first" >&2; exit 1; }
  cp "$GEN" "$OUT/build/guards_generated.sml"
else
  rm -rf "$OUT/export"
  REPO="$REPO" ISABELLE_APP="$ISABELLE_APP" OUT="$OUT" python3 - <<'PYEOF'
import fcntl, os, subprocess
repo, app, out = os.environ["REPO"], os.environ["ISABELLE_APP"], os.environ["OUT"]
with open(os.path.join(repo, "var/native-scaffold/build.lock"), "a") as lock:
    fcntl.flock(lock, fcntl.LOCK_EX)
    env = dict(os.environ, USER_HOME=os.path.join(repo, "var/native-scaffold/user-state"))
    subprocess.run([os.path.join(app, "bin/isabelle"), "export", "-n", "-d", "src/extract/guards",
                    "-O", os.path.join(out, "export"), "-x", "*:code/**", "Veri7vn_Guards"],
                   check=True, env=env, cwd=repo)
PYEOF
  GEN=$(find "$OUT/export" -type f -name 'guards*' | head -n 1)
  [ -n "$GEN" ] || { echo "no generated SML found under $OUT/export" >&2; exit 1; }
  cp "$GEN" "$OUT/build/guards_generated.sml"
fi

cat > "$OUT/build/guards.mlb" <<'MLBEOF'
$(SML_LIB)/basis/basis.mlb
guards_generated.sml
MLBEOF
printf '%s\n%s\n%s\n' "$SRC/regex.sml" "$SRC/recognizer.sml" "$SRC/main.sml" >> "$OUT/build/guards.mlb"
# allowExtendedTextConsts: the Python patterns carry UTF-8 bytes (curly quotes,
# the degree sign, superscripts); SML strings are byte vectors, so the
# recognizer matches them exactly as Python's re does on UTF-8 text.
"$MLTON" -default-ann 'allowExtendedTextConsts true' -output "$OUT/bin/guards" "$OUT/build/guards.mlb"
ls -l "$OUT/bin/guards"
shasum -a 256 "$OUT/build/guards_generated.sml" "$OUT/bin/guards"
