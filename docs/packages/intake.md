# Inert package intake and draft source storage

Implementation under `src/packages/intake/` consumes C01/C04/C05 and the
workbench audit/interaction requirements. Intake stages exact bytes; it does not
parse Python/Isabelle semantics, execute scorers, run theories, admit native objects,
qualify behavior, activate a release or contact external services.

## Entry points and boundaries

`Intake.zip(path, format, limits)` and `Intake.directory(path, format, limits)`
return `Staged`. Explicit formats are Oracle7-original and native-development.
The former requires a package-root `manifest.json`, the latter `package.json`;
these are inert file-presence recognizers, not descriptor-schema validators.
A ZIP may have one common wrapper folder. Files retain exact bytes and portable
relative paths. Source identity hashes length-delimited ordered paths and bytes,
independent of ZIP ordering/compression and friendly origin label. The exact archive
is retained separately. Directory intake has no invented original archive.

`exam_log.jsonl` / `exposure.jsonl` are exposure records, preserved byte-for-byte
with the originating intake record. Sender identities asserted inside those bytes are
not authenticated by intake; typed exposure-policy interpretation remains the
qualification consumer's responsibility. Sender verdict files remain sender evidence;
none is renamed into recipient acceptance. Executable source (including native
`.thy`/ML), binary tools and opaque unknown files remain unresolved. Classification
is navigation assistance, not an executable allowlist or truth assertion. Malformed
JSON is retained for later inspection; it cannot make schema validation pass.

`Content` defensively copies inputs and public outputs. A revision identifies
source content and parent lineage; `Intake.patch` takes expected source revision,
file path, UTF-8 **byte** start/end, exact expected original bytes and replacement
bytes. It rejects stale revision/content, out-of-bounds/overlapping/same-position
edits, malformed replacement UTF-8 and split codepoint boundaries. Multiple edits
are prepared together; rejection yields no modified revision or stored draft head.
Bytes outside edited spans are unchanged, including opaque expert text. It does
not establish that a patch targets a native recipe or preserves its meaning. Native
source parser/proposal validation and PIDE/JS position conversion remain consumers.

## Bounded archive and directory handling

Defaults: 32 MiB archive, 8 MiB/member, 64 MiB total expanded payload, 2048 entries,
512 UTF-8 bytes/path, depth 24 and compression ratio 200. Set smaller trusted-host
policies as needed. Reads are bounded even when advertised sizes lie. Expansion
limits are checked both before decompression and against actual bytes. This is a
memory-bounded whole-package reader with defensive copies, not a streaming huge
corpus loader; source-import must provide a separately designed large-data path.

ZIP processing checks a terminal EOCD, single disk, ordinary ZIP central directory,
member count, local/central order/name/flags/method agreement, contiguous disjoint
local data, size/CRC, data descriptors and actual compressed sizes. It rejects
ZIP64, encryption, unsupported methods/flags, alternate Unicode-path extras,
symlink/special-file Unix modes, unknown local members, hidden/prefixed/trailing
bytes, truncated structures and malformed deflate data. Compatibility deliberately
supports bounded ordinary STORED/DEFLATED archives rather than guessing unsupported
variants. Empty directory members are validated, never extracted.

Portable paths reject traversal, absolute/drive paths, backslashes, empty/dot
segments, non-NFC names, control characters and leading/trailing segment spaces, Windows reserved/ambiguous names,
case collisions and file-parent collisions. Originals are never extracted to member
paths: objects are stored by digest in a host-private directory. Directory intake
uses `SecureDirectoryStream` relative traversal with `NOFOLLOW_LINKS` for root
ancestors and members; an unsupported filesystem provider fails closed. The caller
must supply a real, nonsymlink root path (for example macOS `/private/...`, not its
`/var` symlink). Replaced file metadata is checked after reading. This establishes
an observed exact byte snapshot, not a filesystem-wide atomic snapshot or guarantee
against concurrent same-metadata in-place writes. Acquisition of actively changing
sources needs an external snapshot/stop policy if that consistency is required.

## Immutable objects and the single host journal

`SourceObjects` stores forced immutable blobs, intake records and source revision
manifests in a **trusted host-private** directory. Files are SHA-256 named and verified
on read; input members never become filesystem extraction paths. A forced temporary
inode is published by an atomic no-replace hard link and its directory is forced
before a head can reference it. Unsupported hard-link/directory-force providers fail
rather than silently weaken durability. Existing differing/corrupt objects are not
overwritten. An interrupted unreferenced object is harmless; cleanup/retention must
be coordinated with the host and never infer active authority from object presence.

Intake records retain original archive locator, exact original entries, origin label,
format and source identity. Draft source records retain their originating intake
record through edits, so originals/exposure are recoverable after reopening rather
than orphaned by source editing. Storage manifest locators and source revision IDs
are intentionally distinct. `recover`/`recoverIntake` validate bounds/checksums and
reconstruct inert records, never execute them.

