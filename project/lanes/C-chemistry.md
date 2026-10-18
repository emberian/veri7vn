# Chemistry: parser assurance and usable extension contracts

The existing five specialists freshly score 1,206 / 1,206 right, zero wrong and zero false yes on their shipped dev and held-out panels. This was measured on the warm B-chemistry binary; the newly checked export and freshly compiled binary have exactly the same SHA-256 hashes, so executable behavior is unchanged. Chemistry and chemistry-v3 each score 225 dev / 281 held-out, decay 42 / 42, and labsolutions and labsolutions-r2 each 28 / 27. Receipt: `var/chemistry/c-parser-baseline.json`.

## Changes

`src/extract/chemistry/Chemistry.thy` now has an explicit induction over scanner fuel and well-formed stack frames. An opening parenthesis pushes an empty valid frame; a closing parenthesis merges two valid frames; an element is added only after its symbol has been found in the table. A second induction covers hydrate parts. The executable definitions are unchanged.

The new statements are:

- `scan_wf`: if every frame in `st` has known, distinct element names, and `scan fuel input st = FOk result`, the result has known, distinct names.
- `parse_parts_wf`: a valid initial total and successful part parsing give a valid final total.
- `parse_formula_wf`: `parse_formula f = FOk cs ==> wf_counts cs`.
- `parse_formula_known_distinct`: successful parsing implies `distinct (map fst cs)` and, for every entry `p`, there is a table element `e` with `find_sym (fst p) = Some e`.
- `molar_mass_known_distinct`: an exact molar-mass answer has kind `CK_molar_mass` and comes from a successfully parsed list with distinct table-known symbols; its value is the sum of atomic mass times count.
- `percent_comp_known_distinct`: a successful composition answer contains distinct symbols, and each symbol resolves to a table element.

All six are included in the final `Chemistry_Export.thy` oracle scan. The corrected remote build passed with `VERI7VN_CHEMISTRY PASS theorems=69 oracles=0`. Its immutable receipt is `var/chemistry/remote-attempts/20261018T063429Z-2ee045a251ad/receipt.json` (status passed, exports published). The first attempt stopped because the free identifier `total` resolved to an existing HOL function; the accumulator was renamed to `acc`, with no change to the statement or proof strategy. The proof uses no positive-count premise: `H0` is a successful zero-count parse, and composition correctly declines its zero total mass.

`src/extract/chemistry/capabilities.json` makes the existing extensions visible to the shared runtime contract. Chemistry and chemistry-v3 add `percent_composition`, its composition context, and the zero-mass `impossible` decline. Labsolutions and labsolutions-r2 add `diluted_conc`, `water_to_add`, `moles_in_solution`, and `molarity_from_moles`. Decay needs no extension. These declarations are not proof certificates: they explicitly distinguish exact arithmetic on typed requests from untrusted language recognition, table import, and the physical additive-volume assumption for dilution.

## Consumer check

The runtime owner's shared loader and dispatcher accept all five new kinds. Nine focused composed checks passed: percent composition of water; diluted concentration; water to add; moles in solution; molarity from moles; and declines for XyO2, H0, missing formula, and a supposed dilution whose final volume is smaller than its stock volume. Receipt: `var/chemistry/c-composed-probes.json`.

These checks use the front dispatcher scoped to chemistry, pinned to chemistry-v3 or labsolutions-r2, with the reader disabled. They do not establish full-head routing parity or all six specialist admission criteria. Example invocation: `python3 -B tools/dispatch/dispatch.py --order front --organs chemistry --specialist chemistry-v3 --no-reader`.

## Executable identity and remaining limits

The generated SML from the successful attempt was passed explicitly as `CHEM_GEN` to `src/extract/chemistry/build.sh`. Both artifacts are byte-identical to the baseline:

- Generated SML: `413d5504887cd69c8605d4455cd4202d307d74446b05e537e89fa0d3eaee07fd`.
- Native binary: `9d5088157a14a6b0b7193e51a3a066c334ffa68e5a3794905b712a0fbf82e5ac` (776,312 bytes).

The baseline hashes are saved in `var/chemistry/c-parser-before.sha256`. The shipped panels were not redundantly rerun after proving byte identity. No recognizer, executable definition or reply metadata was changed. Broader routing/package checks belong to the runtime owner. The parser guarantee concerns the embedded element table and recognized formula; it does not prove that the natural-language question was interpreted correctly or that source atomic masses are independently true.
