# Native route state review, 31 October 2026

Reviewer: Codex architecture lane. Source/design review in progress; no builds,
tests, commits, specialist panel numbers or proof claims from this lane.

## Recommended boundary

Use one finite native conversation owner with typed delivered entity/quantity
anchors and explicit pure transitions. Providers propose deliveries; only the
final selected answer updates the owner through the existing core state/exact
HTTP transaction. `native-v1` should identify an admitted resource/semantic
contract, not introduce another journal or copy the host recovery machinery.

The owner itself can establish native lineage: create its explicit empty state
only from the candidate's private absent-base fact and retain it thereafter.
Unknown retained owner absence requires reset/migration, including native-only
legacy envelopes. Do not reinterpret `oracle=None` as empty Python state or
advertise Oracle adapter coverage. The existing Python owner envelope remains
independent. A separate persisted profile marker is unnecessary if the canonical
native owner already supplies this checked lineage.

Keep the existing dimensionless scalar v1 API compatible. Its admitted shape and
precision variants cannot silently become the new quantity conversation schema.
Share arithmetic primitives internally; an actual scalar-owner migration is a
separate explicit compatibility change. Prefer a canonical delivered-anchor owner
over adding a quantity cache and then another independent entity cache.

## Admission and transitions to review

- A caller's supplied observation is not an authenticated provider delivery.
  Bind delivered anchors to selected result, request/revision, admitted source,
  namespace and precision origin. Never infer entity identity from label text.
- Acknowledgements and semantic refusals preserve the previous anchor and its
  lineage. Topic reset affects only declared native fields. An unsupported
  request must not become implicit clearing or an Engine fallback. A successfully
  delivered new answer with no representable anchor is different: it must clear
  the previous antecedent so a later "that" cannot refer to a stale answer.
- Complete native image edge traversal may establish uniqueness in that image;
  it does not establish agreement with a different U8 store. Source rows and
  their scope must stay attached to the result.
- Exact HTTP replay, endpoint/input identity, retirement checks, conversation
  lease and commit comparison stay in the existing authority boundary. Native
  pure evaluation adds no opaque dispatch and must not inherit Engine poison
  merely by copying its execution path.

## Public preparation and readiness

The proposed full-Engine preparation patch is a separate consumer: explicit
load-only mode, source-bound public reader/clause artifacts, no private lessons
or session state, and readiness only after required synchronous preparation.
Trusted pickle remains executable input under protected operator custody.
Native finite routes must not acquire this Engine resource dependency.

## Remaining review

Review peers' concrete owner, delivery, host and preparation source overlays.
Root owns execution qualification and integration. This design recommendation
does not establish finite-route coverage, performance, or general Engine parity.

## Findings during implementation

- Native route bypass still admitted/hashed the configured Engine closure through
  `EnginePool::open`. My initial report incorrectly inferred worker startup from
  `start_all`; source inspection confirmed that method is a no-op. Root selected
  early rejection of native-v1 plus Engine configuration; reviewed that rejection
  before host hashing, journal creation and provider admission.
- Prepared-serving patched `oracle7.load`, but the worker's explicit `--tip`
  constructor path bypassed it. With the background loader suppressed, that path
  could announce readiness with absent organs. Requested synchronous preparation
  there too or rejection before readiness. Re-reviewed the fix: audited w574
  fixed-class preparation runs before constructor return, and worker tip/ready
  guards reject unsupported or unprepared paths before protocol readiness.
- The canonical entity anchor references the envelope's current singleton
  selection. The core owner author added envelope-level validation of this
  relationship, so it is not merely a host convention. Generic explicit graph
  selection changes still need a documented reconciliation policy distinct from
  preserving `/query` refusals; no new provider lineage may be inferred by it.
- Native command application initially cleared selection for every answered
  quantity anchor, including acknowledgement and inspect. A supplied quantity,
  explicit graph selection, then acknowledgement would lose that graph selection.
  Requested clearing only on successful quantity-producing mutations and explicit
  topic reset, preserving selection for acknowledgement/inspect. Re-reviewed the
  corrected command-kind condition and authored regression; source issue resolved.
- Host Count projection supplied an empty unit despite the new owner's explicit
  dimensionless `1` contract and cost parsing normalized unit case. Both were
  corrected and re-reviewed. My initial recommendation to preserve an unsupported
  typed reader delivery conflated refusal with an answered-but-unrepresentable
  result. Root caught the resulting stale-antecedent case; the final repair is
  under review below.

The preparation helper's source/data/Python/options identity, exact artifact pair,
load-only serving branches and protected executable-pickle scope have been read.
The final helper reads bounded bytes once, hashes those exact bytes, and passes
them to `pickle.loads`, under explicit immutable custody. No execution or
cold-start cost claim follows from that source review. Production host admission
of this prepared-mode artifact/environment is separate from the isolated source
patch and is not established by inherited environment variables.

## Source conclusion

