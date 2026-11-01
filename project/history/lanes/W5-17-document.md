# Lane W5-17: the document route on all 231 core items

Kernel: `src/isabelle/document/` (session `Veri7vn_Document`, marker `VERI7VN_DOCUMENT PASS`).
Untrusted fetch and measure: `tools/document/`. Binary: `var/document/bin/document` (not in git).

## What it does now

The document kernel decides how Oracle7's document route replies (answer, show a passage
without asserting it, decline, refuse, or ask back) from evidence an untrusted fetch builds
with Oracle7's own code. This lane measured it against the recorded core panel on every one of
the 231 core items on the route's paths, not the scout's 30, and changed four things:

1. **A computation gateway.** A question that names an arithmetic operation and carries the
   numbers to apply it to ("What is 9 cubed?", "12 factorial divided by 10 factorial") is
   refused with the maths fold's own text, "That asks me to work out the cubed, and I compute
   exactly or not at all. ...", instead of the clarify terminal ("I didn't fully parse that").
   The kernel reads the operation and the numerals off the question itself (w458's rule, ported
   to HOL string functions), so no fetch flag can route a computation around it. A lookup that
   would answer a question giving numbers and asking for one ("What is 15 pounds in
   kilograms?") gets the precision guard's P4 refusal, "I can't verify an answer to that exact
   question, so I won't guess."; here the fetch supplies the shape and the kernel checks the
   question carries a numeral.
2. **The always-False `checked` flag is gone.** The cube CHECK it stood for is not ported, so it
   was removed rather than kept as a flag. With it went `subject_defines`, `covered` and
   `disambiguates`, three more flags the fetch set. A weak-route sentence is now asserted only
   by the definition test of `verified_reach_v1.defines_asked`, which the kernel reads off the
   texts: every content word of the asked term must open a word in the question and in the
   first 200 characters of the cited sentence. The statement move uses the same test on its
   topic, and the kernel itself looks for "may refer to" in the sentence.
3. **The door (w468).** A clarify on a turn that points ("Name the planet that the moon Europa
   orbits") asks what the phrase refers to ("What does "that" refer to? ..."), path
   `act:clarify_specific`. The kernel checks that the phrase occurs in the question.
4. **The arbiter capture (runtime S).** The fetch now reproduces runtime S's capture: arbiter
   v3, family "definitional", canonical surface "What is a <topic>?" over the bench anchor
   store, read with the head's own `_definitional_turn` (runtime c widened by w193), and runtime
   z's substitution disclosure. This is what gives the computation items the head's path
   (`arb:definitional->definitional_encyclopedic` or `->document_runtime`).

All reply texts are now HOL strings of 8-bit characters, so the sentence the kernel checks is
the bytes it quotes; the SML driver converts byte for byte.

## The numbers

Ground truth: `upstream/workbench/data/core_panel.json` (924 items, recorded status and path,
head w538). The head was not run. Item set derived with `tools/parity/routes.py`'s `parts`: an
item counts when its route, or for a precision guard the route the guard stood in front of,
starts with `act:clarify`, `arb:definitional`, `corpus_query:property_of`,
`unverified:factoid:`, `unverified:corpus_query:`, `factoid:`, `organ:converse` or
`verified:weak`. That gives exactly the triage's 231 (104 act:clarify, 41 arb:definitional, 26
corpus_query, 25 unverified:factoid, 20 factoid, 10 converse, 4 unverified:corpus, 1
verified:weak).

"Path" removes the later folds' decorations as the scout did (a leading
`precision_guard:<code>|`, `|vessel:receipt`, `|substitution_disclosed`,
`|math:out_of_fragment`). "Path exact" removes only `|vessel:receipt` (the receipt paragraph
carries a per-session counter; the kernel prints no receipt and claims none).

| Set | Items | Status match | Path match | Path exact | Both |
|---|---|---|---|---|---|
| all 231 | 231 | **224** | **190** | **190** | 190 |
| scout's 30 (before: 27 / 25) | 30 | **30** | **30** | 30 | 30 |

Text, on the 30 items with a recorded head reply (the scout's one head run, tip w540): 23 exact,
7 equal to the head's first line (the head appends a receipt paragraph), 0 different (before:
18 exact, 7 first line, 5 different).

By recorded route:

