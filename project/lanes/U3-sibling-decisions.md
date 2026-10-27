# Decision and simulation components

Ember requested useful Oracle7 sibling capabilities in the appliance, together
with repairs to the siblings themselves. This lane adds five callable operations
using the actual upstream functions. The Python adapter is untrusted computation;
it does not authorize actions, inspect the host or control real equipment.

| Operation | Input and useful result |
| --- | --- |
| `trafficcop.decide` | Supplied state and named options → a proposed choice or abstention, with the complete upstream decision receipt |
| `deepspace.profiles` | No inputs → the four simulator profiles and their supported faults |
| `deepspace.simulate` | Profile, fault, seed, 81–640 ticks → seeded simulation, proposed simulated actions, receipts and score; one tick is 60 seconds |
| `infrastructure.analyze` | At most 512 supplied, sourced, time-stamped readings → upstream status, trends and observed shifts |
| `infrastructure.forecast_gate` | At most 512 supplied forecast/result records → paired comparison against the naive baseline, with sample counts and errors |

The consumer is `DecisionOperations(runtime, workspace)` from
`tools/oracle_components/decisions.py`, installed as `component_operations.py`.
It exposes `catalog()` and `invoke(operation_id, arguments)` to the appliance
service's shared operation registry. The Mini consumer uses that same discovery
and invocation API; these calls are not another platform or permission engine.
Wiring and final Mini acceptance are owned by the service and integration lanes.

## Source identity and packaging

Fetched the official Hugging Face heads on 27 October 2026 into private mutable
checkouts under `var/u3-sibling-decisions/`. They remain at these revisions with
only the listed local patches. Original research snapshots and `upstream/`
were not modified.

| Component | Upstream revision | Packaged executable source closure |
| --- | --- | --- |
| Trafficcop | `08a9f1e70b8e78d9078b4bd9f308b99b9800bcb0` | `trafficcop/__init__.py`, `trafficcop/model.py` |
| DeepSpace | `3538060dbb55f287d060820f7b7c42fe3487632d` | `deepspace/__init__.py`, `sim.py`, `runtime.py`, `fdir.py` |
| Infrastructure | `74456ba7db9172f5822433308943647ecd67cdf0` | `agent.py` |

All three have an Apache-2.0 `LICENSE`; retain it and `README.md` alongside the
selected source. All five operations need only Python's standard library.
No model, asset or network download is required.

Provision each source closure at `components/<id>/source/` and record it in
`APPLIANCE.components[id]`. The provider checks the fixed source location,
repository, revision and every receipt-listed file's size and SHA-256 before
import. Missing, mismatched or unsupported sources are advertised as unavailable.
Imports use private package names, avoiding collisions between sibling modules.
The deployment must remain immutable after those checks. Receipts identify
bytes; they do not prove the authenticity of caller-supplied telemetry.

The source patches, including portable upstream regression tests, are:

| Patch | SHA-256 |
| --- | --- |
| `deploy/appliance/patches/siblings/decision-trafficcop.patch` | `fd4b8e01815b8118a2848792a38e9d434db34dc32784698f0605899fd9682e88` |
| `deploy/appliance/patches/siblings/decision-deepspace.patch` | `3c72d54365ca4e180b7e5a5fdb4b110857bc119dccddaa2470257e57db40fbf2` |
| `deploy/appliance/patches/siblings/decision-infrastructure.patch` | `7b7e4647c626f0654b7f7ad83bb188924e87be55b76e3c30bcf9c99dc042bd60` |

## Repairs and their counterexamples

Trafficcop previously chose the first of two options that discharged the same
obligation. Reversing their order reversed its choice. It now abstains on an
ambiguous binding, optionally proposing a unique evidence-gathering option.
Duplicate option IDs refuse. The input receipt now hashes the complete request,
including questions/options, instead of only the state. Structural bindings no
longer fabricate a 90% probability or distribute probability to struck options;
the probability map is empty and any empirical, smoothed success rate is reported
separately with its count. The existing question/choice receipt remains intact.

DeepSpace's scorer accepted `mark_sensor_invalid` with no zone or sensor and
`switch_to_spare_wheel` with no wheel as correct responses. These commands cannot
execute as written. Required targets must now match the injected fault, and a
response before fault onset is not counted as solving that future fault.
The simulation still uses upstream FDIR and physics unchanged.

Infrastructure's gate compared each method's errors with all naive samples,
even from different entities and forecast times. Thirty trend samples with error
1 could therefore be admitted against thirty unrelated naive samples with error
100. It now pairs origin time, target time, entity, signal, horizon and actual
observation. Duplicate method/event rows are ambiguous and do not count. Each
method needs at least thirty paired samples and a strict improvement of at least
10%; tying an already-perfect baseline is not improvement. Non-hour horizons
receive distinct labels. Timestamp zero is now treated as a real reading rather
than an empty database.

## Checks actually run

- Twelve adapter tests passed using the real patched source closures. They cover
  direct calls through the shared service registry, missing/tampered source receipts, ambiguous and duplicate options,
  simulation, missing-target scoring, no host access during telemetry analysis,
  exact forecast pairing, duplicate exclusion, and numeric/work bounds.
- All three patches applied cleanly to fresh copies of their exact upstream
  files. Applied source bytes equal the private repaired source bytes.
- The patches' portable regression suites pass: Trafficcop 3, DeepSpace 2,
  Infrastructure 4 tests. These were also run on the freshly applied copies.
- Trafficcop's original routing scorer remains **16/16 dev, 30/32 held-out**,
  with 8/8 and 16/16 order-consistent pairs, and **2/2 structured cases**. The two
  prior held-out misses remain. This is the sibling's routing panel, not an
  Oracle7 specialist-panel or whole-appliance accuracy score.
- One actual 320-tick DeepSpace sensor-bias simulation passes its repaired score
  with no harmful action. This is a smoke check, not a rerun of its published
  1,700-scenario result.
- `git diff --check` passes. No theorem statement changed or new proof claimed.

Reproduce adapter checks with:

```sh
python3 -B -m unittest discover -s tests/oracle_components -p test_decisions.py -v
```

`ORACLE_COMPONENT_TEST_SOURCES` may select another parent directory containing
the three patched source checkouts. When those external sources are absent the
real-source suite reports a skip; it does not substitute mocks. Exact routing
and patch-application results are retained under `var/u3-sibling-decisions/`.

## Remaining scope

Packaging and shared service invocation must use these exact source closures;
this lane alone does not establish a signed package or admitted Mini call.
Infrastructure host discovery, polling, command execution and privileged
installation are intentionally not callable through the computation permission.
A future connector needs an actual host/network authority contract. DeepSpace
remains a simplified simulation; Trafficcop returns proposals, not permissions.
The Infrastructure gate trusts supplied observations and still selects among
admissible methods using their paired-sample errors, rather than proving future
forecast quality. Source repairs are prepared for contribution; none was sent to
an upstream author or published by this lane.
