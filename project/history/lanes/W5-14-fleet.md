# W5-14 One family registry, then a quiet fleet run

## Done

`src/extract/families.json` lists the 20 committed families that have a built
binary (19 specialist families and fusion), one entry each: `family`,
`session` (the Isabelle session whose PASS marker gates the build; variants
has none of its own and reuses `Veri7vn_Quantity`), `binary`
(`var/<slug>/bin/<slug>`), `specialists` (131 ids in all), `specialist_flag`
(false for acoustics and fusion), `state_flag` (stores), `build`. Untracked
`earth` (8 specialists) and `finance` (5) are not listed on purpose.
`relations`, `rel-novels` and `commons` are not specialist families and are not
listed.

The lists were taken from the old `score.py` parse in both tools, which agreed
with each other for every family, and every id was confirmed in a lane
document or the family README. The only difference from what the tools found
before is the two untracked families dropping out (old `make_organ.py --list`:
144 specialists in 21 families; now 131 in 19). Humanities (7 specialists) was
already found by both tools; it was missing from the scout's table only
because its binary was built later.

## Tool changes

`tools/perf/fleet.py`: `discover()` and the specialist lists read the
registry; `--var` still moves the binary root; the `--specialist` and `--state`
flags come from the registry entry; `missing_binaries` is now a list of slugs;
the two outlier sentences are computed (cold starts: "the other N binaries
start in X ms or less"; slow warm panels: the range of all other panels and
which of the slow families import `HOL-Decision_Procs.Approximation` in their
sources, instead of the unchecked "all of them interval arithmetic").
CLI unchanged. A 2-item smoke run over anatomyagri, stores and acoustics worked.

`tools/organs/make_organ.py` (small, backward compatible; for W5-10): new
`REGISTRY` dict read from `families.json` at import; `NO_FLAG` is derived from
it; `family_tables()` still parses `score.py` (it fills `EXTRA`, which
`make_organ()` needs for water-r3's panel) but returns the registry's lists,
and prints a warning on stderr if a score.py list differs from the registry.
`--list` output is unchanged for the 19 families. CLI unchanged.

## Fleet run

Status: pending. The machine never fell below load 3 in 70 minutes (other
lanes' builds). A background job waits for load below 1 and then runs
`fleet.py --skip-oracle7` once: script `var/perf/run514.sh`, PID file
`var/perf/run514.pid`, log `var/perf/run514.out`, output
`var/perf/fleet-w514.json` and `var/perf/fleet-w514.md`. Nothing under
`docs/` or the existing `var/perf/fleet.json` is touched until root moves it:

    python3 -B tools/perf/fleet.py --from-json var/perf/fleet-w514.json --markdown docs/performance/fleet.md

after copying the Oracle7 head record (`oracle7`, `oracle7_python`) from
`var/perf/fleet.json` (kept as `var/perf/fleet-before-w514.json`) into the new
JSON. The head row is not re-measured.
