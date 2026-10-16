# Shared exact code target

Veri7vn_Codegen loads four unmodified Isabelle2026-RC1 numeral theories mirrored in installed/. The narrow mirror avoids HOL-Library's directory/session ownership and full heap dependency. Upstream headers and [COPYRIGHT](installed/COPYRIGHT) retain their BSD conditions; these files are not project CC0. installed-sources.json pins installation root/SHA256.

`python3 src/isabelle/codegen/pin_sources.py --check` verifies exact installed/local bytes, hashes and notice. Installation changes require executable requalification; never repair proofs by editing mirrored sources.

HOL meanings remain unchanged; Eval shares one reflected nat/int carrier. Veri7vn_Numerals exports nat_of_integer/integer_of_nat/int_of_integer/integer_of_int; use these rather than rejected direct code antiquotations or representation casts. abstract_nat_is_public_conversion includes negative clamping. Tests use257-bit naturals,−10^40 and a second reflected arithmetic consumer.

Veri7vn_Characters likewise shares native char with exact integer conversions; string remains char list. Cross-module tests preserve0/127/128/255/NUL plus large numeric fields. Shared primitive identity is not parser or admission authority.
