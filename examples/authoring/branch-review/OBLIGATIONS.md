# Review the negative branch

The editable development defines `branch_result x = abs x`. The proposed author
obligation `branch_result x = x` fails for `x = -1`. Its comment deliberately
does not declare a theorem. No capabilities are exported or activated.

Select that exact source span and review one of these distinct changes:

- Condition: require `0 ≤ x` and propose `0 ≤ x ⟹ branch_result x = x`.
  This restricts the domain of the requested equality.
- Obligation: propose `branch_result x = abs x` for all integers.
  This changes the specification of the requested result.
- Example: retain the observation at `x = -1` in the development. A single
  example does not discharge the universal obligation.

The assistance review records the original package manifest and revision, exact
UTF-8 span, diagnostic, selected obligation and explicit meaning decision. Preview
the bytes and review reason before applying. Apply uses the ordinary managed edit
transaction. A changed source rejects the old proposal; cancel suppresses apply.
Reopen and create a new review after a conflict. An applied edit remains editable
source material and requires the normal native build/admission/qualification path.

Native search and retained growth do not yet have a source-bound host operation
available to this assistance adapter. This example makes no search-success or
deployment claim. The broad authoring-assistance task remains open until those
producer operations are integrated into the actual client.
