# Use the real Oracle engine

The usage tools cover these concrete jobs. Each directory contains its request
pack, independent expectations, and instructions; full live replies remain in
the local experiment directories described by the lane reports.

| Job | Tool |
| --- | --- |
| Find supported requests | [Discovery guide](discovery/README.md) |
| Research with citations | [Research dossier](research/README.md) |
| Check available facts and entities | [Coverage inspector](coverage/README.md) |
| Ask about a supplied document | [Passage preparation](documents/README.md) |
| Calculate invoices and interest | [Finance workflow](finance/README.md) |
| Calculate with explicit physical quantities | [Engineering worksheet](engineering/README.md) |
| Combine several calculations | [Composition workflows](composition/README.md) |
| Convert number bases | [Computing workflow](computing/README.md) |
| Inspect evidence claims | [Evidence inspector](evidence/README.md) |
| Compare paraphrases and boundaries | [Reliability pack](reliability/README.md) |
| Estimate file transfer time | [Workbench extension](specialist/README.md) |
| Exercise corrections and follow-ups | [Conversation lane](../../project/lanes/U1-conversation.md) |

These are experimental caller tools and scoped repairs. Explicit local
calculations are labelled separately from Oracle answers. A successful workflow
does not imply that the engine understands the equivalent ordinary question.

The repaired appliance from this batch is `var/usage-20261026/candidate-final`.
Pass that directory with `--runtime` to use the repairs. The runner's default
remains the original baseline so existing recorded experiments and the local
Workbench extension keep their explicit deployment identity. See the
[integrated results](../../project/USAGE-2026-10-26.md) and
`integration-cases.json` for the final targeted replay.

Run a small, sequential experiment against the packaged candidate:

```sh
.venv/bin/python -B tools/usage/run_batch.py \
  --cases tools/usage/my-lane/cases.json \
  --out var/usage-20261026/my-lane-run-1
```

The output directory must be new. Cases are a JSON array with 1–30 objects:

```json
[{"id":"leaves-1","conversation_id":"literature","text":"Who wrote Leaves of Grass?"}]
```

IDs are preserved exactly: 1–80 ASCII letters, digits, underscores or hyphens.
Each encoded adapter request is limited to 16 KiB. Repeated IDs are allowed for
replay/conflict experiments. Cases sharing a conversation ID share conversation
state; different runner output directories have separate workspaces.

The runner starts the existing private adapter, which constructs the real
OracleEngine. The default runtime is `var/appliance-20261026/candidate`. Source
and data are read-only inputs; state is assigned to `OUT/workspace`, and bytecode
writes are disabled. The runner never imports the mutating upstream launcher.
For physical write protection, run the candidate on a read-only mount; this
operator harness itself is not a filesystem sandbox.

Use `--runtime /absolute/path/to/appliance` to compare a newly provisioned
candidate. Keep the original output directory: a new run is additional evidence,
not a replacement for a failed answer.

Only three runners can hold engine slots at once. They use advisory locks under
`var/usage-20261026/slots`, wait up to 30 minutes and occasionally print waiting
status. The adapter inherits its slot lease, so killing the runner cannot free a
slot while that adapter is still alive. Never delete slot lock files or start a
second engine outside this runner to bypass the bound.

Default engine query timeout is 30 seconds and startup timeout is 120 seconds;
operators can set `--query-timeout` and `--startup-timeout` from 1–300 seconds.
HTTP exchanges have absolute deadlines and a 2 MiB reply bound. Queries are not
retried. A fatal backend reply stops the batch; each remaining case is explicitly
recorded as `not_run`. SIGINT/SIGTERM and failures clean up only the recorded
adapter process and its newly created process group.

`results.jsonl` retains every response field, HTTP status, latency, and exact
response bytes as base64. `response.reply` contains upstream provenance without
rewriting or upgrading its claims. `summary.json` records startup capabilities,
counts, stop reason and process exit status; `adapter.log` holds engine logs.
The command exits zero when every case obtained an HTTP response without a fatal
backend failure. This does not mean every answer is correct: 400/409 responses
may be intentional experimental results, and clarification/withholding is distinct
from a runtime failure. Evaluate correctness against independent expected results.
These experiments are not shipped specialist panel scores or Mini admission.
