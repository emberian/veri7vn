# Scout report: the specialist linter (2026-10-17)

The gift for Oracle7's author: `tools/lint/specialist-lint.py` reads any specialist
folder — shipped or newly written — and says in plain words what is wrong with it,
what the verified exam gate would decide on its shipped verdict counts, which head
folds would see its questions before it does, and which composition each number was
measured under. The aggregate over all 305 shipped manifests is committed as
`docs/lint/specialists.md`.

## 1. What I built and how to run it

```sh
# one folder (shipped, by id or path; or a folder you are writing)
PARITY_UPSTREAM=/Users/ember/dev/o7vn/upstream python3 tools/lint/specialist-lint.py densities
PARITY_UPSTREAM=/Users/ember/dev/o7vn/upstream python3 tools/lint/specialist-lint.py var/lint/demo

# every shipped manifest, aggregate document
PARITY_UPSTREAM=/Users/ember/dev/o7vn/upstream python3 tools/lint/specialist-lint.py --all --aggregate docs/lint/specialists.md
```

One file, ~700 lines, no dependencies beyond the tree. It uses three existing
artefacts and touches nothing else:

- **the verified gate binary** `var/gate/build/gate_check` (lane C's session
  `Veri7vn_Specialists`, exported to SML, compiled with MLton; rebuilt via
  `python3 tools/gate/check_verdicts.py --extract && ... --compile`). The decision and
  its reasons come from the HOL definition of exam.py's six criteria, not from Python.
  I reused the build from the main checkout (current with commit `deea470`).
- **the fold catalogue** `audit/folds/folds.json` (lane B): the 132 live pre-route
  folds (253 minus 121 dead copies), guards compiled once.
- **the parity harness's conventions** (`tools/parity/panels.py`): placeholder
  substitution, panel shapes, verdict-file normalisation.

