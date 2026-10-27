# Executable claim boundaries

Run `python3 -B tools/usage/neurosymbolic-literature/test_claim_boundaries.py`.
These five tiny tests distinguish useful readouts, causal control, program
typing, unknown evidence and source-backed facts. The representation and decoder
are hand-written. There is no real neural model, learned embedding, causal
discovery, Oracle call or specialist panel score here.

The first test recovers a hidden quantity from 49 synthetic states while the
base decoder does not use that quantity: all 2,401 aligned quantity swaps leave
the base output unchanged. This is deliberate. A readout can implement a useful
function without explaining what the base decoder computes. A second example
shows that perfect observational prediction need not support a claimed causal
alignment. A valid typed request can still choose the wrong English relation.

The research proposal is in
`project/lanes/LITERATURE-NEUROSYMBOLIC-2026-10-27.md`.