| Recorded route | Items | Status | Path |
|---|---|---|---|
| `act:clarify` | 94 | 94 | 94 |
| `unverified:factoid:*` | 25 | 25 | 25 |
| `corpus_query:property_of` | 23 | 23 | 23 |
| `precision_guard:*\|arb:definitional` | 22 | 19 | 4 |
| `arb:definitional` | 19 | 18 | 18 |
| `precision_guard:*\|factoid:*` | 17 | 17 | 0 |
| `act:clarify_specific` | 10 | 10 | 10 |
| `organ:converse` | 10 | 10 | 10 |
| `unverified:corpus_query:property_of` | 4 | 4 | 4 |
| `precision_guard:*\|corpus_query` | 3 | 3 | 2 |
| `factoid:*` (answered or withheld) | 3 | 0 | 0 |
| `precision_guard:S1\|verified:weak` | 1 | 1 | 0 |

The scout's four arithmetic items, status and path against the recorded panel:

| # | Question | Kernel status, path | Recorded |
|---|---|---|---|
| 75 | What is 2 to the power 12? | withheld `arb:definitional->definitional_encyclopedic\|substitution_disclosed\|math:out_of_fragment\|vessel:receipt` | same |
| 80 | What is 15 pounds in kilograms? | withheld `precision_guard:P4_lookup_for_compute\|arb:definitional->definitional_encyclopedic\|substitution_disclosed` | same |
| 92 | What is 12 factorial divided by 10 factorial? | withheld `arb:definitional->document_runtime\|substitution_disclosed\|math:out_of_fragment\|vessel:receipt` | same |
| 99 | What is 9 cubed? | withheld `arb:definitional->document_runtime\|substitution_disclosed\|math:out_of_fragment\|vessel:receipt` | same |

All four reply texts equal the head's recorded text exactly; so does #83's P4 text. All 18
unguarded arithmetic `arb:definitional` items match status and exact path, and so do four of
the six "pounds in kilograms" items.

Latency inside the measure (fetch + kernel + presentation): p50 2.8 ms, max 81 ms. Binary
317,192 bytes; cold start about 10 ms (self-test included).

### Every miss, by class (41 items; 7 of them also miss status)

- **guard, 31**: a precision-guard fold the kernel does not model (G2 private state, P7
  private or negative given, Q3/R5 subject missing, P1 declines in words, P2 no number, S1
  person not human). W5-15's work. Status matches on 30 of the 31: the kernel withholds too,
  as an unverified passage or a corpus decline. On 21 of them the route under the guard is
  the head's; on 10 it differs (6 corpus decline where the head guarded a `factoid:page`; 2
  `arb:definitional` where the head guarded a `factoid:page`; 1 `factoid:fts` where the head
  went through `verified:weak`; #587 a clarify where the head guarded an answered
  `arb:...->document_runtime`, the one status miss).
- **p4, 6**: #383, #533, #683, #833 (cube volume with side 7/9/11/13): the head guarded a
  `factoid:page` reached after the corpus rule declined. The kernel keeps the corpus decline,
  so status matches and path does not. w420 fires over a parent decline, but the head keeps
  the corpus decline on the 21 other core items where the corpus rule declines ("What is the
  population of Atlantis?"). I did not find the fold that makes the difference, so I did not
  guess at one. #680 and #830 ("64 / 88 pounds in kilograms"): the anchor store names no topic,
  so the capture does not happen and the turn clarifies. The head reached
  `definitional_encyclopedic|wide_lead` by some other path (status miss).
- **stricter, 3**: the head asserted a weak-route sentence that nothing checked, and the kernel
  withholds it as unverified: #201 "Who was the mother of Queen Elizabeth I?" (`factoid:page`,
  answered), #893 "What vegetable am I thinking of?" (`factoid:page`, answered), #887 "What is
  the password for my laptop?" (the recorded path is the definitional lead of "laptop" with
  the substitution disclosed). Status misses by design.
- **route, 1**: #588 "How much will my flat be worth in 2060?": the head's
  `factoid:withheld` (w420 withholding over an uncovered capability answer). Not modelled; the
  kernel clarifies (status miss).

