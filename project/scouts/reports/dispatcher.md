# Scout report: the dispatcher (single-binary deployment shape)

Branch `scout/dispatcher`, 2026-10-17. Everything below was run; nothing is
claimed that was not. Working files: `tools/dispatch/` (committed), scratch and
reports under `var/dispatch/` (not in git).

## 1. What I built

`tools/dispatch/dispatch.py` — an answerer-contract front door that routes a
question through the verified kernels in the order Oracle7's released head
uses, plus the pieces it needs:

- `tools/dispatch/arb_driver.sml` + `build_arb.sh` → `var/dispatch/bin/arb_check`
  (180 KB): lane C's exported `Arbitration.thy` (`arbitrate`, from the
  `Veri7vn_Specialists` session) wrapped in a one-line-text-protocol driver.
  The Pick / Disagree / Fallthrough decision is the HOL function's; the driver
  only parses. Build receipt (command from the worktree root):
  `/Users/ember/dev/o7vn/tools/dev/remote-build hbox src/isabelle/specialists Veri7vn_Specialists --expect 'VERI7VN_SPECIALISTS PASS'`
  → `remote-build: hbox Veri7vn_Specialists exit 0; exports in …/var/scout-wt/dispatcher/var/specialists/export-remote/Veri7vn_Specialists/`
  (log contains `VERI7VN_SPECIALISTS PASS`, Specialists_Tests line 92; exported
  `veri7vn_gate.ML` sha256 3655bbd1d9ee6e85).
- `tools/dispatch/measure_core.py` — the 924-item core-panel measurement against
  the panel's own recorded status/path.

Stages (order read off the released chain, see §3): the network (fusion
answerer; a validity decline withholds and stops the cascade), then every
family binary in parallel through the manifest accept gate and the verified
arbitration (an answer or Disagree ends the turn; an in-domain decline is only
a fallback), then lane F's reader, then `dispatch>declined`. `--order front`
swaps network and organs (the composition the shipped verdicts reproduce
under, for use on a specialist's own exam).

How to run:

```sh
sh tools/dispatch/build_arb.sh
python3 tools/dispatch/dispatch.py --selftest
PARITY_UPSTREAM=/Users/ember/dev/o7vn/upstream python3 tools/dispatch/measure_core.py -- --order head
PARITY_UPSTREAM=/Users/ember/dev/o7vn/upstream python3 tools/parity/harness.py \
  --answerer "python3 tools/dispatch/dispatch.py --order front --specialist {id}" \
  --specialist springs,units-v3,densities-r2,physics-r2,chemistry-v3,cooking-v3,optics-v5,astronomy-v3,calculus,soil-r2 \
  --split heldout --out var/dispatch/panels
```

## 2. What works, with numbers

**Arbitration selftest**: 5/5 (cases mirrored from `Specialists_Tests.thy`:
agree-shortcut, dependence-beats-assumed, checked-decline-beats-foreign,
tie-with-different-numbers → Disagree, empty → Fallthrough).

**Core panel, 924 items, head order** (`var/dispatch/core_report.json`; one
dispatcher process, wall 3.2 s, p50 3.0 ms/item, max 375 ms first item, cold
start 383 ms, 167 MB resident over 27 processes; an earlier run before the
per-item recording tweak gave the same counts at wall 2.8 s / p50 2.4 ms):

| | dispatcher answered | dispatcher withheld |
|---|---|---|
| recorded answered (554) | **268** | 286 |
| recorded withheld (266) | 58 | 208 |
| recorded clarification (104) | 2 | 102 |

- Status agreement 578/924 (63%): 268 both answered, 310 both declined-family.
- Dispatcher answers 328: network 119, specialist_call 132, reader 77.
- Of the 268 both-answered: **121 identical full paths** (84 `network>…` +
  37 `specialist_call>specialist:X>kind`); 11 same first token, different
  specialist (the `densities`/`densities-r2` variant split); 136 different
  first token, all accounted for: 69 `organ:relation`→`veri7vn:reader>` (the
  reader's answers, prefix only), 17 `network3`→`network` (we have only the v3
  planner), 26 relabelled steals (below), 12 `organ:math` answered by the
  calculus kernel, 5 `op:unit_convert` by units-v3, 4 `exact_router` by the
  reader, 9 others.
- **Text**: on the 114 network items where lane H recorded the live head's
  reply, 101 were answered by both and **84 texts byte-identical**; the 17
  differences are all one thing: the plan text names `densities`/`fluids`
  where the shipped network names `densities-r2`/`fluids-r2` (values identical,
  e.g. 1431 mj both ways).
- **Answers where the head withheld: 60** (the precision-guard gap; see §3).
  By head family: organ:math guards 21, specialist_call guards 8,
  unverified:factoid 12, arb:definitional 6, algebra 6, others 6. The two
  largest organ sources: geometry-v4 10, literature-v2 8. Spot-checked
  examples are correct answers ("Name the author of War and Peace" →
  "It was written by Leo Tolstoy."; "What is 15 pounds in kilograms?" →
  6.80388555 kg exact NIST factors; circle area r=3 → 28.2743): the head's
  guards police the head's own routes' false-yes history, and our organs walk
  past them. Against the exam's LANE rule (a specialist may take ≤ ~9 core
  items) this composition would fail as an admitted specialist; as a system
  it trades verdict parity for 60 more answers. That is a decision, not a bug.
