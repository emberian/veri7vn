# Lane W5-18: summarize, timeline and bridge routes in the document kernel

Kernel: `src/isabelle/document/` (session `Veri7vn_Document`, marker `VERI7VN_DOCUMENT PASS`).
Untrusted fetch and measure: `tools/document/`. Binary: `var/document/bin/document` (not in git).

## What it does now

W5-17 found that the document answerer answered 9 core questions the head withholds. All 9 are
noun phrases ("The currency of India", "The first person in space"). The head sends them to a
capability (a summary or a timeline) and withholds. The fetch modelled none of those captures, so
the turns fell through to the converse organ's statement move, which answered with a page's first
sentence, sometimes from the wrong page.

This lane adds the head's three missing routes, in the head's own order (read from the tip's MRO,
inner to outer: the capabilities, runtime S, runtime AO, w420/w424, w426/w430, the w468 door, the
w494 converse organ):

1. **Summarize (runtime AO, then runtime F).** If nothing answered a bare phrase (letters, spaces,
   hyphens and apostrophes only, at most four words, not "go on" or "thanks"), the head rewrites
   it to "Summarize <phrase>.".
2. **Timeline and explain-simply (runtime S).** When the arbiter bids "timeline" or
   "explain_simply" with a clean margin, the head redispatches "Give me a timeline of <topic>."
   or "Explain <topic> simply.". Before this lane, only the "definitional" bid was modelled.
3. **The bridge (w426, as w430 floors it).** Over a declined turn, the head reads a page the
   question names, finds a sentence that names another proper noun, and reads that noun's page.
   The result is a weak-route sentence.

The fetch runs Oracle7's own code for each of these: AO's regexes, F's `_summarize_turn`, AC's
`_timeline_turn` and `_simply_turn`, d's `_bundle`, M's Wiktionary gloss, and w430's
`_c426_bridge`. It does not write anything.

The kernel gains a turn `Capture capability bool` and a weak route `Bridge`.

- **A captured turn is never answered.** None of the three compositions (the summary paragraph,
  the timeline, the simple register) is ported. The kernel withholds every capture and cites
  nothing.
- **When the capability's own material is missing, the kernel says so in the organ's words.**
  F: "No provenance-admitted material on X is available to summarize." AC: "... to explain."
  J: "A timeline needs at least two dated statements; the admitted material on X contains N."
  The kernel counts N itself, by reading the years off the sentences.
- **Otherwise it says it does not compose one.** The text is "I hold admitted material on X, but
  I do not compose a summary from it yet, so I won't give one."
- **What the kernel reads off the question itself:**
  - Every token of the capture's topic must occur in the question. If one does not, the capture
    does not stand and the turn gets the terminal.
  - AO's summary stands only on a bare phrase.
  - A statement-move or terminal turn on a bare phrase becomes the summary capture, whatever the
    fetch proposed. So the statement move never answers a bare phrase.
- **The bridge's sentence is held to W5-17's weak-route law.** It is asserted only when the
  definition test on the question and the cited sentence releases it. Otherwise it is shown,
  marked as unverified.

## The numbers

Ground truth: `upstream/workbench/data/core_panel.json` (924 items, recorded status and path, head
w538). The head was not run.

**All 924 core questions (the answerer pointed at the whole panel):**

