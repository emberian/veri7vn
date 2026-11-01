# U1 specialist: transfer time with explicit units and utilization

The new specialist turns a real Oracle7 decline into a useful transfer-time
estimate through a runnable local consumer. It is not installed into the passing
appliance. No shipped specialist panels were run; there are no new fleet scoreboard
numbers. The measurements below concern a new local panel using the original
Workbench's six checks and real retained core replies.

## What people can do

A person estimating an upload or backup can ask:

> How long does it take to transfer 3 GB at 120 Mbps with 80% utilization?

The demonstrated consumer answers **250 seconds**, explains its 24,000,000,000
bits / 96,000,000 effective bits per second calculation, and states constant
utilization and no startup delay. It keeps the original Oracle reply separately.
The original reply asked what “it” referred to. This extra answer came from the
new specialist, not from rewriting or relabelling that reply.

GB means decimal bytes, GiB binary bytes, Mbps bits per second, and MB/s bytes per
second. The rate and utilization must be explicit. Lowercase ambiguous units,
negative sizes, zero rates, utilization outside (0,100], repeated utilization,
and added startup delays are not answered. The supported grammar is deliberately
small and documented in `tools/usage/specialist/README.md`.

## Real tasks and measurements

Expectations were written before querying. The 12 initial tasks included eight
valid calculations and four invalid or incomplete requests. All 12 got HTTP 200;
all 12 core replies were clarifications. **0/8 valid tasks completed, 4/4 invalid
tasks withheld, no false assertions.** The invalid replies were generally
unhelpful: eleven questions in the batch received “What does ‘it’ refer to?”
because of “How long does it take…”. The alternative “How many seconds to
download…” wording also declined, so the extension addresses a computation gap
as well as a route problem. Core computation latency median was 10.35 ms; HTTP
query median 138.988 ms, maximum 2675.424 ms. These exclude process startup.

The development values include 1 GB at 100 Mbps = 80 seconds; 1 GiB at the same
rate = 85.89934592 seconds; 1 GB at 100 MB/s = 10 seconds; and 5 GB at 100 Mbps,
80% utilization = 500 seconds. The independent literal expectations live beside
the cases. No expectation is computed by importing the organ.

A separate 12-item held-out panel was authored before implementation. Its eight
valid cases use different quantities, prefixes and wording; four must-decline
cases cover negative size, zero utilization, extra delay and conflicting values.
A second shared-runner batch captured all actual core replies. Again, eight
valid cases declined and four invalid cases were withheld. HTTP query median
134.026 ms, maximum 2218.992 ms; core median 10.35 ms.

The original Workbench `exam.py` and its general panel were copied into isolated
scratch, along with the specialist. The exam replayed exact real core replies;
it made no invented engine responses and required every panel question to exist
in retained evidence. All original six checks ran:

| Check | Development | Held-out |
|---|---:|---:|
| Correct, including appropriate non-answers, core alone | 4/12 | 4/12 |
| Correct after local composition | 12/12 | 12/12 |
| Additional correct answers | 8 (needs 3) | 8 (needs 3) |
| Answered wrong | 0 | 0 |
| False assertions on must-decline items | 0 | 0 |
| General questions taken | 0/924 | 0/924 |
| Identity questions taken | 0/5 | 0/5 |
| Specialist median, Workbench's rounded measurement | 0.00 ms | 0.00 ms |
| Budget | 10 ms | 10 ms |
| Original gate decision | WOULD PASS | ADMIT |

The gate's median includes many quick out-of-domain calls and is rounded; it is
not a precise in-domain cost measurement. The four appropriate non-answers in
each total do not mean four useful explanation responses. Workbench's live
composition retains the core's reply when the specialist withholds.

The held-out panel was examined once in this scratch instance, is not a secret
third-party panel, and does not establish broad language coverage. “ADMIT” is the
original Workbench's local replay decision, **not installed appliance admission,
not Mini admission, and not a theorem**. An additional fresh real-engine query,
not in either panel, exercised the runnable consumer and returned 250 seconds.

## Files and checks

Owned source files:

- `tools/usage/specialist/cases.json`, `expectations.json`, `heldout-cases.json`:
  initial tasks, prior expectations, separate held-out core queries.
- `tools/usage/specialist/data-transfer/manifest.json`, `organ_transfer.py`,
  `scorer.py`, `panel.json`: complete Workbench specialist folder.
- `tools/usage/specialist/examine.py`: isolated copied-Workbench exam using exact
  retained real core replies; hashes code and evidence.
- `tools/usage/specialist/ask.py`: real shared-runner consumer using unchanged local
  admission and the Workbench core-first composition rule.
- `tools/usage/specialist/README.md`: contract and executable workflow.
- `tests/usage/specialist/test_transfer.py`: semantic and composition regressions.
- This report.

Exact focused check:

`.venv/bin/python -B -m unittest discover -s tests/usage/specialist -v`

**8 tests passed**. They cover bit/byte and decimal/binary differences, exact
fraction output, echoed numbers failing the scorer, unsupported added conditions,
ambiguous units, numerical boundaries, identity questions, core answer
preservation and guard veto preservation. No Isabelle build ran. There are no
new theorem statements: the Python recognizer and arithmetic are untrusted.

A separate scratch copy also confirmed the original gate behavior: admitted
before modification, `changed` after editing its organ, and replaying its spent
held-out panel raises `this held-out set was already used once; write new held-out
items for a new exam`. The admitted consumer copy was not modified.

Retained evidence under `var/usage-20261026/specialist/`:

- `baseline-1/`: full 12 baseline replies and transport bytes.
- `heldout-core-1/`: full 12 held-out baseline replies and transport bytes.
- `workbench-1/receipt.json`: source/evidence hashes and both six-check verdicts.
- `workbench-1/data-transfer-explicit/`: locally admitted immutable copy.
- `consumer-1/answer.json`: fresh question, untouched core reply, composed answer.
- `gate-controls.json`: file-change and spent-panel controls.

Core tip: `oracle_release_runtime_w436`. Candidate source revision:
`083e3a6c0e2cfc131e62bdc16cb4ec1346194635`. Deployment receipt SHA-256:
`5e2115181f1b6f0b3fb27894e8c9838f1cf526e5242021420283779dd220517b`.
Original Workbench exam SHA-256:
`86d8a4b1b1c649854e44785d9c1451dd39462ed1c9e4c7d3c070b5ae3c43fb18`.
These identify the observed inputs; the adapter does not independently attest
all deployed contents.

## Remaining work and ownership

The appliance, original upstream, shared registry, and private AP1 source were
unchanged. Scratch copied roughly 150 KiB of Workbench code and general-panel
data, not the multi-gigabyte stores. The reusable consumer runs now, but only as
an explicit local wrapper; no native Oracle route or conversation-memory change
was attempted. Installing the source as a regular Workbench extension needs a
fresh held-out exam against that actual installation. Formal verification and
integration into a verified family are separate work with no present claim.

The most useful next core repair is to distinguish the grammatical “it” in “How
long does it take…” from an unresolved reference. That issue was sent to root.
The most useful extension growth would be structured size/rate inputs or explicit
startup-delay composition, with a new panel; silently ignoring extra conditions
would make the current specialist less trustworthy.
