# Native boundary regression

Run `python3 tools/dev/check-native` from the repository root. The driver includes
the implementation and test session roots, limits resources, and checks the
assertion messages retained in Isabelle's build database.

`Native_Boundary_Smoke.thy` exercises seven conditions:

| Assertion | Regression caught |
|---|---|
| `contract_transport` | Local definition/contract fails to instantiate, or unexpectedly retains assumptions, oracle dependencies, or disagreement pairs. |
| `hidden_hypothesis_exposed` | A theorem with zero subgoals and zero oracles is incorrectly treated as having no assumptions. |
| `exported_premise_exposed` | Exported context assumptions disappear from diagnostics instead of becoming explicit premises. |
| `full_statement_preserved` | An implication's conclusion is substituted for its complete statement. |
| `descriptor_exports_resolved` | The real C01 fixture declares an unavailable native context, constant, or theorem; canonical names and object kinds are checked. |
| `unresolved_export_rejected` | A missing specification constant is incorrectly resolved. |
| `wrong_kind_rejected` | A constant is incorrectly accepted as a contract theorem. |

The deliberately false arithmetic statement is used only as a hypothesis; the
exported theorem is `2 + 2 = 5 ==> 2 + 2 = 5`. Nothing proves false arithmetic.

Initial execution on 2026-10-15 with Isabelle2026-RC1, macOS arm64, passed all four
initial assertions; the real package integration then passed all seven.
Core and test sessions took approximately four and three seconds;
these small build observations are not application performance measurements.
Current, machine-readable receipts and full output are in ignored
`var/native-scaffold/`. See `tools/dev/README.md` for isolation and toolchain limits.

`package.json` is a real C01 descriptor of this test fixture. The driver derives
the ML name data from it on every check, so descriptor edits affect native
resolution without maintaining a second hand-written list. Native resolution
retains actual constant/type or theorem objects. The test includes mutations
of the descriptor-derived name and kind to check rejection. The descriptor's
files list covers local editable source; `Veri7vn_Core`, the generator, generated
ML data and HOL are build dependencies recorded separately, not a standalone
package closure. A direct `isabelle build` needs the generated data first; use
the driver.

This integration regression is intentionally separate from the existing
arithmetic/C-emitter experiments. It provides no completed admission policy,
general package loader, execution-refinement theorem, or deployment image.
Successful schema validation and native resolution do not grant C02 admission
authority or establish an executable refinement relation.
