# Supplied thermal storage

Supply a component's heat capacity, a constant conductance to a fixed cooling
reservoir, its initial temperature and a heater schedule. The example heats for
ten seconds and then turns the heater off. It returns requested temperatures,
node and global energy accounting, and numerical crossings of 305 K.

With the standalone host's science operation enabled:

```
python3 tools/usage/thermal_transient.py --url http://127.0.0.1:8000
python3 tools/usage/specialist/thermal-transient/scorer.py --url http://127.0.0.1:8000
```

The twelve-case new workflow panel uses independent exponential cooling/heating,
isolated linear heating and a closed two-body analytic solution. It also checks
ideal reservoir heat, threshold directions, malformed capacities/boundaries/load
schedules, attempted-step exhaustion and below-zero refusal. It does not count a
transport or contract failure as a correct refusal. No run or score is claimed
here, and this is not an upstream shipped specialist panel.

The supplied graph is passive, with constant positive conductances and positive
finite lumped heat capacities. Disconnected components are allowed: their initial
temperatures and capacities determine their evolution. Every fixed reservoir has
a constant temperature throughout the run, and its initial condition must match.
Its capacity is positive but its stored-energy change is zero. Reported reservoir
heat is the ideal external heat needed to maintain that boundary, not measured
cooling capacity. Boundary temperature jumps and their possible impulse heat are
outside this operation.

The client binds each result to the entire supplied model, initial state,
schedule and numerical policy using `thermal-canonical-binary64-v1`. Typed
defaults are filled, object keys sorted, UTF8 strings and containers carry
big-endian u64 lengths, and numeric values carry their big-endian IEEE754
binary64 bits before SHA-256. Integer/float JSON spellings therefore agree.
The client also checks aggregate energy against independently summed node
values and each event estimate against its stated endpoint linear interpolant.

The complete piecewise load schedule supplies all transient heat inputs; base
network loads are not inherited. Every source change and requested sample is an
integration endpoint. A final endpoint fragment may be shorter than the supplied
minimum step; it must still pass the same local acceptance check. Backward Euler uses a serial faer Cholesky factor of
`C+h*L`; positive capacities make this operator positive definite even without a
fixed reservoir. An eight-entry local cache reuses factors for identical time
steps. There is no global mutable factor cache or new dependency. Adaptive step
doubling compares one full step against two halfsteps, accepts the two halfsteps,
and limits that local difference using the supplied kelvin and relative targets.
The relative target scales with absolute kelvin. It is not a rigorous global
error bound. The network's steady SVD rank cutoff is not used by this SPD solve.

Every accepted halfstep checks original-node energy from returned absolute
temperatures, original capacities, sources and link heat. Acceptance includes the
supplied power tolerance times elapsed time, relative balance tolerance, and a
32*epsilon*capacity*absolute-temperature roundoff allowance. Totals use streaming
compensated sums. The client independently checks final storage, exact piecewise
source integrals, node/global balances and cancellation of internal heat.

Threshold records give accepted-halfstep endpoint brackets and a linearly
interpolated numerical crossing time. They do not bound the true continuous
crossing time. Initial equality and grazing are not crossings; rapid recrossings
inside a halfstep can be missed. An empty hit list means no sampled crossing was
found under this method. It does not prove absence. Source changes themselves
never jump temperature.

The operation refuses incomplete trajectories when local work, attempted-step,
minimum-step/error, event-count, physical-temperature or numerical checks fail.
No partial trajectory is promoted. Cooperative checks surround the foreign
factorization, which itself cannot be interrupted. The context-aware API retains
an explicit conservative memory reservation alongside its numerical owner/result.
Typed shape/text bounds are checked before serialization or reservation; encoded
request writing is capped and reserved before allocating its buffers. The allowance
uses four times the configured request-byte ceiling plus actual-dimensional
matrix, scratch and output allowances, covering buffer growth conservatively;
this does not track the allocator, RSS or the host JSON Value after serialization.
The WorkControl-only API retains fixed local bounds without a shared byte ledger.

This does not model fluid advection, district heating, nonlinear radiation,
material inference, switching thermostats or uncertainty propagation. The
scientific-domain paperbin's district-heating papers use advective models and
therefore do not justify symmetric conduction edges. No Isabelle theorem is
added. The Python consumer and numerical computation remain untrusted.
