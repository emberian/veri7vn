# Inert package intake

`src/packages/intake/` implements C01/C04/C05 source staging. `Intake.zip(path, format, limits)` and `Intake.directory(path, format, limits)` return `Staged` for Oracle7-original (`manifest.json`) or native-development (`package.json`) roots. Presence recognition does not validate descriptor semantics or execute Python, Isabelle, scorers, tools, or theories.

Files retain exact bytes and portable paths. Source identity hashes ordered length-delimited paths/bytes, independently of ZIP order/compression and origin label. ZIP originals are retained separately; directory intake invents no archive. JSONL exposure logs and sender verdicts remain attributed originals. Classification assists navigation; executable and unknown files stay unresolved.

`Content` copies inputs and public outputs. `Intake.patch` binds expected revision, path, UTF-8 byte range, expected original bytes, and replacement. It rejects stale content, overlap/same-position edits, invalid UTF-8, split codepoints, and invalid bounds atomically. Untouched bytes remain exact. Native recipe meaning and PIDE/JavaScript position conversion belong to downstream consumers.

## Bounds and filesystem contract

Defaults are 32 MiB/archive, 8 MiB/member, 64 MiB expanded payload, 2048 entries, 512 UTF-8 bytes/path, depth24, ratio200. Advertised and observed sizes are checked. This whole-package reader is memory bounded; large corpora need a separate path.

Ordinary single-disk STORED/DEFLATED ZIPs require terminal EOCD, consistent central/local order, names, flags and methods, contiguous disjoint data, CRC/size agreement, and valid descriptors/deflate. ZIP64, encryption, unsupported flags/methods, alternate Unicode paths, symlink/special modes, unknown members, prefixes/trailers, and truncation reject. Directory entries are validated, never extracted.

Paths reject traversal, absolute/drive/backslash forms, empty/dot segments, non-NFC/control characters, segment-edge spaces, reserved Windows names, case collisions, and file-parent collisions. Originals are digest objects, never extracted to member paths. Directory reads use `SecureDirectoryStream` with `NOFOLLOW_LINKS`; unsupported providers reject. Root ancestors must be real nonsymlink paths, such as `/private/...` on macOS. Metadata is rechecked after reading; actively changing trees still require an external snapshot policy.

## Objects, journal, access

`SourceObjects` stores verified SHA-256 blobs and manifests in an owner-controlled directory. Forced temporary inodes publish by atomic no-replace hard link followed by directory force; unsupported providers reject. Differing existing objects are not overwritten. Intake origin/archive and source parent lineage remain recoverable through edits.

`Drafts` prepares immutable storage, then uses the host's single `DraftJournal.head/compareAndAppend` writer with exact-head CAS, lifecycle checks, history, and durable acknowledgement. `HostDraftJournal` delegates to `WorkspaceStore.head/withSourceHead/compareAndAppend`. Read/edit materialization occurs under the same lifecycle monitor as revocation; a stale locator cannot trigger an unprotected object read. Lost CAS leaves an unreferenced prepared object, not an overwritten head.

Raw object locators are host-internal, never client read capabilities. Current protected association checks govern every read/edit. Checksums establish integrity, not permission, native admission, activation, or physical erasure of all prepared payloads.

## Checks

The current intake receipt covers 26 fixture groups: ZIP/path rejection, exact edits, real SQLite source-head races/reopen/revocation, originals/exposure recovery, and protected materialization. Evidence: `tests/packages/intake/evidence/review-compiled-run.json` and `review-checks.json`. Its two review cases cover revocation before materialization and file/directory namespace collisions.

```sh
python3 tools/dev/check-native \
  --session Veri7vn_Dev_Driver_Test --session-root tests/dev/session \
  --scala-script tests/packages/intake/check.scala \
  --input src/packages/intake \
  --input tests/packages/intake/IntakeTests.scala \
  --input src/runtime/host/WorkspaceStore.scala --timeout 180
```

Use `INTAKE_SUMMARY` from the Scala log, not driver exit alone. Canonical production sources are compiled without network fetches; the warm HOL fixture supplies the serialized test slot, not a theorem about intake. Native recipe/admission, governed reveal, active publication, and complete retention cleanup require their composed consumers.
