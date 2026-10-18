# Facts and humanities continuation

Owner: Codex symbolic/facts_humanities, 18 October 2026. Both families are
complete with fresh proof exports, native panels and dispatcher probes.
Humanities is committed as `45c425b`; the first Facts packet is committed as
`165458a`. A second Facts packet is complete below. Further semantic extensions remain
explicitly open; family green is not a claim that every specialist is finished.

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


## Second Facts packet: scope and requested attributes (complete, ready)

The user expanded the goal to correct source-organ wrongness beyond its shipped
panels. Typed question grammars now attach to actual exported row guards via
`row_guards`, rather than copied patterns. They distinguish human measurements
from animal ones, adult pet teeth from newborn ones, attribution from definitions,
and globally scoped records from local records. They also constrain plant
photosynthesis, insect anatomy, adult CPR, fungal wall material, bread-plate
placement, event dates and exact-title creator questions. Useful alternate
requests are supported, including permanent-tooth counts, usual adult pulse,
insect wing attachment and plant-cell organelles. No source facts or kinds change.

Review caught an incomplete event distinction: a year prefix alone still let
Magna Carta destruction and Hastings commemoration select the original dates.
All 17 date rows now use complete positive event clauses with an exact subject
and event relation. Every date row has an occurrence-positive and an unrelated-
event or extra-scope negative (34 new probes). No verb blacklist is used.

The new HOL definition conjoins independent checked occurrence with the
recognizer predicate. `checked_feature_narrows` states
`checked_features q m p ==> m p`: the checked matcher cannot undo a subject or
requested-attribute restriction. `text_answer_word_occurs` says a selected
literal row has a boundary-delimited, ASCII-case-folded occurrence in the raw
question bytes. `text_answer_first_row` says the selected index is the first
row accepted by the composed feature map. Checked literals now admit internal
spaces as well as ASCII letters. A syntactic inventory finds 115/417 source
guards in that form, versus 58 single-word guards before; all 44 linguistics
rows still have their proved coverage fact. The count is not an additional
coverage theorem. Neither these theorems nor the recognizer prove NLP entailment
or source world truth.

Fresh proof receipt:
`var/facts/remote-attempts/20261018T071339Z-de60bcbf0e83/receipt.json`:
**passed, exports published, exit 0, 63 theorem checks, 0 oracles**.
Export SHA256: `12c80bbb98837bb44ad2d9c7e52ce896ae0afb917d94587a5add6765c8912c09`.
The old warm development artifacts under `next-scope-dev/` are not evidence.

All 22 specialists and family mode: **dev 221/221, heldout 207/207,
wrong 0, false yes 0, valid omissions 0**. The 113 authored probes pass in native
specialist mode, actual dispatcher mode with routes/guards enabled, and unpinned
family mode. A dog-temperature query correctly reaches pets in family mode.
Creator replies retain the exact known title matched by the selected row,
allowing the correct `Name the painter/author of ...` forms through G3s.
`source_sentence` preserves original table prose and `source_subject` records
the matched title. Extraction/rendering is untrusted; unrelated restoration,
purchase, replica, sequel, compound-title and impossible-date queries stay silent.
No arbitrary user qualifier is copied into the response.

The 924-question core comparison for each specialist has eight differences:
six only retain work titles in the response, and two correct the shipped
organ's answers to impossible-date Mona Lisa/Starry Night questions by withholding.
There are no other status/kind/value changes. Tables checker: 0 failures.
Native binary: 422,872 bytes. Exact timings and comparisons are in
`var/c-symbolic-facts-humanities/facts-scope-panels.json`; probes are in
`facts-scope-probes.json`, `facts-scope-dispatch.json` and
`facts-scope-family-probes.json` in that directory.

The shared native compiler now freezes the actual flat MLB inputs, validates
the export and unchanged proof dependencies, and atomically publishes the binary.
Immutable native receipt:
`var/facts/native-attempts/20261018T074200Z-dc3c78e1cadf/compile-inputs.json`.
Binary SHA256: `4c56f2814267a06a05b633f4bcdb6aa896a4611ed40c7b8f5427b711e06d9ce2`.
Recognizer SHA256: `ec700e4aadfe4fc1e01a26e6f88df2147035eac4a1c925decb120820f59c5d56`.
Main SHA256: `f31c56fa908af5b0d1b490b9d85747c97a47057a329e28792fb24c4df2df1c13`.
Commons SHA256: `1cce00aede6c14c3121ccfe8777b5bcdf3618ffcbeb6b6729e05e7b691a93962`.
Main and recognizer follow the proof snapshot and must be consumed from this
native snapshot; current theories and ROOT match the proof receipt. The shared
build wrapper follows the snapshot too, without changing proof statements.

Frozen second-packet files, below `src/extract/facts/`: Facts_Export.thy,
Word_Guards.thy, recognizer.sml, main.sml, build.sh, capabilities.json,
beyond_probes.json, README.md, plus this combined lane report.

Known art-medium limitation: the creator grammar distinguishes the exact work
and requested creator, but currently pools painted/sculpted/created verbs.
`Who sculpted the Mona Lisa?` still answers Leonardo da Vinci. The next change
must distinguish each source work's medium; no claim of medium correctness is
made for this packet.

