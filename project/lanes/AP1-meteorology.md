# AP1 meteorology-v2

Status: authorized native build passed; pinned native panels and independent
probes passed. No Isabelle build was needed or launched. The new ID is ready
in Earth; root owns registry, routing manifest and package integration.

The old reader treats `3,000 m` as `0 m`. Oracle7 4.9's meteorology-v2 fixes
that example by deleting selected commas, but still lets malformed grouping,
negative winds, duplicate measurements and compound units become confident
answers. This lift uses the shared exact numeric lexer, binds each token to a
unique quantity role, and refuses an answer when supplied measurements remain
unused. Signed grouped digits, fractions, scientific notation and leading-dot
decimals retain their value. The new ID and old meteorology ID share the reader;
Earth family dispatch prefers the new ID. Forecast and competing weather
requests abstain. Negative wind speeds and temperatures below absolute zero
are reader refusals, not new proved physical rejection theorems.

The source panel is the pinned Oracle7 slim 4.9 directory at
`var/universe-20261026/huggingface/oracle7-slim/root/specialists/meteorology-v2`.
Its `weather_scorer.py` evaluates the literal response text. The unchanged
baseline native binary scores 96 right, 14 wrong, zero false yes and zero
withheld valid answers on the new 110-row panel. All fourteen errors are
comma-altitude cases. Baseline independent probe results are diagnostic only.

Native execution, matching the preceding Poly/ML source check, scores 52/52
dev and 58/58 heldout through all three modes
(`meteorology-v2`, legacy `meteorology`, and family). Each mode has zero wrong,
zero false yes, zero withheld valid answers, and six correct refusals. The 54 independent probes also pass in each mode; they measure quantity and
routing policies, not additional shipped panel answers. Native results are in
`var/earth/ap1-meteorology/native-check.json`; source results remain separately
in `var/earth/ap1-meteorology/source-check.json`. This packet does not remeasure
all six admission criteria, claim fresh generated panels, or claim package
integration before root completes it.

No HOL definition or theorem changed. Existing `w_value_sound` states that if
`w_kernel r = Value x`, then `xsem x = w_phys r`: the returned expression denotes
the declared heat-index, wind-chill, Magnus, wind-scale or ISA model for the typed
request. Existing checked interval rendering certifies the numeric rounding.
The theorem does not establish that English was parsed correctly or that an
empirical formula describes arbitrary physical conditions. The consumer remains
`Earth.reply_of`, reached by the exact-token recognizer and JSON-lines driver.

Changed files owned by this lane:

- `src/extract/earth/recognizer.sml`: numeric/role recognition and specialist ID.
- `src/extract/earth/main.sml`: document the additional ID.
- `src/extract/earth/capabilities.json`: evidence entry for the new ID.
- `src/extract/earth/meteorology_v2_check.py`: narrow pinned panel and independent checks.
- `src/extract/earth/README.md`: supported surface and reproduction command.
- This lane record.

Executed native build: `sh src/extract/earth/build.sh` (exit 0). The managed
compiler validated the unchanged live HOL closure and existing checked export.
Compile receipt:
`var/earth/native-attempts/20261026T205849Z-ba662abc0c78/compile-inputs.json`.
The 932,472-byte native binary SHA256 is
`675414ef139f5d46a09b06a8008e456566fb6ce8a1704e4ca3b9fcc110c5e815`.
The frozen parser and native input hashes are also recorded in
`var/earth/ap1-meteorology/source-snapshot.json` and `native-build.log`. Session is `Veri7vn_Earth`, historical proof marker is
`VERI7VN_EARTH PASS`; no new proof marker is claimed. Generated kernel SHA256 is
`827fef6eaff03224df96f26a95cf91f64340267a064a969e272083212b910843`.
Native inputs are the generated Earth kernel, Earth `regex.sml`, shared
`commons/numeric.sml`, Earth `recognizer.sml` and `main.sml`, and MLton's basis.
The transitive proof dependencies remain the Earth base/session theories and
existing `HOL-Decision_Procs` closure validated by the managed receipt.

The narrow command exited 0:

```sh
python3 -B src/extract/earth/meteorology_v2_check.py \
  --source var/universe-20261026/huggingface/oracle7-slim/root/specialists/meteorology-v2 \
  --out var/earth/ap1-meteorology/native-check.json
```

No broad suite ran. `git diff --check` and Python syntax checks passed. Six
concrete upstream counterexamples are preserved in
`var/earth/ap1-meteorology/upstream-counterexamples.json` for a separate upstream
contribution; this lane changed no upstream files.
