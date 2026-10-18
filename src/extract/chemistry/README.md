# The chemistry family, end to end

Five shipped Oracle7 specialists (`chemistry`, `chemistry-v3`, `decay`, `labsolutions`, `labsolutions-r2`) as one
verified HOL kernel: element properties from PubChem's table, exact molar mass of any formula (brackets, hydrates),
grams and moles, percent composition, laboratory solutions (mass for a molarity, molarity, dilution, percent w/v) and
radioactive decay (exp and log2 only through verified interval enclosures). Isabelle exports it to SML and the bundled
MLton makes one standalone binary speaking the answerer contract (`--specialist ID` for one manifest's reading).
Proofs and statements, the numbers per panel and the untrusted parts: [lane S07 handoff](../../../project/lanes/S07-chemistry.md).
Tables are generated (`emit_table.py`) and compared with the organ files by `tables_check.py`.

Build: see the reproduction commands in the handoff. Result: every panel item the organ answers is right, 0 false yes.

Explicit reaction yields and leftovers use three clauses, for example:

```text
2 H2 + O2 -> 2 H2O; 4 mol H2, 1 mol O2; yield H2O in grams
2 H2 + O2 -> 2 H2O; 4 mol H2, 1 mol O2; leftover H2 in mol
```

The kernel checks the supplied coefficients against every element and uses the
smallest supplied mole amount divided by its positive net consumed coefficient. Repeated identical species names aggregate, and equal left/right coefficients cancel before finding the limiting reactant. The first example
has a theoretical yield of 36.03 g; the second leaves 2 mol H2. Inputs may use
mol or mmol; outputs may use moles or grams. Every reactant needs one named
initial amount; product-only species may also have an initial amount. Repeated terms share one named inventory. Yield means net newly formed product, while remaining amount includes any initial product. This assumes complete conversion of the limiting reactant and does not
predict whether a reaction occurs, its rate, equilibrium, or measured yield.

The current reaction reader requires the explicit three-clause format. It does
not infer missing coefficients or excess reactants, accept gram inputs or kg
outputs. Different species spellings with equal element-count compositions are withheld as unresolved aliases/isomers; composition alone does not establish chemical species identity. Identically named catalysts and spectators remain in their inventory and do not constrain the net extent. Charged formulas and
isomer identity are not supported. See [the reaction lane](../../../project/lanes/H-chemistry.md)
for checked statements, consumer scores and remaining limits.

A present catalyst does not limit the stoichiometric extent:

```text
2 H2 + O2 + Pt -> 2 H2O + Pt; 4 mol H2, 1 mol O2, .1 mol Pt; yield H2O in mol
2 H2 + O2 -> 2 H2O; 4 mol H2, 1 mol O2, 2 mol H2O; remaining H2O in mol
```

These return 2 mol newly formed water and 4 mol final water respectively under
the stated complete-conversion model.

Mass quantities accept grams, milligrams, kilograms, and micrograms. Moles-to-mass, mass-to-moles, molar mass, solution preparation, and mass-based molarity preserve the supplied or requested unit. For example, `How many kilograms are 2 mol of H2O?` gives 0.03603 kg, and `What is the molar mass of H2O in kg/mol?` gives 0.018015 kg/mol. Decay can compare unlike mass units or express the remaining mass in a requested unit.

Unit conversion does not supply missing chemical information: a concentration is not a sample mass without its volume, and mass cannot be compared with atom count without an isotope-specific conversion. Pounds, ounces, multiple requested units, and sums of elapsed times remain unsupported.


Directed solution calculations: stock and target concentrations retain their roles. The kernel checks whether dilution can reach the target, preserves solute, and computes a unique stock volume for positive stock concentration. Zero amounts are supported where the formula is defined; zero concentration denominators are refused. Requested litre, mole and molar results support milli- and micro-prefixes. Plain quantities are distinct from rates. Mass-defined concentration also supports M, mM, and micromolar output, with gram, milligram, kilogram, or microgram inputs. A zero stock concentration and zero target determine zero stock volume only when the final volume is zero; positive final volume remains underspecified.
