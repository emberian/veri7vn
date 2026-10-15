# Authoring, migration and handoff design

Design recommendation for root synthesis, 2026-10-15. This chooses a coherent
product approach against C01–C05 semantic revision 1 and the inspected Oracle7
workbench. It introduces no implementation or change to approved scope. Source
evidence is collected in [the workbench audit](../review/workbench-gaps.md), with
exact upstream file/line references; the decisions below resolve that audit's
workflow questions rather than repeat its checklist.

## The product an author owns

An author owns an editable **development package**. It can contain several related
capabilities, shared theories, source mappings and examples; one Python manifest
need not become one independently maintained theory or process. A **release** is a
content-identified, built snapshot of that development and its dependency closure.
A **deployment** selects releases, source bindings and operating policies for a
running generation. A **workspace** contains drafts, private source connections,
evaluation runs, conversations and proposed changes. These four concepts suffice;
do not create a different project model for each specialist family.

The product opens to a workspace with packages, sources, conversations and runs.
Selecting a capability shows its meaning and inputs, language bindings, examples,
implementation/evidence and costs as views of the same development. “Run” can try a
draft in an explicitly isolated development context. “Activate” changes the running
deployment only after its applicable admission and qualification requirements pass.
An ordinary question can also yield useful candidate code or a partially developed
artifact without activating it or pretending it is universally correct.

Packages remain ordinary directories, inspectable and editable outside the UI.
Keep the existing format-0 descriptor as an index, not a second semantic language.
Its source roles identify editable inputs; a separate derived build record records
the resolved full closure. Credentials and private workspace databases are never
package files. No hidden editor database is the only copy of an author's work.

## Canonical editable representation: native theory with approachable commands

**Default:** native `.thy` files are canonical for mathematical meanings and
operational definitions. Add family-specific declarative Isabelle commands for
formulas, guarded rules, table/query bindings and capability declarations. The
approachable editor edits these commands in the same file; Isabelle elaborates
them into definitions, obligations and registered native objects. The package
depends on the versioned command library that gives them meaning. The generated
HOL objects appear in an inspector, not in a second independently editable source
file. This is open HOL with useful notation, not a universal capability AST.

Each supported command has a source-preserving parse, source spans, an editor
projection and a versioned elaboration recipe. The editor submits a textual patch
against a known file revision, preserving comments and unrelated commands, then
asks the native service to re-elaborate. A stale revision produces a mergeable
conflict, not a silent last-writer-wins update. Stable author-assigned binding names
connect views; source offsets alone are not object identity. A form is editable
only where the command parser can explain a lossless update.

Expert definitions, locales, proofs and ML remain native source. The form view
renders unfamiliar blocks as native blocks without reformatting or guessing their
semantics. An author can explicitly convert a supported declaration to a native
definition/proof development, preserving public names where possible and starting
a new revision. The former generated view then has no ownership; the form becomes
an inspector until a supported projection is deliberately supplied. We do **not**
promise arbitrary HOL-to-formula round trips. Expert editing changes the same
package, and its effects remain visible through actual native diagnostics.

Structured examples, source acquisition recipes and large input data can live in
ordinary sidecar files. Examples name inputs and expected *scoped* observations or
declines; source recipes name acquisitions and transformations. They must not copy
HOL definitions or theorem statements as editable JSON. Language rules and source
bindings that alter semantic interpretation are declared in the native development
or in a single explicitly owned fragment elaborated by it. The source map reaches
the actual rule/table cell even when the declaration includes a sidecar.

**Alternatives rejected:** independently editable JSON semantics plus `.thy` makes
drift inevitable; a compulsory separate DSL limits the open-ended expert surface;
a theorem editor alone forces every novice to write the same proof scaffolding.
Embedded declarative commands allow the same source to be ordinary Isabelle work
and an approachable application development. Command implementations are trusted
elaboration/plugin code governed by C02, not magically verified macros. Formal
properties attach to their elaborated terms and generated derivations; no arbitrary
author ML is loaded just to preview an untrusted package.

## Authors develop intentions; machinery handles routine obligations

The initial author starts from a family recipe: quantity/formula, finite table or
relation, guarded rule, algorithm, stateful connector, or native development.
Recipes are versioned library developments with reusable correctness and
representation theorems, language-binding templates and negative examples. They
are extensible; the list is not a closed ontology. A source reader inherits the
proved query machinery while retaining its own data-selection and claim policy.

