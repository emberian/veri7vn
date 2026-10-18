# W5-12: every family on commons

Lane W5-12, 2026-10-17, branch dev, commits `[lane W5-12] ...` (21, unsigned, not pushed).

## What it does

Every family kernel that carried its own copy of the numeric core, the
regular-expression matcher or the JSON framing now takes them from
`src/extract/commons/`: `Commons_Num.thy` (session `Veri7vn_Commons`, imported
by the family theory, listed in the family ROOT `sessions`, `-d src/extract/commons`
in `build.sh`) and `commons.sml` (listed in the `.mlb` instead of `regex.sml`;
`main.sml` lost its Json block). The generated SML keeps its shape, so
recognizers are untouched, except facts (below). Nothing about what any binary
answers changed: 0 of 247,000 recorded replies differ.

## Result per family

Replies compared = every recorded reply of the before binary against the
rebuilt one, both panel splits plus the core-panel ("lane") pass, with only
`provenance.specialist_ms` and `rtt_ms` ignored. Before binaries are the ones
in `var/<slug>/bin` at the start of the hour (their sources equal HEAD's
`8e6c4d9`), copied to `var/commons/before-bin/`. Theorems before and after are
equal in every family: no `*_Export.thy` theorem list was touched, and the
fresh marker's count is the list's length. Every marker printed `oracles=0`.

| family | panel items | replies compared | changed | marker (fresh remote build) | theory lines removed | regex.sml lines removed | main.sml lines removed |
|---|---|---|---|---|---|---|---|
| anatomyagri | 156 | 9,446 | 0 | `VERI7VN_ANATOMYAGRI PASS theorems=50` | 16 | 265 | 122 |
| chemistry | 1,206 | 10,496 | 0 | `VERI7VN_CHEMISTRY PASS theorems=47` | 224 | 272 | 122 |
| climate | 306 | 11,454 | 0 | `VERI7VN_CLIMATE PASS theorems=79` | 160 | 265 | 122 |
| computing | 1,364 | 18,086 | 0 | `VERI7VN_COMPUTING PASS theorems=65` | 222 | 265 | 122 |
| discrete | 508 | 9,798 | 0 | `VERI7VN_DISCRETE PASS theorems=70` | 42 | 277 | 122 |
| emoptics | 1,253 | 17,975 | 0 | `VERI7VN_EMOPTICS PASS theorems=54` | 222 | 265 | 122 |
| energy | 569 | 11,717 | 0 | `VERI7VN_ENERGY PASS theorems=92` | 216 | 265 | 122 |
| facts | 428 | 41,304 | 0 | `VERI7VN_FACTS PASS theorems=36` | 0 (SML only) | 281 | 122 |
| geostats | 1,456 | 12,604 | 0 | `VERI7VN_GEOSTATS PASS theorems=71` | 165 | 265 | 122 |
| humanities | 394 | 13,400 | 0 | `VERI7VN_HUMANITIES PASS theorems=110` | 101 | 275 | 122 |
| life | 179 | 11,327 | 0 | `VERI7VN_LIFE PASS theorems=81` | 216 | 265 | 122 |
| materials | 347 | 9,637 | 0 | `VERI7VN_MATERIALS PASS theorems=64` | 200 | 265 | 122 |
| mechanics | 1,264 | 17,986 | 0 | `VERI7VN_MECHANICS PASS theorems=64` | 243 | 265 | 122 |
| space | 1,185 | 16,049 | 0 | `VERI7VN_SPACE PASS theorems=48` | 123 | 265 | 122 |
| trades | 357 | 11,505 | 0 | `VERI7VN_TRADES PASS theorems=28` | 240 | 265 | 122 |
| stores (SML half) | 2,476 | 13,624 | 0 | `VERI7VN_STORES PASS theorems=37` | 0 | 265 | 0 (own json.sml kept) |
| fusion (SML half) | see below | see below | 0 | `VERI7VN_FUSION PASS theorems=32` | 17 changed in place | none | 63 |
| commons itself | | | | `VERI7VN_COMMONS PASS theorems=11` | | | |
| quantity (re-run after the commons.sml change) | 641 | 11,789 | 0 | not rebuilt (theory unchanged) | | | |
| acoustics (same) | 139 | 1,997 | 0 | not rebuilt | | | |

Totals: about 2,400 theory lines, 4,285 `regex.sml` lines and 1,893 `main.sml`
lines deleted across the 17 directories (lines added back: about 100 in
`commons.sml`'s merged engine, a few import lines, comments).
Panel verdicts (right / wrong / false yes, per specialist and split) are the
same files before and after, so every family's shipped-panel numbers are
unchanged; for example chemistry heldout still shows its 2 wrong, which the
before binary had too.

Fusion: `tools/fusion/measure.py` run before and after (with the ported
energy, climate, space and fusion binaries): the whole output file is equal
modulo timing. Part A: 101 of the 102 network replies are the same text as
Oracle7's, one is declined ("needs geometry-v4"), the 12 validity declines
match. Parts B, C and D unchanged. `Veri7vn_Fusion` was rebuilt fresh on
persvati after the energy, climate and space ports: `VERI7VN_FUSION PASS
theorems=32 oracles=0`.

## What was not mechanical

- `commons.sml` Regex grew to cover the four private engines. Three case modes:
  `compile` (unchanged default), `compileCS` (chemistry, humanities), `compileI`
  (Python re.I and `(?-i:...)`, facts), plus backreferences `\1`..`\9` and
  `matchHere` (discrete). The recognizers of chemistry, humanities and discrete
  were not edited; facts' four `Regex.compile` calls became `Regex.compileI`.
  `regex_test.sh` passes, quantity and acoustics replies stayed identical.
  One behavior change for a pattern that nobody uses: a `\1`..`\9` in a pattern
  is now a backreference, where the old canonical engine read it as the digit.
- Same name, different meaning: materials and space define `enclose`,
  `render_fixed` (and space `to_dec`) with other arguments than the commons
  ones; those commons names are hidden in the family (`hide_const (open)`,
  `hide_fact (open)`) so the family's replies and theorem names (`enclose_sound`
  appears in a provenance string) stay as they were. `to_fixed` (climate,
  trades, computing, three meanings) and space's `style` record stayed local.
  computing's `apos` (`STR 0x27`) is now the commons spelling, the same string;
  anatomyagri's `strip_zeros` is now the commons definition, the same function.
