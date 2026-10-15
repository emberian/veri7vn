# Runtime omissions audit

2026-10-15. Read-only source audit against architecture revision 0, C03/C05,
ACC-01–16 and the planned task graph. No upstream imports, execution or builds.
These are contract/coverage corrections before implementation, not an alternative
architecture and not a request to preserve accidental Python behavior.

## Evidence and reachability

Source abbreviations below expand to these exact repository paths:

- `A/` = `upstream/root/fable-content/oracle-m-series-2026-08-15/self_loop/admitted/`
- `T/` = `upstream/root/wander-train/`

The front door is `upstream/oracle7.py:93–111`: read manifest `tip`, import it,
choose the last sorted `OracleReleaseRuntimeW*` class, construct one runtime and
serialize all turns through one dedicated executor thread. The manifest names
`oracle_release_runtime_w540` at `A/HEAD_MANIFEST.json:338`.

I followed source-level base imports and method calls, using AST parsing only.
The manifest's list is not itself a parent chain: `A/oracle_release_runtime_w31.py:36–40`
merges the loop and `SiblingEvidentialV3` branches; `A/oracle_release_runtime_w46.py:25–29`
also has two bases. Helper dispatch matters as much as `chat`: the old
`A/oracle_release_runtime_w480.py:130–138` calls `self._c480_dispatch`, so newer
overrides participate there; `A/oracle_release_runtime_w482.py:76` obtains the
code organ through a virtual method replaced by w486. The w530 helper class
explicitly documents an earlier wrong-class loader mistake at lines 109–111.

**Confidence:** high for the stated local control/data flow and the inherited
entry points; conditional for any optional organ activation. Imports, data files,
installed toolchains, route predicates and earlier returns still control whether
a particular input reaches a branch. I did not demonstrate end-to-end callability
in this audit. In particular, conversation/relation readers can be disabled by
caught import/data failures. A declared family is not evidence that it is usable
in this downloaded deployment.

The coverage ledger should record resolved base order, virtual overrides,
preemption/fallback predicates, required resources and observed feature status.
Do not classify a method as dead merely because a newer method has its name;
`super` and explicit base calls are part of its reachability evidence. This
sharpens existing COV-ROUTE/ACC-15 rather than creating a new implementation lane.

## R1 — P0: routing authority needs typed, scoped dispositions

**Evidence.** `A/oracle_release_runtime_w539.py:39–41,64–76` distinguishes a
reading failure that a general reader may fill from a check-stopped refusal that
it must not bypass. `A/oracle_release_runtime_w533.py:130–132` protects
`does_not_follow`, `out_of_fragment` and `validity`. This is not a simple global
core-first order: `A/oracle_release_runtime_w530.py:112–132` gives a body/gravity
specialist positive precedence, but its in-domain decline replaces the core
only when the core answered through a physics path. Lines 135–163 allow a
relation specialist to replace certain weak answers while retaining the previous
reading in provenance. `A/oracle_release_runtime_w496.py:77–79` permits a
self-only conversational act after a world-evidence refusal.

**Gap.** C03's `Declined(reason, diagnostics)` (`docs/contracts/request-result.md:40–49`)
has no routing authority or scope. A blanket terminal decline would lose useful
fallback and self/social behavior. Conversely, treating every decline as
no-match reproduces the bypass that the upper guards try to prevent. A fallback
that silently changes the question can produce a perfectly checked answer to the
wrong request.

**Correction.** Define internal route outcomes separately from the final user
result. Distinguish no applicable reading, unsupported capability, missing
dependency, unresolved interpretation, inadmissible candidate and an established
obstruction to a particular claim. Attach the exact interpretation/subgoal,
assumptions, route/domain and evidence scope. The arbitrator must check whether
a proposed alternative preserves the requested claim, resolves the obstruction,
or needs a new interpretation decision. A false premise can block one factual
answer while allowing a correction or a clearly framed hypothetical. Conflicting
accepted candidates require comparison under the same interpretation and source
policy, not whichever answers first. Heuristic route scores may prioritize work;
they do not grant truth authority.

