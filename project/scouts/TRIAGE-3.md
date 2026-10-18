# Triage 3: verification log (lane T3, 2026-10-17)

Three scout branches read: `organ-wrappers`, `commons`, `perf-envelope`, and
W5-09's open Mercury item. Scratch under `var/triage/t3/`. No scout worktree
edited. Nothing written under `upstream/` (`find upstream -newer
var/triage/t3/.stamp` empty after every run). The Oracle7 head ran once, by
root's grant, for eight questions. Outcomes and new lanes are in
[`project/swarm/WAVE5.md`](../swarm/WAVE5.md).

| Scout | Verified | Merged | Follow-up |
|---|---|---|---|
| organ-wrappers | yes: two verdict files re-read, folder layout matches lane D's | yes, `0e96ff5` | W5-10 (package for Oracle7's author), W5-11 (front board) |
| commons | yes: three sessions rebuilt fresh on hbox/persvati, 641/641 and 139/139 replies identical; duplication counts hold in shape, two totals off | yes, `2b53bd0`, plus two consumers fixed on dev (`6509730`, `1aab277`) | W5-12 (migrate the other families) |
| perf-envelope | yes: three binaries and the head's cold start re-measured | yes, `90db133`, JSON kept out of git, plain-words paragraph added | W5-14 (registry + quiet re-run); life cold start and interval cost parked |

## organ-wrappers

Verdict files read in place under
`var/scout-wt/organ-wrappers/var/scout/trials/<id>-veri7vn/verdict_dev.json`:

| Organ | decision | reasons | head ok/fy/wrong | composite ok/fy/wrong | core taken | report |
|---|---|---|---|---|---|---|
| units | WOULD FAIL | `WRONG: 14 answered wrong, cap 1` | 39/0/14 | 61/0/14 | 6 of 924 (cap 9) | same |
| law | WOULD FAIL | `DOMAIN: gain 1, needs 3`, `WRONG: 2 answered wrong, cap 1` | 6/0/2 | 7/0/2 | 0 | same |

The other three (acoustics, git, orbits) also match the table. Every recorded
fail in the units, law, orbits and git verdicts has `"by": "core"` (the head);
exam.py keeps at most 12 fails per verdict, so for units 12 of the 14 are
visible, and `with_specialist.wrong == head.wrong` covers the rest. 11 of the
12 units fails are exact-fraction prose ("250 cm is 12500/127 inches") that the
shipped scorer reads as 12500: the head's number is right, the scorer misreads
its format. "The head's wrong answer" in the report means "wrong by the shipped
scorer". Front-composition files under `var/scout/front-parity/` match the
report's second table on all ten rows (e.g. orbits held-out head 3/1/23,
composed 35/0/0).

Layout against lane D's `src/extract/acoustics/oracle7-organ/`: same six files.
Panel and scorer byte-identical (`cmp`); manifest differs only in the `notes`
sentence and the added `veri7vn` block (family, binary, env var, argv,
source); the wrapper differs only by an `ARGV` list (empty for acoustics). The
units folder has the same shape, the wrapper starts `quantity --specialist
units`, and NOTICE names the copied files and their owner.

