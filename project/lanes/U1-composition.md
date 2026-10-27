# U1 composition: useful steps were being presented as final answers

Twenty real requests ran through the immutable candidate and shared runner:
12 initial tasks and 8 atomic follow-ups. The initial usage phase ran no specialist
panels. A later authorized engine repair replayed the shipped energy panel with
its scorer, as detailed below; no new six-criterion admission is claimed. No
theorem was added or changed.

## Initial tasks

Expectations, intermediate quantities and final values were fixed in
`tools/usage/composition/expectations.json` before the first run. Requests contain
only IDs, conversation IDs and text. All 12 received HTTP 200; there were no
transport failures. Median request latency was 0.204426 s, range
0.074852–2.746986 s. Batch elapsed time, including startup/cleanup, was 17.444 s.

| ID | Expected final answer | Actual result | Judgment |
| --- | --- | --- | --- |
| journey | 2.75 h, including 15 min parking | Generic clarification | Unfinished despite complete inputs |
| energy_cost | $0.60 from 3 kWh | $0.60, with energy/tariff calculation | Correct |
| material_cost | $21.60 from 5.4 kg | Generic clarification | Unfinished despite complete inputs |
| trip_fuel | $24 from 15 litres | 24 dollars, dimensional product trace | Correct |
| resistor_energy | 15,000 J from 250 W | Generic clarification | Unfinished despite complete inputs |
| solar_useful | 1.6 kWh stored, from 2 kWh generated | “It uses 2 kWh” | Wrong quantity; storage fraction omitted |
| tank_fill | 50 min from 1,000 litres | 50 minutes, volume/flow trace | Correct |
| work_price | $580 from $480 labour plus $100 materials | Generic clarification | Unfinished despite complete inputs |
| date_relation | Walt Whitman; 36 calendar years | Correct author, explicitly cannot verify second part | Honest partial answer |
| orbital_ratio | 2061 / 365.25 = 5.64271047 Earth years | “A year on Earth lasts about 1.00 Earth years” | Wrong object and quantity |
| net_energy | 3.5 kWh remaining, after 1.5 kWh used | “It uses 1.5 kWh” | Wrong quantity; initial capacity omitted |
| ambiguous_efficiency | Ask for efficiency/heat boundary, or state a conditional model | Withheld, asks for wattage and runtime | Avoids unsupported answer, but asks for the wrong missing information |

Counts: 3 fully correct; 3 answered the wrong quantity; 1 explicit partial
answer; 4 generic clarifications; 1 safe withholding with an unhelpful reason.
The ambiguous heater case was not scored as a numerical success.

Actual request/response evidence is under
`var/usage-20261026/composition/initial/`. Its `results.jsonl` includes full
responses and original response bytes. Distinct routes matter:

* `energy_cost`: `specialist_call>specialist:energy-v3>cost`, “It costs about
  $0.60 (3 kWh = 1500 W × 2 h, at $0.2/kWh).”
* `trip_fuel`: `network4>core_math`, trace formula
  `6 litres of fuel per 100 km × 1.60 dollars per litre × 250 km`.
* `net_energy`: `specialist_call>specialist:energy-v3>energy`, “It uses 1.5 kWh
  (500 W × 3 h = 1500 Wh).” This is correct arithmetic for consumption and an
  incorrect answer to the requested remaining energy.
* `date_relation`: `chat:parts_w537>1 of 2`, author relation `P50` succeeds;
  the date-dependent second part is explicitly unverified.

The tank's trace calls length/depth “height” and width “diameter” internally,
yet its product still answers this rectangular-volume question correctly.
That trace is not evidence that those role assignments are generally valid.

## Atomic follow-ups and explicit continuation

Eight atomic questions had expectations fixed separately before the second run.
Seven answered correctly; one was withheld. All received HTTP 200, without
transport failure. Median request latency was 0.897577 s, range
0.080626–3.713938 s; batch elapsed time was 18.038 s.

| ID | Actual answer | Route |
| --- | --- | --- |
| battery_consumption | 1.5 kWh | `network>core_math` |
| solar_generation | 2 kWh/day before losses | `specialist_call>specialist:energy-v3>solar_yield` |
| drive_hours | 2.5 | `compute:verified` |
| resistor_power | 250 W | `specialist_after_guard>P4_lookup_for_compute>specialist:electronics-r2>power` |
| aluminium_mass | Withheld | `precision_guard:P2_no_number|organ:math>evaluate` |
| whitman_birth | 31 May 1819, names Q81438/P569 | `specialist_call>specialist:rel-journalists>journalists` |
| grass_publication | 1855, names Q132042/P577 | `family_precedence>specialist_call>specialist:rel-novels>novels` |
| mars_ratio | 5.64271 | `compute:verified` |