**Integration.** C03, `operational-model`, `plan-composition`, `routing-dialogue`,
ACC-03/04/05/08. Acceptance cases: a recoverable reader miss, invalid-domain
calculation, alternative valid reading, contradictory candidates, and an allowed
social acknowledgement accompanying a blocked world claim. Workbench reader
precedence is a separate front-door policy and must compose with this boundary;
this finding does not impose core-first ordering on that surface.

## R2 — P0: composite turns need an outcome tree and dependency order

**Evidence.** `A/oracle_release_runtime_w529.py:92–114` rewrites and answers each
part sequentially in the **same session**, updating conversation state between
parts. This supports a later part referring to an earlier result. Its final
status is `answered` if any part answered. By contrast,
`A/oracle_release_runtime_w537.py:41–65` first evaluates the whole turn, then
retries parts in named sub-sessions after a family-precedence answer. w533 also
evaluates the whole turn before splitting and retrying
(`A/oracle_release_runtime_w533.py:179–199`); its family path fills uncovered
parts through a base call (`136–176`). Partial results are flattened into prose
and frequently lose individual references/outcomes.

**Gap.** A single C03 outcome cannot faithfully express an accepted first part,
ambiguous second part and budget-exhausted third part. Immutable request state
alone does not specify whether part two sees part one's output. Parallelizing
all parts would change existing useful contextual behavior.

**Correction.** A turn elaborates to a structured request graph; the response
retains per-node interpretations, outcomes, evidence and dependency edges, with
an explicit partial/completed summary. Sequential dependencies use accepted
structured bindings, not reparsed prose. Independent nodes may run concurrently.
A choice of interpretation or an unfinished subgoal remains local unless the
graph says other nodes depend on it. State/effect policy specifies whether
partial progress may commit. Replanning must not execute the whole turn and then
repeat its actions as subparts.

**Integration.** C03/C05, `plan-composition`, `state-effects`, `routing-dialogue`,
ACC-04/05/11. Include “capital of Austria and its currency,” an independent
two-domain request with one miss, and a dependent multi-step calculation with
cancellation. These are composition semantics, not merely a renderer feature.

## R3 — P0: only final, licensed results should update answer-derived context

**Evidence.** w529 updates context immediately after its parent returns
(`A/oracle_release_runtime_w529.py:76–80`). w534 has another update described as
following the “FINAL answer” (`A/oracle_release_runtime_w534.py:134–149`). Yet
w540 is above both and can subsequently withhold a reversed relation, a number
read-back or a private-state answer (`A/oracle_release_runtime_w540.py:60–80`).
w480 likewise logs a lower answer before those outer layers finish (`130–138`).
`T/chat_context_v2.py:152–190` extracts answer entities, numerical results and
solved variables from response text and stores them as follow-up context.

**Gap.** C04/C05 provide version/commit boundaries, but do not yet state the
publication rule for dialogue memory. If an intermediate rejected answer seeds
the next turn, later proof checking cannot recover the intended conversation.
Conversely, storing no state on refusals would lose legitimate question/topic
and interaction history.

**Correction.** Stage typed state deltas with each candidate. Final arbitration
and admission determine which answer-derived bindings may commit. Track
input-observed topic/utterance history separately from accepted answer values,
and retain rejected candidates only as non-authoritative diagnostics. Record the
final response as delivered, with its claim IDs and per-part status. Context
resolution consumes stable entity IDs and quantities/units from structured
results. It must never infer an answer entity by relinking the rendered first
sentence. The dialogue update is itself a specified state transition.

**Integration.** `interpretation-model`, `state-effects`, `runtime-service`,
`routing-dialogue`, ACC-04/07/11. Regression: an outer guard retracts an answer;
the next “where was she born?” or “square that” cannot use the rejected result.
This is a source-demonstrated ordering risk, not an executed bug reproduction.