On dev, `make_organ.py --list` finds 144 specialists in 21 families, not 124
in 18: humanities (committed since) adds 7, and `src/extract/earth/` and
`finance/` (untracked, someone's work in progress) add 13. A generated
package must be built from committed families only.

Merged: new files only.

**What the folder still needs before Oracle7's author can use it** (W5-10):

1. A binary he can run. Today the README says "build the program in a
   veri7vn checkout". He has none. Ship built binaries: Linux from W5-04
   (`tools/deploy/linux-build.sh`, hbox's Isabelle MLton) and macOS from the
   lanes, one per family, in a shared `specialists/_veri7vn/bin/<os>-<arch>/`
   rather than copied into 144 folders (facts alone serves 22). The wrapper's
   search order gains that path.
2. README wording for him, not for us. Say what the folder is (a copy of his
   own specialist, answered by a program whose formulas and refusals are
   proved), what is proved and what is not (recognizer and wrapper are
   untrusted), and what his exam will say: behind his w540 head, exam.py
   reports WOULD FAIL for every clone, because the head already contains the
   original specialist (gain starved) and exam.py charges the head's own
   wrong answers to the composite. Give the front-composition numbers
   beside it so the verdict is not read as an organ defect.
3. A note on exam.py's fail lists: they print `expected: (decline)` for every
   item (it reads `a`, the shipped panels use `expect`). His code, his call;
   we only point at it.
4. The `stores` organs (cooking, warehouse) depend on the checkout path
   (`Config.repo`, a python fetcher, `--state`). Leave them out of the
   package or fix relocation first.
5. One NOTICE and licence statement for the package, reviewed once.

## commons

**Rebuilt fresh, from a `git archive` of the branch** (`var/triage/t3/commons-check`;
the remote tree name differs from the scout's, so nothing cached was reused;
every log shows `Building ...` then `Finished ...`):

```
tools/dev/remote-build hbox src/extract/quantity Veri7vn_Quantity --expect 'VERI7VN_QUANTITY PASS' -d src/extract/commons
  -> exit 0; VERI7VN_QUANTITY PASS theorems=47 oracles=0   (Veri7vn_Quantity 1:30 elapsed)
tools/dev/remote-build persvati src/extract/acoustics Veri7vn_Acoustics --expect 'VERI7VN_ACOUSTICS PASS' -d src/extract/commons
  -> exit 0; VERI7VN_ACOUSTICS PASS theorems=28 oracles=0  (0:22)
tools/dev/remote-build hbox src/extract/fusion Veri7vn_Fusion --expect 'VERI7VN_FUSION PASS' -d src/extract/quantity -d src/extract/commons -d src/extract/energy -d src/extract/climate -d src/extract/space
  -> exit 0; VERI7VN_FUSION PASS theorems=32 oracles=0     (4:24)
```

`Commons_Num` is checked inside each family session (`theory
Veri7vn_Commons.Commons_Num 100%`), so these receipts cover it.

Generated SML sha256 equals the scout's (quantity `5868f0e5...`, acoustics
`7d369ead...`). MLton binaries from the remote exports: 544,184 and 429,080
bytes, the report's sizes.

| Family | Command | Result |
|---|---|---|
| quantity, 6 specialists | `harness.py --answerer "<new> --specialist {id}"` both splits, and the same with dev's `var/quantity/bin/quantity`; reply records compared without `specialist_ms` | **641 / 641 identical**; 641 right, 0 wrong, 0 false yes |
| acoustics | same | **139 / 139 identical**; 139 right, 0 wrong, 0 false yes |

**Duplication, my own count** (at the scout's base `7fe029c`, and on dev):

| Claim | My count | Verdict |
|---|---|---|
| `regex.sml`: 12 of 17 copies byte-identical | 12 of 17 share sha `0187a0fb` (265 lines); facts, stores, chemistry, discrete, acoustics differ. Dev now has 20 copies (humanities, and untracked earth, finance), 14 identical | confirmed |
| "4,197 lines on disk" | the 17 copies are **4,475** lines | wrong total |
| `main.sml`: 18 copies, "~3,400 lines", ~22 lines differ between two | 18 copies, **3,782** lines; quantity against climate / mechanics / trades / energy / geostats differ by 26 / 22 / 26 / 30 / 32 changed lines (both sides counted) | shape confirmed, total off |
| Isabelle core: 90 items in ≥2 families, 35 identical everywhere, ~1,312 duplicated lines | method-dependent; not reproduced exactly. Item by item for the 38 items now in `Commons_Num.thy`: each appears in 8 to 12 families (`pow10`, `dec_val`, `round_at`, `round_sig`, `digit_lit`, `lit`, `I`, `Q` identical in all), a few have 2 to 8 drifted bodies (`apos` 8, `show_int` 5, `midpoint_close` 5); together 1,882 lines across families | confirmed in substance |

**Consumers the branch did not update, fixed on dev after the merge.** The
branch deletes `quantity/regex.sml` and moves Json out of `quantity/main.sml`.
Two other build scripts used them:

- `tools/deploy/linux-build.sh` (lane W5-04's tool) linked
  `src/extract/<slug>/regex.sml` and built the session without the commons
  `-d`. Fixed (`6509730`): `-d src/extract/commons` when the family ROOT names
  `Veri7vn_Commons`, `commons.sml` when the family has no `regex.sml`. Run on
  persvati from a `git archive` of dev: acoustics session PASS, 70/70 and
  69/69, **1,997 replies identical** to the macOS run.
- `src/extract/variants/build.sh` reuses lane G's export, recognizer and
  driver. Fixed (`1aab277`): links `commons.sml`, exports with the commons
  `-d`. The same `.mlb` compiled from the hbox export: **402 / 402 replies
  identical** to dev's current variants binary over densities-r2, units-v2,
  units-v3-r2, both splits.

Dev's binaries under `var/quantity/bin`, `var/acoustics/bin`,
`var/variants/bin` are still the pre-port builds; they answer identically, and
a laptop rebuild needs the local session database rebuilt with the commons
`-d` (`check-native`).

Not adopted from the report: the commons session has no self-check marker of
its own yet (its theorems are witnessed through the importers' `oracles=0`
checks); W5-12 adds one. The harness's two failure modes the scout hit (a
swallowed `NoneType.get` when `upstream/` is missing; a dirty `--out` replays
an old error) are real and belong to whoever holds `tools/parity/`.

## perf-envelope

Re-measured from a scratch tree (`var/triage/t3/perfroot`, the branch's
`fleet.py` with `tools/parity`, `tools/fusion`, `src` linked to dev), load
average 3.4 (the scout's run: 6.0 at start, not "4 to 5.5" as the report
says). Same binaries: sha256 prefixes `e325a682`, `2b66ec35`, `b9a57826`
equal the table's.

| Binary | cold ms (mine / scout) | p50 ms | p95 ms | peak MiB |
|---|---|---|---|---|
| acoustics | 10.6 / 9.0 | 9.76 / 9.74 | 31.4 / 31.1 | 4.2 / 4.2 |
| life | 219.9 / 218.4 | 0.11 / 0.11 | 32.3 / 32.2 | 4.9 / 4.9 |
| quantity | 5.5 / 5.5 | 0.10 / 0.09 | 0.24 / 0.22 | 9.8 / 9.8 |

Oracle7 head, once, through `tools/parity/answerers/oracle7.py` (state under
`var/parity/state/`, removed on exit), eight acoustics questions:
`--families acoustics --limit-per-specialist 4 --oracle7-python .venv/bin/python`:
first reply **3,844 ms** (scout 3,565), p50 71 ms over seven warm questions
(scout's acoustics p50 56 ms), peak 448 MiB after eight sessions. The report's
"563 MiB at start" is not reproduced (448 here; the ps sample runs every
200 ms); the growth to 1.96 GB over 14,632 sessions was not re-run. "12.1 MiB"
is 12,341 KiB summed from the table (12.05 MiB).

Merged with three changes: `docs/performance/fleet.json` (0.8 MB of
per-question latencies) stays out of git; the tool's default is now
`var/perf/fleet.json`, where the scout's copy sits for `--from-json`. The page
opens with a plain-words paragraph that the tool computes from the run. The
head's command line prints relative to the checkout (it printed the scout's
worktree path). `fleet.md` was regenerated from the scout's JSON; every table
is unchanged.

Prose in the generator that is not computed: "all of them interval arithmetic"
for every panel above 5 ms p50, and "everything else is 80 ms or less" for cold
starts. True of this run; a later run can make them false. W5-14 should compute
or drop them.

## Mercury: arbitration cue or Oracle7's own behaviour?

The open item in `project/lanes/W5-09-dispatcher.md`: astronomy-v3 held-out is
136/0/1 through the dispatcher; "According to NASA, what is the density of
Mercury?" gets chemistry-v3's 13.5336 g/cm3 instead of astronomy-v3's 5429.

What the arbitration saw (`var/triage/t3/mercury.py`, a wrapper that prints
the dispatcher's candidates, run with `--order front --specialist astronomy-v3`):

```
chemistry-v3  dep 0  invented no  wording (0, 2)  ctx False  val 13.5336
astronomy-v3  dep 0  invented no  wording (0, 0)  ctx True   val 5429.0
```

The key is (dependence, not invented, wording, vocabulary), first difference
wins. With no givens, dependence is 0 for both; chemistry's reply repeats two
question trigrams ("density of Mercury"), astronomy's none, so wording decides
before the context cue is looked at. That order is combo_runtime_v1's own code
(`_arbitrate`), and `Arbitration.thy` models the code, not the docstring
(its header says so). The shipped chemistry-v3 organ, run read-only, gives the
same reply ("The density of Mercury (Hg) is 13.5336 g/cm³, per PubChem."), and
w504's standing family (`_gate/standing_v1.txt`) holds both astronomy-v3 and
chemistry-v3. So the same two replies in Oracle7's own Combo would rank the
same way (inferred from the code and the replies; I did not run the shipped
Combo). Why the w540 head withholds here was not traced.

**Recommendation: do not add a context cue to the verified arbitration.** It
would make `Arbitration.thy` stop modelling Oracle7's arbitration, and it
would move other picks with it. The miss is the dispatcher's composition, not
the rule. The release examines a specialist by putting that specialist alone
in front of the head; the panel's 137/0/0 is measured that way. The
dispatcher with `--specialist` still asks every family and arbitrates among
them. In pinned front order it should ask the pinned specialist first, on its
own, and send the turn to the rest of the cascade only when that specialist
does not take it. Oracle7 fixed the analogous Mercury case itself by
narrowing organs (w525: densities-r2 and astronomy-v3-r3 go silent on a
capitalised name), never by changing arbitration; a chemistry narrowing
would break parity with shipped chemistry-v3, so it is not ours to add. Lane
W5-13.

## Claims not verified

- organ-wrappers: the 124-folder smoke run (0 load failures), the three
  non-re-read verdicts beyond their headline counts, the "Git!" and
  optics-v5 head misfires by name, multi-folder `exam_dev.py`.
- commons: the scout's exact Isabelle duplication census (90 / 35 / 1,312;
  my method gives different raw counts), the "~6,300 lines" migration saving,
  `regex_test.sh` against `commons.sml`, `tables_check.py` on the ported
  `Quantity.thy`, the persvati build of acoustics on the scout's own tree.
- perf-envelope: the 61-minute head pass (memory growth, 140 ms p50, 8.4 s
  max), the 16 other binaries, the four outlier reproductions, quiet-box
  numbers.
- Mercury: why the w540 head withholds this question.

## What scouts got wrong

- organ-wrappers: "every wrong answer is the head's" is right by the scorer,
  but 11 of the 12 visible units fails are the head's right number in
  fraction form, misread by the shipped scorer. Discovery saw 18 families on
  its base; dev has 19 committed (and 2 untracked).
- commons: `regex.sml` total 4,475 lines, not 4,197; `main.sml` 3,782, not
  ~3,400. The branch left two consumers of `quantity/regex.sml` broken
  (linux-build.sh, variants/build.sh); fixed on dev.
- perf-envelope: load average stated as 4 to 5.5 (the JSON says 6.0 at
  start); a 0.8 MB raw-data file committed under `docs/`; the head's command
  line carried the worktree path.
