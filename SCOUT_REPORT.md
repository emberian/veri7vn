# Scout report: rel-novels (RelationOrganV2 over the relation store)

Status: COMPLETE prototype — verified kernel green, binary built, parity run. The verified reader
scores exactly what the canonical probe (the shipped organ itself) scores: **84/120 right, 0 wrong,
0 false yes, 36 withheld**, and agrees with the shipped organ **item for item on all 120 items**.

## 1. What I built and how to run it

End-to-end chain (every command from this worktree root):

```sh
# 1. norm index (labels-only stand-in for the missing names_v1.sqlite3), once: ~1.6 GB
python3 -I tools/reader-novels/build_norm_index.py
# 2. theory build (remote; ~4 min; green, no sorry; marker = export SHA-1)
/Users/ember/dev/o7vn/tools/dev/remote-build persvati src/extract/rel-novels Veri7vn_Novel_Reader --expect 'VERI7VN_NOVEL code sha1='
scp persvati:veri7vn-builds/rel-novels/var/rel-novels/gen/Novel_Reader_Code.ML var/rel-novels/gen/
# 3. MLton binary (SHAs the export; must match the build marker)
sh tools/reader-novels/build_decide.sh          # -> var/rel-novels/bin/decide
# 4. one question
echo '{"id":"x","q":"Who wrote A Wild Sheep Chase?","session":"s"}' | python3 -I tools/reader-novels/answerer.py
# 5. parity over the shipped panel (worktrees must point the harness at the real upstream)
rm -rf var/scout/parity && PARITY_UPSTREAM=/Users/ember/dev/o7vn/upstream \
  python3 -I tools/parity/harness.py --answerer "python3 -I tools/reader-novels/answerer.py" \
  --specialist rel-novels --split both --out var/scout/parity
# the shipped organ itself, for the cross-check: python3 -I tools/reader-novels/probe.py
```

Pieces:

- `src/extract/rel-novels/Novel_Reader.thy` (700 lines, **no sorry**, session green on persvati
  2026-10-17, export sha1 `5a5673d4888def891c455e90726ee245ed8de57d`): the specialist's whole
  decision — reader table, novels domain roots, candidate selection (take 3 / dominance), the walk
  over matched phrasings, the agree-on-one-value rule, recognise-then-decline, restates/past
  silences — plus meaning lemmas and the two receipts (§6).
- `src/extract/rel-novels/Novel_Reader_Export.thy` — SML export of `decide_spec` (+ per-attempt
  functions and the tables); writes the generated code and prints its SHA-1 as the build marker.
- `tools/reader-novels/decide_main.sml` + `build_decide.sh` — untrusted JSON-lines I/O around the
  exported decision, compiled with Isabelle's MLton. `echo readers | var/rel-novels/bin/decide`
  dumps the table the answerer checks against `readers.json` at startup.
- `tools/reader-novels/answerer.py` — UNTRUSTED glue: the shipped organ's own normalisation and
  compiled reader regexes propose attempts (in the shipped walk order), the norm index links the
  slot (in-domain-first, fact-count popularity — the documented stand-in), rows/ancestors are
  fetched from `relations_v1.sqlite3`, the binary decides, the reply is rendered with the shipped
  `_show`/`prop_label` and the organ's receipt sentence.
- `tools/reader-novels/probe.py`, `build_norm_index.py`, `probe_port.py` — the canonical probe and
  linker stand-in from the earlier scout lives (unchanged; the parity numbers below cross-check
  against the probe's).

## 2. What works, with numbers

Parity harness (shipped scorer, both splits), run 2026-10-17, `var/scout/parity/`:

- **dev 41/60, heldout 43/60 right — 84/120, 0 wrong, 0 false yes, 36 withheld.**
- Per relation (from the probe, which the parity run matches item for item): P156 24/24,
  P50 22/24 (2 withheld), P840 21/24 (3 withheld), P577 17/24 (7 withheld), **P144 0/24 (24 withheld)**.
- **120/120 item-for-item agreement** with the canonical probe (same status, same value, same
  scorer verdict on every panel item): the verified decision is behaviourally identical to the
  shipped organ on this panel; the seams (recognizer, linker, fetch, rendering) are the probe's
  own seams.
- Decision latency p50 < 1 ms, max 66 ms (first item, process startup). The verdict is INCOMPLETE
  only on the exam's composite criteria (DOMAIN/FALSE YES/LANE/SELF/BUDGET need a head run, not a
  specialist-alone reader).

What does not work: all 24 P144 ("based on") items are withheld because **property P144 is absent
from `relations_v1.sqlite3` store-wide** — no reader over the shipped store can answer them. The
other 12 withholds are the agreement rule refusing in-domain candidates that disagree or name no
single value (the organ working as designed).

## 3. What I learned that was not obvious

- Everything in §3 of the previous lives' report stands (organ cannot run as shipped; P144 is a
  data hole; agreement-based answering; the port cross-check). New this life:
- **The decision fits lane F's "verified decision over fetched rows" shape exactly**: attempts in
  the shipped loop order (keys 50, 577, 840, 156, 144; phrasings in index order), each carrying the
  full pre-dominance candidate list — the HOL side re-derives the shipped dominance/3-candidate
  rule itself (`select`), so the glue never pre-truncates candidates.
- **Values must be resolved fetch-side.** The shipped `values()` compares display labels, not
  entities: the fetch resolves every entity to its label (label-fallback-enwiki) and sends
  `Literal`s; genid/unresolvable become `Blank`, which `vals` filters — reproducing the shipped
  set-of-labels comparison exactly, including "two entities sharing a label are one value".