## R4 — P0: end-user artifacts and speech acts are not universal claims

**Evidence.** `A/oracle_release_runtime_w486.py:78–86` deliberately presents code
as tentative when examples do not pin it down; it retains an `answered` status.
`T/organ_code_chat_v2.py:37–38,140–155` bases confidence on description keyword
coverage. Passing examples is not program correctness for all inputs. Separately,
w494 implements feelings, opinions, jokes, recipes and ordinary acknowledgements
(`A/oracle_release_runtime_w494.py:8–19,61–78`); w496 implements role play,
identity and measured session/self state (`A/oracle_release_runtime_w496.py:7–18,52–84`).
These are reachable dispatch families, not descriptions of a hypothetical model.

**Gap.** C03 says empirical candidates are proposals “available for
development/inspection” (`docs/contracts/request-result.md:58–62`). Read narrowly,
this excludes the existing end-user tentative-program workflow. Treating every
social reply or fictional artifact as an accepted world proposition is the
opposite error.

**Correction.** Separate response act/artifact from the claims it carries.
The user can receive a proposed program, fictional passage, acknowledgement,
clarification or quotation without those objects being promoted to general
truth. Attach accepted claims at their actual scope: for example, the execution
record says this exact program passed these exact tests in this environment.
Keep a proved universal contract distinct. Conversational/fictional framing must
survive rendering and persistence; role play must not create an external-action
receipt. Do not turn the whole interface into refusal whenever a useful artifact
has unresolved obligations.

**Integration.** C03, `routing-dialogue`, `synthesis-growth`, `workspace-client`,
ACC-02/04/08/10. Exercise ordinary end-user tentative code, a follow-up adding a
counterexample, and a role-play reply carrying no claim that anything was booked.

## R5 — P1: preserve three distinct code-generation mechanisms

**Evidence.** The source exposes materially different behaviors:

1. `A/oracle_release_runtime_w32.py:218–275,302–344`: choose a catalogue task and
   target language; invoke the actual toolchain; compare captured output with an
   expected output. Missing toolchain, timeout and mismatch are distinct failures.
2. `A/oracle_release_runtime_w37.py:156–216,295–347`: read ordered operations and
   an aggregation into a pipeline, emit Python/JavaScript, compare execution on
   three selected sample inputs with an independently computed reference.
3. `A/oracle_release_runtime_w482.py:67–90` plus the virtual w486 organ:
   example-guided typed enumeration. `T/code_organ_v3.py:334–444` ranks primitives,
   bounds term size/work/intermediates, merges observed output signatures and
   selects by description coverage. Lines 447–465 execute the emitted source,
   rather than merely trust the in-memory evaluator.

**Gap.** COV-SYNTH currently names the third family explicitly; the task label
“synthesis-growth” can hide the catalogue/toolchain and ordered pipeline paths.
Their languages, domain semantics, search guarantees and evidence are different.
The new serious Isabelle proof search is a further capability, not evidence that
these three have been subsumed.

**Correction.** Give each path a disposition and integration case. Connect an
emitted artifact to its native specification/IR and backend semantics. State
whether a run establishes example agreement, bounded search completeness, or a
general contract. Observational equality on examples is only a search heuristic;
it cannot justify replacing programs for every input. A completed search in a
bounded grammar differs from hitting the term/work cap. Preserve language choice,
toolchain diagnostics and executable artifact delivery. Improve these mechanisms
through verified composition/refinement rather than reproduce the phrase
“verified by execution” as a universal claim.

**Integration.** COV-SYNTH/COV-ROUTE, `synthesis-growth`, `refinement-backends`,
`deployment-builder`, ACC-05/09/10/13/15. Cover all three paths, emitted-vs-model
agreement, a counterexample outside training examples, and target unavailability.

