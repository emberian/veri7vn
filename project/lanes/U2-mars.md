# U2 Mars: the requested number of source years reaches the conversion

The original U1 question was reproduced unchanged against the immutable final
candidate `var/usage-20261026/candidate-final`:

> Earth takes 365.25 days to orbit the Sun and Mars takes 687 days. How many Earth years are 3 Mars years?

Independent expected calculation: `3 × 687 / 365.25 = 5.64271047227926`
Earth years. The actual reply was “A year on Earth lasts about 1.00 Earth years
(365.2 Earth days, NASA).” Its route was
`specialist_call>specialist:astronomy-v3>year_years`, HTTP 200. This is a wrong
quantity, not a small rounding difference. The response and original bytes are
retained in `var/usage-20261027/mars/baseline/`.

Baseline receipt SHA-256:
`34b685093842cbada93de9cb510db4d322fdeb12e56c88d7346132da6063a156`.
Its base source revision is `083e3a6c0e2cfc131e62bdc16cb4ec1346194635`; its usage
patch SHA-256 is
`1a2f69d0bdfe112f67ac01557ddb1c923e5e6c6a1fbaab1097852ade20e3e625`.
The adapter identifies metadata and hashes the receipt; it does not independently
verify deployment contents.

## Actual repair and consumers

Root transferred ownership of the private `astronomy*/organ_astronomy_*.py`
sources after the actual route showed these were the required consumer, rather
than the initially assigned `space*` folders. All nine original files were
byte-compared with the immutable candidate and matched before editing. Their
original hashes and copies remain under `var/usage-20261027/mars/`.

The recognizer now binds five separate operands: source planet, target planet,
source-year count, source orbital period and target orbital period. It computes
`count × source_period / target_period`, rather than choosing the first body
mentioned or silently substituting a single-year table answer. Supplied periods
must have an explicit body and be positive; repeated equal values are allowed,
conflicting ones are rejected. Counts may be nonnegative decimal numbers or the
words zero through ten. Source and target direction is part of the grammar.

The parser handles explicit “How many target years are N source years?” and
“Convert N source years to target years” forms, including counted years on a
planet, counted orbits, and short “N source years in target years” forms. It
supports a period stated as a planet taking N days to orbit, a planet's orbital
period, or a named planet's year. Any remaining prefix conditions stop the
conversion; malformed numbers cannot be salvaged by taking a suffix.

Once all roles are bound, an omitted planetary period may come from the shipped
NASA table; Earth's default is the existing 365.25-day Earth-year convention.
The reply identifies each period's source. Explicit supplied periods override
the defaults, including a different supplied Earth-year length. A Moon orbit is
not silently treated as a solar year. Unknown bodies, negative counts,
nonpositive periods and unbound conditions are refused.

The conversion hook runs before the versioned comparison/one-year fallbacks.
The real `_Organ` loader snapshots modules separately for each specialist; tests
confirm each copy loads from its own directory, so fixing only one similarly
named file would leave other consumers unchanged. The actual modified paths,
relative to `var/ap1-upstream-slim`, are:

* `root/specialists/astronomy/organ_astronomy_v1.py`
* `root/specialists/astronomy-v2/organ_astronomy_v1.py`
* `root/specialists/astronomy-v2/organ_astronomy_v2.py`
* `root/specialists/astronomy-v3/organ_astronomy_v1.py`
* `root/specialists/astronomy-v3/organ_astronomy_v2.py`
* `root/specialists/astronomy-v3/organ_astronomy_v3.py`
* `root/specialists/astronomy-v3-r2/organ_astronomy_v1.py`
* `root/specialists/astronomy-v3-r2/organ_astronomy_v2.py`
* `root/specialists/astronomy-v3-r2/organ_astronomy_v3.py`

Exact final hashes are in `tools/usage/mars/source-manifest.json`; the durable
patch is `tools/usage/mars/astronomy_year_conversion.patch`. No candidate,
original upstream, admission record, manifest or source table was edited.
Python source was frozen for root integration after the checks below.

## Narrow checks and shipped-panel numbers

The pack contains 21 independently specified cases: 12 valid conversions and
nine invalid/unsupported inputs. All pass through each of the four actual
versioned organ chains. All also pass through actual `Family` composition in
both loading orders, so no older copied module revives a rejected request or
returns a different quantity. Examples:

