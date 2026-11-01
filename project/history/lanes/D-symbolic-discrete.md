# Complete derivative ordinals — 18 October 2026

This packet fixes concrete suffix mistakes in the untrusted calculus recognizer.
“Twenty-first” previously selected the first derivative; “21.5th” selected the
fifth; “-1st” selected the first. Full English ordinals 1–50, with hyphens or spaces,
and canonical numeric ordinals now select their exact order. Signs, fractional
orders, inconsistent numeric suffixes and larger or malformed ordinal phrases
produce a taken `unsupported` refusal. “Find derivative” also works without an
explicit order. The supported order bound remains 50.

Changed paths: `src/extract/discrete/recognizer.sml`, `ordinal_probes.py`,
`README.md`, and this report. No HOL definitions, theorem statements, generated
kernel or capability kinds change. No lane commit or upstream write was made.

## Checks and consumer

`sh src/extract/discrete/build.sh` compiled the recognizer with the C packet's
checked export. No Isabelle rebuild was needed: the proof sources and exported
computation are unchanged. Its prior receipt remains
`var/discrete/remote-attempts/20261018T063943Z-788a69334a1f/receipt.json`, with
81 scanned theorems and zero oracles. Export SHA256 remains
`8edfe065fbdb7db7bf01a498204c09d03577bedf4da21d61c8f5ace73af0fc10`.
New Darwin binary SHA256:
`f98212d64b8621664eec9fb4cccf6dab23ca1efe403d954484b1d21b28859d7d`.

The 168 authored ordinal checks give **168 right, zero wrong, zero false yes,
zero valid withheld**, versus committed C's **66 right, 58 wrong, 30 false yes,
14 valid withheld**. They check the exact value of derivatives of x^50 at 1 and
the order stated in the response; unsafe cases must retain `taken=true`.
The author also wrote the recognizer, so these are development evidence, not
independent heldout language tests. Receipts: `var/discrete/d/ordinal-{before,after}.json`.
All earlier 24 calculus probes remain right: `var/discrete/d/probes.json`.

All 168 cases pass through actual `tools/dispatch/dispatch.py --order front
--organs discrete --no-reader --no-document --no-routes`, both with a calculus
pin and without: **168/168 in each mode**. Unsupported cases retain
`provenance.dispatch.decisive=true`. This is scoped dispatcher composition,
not the full head or all-family collision sweep. Receipt: `var/discrete/d/dispatch.json`.

The specialists' own shipped scorers remain **508/508 right** in both specialist
and family modes, with zero wrong, false yes or valid withheld:

| Specialist | Dev right/total | Heldout right/total |
|---|---|---|
| games-v3 | 51/51 | 18/18 |
| logic-v3 | 33/33 | 12/12 |
| dataformats | 93/93 | 93/93 |
| algorithms | 42/42 | 42/42 |
| calculus | 62/62 | 62/62 |

Receipt: `var/discrete/d/shipped.json`. There is no supplied calculus generator;
no fresh-generator result is claimed for this parsing change. Binary size is
921,768 bytes. Five process starts after the preceding probe runs took
5.01, 4.78, 5.36, 4.54 and 5.06 ms; these do not establish uncached-launch latency.
Specialist round-trip medians range from 0.094 to 0.163 ms.

## Proof boundary and remaining work

The consumer still invokes repeated exact differentiation. Existing
`pder_n_derivative` states
`((lambda x. pev (pder_n k p) x) has_field_derivative pev (pder_n (Suc k) p) x) (at x)`.
Existing `c_deriv_at_sound` states that a successful evaluated derivative reply
contains `peval (pder_n (Suc k) p) x0`, whose real value is the derivative of
`pev (pder_n k p)` at `of_rat x0`. Existing `c_reply_answered` states that a
reply is answered exactly when its kernel result is not `CNeed`. None proves
that an English ordinal was interpreted correctly; this packet makes no new
proof claim. Cross-variable derivatives remain explicitly unsupported.

The isolated `has_integral` draft remains unverified scratch under
`var/discrete/codex/integral-draft/`. MST algorithm certificate completeness
also remains open. Linux replay of this changed recognizer is pending; the
immutable C package capture retains its own earlier executable.


## Per-specialist review

Family panel success is not a substitute for these separate semantic limits.

| Exact specialist ID | Concrete review and remaining boundary |
|---|---|
| calculus | This packet corrects complete derivative ordinals and separated numeric/sign modifiers. C checked explicit variable conflicts, rational endpoints and requested-order labels. Differentiation of a polynomial in x with respect to y still refuses, although its ordinary independent-variable derivative is zero. The real-integral bridge is still an unverified draft. |
| games-v3 | C fixed the explicit anagram word LETTER. New concrete defects are recorded for the next packet: face 7 on d6 incorrectly gives 91/216 after three rolls because the request drops the face; five aces without replacement incorrectly becomes one-card probability 1/13 because count recognition stops at four. An authored 195-case development baseline gives 56 right; this is investigation evidence, not a completed capability. |
| algorithms | Reviewed the MST soundness/minimality certificate boundary: an accepted tree is minimal, but completeness of Kruskal passing its independent certificate remains unproved. Shipped panels pass; no new broad semantic investigation of search/sort/graph wording is claimed in D. |
| logic-v3 | C ran shifted supplied generators and the shipped scorer. No new D semantic review of logical sentence interpretation has been performed; passing truth-table panels does not establish arbitrary English entailment parsing. |
| dataformats | C ran shifted supplied generators and the shipped scorer. The JSON recognizer and digest correspondence remain tested-only boundaries. No new D semantic review of malformed encodings or JSON cases beyond those panels is claimed. |