For a spring calculation the author supplies quantity roles, formula, domain and
examples. The editor checks dimensions and interpretation, instantiates existing
definitions and proof rules, and runs bounded search for remaining obligations.
If `sqrt(x*x) = x` fails, it shows the counterexample and offers the distinct
repairs `x >= 0` or `abs(x)`, including callers affected. A successful repair is a
reviewable source patch with its proof development, not an invisible solver result.
Most recipe instances should discharge routine obligations automatically. A hard
obligation stays editable and runnable as a scoped candidate while the author asks
for stronger search, changes intent, or brings an expert native proof.

This assistance must include interpretation and source errors, not only theorem
failures. A table with two matching rows offers “return alternatives,” “ask which
entity,” or a declared selection rule; it cannot repair uniqueness by quietly
discarding a row. A mathematical proof does not certify the wording matched the
user's intention. The author sees the chosen reading and can test it independently
of execution, including the original literal spans.

## Oracle7 intake becomes family development, with accountable repairs

Intake first creates a source-preserving migration record: pinned Python/config/data
identities, actual entry/override path, inputs, outputs, state/effects, exceptions,
guards and empirical examples. Static inspection is safe to do before loading any
code. Differential execution, when useful, runs only in an explicitly authorized
legacy worker with fixtures and a recorded environment. Missing stores remain
missing; do not fabricate baseline answers from panels.

The concrete factoring opportunity is substantial: 161 relation manifests share
two relation class variants; 22 fact manifests share a rule family; two site
manifests share stateful families. Those counts are from the pinned coverage ledger,
not proofs that every instance is equivalent. Build a relation/query recipe once,
then instantiate each reader's domain filters, roles, uniqueness/coverage policy
and language rules. Extract ordered fact rules as data with provenance and explicit
priority, retaining boundary-variant behavior. Treat remaining algorithms by their
actual semantics: graphs, finite probability, encodings, units/frames, calendars,
symbolic mathematics and so on. Shared method signatures do not justify a bulk
translation, and all 119 other manifest entries need their reviewed disposition.

Use constrained Python extraction only for patterns whose translation obligations
we can state and discharge: a particular pure expression subset, finite rule table,
or a family configuration. Otherwise write a native specification and implementation
guided by the old source, factor common behavior, and connect execution to that
specification. There is no credible default “parse arbitrary Python into HOL and
certify it” button. Opaque Python remains labeled a legacy comparison/compatibility
adapter, never completed migration. A semantic lift carries its own implementation
bridge; agreement on old tests is additional compatibility evidence, not that bridge.

Every repaired behavior retains a short old/new example, reason and scoped contract.
For example: an expired conversation specialist must no longer answer a cached
follow-up; a stale MQTT event keeps its event timestamp despite repeated polls.
We preserve useful user behavior while repairing these mistakes. The inherited
runtime's routing, final arbitration, session adoption and workbench entry points
are migrated as a composed product, not hidden behind per-manifest completion.
Original corpus parity and platform completion remain separate statements when
the absent v2/name stores cannot be reconstructed exactly.

## Admission, qualification and deployment are three separate decisions

Do not force one `verified` flag or one linear status onto a whole workspace.
A draft revision has build results, semantic admission records, qualification runs
and deployment references. A run may fail while the previous release remains active.
The release operation seals a particular successful build; activation updates a
deployment pointer atomically. A release can be retired without changing its content
or the meaning of a theorem already formed from it.

The normal flow is **edit → elaborate/build → diagnose/assist → evaluate → release →
activate**. Formal admission governs the claimed semantic/execution assurance of
each export. Operational qualification governs whether that composed generation is
ready for its intended use: positive/negative examples, interpretation overlap,
source failures, effects, and resource envelope. A draft that fails either can
remain useful and inspectable; it cannot inherit its predecessor's approval merely
because its package ID is unchanged.

Choose **repeatable regression as the normal local development loop**, preserving
Oracle7's domain examples, must-decline cases and interference checks. Use fresh
held-out qualification when claiming an improvement over a baseline or publishing
measured generalization. Register a panel/split identity and exposure events; a run
becomes exposed when its contents are released to the candidate/developer workflow,
even if it aborts. Repeating it remains a legitimate regression, visibly no longer
fresh evidence. Imported sender ledgers remain attributed; the recipient can rerun
the exposed set without deleting that ledger or claiming a fresh holdout.

Default activation requires completed native admission for its promised assurance,
passing mandatory family/regression/interference cases, declared dependencies and
effects, and a measured resource policy. It does not require a new statistical
holdout every edit. Oracle7's fixed gain/percentage/latency thresholds become named
legacy qualification profiles for comparison, not universal activation laws. A
hand-written scorer is executable evaluation code with its own identity/trust
boundary, not authority to bless a theorem. No threshold can establish intended
meaning or truth of acquired source claims.

## The complete author loop

