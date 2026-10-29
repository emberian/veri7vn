# Defaults and alternative consistent plans

Native provider, now a workspace member and hosted as the optional `logic`
profile of the standalone service (operations `logic.query` and
`logic.enumerate`). It is not yet in the release package and has no Linux
hosting receipt. No specialist panel numbers yet. No Isabelle proof claim.
The central runner's pinned Linux qualification of the core passed 18 tests:
10 semantic tests, six subprocess boundary tests, and two actual-clingo tests
([receipt](../evidence/2026-10-29-logic-validation.json)). On macOS the hosted
path, the same 18 core tests and the hosted additions passed against a locally
built clingo 5.8.2 ([hosting receipt](../evidence/2026-10-29-logic-hosted.json)).

This provider answers questions about an explicitly complete, finite, grounded
normal logic program. Its rules can have one head atom or no head (a constraint),
positive body atoms, and default-negative body atoms. An empty body with a head
is a fact. Default negation means absence from a candidate stable model; it is
not an assertion that a public-world fact is false. There are no variables,
functions, disjunctions, aggregates, classical negation or automatic grounding.
Labels such as `bird(tweety)` are opaque strings. All rule references are array
indices into `atoms`.

`Request.scope` requires a tenant, a snapshot and `complete_program=true`.
That is a caller coverage assertion, not a verified property. A caller must not
silently translate a partial public search result into this complete scope.
Queries outside the supplied atom universe are rejected. A request replaces
the full local program. There is no persistent model cache, so changing or
retracting a rule cannot reuse old conclusions. Host integration must preserve
that property and isolate tenant/snapshot evidence.

For each query atom, `skeptical` asks whether all stable models contain it;
`credulous` asks whether some stable model contains it. `true_witness` and
`false_witness` point into the returned array of full checked model witnesses.
That array is not normally an enumeration of all models. For example,
the alternative-plans example has models `[0,2]` and `[1,2]`: either transport
choice is credulously true and skeptically false, while travel is true under
both readings. The flight examples have respectively `[0,3]` and `[0,1,2]`:
adding the penguin fact withdraws the earlier flight conclusion. The recursive
policy example grounds a delegation cycle from an owner and derives permission
unless revoked; adding a revocation fact withdraws permission while retaining
reachability. This is a reasoning demonstration, not an admission authority.

The default `operation: "query"` checks consistency with one satisfiability
solve, then asks for a model with the opposite query polarity whenever existing
witnesses do not settle it. A checked counterexample refutes skepticism; a
solver-trusted UNSAT probe establishes absence of a counterexample. This takes
at most one plus the number of queried atoms in solves, and does not enumerate
irrelevant choices. The regression has 60 independent default choices and a
forced queried fact: it has 2^60 models but needs one witness and one UNSAT
probe. `operation: "enumerate"` is the explicit bounded full-enumeration option.
`enumeration_complete=false` is normal for completed query operations.

`status` is `consistent`, `inconsistent` or `inconclusive`. Inconsistent programs
have **null** skeptical/credulous values. If a later required probe fails, the
operation stays inconclusive but retains checked witnesses and completed
answers. A true witness alone preserves `credulous=true`; a false witness alone
preserves `skeptical=false`. The opposite directions stay null unless a completed
probe established them. There is no
vacuous certainty from the empty set of stable models. An empty program has
one empty stable model and is consistent. A missing executable, timeout,
cancellation, pipe overflow, witness/model cap, bad witness or backend failure yields an
inconclusive reply. Invalid requests are errors; a reply too large even to
return the inconclusive envelope is a resource error. Unvalidated or partially
read candidate witnesses are never retained.

If a checked witness contradicts any previously trusted UNSAT claim, every
UNSAT-dependent conclusion is revoked, including otherwise uncontradicted
earlier answers. The reply becomes inconclusive with
`completeness_trust="witnesses_only_backend_inconsistent"` and is rebuilt only
from checked models. This applies on every partial-return path; an ordinary
timeout without such a contradiction may retain completed earlier probes.

## Witness checking and trust

The independent checker constructs the Gelfond–Lifschitz reduct relative to
each candidate M: remove a rule if a negative body atom belongs to M, remove
remaining negative literals, compute the least Horn closure, require it to equal
M and require all remaining constraints to hold. Unsupported positive cycles
therefore cannot fabricate facts. This is handwritten Rust, not extracted HOL.
Every witness is checked, including witnesses for skeptical counterexamples.
The backend's UNSAT probe claims, or its claim that optional enumeration found
**all** models, are solver-trusted without a proof certificate; the reply says so explicitly.
The checker cannot detect a false UNSAT claim or a solver that silently omits
a valid model while claiming optional enumeration complete.