- **Recorded answers we miss: 286**: organ:relation 135 (the reader's 35
  patterns), rel-* specialist stores 68 (names_v1/relations_v2 absent),
  organ:math 12, compose:bridge 12, organ:converse 10, exact_router 7,
  cube 5, integer-sqrt/gcd 6+6, algebra 6, others.
- 29 turns ended on an organ's in-domain decline (orbits 12, densities 12,
  thermo 1, geometry-v4 4) — same withheld status as the head's declines.

**Core panel, front order** (`core_report_front.json`): strictly worse —
77 answers-where-withheld (organs answer past validity stops), network full
paths 24 instead of 84, specialist full 49 instead of 37. Head order is the
right default for the core; front order is for specialist exams.

**Ten whole-family panels, front order** (harness, `var/dispatch/panels/`):

| specialist | lane's verdict (binary alone) | dispatcher | verdict |
|---|---|---|---|
| springs | 42/0/0 | 42/0/0 | same |
| units-v3 | 75/0/0 | 75/0/0 | same |
| densities-r2 | 51/0/0 | 51/0/0 | same |
| physics-r2 | 123/0/0 | 123/0/0 | same |
| chemistry-v3 | 223/0/2 | 223/0/2 | same |
| cooking-v3 | 224/0/2 | 224/0/2 | same |
| optics-v5 | 51/0/0 | 51/0/0 | same |
| astronomy-v3 | 137/0/0 (recorded) | 110/0/4 without `--specialist`; 136/0/1 with it | see below |
| calculus | 62/0/0 | 62/0/0 | same |
| soil-r2 | 36/0/0 | 36/0/0 | same |

(ok / false-yes / wrong, held-out.) **9 of 10 reproduce the lane numbers
exactly.** astronomy-v3 first came out 110/0/4 and a control run of the space
binary alone gave 111/0/3. **RETRACTED (lane W5-09): the earlier text said the
space binary "has drifted past its parity receipt". It has not.** Started with
`--specialist astronomy-v3` the binary scores 137/0/0 on that panel, as lane
S02 recorded. Neither my control run nor the dispatcher passed that flag, so the
binary answered with astronomy-v3-r2's rules (the family's fixed order). The
cause was this dispatcher's, now fixed: `--specialist` is passed through (see
`tools/dispatch/README.md`). With it the dispatcher scores astronomy-v3 136/0/1:
one item is left, "According to NASA, what is the density of Mercury?",
where the verified arbitration picks chemistry-v3 (element, 13.5 g/cm3) over
astronomy (planet, 5429 kg/m3); Oracle7's head withholds this word-sense
case (a G7 guard) and the binary alone answers it right. Putting the pinned
family first in the candidate order did not change the pick, so it is not an
order effect; it stays open.

**Arbitration activity** (three-panel instrumented pass): 212 turns reached
the rule, 113 had ≥2 candidates (mostly quantity-vs-variants duplicates with
byte-identical replies; the Mercury case is the one visible flip).

## 3. What I learned that the code and docs do not say

