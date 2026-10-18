#!/bin/sh
# Compile the macOS programs of the families ported onto src/extract/commons (acoustics, quantity, variants) from the
# kernel SML that a fresh Linux session build produced (tools/dev/remote-build leaves it in var/<slug>/export-remote/).
# Why: those families' build.sh read the SML out of the local Isabelle session database with `isabelle export -n`
# without building, and the local databases of Veri7vn_Acoustics and Veri7vn_Quantity predate the port, so build.sh
# returned the old kernel text. The SML is platform-independent; the fresh PASS is the Linux one.
#
#   tools/organs/macos-from-export.sh        # writes var/organs/darwin-arm64/{acoustics,quantity,variants}
#                                            # and <slug>.generated.sml beside them (package.py hashes it)
set -eu
REPO=$(cd "$(dirname "$0")/../.." && pwd -P)
ISABELLE_APP=${ISABELLE_APP:-/Applications/Isabelle2026-RC1.app}
MLTON=$(ls -d "$ISABELLE_APP"/contrib/mlton-*/*/bin/mlton | head -n 1)
OUT=$REPO/var/organs/darwin-arm64
B=$REPO/var/organs/darwin-build
mkdir -p "$OUT" "$B"
Q=$REPO/src/extract/quantity
one() {  # slug, session, generated-name, mlb tail
  slug=$1; session=$2; name=$3
  gen=$(find "$REPO/var/${4:-$slug}/export-remote/$session" -type f -name "$name*" | head -n 1)
  [ -n "$gen" ] || { echo "no export-remote SML for $slug" >&2; exit 1; }
  mkdir -p "$B/$slug"; cp "$gen" "$B/$slug/${name}_generated.sml"; cp "$gen" "$OUT/$slug.generated.sml"
}
one acoustics Veri7vn_Acoustics acoustics
one quantity Veri7vn_Quantity quantity
cat > "$B/acoustics/acoustics.mlb" <<MLB
\$(SML_LIB)/basis/basis.mlb
acoustics_generated.sml
$REPO/src/extract/commons/commons.sml
$REPO/src/extract/acoustics/recognizer.sml
$REPO/src/extract/acoustics/main.sml
MLB
cat > "$B/quantity/quantity.mlb" <<MLB
\$(SML_LIB)/basis/basis.mlb
quantity_generated.sml
$REPO/src/extract/commons/commons.sml
$Q/recognizer.sml
$Q/main.sml
MLB
mkdir -p "$B/variants"; cp "$B/quantity/quantity_generated.sml" "$B/variants/"; cp "$B/quantity/quantity_generated.sml" "$OUT/variants.generated.sml"
sed -e 's/^structure Recognizer :/structure RecognizerBase :/' \
    -e 's/^  val organs : string list$/  val organs : string list\n  val densities : string -> Quantity.request option\n  val unitsV2 : string -> Quantity.request option\n  val unitsV3 : string -> Quantity.request option/' \
    "$Q/recognizer.sml" > "$B/variants/recognizer_base.sml"
cat > "$B/variants/variants.mlb" <<MLB
\$(SML_LIB)/basis/basis.mlb
quantity_generated.sml
$REPO/src/extract/commons/commons.sml
recognizer_base.sml
$REPO/src/extract/variants/variants.sml
$Q/main.sml
MLB
for s in acoustics quantity variants; do
  (cd "$B/$s" && "$MLTON" -output "$OUT/$s" "$s.mlb" > "$B/$s/mlton.log" 2>&1)
  ls -l "$OUT/$s"; shasum -a 256 "$OUT/$s" "$OUT/$s.generated.sml"
done