The independent test oracle uses minimal models of each reduct and enumerates
proper subsets, rather than copying the least-fixpoint implementation. It covers
all 1,225 two-atom programs of up to two rules, including constraints, facts,
self-negation, positive cycles, contradictions and repeated rules: 4,900 model
checks. Exhaustive search exists only in test code. A separately ignored test
compares default clingo queries to this oracle over all 36 one-atom pairs with
repetition. Another ignored test checks the 2^60-model irrelevant-choice case:
query succeeds with a two-witness cap while explicit enumeration is inconclusive.
Additional tests cover scope checks, duplicate/out-of-range witnesses, model
caps, malformed backend symbols, cancellation, unavailable backend and all five
motivating examples. All 18 tests passed centrally on the frozen source, including both normally
ignored actual-clingo tests run explicitly; skipped tests are not counted as passes.

## Backend decision

Use an operator-pinned **native clingo executable** first. It already solves
stable-model search with a mature ASP engine. This avoids making a new Rust
ASP solver the critical path and lets the host stop a request process by its
recorded PID. Clingo is MIT licensed. Its source build requires C++14 and CMake;
release source includes generated parsers. The central runner built official
clingo 5.8.2 on Linux with Python/Lua disabled, static internal libraries and
two CMake build jobs. The 5,734,088-byte CLI has SHA-256
`fba811b7b18e9379aa701dd92451880b2ce6537a43c359bd726d5ee5ad7b8753`.
Its dynamic system dependencies and license notice are hashed in the
[build receipt](../evidence/2026-10-29-clingo-build.json).
The owned Linux artifact is not installed, service-admitted or bundled.
It is not a fully static/hermetic binary. MacOS qualification and measured
cold/hot request latency remain open. No Rust binding or shared-workspace
C++ build dependency is added by this lane.

An in-process C/C++ binding could avoid process startup, but adds native linking
and requires an interruption/lifetime audit. Prefer it only after a measured
process overhead problem. The C API offers asynchronous/yielding solving and
cancellation, but that is not hard memory isolation.

A Rust CDCL solver such as Varisat is a credible alternative, not bit-mask
enumeration. Varisat is MIT/Apache-2.0 and includes a proof-checking module.
However, translating program completion to SAT alone accepts unsupported
cycles. Correct candidate generation needs loop formulas/unfounded-set handling
or a proven equivalent encoding; any SAT proof additionally certifies the
encoding, not the original program without a translation argument. Building
that translation, incremental loop learning and cooperative interruption is
more work than using clingo for this first consumer. Keep the independent GL
checker whichever backend wins later.

Primary sources read on 29 October 2026:

