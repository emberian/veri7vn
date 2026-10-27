# Oracle7 appliance provisioning

This materializer prepares the complete Oracle7 slim 4.9 runtime at
`083e3a6c0e2cfc131e62bdc16cb4ec1346194635`, including its knowledge stores.
It does not run queries, install a service, or grant Mini authority. The query
adapter is documented in [`tools/appliance/README.md`](../../tools/appliance/README.md).

The upstream release carries 19 verified-family binaries for Linux x86-64,
from veri7vn revision `3bf43cff8eaa1c30db2659d186cdcffe9c4f6c61`. They predate
our current repairs. On other architectures, upstream does not run this kernel
cross-check. Packaging their bytes does not qualify their interpretation of a
question or all of Oracle7's answers.

The October 26 candidate adds the current Earth kernel and the tracked
[`patches/oracle7-slim-4.9-correctness.patch`](patches/oracle7-slim-4.9-correctness.patch).
Its [integration receipt](../../docs/deploy/appliance-2026-10-26.json) records
the exact bytes and passing checks. The Earth overlay declaration is retained
in [`earth-overlay-2026-10-26.json`](earth-overlay-2026-10-26.json); supply the
matching Linux binary under `bin/earth` alongside it as `manifest.json` when
rebuilding. This Earth binary uses `libgmp.so.10` and glibc symbols through 2.34.
The upstream 19 kernels remain at their older versions.

The retained local candidate can be started from the veri7vn checkout:

```sh
.venv/bin/python -B var/appliance-20261026/candidate/adapter/serve.py \
  --runtime var/appliance-20261026/candidate \
  --data-root var/appliance-20261026/candidate/root \
  --workspace var/appliance-workspaces/example --port 7070
```

It is a private loopback backend. Mini still needs to assign the workspace and
bind its calling authority; no public Dreggnet service was installed. Full
appliance smoke runs stopped their services after completion.

## Materialize

Use Python 3.12 with `zstandard`, Git, and curl on macOS or Linux. Publication
uses the platform atomic no-replace rename; Linux needs libc `renameat2`. The source can be a sparse
checkout: the materializer reads the exact commit's Git archive, with LFS
smudging disabled, and retrieves each required LFS payload itself.

```sh
GIT_LFS_SKIP_SMUDGE=1 git clone \
  https://huggingface.co/psiloceyeben/oracle7-slim /srv/source/oracle7-slim
python deploy/appliance/provision.py \
  --source /srv/source/oracle7-slim \
  --target /srv/appliances/oracle7-slim-083e3a6c \
  --cache /srv/appliance-cache \
  --adapter tools/appliance \
  --reuse-from /srv/previous-oracle7
```

`--reuse-from` is optional. It reads matching paths, checks their complete
hashes, and **copies** bytes into its own cache. It never links, changes modes,
unpacks, or writes in that old installation. A mismatch simply needs the pinned
release's payload instead. Keep the cache on the target filesystem to share
verified store bytes through hardlinks. Equal-content stores share one cache
object; files from the old installation never share a writable inode with it.

For the repaired candidate, add `--patch
deploy/appliance/patches/oracle7-slim-4.9-correctness.patch` and
`--kernel-overlay /path/to/earth-overlay`. This patch deliberately changes the
published runtime and both weather organs. Historical `RELEASE_HASHES` and
admission verdicts are retained as historical evidence, not rewritten as a new
qualification. Verify the appliance's recorded composition instead; upstream
fresh admission and release checks remain necessary for an official release.

The subsequent real-usage repairs are a second, ordered patch:
`--patch deploy/appliance/patches/oracle7-slim-4.9-usage.patch`. Apply it after
the correctness patch above. It repairs number-base interpretation, numerical
finiteness, conversation state, source/relation matching, conflicting passages,
geometry inputs, energy quantity roles and trailing calculation conditions.
It changes the actual imported copies, including the admitted converter and all
three math-organ versions. The usage patch does not change extracted binaries
or grant fresh upstream admission. See
[`project/USAGE-2026-10-26.md`](../../project/USAGE-2026-10-26.md) for original
failures, measured outcomes and remaining limits.

`smoke.py --runtime DIR --adapter DIR/adapter/serve.py --out NEW_DIRECTORY
--patched` runs five real-engine queries, exact/conflicting retries, shutdown,
restart replay and a complete source-tree file/stat comparison. It requires
the runtime dependencies. The checker stops only processes it started and
retains its report, workspace and logs. It does not run a fleet exam.

Downloads come from the exact HF commit URL. Their sizes and SHA-256 values come
from that commit's LFS pointers. Decompressed stores must also match both the
size and SHA-256 in `PACK_MANIFEST.json`; decompression stops at its declared
bound. Transfers have connection, low-speed, and total timeouts. Failed
construction leaves the destination unpublished and preserves verified cache
objects for another run. A corrupt existing cache object is an error, not a
silent overwrite. There is no automatic cache eviction.

