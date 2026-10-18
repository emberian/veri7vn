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

Scout status (2026-10-17): prototype. Quantity and acoustics are ported and
at panel parity; the other fourteen families still carry their copies. See
`SCOUT_REPORT.md` at the worktree root for the duplication numbers and the
migration cost.
