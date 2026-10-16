# Exact target numeral foundation

`Veri7vn_Codegen` is a HOL descendant that loads the four unmodified upstream
Isabelle2026-RC1 numeral implementation theories in `installed/`. Isabelle assigns
a source directory to one session: importing the installed HOL/Library directory
into this narrow descendant is rejected because HOL-Library owns that directory.
The local exact-source mirror avoids loading the entire HOL-Library heap.

The copies retain their original author headers. They are upstream Isabelle code,
not covered by this project's CC0 designation. The complete installed Isabelle
copyright, BSD-style licence conditions and disclaimer are retained in
[installed/COPYRIGHT](installed/COPYRIGHT). Upstream source reference: the `src/HOL/Library/` directory of the installed
Isabelle2026-RC1 distribution, whose absolute root and per-file SHA-256 values
are recorded in `installed-sources.json`.

Run `python3 src/isabelle/codegen/pin_sources.py --check` against the selected
installed Isabelle distribution. It requires byte identity between all four local
copies and installed sources, verifies the upstream copyright notice, and checks
the pinned hashes. Never modify these copies to repair a proof. Updating the
installation requires explicit requalification of generated execution and pins.
The source-byte identity is distinct from the local session/context lineage.

The foundation preserves HOL meanings while generating compact target integers.
Its smoke test evaluates exact 257-bit natural and negative 10^40 witnesses; codec
consumers additionally test the complete exact schema fingerprint roundtrip.

The Eval target registers one reflected `nat`/`int` carrier before family modules
are reflected. `nat` is reflected as an abstract type without exporting its
abstract constructor. Native ML uses `Veri7vn_Numerals.nat_of_integer`,
`integer_of_nat`, `int_of_integer` and `integer_of_int` for the exact conversions.
Direct `@{code ...}` antiquotations of these reflected constants are rejected by
Isabelle's serialization guard. The shared functions avoid both a second nominal
numeric carrier and representation casts between family modules.
The abstract `Nat` printer calls the exported public `nat_of_integer` conversion;
`abstract_nat_is_public_conversion` proves their equality, including negative
input clamping. A second reflected consumer checks arithmetic on the same large
witnesses, so the foundation check exercises shared numeric types beyond direct
conversion calls.

The foundation also owns the shared reflected HOL `char` type; `string` remains
its ordinary list alias. `Veri7vn_Characters` exposes exact character/integer
conversions. A record produced and transformed by separate reflected modules
checks bytes 0, 127, 128 and 255, an appended NUL, and the same arbitrary-size
numeric fields. Primitive sharing establishes one type identity across modules;
it does not substitute a parser or reinterpret bytes.