## R6 — P1: learning scope and read-only execution must be explicit

**Evidence.** The w486 library path is a shared file beside the admitted chain
(`A/oracle_release_runtime_w486.py:35,55–67`), not its session. The `loop-` prefix
disables disk persistence. However `T/organ_code_chat_v2.py:145–150` still calls
`self.org.learn` before `_save`, whose persistence check is at lines 65–69. Thus
the switch does not suppress in-memory library growth. Reload executes stored
source and installs it as a primitive (`50–61`); recall checks same-name code on
new examples (`124–133`); save skips any already-used name (`70–78`).

**Gap.** C05 correctly distinguishes logical results, executable attachments and
search experience, but the operational scope of a retained result is not yet
fixed. One user's tentative synthesis can affect another request's search pool;
the legacy single executor hides races without providing ownership or isolation.
An evaluation run can contaminate later results even if it writes no file.

**Correction.** Every retained object declares owner/scope, identity/version,
assurance category, dependencies and activation state. Distinguish transient
per-request memoization, session learning and publishable reusable capability.
A genuinely non-publishing evaluation forks both persistent and in-memory
learning state. Loading an artifact restores its recorded evidence and declared
activation authority; its name or successful import does not grant admission.
New examples may invalidate empirical candidates without invalidating unrelated
proved results. Concurrency is permitted only after replacing the mutable
per-runtime recorder/library/session flags with explicit request state.

**Integration.** C01/C04/C05, `state-effects`, `synthesis-growth`,
`dependency-updates`, `performance-hardening`, ACC-07/10/11/12. Check two sessions,
a read-only benchmark followed by a normal request, conflicting same-name learned
programs, and stale library reload after a primitive changes.

## R7 — P0: normalization needs semantic modes and source-preserving transforms

**Evidence.** `A/oracle_release_runtime_w494.py:50–59` normalizes before calling
the parent chain. `T/organ_converse_v1.py:33–42,156–161` expands wrappers and
contractions, collapses whitespace and changes leading capitalization.
`A/oracle_release_runtime_w533.py:67–68,179–190` removes numeric thousands
separators before dispatch and then may split questions. Code synthesis has a
different transformation: expected outputs are deliberately removed from the
search description to prevent answer leakage (`T/organ_code_chat_v2.py:136–140`).
w521 has explicit multiple-choice and LaTeX entry points
(`A/oracle_release_runtime_w521.py:142–189`).

**Gap.** The architecture mentions normalization, but C03's originating spans
and language bindings do not yet specify how staged rewrites compose or protect
embedded languages. Global string rewrites can change code literals, quoted
premises, mathematics and the distinction between an assertion and a request.
The top guard and a lower reader can even inspect different surfaces.

**Correction.** Preserve raw input, identify language/quotation regions, then
elaborate through typed, versioned transformations with span mappings and
recorded contextual bindings. Code/test/literal data and mathematical notation
have their own parsing rules; conversational wrapper removal is not globally
authorized. Separate formatting normalization from meaning-changing
interpretation proposals. Guards inspect the structured claim and its originating
input, not route-name strings or a renderer's numeric text. Every front door must
pass the same semantic envelope even if its UI offers additional readers.

**Integration.** C03, `interpretation-model`, `routing-dialogue`,
`known-regressions`, ACC-04/05/15. Cover signs/scientific notation, comma-separated
data versus numeric formatting, quoted code containing contractions, LaTeX,
multiple-choice option identity, and a social “and” that is not two questions.

## Recommended implementation gate

Resolve R1–R4 and R7 in shared contracts before freezing executable interfaces.
R5–R6 need explicit coverage/task acceptance before those lanes report completion.
Existing architecture already names most underlying concerns; these findings
make the operational cases concrete and prevent individual lanes from choosing
incompatible interpretations. No additional universal value language or global
single-thread constraint follows from this audit.
