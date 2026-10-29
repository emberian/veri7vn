# Conditional formula composition — exploratory, uncompiled and unmeasured

This isolated crate extends the current polynomial idea to rational formulas.
It has **no specialist-panel numbers**, builds, executed tests, benchmarks or
new Isabelle theorem. It changes no production path or existing SML kernel.
Dependencies already used by native reasoning are declared without fetching.

The useful new boundary is a typed shared expression DAG and a small replay
checker. Nodes carry exact rational constants and coherent linear SI dimensions.
Repeated construction returns the same node ID. Addition rejects incompatible
dimensions before optimization; multiplication/division add/subtract exponents.
Zero is explicitly typed rather than allowed to erase a bad original addition.

The untrusted proposer offers three identities: `x/x -> 1`, `(a*b)/b -> a`,
and `a/d + b/d -> (a+b)/d`. The first two require a demonstrable nonzero
denominator. Closed rational intervals excluding zero provide positive/negative
facts, with sign propagation through products and quotients. The last identity
preserves its denominator and needs no nonzero assumption to preserve its
partial-function domain. An independent replay checks structural identities,
dimensions and conditions; congruence judgements allow a later planner to
compose these steps inside larger expressions. It never trusts an e-class merge.

`src/main.rs` authors concrete assertions for a mechanics composition: kinetic
plus spring energy per unit mass. `(K/m)+(S/m)` becomes `(K+S)/m`, retaining the
specific-energy dimension `[2,0,-2,0,0,0,0]`. At K=12 J, S=6 J, m=2 kg,
the hand calculation is 12/2+6/2=(12+6)/2=9 J/kg. A larger formula registry
could reuse this same mass node and the same normalized total-energy expression
across requested outputs. The selected formula contains one division rather
than two. That is an expression property, not a measured speedup.

Hand walkthroughs, not execution receipts:

| Case | Expected mechanics |
| --- | --- |
| `x/x`, no range | proposer retains original; forged SelfDivide replay fails |
| `x/x`, x in [1,10] from supplied-range | replay permits 1; x=2 evaluates to 1 |
| Same receipt after range withdrawal | snapshot comparison rejects replay and executable handle use |
| Same receipt, x=0 despite [1,10] | actual input-range check rejects before selected evaluation |
| K+m | DAG constructor rejects energy plus mass |
| K/m+S/m at m=0 | fusion is checkable, evaluation rejects original singular point |
| `(a*b)/b` with b containing a singular division | sign may prove nonzero where defined; original evaluation still rejects the singular input |

An executable handle borrows its immutable DAG and stores its exact assumption
snapshot. It cannot be replayed against a different DAG or silently reused under
withdrawn assumptions. Every evaluation checks the supplied bounds and evaluates
the original expression first, then the selected one with a shared memo. This is
deliberately conservative: it establishes an executable original-domain barrier,
but currently does **more** arithmetic than simply evaluating the original.
The candidate is useful as a checked formula/composition artifact now; runtime
savings would require a domain-obligation execution plan which checks original
denominators without recomputing all original numerators, then measurements.

Limits: rational arithmetic has no bit/work budget here; node/proof counts are
capped but these are not hostile-input hosting limits. Recursion follows a
4096-node DAG and has no separate stack-depth cap. Interval assumptions are
caller-supplied premises, not physical facts or measured confidence. Bounds are
on variables only, one interval per variable; open intervals, disjunctions,
addition sign inference, transcendental functions and nonlinear solving are
absent. No parser, serialized receipt transport, stable content digest, e-graph,
global cost search, floating-point equivalence or conditioning claim is made.
The full original-domain evaluation means no cancellation can remove a required
input or singularity. Exact arithmetic can still exhaust resources.

Recommendation: retain this experiment as a reviewable design probe; do not
admit it as a hosted provider yet. First compile and run the authored driver,
review replay for counterexamples, add rational work/bit and depth budgets,
then connect one supplied mechanics model and compare scoped panel behavior.
No new build or test was run for this sprint, as requested.
