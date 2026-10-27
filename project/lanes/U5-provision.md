# U5 appliance construction

The fresh `var/usage-20261027/candidate-u5-v1` contains the reviewed conversation-door
and geometry-unit repairs. It retains the nine U4-v2 component bundles, service
adapter, kernel overlay and data stores. Earlier candidates and receipts were not
changed. The construction did not start an engine or build a signed Mini package.

The full `APPLIANCE.json` SHA-256 is
`a7d1afb9cbdcabfe23c9f1c7b46128e1a0c2c302c4dbbbc7902be38ad8b3c5f9`.
The compact receipt is
[`docs/deploy/appliance-u5-v1-2026-10-27.json`](../../docs/deploy/appliance-u5-v1-2026-10-27.json).
The reproducible argument list and input hashes are in
[`deploy/appliance/candidate-u5-v1.recipe.json`](../../deploy/appliance/candidate-u5-v1.recipe.json).
It reuses `deploy/appliance/components/locked-u4-v2`; no duplicate component locks
or changes to the materializer were needed.

## Inputs and resulting changes

After the U4 patch set, construction applies these two patches in order:

- `deploy/appliance/patches/oracle7-slim-4.9-conversation-door.patch`, SHA-256
  `f47f282fc4ecfd4beb8564176c6bedfb86d7314f56df108337efce0e0b8d029b`.
- `tools/usage/reliability/u5-geometry-units.patch`, SHA-256
  `98b9c263f62f8a1a41d6b09a90e45d662bdb98d67fbf7438117000050d07d115`.

The exact runtime difference from U4-v2 contains only these three files:

| File | Final SHA-256 |
| --- | --- |
| `root/fable-content/oracle-m-series-2026-08-15/self_loop/admitted/oracle_release_runtime_w468.py` | `583b489111f35bfd0432ed7ae72dd3ff6bddc6aa43b3822e6ffa7a8ab4394df2` |
| `root/fable-content/oracle-m-series-2026-08-15/self_loop/admitted/oracle_release_runtime_w488.py` | `c9e3ea08175080f779ff7ae5e93cf5743ca32f693ccb6503e148fc195b9305a4` |
| `root/wander-train/word_problems_v1.py` | `6a22393a62de0b677977499c658fa1d9033a8d22d4414d47c5bab24e574c9532` |

All component manifests, adapter hashes, store identities and per-family kernel
provenance are identical to U4-v2.

## Checks and limits

Materialization exited successfully and used only verified cache entries: there
were no downloads. The complete file inventory contains 4,327 entries and no
unlisted, missing or symlinked files. All 4,317 non-store files were independently
rehashed after construction, including their sizes and executable flags. The 48
component/provider/core dependency checks and all expected final-file hashes also
passed. Store hashes were checked during materialization; their identities remain
unchanged, and the ten store paths share verified cache hardlinks.

There were 602 GiB free before construction. The retained non-store payload is
132,483,568 bytes; the stores contain 15,004,659,712 logical bytes shared with the
cache. Nothing was deleted.

This is byte identity and package composition evidence. No theorem statements
were added and no specialist panels were scored by this lane. The packaging tool
is untrusted Python, not a proof checker. The consumer is the appliance-service
lane's coordinated U5 engine qualification; its behavioral results are separate
from this construction receipt. Root owns integration and any later signed Mini
packaging.

Changed tracked files for this lane are the new recipe, compact receipt and this
report. Previous receipts remain untouched.