`Drafts` prepares immutable storage then changes a draft head only through injected
`DraftJournal.head/compareAndAppend`. The adapter must use the host's single-writer
journal transaction, check access/current lifecycle, compare exact expected head,
retain history, and acknowledge only after durable commit. A lost CAS leaves only
an unreferenced prepared object; no head is overwritten. This is source-edit CAS,
not package activation. No SQL database or publication registry is created here.
The host's operation identity/replay, epoch and generated authority association
remain required for authoritative service operations.

Raw `SourceObjects` access is host-internal. It must never become a client hash
read endpoint: a client-held old locator cannot bypass retirement/forgetting. The
service must obtain current protected source association access through the host
before every read/edit and invalidate forgotten derivatives. A valid checksum is
not access permission or a native theorem.

## Validation status

The queued `tests/packages/intake/check.scala` compiles canonical production/test
sources with bundled Scala/JVM, then runs targeted ZIP/directory/patch/recovery
fixtures. The script uses no network dependency fetches. Exact command and results
are recorded below. Native admission/recipe meaning, active publication,
clean recipient usability and full retention integration are not claimed here.

First compiled execution passed 21 targeted fixtures on Isabelle2026-RC1's bundled
Scala 3.3.8/JVM (macOS ARM64). Production sources and the real
`src/runtime/host/WorkspaceStore.scala` were compiled, then tests exercised actual
host source-head create/edit/revoke/reopen, original/exposure recovery, and denial
of protected reads after revocation. The test `Journal` is used only for explicit
lost-CAS injection; durable recovery tests use the host's SQLite single-writer
implementation. No native semantic theorem is claimed by these conformance checks.

The compile script produced one benign warning for its top-level `getClass` parent
classloader lookup; compilation and all assertions ran successfully. The initial
sandbox run was blocked by Isabelle startup `sysctl`; the authorized serialized
execution outside that sandbox passed without changing global settings.
`tests/packages/intake/evidence/compiled-run.json` and `checks.json` preserve the
executed closure and named assertions before the shared driver slot was reused.

The production adapter `HostDraftJournal` delegates to
`WorkspaceStore.head/withSourceHead/compareAndAppend`. `Drafts.read` and `originals`
materialize bytes inside the same host lifecycle monitor as revocation, so the
read linearizes before revocation or is denied afterward. Source head CAS plus
revoked tombstones survives reopening. Source objects remain internal; this is
not an invitation to expose raw manifest locators over the client protocol.

Subsequent review tightened immutable-store preflight bounds before blob writes and
Unicode case-fold collision detection. The final integrated run passed **24 fixture
groups**, including ordinary internal-space filename preservation, against the host's
updated constructor/bounds implementation. Inputs remained stable. The serialized
driver took 29.09 seconds including the warm fixture build and Scala compilation/run;
this is development-check cost, not a package-intake performance measurement.
`tests/packages/intake/evidence/final-compiled-run.json` pins the final compiled
closure and `final-checks.json` lists every observed group. That 24-group record
precedes the root-review repairs below and does not certify their changed source.

Reproduce the compiled source/host-consumer checks through the shared build queue:

```sh
python3 tools/dev/check-native \
  --session Veri7vn_Dev_Driver_Test --session-root tests/dev/session \
  --scala-script tests/packages/intake/check.scala \
  --input src/packages/intake \
  --input tests/packages/intake/IntakeTests.scala \
  --input src/runtime/host/WorkspaceStore.scala --timeout 180
```

The script is snapshotted automatically. Evidence JSON is intentionally outside
that compile input closure to avoid a receipt hashing itself. The warm HOL fixture
only obtains the designated serialized Scala test slot; it is not a theorem about
intake. The actual production/test sources are compiled from canonical files, not
copied implementations. Final reported results must come from `INTAKE_SUMMARY` in
the Scala log, not merely driver exit status.

## Root review repairs

`Drafts.edit` now obtains both source revision and origin record inside
`DraftJournal.withHead`, checking the exact expected locator while the host lifecycle
monitor still protects materialization. Patching then uses that retained snapshot;
final head CAS still rejects a concurrent edit or revocation. A stale locator alone
can no longer trigger raw object recovery after the current association is revoked.
The deterministic regression revokes through the real host immediately before the
materialization scope and poisons the old fixture manifest; any former raw-read bypass
would fail integrity rather than return the required unavailable/conflict outcome.
The protected callback must remain uncalled.

ZIP namespace validation includes explicit directory members: a regular file `a`
plus empty directory `a/b/` is rejected, while explicit directory `a/` plus file
`a/b.txt` remains valid. These two concrete review findings add exactly two fixture
groups. The resulting integrated run passed **26 fixture groups**, with stable
inputs, in 22.85 seconds including the warm fixture/Scala compile-and-run driver.
`tests/packages/intake/evidence/review-compiled-run.json` pins this current source
closure and `review-checks.json` lists all observed groups. These supersede the
24-group pre-review evidence for the two changed code paths.

Prepared immutable objects may remain after a lost CAS or concurrent revocation.
Managed erasure, object reachability/retention and cancelled-work cleanup remain
explicit downstream service responsibilities; source-head revocation is not a claim
that every prepared payload has already been physically erased.
