# C-earth — useful requests and explicit boundaries

Status: checked kernel and exact native pass all shipped panels, fresh panels,
reserved seed and authored probes. Exact composed acceptance and immutable package capture pass. The C source was committed in `5327e3c`; its exact selected native is retained
in the package capture. No failed build export was consumed.

Earth covers geography, geology, seismology, hydrology, ocean, meteorology,
greenhouse and greenhouse-r2. The Gutenberg–Richter reader now accepts both
`a-value 6` and `a = 6` with the same typed request. It still declines counts
missing the region's coefficients or magnitude threshold. No new answer kinds.

An author probe found a real false answer outside the shipped panels: an invalid
95° latitude was silently dropped, then a great-circle question was answered as
a north–south distance. Latitude validation now reaches the kernel; the latitude
fallback cannot take a question containing longitudes.

The numeric export keeps its self-tests at build time. They previously ran at
every process start, even for an unrelated question (~1.1 seconds here). Short
questions no longer calculate an answer just to decide whether to calculate it,
and a proved code equation shares the sentence/value decimal for the common
four-digit reply format. Existing 50/100/140-bit precision choices are preserved.

## Checked assurance

- Swapping both endpoints of successful great-circle kernel requests leaves the
  real distance unchanged, independently of the computed intervals.
- An answered weather reply is either the explicit wind-chill undefined note,
  or its actual stated decimal and the number inserted into the sentence are
  within the layout error of `w_phys r`.
- Explicit impossible-input equivalences cover geological age/fraction/half-life,
  seismic moment and travel speeds, Manning and fill-time inputs, and greenhouse
  humidity, temperature poles, photoperiod, high/low order and spacing. A missing
  half-life is underspecified, and a nonpositive provided half-life is impossible;
  the audit's originally proposed fraction statement omitted that distinction.
- Manning now requires positive roughness/perimeter and nonnegative area/slope.
- Seven previously unscanned theorem names are included (one denotes seven
  component facts). No claim is made about the English recognizer being proved.

## Final checked measurements

Selected proof: `var/earth/remote-attempts/20261018T073427Z-2376f043dea9/receipt.json`,
hbox exit 0, marker found, source stable, fresh exports published. Immutable
assertion export says `VERI7VN_EARTH PASS theorems=116 oracles=0`.

- Generated SML SHA256: `745f67de3aa451ec425e06e7175f9563b4df75f28e3f7ecc9fb5b53d18252ac7`.
- Native `var/earth/bin/earth`: `8ad365dd0616279833ec6b42d6c6c65510aee8ff384dcf38347f54fcc94d9462`, 911064 bytes.
- Actual consumed compiler inputs: `var/earth/native-attempts/20261018T075139Z-215e77668727/compile-inputs.json`.

The common native helper froze and hashed the actual generated SML, family regex,
recognizer and main before compiling, bound the generated code to the passed
proof receipt, then rechecked the frozen inputs. The family build script now
uses that helper. No shared numeric lexer is consumed by this C binary.

| Panel | Right / total | Wrong | False yes | Valid withheld |
|---|---:|---:|---:|---:|
| Shipped | 554/554 | 0 | 0 | 0 |
| Fresh offset 701 | 354/354 | 0 | 0 | 0 |
| Fresh offset 1701 | 346/346 | 0 | 0 | 0 |
| Reserved offset 9701 | 342/342 | 0 | 0 | 0 |
| Authored probes | 20/20 | 0 | 0 | 0 |

The original shipped organs score 549/554, with five withheld Gutenberg–Richter
questions; the new reader answers all of them. Before the reader changes, fresh
701+1701 scored 690/700; the checked binary scores 700/700. Hydrology and meteorology
do not ship generator source anywhere in upstream: their shipped panels and
refusal probes are covered, with no independent fresh-panel claim for those IDs.
Generators retain the original authors' wording templates and blind spots.

The official actual-family harness independently scores all 554 shipped items
correctly. Its labels remain INCOMPLETE because the head/core/self admission
checks were not run in this scoped repair; full six-criterion completion is not
claimed. Four panel medians also remain above the 5ms target.

Shipped p50 milliseconds: geography 0.108, geology 20.199, seismology 21.880,
hydrology 0.165, ocean 2.195, meteorology 0.255, greenhouse 12.378,
greenhouse-r2 12.190. Cold median is 3.25ms, compared with roughly 1.1 seconds
before removal of exported startup self-tests. Expensive interval queries still
retain their prior precision; further numerical performance work remains.

Receipts: `var/earth/c-final/report.json`, `var/earth/c-parity/`,
`var/earth/c-final.log`, `var/earth/c-parity.log`, `var/earth/c-native-final.log`.
Commands:

```
python3 -B src/extract/earth/beyond.py --seeds 701,1701,9701 --out var/earth/c-final
python3 -B tools/parity/harness.py --answerer 'var/earth/bin/earth' --specialist geography,geology,seismology,hydrology,ocean,meteorology,greenhouse,greenhouse-r2 --split both --out var/earth/c-parity
```

## Composed refusal and model limits

The family capability overlay declares actual `impossible` refusals for geography
and ocean, and `imprecise` numeric refusals for every Earth specialist. The ocean
context adds the specific shallow-water phrase. Runtime's actual unpinned
consumer now retains the invalid-latitude refusal as decisive and runs no fallback
stage; Gutenberg–Richter 100 also answers. Receipt:
`var/C-runtime-consumers/earth-declines.json` (explicitly warm binary, proof pending).
The family/merged-contract probes additionally retain both zero-depth tsunami and
shallow-water travel refusals (`var/earth/c-capabilities.json`).

The C packet does not establish complete domain coverage. Subsequent adversarial
probes found unsigned-token errors in geology and ocean, truncation of a runoff
coefficient of 1.5 to 1, and an unbounded daily-light duration. These are recorded
with actual replies and a model ledger for all eight Earth and six climate IDs in
`var/earth/d-domain/LEDGER.md` and `ledger-probes.json`. The next Ocean source is
prepared separately, using the shared exact lexer and physical feasibility
conditions. It is not part of the checked C source or score claims. The durable next-wave
ledger is [D-earth.md](D-earth.md).

The selected final native passes four actual dispatcher probes in
`var/C-runtime-consumers/earth-final.json`: invalid latitude is terminal
impossible, Gutenberg–Richter count100 answers, and both tsunami and generic
shallow-water zero-depth travel are terminal impossible. These are bound to the
final native hash. Generic shallow-water refusal currently says “A tsunami
needs...” despite the broader accepted context; the boundary is correct, while
that noun remains narrower than the question. Immutable package capture is
`var/C-runtime-package/bound-prepared/20261018T075139Z-215e77668727/earth`.
Root committed `5327e3c`; subsequent D source is separate from this captured C packet.