* Original: 3 Mars years → 5.64271047227926 Earth years.
* Reverse: 3 Earth years → 1.5949781659388647 Mars years.
* Supplied Venus=225 days and Earth=360 days: 2 Venus years → 1.25 Earth years.
* Supplied Jupiter=4320 days and Mars=675 days: 2 Jupiter years → 12.8 Mars years.
* Supplied Mars=700 days and Earth=350 days: 3 Mars years → 6 Earth years.
* Zero count returns zero; a fractional count preserves the factor.
* Conflicting Mars periods, zero/negative periods, malformed grouping,
  negative count, unbound speed conditions, unknown planets and Moon years
  decline without replacing the goal with a one-year table entry.

Exact command:

```
.venv/bin/python -B -m unittest discover -s tests/usage/mars -p 'test_*.py' -v
Ran 7 tests in 0.094s — OK
```

The seven tests include the 21-case matrices, additional wording/boundary cases,
period-source labels, unchanged mass-comparison routing and module isolation.
The existing sheet constructors issue ResourceWarnings under unittest because
they do not explicitly close their reads; these predate this repair.

Each specialist's actual shipped panel was replayed through its own scorer,
using the real manifest loader. These are direct specialist numbers, **not a
fresh held-out admission or a complete six-criterion Workbench exam**:

| Specialist | Development right / wrong / withheld-valid | Held-out before → after, right / wrong / withheld-valid | Correct declines dev / held-out | False yes |
| --- | --- | --- | --- | --- |
| astronomy | 54 / 0 / 0 | 64 / 13 / 0 → 70 / 7 / 0 | 6 / 4 | 0 |
| astronomy-v2 | 131 / 0 / 0 | 123 / 8 / 0 → unchanged | 7 / 7 | 0 |
| astronomy-v3 | 131 / 0 / 0 | 130 / 0 / 1 → unchanged | 7 / 7 | 0 |
| astronomy-v3-r2 | 131 / 0 / 0 | 130 / 0 / 1 → unchanged | 7 / 7 | 0 |

Every previously correct individual panel item remains correct, checked by
comparing failure sets rather than only totals. The legacy v1 gains six correct
year conversions; its remaining ratio errors and v2's historical ratio errors
are outside this repair. Direct panel receipts are
`var/usage-20261027/mars/panels-before.json` and `panels-after.json`; the checker is
`tools/usage/mars/check_panels.py`. No admission fields were rewritten.

## Native operation boundary

Read-only inspection found the native `src/extract/space` request `AYears abody`
contains neither a count nor a target/supplied period. Its `qval` is
`period_of body / (36525/100)`. Its existing theorem is:

```
kernel (AYears b) = Exact (STR ''year_years'') (qval (AYears b)) ∧
qval (AYears b) * (36525 / 100) = period_of b
```

This theorem is about a single table-defined year. It cannot justify a reply to
the original three-year supplied-period question. A recognizer-only patch cannot
recover the missing operands from that constructor.

The proposed native operation is `AYearConvert source target count p_source
p_target`, with nonnegative count and positive periods, result
`count * p_source / p_target`, and an algebraic statement
`result * p_target = count * p_source`. English role binding and the provenance
of supplied/table periods remain a separate untrusted boundary. Root assigned a
native lane and the exact grammar/cases were shared with it. This lane did not
edit native sources, run Isabelle, or claim a new theorem. Native results belong
to that lane's actual statement/build receipts.

## Integration status and remaining limits

The Python source is frozen and the full-engine replay now passes all 21
requests on root's U2 Python candidate, as recorded below. Root owns integration
and provisioning. Native/receiving-host outcomes remain separate measurements.

The implementation is a bounded orbital-year conversion parser, not arbitrary
astronomical modeling. It uses supplied scalar periods or the shipped rounded
table; it does not model time-varying periods, day-length conversions, calendars,
fictional worlds or infer a solar year from the Moon's orbital month. Such
conditions must not be silently dropped. There is no new proof claim in the
Python repair.

## Full immutable baseline pack

While root prepared integration, all 21 independently specified requests were
also run through the unchanged final U1 engine, using the shared runner. The
pack's 12 valid conversions yielded **0 correct answers, 6 wrong one-year
answers, 5 clarifications and 1 withholding**. Its nine invalid/unsupported
requests yielded **6 numerical answers and 3 refusals/clarifications**.

