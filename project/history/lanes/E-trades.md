# NIOSH request and input corrections, 18 October 2026

Status: proof and final native passed; source frozen for runtime capture and
root integration. Persvati attempt `20261018T080922Z-1ba32c1e8f2b` passed,
44 theorem roots and zero oracles. Two earlier attempts exposed unavailable
tactic/lemma names; the replacements use the local Isabelle multiplication
and division lemmas without changing the statements. A queued snapshot with
one stale alias was cancelled before execution.
The D packet is integrated as bce4811 and its input-bound native is preserved
as `var/E-trades/before-bin`.

A lifting-index question without a load previously returned a recommended
weight limit, because the target was inferred from whether a load had been
parsed. The request now keeps the target explicitly. Missing load receives
an underspecified refusal; it cannot silently select weight limit instead.
The NIOSH reader uses shared exact numeral spans and unique role matches.
For example, FM=1/2 previously became FM=1, returning 23 rather than 11.5 kg.

Necessary physical-model guards require nonnegative distances, angle and load,
FM between zero and one, and CM equal to 0.90, 0.95 or 1.00. A lifting index
also requires a positive weight limit. The guards do not choose which table
row applies to a real task, nor decide whether the NIOSH equation applies.
The original metric geometry conventions remain explicit assumptions.
Explicit incompatible length/angle units and percent multipliers are withheld
rather than silently interpreted as centimetres, degrees or bare ratios.

Checked independent laws:

- Horizontal, vertical, distance and asymmetry multipliers lie in [0,1] when
  the angle is nonnegative.
- Under the necessary domain guards the computed weight limit lies in [0,23] kg.
- An exact weight-limit answer has weight-limit kind and lies in that interval.
- An exact lifting-index answer has index kind, nonnegative load and index,
  positive weight limit, and index times weight limit equals supplied load.

The source for the FM/CM restrictions is the original
[NIOSH applications manual, tables 5 and 7](https://stacks.cdc.gov/view/cdc/5434/cdc_5434_DS1.pdf).
English roles, numeric lexing, framing and real-task applicability are untrusted.

Twenty-two new probes join the 35 prior probes. Before this change the D native
scores 42 right, 6 wrong, 6 false yes and 3 valid withheld in both modes.
Final E scores 54 right, zero wrong, zero false yes and 3 valid withheld.
The three valid withheld requests explicitly use inches, radians or a percent
multiplier. Their conversions remain unsupported. Separately, all three
refusal-policy assertions pass (baseline one of three). Label correction reused
saved replies; it did not rerun panels or count supported mathematics as invalid.
Two fixture kind labels were corrected from internal `li` to the established
wire kind `lifting_index`; the numeric answers and wire output were already
correct. Receipts: `var/E-trades/probes-before.json` and `final.json`.

Shipped panels score 357/357 in specialist and family modes. Fresh seed 20270718
scores 357/357; untouched seed 20270819 scores 363/363. D baseline results match
both samples. Safety has no shipped fresh generator, so its 89 original panel
cases are retained and explicitly identified; other fresh samples use the
original generator templates and are not independent question design.
The official scoped harness confirms 357/357 with zero wrong or false yes;
its overall verdict remains INCOMPLETE because full-head criteria were not run.
Source-to-table checks pass. The 862,392-byte binary's first measured launch
was 148.97 ms; the next four took 2.83–3.49 ms.

Native SHA256:
`f97cb01590df9e2d40d3c47e5994f650a9b16b688a2a47dbefcce1fdd8732bf1`.
Actual-input receipt:
`var/trades/native-attempts/20261018T081853Z-9962abc764e9/compile-inputs.json`.
Proof receipt:
`var/trades/remote-attempts/20261018T080922Z-1ba32c1e8f2b/receipt.json`.
Final hashes: `var/E-trades/final-hashes.json`. Checks, saved baseline comparisons,
and official scoped `parity` are under `var/E-trades/`.

Changed source: `Trades.thy`, `Trades_Export.thy`, `recognizer.sml`, `main.sml`,
`capabilities.json`, `README.md`, `probes.json`, and `score.py`, plus this report.
The safety consumer retains existing `rwl` and `lifting_index` wire kinds;
new laws appear in per-request theorem metadata. Runtime composition and
Linux/package capture remain separate from this native validation.

Composed testing exposed an acceptance-metadata gap for the new impossible
NIOSH domain refusal. The safety sidecar now accepts taken impossible declines
in its domain, so FM=2 can stop at the specialist instead of falling through.
The native is unchanged; runtime checks terminality separately.

The selected native passes four actual dispatcher checks: fractional RWL11.5,
fractional-load lifting index0.5, missing-load terminal refusal, and FM2
terminal impossible refusal. Receipt: `var/C-runtime-consumers/trades-E-final.json`.