Replies and exact bytes are under `var/usage-20261026/composition/steps/`.
Oracle's reply route says `compute:verified`; this report does not upgrade that
label into an independently established theorem about the reply.

Five explicit workflows now consume exact atomic receipts and finish local
arithmetic: battery remaining 3.5 kWh; solar stored 1.6 kWh; resistor energy
15,000 J; journey total 2.75 h; publication calendar-year gap 36 years. These
are **caller workflow completions**, not five improved direct Oracle replies.
The author identity in the publication plan was supplied from the earlier actual
author reply; the workflow does not discover or establish that link itself.
The generated case lists match the actual atomic requests in the retained run.

`workflow.py` labels Oracle replies and local arithmetic separately. It checks
exact request binding, answered status, expected response forms, quantity units,
unique quantity names and the dimensions of local operations. It preserves a
full receipt even when a step fails. A result for “used” cannot silently become
“remaining”; the subtraction is a named step. It does not infer a plan from
arbitrary prose, authenticate replies, or prove that a caller-chosen formula
matches the physical question. Those limits are explicit in its docstring,
result authority field and README.

## What to improve next

The confirmed priority is enforcing the requested quantity before a direct
specialist answer wins. The appliance's
`root/specialists/energy-v3/organ_energy_v1.py` device-energy branch finds watts
and duration anywhere, then returns energy used without checking whether the
question requests generated, stored or remaining energy. That explains two
observed wrong answers. The astronomy route similarly selects Earth rather than
the requested three-Mars-years conversion. Tightening goal coverage and then
composing a named continuation would turn useful intermediate work into an
actual answer.

The existing `workbench/swarm/point.py` already distinguishes quantity names and
units, binds admitted parts, and records plan steps. It is a better basis for
connecting an explicit planning request than asking the dimensional network to
recover meaning from units alone. Its `research_value`/`_plan` fallback still
makes accepted text shape and the user's chosen plan part of the trust boundary.
The real question surface did not route these ordinary requests into that
explicit named-quantity workflow. No existing/shared module was changed here.

The split requests are a reproducible wording workaround. Material mass still
failed as a direct atomic lookup/calculation, and the work-price task has not
been repaired. A future engine repair needs the original question regressions
as well as the easier atomic ones.

## Changed files and check

Owned files only:

* `tools/usage/composition/workflow.py` and `README.md`.
* Initial `cases.json` / `expectations.json`, atomic `step-cases.json` /
  `step-expectations.json`.
* Five explicit plan JSON files: `battery-remaining`, `solar-stored`,
  `resistor-energy`, `journey-total`, `author-publication-gap`.
* `tests/usage/composition/test_workflow.py` and `recorded-replies.json`.
* This report.

The replay fixture retains seven actual response objects without alteration;
it omits duplicate raw-body and timing fields. Original bytes remain in scratch.
It is test data, not proof of source authenticity.

Exact check:

```
.venv/bin/python -B -m unittest discover -s tests/usage/composition -p 'test_*.py' -v
Ran 11 tests in 0.004s — OK
```

The tests exercise five real-reply workflows plus original wrong-quantity
receipt rejection, wrong question/session, partial/refused replies, wrong
units/roles/routes, duplicate/missing receipts, failed-step evidence retention,
quantity reassignment, dimension checks, unit conversion, division by zero,
non-finite values, and relation subject/property binding.

No Isabelle build, git operation, candidate/upstream write or corpus copy was
performed. Consumers are callers needing reliable multi-step calculations and
engine maintainers who can now reproduce the difference between an intermediate
number and the requested answer.

## Authorized engine repair, frozen for root integration

Root subsequently assigned the single private source file
`var/ap1-upstream-slim/root/specialists/energy-v3/organ_energy_v1.py`.
Before editing, `cmp` confirmed its bytes matched the immutable candidate.
The original SHA-256 was
`723dbb4edc2e33af17ee167a424de2043c79ccdddcfb803a4719229d44877da6`.
Only that private source file and the existing composition-owned paths changed.
The v3 and v2 wrappers, manifest, admission records and candidate were untouched.

