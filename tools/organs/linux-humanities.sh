#!/bin/sh
# Build the humanities answerer on a Linux host. tools/deploy/linux-build.sh cannot: humanities' driver also needs
# src/extract/humanities/rules.sml in the .mlb (see src/extract/humanities/build.sh). Same steps otherwise.
#   tools/organs/linux-humanities.sh [host]       # default hbox; binary lands in ~/veri7vn-deploy/bin/humanities
set -eu
host=${1:-hbox}
REPO=$(cd "$(dirname "$0")/../.." && pwd -P)
cd "$REPO"
tools/dev/remote-build "$host" src/extract/humanities Veri7vn_Humanities --expect 'VERI7VN_HUMANITIES PASS'
rroot="veri7vn-builds/$(basename "$REPO")"
ssh -o BatchMode=yes "$host" sh -s "$rroot" <<'REMOTE'
set -eu
R=$HOME/$1
MLTON=$(ls -d "$HOME"/tools/isabelle-rc1/Isabelle2026-RC1/contrib/mlton-*/x86_64-linux/bin/mlton | head -n 1)
D=$HOME/veri7vn-deploy
mkdir -p "$D/bin" "$D/build/humanities"
GEN=$(find "$R/export/Veri7vn_Humanities" -type f -name 'humanities*' | head -n 1)
[ -n "$GEN" ] || { echo "no exported SML under $R/export/Veri7vn_Humanities" >&2; exit 1; }
cp "$GEN" "$D/build/humanities/humanities_generated.sml"
S=$R/src/extract/humanities
cat > "$D/build/humanities/humanities.mlb" <<MLB
\$(SML_LIB)/basis/basis.mlb
humanities_generated.sml
$S/regex.sml
$S/rules.sml
$S/recognizer.sml
$S/main.sml
MLB
cd "$D/build/humanities"
swarm-build "$MLTON" -output "$D/bin/humanities" humanities.mlb
ls -l "$D/bin/humanities"
sha256sum "$D/bin/humanities"
REMOTE
