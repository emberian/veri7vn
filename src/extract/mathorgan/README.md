# Small mathematics routes

This program answers linear equations in one unknown, integer square roots,
greatest common divisors, least common multiples, and a limited set of mass
and time conversions. Its standalone mode also includes two word-problem
schemas and reconstructs some of the head's mathematics refusals. The main
dispatcher uses the fuller `wordprob` program for word problems.

The code was adopted from `scout/math-organ` at `a9183c5`. The adoption uses
the shared UTF-8 regex and JSON code in `commons.sml` instead of the scout's
older copies. HOL reply text was subsequently repaired: equations retain
both sides, and unsupported claims of a second-method check or verified
English interpretation were removed. The `Veri7vn_MathOrgan` session
was freshly built on hbox on 2026-10-18 (final attempt
`20261018T063946Z-59fed3b412e5`): 41 scanned statements, no
oracles. The marker is `VERI7VN_MATHORGAN PASS theorems=41 oracles=0`.

Independent adoption checks caught errors that the original panel missed:
the recognizer dropped a negative square-root sign, truncated decimal inputs
to integers, lost the sign of an implicit `-x` coefficient, and overflowed
on large integers. It now preserves signed whole
numbers with arbitrary-precision integers. Noninteger or ambiguous integer
operator input is an explicit recognizer refusal, marked separately from a
kernel result. Negative GCD/LCM arguments use their absolute values. An ordinary square-root
question needs an exact integer root; otherwise the route refuses rather
than silently returning the floor. Explicit integer-root questions still
return the floor with its defining bounds.

The central guarantees concern the typed request read by the untrusted
recognizer. For a nondegenerate equation `a*x+b=c*x+d`, the returned rational
root satisfies that equation and is its only root. For nonnegative integer
`n`, the integer square root `s` satisfies `s*s <= n < (s+1)*(s+1)`. Conversion
values preserve the source amount times its unit factor. The reply's value
field is the kernel's rendered value. `render_rat` uses an exact integer,
terminating decimal or fraction; it does not round. Some intermediate step
text uses a separate six-significant-digit formatter whose rounding behavior
is tested, not proved. These do not prove that the recognizer
read the user's sentence correctly; the theorem names in JSON are a static
inventory, not a proof newly constructed for that sentence.

The program is deliberately small. It does not implement a general algebra
system or a general expression parser, even though the kernel includes an
expression datatype. Fraction arithmetic and identities or inconsistent
equations are not answered by this recognizer. Some refusal rules reproduce
the original head's conservative behavior, such as refusing a solution that
already appears among the question's given values.

Build and score:

```sh
tools/dev/remote-build persvati src/extract/mathorgan Veri7vn_MathOrgan --expect 'VERI7VN_MATHORGAN PASS'
sh src/extract/mathorgan/build.sh
python3 -B src/extract/mathorgan/score.py --answerer var/mathorgan/bin/mathorgan --replies var/scout-wt/math-organ/var/mathorgan/panel/head_replies.jsonl --allow-assurance-text-change
python3 -B src/extract/mathorgan/test_recognizer.py
```

The scorer compares the 93 mathematics questions with previously recorded
head replies. It compares status and path on every question and exact text
on answered questions. It does not independently establish mathematical
correctness or measure the whole head's six release criteria.
Before the unsupported assurance sentences were removed, the adopted binary
matched all 93 recorded cases. The scorer separately reports exact matches
and the precise suffix-only changes; its optional flag never hides other
text or value differences. The final binary keeps all 93 status/path results: 52 exact matches and
41 suffix-only changes. Seven test methods cover 28 boundary cases absent
from the original panel. Seven selected cases also pass through the real
dispatcher, including its actual precision guards.

For composition, `--route algebra` and `--route ops` produce an answer, a
recognized refusal (`provenance.taken=true`), or no match (`taken=false`). A
recognized refusal stops the cascade. `--route guards` reconstructs a
hypothetical mathematics refusal from the question; use it only after the
other answer-producing routes have found no answer. The separate `guards`
program inspects the actual selected answer and has a different protocol.
