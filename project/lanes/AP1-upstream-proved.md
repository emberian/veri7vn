# AP1 — Oracle7 kernel cross-check boundary

Root integration: submitted as [GitHub Oracle7 #1](https://github.com/psiloceyeben/oracle7/pull/1), also ported into the slim appliance patch and [HF slim #1](https://huggingface.co/psiloceyeben/oracle7-slim/discussions/1). Both are proposed changes, not merged. The actual Linux Earth binary also passed the patched process exchange; see the current batch receipt.

26 October 2026. Implemented by Codex in the research GitHub checkout based on
Oracle7 `87b015e`. Root owns integration, commits and any upstream contribution.
No specialist panel was run; there are **no new panel numbers** from this lane.

## What changed

Owned changes:

- `var/universe-20261026/github/oracle7/runtime/admitted/oracle_release_runtime_w551.py`
- `var/universe-20261026/github/oracle7/tests/test_w551_kernel_check.py`
- this report.

The old comparison looked at a yes/no prefix and one floating-point number.
It called unrelated text agreement and accepted different units, later values,
and even zero versus one. It then retained the original answer and marked it
`proved`. The later w557 fold treats any truthy `proved` field as sufficient
support, so fixing only the numerical tolerance would leave an excessive claim.

The new fold records a `kernel_check`, never a new `proved` field or path tag.
It compares the complete display. Literal text, whole yes/no answers, or equal
Decimal numbers in identical surrounding text can agree. All labels, units,
list delimiters and later numbers remain present. ASCII numbers, scientific
notation and U+2212 minus are understood; unfamiliar formats remain unsupported.
The receipt identifies whether agreement was literal or numeric formatting.
This is an untrusted comparison, not a theorem about English interpretation.

Different words, units or templates are unsupported: the original answer remains
available without a proof claim. A finer displayed number that rounds to the
coarser display under half-even or half-up is also explicitly unsupported with
method `display_rounding`; the adapter does not pretend that either rounded
value is the unknown exact result. Other unequal values in the same full numeric
template, or opposite whole yes/no answers, withhold the answer. They retain the
legacy `proved_check:disagree>` path for consumers, remove stale `value`, `kind`
and `proved`, and carry `kernel_check.comparison = "disagreement"` and
`kernel_check.terminal = true`.

Every comparison receipt preserves the kernel's complete reply under `reply`,
including `value`, `kind`, `path` and declared provenance, with an explicit scope
statement. Empty/malformed provenance, missing
theorem declarations, `taken != true`, malformed replies and kernel refusals do
not become proof. The kernel's `value` is deliberately not treated as an exact
rational: Mechanics emits its already rounded display number there.

The executable is now checked against `PROVED.json`'s existing `binaries` SHA256
mapping. Executable copies use digest-bearing names, are checked before an atomic
replacement, and are rechecked on reuse. A same-size stale cached binary cannot
supply the check. Process keys include installation path and digest; a manifest
update retires/reaps the old process instead of silently reusing it. Timeout,
bad JSON and mismatched reply IDs retire the process too. Linux x86-64 remains
the only shipped native target; unsupported platforms leave the parent answer
unchanged. Missing/invalid manifests can recover on a later request.

The JSONL exchange uses nonblocking pipes and one monotonic deadline covering
both request writes and reply reads. A kernel that stops reading cannot block
the caller forever before its read timeout starts. Requests are capped at
64 KiB including framing; replies at 256 KiB including their newline. No I/O
thread survives a timeout. Each request has a fresh ID; unsolicited extra lines
are rejected immediately when seen together, or by ID on the next exchange.

## Consumer contract

```json
{
  "kernel_check": {
    "comparison": "agreement | disagreement | unsupported",
    "method": "exact_text | numeric_format | boolean | numeric_template | display_rounding | unmatched_text | missing_text",
    "terminal": false,
    "reply": {"id": "...", "status": "answered", "response": "...", "value": 10, "path": "...", "kind": "...", "provenance": {}},
    "response": "the kernel's complete displayed response",
    "provenance": {"taken": true, "kernel": "...", "session": "...", "theorems": ["..."]},
    "binary": {"name": "...", "sha256": "..."},
    "scope": "Untrusted full-output comparison; question recognition and theorem premises are not checked. Provenance is declared by the kernel."
  }
}
```

`terminal` is true only for disagreement. `binary` is added by the actual process
boundary; controlled test doubles need not supply it. Receiving/outer folds must
preserve a terminal refusal rather than retrying into an ordinary answered
result. That composition work belongs to AP1's separate runtime-guard lane.

## Evidence and predicted behavior

Read the research report, actual Mechanics SML reply framing, the HOL display
functions, and `Mechanics_Export.thy`'s concrete kinetic-energy example before
implementation. The test response is the actual display for mass 5 and speed 2:
`The kinetic energy is 10 J (KE = 1/2 m v^2 = 1/2 x 5 x 2^2).`
No theorem was added or changed. Existing theorem-name arrays are declarations;
this adapter neither proves their premises nor checks the recognizer.

Predictions exercised through the actual `OracleReleaseRuntimeW551.chat` fold,
with an explicitly controlled parent and kernel:

| Parent / kernel | Outcome |
| --- | --- |
| `10 kg` / `10 m` | unsupported; parent unchanged, no proof |
| `Paris` / `London` | unsupported; parent unchanged, no proof |
| `0` / `1` | withheld; terminal disagreement |
| `10; second result 5` / `10; second result 900` | withheld |
| `10.00 kg` / `10 kg` | numeric-format agreement; no proof |
| `0.68 kg` / `0.675 kg` | rounding-compatible but unsupported; no proof |
| `−10 m` / `10 m` | withheld |
| complete identical Mechanics reply | exact-text agreement; full provenance retained |
| missing or empty provenance | no check receipt or proof claim |
| same-size executable update | new digest-bound process answers |

Check run from the veri7vn checkout:

```sh
python3 -B -m unittest discover \
  -s var/universe-20261026/github/oracle7/tests \
  -p test_w551_kernel_check.py -v
```

**18 tests passed in 1.898 seconds.** Includes multiple text, unit, list, Unicode,
sign, scientific notation, malformed-number and rounding subcases; actual fold
outputs; corrupted-copy refusal; stale cache replacement; executable process
upgrade; timeout cleanup; blocked initial and cached-process writes; partial and
oversized replies; oversized requests; duplicate replies; invalid UTF-8 and deep
JSON; malformed reply recovery; manifest recovery; and the
architecture guard. Process tests run small portable script fixtures, not the
shipped Linux executables. `git diff --check` passed for the upstream checkout.

## Limits and remaining work

This is a bounded upstream fix, not a new specialist or fleet qualification.
No corpus, full engine, shipped Linux kernel, Isabelle build or specialist panel
was run. Exact templates intentionally sacrifice cross-check coverage instead
of claiming to interpret equivalent paraphrases or convert units. Whole-output
numeric formatting is an observed display comparison; it does not establish
that digits in prose are physical quantities or that an original claim is true.

Manifest hashes bind bytes to trusted installation configuration, not to a signed
publisher, a theorem proof artifact or a hostile mutable filesystem. Installations
must remain immutable while serving; this does not close every local file race.
The manifest is reread for each request but a running process is not rehashed on
every call. Its digest is the identity checked before spawn.

Outer-fold terminal refusal propagation, appliance exposure and a refreshed
kernel distribution remain separate integration tasks. No commits or messages
to external people were made by this lane.