An opt-in **Gaps** view groups unresolved requests and their structured reasons.
The author selects a cluster, sees original readings and blockers, and creates a
draft using an existing recipe or requests a proposed abstraction. Selected
questions become development examples with unknown expectations, origin and private
classification. The author or declared source supplies expected behavior. They
are not auto-labeled facts and never silently become held-out data.

The editor explains each failed build, reading or qualification in place, with
counterexamples and proposed patches. The author accepts a repair, runs the intended
questions and interference suite, then profiles a representative batch. The cost
view distinguishes interpretation, source access, search, execution, checking,
rendering and startup/admission. It links a hot operation to a proposed index,
specialization, cached plan or implementation refinement. Applying an optimization
creates a candidate revision and its preservation obligation; passing it and
qualification produces a release. Deploying that release leaves active requests
pinned to their original generation, subject to current retirement authority.

This is the same workflow whether a human writes the first formula or a synthesis
strategy proposes it. Retained proof developments and implementations become normal
package source; successful strategies/rankings remain separate search experience.
The UI should make the improvement usable, not require the author to discover
which hidden ML function to call after the proof succeeds.

## Sources and local state are workspace bindings, not secret package payloads

A package declares the source interface it needs and the interpretation/query
semantics. A workspace binds that interface to an imported corpus, local files,
machine/SSH reader, MCP server or sensor. An immutable snapshot carries known origin,
selection/schema mapping and content identity. Acquisition jobs and long-lived
subscriptions have **configured → running → stopped/failed → retired** lifecycle
state and versioned configuration. Reconfiguration starts a new observation policy;
it cannot relabel old samples. Poll/event timestamps, deduplication, quality and
unit/calibration provenance belong to observations, as required by C04.

Connection discovery, probes and requalification are named operations with their
own effect permissions. The default source setup previews schema/mapping against
fixtures or recorded reads; a real tool invocation is performed only under the
workspace's selected authority. An MCP tool is not read-only because it appears
under “Sources.” Its precise arguments and target are inspectable before a world
action. Source credentials live in a host secret reference/store; the package and
portable build recipe contain no credential material.

Feedback appends an attributable event linked to the result/invocation, then proposes
a new interpretation/ranking policy. It never directly rewrites live routing.
Local background evaluation may qualify a proposal; automatic activation is allowed
only within an explicitly configured policy and the same authority boundary.
Default is reviewed activation of learned routing changes, with one-click undo
producing a new policy revision. Factual feedback supplies a correction proposal,
not a theorem. Feedback on a bad tool must not trigger unapproved real tool calls.

## Persistence, forgetting, restoration and transfer

Preserve the upstream default of local conversation history enabled, with per-session
ephemeral mode; keep the gap journal opt-in. Temporary recall capabilities default
to seven days. Use explicit retention settings for other sources rather than pretend
that “immutable” means forever. For sensors default the retained observation window
to 24 hours unless the author selects a longer archive, and actually enforce that
retention independently of file size. Source packages intentionally curated for
long-term use are different from incidental conversation/poll data.

**Retire** prevents new execution/use while allowing retained historical inspection.
**Forget** removes managed payloads and transitive managed derivatives, invalidates
dependent cache/session handles and removes content-bearing traces. Explicitly
curated package material derived from those sources is shown in the impact preview:
the author may retain it as a deliberate copy or include it in forgetting. Default
forgetting includes uncurated examples, summaries and learned features; retaining a
derived private copy is never hidden. Already committed external actions cannot be
undone by deletion. Exports and uncontrolled third-party copies are outside managed
erasure. Minimal tombstones contain opaque IDs and lifecycle status, not snippets;
avoid retaining raw-content hashes when their disclosure itself is unwanted.

Retirement stops new invocations. Forgetting/revocation additionally cancels pending
work that needs the removed data, prevents publication and revokes cached handles.
Committed operations remain as status records where permitted; reconciliation can
report that source details were intentionally removed. Ordinary package replacement
does not cancel unrelated old-generation requests. These are different transitions,
not a global “invalidate all history” rule.

Session restoration loads typed checkpoints and accepted transitions under current
access policy. It never re-executes historical requests. In-doubt external actions
enter reconciliation with their operation identity; reconnect does not retry them
blindly. Read-only “what did we say?” quotes the retained answer and its time/scope.
It does not reclassify it as a fresh source observation.

Export is **select → preview closure → package**. The default portable package
contains authored public source, selected examples, documentation and reproducible
build/dependency recipes. Private source bindings, transcripts, credentials,
feedback, caches and derived private examples are excluded. The preview lists
omitted required dependencies and whether the result is source-rebuildable, runnable
with recipient bindings, or a deliberately incomplete development. Private exports
require selecting those contents explicitly. Import stages files for inspection,
resolves dependencies, builds under controlled policy and evaluates before activation;
sender proofs/receipts are re-associated with native objects, never trusted as JSON.

