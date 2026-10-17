# The chemistry family, end to end

Five shipped Oracle7 specialists (`chemistry`, `chemistry-v3`, `decay`, `labsolutions`, `labsolutions-r2`) as one
verified HOL kernel: element properties from PubChem's table, exact molar mass of any formula (brackets, hydrates),
grams and moles, percent composition, laboratory solutions (mass for a molarity, molarity, dilution, percent w/v) and
radioactive decay (exp and log2 only through verified interval enclosures). Isabelle exports it to SML and the bundled
MLton makes one standalone binary speaking the answerer contract (`--specialist ID` for one manifest's reading).
Proofs and statements, the numbers per panel and the untrusted parts: [lane S07 handoff](../../../project/lanes/S07-chemistry.md).
Tables are generated (`emit_table.py`) and compared with the organ files by `tables_check.py`.

Build: see the reproduction commands in the handoff. Result: every panel item the organ answers is right, 0 false yes.
