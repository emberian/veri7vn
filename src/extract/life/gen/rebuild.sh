#!/bin/sh
# Regenerate src/extract/life/recognizer.sml from the parts (run from anywhere).
# The parts write regex text inside the bracket pair U+27E6 .. U+27E7, which conv.py turns into
# an escaped SML string literal. With "compile" as the first argument, also recompile var/life/bin/life
# from the already-exported var/life/build/ (after build.sh).
set -eu
D=$(cd "$(dirname "$0")" && pwd)
cat "$D/part1.sml" "$D/part2.sml" "$D/part3.sml" > "$D/all.sml.tmp"
python3 -B "$D/conv.py" "$D/all.sml.tmp" "$D/../recognizer.sml"
rm -f "$D/all.sml.tmp"
if [ "${1:-}" = compile ]; then
  M=$(ls -d /Applications/Isabelle2026-RC1.app/contrib/mlton-*/*/bin/mlton | head -n 1)
  REPO=$(cd "$D/../../../.." && pwd)
  cd "$REPO/var/life/build" && "$M" -output ../bin/life life.mlb
fi
