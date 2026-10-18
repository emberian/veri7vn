# Lane W5-10: the organ package for Oracle7's author (2026-10-17)

`var/organs/veri7vn-specialists-2026-10-17.tar.gz` (11,189,727 bytes, sha256 `04bb8edca8864f2f...`; not in git).
Built from veri7vn dev, 18 committed families, 125 specialist folders. Layout and rules:
[docs/handoff/organ-package.md](../../docs/handoff/organ-package.md). What he reads: `_veri7vn/README.md` in the
package (source `tools/organs/package_readme.md`).

## Contents

| Part | Size |
|---|---|
| tarball | 11.2 MB (41 MB unpacked) |
| `_veri7vn/bin/darwin-arm64/` 18 programs | 12 MB |
| `_veri7vn/bin/linux-x86_64/` 18 programs | 25 MB |
| 125 folders: manifest, wrapper, panel, scorer | about 4 MB |
| `_veri7vn/` README, NOTICE, MANIFEST.json, SHA256SUMS, smoke.py, 18 receipts | small |

Left out: `stores` (6 specialists; its program needs the checkout path and a python fetcher), untracked `earth` and
`finance` (13 specialists). Discovery takes only families whose directory is tracked and unmodified in git.

## Smoke test (done)

Every folder, dev and held-out, `answer()` through the wrapper, scored with the shipped scorer, run as
`env -i PATH=/usr/bin:/bin python3 -B specialists/_veri7vn/smoke.py` from an unpacked copy, no veri7vn checkout in
reach on hbox (no checkout exists there), no env vars; every folder used `_veri7vn/bin/<os>-<arch>/<family>`.

| Machine | Folders | Questions | ok | wrong | false yes | Replies vs family lanes' harness runs |
|---|---|---|---|---|---|---|
| macOS arm64, scratch root `var/organs/smoke-mac/root` (everything else symlinked to upstream/root) | 125 | 12,247 | 11,802 | 46 | 0 | 12,247 of 12,247 equal (status and response) |
| hbox linux-x86_64, `~/o7vn-smoke/root` | 125 | 12,247 | 11,802 | 46 | 0 | 12,247 of 12,247 equal, and equal to macOS |

Three named folders (dev ok/wrong/fy, held-out ok/wrong/fy), the same on both machines and equal to the lanes' own:
acoustics 70/0/0 and 69/0/0; units 76/0/0 and 76/0/0; git 10/0/0 and 7/1/0 (the one wrong is the
`git stash` item the shipped git organ answers identically). Also orbits 35/0/0 and 35/0/0. The comparison is
`tools/organs/package_compare.py` against `var/linux/macos/` (W5-04's baseline harness runs); water-r3 has no
panel of its own and is compared with water's run, as lane S08 scores it. The 46 wrong are the shipped organs' own
disagreements with their scorers in the lanes' tables (materials, space and others), not new.
SHA256SUMS verifies on both machines.

## Programs

- macOS: each family's `var/<family>/bin/<family>`, except acoustics, quantity and variants.
- Linux: `tools/deploy/linux-build.sh` on hbox for 15 families (fresh remote PASS each); `tools/organs/linux-humanities.sh`
  (humanities needs `rules.sml` in the .mlb, which linux-build.sh does not know); `tools/organs/linux-variants.sh`
  (variants has no session or main.sml of its own). space: hbox's build of `Veri7vn_Space` was terminated (SIGTERM,
  return code 143) twice at `Space_Tables` `grav_earth_pos`; persvati passed it, its exported SML is byte-identical to
  the macOS one, and hbox compiled it.
- Finding: `build.sh` of acoustics, quantity and variants returns the OLD kernel. It reads the SML from the local
  session database with `isabelle export -n` and never builds; those databases predate the commons port. A rebuild
  from `build.sh` today (I did one first) gave generated-SML hashes `4e2bc00e` / `1732dcfa` (old), the fresh Linux
  builds `7d369ead` / `5868f0e5`. `package.py` refuses a package whose two kernels differ, which caught it. The
  macOS programs of those three were therefore compiled from the fresh export by `tools/organs/macos-from-export.sh`.
  Their replies are equal to the pre-port harness runs on all 12,247 questions, so the port changed no reply there.
  The root should rebuild or drop the stale local databases (`check-native` for Veri7vn_Acoustics and Veri7vn_Quantity).
- Linux programs link `libgmp.so.10` and `libc.so.6`; macOS programs link `/opt/homebrew/opt/gmp`. Neither is shipped.

## Receipts

`receipts/<family>.json`: sha256 and size per program, macOS check-native receipt (newest passed, with the list of
theory files that changed since it; non-empty for acoustics 3, quantity 2, variants 2), Linux host, glibc, MLton,
remote-build log hash with the PASS marker, generated-SML hash on both platforms (equal for all 18).

## Not done, and why

- The head was not run (lane rule). The WAVE5 line "acoustics' dev verdict byte-equal to lane D's" is therefore not
  re-run. What stands in for it: acoustics folder files equal lane D's hand-built ones (panel and scorer byte-equal;
  manifest differs in `notes` and the `veri7vn` block; wrapper adds only the package search path), and its
  answers equal the lane's on all 139 questions. A head run belongs with W5-11.
- The exam verdicts and front-composition numbers in the README are the organ-wrappers scout's, for five folders.
- Package size is dominated by 25 MB of Linux programs (dynamic, 1 to 1.8 MB each).

## Files and a conflict to know

Committed: `tools/organs/{package.py, package_smoke.py, package_compare.py, package_readme.md, package_notice.txt,
smoke_root.sh, linux-humanities.sh, linux-variants.sh, macos-from-export.sh}`, my hunks of `make_organ.py` (binary search
path; `packaged=True` mode), `docs/handoff/organ-package.md`, this file. W5-14's uncommitted edits to the same
`make_organ.py` (registry) were left in the working tree and not committed by me. `package.py` and
`package_compare.py` read `src/extract/families.json`, which W5-14 has not committed yet; they need it.
Reproduce: see the build commands in the handoff doc.
