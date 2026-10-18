# Scout report: commons (the shared numeric core and SML library)

Branch `scout/commons`, worktree `var/scout-wt/commons`, 2026-10-17.
Everything below was run in the worktree; every number comes from a command I
ran, in this worktree, today.

## 1. What I built

`src/extract/commons/`, one session and one SML library:

- `ROOT` — session `Veri7vn_Commons` (HOL + `HOL-Decision_Procs`,
  `HOL-Library`; `Code_Target_Numeral`/`Int`/`Nat` imported in the theory).
- `Commons_Num.thy` (283 lines) — the numeric core every family was copying:
  `rl`, `I`/`Q` floatarith glue (+`Dv`/`Sb` combinators), `pow10`, `dec_val`,
  `round_at`/`round_at_error`/`round_tie_up`, `exp_up`/`exp_down`/`sig_exp`,
  `round_sig`(+sound), `midpoint_close`, `to_dec`(+sound), `enclose`
  (+sound), `digits`…`render_dec`, `show_int`/`show_nat`/`show4`/`show_input`,
  `apos`, `render_fixed`/`render_trim`. All proofs close; no `sorry`, no
  axioms. The parameterized (lane-G lineage) versions are canonical; the
  pre-parameterization acoustics variants (`dec_exp`, 1-arg `render_dec`) are
  absorbed as `sig_exp 4` / `render_dec 4` at call sites. Family policy
  constants stay local (`prec`: 53 in quantity, 64 in acoustics).
- `commons.sml` (404 lines, UNTRUSTED) — the canonical Regex engine
  (quantity's 265-line `regex.sml`, itself lane D's engine plus `^`, `$`,
  `{m,n}`, lookbehind — a strict superset with the same signature) plus the
  122-line `Json` framing every `main.sml` carried.

TWO families ported to import them:

- **quantity**: `Quantity.thy` 1613 → 1394 lines, `regex.sml` deleted,
  `main.sml` 198 → 77 lines, `ROOT` gains `sessions Veri7vn_Commons`,
  `build.sh` and `regex_test.sh` point at commons.
- **acoustics**: `Acoustics.thy` 893 → 726 lines, `regex.sml` deleted (its
  older 200-line engine replaced by the canonical superset), `main.sml`
  184 → 62 lines, same ROOT/build.sh changes; the export self-test's
  `render_dec (3313, -1)` became `render_dec 4 (3313, -1)` (5 sites).

Run it (from a checkout containing this branch):

```sh
python3 tools/dev/check-native --session Veri7vn_Commons --session-root src/extract/commons --timeout 900
tools/dev/remote-build hbox src/extract/quantity Veri7vn_Quantity --expect 'VERI7VN_QUANTITY PASS' -d src/extract/commons
tools/dev/remote-build persvati src/extract/acoustics Veri7vn_Acoustics --expect 'VERI7VN_ACOUSTICS PASS' -d src/extract/commons
sh var/commons/scout-build.sh quantity Veri7vn_Quantity quantity   # MLton from the remote export
sh var/commons/scout-build.sh acoustics Veri7vn_Acoustics acoustics
PARITY_UPSTREAM=/Users/ember/dev/o7vn/upstream python3 tools/parity/harness.py \
  --answerer "var/acoustics/bin/acoustics" --lane-answerer "var/acoustics/bin/acoustics" \
  --specialist acoustics --split both --out var/commons/parity-after/acoustics
PARITY_UPSTREAM=/Users/ember/dev/o7vn/upstream python3 tools/parity/harness.py \
  --answerer "var/quantity/bin/quantity --specialist {id}" --lane-answerer "var/quantity/bin/quantity --specialist {id}" \
  --specialist densities,units,units-v3,springs,fluids,fuels --split both --out var/commons/parity-after/quantity
```

(`PARITY_UPSTREAM` matters only in a worktree: upstream/ does not exist there,
and without it the harness dies on a swallowed `NoneType.get` — it also needs
a FRESH `--out` dir; a dir holding verdicts from a crashed run reports
HARNESS ERROR again.)

## 2. What works, with numbers

**Parity is exact, at the reply level, not just the scorer level.** I scored
the before binary (built in this worktree from the unported sources) and the
after binary on every panel item, then diffed every recorded reply
(status, response text, path, kind, value):

| family | items (dev+heldout) | replies byte-identical | scorer verdicts | PASS marker | binary before → after |
|---|---|---|---|---|---|
| quantity (densities, units, units-v3, springs, fluids, fuels) | 641 | **641 / 641** | 641 ok, 0 wrong, 0 false-yes, both splits | `VERI7VN_QUANTITY PASS theorems=47 oracles=0` | 544,520 → 544,184 B |
| acoustics | 139 | **139 / 139** | 139 ok, 0 wrong, 0 false-yes | `VERI7VN_ACOUSTICS PASS theorems=28 oracles=0` | 428,056 → 429,080 B |

