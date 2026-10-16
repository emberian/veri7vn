# Contextual routing and dialogue

`src/isabelle/language/runtime/Veri7vn_Dialogue.thy` is the native policy model.
It consumes the existing interpretation, request, subgoal, blocker, binding,
selection, session delta and renderer types. It introduces a versioned capability
precedence policy, not a new registry or claim carrier.

Interpretation selection precedes capability precedence. All eligible readings
survive in `dialogue_clarification`; an explicit selection receipt must contain
exactly those alternatives and name one of them. The receipt records a policy
decision, not a proof of human intent. `dialogue_select` rejects a mismatched
policy version. Among routes for the selected interpretation and exact
`same_requirement`, it retains every equally preferred route. This is a conservative
policy relation over existing metadata, not a native proof that two independently
elaborated operations answer the same question. Independently allocated target and
support identities can differ even for equivalent native predicates. Capability
precedence must therefore follow native comparison of the exact predicate, scope,
assumptions and pins, or an approved native conversion witness. Without that
association, alternatives remain distinct interpretations. A higher priority does
not establish a claim, resolve contradictory candidates or discharge a blocker.

`addressed_capabilities` distinguishes unaddressed routing (`None`) from an
explicit source restriction (`Some allowed`). `Some []` records an explicitly
addressed but unavailable source and permits no fallback. The source/addressing
refusal must remain visible to the caller; an empty allowed set cannot be changed
to general routing. There is no resident consumer of this policy record yet; the
actual `math/1` inspection is a separate fixed singleton route.
It is installed native policy data, not authority granted by client scores.
An unavailable addressed personal source does not become permission to answer
from a dictionary or an unrelated numeric source. A scoped veto is checked through
the existing `unblocked` judgment for every capability. A different justified
interpretation remains possible through an explicit selection decision.

`dialogue_current_select` looks up requests in the actual authority state and
checks freshness. Both direct and current selectors require shared parent accessibility,
including the parent request ID, as well as child accessibility. Its selected routes require `goal_ready_live`, so dependent
multipart goals consume current accepted structured predecessor bindings. The
runtime must retain per-part outcomes and dependency edges through `render_parts`;
one successful part does not make an incomplete turn complete.

`dialogue_adoption` produces the existing `StageAdoption` event only when
`adoption_permitted` holds. The single durable authority writer still stages and
acknowledges this event. A formerly accepted binding invalidated by an outer guard,
retirement, revocation or cancellation cannot seed a follow-up. Recording an
utterance remains independent of adopting an answer. The renderer continues to
require the exact claim kind, modality, premises, collection coverage,
dependencies and generations; this layer does not strip source qualifiers.

## Source grounding

The inspected upstream runtime is the actual C3 chain recorded in
`docs/coverage/classification/runtime-chain.json` and `runtime-review.md`.
Direct source reads motivating this implementation:

- `oracle_release_runtime_w530.py:112–163`: positive named-body precedence and
  replacement of designated weak relation answers; no universal core-first rule.
- `oracle_release_runtime_w529.py:65–114`: unresolved pronouns require
  clarification; dependent parts share context, but update it before final guards.
- `oracle_release_runtime_w540.py:60–80`: final direction, number-readback and
  personal-question guards can withhold an inner answer after that earlier update.

The policy deliberately preserves dependent structured context while repairing
that premature adoption. It does not reproduce response-string entity parsing.
Finite source coverage remains a claim about the registered snapshot/recipe, not
global world truth. Source declaration/reader revisions and aliases stay owned by
the existing relation-language gate.

`tests/regressions/test_workbench_lifecycle.py` reproduces the upstream ordering
defect where pronoun dispatch consults an expired reader before filtering its
lease. That test is evidence of the original defect, not a repaired native source
follow-up. The future source conversation path must check lease/expiry before
resolving a referent and recheck current authority before adopting or emitting its
result. The mathematics inspection-handle timeout does not satisfy that source
session obligation.

