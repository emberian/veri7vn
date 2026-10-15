# Native scaffold check

From the repository root, run:

```sh
python3 tools/dev/check-native
```

The check uses `/Applications/Isabelle2026-RC1.app/bin/isabelle`, bundled HOL,
one build job and two ML threads. It builds saved heaps for `Veri7vn_Core` and
`Veri7vn_Scaffold_Tests`. It does not build HOL-Analysis or the older prototypes.
Python 3 with the standard library is sufficient on macOS/Linux.

Override the executable using `--isabelle /absolute/path/to/isabelle` or
`VERI7VN_ISABELLE`. An override is recorded, not assumed compatible with RC1.
`--timeout 600` sets a per-command wall-time cap; on timeout the launched process
group is terminated and failure recorded. This is a development build bound,
not the future product's search-resource semantics.

Isabelle's `USER_HOME` is set for child processes to
`var/native-scaffold/user-state`; ordinary `HOME` and global Isabelle settings
are not changed. Local build state and receipts live in ignored `var/`.
The installed Isabelle distribution and bundled HOL remain external toolchain
dependencies; this is not a hermetic or redistributable runtime image.

The same command safely reruns incrementally. A checkout-local advisory lock
prevents concurrent invocations of this entrypoint and is released by the OS
when it exits. Do not run other Isabelle builds concurrently: legacy scripts
and manually launched processes do not share this lock. No cache is deleted.
Some execution sandboxes block Isabelle's startup `sysctl`; use the normal
approved execution context if that happens, rather than modifying global setup.

`var/native-scaffold/receipt.json` records toolchain version/settings, host,
commands, source hashes, timing, and assertion names. `build.log` and `smoke.log`
hold detailed output. Cached successful sessions retain their assertion log;
the receipt does not pretend they were re-executed on an incremental no-op.
Source hashes and the generated export data hash are checked again at completion.
Concurrent edits mark the receipt `unstable` and fail the command; they do not
trigger an automatic rebuild loop. This catches changed final contents, not an
edit that is reverted between the two snapshots. Immutable build inputs remain
work for the deployment builder.

The driver also parses `tests/scaffold/package.json` once and emits a data-only
ML export list consumed by the actual native test. It rejects duplicate JSON
keys and escapes every UTF-8 byte of names; the receipt records the descriptor
and generated artifact hashes. This is a fixture bridge, not a general package
loader. Schema validation remains a separate check:

```sh
.venv/bin/python schemas/check.py tests/scaffold/package.json
```

The smoke checks local definition and locale-contract transport, exposes a
hidden theorem hypothesis, exposes it as an implication after context export,
and retains the full statement. It resolves declared exports in the actual
theory context and rejects unresolved and wrong-kind exports.
`Veri7vn_Inspection` is a diagnostic helper,
not an admission validator. It does not implement the policies in C02 or confer
any assurance route. Review `docs/contracts/` for those evolving contracts.

Source layout:

- `src/isabelle/`: minimal native implementation session.
- `tests/scaffold/`: integration theories with positive and negative assertions.
- `experiments/`: retained isolated native feasibility probes, excluded from this
  build graph.

The earlier root `isabelle/`, `o7ir/`, and `generated/` prototype and its runner
were removed. See the [cleanup and Git recovery record](../../docs/design/prototype-cleanup.md).
The native scaffold and upstream audit/research tools are retained independently.
