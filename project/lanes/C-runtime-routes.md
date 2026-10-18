# Mathematics and precision guards in the dispatcher

Owner: Codex runtime/routes, 2026-10-18. No commits made by this lane.

The dispatcher can now call mathematics and word problems through their
actual protocols, and check the selected answer with precision guards. An
explicitly recognized refusal stops routing. An unrecognized question may
continue to another organ. The adapter is `tools/dispatch/routes.py`; the
dispatch lane connects it to `dispatch.py` and the registry.

The mathematics scout was adopted from `scout/math-organ` at `a9183c5`, with
the current shared regex/JSON implementation. Its HOL source was freshly
built; its recognizer was then repaired after independent probes found that
it dropped negative signs, truncated decimals and overflowed machine
integers. It also lost the sign of an implicit `-x` coefficient. Signed
whole-number inputs now use `IntInf`. Noninteger and
ambiguous operator input gets a decisive, explicitly untrusted recognizer
refusal. It does not manufacture a typed request and pretend the kernel
checked it. Ordinary square-root questions no longer silently receive
integer-floor answers when the root is irrational.

Review also found unconditional inherited sentences claiming a second-method
check or verified interpretation of English quantities and the requested
goal. Those sentences were removed in HOL; values and formula steps remain.
The displayed original linear equation now retains the right-side unknown
term. No mathematical theorem statement was weakened.

## Changed paths

- New `src/extract/mathorgan/`: `Math.thy`, `Math_Export.thy`, `ROOT`,
  `build.sh`, `main.sml`, `recognizer.sml`, `README.md`, `score.py`,
  `test_recognizer.py`.
- `src/extract/wordprob/main.sml`, `Wordprob.thy`, `Wordprob_Export.thy`,
  `score_core.py`, `build.sh` and `README.md`: nonempty recognized
  requests that the kernel declines now report `taken=true` and a named
  decline path, rather than falling through as if nothing recognized them.
  Reply text no longer claims that the untrusted English interpretation was
  verified; the scorer separately reports that exact suffix-only change.
- `src/extract/guards/README.md`: actual-reply composition and limits.
- New `tools/dispatch/routes.py` and `test_routes.py`.
- This report. No changes to fusion or routing theories.

## Guarantees and boundaries

The imported math theory was read, not merely compiled. Its binding
statements include:

- `isqrt_interval`: `isqrt n * isqrt n <= n` and
  `n < (isqrt n + 1) * (isqrt n + 1)`.
- `solve_linear_sound`: if `a != c`, then `x = (d-b)/(a-c)` satisfies
  `a*x+b=c*x+d`; the kernel returns that value unless the existing echo
  policy recognizes it among the question's givens.
- `solve_linear_complete`: under the same nondegeneracy premise every
  solution is `(d-b)/(a-c)`.
- `reply_states_value`: when the kernel returns a value and the reply
  answers, its value field is the kernel's rendered value, excluding the
  separately handled perfect-square yes/no question.

The proofs assume the typed request. The English recognizer, route order,
framing and optional relation-store inputs are untrusted. Static theorem
names in answer metadata are not per-answer proofs. Some guard statements
only pin the implemented predicate; they do not prove English semantics.

The math scout's `--route guards` reconstructs a hypothetical math refusal
from the question. It is a final fallback, after other answer routes. The
separate precision-guard stage checks the actual returned reply and only
narrows it. It covers 20 of 87 catalogue codes. Missing human/date facts are
unknown and reported as absent; there is no complete store guard adapter yet.

## Checks run

- Fresh `Veri7vn_MathOrgan` build on persvati: exit 0,
  `VERI7VN_MATHORGAN PASS theorems=41 oracles=0`, 27 seconds session time.
  Receipt: `var/mathorgan/remote-attempts/20261018T062842Z-f66e5c91eceb/receipt.json`.
- `sh src/extract/mathorgan/build.sh`: pass with the bundled MLton.
  Initial adopted binary SHA-256 (superseded by the wording/display repair):
  `16a8bfe22a21e01cbf24e677e4fd9672c7dcb7c6afe83c2793bc53a13a5bd6a9`.
- `python3 -B src/extract/mathorgan/score.py --answerer var/mathorgan/bin/mathorgan --replies var/scout-wt/math-organ/var/mathorgan/panel/head_replies.jsonl --out var/mathorgan/adoption-panel.json`:
  **93/93 recorded-head matches before assurance-text repair**, comprising 47 answers and 46 refusals.
  Status/path checked for all; exact response text checked for answers.
  This is a rerun of the new binary against existing recorded head replies,
  not a new head run or the six-criterion specialist exam.
- `python3 -B src/extract/mathorgan/test_recognizer.py`: four test methods,
  **23 independent boundary cases pass**. Includes 10^38 input, negative
  roots, decimal/exponent/fraction inputs, signed GCD/LCM and ambiguity.
