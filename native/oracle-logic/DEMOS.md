# A reasoning laboratory, before choosing an integration

New exploratory code. It compiles, passes `clippy -D warnings`, and its default
mode runs on macOS ([receipt](../evidence/2026-10-29-experiments-execution.json)). Lane O3 then ran
`--solver` with a locally built clingo 5.8.2 on macOS: all thirteen actual
replies agree with the handwritten status and skeptical/credulous answers, and
a separate full enumeration of each request gives exactly the handwritten
stable models ([hosting receipt](../evidence/2026-10-29-logic-hosted.json)).
There are no panel numbers. The demos are not registered in the service; the
core provider is, as the `logic` profile.
The earlier 18-test receipt qualifies the frozen provider core, not these demos.
Only `examples/**` and this document changed in this sprint. No new dependency,
PyO3/HTTP integration, host registration or action execution.

`examples/reasoning_lab.rs` walks through thirteen revisions/readouts over four
small but useful domains. `examples/support/mod.rs` is reusable scaffolding:
name atoms and rules, attach source descriptions, atomically assert/withdraw
fact tokens, produce a complete snapshot, and explain a supplied interpretation
through finite support rounds. Expected models and answers are handwritten.
`tests/demo_consistency.rs` runs the default mode and checks that the thirteen
handwritten readouts agree with each other and with the builder's rules; that is
a consistency check of the demo layer, not a solver result.

The default executable mode would print newline-separated pretty JSON objects:
the full bounded-program request, handwritten expected answers, named evidence
ledger, revision log and conditional rule traces. An explicit
`--solver /absolute/operator-admitted/clingo` would use the existing provider
API and add an actual reply to each readout. Only the default mode has been
executed. There is deliberately no implicit executable discovery, install,
background process, deployment or automatic action.

## What to inspect in the scenarios

| Scenario and revision | Hand-derived stable alternatives | Intended lesson |
|---|---|---|
| Bird reported independently twice | bird, flies | Default derives from grounded evidence |
| New penguin observation | bird, penguin, flight-exception | Added evidence withdraws flight |
| Penguin token and one bird token withdrawn | bird, flies | Default restored; second source still supports bird |
| Last bird token withdrawn | empty model | No cached flight survives loss of its premise |
| Agent has local and remote analysis tools | local-run or remote-run; both imply planned | Each action is credulous; planned is skeptical |
| Job explicitly confidential | local-run only | A scoped classification blocks a default option |
| Local readiness withdrawn | ask-operator, no planned action | Lack of a feasible action can be a consistent state |
| Classification token withdrawn for replacement fixture | remote-run only | Replan from the revised full program |
| Alert without test observation | sensor-fault or real-event | Alternatives explain the alert; request a discriminating measurement |
| Failed self-test | sensor-fault only | Measurement eliminates an incompatible explanation |
| Incompatible passed test also arrives | no stable model | Preserve conflicting evidence, report inconsistency |
| Misattributed failed-test token withdrawn | real-event only | Explicit provenance-level repair changes the explanation |
| Request activates must-release and must-hold | no stable model | Inconsistent obligations authorize neither action |

Every interpretation in the actual output includes all supporting input facts;
the table abbreviates them. Inconsistent programs get null query answers, not
universal truth. Timeout/cancellation/incomplete search are inconclusive, not
inconsistent. The demos do not simulate those resource failures: the existing
core boundary fixtures cover them.

The diagnosis model intentionally assumes exactly two exclusive causes and a
perfect test. It is a teaching instrument, not a medical or engineering safety
system. It does not infer causality from correlations, assign probabilities,
rank diagnoses, or perform general minimal abduction. The information-gathering
rule checks for absent supplied test observations; it does not pretend a normal
logic rule can inspect all models. The driver separately asks skeptical and
credulous questions to expose that ambiguity.

The agent scenario proposes one next step; it is not a multistep optimal planner.
A safe action executor would need actual observations, an authority boundary,
action costs, effects, failure handling and horizon semantics. Skeptical
`planned=true` does not choose a branch or authorize an action. The policy
conflict example likewise invents no priority between competing obligations.

## The revision layer is the interesting next seam

Facts belong to evidence tokens, not just atoms. Withdrawing `camera/bird`
leaves `keeper/bird` active. Both the inactive token and its source remain in
the ledger. A batch of changes applies to a cloned draft and replaces the live
program only if every token operation succeeds; a typo cannot silently commit
half a revision. Evidence IDs cannot be reused. Atom IDs stay stable as the
program evolves. Queries must name atoms already declared by its rules/facts.

Each snapshot serializes every active rule and fact. There is no incremental
solver cache and no attempt to repair an old answer by deleting its displayed
support: default negation can propagate changes through the entire program.
The existing query backend probes countermodels, so the number of unrelated
alternative models does not force full enumeration. Revision history currently
uses a local topic plus counter for snapshot names; this is an exploratory
label, not a globally unique or content-addressed identity. More specifically,
the public `rule()` and `atom()` builder methods can mutate even one Program
after a revision or request without advancing that counter: the same instance
can therefore emit different programs under the same `scope.snapshot` value.
The current scenarios finish policy construction before their first revision,
and there is no cross-snapshot cache. Before adoption, either seal policy/atom
construction once revisions begin, or advance/hash identity for every program
change. The current snapshot string must never be a cache key or durable
evidence identity.

