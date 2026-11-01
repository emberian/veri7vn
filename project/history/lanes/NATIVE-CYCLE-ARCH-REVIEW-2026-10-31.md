# Native cycle architecture review — 31 October 2026

Review baseline `d2bd96d`; active source review of typed host replies, encoded transport, and evidence recovery. No builds/tests or implementation edits by this reviewer. No panel numbers or theorem claims.

The agreed typed boundary is a private admitted request retained through execution and independent typed checks, followed by an opaque serialize-only checked reply. External reply parsing cannot manufacture that token. Original HTTP request bytes, canonical provider envelope size and identity encoding remain distinct limits. The wire boundary owns a complete bounded encoded buffer and writes nothing to HTTP until encoding succeeds; legacy Value callers adapt at the boundary. Persisted query reply bytes are strictly validated before being reused. Query completion/poison decisions must describe the same final body; an oversized-response replacement must not retain the original body's completed flag.

Evidence checkpoint is a checked current-version receipt, not historical snapshot storage, compaction or an import token. It reads existing native owner state under the tenant/session/runtime binding and preserves the snapshot guard through projection. An empty-native-owner bootstrap at session zero must not create a durable session or fabricate Python coverage. The tenant argument comes from the hosting trust boundary; a header or receipt is not itself authentication. Client recovery must durably record the entire pending request before sending, retry it exactly before comparing a checkpoint, validate its acknowledgement, then atomically advance the local cursor. The local file is retry bookkeeping, not an authoritative replica; concurrent advancement must fail rather than silently rebase.

## Early findings

- NativeRuntime's admitted-operation vector was publicly mutable even though invocation used it as the entitlement check for direct image/snapshot routes. A Rust caller could append a globally known route. Requested a private immutable view and a real restricted-release regression; ordinary HTTP registry admission was already protected.
- New bounded wire writing called `try_reserve_exact` on every serialized chunk, permitting allocation/copy work per token rather than amortized growth. Requested capped geometric growth and a structural allocation-growth assertion while retaining the byte ceiling.

Both early findings are repaired in source: `NativeRuntime::operations()` exposes only an immutable slice, and `BoundedWriter::write` grows geometrically within the byte ceiling. The restricted-release checkpoint test exercises real entitlement admission rather than changing an internal vector.

## Frozen wire and checkpoint source pass

`Service::finish_query` now computes completion from the encoded original Value and explicitly retains poison when it substitutes an oversized-response refusal. `encode_response` changes a retained `http_status` to 502 with its replacement, avoiding an immediate 502 becoming 504 on replay. `Journal::begin_encoded` strictly parses retained bytes before deriving status and returning the original buffer; `finish_bytes` remains internal. `http::respond` writes only the completed buffer. No remaining blocker found in this frozen wire source. The authored `encoded_reply_tests` cover oversized completion across restart, oversized uncertainty with identical replay status/bytes, and canonical successful bytes with exact large numbers. `http_encoded_tests` covers a single encoding followed by socket transmission and refusal without a partial original response. These tests were read, not executed.

Checkpoint host projection retains the validated owner snapshot and clone/output reservation through bounded encoding. Both owner session version and evidence revision/optional identity are checked; absent-owner bootstrap produces a receipt without a durable write. `Workspace::import_with_control` replays checked revisions with inherited cancellation/work hooks. The existing runtime validation also replays history; no elimination of that duplicate work is claimed.

The client recovery size blocker is repaired: `atomic_cursor` now checks the exact UTF-8 serialization against the same 1 MiB read cap before replacing the file. `revise` removes an unsaved pending request from its live object on save failure, preventing a caller that catches the error from later sending undurable intent. The new combined 600k acknowledgement/600k pending regression checks no mutation, unchanged prior file and successful reopening. Recovery ordering, scope/deployment binding, exclusive cursor lock and atomic replacement were inspected; no remaining checkpoint source blocker found. The combined cursor bound is a client limit, not a server evidence limit.

## Fuel blocks and typed boundary

