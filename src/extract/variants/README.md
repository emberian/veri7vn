# Variants of the quantity family: densities-r2, units-v2, units-v3-r2

Three shipped manifests that are versions of specialists lane G already lifted
(`src/extract/quantity/`). They add no kernel behaviour, so this folder has no
Isabelle session: it reuses lane G's checked kernel (`Veri7vn_Quantity`) and
adds one small untrusted SML layer, `variants.sml`, that only withholds.

- `densities-r2` = densities + `names_narrowing_v1` (silent when a material word
  appears only capitalised mid-sentence, "the mass of Mercury").
- `units-v2` now also accepts the same explicit two-sentence conversion questions
  as units-v3 (for example, “I have 2 feet. How many inches is that?”). The shared
  recognizer accepts “What does 37 K come to in C?” and keeps the exact affine
  temperature model. These complete 31 previously missed shipped held-out items.
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
the quantity recognizer is copied by hand. Handoffs: `project/lanes/S17-variants.md`
and `project/lanes/C-physical-quantity-sound.md`.

To compile a specific successful remote proof export, set
`GENERATED_SML=/absolute/path/to/quantity.ML` when invoking `build.sh`.
The script preserves previous exports and replaces the finished binary atomically.