The source expiry default belongs to a temporary recall reader, not to every
conversation. In `upstream/workbench/server.py:987–1006`, saving a conversation as
a specialist defaults to seven days, bounds the requested duration to 1–365 days,
and writes a wall-clock `expires` value into that reader's manifest. Ordinary
conversation storage (`server.py:67–110`) defaults to retention enabled and has no
TTL. `chat_context_v2.py:36–60` has a 2,000-session capacity bound, not timed
expiry. `ConversationOrgan` (`sources.py:363–412`) recalls answered, non-workbench
turns only for explicit recall questions and quotes their original date and route.
A native reader lease needs its own clock/deadline observation and current access
checks; explicit session expiry does not implement that original default. A new
global conversation deadline would be an additional policy, not source preservation.

## Resident integration contract under review

No new source/domain callback registry is authorized. D46 fixed constructors must
join the same reservation, execution, result and recovery pipeline. The first
bounded inspection proposal is `inspect_routing` with payload `math/1` and one
artifact containing the original UTF-8 bytes, at most 256 bytes. The response is
`routing`, one of `readings`, `literal`, `budget`, `unrecognized`, `structure_blocked`, and an ASCII
comma-separated list of alternative indexes (0–255) only for `readings`.
Inspection allocates no request or execution authority. The client keeps the
original bytes and submits the selected index with the same bytes to the existing
fixed mathematics proposal; native elaboration rechecks the reader.

The RPC producer is present in the resident source and has passed the actual
resident/browser check described below. Installed-package qualification is separate.
Source inspection additionally needs the protected source binding and authored
reader declaration references, which the source owner/assembly must expose through
D46 before a client can route them. The source gate's internal `inspect` is not a
public resident operation. Do not manufacture a source route using user labels.

Generated policy functions must be loaded in the existing metadata frame's single
code-antiquotation block to share the authority carrier. Loading an independent
generated universe and copying request records is not the runtime bridge. The
resident assembly must provide current state internally; client checkpoints cannot
be passed off as the authoritative state. These hooks and the installed policy
provenance still need assembly review and actual host/workbench checks.

## Validation status

`Veri7vn_Dialogue_Tests` contains concrete regressions for positive precedence,
addressed-source fallback, per-interpretation veto across capabilities, stale
selection, changed targets, ambiguity surviving priority, stale alternatives,
dependent live inputs and withheld follow-up adoption. Initial native attempt
`db3d52e2469c40fc95bfee9c34a33a4b` rebuilt Interpretation successfully and stopped
at the dialogue ambiguity proof: the reused lemma stated the length of the input
alternatives, while the conclusion stated the equal retained alternatives. The
proof now explicitly substitutes that equality; the policy and statement are
unchanged. Attempt `45e83685656e461c8d17329e6fef82dc` passed and saved the
Dialogue model in seven seconds, then found an unquoted `subgoal` keyword in the
test leaf. That syntax was repaired before the coordinated D43 migration. The v1 model
pass does not establish the test leaf or resident consumer. Current D43 migration
uses the shared `same_requirement`, typed dependencies and per-goal generations;
ClaimRequirement retains `same_target`, while candidate ArtifactReady remains
nonassertional. It requires a fresh check after shared parents converge.

