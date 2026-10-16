# Prototype boundary and recovery

Native platform source lives under `src/isabelle/`. The earlier Python expression/
DAG/C experiment proved only pure expression/DAG correspondence, not Oracle7
interpretation, routing, state, database behavior, C emission or Python migration.
It is not a production dependency.

Inspect its recoverable source without changing the shared tree:

```sh
git show 9e4f619869a4a37eff09c25a0950d0113cc033c1:o7ir/kernels.py
```

That commit contains `o7ir/`, root `isabelle/`, generated C/ML artifacts and their
coupled runners. Upstream audit tools and isolated native experiments remain useful
research, with their stated limits; reuse requires actual statement/consumer review.
