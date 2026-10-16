# Native boundary regression

Run in the steward's slot:

```sh
python3 tools/dev/check-native
```

`Native_Boundary_Smoke.thy` checks:

| Assertion | Required property |
|---|---|
| `contract_transport` | Instantiated contract; no hidden assumptions/oracles/disagreement pairs. |
| `hidden_hypothesis_exposed` | Hypotheses remain visible despite zero subgoals/oracles. |
| `exported_premise_exposed` | Exported assumptions become premises. |
| `full_statement_preserved` | Preserve the implication, not merely its conclusion. |
| `descriptor_exports_resolved` | Resolve canonical C01 names and kinds. |
| `unresolved_export_rejected` | Reject missing constants. |
| `wrong_kind_rejected` | Reject constants offered as theorems. |

The false-arithmetic fixture proves only `2 + 2 = 5 ==> 2 + 2 = 5`.

All seven passed on Isabelle2026-RC1/macOS arm64; Core≈4s, tests≈3s. These are build observations. Current receipts/logs: `var/native-scaffold/`; [driver](../../tools/dev/README.md).

The driver generates native name data from `package.json`, recording hashes and testing name/kind mutations. Its file list covers editable sources, not dependencies or deployment closure. Native resolution retains actual objects; admission and executable refinement require separate gates. Use the driver to generate prerequisite data.
