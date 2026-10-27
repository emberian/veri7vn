# Transfer-time extension

This specialist estimates time from file size, sustained link rate, and explicit
utilization. It distinguishes 1 GB from 1 GiB and 100 Mbps from 100 MB/s. It answers
complete supported questions and refuses extra conditions it cannot model.

Example:

> How long does it take to transfer 3 GB at 120 Mbps with 80% utilization?

Answer: **250 seconds**, assuming the supplied rate and utilization stay constant
and there is no startup delay. This estimates throughput; it does not predict a
particular Internet connection. Utilization already includes throughput losses.

The code uses exact fractions before displaying 12 significant decimal digits.
It is untrusted Python, with no Isabelle theorem or Mini authority.

## Reproduce the experiment

Run these from the repository root. Every output directory must be new; change
the suffix when collecting another experiment. The shared runner controls access
to the real engine and leaves the candidate and upstream unchanged.

```sh
.venv/bin/python -B tools/usage/run_batch.py \
  --cases tools/usage/specialist/cases.json \
  --out var/usage-20261026/specialist/baseline-1
.venv/bin/python -B tools/usage/run_batch.py \
  --cases tools/usage/specialist/heldout-cases.json \
  --out var/usage-20261026/specialist/heldout-core-1
.venv/bin/python -B tools/usage/specialist/examine.py \
  --dev-evidence var/usage-20261026/specialist/baseline-1 \
  --heldout-evidence var/usage-20261026/specialist/heldout-core-1 \
  --out var/usage-20261026/specialist/workbench-1
```

`examine.py` copies only the original Workbench `exam.py`, its 924-question general
panel, and this specialist into scratch. It runs the original six checks against
exact retained real core replies. A missing question, failed query, or mismatch
between decoded replies and the retained HTTP bytes aborts the replay. Replaying
does not make another engine claim and does not admit anything into the appliance.
The locally authored held-out panel is separate from development cases, written
before the implementation, and examined once in that scratch copy. It is not a
secret third-party test. Creating another scratch copy is not a new held-out set.

The receipt records source and evidence hashes. Workbench invalidates the local
admission if any specialist file changes and rejects a reused held-out set.
Do not copy the experimental verdict into a different installed runtime; examine
there against fresh held-out items before using it as an installed extension.

## Ask a fresh question

The consumer starts a real engine through the shared runner, preserves its reply,
and fills only a permitted decline with the unchanged local specialist:

```sh
.venv/bin/python -B tools/usage/specialist/ask.py \
  --admission var/usage-20261026/specialist/workbench-1 \
  --out var/usage-20261026/specialist/consumer-1 \
  'How long does it take to transfer 3 GB at 120 Mbps with 80% utilization?'
```

`answer.json` separates the original `core_reply` from `composed_reply`. The
consumer follows Workbench's single-turn, core-first rule: it preserves answered
core replies, guard vetoes, and replies outside this specialist's grammar. It does
not add Workbench conversation memory. Refusal explanations from the organ are
available when inspecting it directly; like Workbench, the consumer retains the
core reply when the specialist does not answer.

Supported wording starts `How long does it take to` or `How many seconds to`, then
`transfer`, `download`, or `upload`. Use `at RATE` or `over a RATE connection`, and
end with `with PERCENT% utilization` (or `utilisation`). Supported size units are
`B`, `kB`, `MB`, `GB`, `TB`, `KiB`, `MiB`, `GiB`, `TiB`. Rates are `bps`, `kbps`,
`Mbps`, `Gbps`, `Tbps`, or a supported byte unit followed by `/s`. Case matters
for units. Size may be zero; rate must be positive; utilization must be in (0,100].
Each decimal has at most 18 integer and 12 fractional digits. Scientific notation,
additional delays, multiple rates and conversational follow-ups are unsupported.

## Focused checks

```sh
.venv/bin/python -B -m unittest discover -s tests/usage/specialist -v
```

The scorer requires an explicit time result with seconds units, so echoed input
numbers cannot pass. Expected values are literal independent answers, not calls
to the implementation. See `project/lanes/U1-specialist.md` for measured results.
