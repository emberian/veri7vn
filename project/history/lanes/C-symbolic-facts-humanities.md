# Facts and humanities continuation

Owner: Codex symbolic/facts_humanities, 18 October 2026. Completed packets have
fresh proof exports, native panels and dispatcher probes. Humanities packets are
committed as `45c425b` and `285e963`; Facts packets as `165458a` and `1d8332e`.
The third Facts packet is committed as `83bb150`; a fourth is ready below with the dispatcher clarification regression repaired. Further semantic extensions
remain explicitly open; family green is not a claim that every specialist is
finished.

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
| literature-v2 | Opening-line quotation versus opinion; original authorship/publication versus sequels, adaptations and translations | Quotation fix complete; exact-title author/first-publication grammar implemented in third packet, native consumer complete; stated coverage limits remain; four narrator/two setting rows complete in fourth packet; quotations and remaining attributes still bounded |
| worldhistory | Winner/signatory requests and destruction/commemoration dates selected original event years | Complete event clauses plus positive/negative probes for all 17 date rows; alternate events and reissues are withheld, not modeled |
| arthistory | Thief/replica questions selected the original artist; sculpture verbs selected a painting’s artist | Exact-title and medium grammar complete through third packet; mismatched media withhold rather than invent an answer; ambiguous titles remain source assumptions |
| medicine-r2 | Animal-scoped pulse/pressure and unqualified adult measurements | Shared typed measurement grammar complete in second packet; drug/clinical interpretation outside these rows unexamined |
| medicine | Axolotl pressure, hummingbird pulse, dog temperature selected human values | Temperature fix complete in first packet; pulse/pressure grammar and useful alternate wording complete in second packet |
| law | Marbury vote count selected judicial review | Principle-request grammar complete in second packet; six general definition scopes complete in fourth packet; other case attributes and non-US legal scope remain bounded |
| psychology | Definitions/criticism of classical conditioning selected its discoverer | Attribution grammar complete for classical/operant rows in second packet; definition values and other concepts remain open |
| sociology | “What does anomie mean?” returns structured value Emile Durkheim though its sentence says normlessness | Source-bound typed meaning projection implemented; third-packet checked projection and native consumer complete; source truth remains assumed |
| linguistics | English embedded beside accented letters, digits, underscores or other letters | First-packet byte-boundary fix complete; all 44 source rows covered by literal guard theorem; full source-language identity and branch projection complete in fourth packet; other language varieties and disputed classification remain unsupported |
| poetry | Illustrator/sequel questions selected original writer; syllables in a form’s name versus its verse pattern | Exact-title author grammar complete in second packet; all ten form/metric row grammars implemented in third packet, native consumer complete; stated coverage limits remain; total haiku syllables not projected |
| botany | Bacterial photosynthesis selected plant chloroplasts | Plant/organelle grammar complete in second packet; other taxonomic scope assumptions unexamined |
| entomology | Spider leg attachment selected insect thorax | Insect-appendage grammar and wing query support complete in second packet; larval/anatomical exceptions unexamined |
| marinebio | Largest fish in Loch Ness selected global whale shark | Global-range grammar complete in second packet; other ocean zone/property attributes unexamined |
| ornithology | Largest bird in New Zealand selected global ostrich | Global record grammar complete for size/wingspan in second packet; extinct birds and source-record rankings not adjudicated |
| mycology | “How thick are fungal cell walls?” selected material chitin | Material-request grammar and polymer query complete in second packet; species exceptions unexamined |
| mycelial | Fungi-to-plant exchange returns structured value sugars, although prose supplies both directions | Directed resource-edge model and source-bound value projection implemented; third-packet checked projection and native consumer complete; source truth remains assumed |
| pets | Newborn puppy/kitten teeth selected adult counts | Adult/permanent-tooth grammar plus tooth-count variants complete in second packet; other age/health contexts unexamined |
| childdev | Definition of object permanence selected its developmental stage | Stage-request grammar complete in second packet; definition projection and other developmental assertions open |
| etiquette | Bread plate material question selected placement upper left | Placement grammar and alternate request complete in second packet; cultural gift-setting scope unexamined |
| firesafety-v2 | UK-qualified electrical-fire class selected US Class C | US/unqualified fuel and class grammar complete in third packet; other jurisdictions are not modeled; native consumer complete; stated coverage limits remain |
| firstaid | Infant/two-rescuer CPR selected adult single-rescuer rows | Adult-model vocabulary/metric restriction complete in second packet; wider first-aid scope still unexamined |
| javascript | Whole-expression suffix and identifier case were ignored by canned regex | Finite typed evaluator and whole-expression consumer complete; 673/800 independent engine-matching answers, 127 withheld-valid; unsupported operators/floats/calls remain explicit limits |
| music-v2-r2 | MIDI Cb4/B#4 cross octave boundaries; inverse preserves pitch class with exact octave carry | Humanities packet complete; other music semantics remain bounded to existing operations |
| music-v2 | Same MIDI boundary and source panel/fresh-seed checks | Humanities packet complete; no separate claim that every musical convention was reviewed |
| grammar | Unknown candidates in past/plural/comparison forms must stay silent under the active priority flags | Humanities packet complete; word-formation rules remain closed source tables |
| mythology | Non-identical Greek/Roman forward rows have reverse names in the reverse table | Reverse-table theorem complete; ambiguous cultural attribution and variants unexamined |
| ushistory | Foreign president, defeated-president relation, and destruction/commemoration dates incorrectly answered US ordinal/event years | Whole president-role grammar and complete clauses for all 19 event rows now pass consumer probes; source chronology/coverage assumptions remain |
| library | Target ISBN-13 label must not swallow the “10” from a later source ISBN-10 label | Conversion-label fix and independent probes complete; broader bibliographic identity not proved |
| government | Structural membership versus attendance/quorum/vacancies; minimum eligibility versus actual person age | All 13 fact-row request grammars complete in third packet; topic/amendment/article interpretation still bounded and unexamined beyond prior probes |