What it checks per folder: manifest fields (id, organ module/class with inheritance
resolution for versioned organs, accept.kinds/declines/context_regex, budgets, store,
expires, supersedes), panel shape and exam.py's minimums, scorer import plus a smoke
call on a withheld reply, verdict binding (exam.py's files_sha), the gate verdict, the
cue and panel shadowing, and the composition note.

## 2. What works, with numbers

- All **305** manifests linted in **1.6 s**; nothing under `upstream/` written, no
  organ run (scorers are imported, as exam.py does, with bytecode off).
- **292** verdict files reached the verified gate: **239 agree** exactly (decision and
  reasons), **3 disagree** (all LANE, see finding 2), **50 insufficient** (older gate
  v2 files without `domain.spec.wrong`), **13** folders carry no verdict of any kind.
- **534 manifest errors in all 305 folders, 732 notes** (every folder has at least the
  flat-panel error, finding 1).
- Cue shadowing: of the 143 specialists with routing cues, all 143 are matched by a
  live answering pre-route fold; for 54 a fold that *answers whenever its guard fires*
  matches. Calibrated against 100 core-panel questions so universal guards (fire on
  ≥90% of anything) are separated from real overlap.
- Verified by hand, not just by the tool: the 5 backspace regexes, the 7 stale store
  paths, the 161 empty context regexes, the 163 no-decline panels, the taken
  distribution (max 6), the two inherited verdicts, exam.py's `.get`/placeholder/MIN
  code paths, and the `_TOKEN`/`_world_material`/`_NUMBERS_HINT` guard patterns.

What does not work: nothing failed to run. The known soft spots are the probe texts
for cue matching (two question shapes per cue; a filler word must be dull — an early
version used "X", which algebra guards match as a variable), and shadowing says
"matches" not "answers" for every fold except those the catalogue marks
`answers_whenever_guard_fires`.

## 3. The ten most interesting findings

1. **exam.py cannot run a single shipped panel.** 304 of 305 panels are flat lists of
   items tagged `split`; exam.py calls `panel.get(split)` on what it loaded, and a
   list has no `.get` — AttributeError. Independently, 304 panel paths carry the
   `__ORACLE7_ROOT__` placeholder, which exam.py joins onto the folder as written,
   pointing at `<folder>/__ORACLE7_ROOT__/...`, which does not exist. The workbench
   exam is written for new folders authored in the workbench; against the drop it is
   decorative.
2. **Every shipped verdict measured the lane cap on a sample, not the panel.** All 292
   files carry core_n of 400–406 (the manifest's `core_sample.n`), so the cap the
   1%-formula gives is 5; exam.py always runs the full 924 (cap 9). The only three
   disagreements in the whole drop (rel-graphicartists, rel-novels, rel-translators)
   are exactly the specialists that took 6: they fail the sample's cap of 5 and fit
   exam.py's cap of 9. The release's own admissions were tighter than exam.py's rule,
   by accident of sampling.
3. **No shipped verdict carries a files_sha.** exam.py's status check compares the
   folder's current hash to the one written in the verdict; with no hash in the file,
   every one of the 242 checkable specialists reads as "changed since its exam" and
   stays out of the workbench's model. The one-use-held-out binding exists only in
   exam.py's world; the release never wrote the hash the portable exam looks for.
4. **161 relation readers set `context_regex` to the empty string, which matches every
   text.** exam.py's never-matching default applies only when the key is *absent*;
   present-but-empty compiles to the empty pattern. So every in-domain decline of
   every `rel-*` specialist is in-context everywhere — core-panel and identity
   questions included. Half the catalogue silently opted out of the context gate in
   the direction of "always", not "never".
5. **Five manifests contain a raw backspace in `context_regex`: decay, fluids,
   fluids-r2, fuels, springs.** The author wrote `\b` as JSON `\b`, which decodes to
   U+0008, not the regex word boundary. The pattern can never match a real question,
   so no in-domain decline of those specialists is ever accepted — confirmed against
   their own panels: fluids' context gate misses 25 of 25 held-out questions. Four of
   the five are lane G's quantity family, at parity on answers while their decline
   discipline was never enforceable by the workbench's own rule.
6. **The relation panels measure no false-yes discipline at all.** All 161 `rel-*`
   panels have zero must-decline items (`valid: false`); 42 more folders have exactly
   one, and 18 have held-out sets under 10 items. exam.py refuses to run any of them
   (`MIN_HELDOUT=10, MIN_DECLINE=2`). In total 205+ of the 305 panels are unrunnable
   under exam.py's minimums — the release gate v2 enforced no such minimums, and 163
   specialists were admitted without a single false-yes probe.
7. **The head's narrow guards are pointed at specialist territory.** Genuine
   specialist-shaped shadows (guard fires on ≤5% of generic questions but on the
   specialist's own material): `w37 _NUMBERS_HINT` (`\b(number|integer|value)s?\b`)
   matches sql's and economics' cues; `w34`'s inline "world material" guard — actually
   the punctuation class `["“—–:;(]` — matches fluids/carbonmat/algorithms/orbits
   panel questions 18–25 of 25; `x _FILLER` matches astronomy's. Under exam.py's
   behind-composition these folds see such questions first; 54 specialists have a cue
   where a fold that answers outright on a guard match overlaps.
8. **Universal guards hide inside friendly names.** `w55 _TOKEN`
   (`\s*(\d+...|[xyz]|...)`) fires on 66% of generic questions — any word containing
   x/y/z after a space ("Ren**z**i", "man**y**") counts as algebra. `t ABOUT_LEAD` is
   an entirely optional group: it matches everything. Without baseline calibration
   (which the linter now does against 100 core questions) a shadow report would be
   noise; with it, these show as "not specific".
9. **Seven versioned specialists point `store.path` at predecessor folders that did
   not ship** (additive-v2 → `additive/`, games-v3, logic-v3, materials-v2,
   microbiology-v2, nutrition-label-v2, robotics-v2). exam.py never reads store.path,
   but the release's store-size budget cannot have been measured against a file that
   is not in the drop. Related: only 2 of the 15 `-r2/-r3` revision folders carry an
   inherited verdict; 13 carry none, and water-r3 cannot be examined at all (no
   panel path — `water_panel_v1.json` sits unregistered — no scorer module registered,
   no budgets, no cues).
10. **The drop publishes only successes.** All 290 held-out verdict files say ADMIT
    with an empty reasons list; not one NEGATIVE or DEV-FAIL file exists in any
    folder, though the architecture describes 23 published failures. The failures live
    outside the specialists tree (admission ledger), so a linter run over the drop
    cannot see the release's reject pile — the "23 failed exams" of CORE.md are not
    lintable from `specialists/` alone.

## 4. What I learned that was not obvious

- The release gate v2's verdicts are *almost* exam.py's rule — 239/242 exact — and
  the three misses are a measurement-protocol difference (sampled core), not a rule
  difference. Lane C's HOL gate is now the tiebreaker that makes that precise.
- exam.py's manifest handling has three separate never-tested code paths (missing key
  vs empty string vs placeholder path), and the shipped drop sits on the wrong side of
  all three. Any "run the workbench exam on the drop" plan needs a shim, and the shim
  must say which of the three it is fixing.
- Fold guards named for one purpose routinely match something else
  (`_world_material` is punctuation; `_TOKEN` is "contains x/y/z"). Guard-name-based
  reasoning about the cascade is untrustworthy; only calibrated match rates are.
- The verdict files' `domain.head.fails` blocks contain the actual head replies per
  item — a free corpus of head behaviour at exam time that nobody has harvested yet.

## 5. Dependencies for excellence

- **A shared contract module** owning exam.py's field mapping and `files_sha`
  (currently copied in `tools/gate/check_verdicts.py`, `tools/parity/panels.py`, and
  now the linter, each with a comment naming the source). Owner: lane C or root; the
  linter should import it, not re-implement it.
- **A committed build path for the gate binary.** `var/` is not committed; the
  aggregate doc tells the reader to rebuild via tools/gate. A `tools/lint/README`
  one-liner or a make target would remove the surprise. Owner: whoever adopts the
  linter.
- **The failure pile.** The 23 rejected exams are not in the drop; the admission
  ledger digest is the only source. A lane that wants to lint "would the gate have
  caught the failures" needs that file fetched or declared out of scope. Owner: root.
- **Hook folds are not modelled** in the shadow section (only pre-route, per the
  catalogue's own blind spot: 21 hooks change deeper folds from above). Owner: lane B
  successor.

## 6. Proposed follow-up lanes

1. **"Exam that runs the drop"** (S, sonnet): a thin runner that loads shipped panels
   (substituting the placeholder, accepting flat lists), enforces or explicitly waives
   the minimums, and calls the verified gate binary for the decision — the parity
   harness already has the loaders; wire them to the gate. Number that proves it done:
   all 292 checkable verdict files re-decided through the binary with zero Python
   re-implementations of the six criteria.
2. **"Manifest hygiene patcher"** (S, sonnet): `specialist-lint.py --fix` emitting a
   patch file (never writing upstream) for the mechanical faults: 5 backspace regexes,
   7 stale store paths, water-r3's unregistered panel/scorer, and the 161 empty
   context regexes (as an explicit decision, not silently). Number: 0 control-character
   regexes and 0 unresolved store paths in a re-lint of the patched copy.
3. **"Who does this fold steal from"** (M, opus): invert the shadow matrix — every
   live answering fold × every specialist's full held-out panel (not a 25-sample),
   calibrated per fold, cross-checked against lane A's head-run parity data where the
   head was actually run. Number: per-fold take counts that agree with lane A's
   measured interception on the overlapping specialists.
4. **"Linter as an organ"** (M, sonnet): package gate_check + the linter as a
   drop-in Oracle7 specialist folder (the acoustics-organ pattern) so the author can
   lint a folder from the workbench itself. Number: the parity harness scores it as an
   answerer, and it lints a folder given by path.
5. **"Head-fail corpus"** (M, fable): harvest the `domain.head.fails` blocks from all
   290 verdicts into a labelled corpus of head declines-by-item (path, response), and
   state what fraction are fillable under the HOL `fillable` definition. Number:
   corpus size and the fillable fraction, per reading-decline marker.

## 7. Honest status

- Everything reported above was actually run; the aggregate document is generated,
  not hand-written. No `sorry`, no axioms, no new Isabelle sessions — the verified
  part is lane C's already-built gate binary, re-used as-is.
- Untrusted by construction: scorer imports (executed Python, as exam.py does),
  regex probes for cue matching (two shapes per cue), and the AST organ checks (no
  execution). The gate mapping for release-v2 files is copied from lane C's
  check_verdicts.py with a comment naming it.
- The gate binary was not rebuilt in this worktree (copied from the main checkout's
  var/gate, current with `deea470`); the report's reproduce commands include the
  rebuild path.
- Scratch (demo folder, copied binary) lives under `var/lint/` and `var/gate/` in this
  worktree; nothing outside it and `tools/lint/` + `docs/lint/` was written. Disk use
  is negligible (~400 KB).
