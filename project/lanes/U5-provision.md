# U5 appliance construction

The latest construction is `candidate-u5-v2`, recorded in the final section below.
Version 1 remains intact as the comparison point; behavioral qualification is
owned by the service lane.

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


## U5 v2: repair the live geometry route and add transfer time

The fresh `var/usage-20261027/candidate-u5-v2` follows the version-1 service finding
that the actual geometry specialist route could still give a dimensionally wrong
answer. The new construction adds the reviewed geometry specialist repair and
its manifest, plus the transfer-time specialist, standing-extension list, w554
integration and optional qualification metadata in the operations adapter.

Its `APPLIANCE.json` SHA-256 is
`3d0e2c804c7c76f7a683e564053ccb5474bf3f1e97d30246c70f52f33dbd1338`.
The new receipt is
[`docs/deploy/appliance-u5-v2-2026-10-27.json`](../../docs/deploy/appliance-u5-v2-2026-10-27.json),
and the recipe is
[`deploy/appliance/candidate-u5-v2.recipe.json`](../../deploy/appliance/candidate-u5-v2.recipe.json).

After the entire U5-v1 patch set, construction adds:

- `tools/usage/reliability/u5-geometry-route.patch`, SHA-256
  `62c876abfa377730784a024fef06c99e89665b17f7a70474377a6569a3cfa98b`.
- `deploy/appliance/patches/oracle7-slim-4.9-transfer-extension.patch`, SHA-256
  `55d63586cf45ab7a1c614e4d1a0e3d0873f2c9471043c9d19a8153571c8738ae`.

Only the operations component lock was refreshed:
`deploy/appliance/components/locked-u5-v2/operations.json`, SHA-256
`e6112acc9bb9dbbc8651f78ba9c2f8e729dc7365029c8fb485a608a61a4c54aa`.
The adjacent mixed `bundles.json` refers to that lock and the eight unchanged
`locked-u4-v2` manifests. Existing locks were not rewritten or copied.

The runtime difference is exactly ten files: the operations adapter, w554,
`standing_extensions_v1.txt`, the five `data-transfer-v1` files (README, manifest,
organ, panel and scorer), and the geometry-v4 organ and manifest. Their complete
final hashes are in the receipt. In particular, operations is `ea53d47f…`, w554 is
`edeadeb4…`, and the geometry organ/manifest are `c2ea6f84…` / `a2096877…`, matching
the reviewed inputs.

Construction exited successfully using verified cache entries only. All 4,323
non-store file hashes, sizes and executable flags were checked, as were all 48
component/provider/core dependencies. The full inventory has 4,333 entries with
no unexpected, missing or symlinked files. All frozen final-source hashes pass.
The other eight components, other adapters, store inventory and kernel provenance
are identical to version 1. All ten stores still share verified cache hardlinks.

There were 598 GiB free before construction. The retained non-store payload is
132,511,003 bytes. Earlier candidates and receipts remain unchanged; no files were
deleted. This lane ran no Engine, specialist panels or signed packaging. The
service lane received this exact candidate identity for its coordinated replay;
these construction checks do not establish behavioral correctness.

Version-2 lane changes are the new recipe, receipt, operations lock and mixed
index, plus this report update. The materializer itself is unchanged.