## Second Humanities packet: president roles and event identity (ready)

The shipped US-history recognizer answered `Who was the 1st president of France?`
with George Washington, `Who defeated the 2nd US president?` with John Adams,
and `When was the US Bill of Rights destroyed?` with 1791. Full question forms
now bind the requested president role, US scope, complete source name and valid
ordinal suffix. Full event clauses pair every one of the 19 existing date rows
with its actual source event. Foreign scope, changed events and trailing movie/
novel qualifications do not match. These are positive grammars, not a list of
forbidden verbs. Source assertions and English interpretation remain untrusted.

No HOL statement changed. The consumer is the existing `hreply` kernel:
`nth_value` binds an accepted ordinal to the corresponding president list entry;
`num_value` binds a name to its ordinal positions; `event_value` binds an accepted
ordered event mask to its stored date and text, with the existing US/other-country
scope preconditions. This does not prove that the recognizer understood English.

The existing proof receipt `var/humanities/remote-attempts/20261018T065404Z-478dcd4ff9dd/receipt.json`
passed 115 theorem checks with 0 oracles. Current proof dependencies are identical.
New immutable consumed-input receipt:
`var/humanities/native-attempts/20261018T075229Z-40f92d862903/compile-inputs.json`.
Binary SHA256 `9ed6ff9b607d5a370ccb38ada66ab4a34ce2e5c25ae1e01f7c8c76c4934a69dc`,
598,472 bytes. Recognizer SHA256
`425f0ad967e587bbb14b5f1e65964bcfac10647c4084f29076097d49f18e18ab`.
The new shared `native-compile` wrapper freezes actual MLB inputs and validates
the proof/export binding before atomically publishing. It consumes this current
recognizer, not the older recognizer in the proof snapshot.

All seven specialist panels and family mode: **197/197 dev, 197/197 heldout,
0 wrong, 0 false yes, 0 valid omissions**. All **70/70** authored probes pass
natively, through the actual dispatcher, and in unpinned family mode. The new
45 probes cover president-role positives/negatives and every event row with a
positive and an unrelated-event/scope negative. Two previously untouched
US-history generator offsets, 1310023 and 1410029, each score **12/12 dev and
12/12 heldout**, 0 wrong/false yes/omissions. Generator phrasings are still the
source author's fixed templates, not independent language coverage.

Evidence under `var/c-symbolic-facts-humanities/`:
`humanities-scope-panels.json`, `humanities-scope-probes.json`,
`humanities-scope-dispatch.json`, `humanities-scope-family-probes.json`,
`ushistory-fresh-report.json`. Humanities files frozen:
recognizer.sml, build.sh, capabilities.json, beyond_probes.json, README.md,
plus this report. No new kinds, source rows or proof claims.

## Third Facts packet: typed expressions and requested fields (ready)

