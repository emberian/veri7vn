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
was initially built on hbox on 2026-10-18 (final attempt
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

The affine route accepts complete equations in one selected scalar letter (`a`
to `z`, case-folded to lowercase):
exact decimal, grouped, fractional and scientific coefficients; parentheses;
sums, differences, negation; multiplication by a normalized constant; and
division by a normalized nonzero constant. It preserves the expression tree
and sends it to the kernel. HOL normalization proves that each accepted tree
has value `a*i(name)+b` under every variable reading `i`, including definedness.
A second theorem ensures that the accepted tree contains only the chosen name. The result distinguishes one
exact rational root, every rational value, and no rational solution. For a
unique root, the actual checker also evaluates both original typed sides at
that root. Nonlinear products, variable divisors, division by zero, powers,
malformed numbers, additional unknowns and oversized requests are explicit
refusals. A missed English pattern does not become a partial equation.

The target may be named before or after the equation, as in “Solve for t
3t+2=11” or “Solve 3t+2=11 for t”. Without a target, the sole variable is inferred;
constant-only equations retain x by default. Conflicting targets and a second
unknown refuse, even when the second unknown cancels. `2*e` explicitly names e;
malformed scientific `2e` is not reinterpreted as multiplication.

Each affine answer includes the chosen variable, original typed tree, normalized sides,
classification, exact root when unique, and the actual checker outcome in
`provenance.evidence.checked_computation`. The route consumer independently
replays that bounded arithmetic and checks the displayed result. It also
requires `provenance.request_text` to equal the submitted request, preventing
stale or swapped replies from passing. Neither check proves that the untrusted
parser read the user's text correctly. The parser uses shared `ExactNumeric`
for whole numeric atoms; limits are 128 total AST nodes, depth 32, and 256
decimal digits per reduced rational component in the packet.

Complete solve requests may return a root already present in the input.
Incidental assignments inside derivative questions are not solve requests.
G5 recognizes the complete request surface. P2 recognizes exact all/no-solution
sentences as solution-set classifications, while other nonnumeric replies
still face its number-presence rule. Standalone guards reconstruct text
features; they do not verify affine packets. The route consumer does that
before invoking guards.

The other routes retain their typed-request guarantees: for nonnegative
integer `n`, integer square root `s` satisfies `s*s <= n < (s+1)*(s+1)`;
conversion values preserve amount times unit factor. Their theorem-name
lists are static inventories, not per-answer proof objects. Affine replies
use canonical integers or fractions with no rounding. The legacy `render_rat`
also uses exact integers, terminating decimals or fractions; some legacy
intermediate text uses a separately tested six-significant-digit formatter.
This remains a finite equation solver, not a general computer algebra system.

Build and score:

```sh
tools/dev/remote-build persvati src/extract/mathorgan Veri7vn_MathOrgan --expect 'VERI7VN_MATHORGAN PASS'
sh src/extract/mathorgan/build.sh
python3 -B src/extract/mathorgan/score.py --answerer var/mathorgan/bin/mathorgan --replies var/scout-wt/math-organ/var/mathorgan/panel/head_replies.jsonl --allow-assurance-text-change
python3 -B src/extract/mathorgan/test_recognizer.py
python3 -B src/extract/mathorgan/test_affine.py
```

The scorer compares the 93 mathematics questions with previously recorded
head replies. It compares status and path on every question and exact text
on answered questions. It does not independently establish mathematical
correctness or measure the whole head's six release criteria.
Before the unsupported assurance sentences were removed, the adopted binary
matched all 93 recorded cases. The scorer separately reports exact matches
and the precise suffix-only changes; its optional flag never hides other
text or value differences. That initial adoption kept all 93 status/path results:
52 exact matches and 41 suffix-only changes. The subsequent complete-request repair
kept 87 status/path pairs; six derivative questions now correctly fall through
instead of being misread as linear equations and vetoed. They remain withheld
in this small route's comparison. Seven test methods cover 28 boundary cases
absent from the original panel. Eight route test methods exercise complete
solve requests and the actual precision guard, including a root that equals a
number in the question.

For composition, `--route algebra` and `--route ops` produce an answer, a
recognized refusal (`provenance.taken=true`), or no match (`taken=false`). A
recognized refusal stops the cascade. `--route guards` reconstructs a
hypothetical mathematics refusal from the question; use it only after the
other answer-producing routes have found no answer. The separate `guards`
program inspects the actual selected answer and has a different protocol.

The affine extension intentionally replaces legacy solution prose and answers
identities/inconsistent equations instead of calling both “zero slope”. Its
current proof/native and selected-consumer results are recorded separately in
`project/lanes/E-runtime-affine.md`; the old 93-response comparison remains a
historical reference rather than a requirement to preserve its weaknesses.

The affine extension was proved on persvati with 47 scanned statements and
zero oracles (`20261018T081347Z-fa668924d7c5`). Its selected actual dispatcher
checks cover unique/all/no solutions and malformed/nonlinear/undefined inputs:
8/8 expected outcomes, alongside the focused parser, evidence-mutation and
guard-composition tests recorded in the lane report.

Closed arithmetic now has a checked route too: whole requests such as
“What is 5 squared?”, “Evaluate (-3/2)^2”, or “Calculate 1/3+1/6” preserve the
original typed expression and return exact integer/fraction values. Only
square/cube powers are supported. Unbound variables, division by zero,
malformed tokens, other powers and excess resource bounds refuse. Unary minus
has its usual precedence (`-2^2 = -4`, `(-2)^2 = 4`); squared/cubed word suffixes
apply to the entire preceding operand. A mandatory `closed_expression` packet
is independently replayed and its request text checked before guards run.
The route is `--route closed` (also accepted by `--route ops` for direct callers).
All five focused test methods and eleven selected actual dispatcher probes
pass. The 52-statement proof/native and exact boundaries are recorded in
`project/lanes/F-runtime-closed.md`. Run
`python3 -B src/extract/mathorgan/test_closed.py` for the focused checks.


Complete imperative requests also accept one polite preface: “Please solve …”,
“Could you calculate …”, or “Would you please evaluate …”. The preface is
recognized only before a supported command; the remaining expression must
still match completely. The checked reply retains the original full request
text. `test_request_phrasing.py` covers valid roots/classifications/arithmetic,
trailing text and incidental assignments. The ordinary all-default dispatcher
passes 14 focused joint controls; see `project/lanes/H-runtime-default.md`.
