# Current recipient operations

Version: revision-2 development, 2026-10-15. The source client and resident client
share managed source objects; their command surfaces currently differ.

| Goal | Actual operation | Boundary |
|---|---|---|
| Import original/native source | Source launcher: `WORKSPACE import-original/import-native NAME PATH OPERATION_ID`; browser Import | Retains source, does not run or admit it |
| Inspect/edit | Source launcher `list`, `inspect NAME`, `source NAME PATH`, `migration NAME`, `edit`; browser Inspect/Open/Save | Revision/token and expected bytes protect concurrent edits |
| Run installed mathematics | Resident `--workbench run 'the product of 6 and 7' [INTERPRETATION_INDEX]`; browser Run mathematics | Uses installed capability, not the edited draft |
| Inspect a durable request | Resident `--workbench result REQUEST_ID`; browser Refresh result | Reports native status, licensed HTML and available provenance |
| Cancel | Resident `--workbench cancel REQUEST_ID`; browser Cancel request | Waits for durable native acknowledgement |
| Forget request | Resident `--workbench forget REQUEST_ID --confirm`; confirmed browser action | Withdraws dependent results; physical erasure follows cleanup barrier |
| Build/admit draft | Pending real host/client construction join | Source storage/materialization is insufficient |
| Profile/refine/export/activate specialist | No complete recipient workflow yet | Required for handoff acceptance |

The full source edit signature is:

```text
WORKSPACE edit DRAFT MANIFEST REVISION PATH START_BYTE END_BYTE EXPECTED_FILE REPLACEMENT_FILE OPERATION_ID
```

Spans are half-open UTF-8 byte offsets. Expected-file contents must exactly equal
the selected original bytes. Use the current `inspect` values; after a successful
edit inspect again. An operation ID identifies that operation, so use a new ID for
a different edit. Prefer the browser for ordinary whole-file text editing.

Resident commands belong after all runtime options: `--workbench` consumes the
remaining arguments. The runtime requires its matching packaged Isabelle classpath,
workspace, images and session roots. Follow the actual package's launch plan in
[deployment staging](../deployment/local-staging.md); there is no stable complete
installed authoring launcher to substitute here. A local successful sum/product
launch and restart does not establish clean recipient installation or deployment
of edited packages.

`run` prints a request ID, observes for up to one minute and succeeds only for
`accepted_exact`. If observation expires, keep the ID and inspect the same durable
workspace: expiration does not establish refutation or cancellation. An ambiguous
input requires an actual native alternative index; the browser retains the original
bytes for at most five minutes while a choice is pending. Meaning previews for
alternatives remain missing.

Recovery starts by reopening the same workspace and inspecting retained sources
or request IDs. It does not replay historical requests. Source revision, native
candidate, qualification and active capability are different objects: a matching
hash, receipt or historical success does not re-create native authority. See [native recovery](../formal/native-recovery.md). Current development sources
`docs/workbench/diagnostics.md` and `docs/packages/lifecycle.md` describe adapters
still being integrated; their source status does not establish installed behavior.

If import rejects an ancestor symlink, choose its physical path (`/private/var/...`
instead of a `/var/...` alias on macOS). If the workspace is locked, close its
existing owner. If a save conflicts, reopen and reconcile. If a native diagnostic
names an old revision, inspect that captured source before changing current text;
a byte span in an old file must not highlight unrelated current content.