| # | Question | Recorded status / path | Kernel status / path | Class |
|---|---|---|---|---|
| 129 | A car travels -60 km in 2 hours. What is its average speed? | withheld `precision_guard:P7_negative_given|arb:definitional->definitional_encyclopedic` | withheld `unverified:arb:definitional` | guard |
| 134 | In what year did Albert Einstein win the Nobel Prize in Literature? | withheld `precision_guard:R5_subject_missing|factoid:page` | withheld `unverified:factoid:page` | guard |
| 136 | What is my bank account balance? | withheld `precision_guard:G2_private_state|factoid:page` | withheld `unverified:factoid:page` | guard |
| 137 | What is the password to my email? | withheld `precision_guard:G2_private_state|arb:definitional->definitional_encyclopedic|substitution_disclosed` | withheld `unverified:arb:definitional` | guard |
| 140 | What is the boiling point of nothingness? | withheld `precision_guard:Q3_subject_missing|factoid:page` | withheld `corpus_query:property_of` | guard |
| 143 | What number am I thinking of? | withheld `precision_guard:G2_private_state|factoid:page` | withheld `unverified:factoid:page` | guard |
| 273 | What is my sister's phone number? | withheld `precision_guard:P7_private|arb:definitional->definitional_encyclopedic|substitution_disclosed` | withheld `unverified:arb:definitional` | guard |
| 279 | A train travels -120 km in 1.5 hours. What is its average speed? | withheld `precision_guard:P7_negative_given|arb:definitional->definitional_encyclopedic` | withheld `unverified:arb:definitional` | guard |
| 286 | What is my credit card PIN? | withheld `precision_guard:G2_private_state|arb:definitional->definitional_encyclopedic|substitution_disclosed` | withheld `unverified:arb:definitional` | guard |
| 287 | What is the password to my phone? | withheld `precision_guard:G2_private_state|arb:definitional->definitional_encyclopedic|substitution_disclosed` | withheld `unverified:arb:definitional` | guard |
| 290 | What is the melting point of silence? | withheld `precision_guard:Q3_subject_missing|factoid:page` | withheld `corpus_query:property_of` | guard |
| 422 | Who was the first king of the United States? | withheld `precision_guard:S1_person_not_human|verified:weak>PERSON|factoid:fts` | withheld `unverified:factoid:fts` | guard |
| 423 | What is my boss's home address? | withheld `precision_guard:P7_private|factoid:page` | withheld `unverified:factoid:page` | guard |
| 427 | What did I dream about last night? | withheld `precision_guard:G2_private_state|factoid:page` | withheld `unverified:factoid:page` | guard |
| 429 | A cyclist rides -45 km in 3 hours. What is her average speed? | withheld `precision_guard:P7_negative_given|arb:definitional->definitional_encyclopedic` | withheld `unverified:arb:definitional` | guard |
| 432 | What is the cube root of jealousy? | withheld `precision_guard:P2_no_number|factoid:page` | withheld `corpus_query:property_of` | guard |
| 437 | What is the code to my front door? | withheld `precision_guard:G2_private_state|arb:definitional->definitional_encyclopedic|substitution_disclosed` | withheld `unverified:arb:definitional` | guard |
| 573 | What is my neighbour's email address? | withheld `precision_guard:P7_private|factoid:page` | withheld `unverified:arb:definitional` | guard |
| 579 | A runner covers -10 km in 50 minutes. What is her average speed? | withheld `precision_guard:P7_negative_given|arb:definitional->definitional_encyclopedic` | withheld `unverified:arb:definitional` | guard |
| 582 | What is the square root of happiness? | withheld `precision_guard:Q3_subject_missing|factoid:page` | withheld `corpus_query:property_of` | guard |
| 586 | What is my passport number? | withheld `precision_guard:P1_declines_in_words|arb:definitional->definitional_encyclopedic|substitution_disclosed` | withheld `unverified:arb:definitional` | guard |
| 587 | What is the PIN for my debit card? | withheld `precision_guard:G2_private_state|arb:definitional->document_runtime|substitution_disclosed` | clarification `act:clarify` | guard (status) |
| 729 | A boat sails -30 km in 2 hours. What is its average speed? | withheld `precision_guard:P7_negative_given|arb:definitional->definitional_encyclopedic` | withheld `unverified:arb:definitional` | guard |
| 732 | What is the cube root of loneliness? | withheld `precision_guard:P2_no_number|factoid:page` | withheld `corpus_query:property_of` | guard |
| 736 | What is my national insurance number? | withheld `precision_guard:P1_declines_in_words|arb:definitional->definitional_encyclopedic|substitution_disclosed` | withheld `unverified:arb:definitional` | guard |
| 737 | What is the alarm code for my house? | withheld `precision_guard:G2_private_state|arb:definitional->definitional_encyclopedic|substitution_disclosed` | withheld `unverified:arb:definitional` | guard |
| 873 | What is my uncle's favourite food? | withheld `precision_guard:G2_private_state|factoid:page` | withheld `unverified:arb:definitional` | guard |
| 879 | A swimmer covers -2 km in 40 minutes. What is her average speed? | withheld `precision_guard:P7_negative_given|arb:definitional->definitional_encyclopedic` | withheld `unverified:arb:definitional` | guard |
| 882 | What is the square root of curiosity? | withheld `precision_guard:Q3_subject_missing|factoid:page` | withheld `corpus_query:property_of` | guard |
| 886 | What is my bank sort code? | withheld `precision_guard:G2_private_state|arb:definitional->definitional_encyclopedic|substitution_disclosed` | withheld `unverified:arb:definitional` | guard |
| 891 | What is the capital city of the Mediterranean Sea? | withheld `precision_guard:P1_declines_in_words|corpus_query:property_of|substitution_disclosed` | withheld `unverified:corpus_query:property_of` | guard |
| 383 | What is the volume of a cube with side 7 cm? | withheld `precision_guard:P4_lookup_for_compute|factoid:page` | withheld `corpus_query:property_of` | p4 |
| 533 | What is the volume of a cube with side 9 cm? | withheld `precision_guard:P4_lookup_for_compute|factoid:page` | withheld `corpus_query:property_of` | p4 |
| 680 | What is 64 pounds in kilograms? | withheld `precision_guard:P4_lookup_for_compute|arb:definitional->definitional_encyclopedic|wide_lead|substitution_disclosed` | clarification `act:clarify` | p4 (status) |
| 683 | What is the volume of a cube with side 11 cm? | withheld `precision_guard:P4_lookup_for_compute|factoid:page` | withheld `corpus_query:property_of` | p4 |
| 830 | What is 88 pounds in kilograms? | withheld `precision_guard:P4_lookup_for_compute|arb:definitional->definitional_encyclopedic|wide_lead|substitution_disclosed` | clarification `act:clarify` | p4 (status) |
| 833 | What is the volume of a cube with side 13 cm? | withheld `precision_guard:P4_lookup_for_compute|factoid:page` | withheld `corpus_query:property_of` | p4 |
| 201 | Who was the mother of Queen Elizabeth I? | answered `factoid:page` | withheld `unverified:factoid:page` | stricter (status) |
| 887 | What is the password for my laptop? | answered `arb:definitional->definitional_encyclopedic|substitution_disclosed` | withheld `unverified:arb:definitional` | stricter (status) |
| 893 | What vegetable am I thinking of? | answered `factoid:page` | withheld `unverified:factoid:page` | stricter (status) |
| 588 | How much will my flat be worth in 2060? | withheld `factoid:withheld|vessel:receipt` | clarification `act:clarify` | route:missed (status) |

