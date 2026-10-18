# G Trades — exact rectangular board-foot quantities

Promoted live successor to F Trades, native6ae6b577, frozen for root commit and
package capture. The staged ancestry is retained under var/G-trades/staged.
The prior F binary reads1/2 inch as2 inches, loses negative signs and reads1.5
boards as5. G fixes the quantity roles and preserves the shipped board-foot forms.

## Model and actual behavior

Each thickness, width and length carries its source unit: inch, foot, centimetre
or millimetre. HOL performs exact conversions and divides the rectangular cubic-
inch volume times complete-piece count by144. Count remains an exact rational
at the typed boundary, then the kernel requires a nonnegative integer. Dimensions
must be nonnegative. Bare thickness/width in conventional product notation retain
the inch convention; length requires an explicit unit. Partial-board quantities
are valid unsupported requests, counted withheld-valid rather than correct
invalid refusals. Metre source units remain unsupported in this packet.

The independent volume binding states that every successful result has
board_feet kind, nonnegative dimensions, nonnegative integral piece count and
144*q = inches(thickness)*inches(width)*inches(length)*pieces. A second theorem
proves q nonnegative. These statements assume rectangular complete pieces. No
nominal-to-dressed adjustment, irregular shape filling or waste allowance is
inferred. They do not prove the English reader chose the intended quantities.

The reader uses ExactNumeric masking, consumes unique product or named dimension
roles and every numeric token, and sends complete isolated unit fields through
MeasuredInput. Unit spans are local to their fields, not claimed as original
whole-question offsets. Compound units and quantities of another physical kind
cannot be silently relabelled. Explicit nonrectangular geometry and unspecified
waste allowances are withheld. Decimal punctuation does not become a narrative
sentence boundary; the raw numeric text still reaches the exact lexer. Shared
source is unchanged.

## Measurements

Both isolated and whole-family modes:357/357 shipped mapped,353/353 fresh
seed20280718,363/363 untouched seed20280819; all0 wrong and0 false yes. The
final official scoped harness also gives357/357. Its verdict remains INCOMPLETE
because the full-head six criteria were not run. Fresh sampling uses shipped
generator templates, not independently designed language coverage.

On115 authored probes, F gives76 right,17 wrong,10 false yes and12 valid withheld.
G gives101 right,0 wrong,0 false yes and14 valid withheld. Fourteen separate refusal
policy checks pass. Seven valid misses are inherited F safety/RGB cases; the
seven new valid misses are two partial-board quantities, a metre unit, a count
word beyond the finite grammar, two grouped counts and a compact count without
a quantity noun.
Appropriate refusal does not make those answered capabilities.

The actual Dispatcher passes19/19 targeted cases with exact staged native and
capability injection; after promotion ordinary live CLI passes21/21 including
the two F RGB controls: fraction2 board feet, mixed-unit4, scientific count800,
negative-dimension impossible, partial-board model refusal, incompatible units,
malformed numbers and unsupported metres. All declines are decisive. Receipt:
var/G-trades/promoted-consumer.json. No production selection was changed.

Shipped startup times are178.12,3.86,3.65,3.39,3.78 ms; median3.78 ms. First launch retained. These local macOS timings are not Linux performance
claims.

## Exact artifacts and remaining scope

Managed persvati proof `20261018T095022Z-7b306970ccf6`:49 roots,0 oracles,exit0.
The first attempt57398f775954 failed because the unread constructor's unreachable
answer branch did not follow the existing Imprecise convention; its missing-input
guard already determines the actual underspecified result. The guard/laws were
not weakened. Later reader fixes preserve quoted plank/piece forms and distinguish
grammatical nouns from source units; no further HOL change was needed.

Export SHA256 `9e3c0dd3e78815bc1980347c3bd37568d34d829edc59b1a2eeecf2751effc136`.
Native SHA256 `6ae6b577c52dec9cdd9b13abb0feb429c90f6d6c9e4f9c0d076ed9e8fe6c7547`.
Manifest:
`var/trades/native-attempts/20261018T101009Z-f16319dd717f/compile-inputs.json`.
The main shared helper accepted the staged proof closure and published the
identical selected6ae6b577 binary at the canonical live path. build.sh retains
executable mode100755. Dependencies are measured-input11f70352 and numeric2f313c77.

Nine source files are named and hashed in var/G-trades/ready.json: Trades.thy,
Trades_Export.thy,recognizer.sml,main.sml,build.sh,capabilities.json,probes.json,
score.py,README.md. They include the pending F RGB work. Summary totals are in
summary.json; final-shipped/fresh/untouched.json, before-F-count-corrected.json and parity/ hold
full results. Earlier232446/de84 candidates are retained under predecessor-/
de84- evidence. One earlier runtime fixture accidentally selected a crafts row
question by substring; its recorded exact question is preserved, and the final
fixture explicitly selects the woodworking malformed input. No shared-runtime
repair was needed for the final8/8 result.

Consumer: woodworking, existing board_feet kind, with explicit impossible and
underspecified acceptance. Other printing/architecture/woodworking numeric
readers retain separately recorded gaps. This packet does not claim to repair
those or infer arbitrary rectangular geometry from a natural-language story.

Independent review held9b7a2dc2: explicit “three boards” and “two boards” were
not consumed and silently defaulted to one. The replacement consumes complete
numeric or finite word-count phrases (zero through ninety-nine), refuses
unconsumed quantifiers/multiple groups, and never defaults an unspecified plural
source to one. Singular-noun mistakes such as “two board” still preserve the
supplied count. Unknown larger word counts are valid withheld. The source and
evidence for9b7 remain immutable under9b7a2dc2-source and9b7- result prefixes.
