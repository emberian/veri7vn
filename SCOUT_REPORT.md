# Scout report: organ-wrappers (2026-10-17)

Lane D hand-built one Oracle7 specialist folder for acoustics. This scout generalized it: one generator
writes such a folder for **every specialist of every landed family**, and Oracle7's own dev exam was run
on five of them from scratch copies. The short version: the generator is faithful (it reproduces lane D's
acoustics verdict exactly), Oracle7's exam refuses all five **for reasons that are properties of the exam's
composition and of today's head, not of the organs**, and the release's own front composition passes four
of the five cleanly on both splits.

## 1. What I built

### `tools/organs/make_organ.py` — one folder per landed specialist

Discovers the family → specialists mapping itself by parsing each `src/extract/*/score.py`'s id table
(AST, never executed), falls back to the shipped manifests under `upstream/root/specialists/` for
everything else, and writes lane D's folder shape per specialist:

- `manifest.json` — the shipped manifest with `id` → `<sid>-veri7vn`, `organ`/`store` pointing at the
  wrapper here, `panel.path` local, a veri7vn source entry appended, `number` dropped, and a `veri7vn`
  block (`family`, `binary`, `binary_env`, `argv`) so tools can find the binary. `accept`, `budgets`,
  `routing_cues`, `core_sample` and the sources are the shipped ones verbatim.
- `organ_<sid>_veri7vn.py` — lane D's wrapper generalized: starts `var/<slug>/bin/<slug>
  --specialist <sid>` once (acoustics: no argument), pipes each `answer()` over the answerer contract,
  maps to `{kind, status, response, value}` or None. Binary from `$VERI7VN_<SLUG>_BIN`, else `bin/<slug>`
  beside the folder, else `var/<slug>/bin/<slug>` up the tree.
- the shipped panel, regrouped into `{"dev": [...], "heldout": [...]}` (what `workbench/exam.py` reads;
  the shipped flat list does not load there), and the shipped scorer, verbatim.
- `NOTICE` (what is copied, from where), `README.md` (how to install and exam).

Where a shipped manifest declares no panel of its own (`water-r3`), the panel and scorer named in the
family's score.py row are used. Where they live in a sibling's folder (`water`'s), that copy is used and
named in the NOTICE.

**124 folders, 18 families, 14,329 panel items, 5.1 MB total** — every family with a handoff on this
branch: acoustics 1, quantity 6, mechanics 9, space 8, em-optics 9, climate 6, energy 6, chemistry 5,
materials 6, life 6, anatomy-agri 5, geostats 6, discrete 5, trades 6, computing 9, variants 3, facts 22,
stores 6. Not included: `fusion` (a planner over kernels, not a specialist folder) and `reader` (the
relation reader). A `humanities` binary exists in the main checkout but has no handoff or score.py on this
branch, so discovery does not see it.

```sh
export PARITY_UPSTREAM=/Users/ember/dev/o7vn/upstream      # worktrees have no upstream/
python3 tools/organs/make_organ.py --list                  # what it found
python3 tools/organs/make_organ.py                         # writes var/organs/<sid>-veri7vn/
python3 tools/organs/make_organ.py --smoke                 # loads each folder like exam.py's Loaded,
                                                           # asks item 1 of each split (needs the binaries)
