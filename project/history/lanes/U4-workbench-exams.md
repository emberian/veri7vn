# U4: inspect specialist exams without running them

The appliance can now expose `workbench.specialists.inspect`. It reads a specialist's declaration, retained exam results, panel inventory, and held-out use journal. It calls the actual upstream `workbench/exam.py` functions `status` and `files_sha` on a bounded captured copy. It does not import the specialist or scorer, run an exam, consume a held-out panel, register a specialist, or grant a Mini permission.

## Consumer contract

`tools/oracle_workbench/exam_inspection.py` exports `ExamInspection(runtime, workspace)`, with `catalog()` and `invoke(operation_id, arguments)`. Package it as `runtime/adapter/exam_inspection.py`. The only fixed runtime dependency is `runtime/workbench/exam.py`; its imports are Python standard library modules. No additional Python packages, assets, private-source edits, or upstream patches are required.

Arguments are a strict object:

```json
{"specialist_id":"meteorology-v2","location":"packaged","dev_examples":0}
```

`location` defaults to `packaged`; it can also be `workspace`. `dev_examples` defaults to zero and accepts integers zero through three. The specialist ID is an ASCII identifier, at most 80 characters. Callers cannot supply a filesystem path, URL, Python module, or executable.

The fixed selected folder is `runtime/root/specialists/ID` or `workspace/workbench-local/specialists/ID`. Runtime and workspace must be disjoint. Invalid arguments raise `ValueError`. A missing specialist, malformed captured metadata, resource limit, or refused file produces `status: withheld` and a stable `reason`. Successful inspection uses `status: answered`, even when the recorded specialist is draft, broken, changed, failed, or expired.

Response sections:

- `declaration`: selected manifest identity, kinds, and byte digest.
- `recorded_exams.dev` and `.heldout`: redacted retained metrics, decision, record digest, and `origin` (`publisher_retained` or `workspace_retained`). `execution_observed_by_inspector` is always false. Retention in the local workspace is not evidence of an observed local measurement.
- `workbench_admission`: actual upstream state and the recorded decision, plus `files_binding`. Binding reasons distinguish `missing_files_sha`, `invalid_files_sha`, `files_match`, and `files_changed`. File binding uses upstream's exclusions; it does not authenticate the record or establish numerical correctness.
- `panel`: availability, declared dev/heldout item counts, source-byte digest, and optional dev questions only. A portable split-object panel also has the same canonical held-out digest used by upstream. Published arrays of split-tagged rows are inventoried but do not pretend to be that portable digest. Missing panels remain unavailable; nothing is fetched.
- `heldout_usage`: retained journal counts and matching portable-panel digest use counts, without writing or consuming a use.
- `inspector`: exact captured upstream `exam.py` SHA-256. `snapshot` records captured byte and entry counts.
- `exam_executed: false`, `specialist_code_executed: false`, `runtime_registered: null`, and `mini_permission: not_assessed` keep the authority boundary explicit.

Held-out questions, answers, raw failure rows, and reason strings are not returned. Dev answers are also omitted. No network registry lookup is performed.

## Capture and bounds

The adapter opens fixed folders and regular files with no-follow directory/file descriptors, refuses symlinks and nonregular entries, and checks identities before and after capture, including the parent-name link. This detects source replacement or modification during capture. All subsequent upstream inspection reads the temporary captured bytes, which are removed on completion. Results describe that snapshot, not later source changes.

Directory enumeration uses a bounded `scandir` iterator before sorting; it does not materialize an unbounded directory listing. Limits are 256 entries, 2 MiB per file, 8 MiB aggregate, eight directory levels, 512-byte relative paths, and bounded JSON depth/node/numeric sizes. Duplicate keys, nonfinite numbers, and invalid Unicode are refused. The journal has its own 512-line/128-KiB bound. Even files excluded by upstream's digest must fit the capture limits; large specialist bundles may therefore be withheld. No claim is made about external dependencies covered by neither the folder nor upstream's file digest.

## Actual checks

`python3 -m unittest discover -s tests/oracle_workbench -p test_exam_inspection.py -v`: **17 tests passed**. Tests use the actual private-runtime `exam.py`, not substitute status/hash implementations. They cover bound versus stale admission, missing/invalid hash explanations, draft/dev and expired/failed states, missing/outside/published panels, source-record empty panel hashes, JSON/numeric rejection, strict caller arguments, symlink/FIFO refusal, every capture budget (including an oversized real directory that stops enumeration at the entry budget plus one), replacement during capture, missing manifest/specialist, source-byte preservation, exact inspector digest, redaction, and a poison specialist/scorer that would create a marker if executed. It never executes.

One read-only inspection of the actual private Slim `meteorology-v2` folder answered: publisher-retained ADMIT; upstream state `changed`; binding reason `missing_files_sha`; 52 declared dev rows and 58 held-out rows. Those are inventory counts, not newly scored panel results. The missing binding explicitly does not establish that source files changed. The retained verdict's 58 correct / 0 wrong / 0 false-yes specialist figures remain publisher claims.

Service integration is owned by the service lane. Its three focused tests compose the actual provider through registry, discovery, invocation, and persistent replay, including refusal/unavailable behavior. See `U4-service.md` for its authoritative result. Packaging is owned by the provision lane.

No specialist panel was run in this lane; there are **no newly measured panel scores**. No Isabelle theorem was added or changed. No full Engine or frozen candidate was modified. Running exams and installing specialists still need an execution path that records measurements and applies Workbench's admission checks; this inspection supplies evidence for that unfinished workflow.
