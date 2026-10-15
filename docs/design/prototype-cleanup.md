# Retired early prototype

2026-10-15. At the user's request, removed the abandoned Python expression/DAG/C
prototype before continuing design of the Isabelle-native environment. This is
cleanup of a superseded implementation direction, not removal of the upstream
reference or a claim that the replacement platform is implemented.

Removed thirteen tracked files:

- `o7ir/{__init__.py,kernels.py,relations.py}`: manual arithmetic representation,
  C emission and relation-pattern lifting.
- `isabelle/{ROOT,Veri7vn_IR.thy,Veri7vn_Springs.thy}`: the old arithmetic/DAG
  session and generated certificates. The native source is under `src/isabelle/`.
- `generated/{springs.c,kernels.json,Veri7vn.Veri7vn_IR/code/checker.ML}`:
  outputs of that prototype.
- `tests/test_compilation.py`, `tools/build_kernels.py`, `tools/check.sh`:
  tests and runners coupled to those deleted implementations.
- `audit/results/relations-ir.json`: the generated `o7ir.relation-match.v1`
  artifact, not an upstream source/provenance record.

The files remain recoverable from Git commit
`9e4f619869a4a37eff09c25a0950d0113cc033c1` (also introduced in `81e1b31`).
For inspection without changing the working tree, use
`git show 9e4f619:o7ir/kernels.py`. No additional archive was created.

Preserved the native scaffold, schema and project tooling, release download and
audit scripts, Scry research client, upstream reference, source/provenance audit
records, and native research experiments. These Python utilities support research
and development; they are not the retired specialist runtime. No ignored build
state, caches, shared files, or other agents' work was removed.

Validation after deletion:

- No executable dependency on the removed prototype remains in `src/isabelle/`,
  `tools/dev/`, `tests/scaffold/`, or `schemas/`.
- Project ledger validates; all seven project-tool tests pass.
- All nineteen package-schema fixtures and the real native descriptor validate.
- Every source and generated-data hash in the last passing, stable native build
  receipt still matches. No new Isabelle build was needed for these deletions.

Historical references in the architecture/research narrative should be read as
references to the earlier experiment, recoverable from the commit above.
