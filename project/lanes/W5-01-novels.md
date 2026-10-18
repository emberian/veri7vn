# Lane W5-01: the novels reader, finished (handoff, 2026-10-17)

`rel-novels` is Oracle7's relation specialist for novels and books. It reads five
hand-written question patterns (author P50, publication date P577, narrative
location P840, followed by P156, based on P144), looks the work up in the Wikidata
relation store, and answers only when every in-domain candidate agrees on one stored
value. This lane's reader is a HOL decision for exactly that rule, exported to
Standard ML and compiled with the MLton inside Isabelle into `var/rel-novels/bin/decide`.
An untrusted Python glue (`tools/reader-novels/answerer.py`) finds the entity, fetches
its rows and renders the reply.

## The numbers, stated plainly

- The shipped verdict files (`upstream/root/specialists/rel-novels/verdict_*.json`)
  show the specialist alone at **54/60 dev and 50/60 held-out, 104/120**. That was
  measured on a relation store (`relations_v2.sqlite3`) that **did not ship** with the
  release, so nobody outside the original machine can reproduce it.
- This reader, on the store that did ship (`relations_v1.sqlite3`), through lane A's
  harness: **dev 41/60, held-out 43/60, 84/120 right, 0 wrong, 0 false yes, 36 withheld.**
- **120/120 identical to the shipped organ's code on that store.** The shipped organ
  (`RelationOrganV2`, run by `tools/reader-novels/probe.py` against the same store and
  the same stand-in linker) and this reader agree on every panel item: same status, same
  value, same reply text.
- **24 of the 36 withholds are property P144 ("based on").** `relations_v1` holds no
  P144 fact at all (`SELECT COUNT(*) FROM fact WHERE p=144` is 0; P50 has 96,013). No
  reader over the shipped store can answer them. The other 12 withholds are the
  agreement rule refusing in-domain candidates that disagree or name no single value
  (P50 2, P840 3, P577 7), which is the organ working as designed.

So 84/120 is not a regression from 104/120. It is the same code on a smaller store.

## Receipts

1. Theorems, oracle-free. `tools/dev/remote-build persvati src/extract/rel-novels Veri7vn_Novel_Reader --expect 'VERI7VN_NOVELS PASS'`
   exited 0 (log `var/rel-novels/remote-build.log`):
   `VERI7VN_NOVELS PASS theorems=38 oracles=0`.
   The marker is printed by `Novel_Reader_Export.thy`, which collects 38 theorem facts,
   calls `Thm_Deps.all_oracles` and errors if there is any (lane G's mechanism).
2. The generated SML is the file the remote build returned,
   `var/rel-novels/export-remote/Veri7vn_Novel_Reader/Veri7vn_Novel_Reader.Novel_Reader_Export/code/novel_reader.ML`
   (sha1 `6edebfd1c416e1944e82325a102bc79fe3ddb0ad`). `tools/reader-novels/build_decide.sh`
   reads it from there; nothing is copied by hand. The binary is 199,304 bytes.
3. `python3 -I src/extract/rel-novels/tables_check.py` prints `ok` for 15 lines and
   `tables_check: all tables equal the shipped organ's`: reader table (keys, forward
   phrasing counts, the one dropped phrasing), no inverse phrasings, property of each key,
   novels domain roots (no occupations, no excluded properties), the time-variant list,
   dominance 10, take three, the agree-on-one-value and silence rules in the organ source.
   The phrasings themselves are not transcribed: the glue imports the shipped compiled
   regexes, so the check pins only their counts.
4. Parity: `PYTHONDONTWRITEBYTECODE=1 python3 -I tools/parity/harness.py --answerer "python3 -I tools/reader-novels/answerer.py" --specialist rel-novels --split both --out var/rel-novels/parity`
   printed `dev INCOMPLETE n=60 ok=41 fy=0 wrong=0` and `heldout INCOMPLETE n=60 ok=43 fy=0 wrong=0`.
   INCOMPLETE because the exam's composite criteria (domain gain over the head, lane
   interception, budget) need a head run, not a specialist-alone reader.

