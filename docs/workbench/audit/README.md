# Workbench source and fixture audit

2026-10-15 · authoring61 · D12/D20–D28 · C01/C03/C05 · ACC-02/11/14/15.

This audit inspects the shipped implementation, then executes selected original
functions against disposable local fixtures. It establishes migration requirements
and reusable interaction patterns, not a native implementation, admission theorem,
independent author trial, or completed sibling migration. Architecture revision 2
and D27 govern the replacement: canonical `.thy` recipes, preserved expert blocks,
one package/release/deployment/workspace lineage and common UI/CLI operations.

Run `python3 audit/workbench/check.py --write` from the repository. Eleven checks
pass on this checkout. `audit/workbench/results.json` records observations and
source hashes. Temporary workspaces are removed; upstream code is not edited.
The runner imports upstream modules with their local paths redirected before
import, starts no server/poller, and uses no engine/tool/SSH network connection.
It executes only a literal harmless Python function/test subprocess. Its mocks
measure the selected call boundary, not external service behavior. Source hashes
bind inspection material but confer no semantic authority.

## Concrete traces and dispositions

| Workflow | Actual entry and implementation | Evidence | Disposition for native workspace |
|---|---|---|---|
| Gap → draft | `server.H.do_POST /api/chat`, `/api/journal`, `gaps`, `scaffold`; `app.js` Gaps → Build | WB01; journal is opt-in; scaffold copies templates and inserts questions with `a:""`, `valid:true` | Preserve original question/reason/origin and opt-in control; repair unknown expectation representation. A blank answer is not ground truth. |
| Edit → develop → qualify → activate | `/api/save`, `/api/exam`; `exam.run/start/status`; `Workbench.reload`; Build view verdict/progress | Source: development verdict cannot activate; heldout log written before loading/execution; admitted-and-unchanged status loads automatically | Preserve dev repetition and failure diagnosis; distinguish admission, operational qualification and activation. Explicit versioned deployment replaces automatic loader coupling. |
| Guarded composition | `Workbench.chat`, `exam.fillable`; addressed source readers precede core, ordinary fallback follows selected reading declines | WB02 exercises P versus G guard | Preserve addressed-local lane and guard scope; negative-space/interference tests must match both actual routes, not only core-first exam composition. |
| Local computer / SSH | `/api/scan`, `/api/computer`, `/api/server`, `/api/server/add`; `sources.scan_local/scan_server`, `MachineOrgan`, `machine_probes` | WB11 executes SSH parsing with subprocess replaced; fixed script, BatchMode, timeout and accept-new host key setting inspected | Preserve read provenance and setup preview; represent scan/discovery as acquisition with target authority. Host identity acceptance is a visible policy; do not copy silent trust-on-first-use. Live machine scan not executed. |
| File intake | `/api/files/add` copies CSV/TSV/TXT/MD; `file_probes`, `FilesOrgan.load/answer` | WB10 returns cell plus file/row/column | Reuse table/text preview and located answers; repair corpus identity/caching and ambiguity semantics. File suffix support is concrete; arbitrary document ingestion is not shipped here. |
| MCP setup / qualification | `/api/mcp/connect` starts stdio or HTTP client; `/api/mcp/save` builds source and immediately starts probes; `McpOrgan.schema/takes/answer` | WB05 calls one mock `reply` during readback; lane/self uses mock `takes`. Real `answer` invokes `tools/call`; schema lookup may discover remotely | Preserve selectable tools and precise call receipt; discovery, probe and requalification require separate authority. A source label is not a read-only guarantee. Schema/argument mapping and changed-schema qualification need repairs. |
| Feedback | `/api/feedback` parses tool from response; `mcp.learn`, then asynchronous `exam.start_source`; `route` rereads credit | WB03 credit/probes changes leave `files_sha` unchanged; source shows suppression after three wrong marks exceeding right | Preserve useful learning proposal; append attributable result-linked feedback, evaluate candidate policy, publish a new policy revision atomically. Existing live mutation before requalification is a defect. Non-MCP marks only say noted. |
| Sensor setup / repeated acquisition | `/api/sensor/test/add/remove`; add saves config, polls, starts worker, then qualifies; `poll_once/history/SensorOrgan` | WB08 same source payload receives two poll timestamps | Preserve adapters and plotted history; event/receipt time, deduplication, unit/config origin and invalid last-valid behavior need explicit semantics. Physical pruning is conditional on 4 MB; default 24h query window is not erasure. Removal must prevent late worker resurrection. No hardware/network/worker exercised. |
| Persist / recall / restore / expire | `/api/conv/*`, `conv_add`, `ConversationOrgan`; `Workbench.chat/last/warm` | WB06 reconnect executes old question; WB07 cached pronoun path answers expired specialist before live filter | Preserve historical quotation and default seven-day temporary recall; restore accepted state without execution. Current authority applies to cached followups. Forgetting must account for core memory, last-subject cache, journal and derived draft examples; unlinking transcript alone is insufficient. |
| Share / import / exposure | `package`, `import_zip`, `exam.run` | WB04 packages exam log but import rejects its `.jsonl` extension | Repair intake before claiming sender exposure is imported. Preserve attributed exposure and sender verdict separately; recipient rerun may be regression, not fresh holdout. Inspect original manifest/organ/scorer/panel/card, without executing untrusted Python on import. |
| Authored code experimentation | Code view asks `/api/chat` for Python, extracts code, seeds editable assert, `/api/code/run` invokes `run_code` | WB09 actual harmless authored test passes; `-I`, temporary cwd, timeout, trailing output | Preserve scratch code + explicit tests + observations as artifacts; optional versioned trusted-code worker is distinct from native capability execution. This process has no filesystem/network sandbox. Native expert editor alone would omit this workflow. |
| Local Film / route explanation | `app.js renderFilmList/record`, `o7-explorer.js`; selected turns → canvas trace → MediaRecorder WebM | Source inspected; browser playback/codec/export not executed | Reuse selection, framing, generated-image label, hidden-tab pause. Repair marker stripping, capped narration and display so conditions/historical status/evidence survive in full companion explanation. Self-contained HTML is new required design, not an upstream export demonstrated here. |
| Optional media | `/api/el/connect/speech/sound/image`; Film calls adapters before recording | Source inspected, no service contacted; remembered key in local settings; image download can send key on retry | Retain adapter requirement pending root D16 scope; explicit export payload/credential reference. Local Film does not imply remote narration/illustration. |
| Integrity / public registry | `verify.verify_install/check_anchor`, `registry.fingerprint/check/relay`, Share wallet registration/attestation | Source inspected; UI signs/simulates/sends transaction; local fingerprint versus remote observation distinguished | Preserve local integrity verification. Public commitments and token/chain policy remain D16 root decision, not native proof or a silently deleted workflow. No signing/upload/contact performed. |

