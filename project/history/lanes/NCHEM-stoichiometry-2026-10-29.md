# Exact supplied-species reaction balancing

29 October 2026. Owner: Sol chemistry deputy. Public operation candidate:
`chemistry.balance_reaction`.

Changed files: `native/oracle-reasoning/src/stoichiometry.rs`,
`native/oracle-reasoning/tests/stoichiometry_contract.rs`, and this report.
Root owns module registration, Cargo dependencies, JSON dispatch, catalog,
Python/host integration and centralized execution. Additional dependencies:
`num-rational` (BigRational) and `num-integer` (gcd/lcm); existing num-bigint,
num-traits, serde and thiserror suffice otherwise.

## What it does

`balance_reaction(&ReactionInput, &ChemistryLimits) -> Result<BalanceOutput>`
constructs the exact signed conservation matrix and computes rational reduced
row echelon form, rank and a complete rational nullspace basis. Columns follow
input species order. Reactants are positive and products negative in the matrix.
A one-dimensional nullspace yields the unique primitive positive integer ray
when every coordinate has the same strict sign. A zero coordinate or mixed
signs establishes that the supplied species cannot all have positive
coefficients on their declared sides. Full rank establishes no nonzero balance.
These outcomes concern the supplied inventory, not chemical possibility.

For larger nullspaces, the response supplies the basis and free species indices.
The full solution is the linear combination of the reported basis vectors;
strict positivity means every coordinate of that combination is greater than
zero. A bounded search assigns positive integers to free coordinates, initially
all one. Default bound eight and candidate cap 4096 keep the search finite.
A rational positive candidate is cleared of denominators and divided by its gcd.
It need not minimize total coefficients among all admissible balances. Exhausted
search reports `multiple_search_inconclusive`, never impossibility. Any rational
positive solution has a scaled integer free-coordinate representation, but this
finite search need not reach it.

`check_balance(&ReactionInput, &[String], &ChemistryLimits)` separately traverses
original species declarations and recomputes each inventory's total on each
side, without using the elimination matrix. It rejects missing, zero, negative,
noninteger and nonprimitive coefficients. Accepted replies carry both side totals
for every inventory including charge. This independently checks the candidate's
conservation; rank and basis are exact computed outputs, not independently
certified rank statements. No new theorem statements or Isabelle claims.

## Input and limits

Input is a `species` list, each with unique nonempty name, side `reactant` or
`product`, `composition` mapping and explicit signed integer `charge`. Counts
are positive u64 values. Names are labels, not a database lookup. Valid inventory
labels use one of the 118 element symbols, optionally followed by `-` and a
one-to-three digit positive isotope mass number without leading zero, e.g.
`C-13`. Isotopes and unspecified element inventories are distinct; the operation
does not assume that unspecified carbon can substitute for carbon-13. A supplied
electron has empty composition and charge -1. Other empty compositions are
rejected. Both reaction sides and at least two species are required.

There is deliberately no formula parser here: callers declare composition and
charge, so an ambiguous ionic suffix or hydrate notation cannot silently change
the mathematical question. Neither valid element symbols nor a plausible isotope
label establish that a molecule, ion or nuclide exists. The operation checks
supplied inventories, not valence, stable isotope existence, thermodynamics,
kinetics or reaction conditions. Water, protons and electrons must be supplied;
the operation does not insert them to manufacture a redox equation.

Defaults: 32 species, 128 conserved inventories including charge, 4096 bits per
integer numerator/denominator and one million counted arithmetic operations.
Elimination and search check bit growth after arithmetic operations, and replay
also checks product and sum growth. These are cooperative bounded computations,
not process containment or wall-clock guarantees. JSON request bytes must retain
the provider's enclosing request limit. ChemistryLimits is operator configuration,
not part of the untrusted reaction request.

## Existing consumers and evidence read

