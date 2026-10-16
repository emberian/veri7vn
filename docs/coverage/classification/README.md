# Reviewed source disposition

`audit/coverage/decisions.json` retains all **305 `not_lifted` manifests**, operations and per-operation roles. All 119 formerly unclassified domains now have [semantic profiles](domain-profiles.json), including laws, repairs and task owners. `denominator.json` retains 1,757 Python paths and 3,608 Git entries; no file is excluded as dead. Missing payloads remain in `audit/results/availability.json`.

## Reproduce

- `python3 tools/audit/reachability/classify.py`: reviewed manifest partition.
- `python3 tools/audit/reachability/check.py`: hashes, operation denominator, tasks and chain membership.
- `python3 tools/audit/reachability/runtime.py`: pinned HEAD list without runtime import.
- `python3 tools/audit/reachability/dispatch.py`: actual C3 and virtual/super/explicit-base calls; [review](runtime-review.md).
- `python3 tools/audit/reachability/profile_closure.py`: 293-file local inherited/helper closure.
- `python3 tools/audit/reachability/source_roles.py`: exact source/tracked partition in `source-roles.json`; [residuals](residual-matrix.md).

Equal code does not establish equal stores, configuration, interpretation or dispatch. Conditional activation and nonlocal/dynamic dependencies require consumer checks.

| Actual boundary | Required preservation/repair |
|---|---|
| `oracle7.py` → serialized Runtime chat | Queue, cancellation, state scope |
| w525 parent → narrowing → family → network | Preserve `_c525_lacks` blockers through dependency failure |
| `combo_runtime_v1._Organ` manifest loading/environment isolation | Preserve typed values; prequalify signature instead of retrying internal TypeError |
| `network_v3.solve` typed pool/dedup/shallow plans | Boolean/value/guard equivalence, conflicting plans, budgets |
| Bounded SQL connection/authorizer/progress/fetch SHOW+1 | Engine observation plus owned observer: errors, NULL/order/prefix/configuration |
| FormatsOrgan normalization | Literal bytes survive payload extraction |
| Workbench loading/exams/transfer | Candidate execution, external effects, learning and source lifetime |

D28 assigns roles **per operation**: observing SQL does not waive observer correctness; source reports still require readers and coverage/uniqueness; Python arithmetic remains an owned algorithm. Site observations, state transitions, proposals and external actions remain distinct.

G01/G03 map to admission/operational model; G02 to interpretation/domain codecs; G04 to routing/arbitration; G05 to exposure/qualification; G06 to event clocks; G07 to expiry/reconnect; G08 to author repair. Executed cases: `docs/coverage/known-defects.md` and [workbench audit](../../workbench/audit/README.md), with source pins and corrected import/exposure evidence in `audit/workbench/source-locations.json` and `transfer-regression.json`.

D16 public publication and D17 corpus replacement remain scoped decisions. D18 siblings remain investigations. Local Film/code artifacts and all three synthesis mechanisms remain core candidate workflows. Classification supplies ownership; native refinement and deployment still require family/integration evidence.
