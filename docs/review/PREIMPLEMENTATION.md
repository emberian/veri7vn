# Preimplementation gap audit

2026-10-15. Requested after foundation checkpoint `81e1b31`, before the first
implementation wave. This is a source-backed design review, not a claim that all
Oracle7 behavior was executed or that migration is complete.

## Conclusion

The native Isabelle architecture survives this review. Several interfaces were
too underspecified to begin independent implementation safely. Broad coverage
promises had concealed distinctions that need concrete representation and tests.
The changes below strengthen the agreed product rather than add all six sibling
applications to migration scope. No production implementation is introduced here.

The source reports retain exact paths, line references, reachability limits and
additional findings:

- [Domain specialists](domain-gaps.md)
- [Runtime, dialogue and synthesis](runtime-gaps.md)
- [Workbench and lifecycle](workbench-gaps.md)
- [Sibling contract stress tests](sibling-gaps.md)

## G01 — Claim scope is independent of assurance

An answer can describe a mathematical consequence, a source observation, a finite
model prediction, a measured test result or an optimization over a declared
candidate set. The assurance route describes how that *particular claim* is
supported. It must not erase which claim was made.

For example, certifying a classifier's computation does not establish that its
label is correct in the world. Maximizing over seeded simulated scenarios is not
worst-case reasoning over every physically possible scenario. A numerical score
is not a calibrated probability merely because it lies between zero and one.

The core's tentative code output is already useful ordinary-user behavior, not
only a developer diagnostic. A candidate artifact may be shown with exact test
observations and outstanding obligations without being admitted as a universally
correct executable capability. The current C03 wording risks suppressing this.
The runtime also has greetings, help and self/role speech acts. Such acts need
their own structured role; they are not all failed attempts to prove a world
claim. A refusal can constrain a claim without forbidding a useful response.

**Required design correction:** separate claim scope, evidence/assurance, and
artifact lifecycle. Keep candidates first-class and inspectable in normal user
workflows. Tests remain empirical observations, not a fourth proof route. A claim
about a backend observation must not become a loophole that labels every opaque
Python adapter a completed lift.

Owners: interpretation-model, native-admission, operational-model,
synthesis-growth, routing-dialogue. Connections: C02/C03/C05, PO-03/04/05.

Synthesis coverage must separately account for the original catalogue/toolchain
execution, ordered pipeline search with differential samples, and typed bounded
enumeration with a persistent empirical library. One small enumerator does not
subsume all three. Generated files/programs and other output artifacts need
content identity, producing-operation association and precise evidence scope;
a property of placement metadata does not automatically establish a property of
rendered pixels or an exported file.

## G02 — Semantic profiles and lossless inputs

The domain inventory includes SQL, graph algorithms, exact finite probabilities,
data encodings, calendars, affine temperatures, logarithmic quantities, vectors
and reference frames. A scalar plus a unit string cannot represent their laws.
Examples include temperature points versus differences, dB aggregation, and
angles relative to a joint frame. Native open types are appropriate, but their
codecs, operation signatures and permitted conversions must be explicit.

The dataformats specialist collapses whitespace before extracting strings for
JSON parsing, encoding and hashing. Natural-language normalization must never
silently rewrite embedded code, quoted strings or byte payloads.

**Required design correction:** define extensible semantic profiles with native
types, representation relations, literal boundaries, numeric conventions,
permitted operations and evidence obligations. Preserve original text/bytes and
source maps alongside normalized language views. Do not create a closed universal
datatype containing every domain or normalize all inputs through prose.

Owners: coverage-disposition, native-registry, operational-model,
interpretation-model, domain-families, mathematics-family. Connections: C01/C03,
PO-01/02/03/07.

## G03 — Results need structure beyond one success flag

SQL returns at most twenty displayed rows and records truncation only in prose.
Graph routines return costs while witnesses remain in prose or are discarded.
Multipart conversation returns an overall answered status when only some parts
succeed. These are distinct claims with distinct composition rules.

**Required design correction:** carry typed collections/artifact references,
coverage/completeness and ordering semantics, and per-subgoal outcomes and
dependencies. A prefix is not a complete query answer. A feasible witness is not
an optimality certificate. A solved part does not discharge another part's goal.
Dependent subquestions use explicit intermediate state rather than unrelated
sessions or reparsed answer text. Compact UI rendering must retain that structure.

Owners: operational-model, source-semantics, plan-composition, routing-dialogue,
graph-family, domain-families. Connections: C03/C04, PO-02/03/04/06/09.

## G04 — Routing and refusal have scope

The original runtime has positive specialist precedence, route-specific vetoes,
fallback allowed after lack of a reading, and fallback forbidden after some
failed checks. The workbench also prioritizes addressed personal-source readers
before the core. Neither a universal core-first rule nor a terminal decline flag
captures this behavior.

**Required design correction:** represent applicable candidates, unresolved
interpretations and scoped blockers separately. A blocker identifies the
interpretation, premise, capability or request scope it constrains and what would
discharge it. A new route cannot evade an applicable failed check, while a refusal
of one reading need not ban a different justified reading. Routing decisions and
their observations belong in versioned policy and the inspectable trace.

Owners: interpretation-model, plan-composition, routing-dialogue,
native-registry, known-regressions. Connections: C03/C04/C05, PO-01/04/08.

## G05 — Formal admission is not operational qualification

