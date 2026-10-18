# Discrete semantic continuation — 18 October 2026

The games packet is checked and frozen for integration. The committed ordinal
packet is `21242bd`; runtime captured its immutable compiler inputs and executable
separately before this work began. The other concrete defects below are next
work, not claims of completed support. No lane commit or upstream write was made.

## Changed behavior and paths

The request retains the signed die face. The answer divides the number of roll
sequences containing that face by the number of all roll sequences. Impossible
faces and zero rolls give zero. Complete card counts now reach the existing
exact calculation: five aces without replacement give zero, not 1/13. Zero card
draws give one; counts exceeding the matching-card population without replacement
give zero, with an explanation that does not print spurious 0/0 factors.

Counts are whole numbers from 0 through 1000; die sides are 1 through 1000.
Numeric counts and English cardinals through 99, plus one hundred, are supported.
Mixed card categories, additional trial quantities, complements, conflicting
replacement instructions and incomplete quantities decline decisively. This
bounded grammar remains untrusted, and the capability declaration is static.

Changed files: `src/extract/discrete/{Disc_Games.thy,Discrete_Export.thy,
recognizer.sml,main.sml,capabilities.json,build.sh,beyond.py,games_probes.py,
README.md}` and this report. No shared source path changed. The build recipe now
uses the shared immutable-input `tools/dev/native-compile` helper. `beyond.py`
can filter to one changed specialist instead of running unrelated generators.

## Proof and actual compiler inputs

Passed proof receipt:
`var/discrete/remote-attempts/20261018T074155Z-1496bfb5b687/receipt.json`.
The actual log says `Finished Veri7vn_Discrete (0:01:25 elapsed time)` and the
whole session scan reports **89 theorems, zero oracles**. Export SHA256:
`1cfe11c33c1d2590a2ace42e39d8f552e13578c0ba5fef8248bc70371b8c503b`.

Native input manifest:
`var/discrete/native-attempts/20261018T075542Z-f1a38f73b1b0/compile-inputs.json`.
This records the actual copied generated kernel, recognizer, main and commons
that MLton consumed, their hashes, the proof receipt, and the resulting binary.
Native SHA256:
`8b5edec2dc27341bc9b40341ad4244f6e22ddc4af10c41d90e8b58966cb1dcf1`.
The immutable executable is `binary` beside that manifest.

The first proof attempt `20261018T073438Z-280c004d0ec4` failed on three unfinished
propositional/range steps and published no export. Those steps were repaired in
the passed successor. The first native attempt `20261018T075107Z-75bb590166ff`
found that exported signed integers use constructor `Int_of_integer`; correcting
the recognizer required only another native compile, not another proof build.

The new mathematical statements are:

- `roll_sequences s k = {xs::int list. set xs ⊆ {1..int s} ∧ length xs = k}`.
- `card (roll_sequences s k) = s^k`, and `0 < s` implies its cardinality is positive.
- `finite A` implies the number of length-k lists over A containing f is
  `(card A)^k - (card (A - {f}))^k`. This uses independent list/set counting.
- The number of roll sequences containing f is `s^k - (s-1)^k` when
  `1 ≤ f ∧ f ≤ int s`, and zero otherwise.
- `g_kernel (G_atleast s k f) = GProb GK_at_least_one p` implies that p is the
  ratio of the containing-face count to the complete roll-sequence count, and
  `0 ≤ p ∧ p ≤ 1`. The recognizer requires positive sides, so the independent
  denominator-positivity statement applies to its requests.
- `g_kernel (G_atleast s 0 f) = GProb GK_at_least_one 0` for every s and f.
- A face outside `1..int s` makes `g_kernel (G_atleast s k f)` return probability zero.
- `g < k` implies `seq_prob g n k = 0`, and `card_good c < k` implies
  `g_kernel (G_card_k c k False) = GProb GK_card_k 0`.

The existing ordered-card-count theorem still states that a without-replacement
probability times the number of ordered draws from 52 cards equals the number
of ordered draws from the matching cards. The new explicit zero theorem adds
information when both counts vanish. None of these statements proves that the
English request was interpreted correctly. The theorem-name array in the
transport is a static list, not a per-answer certificate.

## Runtime evidence

The shipped independent scorers give **508/508 right** in specialist mode and
**508/508 right** in family mode, zero wrong, false yes or valid withheld:

| Exact specialist ID | Dev right/total | Heldout right/total |
|---|---|---|
| games-v3 | 51/51 | 18/18 |
| logic-v3 | 33/33 | 12/12 |
| dataformats | 93/93 | 93/93 |
| algorithms | 42/42 | 42/42 |
| calculus | 62/62 | 62/62 |

