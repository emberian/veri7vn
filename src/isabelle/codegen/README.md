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
