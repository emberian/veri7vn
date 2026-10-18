# The organ package

`tools/organs/package.py` prepares a tarball for an Oracle7 installation. It
copies specialist panels and scorers, native programs and their available
receipts. It sends nothing to anyone and writes nothing under `upstream/`.

The registry now includes 144 specialist IDs in 21 specialist families.
Earth and finance are registered. Roles such as guard, word problem and math
are not specialist folders. Stores needs binaries with the explicit asset-path
options and is included only with `--include-stores`; its six IDs otherwise
remain explicitly excluded.

## Selected delivery: 2026-10-18

`var/C-runtime-package/delivery-20261018-a5f10.json` records the selected
21-family, 144-folder delivery. Root promoted these existing archives after
Finance source commit `fb5c6ec` and package tooling commit `b26ff69`; their
candidate filenames remain unchanged:

| Platforms | Archive under `var/C-runtime-package/` | Bytes | SHA256 |
|---|---|---:|---|
| Apple Silicon macOS | `candidate-native-a5f10/veri7vn-specialists-2026-10-18.tar.gz` | 8,377,015 | `6d8d5b9a3ede107271662e5f3e07ba2679823b76255e0051ad2e36e2d6f4afa7` |
| macOS and x86-64 Linux | `candidate-both-a5f10/veri7vn-specialists-2026-10-18.tar.gz` | 17,729,837 | `f7a51fe544a669da9a77684a1d9d2019712c3a673e7bb47e3f91d19f71473791` |

The shared checker is exactly approved commit `105051f`, SHA256
`11c8ec3ce9c89499811fcc29c7936d115c530208e14fd389ce93b8f43417e029`.
It was not replaced with newer working-tree code during promotion. Captured
family versions and their acceptance declarations remain fixed; later family
and composition packets do not enter this delivery.

All family platform comparisons have matching replies. Finance's original
scorer reports **553/559 right, six wrong, zero false yes, 36 withheld**; the
six exact-Fisher versus approximate-scorer disagreements remain recorded, not
rescored. Two supported-in-principle discount phrasings still withhold. Three
Finance boundary probes pass identically after extracting each platform archive;
the report `project/lanes/C-runtime-package.md` links the scoped evidence.
These checks are not a whole-head admission or timing score. Warehouse defaults
to preview, and composition roles are excluded. No archive has been sent externally.

## Layout

    specialists/
      _veri7vn/
        README.md  NOTICE  MANIFEST.json  SHA256SUMS  smoke.py
        bin/<platform>/<family>
        receipts/<family>.json
        stores/                       # only when explicitly included
      <id>-veri7vn/
        manifest.json  organ_<id>_veri7vn.py  <panel>.json  <scorer>.py

`make_organ.py` uses `tools/runtime_contract.py` to merge reviewed family
capabilities into the original acceptance rules. Wrapper replies retain their
provenance and their decisive declines. `smoke.py` applies the acceptance rule
before scoring, so a new answer kind filtered out by the manifest cannot pass
unnoticed. Cross-platform comparison rejects missing folders or splits and
unequal reply counts as well as changed replies.

## Prepare and check a selected package

    python3 -B tools/organs/package.py --family chemistry,earth,finance \
      --platform darwin-arm64 --out var/my-package
    python3 -B var/my-package/stage-2026-10-18/specialists/_veri7vn/smoke.py \
      --ids chemistry-v3,geography,retail --dump var/my-package/smoke.json

Omit `--family` and `--platform` for all registered specialist families and
both supported platforms. Use a fresh output directory: existing stages and
archives are not overwritten. Modified family sources are an error unless
`--allow-dirty` explicitly requests a source snapshot. It does not certify that
the copied binary contains those changes.

Builds remain governed by the project's designated build hosts and controls.
`--pull-linux HOST` copies existing deployed programs; it does not build them.
A package may contain an old binary, so a current-source release also requires
fresh build evidence from the family owner. In particular, the historical
computing Linux receipt at `var/linux/receipt-computing-persvati.json` states
that it built commit `32dd0ff`, not the then-current source.

## Evidence boundaries

Each receipt contains artifact hashes, the packaging-time source snapshot,
any older native session receipt and Linux receipt records matched by binary
hash. Packaging no longer describes an arbitrary log file as a successful
build. A source snapshot and generated-SML hash are useful diagnostics but do
not prove which source produced a binary. The original receipt's commit and
notes remain visible. Missing evidence stays missing.

Smoke counts are per specialist and split. A full head exam and fleet timing
are separate checks; do not infer them from archive creation or a narrow smoke.
GMP is dynamically linked, only Apple Silicon macOS and x86-64 Linux programs
are supported, and compatibility with older Linux libraries remains untested.

## Warehouse effects in an external Oracle7 host

Generated warehouse wrappers default to read-only preview. The original
Oracle7 Combo calls every candidate, probes counterfactuals, and reasks during
segmentation and disagreement handling. It has no post-selection commit hook.
Consequently a candidate may not mutate even its private session/order log.
The wrapper maps kernel `confirm`, `ordered`, and `cancelled` preview outcomes
to truthful `effects_disabled` refusals. The generated manifest accepts this
kind and marks it as a decline. Other read-only queries remain useful; preview
also suppresses conversational-reference updates, limiting followups.

Only a sequential single-owner host may explicitly construct the wrapper with
`allow_effects=True`, after choosing it and without speculative calls or
replays. Its state is temporary and process-local. This is not general safety
for a committed wrapper inside arbitrary hosts. The veri7vn dispatcher's
separate post-selection commit protocol does not change external Combo.

`tools/organs/check_warehouse_composition.py` runs the actual upstream Combo
against generated folders, including counterfactual/segmentation/disagreement
reasks and concurrent calls. It checks no default state file appears, plus a
separate direct explicit opt-in proposal/confirmation sequence. It does not run
the complete head. Use current stores binaries with preview support.

For an archive assembled while family owners continue new work, use
`--prepared-dir PATH` with one validated `<family>/prepared.json` capture per
selected family. The captured native program, exported kernel, runtime files
and capability declarations are used together. Missing or modified captures
fail assembly. The current shared consumer checker is copied once per archive
and recorded separately; its version is not a new family proof claim.

For Linux refresh from those frozen inputs, `--runtime-overlay PATH` points to
the capture's `runtime/` root; set `MACBIN` to its captured Darwin program.
The passed receipt still supplies the verified export. Wrappers, acceptance,
panels and the Darwin baseline are prepared before the remote compile waits
for its lock. Later live-source changes cannot alter that comparison.