These match the shipped-organ board numbers (320/0 heldout across the six
quantity specialists; 69/0 acoustics). p50 per question is unchanged
(0.01–0.05 ms both sides); cold start ~10 ms. `tables_check.py` still PASSes
on the ported `Quantity.thy` (tables untouched). `regex_test.sh` PASSes
against `commons.sml` (including the S17 `\S`-vs-`\s` regression). The
generated SML keeps its shape: one flat file, `Str_Literal` then
`structure Quantity` / `structure Acoustics` — commons code inlines into the
family module, so `recognizer.sml`/`main.sml` see the same interface.
Acoustics' generated kernel grew 4,625 → 4,627 lines (the `render_dec 4`
arguments); the +1 KB binary is the larger canonical regex engine.

**Umbrella check: green.** `Veri7vn_Fusion` has `Veri7vn_Quantity` as parent
session; with `-d src/extract/commons` added (patched in
`src/extract/fusion/build.sh`) it built on hbox and printed
`VERI7VN_FUSION PASS theorems=32 oracles=0`.

### The duplication, measured

Scope note: the brief said fifteen family kernels; sixteen directories carry
the full family-kernel shape (`recognizer.sml` + `regex.sml` + `main.sml` +
`tables_check.py`): acoustics, anatomyagri, chemistry, climate, computing,
discrete, emoptics, energy, facts, geostats, life, materials, mechanics,
quantity, space, trades — plus `stores` (relation reader, same SML shape) and
`fusion` (planner, `main.sml` only).

- **Isabelle numeric core** (16 core theories, 7,298 named-item lines): 90
  named items live in ≥2 families. 35 are byte-identical in every family that
  has them (~1,312 duplicated lines, 18% of the core total). The rest are
  *drifted copies of the same concepts*: acoustics holds the
  pre-parameterization versions (`exp_up` without the bound argument,
  1-arg `render_dec`, `dec_exp` ≡ `sig_exp 4`), space re-parameterized
  `to_dec`/`sig_exp` by a `style` record, geostats renamed `I`/`Q` to
  `fI`/`fQ`, computing spells the apostrophe `STR 0x27`. One name genuinely
  collides across families with different bodies: `to_fixed`
  (climate vs trades vs computing differ in tolerance conditions) — that one
  is family policy, not commons.
- **`regex.sml`**: 12 of 17 copies byte-identical (265 lines each); the other
  five are 0.83–0.996 similar (older engines or small extensions). 4,197
  lines on disk for one 265-line engine.
- **`main.sml`**: 18 copies of ~198 lines; between any two, only ~22 lines
  differ (family name, usage string, theorem list, `Family.` qualifiers).
  ~3,400 lines for one ~190-line driver.
- **Boilerplate**: `tables_check.py` ×16, `build.sh` ×19, `score.py` ×18,
  `ROOT` ×18 — every one a near-identical template differing in paths and
  session names (~5,800 lines of script).

**Port diff size** (this branch, `git diff 7fe029c..HEAD --stat`):
17 files, **+504 / −854** — the tree got 350 lines smaller while gaining a
whole new session and library. Git even recorded `quantity/regex.sml →
commons/commons.sml` as a rename.

**Full migration (14 remaining families), cost and save:**

- thy: ~1,270 lines deleted (per-family commons-item counts: mechanics 184,
  trades 172, emoptics 170, computing 167, energy 165, space 155, climate
  113, geostats 102, discrete 33, anatomyagri 11; chemistry/facts/life/
  materials keep only SML-side duplication — their theories use their own
  layout helpers or none).
