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
smallest supplied mole amount divided by its coefficient. The first example
has a theoretical yield of 36.03 g; the second leaves 2 mol H2. Inputs may use
mol or mmol; outputs may use moles or grams. Every reactant needs one named
amount. This assumes complete conversion of the limiting reactant and does not
predict whether a reaction occurs, its rate, equilibrium, or measured yield.

The current reaction reader requires the explicit three-clause format. It does
not infer missing coefficients or excess reactants, accept gram inputs or kg
outputs, or combine duplicate species. Equal element-count compositions across
or within sides are withheld, including catalysts and spectators; composition
alone does not establish chemical species identity. Charged formulas and
isomer identity are not supported. See [the reaction lane](../../../project/lanes/E-chemistry.md)
for checked statements, consumer scores and remaining limits.
