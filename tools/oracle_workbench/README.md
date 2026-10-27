# Workbench operations for the appliance

`operations.py` exposes four operations using Oracle7's actual Workbench code.
The appliance service loads `WorkbenchOperations(runtime, workspace)` in its
single worker and publishes `catalog()` alongside the other operation providers.
`invoke(operation_id, arguments)` returns the complete result. Mini still owns
permission, admission and resource accounting; this Python adapter is untrusted.

| Operation | Inputs | Result |
| --- | --- | --- |
| `workbench.tables.lookup` | One inline CSV/TSV file, exact selector column/value, result column | One cell and its file/row/column reference; missing or ambiguous selections refuse |
| `workbench.documents.query` | Inline text/Markdown files and a question | A matching quoted passage, or a refusal retaining equally relevant differing passages |
| `workbench.sensors.analyze` | Uniform 900-second readings, explicit baseline length, ideal band and unit | Original retrospective fluctuation flags, latest ideal distance and baseline spread |
| `workbench.prose.compose` | Up to eight attributed sentences, topic, optional voice text | Original ProseFold arrangement, source IDs and lexical decomposition results |

The catalog contains strict JSON input schemas, concrete executable examples,
source-file hashes, units and limitations. Required default dependencies are
checked per operation. A missing voice corpus, NumPy or implementation makes the
operation unavailable without hiding unrelated operations. The structured table
operation requires the new `FilesOrgan.lookup` method in the accompanying
`workbench/sources.py` patch.

These are direct calls to the reader, sensor and composition implementations.
They do not manufacture an English prompt and send it through `Engine.chat`.
Document search itself is the upstream keyword-based passage reader, so its
question remains a string. There is no factual or semantic-equivalence proof:
source attributions are supplied by the caller, and ProseFold's check compares
content words. Source labels cannot establish trust or permission.

## Example

```python
operations = WorkbenchOperations(runtime, workspace)
reply = operations.invoke("workbench.tables.lookup", {
    "file": {"name": "stock.csv", "text": "item,price\nhoney,8\n"},
    "selector_column": "item",
    "selector_value": "honey",
    "result_column": "price",
})
# reply["value"] == "8"; reference names stock.csv, row 2, column price.
```

The service's request journal wraps this invocation. Direct module calls do not
add their own request IDs, retry policy, HTTP server, authentication or journals.

## Bounds and data handling

The runtime and workspace paths are operator-selected and disjoint. Caller file
names must be unique basenames with a supported suffix. The adapter accepts at
most eight files and 32 KiB of combined UTF-8 text. It copies only those supplied
bytes to a temporary directory under the assigned workspace, invokes the real
reader and removes that temporary directory. Replies include input SHA-256s.
There is no caller-selected host path, URL, command or import name.

Sensor input has at most 2,048 readings; null means a missing 15-minute sample.
There must be at least 32 baseline samples, two nonmissing baseline readings and
a nonempty observation suffix. Numeric values must be finite and within ±10¹².
The algorithm is retrospective and heuristic. No flags does not mean healthy;
a single channel cannot distinguish a sensor problem from a real-world change.

Prose uses at most eight one-line records of up to 1,024 characters and optional
voice text of up to 8,192 characters. Synonym rewriting is disabled. The adapter
restores the original module's voice/context globals after every call; all calls
use the appliance's one worker thread. A failed lexical check withholds the
composed text while retaining diagnostic sentences and sources.

## Broader Workbench integration

The rest of the Workbench remains a real integration target, with different
resource and permission needs:

| Surface | Required integration |
| --- | --- |
| Live HTTP/MQTT/serial sensors and SSH/MCP connectors | Host-assigned connection handles and explicit network/device/tool grants; never arbitrary targets embedded in a query |
| Local machine scan | A separately authorized observation of the intended machine; a query grain's process namespace is not the operator's host |
| Uploaded file libraries | Workspace-owned object handles and explicit retention, followed by these same readers |
| Specialist builders, exams and learned programs | A writable builder profile with bounded code execution; promote reviewed artifacts into a new pinned runtime |
| Self-examination and paired sensor attribution | Additional structured supplied-data operations using the existing baseline/self-exam code; describe statistical hypotheses and sampling conventions |
| Essay gathering from Oracle answers | A bounded multi-query operation on the same Engine thread, retaining each answer/source and the outer request's failure semantics |
| Workbench HTML UI | A consumer of these APIs under the same per-grain authority and state, not an exposed upstream admin/update server |

These surfaces are not advertised as callable by this module yet. The existing
query permission must not silently become remote-command or arbitrary-code
permission merely because the upstream Workbench has those buttons.

## Run the checks

```sh
.venv/bin/python -B -m unittest discover -s tests/oracle_workbench -v
```

The tests use the actual private upstream modules under `var/ap1-upstream-slim`;
set `ORACLE_WORKBENCH_RUNTIME` to a materialized patched runtime to test that
artifact. They cover callable examples, citations, conflicts, exact selection,
path/data refusal, actual dropout detection, missing dependencies and the source
regressions. They do not score shipped specialist panels or exercise Mini
admission. Root's composed appliance run supplies that separate evidence.
