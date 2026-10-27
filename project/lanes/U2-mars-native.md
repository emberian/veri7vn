# Native orbital-year conversion (27 October 2026)

Owner: Codex `mars_native`. Consumer: the native Space family and its four
astronomy specialist IDs, then the appliance's native kernel adapter.

## Measurement status

The eight shipped panels score **1,185/1,185 in isolated specialist mode**,
with zero wrong and zero false yes on both macOS and Linux. All 1,185 accepted
panel replies are identical across platforms. Counts by specialist are Orbits
70, Planetary 36, Spacecraft 42, Spacecomms 68, Astronomy 141, Astronomy-v2 276,
Astronomy-v3 276 and Astronomy-v3-r2 276.

Complete-family mode scores 1,183/1,185, zero wrong, retaining the two documented
Planetary off-domain scores caused by useful Astronomy replies. This change
does not claim to resolve those scorer disagreements.

The 36 focused semantic cases pass in all four astronomy IDs and complete-family
mode on both macOS and Linux: 180/180 on each platform, zero wrong, false yes,
withheld valid or process errors. The primary native response is:

> 3 Mars years are about 5.64271047228 Earth years (3 x 687 days / 365.25 days per year).

The reverse conversion returns 1.59497816594 Mars years. Contradictory supplied
periods, malformed quantities, unsupported extra conditions and negative counts
are refused rather than reinterpreted as single-year table properties.

The first managed proof build passed on hbox, attempt
`20261027T044215Z-0630d8985292`: `VERI7VN_SPACE PASS theorems=118 oracles=0`.
The base and Space sessions took 4m49s total. No proof repairs or second build
were needed. Linux compilation reused that exact export with the final runtime
overlay; it did not rebuild Isabelle.

Receipts and binaries:

- Proof/export: `var/space/remote-attempts/20261027T044215Z-0630d8985292/receipt.json`.
- macOS compiler input capture:
  `var/space/native-attempts/20261027T044843Z-91a5478c6989/compile-inputs.json`.
- macOS binary: `var/space/bin/space`, 823,448 bytes, SHA-256
  `4dbf07c92fe6c810dbca032cfbab1fc7110370bbc74faac422913aa0f26c6fc7`.
- Native focused results: `var/space/mars-native-macos.json` and
  `var/space/mars-native-linux.json`.
- macOS shipped score: `var/space/mars-panels-macos.json`.
- Linux panel/deployment receipt:
  `var/linux/receipt-space-hbox-space-1793076556-95736.json`.
- Linux binary: `var/linux/linux/space-1793076556-95736/space`, 1,729,800 bytes,
  SHA-256 `63f5248b8f8beac41fb791d791f6a7038e0fd7c0ae141dced5e6d450d2a9c667`.
- Linux remote binary:
  `/home/hbox/veri7vn-deploy/build/space-1793076556-95736/space`.


## What changed

`Space.thy` adds `AYearConvert source target count source_period target_period`.
It calculates `count * source_period / target_period`, with both periods in
Earth days. The request keeps the source and destination bodies distinct from
their supplied periods. The public answer kind remains `year_years`, which the
existing specialist manifests admit. A one-year table property remains the
separate existing `AYears` request.

`recognizer.sml` requires an explicit count, source and target. It consumes
complete named-period premises, permits repeated equal periods, and refuses
conflicting periods, unexplained conditions, malformed numbers and Moon years.
A supplied period replaces that planet's default. Otherwise Earth uses the
365.25-day convention and another planet uses the existing NASA table. These
choices occur only after the three quantity roles are bound. Both the complete
family and all four astronomy IDs use this parser before older table queries.
Unparsed conversion intent cannot fall through to a one-year table value.

`Space_Export.thy` exports the new constructor, scans its three theorems for
oracles, and checks the original conversion, reverse direction, zero count,
zero target period and negative count. `main.sml` names the new theorems in
native provenance. `check_year_conversion.py` checks the shared 21-case pack
and 15 additional independent semantic cases through every astronomy ID and
family routing; its expected rational values do not call the implementation.

## The theorem statements

For any source and target labels, count `n` and periods `ps`, `pt`:

- `year_conversion_model`: assuming `0 <= n`, `0 < ps`, `0 < pt`, the actual
  `kernel (AYearConvert src dst n ps pt)` returns
  `Exact ''year_years'' (qval (AYearConvert src dst n ps pt))`, that returned
  value multiplied by `pt` equals `n * ps`, and the value is nonnegative.
- `year_conversion_answer_equation`: if that kernel request returns
  `Exact k q`, then `0 <= n`, `0 < ps`, `0 < pt`, `k = ''year_years''`, and
  `q * pt = n * ps`.
- `year_conversion_declines`: that kernel request returns `Decline w` exactly
  when either period is nonpositive and `w = Impossible R_nonpositive`, or
  both periods are positive, the count is negative and
  `w = Impossible R_physical_domain`.

These are claims about the typed request and its computed answer. They do not
prove English role assignment, the truth of user-supplied periods or NASA data.

## Boundaries and integration

The response text uses twelve significant digits. Space's existing JSON value
contract still uses six significant digits. The active Python w551 comparator
compares complete response templates and exact displayed numbers; differing
Python/native prose is `unsupported/unmatched_text`, not a contradiction or a
proof of agreement. The native calculation must be tested as its own consumer.