Conditional explanations expose positive supports, exact rule/evidence IDs,
source descriptions, and default assumptions absent from the supplied model.
They compute finite rounds from facts, rather than offering a positive cycle as
its own justification. They list alternate fired supports as well as the first
one. These traces explain a *particular interpretation*: they do not establish
that it is stable, or prove a skeptical/negative conclusion. The independent
core GL checker admits actual model witnesses; UNSAT-dependent conclusions
still trust the pinned solver. There is no public-source completeness claim.

## Design findings worth choosing between

1. **Keep revisions above the solver.** A small evidence/program layer gives
   useful retractions, source repair and reviewable assumptions without changing
   stable-model search. Promote it only after deciding its identity and error
   contracts; currently builder misuse can panic and revisions clone small
   programs. Production would want typed fallible construction, limits before
   allocation and stable content hashes over rules, evidence and scope.
2. **Separate possible actions from commitments.** Credulous action candidates
   are natural plans. Skeptical invariants are useful guards. Neither picks an
   action. A later planner may rank finite plans or add explicit action/time
   atoms, but should not hide choice inside an arbitrary solver model.
3. **Make evidence repair visible.** The diagnosis trace retains both conflicting
   observations and names the token eventually withdrawn. A next experiment
   could propose minimal evidence withdrawals as *repair suggestions*. That
   needs an explicit optimization/abduction contract and source trust policy;
   silently dropping a constraint would change the question.
4. **Distinguish explanations from certificates.** Named finite support traces
   are useful now; absence explanations need the exact constrained probe and
   solver identity, not just a model's missing atom list. The frozen API currently
   returns model witnesses and truth values but no per-probe certificate/trace.
   A future evidence envelope could carry query polarity, constraint, exit/JSON
   status, source snapshot hash and resource termination reason. That is a
   concrete interface improvement to consider, not a reason to integrate today.
5. **Closed-world scope must be deliberately manufactured.** All scenarios are
   complete supplied finite programs with explicit local policies. Missing facts
   from public retrieval remain unknown. A future caller could materialize a
   bounded planning state from known observations while keeping unknown inputs
   as explicit atoms rather than defaulting a public knowledge base to false.

A useful next experiment is richer time-indexed replanning or explicit
minimal-repair suggestions over these same provenance tokens. Neither needs a
web endpoint. The implementation sprint can continue in this laboratory until
its interfaces and limitations are worth admitting to the host.

## Try evidence revision through the Rust host

`tools/usage/hosted_reasoning.py` is a Python standard-library consumer of the
[Rust appliance host](../docs/HOST.md). Start the packaged Rust host with
its optional `logic` profile and operator-admitted solver, then run from the
repository root (replace the address with the host's configured listener):

```sh
python3 tools/usage/hosted_reasoning.py --url http://127.0.0.1:8765 --tenant reasoning-demo
```

It discovers both live operations under `/operations/{id}`, then calls
`/invoke` for both querying and enumeration at each of five revisions. The
finite local policy concerns a build dependency: a ready dependency normally
permits two alternative candidates, reusing a cache or rebuilding. Neither
candidate is selected or executed. A scanner's compromise report defeats the
default; an auditor's clean report then conflicts with it under an explicit
local integrity constraint. Withdrawing the mistaken scanner token restores
the candidates. Withdrawing the dependency observation removes both again.
Every output line includes the evidence ledger, scope, conclusions and both
host replies. All observations are manufactured examples.

The client checks the exact returned scope and content identities, independently
rechecks every returned stable-model witness, and rejects malformed replies
instead of substituting expected answers. It compares the two operations when
enumeration completes. Skeptical means present in every stable model;
credulous means present in at least one. Inconsistent means the complete local
policy and observations admit no stable model. Unknown means a search did not
settle a question, or (separately, in `external_approval`) neither an approval
nor a denial was observed. Absence of those observation atoms in this supplied
program does not establish anything about real approval. False in the local
program is printed separately from unknown.

Each revision sends the whole program. Evidence tokens cannot be reused;
withdrawn observations remain visible. Snapshot labels cover policy, provenance
and revision history; the host additionally supplies its own program/request
hashes. Witness checks are handwritten Python/Rust, not Isabelle proofs.
Absence and enumeration completeness still trust the admitted solver, without
a certificate. This client is untrusted and creates no deployment authority.

Calls have no automatic retry. `--retries 1` explicitly allows repeating a
pure call after transport failure or HTTP 429/503; request IDs correlate calls
and make no promise of durable replay. No Mini application is required.

Focused client checks:

```sh
python3 -m unittest discover -s tests/usage -p test_hosted_reasoning.py
```

Those tests use an independent small subset-minimal-reduct oracle and
hand-derived model fixtures. They test the client contract and revision logic;
The [31 October receipt](../evidence/2026-10-31-host-validation.json) records
two launches of a relocated Linux Rust package, each running both operations
through all five revisions. No specialist panel numbers are claimed for this
workflow.