- `sh src/extract/wordprob/build.sh` and
  `python3 -B src/extract/wordprob/score_core.py`: pass. Core word questions
  **24/24 exact status/path/text before assurance-text repair**. Over 924 questions, 915 agree with the
  original word organ's answer/decline decision; all nine differences are
  intentional negative-given refusals. No schema disagreement and no
  answered negative-given question. All 12 P7 panel items withheld.
- `python3 -B tools/dispatch/test_routes.py`: **7 tests pass**, including
  **114/114 recorded synthetic guard inputs** through the actual adapter.
  The synthetic inputs do not establish whole-head accuracy.
- Route-only composition on the 93 mathematics questions: **84 exact
  matches**, six circle-area questions formerly declined by the head now
  answered by the fuller word-problem kernel, three negative-radius
  questions still declined under explicit word-problem paths. Receipt:
  `var/mathorgan/routes-panel.json`. Thus the composed capability is not
  claimed to have exact released-head route parity.

Both build scripts accept `VERI7VN_EXPORT_DIR` to compile an exact successful
attempt export; math defaults to its exact session directory, never a search
through legacy exports.

### Final mathematics packet (frozen)

- Successful final attempt: `var/mathorgan/remote-attempts/20261018T063946Z-59fed3b412e5/receipt.json`, hbox. The actual build log contains
  `Finished Veri7vn_MathOrgan` after `Math_Export 100%`; the separate session
  log contains `VERI7VN_MATHORGAN PASS theorems=41 oracles=0`. 28 seconds
  session, 31 seconds total. Source ROOT/theory files match the immutable
  snapshot. The attempt was not canceled. Export SHA-256:
  `22285a1ab07d2a799cde636818bf4f52a449faca072b3bae0dbf51d743435651`.
- Compiled with `VERI7VN_EXPORT_DIR` pointing to that exact attempt's
  `results/export/Veri7vn_MathOrgan`, rather than a published convenience
  location. Final binary SHA-256:
  `686ddfcdf3195e1ffa5ae9d6ec8cb95c12ed9335519dd80c330f13a59997dcff`.
- `test_recognizer.py`: **7 tests / 28 boundary cases pass**, including
  ordinary versus integer square roots, two-sided equations, implicit `-x`,
  decimal/fraction/exponent rejection and large integers.
- `score.py --allow-assurance-text-change` against the same recorded head:
  **93/93 status/path matches; 52 exact matches; 41 differ only by the
  removed unsupported assurance suffixes; zero other differences**.
  Receipt: `var/mathorgan/final-panel.json`. The unmodified strict scorer
  still reports exact text differences; reference data was not rewritten.
- Real dispatcher with `--organs chemistry --no-reader --no-document
  --timeout 10`: **7/7 selected outcomes pass**, including negative and
  irrational roots, explicit integer root, two-sided and negative-coefficient
  algebra, decimal rejection and GCD. Answered results passed through actual
  precision guards; recognized refusals stopped before later routes.
  Receipt: `var/mathorgan/final-dispatch.json`.

Frozen math files are all nine listed under `src/extract/mathorgan/` above.
No proof statements were weakened; the numeric theorems listed in this report
are unchanged. The changes to HOL are reply text and retention of the RHS
coefficient in the displayed equation. Wordprob's wording build also passed separately:
`var/wordprob/remote-attempts/20261018T063622Z-9431890ef1f7/receipt.json`,
persvati, actual `Finished Veri7vn_Wordprob`, 29 seconds session / 84 seconds
total. Source/theory equality, session marker and export hashes were checked;
compilation used that exact immutable export. Final wording binary SHA-256:
`3b93fb5978ce3a465fbacc98f7e963c0d98f92c80734c54541c168372fc88d94`.
The final 924-question check still has 915 answer/decline agreements, all nine
differences intentional negative-given refusals, no schema disagreement and
no negative-given answer. Core24 has 24 status/path matches, zero exact-text
matches, and 24 precise suffix-only changes. All12 P7 items withheld. The
seven adapter tests, including114 guard inputs, still pass. Its newly found mixed-unit and rate-denominator defects
are recorded in `var/wordprob/semantic-boundary-baseline.json` and are the next
semantic repair packet; they are not covered by the mathematics success.

## Remaining work and consumer

The consumer is the default dispatcher, whose integration owner runs the
whole-stage checks. Guards still lack 67 catalogue codes and automatic
read-only human/date inputs. Math remains a small route family, without a
general expression parser, fraction arithmetic or answers for degenerate
linear equations. It preserves the head's echo-refusal policy. Broader
mathematics should grow from explicit syntax/semantics, not from more
permissive substring number extraction.