The canonical native owner and host overlay have no unresolved blocking state
finding from this review. Initialization uses private captured absence; retained
owner absence never means empty, Oracle state is not imported, and envelope-level
validation enforces the singleton entity reference. Exact units, precision origin
and supplied/provider lineage remain explicit. Shared transaction/replay/lease
authority is retained; native-v1 rejects an Engine resource configuration early.

The public preparation overlay is source-approved for its isolated explicitly
selected U8 dependency-readiness contract. Execution qualification, actual image
closure, restart/replay behavior and resource costs remain central validation
work. No tests or builds were run by this reviewer.

Final core resource/overflow pass verified checked next revisions, restricted
budgets and pre-clone decode reservations, plus bounded bigint intermediate
growth/work reservations before multiplication. Reviewed frozen core hashes:
`native_conversation.rs`:
`c70e48dcfdf0b52089928fba06046e1eefd88a5de9fb1c9f0d56ebea4f0436ec`;
`runtime/native_conversation.rs`:
`78fa93c32b0037de39f30c2c54d9c5217a1de4ff1bb1e943bcb4b912abf06f42`.
The latter includes a final typed-plan input-byte limit and work charge before
validation/SQL, reviewed after the initial freeze.
Source signoff was sent directly to the central validator; awaiting execution is
not a source-review blocker.

## Fresh prepared-source derivation

Reviewed `derive.py`: nonstore files are copied and checked, only declared store
files are shared, the pinned patch targets the copies, the final inventory hashes
actual bytes, and every shared store entry must still equal the admitted baseline
entry. The fresh APPLIANCE receipt records parent/patch provenance. Publication
uses the existing exclusive atomic directory rename. No chmod targets a shared
store symlink. Store targets remain subject to immutable operator custody.

The final output traversal guard now rejects `..` before baseline reads or
temporary-directory creation. This closes the lexical-disjointness gap caused
by `Path.absolute()` retaining parent traversal. Re-reviewed derive SHA-256
`3e15040d0b6bf7beb43a1340a58c0ab7ba3c6348dc35a87bc76f0b42eb5b3a4c`.
Scoped source approval is clear independently of actual preparation/runtime
success; no tests or builds were run by this reviewer.

## Delivered answers without a native anchor

Root identified a concrete stale reference: energy in J, then an answered
temperature without an admitted unit projection, then "multiply that" would
scale the old J value. A delivered answer changes what the follow-up denotes even
when its value cannot be represented by the finite owner. Requested narrow fix:
after final answer arbitration, invalidate anchor and selection when no typed
delivery is possible, retaining the actual answer and exact reply transaction.
Use an explicit invalidation transition label. Refusal, unsupported requests and
acknowledgement still preserve prior state. This corrects the earlier review's
overbroad preservation recommendation; no new route or numeric cast is needed.

Source repair approved: `native_delivery` invokes existing `ResetTopic` only
inside the answered branch when no typed anchor was delivered. That transition
clears both anchor/delivery and selection in the same candidate; the original
answer remains the final HTTP reply with `cleared_unrepresentable_answer`.
Refusals bypass this mutation, and acknowledgement uses its preserving fallback.
The authored regressions exercise a real reader temperature answer and a numeric
provider answer without a unit after an energy anchor; each requires the next
multiply to withhold with an empty anchor. No tests were run by this reviewer.
Reviewed service SHA-256:
`ac4aeece25d775f88b6dc0e8f746f8f3e7cbddace3a8cf365d7a75c5b4ae5521`;
host test SHA-256:
`73e306c358420bc5d67bf79f0cbe810b2f130b572053ac5650d2ea4089c8be31`.

## Query cursor for the next invocation

Source-approved native-v1 query cursor addition: every successful query body gets
outer `conversation_version` from checked candidate base revision plus one,
before bounded encoding and the same atomic state/reply commit. This covers
reader, organ and fallback replies. Existing completion/replay paths return the
original bytes and original version; failures do not manufacture a committed
turn. The authored regression uses a returned entity-query version for a stateful
quantity invocation, then checks a later acknowledgement, the exact old query
replay and a current inspection. No new state authority or readonly-v1 behavior.
Reviewed service `c193245439e89196a6cdadd5f4bb18024740801f56d4f4c200c05ddedd3b1caa`
and tests `cf829debacbade3d6907c1b7cf0bb043280f123be8159c0d33337be8db64bf50`.
No tests or builds run by this reviewer.

Final narrow source pass against `cb95203`: the two numeric/cost regexes now use
process-wide `OnceLock<Regex>` initialization. Pattern bytes, capture indices,
number normalization, case-sensitive `J`/`kWh` units and dispatch behavior are
unchanged; only repeated compilation is removed. The other service diff is the
already reviewed outer query cursor. Final service SHA-256 verified:
`04e8154daa373f67b4f8a6046600b9df85566d19baa34d702d18b69643618b7a`.
Source approved and held; no builds or tests run by this reviewer.