Receipt: `var/discrete/e/shipped-final.json`. No full six-criterion head run is claimed.
Fresh games generator seeds 181139, 181151 and 181163 give **207/207**; the
original organ gives 205/207. The final untouched post-freeze seed 181173 gives
**69/69** for both new and original organ. These use the supplied games
generator/scorer and share their tables/templates. The first two seeds also
matched the prior ordinal executable (138/138). They preserve earlier anagram
gains; the new dice/card gains appear in the authored cases below. Receipts:
`var/discrete/e/fresh-before/report.json` and
`var/discrete/e/fresh-final/report.json`.

The expanded 213 authored games checks improve from **56/213 to 213/213**.
Expected dice values enumerate small finite sample spaces; card values use exact
binomial counts or independent-draw powers. After the implementation froze,
seed 181167 gives **213/213**, changing 50 random card-count cases while retaining
the boundary cases. This is a heldout numeric sample from the lane's own harness,
not independent language evidence. Receipts: `games-after.json` and
`games-heldout-final.json` under `var/discrete/e/`. The prior calculus probes remain
**24/24**, and the complete ordinal probes **168/168**.

Actual `dispatch.py --order front --organs discrete --no-reader --no-document
--no-routes` passes **213/213 pinned and 213/213 unpinned**. Unsupported requests
retain `provenance.dispatch.decisive=true`. Receipt: `var/discrete/e/dispatch-final.json`.
This is scoped composition, not an all-family collision or full-head claim.
Linux replay of this new games executable is pending package integration.

Binary size is **940,888 bytes**. Specialist round-trip medians range from
**0.046 to 0.157 ms**; games family-mode median is **0.271 ms**. Five final process
launches after preceding probe runs measured **4.25, 4.13, 3.94, 3.54, 4.43 ms**.
An earlier intermediate build measured 137.75 ms on its first score-harness
launch, followed by 3.51–5.03 ms. The first-launch variation remains unexplained;
the all-uncached-starts-under-20-ms target is not established. No speedup claim
is made.

The cold `HOL-Analysis` integral bridge remains unverified scratch. The build
owner deferred its potentially long dependency build while ordinary family
proofs converge and disk space is constrained. It did not block this games packet.

## Per-specialist review and outstanding work

All examples below were run against the captured ordinal executable at
`var/discrete/d/immutable/discrete`. Its hash is
`deeb407fe9adac328701339f766ce2ba04388e0dcb82ea4e8920dd35e1d66fa6`.
The shipped family panel being green does not settle any of these examples.

| Exact specialist ID | Concrete finding and next boundary |
|---|---|
| calculus | Complete ordinals and malformed adjacent modifiers are fixed in `21242bd`. Cross-variable derivatives still refuse accurately, although the derivative of x squared with respect to independent y is zero. The real-integral bridge remains unverified. |
| games-v3 | Fixed in this packet: face 7 on d6 previously gave 91/216 for three rolls; five aces without replacement became one-card probability 1/13. Typed face retention, complete counts, empty draws and impossible events are checked in this packet. |
| dataformats | Hash/Base64 requests collapse spaces inside literal payloads: `"a  b"` becomes `"a b"`. A literal newline inside a JSON string becomes a space and wrongly passes validation. `-10 decimal to binary` becomes positive 10; `1.5 decimal to binary` becomes 5. Next packet must preserve raw payload bytes through actual dispatch and consume the complete numeric token. Signed integers deserve exact support; fractions need an explicit boundary. No fix yet. |
| algorithms | Sorting `[1/2,3,4,5]` produces `2,3,4,5`; sorting `[1,2,3,4/5]` produces `1,2,3,4`. MST for `A-B(-1), B-C(2), A-C(10)` drops the negative edge and reports 12 instead of 1; shortest path A to C similarly reports 10 after dropping A to B. The certificate proves the parsed graph, not coverage of the requested graph. Next packet must consume whole lists and edges. Sorting already uses rational comparison; negative MST weights are mathematically valid, while negative shortest-path edges require appropriate algorithm assumptions. No fix yet. |
| logic-v3 | `Is p |- p and q valid?` wrongly says valid. `Is p and q |- p valid?` and `Is p and not p |- q valid?` wrongly say invalid. The argument-span selector drops word operators even though the formula parser supports them. The mixed formula `p -> q or not (p -> q)` also gets only a symbolic subspan classified as contingent. Next packet must consume complete premises/conclusions/formulas. No fix yet. |

Remaining algorithm assurance includes completeness of Kruskal passing its
independent minimality checker. Current successful certificates remain useful,
but they do not fix the interpretation failures above. JSON and digest
correspondence retain their existing tested-only boundaries.
