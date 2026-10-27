# U6 construction and Linux code transfer

The first immutable U6 candidate is `var/usage-20261027/candidate-u6`, with
`APPLIANCE.json` SHA-256
`7da99b59667957011fba36a326f82e5beff7c39b264244b31d84c2b9da50c024`.
Its recipe is `deploy/appliance/candidate-u6.recipe.json`, and its composition
receipt is `docs/deploy/appliance-u6-2026-10-27.json`.

Exactly three files differ from U5-v2: the service adapter, its README and the
new tenant-pool module. All nine component manifests, upstream patches, data
stores and kernels are unchanged. The existing 17 materializer/component tests
pass. Construction used verified cache entries only; all 4,324 non-store file
hashes, sizes and executable flags match the final receipt. The optional pool
module is present in both the full inventory and adapter hash map. No Engine or
retained Mini deployment was started by this lane.

A code-only archive contains 4,309 files, excluding the 26 existing public data
entries after checking each excluded SHA-256 and size against the candidate.
It is 28,757,613 bytes, SHA-256
`9cebbbe5a92ecfa4690bf8410bfe2f545cfa0ea6dfb8ecee3c607149fa1f3d07`.
The receiving copy was extracted and each code file rehashed on dregg-build at
`/build/lanes/oracle-tenancy-measure/u6-input/runtime`. The adjacent overlay receipt
records the absent data files; the measurement lane must mount their exact
read-only counterparts. No 15 GB data copy was needed. The existing data inventory
remains `32bb3cf1a6337ee2c7b6ec902bb5bfdff11ba1fd5f1fa3b730dc269431b27d0a`.

This initial U6 candidate is retained as a measurement input. It predates the
subsequent cold-reset and legacy-workspace refusal repairs; a separate U6-v2
candidate was prepared for the next signed package, as recorded below. No existing receipt or
candidate is rewritten to imply those repairs were already present.

These are packaging and byte-identity checks, not specialist panel scores,
theorem statements or receiving-path qualification. Shared-data measurement and
bridge behavior have separate owners and receipts.


## Final U6-v2 candidate

The separate `var/usage-20261027/candidate-u6-v2` includes the final cold-reset
optimization and refusal of legacy root-level `requests.sqlite3`. Its receipt
SHA-256 is `65d0391ee109d7f2873391d7f71cb0991d806b922f73c932764169e3cab90dd8`.
Its recipe and compact receipt are `deploy/appliance/candidate-u6-v2.recipe.json`
and `docs/deploy/appliance-u6-v2-2026-10-27.json`. All 4,324 non-store files were
rehashed; the nine component manifests, repaired upstream source, stores and
kernels remain unchanged. The pool is `a593bbc6…`, README `783da779…`, and service
`0719e0af…`. Earlier candidates remain untouched.

The receiving code-only counterpart is
`/build/lanes/oracle-tenancy-measure/u6-v2-input/runtime`. Its 4,309 code files
were all rechecked for hash, size and executable mode after constructing a
separate copy from the first U6 input plus a 198,999-byte delta. The overlay
receipt SHA-256 is `03360f3fa662a507bb9cafafefe336fb50fe862e1c6d3c6168cff6eef1224ac3`.
The same 26 public-data paths are excluded and must be mounted read-only. Both
the measurement and bridge lanes received this exact identity; this lane did
not launch their workers.

## Version 6 package preparation

Packaging uses new scratch only, at `var/oracle-runtime-v6`, the unchanged pinned
v5 rootfs/data inventory, final Linux bridge `11cb93bc…`, and a package-tool
snapshot from Mini commit `30268be06e4f758ccee58c54dafcfe042cdd6336`.
The ten focused stage tests pass. Version 6 metadata declares one resident worker
and 128 possible persistent tenant workspaces, with a fresh grain required for
legacy v5 workspaces. These are package declarations, not receiving acceptance.
The complete signed-package result will have a separate Mini v6 receipt; no
retained world or public deployment is part of this construction.


## Signed Mini v6 result

The canonical signer and independent inspector both completed successfully.
`var/oracle-runtime-v6/oracle-runtime-v6.spk` is 97,205,848 bytes, SHA-256
`383d6fe7eeaee7b54f1ab00c42dc2c2301a520abfee1a2fa6f4b0a903f12ebd9`.
Its decoded archive is 520,269,200 bytes, with all 15,372 members matched against
stage `20199e7adaaab6e1f51b4cc13c17f69668472aa48edb68a9f87c98679f31af3a`.
The signature identifies the existing Oracle application and version 6. The
independent inventory SHA-256 is
`7dc313fd3280341f3eceeb1399f8be1bf05ba93052f3873c7537a09d40749d5d`.
Standard archive bounds passed; the shared-data inventory remains unchanged.

Mini lane worktree `oracle-runtime-v6` contains three new integration files:
`deploy/oracle/runtime-v6-receipt.json`, `deploy/oracle/data-selection-v6.json`,
and `deploy/oracle/runtime-v6.md`. This is artifact preparation only. No retained
Mini world, installed grain, or public deployment was changed. Signing keys
remain outside the stage and package; only public identity is in the receipt.
