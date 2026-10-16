# Import, inspect and revise your first specialist

Set `V7_COMMAND` and `V7_STATE` using the [installed workshop](installed-source-workshop.md). This exercise retains original Oracle7 paint source and inspects its native migration proposal; import does not execute Python or admit the proposal.

Acquire the pinned small source example if absent. Check an existing checkout's revision/local edits before reusing it:

```sh
GIT_LFS_SKIP_SMUDGE=1 git clone https://huggingface.co/psiloceyeben/oracle7 upstream
git -C upstream checkout c5d6a29d5bc5e2525078e5a53afa1abf659e4d69
```

No large-store unpacking is required. Recognized `organ_paint_coverage.py` SHA256 is `35ca95a96df508b215eab49a74b0350d1cb8d7b4f2606c58ada81dcaf016609c`.

```sh
V7_ORIGINAL=/absolute/path/to/upstream/workbench/examples/paint-coverage
"$V7_COMMAND" launch --state "$V7_STATE" --surface source -- import-original paint "$V7_ORIGINAL" tutorial-paint-import-1
"$V7_COMMAND" launch --state "$V7_STATE" --surface source -- inspect paint
"$V7_COMMAND" launch --state "$V7_STATE" --surface source -- migration paint
"$V7_COMMAND" launch --state "$V7_STATE" --surface source -- source paint organ_paint_coverage.py
```

Use a physical symlink-free import path. Keep the printed source revision/edit token. Compare original width × height × coats ÷ spread-rate behavior with the proposal: parser, units, default rate, positive dimensions, zero-rate handling and rounding need explicit decisions. Its eighteen historical panel cases remain attributed examples, not fresh holdouts. An original import without native `package.json` still has inspectable source.

Continue with the bundled editable candidate:

```sh
V7_IDENTITY=$("$V7_COMMAND" locate --tutorial retained-identity)
"$V7_COMMAND" launch --state "$V7_STATE" --surface source -- import-native identity "$V7_IDENTITY" tutorial-identity-import-1
"$V7_COMMAND" launch --state "$V7_STATE" --surface source -- serve
```

If already imported, inspect `identity` instead. Read `OBLIGATIONS.md`; Open `Retained_Identity.thy`, add a comment and Save twice. Close with Enter, then reopen source through the CLI and check exact persistence. Preserve expert blocks and reconcile conflicts before resaving.

The retained identity uses existing mathematical operations: zero→zero and one→one support examples, not its universal claim. New carriers/kernels/code setup require a qualified bundle. Build, native admission, empirical qualification and activation remain separate steps; follow the [operation reference](../reference/recipient-operations.md) and [rehearsal](../handoff/recipient-rehearsal.md) for their actual availability.
