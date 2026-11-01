# Triage 1: verification log (lane T1, 2026-10-17)

Five scout branches read; their load-bearing numbers re-run read-only from the
main checkout or the scout worktree. Nothing written under `upstream/`, no scout
worktree edited, the Oracle7 head not run. Outcomes and the next wave are in
[`project/swarm/WAVE5.md`](../swarm/WAVE5.md).

| Scout | Verified | Merged | Follow-up tier |
|---|---|---|---|
| specialist-linter | yes, with one misread finding | no, fix one finding first | sonnet (fix), opus (fold shadowing) |
| linux-binaries | yes | yes, `4eb46e9` | sonnet |
| rel-novels | yes (numbers and theorems); the framing needs a caveat | yes, `ffcdda8` | sonnet (land), opus (generalize) |
| code-organ | yes (numbers); main theorem is shallow | no, parked on its branch | none until root names a number |
| math-organ | blockers confirmed; still unbuilt; a new life is running | no | wait for its report |

Both merges moved the scout's root-level `SCOUT_REPORT.md` to
`project/scouts/reports/<name>.md` inside the merge commit, so the next report
does not collide with this one at the repository root.

## specialist-linter

| Claim | Command (shortened) | Result |
|---|---|---|
| exam.py cannot load a flat panel | `grep -n '.get(split)' upstream/workbench/exam.py` | line 149 `items = panel.get(split) or []`; line 148 joins the panel path onto the folder as written. Confirmed. |
| 304 flat panels, 304 placeholder paths | python count over `specialists/*/manifest.json` | 304 and 304 of 305. Confirmed. |
| 161 empty `context_regex`, 5 with a raw backspace | same script | 161; 5 = decay, fluids, fluids-r2, fuels, springs. exam.py line 85 uses its never-match default only when the key is missing. Confirmed. |
| no verdict carries `files_sha` | same script | 0 of 290 `verdict_heldout.json`. Confirmed. |
| 163 panels with no must-decline item | same script | 163. Confirmed. |
| core counts measured on a sample of about 400 | tally `core.n` | 400 to 406 in all 290 files; core panel has 924. Confirmed. |
| the 3 gate disagreements are the 3 specialists that took 6 | tally `core.taken_by_specialist` | max 6, exactly rel-novels, rel-graphicartists, rel-translators. Lane C's own `tools/gate/check_verdicts.py` gives the same three (dev and held-out: 476 agree, 6 disagree, 100 insufficient of 582). Confirmed. |
| "the cap it used was 5; the release was tighter than exam.py" | the same three files | **Wrong reading.** All three say ADMIT with 6 takes, so the release did not apply a cap of 5. What is true: exam.py's formula applied to a 405-question sample gives 5, the full panel gives 9, and the release admitted 6. The release was looser than the formula on its own sample, not tighter. |
| runs on three folders | `specialist-lint.py densities / rel-novels / water-r3` from its worktree | all exit 0, nothing written (checked with `find -newer` and `git status`). Output: `var/triage/lint-*.txt`. |

