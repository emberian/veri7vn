# Coherent state review, 31 October 2026

Central execution after this source review is recorded in the
[coherent checkpoint](COHERENT-NATIVE-2026-10-31.md) and its receipt.

Reviewer: Codex architecture lane. This is a source review, not an
execution receipt. No builds or tests run by this lane; no specialist panel
numbers or new proof claims.

## Review gates

The core session and exact HTTP response must have one atomic commit. Host
dispatch records cannot override a core completion after a crash or lost commit
acknowledgement. Both endpoints must share conversation admission through actual
execution cleanup, including work continuing after its HTTP receiver times out.
Request identity must distinguish endpoint, operation, release and input while
remaining stable when a retry observes a later session revision. Legacy identity
collisions must refuse rather than adopt an old reply under a new format.

The Engine profile must use actual pinned materialized sources and admit a safe
call before execution. Enumerating exported owners does not make arbitrary
`Engine.chat` read-only. The materialized candidate-u8 reconciliation explicitly
borrows module context in `begin` and restores it in `release`; this implementation
and its enclosing cleanup are part of the required source coverage. An existing
session with `oracle=None` means unknown coverage, not an empty Engine session.

## Findings sent to owners

- Core owner candidate execution initially omitted operation admission while
  checking owner registration/schema. Requested `require_operation(T::OPERATION)`
  as in the existing transactional path. Author added this check.
- Candidate reader application drops the proposal reservation when transferring
  selection. The candidate reserves a bounded envelope allowance, but acceptance
  must also bound its retained deltas and keep sufficient memory custody through
  commit. Graph, language and owner candidate paths need the same accounting.
  Author added candidate size checks before transferring retained deltas and
  retained the candidate's envelope reservation.
- Engine restore initially interprets every absent Oracle payload as empty.
  Requested explicit new-session initialization distinct from unsupported existing
  coverage. Capture after arbitrary execution cannot repair an unsafe dispatch.
- Host acknowledgement initially cleared conversation poison on every successful
  replay. Counterexample: A commits, B dispatches and fails, replay A clears B's
  poison. Requested poison ownership tied to the dispatch request, including
  acknowledgement recovery; a conversation lease alone does not fix this.
  Re-reviewed the fix: dispatch records `poisoned_by`, and acknowledgement,
  finish and forget clear only that request's poison. Source finding resolved.
- Host projected a dimensioned numerical winner into both context.result and
  the unitless scalar cache, which the adapter rejects. Requested unitless-only
  scalar projection and an explicit refusal projection handshake. Dimensioned
  scalar projection was fixed; origin now requires an explicit producer tag.
- The pinned w29 tokenizer discards unmatched punctuation with `re.findall`;
  `2 + 2%` becomes `2 + 2`. Its successful parse is not sufficient whole-surface
  admission. Requested lexical coverage before the adapter's arithmetic call.
  Its direct class method also calls virtual methods on the runtime, requiring
  method-owner verification or a restricted facade for the claimed route boundary.
  Re-reviewed the whole-surface lexical guard and the restricted pinned-method
  facade; both source findings are resolved.

## Checked evidence boundary

The proposed checked-owner path may skip selected-owner domain validation only
when registered schema/authenticated binding checks still run and the selected
owner is immediately restored with inherited control. Other retained owners keep
their validation. The resulting typed Workspace and reservations travel together;
command JSON cannot supply a checked handle. A default wrapper around legacy
validation must not claim to interrupt work inside that legacy validator.

Reviewed the implemented checked-read path: scope comes from authenticated
binding, other extensions retain validation, and the host holds the snapshot
through checkpoint/solve and response encoding. No blocking source issue found.
Mutation still repeats controlled restoration/validation; restore-once applies
to the checked read and its consumers, not all mutation work.

## Numerical evidence consumer

Reviewed `tools/usage/thermal_revision.py` and its README after clarification.
The explicit package supplies values, W/W-K units, targets and source labels;
skeptical evidence atoms select package records. The evidence engine does not
authenticate those numbers or source labels. Missing/conflicting supports withhold;
alternative equal supports survive individual withdrawal. The result binds the
evidence receipt, complete package, adapted model and numerical network identity.
Each calculation prepares a fresh network. No blocking source issue found for
this stated supplied-model scope; execution checks remain with its owner/root.

## Remaining review

Final core source reviewed: exact private base comparison, bound envelope limits,
registered native owner validation, Oracle owner release schemas, revision-stable
query replay identity, namespace retirement and owner operation admission are
present. The direct reader-options API and covered host HTTP API currently have
distinct identities. The author subsequently added an explicit output-contract
digest domain for inner language results versus final HTTP responses.

The final reviewed Engine adapter uses direct admitted arithmetic, supplied
physics, fixed relation questions, acknowledgements and cost calculations; it
does not call arbitrary `Engine.chat`. Host/adapter capture scope and explicit
refusal-preservation handshake now agree. Source approval applies to those
bounded routes, not the whole legacy Engine. The pinned materialization is
candidate-u8; missing reconciliation or mismatched source coverage refuses.