The first current numeric/D43 attempt,
`b80883b38f884d20b1e20b1e87fb532d`, saved Metadata, Events and Authority, then
stopped in the Rendering ancestor at line 167: a remaining `render_claim` call
received the new `goal_requirement` sum. Dialogue and its 16-lemma test leaf were
not reached. The rendering owner is repairing the typed claim/artifact projection;
this result is not a dialogue policy pass or counterexample.
The next leaf also includes direct goal-ID and output-slot denial cases with
noncolliding child identities: forgetting the preferred child or slot must leave
its unrelated sibling eligible. These additions bring the pending leaf to 18
lemmas and await the same repaired parent check.
The model before the latest shared-parent guard alignment passed in
`43167957fc6646ac8fb9286403bb415e`.
Leaf retries corrected record declaration order and explicit finite-list proof
normalization. Attempt `eddf9d38f8fe4ef8aef371b4f2527706` then refuted the two new
lifecycle fixtures: changing only `forgotten_objects` creates no denial, because
actual `Forget` also updates revocation and cancels affected goals. Those fixtures
now execute the real `step` transition on a state containing the original parent,
then select from the updated request through `dialogue_current_select`. The receipt
is derived from the original independent plan's readings; the stale-alternative
negative remains. The authority predicate was not weakened. The corrected leaf
awaits the next stable parent check after the coordinated shared migration.
The policy now reuses the existing D56 `parent_accessible` helper rather than
checking only parent dependencies. A nineteenth regression executes `Forget` on
the parent and rejects both current lookup and a stale direct request object.
The actual child/slot sibling-survival cases remain. These new model bytes need
the fresh check; the earlier saved model is historical evidence.

The actual `inspect_routing` producer, resident parser and workbench adapter passed
the real browser consumer in attempt `ccf79120fc7744b196fd268d69548f32`. The test
posts a product question through the native route and obtains licensed HTML, then
confirms Forget. That attempt qualified the then-current `DialogueClient.scala`. The subsequent
conversation-aware overload and host facade are source drafts awaiting fresh
compilation and the native session operations; the archived browser pass does not qualify those new bytes.
The conversation-aware inspection overload retains only the expected native
session ID/version with the exact pending original bytes. Selection calls the
fixed conversation mathematics facade; the native owner must check current session
accessibility, observation and final arbitration. `discardConversation` erases
pending inputs when the UI expires or forgets that conversation. No transcript,
claims or adopted-state cache is added to this client. Context-free `math/1`
inspection does not resolve pronouns. Host/native execution and UI adoption of
this overload remain unqualified.

This evidence covers the fixed mathematics path, not source/domain or multipart
routing. `tests/language/runtime/resident.scala` is the separate stronger
real-service harness, still queued. Independent requests
are not a dependent multipart request: the current math request owner allocates
one request/goal/slot per question. A native composite reservation with same-request
licensed intermediate bindings remains necessary for multipart conversation
adoption. Existing authority and rendering theorems remain the assurance path for
licensing and adopted state.

## Composite request integration needs

The joint native identity review must preserve these consumer requirements:

Route alternatives are bounded proposals, not required request children. Native
selection chooses one actual material for each requested goal before the parent is
sealed and reserved. Losing proposals release their resources; they must not leave
`NeedsInput` parts in the reserved request. The selected operation retains its full
support dependencies. `dialogue_current_select` inspects existing current children;
it does not implement this pre-reservation proposal-to-material association.

The fixed native adapter `native_math_routing.ML` compares two actual reader
indexes on the same live, unclaimed protected child in one admitted mathematics
instance. It certifies the full parameterized predicate in the actual contract
generation and compares native terms; it allocates no family material or request
identity. Only the selected index is then elaborated and claims that child. The
focused native fixture checks that comparison leaves the child unclaimed, rejects
an invalid index and post-claim comparison, and seals exactly one selected child.
The service now loads this adapter, and scoped mathematics elaboration calls it
before claiming a child when a reader offers several indexes and no selection.
It constructs one material only if all actual predicates agree; otherwise it
returns `NeedsSelection`. The current authored arithmetic rules expose no known
real multiple-equivalent-reading fixture, so the focused test exercises the
actual singleton no-selection path rather than manufacturing alternatives. These
changes await the coordinated native check. They provide no
cross-family conversion, independent source equivalence or current-authority
permission; the actual coordinator and generated owner retain those checks.

- One opaque parent scope owns the original input, workspace, installed policy
  version, environment and explicit session/time observation. Operation-specific
  elaboration receives that scope and an exact original span or declared structured
  input; callers do not supply arbitrary request/goal/slot identities.
- Each opaque child carries its minted parent request ID, goal ID, output slot,
  selected interpretation, exact requirement, typed dependencies and existing
  prepared family operation. Sealing the parent checks unique goals/slots and
  topological references under the same parent before one composite reservation.