Read chemistry-v3's pinned manifest and chemistry's shipped panel. Their declared
sources are PubChem's periodic table and OpenStax Chemistry 2e; panel examples
cover H2O/CO2 molar masses, gram/mole conversions and elemental percentages.
The new operation complements those consumers by producing coefficients rather
than inferring a reaction from mass data. It is not a replacement for their
formula reader, sourced periodic table or mass-unit handling.

Read `src/extract/chemistry/stoich/Stoichiometry.thy`: the existing supplied
certificate model checks positive coefficients and complete parsed atom counts,
and explicitly disclaims reaction occurrence. Its element conservation theorem
is not inherited by this Rust operation. The useful next consumer is a typed
chemistry adapter supplying complete compositions and charge, presenting the
returned coefficients and freedom alongside existing mass calculations.

Read the abstract/introduction of local paperbin's Dumas–Kaltofen,
*Essentially Optimal Interactive Certificates in Linear Algebra*
(`dumas-kaltofen-essentially-optimal-interactive-certificates-linear-algebra-issac2014.txt`,
arXiv:1401.4567v4). The relevant design principle is cheaper independent output
checking. This implementation uses direct deterministic inventory replay; it
does not implement that paper's interactive/Fiat–Shamir rank certificates or
claim their asymptotic complexity or security assumptions.

## Checks and remaining work

The author lane ran no build, test or specialist scorer, per root's centralized
execution instruction. Central validation below is now complete for this scoped
checkpoint. There are no new specialist-panel numbers. The original contracts cover ethane combustion (2,7,4,6), iron oxidation
(4,3,2), iron electron release (1,1,1), acidic permanganate half-reaction
(1,8,5,1,4), missing electrons, isotope mismatch, underdetermined CO/CO2
production, inconclusive search, a species forced to zero, malformed elements,
nonprimitive/negative/zero coefficients, and work/dimension/bit bounds.
The final suite contains ten contract functions, including the subsequent
duplicate-input and public-JSON boundaries. Central execution passed all ten.

The optional reasoning adapter and private standalone HTTP consumer are now
integrated and centrally exercised. Remaining: a richer typed chemistry
consumer and affected specialist panel scoring. More advanced positive-cone feasibility,
minimal integer balancing, isotope database validation and formula parsing are
not implemented. Conservation is useful even when physical feasibility remains
unknown.

Root review cleanup: the species composition deserializer now rejects duplicate
JSON inventory keys before BTreeMap construction; identical repeated counts are
also rejected. Blank-only names are invalid. Counts retain the complete u64
range without signed narrowing. Added three contract functions covering these
boundaries and the combined arithmetic budget. Output now includes stable
`schema: oracle-stoichiometry-v1` and operation identity. Elimination,
search, primitive reduction and candidate replay share one work counter; the
public standalone checker creates its own bounded counter. Rustfmt ran on the
two Rust files successfully. No builds or tests ran in the author lane.

## Central chemistry checkpoint

On hbox, `CARGO_BUILD_JOBS=2` and the warm shared target ran:

- `cargo test --locked -p oracle-reasoning --test stoichiometry_contract`: 10 passed, no failures or ignored tests.
- `cargo clippy --locked -p oracle-reasoning --all-targets -- -D warnings`: passed.
- The Python reasoning adapter contracts: 24 passed. These use a fake module and do not establish native mathematics.
- Standalone service contracts with the actual immutable combined extension: 10 passed, no skips. The actual CLI journey launched, discovered and called the chemistry operation with Fe(II), Fe(III) and an explicit electron; it returned coefficients `[1,1,1]`. The service shut down and repeated the journey after fresh startup. Existing graph/science/incremental calls also passed.

[The central receipt](../../native/evidence/2026-10-29-chemistry-validation.json)
retains commands, complete scoped logs, source hashes and extension hash
`495f67dd6207cb23b11ccd98540acf89c74a726131cbe13ea7658e76f56e5d79`.
The reused combined binary includes unfinished reader/runtime work. This
checkpoint qualifies only the supplied-species computation and pure service
consumer; it does not qualify those unrelated changes or a signed Mini release.
No theorem statements or new specialist-panel scores were added.