1. **The composition order, precisely.** The core panel's own paths are the
   head's, and the head asks the **network before any specialist** (w508,
   pre-route at MRO index 64, ahead of w504's specialist_call at 68), with a
   **validity decline stopping the cascade dead** ("26 hours a day", a
   negative length — 24 core items, including all 11 `G1_sign_kept` items: the
   fusion binary's validity rules subsume that guard). w525 (post-replace,
   index 28) adds the NEW family (densities/fluids/decay/springs/fuels) and
   network_v3 only **after the whole chain declined** ("lacks": withheld and
   not deliberate). An organ's in-domain decline does NOT stop the head: the
   cascade continues to organ:relation. The dispatcher encodes exactly this;
   front order exists because the shipped specialist verdicts reproduce under
   the intercepting composition instead.
2. **A family binary's `provenance.taken` cannot be trusted for composition.**
   The stores binary replies `taken: true, kind: off_site` to every foreign
   question ("Who wrote Germinal?" → "That's outside what I can see…"). The
   real combo's `_Organ.reply` would drop that reply (off_site is in neither
   kinds nor declines_in_domain). The dispatcher therefore applies the
   manifest accept rule itself; without it, warehouse-r2 hijacked 19 of the
   first 30 core items. The stores lane never measured the LANE rule (its
   handoff says so) — this is the shape of that gap.
3. **The precision-guard gap is the whole false-yes story on the core panel.**
   60 of 328 dispatcher answers (18%) land where the head withheld; 21 of them
   are organ:math-family guards. Spot checks say the answers are right; the
   guards encode the head's own false-yes history, not the organs'. veri7vn
   must choose per guard: port it as a verified narrow over the dispatcher
   (parity, LANE-clean) or accept the answer (domain gain, verdict change).
   My precheck also shows the fusion binary alone answers **zero** core items
   the head withheld — the network stage is already guard-clean.
4. **The fusion binary is a v2/v3 superset and relabels paths.** It answers
   the 84 v2 items byte-identically (and 17 of 18 v3 items, one needs the
   geometry kernel), but also steals ~18 specialist items at depth 1
   (springs, fuels, densities lookups) that Oracle7's v2-only network declined
   — same status and value, different path and reply text. Node names differ
   on the v3 traces (`densities` vs `densities-r2`), 17 text diffs. A v2-mode
   flag (node catalogue restricted to the v2 set) would recover both.
5. **The variants binary emits r1 organ ids.** Lane S17's kernel reuses lane
   G's organs, so `specialist:densities` appears from two binaries with
   byte-identical text; arbitration sees duplicate candidates. Harmless today
   (agree-shortcut or identical pick), but the ids should be the r2s'.
6. **The reader is cheap enough to be a stage, not a front organ**: its
   35-pattern gate refuses in ~1 ms, so the whole 924-item panel including
   ~590 reader stage calls ran in 2.8 s. 77 answers, 69 on organ:relation
   items (lane F's 60 measured within the 205-item subset + 4 exact_router +
   4 elsewhere). One reader answer where the head withheld (in the 60).
7. **The rel-* specialists are the biggest single coverage hole** (68 missed
   answers): their organs read `names_v1`/`relations_v2` stores that did not
   ship. Nothing in veri7vn can fix that without new data.

## 4. Dependencies for excellence

