# Reviewed disposition boundary

`audit/coverage/decisions.json` retains every one of 305 manifest records, exact
operations, per-operation roles and source-profile links. Every record remains
`not_lifted`. Reproduce with `python3 tools/audit/reachability/classify.py`.
All 119 previously unclassified domain entries now link to source-reviewed
[semantic migration profiles](domain-profiles.json), with operation laws, roles,
existing repairs to preserve, new repair obligations and owner task IDs. Parent
helpers and deployment/refinement remain explicit closure obligations; this does
not establish any completed native lift.
Validate pinned manifest hashes, exact operation denominator, task references and
chain membership with `python3 tools/audit/reachability/check.py`.
`denominator.json` retains all 1,757 Python entries and the 3,608 tracked-file
count. No file has been excluded as dead code. Missing materialized data remains
`audit/results/availability.json`; no replacement corpus identity is invented.

`python3 tools/audit/reachability/runtime.py` follows the pinned HEAD chain list
without importing the runtime. The
resulting `runtime-chain.json` records HEAD membership. Actual imported C3
class order and virtual/super/explicit-base calls are resolved separately by
`python3 tools/audit/reachability/dispatch.py`; see
[runtime review](runtime-review.md) and `dispatch.json`. Conditional activation and dynamic/helper closure remain explicit open work. The list is evidence to inspect,
not an automatic exclusion or claim of full 317-fold semantic review.

| Surface | Inspected actual route / transition | Failure / migration obligation |
|---|---|---|
| CLI / HTTP | oracle7.py loads HEAD tip; serialized Runtime chat forwards to runtime | Queue/cancellation/state scope require runtime-service/routing-dialogue |
| Core specialist fallback | w525.chat invokes super().chat first; narrowing may suppress prior answer, family reply then network_v3.solve | deliberate validity refusals protected by `_c525_lacks`; exceptions preserve parent result; scoped refusal needs G04 operational review |
| Specialist call | combo_runtime_v1._Organ loads manifest class, isolates env, answer(text,session), TypeError retries answer(text) | Exceptions become silence; manifest kind/decline rules apply; structured value dropped. Preserve source observations, repair lost typed data and failure scope |
| Network composition | network_v3.solve expands typed pool, deduplicates, finishes shallowest plans | Boolean presence and rounded values insufficient equivalence; retain disagreement, budgets and original role constraints; plan-composition |
| SQL | fresh _conn with authorizer/progress/size bounds, setup then SELECT, fetch SHOW+1, close | Engine observation + owned observer algorithm; exact errors/NULL/order/prefix and configuration; source-semantics/domain-families |
| Hash/encoding | FormatsOrgan.answer normalizes all text before payload extraction | Owned deterministic algorithm; preserve operation, repair byte corruption; interpretation-model/domain-families |
| Workbench | separate `audit/workbench` fixture/route evidence | Candidate workflows plus external acquisition/action; package-lifecycle/stateful-connectors |

D28 requires roles per operation: SQL observations do not waive correctness of
the observer; relation/fact source reports do not waive owned readers, coverage,
absence or uniqueness. Numeric algorithms never become external observations
merely because they call Python. Site operations retain observations, owned state
transitions, candidate proposals and external actions separately. Mixed entries retain the laws and model assumptions in their semantic profiles;
imported-helper closure and actual native assurance bridges remain open.

G01/G03 candidate and lifecycle cases belong to native-admission/operational-model;
G02 literal/codec/profile cases to interpretation-model/domain-families;
G04 scoped refusal/arbitration to routing-dialogue/operational-model;
G05 exposure/requalification to package-lifecycle/synthesis-growth;
G06 repeated MQTT source event to source-semantics/stateful-connectors;
G07 cached expiry/reconnect to runtime-service/state-effects;
G08 author workflow impact/repair to workspace-interaction/diagnostics-repair.
Concrete executed cases are in ../known-defects.md and audit/workbench; source
reports retain proposed graph optimum, probability/model, calendar/affine/log/frame
and guarded-boundary obligations. None is declared covered by shared class name.

Six siblings remain contract stress investigations under D18. Their algorithms
are not silently included or excluded from core migration. Film local artifacts,
author code experimentation and all three synthesis routes stay core candidate
workflows; public registry/chain publication stays D16, missing corpus D17.

Workbench workflow dispositions and source pins are in
[the independent workflow audit](../../workbench/audit/README.md),
`audit/workbench/source-locations.json` and `transfer-regression.json`.
That audit has eleven executed local checks; its import rejection correction
supersedes the earlier source-only repeated-holdout claim.

Local inherited/helper source closure is reproduced by
`python3 tools/audit/reachability/profile_closure.py`: 293 local source files,
with shared policy and byte-identical source-text review links. Equal code does
not establish equivalent stores, configuration, interpretation or dispatch.
Nonlocal/dynamic dependencies and materialized-source qualification remain open.
The real manifest wrapper is exercised locally in the regression suite; domain
declines survive, successful values lose type data, and internal TypeError can
retry an already-started mock action.

The final [source-family and lifecycle residual matrix](residual-matrix.md)
accounts for every source/tracked entry and materialized pack, resolves dynamic
loaders/feedback/background ownership, and distinguishes all three synthesis
mechanisms. `source-roles.json` is the exact compact partition and call-site
catalog; no exclusions or native coverage promotions follow from it.
