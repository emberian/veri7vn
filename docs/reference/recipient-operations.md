# Current recipient operations

Version: revision-2 development, 2026-10-16. The source client and resident client
share managed source objects; their command surfaces currently differ. Set
`V7_COMMAND=/absolute/path/to/installation/current/bin/veri7vn` and use an absolute
private state path. The qualified local installation is described in the
[installed workshop](../tutorials/installed-source-workshop.md).

```sh
"$V7_COMMAND" verify
"$V7_COMMAND" launch --state /absolute/private/source-state --surface source -- list
"$V7_COMMAND" launch --state /absolute/private/runtime-state --surface workbench -- run 'the sum of -2 and 3'
```

| Goal | Actual operation | Boundary |
|---|---|---|
| Import original/native source | Source surface: `import-original/import-native NAME PATH OPERATION_ID`; browser Import | Retains source, does not run or admit it |
| Inspect/edit | Source surface `list`, `inspect NAME`, `source NAME PATH`, `migration NAME`, `edit`; browser Inspect/Open/Save | Revision/token and expected bytes protect concurrent edits |
| Run installed mathematics | Workbench surface `run 'the product of 6 and 7' [INTERPRETATION_INDEX]`; browser Run mathematics | Uses installed capability, not the edited draft |
| Inspect a durable request | Workbench surface `result REQUEST_ID`; browser Refresh result | Reports native status, licensed HTML and available provenance |
| Cancel | Workbench surface `cancel REQUEST_ID`; browser Cancel request | Waits for durable native acknowledgement |
| Forget request | Workbench surface `forget REQUEST_ID --confirm`; confirmed browser action | Withdraws dependent results; physical erasure follows cleanup barrier |
| Build/admit draft | Pending real host/client construction join | Source storage/materialization is insufficient |
| Profile/refine/export/activate specialist | No complete recipient workflow yet | Required for handoff acceptance |

The full source edit signature is:

```text
edit DRAFT MANIFEST REVISION PATH START_BYTE END_BYTE EXPECTED_FILE REPLACEMENT_FILE OPERATION_ID
```

Spans are half-open UTF-8 byte offsets. Expected-file contents must exactly equal
the selected original bytes. Use the current `inspect` values; after a successful
edit inspect again. An operation ID identifies that operation, so use a new ID for
a different edit. Prefer the browser for ordinary whole-file text editing.

Pass source commands after `launch --state STATE --surface source --` and resident
commands after `launch --state STATE --surface workbench --`. The launcher selects
the corresponding packaged JAR and runtime dependencies. `plan` accepts the same
arguments and prints the launch plan without dispatching the application. Tutorial
paths come from `locate --tutorial NAME`.

The shipped launcher has passed source import/reopen, installed mathematics and
fresh-process result inspection outside the checkout. Its bundled identity workshop
has passed two browser Saves and exact source reopening. See the
[standalone evidence](../../tests/deployment/evidence/standalone-aae0d7dd.json).
This finite macOS ARM64 result does not establish deployment of edited specialists,
Linux execution or independent recipient usability.

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