- geostats called commons `I` and `Q` `fI`, `fQ` on purpose: its stats theory had
  a lemma with a variable named `Q`. Renamed the variable (the first geostats
  commit failed the remote build for that; fixed in `1fb87cc`, fresh PASS).
- fusion: `main.sml`'s `J` builds on commons' `Json` (5 copied functions gone),
  `build.sh` links `commons.sml`, `ROOT` lists `Veri7vn_Commons`, and
  `Fusion_Nodes.thy` says `Commons_Num.dec_val` / `pow10` where it said
  `Energy_Core`, `Climate_Num` and `Space` (11 names), because those items moved.
  That file is outside the lane's SML-only wording but the umbrella could not
  build otherwise.
- `tools/deploy/linux-build.sh`: already linked `commons.sml` for ported
  families (commit `6509730`); changed now to read the PASS marker from the full
  stored log, because `remote-build --expect` only sees the last 2,000 lines and
  a session that loads Commons on a plain HOL parent (anatomyagri, discrete)
  logs the Approximation import after its marker. Checked end to end: anatomyagri
  on persvati, 156 panel items scored there, 9,446 replies identical to macOS.
  `tools/organs/linux-humanities.sh` got the same commons `-d` and `commons.sml`.
  The same truncation applies to `remote-build --expect` itself (not mine to edit).
- `src/extract/families.json`: no change needed (family, session, binary and
  specialist lists are unchanged by the port).
- Commons has its own check now: `Commons_Export.thy`, a self-test of
  `render_dec` at 4, 10 and 15 digits, `render_fixed`, `render_trim`,
  `show_int`, and `enclose` (through `to_dec`) on known values; `round_tie_up`,
  `round_sig_sound`, `to_dec_sound`, `enclose_sound` and the rest are in the
  scanned theorem list; marker last: `VERI7VN_COMMONS PASS theorems=11 oracles=0`.
  (`round_tie_up` is over reals, so the self-test cannot run it.)

## Not done, and things to know

- `earth`, `finance` and `guards` still carry their own `regex.sml` (not in this
  lane's family list, written elsewhere).
- Two of my commits (anatomyagri's and chemistry's `regex.sml` deletion) were
  swept into other lanes' commits through the shared index (`1024e60` and
  nearby); the tree is right, the `regex.sml` deletion just is not in the
  family's own commit. I switched to plain `rm` plus `git commit -- <paths>`.
- Incident, my fault: I ran one `isabelle build -f` per host (geostats on hbox,
  humanities on persvati) to recover sessions whose stored log had been lost when
  two of my builds ran on one host at once (their `build_log` was empty;
  a concurrent build had overwritten it). `-f` rebuilt `Pure`, `HOL` and the
  ancestors. On hbox this left the heaps of `HOL-Library`, `HOL-Decision_Procs`
  and the Veri7vn sessions older than `HOL`, and other lanes' builds (mathorgan
  was running) and mine then raced rebuilding `HOL` (`SQLITE_CONSTRAINT_PRIMARYKEY`,
  `Session startup failed ... 127`). hbox disk is 92% (36 G free). I moved the
  remaining builds to persvati, where the forced build had completed. hbox needs
  one quiet `isabelle build -b HOL-Decision_Procs HOL-Library` before the next lane
  builds there. Do not use `-f`; one build per host at a time.
- Space built on persvati (hbox SIGTERMs it under the memory cgroup, as known).
- Local `check-native` was not run; no local Isabelle session was built. The
  rebuilt binaries are compiled from the remote exports with the MLton inside
  the local Isabelle (`var/commons/mkbin.py`), installed over `var/<slug>/bin/`
  (not in git); `var/commons/after-bin/` has copies. A laptop rebuild through each
  `build.sh` needs the local session databases rebuilt with the commons `-d`.
- The `var/commons/` helpers (untracked, untrusted, scratch): `score.py`,
  `cmp.py`, `mkbin.py`, `rb.sh`, `finish.sh`, `dedupe.py`, `port_infra.py`.

## Reproduce one family

```sh
var/commons/rb.sh persvati chemistry Veri7vn_Chemistry 'VERI7VN_CHEMISTRY PASS'
python3 var/commons/mkbin.py chemistry Veri7vn_Chemistry     # MLton from the remote export
python3 -B var/commons/score.py chemistry var/commons/after-bin/chemistry var/commons/after/chemistry
python3 var/commons/cmp.py chemistry                         # against var/commons/before/chemistry
```

or the plain tools: `tools/dev/remote-build persvati src/extract/chemistry Veri7vn_Chemistry
-d src/extract/commons` and `PARITY_UPSTREAM=... python3 tools/parity/harness.py --answerer
"var/chemistry/bin/chemistry --specialist {id}" --specialist chemistry,chemistry-v3,decay,labsolutions,labsolutions-r2 --split both --out <fresh dir>`.
