# Native strategies

The first concrete producer searches actual Isabelle proof states. It prepares a
certified target and curated theorem catalogue in an actual opaque registry
generation, resolves names once to native theorem objects, and retains that exact
context. Receiver and worker generations are distinct pinned native objects;
the certified original target belongs to the receiver and transfers to its worker
descendant. The static factory exposes `Search` plus opaque job/output operations; its producer
implementation remains lexical-private. The public policy contains only catalogue `Retrieve`, `Apply`, explicit-fact `Simplify`,
conjunction `Split`, implication `Introduce` and `Assume`. It cannot supply ML,
Isar, method text, arbitrary callbacks or its own accepted theorem flag.

`Veri7vn_Search_Fn(Tickets)` is the sole producer entry. Its consume-only ticket
view comes from the final private host assembly. `start` consumes an already
charged one-shot pure-operation ticket and checks its actual opaque instance,
operation, executable pin, prepared target request and both registry generations, plus
the exact generated `search_work_cost` for the prepared bounded run. It forks a fixed worker; cancellation is a synchronized flag checked
between bounded actions, and join suppresses a late proof proposal after
cancellation or instance/input revocation. A prepared request is owned once; a
second concurrent start fails. Join consumes the future and clears native inputs,
explicit output release clears trace/proposal cells, and cancel stops, joins and
releases. The separate request_cancel operation permits collecting a cancellation
trace. Instance release revokes and clears its outstanding prepared inputs. Host hard process limits/current association validation remain
separate requirements. Preparation alone licenses no execution or acceptance.

The FIFO search keeps alternate proof routes and records the original subgoals,
selected action and advanced/failed/blocked/timed-out result for every attempt.
It currently performs no live-state deduplication. Retained successors have at
most 256 subgoals and 20,000 term nodes; the queue has a 200,000-node weight cap,
and the trace has at most 10,000 events and a bounded term-node weight. These are
representation bounds after native tactic evaluation, not process memory bounds. Expansion, frontier, successor,
per-action time and total wall-time bounds are explicit. Frontier overflow stops
with remaining goals rather than silently pruning and claiming completeness.
`Exhausted` means only this finite action policy had no remaining route; it is not
refutation. Budget/deadline/cancellation have separate outcomes. An actual theorem
is converted to bounded inert `Veri7vn_Proof_Transport` bytes, never a serialized
`thm` handle. A receiver reconstructs and audits against its immutable exact
claim, hypotheses, premises, sorts and lineage using native admission. Strategy
success is not native admission or a durable output-slot binding.

The checked `Native_Search_Tests` consumer starts through a test-only issuer,
requires implication introduction plus conjunction splitting and assumptions,
retains a failed `TrueI` alternate route, uses a worker-private conjunction lemma,
expands it relative to the pre-lemma receiver, transports the produced proof, and asks
the receiver to admit the exact original target. It also rejects ticket replay, equal-cost foreign instances and concurrent
ownership of one prepared target, and suppresses late cancelled proposals.
The worker requires native proof recording; it checks that configuration and does
not change global settings. Fresh compilation attempt
`cca545138fa14f02907589a0760d3837` built the producer and consumer. Stable scoped
attempt `0355b13cd3134eeb8ec046482c2a4fb1` then passed all six runtime markers:
exact-target receiver admission, consumed-ticket replay rejection, exact-instance
single ownership, late cancellation suppression, budget/exhaustion separation
from refutation, and multipart scope/budget preservation. The receipt is under
`var/native-scaffold/sessions/22e454997eddee6d/attempts/` and records stable source
hashes. This validates the fixed native producer and receiver test consumer;
production service registration remains open.

`Veri7vn_Strategies` models a finite scheduled worklist with per-goal candidates,
refutations, scoped route failures and blockers. Its theorems state positive
per-attempt charge, a total fuel charge bound, cancellation without work and that
route failure/candidate recording does not create refutations. Its family `run`
parameter is specification notation, not an exposed runtime callback. The ML
producer is not yet proved a refinement of that scheduler model. Existing plan
search observation-equivalence theorems may justify a future finite pruning rule;
this implementation does not pretend state/target equality alone preserves
resources, guards and history.

