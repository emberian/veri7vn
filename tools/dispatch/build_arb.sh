#!/bin/sh
# Build var/dispatch/bin/arb_check: the MLton compile of lane C's exported
# arbitration (Veri7vn_Gate, from src/isabelle/specialists, session
# Veri7vn_Specialists) plus tools/dispatch/arb_driver.sml.
#
# Native compilation freezes inputs and validates a matching managed proof.
# PROOF_RECEIPT selects an explicit successful receipt. ARB_OUTPUT may
# select a candidate path without replacing the active dispatcher binary.
# The export is looked for in this worktree first (var/specialists/export-remote/,
# filled by tools/dev/remote-build), then in the main checkout's
# var/gate/export/ (lane C's build of the same committed sources).
set -eu
cd "$(dirname "$0")/../.."
: "${PROOF_RECEIPT:?set PROOF_RECEIPT to the successful managed Specialists receipt}"
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
printf '%s\n' '$(SML_LIB)/basis/basis.mlb' veri7vn_gate.sml "$PWD/tools/dispatch/arb_driver.sml" > var/dispatch/build/arb_check.mlb
set -- tools/dev/native-compile --family arbitration --session Veri7vn_Specialists --compiler "$MLTON" --from-receipt "$PROOF_RECEIPT"
OUT=${ARB_OUTPUT:-var/dispatch/bin/arb_check}
python3 "$@" -- -output "$OUT" var/dispatch/build/arb_check.mlb
echo "compiled: $OUT"
shasum -a 256 "$SRC" "$OUT"
