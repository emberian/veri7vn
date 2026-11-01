# Signed Python appliance packages

The signed v7 appliance is the qualified 4.9-based Python composition. The
native runtime has separate packaging and qualification. A fresh signed
Mini/agent/browser/restart journey remains unfinished; construction, transfer
and independent Linux HTTP checks do not establish Mini admission or deployment.
There are no specialist-panel scores or theorem statements from packaging.

## Reproduce the construction

Use the versioned recipes and byte-identity receipts rather than the retired
construction reports. These preserve input hashes, component locks, final file
hashes and checks:

| Candidate | Recipe | Receipt |
| --- | --- | --- |
| U5-v1 | [recipe](../../deploy/appliance/candidate-u5-v1.recipe.json) | [receipt](../../docs/deploy/appliance-u5-v1-2026-10-27.json) |
| U5-v2 | [recipe](../../deploy/appliance/candidate-u5-v2.recipe.json) | [receipt](../../docs/deploy/appliance-u5-v2-2026-10-27.json) |
| U6 | [recipe](../../deploy/appliance/candidate-u6.recipe.json) | [receipt](../../docs/deploy/appliance-u6-2026-10-27.json) |
| U6-v2 | [recipe](../../deploy/appliance/candidate-u6-v2.recipe.json) | [receipt](../../docs/deploy/appliance-u6-v2-2026-10-27.json) |
| U7 | [recipe](../../deploy/appliance/candidate-u7.recipe.json) | [receipt](../../docs/deploy/appliance-u7-2026-10-27.json) |

U6 predates the cold-reset optimization and refusal of legacy root-level
`requests.sqlite3`; U6-v2 includes both. U7 adds only lazy catalog loading from
`bc945d9` to U6-v2: `adapter/serve.py` and `adapter/README.md` change. Components,
source repairs, pool, kernels and the shared public-data inventory remain fixed.
The shared-data inventory is
`32bb3cf1a6337ee2c7b6ec902bb5bfdff11ba1fd5f1fa3b730dc269431b27d0a`.
Linux code-only inputs omit 26 public-data paths, which require exact read-only
mounts. No data is reconstructed from the signed package.

Nine actual Engine checks passed on a byte-identical U7 source overlay. The
original cleanup selector chose its wrapper; a separate correction verified the
recorded process identities and stopped all three Python processes. This is not
a graceful original harness pass. Both evidence hashes are in the U7 receipt.
[Linux tenancy qualification](U7-tenancy-qualification.md) is separate.

## Signed artifact identities

Both versions passed the canonical signer and independent archive inspector.
They use the pinned Linux rootfs, bridge `11cb93bc…`, shared-data selection and
Mini package-tool snapshot `30268be06e4f758ccee58c54dafcfe042cdd6336`.
Version 6 declares one resident worker and 128 possible persistent tenant
workspaces; legacy v5 workspaces require a fresh grain. These are declarations,
not receiving acceptance.

| Identity | v6 | v7 |
| --- | --- | --- |
| Scratch artifact | `var/oracle-runtime-v6/oracle-runtime-v6.spk` | `var/oracle-runtime-v7/oracle-runtime-v7.spk` |
| Bytes | 97,205,848 | 97,206,044 |
| SPK SHA-256 | `383d6fe7eeaee7b54f1ab00c42dc2c2301a520abfee1a2fa6f4b0a903f12ebd9` | `e860a781dc8b897eadd002f28e388b799de92de0f019f1b357d140a9264a3888` |
| Decoded bytes / members | 520,269,200 / 15,372 | 520,275,720 / 15,372 |
| Stage SHA-256 | `20199e7adaaab6e1f51b4cc13c17f69668472aa48edb68a9f87c98679f31af3a` | `8e73b5bceeec9de8d171eba2a76c1bdc0bc24b1608d93156a611985a007cfc0c` |
| Independent inventory SHA-256 | `7dc313fd3280341f3eceeb1399f8be1bf05ba93052f3873c7537a09d40749d5d` | `dd0b28163c4233676b1c4873af256b67c87f0a4baaaa742d919839b2d4f1a6fc` |

Mini worktree `oracle-runtime-v6` holds the versioned
`deploy/oracle/runtime-v{6,7}-receipt.json`, `data-selection-v{6,7}.json` and
`runtime-v{6,7}.md`. Signing keys remain outside the package.

The v7 receiving inputs are at
`dregg-build:/build/lanes/oracle-v7-acceptance/inputs`. Transfer and remote hashes
matched: SPK as above, post-pack receipt
`9a79efa239c2f581e8d37e878de8f0b8ab276a4be172e50dc4e49333ca81d972`,
versioned Mini receipt
`2c78a41c2d9659eaa6d57cb16af2e2ec500f60de9aa8aae649d7957c19c0c07d`.
That transfer created no Store and established no admission. Root owns the
remaining receiving and browser journey.
