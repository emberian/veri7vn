# C02 — Native admission and assurance

Revision 0. This is an implementation contract; the scaffold's native diagnostic
probe does not implement the admission boundary described here.

## Native interface

The admission input is an approved native context, an exact certified target,
declared contextual parameters/premises, an explicit policy, and a candidate native
theorem or implementation attachment. The output is either an opaque accepted
record owned by admission or structured diagnostics. Search and package authors
cannot construct accepted records directly.

Conceptually (not final ML signatures):

```text
admit_consequence(context, target: cterm, policy, candidate: thm)
  -> AcceptedConsequence | Diagnostics
attach_implementation(accepted_contracts, native_definition, representation,
                      code_setup, execution_boundary)
  -> AcceptedImplementation | Diagnostics
```

The accepted record retains actual native objects in their legitimate context.
A JSON name, pretty-printed statement, hash, or prior receipt cannot replace them.
Restoring across processes means resolving/replaying under the pinned generation
and checking the association again.

## Required checks

Admission must account for the complete proposition, exact target instantiation,
hypotheses, explicit premises, type/sort conditions, unresolved flex-flex pairs,
allowed theory ancestry, contextual export, pending derivations, transitive oracle
dependencies, and the policy governing theory construction. A theorem with zero
subgoals and zero oracles may still depend on an unauthorized hypothesis or axiom.
Definitional packages introduce legitimate definitional facts; rejecting every
new axiom-table entry is not an adequate extension policy either.

Context export exposes/discharges assumptions into the resulting sequent; it does
not make those assumptions true. The result retains authorized premises explicitly.
Source reports remain data or scoped premises, never silently installed global
world axioms. Implementation attachment separately validates the connection among
the accepted contract, executable definition, representation, code setup and actual
runtime artifact. A theorem about a reference model alone does not satisfy it.

## Assurance routes

These route names are a shared vocabulary, not a total strength ordering. Issuing
one requires an implemented acceptance procedure and a documented boundary.

| Route | Meaning | Required retained evidence |
|---|---|---|
| `kernel_consequence` | A native consequence accepted under authorized theory/context policy | Exact native theorem and target; premises, sort conditions, generation, completed dependency audit |
| `refined_execution` | A concrete execution is covered by the admitted implementation relation and declared execution boundary | Accepted implementation identity, input/output association, conditions, artifact/code setup, runtime assumptions |
| `oracle_consequence` | A native consequence using specifically authorized computational oracle dependencies | Everything needed for consequence admission plus named allowed/observed oracle dependencies and their execution boundary |

`kernel_consequence` is not a claim that all of Isabelle, the operating system or
the base axiomatic foundation has been independently verified. An ordinary native
result can retain explicit assumptions. `refined_execution` does not manufacture a
native theorem for each invocation. `oracle_consequence` must never be substituted
silently after a stricter request fails. Empirical tests and model scores are useful
development records but are not additional proof routes.

The metadata describing a route is an inspection view of the accepted native
record. No author-supplied `verified: true`, `proof_status`, or route string grants
authority. Portable receipts must be tied to the accepting runtime/generation or
rechecked; cryptographic receipt authentication, if added, remains distinct from
logical justification.

## Required adversarial checks

Reject or retain as a proposal: an assumed false target; undeclared premises;
wrong target; forbidden ancestor theory; hidden oracle dependency; proof skipping;
unresolved constraints; unresolved export; and an execution artifact unrelated to
the theorem. Accept legitimate scoped consequences without misrendering them as
unconditional. Test native namespace/context transport, not only serialized names.

The eventual formal acceptance relation must connect to the actual authoritative
implementation by generation, refinement or checked replay. A separately handwritten
lookalike validator does not close that obligation.
