# C03 — Requests, interpretations, results and diagnostics

Semantic revision 2; descriptor `veri7vn.package/0`. Concrete protocol qualification
is separate from these semantic obligations.

## Request

A request binds correlation ID, immutable environment, observation context (C04),
input, interpretation policy, allowed assurance routes (C02), budget and effects
(C05). Record relevant session/state/time or explicit non-use. Structured input
uses a declared codec or native term/context, not universal HOL-as-JSON. Pretty
printing is not identity.

Retain original bytes and encoding boundary under C04. Derived normalized views
carry maps to original spans, including deletion/expansion. Literal codecs preserve
code, quoted strings, case, whitespace and arbitrary bytes: hashing two spaces is
not hashing one. Record the view actually interpreted.

Semantic profiles declare carriers, representation relations, operations, codecs,
display projections, materialization bounds and evidence obligations. Exact/approximate
numbers, affine points/differences, logarithmic quantities, frames, probability
models and dates/durations retain different laws. Codecs do not serialize authority.

## Interpretation and routing

```text
Resolved(reading)
Ambiguous(nonempty alternatives, separating choices)
Unrecognized(diagnostics)
```

Readings retain source spans, grammar/binding evidence, entity/role choices, target
and conditions. Resolving ambiguity records the choice and decision. A model's
reading remains a proposal until accepted under policy; correctness for that reading
does not prove human intention. Authors can inspect interpretation without execution.

Versioned routing records applicable candidates and blockers scoped to reading,
premise, capability or request. A fallback cannot evade the same failed check;
unrelated justified readings and helpful speech acts remain possible. Distinguish
no reading, unsupported capability, missing dependency, ambiguity, rejection and
established obstruction. Arbitration compares candidates under the same scope/policy,
not first-success order. A new reading requires its own decision.

## Claim scope, response acts and artifacts

Scope/modality, assurance and artifact lifecycle are independent. Preserve asserted,
conditional, quoted, hypothetical and fictional framing; source/engine report,
finite-model prediction, test observation and mathematical consequence are different
claims. Scores retain their kind, population and assumptions; `[0,1]` is not
necessarily probability. Scope belongs in the native target, not merely a badge.

Ordinary users may receive tentative code, tests, reference commands, explanations
or creative artifacts without a universal correctness claim. Passing tests does not
admit/activate code. Reference commands remain data until separately authorized.
There is no empirical fourth proof route. Engine observations bind actual version,
configuration, exact input/setup, output/error and executor boundary; timeout is not
syntax failure. A wrapper does not lift the engine's domain semantics.

Claims bind actual emitted bytes/pixels/content. Metadata or a pre-render plan cannot
prove a property of the final artifact without a serialization/rendering relation
or validation. Illustrations are decoration unless independently licensed as evidence.

## Result variants

```text
Accepted(licensed structured result, interpretation, assurance,
         conditions, dependencies, observation_context)
NeedsInput(alternatives_or_conditions, diagnostics)
Declined(reason, diagnostics)
Inconclusive(reason, searched_scope, diagnostics)
Failed(diagnostics)
Cancelled(diagnostics)
```

Only `Accepted` licenses its exact claim. Timeout, exhausted budget and incomplete
search are inconclusive, never accepted negatives. Missing data does not establish
absence. Existence witnesses do not establish complete enumeration. Conflicting
reports may support a scoped conflict report, not arbitrary conclusions.

Response acts/artifacts are not exhausted by these claim outcomes. Rendering and
persistence preserve polarity, modality, units, numeric semantics, conditions and
provenance. Streaming progress has no acceptance authority.

Multipart requests retain per-subgoal outcomes, interpretations, conditions and
dependency graph. Typed bindings feed dependent nodes; answer prose is not an API.
Independent parts can commit under explicit policy; one answer cannot discharge a
failed dependent part. Collections retain schema, order, multiplicity and coverage:
prefixes are not complete results, NULL is not execution failure, no unique mode is
not missing data. Witness, cost and optimality bounds remain separate.
Speculative consumers may use candidates with unresolved obligations; authoritative
state/claim consumers may not treat them as accepted values.

## Diagnostics

A diagnostic has stable code, severity, readable explanation, source/object locator
and optional counterexample/repair. Categories include:

```text
package.invalid package.unresolved_export environment.mismatch
interpretation.ambiguous interpretation.unrecognized
admission.target_mismatch admission.undeclared_assumption
admission.forbidden_dependency admission.unresolved_obligation
execution.domain execution.budget execution.cancelled
execution.unavailable execution.failure
source.unavailable source.conflict source.coverage_required
```

Details explain the actual failure without secrets/backend dumps. Restricting
`sqrt(x*x)=x` to `x>=0` and changing its result to `abs(x)` are different repairs.

## Semantic target and execution provenance

D30 uses `NoExecution | ExecutableGeneration g`. Semantic equality checks exact
proposition, reading, scope, modality, premises and lineage; execution requirements
are separate. Without an executable-specific requirement, a proof-only kernel fact
can answer a bundle-pinned request. Requiring generation `g` rejects absent/swapped
provenance. Refined execution and the conservative oracle profile require actual
registered request pins. Claims retain their real dependency.

Native gate-owned elaborators derive target and projection from actual objects;
labels or matching numeric IDs do not prove correspondence. Registry ingress rejects
unknown pins; generated control checks compatible dependencies against authentic pins.

## Parameterized requests and output specialization

D34 opens a typed question before its output is known, retaining immutable template,
inputs, graph, scopes, premises and owned result slots. Unbound slots license no goal.
The native gate checks typed substitution; generated control checks one-shot ownership,
current dependencies, scope and cancellation. Preserve original/specialized requirements:
numeric target replacement is not substitution. Each graph node owns its result slot.
Pure computation invents no external attempt; external output binds the actual
confirmed attempt/input. Candidate binding differs from authorized historical retention.
The slot ledger/publication share a durable transaction; restore reconstructs without
recomputation or effects.

## Refuting checks

Exercise ambiguity, source conflict/missingness, conditional consequence, forbidden
route, cancellation and exhausted search. Check literal maps, NULL/blob/prefix rows,
framed/exact values, feasible-but-nonoptimal witnesses, dependent partial turns,
tentative tested code, scoped blockers and final-artifact validation. See
[G01–G04/G08](../review/PREIMPLEMENTATION.md), [domain gaps](../review/domain-gaps.md)
and [runtime gaps](../review/runtime-gaps.md).