```

Smoke result: **0 load failures, 0 accept-rule refusals across all 124 folders** (binaries at
`/Users/ember/dev/o7vn/var/<slug>/bin/<slug>`, passed via the env vars). The one "not taken" (units-v2's
first heldout item, "I have 1 hours. How many minutes is that?") is parity: the shipped `units-v2` organ
also declines it.

Fidelity control: the generated `acoustics-veri7vn` manifest equals lane D's hand-built one except the
intended `notes` wording and the added `veri7vn` block; panel items are identical; and its dev-exam
verdict is byte-for-byte lane D's (below).

### `tools/organs/exam_dev.py` — Oracle7's own dev exam on any folder

Lane D's `src/extract/acoustics/exam_dev.py` generalized: copies the folder to `var/scout/trials/`,
builds a fresh `upstream/oracle7.py` Engine per exam with state under `var/scout/exam-state/`, redirects
the head's self-loop writes out of upstream with lane A's `redirect_self_loop()`, runs
`exam.run(trial, "dev", eng)`, prints the verdict. Dev split only — a held-out exam spends the set.
Several folders run one process each (a second Engine in one process finds the self-loop paths already
redirected and refuses; safe failure, loud). Needs the checkout's `.venv` python (the head imports numpy).

```sh
python3 tools/organs/exam_dev.py var/organs/<sid>-veri7vn
```

## 2. What works, with numbers

### The five dev exams (exam.py's own composition: head first, specialist only on a fillable decline)

Head at tip `oracle_release_runtime_w540`. Verdict reasons verbatim:

| Organ | n | decision | reasons verbatim | head ok/fy/wrong | with_specialist | core taken/924 (cap 9) | self | p50 ms |
|---|---|---|---|---|---|---|---|---|
| acoustics-veri7vn | 70 | WOULD FAIL | `DOMAIN: gain 1, needs 3` | 46/0/0 | 47/0/0 | 0 | ok | 0.02 |
| units-veri7vn | 76 | WOULD FAIL | `WRONG: 14 answered wrong, cap 1` | 39/0/14 | 61/0/14 | 6 | ok | 0.02 |
| git-veri7vn | 10 | WOULD FAIL | `DOMAIN: gain 0, needs 3`, `WRONG: 7 answered wrong, cap 1` | 3/0/7 | 3/0/7 | 0 | ok | 0.02 |
| orbits-veri7vn | 35 | WOULD FAIL | `WRONG: 16 answered wrong, cap 1` | 1/2/16 | 10/2/16 | 2 | ok | 0.03 |
| law-veri7vn | 9 | WOULD FAIL | `DOMAIN: gain 1, needs 3`, `WRONG: 2 answered wrong, cap 1` | 6/0/2 | 7/0/2 | 0 | ok | 0.06 |

Full verdicts: `var/scout/trials/<sid>-veri7vn/verdict_dev.json` (and `var/scout/exam-*.log`).
`core_head` is `oracle_release_runtime_w540` in all five; LANE, SELF and BUDGET pass in all five; the
acoustics verdict is identical to lane D's hand-built run (head 46, comp 47, gain 1 vs 3).

**Every wrong answer in every composite is the head's own** (`with_specialist.wrong == head.wrong`
throughout; the organs add zero wrong and zero false-yes). Reading the fails:

- units: the head answers conversions itself in exact-fraction prose — "250 cm is 12500/127 inches. the
  factor from cm to inches is 50/127…" — which the shipped scorer (first decimal after "is/about",
  0.2% + 0.05) reads as 12500. 14 dev / 29 heldout such items.
- git: the head answers from a corpus reading — "Git! is a 1965 American drama film directed by Ellis…"
  — on 7 of 10 items.
- orbits: the head's shipped `astronomy-v3` answers an adjacent fact ("Earth's orbital velocity is
  29.8 km/s") where the satellite computation was asked.
- law: the head asserts definitional readings ("[ev:direct] Habeas corpus is…") on 2 of 9.

### The release's own composition (specialist in front, `--compose front`) on the same organs

Via lane A's answerer and harness, same head, shipped panels, both splits
(`var/scout/front-parity/`; LANE/SELF/BUDGET unmeasured there but covered by the exam runs above):

| Organ | split | n | head ok/fy/wrong | composed ok/fy/wrong | gain vs need |
|---|---|---|---|---|---|
| acoustics | dev | 70 | 46/0/0 | **70/0/0** | 24 vs 3 |
| acoustics | heldout | 69 | 62/2/0 | **68/1/0** | 6 vs 3 |
| units | dev | 76 | 39/0/14 | **76/0/0** | 37 vs 3 |
| units | heldout | 76 | 43/0/29 | **76/0/0** | 33 vs 3 |
| git | dev | 10 | 3/0/7 | **10/0/0** | 7 vs 3 |
| git | heldout | 10 | 6/0/2 | 7/0/1 | 1 vs 3 |
| orbits | dev | 35 | 1/2/16 | **35/0/0** | 34 vs 3 |
| orbits | heldout | 35 | 3/1/23 | **35/0/0** | 32 vs 3 |
| law | dev | 9 | 6/0/2 | **9/0/0** | 3 vs 3 |
| law | heldout | 9 | 7/0/0 | **9/0/0** | 2 vs 3 |

Four of five organs pass DOMAIN, NO FALSE YES and FEW WRONG on both splits. The two short gains are
small-panel arithmetic, not organ defects: with n=10 and the head already right on 6 (git) or n=9 and the
head right on 7 (law), `max(3, 2%)` cannot be reached even at 100%. git's single heldout wrong is parity:
"What command brings back the stash in git?" → `git stash`, byte-identical to what the shipped git organ
(the one inside the head) answers. acoustics' single heldout false-yes is the head's own: after our organ
correctly declines a supersonic must-decline item, the head's shipped `optics-v5` answers it as
f = c/λ = 5.996e+05 Hz.

### Does exam.py's composition block admission, as lane D found?

**Yes, and more strongly than lane D measured.** Two mechanisms, both properties of the harness and the
head, not the organs:

1. **Gain starvation** (lane D's finding): the w540 head already contains the standing specialists —
   lane A's control documented this (folds w504–w536 call `combo_runtime_v1.Family`/`Network`) — so the
   slot exam.py measures is already occupied. A veri7vn clone consulted only on fillable declines is
   nearly redundant: gain 0–1 where the head answers or declines unfillable (`operator:unparsed` is not
   in `READING_DECLINES`).
2. **Inherited wrongs** (new): exam.py counts the composite's wrong answers, and the composite inherits
   every head assert. On units/orbits/git/law panels the w540 head asserts wrongly at 7–29 items per
   panel by the specialist's own scorer (fractions, adjacent facts, corpus misfires), far above the
   `max(1, 2%)` cap — so no organ behind that head can ever pass those panels, however perfect.

Under the composition the release actually runs (front; CORE.md notes the shipped combiner works this
way, and lane A's full sweep `var/parity/full-front-shipped-head/` measured it across all 305), the same
organs pass. **The verdicts are a property of the exam's behind-the-head composition, not of the organs.**

## 3. What I learned that was not obvious

- The head **contains** the shipped specialists at w540. Any "add specialist X to Oracle7" experiment at
  this tip measures X against a model that already has a copy of X inside it — front composition merely
  moves the clone ahead of its original, behind composition starves it.
- exam.py's fail records print `expected: (decline)` for every item: it reads `it.get("a")` but shipped
  panels key answers as `expect`. Cosmetic, but it makes raw fail lists misleading to read.
- exam.py's `Loaded` loads our generated folders unmodified (local panel path, local scorer, stdlib-only
  wrapper), where shipped manifests need lane A's `__ORACLE7_ROOT__`-substituting subclass. The
  generated shape is the more portable one.
- The wrapper organ needs the checkout `.venv` python for exams (numpy in the head), and
  `python3 -I` on shipped organ folders **writes `__pycache__` into upstream** — isolated mode ignores
  `PYTHONDONTWRITEBYTECODE`. My one probe did that; I removed exactly those three files
  (`units-v2/__pycache__/{narrow_v1,organ_units_v1,organ_units_v2}.cpython-311.pyc`) and verified
  `find upstream -newer` is clean. Use `-I -B`.
- One oracle7.py Engine per process for exams: a second build reuses cached sys.modules whose Path
  globals were already redirected, and `redirect_self_loop` correctly refuses. exam_dev.py now runs one
  subprocess per folder.
- Engine build ≈ 3 s; a whole dev exam (panel + 924 core + identity + engine) runs in 5–19 s per organ;
  organ p50 0.02–0.06 ms against 50 ms budgets. The organs are never the cost; the head is.
- `stores` organs depend on the build-time checkout path (the binary spawns
  `src/extract/stores/fetch.py` by `Config.repo` and wants `--state`); their folders generate and smoke
  fine but are not relocatable the way the others are. Not examined here beyond the smoke run.

## 4. Dependencies for excellence

- **A decision on where generated organs live.** Lane D committed acoustics' under
  `src/extract/acoustics/oracle7-organ/`; the generator writes `var/organs/` (uncommitted). If the 124
  folders are to ship in-tree, root picks a home (`var/organs/` + a make target, or per-family like lane
  D) and the NOTICE/licence story gets reviewed once, not 124 times.
- **A parity-board column for front composition of veri7vn organs** (lane A's harness already supports
  it). The exam.py column will read WOULD FAIL forever against a specialist-containing head; the front
  column is the one that can move.
- **Binary discovery** is env-var-or-walk-up; a `tools/organs` install step that copies binaries into
  the folders (`bin/<slug>`) would make them true drop-ins for machines without a veri7vn checkout.
  Untested here (exams used the env var), so it is a dependency, not a result.
- **Upstream exam schema drift**: shipped verdicts use an older schema (`DEV-PASS`/`ADMIT`, head as a
  fold name, no counts), so admission-time head behaviour cannot be compared numerically from them; only
  lane A's reconstructed controls can.

## 5. Proposed follow-up lanes

1. **Front-composition parity board for all 124 organs** (M, sonnet). Run lane A's harness
   `--compose front` over every generated organ, both splits, and record per-specialist
   right/wrong/false-yes plus LANE/SELF/BUDGET via `--lane-answerer`. Number that proves it done: a
   board table with 124 rows, matching each family lane's own panel numbers where those exist (they
   should, exactly).
2. **Head-drift audit: w363 → w540 on specialist panels** (S/M, opus). Lane A's `--tip` machinery plus
   the five organ panels: measure head ok/wrong per tip on units/orbits/git/law/acoustics panels to find
   which folds introduced the fraction-prose conversions, the "Git!" corpus misfire and the
   optics-v5 overreach. Proves it done: named folds for each new head-wrong class, counts per tip.
3. **Admission of a *new* specialist through Oracle7's own gate** (M, opus). The five here are clones of
   already-admitted specialists, so gain is structurally starved. A specialist Oracle7 does not have
   (e.g. a veri7vn-only family, or a narrowed variant) examined dev-only through exam.py would measure
   the gate as it was meant. Number: one `WOULD PASS`/`ADMIT`-path verdict, or a precise account of why
   not.
4. **Organs in-tree + install story** (S, sonnet). Root decides the home; make_organ gains a
   `--commit` mode writing named files; binaries copied in via a make step; READMEs and NOTICEs reviewed
   once. Number: `make_organ.py --smoke` green on a clean checkout with binaries installed the
   documented way.
5. **Held-out exam, once, for one organ** (S, opus, needs root's sign-off since it spends a set). If
   any of this is to be claimed in Oracle7's own terms, one organ (acoustics or units) takes its real
   held-out exam through the front composition the release uses. Number: that verdict, verbatim.

## 6. Honest status

- No Isabelle was built in this scout; the kernels and binaries are the landed lanes' work, used as-is
  from the main checkout (read/execute only). Nothing under `upstream/` was written by any exam or
  harness run (verified with `find -newer` after each phase); the one pycache slip is in §3.
- The five dev exams and the front-composition sweep are the only measurements; the other 119 organs
  have smoke coverage (loads, spawns, accept-rule pass, one item per split) and no panel numbers here —
  lane A's harness over them is follow-up lane 1.
- `exam_dev.py` multi-folder mode is verified (git+law); all five verdicts reproduced identically on a
  re-run.
- Untrusted in the organs: the wrappers (Python, stdlib only) and each family's untrusted recognizer
  layer, exactly as the family handoffs state; the wrappers add no computation of their own.

Branch `scout/organ-wrappers`, commits: `tools/organs: make_organ generates…`, this report.