- Dependent inputs come from a current licensed native output association through
  an admitted typed adapter. The mathematics `Parameter` carrier and existing plan
  input environment are available seams; printed numbers and rendered sentences
  are not input associations.
- Each child retains its outcome, conditions, provenance and dependency edges.
  Final whole-turn guards precede adoption. A blocked child prevents dependent
  adoption while unrelated children can retain explicitly partial results.
- Recovery reconstructs the parent DAG, child family/operation/slot associations,
  original spans and pinned selection decisions, checks current authority and
  restores historical status without executing old questions.

The native source now makes that identity migration: interpreted-request lifetime
comparison uses workspace/request/goal/slot, and the resident mathematics map uses
request/goal/slot keys. Scoped requests independently retain their child view, so
releasing producer child/parent handles does not retire the selected consumer.
These source changes still need their actual current-service checks. Identity and
lifetime support alone do not implement dependent multipart execution: the closed
mathematics constructor still rejects predecessor children, and typed intermediate
consumption plus one composite reservation/recovery/final arbitration remain
required. Rewriting committed snapshots or grouping independent UI requests
cannot supply those missing associations.

## Source graph display integration

`runtime/graph/Graph_Rendering.thy` consumes the actual `Graph_Source` replies.
Its typed projection retains exact original edge records, signed integer costs,
cuts, explicit enumeration depth, stop reasons and weighted edge-to-raw-row lineage.
An assertable source result has a mandatory imported-snapshot constructor and
the existing complete claim clauses. Compatibility requires `SourceObservation`
and the exact feasibility/optimality and collection scope of that reply. Complete
path enumeration is explicitly bounded by the displayed depth and pinned graph;
it is not a statement about all paths without a depth bound.

The outer `GraphSnapshotAnswer` means the source schema decoded. Inner exhausted,
malformed, rejected-certificate, direction and materialization outcomes are
`DisplayImportedDiagnostic`, which has no claim header. Schema, incomplete-source,
unsupported-operation and request-resource failures also remain diagnostics.
Neither a failed search nor a frame-size failure establishes unreachable vertices.

The pure projection preserves the existing typed `native_source_manifest`
internally. That is not permission to publish the full protected manifest. The
source owner's observer-free association and fixed `Source_Graph_Observer` leaf
must tie the exact worker reply, actual source context, claim specialization and
permitted exposure policy before native output serialization. No actual graph
resident producer or Scala frame is claimed yet. The acquisition composition lemma
is explicitly `/1`; the real `/1` or `/2` leaf must consume the common typed
association meaning rather than relabeling the compact decoder theorem. The new
optional `Associated_Graph_Rendering` child now consumes the canonical
`run_associated_graph_query` and `source_association_meaning`. Its theorem retains
the whole associated graph meaning, exact private manifest, independent versioned
original-byte representation and the same attached observation through rendering.
It introduces no additional evaluator or source carrier. This composition still
awaits native compilation and its fixed observer consumer; it licenses no supplied
claim header.

Graph display fixtures exercise the actual structured query with a signed edge
cost of -3 and edge ID 7/raw row ordinal 2, bounded relation paths and an actual
expansion stop. Native checks await the graph/source and D43 parent convergence.
The future closed serializer must bound encoded bytes before allocation, using an
edge catalog with witness references when useful. A bound on path count alone
does not bound total repeated edge records or large identifier encodings.

The renderer now separates the light path proof from optional general graph
soundness. Light execution theorems require the explicit
`source_graph_path_request` classifier and use the sole `Graph_Dispatch`
evaluator. The original general theorems, including minimum-tree results, remain
in `Graph_Rendering_Soundness` and `Associated_Graph_Rendering_Soundness` with
the heavy graph proof dependency. This changes the proof closure, not the
evaluator or result vocabulary. A light native observer must check the path
classifier before licensing a graph answer; available datatype constructors are
not permission to claim the unimported general theorem.
