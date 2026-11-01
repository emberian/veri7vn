# F Trades — saturated digital RGB colour lists

Staged implementation, not yet promoted while E awaits integration/capture.
All six specialist surfaces remain inventoried in D-trades.md. This packet
addresses crafts: actual red+green+blue was withheld although the organ promises
white; the old reader required exactly two distinct colour words.

The typed RGB request now holds a list. Red, green, blue, cyan, magenta, yellow,
white and black are canonical sets of full-intensity channels. Combining a
nonempty supported list takes the channel union and returns its canonical name.
This supports arbitrary lists and repeated colours. Existing painter-wheel
mixing remains its separate RYB model. Explicit RGB/digital wording enables the
full eight-colour model; ordinary primary-light questions retain their existing
meaning, including the promised three-primary result. The response explicitly
says saturated digital channels and disclaims brightness/spectral prediction.

## Checked statements and boundary

If the kernel returns Hue(k,c) for MixRgb(cs), k is mix_rgb, cs is nonempty,
every input is in the supported eight-colour set, and the output channel set
is exactly the union of the input channel sets. Thus no channel can disappear
or appear without an input supplying it. The fold's set-union law and an
independent compatibility law prove all previously supported binary table
results agree. There are no new axioms or proof bypasses.

The model assumes saturated digital channels, not arbitrary physical colour
spectra or weighted intensities. Orange/teal inputs and weighted mixtures are
valid but unsupported, so they count as valid withheld. Unknown words and
numbers are not silently dropped to answer a smaller mixture. RGB secondary
colours in unqualified physical-light questions remain withheld. English
recognition, numeric lexing, native compilation and framing remain untrusted.

## Results

Both isolated and whole-family modes: shipped 357/357, fresh seed20280318
360/360, untouched seed20280419 355/355; 0 wrong, 0 false yes. E matches both
fresh panels exactly. The official scoped scorer also gets357/357, while its
verdict remains INCOMPLETE because full-head six-criterion evaluation was not run.
One initial shipped grammar omission ('gives') was corrected in the staged
reader before final measurement; it did not change the proven model.

76 authored probes: E 59 right/0 wrong/0 false yes/17 valid withheld;
F 69 right/0 wrong/0 false yes/7 valid withheld. Seven separate refusal-policy
assertions pass. Three unsupported NIOSH conversions are retained from E; four
RGB unsupported-model requests remain capability misses, not successes.
New probes include three primaries, secondary channels, repeated colours,
white/black, many-colour lists, unsupported/weighted input and empty input.

Five shipped-run starts 77.32,3.28,3.63,3.61,3.29ms; median 3.61ms. First launch
is reported. Fresh/untouched medians 3.12/3.04ms. These are local macOS timings.

## Binding and files

Managed proof persvati `20261018T085509Z-acbdda0dfb4c`: 47 roots, 0 oracles, exit 0.
Receipt under `var/F-trades/checkout/var/trades/remote-attempts/`.
The staged checkout copies passed E source and records its base and overlay in
`var/F-trades/checkout/stage-provenance.json`.
Export SHA256 `5f4fd7b4639e471dc41fe35fa2e70723e899dca00457fc817bb641411d1afa88`.
Native SHA256 `dd9ffbd1e7c0f4b41ce23e4eaca41dd8b138db6fbbd42634ee130a237065e85e`.
Actual-input receipt:
`var/F-trades/checkout/var/trades/native-attempts/20261018T090709Z-1a89c2ee1717/compile-inputs.json`.

Changed owned files: Trades.thy, Trades_Export.thy, recognizer.sml, main.sml,
capabilities.json, probes.json, score.py, README.md. Canonical staged sources
are in `var/F-trades/staged/`, hashes in final-source-hashes.json, summed
measurements in summary.json. Evidence: final-shipped.json, final-fresh.json,
final-untouched.json, before-fresh.json, before-untouched.json, probes-before.json
and parity/. Existing mix_rgb wire kind remains unchanged; the list constructor
is consumed by the staged reader and channel-union answer rendering.
Actual dispatcher composition, live integration and Linux capture remain pending.

The staged consumer check found the crafts wrapper discarded MixRgb declines
before acceptance. The final wrapper now preserves typed RGB underspecified
results. Native is superseded by
`dd9ffbd1e7c0f4b41ce23e4eaca41dd8b138db6fbbd42634ee130a237065e85e`,
with actual-input receipt
`var/F-trades/checkout/var/trades/native-attempts/20261018T090709Z-1a89c2ee1717/compile-inputs.json`.
This native repeats 357/357 shipped and 69 right/0 wrong/0 false yes/7 valid
withheld probes in both modes. All 7 policy assertions pass; the four RGB
assertions now require the typed underspecified kind, not merely silence.
Evidence: `typed-final-shipped.json`. Fresh/untouched and official results above
remain attributed to the preceding 28c1e1a2 candidate. The checked export is
unchanged. Actual composed refusal requires the staged RGB context sidecar.

Actual dispatcher execution with temporary F declarations passes both final
controls: cyan plus red RGB gives white, and weighted RGB produces terminal
underspecified. Receipt:
`var/C-runtime-consumers/staged-F-trades-declarations.json`. The unchanged
shared loader reads the staged sidecar for this test; normal E production
selection is untouched.
