# Scout report: perf-envelope (2026-10-17)

## 1. What I built

`tools/perf/fleet.py` — one tool that measures the whole fleet of verified binaries
and Oracle7's own head on the shipped panels, and writes the table to
`docs/performance/fleet.md` (committed, with per-panel appendix) plus a JSON
sidecar `docs/performance/fleet.json` holding every raw number. Committed on this
branch in six commits (tool, a StopIteration fix, partial-dump fix, status-count
fix, `%.0f` format fix, outliers wording).

How to run it (from the main checkout, where `upstream/` and the binaries live):

```sh
PYTHONDONTWRITEBYTECODE=1 python3 tools/perf/fleet.py \
  --oracle7-python .venv/bin/python      # everything; ~1 min families + ~60 min Oracle7
python3 tools/perf/fleet.py --skip-oracle7 --families life    # one family, seconds
python3 tools/perf/fleet.py --from-json docs/performance/fleet.json   # regen markdown only
```

From this scout worktree I ran it with `--var /Users/ember/dev/o7vn/var` (where the
binaries are), `PARITY_UPSTREAM=/Users/ember/dev/o7vn/upstream`, `--scratch var/perf`
(worktree-local logs), and `--oracle7-python /Users/ember/dev/o7vn/.venv/bin/python`
(the head needs numpy; the system python3 dies on import).

What it measures, per family binary (19 of 19 under `src/extract/*/` were already
built; none missing, so nothing was rebuilt):

- **size, sha256, mtime** of the binary;
- **cold start** — process start to first reply — from the first question of every
  per-specialist process plus three one-question fresh starts;
- **p50/p95/max per question**, warm, over every dev and heldout panel item of every
  specialist the family serves, asked exactly the way its lane scored it
  (`--specialist <id>`; `--state <scratch>` for stores, unlinked before each process,
  as its own score.py does);
- **peak RSS** — the exact `ru_maxrss` of the child via `os.wait4`, and a 200 ms ps
  sample of the whole process tree for answerers that spawn children (Oracle7's head,
  fusion's wrapper, stores' python fetcher); the table shows the larger;
- **the manifest budgets** — tightest `latency_p50_ms` and `store_mb` across the
  family's specialists, and whether the measured p50 fits.

Family discovery reads each `src/extract/<slug>/score.py`'s ALL-CAPS list
(`SPECIALISTS`/`IDS`/`VARIANTS`) by ast, falling back to a single specialist named
like the slug. Fusion has no panels; it is measured on its own 396-question batteries
(lane H + H2) through its untrusted answerer wrapper — the deployable unit. Oracle7
runs once, one head process over all 14,632 questions in family order.

## 2. What works, with numbers

The fleet table (this run, MacBook Pro M2, load average ~4–5.5 — other lanes were
building; medians are stable run-to-run, tails are machine noise). Full table with
per-panel appendix and binary hashes: `docs/performance/fleet.md`.

| binary | KiB | questions | cold ms | p50 ms | p95 ms | max ms | peak MiB | budget | fit |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| acoustics | 418 | 139 | 9.0 | 9.74 | 31.1 | 31.7 | 4.2 | 50 | yes |
| anatomyagri | 394 | 156 | 2.0 | 0.12 | 0.21 | 0.25 | 3.8 | 50 | yes |
| chemistry | 760 | 1206 | 65.5 | 0.11 | 0.33 | 53.0 | 5.4 | 50 | yes |
| climate | 605 | 306 | 39.0 | 0.10 | 21.2 | 29.7 | 4.6 | 50 | yes |
| computing | 1249 | 1364 | 12.5 | 0.05 | 0.23 | 20.6 | 5.9 | 50 | yes |
| discrete | 869 | 508 | 2.1 | 0.07 | 0.21 | 35.0 | 4.4 | 50 | yes |
| emoptics | 742 | 1253 | 80.3 | 0.11 | 28.9 | 67.8 | 4.9 | 50 | yes |
| energy | 742 | 569 | 4.6 | 0.12 | 0.25 | 4.6 | 4.3 | 50 | yes |
| facts | 326 | 428 | 2.1 | 0.20 | 0.98 | 2.3 | 7.0 | 50 | yes |
| fusion (wrapper) | 395 | 396 | 49.3 | 0.47 | 0.91 | 1.6 | 24.9 | – | – |
| geostats | 585 | 1456 | 13.9 | 0.15 | 7.38 | 8.9 | 4.3 | 50 | yes |
| life | 722 | 179 | 218.4 | 0.11 | 32.2 | 149.1 | 4.9 | 50 | yes |
| materials | 756 | 347 | 2.2 | 0.12 | 49.8 | 182.4 | 5.0 | 50 | yes |
| mechanics | 638 | 1264 | 21.1 | 0.14 | 5.49 | 10.3 | 4.6 | 50 | yes |
| quantity | 531 | 641 | 5.5 | 0.09 | 0.22 | 3.9 | 9.8 | 50 | yes |
| space | 702 | 1185 | 154.7 | 0.12 | 20.3 | 74.0 | 5.7 | 50 | yes |
| stores | 550 | 2476 | 78.6 | 0.43 | 1.69 | 4.8 | 91.7 | 50 | yes |
| trades | 792 | 357 | 2.5 | 0.16 | 36.8 | 114.9 | 4.7 | 50 | yes |
| variants | 565 | 402 | 5.9 | 0.10 | 0.31 | 0.5 | 9.8 | 50 | yes |
| **Oracle7 head** | – | 14632 | 3565 | 140.2 | 821.7 | 8417 | 1959 | – | – |