- SML: 3,745 lines of `regex.sml` and ~2,300 lines of `Json` blocks deleted;
  each `main.sml` becomes a ~77-line dispatcher (acoustics' is 62).
- Mechanical per family: delete the item block (the analyzer in
  `var/commons/measure_thy.py` lists each family's items), add one import
  line + one ROOT `sessions` line + one `-d`, adapt `render_dec`/`sig_exp`
  call sites if the family predates parameterization (acoustics needed 5;
  space will need its `style` call sites looked at), drop `regex.sml`, slim
  `main.sml`. Then one remote build with the PASS marker and one full panel
  re-score with the byte-diff against the before binary — that diff is the
  acceptance gate, and it is cheap (~2 min build + ~1 min score per family).
- Estimate: **sonnet-tier, ~1 family per hour including scoring**; a day of
  lane time for all fourteen. Save: ~6,300 lines deleted, one place for
  every future fix (the S17 regex escape bug and the tie-rounding statement
  each had to land in 9–17 places), and one build of the core instead of
  sixteen re-provings of the same lemmas (a full commons+family build is
  dominated by HOL-Library/Approximation, ~45 s remote; unchanged).

## 3. What I learned that was not obvious

- **The copies are not drift-free, and the drift has a direction.** Lane D
  wrote precision-4-hardcoded helpers; lane G parameterized and proved more;
  eleven later lanes copied lane G byte-for-byte, and each copy's header
  *says so* ("copied from lane G unchanged"). So the migration is mostly
  deletion, not reconciliation — except acoustics (oldest) and space (most
  generalized), which need the small call-site adaptations I did for
  acoustics.
- **`module_name` in `export_code` flattens cross-session code into the
  family module.** Importing `Commons_Num` from another session does not
  change the generated file's shape at all — the recognizer and driver are
  untouched. This was the biggest unknown going in; it resolved in our favour
  and is the reason the port is reply-byte-identical.
- **`prec` is family policy, not core.** quantity uses 53, acoustics 64 with
  a per-kind `prec_of` (40 for the decibel kinds). It must stay out of
  commons or the acoustics enclosures change.
- **The harness in a worktree needs `PARITY_UPSTREAM` and a fresh `--out`.**
  Without upstream it fails with a swallowed `AttributeError` that looks
  like an answerer bug; with a dirty out-dir it replays the error even after
  you fix the cause. Worth a one-line fix in `tools/parity/harness.py`
  (respect an unset-upstream with a clear message; refuse a non-empty
  `--out` unless `--rescore`).
- **One real name collision exists**: `to_fixed` means three different
  things (climate, trades, computing). A migration must rename or leave
  those local — do not force them into commons.
- **`stores` and `fusion` ride the same SML scaffold** (`regex.sml`
  byte-identical modulo 3 lines in stores' case; fusion's `main.sml` is the
  same driver). The SML half of commons applies to 18 directories, not 16.

## 4. Dependencies for excellence

- **An oracle/self-check in commons itself.** The families' export ML blocks
  assert `all_oracles` empty for their theorem lists (both did, oracles=0),
  but `Veri7vn_Commons` has no such block of its own; its soundness is
  currently witnessed only through the importers. Owner: whoever lands the
  migration lane; a 10-line ML block listing the commons theorems.
- **`tools/parity/harness.py` robustness** (the two failure modes above).
  Owner: lane A or root; S.
- **A decision on `to_fixed` and on space's `style` record**: keep local
  (recommended; they are policy) or unify with a parameter. Owner: root,
  when the migration lane is briefed.
- **build.sh templating**: after migration, every `build.sh` differs only in
  slug/session names — a `tools/dev/family-build <slug>` would delete the
  last ~800 lines of boilerplate. Not needed for correctness; nice later.

## 5. Proposed follow-up lanes

1. **Migrate the remaining fourteen families onto commons** — S, sonnet.
   Copy this branch's pattern per family (the exact per-family item lists
   are in `var/commons/measure_thy.py` output above; the acceptance gate is
   the reply-byte-diff against the before binary, both splits). Done when:
   every family's panels show 0 reply diffs and the tree is ~6,300 lines
   smaller.
2. **Commons self-check + CI-style marker** — S, sonnet. Add the ML block
   (`all_oracles` empty over the commons theorem list, a `self_test` pinning
   `render_dec 4/10/15`, `round_tie_up`, `to_dec` on a known interval) and a
   `VERI7VN_COMMONS PASS` marker. Done when: remote-build --expect passes on
   a clean box.
3. **Family build driver** (`tools/dev/family-build`) — S, sonnet. One
   script parameterized by slug/session replacing 19 `build.sh` copies.
   Done when: two families build through it and their `build.sh` files are
   deleted.
4. **Unify the recognizers' narrow_v1 scaffolding** — M, opus. The
   narrow_v1 rule is re-ported per family inside `recognizer.sml` (~40–80
   lines each); extract a tested `Narrow` structure into commons.sml with
   each family's word lists as data. Done when: a family's recognizer loses
   its narrow block and its panels stay byte-identical.
5. **Prove the number layout** (`render_dec` meets `%.pg`)** — M, fable-tier
   metatheory, optional. Lane G's open item; commons now gives it one home
   and one statement. Done when: a theorem pins `render_dec p d` against a
   declarative spec of Python's `%.pg` for the cases the organs print.

## 6. Honest status

- No `sorry`, `oops`, `skip_proof` or axioms anywhere in commons or the two
  ports; both family PASS markers printed `oracles=0` from their own ML
  blocks. Commons' *own* oracle check does not exist yet (§4).
- Untrusted parts unchanged in kind: `commons.sml` (Regex + Json) is
  UNTRUSTED exactly as the per-family files were; the recognizers are
  untouched; `main.sml` remains the untrusted driver.
- The fusion umbrella check finished green: `Veri7vn_Fusion` (parent session
  `Veri7vn_Quantity`, which re-checks the ported `Quantity.thy`, plus
  Energy/Climate/Space theories inside it) built on hbox with
  `-d src/extract/commons` and printed `VERI7VN_FUSION PASS theorems=32
  oracles=0` (assertion export `var/fusion/export-remote/.../assertions/fusion`).
  `src/extract/fusion/build.sh` gained the same `-d`.
- The `upstream` symlink in this worktree root (→ the main checkout's drop,
  read-only, for tables_check/harness) is untracked and must not be
  committed; `.gitignore`'s `upstream/` pattern does not match a symlink.
- I did not touch the main checkout, other branches, or anything under
  `upstream/`. Disk never went below 266 Gi free.
