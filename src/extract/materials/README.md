# The materials family, end to end

Six shipped Oracle7 specialists as one program: `additive-v2` (3D-printing arithmetic),
`materials-v2` (crystals, aerogels, stress and strain), `soil`, `soil-r2`, `water` and
`water-r3` (`upstream/root/specialists/<id>/`). `soil-r2` and `water-r3` only add a
"stay quiet on a neighbour's question" check to `soil` and `water`, so they share the
kernels and differ in the recognizer.

Same recipe as the quantity family (`../quantity/README.md`): the formulas and the decisions to
decline are HOL with proofs; Isabelle exports them to Standard ML; the MLton inside Isabelle
builds one standalone binary; the English reader (`recognizer.sml`, `regex.sml`) is
hand-ported from the organs and is **untrusted**; `tables_check.py` ties the HOL constants and
the texture rule list to the organ files.

New here: the irrational values (OpenSCAD sphere, cylinder and cone volumes, the packing
factors, pH and its inverse) are enclosed in verified intervals with `pi`, `sqrt`, `ln` and `exp`
from `HOL-Decision_Procs.Approximation`, then rounded in the layout each organ prints. Theorems
state the bound for every printed digit string (`enclose_sound`, `stated_of_sound`).
Soil texture is a typed class decided by the organ's twelve ordered rules.

```sh
python3 tools/dev/check-native --session Veri7vn_Materials --session-root src/extract/materials --expect 'VERI7VN_MATERIALS PASS' --timeout 900
python3 -B src/extract/materials/tables_check.py
sh src/extract/materials/build.sh
PYTHONDONTWRITEBYTECODE=1 python3 -B src/extract/materials/score.py
PYTHONDONTWRITEBYTECODE=1 python3 -B tools/parity/harness.py --answerer var/materials/bin/materials --specialist additive-v2,materials-v2,soil,soil-r2,water,water-r3 --split both --out var/materials/parity
```

Result: every item of every shipped panel is right, 0 wrong, 0 false yes, 0 disagreements
with the organs (`water-r3` has no panel of its own; it is scored on `water`'s). Details in
[the handoff](../../../project/lanes/S08-materials.md).