The native recognizer accepts the shared exact lexer, including fractions and
scientific notation. The Python repair currently accepts decimal counts only.
The native recognizer refuses an otherwise valid period supplied for a third
planet unused by the conversion; the Python parser currently ignores it after
checking it is a valid positive period. These scopes must not be described as
identical.

## Appliance overlay

The requested combined overlay is `var/usage-20261027/earth-space-overlay`. It
copies the earlier Earth overlay unchanged and adds the exact tested Linux
Space binary. Its manifest SHA-256 is
`dc629dbb008931288fed19f3da459be287fa7152da1378de98c3fa9af3a3749f`.
The replacement explicitly requires the pinned prior Space digest
`725a57a7ec25a13f1a8f155183013520b3c1636c91cd3a90c4440e06a0c0552e`.
It contains both family provenance records, their exact source/build identities,
17 specialist mappings and inspected runtime requirements. Space requires
Linux x86-64, `libgmp.so.10`, `libc.so.6`, GLIBC symbols through 2.34, and
`/lib64/ld-linux-x86-64.so.2`.

The actual `apply_kernel_overlay` function passed against a scratch copy of the
pinned manifest and matching real binary payloads. The resulting manifest has
20 families and 137 mapped specialist IDs. Check receipt:
`var/usage-20261027/earth-space-overlay-check.json`. An earlier check using the
slim checkout's LFS pointers was correctly refused as a base-binary mismatch;
no pointers were counted as executable payloads. Baseline Earth files and
existing candidates were not changed. Root owns final candidate provisioning,
full-engine consumption and receiving-host acceptance.

## Exact checks

```sh
python3 tools/dev/remote-build hbox src/extract/space Veri7vn_Space -d src/extract/commons --expect 'VERI7VN_SPACE PASS'
GENERATED_SML=/Users/ember/dev/o7vn/var/space/remote-attempts/20261027T044215Z-0630d8985292/results/export/Veri7vn_Space/Veri7vn_Space.Space_Export/code/space.ML sh src/extract/space/build.sh
python3 src/extract/space/check_year_conversion.py --binary var/space/bin/space --out var/space/mars-native-macos.json
python3 -B src/extract/space/score.py --binary var/space/bin/space --out var/space/mars-panels-macos.json
python3 tools/deploy/linux-family.py space hbox --from-receipt var/space/remote-attempts/20261027T044215Z-0630d8985292/receipt.json --runtime-overlay
python3 src/extract/space/check_year_conversion.py --host hbox --binary /home/hbox/veri7vn-deploy/build/space-1793076556-95736/space --out var/space/mars-native-linux.json
```

Changed tracked sources: `Space.thy`, `Space_Export.thy`, `recognizer.sml`,
`main.sml`, `capabilities.json`, `README.md` and new
`check_year_conversion.py`, all under `src/extract/space/`, plus this report.
Root committed the native repair as `381d8d8`. The original native lane used
one scoped Space build; the later dependent-session check is recorded below.

## Dependent Fusion compatibility check

After the native commit, root requested one scoped check of the known consumer.
The managed hbox attempt `20261027T045401Z-732ecb64f2ed` **failed**, exit 1, after
4m50s. All parent heaps were reused; only `Veri7vn_Fusion` was built. No Fusion
files or existing binaries were changed. The exact command was:

```sh
python3 tools/dev/remote-build hbox src/extract/fusion Veri7vn_Fusion -d src/extract/quantity -d src/extract/commons -d src/extract/energy -d src/extract/climate -d src/extract/space --expect 'VERI7VN_FUSION PASS' --no-exports
```

The failure is at `Fusion_Nodes.thy:333`: `planet_weight_node` applies
`Space.weight_model` without establishing `0 <= k`. The existing accepted-kernel
fact `ex` already implies that condition through `Space.physical_domain`, but
the consumer currently extracts only positive planet mass and radius. This
pre-existing omission is separate from the new year-conversion equation. The
recommended repair is to derive the nonnegative weight from `ex`, pass it to
`Space.weight_model`, and include it in the consumer theorem's conclusion.
Root was notified before any Fusion edit and transferred `Fusion_Nodes.thy`
for the repair. The theorem now also concludes `0 <= k`, derived from the
existing accepted-kernel fact; no new assumption was added. Both the original
weight equation and stated-decimal bound are retained. No theorem consumer
needed a conjunction adjustment (only the export oracle scan references it).
The same bounded check then **passed**, exit 0, as attempt
`20261027T050101Z-f552edec465e`. The stored session log contains
`VERI7VN_FUSION PASS theorems=39 oracles=0`; the managed receipt confirms the
marker, completed build and stable source snapshot. Fusion itself took 4m49s
(5m09s total driver build time). Parent heaps were reused.

Failure receipt:
`var/fusion/remote-attempts/20261027T045401Z-732ecb64f2ed/receipt.json`.
The stored `results/session.log` and `results/build.log` contain the exact failed
subgoal. Passing repair receipt:
`var/fusion/remote-attempts/20261027T050101Z-f552edec465e/receipt.json`.

This establishes proof compatibility of the current Space request type with
Fusion, including its connected planet-weight theorem and build-time self-test.
No new Fusion panel score or binary was produced; `--no-exports` kept this a
compatibility check. The only additional source change is
`src/extract/fusion/Fusion_Nodes.thy`, assigned by root after the concrete failure.
