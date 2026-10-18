# The organ package for Oracle7's author

A tarball, `var/organs/veri7vn-specialists-<date>.tar.gz` (never committed), that Oracle7's author unpacks
into his own `root/` with no veri7vn checkout. It holds every committed veri7vn family as ready-made Oracle7
specialist folders plus the built programs behind them. Built by `tools/organs/package.py`.

## Layout

    specialists/
      _veri7vn/                      shared, not a specialist (no manifest.json, like _gate and _cards)
        README.md                    written for him: what this is, proved and not, why exam.py says WOULD FAIL
        NOTICE                       the one NOTICE: what is Oracle7's, what is ours, third-party parts
        MANIFEST.json                families, specialists, commit, program hashes
        SHA256SUMS                   every file in the package
        smoke.py                     asks every folder its own panel; stdlib only, no head
        bin/darwin-arm64/<family>    one program per family and platform
        bin/linux-x86_64/<family>
        receipts/<family>.json       what produced each program (below)
      <id>-veri7vn/                  one per specialist, 125 today
        manifest.json  organ_<id>_veri7vn.py  <panel>.json  <scorer>.py

A folder holds no program and no NOTICE or README of its own: the wrapper finds the program by this order,
`$VERI7VN_<FAMILY>_BIN`, `bin/<family>` beside it, `../_veri7vn/bin/<os>-<arch>/<family>`, then
`var/<family>/bin/<family>` up the tree (a checkout). `<os>-<arch>` is `platform.system().lower()` and the
normalised `platform.machine()`. A machine with no program gets an error naming the path it looked for.

## What goes in

- Families from `src/extract/families.json` whose directory is tracked by git and unmodified. Untracked
  `earth` and `finance` are never read. `stores` is left out: its program starts a Python fetcher by checkout
  path (`state_flag` in the registry). `fusion` has no specialists. That leaves 18 families, 125 specialists.
- The folder shape is `make_organ.py`'s (`packaged=True`): panel and scorer are copies of the shipped ones.

## Receipts

`receipts/<family>.json`, per platform: sha256 and size of the program; for macOS the newest passed check-native
receipt of the family's session (path, attempt, Isabelle version) and the list of theory files that changed since
that receipt (non-empty for families ported onto commons after their receipt: the evidence for them is the
fresh Linux build and equal generated SML); for Linux the host, glibc, MLton, the remote-build log with its PASS
marker, the generated-SML hash and the libraries the program links. `package.py` refuses a package whose Linux
and macOS kernels were generated from different SML.

## Build it

    tools/deploy/linux-build.sh <family> <Session>        # per family, on hbox (variants: tools/organs/linux-variants.sh)
    python3 -B tools/organs/package.py --pull-linux hbox  # copies the Linux programs, writes the tarball
    tools/organs/smoke_root.sh var/organs/veri7vn-specialists-<date>.tar.gz var/organs/smoke-mac
    cd var/organs/smoke-mac && env -i PATH=/usr/bin:/bin /usr/bin/python3 -B root/specialists/_veri7vn/smoke.py --dump ../smoke-mac-dump.json
    python3 -B tools/organs/package_compare.py var/organs/smoke-mac-dump.json    # against the lanes' harness runs

The macOS programs are each family's `var/<family>/bin/<family>` from its `build.sh`; rebuild any that predate
the commons port (quantity, acoustics, variants were) before packaging.

## Limits

- The programs link GMP dynamically (`/opt/homebrew/opt/gmp` on macOS, `libgmp.so.10` on Linux). Not shipped.
- Two platforms. Linux programs were built on one host (glibc 2.40); older glibc is untested.
- The head is never run by this tooling. The Oracle7 `exam.py` verdicts and the front-composition numbers in the
  README are from the organ-wrappers scout for five folders; the all-folder board is W5-11.
