# H Trades — source units for printing and fabric lengths

**Root adoption update:** H is now integrated and natively compiled. Scoped panels pass, but one negative-fabric default composition gap remains. The following drain account is historical; see the root integration section below.
Live Trades G remains integrated at e1e9427. Source is staged in
`var/H-trades/staged`, with a coherent build checkout and ancestry record under
`var/H-trades`. The final scoped proof passed 51 roots with zero oracles. The display adjustment
uses four significant digits for fabric lengths so small positive lengths do
not round to zero at three decimal places.

The G binary on the 151 authored questions gives 114 right, 4 wrong, 4 false yes
and 29 valid withheld, identically in isolated and family modes
(`var/H-trades/before-G.json`). Existing shipped mapped panels remain 357/357
for this baseline. Specific counterexamples are a 2 cm printed part with 0.2 mm
layers returning 1 instead of 100, half an inch of fabric read as five inches,
negative fabric length returning a positive result, and a supplied mm/s unit
accepted as layer thickness.

The replacement carries source unit tags into HOL for both part height and
uniform layer height. Both are converted to inches before calculating the least
integer layer count whose total height covers the part. Part height must be
nonnegative and layer height positive. The independent binding law states those
domain facts, H <= n*h, and (n-1)*h < H; a second law states n >= 0. Adaptive
layers, additional first-layer quantities and unknown unit vocabularies remain
unsupported rather than being silently simplified.

Fabric length is continuous. Its new binding law states the named result kind,
nonnegative source/output, and 36*y = source length in inches. It neither rounds
up to whole purchasable yards nor rejects fractional source lengths. Width,
area, waste and discrete strip layouts require different models and are
withheld. The same length conversion functions serve board-foot dimensions,
printing and fabric, while the board count remains discrete.

Recognition uses ExactNumeric and MeasuredInput, checks every numeric input,
and binds actual source units before grammatical role selection. It cannot use
a requested output unit to supply a missing source unit. English roles and
rendering remain untrusted. These are authored capability tests, not claims
that the proof certifies the English interpretation. Policy assertions for
valid unsupported requests are reported separately from capability counts.

Final proof, native, panels, startup and actual dispatcher evidence remain to
be collected before promotion. No Linux or full-head six-criteria claim exists
for H yet.

## Drain boundary

Root requested convergence on 18 October. H is preserved in scratch and has
not replaced the integrated G Trades source or binary. No additional H work is
being launched. The first scoped attempt
`20261018T101909Z-ab830d577579` failed because `nlinarith` is unavailable in this
Isabelle session. It was replaced by a direct use of the proven coverage law,
linear transitivity and `zero_le_mult_iff`. The subsequent attempt is
`var/H-trades/checkout/var/trades/remote-attempts/20261018T102417Z-09e44ae53927/receipt.json`.
Its final outcome will be appended below. The accidental main-checkout G build
`20261018T101808Z-17331a84d8cb` was cancelled through its own recorded driver PID;
it is not an H proof.

Exact staged/checkout byte hashes are in
`var/H-trades/drain-source-hashes.json`; there were no overlay differences at
drain. `var/H-trades/stage-ancestry.json` binds the coherent G base and H overlay.
The new reader has not yet been compiled against the new export. Any claim of
usable H completion would be premature.

Resume from these ordinary source copies. If the final receipt passed, copy its
exact `results/export/Veri7vn_Trades/Veri7vn_Trades.Trades_Export/code/trades.ML`
to the staged checkout's `var/trades/build/trades_generated.sml`. Create the flat
MLB with basis, that generated file, staged commons/ExactNumeric/MeasuredInput,
recognizer and main, in that order. Invoke the staged `tools/dev/native-compile`
with `--family trades --from-receipt <that receipt> --compiler <Isabelle MLton>`
and `-- -output <staged binary> <staged MLB>`; it shares the main compiler lock.
Do not invoke the main helper until intentionally promoting, because it publishes
the canonical live pointer. Then run the staged `score.py --binary <binary>
--out var/H-trades/final-shipped.json --probes`, fix reachable errors, measure
fresh/untouched panels and actual composed cases, and freeze before promotion.
Keep the existing G word-count and RGB controls in that comparison. The source
keeps all 115 G fixtures and adds 36 H fixtures, for 151 total.

