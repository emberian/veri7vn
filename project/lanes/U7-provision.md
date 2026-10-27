# U7 immutable appliance and version 7 package

U7 contains only the committed lazy catalog-loading production change from
`bc945d9`. Its full `APPLIANCE.json` SHA-256 is
`78773bfb4ec72633332dfd67d9a466f4022f2457371fff32d3b673bcd499844c`.
The candidate is `var/usage-20261027/candidate-u7`, its reproducible input recipe
is `deploy/appliance/candidate-u7.recipe.json`, and its composition receipt is
`docs/deploy/appliance-u7-2026-10-27.json`.

Exactly `adapter/serve.py` and `adapter/README.md` differ from U6-v2. Their hashes
are `1152526eed823e0c2740961115605f5df63a45b865e8303eb2dc4dca3d98da5f` and
`62244bf82e3f9d0752c5099af4f8be807e5496adf6b57f93192517559ea29b23`.
All nine component locks, upstream patches, providers, pool, kernels and data
are unchanged. Materialization used verified cache entries without downloading.
The final file inventory and all 4,324 non-store SHA-256/size/mode checks pass.

The service qualification ran nine actual Engine behavioral checks on an
uninstrumented source overlay. Its complete adapter hash map matches this
candidate. Query/replay remained deferred; discovery and real direct invocation
worked; query bytes remained identical after catalog initialization. The original
runner selected its wrapper during shutdown. Separate corrective cleanup
validated the actual recorded process identities and confirmed all three owned
Python processes stopped. This is not a claim of a graceful original harness
pass. Both retained evidence hashes are in the U7 construction receipt.

The Linux code-only image is
`/build/lanes/oracle-tenancy-measure/u7-input/runtime`. A new copy of the U6-v2
code plus a 203,851-byte delta produced it; all 4,309 code files were rehashed
on receipt. The adjacent overlay receipt SHA-256 is
`6d3ccf4397290e785d944485eace104a15930667d7542d2c23355ce7212ee366`.
The same 26 shared-data paths are absent and must be mounted read-only; their
hashes/sizes match the retained public inventory
`32bb3cf1a6337ee2c7b6ec902bb5bfdff11ba1fd5f1fa3b730dc269431b27d0a`.
No 15 GB copy was made. Earlier candidates and Linux inputs remain unchanged.

Root reviewed the behavioral and corrective cleanup evidence and authorized
version 7 signing. New package scratch is `var/oracle-runtime-v7`; it uses the
same canonical signer, independent verifier, pinned Linux rootfs, bridge
`11cb93bc…`, source metadata/launcher snapshot and shared-data selection as v6.
Only the candidate identity and signed application version change. Stage
verification passed with 15,372 members, stage SHA-256
`8e73b5bceeec9de8d171eba2a76c1bdc0bc24b1608d93156a611985a007cfc0c`.
The final signed result is recorded below after independent verification.

This lane adds no theorem statements and reports no new specialist panels. It
performs construction and artifact verification, not Mini receiving or public
deployment. The next consumer is root's fresh version-7 Mini/browser journey.


## Verified signed result

The canonical signer and independent inspector both exited successfully.
`var/oracle-runtime-v7/oracle-runtime-v7.spk` is 97,206,044 bytes, SHA-256
`e860a781dc8b897eadd002f28e388b799de92de0f019f1b357d140a9264a3888`.
Its decoded archive is 520,275,720 bytes; all 15,372 members match the stage.
The signature identifies the existing Oracle application at version 7.
The independently derived inventory SHA-256 is
`dd0b28163c4233676b1c4873af256b67c87f0a4baaaa742d919839b2d4f1a6fc`.
Standard archive limits passed. Version 6 remains unchanged.

New Mini integration files are in the `oracle-runtime-v6` lane worktree:
`deploy/oracle/runtime-v7-receipt.json`, `deploy/oracle/data-selection-v7.json`
and `deploy/oracle/runtime-v7.md`. The v7 selection preserves the existing data
inventory rather than copying or reconstructing data in the package.
The service behavioral pass and separate cleanup correction are explicitly
recorded in the versioned receipt. No graceful original harness pass is claimed.

The new receiving input directory is
`dregg-build:/build/lanes/oracle-v7-acceptance/inputs`; artifact transfer and its
remote hash check are preparation only, not a Store creation or admission.
The next receiving/browser journey is root-owned and consumes version 7 alone.

Transfer exited successfully and all three remote SHA-256 values matched local
files. The received SPK is 97,206,044 bytes with mode 0600. The post-pack receipt
SHA-256 is `9a79efa239c2f581e8d37e878de8f0b8ab276a4be172e50dc4e49333ca81d972`;
the versioned Mini receipt SHA-256 is
`2c78a41c2d9659eaa6d57cb16af2e2ec500f60de9aa8aae649d7957c19c0c07d`.
No Store was created and no shared-data copy was made by this lane.
