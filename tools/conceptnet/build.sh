#!/bin/sh
# Compile var/conceptnet/bin/decide from the HOL export (written by the Veri7vn_Conceptnet session
# build, or fetched from a remote build into var/conceptnet/export-remote/) and the untrusted I/O
# driver decide_main.sml, with the MLton that ships inside Isabelle2026-RC1.
set -eu
REPO=$(cd "$(dirname "$0")/../.." && pwd)
MLTON=$(ls -d /Applications/Isabelle2026-RC1.app/contrib/mlton-20241230-1/*/bin/mlton | head -n 1)
GEN="$REPO/var/conceptnet/gen/Conceptnet_Code.ML"
REMOTE="$REPO/var/conceptnet/export-remote/Veri7vn_Conceptnet"
OUT="$REPO/var/conceptnet/bin"
mkdir -p "$OUT"
if [ -d "$REMOTE" ]; then
  # a remote build brought the export back; prefer it whenever it is newer than the
  # locally generated copy (the local gen/ is only written by a local session build)
  src=$(ls -t $(find "$REMOTE" -name '*.ML' 2>/dev/null) 2>/dev/null | head -n 1 || true)
  if [ -n "$src" ] && { [ ! -f "$GEN" ] || [ "$src" -nt "$GEN" ]; }; then cp "$src" "$GEN"; fi
fi
test -f "$GEN" || { echo "missing $GEN: build the Veri7vn_Conceptnet session first" >&2; exit 1; }
printf '$(SML_LIB)/basis/basis.mlb\n%s\n%s\n' "$GEN" "$REPO/tools/conceptnet/decide_main.sml" > "$OUT/decide.mlb"
"$MLTON" -output "$OUT/decide" "$OUT/decide.mlb"
shasum "$GEN" "$OUT/decide"