The new JavaScript consumer parses a complete, case-sensitive expression into
an exported HOL AST. It supports bounded integer literals, ASCII strings,
booleans, null, undefined, NaN, addition, subtraction, strict/loose equality,
typeof and parentheses. Numeric literals, coerced strings and intermediate
numeric results must remain within ±9007199254740991. Unsupported syntax,
coercion or arithmetic declines. Exact whole expressions outside this finite
model (the existing floating-point examples, array typeof, Math.max and parseInt)
and static facts use a whitelisted source-table lookup. They retain source-table
assumptions. This is not a complete ECMAScript or IEEE-754 proof.

The source row for mycorrhizal exchange previously answered both directions with
the scalar “sugars.” A typed directed resource relation now projects sugars from
plant to fungus, and water plus mineral nutrients from fungus to plant. The
anomie row similarly projects “normlessness” for a meaning request, while keeping
its attributed author for an authorship request. Both projections consume the
actual checked Facts outcome and validate its source store and row identity.
The typed edges and concept meaning are source transcriptions, not proved world
facts or proved English interpretation.

New theorem statements and actual consumers:

- `js_eval_sound`: `js_eval e = Some v` implies the inductive primitive-expression
  semantics relates `e` to `v`. `Main.jsReply` consumes this exported evaluator.
- `js_eval_safe_integer`: an evaluator result `JNum n` has
  `abs n ≤ 9007199254740991`. The numeric-addition law requires both operands and
  their sum to satisfy this bound; string addition concatenates the string with
  the primitive rendering of a safe value. Differing primitive types cannot be
  strictly equal. These are laws of the stated finite model.
- `js_table_row_bound`: any emitted source pair equals the indexed source row's
  value and sentence, with the index in bounds. `Main.jsReply` uses this lookup
  only after the untrusted exact whole-expression/static-question recognizer.
- `transferred_exact`: a resource belongs to the selected transfer list iff its
  exact giver/receiver/resource triple belongs to the supplied edge list.
  `exchange_reverse_disjoint` says opposite directions for distinct partners
  have disjoint resources in this supplied relation.
- `projection_requires_source`: a successful requested-field projection requires
  an actual `Answer` at row 1 of the sociology or mycelial source store.
  `Main.reply` passes its checked answer into `projected_value`; the directional
  branch joins the list computed by `transferred`.

Whole-question grammars also distinguish artwork media, literary original
creator/publication requests from sequels and translations, poem/meter properties
from the spelling of their names, all six remaining historical person roles,
and the source US fire classification from other jurisdictions. Answers to US
fire-class questions name that scope. These interpretations remain untrusted.
Known-title rendering retains the actual matched source title rather than
copying arbitrary user qualifiers.

Proof receipt:
`var/facts/remote-attempts/20261018T080434Z-dde442a8ae3b/receipt.json`,
**passed 72 theorem checks, 0 oracles**. The first attempt `447864ed0f5f` failed
two ordinary proof tactics; explicit finite cases and an explicit implication
chain repaired the proofs without weakening statements. Facts_Base now inherits
the Commons heap to reuse the shared number renderer. Checked export SHA256:
`9e6f21b83474dc8aac3f1b267ede129a345e34e924bece9a5906da5279eb3bd6`.

Actual consumed-input native receipt:
`var/facts/native-attempts/20261018T081417Z-293860cc8585/compile-inputs.json`.
Binary SHA256 `2635eb6aa53c474250949c499692be80a91a16d3c034afeda9537095e22146e6`,
497,864 bytes. The first native attempt exposed the generated integer constructor's
capitalized name; the parser now uses that actual exported constructor. The final
native receipt binds current parser, projection, recognizer, main and commons
SML separately from the earlier proof snapshot, with unchanged proved theories.

All 22 shipped specialist panels and family mode remain **221/221 dev,
207/207 heldout, 0 wrong, 0 false yes, 0 valid omissions**. The 203 authored
policy assertions pass in native specialist, actual dispatcher and unpinned
family modes. They are not 203 answered capabilities: specialist/dispatcher
results contain **98 supported answers, 102 meaningful or underspecified valid
requests withheld, and 3 malformed-JavaScript refusals**, with no observed wrong
answers or false yeses. Family mode correctly routes the dog-temperature request
to pets, giving **99 supported answers, 101 withheld-valid, 3 syntax refusals**.
Authored `capability_case` metadata records this distinction; scorer expectations
were not relabeled to count unsupported meaningful requests as invalid.

Independent Node engine comparisons used two previously untouched generated-AST
seeds. Seed 912367: **333/400 answered matching Node, 0 wrong, 67 withheld-valid**.
Seed 1012381: **340/400 answered matching Node, 0 wrong, 60 withheld-valid**.
The generated expressions are valid JavaScript; all 127 omissions represent the
finite model's coverage boundary. These are independent engine observations,
not a formal ECMAScript correspondence proof or shipped panel numbers.

