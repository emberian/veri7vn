# Current recipient operations

Use the shipped launcher from the [qualified local workshop](../tutorials/installed-source-workshop.md), with private state outside the installation:

```sh
V7_COMMAND=/absolute/path/to/installation/current/bin/veri7vn
"$V7_COMMAND" verify
"$V7_COMMAND" launch --state /absolute/private/source-state --surface source -- list
"$V7_COMMAND" launch --state /absolute/private/runtime-state --surface workbench -- run 'the sum of -2 and 3'
```

| Goal | Command after the surface's `--` | Effect |
|---|---|---|
| Import source | `import-original/import-native NAME PATH OPERATION_ID` | Retains inert original/native source |
| Inspect/edit | `list`, `inspect NAME`, `source NAME PATH`, `migration NAME`, `edit`; browser Open/Save | Revision/expected-byte checked edits |
| Package dependencies | `impact NAME` in current source client | Declared package graph only; check packaged version |
| Run installed mathematics | `run 'the product of 6 and 7' [INDEX]` | Uses installed capability, not edited draft |
| Inspect result | `result REQUEST_ID` | Native status, licensed HTML and available provenance |
| Cancel / Forget | `cancel REQUEST_ID`; `forget REQUEST_ID --confirm` | Durable acknowledgement; erasure follows cleanup barrier |

```text
edit DRAFT MANIFEST REVISION PATH START_BYTE END_BYTE EXPECTED_FILE REPLACEMENT_FILE OPERATION_ID
```

Offsets are half-open physical UTF-8 bytes; expected contents must match. Inspect again after Save. Reconcile conflicts against current source; retain submitted text. Use a new operation ID for a different operation. Close `serve` before another process opens the same workspace.

`plan` previews the same launch arguments without dispatch. `locate --tutorial NAME` finds verified bundled assets. Import paths must be physical and symlink-free. Reopen the same state to recover sources/results; recovery never replays requests.

`run` observes for up to one minute and succeeds only for `accepted_exact`. A wait timeout is inconclusive. Ambiguous readings require a native index; pending original bytes expire after five minutes. Useful meaning previews remain a client gap.

The [standalone evidence](../../tests/deployment/evidence/standalone-aae0d7dd.json) covers finite macOS source/native/restart operations. Edited-package build/admission/activation, profile/refine/export, Linux and independent recipient acceptance require their own completed workflows. See [client contracts](../workbench/client.md) and [native recovery](../formal/native-recovery.md).
