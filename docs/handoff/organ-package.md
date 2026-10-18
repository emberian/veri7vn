# The organ package

`tools/organs/package.py` prepares a tarball for an Oracle7 installation. It
copies specialist panels and scorers, native programs and their available
receipts. It sends nothing to anyone and writes nothing under `upstream/`.

The registry now includes 144 specialist IDs in 21 specialist families.
Earth and finance are registered. Roles such as guard, word problem and math
are not specialist folders. Stores needs binaries with the explicit asset-path
options and is included only with `--include-stores`; its six IDs otherwise
remain explicitly excluded.

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