## What was wrong on arrival

The scout report and the merged triage said the theory built green. **It did not.** As
merged, `Novel_Reader.thy` failed on both hbox and persvati: an undefined fact
(`in_set_consI`), a `@{term relation_spec_v2.answer}` antiquotation naming a Python
function, and seven proofs that did not finish. (The earlier "green" and the sha1
`5a5673d...` came from a stale stored session.) This lane rewrote the proof part and kept
the decision the same:

- A new `step` function says what the walk does at one attempt: carry on (possibly marking
  a decline) or end the turn with Answer, Incomplete or Silent. `walk` is now defined from
  `step`, and `attempt_values`, `attempt_decline` and `transparent` are statements about
  `step`. The three conditions the old proofs choked on (`live`, `allc`, `agreed`) are named
  definitions, so the simplifier no longer unfolds them into a tangle.
- The proofs by induction over the attempt list are now short case splits on `step`.
- Same decision, same export names. The proof that nothing changed is the 120/120 above.

## Theorem statements (the load-bearing two)

```
theorem answer_stored:
  assumes "decide_spec f attempts = Answer (s, p, v)"
  shows "p ∈ {50, 577, 840, 156, 144}"
    and "∃a c. a ∈ set attempts ∧ attempt_values f a = Some (s, p, v) ∧
          c ∈ set (mineof a) ∧ qid c = s ∧ dom_complete c ∧
          (∀c' ∈ set (selof a). complete c') ∧
          (p, v) ∈ set (rows c) ∧ v ≠ Blank ∧ ¬ restates f v ∧
          (∀c' ∈ set (mineof a). set (vals p c') = {v})"

theorem decline_stored:
  assumes "decide_spec f attempts = Decline (p, s)"
  shows "p ∈ {50, 577, 840, 156, 144}"
    and "∃a c. a ∈ set attempts ∧ in_table (key a) (idx a) ∧ slot_ok a ∧ candidates a ≠ [] ∧
          c ∈ set (selof a) ∧ qid c = s ∧ domain_member c"
```

An answer names one of the five properties, a linked in-domain candidate whose stored rows
hold exactly that value, agreed by every in-domain candidate among the selected ones, and
not restating the question. A decline is recognise-then-decline: a linked in-domain
candidate of a matched phrasing. `decline_meaning`, `incomplete_meaning` and
`silent_meaning` give the other three outcomes' meaning; `walk_answer_exists` and
`no_answer_when_none` tie the walk's answer to one attempt. The premises `complete` and
`dom_complete` (the fetch returned every stored fact; the ancestor rows are the closure
walk) are assumptions about the untrusted glue, not proved.

## What it cannot do yet

- The linker is a stand-in: `names_v1.sqlite3` (labels, aliases, sitelinks) did not ship,
  so `var/rel-novels/norm_index.sqlite3` (labels and English titles of the v1 store, ranked
  in-domain first then by fact count) replaces it. Aliases do not exist there.
- P144 questions (24 items) are unanswerable on this store.
- No head run, so the exam's composite criteria are open.
- `var/rel-novels/norm_index.sqlite3` is 1.6 GB and is rebuilt by
  `tools/reader-novels/build_norm_index.py` (about 70 s, read-only against the v1 store).

## Consumer

W5-02 (one kernel for all relation readers) starts from this theory's `step`/`walk` shape
and its two receipts.

## Reproduce

```
tools/dev/remote-build persvati src/extract/rel-novels Veri7vn_Novel_Reader --expect 'VERI7VN_NOVELS PASS'
python3 -I tools/reader-novels/build_norm_index.py        # once
sh tools/reader-novels/build_decide.sh
python3 -I src/extract/rel-novels/tables_check.py
PYTHONDONTWRITEBYTECODE=1 python3 -I tools/parity/harness.py --answerer "python3 -I tools/reader-novels/answerer.py" --specialist rel-novels --split both --out var/rel-novels/parity
PYTHONDONTWRITEBYTECODE=1 python3 -I tools/reader-novels/probe.py     # the shipped organ, for the item-for-item comparison
```
