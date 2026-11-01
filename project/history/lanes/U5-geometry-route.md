# U5: stop the geometry specialist from bypassing dimensional checks

The actual `geometry-v4 → Family → w504` consumer now answers the recorded
mixed-unit rectangle as **0.12 m²**, and the recorded diagram rectangle as
**12 square units** without inventing inches. The inherited non-rectangle
formulas refuse unsupported mixed or invalid length units instead of using raw
numbers. Twenty-three focused consumer tests pass.

The specialist's own published scorer gives **96 valid correct / 0 wrong plus
4 correct refusals on dev**, and **89 valid correct / 0 wrong plus 4 correct
refusals on heldout**, unchanged from the pre-edit replay. These are read-only
replays of published split rows, not a fresh held-out set or the six-criterion
Workbench exam. No full Engine, build, Mini admission, or theorem was run here.

## Observed route and exact corrected meanings

The real U5-v1 appliance receipts at
`var/u5-service/u5-v1-real/calls.jsonl` show `geometry-v4` replacing the core's
clarification at `specialist_call>specialist:geometry-v4>rect_area`:

| Original request | Actual U5-v1 reply | New controlled consumer reply |
|---|---|---|
| Rectangle length 3 meters, width 4 centimeters; area | Bare 12 | 0.12 m², from 3 × 0.04 |
| Rectangle length 3 in the diagram, width 4 in the diagram; area | Bare 12 | 12 square units |

The first was a wrong dimensional answer: 3 m × 4 cm = 0.12 m² = 1200 cm².
The second was incomplete/unqualified, not an established wrong scalar; it did
not explicitly claim inches. Its useful interpretation is unitless diagram
lengths, which the new response names clearly. The frozen appliance and original
replies were not modified.

Full original Engine replies and new controlled consumer replies are retained
separately in `var/usage-20261026/reliability/route/consumer-comparison-final.json`.
The new rows are not labeled as full-Engine output.

## Implementation and its limits

`GeometryOrganV4` previously delegated directly through v3/v2 to v1, whose
`val` reader stripped units from dimensions. The new standalone dimensional
reader binds explicit named dimensions, checks repeated-role consistency and
matches supported units to their scale. It has no dependency on the head's
word-problem import path.

For rectangles with explicit length and width:

- A common unit keeps its original scale: 3 cm × 4 cm becomes 12 cm².
- Different supported units are normalized to meters: 3 m × 4 cm becomes
  0.12 m², or perimeter 2 × (3 + 0.04) = 6.08 m.
- Explicitly unitless diagram dimensions become square units or units.
- A physical dimension mixed with a unitless one is refused rather than
  assuming a missing unit.

Other inherited dimensional formulas keep their valid same-unit numeric results
and now name the linear, squared or cubed unit. Unsupported mixed units are
explicitly withheld. Unknown units, powered/compound units used as lengths,
unbound physical dimensions and negative dimensions cannot silently reach the
legacy raw-number calculation. Radius/diameter must agree, and cube side/edge
must describe the same length. Equivalent-unit duplicates remain consistent.

The reader distinguishes `in` at an inch-measurement boundary from `in the
diagram`, `in this drawing`, or similar bounded diagram phrases. It does not
pretend to resolve arbitrary English prepositions. Numeric apartment identifiers
are not dimensions. Rounding and ordinary location wording remain supported;
explicit requested output conversions and multiple measures/shapes remain
bounded limitations.

The real manifest acceptance wrapper originally discarded precise refusals for
supported square/box/cuboid and plural-shape requests because its decline-context
regex omitted those nouns. Root approved extending that context to actual
supported shape names and plurals. The consumer tests check the resulting
withheld replies through `Family` and w504, not only by calling the raw organ.
Shape mentions without a requested geometry calculation leave the original
parent response unchanged. No saved verdict, files hash, scorer, or admission
record was edited to authorize this repair.

The scope remains conservative. It does not add general mixed-unit conversion
to all geometry formulas, output-unit conversion, multiple-shape aggregation,
or an English theorem about binding. Formula-only unitless published tasks keep
their old behavior. A later root-coordinated full-family Engine replay is still
needed; this harness loads only the repaired specialist into the actual Family.

## Exact checks and measured panel outcomes

```
.venv/bin/python -B -m unittest discover -s tests/usage/reliability_route -v
```