The actual specialist now performs these named continuations:

* Remaining battery energy: initially stored energy minus battery-side energy
  withdrawn. Load energy is divided by the supplied conversion efficiency.
  A supplied discharge-depth fraction bounds feasible runtime; asking for usable
  energy remaining subtracts from the usable fraction explicitly.
* Newly stored energy: generated/input energy times the supplied storage fraction.
  Power and duration, a stated input energy, and explicitly per-panel power are
  supported. Initial charge/capacity limits require a fuller charging plan.
* Runtime: battery capacity times conversion efficiency times usable fraction,
  divided by consumed load. The inverter rating is checked as a constraint and
  is never substituted for consumed power. Wh, kWh and V×Ah capacities work.

Zero efficiency/depth gives zero runtime; out-of-range factors, nonpositive load,
load above rating, conflicting capacities/factors, unbound losses, unsupported
multiple sources/loads and infeasible discharge requests are withheld. Efficiency
and an equivalent loss fraction are not multiplied twice. Charging efficiency
cannot stand in for inverter efficiency. Malformed comma groups cannot yield a
salvaged suffix number. A valid `1,000 Wh` still works.

All six original composition/engineering energy reproductions now pass through
the actual private `EnergyOrganV3 → EnergyOrganV2 → EnergyOrgan` chain: 1.6 kWh
newly stored; 3.5 kWh remaining; three 7.2-hour runtime formulations; refusal for
120% efficiency. This is direct specialist execution; root's combined engine
replay remains necessary. The exact six requests and independent expectations
are in `energy-repair-cases.json` and `energy-repair-expectations.json`.

The durable patch is `tools/usage/composition/energy_quantity_roles.patch`.
Additional owned files are `check_energy_panel.py` and
`tests/usage/composition/test_energy_repair.py`.

### Actual shipped panel comparison

The manifest's actual `energy_panel_v3.json` and `energy_scorer.ok` were run
against the original v3 specialist before editing and against the repaired one.
Both produced exactly these counts:

| Split | Valid right | Wrong | Withheld valid | Correct must-decline | False yes |
| --- | --- | --- | --- | --- | --- |
| Development, 74 items | 70 | 0 | 0 | 4 | 0 |
| Held-out replay, 70 items | 66 | 0 | 0 | 4 | 0 |

This is direct specialist replay of already-published examples, **not a fresh
held-out admission or the complete six-criterion composed-engine exam**. The
scorer's 0.5%/currency tolerance is preserved; new quantity-role regressions
instead inspect the named result and independently calculated value.

Exact command:

```
.venv/bin/python -B tools/usage/composition/check_energy_panel.py --directory var/ap1-upstream-slim/root/specialists/energy-v3
```

Receipts: `var/usage-20261026/composition/energy-before.json` and
`energy-after.json`. Final narrow test command remains:

```
.venv/bin/python -B -m unittest discover -s tests/usage/composition -p 'test_*.py' -v
Ran 24 tests in 0.013s — OK
```

This consists of 13 actual-engine-module regression tests and the prior 11
workflow tests. The new tests include changed numbers, factor boundaries,
capacity conflicts, order/units of load/rating, source multiplicity, malformed
commas, feasible remaining energy and honest rejection of unbound models.

### Exact Workbench identity effects

Frozen source SHA-256:
`9d446d096f25abe8cb507bc71a63b20c6cb7965b600dc55d19de59d0c354f7fc`.

Actual `workbench.exam.files_sha` before:
`4c1feef2eeb745779bf473097182eb5b3fbbcc4f890ae11159bb5e2f6a5089cb`.
After:
`3d4199e7328296a982657f4335c611b09c020ee89cfd013a7115da9aa4a5acf9`.

The shipped `verdict_heldout.json` says `ADMIT` but contains no `files_sha` or
panel hash. Consequently actual `exam.status` reports `changed` for **both** the
unchanged candidate and repaired private folder. It would be inaccurate to say
this edit alone changed an admitted Workbench folder into that state. Registry
fingerprinting's `files` component changes; the verdict bytes are unchanged.
No admission/hash field was rewritten to bless the repair.

