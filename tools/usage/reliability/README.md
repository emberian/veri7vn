# Check answer stability

This pack asks 15 everyday questions and checks ten relationships between their
answers. Expectations were written before the first engine run. It checks
paraphrases, changed values, changed requested quantities, irrelevant numbers,
negative numbers, zero boundaries, and contradictory premises.

Run a fresh engine experiment using the shared runner:

```sh
.venv/bin/python -B tools/usage/run_batch.py \
  --cases tools/usage/reliability/cases.json \
  --out var/usage-20261026/reliability/run-N
.venv/bin/python -B tools/usage/reliability/check_pairs.py \
  --results var/usage-20261026/reliability/run-N/results.jsonl \
  --out var/usage-20261026/reliability/run-N/pair-report.json
```

Both output locations must be new. The checker exits 1 when a task or pair
fails. A pair passes only when both answers match their independent expectations
and the expected relationship holds. Two identical refusals do not pass a pair
that expected numerical answers. The JSON distinguishes a correct scalar, safe
refusal, needless refusal, wrong answer, unparsed answer and transport failure.
It accepts only explicit scalar answer forms; it never hunts through arbitrary
provenance or citations for the expected number. Missing or duplicate IDs are
errors. Raw replies stay untouched in the runner's receipt.

This is an untrusted, scalar-level experiment checker, not a theorem or a scorer
for the shipped specialist panels. It does not establish dimensional correctness,
truth of provenance claims, or the usefulness of refusal wording. A safe refusal
only means the engine did not assert a value for an undefined/inconsistent case.
The lane report reviews those limitations and wording separately.

`geometry_ambiguity.patch` is a concrete repair for the independently observed
contradictory-length answer. It applies to `root/wander-train/word_problems_v1.py`
of the source checkout whose original SHA256 is
`391dca52e670889d7ba28d2883359878d5e2ba1891f31830c103af8af9e0d221`.
The root-approved source checkout was edited; the passing appliance and upstream
were kept read-only. Geometry roles must bind explicitly to length units;
conflicting duplicates, unmatched dimensions and mixed-unit raw arithmetic are
refused. Equal repeated bindings and unitless identifiers are accepted. This
small repair does not expand the prose grammar or solve general contradictions.

Narrow tests require the source checkout, or an explicit module path:

```sh
RELIABILITY_WORD_MODULE=/absolute/path/to/word_problems_v1.py \
  .venv/bin/python -B -m unittest discover -s tests/usage/reliability -v
```

Without the variable they use the approved source checkout under
`var/ap1-upstream-slim/`. The tests cover the checker and geometry role binding.
