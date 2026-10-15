# C03 — Requests, interpretations, results and diagnostics

Revision 0. These are shared semantic variants; wire encoding and concrete ML
signatures are **reserved**, pending the first integrated native client.

## Request

A request has a correlation ID, a pinned immutable environment and a request
observation context (C04), input, an interpretation policy, explicitly allowed
assurance routes (C02), and an execution budget/effect policy (C05). The observation
context names the relevant session/state versions and evaluation time with its clock
basis; explicitly stateless/timeless work records that distinction. Follow-up answers
and freshness decisions must not silently read whichever state or wall clock happens
to be current. A natural-language input is text plus source spans. A structured input
uses a declared capability-specific codec or a native term in its context; there is
no universal JSON encoding of arbitrary HOL values. The input's pretty printing is
never treated as its semantic identity.

Resolved inputs are explicit interpretations. Each interpretation records its
originating spans, recognized grammar/rule bindings, entity/role choices, native
target and still-open conditions. A model-generated reading is a proposal until
the chosen interpretation policy accepts it. Correct reasoning about one reading
does not prove that it captures the human's intended question.

Interpretation produces one of:

```text
Resolved(reading)
Ambiguous(nonempty alternatives, separating choices)
Unrecognized(diagnostics)
```

Resolving ambiguity must retain the selected interpretation and the decision that
selected it. Dispatch order is not permission to discard meaningful alternatives.
The engine must support author inspection and repair of interpretation independently
of executing a specialist.

## Result variants

```text
Accepted(licensed structured claim/result, interpretation,
         accepted assurance record, explicit conditions, dependencies,
         request observation context)
NeedsInput(alternatives or missing conditions, diagnostics)
Declined(reason, diagnostics)
Inconclusive(reason, searched_scope, diagnostics)
Failed(diagnostics)
Cancelled(diagnostics)
```

`Inconclusive` includes timeout, budget exhaustion and incomplete search. It is
never an accepted negative answer. A missing store is a dependency failure, not
evidence that no matching fact exists. A successful existence witness and a complete
enumeration of all results require different evidence. A conflict can be an accepted
structured report *about conflicting source statements*, provided that is the exact
licensed claim; it is not unrestricted permission to infer from contradictory facts.

Only `Accepted` carries an accepted assurance record. Empirical candidates remain
proposals available for development/inspection, never silently placed in that variant.
Conditions and provenance are retained even if ordinary UI text is concise. The
renderer must preserve claim polarity, scope, units, numeric semantics, alternatives
and conditions. Streaming progress events have no answer-acceptance authority.

## Diagnostics

A diagnostic contains a stable code, severity, author/user-readable explanation,
relevant source spans or object locators, and optional counterexamples or proposed
repairs. The initial vocabulary is:

- `package.invalid`, `package.unresolved_export`, `environment.mismatch`
- `interpretation.ambiguous`, `interpretation.unrecognized`
- `admission.target_mismatch`, `admission.undeclared_assumption`,
  `admission.forbidden_dependency`, `admission.unresolved_obligation`
- `execution.domain`, `execution.budget`, `execution.cancelled`,
  `execution.unavailable`, `execution.failure`
- `source.unavailable`, `source.conflict`, `source.coverage_required`

Codes identify the category; structured details explain the actual failure.
Do not put secrets or unrestricted backend dumps into user-facing diagnostics.
Repair proposals distinguish changes that preserve intended meaning from changes
to the domain/specification. For real square roots, restricting `x >= 0` and changing
`sqrt(x*x) = x` to `sqrt(x*x) = abs(x)` are different repairs.

## Cross-lane checks

Exercise a resolved mathematical request, ambiguous entity, missing source,
conditional theorem, source conflict, forbidden assurance route, exhausted search,
and cancelled request end-to-end. The client must not turn any non-accepted variant
into success, strip a premise from an accepted claim, or confuse an old generation's
answer with a current one.
