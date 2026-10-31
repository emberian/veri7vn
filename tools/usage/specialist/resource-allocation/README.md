# Exact continuous resource allocation

Choose divisible product quantities to maximize declared profit under complete
supplied resource capacities, minimum quantities and optional quantity limits.
The client declares product units, money units and resource units. Consumption
means resource unit per product unit. Every resource must name every product;
zero consumption is explicit. Unit strings are assumptions; there is no implicit
conversion. Fractions of a batch are permitted. Integer production, real stock
coverage, safety and uncertain measurements are outside this model.

The native operation minimizes the negative profit. Its exact two-phase simplex
proposer uses smallest-index entering variables and basis-index ratio ties to
avoid cycling. Every optimum needs both feasible quantities and nonnegative
original-row multipliers with matching objective. Infeasibility needs a Farkas
contradiction. Unboundedness needs both a feasible base and an improving ray.
Arithmetic, tableau and pivot exhaustion are unknown, never an optimum or proof
of impossibility. The separate feasibility-only operation keeps its old behavior.

After root integrates and enables `reasoning.optimize_linear` in the host:

```
python3 tools/usage/specialist/resource-allocation/examine.py --url http://127.0.0.1:8765
python3 tools/usage/resource_allocation.py supplied-allocation.json --url http://127.0.0.1:8765
```

The client discovers the operation, invokes it, and independently replays its
certificate against the original rows. Optima include product quantities,
profit and row accounting. A row multiplier is in money per row unit and is a
dual certificate, not an unconditional prediction of a future market price.

Six hand-derived cases cover a two-resource corner, fractional production,
inconsistent stock/minimum demand, an unbounded model, zero profit and losses.
Rust tests also compare bounded small polygons against independent intersection
enumeration and cover a classic degenerate cycling instance. No test execution
or panel numbers yet. No Isabelle theorem is claimed. This panel is separate
from the shipped specialist panels and does not replace their scores.
