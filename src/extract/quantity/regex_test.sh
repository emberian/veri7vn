#!/bin/sh
# Compile regex.sml + regex_test.sml with the Isabelle-bundled MLton and run it. No Isabelle session.
set -eu
D=$(cd "$(dirname "$0")" && pwd)
APP=${ISABELLE_APP:-/Applications/Isabelle2026-RC1.app}
MLTON=$(ls -d "$APP"/contrib/mlton-*/*/bin/mlton | head -n 1)
T=$(mktemp -d)
printf '$(SML_LIB)/basis/basis.mlb\n%s/regex.sml\n%s/regex_test.sml\n' "$D" "$D" > "$T/t.mlb"
"$MLTON" -output "$T/t" "$T/t.mlb"
"$T/t"
rm -rf "$T"