## Growth breadth and remaining integration

The actual upstream mechanisms remain distinct: w32 selects hand-written
catalogue programs and executes toolchains; w37 reads ordered typed pipelines,
emits programs and compares sample outputs to a differential oracle; w482/w486
connect bounded typed enumeration to retained organization/library behavior.
Their samples and retained candidates are not universal proof. Native declaration
actions distinguish catalogue synthesis, pipeline synthesis and typed enumeration,
as well as witness, counterexample, conjecture and refinement proposals. These
broader actions are modeled but not yet implemented by this first proof producer.
They require fixed admitted family operations, exact scopes and obligations,
actual isolated per-job learning state, proposal retention/recovery and native
publication paths. No generic enumerator or fixed proof fixture satisfies them.

Outstanding deployment gates include the host's closed static strategy-family
registration and exact code/profile pin, actual charged job/process lifecycle,
private-input/current-dependency validation, receiver recovery and durable final
slot binding, hostile/late/multipart tests, trace/term memory bounds and measured
costs. The current structural cost is conservatively derived from maximum
expansions, catalogue/action count, successors and frontier; it is not an empirical time or
memory guarantee. Search policy cannot issue tickets, mutate the durable writer
or replace the non-rebinding native gate. New native action kernels require a new
qualified executable; ordinary curated catalogues/policies reuse the fixed
interpreter under exact context identities.

## Exact mathematical candidate policy

`search/mathematics/Mathematics_Proposals` now uses the existing mathematical
family's actual `math_expr`, `math_eval` and independent `math_value` relation.
It builds a capped finite expression grammar from explicitly named atoms using
negation, absolute value, addition, multiplication and division. Binary pairing
limits each prefix before allocating its Cartesian results. Each layer has at
most the requested cap; the operator ordering and per-layer cap define this
particular search space. There is no completeness claim over all expressions,
minimality claim or observational-equivalence pruning.

Candidates retain exact sample bindings and expected option values: a missing or
undefined evaluation remains `None`. `proposed_candidate_scope` characterizes
exactly the named finite enumeration and those samples.
`proposed_defined_samples_native` connects every defined matching sample to the
family's native mathematical value relation. `counterexample_native_values`
connects a concrete unequal-value witness to both native meanings. The explicit
`sample_agreement_not_universal` counterexample shows zero and the identity agree
at input zero but differ at one. The pending generated fixture discovers a
doubling expression from two samples while preserving division-by-zero partiality.

This is a typed enumeration proposal policy, not the other two upstream growth
mechanisms. It is not yet connected to the production mathematical bundle's
reflected carrier and actual evaluation tickets. Production must reuse that same
type mapping and native operation/profile rather than cast a separately generated
expression datatype. Learned-library retention, ordered pipeline differential
samples and external catalogue toolchain observations retain their separate
integration gates above.


## Finite producer check and actual service consumer

The first native consumer batch additionally contains a one-expansion multistep
goal producing `BudgetStop`, and an unprovable `False` goal under the declared
assumption-only action list producing `Exhausted`. Both require retained attempted
route traces; neither outcome is a refutation. The charge, cancellation and failure-versus-refutation
scheduler laws, multipart fixture and native runtime cases have checked in the
scoped attempts above.

Assembly owns the next shared service registration after its current service
baseline. Its request must hold the exact opaque prepared target/fact objects,
receiver and worker generations, actual operation/profile/code pin and current
native association. The actual owner durably charges and acknowledges generated
`ExecutePure` before issuing the private ticket. Authoring has this shape but
exposes no alternate raw issuer or formula callback. A final proof claim keeps
its original target and kernel-consequence requirement; the charged search
computation is a separate execution requirement. An inert proof proposal becomes
a managed proof-wire source and independent native reconstruction before any
replayable descriptor/publication, never metadata-as-proof.

Installed `Timeout.apply` ignores durations below one millisecond. The producer's
wrapper explicitly refuses such a remaining duration instead of accidentally
starting an unbounded late action or proof export. Total-time, per-action-time and
proof-transport bounds still do not establish an OS memory/process guarantee.
