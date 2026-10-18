# Scout report: conversation (Oracle7's dialogue layer)

Target: map Oracle7's conversation behaviour — dialogue state across turns,
the meta-fold rewrites of runtime AO, the `organ:converse` route, the 143
state-touching folds — prototype a HOL model of the rewrite layer with the
two properties the AO docstring claims, build remotely, and say what a
verified conversation layer needs and whether the shipped scripts allow
scoring it.

Branch `scout/conversation`, commit `663408a` and later. Everything below
was run by me unless marked otherwise; `upstream/` was only read.

## 1. What Oracle7's conversation behaviour actually is

Four mechanisms, in the order a turn meets them:

**The slot (runtime E, `oracle_release_runtime_e.py`).** A per-session dict
`{last_result, last_topic, last_offset}` plus three ACTS routes
(`act:provenance_replay`, `act:continue_topic`, `act:acknowledge`) that
convert conversational acts over the stored answer. E also sets `last_topic`
when the inner chain answered via `anchored_summary` /
`definitional_encyclopedic`.

**The instrument (runtime AN).** One `LiminalTransition` per turn: surfaces,
terms in/out, the route, and `continuity` — the turn structurally used prior
state (an act route consumed it, or a verified conversion resolved a
reference against it). AN's docstring is explicit that it changes no answer.

