# AP1 upstream meteorology quantity repair

Root integration, 26 October: included in the tracked appliance patch and the passing real-engine candidate. Proposed upstream in [HF slim #1](https://huggingface.co/psiloceyeben/oracle7-slim/discussions/1), not merged. See [batch results and remaining work](../APPLIANCE-2026-10-26.md). The lane evidence below describes its scoped checks before root integration.

Status: implemented and narrowly checked in the private contribution checkout.
Root owns commit, upstream contribution and any fresh release/admission process.
No native compilation, Isabelle build or upstream metadata rewrite occurred.

The original Oracle7 slim 4.9 meteorology-v2 confidently answered all six
counterexamples captured in `var/earth/ap1-meteorology/upstream-counterexamples.json`:
malformed `3,00 m` became zero altitude; Unicode-negative altitude became
positive; `m/s` was truncated to metres; a supplied pressure baseline was ignored;
negative wind became Beaufort zero; and two wind speeds silently selected the
first. The repaired reader withholds those requests.

A small Python helper scans whole numeric runs and validates their complete
sign, comma, decimal, exponent and optional fraction grammar before matching
quantity roles. It uses Python's Fraction library rather than copying the
verifier's SML parser. Callers bind issued markers, require unique measurements,
validate temperature/wind/altitude units and humidity context, and check that no
parsed number remains unused. Negative speeds, temperatures below absolute zero,
competing requests, ambiguous dew-point labels, non-finite arithmetic and
numeric resource-limit violations abstain. Published formulas, scale thresholds,
unit conversions and response formatting remain unchanged.

The private checkout changes are confined to:

- `var/ap1-upstream-slim/root/specialists/meteorology-v2/organ_weather_v2.py`
- `var/ap1-upstream-slim/root/specialists/meteorology-v2/weather_measurements_v2.py`
- `var/ap1-upstream-slim/tests/meteorology_v2/quantity_cases.json`
- `var/ap1-upstream-slim/tests/meteorology_v2/test_weather_quantities.py`

Validation command, exit zero:

```sh
python3 -B -m unittest discover -s var/ap1-upstream-slim/tests/meteorology_v2 -v
```

Seven test methods pass, including real Family/_Organ coexistence checks: the 110-row shipped panel with its own text scorer,
59 independent quantity policies, exact-span/resource controls, and additional
unit/role/finite-value controls. Official results remain **110 right, zero wrong,
zero false yes, zero withheld valid**, with six correct refusals (dev 52/52,
heldout 58/58). Regression tests are not a fresh held-out admission exam. Exact
scores, source hashes, replies and integrity observations are in
`var/earth/ap1-meteorology/upstream-repair-check.json`.

Admission is intentionally not fabricated. The released legacy verdict has no
`files_sha`; the current `workbench/exam.py` expects one, so its `status` returns
`changed` for this legacy verdict independently of whether it represents these
source edits. The release instead hashes the specialist directory in
`RELEASE_HASHES.json`: published part `eae191b6e48feb4fae5011fbaa190f5fbe7286e35d9b2c5b49005cc4baca06ff`
has five files; the current six-file part is
`a1a54c3877cc55deafabe024037657cd0448e28a8eda72065d3a68982d518a1d`.
Both manifests intentionally gain ISA context and routing cues. Existing
verdicts and release hashes remain byte-for-byte unchanged.

A release needs the real admission process with a new held-out set and current
core composition, then intentional directory/release/Merkle hash regeneration
and the normal publisher's release process. The portable workbench runner also
expects a split-keyed panel object and local panel path, while this legacy
manifest points to a placeholder path and a flat list panel. It cannot simply
be invoked unchanged as a replacement for the legacy release gate. These format
and provenance differences are recorded rather than papered over by changing
old verdict hashes.

The tighter upstream tests exposed two humidity boundary gaps and one repeated
dew-label gap in the first Earth build. Root authorized a separate small reader
follow-up before package closure. Both
implementations now pass the expanded 59-case set, including the adjacent
labelled-temperature positive control that checks dew-label routing priority.
The verified formula computation itself is unchanged.


## Coexistence follow-up

Root's actual patched Engine smoke found the malformed `ISA temperature at
3,000 m/s altitude?` still answered through the older `meteorology` organ after
v2 abstained. Production `Family` asks all coexisting organs; abstention by a
newer version does not suppress an older reader. The legacy bundle now carries
the repaired organ and its own identical numeric helper. This preserves its
independent loading and supported answers instead of disabling the version.
Both manifests also recognize `ISA`, so typed range/missing-input refusals are
not filtered out by the acceptance context.

Additional private files changed:

- `root/specialists/meteorology/organ_weather_v1.py`
- `root/specialists/meteorology/weather_measurements_v2.py`
- `root/specialists/meteorology/manifest.json`
- `root/specialists/meteorology-v2/manifest.json`
- `tests/meteorology_v2/test_weather_coexistence.py`

The test instantiates the actual `combo_runtime_v1.Family` and isolated `_Organ`
loader against these source folders, in both version orders. It checks helpers
come from their own bundle, the original v1 panel is 98/98, the v2 panel is
110/110, and the combined v2 panel remains 110/110 in each order. Every panel
run has zero wrong/false yes/withheld-valid, with six correct refusals. Plain
ISA and standard-atmosphere malformed/compound/extra-quantity requests cannot
recover a legacy answer; ISA out-of-range and missing-input refusals survive
acceptance filtering. This consumer-level regression complements root's final
full Engine smoke; it does not substitute for that whole-system check.

Both changed release-part hashes and all nine private changed-file hashes are
recorded in `upstream-repair-check.json`. A new admission/release must now account
for both meteorology bundles. Earth source and native artifacts were unchanged
by this coexistence repair.