The original authoring process measures added answers, wrong answers, false yeses,
unwanted interception of general questions, held-out exposure and latency. A
proved kernel can still have an intrusive recognizer or a useless deployment.
Conversely, passing those tests does not prove a generalized contract.

**Required design correction:** preserve a separate operational qualification
record tied to exact code, interpretation/routing policy, mutable learned state,
exam/scorer and runtime versions. Model dev/held-out exposure and imported exam
history honestly; rerunning an exposed test is not a fresh held-out evaluation.
Retain negative-space/abstention and extension-interference tests. No empirical
score substitutes for formal admission, and formal admission does not waive these
product tests. Feedback is a versioned policy proposal requiring appropriate
qualification, not an untracked mutation outside the package identity.
Non-publishing evaluation must isolate in-memory learning as well as disk writes;
the original persistence switch does not prevent its shared library from learning.
Retained objects distinguish request, session and shared scope before requests
are parallelized over mutable runtime state.

Owners: workbench-audit, package-lifecycle, native-registry, synthesis-growth,
known-regressions, performance-envelope. Connections: C01/C04/C05, PO-08/09.

## G06 — Observation and validation can perform effects

The original has background sensor polling and MCP calls during source checks,
not only a pure question/answer path followed by a proposed write. Finite-window
statistics also depend on rejected samples, event times, sampling and missingness.

**Required design correction:** give every external operation an executor
contract, including qualification, preview, background acquisition and replay.
Use recorded/mock sources for tests unless live execution is explicitly authorized.
Model acquisition events, event/ingestion/evaluation clocks, missing or rejected
samples, measured versus simulated provenance, windows, staleness and cancellation.
Background jobs have owners, budgets and restart/retirement semantics. Account for
whole-session worker load and interference, not only per-call timeouts.

Owners: source-semantics, state-effects, stateful-connectors, runtime-service,
performance-envelope. Connections: C04/C05, PO-03/09/10.

## G07 — State restoration, retirement and forgetting

The workbench restores context by replaying previous questions. The runtime can
update conversation context before an outer guard withholds the answer. Temporary
readers have expiry; conversations and journals can be deleted; private readers
are excluded from sharing. Immutable generations alone do not define these cases.

**Required design correction:** commit structured conversation deltas only after
final outcome arbitration; distinguish recording an utterance from adopting an
answer as context. Restore recorded state/events without repeating external
actions. Define retirement/expiry, revocation, retention and export classes for
sources, transcripts, caches, learned state and derived artifacts. A pinned old
generation is not perpetual authority to use retired private material. State what
is removed, invalidated or retained under an explicit policy; do not promise erasure
of uncontrolled copies. Forgetting can intentionally limit future replayability.

Owners: state-effects, dependency-updates, package-lifecycle, routing-dialogue,
runtime-service, deployment-builder. Connections: C01/C04/C05, PO-08/09/10.

## G08 — Preserve the author's improvement loop and explanations

Existing workflows include decline clustering into draft specialist examples,
feedback and requalification, code checked against the user's tests, conversation
recall specialists, route visualization, and browser-local films of reasoning
paths. Generic editor/import/export tasks do not fully specify these workflows.

**Required design correction:** explicitly map each to a preserved or deliberately
repaired workflow. Explain where the first useful artifact comes from, how an
author revises it and how it reaches ordinary deployed use. Render traces and
exported artifacts from structured outcomes and provenance; generated illustration
is not evidence. Keep opt-in journaling, private-reader export boundaries and
optional external-service calls explicit. Film implementation and external
publication compatibility need a visible scope decision rather than accidental
omission. Six sibling products remain architectural stress tests, not automatic
additional deliverables.

Import must include an explicit path from the author's existing Oracle7
manifests, cards, panels/scorers and source references, not merely import of our
new package format. Preserve originals and distinguish carried empirical evidence
from newly checked claims. Known families can have migration recipes; unknown
Python behavior must yield concrete unresolved obligations, not be silently
wrapped and declared lifted. The author should recognize the original capability,
see each intentional repair, and have editable material to continue developing.

Preserve the original local/offline core deployment property. Packaged core
reasoning and local authoring must not silently require an external language model,
remote prover, CDN or startup download. Deliberately connected sources/services
have explicit availability and effect boundaries. Test with network access disabled;
this does not promise the original advertised memory budget, which requires actual
measurement on supported targets.

Owners: workbench-audit, workspace-interaction, workspace-client,
diagnostics-repair, authoring-assistance, workspace-integration, recipient-handoff.
Connections: C01/C03/C05, ACC-01/02/03/09/10/14/16.

## Consequence for fan-out

The first wave can still proceed in parallel, but registry, operational-model,
interpretation and source lanes must design against these shared cases before
their signatures become dependencies. Each gap is attached to actual task
acceptance/checks. Interface review must exercise concrete cases, not merely
accept statements that the design is extensible. This audit is not the completed
reachability classification, full sibling audit or an executed regression suite;
those remain tracked work. No missing implementation is marked complete here.

Coverage must map each actual entry surface through its dispatch/override path,
state reads and writes, output and side effects, failure/cancellation/expiry
behavior, and eventual migration decision. Include alternate workbench/CLI paths
and persistence across restart. A manifest inventory alone cannot capture the
inherited runtime's virtual dispatch or the full lifecycle. Source-derived risks
in these reports are not labeled reproduced bugs until exercised appropriately.
