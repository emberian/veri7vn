# Scout report: rel-novels (RelationOrganV2 over the relation store)

Status at resume: this report was first written from the prior scout attempt's
committed work (canonical probe + draft theory). The verified-kernel half
(theory build, MLton binary, answerer, harness score) is being finished in
this session; every number below names what produced it.

## 1. What I built (so far) and how to run it

- `tools/reader-novels/build_norm_index.py` — builds
  `var/rel-novels/norm_index.sqlite3` (~1.6 GB): a labels-only stand-in for the
  missing `names_v1.sqlite3`, built read-only from the v1 store's own
  `entity(qid,label,enwiki)` table with entity_linker_v1's normalisation.
- `tools/reader-novels/probe.py` — **the canonical probe**: the *shipped*
  organ (`RelationOrganV2`, `upstream/root/specialists/rel-novels/`) run over
  the *shipped* store `relations_v1.sqlite3`, with exactly two substitutions
  for things that never shipped: the store handle (v2→v1) and the linker
  (names_v1 → norm index, in-domain-first ranking, fact count as popularity).
  Run: `python3 -I tools/reader-novels/probe.py` from the worktree root.
- `tools/reader-novels/probe_port.py` — a Python port of the organ's decision
  (statement-for-statement), cross-checked against the shipped organ; drift
  was localized to the linker stand-in. (It imports a `names.py` that was not
  committed; it is superseded by probe.py's in-process linker. Kept as a
  record of the port cross-check.)
- `src/extract/rel-novels/Novel_Reader.thy` — draft HOL decision theory
  (451 lines, no `sorry`): the walk over matched phrasings, candidate
  selection (take 3 / dominance), the agree-on-one-value rule, declines,
  the restates/past silences, and per-outcome meaning lemmas. **Not yet
  built**; export, recognizer, answerer still to come (see §6).

## 2. What works, with numbers

Canonical probe (shipped organ, shipped scorer, relations_v1 + norm index),
run 2026-10-17, output `var/rel-novels/probe_items.jsonl`:

- **dev 41/60 right, heldout 43/60 right — 84/120 total, 0 wrong, 36 withheld.**
- Per relation: P156 24/24, P50 22/24 (2 withheld), P840 21/24 (3 withheld),
  P577 17/24 (7 withheld), **P144 0/24 (24 withheld)**.
- Every P144 (based on) item is withheld for one store-level reason:
  **property P144 is absent from `relations_v1.sqlite3` store-wide** (no row
  with p=144 exists), so no reader over the shipped store can ever answer
  them. The 12 non-P144 withholds are agreement-rule refusals (in-domain
  candidates disagreeing or naming no single value) — the organ working as
  designed, not data gaps.
- 0 wrong means 0 false yes on this panel: nothing answered that the shipped
  scorer marks incorrect.

## 3. What I learned that was not obvious

- **The shipped organ cannot run as shipped.** `relation_spec_v2` reads
  `relations_v2.sqlite3` and `names_v1.sqlite3` (labels+aliases+sitelink
  counts); neither shipped. Both must be reconstructed for *any* run, shipped
  or verified. The v1 store carries the five properties' facts (minus P144),
  entity labels, and enwiki titles — enough for a labels-only linker with a
  fact-count popularity prior (lane F's stand-in).
- **P144 is a data hole, not a modelling problem.** relations_v1 simply has
  no `based on` facts. The ceiling for any reader over the shipped store is
  96/120 on this panel (all non-P144 items); the canonical probe reaches
  84, losing 12 to legitimate in-domain disagreement/no-value refusals.
- **The organ's answer rule is strictly agreement-based**: forward readers
  take up to 3 linked in-domain candidates and answer only when all name
  exactly one shared stored value; otherwise they decline in domain
  ("I can't verify ... I won't guess"). One dropped phrasing (50|fwd|2) only
  ever marks a decline. Inverse readers are unreachable for this specialist
  (no `inv` phrasings in its readers). A value that restates the question
  silences the whole turn.
- **The five readers' keys are their Wikidata properties** (P50, P577, P840,
  P156, P144), all forward, with phrasing counts 6/3/2/2/2 and exactly one
  dropped phrasing (50,2). None of the five properties is time-variant, so
  the shipped past-tense silence never fires here (the theory keeps it for
  fidelity).
- The port cross-check (probe_port.py) reproduced the shipped organ's
  decisions item-for-item except where the linker stand-in differed — i.e.
  the decision logic is faithfully portable and the only drift source is
  candidate proposal/ranking.

## 4. Dependencies for excellence

- **A real names index** (labels+aliases+sitelinks). The norm index covers
  labels+enwiki only; aliases are missing and popularity is a fact-count
  stand-in. Owner: whoever rebuilds `names_v1` from the upstream dump tooling
  (a data lane, not a proof lane). Until then the linker is the single
  untrusted seam and its ranking is a documented difference from shipped.
- **P144 data**: either a store refresh that includes P144 facts, or the
  panel expectation changes. Not fixable in the reader.
- **Lane F's shared reader scaffolding** (`tools/reader/{fetch,link}.py`,
  the decide-binary protocol): already reusable; a follow-up family lane
  should generalize it from one specialist to the 161 `rel-*` organs.

## 5. Proposed follow-up lanes

1. **Rel-novels family kernel** (M, sonnet): finish this scout's shape into a
  landed family — `Novel_Reader.thy` exported, MLton decide binary, answerer
  over the norm index, parity harness green. Done = the harness numbers in
  `project/lanes/`, matching the canonical probe (84/120, 0 wrong, 36
  withheld with the P144 reason named).
2. **Linker stand-in hardening** (S–M, opus): measure the norm-index linker
  against the shipped one on the non-P144 items; add alias routes if the
  panel exposes misses. Done = probe per-relation withholds drop or are
  explained item-by-item.
3. **RelationOrganV2 family generalization** (L, opus): one verified decision
  kernel plus per-specialist tables (readers, domain roots, dropped
  phrasings) for all 161 `rel-*` specialists, like lane O18's stores family.
  Done = every `rel-*` panel scored with its own table, 0 wrong, false-yes
  count 0, withholds explained.

## 6. Honest status

- The canonical probe numbers are real runs of the shipped organ over the
  shipped store with the two documented substitutions; the probe is UNTRUSTED
  glue by construction (it imports and patches upstream modules read-only).
- `Novel_Reader.thy` is a draft: written with no `sorry`, but **not yet
  built** — its proofs (notably `decline_meaning`) are unverified until
  Isabelle accepts them. No export, no binary, no answerer, no harness run
  yet. This section is updated as that lands.
