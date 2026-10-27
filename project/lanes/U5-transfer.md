# U5 transfer time: ordinary and direct specialist registration

The changed source now contains an installable transfer-time specialist through
the existing specialist manifest, combiner and standing-list contracts. The
compact request `How long does it take to transfer 1GB at100Mbps?` returns
**Ideal transfer time: 80 seconds**, with the 100% utilization assumption and
absence of startup delay stated explicitly. With explicit utilization, the answer
uses it. GB/GiB and Mbps/MB/s retain their different meanings.

This is **locally enabled untrusted Python**, not an upstream-admitted specialist,
not a fresh held-out admission, and not a proved kernel. Those limits accompany
ordinary reply provenance, direct discovery and direct result data. No shipped
specialist panels were scored in this lane; no fleet scoreboard or new theorem
claim is made. No full Engine or candidate build was launched here. Root owns
patch export, candidate-v2 construction and the coordinated real-Engine check.

## Integration

The new `root/specialists/_gate/standing_extensions_v1.txt` registers
`data-transfer-v1`. The existing w554 fold consults this separate local-extension
list only after the parent, star stage and owner stage have failed to answer.
The original combiner loads the manifest and organ. This is not a per-question
adapter shortcut and does not add a special service endpoint.

Only a recognized generic reading decline is eligible. Existing answered replies,
private paths, all precision guards (including P5/P7), chained self/identity/veto
paths, same-name and weight guards, unresolved
references, terminal refusal receipts, and unrecognized decline paths remain
unchanged. The fallback requires exactly one answering specialist and the explicit
locally-enabled/unqualified manifest state. It does not reuse the old core
provenance or copy a prior proof/value receipt onto the new answer.

Direct discovery already finds standing-list references in modules of the actual
runtime inheritance chain. The new list therefore registers
`specialist.data-transfer-v1.answer` without a second service registry. The
adapter now accepts optional, bounded manifest qualification metadata and includes
it in `implementation.qualification` plus user-readable limitations. Existing
manifests without that field retain their prior descriptor shape. Invalid or
oversized qualification data disables only that entry. A declaration is expressly
labelled source metadata, not independent admission evidence.

The direct operation retains the organ's raw qualification and exact fraction
calculation. Direct calls still bypass global head guards, as their declaration
already says. The organ itself accepts only supplied numerical inputs and reads
no private files or network state.

## New contract and controls

U1 required explicit utilization. U5 deliberately adds an ideal estimate when
utilization is omitted, with an explicit assumption in the answer. It also accepts
compact `1GB at100Mbps` and `How long to` wording. U1 source and its old verdict
are unchanged; their admission is not inherited by this different implementation.
This uses native local enablement rather than pretending to have installed a
freshly admitted Workbench extension.

The recognizer requires the entire question to match. A startup delay, another
rate, repeated utilization, or an appended request is not silently discarded.
Rate must be positive; size nonnegative; utilization in (0,100]. Unit case is
significant. Arithmetic uses exact fractions before 12-significant-digit display.
The bounded grammar, input sizes, supported units and explicit limitations are
in the new specialist README.

Sixteen new independent expected cases were written before implementation in
`tools/usage/specialist/u5/expectations.json`. The new source panel contains these
as development controls; its held-out list is empty. There is no `ADMIT` verdict
or admission log copied into the folder.

Measured through the actual organ/combiner and w554 extension path with a
**controlled generic parent reply**:

| Result | Count |
|---|---:|
| Valid cases answered correctly | 10/10 |
| Invalid cases left unanswered | 6/6 |
| Wrong answers or false assertions | 0 |
| Published Workbench general questions taken by this organ | 0/924 |

Examples beyond the original request: 9 GB at 300 Mbps, 60% utilization gives
400 s; 2 GiB at 128 MiB/s gives an explicitly ideal 16 s; 7.5 MB at 2.5 MB/s,
50% utilization gives 6 s; 3 KiB at 8 kbps, 40% utilization gives 7.68 s.
The independent scorer requires a time in seconds and the correct ideal/estimated
mode; echoed numbers or a missing ideal-utilization assumption do not pass.

