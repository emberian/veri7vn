# The discrete family, end to end

Five shipped Oracle7 specialists as one program: `games-v3` (exact dice, card and poker
probability, anagram counts), `logic-v3` (truth tables), `algorithms` (shortest path,
spanning tree, binary search, sorting, a complexity table), `calculus` (derivatives and
integrals of polynomials) and `dataformats` (number bases, base64, percent-encoding, JSON
validity, SHA-256/SHA-1/MD5, weekday of a date). Same recipe as the quantity family: the
decisions and values are HOL functions with proofs, exported to Standard ML and compiled with
the MLton inside Isabelle into one binary (`var/discrete/bin/discrete`, 890 KB, not committed)
that speaks the [answerer contract](../../../docs/contracts/answerer.md).

Where a result has a witness, the kernel states it and the theorem checks it: a shortest path
is a walk in the graph and no walk is lighter (a feasibility certificate from the search);
an invalid argument carries the truth-table row that refutes it; a binary-search index holds
the value; a sorted list is a permutation that is in order; a derivative is the real
derivative of the polynomial (Isabelle's `has_field_derivative`).

Honest limits: Kruskal's tree is proved to use graph edges only (its minimality is not
proved); the digests are executable specifications checked by known-answer vectors at build
time, not proved against another definition; the JSON validator follows CPython's scanner and
is tested, not proved against RFC 8259; the definite integral is the antiderivative's value
difference (HOL-Analysis is not imported). Statements and numbers:
[handoff](../../../project/lanes/S12-discrete.md).

Build: `python3 tools/dev/check-native --session Veri7vn_Discrete --session-root src/extract/discrete --expect 'VERI7VN_DISCRETE PASS' --timeout 600`, then `python3 src/extract/discrete/tables_check.py`, `sh src/extract/discrete/build.sh`, `PYTHONDONTWRITEBYTECODE=1 python3 src/extract/discrete/score.py`.
Every panel (both splits, specialist mode and family mode) scores right on every item, 0 wrong,
0 false yes, 0 disagreements with the organs.
