# A supplied steady thermal network

`science.thermal_network` constructs coupled heat balances from a network of
nodes and passive links. A node has signed applied heat in watts and optionally
a fixed absolute temperature in kelvin. A link has a finite, strictly positive
conductance in W/K. Positive applied heat enters a node; negative heat removes
it. A link's reported positive heat flow goes from its `from` node to its `to`
node. The provider assumes steady state and fixed linear conductances. It does
not infer geometry, material conductivity, heat capacity, weather or HVAC
equipment behavior.

For each link it uses `q_ij = G_ij*(T_i-T_j)`. Each free node obeys
`sum_j q_ij = applied_heat_w`. This is the standard thermal-resistance network
model described in [MIT's thermal resistance notes](https://web.mit.edu/16.unified/www/FALL/thermodynamics/notes/node118.html).
This provider applies that declared model to the supplied graph; it is not a
complete building simulation. For comparison, the
[EnergyPlus heat balance](https://energyplus.readthedocs.io/en/stable/guides/engineering-reference/3.6-inside-heat-balance.html)
also accounts for radiation and convection processes which cannot in general
be replaced by fixed passive conductances.

## An actual coupled balance

[The runnable request](examples/thermal-network.json) has a reservoir at 300 K,
two free nodes `a` and `b`, heat inputs 20 W and 10 W, a 1 W/K link between
them, and reservoir links of 2 W/K and 1 W/K respectively. The provider
constructs, in temperature intervals from 300 K:

```
3*delta_a - delta_b = 20 W
-delta_a + 2*delta_b = 10 W
```

Both intervals are 10 K, so both temperatures are 310 K. Heat flow between
the free nodes is zero; their reservoir links carry 20 W and 10 W. The
reservoir exchange is -30 W, meaning that it removes heat. The result contains
these link flows, each original node's power balance, and the total external
heat balance. `linear_unknown_node_ids` maps the numerical matrix rows,
columns and candidate back to free nodes in the input order.

The JSON arguments are `description`, `assumptions`, `reference_temperature_k`,
`nodes`, `links`, optional `power_tolerance_w` (default `1e-8` W), and optional
`tolerances` with the existing rank/relative-consistency fields. Each node is
`{id, applied_heat_w, fixed_temperature_k?}` and each link is
`{from, to, conductance_w_per_k}`. Names are unique, nonempty and at most 128
bytes. All temperatures are absolute kelvin, not Celsius values or temperature
intervals. The reference temperature only chooses interval coordinates; it
does not establish a boundary or make a floating system physically grounded.

A fixed-temperature node denotes an ideal reservoir able to supply or remove
whatever additional heat is needed. Its `applied_heat_w` is still a prescribed
external source; `boundary_exchange_w = outgoing_link_heat_w - applied_heat_w`
reports the reservoir's additional exchange. This quantity is computed, not an
independent measurement or a finite heater-capacity check. A system consisting
only of fixed nodes needs no linear solve and still reports every heat flow
and reservoir exchange.

## Topology and refusal

Every connected component is reported. A component is grounded if it has at
least one fixed-temperature node. With positive conductances a grounded
component's free-node matrix has full rank in exact arithmetic. A floating
component has one additive temperature freedom, even when it is an isolated
free node. The provider compares this topology-derived rank with the numerical
SVD rank rather than silently inventing a reference constraint. These facts
follow from the nonnegative quadratic form `sum_edges G_ij*(d_i-d_j)^2`;
there is no Isabelle proof claim for this implementation.

- `solved_within_tolerance` means all components are grounded, topology and
  numerical rank agree, original-node power balances pass, and candidates do
  not fall below absolute zero.
- `underdetermined_within_tolerance` means balances and rank pass but at least
  one component floats. Floating nodes return offsets and heat flows; their
  absolute `temperature_k` and `candidate_temperature_k` remain absent.
  Accepted grounded components in the same result retain their temperatures.
- `inconsistent_within_tolerance` means an original-node candidate fails the
  declared power policy or a floating component has a net source imbalance.
  These are numerical checks, not exact impossibility certificates. Candidate
  flows and residuals remain available, while accepted temperatures are absent.
- `numerical_rank_unresolved` means the power checks pass but the numerical
  cutoff lost or retained a direction contrary to the supplied topology. No
  candidate is promoted to an accepted temperature.
- `below_absolute_zero_candidate` means the balance and rank checks pass but
  a grounded candidate temperature is negative in kelvin. No candidate is
  promoted to an accepted temperature.

A floating component with equal positive and negative heat inputs can have
steady flows and temperature differences. A floating component with net heat
input cannot maintain steady state without storage or another heat path. Its
component evidence includes the signed net applied heat and whether that sum
is within `power_tolerance_w + consistency_relative*sum(abs(applied_heat_w))`.

Zero-conductance links must be omitted. Negative or nonfinite conductances,
self-links, unknown endpoints, duplicate node definitions and duplicate
unordered links are rejected. Combine intended parallel conductances
explicitly. Two different reservoir temperatures at different nodes are valid;
two definitions for the same node are a conflict. Nonfinite heat inputs,
negative/nonfinite fixed or reference kelvin, and negative/nonfinite absolute
power tolerances are rejected.

## Power evidence and numerical limits

The adapter uses the existing serial SVD to generate a least-squares candidate
for the constructed free-node system. It then recomputes edge flows and each
node's original power balance. Grounded flows use reconstructed absolute
candidates and the original prescribed boundary temperatures, so a pathological
reference which loses a temperature on reconstruction cannot conceal the
error behind a small transformed-matrix residual.

An original-node power residual passes when its magnitude is no larger than
`power_tolerance_w + consistency_relative*(sum(abs(incident heat flows)) + abs(applied_heat_w))`.
The absolute W allowance avoids treating harmless rounding in a zero-source
equilibrium as a contradiction. This domain acceptance policy is explicit and
distinct from the linear solver's pure componentwise backward-error flag;
both are retained. Every result repeats both tolerances and the physical model.

`conservation` reports total applied heat, total ideal-reservoir exchange, net
external heat, the sum of outgoing internal-link heat over all nodes, and the
sum of original-node power residuals. Internal links contribute equal and
opposite heat by construction; the aggregate can still show floating-point
cancellation. Boundary closure is computed by definition and does not validate
the reservoir assumption. Small residuals do not establish that the supplied
conductances, sources or missing paths are physically true or complete.

The network cap is 128 total nodes and 1024 links. Existing JSON, numerical
work, scratch and cancellation limits still apply, and topology work also
respects the operator's work limit. There is no transient storage, nonlinear
radiation, advection, active heat pump, uncertainty estimate or automatic model
fitting. Fixed conductance can represent an explicitly justified linearized
effect, but the caller must state that approximation. This is an optional
experimental provider for future thermo/HVAC adapters; no specialist panel,
Mini route or deployment qualification has been added.