The unchanged source-table checker reports 0 failures across all 417 rows. Across
each specialist's 924 core questions, 28 replies differ from the shipped organ:
24 retain a matched title in the response; four refuse impossible-date author/
artist questions instead of discarding the date. There are no other core status
or value changes. Evidence is under `var/c-symbolic-facts-humanities/`:
`facts-third-panels.json`, `facts-third-probes.json`, `facts-third-dispatch.json`,
`facts-third-family-probes.json`, and both `js-conformance-<seed>.json` files.

Frozen named files: `src/extract/facts/{ROOT,JS_Expr.thy,Fact_Projection.thy,
Facts_Export.thy,javascript.sml,projection.sml,recognizer.sml,main.sml,build.sh,
capabilities.json,beyond_probes.json,js_conformance.py,README.md}` and this report.
Humanities remains the completed, integrated second packet above.

Remaining bounded work: broad literature narrator/setting rows still confuse
adaptations; `Who narrates the film adaptation of Moby-Dick?` returns Ishmael.
`Which language family does Arabic Sign Language belong to?` still returns the
spoken-Arabic family Afro-Asiatic. `What is habeas corpus in a video game?` still
returns the real legal definition. Total haiku syllables are not projected from
the stored per-line pattern. Artwork names shared by multiple works remain
source-table ambiguities. These are concrete next interpretation/capability work,
not covered by completed panels or by this packet's claims.


## Fourth Facts packet: language branches and full request scope (ready)

The old consumer answered `Which branch does English belong to?` with the family
Indo-European, although its source sentence supplied Germanic. A typed table now
carries the 43 source language/family/branch triples. The real response consumer
passes the checked source answer into `projected_value LanguageBranch`, returns
the selected branch as its structured value, and preserves the source sentence.
Basque has no supplied branch and a branch request withholds. Full language
identity and requested-family grammars prevent Arabic Sign Language, fictional
Neo-English and a wrong supplied parent family from being reduced to an embedded
spoken-language name. Mandarin/Cantonese Chinese are explicit known aliases.

New statements:

- `language_field_bound`: a successful lookup at index i requires 0<i and
  i≤length language_fields, and returns exactly language_fields[i−1].
- `language_family_rows`: the complete ordered list of typed family fields equals
  the actual source-table values after its Basque row. This checks all 43 row
  correspondences, not just observed probe selections. Branch assertions remain
  transcribed source data, not proved linguistic truth.
- `branch_projection_exact`: any successful branch projection requires a checked
  Answer from the linguistics store at an index whose typed field is precisely
  the returned branch (along with its source language/family).
- `projection_requires_source` now includes the linguistics source and bounded
  positive branch index, while preserving the original sociology/mycelial row-1
  requirements. The actual `Main.reply` consumer supplies its checked outcome.

Four narrator rows, two settings, ship/squire, seven character-to-work rows and
six legal definitions also use whole positive requested-relationship grammars.
A film adaptation no longer inherits a novel's narrator; asking who played Jean
Valjean no longer returns the work title; fictional legal settings no longer
inherit real legal definitions. Unsupported meaningful variants remain
withheld-valid. English interpretation and source assertions remain untrusted.

Proof receipt `var/facts/remote-attempts/20261018T083522Z-0c237f11e22f/receipt.json`
passed **75 theorem checks, 0 oracles**. First attempt c07182377287 proved the
projection/source lemmas but did not finish finite quantified correspondence
simplification. Direct equality of the complete family lists replaced that
index-heavy presentation without dropping rows or changing their order.
Export SHA256 `b4550d6fd2b7bb3e710045237b712add64bc5f35c291acaceed8368fc09a6dcf`.
Actual current native receipt:
`var/facts/native-attempts/20261018T084027Z-81fcefa97cb0/compile-inputs.json`.
Binary SHA256 `0a21f97b358e142a72d17747ba5052400c61f64b50f5e8931f4c0cc2a9e122b7`,
552,808 bytes. The helper binds current SML separately from the earlier proof
snapshot; proved theories match. `language_fields_check.py` independently reads
the upstream source AST and verifies all 43 typed triples and order exactly.

All 22 shipped specialist panels and family mode: **221/221 dev, 207/207 heldout,
0 wrong, 0 false yes, 0 valid omissions**. All **346/346** authored policy
assertions pass natively and in family mode. Native capability counts:
**185 supported answers, 158 withheld-valid, 3 syntax refusals, 0 observed
wrong/false yes**. Family mode has 186 supported answers and 157 withheld-valid
because the dog-temperature request correctly routes to pets. The new 143 cases
add 87 supported answers, including branch fields, and 56 withheld-valid cases.
No JavaScript implementation changed; its previous independent engine evidence
remains applicable, and its authored native regression cases passed again.

