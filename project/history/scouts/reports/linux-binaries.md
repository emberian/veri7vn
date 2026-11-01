# Scout report: linux-binaries (2026-10-17)

Target: prove Linux deployment — build the quantity and acoustics family
binaries on hbox from what `tools/dev/remote-build` returns, score them there
against copies of their panels, compare with the macOS binaries, record sizes
and timings, and leave a script that does it for any family.

**Outcome: proved, with zero divergence.** Full detail in
`project/lanes/S-linux-binaries.md`; the short version below.

## 1. What I built

- `tools/deploy/linux-build.sh <slug> <session> [--specialists ids] [--host hbox]
  [--skip-build] [--compare-to <local parity dir>]` — the whole path for any
  family: remote-build on the Linux host, MLton compile there under swarm-build,
  staging of the harness + panels (a 604 KB copy; `upstream/` untouched), the
  harness over every specialist and split, cold-start timing, results pulled
  into `var/<slug>/deploy-linux/`, and an optional per-item diff against a macOS
  run that fails on any divergence.
- `tools/deploy/coldstart.py` — cold start (process start to first reply, 5
  runs) against the first question of the specialist's own staged panel.
- `project/lanes/S-linux-binaries.md` — the lane-style handoff with receipts.

Run it:

    tools/deploy/linux-build.sh quantity Veri7vn_Quantity \
      --specialists densities,units,units-v3,springs,fluids,fuels \
      --compare-to var/scout/parity-macos/quantity

## 2. What works, with numbers

Builds: both sessions built fresh on hbox (exit 0, PASS markers found; ~4 min
for quantity with its base session from source, ~2 min for acoustics).

Binaries (MLton 20241230 from each host's Isabelle2026-RC1):

| | macOS arm64 | Linux x86-64 | Linux cold start | p50 in binary |
|---|---|---|---|---|
| quantity | 544,520 B | 1,243,912 B | 3.7–10.3 ms | ≤ 0.05 ms |
| acoustics | 427,176 B | 879,160 B | 2.2–7.3 ms | ≤ 0.01 ms |

(macOS cold starts for comparison: 7.0 and 5.8 ms. Budget is 50 ms.)

Panels on hbox, Linux binaries, same harness as macOS: acoustics 70/70 dev +
69/69 heldout; densities 51/51, units 76/76, units-v3 76/76 dev + 75/75
heldout, springs 42/42, fluids 34/34, fuels 42/42; 0 wrong, 0 false yes
everywhere; units/units-v3 take the same 6 of 924 core questions as the shipped
organ; no identity question taken.

Comparison with the macOS binaries: **13,786 replies identical byte for byte**
after removing the two timing fields (`rtt_ms`, `provenance.specialist_ms`);
all 14 verdict files identical modulo timing fields. Nothing does not work; no
failing cases.

## 3. What I learned

- **Isabelle code generation is deterministic across hosts.** My fresh hbox
  exports are sha-identical to the exports lanes G and D pulled days earlier.
  So a Linux binary runs the *same* generated kernel code as the macOS one;
  only MLton's platform codegen differs. Cross-platform trust needs no second
  proof burden.
- **MLton is bit-reproducible on a host**: two independent compiles an hour
  apart (one after a fresh session build) gave the same binary sha256.
- The drivers are genuinely hermetic — stdin/stdout JSON lines, no paths, no
  env, no files — so "deployment" is one ELF file. Its only shared-library
  needs are `libc.so.6` and `libgmp.so.10` (MLton's GMP runtime): a deployment
  host needs libgmp10, nothing else.
- The harness ports as-is: pure python3 (3.12 on hbox), `PARITY_UPSTREAM`
  redirects the upstream root, and it needs only the specialist folders in play
  plus `workbench/data/core_panel.json`. The memory-cap poll uses `ps -o rss=`,
  which exists on Linux.
- `remote-build` from a worktree keys the remote tree on the checkout's basename
  (`linux-binaries`), so a worktree gets a fresh remote tree and rebuilds base
  sessions (~2 extra minutes, once). `swarm-build` wraps the MLton step too —
  cheap, and keeps the box rules structural.
- Linux binaries are ~2.06× the macOS size (x86-64 codegen, both unstripped);
  irrelevant next to the 50 ms budget.

## 4. Dependencies for excellence

- **A root decision: where Linux binaries live.** They are on hbox only
  (`~/veri7vn-deploy/bin/`); `var/` is not committed. Either commit the ~1 MB
  binaries (or tarballs) with sha256 receipts, or keep receipts-only and treat
  the script as the reproducer. Owner: root.
- **libgmp on deployment hosts** — pin or statically link if binaries must run
  outside hbox. Owner: whoever owns the deployment story (none yet).
- The script assumes the hbox/persvati layout (`~/tools/isabelle-rc1`,
  `swarm-build`). Fine while those are the only Linux hosts; revisit if a CI
  runner appears. Owner: root/infra.

## 5. Proposed follow-up lanes

1. **"All families on Linux"** (S, sonnet): run `linux-build.sh` for every
   landed `src/extract/*` family with its specialists, file the receipts under
   `var/<slug>/deploy-linux/`, and add a Linux column to the plan's parity
   table. Done when every landed family's Linux verdicts equal its macOS ones.
2. **"Deploy receipts in git"** (S, sonnet): per family, commit a small manifest
   (binary sha256, generated-SML sha256, panel shas, verdict counts, host and
   glibc) produced by the script, so any binary can be re-derived and checked.
   Done when `tools/deploy` emits the manifest and root agrees on the location.
3. **"Portability beyond hbox"** (M, opus): build on persvati, run the hbox
   binaries in a minimal container/older-distro VM, record the glibc/libgmp
   floor, and decide static vs dynamic linking. Done when a binary built once
   runs on two Linux distros with identical panel numbers.

## 6. Honest status

No `sorry`, no untrusted steps beyond what the families already declare
(the recognizers are untrusted by construction, as shipped). Every number above
was run, not inferred: fresh hbox session builds, on-hbox MLton compiles,
on-hbox harness runs, and the byte-level comparisons are in
`var/*/deploy-linux/` and `var/scout/parity-macos/` (not committed). One
script bug was found and fixed during testing (a malformed tuple unpack in
`coldstart.py`); the final script runs clean end to end for both families.