For a proper new local Workbench admission, prepare a separate writable specialist
folder, keep the repaired module chain and scorer, provide a new development and
held-out panel using Workbench's `{dev: [...], heldout: [...]}` shape, and point
its manifest at that local file. The shipped panel is a flat list, so it is not
directly accepted by `exam.run`'s split lookup. Do not count reshuffling or
renaming the spent shipped held-out items as a fresh set. Run dev first, freeze
source, and run the fresh held-out once using the actual target engine; the exam
also checks its 924 core items, identity and latency. It writes a new hash-bound
verdict and spends that held-out set before execution. Root owns combined
provisioning and any such admission operation.

Remaining scope: this is a constant-power, constant-efficiency model. General
charging with initial energy/capacity, multi-source or multi-load networks,
variable loads and distinct cascaded conversion stages need an explicit expanded
plan. The repair refuses these rather than ignoring their conditions. No new
formal guarantee or broad completion claim is made.

## Final combined-candidate engine replay

Root provisioned the frozen energy file with the other lanes' repairs into
`/Users/ember/dev/o7vn/var/usage-20261026/candidate`. The source file there matches
the frozen SHA-256 above exactly. This candidate was not edited by this lane.

The original 12 requests were rerun unchanged, followed by eight independently
specified invalid/unsupported stored/remaining-energy requests. All 20 received
HTTP 200; no request was skipped and there were no HTTP or transport errors.
The adapter exited 0. Exact requests, full replies and response bytes are in
`var/usage-20261026/composition/combined-final/`; total batch elapsed time was
13.161 s. This brings the lane's real-engine request total to **40**: 12 initial,
8 atomic follow-ups, and 20 final replay/boundary requests.

Original-12 outcomes improved from **3 correct / 3 wrong quantities** to
**5 correct / 1 wrong quantity**. The other outcomes stayed at one explicit
partial answer, four generic clarifications and one safe but unhelpfully
explained withholding. Both repaired answers now come from the actual engine:

* `solar_useful`: `specialist_call>specialist:energy-v3>energy`, “The newly stored
  energy is 1.6 kWh (2 kWh generated/input energy × 0.8 storage fraction).”
* `net_energy`: same specialist route, “The remaining energy is 3.5 kWh
  (5000 Wh initially − 1500 Wh withdrawn; load 500 W × 3 h, conversion
  efficiency 1).”

The earlier correct energy cost ($0.60), fuel cost ($24) and tank fill time
(50 min) remain correct. The Mars conversion still returns one Earth year
instead of 5.64271047 Earth years; that separate astronomy requested-quantity
repair is outstanding. The author/date answer is still explicitly partial.

All **8/8** boundary requests were withheld by
`specialist_call>specialist:energy-v3>underspecified`, with relevant reasons:
120% storage, missing storage fraction, battery overdraw, negative remaining-
energy duration, malformed `1,2 kWh`, multiple batteries, negative charging
period and conflicting storage fractions. No legacy fallback resurrected these
requests as numerical answers. The boundary pack and pre-run expected refusal
conditions are retained in `energy-boundary-cases.json` and
`energy-boundary-expectations.json`.

Latency of the original 12: median 0.188892 s, range 0.070598–2.320903 s.
Boundary eight: median 0.081684 s, range 0.056527–0.149895 s. These are measured
request timings, not an engine-only performance benchmark.

Recorded deployment identity:

* Base source revision: `083e3a6c0e2cfc131e62bdc16cb4ec1346194635`.
* Receipt SHA-256:
  `e3628455a546219ad1505cd04b548a4282bff7647cc10a8c78fb30ae548b66d8`.
* Correctness patch SHA-256:
  `feb44d407634699545634350281e530b1bcc0ecf7bd951bdfc01655dbf99ecd6`.
* Usage patch SHA-256:
  `eecb26f28f86f015b4a0c3e6056d3a8e9fafe6e9760e811db2289e7701d424a7`.
* Overlay manifest SHA-256:
  `91e3525e922f98a662d81e0c8a154dfaf51ee55ec24e37f6125cc0ea873be1d4`.

Capabilities explicitly say only receipt bytes are hashed and deployment
contents are not verified by the adapter. Those labels are preserved as supplied;
the actual repaired energy source was independently byte-hashed here. This final
run establishes these task outcomes on this candidate, not fleet-wide scores,
new admission or a theorem. Engineering is separately replaying its runtime
cases through the same combined candidate.
