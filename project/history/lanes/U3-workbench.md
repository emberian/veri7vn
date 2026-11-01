# U3: callable Workbench operations

The Workbench adapter now directly calls four existing implementations: exact
CSV/TSV cell lookup, document passage reading, retrospective sensor analysis and
ProseFold composition of supplied attributed sentences. It publishes executable
examples and input schemas with availability, units, required source hashes and
limitations. It accepts inline data rather than caller-selected host paths or
network endpoints. The consumer is the appliance service's existing single
worker; Mini supplies the enclosing admitted call.

## Changed files

Tracked additions:

- `tools/oracle_workbench/operations.py`
- `tools/oracle_workbench/README.md`
- `tests/oracle_workbench/test_operations.py`
- This report.

Private upstream edits for root's next release patch:

- `var/ap1-upstream-slim/workbench/sources.py`: adds `FilesOrgan.lookup`;
  refuses differing table cells or equally relevant differing passages rather
  than selecting a lexical winner; a no-match response no longer claims that
  nothing in the documents states the fact; cache invalidation checks each
  file's name, size and nanosecond mtime rather than only the maximum mtime.
- `var/ap1-upstream-slim/workbench/sensors_baseline_v4.py`: guards the eight-hour
  historical index just as the two-hour and 48-hour indices are guarded. Short
  histories no longer index before the beginning of the list.

No original `upstream/`, immutable candidate, Mini source, running process,
Store or public service was changed. No commits were made by this lane.

## What was checked

The focused suite runs actual upstream modules, without loading the Oracle
engine: 16 tests passed. Catalog examples all return answers on the patched
source; an absent ProseFold default voice correctly marks only that operation
unavailable. A missing or conflicting cell, ambiguous document passages,
unsupported cadence, invalid baseline, nonfinite input, path escape, duplicate
file names and duplicate source IDs refuse. A supplied 16-sample missing suffix
is detected as a dropout at indices 96..112. Prose sources survive composition
and repeated calls return identical output without leaking voice state.

A narrow before/after replay against private source HEAD is retained in
`var/u3-workbench/red-green.json`: two tables containing different honey prices
previously returned 12 from the lexically later filename; the repair returns a
refusal with both cell references. An eight-sample sensor series with a
four-sample baseline previously raised `IndexError`; the repair returns empty
step/drift lists because no eight-hour history exists. The source's negative
index could reference later observations in sufficiently long short-history
inputs; the retained longer control returned identical flags before/after and
is not evidence of a changed real-world classification.

No theorem statements changed. No specialist panels were scored and no new
specialist score, formal answer-proof claim or Mini admission result is claimed.

## Packaging and remaining work

Copy `tools/oracle_workbench/operations.py` to
`runtime/adapter/workbench_operations.py`, and apply both private source repairs.
Existing dependencies are the Workbench files, ProseFold default voice and
NumPy; no new download or pip step is required. The provision lane owns the
component manifest and the service lane owns HTTP/journal integration.

This adapter does not expose the Workbench's server administration, updates,
code builders, outbound MCP, SSH, polling or machine scan. The usage document
maps each to the required host-owned handles/profile and consumer. Sensor flags
and ProseFold fidelity remain heuristic; inline source labels are not verified
facts. Next integration is the composed service/agent call and packaging check,
not another standalone HTTP server or a duplicate implementation of Mini policy.
