#!/bin/sh
# Compile the variants answerer binary on a Linux build host, the way src/extract/variants/build.sh does on macOS.
# tools/deploy/linux-build.sh cannot (variants has no main.sml of its own and no session of its own). Run it after
# `tools/deploy/linux-build.sh quantity Veri7vn_Quantity` has left the checked export and the synced tree on the host.
#
#   tools/organs/linux-variants.sh [host]        # default hbox; binary lands in ~/veri7vn-deploy/bin/variants
set -eu
host=${1:-hbox}
REPO=$(cd "$(dirname "$0")/../.." && pwd -P)
rroot="veri7vn-builds/$(basename "$REPO")"
ssh -o BatchMode=yes "$host" sh -s "$rroot" <<'REMOTE'
set -eu
R=$HOME/$1
MLTON=$(ls -d "$HOME"/tools/isabelle-rc1/Isabelle2026-RC1/contrib/mlton-*/x86_64-linux/bin/mlton | head -n 1)
D=$HOME/veri7vn-deploy
mkdir -p "$D/bin" "$D/build/variants"
GEN=$(find "$R/export/Veri7vn_Quantity" -type f -name 'quantity*' | head -n 1)
[ -n "$GEN" ] || { echo "no exported SML under $R/export/Veri7vn_Quantity" >&2; exit 1; }
cp "$GEN" "$D/build/variants/quantity_generated.sml"
Q=$R/src/extract/quantity
sed -e 's/^structure Recognizer :/structure RecognizerBase :/' \
    -e 's/^  val organs : string list$/  val organs : string list\n  val densities : string -> Quantity.request option\n  val unitsV2 : string -> Quantity.request option\n  val unitsV3 : string -> Quantity.request option/' \
    "$Q/recognizer.sml" > "$D/build/variants/recognizer_base.sml"
grep -q '^structure RecognizerBase' "$D/build/variants/recognizer_base.sml"
grep -q 'val unitsV2 :' "$D/build/variants/recognizer_base.sml"
cat > "$D/build/variants/variants.mlb" <<MLB
\$(SML_LIB)/basis/basis.mlb
quantity_generated.sml
$R/src/extract/commons/commons.sml
recognizer_base.sml
$R/src/extract/variants/variants.sml
$Q/main.sml
MLB
cd "$D/build/variants"
swarm-build "$MLTON" -output "$D/bin/variants" variants.mlb
ls -l "$D/bin/variants"
sha256sum "$D/build/variants/quantity_generated.sml" "$D/bin/variants"
REMOTE