The bounded-fuel source preserves genuine work ancestry: `WorkControl::check` has a compatible `checkpoint(0)` default, while ExecutionContext performs its cancellation/deadline/sticky-limit check without charging. Known graph loop extents are prepaid and each iteration still checks cancellation. Failed/cancelled blocks conservatively retain their prepaid charge. Sorting remains an admitted finite but uninterruptible operation bracketed by checks; this is not a comparison-count or hard-interrupt claim. No remaining source blocker found in that seam; authored fuel/graph tests were inspected, not run.

Final typed custody/feature-gating source pass is complete with no remaining architecture blocker. The private checked reply owns provider payloads through transport serialization and cannot be deserialized or detached. The allocation-free `finite::check` recursively rejects nested nonfinite f32/f64 values at its sole constructor, addressing the NaN-to-null gap that Rust structure alone does not prevent. Every admitted command dispatches to its typed checker; production `legacy_check` is gone, and legacy result Value/decode paths remain test-only. `Pure::invoke` materializes the final checked reply for compatibility. Optional provider modules and enum arms are gated, and private unavailable sentinels keep the feature-empty enums valid without creating an unchecked reply path.

The reasoning descriptor walk retains exact scalar integer checks and bounded descriptor-driven object bookkeeping; provider payloads are not reconstructed as a Value tree. Final per-provider numerical/variant compatibility is covered by the independent provider review. The authored nested-NaN mutations, changed status/source/operation, const-array order and u128-bound regressions, prior-contract differential examples, and LP/GLM decode/materialization probe are decisive checks for this seam; no execution results are claimed here. This removes a full payload conversion, not every validation traversal: finiteness and descriptor checks still traverse serialized events. Central validation remains independent.

## Frozen source identities

SHA-256 at final architecture pass (paths under `native/oracle-host/src/` unless stated):

```text
0c578d02ba8c5a3d3ee7dfd08f66d61dde780354f675b5c2fd05fd294846b371  pure.rs
d37c442098b05070f16b8f7925b6348b1c3660e946ac7e38d279b10510d42513  pure/typed.rs
2789a126b0038cccf4162f8aaf6a5d1aac8abb185a101a2491f1483db25c678b  pure/typed/bio.rs
ba8fce4ebc1bf939d7649139adff6bb80b71b2e861b21363f436a92dc07e2f7f  pure/typed/contract.rs
8415bdc182dfea2c436a3623c7aa412ab93d9ccf7d9e6d9e099a7322f1e289dd  pure/typed/finite.rs
d249ba58f33ee8b5db653104f028c73e84eafa7ac98831ffd60b670243dc7e66  pure/typed/logic.rs
c56f7c49a40e5075bf73d07bf42397c841bb87facb9cd010ecb6b3e6240d31d6  pure/typed/reasoning.rs
71b3f0cc6833908c867216e4ddd110317ebd1bd330ea7210c014b096e61d60b5  pure/typed/science.rs
1454ffbc8356a4b629e16ed988b192d70be1a9ac017fa826e9e8a07c354de507  pure/typed/statistics.rs
845afc8c444ab2c59fb38d80ebccede86952188bbee10381b86c7a1cbd571895  wire.rs
3229300f23d8dcc836601d1fe76c6b6eeec92f06c71ca3d5b10f80be380faaf9  service.rs
c39d37aa0e45238cef899593363d734b4d0dc251ecfa12a1fd570993859d9e66  journal.rs
1f56f67c332e5c5887f6018229a144117b0f850f32e00f8e581a624e5c756051  http.rs
385fbdec689765ba966197a8679e9b316fc568623116ed24da448d29b838717e  native.rs
f65b16b1106cf8a46f5f8adb7c2c29ced5b97f2ce8427e5951978db8c26dd575  revisions_owner.rs
520ee2cfbc33fa5e1adfb135db1d64a3859c6afc7b64ff6ade2f84b6bd54ae2b  tools/usage/revisable_evidence.py (repository-relative)
4e88f106c2bb3ec541f6f66ab92d558120e8fed6361f36fcaf669e008c3db939  native/oracle-execution/src/lib.rs (repository-relative)
```
