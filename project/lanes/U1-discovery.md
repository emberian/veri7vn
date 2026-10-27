# U1 discovery: useful questions need a separate entrypoint

No shipped specialist panels were run, and this lane has no panel numbers.
No Isabelle build ran and no theorem is claimed. This is a caller workflow
improvement measured through the passing appliance, not a fleet score or an
engine repair.

A new caller can now search declared tasks, see exact example questions, inspect
what actually happened in retained trials, and prepare a conversion request
without inventing missing information. The consumer is an agent or person using
the appliance API who does not know the engine's supported wording.

## Actual use

All runs used `.venv/bin/python -B tools/usage/run_batch.py` with the immutable
`var/appliance-20261026/candidate` and private workspaces. All 22 requests across
three runs received HTTP 200; no transport or backend fatal error occurred.
The source revision reported by the adapter was
`083e3a6c0e2cfc131e62bdc16cb4ec1346194635`, runtime tip
`oracle_release_runtime_w436`, deployment receipt hash
`5e2115181f1b6f0b3fb27894e8c9838f1cf526e5242021420283779dd220517b`.
Those are metadata and a receipt hash, not independent deployed-file verification.

The first 12 requests had independently written expectations before querying.
They produced four completed tasks, one useful refusal and seven incomplete
tasks:

| Request | Actual outcome |
| --- | --- |
| What can you help me with? | Generic withheld reply; no task guide |
| Show three example questions you can answer. | Generic clarification; no examples |
| Can you convert units? How should I ask? | Generic clarification; no conversion inputs |
| What facts can you look up? | Generic withheld reply |
| Who wrote Leaves of Grass? | Walt Whitman, with relation and Simple Wikipedia references |
| How far is 5 miles in kilometers? | 8.04672 km through units-v3 |
| Convert 5 miles to km. | 25146/3125 km through unit_convert, the same value |
| Convert 5 miles to kilograms. | Useful refusal explaining length versus mass |
| Convert miles to km. | Generic clarification; does not ask for the missing amount |
| What is 17 times 23? | 391 |
| Can you help me write Python code? | Marked answered, but only a generic assistant description |
| Why couldn't you answer that? | Same code-help conversation; generic withheld reply |

There were five engine `answered` statuses, four `withheld`, three
`clarification`. The distinction matters: one `answered` task was not completed,
and one `withheld` reply was exactly the useful behavior needed. End-to-end
query latency median was 0.127324 seconds, maximum 2.795198 seconds. These are
small-run observations including first-query overhead, not a benchmark.

The help refusal contains a blocked generic reply in provenance, including a
claim that the assistant can write code. This lane retains that evidence but
does not promote the blocked response to an answer or infer general code
writing support from it.

## Implemented improvement

`tools/usage/discovery/guide.py` is an explicitly untrusted read-only helper.
`catalog(runtime, query, limit, examples)` reads the shipped Workbench index,
specialist manifests and valid dev-panel examples. It does not import the
launcher, execute a specialist, copy stores, or write candidate state. It
searches task names and routing cues, prioritizing specialist ID matches, and
returns declared tasks, declared refusals, source paths/hashes and usable
examples. It does not turn historical panel scores into live coverage claims.

The candidate has 267 index entries. The bounded source read selected two dev
examples per entry where available: 443 examples across 222 entries. Entries
without selected examples remain declarations, not evidence of unavailable
functionality. These counts describe metadata, not answered tasks.

The guide separately returns complete retained historical replies, deployment
identity, and reviewed task outcomes. A declared example can link to an exact
historical request; neither an exact example nor a successful trial establishes
coverage for every request in that domain. Passing a different `--runtime`
changes the declarations, while measurements remain explicitly historical.

`prepare_conversion(...)` returns targeted questions for missing amount/source
unit/target unit. With all three supplied it emits an adapter request and runner
case. It preserves caller values, rejects non-finite or instruction-shaped
numeric inputs, and makes no claim that a prepared query is supported. Units
and dimensional compatibility remain engine decisions.

`GET /capabilities` currently returns protocol, source revision, tip, deployment
metadata, evidence disclaimer, workspace scope, queue size and resource bounds.
It contains no domains, task grammar, examples or required argument list.
The original CLI's `specialists [word]` and `card` read the Workbench catalog;
they are separate from the adapter's Engine.chat path. The helper uses that
existing source to fill the caller-facing discovery gap without changing shared
API files.

## Tested improvement and retained failure

The first generated guide trial exposed a ranking bug: search for `units`
selected `rel-militaryunits` instead of `units-v3`. Both selected founded-date
questions were withheld. Their replies and original requests are preserved in
`search-regression-observations.json` and `search-regression-cases.json`.
No independent factual expectations had been written for these two mistakenly
selected date questions, so they are not scored as factual failures. The actual
failure was selection for the caller's conversion task. The search now boosts
exact specialist-ID words, and a regression uses competing units and military
units entries.

After that fix, five guide-selected/prepared requests were run against the
same candidate in another private workspace. Four completed, one partially
completed; all five were marked answered by the engine:

| Guided request | Actual result |
| --- | --- |
| What are the parameters of random.shuffle in Python? | `(x)`, labeled Python 3.12.3 |
| What does the Python function gzip.GzipFile do? | Class signature and a truncated first doc line; partial help, not a full explanation of gzip behavior |
| I have 2.5 g. How many pounds is that? | 0.005512 pounds, correct rounded value; its displayed factor is approximate |
| Convert 100 kPa to psi. | 14.50377377 psi, agreeing with independent conversion |
| Convert 12 miles to km. | 301752/15625 km = 19.312128 km |

Guided run query latency median was 0.118682 seconds, maximum 1.301727 seconds.
This does not show that help queries themselves improved; it shows that the
new caller workflow finds and expresses useful concrete tasks. It also exposes
the incomplete Python documentation instead of treating every answer as success.

Narrow verification:

```
.venv/bin/python -B -m unittest discover -s tests/usage/discovery -p 'test_*.py' -v
Ran 9 tests ... OK
```

The tests cover the observed search regression, preserving the distinction
between engine status and task judgment, asking for missing input, preserving
caller quantities, rejecting malformed/non-finite inputs, excluding held-out,
invalid and declined examples, unknown searches and source path/symlink escape.
A full metadata-only read of the 267 declarations also completed successfully.

## Files and remaining work

Changed/new owned files:

- `tools/usage/discovery/guide.py`, `README.md`
- `tools/usage/discovery/cases.json`, `expectations.json`, `observations.json`
- `tools/usage/discovery/guided-cases.json`, `guided-expectations.json`
- `tools/usage/discovery/search-regression-cases.json`, `search-regression-observations.json`
- `tests/usage/discovery/test_guide.py`
- `project/lanes/U1-discovery.md`

Complete transport bytes, summaries, adapter logs and private state remain in
`var/usage-20261026/discovery/{initial,guided,guided-fixed-search}/`.
No candidate, upstream, shared API or frozen file was edited. No Git operation
or subagent was used.

The next shared integration would expose this catalog through the appliance
or a unified caller command. Root can import the helper without launching an
engine. Engine self-help, missing-argument clarification and truncation of
Python documentation remain defects/limitations; this lane has not repaired
them. The initial supported cases demonstrate that discoverability can fail
while the underlying task succeeds, so generic help refusal should not be used
to infer absent conversion, arithmetic or reference capabilities.
