# Facts and humanities continuation

Owner: Codex symbolic/facts_humanities, 18 October 2026. Both families are
complete with fresh proof exports, native panels and dispatcher probes.
Humanities is committed as `45c425b`; Facts is frozen and ready for integration.

## What changes

Facts gains an executable HOL matcher for literal word guards of the form
`\bword\b`. The real answer path calls it, rather than accepting the regex
engine's Boolean for those guards. It checks the letters, ASCII case folding,
position and boundaries in the supplied question. All 44 linguistics rows use
this form. Non-ASCII bytes count as word characters to avoid finding an ASCII
name inside a longer Unicode word. Other regex patterns, gate/block/ask,
narrative classification, JSON decoding and source transcription remain
untrusted. The reply identifies whether its chosen row used the checked matcher.
This is pattern matching, not a proof that the sentence is true or that the
question semantically asks for the returned fact.

Humanities completes the existing ISBN conversion and government count queries.
The old ISBN recognizer could read the `10` in the source label as digits after
a target `ISBN-13` label. The revised recognizer prefers a number immediately
after its own label. Government alternate questions use the existing HOL rows;
qualified historical, foreign and state-specific queries do not gain an answer.
No new answer kinds are required.

The audit's MIDI octave equality was false: Cb4 is MIDI 59, whose canonical
spelling is B3; B#4 is MIDI 72, C5. The replacement preserves pitch class and
includes the exact octave carry. Grammar silence is established for past tense,
plural and comparison as well as the existing participle statement. Every
non-Apollo Greek-to-Roman row appears in the reverse table.

Runtime self tests remain build-time checks and no longer become eager exported
values. The family build scripts consume remote exports and accept explicit
`FACTS_GEN`/`HUMANITIES_GEN` paths to pin a completed attempt; they do not delete
old exports or silently read a stale local session database.

## Baseline and development measurements

Before: humanities specialist dev/heldout right:
music-v2 64/64, music-v2-r2 64/64, grammar 15/15, mythology 13/13,
ushistory 12/12, library 15/14, government 14/10; wrong and false yes zero.
The five heldout omissions are ISBN conversion and four government questions.
Recognizer-only warm-export development check answers all five, with all original
panels still wrong/false-yes zero, and passes 22/22 committed author-written
probes. This is not a fresh proof or a completed-family receipt.

Fresh humanities generators use offsets 610018 and 710019, preserving the
shipped generator's two split seeds. They vary samples and numbers, not fixed
phrasing templates. Both baseline runs reproduce omissions in library and
government. The fixed Facts panels have no seed parameter or random generation;
claiming fresh seeded Facts panels would be misleading.

All 22 Facts specialists measured before: dev 221/221 right, heldout 200/207
right, zero wrong/false yes; seven baseline omissions (literature quotation blocked
by `best`/`worst`, botany 2, marine biology 2, ornithology 2). Exact per-specialist
counts are in `var/c-symbolic-facts-humanities/all-facts-before.json`.

## Proved statements consumed by the implementation

- `word_holds_occurrence`: the executable word matcher succeeds iff an offset
  in the question satisfies `word_at`, which independently spells out substring
  equality and both boundaries after ASCII case folding.
- `text_answer_word_occurs`: when the actual text answerer answers at row i and
  that row decodes to word w, such an offset exists in the supplied question byte string.
- `text_answer_first_row`: the answer index is within the store; value and sentence
  come from that row, and no earlier row's checked feature holds.
- `linguistics_guards_checked`: every linguistics row decodes as a literal-word guard.
- `gkernel_silent_past/plural/comparison`: silence with the corresponding active
  priority flag means every candidate is absent from the relevant closed table.
- `midi_kernel_roundtrip`: encoding n at octave oct to k, then decoding k to n',
  oct', implies equal pitch classes and
  `oct' = oct + (nat_pc (fst n) + snd n) div 12`.
- `g2r_in_r2g`: each forward row with different Greek and Roman keys has its
  reversed names in the reverse table.

## Remaining scope

Root integration and cross-platform packaging consume the frozen source and
receipts below. No Facts or Humanities proof or native-panel work remains.
These are scoped family results, not all six exam criteria or a full Oracle7
head comparison. Source assertions, broad natural-language interpretation and
nonliteral regex guards remain untrusted. Facts has fixed panels rather than
fresh random generators. No value-substring claim is revived: source values
need not occur literally in their sentences.

## Humanities ready for integration (final native evidence)

Fresh proof/export receipt:
`var/humanities/remote-attempts/20261018T065404Z-478dcd4ff9dd/receipt.json`,
passed, exported, `VERI7VN_HUMANITIES PASS theorems=115 oracles=0`.
The comparison-silence proof needed an explicit split on the superlative flag;
statements were unchanged. The false audit octave equality was replaced by the
exact carry statement above. All current humanities `.thy`, `.sml`, and build
script files match this final receipt snapshot.

Final specialist dev/heldout right: music-v2 64/64, music-v2-r2 64/64,
grammar 15/15, mythology 13/13, ushistory 12/12, library 15/15, government 14/14.
Total **197/197 each split, zero wrong, false yes or withheld valid items**,
versus the prior kernel's 197/192. Family mode gives the same counts.
Fresh offsets 610018, 710019, 910021 each give 197/197 on each split with zero
wrong/false yes/withheld valid. The third offset was untouched until the final
binary. Shipped-organ control dev/heldout: 196/193, 197/193, 196/193 respectively;
zero wrong/false yes, with 1/4, 0/4, 1/4 valid omissions. The generators vary
choices/numbers and retain their author's fixed templates.

