# Balance supplied species with exact conservation

`chemistry.balance_reaction` finds coefficients that conserve the declared
element and isotope inventories and electric charge. Supply every species,
its reaction side, its complete composition and its signed charge. Names are
display labels; the service does not parse formulas, look up chemical identity,
or add water, protons, electrons or other missing species.

The operation is part of the optional `reasoning` native profile. Run the
[standalone native service](STANDALONE.md) with an extension containing this
operation and an operator-selected extension hash. Existing host enablement,
worker limits and tenant admission still apply. No additional profile or
request-controlled activation is needed.

For local development, the examples below use the standalone service's example
64-character routing key. In a hosted deployment the trusted bridge supplies
that key; the header itself is not authentication. First inspect the actual
operation and its current `chemistry_limits`:

```sh
curl -sS http://127.0.0.1:7071/operations/chemistry.balance_reaction \
  -H 'X-Mini-Oracle-Tenant: aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
```

## Neutral combustion

Supply ethane and oxygen on the reactant side, with carbon dioxide and water
on the product side:

```sh
curl -sS http://127.0.0.1:7071/invoke \
  -H 'Content-Type: application/json' \
  -H 'X-Mini-Oracle-Tenant: aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' \
  --data-binary @- <<'JSON'
{
  "request_id": "ethane-balance",
  "conversation_id": "chemistry-example",
  "operation_id": "chemistry.balance_reaction",
  "arguments": {
    "species": [
      {"name": "C2H6", "side": "reactant", "composition": {"C": 2, "H": 6}, "charge": 0},
      {"name": "O2", "side": "reactant", "composition": {"O": 2}, "charge": 0},
      {"name": "CO2", "side": "product", "composition": {"C": 1, "O": 2}, "charge": 0},
      {"name": "H2O", "side": "product", "composition": {"H": 2, "O": 1}, "charge": 0}
    ]
  }
}
JSON
```

The positive balance has coefficients `['2', '7', '4', '6']` in input species
order: `2 C2H6 + 7 O2 -> 4 CO2 + 6 H2O`. The conservation diagnostics give
carbon totals 4, hydrogen totals 12, oxygen totals 14 and charge totals 0 on
each side. These are exact integer totals for the declarations above.

## Ionic redox with an explicit electron

This acidic permanganate half-reaction supplies protons and electrons directly.
An electron is represented by empty composition and charge `-1`; other empty
compositions are rejected.

```sh
curl -sS http://127.0.0.1:7071/invoke \
  -H 'Content-Type: application/json' \
  -H 'X-Mini-Oracle-Tenant: aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' \
  --data-binary @- <<'JSON'
{
  "request_id": "permanganate-half-reaction",
  "conversation_id": "chemistry-example",
  "operation_id": "chemistry.balance_reaction",
  "arguments": {
    "species": [
      {"name": "MnO4-", "side": "reactant", "composition": {"Mn": 1, "O": 4}, "charge": -1},
      {"name": "H+", "side": "reactant", "composition": {"H": 1}, "charge": 1},
      {"name": "electron", "side": "reactant", "composition": {}, "charge": -1},
      {"name": "Mn2+", "side": "product", "composition": {"Mn": 1}, "charge": 2},
      {"name": "H2O", "side": "product", "composition": {"H": 2, "O": 1}, "charge": 0}
    ]
  }
}
JSON
```

The coefficients are `['1', '8', '5', '1', '4']`. The reactant charge total is
`-1 + 8 - 5 = 2`, matching the product charge total. Manganese, oxygen and
hydrogen inventories also match. No acidic environment or chemical occurrence
is inferred from those equalities.

## Read the answer

The HTTP envelope places the adapter answer under `reply`; the full native
result is `reply.result`, with schema `oracle-stoichiometry-v1`. It retains rank,
nullity, the complete rational nullspace basis, free species indices,
coefficients, conservation totals and bounded-search diagnostics. Columns and
coefficients follow input species order. Basis vectors describe the full
rational solution space through their linear combinations.

| Native `result.status` | Adapter result | Meaning |
| --- | --- | --- |
| `unique_positive` | `answered`, `answer_kind: positive_balance` | A one-dimensional solution space yields one primitive strictly positive integer balance, up to positive scaling. |
| `multiple_with_positive_candidate` | `answered`, `answer_kind: positive_balance` | A larger solution space contains a found primitive positive candidate; the response retains the other degrees of freedom. |
| `no_nonzero_balance` | `answered`, `answer_kind: mathematical_negative` | The supplied signed conservation matrix has no nonzero balance. |
| `no_strictly_positive_balance` | `answered`, `answer_kind: mathematical_negative` | Its one-dimensional solution space cannot assign every supplied species a positive coefficient on its declared side. |
| `multiple_search_inconclusive` | `withheld`, `reason: positive_balance_search_inconclusive` | The finite positive-coefficient search found no candidate. The complete basis remains available; impossibility has not been established. |

The two mathematical negatives concern the exact supplied inventory and sides.
They do not say that a real-world reaction is impossible. A different species
list or corrected composition changes the mathematical question.

All input atom counts are positive u64 JSON integers and charges are i64 JSON
integers. Use serialization that preserves those integers exactly; floating
point counts and string counts are rejected. Output coefficients and
conservation totals are decimal strings, and basis entries are integer or
rational strings such as `1/2`. No floating point approximation is used.

Element labels must be actual symbols, optionally followed by an isotope mass
number such as `C-13`. An isotope label and an unspecified element label are
distinct conserved inventories. Accepting a label does not validate that a
nuclide or chemical species exists. Each species needs a unique nonblank name,
and both sides must be present.

## Limits and assurance

Discovery reports the bound native catalog's `chemistry_limits`: species and
conserved-row ceilings, integer bit growth, counted arithmetic work,
free-coordinate search bound and candidate count. Charge uses one conserved
row. Elimination, positivity search and independent inventory replay share an
arithmetic budget; resource exhaustion withholds the answer. Host request and
reply byte limits also apply, including the full retained basis.

A positive candidate is replayed over the original supplied compositions and
charge, independently of the elimination matrix. The native checker requires
strictly positive integer coefficients with greatest common divisor one. In a
multidimensional solution space, that does not guarantee the smallest total
coefficients or any other global optimum. Rank and basis are exact computed
outputs, without an independent rank certificate or Isabelle theorem.

Conservation establishes neither physical feasibility nor reaction conditions,
thermodynamics, kinetics, valence or identity. The direct native library's
budgets are cooperative; the standalone service separately enforces its
process wall-time/cancellation boundary. The operation remains an experimental
computation with no specialist-panel score or Mini release admission claimed.
