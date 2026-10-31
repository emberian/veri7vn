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
boundary values may vary. The base network's loads also serve as a preparation
check. A content hash includes the complete ordered input and numerical policy.
There is no global mutable factor cache. Dense serial SVD follows the existing
small-network rank policy; no speed advantage over sparse factorization is
claimed without measurement. Preparing a network includes one initial RHS solve;
the scenario and sensitivity counters count subsequent requested solves only.

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