- [Lifschitz, Thirteen Definitions of a Stable Model](https://www.cs.utexas.edu/~vl/papers/thirteen.pdf)
  (local text `/Users/ember/paperbin/lifschitz2008-thirteen-definitions-stable-model.txt`),
  especially reducts, completion and loop formulas. The local Elkan 1990
  rational reconstruction of nonmonotonic TMSs motivates grounded support,
  contradiction handling and why truth maintenance alone is not an ASP solver.
- [Potassco clingo](https://potassco.org/clingo/),
  [source build instructions](https://github.com/potassco/clingo/blob/master/INSTALL.md),
  [MIT license](https://github.com/potassco/clingo/blob/master/LICENSE.md).
- [Varisat API](https://docs.rs/varisat/latest/varisat/),
  [manifest/license and dependencies](https://github.com/jix/varisat/blob/master/varisat/Cargo.toml).
- [clasp exit-code definitions](https://github.com/potassco/clasp/blob/master/clasp/cli/clasp_app.h)
  and [exit-code construction](https://github.com/potassco/clasp/blob/master/src/clasp_app.cpp):
  SAT flag 10, exhausted flag 20, interrupted flag 1. The process boundary
  requires exact agreement: exit 10 / SAT / More=yes / positive model count;
  exit 30 / SAT / More=no / positive count; exit 20 / UNSAT / More=no / zero
  count. All other combinations, unknowns, signal exits and interruption flags
  fail closed before a query can trust absence. Synthetic malformed process
  fixtures cover status conflicts and interruption after a checked base model.

Additional subprocess fixtures author a child that refuses stdin while the
provider writes a pipe-sized program, an overflowing stdout producer, and an
in-flight cancellation after the child records its PID. They assert prompt
inconclusive replies and that the recorded child no longer exists after the
call returns. Fixtures use shell builtins only and spawn no descendants. These
are not hard RSS containment tests; no hard RSS bound is implemented here.

## Runtime and integration boundary

`process::call(json, pinned_absolute_executable, limits, cancellation)` is the
proposed native seam. It does not accept user flags or executable paths in JSON.
The generated source contains numeric atom IDs only, with no scripts/includes.
The adapter clears the child environment, uses one solver thread, caps models
at one more than the accepted limit, drains capped stdout/stderr concurrently,
checks a request-wide deadline/cancellation token, kills/reaps its own child
on failure, and charges encoding/checker work and aggregate solver pipe bytes
across every probe. Source encoding, input parsing and all solves share the
same deadline. Defaults: 256 KiB
input, 1,024 atoms, 4,096 rules, 32,768 body literals, 256 witness models, 2 MiB
aggregate solver pipe bytes, 2 MiB reply, at most 64 KiB stderr per solve,
250 ms and five million encoding/checker/poll work steps. Query solves request
one model; explicit enumeration stops at one more than the accepted cap.
Two-millisecond polling is cooperative and subject to OS scheduling. There is
no hard memory or CPU limit here. The shared host must supply OS containment,
fair admission and executable identity validation before production exposure.
An owned, pinned Linux clingo CLI now exists in central-runner scratch; it is
not installed or admitted to the host. Before host integration,
an operator must admit a particular native solver artifact: pinned version,
platform, executable hash, dependency/notice manifest and qualified exit/output
behavior. An absolute path alone does not establish that identity. This crate
is a proposed adapter and does not implement the operator admission policy.
The adapter expects the pinned native binary not to launch descendants.

## Hosted path

`hosted::call` takes `{"operation": "logic.query"|"logic.enumerate",
"arguments": <request without operation>}` plus operator host JSON
`{"solver": "/absolute/path"}`. The operation ID chooses query or enumeration;
the request may not contain `operation`, and its strict field list rejects any
solver path or flag. The PyO3 exports are `logic_call(request, host_json)` and
`logic_catalog()` behind the `logic` feature. In the service, the operator's
provider entry carries `"solver": {"path", "sha256"}`; the pool copies and
hashes those bytes at startup (a mismatch fails startup), and each worker
re-hashes its copy before passing only that path to Rust. `process.rs` is
unchanged: the same deadline, pipe caps, child kill/reap and inconclusive
replies apply. The pool's per-call deadline additionally kills the worker's
whole process group, which contains the solver child.

Each hosted reply adds `program_identity`, the SHA-256 of the exact
`encode(request)` ASP text. That text is the numeric rule list, so it determines
the set of stable models; it omits labels, queries and scope. `request_identity`
hashes the compact serde JSON of the whole validated request, including
labels, scope, queries and operation. Any future cache should key models on
`program_identity` and audit replay on `request_identity`, never on the
caller's `scope.snapshot` label. `scope.complete_program=true` remains a
caller coverage assertion, not a verified property. The service also requires
`scope.tenant` to equal the host-assigned tenant. Nothing is persisted.

Integration status against the plan below: steps 1 and 2 are done; step 3 is
done for registration and tenant scope (as `logic.query`/`logic.enumerate`,
not `logic.stable_models`), but packaged-executable qualification on Linux and
release-package inclusion remain open. Step 4 has not started.

The planned integration after the current reader/graph/refusal checkpoint was:

1. Root adds this crate to the native workspace, removes its staging `[workspace]`
   stanza, switches serde dependencies to workspace entries, and resolves the
   shared lock once. The central runner has qualified the standalone tests, pinned Linux clingo
   build, timeout, overflow and cancellation fixtures; repeat composition checks
   after workspace changes.
2. Add an optional `logic` feature to `oracle-python`; expose `logic_call` and
   `logic_catalog` beside `reasoning_call`. Detach the GIL, preserve cancellation,
   pass host-owned executable/limits rather than request flags, and map invalid
   input/resource envelopes consistently with other native providers.
3. Register `logic.stable_models` in `tools/oracle_components` with the shared
   host's containment/admission budget and attributable scope/witness evidence.
   Add per-tenant/snapshot refusal tests; do not register permission-demo outputs
   as host authorization decisions. Qualify the packaged executable and feature
   together on macOS/Linux. No appliance admission until that composition runs.
4. Add a real specialist-facing panel consumer and report its own scorer's
   numbers. This lane currently has **no specialist panels or scores**.

Scoped central commands (both test commands have now passed; see receipt):

```sh
cargo test --manifest-path native/oracle-logic/Cargo.toml --test semantics
CLINGO_EXECUTABLE=/absolute/pinned/clingo cargo test --manifest-path native/oracle-logic/Cargo.toml --test semantics -- --ignored
```
