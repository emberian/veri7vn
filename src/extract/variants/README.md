# Variants of the quantity family: densities-r2, units-v2, units-v3-r2

Three shipped manifests that are versions of specialists lane G already lifted
(`src/extract/quantity/`). They add no kernel behaviour, so this folder has no
Isabelle session: it reuses lane G's checked kernel (`Veri7vn_Quantity`) and
adds one small untrusted SML layer, `variants.sml`, that only withholds.

- `densities-r2` = densities + `names_narrowing_v1` (silent when a material word
  appears only capitalised mid-sentence, "the mass of Mercury").
- `units-v2` = the `organ_units_v2` organ, which lane G's recognizer already had
  inside units-v3 (exact rationals, quantity-first phrasing, `narrow_v1`).
- `units-v3-r2` = units-v3 + a boundary rule: silent on turns with heat loss /
  R-value / U-value / heating degree days markers and none of units' own.

```sh
sh src/extract/variants/build.sh                  # exports lane G's session db, builds var/variants/bin/variants
python3 src/extract/variants/variants_check.py    # material patterns equal the organ's MAT_RX
python3 src/extract/variants/score.py             # panels + differential against the variant organs
python3 tools/parity/harness.py --answerer "var/variants/bin/variants --specialist {id}" \
  --specialist densities-r2,units-v2,units-v3-r2 --split both --out var/variants/parity
```

`build.sh` derives `RecognizerBase` from lane G's `recognizer.sml` with `sed`
(renames the structure and exposes `densities`, `unitsV2`, `unitsV3`); nothing in
`src/extract/quantity` is edited. Handoff: `project/lanes/S17-variants.md`.