Result: **23 tests passed**. They use actual geometry-v4, actual manifest
acceptance, actual Family isolation/selection and the actual w504 `chat` method.
Only the expensive parent is substituted. Successful parent replies and deliberate
parent refusals stay unchanged; unrelated requests fall through. Additional
controls cover mixed units in cylinder, cone, triangle and box formulas, malformed
units, physical/unitless mixtures, duplicate dimensions, cube/radius consistency,
shape count, request scope, unit aliases and retained positive calculations.
Full output: `var/usage-20261026/reliability/route/tests-final.txt`.

```
.venv/bin/python -B tests/usage/reliability_route/score_shipped.py \
  --out var/usage-20261026/reliability/route/panels-after-final.json
```

The runner reads the shipped list-format `geometry_panel_v3.json`, calls the
actual organ acceptance wrapper, and uses its unchanged `geometry_scorer.ok`.
It never calls the mutating Workbench exam entry point. Before/after records:
`var/usage-20261026/reliability/route/panels-before.json` and `panels-after-final.json`.

| Published split | Rows | Valid correct | Wrong | Valid withheld | Correct refusal | False yes |
|---|---:|---:|---:|---:|---:|---:|
| Dev | 100 | 96 | 0 | 0 | 4 | 0 |
| Heldout | 93 | 89 | 0 | 0 | 4 | 0 |

Both pre-edit and repaired versions receive all 193 good judgments. **173 complete
wrapper replies are identical; 20 change only by adding the supplied linear,
squared or cubed units to correct circle/sphere calculations.** No previously
correct scalar or refusal regressed. The retained final median per-call times
were approximately 0.046 ms dev and 0.047 ms heldout; these are narrow in-process
observations, not appliance performance claims.

The specialist scorer checks scalar agreement and decline status. It does not
establish dimensional completeness; that is why the independent physical
examples and response-unit assertions accompany its numbers. DOMAIN gain versus
the live head, core-lane takeover, identity preservation across the full head,
and all six Workbench criteria have not been measured in this lane.

## Changed files and handoff

Approved mutable files:

- `var/ap1-upstream-slim/root/specialists/geometry-v4/organ_geometry_v4.py`
- `var/ap1-upstream-slim/root/specialists/geometry-v4/manifest.json`

Public owned additions:

- `tests/usage/reliability_route/test_geometry_route.py`
- `tests/usage/reliability_route/score_shipped.py`
- `project/lanes/U5-geometry-route.md`

Original source and manifest snapshots, final hashes, focused receipts and
published panel replies are under `var/usage-20261026/reliability/route/`.
Root owns source checkpointing, portable patch export and the next v2 candidate.
No candidate or upstream file was edited, no admission verdict was rewritten,
and no Git/staging operation or subagent was used.


## Final review coverage and freeze

The final reader also accounts for every number before recomputing a physical
or diagram answer. Named numeric apartment identifiers are explicitly exempt;
an extra dimension tuple such as “also 5 by 6” is ambiguous and is refused.
Supported formulas have explicit role sets, so a sphere's extra height or a
circle's extra height cannot disappear while the response gains an authoritative
unit label. These are bounded coverage checks, not assumptions that every English
quantity has been understood.

Non-calculation questions such as “Who discovered the area formula of a circle?”
and questions about a formula's history, name or color preserve the parent reply.
They do not become demands for a radius merely because a measurement noun occurs.
Those controls are included in the final 23 passing tests and fresh published
panel replay.

The serving standing lists inspected (`standing_v1.txt` and `standing_v2.txt`)
name `geometry-v4`; no other geometry entry appeared in the standing-list search.
The full-family Engine remains root's next check, not something inferred from
this narrower actual-Family test.

Final source SHA256:

- `organ_geometry_v4.py`: `c2ea6f84cd23d166bba191fe2b798ba7b84362df91deb160e816914c3d871f24`.
- `manifest.json`: `a2096877a10091c86fc16171e5c9b0a791b7c7e4a0ca86accc1d1d371392d538`.

These files are frozen for root's checkpoint and export. The exact public file
list is the two files under `tests/usage/reliability_route/` and this report.

Root reviewed the source and manifest changes and reran all 23 route tests.
Private-source checkpoint: `013b961`. The portable repair is
`tools/usage/reliability/u5-geometry-route.patch`, for the next candidate after
the U5 word-reader unit patch. The earlier failing candidate remains intact.
