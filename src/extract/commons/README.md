# commons

One home for what every extracted family kernel under `src/extract/` was
carrying its own copy of.

- `Commons_Num.thy` (session `Veri7vn_Commons`): the numeric core as HOL
  definitions with their proofs — exact rationals read as reals, the
  floatarith glue into Isabelle's verified interval arithmetic, decimal
  rounding (`round_at`, `round_sig`, `to_dec`, `enclose`) with the error
  bounds, and the ASCII number layout (`render_dec`, `show_int`, `show4`,
  `show_input`, `render_fixed`, `render_trim`). Provenance: lane D wrote the
  first enclosure and layout, lane G proved the bounds and parameterized the
  layout; every later lane copied lane G. Nothing here knows a request, a
  kind or an organ; family policy constants (for example `prec`, the interval
  precision: 53 for quantity, 64 for acoustics) stay in the family.
- `commons.sml` (UNTRUSTED, like every family's `regex.sml`/`main.sml`): the
  canonical regular-expression matcher (lane D's, extended by lane G with
  `^`, `$`, `{m,n}` and lookbehind — a strict superset, same API) and the
  answerer-contract JSON framing from `main.sml`. A family's `.mlb` lists
  this file instead of its own `regex.sml`, and its `main.sml` keeps only
  the family dispatch.

## Using it

An importing family session declares `Veri7vn_Commons` in its ROOT `sessions`
and the family theory imports `"Veri7vn_Commons.Commons_Num"`, deleting its
local copies of the items above. Builds add `-d src/extract/commons`. The
generated SML is unchanged in shape: `export_code ... module_name <Family>`
inlines the commons code into the family module.

Status (lane W5-12, 2026-10-17): every family kernel under `src/extract/` that had a
private copy now imports this session and links `commons.sml`: anatomyagri,
chemistry, climate, computing, discrete, emoptics, energy, facts, geostats,
humanities, life, materials, mechanics, space, trades (and, SML half only,
stores and fusion), as quantity and acoustics did before. `Commons_Export.thy`
is the session's own check: a self-test of the number layout and the verified
enclosure, the theorem list scanned for oracles, and the marker
`VERI7VN_COMMONS PASS theorems=11 oracles=0` as the last command. The Regex
in `commons.sml` has three case modes (`compile` lower-cases the pattern and
expects a lower-cased text; `compileCS` keeps case; `compileI` is Python's
re.I with `(?-i:...)`), backreferences `\1`..`\9` and `matchHere`, folded in
from the four families that had private engines. Names a family defines with a
different meaning than the commons one (materials and space: `enclose`,
`render_fixed`, space also `to_dec`) are hidden from the commons side in that
family; `to_fixed` (climate, trades, computing) is policy and stays local.
