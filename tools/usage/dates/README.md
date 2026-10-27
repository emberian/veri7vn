# Dates with their actual precision

A date such as `1564-04-01T00:00:00Z` does not tell the reader whether the source
specified a day, a month, or only a year. This workflow keeps that information
beside the existing relation store without modifying it.

The source pack covers 195 entities and 200 entity/property pairs: the selected
P569/P570 rows from four shipped specialist panels, eight original precision
regressions, and Jane Austen for the actual conversation follow-up. The source
sidecar is 2,548,330 bytes. This is bounded coverage and a reusable import path,
not complete date coverage. Active readers decline dates with unavailable or
mismatched precision metadata; supported coarser dates remain answerable.

## Build the small sidecar

```sh
.venv/bin/python -B tools/usage/dates/import_precision.py \
  --runtime var/usage-20261026/candidate-final \
  --selection tools/usage/dates/selection-panels.json \
  --cache var/usage-20261026/dates \
  --out var/usage-20261026/dates/new-date-precision.json \
  --fetch
```

Select 1–256 entity IDs and up to eight properties per entity, at most 2,048
pairs. Source reads are bounded to 8 MiB each, each selected property to 100
claims/values, and the sidecar to 16 MiB. Up to four workers share a 1.2-second
request pace and honor retry/backoff responses. `--fetch`
authorizes fetching missing public snapshots. Omit it to reproduce from the
cached snapshots without network access. An existing output is never overwritten.
The input relation SQLite file is opened immutable and read-only. Only indexed
queries for the selected entity/property pairs are made.

The importer reads Wikidata's JSON and RDF exports from the same revision. It
joins a statement ID to its RDF value node, checks precision/calendar/timezone
agreement, and binds the **exact RDF literal** to the existing store value.
It never guesses a conversion or treats the first day of a month as a placeholder.
Raw snapshots remain in scratch; the sidecar preserves the selected claims,
references and qualifiers, revision IDs, source URLs and snapshot hashes.

Wikidata's [date documentation](https://www.wikidata.org/wiki/Help:Dates) explains
precision, calendars, uncertainty qualifiers, and the different BCE conventions
of JSON and RDF. The importer preserves both representations instead of applying
one convention to the other. The original relation-store builder was not found
in this distribution; the four-column legacy schema and exported values show
what was lost, not which unavailable source line discarded it.

## Runtime input contract

Package these new files together with the corrected readers:

- `root/relstore/date_precision_v1.json`
- `root/wander-train/date_precision_v1.py`

The default path is relative to `ORACLE7_ROOT`; `ORACLE7_DATE_PRECISION` can select
an alternate sidecar for controlled testing. Runtime performs no network access.

The JSON contract has `schema: "oracle7-date-precision-v1"`, `version: 1`, a
`legacy_store` declaration, and `records`. Each record contains:

- `subject` and `property`: canonical Q/P identifiers.
- `source`: JSON/RDF URLs at the same revision, hashes, observation timestamp.
- `legacy_literals_observed`: exact values from the selected immutable store.
- `statements`: the complete selected property claims, including deprecated
  claims; each time-valued claim also retains its RDF time node.
- `bindings`: exact `(legacy_literal, statement_id)` matches.

The helper looks up `(subject, property, exact literal)`. It checks metadata
consistency and uses the source's best rank, excluding deprecated claims. An
explicit Gregorian/Julian request selects a matching sourced representation;
it does not perform a calendar conversion. Unknown or conflicting metadata is
visible rather than inferred. Unsupported calendars are not silently relabeled.

The public helper entry points are `render(value, question, subject, property)`,
`available(...)`, `evidence(...)`, and `interval(value, subject, property)`. Context is required to
use the sidecar. Readers check `available` before asserting a date; `render`
alone offers an unavailable-metadata diagnostic for inspection. It preserves
requested/coarser precision and qualifiers;
`evidence` exposes exact statements and references. `interval` gives conservative
calendar-local bounds only when supported. Circa, unknown qualifiers, unknown
calendars and missing metadata cannot establish an order. Overlapping intervals
cannot establish which event occurred first.

## Check the implementation and the real engine

```sh
.venv/bin/python -B -m unittest discover -s tests/usage/dates -p 'test_*.py' -v

.venv/bin/python -B tools/usage/run_batch.py \
  --runtime PATH_TO_NEW_IMMUTABLE_CANDIDATE \
  --cases tools/usage/dates/cases.json \
  --out var/usage-20261026/dates/replay-new
```

`DATE_TEST_SOURCE` selects the corrected private source directory for unit checks;
by default the tests use `var/ap1-upstream-slim/root/wander-train`. The question
pack and expectations were recorded before the baseline run. Retain original
answers and inspect actual routes; helper tests alone do not establish engine
integration. No theorem claims come from this workflow.

The bounded shipped-panel measurement uses unchanged specialist scorers:

```sh
.venv/bin/python -B tools/usage/dates/score_date_panels.py \
  --runtime var/usage-20261026/candidate-final \
  --source var/ap1-upstream-slim/root/wander-train \
  --sidecar var/ap1-upstream-slim/root/relstore/date_precision_v1.json \
  --out var/usage-20261026/dates/new-panel-measurement
```

It selects only forward P569/P570 dev/heldout questions for actors, novelists,
mathematicians and chemists. It is not a full six-criterion score. See the U2
lane report for source-bound explanations of scorer disagreements. The separate
`consumer-cases.json` pack checks Austen conversation continuity, an explicit
Gregorian request, and date ordering; run it against the new immutable candidate
with the same shared runner and a fresh output directory.


The active earlier runtime comparison consumer in `oracle_release_runtime_w426`
uses the same interval operation. It must not choose a presidency, telescope or
other unrelated year from prose as a birth date. Unknown/overlapping date orders
return the existing terminal refusal receipt. The nine-question consumer pack
checks this active consumer separately from date rendering and the 192-row panel
slice. A passing direct helper check alone does not establish that routing works.