Final staged proof result: **passed**, VERI7VN_TRADES PASS theorems=51 oracles=0.
Export SHA256 `0e688a0e775e626de5113c936714cbb9e8018b00000659dd81060ceaaecebab6`.
No H native was compiled or published after this proof. The 151-case baseline
remains a measurement of G, not a measurement of H. H stops here for drain.


## Root integration after drain

Root inspected the checked length-conversion, layer-cover/minimality and
fabric-balance statements and the executable request/reply path. The retained
51-root/zero-oracle proof was reused; no new proof attempt was needed. The first
staged native64b0006 compiled successfully and passed357/357 shipped items in
both isolated and family modes. Independent probes found that the English
framing vocabulary omitted “for” in ordinary layer questions. Root added that
word and18 independent regression cases; the original stage and first compiler
snapshot remain available.

The final live native isce7385b3968464b6f7d101f85628f5b594af1eac4d31f25d72272c6226239193.
Current-checkout compile20261018T112725Z-1ff3b389f02e matches the repaired staged
native exactly; the verifier reports no proof/runtime drift. The original G
live source/native hashes matched before adoption. Root froze the exact inputs
at `var/C-runtime-package/bound-prepared/20261018T112725Z-1ff3b389f02e/trades`.

Results in both isolated and family modes:

- Shipped:357/357 right, zero wrong/false yes/valid withheld.
- Fresh-seed mix20261018079:360/360 right, zero wrong/false yes/valid withheld.
  Five specialists use regenerated panels; Safety retains its shipped panel
  because no generator is present. This is not360 wholly new questions.
- Authored169:149 right, zero wrong/false yes,20 valid withheld. The149 comprise
  95 numerical/colour answers and54 correct invalid refusals. All20 explicit
  refusal policy assertions pass, but remain capability misses.
- Root's18 independent layer/fabric cases pass after the framing repair. On the
  original151 authored cases, H improves G's114 right/4 wrong/4 false yes/29
  valid withheld to131 right/0 wrong/0 false yes/20 valid withheld.
- Fourteen actual full-default checks:13 pass, one fails. Layer values, positive
  fabric conversions, existing board-count and RGB controls work. Negative
  fabric is answered by units-v3 despite Crafts returning a physical-domain
  refusal. Both candidates reach arbitration; the generic conversion wins.
  This is an unresolved composition error, not an isolated-reader failure.

The executable `src/extract/trades/check_composition.py` preserves four focused
consumer tests:layer count, positive fabric, negative fabric, and valid plain
signed conversion. It currently passes3/4 and exits1. Changing global arbitration
or making all signed conversions invalid would exceed this bounded repair and
would not faithfully represent the two models. A proper cross-model admission/
arbitration repair remains required; no full-default completion claim is made.

Evidence, consumer hashes and exact source ancestry are in
`var/root-trades-h/integration.json`. Linux comparison and scoped portable
packaging remain outstanding. The selected144-specialist delivery is unchanged.
No native/proof job or implementation deputy remains from this integration.


## Default composition repair landed afterward

The negative-fabric default failure above is now repaired by the checked
contextual refusal tie preference and complete Crafts material context metadata.
See `K-runtime-domain-tie.md` for the actual candidate readings, new proof and
composition checks. The expanded default panel passes24/24, and the permanent
14-case composition regression passes against the live dispatcher. The updated
metadata/source capture for future Trades portability work is
`var/root-physical-arbitration/prepared/trades`; the earlier capture remains
historical. The Trades native and its357/357 shipped result are unchanged.