Remaining acceptance gates are execution, actual provider projection support,
restart/replay and explicit per-owner transition documentation. In particular,
unmarked numerical origins are unsupported, entity projection requires the
operator's namespace declaration, and the adapter clears arithmetic pending
conversion state rather than preserving every upstream transition. Root owns
execution checks and integration. No execution success is inferred from this
source review.

## Root integration review

Reviewed the explicit manifest profile/namespace additions, CLI forwarding and
helper packaging. The default manifest remains unchanged in scope; readonly-v1
adds only its finite owner schemas, and Wikidata mapping adds a separate schema
marker required by `enable_conversation`. These declarations affect release
identity. The helper is independently hashed and packaged beside the worker.

The narrow helper-loading blocker is resolved. The worker now loads its resolved
`conversation_adapter.py` sibling with `spec_from_file_location` under a private
module name and retains that explicit module. Public import-cache entries and
Engine search-path changes cannot select another helper. Reviewed the added
fixture covering both shadows and subsequent cached reuse; did not execute it.
Reviewed worker SHA-256:
`468813898cf2f33c64d6fcff74b283847d9510dd0a1148725e55f217127eebdd`.
Reviewed adapter-test SHA-256:
`ea1aceb98417f6c45956c469b33966b9ff324fa687bb9cf211ae4cc868575ec1`.

Final source conclusion for the reviewed implementation: earlier source findings
are resolved. Approval retains the route, provenance and execution-evidence limits
above, with the native-first entry gap below identified during final integration.

## Native-first entry follow-up

A first covered `/invoke` currently creates a native-only envelope. A later
`/query` requiring the adapter refuses because revision is positive but Oracle
coverage is absent. This is a missing coherent entry path: a newly created
covered session had no prior Engine history, but its retained coverage does not
distinguish that fact from unknown legacy state. Do not weaken the restore guard.

Recommended narrow fix when Engine is configured: for a genuinely absent base
session, obtain an admitted adapter preserve-only initialization/capture before
the first invoke commit. Store that real covered snapshot, the native delta and
the exact reply together, using the existing request-owned dispatch uncertainty
protocol. Retained sessions without coverage must still refuse/reset. An explicit
host-only never-entered-Oracle lineage marker is an alternative, but must be
created only from an absent base and never inferred during legacy recovery.

This initialization does not establish semantic synchronization of native scalar
or arbitrary graph/owner results into Python. `context_delta` owns a separate
native scalar, and its contract does not move other Python owners. Those delivery
transitions need explicit typed mappings; shared storage alone does not supply
them. This distinction should remain visible in the supported profile contract.

Reviewed the native-first repair: `starts_new_session` reads the private captured
absence of a persisted row. The invoke path obtains an actual preserve-only
adapter capture before its atomic commit, preserves the
conversation lease through cleanup, checks core completion before host ledger
classification, and refuses existing poison before initialization. Invoke ledger
bytes use the canonical invocation envelope, keeping endpoint collisions distinct.
Shared failure handling covers initialization, capture, response encoding and
commit, with request-owned poison and exact completion precedence.

The query path's two older revision-based initialization guards were also changed
to `starts_new_session`; verified in source. A retained revision-zero envelope
with unknown coverage therefore cannot be initialized as new. No unresolved
blocking source finding remains in this overlay. Execution/recovery qualification
and the explicit native-owner/Python transition limits still apply.

Final ordering review found that registry shape validation did not reject malformed
plan strings or invalid typed owner commands before initialization. The author
changed the order to native candidate proposal, bounded exact HTTP encoding,
preserve-only initialization, then atomic commit. Reviewed this final source:
capture installs only Oracle state/coverage, preserving the native candidate
delta; post-initialization errors still use shared uncertainty cleanup under the
same lease. Reviewed new malformed-plan/command and oversized-reply fixtures that
assert no dispatch/poison before a valid following turn. Did not run the fixtures.
This resolves the unnecessary-dispatch finding without relaxing unknown coverage.

## Known no-answer outcomes

Reviewed the dedicated `SemanticWithheld` overlay for unsupported routes, entity
ambiguity, subject ambiguity and existing w29 arithmetic refusals. The worker
catches only this type after evaluation's `finally` releases ambient context,
restores the original committed envelope on the same executor, constructs an
explicit preserving refusal, and then performs normal capture outside the catch.
Restore, source-pin, codec and capture failures remain operational failures.
Reviewed fixtures for prior precision/pending/path preservation and failure
propagation without executing them. No blocking source finding in this overlay.
Reviewed the final finite classification extension: quantity division-by-zero
uses the same preserving refusal. The adapter calls pinned `grow60.ask` once to
retain its typed decline kind; only `declined` with `form`, `no_part`, `no_value`
or `disagree` and a string reason becomes a semantic refusal. This matches the
actual source contract, whereas `voice10.Physics.ask` discarded the kind. The
thin answered formatting is reproduced without a second formula evaluation;
plan/program admission checks remain before execution. Unexpected None, malformed
results, unknown decline kinds and error statuses remain operational failures.
Reviewed the narrow implementation and fixtures without running them. No blocking
source finding remains in this final classification overlay.