The disk check conservatively reserves room for raw and compressed stores,
possible copies across filesystems, and scratch space. It does not reserve disk
against other processes. Stop other writers or use a dedicated filesystem when
concurrent jobs can consume that margin. This slim release has about 15 GB of
logical unpacked stores; duplicate content reduces physical storage. The
materializer does not inherit Mini's user-upload size limits.

An existing target is never intentionally replaced: publish each version to a
new path. During construction a sibling temporary directory holds incomplete
files. `APPLIANCE.json` records the source commit, every final file's size/hash,
store declarations, patch identities, and historical kernel revision. The last
step renames the completed directory into place. Files are read-only; production
hosts should mount it read-only as well. Directory permissions alone are not a
sandbox or a host admission check.

## Include local repairs

Add `--patch /path/to/reviewed.patch` once per patch, in application order. Each
patch must apply cleanly to the pinned source. The receipt records its SHA-256
and all resulting file hashes. Patches cannot change the store manifest or
store contents without making provisioning fail. The result is a **locally
modified release**, not a new upstream release. Run focused runtime checks for
the selected patch set before promoting it.

The Python interpreter and installed dependencies are not embedded or attested
by `APPLIANCE.json`. Create a dedicated environment using the release's
`requirements.txt` with `-c deploy/appliance/constraints.txt`; the constraint
pins its open-ended zstandard requirement to `0.25.0`. Retain the resolved
environment lock/wheels for production and record it alongside the runtime. The source/data recipe is pinned;
dependency resolution alone does not make the whole host reproducible.

## Add a newer verified family

`--kernel-overlay /path/to/overlay` accepts a directory containing `bin/<name>`
and `manifest.json`. For example, its shape is:

```json
{
  "binaries": {"earth": "<binary SHA-256>"},
  "specialists": {
    "meteorology-v2": {
      "binary": "earth", "flag": true,
      "family": "earth", "session": "Veri7vn_Earth"
    }
  },
  "provenance": {
    "earth": {"source_revision": "<revision>", "build_receipt": "<receipt>"}
  }
}
```

Use the complete intended specialist map for that family, not just the example
entry. The files must be regular files with simple names and matching hashes.
Adding a family cannot silently overwrite one already present. An intentional
replacement must additionally declare `expected_previous: {name: old_sha256}`;
the old bytes must match that digest before replacement. Existing specialist
mappings may change only through an explicitly replaced family.

The merged `PROVED.json` has `commit: null`, preserves `base_commit`, and records
`family_provenance` for every family. Its old parity measurement becomes
`base_parity`. This prevents an appliance containing kernels from different
builds from claiming one source revision or reusing a historical fleet score as
its new qualification. `APPLIANCE.json` also records the overlay manifest hash,
per-family provenance, and final binary hashes. Byte identity checks do not
establish the supplied build receipt's truth; the operator must review the
scoped proof/native/panel receipts before selecting an overlay.

## Run and move it

`--adapter tools/appliance` copies only the finalized `serve.py` and README into
`adapter/`, with their hashes in the receipt. A single service file is also
accepted. The adapter is optional for a stock-runtime comparison artifact.

```sh
PYTHONHASHSEED=0 python /srv/appliances/oracle7-slim-083e3a6c/adapter/serve.py \
  --runtime /srv/appliances/oracle7-slim-083e3a6c \
  --data-root /srv/appliances/oracle7-slim-083e3a6c/root \
  --workspace /srv/oracle-workspaces/example \
  --port 7070
```

The root view includes source modules and small data as well as the large
stores. Keep each service's workspace outside the runtime. One host-owned
workspace maps to one service; requests cannot select another workspace. The
adapter disables automatic unpacking and retains the complete reply envelope.
Mini integration still needs a host-authorized application route to this private
backend; a Python HTTP socket is not that authority boundary.

A portable tar archive preserves the complete runtime and internal hardlinks:

```sh
tar -cf oracle7-slim-083e3a6c.tar -C /srv/appliances oracle7-slim-083e3a6c
shasum -a 256 oracle7-slim-083e3a6c.tar > oracle7-slim-083e3a6c.tar.sha256
```

Record this repository's revision and the resolved dependency environment
alongside the archive. Do not include the reusable download cache,
workspace, credentials, `.git`, or another user's data. Preserve the runtime's
`LICENSE`, `NOTICE`, and `DATA_LICENSES.md`. This recipe does not invoke a Mini
SPK importer or install on Dreggnet; a large operator package needs its own
streaming import, disk allocation, and authority integration.

## Narrow checks

```sh
python -m unittest discover -s deploy/appliance/tests -v
```

These fixtures test package integrity and failure publication, not specialist
answer quality. They include a real Git/LFS-pointer fixture and small compressed
stores so the same production materializer runs without downloading a corpus.