The actual operations discovery, loader and direct-call methods were exercised
on an isolated filesystem containing this specialist. The actual w554 module
supplies the runtime class and list references; its parent is controlled, and
unrelated historical lists are absent in that test fixture. This is a lightweight
component consumer, not an invented full-Engine result.

## Checks and retained evidence

Commands and final results:

```
.venv/bin/python -B -m unittest discover \
  -s var/ap1-upstream-slim/tests/transfer_extension -v
# 8 tests passed

.venv/bin/python -B -m unittest discover \
  -s tests/appliance -p test_transfer_qualification.py -v
# 5 tests passed

.venv/bin/python -B -m unittest discover \
  -s tests/appliance -p test_operations.py -v
# 10 existing operation tests passed
```

The tests cover every new domain case, units and assumptions, original-answer
priority at all prior stages, privacy/precision/terminal refusals, quoted and
compound requests, no forged admission state, proof/provenance cleanup, general
panel overlap, discovery/invocation, malformed and oversized qualification, and
unchanged legacy descriptors. Source diff whitespace checks also passed.

Root review caught the first draft's overly broad eligibility for P-coded
precision declines and chained self/identity/veto paths. The final version
preserves every `precision_guard:` segment and these explicit chained guard
tokens; P5/P7 and chained controls pass through the actual fallback unchanged.
A further composition check covers valid qualification metadata pushing an
otherwise valid descriptor over its 24 KiB cap. Failure now reconstructs a small
unavailable descriptor instead of retrying the oversized partial one. That test
and the ten existing operation regressions pass.

Reproduce the retained component receipt with a new output name:

```
.venv/bin/python -B tools/usage/specialist/u5/measure_components.py \
  --out var/usage-20261027/specialist/component-receipt-3.json
```

Existing receipt:
`var/usage-20261027/specialist/component-receipt-2.json`. It contains complete
component replies, direct descriptor/result, source hashes and scope labels.
`frozen-hashes-v2.json` in the same directory records the exact implementation and
private-test inputs. The full-Engine input pack for root's coordinated run is
`tools/usage/specialist/u5/cases.json`; independent expectations are beside it.

## Changed paths and packaging handoff

Root approved these exact shared paths before edits. Mutable private source:

- `root/specialists/data-transfer-v1/organ_transfer_v1.py`
- `root/specialists/data-transfer-v1/manifest.json`
- `root/specialists/data-transfer-v1/panel.json`
- `root/specialists/data-transfer-v1/scorer.py`
- `root/specialists/data-transfer-v1/README.md`
- `root/specialists/_gate/standing_extensions_v1.txt`
- `root/fable-content/oracle-m-series-2026-08-15/self_loop/admitted/oracle_release_runtime_w554.py`
- `tests/transfer_extension/test_transfer_extension.py`

These paths are beneath `var/ap1-upstream-slim/`. w554 also closes its standing-list
file handles after reading, which removed the ResourceWarning observed when the
new path was exercised.

Public tracked changes:

- `tools/appliance/operations.py`
- `tests/appliance/test_transfer_qualification.py`
- `tools/usage/specialist/u5/cases.json`
- `tools/usage/specialist/u5/expectations.json`
- `tools/usage/specialist/u5/measure_components.py`
- This report.

Frozen adapter SHA-256:
`ea53d47f2c284bf4939dd8a008f0609660ca0026636724b529ce7f69de6057ed`.
Frozen w554 SHA-256:
`edeadeb4f65ed7abc4568471912fa8884d6761d0698175046ebf5c1add8550f3`.
The provisioner has these hashes. Root exports the private-source patch; candidate
v2 must include it and refresh the operations component lock while retaining the
other eight component bundles. Historical release hashes, prior verdicts and
immutable candidates were not edited. No geometry-v4, word-problem or r468 files
were changed. No commits, subagents, full Engine launches or builds were performed.

Remaining qualification: run the original compact question and all fresh controls
through the complete candidate, inspect the direct descriptor/result there, and
check preserved core answers and private guards. Those observations will decide
whether later folds affect the new fallback. This report does not count component
success as completed full-appliance use.