- **`restates` needs question-normalised words without stopword filtering on the question side**
  (only the value side filters stopwords) — mirrored in `question_words`/`value_words`.
- **Isabelle automation lesson (cost: one 5-minute diverged `auto` and an orphaned remote build):**
  the meaning lemmas' one-shot `auto` over the full nested `walk` tree diverges on
  `walk_silent_inv`; the fix is explicit case splits down the tree with atomic facts (`t1 t2 t3`,
  named case results — inner `case False` shadows outer ones), each closed by a small `simp`/`auto`.
  The sibling lemmas (`walk_decline_inv` &c.) used helper `dest` rules for the same reason.
- **SML export shapes:** tuple-typed constructor arguments stay nested (`Answer of natural *
  (natural * rel_value)` — pattern `Answer (s, (p, v))`), and `readers` comes out as
  `(natural * (natural * natural list)) list`. The gen file is written on the REMOTE by the ML
  block; `remote-build` excludes code exports from its pull, so `scp` the gen file back and check
  its SHA-1 equals the build marker (build_decide.sh enforces this pairing).
- **The harness in a worktree** needs `PARITY_UPSTREAM=/Users/ember/dev/o7vn/upstream` (the
  worktree has no 43 GB `upstream/`); without it the panel load fails with a bare
  `AttributeError: 'NoneType'`.

## 4. Dependencies for excellence

- A real names index (labels+aliases+sitelinks) and P144 data: unchanged from before — data lanes,
  not proof lanes. The linker stand-in remains the single ranking difference from shipped.
- Lane F's scaffolding (`tools/reader/`): this scout's answerer copies its contract; a family lane
  should factor the shared parts (binary protocol, fetch completeness flags, reply rendering).
- Nothing else is missing for the kernel itself: the theory, export, binary and answerer all run
  today on the shipped store with the two documented substitutions.

## 5. Proposed follow-up lanes

1. **Rel-novels family kernel** (S–M, sonnet): land this scout's shape as a family — move
   `src/extract/rel-novels/` + `tools/reader-novels/` onto the main tree (modulo the linker
   stand-in's var/ artifacts), re-run parity there, write `project/lanes/`-style handoff with the
   receipts. Done = main-tree parity numbers equal 84/120, 0 wrong, 0 false yes, and the build
   marker recorded.
2. **Linker stand-in hardening** (S–M, opus): aliases and a sitelink-count proxy in the norm
   index; measure per-relation withholds item by item. Done = probe withholds drop or each is
   explained (agreement-rule refusals vs linker misses).
3. **RelationOrganV2 family generalization** (L, opus): one verified kernel (this theory
   generalized: per-specialist reader/domain tables as data, inverse phrasings — absent here —
   modelled) plus per-specialist tables for all 161 `rel-*` specialists. Done = every `rel-*`
   panel scored with its own table, 0 wrong, false-yes 0, withholds explained; the per-specialist
   numbers in `project/lanes/`.
4. **Store refresh for P144** (S, sonnet, data): check whether any shipped store carries P144
   facts (relations_v2 never shipped; a rebuild would); if not, record the 24-item ceiling as a
   panel property. Done = the P144 story is data-backed or the panel expectation changes.

## 6. Honest status

- `Novel_Reader.thy`: **built green on persvati (Isabelle2026-RC1), zero `sorry`/`oops`, no new
  axioms** (grep-verified; the session build is the check). Export sha1
  `5a5673d4888def891c455e90726ee245ed8de57d` ties the binary to the theory.
- The receipts (theorem statements, quoted):

  > **answer_stored**: `decide_spec f attempts = Answer (s, p, v)` ⟹ `p ∈ {50, 577, 840, 156, 144}`
  > and ∃ attempt a, candidate c: `a ∈ set attempts`, `attempt_values f a = Some (s, p, v)`,
  > `c` among a's selected in-domain candidates, `qid c = s`, `dom_complete c`, every selected
  > candidate `complete`, `(p, v) ∈ set (rows c)`, `v ≠ Blank`, `¬ restates f v`, and every
  > in-domain candidate of a has exactly `{v}` as its stored values of p.
  >
  > **decline_stored**: `decide_spec f attempts = Decline (p, s)` ⟹ `p ∈ {50, 577, 840, 156, 144}`
  > and ∃ attempt a, candidate c: `a ∈ set attempts` with table phrasing, slot and candidates,
  > `c` among a's selected candidates, `qid c = s`, `domain_member c` (a real novels-domain
  > entity whose closure hits the roots).

  Both are conditional on the fetch flags (`complete`, `dom_complete`) — premises the untrusted
  fetch asserts, never established in HOL. Meaning lemmas cover all four outcomes
  (answer/decline/incomplete/silent), each naming the attempt that produced it.
- Untrusted, by construction: the recognizer (shipped regexes, read-only), the norm-index linker
  (ranking is the documented difference from shipped), the fetch (asserts completeness of
  unbounded sqlite range scans), the rendering, and `decide_main.sml`'s JSON layer. The answerer's
  docstring names every assumption; the binary is the only verified part.
- Runs behind the numbers: theory build (persvati, this session, log in `var/rel-novels/remote-build.log`),
  MLton build (sha1 pair above), smoke test, parity both splits, and the 120/120 item-for-item
  cross-check against `probe_items.jsonl` (the shipped organ's own run).
- var/ artifacts (norm index, gen, bin, parity) are not committed — the commands in §1 rebuild them.
