# Find a question Oracle can answer

The packaged engine can answer concrete questions that its own help replies do
not explain how to ask. This read-only guide searches the shipped specialist
catalog and manifests, shows example requests, and keeps actual trial replies
separate from advertised capabilities. It never imports or starts the engine.

From the repository root:

```sh
.venv/bin/python -B tools/usage/discovery/guide.py catalog units --limit 1
.venv/bin/python -B tools/usage/discovery/guide.py catalog python --limit 1
.venv/bin/python -B tools/usage/discovery/guide.py catalog author
```

The output is JSON. `declarations` contains task names, routing cues, declared
refusals, sources, and examples read from **dev** panels. Each source has a path
and SHA-256. The guide searches the shipped Workbench index rather than assuming
every specialist folder is active. Even presence in that index does not prove
that the adapter reaches a specialist for every advertised question.

`historical_measurements.cases` contains exact requests and complete engine
replies from the October 26 appliance. `task_judgment` is the lane's review of
whether the request was satisfied, separate from the engine's `status`.
`historical_exact_request_ids` links a dev example to a retained exact trial;
an empty list means no trial retained here. These observations describe that
recorded deployment and wording, not every query in the domain or the current
contents of a later runtime. Use `--runtime PATH` to read another runtime's
current declarations; the historical section remains explicitly historical.

Examples that worked in the initial usage trial:

| Task | Exact request | Actual result |
| --- | --- | --- |
| Author lookup | `Who wrote Leaves of Grass?` | Walt Whitman, with relation and Simple Wikipedia references |
| Arithmetic | `What is 17 times 23?` | 391 |
| Conversion | `How far is 5 miles in kilometers?` | 8.04672 km |
| Conversion | `Convert 5 miles to km.` | 25146/3125 km, the same value |

The two conversion phrasings take different engine routes. The more formal
phrasing is a useful option, not evidence that natural wording is broken.

## Prepare a request without guessing missing inputs

```sh
.venv/bin/python -B tools/usage/discovery/guide.py convert \
  --from-unit miles --to-unit km
```

This returns `needs_input` and “What amount should be converted?” The engine's
reply to `Convert miles to km.` only gave a generic clarification. The guide
asks for the actual missing information before constructing a request.

After the caller supplies the amount:

```sh
.venv/bin/python -B tools/usage/discovery/guide.py convert \
  --amount 12 --from-unit miles --to-unit km --cases \
  > var/usage-20261026/discovery/my-conversion.json
.venv/bin/python -B tools/usage/run_batch.py \
  --cases var/usage-20261026/discovery/my-conversion.json \
  --out var/usage-20261026/discovery/my-conversion-run
```

Use a new output directory for every run. Without `--cases`, the guide returns
both an adapter request (`request_id`, `conversation_id`, `text`) and a runner
case (`id`, `conversation_id`, `text`). It does not send either request.
Supported unit spellings and dimensional compatibility still belong to the
engine. The builder does not infer density to turn mass into volume, invent
an amount, or treat a prepared request as an answer.

## What the service actually advertises

The adapter's `GET /capabilities` gives the protocol, source revision, runtime
tip, deployment receipt metadata, evidence disclaimer, workspace scope and
request/reply/time limits. It does **not** advertise domains, example queries,
required inputs, or a supported grammar. Its receipt hash does not establish
that all deployed files match their receipt. `observations.json` retains the
endpoint response from the measured run.

The original Workbench CLI has `specialists [word]`, `card <id>` and `help`;
those are a different entrypoint from `Oracle7.Engine.chat` used by the adapter.
This guide reads the same specialist index directly and adds request examples
without invoking the original launcher's state/setup side effects.

A concrete Python task discovered this way, `What are the parameters of
random.shuffle in Python?`, returns `(x)` and identifies the stored Python
version as 3.12.3. This does not establish arbitrary code-writing support.
`What does the Python function gzip.GzipFile do?` returns a signature and a
truncated first documentation line; that trial is marked partially completed.

Keep full refusals and provenance. A recorded `answered` status is not enough:
`Can you help me write Python code?` was marked answered but gave only a generic
assistant description. A refusal also does not prove the requested fact is
false or missing from every source. The incompatible request `Convert 5 miles
to kilograms.` did give a useful length-versus-mass explanation.

## Reproduce and inspect

`cases.json` and `expectations.json` define the initial 12-question experiment.
`guided-cases.json` and `guided-expectations.json` retain the five requests
selected or prepared by the final guide. Complete transport results are under
`var/usage-20261026/discovery/`; compact committed observations preserve the
full reply objects. `search-regression-*` preserves an earlier ranking mistake
that selected military units when searching for conversion units; the guide
now ranks matching specialist ID words first.

```sh
.venv/bin/python -B -m unittest discover -s tests/usage/discovery -p 'test_*.py' -v
```

No specialist panels were scored. No theorem is claimed. This is an untrusted
caller aid and a workflow improvement; it does not repair engine help, routing,
reference extraction, or general conversation.
