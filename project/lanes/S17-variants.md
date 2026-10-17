# Lane S17-variants: densities-r2, units-v2, units-v3-r2 (handoff, 2026-10-17)

Files: `src/extract/variants/{variants.sml, build.sh, score.py, variants_check.py, README.md}`.
Binary `var/variants/bin/variants` (579,112 bytes, not committed; cold start 7.4 to 8.0 ms).
No Isabelle session was built and there is no `VERI7VN_VARIANTS PASS` marker: the three
variants add no kernel behaviour (see the diffs), so they run on lane G's kernel,
`Quantity.reply_of`, from the `Veri7vn_Quantity` session database (`isabelle export -n`,
as lane G's build.sh). Theorems are lane G's (`kernel_exact_sound`, `stated_dec_sound`, ...),
see `project/lanes/G-quantity.md`. The layer is untrusted SML.

## Exact diff summary per variant

- **densities-r2 vs densities.** `organ_densities_v1.py` is byte-identical.
  `organ_densities_v2.py` (17 lines) subclasses it: collect every match of the 29 material
  patterns (MAT_RX); if `names_narrowing_v1.named_not_material` holds (some material word
  occurs only capitalised and not at a sentence start, none in lower case) return None; else
  v1's answer. `narrow_v1.py` and the panel JSON are byte-identical to densities'. Manifest
  differs by id, name, organ module/class, and note ("byte-identical to v1 on every panel
  input"). Ported as `densitiesR2` in `variants.sml`.
- **units-v2 vs units (lane G's units).** `organ_units_v1.py` byte-identical to units.
  The organ is `organ_units_v2.py` (exact rational factors, quantity-first "how many"
  phrasing, `narrow_v1`), identical to the file inside units-v3. Lane G's recognizer already
  ports it as `unitsV2` (used under units-v3), so this variant is that function exposed under
  its own id. The panel is a different file, `units_panel_v2.json` (149 items). `narrow_v1.py`
  identical.
- **units-v3-r2 vs units-v3.** `organ_units_v1/v2/v3.py`, `narrow_v1.py` and the panel are
  byte-identical. The new organ `organ_units_v3_r2.py` returns None when `NOT_MINE`
  (heat loss | R-\d{1,2} | R-value | U-value | heating degree days) matches and `MINE`
  (convert | conversion | how many W is/are/in | in <prefix>W?s? "?") does not, where MINE has
  a trailing lookahead that fails if `R-\d` occurs later. Else units-v3. Ported as
  `unitsV3R2`. No verdict files ship for it.

All three rules only turn an answer into a withhold; none creates an answer or changes a value.

## Results (lane A harness, `--specialist ID`; right / wrong / withheld-on-valid / false yes)

| Specialist | dev | heldout | Shipped heldout | p50 in binary vs 50 ms |
|---|---|---|---|---|
| densities-r2 | 51 / 0 / 0 / 0 (n=51) | 51 / 0 / 0 / 0 (n=51) | densities: 51/51, 0 fy (r2 inherits it: "byte-identical on every panel input") | 0.23 ms |
| units-v2 | 75 / 0 / 0 / 0 (n=75) | 43 / 0 / 31 / 0 (n=74) | 43 correct, 0 false yes, n=74 | 0.06 ms |
| units-v3-r2 | 76 / 0 / 0 / 0 (n=76) | 75 / 0 / 0 / 0 (n=75) | no verdict file; units-v3 shipped 75/75 | 0.08 ms |

The units-v2 heldout 31 withheld are the shipped organ's own misses, not ours: its panel holds
"I have 1 hours. How many minutes is that?"-style two-sentence questions and "What does 0 F come
to in K?" temperature phrasings, which units-v2 does not read (units-v3 added the two-sentence
form). The binary withholds exactly the 31 the organ withholds (shipped verdict fails list has
the same questions). Named, from `var/variants/score.json`: 21 two-sentence conversions
("I have 100 g. How many stone is that?", ...) and 10 "What does N X come to in Y?"
temperatures (e.g. "What does 0 F come to in K?"). Verdict `INCOMPLETE` only because the harness
had no head answerer (rules 1, 2 unmeasured).

Organ agreement (`score.py`): per variant, the binary agrees with the shipped variant organ
(answered/withheld, kind, value within the scorer tolerance) on its whole panel (0 disagreements)
and on about 650 more questions (every other quantity panel plus narrowing probes: Mercury,
Gold Coast, R-value, U-value, heat loss), 0 disagreements. The probes make the narrowing fire:
"What is the mass of 2 litres of Mercury?" is withheld by densities-r2 and answered by densities;
"Convert 5 feet to metres. R-13 insulation" is withheld by units-v3-r2 and answered by units-v3.
Binary 579 KB; worst single question 0.47 ms.

## Bug found while porting

`Regex` lower-cases patterns, which turns `\S` into `\s`: the Python `[\s\S]*` in MINE became
`[\s\s]*` and the R-13 probe disagreed with the organ. Fixed by writing `(?:.|\s)*`. Any other lane
porting `\S`, `\D`, `\W` through lane G's Regex has the same problem.

## Untrusted and remaining

Untrusted: `variants.sml` (hand port of the two narrowing rules), the sed-derived
`RecognizerBase`, JSON framing (lane G's main.sml, used as is), MLton. `variants_check.py` ties
the 29 material patterns to the organ's MAT_RX. No HOL theorem states the narrowing; it holds by
construction (a `NONE` guard around a base result). If root wants it in HOL, the narrowing
predicates would need regex semantics there. Remaining: none for scoring; the base recognizer
dependency means a change to lane G's recognizer.sml signature or `Narrow` could break build.sh
(its greps fail loudly).
