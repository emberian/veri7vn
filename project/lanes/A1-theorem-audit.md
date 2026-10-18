# Lane A1: theorem audit

Read-only audit of every theorem and lemma statement under `src/extract/*/` and
`src/isabelle/{document,reader,routing,specialists}/`, tree `e1a3738` (after
W5-12). No theory edited, no Isabelle build.

## Result

2,234 statements in 30 directories. Classes (rules in the audit):

| Class | Count |
|---|---|
| Binding | 1,079 (533 about the kernel/reply/decision, 122 laws of the real-number model, 424 about helpers) |
| Definitional (restates the code) | 471 |
| Vacuous | 15 |
| External (leans on a fetch/recognizer flag) | 26 |
| Worked example | 134 |
| Helper lemma | 509 |

Binding share of the 1,725 claims: 63%. Of the 1,333 statements the PASS scans
name, 871 are binding, 371 definitional, 13 vacuous.

Mechanical checks (script `var/audit/markers.py`):

- no `sorry`, `oops`, `skip_proof`, `axiomatization`, `quick_and_dirty` in any session;
- `by eval` in built sessions: `Guards_Vectors.thy` (2: `vectors_pin`,
  `vectors_count`, and the theory builds after the PASS marker because `ROOT`
  lists it after `Guards_Export`) and `Specialists_Tests.thy` (11);
- markers that refuse no oracle: `Veri7vn_Specialists` and `Veri7vn_Reader`
  (bare `writeln`);
- every other marker is the export theory's last command and refuses oracles;
- 109 `theorem`-keyword facts are in no scan: computing 44, specialists 25,
  reader 18, earth 7, discrete 5, energy 3, geostats 2, guards 2, life, space,
  routing 1 each.

Two findings beyond restatement: geostats answers `s * s * s` for a negative
side (`cube_volume_value` proves it for every `s`; no decline for negative
lengths in `greason_of`), and finance's real-rate kernel states `i - p` while
`fisher_relation` proves the exact Fisher equation about a formula the kernel
never computes.

## Files

- `docs/assurance/theorem-audit.md`: summary, method, per-family table, three
  missing binding theorems per family with proposed statements, appendices
  (every vacuous and external statement; every unscanned theorem).
- `project/swarm/WAVE6.md`, `project/swarm/wave6.json`: 24 fix lanes (19 sonnet,
  5 opus), each done on "N binding theorems added, vacuous 0, unscanned 0, marker
  last with oracles=0, panel replies unchanged"; two deferred.
- Scratch (not in git): `var/audit/extract.py`, `markers.py`, `check_class.py`,
  `aggregate.py`, `dump.py`, and `var/audit/class/<family>.txt` (one class per
  statement, regradable line by line).

## Checks run

- `python3 -B var/audit/check_class.py <all 30>`: every statement classified exactly
  once, `?=0` in every family, re-run after W5-12's commits landed mid-audit
  (2,234 statements both times).
- `python3 -B var/audit/markers.py`: the marker table above.

## What it cannot tell you

The classes are my reading of the statements, with the borderline rules written
down; a second reader would move some dozens between definitional and binding
(mostly law-form value theorems). The kernel/model/helper split of binding
theorems is a name heuristic. The audit has no panel numbers of its own: it
changes no reply.

## Remaining

- Root: move the `var/audit/` scripts to `tools/audit/` if the fix lanes should
  re-run them from git (outside this lane's paths).
- Wave 6 lanes per `WAVE6.md`. The consumer is root, which launches them.
