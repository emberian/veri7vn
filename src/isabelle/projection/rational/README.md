# Certified rational input normalization

`Veri7vn_Rational_Input.normalize ctxt limits original` returns `(converted, equality)`.
The native theorem has precisely the original cterm on its left and the converted
cterm on its right, with no hypotheses or premises. This is input representation
normalization, not evaluation, admission, or a theorem of a computed answer.

The fixed rewrite set expands rational literals and explicit `Frct (numerator,
denominator)` pairs, then normalizes literal integer/natural constructors for the
canonical code target. It permits negative and zero denominators with their actual
HOL meanings. An abstract `Frct` applied to a computed pair, a nested abstract
rational, open terms, and abstractions are refused. Both original and converted
terms must satisfy node/depth bounds; rewriting has an explicit timeout.

The child imports `Veri7vn_Codegen`, so consumers use `Veri7vn_Numerals` for ML
conversion to and from the shared generated nat/int carriers. The helper introduces
no family-specific carrier, theorem registration, executable pin, or authority.
Each consumer still checks its exact call shape and carrier, retains the equality,
and rechecks the same converted computation/output association under its own
bounded projection and admitted implementation contract.

Migration: quantities currently retain their reviewed local converter until this
independent child is checked. Mathematics and finite-statistics consumers must
check their actual call composition after adopting this module. A passing child
marker does not qualify those consumers.