## Reusable components and deliberate replacements

The template directory provides a useful Oracle7 intake example (organ, manifest,
panel, scorer and README); the paint-coverage example is a concrete starter to
map, not a native implementation to rename. Gap grouping, located table preview,
qualification progress/failure cards, selected-turn Film and route animation are
reusable interaction patterns. They consume new typed outcomes and artifacts;
legacy path strings/response regexes are not the new semantic interface.

`static/app.js` is a DOM application with shared mutable session/turn state; lifting
it wholesale would retain stale identity and source ambiguity. `o7-explorer.js`
contains separable rendering ideas, but its concrete labels/trace vocabulary must
be mapped. Bundled fonts/Three.js/Solana vendor bytes require license/dependency
closure review; presence in the repository is not redistribution clearance.

`cli.Session` already calls `Workbench.chat`, demonstrating valuable common user
operations. CLI command branches call source and exam functions directly; the new
CLI should consume the same authenticated runtime protocol as the browser rather
than becoming another authority path. CLI documentation lists `registry-record`
and `main` handles it, but `COMMANDS` omits it; inspect the launcher dispatch before
claiming end-to-end CLI reachability. Shared operation coverage is not complete
because a function exists.

## Interface requirements for workspace-interaction

The next task can proceed with source-backed flows. It needs revision-checked
source patch operations (canonical recipe ranges + preserved expert text), draft
examples with explicit unknown/proposed/declared expectations and provenance,
qualification jobs with baseline/candidate/panel/scorer identities and exposure,
and separate release/deploy/rollback operations. Operations must return structured
blockers, request/result identity, current lifecycle authority, observation scope,
effect preview/dispatch state, and navigable diagnostics/source locations.

Source setup must expose configure/discover/preview/probe/start/stop/requalify/retire/
forget separately. Read-only fixture preview is available without pretending real
probes are harmless. Feedback proposes a versioned policy. Export first previews
private closure and omitted bindings; Oracle7-original intake stages source and
exposure before migration. Recall, restore-state and execute-again are different
commands. Film/code/optional remote adapters belong in visible flows, not only an
expert theory tab. No new competing package schema is introduced by this audit.

Remaining evidence belongs to implementation consumers: actual native admission and
qualification composition, controlled source protocols, browser Film rendering and
codec export, dependency/license closure, clean recipient import/rebuild, and a
real author walkthrough. Remote media/chain first-handoff inclusion needs root's
material scope decision. Six siblings remain compatibility investigations under
D18; this audit neither migrates them nor narrows their denominator.

## Transfer correction and pinned locators

The earlier `docs/review/workbench-gaps.md` transfer paragraph is a source-review
inference about what would happen after importing an exposure ledger. WB04 reaches
a prior blocker: `server.py:561` packages the ledger, while `server.py:582`
`import_zip` checks members at `:594–597` against `FNAME` (`:59`), which omits JSONL.
It raises before extraction, verdict renaming or recipient exam invocation. Thus
ordinary examined packages with the log are rejected first. Retained sender exposure
is still the correct replacement requirement, but is not observed import behavior.
`audit/workbench/transfer-regression.json` separately specifies desired native intake
assertions and explicitly marks the missing native consumer; reproducing the old
bug cannot close that regression. `source-locations.json` gives definition line
ranges; `results.json.source_sha256` pins the actual shipped bytes for every locator.