The final 25 author-written probes pass 25/25 natively and 25/25 through the real
dispatcher in front order, with specialist pinning, guards/routes enabled and
relation/document adapters disabled. This tests acceptance and composition;
it is not all six exam criteria or a comparison against the complete Oracle7 head.
Government historical, foreign and state-specific structural queries are refused
by the untrusted recognizer; they do not become a new certified decline kind.

Binary 597,032 bytes, median cold start 14.49 ms; specialist p50 round trips
0.059–0.178 ms. Receipt-bound native inputs:
`var/humanities/build/compile-inputs.json`.
Binary SHA256:`b6ef6d025627e8f80440e092c219a779c2c03640bd257e93890311738c3cc0d6`.
Export SHA256:`e8d1520430f42cae569436f2860d7c41df33696b7031cbf47dcc268f754879cd`.
Tables checker passes with 0 failures.

Final receipts are under `var/c-symbolic-facts-humanities/`:
`humanities-final.json`, `fresh-final/report.json`,
`humanities-probes-final.json`, `humanities-dispatch-final.json`.

Humanities changed files (frozen): README.md, Humanities_Export.thy, build.sh,
recognizer.sml, capabilities.json, beyond_check.py, beyond_probes.json,
check_probes.py, facts/Grammar.thy, facts/Mythology.thy, facts/Facts_Check.thy,
music/Music.thy, music/Music_Check.thy, all below `src/extract/humanities/`.
Humanities source is frozen and committed; no subsequent edits were made.


## Facts ready for integration (final native evidence)

Proof/export receipt:
`var/facts/remote-attempts/20261018T065727Z-84d4fd490a22/receipt.json`,
passed, export published, exit 0; `VERI7VN_FACTS PASS theorems=62 oracles=0`.
The executable offset equivalence needed `auto` rather than `simp`; its statement
was unchanged. The initial literal-string interface rejected non-ASCII input.
The final interface exports `question_bytes`, decoding actual UTF-8 byte integers
into HOL characters, and the driver passes that result into both text answerers.
It does not strip or replace accented characters. Bytes 128 and above count as
word characters, so accented adjacency cannot masquerade as an English word
boundary. Unicode punctuation may conservatively prevent a match; this is not
full Unicode linguistic word segmentation.

All 22 specialist panels: **dev 221/221, heldout 207/207; wrong 0, false yes 0,
valid omissions 0**. Family mode gives the same counts. Before: specialist
221/200, family 220/200, with seven heldout omissions and a pre-existing family
wrong answer for a dog's body temperature. Question normalization closes the
seven omissions using existing rows. A positive recognition grammar now limits
the human-temperature row to explicit human or unqualified constructions, so
animal questions reach pets or remain silent. This narrowing is untrusted.
The final core comparison has zero differences on each specialist's 924 questions.

The final 29 author-written probes pass **29/29 natively and 29/29 through the
actual dispatcher**, with specialist pinning, routes/guards enabled and relation/
document adapters disabled. Three unpinned family probes also pass: dog gets
101 to 102.5, human gets 98.6, and an axolotl temperature question is withheld.
The accented prefix/suffix probes now return withheld, without exceptions.
An accepted English-language family query reports `checked_ascii_word`, word
`english`, with the other recognizer checks explicitly untrusted.

Binary: 385,480 bytes; median cold start 5.35 ms; specialist p50 round trips
0.240–1.449 ms, family 0.481–2.843 ms. Tables checker: 0 failures.
Native inputs: `var/facts/build/compile-inputs.json`.
Binary SHA256: `fe9ce8e556a1cc1ee31df1c9c214f75c43afaae0d3b10cfcd39cfa97e9c8a74e`.
Export SHA256: `109a62fb2e6d608a3918f771397390eb24383b509132b99813e0f8c101d1b2bd`.
Final recognizer SHA256: `f69d79ea390693f6ccc216fae5d40595908b046ea992a0de1a06c26ab0541ea8`.

All own theories, ROOT, main.sml and build.sh match the successful proof snapshot.
The final recognizer temperature narrowing follows that snapshot and is bound
by the native compilation receipt; Linux packaging must consume this current
recognizer, not blindly use the older snapshot. The compiled commons source
matches the snapshot and has SHA256
`1cce00aede6c14c3121ccfe8777b5bcdf3618ffcbeb6b6729e05e7b691a93962`.

Final measurements under `var/c-symbolic-facts-humanities/`:
`all-facts-final.json`, `facts-probes-final.json`, `facts-dispatch-final.json`,
`facts-family-temperature-final.json`. The earlier `all-facts-ascii-export.json`
is explicitly an obsolete ASCII-interface result, not final evidence.

Facts changed files (frozen), all below `src/extract/facts/`:
Facts_Export.thy, ROOT, Word_Guards.thy, main.sml, recognizer.sml, build.sh,
README.md, capabilities.json, beyond_probes.json. The combined report is also
ready for integration. No new kinds are added; capability declarations describe
acceptance/evidence assumptions and are not per-answer proof certificates.