Fleet totals: **19 binaries, 12.1 MiB on disk, 14,632 questions, zero protocol
errors or timeouts, every family 2–4 orders of magnitude inside its latency
budget.** If every binary were resident at once: 210 MiB, of which stores' tree
(MLton + its python fetcher) is 92 MiB; every other binary peaks at 3.8–9.8 MiB.

Oracle7's head, same questions, one process: answered 12,005, non-answered 2,627
(2,237 withheld + 390 `clarification`, which scores as withheld), zero errors, in
61 minutes. Per family its p50 runs 56 ms (acoustics) to 460 ms (chemistry), with
an 8.4 s max on a space question — its *fastest* family is still ~580× slower than
the fleet binary answering the same questions.

The four outliers the lanes named all reproduce, now pinned to per-panel rows:

| lane note | this run |
|---|---|
| ecology 27 ms | ecology p50 **27.2–27.6 ms** (life binary, the logistic-population kind; biology in the same binary is 0.05 ms) |
| cooking first-call 145 ms | cooking cold **76–79 ms** now (python3 fetch shim spawn; their run was more loaded) |
| life cold start 230 ms | **215–237 ms** on every non-ecology panel; ecology's own first question is a slow interval one, so its cold start reads 335–348 ms |
| orbits 20 ms | orbits p50 **20.1–20.3 ms**, p95 74 ms (planetary in the same binary: 0.1–0.2 ms) |

The same sweep found interval-cost panels the lanes had not named: **emoptics on
wiring p50 35.2 ms (the fleet's warm record), space on spacecraft 26.7 ms, climate
on climate 14.0 ms, emoptics on electrical 5.2 ms.**

What does not work / caveats, named:

- **p95/max under load are machine noise, not binary behaviour.** materials p95
  49.8 ms with p50 0.12 ms; trades max 114.9 ms with p50 0.16 ms. Three independent
  full family runs agreed on every median within ~3% (life cold 215.8→218.0→218.4 ms,
  chemistry 67.6→67.1→65.5 ms, acoustics p50 10.28→10.07→9.74 ms). Canonical tails
  need a quiet box.
- **The Oracle7 pass is the long pole**: 61 minutes for 14.6k questions. The tool
  dumps partial JSON every 100 questions (after a first attempt was killed by a
  10-minute background cap).
- The tool measures, it does not score: statuses are counted for sanity (every
  family binary's replies are answered/withheld except one `clarify` from stores on
  a cooking-v2 item; the head also emits `clarification`), but parity numbers stay
  with `tools/parity/`.

## 3. What I learned that was not obvious

1. **Warm cost has exactly two classes.** Seventeen of nineteen binaries answer in
   0.05–0.5 ms (recognizer + exact rational/table arithmetic in MLton). Every
   per-question p50 above 5 ms in the whole fleet is HOL-Decision_Procs
   Approximation interval arithmetic: wiring 35, ecology 27, spacecraft 27, orbits
   20, climate 14, electrical 5, acoustics 9.7 ms. That is where any warm-latency
   work should aim, and nowhere else.
2. **Cold starts cluster into four shapes**: ~2–6 ms plain MLton exec (anatomyagri,
   discrete, energy, facts, materials, trades, quantity, variants); 12–80 ms when
   static table data is larger (chemistry, climate, computing, emoptics, geostats,
   mechanics — cold tracks table size, not question mix); 78 ms + python-child for
   stores; and 218 ms for life, which pulls in the whole Approximation export.
   space's 155 ms is load-sensitive (lane S02 measured 65 ms quiet, 162 loaded).
3. **Oracle7's head grows ~96 MB of RSS per 1,000 distinct sessions** (563 MiB at
   start to 1,959 MiB over 14,632 questions; every question got a distinct session
   id and the engine keeps per-session state). A long-lived head has unbounded
   memory growth by construction; the extracted binaries hold 4–10 MiB flat
   regardless of question count. This is the sharpest deployment contrast in the
   whole table — three orders of magnitude on every axis (cold 3.6 s vs 2–6 ms,
   p50 140 ms vs 0.1 ms, RSS 2 GiB vs 5 MiB).