## UI, CLI, Film and code experimentation

**Engineering default:** a local browser application written in TypeScript/React,
with CodeMirror 6 for source editing, all assets bundled for offline use. These are
proposed implementation choices, not claims about already tested compatibility or
redistribution clearance. React is chosen for the interdependent editor, run,
diagnostic, source and change-impact views; CodeMirror for an editor component rather
than a custom textarea IDE. A small vanilla application was adequate for upstream's
monolithic `app.js`, but reproducing its ad hoc state across this larger workspace
would obscure ownership and stale-result handling. An Electron shell adds a second
application runtime without supplying semantic authority; do not require one.

The native runtime host serves the bundled assets and an authenticated loopback
protocol; origin checks and an unguessable per-launch credential prevent other local
pages issuing author operations. The CLI is a thin client of those same versioned
operations, with human and machine output and attach/start behavior. Follow the
runtime lane's host/process choice, avoiding a second Python semantic server or a
Node service solely for the UI. Node tooling, if used, is a build-time dependency.
Expert “open in Isabelle” uses the actual package source and source locations;
advanced native editing need not be reimplemented completely inside the browser.

Preserve **code experimentation** as a workspace scratchpad: ask for a program,
inspect/edit it, supply examples/tests, execute under an explicit worker policy,
retain the artifact and observations, and request stronger synthesis/proof before
promoting it. Native expression/plan experiments use the native development worker;
generated Python and other supported language artifacts use versioned optional
toolchain workers. They are not production capability engines or proven merely
because tests pass. The initial compatibility Python worker must clearly be
user-authorized code execution with process/resource controls; `python -I` and a
temporary directory are not a filesystem/network sandbox. Restrictive isolation
must be supplied by a real supported backend or the operation must remain in the
explicit trusted-code profile. Keep content bytes, compiler/interpreter identity,
inputs and results attached to each run. No unrestricted generated ML runs in the
authoritative resident process.

Preserve **Film's local purpose**: select a result/derivation, preview a truthful
explanation, export a self-contained HTML explanation and browser-produced WebM
when supported. The HTML carries navigable conditions and source/evidence links;
the video is a presentation derived from it, with a companion receipt bundle.
Never silently truncate a condition to fit narration or remove provenance without
a visible reference. Generated images are labeled decoration, never evidence.
The existing renderer, framing and animation ideas can be reused after review;
new result objects replace string parsing of paths and evidence markers.

Recommend optional adapters for remote narration/illustration and public registry
operations, disabled unless configured, with explicit export/effect previews.
Preserve import of their provenance records. Solana/token burning is not needed for
native proof, integrity or package sharing and should not be in the mandatory core
dependency closure. Whether those network adapters must ship in the first handoff
is a real scope preference for Ember/root to settle, not a reason to silently
discard an existing workflow. Local Film and experimentation remain required here.

## Handoff and remaining genuine choices

The handoff is an offline-capable installation containing the native runtime and
prebuilt application heaps, bundled workbench, CLI launcher, recipe libraries,
editable example developments and chosen corpus/solver packs. It opens an actual
workspace and completes create → diagnose → repair → profile → activate without a
repository checkout, hidden developer command or surprise HOL-Analysis build.
Building a new development uses the same controlled build service with progress
and warm dependencies; the UI distinguishes that from opening an existing release.
Support macOS ARM64 and Linux x86_64 as D11 requires, with separate actual evidence.
Do not hide absent original corpora behind a successful sample workspace.

A recipient should see a small worked package for each core authoring pattern,
one substantive composed/search-driven development, and the migrated Oracle7
coverage map with each preserved/repaired behavior navigable to source and evidence.
The workspace exposes environment/toolchain identity, export/backup/recovery,
source-binding repair and deployment rollback. A plain directory export preserves
custom theory edits and can be rebuilt by a recipient with the declared tools.

Most decisions above are engineering defaults root can adopt: canonical `.thy`
with declarative commands, shared UI/CLI operations, repeatable regression plus
honest exposure history, reviewed feedback activation and explicit retention
transitions. Real user preferences are whether first-handoff compatibility includes
the remote media/public-chain adapters; desired default private-data retention
beyond the proposed upstream-compatible defaults; and license/publication policy.
Missing-original-corpus replacement is a separate provenance/product decision.
Exact widget layout or proof tactic selection should not be escalated as a new
design approval. None of this authoring design requires novices to hand-prove every
instance, nor permits a polished front end to conceal an unconnected Python port.
