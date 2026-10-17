#!/bin/sh
# Build var/dispatch/bin/arb_check: the MLton compile of lane C's exported
# arbitration (Veri7vn_Gate, from src/isabelle/specialists, session
# Veri7vn_Specialists) plus tools/dispatch/arb_driver.sml.
#
# The export is looked for in this worktree first (var/dispatch/export-remote/,
# filled by tools/dev/remote-build), then in the main checkout's
# var/gate/export/ (lane C's build of the same committed sources).
set -e
cd "$(dirname "$0")/../.."
MLTON=$(ls /Applications/Isabelle2026-RC1.app/contrib/mlton-*/*/bin/mlton | head -1)
SRC=""
for CAND in var/specialists/export-remote/Veri7vn_Specialists/Veri7vn_Specialists.Gate_Export/code/veri7vn_gate.ML \
            /Users/ember/dev/o7vn/var/gate/export/Veri7vn_Specialists.Gate_Export/code/veri7vn_gate.ML; do
  if [ -f "$CAND" ]; then SRC="$CAND"; break; fi
done
[ -n "$SRC" ] || { echo "no veri7vn_gate.ML export found; run remote-build first" >&2; exit 1; }
echo "export: $SRC"
mkdir -p var/dispatch/build var/dispatch/bin
cp "$SRC" var/dispatch/build/veri7vn_gate.sml
cp tools/dispatch/arb_driver.sml var/dispatch/build/arb_driver.sml
printf '%s\n' '$(SML_LIB)/basis/basis.mlb' veri7vn_gate.sml arb_driver.sml > var/dispatch/build/arb_check.mlb
"$MLTON" -output var/dispatch/bin/arb_check var/dispatch/build/arb_check.mlb
echo "compiled: var/dispatch/bin/arb_check"
shasum -a 256 "$SRC" var/dispatch/bin/arb_check
