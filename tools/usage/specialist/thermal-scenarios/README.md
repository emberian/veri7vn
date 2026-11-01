# Supplied thermal scenarios

Compare a supplied board hotspot, case and ideal cooling boundary at three
heat loads and reservoir temperatures. The example asks for local effects of
heater power and each cooling conductance. It solves one fixed positive linear
network using one retained dense SVD and checks every original node's power
balance for every scenario. It also checks each differentiated free-node balance.

Run against the standalone host with science enabled:

```
python3 tools/usage/thermal_scenarios.py --url http://127.0.0.1:8000
python3 tools/usage/specialist/thermal-scenarios/scorer.py --url http://127.0.0.1:8000
```

`panel.json` supplies nine independently calculated workflow cases. Its literal
answers use series thermal resistances, not the implementation's matrix code.
The scorer reports right, wrong, false yes and execution errors; transport failure
is not a correct refusal. These are new workflow cases, not Oracle7's shipped
specialist-panel numbers. No panel run or completion score is claimed here.

Every node must connect to a fixed-temperature boundary. Each scenario supplies
complete heat and temperature vectors in the network's node order; only existing
boundary values may vary. Preparation validates the base values and physical
model declarations but does not solve the base load case. Its finite loads may still produce an impossible
or numerically unrepresentable steady state; only requested solves assess that.
A content hash includes the complete ordered input and numerical policy.
There is no global mutable factor cache. Dense serial SVD follows the existing
small-network rank policy; no speed advantage over sparse factorization is
claimed without measurement. Preparing a network validates topology, assembles
the reduced operator and factors it once. It does not perform an initial load solve. Every requested
scenario rebuilds only the right-hand side from loads and current fixed values,
then reuses the stored topology and factors. The scenario and sensitivity
counters count the requested solves.

The consumer independently recomputes original-node power from returned absolute
temperatures and supplied conductances. Boundary exchange closes ideal reservoir
balances; it is not an observed cooling capacity. Load sensitivities use K/W;
conductance sensitivities use K/(W/K). They hold boundary temperatures and all
other parameters fixed. A load at an ideal boundary changes reservoir exchange,
not its temperature. There is no boundary-temperature derivative operation.

This assumes steady passive constant-conductance conduction. It cannot describe
advection, radiation, heat storage, active cooling control or temperature-dependent
material behavior. The derivatives are local, scenarios are sampled, and neither
is an uncertainty enclosure or inverse-design certificate. The numerical code
and Python adapter are untrusted; this adds no Isabelle theorem.

The context-aware Rust API reserves conservative retained factor/construction and
output buffer allowances in the shared memory ledger. This is not allocator or
RSS accounting, and it does not cover the host JSON Value after serialization.
The legacy WorkControl-only API retains fixed local size/work
caps but has no memory ledger. Cancellation is cooperative between loops and
before/after SVD; the foreign SVD call itself is not interruptible.

The existing Rust `PreparedThermalNetwork` can also live across requests. Its
`solve` method preserves the raw-result API; `solve_with_context` returns an owner
with private evidence and a byte reservation held until that owner drops. The
prepared model's reservation lives with its immutable owner and is charged once
when Arc-shared. Each solve uses the caller's current work/deadline/cancellation
context, not a context retained by preparation. Serialized host JSON needs its
own byte custody after leaving this numerical owner.

`operator_identity()` covers ordered node IDs, link coefficients/endpoints,
boundary membership and numerical policy. Loads and fixed temperature values
change only the right-hand side. `template_identity()` additionally binds the
immutable descriptions, assumptions, reference and power policy, with all RHS
values normalized to zero. Each context-owned result binds that template and its
complete supplied scenario. These content hashes do not authenticate a source.
The historical `identity()` still covers the complete original preparation input.
Changing topology, conductances, membership or policy requires preparing again;
changing assumptions/reference/power policy also requires a new immutable owner.

Retained solves use a quadratic local work estimate for factor application plus
node/link checks, rather than charging a fresh cubic SVD estimate. Stricter
caller dimensions, request-byte caps and work budgets still apply. A zero SVD
scratch allowance is valid for a retained solve, since it performs no new SVD.
No timing advantage or whole-process memory bound is claimed by these structural
changes. The fresh API supplies a fresh-factorization comparison and shares the
compiled topology and acceptance code. Closed-form chain cases and the Python
original-node replay provide independent checks.
