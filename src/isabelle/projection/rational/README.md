# Checked rational normalization

Veri7vn_Rational_Input.normalize ctxt limits original returns converted plus a hypothesis/premise-free theorem **original=converted**, not an answer theorem.

Fixed rewrites expand rational literals/explicit Frct pairs and canonical numeral constructors, preserving actual negative/zero-denominator HOL meanings. Computed pairs, nested abstract rationals, open terms and abstractions reject; both endpoints have node/depth bounds and timeout.

Codegen supplies shared numeral carriers. Consumers retain endpoint equality and independently check exact call/output/pin/projection association. Quantities retain their local converter pending this child; math/finite consumers need composed checks. A child PASS does not qualify migration.
