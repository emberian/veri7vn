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
derivative of the polynomial (Isabelle's `has_field_derivative`); a spanning tree is stated
only after a checker passes it, and the check passing proves it is a spanning tree of the
graph and no spanning tree weighs less (`a_mst_minimal`, proved against a definition of
spanning tree that does not mention Kruskal). The graph is declined as disconnected exactly
when it has no edges or two of its nodes are joined by no path (`a_mst_disconnected`).

Honest limits: that Kruskal's tree always passes the checker is not proved (a tree that
failed would be withheld; none of the 16 spanning-tree panel questions fails it); the digests are executable specifications checked by known-answer vectors at build
time, not proved against another definition; the JSON validator follows CPython's scanner and
is tested, not proved against RFC 8259; the definite integral is the antiderivative's value
difference (HOL-Analysis is not imported). Statements and numbers:
[handoff](../../../project/lanes/S12-discrete.md).

Build: remotely, `tools/dev/remote-build persvati src/extract/discrete Veri7vn_Discrete -d src/extract/commons --expect 'VERI7VN_DISCRETE PASS'` (build.sh then uses the returned SML), or locally `python3 tools/dev/check-native --session Veri7vn_Discrete --session-root src/extract/discrete --expect 'VERI7VN_DISCRETE PASS' --timeout 600`, then `python3 src/extract/discrete/tables_check.py`, `sh src/extract/discrete/build.sh`, `PYTHONDONTWRITEBYTECODE=1 python3 src/extract/discrete/score.py`.
Every panel (both splits, specialist mode and family mode) scores right on every item, 0 wrong,
0 false yes, 0 disagreements with the organs.

The October continuation expands polynomial requests to derivatives of orders 1–50
(including evaluated derivatives), and to “primitive” and “anti-derivative”.
Explicit variable conflicts, zero denominators, malformed numeric qualifiers and
unsupported orders produce a taken `unsupported` refusal. This matters when the
family runs in front of another answerer: falling through could repeat the old
confident wrong answer. The recognizer remains untrusted; none of these changes
proves that an English question was interpreted correctly. Explicit anagram words
such as LETTER are accepted rather than mistaken for a request missing its word.

`beyond.py` runs the supplied games, logic and format generators with shifted seeds
and their own scorers, without writing upstream. The supplied snapshot has no
calculus or algorithms generator. `probes.py` records 24 calculus development
probes with exact expectations; its author also changed the recognizer, so it is
not independent evidence. Current numbers and build receipts belong in
[the continuation report](../../../project/lanes/C-symbolic-discrete.md).

Derivative ordinals now parse as complete phrases: “twenty-first” and “twenty
first” mean 21, while negative, fractional and malformed ordinals refuse instead
of taking a convenient suffix. Numeric ordinals require their canonical suffix
(21st, not 21th). `ordinal_probes.py` checks exact values and the named order for
168 authored cases; [the ordinal report](../../../project/lanes/D-symbolic-discrete.md)
records panel and dispatcher results. This still does not verify English parsing.

The games continuation retains the requested signed die face and connects its
probability to counts of actual finite roll sequences. Impossible faces and zero
rolls give zero. Complete card draw counts now use the exact existing calculation;
zero draws give one and too many matching cards without replacement give zero.
Mixed events and incomplete quantities refuse decisively. Counts are bounded at
1000; the recognizer remains untrusted. `games_probes.py` checks exact arithmetic
against enumerated dice and combinatorial card counts. The [games report](../../../project/lanes/E-symbolic-discrete.md)
records the checked statements, panel results, compiler inputs and remaining
interpretation defects in the other specialists.