| | Before (W5-17) | Now |
|---|---|---|
| answered, outside the 231 | 21 | **0** |
| of them where the head withheld or clarified | **9** (#61 #63 #213 #218 #511 #513 #661 #663 #811) | **0** |

The other 12 answers outside the 231 were items the head answered too. All but #815 were the
statement move on turns where the head took the bridge (11 items) or explain-simply (#815). The
kernel now withholds them; see "stricter" below.

**The 231 document-route items:**

| | W5-17 | Now |
|---|---|---|
| status | 224 | **225** |
| path | 190 | **190** |
| path exact | 190 | **190** |
| both | 190 | **190** |

The one change is #588, "How much will my flat be worth in 2060?". The head's arbiter captures it
as explain-simply, the capability answers, and w420's factoid route then withholds over an
uncovered reply (`factoid:withheld`). Before, the kernel clarified. Now it withholds on the
explain-simply capture, so status matches. The path still misses: w420's withhold receipt is not
modelled. The text on the 30 recorded head replies is unchanged: 23 exact, 7 equal to the head's
first line.

**The 26 wider-prefix items:** status 23 of 26 (was 3), path 26 of 26 (was 0), path exact 24 of
26. "Path" removes the later folds' decorations, as W5-17 defined it.

| # | Question | Head status / path | Kernel status / path | Match |
|---|---|---|---|---|
| 61 | The currency of Switzerland | withheld `capability:summarize\|vessel:receipt` | withheld `capability:summarize` | S P |
| 63 | The first man to walk on the Moon | withheld `arb:timeline->capability:timeline\|vessel:receipt` | withheld `arb:timeline->capability:timeline` | S P |
| 125 | Who won the 2030 FIFA World Cup? | withheld `unverified:compose:bridge` | withheld `unverified:compose:bridge` | S P |
| 213 | The first woman to win a Nobel Prize | withheld `arb:timeline->capability:timeline\|vessel:receipt` | withheld `arb:timeline->capability:timeline` | S P |
| 214 | Name the planet that the moon Callisto orbits | withheld `unverified:compose:bridge` | withheld `unverified:compose:bridge` | S P |
| 218 | The inventor of dynamite | withheld `capability:summarize\|vessel:receipt` | withheld `capability:summarize` | S P |
| 363 | The first person to reach the South Pole | **answered** `arb:timeline->capability:timeline` | withheld `arb:timeline->capability:timeline` | P (status: answered timeline, not ported) |
| 436 | What is my social security number? | withheld `precision_guard:G2_private_state\|arb:explain_simply->capability:explain_simply` | withheld `arb:explain_simply->capability:explain_simply` | S P (exact: guard not modelled) |
| 511 | The currency of Mexico | withheld `capability:summarize\|vessel:receipt` | withheld `capability:summarize` | S P |
| 512 | Name the composer of Boléro | withheld `unverified:compose:bridge` | withheld `unverified:compose:bridge` | S P |
| 513 | The first person in space | withheld `arb:timeline->capability:timeline\|vessel:receipt` | withheld `arb:timeline->capability:timeline` | S P |
| 572 | Who was the first emperor of Canada? | withheld `arb:timeline->capability:timeline\|vessel:receipt` | withheld `arb:timeline->capability:timeline` | S P |
| 658 | Which company developed the video game Portal? | withheld `unverified:compose:bridge` | withheld `unverified:compose:bridge` | S P |
| 661 | The currency of India | withheld `capability:summarize\|vessel:receipt` | withheld `capability:summarize` | S P |
| 663 | The first person to fly solo across the Atlantic | withheld `arb:timeline->capability:timeline\|vessel:receipt` | withheld `arb:timeline->capability:timeline` | S P |
| 664 | Name the planet that the moon Nereid orbits | withheld `unverified:compose:bridge` | withheld `unverified:compose:bridge` | S P |
| 669 | Name the author of The Waste Land | withheld `precision_guard:R2_dump_for_slot_question\|arb:explain_simply->capability:explain_simply` | withheld `arb:explain_simply->capability:explain_simply` | S P (exact: guard not modelled) |
| 722 | Who was the first king of Switzerland? | withheld `arb:timeline->capability:timeline\|vessel:receipt` | withheld `arb:timeline->capability:timeline` | S P |
| 723 | What is my cousin's date of birth? | withheld `arb:timeline->capability:timeline\|vessel:receipt` | withheld `arb:timeline->capability:timeline` | S P |
| 784 | Which country is the city of Debrecen in? | withheld `unverified:compose:bridge` | withheld `unverified:compose:bridge` | S P |
| 808 | Which company developed the video game Doom? | withheld `unverified:compose:bridge` | withheld `unverified:compose:bridge` | S P |
| 811 | The currency of Austria | withheld `capability:summarize\|vessel:receipt` | withheld `capability:summarize` | S P |
| 813 | The first person to climb Mount Everest with Tenzing Norgay | **answered** `arb:timeline->capability:timeline` | withheld `arb:timeline->capability:timeline` | P (status: answered timeline, not ported) |
| 815 | The director of the film Rome, Open City | **answered** `arb:explain_simply->capability:explain_simply` | withheld `arb:explain_simply->capability:explain_simply` | P (status: answered explain-simply, not ported) |
| 872 | Who was the first emperor of Argentina? | withheld `arb:timeline->capability:timeline\|vessel:receipt` | withheld `arb:timeline->capability:timeline` | S P |
| 875 | Who won the 2050 FIFA World Cup? | withheld `unverified:compose:bridge` | withheld `unverified:compose:bridge` | S P |

Named misses:
- **Answered capability (3 status misses: #363, #813, #815).** The head composed a timeline or a
  simple explanation and answered. Composing these is out of scope by the brief. The kernel
  withholds and says it does not compose one. The fetch still keeps the head's order: the organ
  answered there, so the bridge is not tried over it.
- **Guard (2 exact-path misses: #436 G2, #669 R2).** These are precision-guard folds the kernel
  does not model (W5-15's work). Status and the route under the guard match.

**Stricter outside the 26 (11 items, not counted in any gate):** #60 #65 #70 #210 #215 #361 #365
#510 #515 #518 #810 ("Tell me the capital of Norway", "The director of the film Jaws", "The
currency of Sweden"). The head answered these with `compose:bridge`. Its verifier (w515's
verified reach, widened by w517) only checks turns it calls factual, and these are not
questions. So it asserted the bridge sentence unchecked. The kernel applies the weak-route law to
every turn and shows the passage unverified. Before this lane the binary "answered" them through
the statement move, a route the head never takes on them.

Latency inside the measure (fetch + kernel + presentation), all 924: p50 3.8 ms, max 14.1 s. The
bridge is w426/w430's own page search under w420's 4 s budget; on eight timed bridge turns it took
2.0 to 6.5 s here. Binary 368,392 bytes. Cold start about 10 ms, self test included.

## Theorems

New and changed statements, verbatim from `src/isabelle/document/Document_Route.thy`. The other
W5-17 theorems are unchanged.

The decision now reroutes before the route:

```
definition reroute :: "turn ⇒ evidence ⇒ turn" where
  "reroute t ev = (if (t = Statement ∨ t = Fallback) ∧ bare_phrase (asked ev) then Capture Summarize False else t)"

definition decide :: "turn ⇒ evidence ⇒ outcome" where
  "decide t ev = (case compute_op (asked ev) of
       Some op ⇒ Refused (OutOfFragment op)
     | None ⇒ if lookup_refused ev then Refused LookupForCompute else door ev (route (reroute t ev) ev))"

| "route (Capture k a) ev = (if capture_named k a ev then NotComposed k a else Clarify)"

definition capture_named :: "capability ⇒ bool ⇒ evidence ⇒ bool" where
  "capture_named k a ev ⟷ topic_named ev ∧ (k = Summarize ∧ ¬ a ⟶ bare_phrase (asked ev))"

definition topic_named :: "evidence ⇒ bool" where
  "topic_named ev ⟷ ssplit [] (topic ev) ≠ []
     ∧ list_all (λw. occurs (lowercase w) (lowercase (asked ev))) (ssplit [] (topic ev))"

definition bare_phrase :: "string ⇒ bool" where
  "bare_phrase q ⟷ bare_shape q ∧ wcount False q ≤ 4 ∧ lowercase q ∉ set continuations"

definition dated :: "evidence ⇒ claim list" where
  "dated ev = filter (λc. year_scan True (sentence c)) (claims (pool_e ev))"
```

`bare_shape` is AO's `BARE` ported character by character. `wcount` counts the maximal runs of
non-space characters. `continuations` lists AO's 17 `CONTINUATION` phrases. `year_scan` is J's
`\b(1[0-9]{3}|20[0-2][0-9])\b`. `capture_path k a` is `capability:<family>`, prefixed by
`arb:<family>->` when the arbiter captured the turn.

```
theorem capture_iff:
  "decide (Capture k a) ev = NotComposed k' a' ⟷
     compute_op (asked ev) = None ∧ ¬ lookup_refused ev ∧ capture_named k a ev ∧ k' = k ∧ a' = a"

theorem capture_never_reaches_statement:
  shows "reroute (Capture k a) ev = Capture k a"
    and "decide (Capture k a) ev ≠ Answer c e"
    and "cited_claims (decide (Capture k a) ev) = []"
    and "decide (Capture k a) ev = NotComposed k a ∨ decide (Capture k a) ev = Clarify
         ∨ (∃p. decide (Capture k a) ev = AskWhich p) ∨ (∃g. decide (Capture k a) ev = Refused g)"

theorem bare_phrase_never_reaches_statement:
  assumes "bare_phrase (asked ev)"
  shows "decide Statement ev = decide (Capture Summarize False) ev"
    and "decide Fallback ev = decide (Capture Summarize False) ev"
    and "decide Statement ev ≠ Answer c e"

theorem capture_names_the_question:
  assumes "decide (Capture k a) ev = NotComposed k a"
  shows "ssplit [] (topic ev) ≠ []
      ∧ (∀w∈set (ssplit [] (topic ev)). ∃pre suf. lowercase (asked ev) = pre @ suf ∧ starts (lowercase w) suf)"
    and "k = Summarize ∧ ¬ a ⟹ bare_phrase (asked ev)"
    and "∃pre suf. response_of t ev (decide (Capture k a) ev) = pre @ topic ev @ suf"
    and "status_of (decide (Capture k a) ev) = STR ''withheld''"
    and "path_of t ev (decide (Capture k a) ev) = capture_path k a"
    and "cited_claims (decide (Capture k a) ev) = []"

theorem timeline_count_read_off_the_text:
  assumes "decide (Capture Timeline a) ev = NotComposed Timeline a" and "length (dated ev) < 2"
  shows "response_of t ev (decide (Capture Timeline a) ev) =
      timeline_lead @ topic ev @ '' contains '' @ (if dated ev = [] then ''0'' else ''1'') @ ''.''"
    and "∀c∈set (dated ev). ∃pre y suf. sentence c = pre @ y @ suf ∧ is_year4 y"
    and "∀c∈set (claims (pool_e ev)). c ∉ set (dated ev) ⟶ ¬ year_scan True (sentence c)"

lemma year_scan_sound: "year_scan b s ⟹ ∃pre y suf. s = pre @ y @ suf ∧ is_year4 y"

lemma route_reroute_answer: "route (reroute t ev) ev = Answer c e ⟹ reroute t ev = t"
```

Changed W5-17 statements. `answer_comes_from_route` keeps its statement; its proof now goes
through `route_reroute_answer`.

```
theorem statement_answer_iff:
  "decide Statement ev = Answer c e ⟷
     compute_op (asked ev) = None ∧ ¬ lookup_refused ev ∧ ¬ bare_phrase (asked ev) ∧ e = None
     ∧ candidate ev = Some c ∧ anchor_present (pool_e ev) ∧ names_term ev c ∧ ¬ disambiguation c"

theorem door_asks_only_what_was_said:
  assumes "decide t ev = AskWhich p"
  shows "route (reroute t ev) ev = Clarify ∧ pointer ev = Some p ∧ p ≠ []
    ∧ (∃pre suf. asked ev = pre @ suf ∧ starts p suf)"
```

The bridge is `Weak Bridge`. W5-17's weak-route theorems are stated for every weak route `r`,
so they cover it with no new statement. In particular `weak_answer_quotes_the_term` with
`r = Bridge`: a bridge sentence is asserted only when the question is a what-is question and
every content word of the asked term opens a word in the question and in the cited sentence's
first 200 characters. `unverified_reply_shape` says the withheld reply quotes that sentence and
cites nothing.

What the theorems bind to the text, and what they take on trust:
- **Read off the text by the kernel:**
  - the bare-phrase shape of the question;
  - that every token of the capture's topic occurs in the question;
  - that the reply quotes the topic;
  - the count of dated sentences, read off the material's sentences.
- **Taken from the fetch, untrusted:**
  - the arbiter's family;
  - that the topic is an anchor title;
  - the capability's material itself (the gate's admissions, the Wiktionary gloss);
  - the bridge's sentence.

`capture_never_reaches_statement` holds whatever the fetch says, because it is about the turn
class. `bare_phrase_never_reaches_statement` holds whatever turn the fetch proposed, because the
kernel reads the bare phrase from the question.

## Receipt

```
tools/dev/remote-build hbox src/isabelle/document Veri7vn_Document --expect 'VERI7VN_DOCUMENT PASS'
  -> build 1: FAILED. Errors, read from that run's log before build 2 overwrote it: an underscore-leading
     name in a @{text} antiquotation, and `k` used at two types in reroute_simps. No proof failed.
     (The first invocation stopped before reaching the host, after printing a local `ar` usage message;
     var/document/rb18-1-hbox.log is the stale W5-17 log it left. Rerun under `sh -x`, the script ran
     normally. The cause was not found.)
tools/dev/remote-build persvati src/isabelle/document Veri7vn_Document --expect 'VERI7VN_DOCUMENT PASS'
  -> rc 0, var/document/rb18-2-persvati.log
     line 31:   Finished Veri7vn_Document (0:00:19 elapsed time, 0:00:25 cpu time, factor 1.35)
     line 1513: VERI7VN_DOCUMENT PASS theorems=62 oracles=0
     line 1548: self test parts 1..11 all true
     line 1551: REMOTE_MARKER_FOUND: VERI7VN_DOCUMENT PASS
```

The marker and its oracle scan are still the last commands of `Document_Route_Export.thy`. The
session's theories are ordered Route, Test, Export. No theorem uses `eval`. The new self-test
part st11 is computed by the build and again by the binary at start-up. It checks:
- the bare-phrase reading on nine surfaces (four core questions among them);
- F's and J's withheld texts;
- the topic check;
- that a statement turn and a terminal turn on a bare phrase both become the summary capture;
- the bridge's unverified path.

The export's SHA-256 begins `d5ae1f2a6f0a6410`; the binary's begins `c4c702cfea88b25a`.

`find upstream -newer var/document/.t0` after all runs (probes, dry runs, two measures) listed
nothing. The arbiter's ConceptNet connection, which arbiter v3 opens with `mode=ro` only, is now
opened by the fetch with `immutable=1` and handed to it first. The Wiktionary build is opened the
same way.

## Untrusted parts

- `tools/document/fetch.py` (docstring items 1 to 8):
  - the cascade order;
  - the arbiter's verdict and the anchor topic;
  - the capability organs run on an AC-class object with injected stores;
  - `w420_over`, w420's chat over a parent reply, copied from source;
  - the bridge's gates.
- `tools/document/document_main.sml`.
- `tools/document/measure.py`.
- `tools/document/answerer.py`.

## Remaining

- **Composing the captured capabilities.** The summary paragraph (F, paragraph compiler v2), the
  timeline (J and AC's distinct-year rule) and the simple register (AC). Until then #363, #813
  and #815 miss status by design.
- **The precision guards** in front of the route (W5-15): the 31 guard items in the 231, plus
  #436 and #669.
- **w420's `factoid:withheld` receipt** over an uncovered capability answer (#588's path).
- **The bridge depends on time.** The fetch's bridge is the organ's own search under a 4 s
  budget, so on a slower machine it can find less. The head's recorded paths agreed with this
  machine on all 26, and the 231 did not move.
- **Two fetch paths still use W5-17's object.** The factoid try over the terminal is still w420's
  own `_f420_try`. The tip's is w424's, which only the new capture paths use. Switching the
  terminal path to w424's may move W5-17's numbers; it was not tried here.
- **AO's `BARE` under `re.I`.** In Python it also matches four non-ASCII letters (U+0130,
  U+0131, U+017F, U+212A). The kernel's port does not, so on those it is stricter.
- **Not ported in the bridge.** The comparison and both-form compose rules (`compose:comparison`,
  `compose:both`) and w426's derived-fact store. Turns of those shapes get no bridge here.

No specialist panel numbers: this lane measures the document route against the core panel's
recorded status and path, and the route is not a shipped specialist.

## Reproduce

```
tools/dev/remote-build persvati src/isabelle/document Veri7vn_Document --expect 'VERI7VN_DOCUMENT PASS'
sh tools/document/build.sh
PYTHONDONTWRITEBYTECODE=1 PYTHONHASHSEED=0 .venv/bin/python tools/document/measure.py --all --out var/document/measure924.json
```
