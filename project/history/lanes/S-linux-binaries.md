# Lane S-linux-binaries: Linux deployment proved

Scout lane, 2026-10-17. Target: prove that a veri7vn family kernel builds and
scores identically on Linux. Done for `quantity` and `acoustics` on hbox
(x86-64, Ubuntu, glibc 2.40), end to end, by `tools/deploy/linux-build.sh`.

## What ran

1. `tools/dev/remote-build hbox src/extract/quantity Veri7vn_Quantity --expect 'VERI7VN_QUANTITY PASS'`
   and the same for `Veri7vn_Acoustics`: both exit 0, markers found. The
   worktree's remote tree (`~/veri7vn-builds/linux-binaries/`) was fresh, so the
   base sessions (Approximation) built from source too; the quantity pair took
   about 4 minutes, acoustics about 2.
2. The exported SML of both families is **byte-identical** to the exports the
   lanes pulled earlier (`quantity.ML` sha `1732dcfa…`, `acoustics.ML` sha
   `4e2bc00e…`): Isabelle code generation is deterministic across hosts and
   runs, so a Linux binary's provenance rests on the same generated code as the
   macOS one.
3. On hbox: `.mlb` of generated SML + `regex.sml` + `recognizer.sml` +
   `main.sml`, compiled with the MLton inside the host's Isabelle2026-RC1 under
   `swarm-build`. Repeated compiles are bit-reproducible (same sha256 twice,
   including after a fresh session build).

## Numbers

| Binary | macOS arm64 | Linux x86-64 | Linux cold start (5 runs) | p50 in binary |
|---|---|---|---|---|
| quantity | 544,520 B | 1,243,912 B | 3.7 – 10.3 ms | ≤ 0.05 ms (budget 50) |
| acoustics | 427,176 B | 879,160 B | 2.2 – 7.3 ms | ≤ 0.01 ms (budget 50) |

Panels, scored on hbox by the same harness (`tools/parity/`) over a staged copy
of the shipped panels (7 specialist folders + `core_panel.json`, 604 KB; nothing
under `upstream/` touched on either machine):

- acoustics: dev 70/70, heldout 69/69, 0 wrong, 0 false yes.
- densities 51/51, units 76/76, units-v3 75/75 heldout and 76/76 dev,
  springs 42/42, fluids 34/34, fuels 42/42 — every split, 0 wrong, 0 false yes.
- Lane checks: units and units-v3 take the same 6 of 924 core questions as the
  shipped organ; the other five take 0; no identity question taken.

**Per-item comparison with the macOS binaries: 13,786 replies (panels, core
panel and identity, both splits, all seven specialists) are identical byte for
byte after removing the two timing fields (`rtt_ms`,
`provenance.specialist_ms`). All 14 verdict files are identical modulo timing
fields. Zero divergence.**

## Runtime dependency

The Linux binaries are ELF x86-64, dynamically linked against `libc.so.6` and
`libgmp.so.10` only (MLton's bignum runtime). A deployment host needs libgmp10;
everything else is in the one file.

## Reproduce

    tools/deploy/linux-build.sh quantity Veri7vn_Quantity \
      --specialists densities,units,units-v3,springs,fluids,fuels \
      --compare-to var/scout/parity-macos/quantity
    tools/deploy/linux-build.sh acoustics Veri7vn_Acoustics \
      --specialists acoustics --compare-to var/scout/parity-macos/acoustics

Receipts in `var/<slug>/deploy-linux/` (verdicts, per-item replies, harness
log) and the macOS baselines in `var/scout/parity-macos/` (not committed).
`--skip-build` reuses the export already on the host.

## Remaining

- Other families: the script is family-generic but has been run on two; the
  other landed `src/extract/*` families should go through it once each.
- Binary archiving: Linux binaries live only on hbox (`~/veri7vn-deploy/bin/`);
  whether binaries or sha256 receipts get committed is root's decision.
- Portability beyond hbox's glibc 2.40 / libgmp10 untested (a static-link or
  container check would close that).