The invalid negative-count and Moon-year cases were answered through
`specialist_after_guard>P4_lookup_for_compute>specialist:astronomy-v3-r2>year_years`.
This observed fallback confirms why the repaired semantics must reach the
versioned copies, rather than only the initially visible v3 route. Contradictory
periods, malformed grouping/counts and an unbound speed condition also received
one-year table answers. Zero and negative periods were stopped by existing
precision guards; the unknown fictional planet clarified.

All 21 requests received HTTP 200, with no transport failure. Median latency was
0.144991 s, range 0.080134–4.465089 s; batch elapsed time was 20.557 s. Full replies
and original bytes are retained in `var/usage-20261027/mars/baseline-pack/`; the
compact judgment counts are in `tools/usage/mars/baseline-summary.json`.
The original question was measured once separately and once in this pack; these
are repeated runs of one case, not independent evidence of two distinct tasks.

## Repaired full-engine replay: 21/21 task expectations met

Root provisioned the frozen changes into the immutable
`/Users/ember/dev/o7vn/var/usage-20261027/candidate-python`. Independent SHA-256
checks confirmed that all nine deployed astronomy Python files exactly match
`tools/usage/mars/source-manifest.json`. This lane made no candidate or additional
private-source edits after that freeze.

The same 21-case pack was run through the shared runner with the candidate path
explicitly selected:

```
.venv/bin/python -B tools/usage/run_batch.py --runtime var/usage-20261027/candidate-python --cases tools/usage/mars/cases.json --out var/usage-20261027/mars/repaired-engine
```

All **12/12 valid conversions answered correctly**, with the expected target
planet's year unit as well as the numerical value checked. All **9/9
invalid/unsupported requests were withheld**. There were zero incorrect answers,
zero uncompleted valid cases, zero skipped requests, zero HTTP errors and zero
transport errors. All 21 requests returned HTTP 200; the adapter exited 0.

The original request's actual reply:

> 3 Mars years are about 5.64271047228 Earth years (3 × 687 Earth days per Mars year ÷ 365.25 Earth days per Earth year; periods: Mars supplied, Earth supplied). [astronomy-v3]

Its path is `specialist_call>specialist:astronomy-v3>year_years`. The reverse,
Venus, Jupiter-to-Mars, fractional, zero, word-count, explicit-definition,
overridden-period, repeated-consistent-period and same-planet cases also answered
through this v3 route. The table-default request answered through
`specialist_after_guard>P4_lookup_for_compute>specialist:astronomy-v3-r2>year_years`,
with its NASA-table and Earth-year-convention inputs explicitly labelled.

Conflicting/malformed/nonpositive periods and an unbound speed condition now
withhold through `astronomy-v3>no_value` with relevant explanations. The
negative-count and Moon-year requests remain withheld at
`precision_guard:P4_lookup_for_compute|factoid:page`; they no longer acquire the
old v3-r2 fallback answers. The unknown body is withheld by v3. No rejected case
was restored as a numerical answer by a versioned fallback.

Full unmodified replies, response bytes and adapter logs are in
`var/usage-20261027/mars/repaired-engine/`. Separate judgments and deployment
metadata are retained in `tools/usage/mars/repaired-summary.json`. Median request
latency was 0.188679 s, range 0.087704–2.366801 s. Batch elapsed time was 18.122 s.
These are actual task measurements, not a general performance benchmark.

Deployment receipt SHA-256:
`a19f3dd920d0fbefd8d8d70495c233bd0132a469ea2cd5c62a3c777c7ad4adc5`.
The new `oracle7-slim-4.9-dates-mars.patch` SHA-256 is
`ae5cee2b265b0c1902407a9fd88385bd32532a4a828b6661e3209acc07277491`.
The unchanged overlay-manifest SHA-256 is
`91e3525e922f98a662d81e0c8a154dfaf51ee55ec24e37f6125cc0ea873be1d4`;
capabilities identify `linux-x86_64` kernel artifacts and explicitly say the
adapter does not verify deployment contents. These macOS engine observations
establish the deployed Python route. They do not substitute for the native
lane's kernel receipts or the actual Mini receiving-host acceptance run.

Measured change on this pack: valid completions **0/12 → 12/12**; numerical
answers to invalid/unsupported requests **6/9 → 0/9**. Including the separately
repeated original baseline request, this lane has retained 43 real requests over
21 distinct question texts. No new six-criterion admission or theorem is claimed.
