# The materials family, end to end

Six shipped Oracle7 specialists as one program: `additive-v2` (3D-printing arithmetic),
`materials-v2` (crystals, aerogels, stress and strain), `soil`, `soil-r2`, `water` and
`water-r3` (`upstream/root/specialists/<id>/`). `soil-r2` and `water-r3` only add a
"stay quiet on a neighbour's question" check to `soil` and `water`, so they share the
kernels and differ in the recognizer.

Same recipe as the quantity family (`../quantity/README.md`): the formulas and the decisions to
decline are HOL with proofs; Isabelle exports them to Standard ML; the MLton inside Isabelle
builds one standalone binary; the English reader (`recognizer.sml`, `../commons/commons.sml`) is
hand-ported from the organs and is **untrusted**; `tables_check.py` ties the HOL constants and
the texture rule list to the organ files.

New here: the irrational values (OpenSCAD sphere, cylinder and cone volumes, the packing
factors, pH and its inverse) are enclosed in verified intervals with `pi`, `sqrt`, `ln` and `exp`
from `HOL-Decision_Procs.Approximation`, then rounded in the layout each organ prints. Theorems
state the bound for every printed digit string (`enclose_sound`, `stated_of_sound`).
Soil texture is a typed class decided by the organ's twelve ordered rules.

```sh
tools/dev/remote-build persvati src/extract/materials Veri7vn_Materials -d src/extract/commons --expect 'VERI7VN_MATERIALS PASS'
python3 -B src/extract/materials/tables_check.py
VERI7VN_GENERATED=/path/from/successful/receipt/materials.ML sh src/extract/materials/build.sh
PYTHONDONTWRITEBYTECODE=1 python3 -B src/extract/materials/score.py
PYTHONDONTWRITEBYTECODE=1 python3 -B tools/parity/harness.py --answerer var/materials/bin/materials --specialist additive-v2,materials-v2,soil,soil-r2,water,water-r3 --split both --out var/materials/parity
```

Result: every item of every shipped panel is right, 0 wrong, 0 false yes, 0 disagreements
with the organs (`water-r3` has no panel of its own; it is scored on `water`'s). Details in
[the handoff](../../../project/lanes/S08-materials.md).

## Linear-elastic inverse calculations

The materials specialist also computes stress from Young modulus and strain,
and strain from stress and Young modulus. Inputs can use Pa, MPa or GPa;
strain can be a ratio or a percentage. Compression may use a negative sign.
The kernel refuses a nonpositive modulus. The answer names its assumption:
uniaxial linear elasticity. It does not decide whether a real sample remains
elastic or whether a structure is safe.

`capabilities.json` records the model boundary for dispatch and packaging.
The new requests reuse the existing `stress` and `strain` kinds, and their
replies name the binding theorem selected by the typed request. Recognition
of English and unit labels remains untrusted.

`score.py --fresh-seed 20261018 --out var/materials/fresh-score.json --probes`
runs fresh samples from the shipped generators and the authored extension
probes. Fresh seeds vary selections from the generators' existing pools;
they do not provide independent phrasings. `generation.json` records exactly
which generator supplied each specialist.