Outstanding next work: mycorrhizal exchange needs directional structured values;
the shipped scorer scans prose mentioning both directions and misses a value
always set to sugars. JavaScript needs whole-expression, case-sensitive typed
evaluation. The ledger below records further individual semantic limits.

## Per-specialist semantic review ledger

This ledger separates completed packets from remaining semantic work.
A family score is not evidence that every behavior below has been examined.

| Exact specialist ID | Concrete behavior examined | Status / bounded remaining limit |
|---|---|---|
| literature-v2 | Quoted “best/worst” opening lines versus an actual opinion outside the quote | First packet complete; other literary attribute/edition ambiguities not yet reviewed |
| worldhistory | Winner/signatory requests and destruction/commemoration dates selected original event years | Complete event clauses plus positive/negative probes for all 17 date rows; alternate events and reissues are withheld, not modeled |
| arthistory | Thief/replica questions containing Mona Lisa selected the original artist | Exact-title creator grammar complete; medium still unmodeled: “Who sculpted the Mona Lisa?” wrongly answers Leonardo da Vinci; ambiguous titles remain source assumptions |
| medicine-r2 | Animal-scoped pulse/pressure and unqualified adult measurements | Shared typed measurement grammar complete in second packet; drug/clinical interpretation outside these rows unexamined |
| medicine | Axolotl pressure, hummingbird pulse, dog temperature selected human values | Temperature fix complete in first packet; pulse/pressure grammar and useful alternate wording complete in second packet |
| law | Marbury vote count selected judicial review | Principle-request grammar complete in second packet; other case attributes and non-US legal scope unexamined |
| psychology | Definitions/criticism of classical conditioning selected its discoverer | Attribution grammar complete for classical/operant rows in second packet; definition values and other concepts remain open |
| sociology | “What does anomie mean?” returns structured value Emile Durkheim though its sentence says normlessness | Confirmed structured-attribute gap; typed projection still pending |
| linguistics | English embedded beside accented letters, digits, underscores or other letters | First-packet byte-boundary fix complete; all 44 source rows covered by literal guard theorem; broader subject disambiguation remains open |
| poetry | Illustrator/sequel questions containing a known title selected its original writer | Exact-title author grammar complete in second packet; prosody edge cases not yet examined |
| botany | Bacterial photosynthesis selected plant chloroplasts | Plant/organelle grammar complete in second packet; other taxonomic scope assumptions unexamined |
| entomology | Spider leg attachment selected insect thorax | Insect-appendage grammar and wing query support complete in second packet; larval/anatomical exceptions unexamined |
| marinebio | Largest fish in Loch Ness selected global whale shark | Global-range grammar complete in second packet; other ocean zone/property attributes unexamined |
| ornithology | Largest bird in New Zealand selected global ostrich | Global record grammar complete for size/wingspan in second packet; extinct birds and source-record rankings not adjudicated |
| mycology | “How thick are fungal cell walls?” selected material chitin | Material-request grammar and polymer query complete in second packet; species exceptions unexamined |
| mycelial | Fungi-to-plant exchange returns structured value sugars, although prose supplies both directions | Confirmed scorer blind spot; directional typed value projection pending |
| pets | Newborn puppy/kitten teeth selected adult counts | Adult/permanent-tooth grammar plus tooth-count variants complete in second packet; other age/health contexts unexamined |
| childdev | Definition of object permanence selected its developmental stage | Stage-request grammar complete in second packet; definition projection and other developmental assertions open |
| etiquette | Bread plate material question selected placement upper left | Placement grammar and alternate request complete in second packet; cultural gift-setting scope unexamined |
| firesafety-v2 | UK-qualified electrical-fire class still returns Class C | Jurisdiction is not modeled; concrete scoped review pending, no claim of cross-jurisdiction correctness |
| firstaid | Infant/two-rescuer CPR selected adult single-rescuer rows | Adult-model vocabulary/metric restriction complete in second packet; wider first-aid scope still unexamined |
| javascript | Whole-expression suffix and identifier case are ignored by canned regex | Finite typed evaluator design prepared; actual implementation/proof/consumer integration pending |
| music-v2-r2 | MIDI Cb4/B#4 cross octave boundaries; inverse preserves pitch class with exact octave carry | Humanities packet complete; other music semantics remain bounded to existing operations |
| music-v2 | Same MIDI boundary and source panel/fresh-seed checks | Humanities packet complete; no separate claim that every musical convention was reviewed |
| grammar | Unknown candidates in past/plural/comparison forms must stay silent under the active priority flags | Humanities packet complete; word-formation rules remain closed source tables |
| mythology | Non-identical Greek/Roman forward rows have reverse names in the reverse table | Reverse-table theorem complete; ambiguous cultural attribution and variants unexamined |
| ushistory | Own shipped panels and three generator offsets exercised | No new semantic counterexample review beyond those panels; explicit bounded unexamined area |
| library | Target ISBN-13 label must not swallow the “10” from a later source ISBN-10 label | Conversion-label fix and independent probes complete; broader bibliographic identity not proved |
| government | Alternate structural counts versus historical, foreign and state-specific scopes | Typed count forms and scope refusals complete; broader constitutional/temporal questions unexamined |