Code read: the gate section builds one line of counts per verdict file and pipes
them to lane C's MLton binary `var/gate/build/gate_check`; the decision and
reasons come from the binary. Honest use. The field mapping is a copy of
`tools/gate/check_verdicts.py` (untrusted glue, labelled as such). The
shadowing section is a heuristic: it tests each live pre-route fold's guard
regexes against two template sentences per routing cue and the first 25
held-out questions, calibrated by how often the guard fires on 100 core
questions. A guard match is not the fold firing (the fold's body is not run), so
"matches" is the right word and the report mostly uses it. The "not universal"
cut is 90%, so a guard firing on 66% of generic questions (`w55 _TOKEN`) is
still listed as specific in per-folder output.

## linux-binaries

| Claim | Command | Result |
|---|---|---|
| 13,786 replies identical to macOS | python diff of `var/{quantity,acoustics}/deploy-linux/*.jsonl` against `var/scout/parity-macos/*/` in its worktree, dropping `rtt_ms` and `specialist_ms` | 28 file pairs, 13,786 lines, 13,786 identical, 0 missing. Confirmed. Of those, 780 are panel items and 13,006 are core-panel probes (mostly withheld), so the strong part of the evidence is the 780. |
| fluids held-out 34/34, 0 wrong, 0 taken of 924 | read `fluids.heldout.json` | `with_specialist ok 34 fy 0 wrong 0`, `core taken 0 cap 9`. Confirmed. |
| macOS comparison used the main checkout's binaries | `run.json` | answerers are `/Users/ember/dev/o7vn/var/{acoustics,quantity}/bin/...`. Confirmed. The report quotes acoustics at 427,176 bytes; the file there is 428,056. Small slip, no effect on the result. |
| script is box-safe | grep `linux-build.sh` | MLton under `swarm-build`; only `rm -rf` is its own remote output dir; reads upstream, copies 604 KB to hbox. Fine. |

## rel-novels

| Claim | Command | Result |
|---|---|---|
| P144 absent from the store | `sqlite3 'file:...relations_v1.sqlite3?mode=ro' "select count(*) ... where p=144"` (indexed on `(p,o)`) | 0. P50 96,013; P577, P156 over 100,000; P840 74,584. Confirmed. |
| 84/120, 0 wrong, 0 false yes | count replies in its `var/scout/parity/*.items.jsonl` and verdicts | 41 dev + 43 held-out answered, all scored good; `with_specialist wrong 0, fy 0`. Confirmed. |
| 120/120 item for item with the shipped organ | compare status and value with `var/rel-novels/probe_items.jsonl` | 0 mismatches. Confirmed. |
| binary tied to the theory | build log marker vs `shasum` of the gen file | both `5a5673d4888def891c455e90726ee245ed8de57d`. Confirmed. |
| no `sorry` | grep theory | none; session ROOT sets no `quick_and_dirty`, so a green build excludes `sorry`. |

Theorems read (`answer_stored`, `decline_stored`, plus `attempt_values_sound`
and the four meaning lemmas). They are real: an answer implies the value is in
the fetched rows of an in-domain candidate, every in-domain selected candidate
has exactly that value, it is not Blank and does not restate the question; a
decline names an in-domain candidate the recognizer linked. Neither is a
tautology. Both rest on the fetch's `complete` and `dom_complete` flags, which
the untrusted Python asserts. The answerer really goes through the binary
(`decide_main.sml` calls `decide_spec`; the Python renders only).

How the kernel is tied to the organ: by agreement on the 120 panel items, not by
proof. Nothing states that `decide_spec` equals the Python organ; it is a
transcription with soundness lemmas about what any answer means.

Caveat the report omits: the shipped verdict files say the organ scored 104/120
(54 dev, 50 held-out) when it was examined on its own store. "Parity with the
shipped organ" here means parity with the shipped code running on the shipped
`relations_v1` and a labels-only linker stand-in, not with the shipped verdict.
The 24 P144 items bound what any reader over this store can reach.

Smaller gaps: the export marker is a SHA-1, not lane G's oracle-refusing PASS
marker; the gen file is fetched by hand with `scp` rather than through
`remote-build`'s pull; there is no `tables_check.py` (the answerer checks the
reader table against `readers.json` at start-up instead).

## code-organ

| Claim | Command | Result |
|---|---|---|
| 0 of 924 core items are code-route | path tally over `core_panel.json` | 0 contain `code`. Confirmed. |
| table parity 31 moves, 4 groups | `python3 -B src/extract/codeorgan/tables_check.py` (worktree) | `tables agree: 31 moves, 4 groups` (of the organ's 146). Confirmed. |
| PASS, 13 theorems, 0 oracles; self test | log grep; `codeorgan --self` | marker present; `self_test PASS`. Confirmed. |

The headline theorem `enum_well_typed` (`enum sig u ⟹ tys sig u ≠ []`) is close
to definitional: `enum`'s application rule requires `slots_ok`, which is the
same condition `tys` tests, and every move has a non-empty output list. It is
not `P ⟶ P`, but it says little beyond the definitions. Constants are always
typed int. No panel exists for this organ, as the scout says.

## math-organ

Inherited draft (commit `d11b3d3`): line 256 does read `\<open>%g\<open>`
(an open where a close was meant), and `want_perfect` is used once and never
defined. Both blockers confirmed. Branch head `2169b25` fixes both and adds ROOT
and `Math_Export.thy`, unbuilt. The worktree has uncommitted edits to `Math.thy`
and `Math_Export.thy`; the last finished remote build failed in a proof about the
integer square root (line 71). A fresh scout life (`claude -p`, cwd in that
worktree) started at 19:47 and a new hbox build began at 19:48. No `sorry` in the
branch. No panel number exists. It ran lane A's head answerer once over 87
items with its own state dir (`var/scout/oracle7-state`), which is allowed for
scouts.

## Box notes

- One `.pyc` under upstream was written today at 17:48 by Python 3.11 (the
  system `python3`): `upstream/root/wander-train/__pycache__/relation_readers_v1.cpython-311.pyc`.
  Scripts that import that module: rel-census `census.py`, rel-novels
  `answerer.py` and `probe_port.py`. Not deleted (not mine); root decides. Nothing else
  under upstream's 281 `__pycache__` folders was written in the last ten hours.
- Lint outputs from this triage: `var/triage/lint-{densities,rel-novels,water-r3}.txt`.