**The state writer (runtime AM).** Writes `last_result` from the FINAL
result at the top of the chain, overwriting whatever inner layers recorded,
and never on act routes ("acts are conversions OVER the last answer; they
must not overwrite it"). Its docstring records why: routes resolved above E
never wrote state at all, so the ACTS layer read state describing a
different answer than the user received.

**The rewrite layer (runtime AO, the M53 meta-fold; the released head's
copy is fold w529 over `chat_context_v2.py`).** AO: four constructions
(REFERENT_SUBSTITUTION x39 support, ELLIPSIS_COMPLETION x32, OPENER_ALIAS
x11, REPAIR_ACCEPT x5, from the M52 residue of 161 unanswered turns), each a
REWRITE of a form the chain cannot read into one it can, followed by
re-dispatch through the unchanged chain. The `chat` method: probe the raw
turn through AM against a SNAPSHOT of dialogue state, restore the snapshot,
and only if the probe declined compute the conversion; probe the specific
rewritten form; if that is unserved for a referent substitution, fall back
to the grounded summary of the same topic; declare the conversion before the
single dispatch so the instrument records it on the transition. w529 is the
same shape with a different ground: it resolves pronouns/ellipsis against a
`Turn` state updated FROM REPLY RECEIPTS (subject entity, answer entity,
numeric result, solved variables, material phrase), tags the path
`chat:resolved>...`, and — unlike AO — can emit a clarification
(`chat:unresolved`) instead of passing an unresolvable pronoun through.

**`organ:converse` is not the rewrite layer.** It is the general-conversation
FALLBACK organ (`organ_converse_v1.py`, wired by fold w494): normalize
wrappers, then — only where the chain could not PARSE the turn, never over an
evidence-based withhold — feelings/opinions/jokes/recipes/statements/addressed
moves, every substantive sentence cited. Route tag `organ:converse><move>`;
the cooking panel's verdict files show `organ:converse>statement` answers.

**The 143 folds.** Lane B's catalogue: 84 are the episodic-recall `pre_route`
fold (identical 63-line modules repeated along the chain), the rest spread
over `post_replace` 13, `hook` 6, `state_only` 4 (an, am, ...), `rewrite` 5,
`post_redispatch` 4, `probe_rewrite` 1 (ao — the only one of its kind),
`pre_and_post` 1, `base` 1. The dialogue-STATE writers proper are E, AM, AN
and AO; the episodic-recall family binds whole episodes, a different (and
much larger) notion of state.

## 2. What I built

`src/extract/converse/` (session `Veri7vn_Converse`, built REMOTELY on
persvati, marker `VERI7VN_CONVERSE PASS theorems=11 oracles=0`):

- **`Converse.thy`** — the verified kernel. A `reading` datatype (one
  constructor per AO guard; the recognizer's regexes stay untrusted, lane-F
  style), the four constructions, `rewrite` over dialogue state (the log
  walk `live_topic`, the referential-NP check, the PREDICATE_OF table as
  checked data), `form` (raw / conversion / grounded fallback — AO's three
  decision points), `conv_step` (one turn = one dispatch; the two chain
  entry points stay abstract parameters), `note_of` (the transition's
  conversion record). Theorems, verbatim claims:
  - `conv_step_is_one_dispatch`, `probe_state_discarded`: the turn is
    exactly one dispatch, and the probes' state writes never survive —
    AO's snapshot-then-restore.
  - `warrant_stays_with_route`: an answered reply of the layer IS the
    unchanged chain's reply to the dispatched form ("Nothing here answers;
    the warrant is whatever the re-dispatched route provides").
  - `form_cases`, `gate_no_new_answer`, `no_silent_substitution`:
    conversions fire only when the probe on the raw turn declined, and the
    dispatched form is always a conversion's output or the documented
    fallback — never a silently invented one.
  - `probe_leaves_log_unchanged`: however many probes ran, the turn adds
    exactly ONE transition (AO attempt 1 doubled them; "the held-out turn
    count inflated 248 → 294"; the gate rejected it).
  - `note_iff_conversion`: the note exists only for a real conversion, and
    the unserved flag is set only for referent substitutions whose specific
    form the chain declined.
  - `conv_step_deterministic`: determinism transfers.
- **`Converse_Export.thy`** — export + executable self test over mock chains
  (gate closed, served predicate, unserved fallback, referential NPs, note
  flags, one-transition growth). 11 theorems, zero oracles, no sorry.
- **`recognizer.sml`** (UNTRUSTED) — verbatim port of the AO regexes through
  lane G's `regex.sml`, including the case-flag quirk below.
- **`main.sml`** (UNTRUSTED driver) + `build.sh` — `var/converse/bin/converse`,
  216 KB, MLton; a stateful JSON-lines protocol (probe/result oracles per
  request stand for the chain).
- **`tables_check.py`** — `predicate_of` (7 rows), `referential_nps` (3),
  summarize wording, all asserted equal to the organ's literals: PASS.
- **`score.py`** — the two measurements below.

Reproduce:

    /Users/ember/dev/o7vn/tools/dev/remote-build hbox src/extract/converse \
        Veri7vn_Converse --expect 'VERI7VN_CONVERSE PASS'
    sh src/extract/converse/build.sh
    python3 src/extract/converse/tables_check.py
    python3 src/extract/converse/score.py

## 3. Numbers

**The sealed dialogue tests DID ship, and the board is scoreable offline.**
`upstream/research/sealed_history/` has the scripts
(`conv_sealed_v[1-5].json`), the scoring rules (the `conv_tests_v1.py`
docstring: fact/follow/multi/number/decline/social), and the run recordings
with full replies, statuses and paths (conv1 run 3 on w533: 88 turns; conv2
on w533: 51; conv4 on w536: 49; conv5 on w538: 49 — 237 turns total). The
RUNNER (`run_conv_v1.py`) did not ship. My reimplementation of the rules
**reproduces 236/237 recorded verdicts and 3 of 4 published summaries
exactly** (conv2, conv4, conv5 byte-for-byte; conv1r3's summary differs only
through the single item below). The one divergence: `d17t1 'And Phobos?'` —
Oracle7 answered with a `capability:summarize` paragraph about Phobos that
never says "Mars"; the shipped runner graded it right, the docstring rule
says wrong. That is exactly the "reach is not an answer" class the 2026-09-28
gate diff later called a false yes. So: no Oracle7 head is needed to score
conversation replies — only the recordings plus these rules.

**Layer decision agreement (my compiled kernel vs the recordings' `chat:*`
path tags), 237 turns, 6 ms total (216 KB binary):**

| kind | n | agree | mine rewrote | Oracle7 rewrote |
|---|---:|---:|---:|---:|
| fact | 65 | 65 | 0 | 0 |
| social | 18 | 18 | 0 | 0 |
| follow | 96 | 36 | 10 | 64 |
| number | 38 | 31 | 7 | 6 |
| multi | 8 | 4 | 0 | 4 |
| decline | 12 | 7 | 4 | 1 |
| **all** | **237** | **161 (68%)** | **21** | **75** |

Readings seen: plain 173, free_deictic 40, ellipsis 21, continuation 2,
pred 1; constructions fired: ELLIPSIS_COMPLETION 15, REFERENT_SUBSTITUTION 6
(of which 6 unserved fallbacks). No repair/opener/bare fired — see the quirk.

The disagreement is not noise; it is the central finding. The dialogues'
first turns are FACT questions ("Who directed Yojimbo?"), which AO's
`_live_topic` walk does not ground (it only grounds opener forms: "tell me
about X / what is X / summarize X"), so my AO-faithful layer passes the
pronoun follow-ups that w529's receipt-grounded engine rewrites
("Where was he born?" → `chat:resolved>organ:relation>form:birthplace>...`).
Where my layer DID rewrite against Oracle7's pass, the named cases are
AO's own defect classes faithfully reproduced: "And of Denmark?" →
"Summarize of denmark." (AO's ellipsis treats a prepositional fragment as a
topic; entity-swap ellipsis is w529's `_replace_subject`, which AO lacks),
and "What language will people speak there in 3000?" → a referent
substitution onto the NP "the official language of brazil" (AO's opener walk
grounds whatever follows "what is", predicates included).

## 4. What I learned that was not obvious

- **The two rewrite layers are the same theorem and different organs.** AO
  (M53, research chain) and w529 (released head) share the exact shape my
  kernel proves things about — probe, rewrite, one re-dispatch, never answer
  — but ground differently: AO on opener-form surfaces in the transition
  log, w529 on entities recovered FROM REPLY RECEIPTS (`_entity_of_reply`'s
  receipt parsing, including the inverse-read direction trick). A verified
  conversation layer must model the GROUND as a typed input, exactly as the
  rewrite is typed here.
- **The AO regexes have a case bug that kills two of the four
  constructions.** REPAIR and OPENER are compiled WITHOUT `re.I`
  (`oracle_release_runtime_ao.py` lines 28-29) while every other guard
  carries it: "i meant volcanoes" converts, "I meant Volcanoes" does not,
  and "Tell me about earthquakes." — printed in AO's own cluster support
  table — never matches OPENER. The M53 support counts were therefore
  computed on lowercased text somewhere upstream of the fold, or the
  branches are dead code for cased input. I ported the quirk verbatim
  (recognizer header) rather than fixing it; a real lane must decide.
- **AM/AN/AO's comments are a design-document in miniature.** Attempt
  histories are recorded in the code: AO's probe-restore (attempt 2
  rejected: continuity 153 → 124), the single-dispatch rule (attempt 1
  doubled transitions, turn count 248 → 294), the pending-conversion
  declaration (attempt 5), the ground fix (attempt 6 resolved "it" to a
  predicate). My two probe-purity theorems are exactly the properties those
  attempts kept violating; the code got there by gate rejection, the kernel
  gets there by construction.
- **The 143 state folds are mostly one fold.** 84 of 143 are the identical
  episodic-recall `pre_route` module repeated along the chain; the live
  state machinery is E+AM+AN+AO plus the w-chain's `chat_context_v2.Turn`
  (subject/answer/result/solved/material/topic — a seven-field state the
  released head actually reads).
- **`organ:converse`'s safety rule is worth copying into any verified
  fallback**: it may not speak over an evidence-based withhold (only the
  crisis path may), and its request move answers only definitional
  requests — "reach is not an answer" is enforced by a dated gate diff.
- **The scorer can be validated before it is trusted.** Rescoring the
  shipped recordings against their own published summaries is a cheap,
  exact check — it caught that my first `number` rule reading was wrong and
  pinned the one genuinely ambiguous item.

## 5. Dependencies for excellence

- **A dialogue mode in the parity harness** (lane A's `tools/parity/`): the
  answerer contract already has `session`, but panels are single-turn. A
  `--dialogues` mode feeding turns per session and applying the
  conv_tests_v1 rules would make conversation a board row. Owner: lane A;
  my `score.py` rules check is the reference implementation (236/237).
- **The GROUND as shared data.** Receipt parsing (`_entity_of_reply`) and
  the w529 `Turn` state need a typed entity record (qid, label, is_person)
  shared with the relation-reader lanes (lane F). Owner: whoever lifts the
  relation reader next; the receipt regexes live in `chat_context_v2.py`
  lines 78-127.
- **A decision on the AO case bug** (fix + note, or keep verbatim). Owner:
  the conversation lane, with root's sign-off since it changes behaviour.
- **The w529 acceptance gate as a verified predicate.** `recognised(q)` (a
  rewrite is accepted only if the relation readers can read it) is the
  property that keeps rewrites from breaking the core's own acts
  (m52 replay: 34 route changes → 0). It wants to be a premise in the
  kernel (`rewrite_accepted`), which needs the relation readers' shape as
  a HOL predicate. Owner: lane B/F interface.

## 6. Proposed follow-up lanes

1. **Conv-board lane (S, sonnet).** Add a dialogue mode to the parity
   harness and put the four shipped sealed runs on the board with the
   reimplemented rules; every future conversation change then has a number.
   Done when: the board reproduces the four published summaries from the
   recordings (3 exact + conv1r3 with the named divergence), and a
   candidate answerer can be scored on the same 237 turns.
2. **w529 lane (M, opus).** Lift the released head's rewrite engine
   (`chat_context_v2.py`, 422 lines) the way this scout lifted AO: typed
   readings for pronoun/ellipsis/result/multi swaps, the `Turn` state as a
   HOL record, the `recognised` acceptance gate as a premise, the
   clarification (`chat:unresolved`) as a typed outcome. Done when: the
   kernel's decisions on the 237 recorded turns agree with the `chat:*`
   tags on ≥ 90% of follow turns (this scout's AO model gets 36/96), with
   the same two theorems (warrant stays with the route; probe/state
   purity) and the scorer's number to prove it.
3. **Converse-organ lane (M, sonnet).** The `organ:converse` fallback as a
   verified organ over the record store (definitional-only requests,
   never over an evidence-based withhold, canned-addressed replies never
   counted as knowledge). Done when: it scores its own turns from the
   conv recordings' `organ:converse` paths plus the cooking panel's
   statement turns, 0 false yes.
4. **Dialogue-state metatheory (S/M, fable).** The state machinery E/AM/AN
   as one locale: acts never overwrite `last_result`, state written only
   from the final result, one transition per turn, continuity defined over
   the log — the invariants AM's and AN's docstrings claim. Done when: the
   four invariants are theorems over the same abstract-chain locale this
   scout uses, and the AO kernel instantiates them unchanged.

## 7. Honest status

- No `sorry`, `oops`, `skip_proof` or axioms; 11 theorems, 0 oracles; the
  build's own oracle check enforces it (marker line above).
- Untrusted and named: `regex.sml`, `recognizer.sml`, `main.sml` (the
  driver's mock chains stand for the real AM/AN entries; the kernel
  theorems hold for any chains, which is the point). The probe/result
  oracles in scoring are derived from the recordings, not measured from a
  live chain — stated in `score.py`'s header.
- The decision-agreement number is a LAYER number on recorded dialogues,
  not a specialists-panel number; there is no conversation row on the
  parity board yet (dependency 1).
- The one rules divergence is named, not chased: d17t1 'And Phobos?'.
- Known infelicity, kept for fidelity: the recognizer lowercases text for
  the case-insensitive patterns, so captured topics are lowercase where
  the organ keeps case; decision-neutral (documented in the recognizer
  header).
- Disk: `df` fine throughout; `var/converse/` holds only logs, the export
  and a 216 KB binary.