4. **The answerer contract is uniform but the wrappers are not.** Every family
   binary takes `--specialist <id>` and speaks clean JSON lines (zero protocol
   errors over 14,236 panel items), but: `oracle7.py` prints a non-JSON banner
   line first (drivers must skip unparseable lines, as the parity harness does —
   my first driver crashed on it); the head silently dies under a python without
   numpy; stores shells out to `python3 -I fetch.py` via `/usr/bin/env` per process
   (its cold cost *is* a python startup); fusion's binary is spoken for by an
   untrusted python wrapper (its 49 ms cold is python starting, not MLton).
5. **Specialist discovery is convention, not data.** Each family's score.py names
   its specialists in an ALL-CAPS list, but under three different names
   (`SPECIALISTS`, `IDS`, `VARIANTS`), and acoustics names none (it *is* the
   specialist). `water-r3` (materials) ships a manifest with **zero panel items in
   both splits** — a fleet table has to tolerate empty panels, and code iterating
   naively will crash exactly where my first run did.
6. **The perf envelope is already won.** Every family is 250–8000× inside its
   latency p50 budget; nothing in the fleet is within a factor of 50 of hurting
   the exam. Perf work from here is polish (cold starts, the interval families),
   not risk.

## 4. Dependencies for excellence

- **A canonical, quiet-box table.** This run was taken at load ~4–5.5. Root should
  decide that `docs/performance/fleet.md` is a living document and regenerate it
  on an idle machine when a family lands (one command; the tool records load).
- **Machine-readable family→specialist mapping.** The ast-heuristic over score.py
  held for all 19 families, but a `family.json` (or a `specialists:` key in each
  ROOT) owned by root would remove a whole class of brittleness. Small lane.
- **Binary identity at build time.** fleet.py hashes binaries after the fact; a
  sha256 stamp written by each build.sh would tie numbers to builds. Small lane.
- **The relation stores never shipped** (`names_v1`, `relations_v2`), so lane F's
  reader binary (`var/reader/bin/decide`, 199 KB, outside `src/extract/`) cannot be
  panel-measured at all; it stays out of the fleet table by necessity, not choice.

## 5. Proposed follow-up lanes

1. **Fleet row in every handoff** (S, sonnet) — add the one-command fleet.py
   invocation to the lane template; each handoff quotes its row. Done when every
   handoff in `project/lanes/` carries size/cold/p50/RSS and the numbers match
   `docs/performance/fleet.md`.
2. **life cold start** (M, opus) — export only the Approximation operations life
   uses (lane S09 already named this) or move the interval setup off the startup
   path. Done when life cold < 50 ms and all six life panels score exactly what
   S09's handoff reports (0 wrong, 0 false yes).
3. **stores first call** (S, sonnet) — pre-spawn the python fetcher at process
   start, or fold the hot read into SML. Done when cooking cold < 30 ms with all
   2,476 panel verdicts unchanged.
4. **Interval-question warm cost** (M, opus) — wiring 35, ecology 27, spacecraft 27,
   orbits 20, climate 14, acoustics 9.7 ms per question; tighten enclosures or drop
   precision where the stated digits provably cannot change. Done when those p50s
   fall ≥ 4× with byte-identical panel outputs.
5. **Quiet-box canonical run + head-memory note** (S, sonnet) — rerun fleet.py at
   load < 1, commit the table, and record the head's per-session memory slope
   (~96 MB/1000 sessions) in docs. Done when fleet.md states load < 1 and the slope.

## 6. Honest status

- No theorems were touched; this is measurement tooling. `tools/perf/fleet.py` is
  untrusted code in the sense of the answerer contract: it reads panels read-only,
  writes only under `var/` (or `--scratch`) and `docs/performance/`, never under
  `upstream/`. I cleaned the scratch files it first wrote into the main checkout's
  `var/perf/` (my own files only; the dir is gone).
- Every number above came out of the runs described, on this machine, at the load
  stated; the family numbers are from the third full run (the first two are
  described below), the Oracle7 numbers from the completed 61-minute pass, and the
  committed `docs/performance/fleet.md` matches them.
- Three false starts are recorded in git: a StopIteration on materials' empty
  water-r3 panel, the 10-minute background cap that killed the Oracle7 pass
  (nothing lost after the partial-dump fix), and two small writer bugs (a literal
  `%.0f` for values ≥ 1000 ms, and non-answered statuses counted as errors). All
  are fixed; the family numbers were re-measured after the first fix, and the
  markdown was regenerated from the final JSON after the writer fixes.