Actual dispatcher initially passed **344/346** original status assertions. A
new dialogue layer changed two native withheld results to
`clarify`/`missing_reference`: `When was the United Nations headquarters renovated
after it was founded?` and `When was the People's Republic of China first
commemorated after it was founded?`. Runtime's dialogue owner fixed incidental
pronouns by requiring a complete primary-slot follow-up form. A focused actual
dispatcher recheck now returns withheld for both self-contained questions.
All **346/346** composition assertions are therefore cumulatively verified
(344 original passes plus the two focused rechecks), without changing Facts
source or relabeling assertions. Dispatcher capability counts match native:
185 supported answers, 158 withheld-valid, three malformed-syntax refusals,
0 observed wrong/false yes. Original and repair evidence is preserved in
`facts-fourth-{panels,probes,dispatch,family-probes}.json` and
`facts-fourth-dialogue-recheck.json` under `var/c-symbolic-facts-humanities/`.
The core comparison remains the third packet's 28 differences (24 title
renderings, four impossible-date refusals); no new core status/value/rendering
differences appear across each specialist's 924 questions.

Facts files frozen: `ROOT`, `Language_Fields.thy`, `Fact_Projection.thy`,
`Facts_Export.thy`, `language_fields_check.py`, `projection.sml`, `recognizer.sml`,
`main.sml`, `capabilities.json`, `beyond_probes.json`, `README.md`, and this report
section. Remaining: literal quotation/character qualifiers beyond these rows,
source classification controversies, other legal case attributes and unsupported
branches/relations. Additional scope challenges still answer six for an injured
insect's legs and three for an octopus embryo's hearts; these need their own
model-scope review. Source definitions for xylem color, feather use, hyphae count
and mycorrhiza age correctly withhold in the separate observed probes.


## Third Humanities packet: government requested fields (ready)

`How many voting US senators are present today?` used to return the structural
membership count 100. All 13 government fact rows now use complete positive
request forms for structural membership, electoral totals/winning threshold,
source amendment count, standard term length or minimum eligibility age. They
reject attendance, vacancies, quorum, votes on a particular bill, particular
person ages and historical/foreign scope rather than silently discarding those
requested fields. This is an interpretation repair; those meaningful requests
remain withheld-valid, not answered capabilities. Topic/amendment/article
recognition is unchanged and remains a separate interpretation boundary.

No HOL statement changed. The real consumer remains `vreply (VFact hits)` and
its existing first-matching source fact row/value theorem. The recognizer now
constructs that ordered mask from exact requested-field grammars. The proof
receipt `var/humanities/remote-attempts/20261018T065404Z-478dcd4ff9dd/receipt.json`
passed 115 theorem checks with 0 oracles; current proof dependencies match.
Actual native receipt:
`var/humanities/native-attempts/20261018T083507Z-44cac529eda0/compile-inputs.json`.
Binary SHA256 `05c28101c984b5bb6ee3b11db050596db3a333ec5109f2274bd77b838ff3f70b`,
598,280 bytes. Current recognizer SHA256
`3c4016d146c527f5912f0fec3c4423ed95df47b5bf1b4416f1edf0b07ec035e2`.
All seven shipped panels and family mode: **197/197 dev, 197/197 heldout,
0 wrong, 0 false yes, 0 valid omissions**. All **89/89** policy assertions pass
natively, through actual dispatcher and in family mode. Capability counts are
**46 supported answers, 43 withheld-valid, 0 observed wrong/false yes**; the 19
new cases comprise eight supported fields and eleven unsupported meaningful
requests. Evidence: `humanities-government-{panels,probes,dispatch,family-probes}.json`
under `var/c-symbolic-facts-humanities/`. No broad rerun or new proof submission
was needed for this recognizer-only change beyond the existing family panels.

Humanities source frozen: `recognizer.sml`, `capabilities.json`,
`beyond_probes.json`, `README.md`, plus this report section. Facts fourth work
remains independently active. Remaining music ambiguity: a note in a transposing
instrument's score needs instrument/key conventions; current generic MIDI
recognition can still assume direct concert pitch. Independent mythology
killed/father, surname Child plural and book-title ISBN negatives withheld;
reclining-lie past tense correctly returned lay. These observations do not imply
complete review of every Humanities interpretation.
