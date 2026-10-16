# Exact finite models and descriptive statistics

`src/families/domains/finite` shares Isabelle's native `rat` with the other
exact families. Lists represent multisets: duplicate observations contribute
mass. `PartialPopulation` cannot produce an exact normalized event probability. Its
closed reply is `FiniteIncomplete`, and typed plans preserve an unresolved
completeness blocker instead of conflating it with an invalid model.
`CompletePopulation` describes a closed supplied model; it does not certify that
an external source enumerates the world. Source closure and model premises must
be retained by the existing request owner before a result becomes authoritative.

The executable definitions cover uniform and nonnegative weighted finite event
probabilities, mean, median, modes, range, sample/population variance, exact centering, z-scores with a supplied positive
rational standard deviation, named n/k
selection counts, binomial probabilities, fair independent repeated die events and enumerated dice totals,
replacement-sensitive all-success draws, one-locus gamete products, and
Hardy–Weinberg genotype shares from an explicit rational q. Modes always return a
collection, including all tied maxima; an empty input returns an empty collection.
Mean/median/range and population variance reject empty input; sample variance
requires at least two observations. Named n and k are never silently exchanged.
Invalid die models are rejected; a face outside a valid die is an impossible event
with zero probability. Zero repeated trials is well-defined and yields zero
at-least-one probability. Weighted models reject negative mass and zero total mass.

`Finite_Plans` instantiates the existing `typed_plan_bundle`; it does not add a
platform-wide value sum. `finite_dispatch_refinement` relates the closed executable
operations to `finite_meaning`. `finite_execution_refinement` relates the request
and full reply including condition identifiers. A result containing those IDs is
not, by itself, authority for the referenced conditions. Native admission, current
owner validation and structured result issuance belong to the existing runtime
boundary. The component cannot mint accepted native results.

Source interpretation follows the audited Oracle7 games/statistics/genetics
profiles. Exact rational results repair their float-only projections. Statistics
V2's named selection order repair is preserved. Alleles are native case-sensitive
characters; the single-locus crossing kernel never lowercases them. Supplied
recessive character is explicit, and the finite uniform product is a model,
not a biological population observation. Hardy–Weinberg requires the equilibrium
model and q in [0,1]; inferring irrational q from a phenotype share, approximate
standard deviations, multi-locus validation/independent assortment, poker category
exclusions, anagram case policy, efficient dice convolution, source recognition and resource
qualification remain required breadth. No original manifest is claimed lifted.

`Finite_Regression` contains kernel-checkable target statements. The independent
Python reference enumerates small spaces to derive those targets; running it is
not a test of generated Isabelle execution. Native session and production
consumer validation are recorded by the integration/build owner.

The fixed `Veri7vn_Finite_Execution` adapter binds the admitted universal contract,
code identity, bounded rational conversion, original certified input, managed
request and generated output. Selection counts and repeated-trial parameters have
explicit magnitude guards before evaluation, alongside syntax, time and projection
bounds. These declines are operational limits, never zero probability claims.

`Veri7vn_Finite_Scoped_Request` consumes an actual original `Scope.child` and managed
source/development owners. It reads the original literal statistics request itself,
retains the child, checks physical source identity and generation, and binds the
actual opaque output to a structured native answer. This initial literal profile
uses no adopted external conditions: its collection is the explicitly supplied
list, not a claim about an unseen population. Its certified result target is
syntax associated with the admitted implementation and runtime output, not a
per-answer kernel theorem. The generated Owner and fixed service factory must
still license execution/publication through the runtime-refinement route.

The finite test session exercises real native prepare/execute/project and the
scoped original-source path, including cross-instance/request, oversized-model,
retirement and denial cases. They are awaiting the shared build owner's first
compiler/execution qualification. Persistent recovery and installed service/client
integration remain open consumers.

`fair_rolls_mass` connects dice-total enumeration to the exact closed mass
`sides^dice`. Runtime dice-total enumeration is capped at 65,536 outcomes; this
is an explicit workload guard, and no efficiency claim is made for enumeration.

The checked-plan regression composes exact centering into sample variance over
the produced collection, retaining inherited condition identifiers in order.
Those identifiers are not adopted condition objects or source-coverage proofs;
a future real-source bridge must bind them to the existing managed conditions.

Compatibility is explicit: Oracle7 statistics V2 withholds binomial k>n and games
withholds out-of-range dice sums. Here a valid finite model can return zero mass
for an impossible event; invalid parameters still reject. This is a mathematical
repair/extension rather than byte-for-byte source behavior. The source's no-unique-
mode `None` becomes a collection of all maximizing values, including all values
when every observation occurs once. The initial literal reader is deliberately a
scoped grammar and does not claim the full V3 dataset/cue/recognition behavior.

The optional `Veri7vn_Finite_Service` child fixes the existing curated ticket
worker functor to `Veri7vn_Finite_Execution`. It reuses the actual ticket
consumption, charge equality, single-request ownership, cancellation and output
cleanup protocol rather than implementing a second permission machine. The
state owner supplies its existing opaque ticket view during final fixed service
assembly. This child currently imports the existing domain service objects to
reuse that mechanism; it is separate from the pure and runtime first-check
closures. Actual owner/factory instantiation and publication remain unqualified.