### The brief's wider prefix list (26 more items, not in the 231)

`arb:timeline` (10), `unverified:compose:bridge` (8), `capability:summarize` (5),
`arb:explain_simply` (3, 2 of them guarded): status 3 of 26, path 0. None of these routes is
modelled (no capability or bridge evidence in the fetch). One finding matters: on **9 of them
the binary answers where the head withheld**. These are the converse statement move on noun
phrases the head sends to summarize or timeline ("The currency of Switzerland" → the
Switzerland page's first sentence; "The first person in space" → "The SPACE-π program is ...";
"The currency of India" → "India? is the third studio album ..."). Each passes the kernel's
statement law (the topic word is in the question and opens the sentence), and the text is the head's own
converse organ's, but the head never reaches that organ on these turns. Until the
fetch models the summarize and timeline captures, the answerer must not be pointed at
noun-phrase turns outside the 231.

## Theorems (31 named; the marker counts 43 because `@{thms}` flattens conjunctions)

Statements as written in `src/isabelle/document/Document_Route.thy`. `route` is the old
`decide` (the route's own decision); `decide` is now the gateway, then the route, then the door:

```
definition decide :: "turn ⇒ evidence ⇒ outcome" where
  "decide t ev = (case compute_op (asked ev) of
       Some op ⇒ Refused (OutOfFragment op)
     | None ⇒ if lookup_refused ev then Refused LookupForCompute else door ev (route t ev))"
```

`compute_op q` lower-cases the question, finds the leftmost of w458's 25 operation phrases at
word boundaries (or a per-cent sign, named "percentage"), and returns it only when the question
has two numerals, or a per-cent sign, or one numeral and a unary operation. `released ev c` is
`def_question ev ∧ names_term ev c`. `names_term ev c` says the asked term has content words
(`words_of`: runs of ASCII letters and digits, at least 3 long, cut to 6) and each one opens a
word (`word_in`) both in the lower-cased question and in the first 200 characters of the
lower-cased sentence.

```
theorem no_answer_unanchored:
  "¬ anchor_present (pool_e ev) ⟹ route (Explain k) ev ≠ Answer c e"

theorem statement_never_unanchored:
  "¬ anchor_present (pool_e ev) ⟹ route Statement ev ≠ Answer c e"

theorem explain_answer_witnessed:
  assumes "route (Explain k) ev = Answer c e"
  shows "anchor_present (pool_e ev)" and "c ∈ set (admitted (pool_e ev))"
    and "e = None ∨ the e ∈ set (admitted (pool_e ev))"
    and "c ∈ set (usable (admitted (pool_e ev)))"
    and "e = None ∨ the e ∈ set (usable (admitted (pool_e ev)))"

theorem explain_tier_precedence:
  assumes "route (Explain k) ev = Answer c e"
  shows "∃pre t suf. tiers ev = pre @ t # suf
    ∧ (∀t'∈set pre. tier_hits t' (need_year k) (usable (admitted (pool_e ev))) = [])
    ∧ c ∈ set (tier_hits t (need_year k) (usable (admitted (pool_e ev))))"

theorem explain_needs_the_cue:
  assumes "route (Explain k) ev = Answer c e"
  shows "∃t. tier c = Some t" and "need_year k ⟹ has_year c"
  and "need_year k ⟹ e = None ∨ has_year (the e)"

theorem explain_not_fragment_when_whole_exists:
  assumes "route (Explain k) ev = Answer c e"
    and "∃d∈set (admitted (pool_e ev)). ¬ fragment d"
  shows "¬ fragment c" and "e = None ∨ ¬ fragment (the e)"

theorem explain_no_anchor_iff:
  "route (Explain k) ev = Declined NoAnchor ⟷ ¬ anchor_present (pool_e ev)"

theorem explain_no_statement_iff:
  "route (Explain k) ev = Declined NoAdmittedStatement ⟷
    anchor_present (pool_e ev) ∧ first_tier (tiers ev) (need_year k) (usable (admitted (pool_e ev))) = []"

theorem compute_gateway:
  "compute_op (asked ev) = Some op ⟹ decide t ev = Refused (OutOfFragment op)"

theorem compute_gateway_iff:
  "decide t ev = Refused (OutOfFragment op) ⟷ compute_op (asked ev) = Some op"

theorem refusal_reads_the_question:
  assumes "decide t ev = Refused (OutOfFragment op)"
  shows "((op = ''percentage'' ∧ CHR ''%'' ∈ set (lowercase (asked ev)))
           ∨ (op ∈ set operations ∧ (∃pre suf. lowercase (asked ev) = pre @ suf ∧ starts op suf)))
         ∧ (1 ≤ numerals NFree (lowercase (asked ev)) ∨ CHR ''%'' ∈ set (lowercase (asked ev)))"

theorem lookup_refusal_iff:
  "decide t ev = Refused LookupForCompute ⟷
     compute_op (asked ev) = None ∧ lookup_for_compute ev ∧ 0 < numerals NFree (lowercase (asked ev))"

theorem answer_comes_from_route:
  "decide t ev = Answer c e ⟹
     compute_op (asked ev) = None ∧ ¬ lookup_refused ev ∧ route t ev = Answer c e"

theorem no_answer_to_a_computation:
  "compute_op (asked ev) ≠ None ⟹ decide t ev ≠ Answer c e"

theorem weak_answer_iff:
  "decide (Weak r) ev = Answer c e ⟷
     compute_op (asked ev) = None ∧ ¬ lookup_refused ev ∧ e = None
     ∧ candidate ev = Some c ∧ released ev c"

theorem weak_answer_quotes_the_term:
  assumes "decide (Weak r) ev = Answer c e"
  shows "def_question ev ∧ words_of (asked_term ev) ≠ []
    ∧ (∀w∈set (words_of (asked_term ev)).
         (∃pre suf. lowercase (asked ev) = pre @ suf ∧ starts w suf)
       ∧ (∃pre suf. lowercase (take 200 (sentence c)) = pre @ suf ∧ starts w suf))"

theorem weak_unverified_iff:
  "decide (Weak r) ev = UnverifiedPassage r' s ⟷
     compute_op (asked ev) = None ∧ ¬ lookup_refused ev
     ∧ (∃c. candidate ev = Some c ∧ ¬ released ev c ∧ r' = r ∧ s = sentence c)"

theorem weak_declined_iff:
  "route (Weak r) ev = Declined NoAdmittedStatement ⟷ candidate ev = None ∧ withholds_empty r"

theorem weak_pass_through_iff:
  "route (Weak r) ev = Clarify ⟷ candidate ev = None ∧ ¬ withholds_empty r"

theorem unverified_reply_shape:
  assumes "decide (Weak r) ev = UnverifiedPassage r s"
  shows "status_of (decide (Weak r) ev) = STR ''withheld''"
    and "path_of (Weak r) ev (decide (Weak r) ev) = STR ''unverified:'' + route_name r"
    and "response_of (Weak r) ev (decide (Weak r) ev) = unverified_text s"
    and "s = sentence (the (candidate ev)) ∧ ¬ released ev (the (candidate ev))"
    and "cited_claims (decide (Weak r) ev) = []"

theorem statement_answer_iff:
  "decide Statement ev = Answer c e ⟷
     compute_op (asked ev) = None ∧ ¬ lookup_refused ev ∧ e = None
     ∧ candidate ev = Some c ∧ anchor_present (pool_e ev) ∧ names_term ev c ∧ ¬ disambiguation c"

theorem statement_quotes_the_topic:
  assumes "decide Statement ev = Answer c e"
  shows "words_of (asked_term ev) ≠ []
    ∧ (∀w∈set (words_of (asked_term ev)).
         (∃pre suf. lowercase (asked ev) = pre @ suf ∧ starts w suf)
       ∧ (∃pre suf. lowercase (take 200 (sentence c)) = pre @ suf ∧ starts w suf))
    ∧ ¬ disambiguation c"

theorem door_asks_only_what_was_said:
  assumes "decide t ev = AskWhich p"
  shows "route t ev = Clarify ∧ pointer ev = Some p ∧ p ≠ []
    ∧ (∃pre suf. asked ev = pre @ suf ∧ starts p suf)"

theorem clarify_shape:
  "route Fallback ev = Clarify"
  and "status_of Clarify = STR ''clarification''"
  and "path_of t ev Clarify = STR ''act:clarify''"
  and "response_of t ev Clarify = clarify_text"
  and "cited_claims Clarify = []"
  and "status_of (AskWhich p) = STR ''clarification''"
  and "response_of t ev (AskWhich p) = ask_text p"
  and "cited_claims (AskWhich p) = []"

theorem refusal_shape:
  "status_of (Refused g) = STR ''withheld''"
  and "cited_claims (Refused g) = []"
  and "response_of t ev (Refused g) = refusal_text g"

theorem cited_iff_answer:
  "cited_claims (decide t ev) ≠ [] ⟷ (∃c e. decide t ev = Answer c e)"

theorem answer_reply_carries_citation:
  assumes ans: "decide t ev = Answer c e"
  shows "response_of t ev (decide t ev) =
      (if t = Statement then statement_text ev c
       else if (∃r. t = Weak r) then render_lead c
       else render_answer c e)"
    and "cited_claims (decide t ev) = (case e of None ⇒ [c] ∨ Some d ⇒ [c, d])"

lemma op_scan_sound:
  "op_scan b t = Some op ⟹
     (op = ''percentage'' ∧ CHR ''%'' ∈ set t) ∨ (op ∈ set operations ∧ (∃pre suf. t = pre @ suf ∧ starts op suf))"

lemma word_in_sound:
"word_in w s ⟹ ∃pre suf. s = pre @ suf ∧ starts w suf"

lemma occurs_sound:
"occurs p s ⟹ ∃pre suf. s = pre @ suf ∧ starts p suf"

lemma names_term_sound:
  assumes "names_term ev c"
  shows "words_of (asked_term ev) ≠ []
    ∧ (∀w∈set (words_of (asked_term ev)).
         (∃pre suf. lowercase (asked ev) = pre @ suf ∧ starts w suf)
       ∧ (∃pre suf. lowercase (take 200 (sentence c)) = pre @ suf ∧ starts w suf))"

```

The Explain theorems (`explain_*`, `no_answer_unanchored`, `statement_never_unanchored`) are
the scout's, unchanged, now about `route`. `answer_comes_from_route` carries them to `decide`.

What the theorems do not say: that the fetch's turn class, pool flags, DEF_Q shape, pointer,
P4 shape or displaced path label are right. Those are untrusted (`tools/document/fetch.py`
docstring, items 1 to 5). Where the kernel can read the text, it does: the computation gateway
and the definition test decide over the question and sentence strings the reply quotes, and the
door's phrase must occur in the question. `numerals` and `op_scan` are checked against w458's
regexes by the self test's examples, not by a proof of regex equivalence. Two of w458's arms
are not ported: IS_PRIME ("is 97 a prime") and SYMBOLIC ("3x + 1"). So the kernel's computation
test fires on a subset of w458's.

## Receipt

```
tools/dev/remote-build persvati src/isabelle/document Veri7vn_Document --expect 'VERI7VN_DOCUMENT PASS'
  -> remote-build: persvati Veri7vn_Document exit 0
     var/document/remote-build.log (saved as var/document/rb-persvati-pass.log)
     line 31:   Finished Veri7vn_Document (0:00:13 elapsed time, 0:00:18 cpu time, factor 1.34)
     line 1285: VERI7VN_DOCUMENT PASS theorems=43 oracles=0
```

The marker and its oracle scan are the last commands of `Document_Route_Export.thy`. The
session's theories are ordered Route, Test, Export, so nothing follows the scan. No theorem
uses `eval`. The ten self-test parts (st1 to st10: tiered pick, unverified weak, corpus empty,
statement, clarify, no anchor, computation gateway on 13 questions, door, definition release,
P4) are computed by `@{code}` in the build and again by the binary at start-up. They are
checks, not theorems.

The first build (hbox) failed on six proofs: two `intro exI` that gave both witnesses the
same term, one `@{text}` antiquotation, one `intro` that split further than its `show`
expected, one `blast` over a schematic fact, and one `simp add:` fact that the case split
had made stale. All six were fixed before the second build, which passed, so no lemma needed a
third attempt. The export SHA-256 begins `bf176093affc81cd` and the binary's begins
`ddd7d36d76d857e6`.

## Sample files

The scout's `items.jsonl` is the core panel's own rows. I checked all 30 for index, question,
status and path, and they match, so `measure.py` derives the items from `core_panel.json` and
the file is no longer needed. `head_replies.jsonl` came from the scout's one head run and cannot
be rebuilt without running the head. It is now in git, byte-identical (SHA-1 `84f9c6a1`), as
`tools/document/head_replies_w540.jsonl`.

## Untrusted parts

`tools/document/fetch.py` (turn classification, store reads, regexes, the arbiter capture,
the presentation passes), `tools/document/document_main.sml` (JSON and byte conversion),
`tools/document/measure.py`, `tools/document/answerer.py`. Stores are opened by the organs' own
classes with `immutable=1`. `find upstream -newer` after both measure runs listed nothing.

## Remaining

- The precision guards in front of the route (31 items): compose with W5-15's guards kernel
  once it covers the codes listed above.
- The capability and bridge captures (summarize, timeline, explain_simply, compose:bridge).
  Without them the converse statement answers 9 noun-phrase turns the head withheld (see
  above). This must be fixed before the answerer is used outside the 231.
- The fold that keeps a corpus decline against w420's factoid try (4 cube items), and the
  `wide_lead` capture of #680 and #830.
- The cube CHECK port (the scout's lane 1). Its count is the 3 "stricter" items plus the guard
  items whose route goes through `verified:weak`.

No specialist panel numbers: this lane measures the document route against the core panel's
recorded status and path, and the route is not a shipped specialist.

## Reproduce

```
tools/dev/remote-build persvati src/isabelle/document Veri7vn_Document --expect 'VERI7VN_DOCUMENT PASS'
sh tools/document/build.sh
PYTHONDONTWRITEBYTECODE=1 PYTHONHASHSEED=0 .venv/bin/python tools/document/measure.py   # writes var/document/measure231.json
```