- **A canonical organ order** (Oracle7's standing/new family lists) as data
  the dispatcher reads. W5-09 found that moving the pinned family first does not fix the Mercury flip, so a canonical order is not shown to fix it (untested). Owner: root, one afternoon,
  from `standing_net_v1.txt` / `standing_new_v1.txt` + w504's family list.
- **v2-mode for the fusion answerer** (restrict the node catalogue) — recovers
  18 specialist paths and the network/network3 split. Owner: the fusion lane.
- **The precision guards as a decision**: port G1/G7-style guards as verified
  narrows over specialist replies, or accept the 60 answers and say so.
  Owner: root (a policy call), then a lane (S/M).
- ~~The space binary's drift~~: retracted, see section 2; there was none.
- **Accept-rule data in the distribution**: the dispatcher reads manifests
  from `upstream/` for kinds/declines/context_regex; a standalone build should
  carry those (small JSON) so it stops depending on the drop.
- **rel-* stores** (data, not code) for the remaining 68 core answers.

## 5. Proposed follow-up lanes

1. **Verified stage order** (S, sonnet): lift the dispatcher's stage machine
   (READING guard → network → specialists → reader → decline) as a HOL
   datatype mirroring `Combo.compose`/w508/w525's order, with the theorem
   "a validity decline is never answered by a later stage". Number: the 924
   core statuses reproduced by the exported function on recorded oracle
   inputs, 0 disagreements with dispatch.py's Python order.
2. **Precision guards as verified narrows** (M, opus): port the guards that
   fire on specialist replies (G1 sign, G3 date, G7 word sense) from the fold
   sources as regex-decision narrows over the dispatcher's reply, behind a
   flag. Number: dispatcher answers-where-head-withheld drops 60 → ≤ 10 with
   0 of the 268 agreements lost.
3. **Network v2 mode** (S, sonnet): node-catalogue restriction in the fusion
   answerer. Number: 18 stolen specialist paths return to `specialist_call>`,
   the 17 `network3` texts match, core full-path agreement 121 → ≥ 156.
4. **Reader coverage** (M, opus): extend the admitted-pattern set or lift
   `general_reader_v1`'s type checks over v1-store rows. Number: reader
   answers on organ:relation items 69 → ≥ 110 of 204, 0 wrong (each answer
   still row-backed).
5. **Static all-in-one distribution** (M, sonnet): the sketch below made real
   — Linux MLton rebuilds, manifests-as-data, one tarball + a smoke panel.
   Number: unpacks and scores the ten panels on a clean Linux box to the same
   ok/fy/wrong as here.

## 6. The all-in-one distribution sketch

What a static, single-install veri7vn needs on Linux (no Isabelle at runtime):

| Piece | Size | Notes |
|---|---|---|
| 19 family binaries + fusion + arb_check | 13.2 MB + 180 KB | darwin/arm64 MLton today; portable generated SML, recompile per family with Linux MLton (`build.sh` already parameterised per lane) |
| reader decide binary | 196 KB | same |
| Python glue: dispatch.py, fusion/answerer.py, reader answerer/link/fetch, upstream's exact_router_v1 + entity_linker_v2 + oracle_relstore_v1 | ~1,500 lines | stdlib only (json/re/sqlite3/fractions); Python ≥ 3.9 |
| relations_v1.sqlite3 | 3.3 GB (1.1 GB zstd shipped) | the reader's only big store; family binaries need NO stores (tables are compiled into the kernels) |
| relstore small files | 2.5 MB | prop_labels.tsv, router_patterns_v4.json, lexicon_v1.json, domains |
| accept-rule data (manifest kinds/declines/context_regex) | < 1 MB | to be extracted from upstream so the drop is no longer needed |

Runtime shape: one `dispatch.py` process (383 ms cold start, 167 MB resident)
speaking JSON lines; 21 organ subprocesses stay resident; p50 2.4 ms, p99
~370 ms (first reader linker hit). The verified core (kernel values, fusion
decision, arbitration) is ~13.6 MB of MLton binaries; everything else is
untrusted glue and one big SQLite file.

## 7. Honest status

- No Isabelle proofs were written on this branch; the verified pieces are
  lane C's arbitration (used as exported, selftest pinned) and the lanes'
  family kernels (used as built). No `sorry` introduced anywhere.
- Untrusted, named: everything in `tools/dispatch/dispatch.py` (oracle port,
  stage order, path relabelling, accept gate, fan-out), `arb_driver.sml`
  (protocol only), the fusion/reader answerers' Python.
- The counterfactual dependence count re-asks organs with +7%-nudged givens;
  it is skipped when the agreement shortcut or single-candidate case makes it
  irrelevant (a faithful mirror of the HOL rule's own short-circuits — the
  binary still decides).
- Numbers above come from: `var/dispatch/core_report.json` (924, head),
  `core_report_front.json` (924, front), `var/dispatch/panels/` (10 panels),
  `var/dispatch/panels2/` (3 panels, arbitration instrumentation),
  `var/dispatch/control-space-binary/` (astronomy-v3 control),
  `var/dispatch/fusion_precheck.jsonl` (fusion over all 924).
- The astronomy-v3 111/3 control was run without `--specialist`; `var/dispatch/control-space-binary/` records that run, not a drifted binary (retracted).
