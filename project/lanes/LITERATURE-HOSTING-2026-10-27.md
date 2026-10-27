# Hosting literature, 27 October 2026

Sol runtime literature lane. **No specialist-panel numbers:** this is hosting
research and a small analytical model, not an answer-quality or deployment
qualification. Root owns integration. No active worker, Mini lifecycle, runtime,
shared dataset or pool implementation was changed.

The most useful next step is to measure where startup time and private memory
come from, then remove repeatable tenant-neutral initialization. Durable
conversation restoration is a separate piece of work. A faster worker start
alone does not preserve a conversation, and a request-result journal is not an
Engine state checkpoint.

## Retained evidence

Seven primary papers and extracted text are saved in
`/Users/ember/paperbin/oracle7-20261027/hosting/papers/`. The adjacent
`manifest.json` records title, authors, year, publication, download URL, SHA-256,
source discovery and body sections read. Every paper has a full saved PDF;
these notes use the relevant body sections, not just abstracts. No paper is
labelled fully read cover to cover.

Both requested search sources were used. `search/kagi-*.json` contains four
bounded Kagi Search API responses with query, UTC time and response metadata.
`search/scry-*.json` and `search/*.sql` retain Scry schema/context plus three
bounded literature queries with coverage, completeness and billing metadata.
Discovery used [Scry](https://scry.io/) and Kagi; interpretation below comes from
the primary papers. The first broad title search was polluted by biological
SEUSS/REAP names and hit its 30-row limit. `selected.sql` corrected that search
by paper identity. Missing Scry rows do not establish that a paper is absent.
The Spice Scry match is a 2025 preprint; the retained PDF is the 2026 final paper.
No credentials or environment dump is retained or committed.

The installed v5 baseline supplied by `shared_data_review` is
`dregg-build:/build/lanes/oracle-tenancy-measure/baseline-v5/receipt.json`, SHA-256
`c846ce95dbf35d20031c7fa230ae6ec549d51984c2b31effa14cad03dc89f1b2`:
12.424 s startup, 0.351 s query, warmed process-tree PSS 476743 KiB
(**465.6 MiB**), private 464772 KiB (**453.9 MiB**), RSS 496608 KiB and
cgroup peak 701353984 bytes. About 239 MB of file memory was charged to the
cgroup. These are this older installed build's measurements, not the newer
hosted candidate's. Only ready/after-query samples exist, so the startup cost
cannot yet be attributed to import, loading, history or operation registration.
A harness cleanup bug left its adapter alive after bwrap exited; the measuring
lane subsequently stopped that exact owned PID. The receipt alone does not
prove clean exit. The earlier shorthand “454 MiB PSS” confused private with PSS.

## What the papers contribute

| Paper | Body read and useful result | Oracle consequence and limit |
| --- | --- | --- |
| [SOCK, Oakes et al., ATC 2018](https://www.usenix.org/system/files/conference/atc18/atc18-oakes.pdf) | Sections 4.1–4.3 distinguish an immutable installed-package cache, pre-imported interpreter templates and idle handler processes. A Zygote tree shares pages through copy-on-write; cache eviction accounts for sharing. | Share immutable files and measure duplicated import work. A tenant's warmed Engine cannot be the template for another tenant; it already owns mutable state and a SQLite-owning executor. |
| [SEUSS, Cadden et al., EuroSys 2020](https://www.cs.bu.edu/~jappavoo/Resources/Papers/seuss.pdf) | Sections 3–5 separate base-runtime snapshots from function snapshots, use copy-on-write snapshot stacks and warm common pathways before capture. Snapshot capture precedes invocation arguments. | Factor common initialization from tenant initialization. Its custom unikernel/OS boundary is substantial engineering; its fast snapshots are not a Python multiprocessing option. |
| [REAP, Ustiugov et al., ASPLOS 2021](https://ustiugov.github.io/assets/files/REAP_ASPLOS21.pdf) | Sections 5–7 record a stable page working set and prefetch it in bulk. Section 7 discusses changing inputs, overfetch, RNG duplication and layout reuse. Correctness must tolerate missing prefetched pages. | If file faults dominate, selectively prime the measured immutable working set. Avoid warming all 15 GB. Direct I/O in REAP serves its guest-memory copy path; it is not advice to bypass Oracle's normal shared file cache. |
| [Spice, Holmes et al., OSDI 2026](https://www.usenix.org/system/files/osdi26-holmes.pdf) | Sections 2–5 separate memory restoration from restoring threads, descriptors and other kernel objects. SHELF/spliceVMA decouple sparse disk layout from VMAs; its prototype stops function threads at a safe point. | Measure restore plus first useful answer. A memory dump alone does not restore Oracle's executor, SQLite connections, pipes, working directory or tenant filesystem consistently. Spice needs OS/runtime support absent from this appliance. |
| [Serverless in the Wild, Shahrad et al., ATC 2020](https://www.usenix.org/system/files/atc20-shahrad.pdf) | Section 4.2 uses bounded per-application idle-time histograms, head/tail percentiles and a conservative fallback while patterns are uncertain. Evaluation separates cold starts from idle memory. | Record real tenant arrivals before adapting retention. With one slot, an idle timeout cannot prevent eviction when another tenant needs the slot. Prewarming must occupy a counted slot and never displace busy work. |
| [Dominant Resource Fairness, Ghodsi et al., NSDI 2011](https://www.usenix.org/events/nsdi11/tech/full_papers/Ghodsi.pdf) | Sections 3–4 define fairness over each user's dominant CPU/memory share; scheduling chooses a ready user with the least share subject to resource availability. | Resident-count safety and fair admission are different properties. At one homogeneous slot, DRF adds little; retries still need an admission order. It does not prove a waiting-time bound for long, nonpreemptive Engine work. |
| [Boki, Jia and Witchel, SOSP 2021](https://www.cs.utexas.edu/~witchel/pubs/jia21sosp-boki.pdf) | Sections 3 and 5 distinguish durable log entries from disposable cached object views. State reconstruction starts from a versioned view plus subsequent ordered updates; workflows explicitly handle idempotency. | Oracle needs an explicit state model before restoration. Replaying old `chat` or `invoke` calls may repeat side effects and does not inherit Boki's consistency guarantees. A result journal must remain authoritative for exact retries. |

## Five concrete engineering decisions

1. **Measure startup phases before selecting a snapshot mechanism.** In
   `tools/appliance/serve.py`, future telemetry should separate parent spawn,
   `_worker` preflight, `import_launcher` module execution, `Engine()` and the
   owner-thread `Operations` construction. Split `Engine()` further only after
   that phase is known to dominate. Record monotonic durations, PSS/private
   pages, minor/major faults, bytes read and cgroup file/anonymous charges at
   each boundary; collect the first answer too. Keep tenant text and identifiers
   out of these metrics. Use the same immutable deployment and a newly started
   worker under an already warm host cache; do not drop global caches. Consumer:
   `appliance_service` plus `shared_data_review`. Sources: SOCK, REAP and Spice.
   Acceptance: a sum of phase timings explains ready latency within measured
   overhead, and opt-in telemetry changes no reply bytes in the existing
   `tests/appliance/test_service.py` and tenant tests. One leased Linux Engine
   run supplies the measurement; this lane did not start it.

2. **Share file-backed data first; keep semantic heaps private.** The existing
   runtime/data mounts are the right first layer. Linux already caches read file
   pages; decoded Python objects and SQLite private page caches can still be
   duplicated. Inspect large immutable structures after phase sampling and
   replace demonstrably duplicated static tables with versioned read-only
   file-backed representations only where useful. Pin any working-set hint to
   the deployment/data digest, cap its bytes, and fall back to ordinary reads.
   `immutable=1` belongs only on genuinely immutable published databases, never
   on tenant journals. Sources: SOCK, REAP and
   [Linux page-cache documentation](https://docs.kernel.org/admin-guide/mm/concepts.html#page-cache);
   [SQLite's immutable contract](https://www.sqlite.org/uri.html#uriimmutable).
   Consumer: appliance loader/immutable data review. Acceptance: identical
   specialist-panel replies for any changed reader, plus measured two-worker
   private/PSS/cgroup deltas and A/B tenant state probes. Summing RSS alone is
   insufficient. This is a representation change, not permission to share a
   mutable Engine, and does not establish that two workers fit class L.

3. **Keep `spawn` now; evaluate a tenant-neutral template only if profiling
   justifies it.** `EngineProcess.__init__` explicitly uses spawn; `_worker`
   constructs the Engine and its owner-thread Operations afterward. A future
   Linux template must contain no tenant configuration, mutable semantic state,
   live Engine executor or SQLite connection. Prove the preloaded modules leave
   it single-threaded, then reopen connections and set paths in each child.
   A template process itself counts against memory. Sources: SOCK/SEUSS and
   [Python's multiprocessing contract](https://docs.python.org/3/library/multiprocessing.html#contexts-and-start-methods),
   which warns about forking multithreaded processes. Replacing `spawn` with
   `fork` after `Engine()` is not this design. Consumer: appliance startup work.
   Acceptance: separate tenant-global/session state probes, descriptor audit,
   repeated start/close under timeout, child-only termination, source/data hash
   identity and lower measured latency/private memory. A CRIU/VM snapshot needs
   equivalent path, descriptor, randomness and deployment-version checks;
   Spice's patched-kernel architecture is not an immediate dependency choice.

4. **Make restoration explicit before relaxing `conversation_reset_required`.**
   Inventory all state relevant to a tenant's next answer, including globals
   shared between its conversations and persisted workspace writes. Define a
   versioned checkpoint with deployment/data identity and a request sequence,
   exported/imported on the Engine's owner thread at a safe cut. Parent-side
   result plus checkpoint publication must be atomic; the cut must also agree
   with any Engine-owned durable stores. A worker crash between side effects
   and that commit stays uncertain/poisoned; an older checkpoint cannot justify
   replaying an operation. Checkpointing is not Python object pickling. Keep
   exact durable retries on `_retained` without allocating an Engine. Source:
   Boki's log/view distinction, with SEUSS/Spice's capture boundaries. Consumer:
   future Oracle state API and pool generation registry. Acceptance: equivalent
   next-turn behavior before/after eviction, including pronouns, variables,
   tenant-global changes and operation effects; crash at each publication
   boundary; stale schema/deployment refusal; no cross-tenant state. Until those
   pass, preserve today's explicit reset contract. This is the main functional
   upgrade for long-lived conversations; changing idle timeout cannot supply it.

5. **Measure contention, then add bounded admission fairness if it is needed.**
   Current `tenant_busy`/`pool_busy` 429s and zero query queue keep memory
   bounded but let request arrival races decide who runs. Record refusal counts,
   admitted worker seconds and oldest unsatisfied demand per authenticated
   tenant. If polling starvation appears, introduce one expiring admission
   ticket per trusted tenant, a global fixed ticket cap, a deadline and fair
   round-robin order; it reserves no extra Engine and executes no hidden job.
   A ticket is a new explicit protocol and needs root/bridge/UI integration,
   rather than slipping a queue into this pool. Close failures keep their
   poisoned slot. Source: DRF's distinction between resource feasibility and
   allocation policy; Wild's workload measurement. Consumer: host admission and
   bridge. Acceptance: a hot retrying tenant cannot indefinitely beat an already
   eligible ticket; expired/disconnected clients cannot block progress; retries
   use exact bytes; deadlines, tenant cap, worker cap and fail-closed shutdown
   remain enforced. Homogeneous slots need simple ordering, not a full DRF
   implementation. This research does not claim current admission is fair.

## Small experiment: capacity causes churn even with a long idle timeout

`python3 tools/usage/hosting-literature/churn.py` is an **untrusted analytical
model**, not a load test. It opens no Engine, process, socket or tenant store.
It models sequential new conversations, least-recently-used eviction, immediate
completed-journal retries and a resident cap. TTL, concurrency, failures and
shutdown cost are excluded to isolate capacity pressure. Timings use the older
v5 measurement above as inputs, not as a hosted-build prediction.

| Synthetic trace: 32 tenants, four calls each | Cap | Cold / warm | Peak workers | Estimated sequential Engine time |
| --- | --- | --- | --- | --- |
| Alternate all tenants each round, new conversation per call | 1 | 128 / 0 | 1 | 1635.200 s |
| Same alternating trace | 2 | 128 / 0 | 2 | 1635.200 s |
| Group four calls by tenant, new conversation per call | 1 | 32 / 96 | 1 | 442.496 s |
| Same grouped trace | 2 | 32 / 96 | 2 | 442.496 s |
| Exact completed retries already retained in journals | 1 or 2 | 0 / 0, 128 replays | 0 | 0 Engine time |

All model assertions passed. Its `returns_to_evicted_tenant=96` on the
alternating trace is a churn indicator, **not** a count of real 409s: the model
uses new conversation IDs so those calls can execute. In the actual current
pool an old conversation instead receives `conversation_reset_required` before
starting a worker. The model's zero retry Engine time excludes SQLite/HTTP time.
The result shows why larger idle retention alone cannot fix dozens-of-tenant
alternation. Grouping calls illustrates locality; it is not a recommendation to
hold other users behind a long batch.

`/Users/ember/paperbin/oracle7-20261027/hosting/churn-model.json` retains the exact
output. No production performance gain is claimed from this experiment.

## Handoff

Changed files: this report and `tools/usage/hosting-literature/churn.py`.
Theorem statements: none; no formal assurance changed. Check run: the command
above exited 0 and reported `model_checks: passed`, with the counts shown here.
The narrow model check addresses capacity-driven churn only. No Isabelle build,
answer panel, live worker qualification, Mini operation or deployment was run.

Remaining: phase telemetry/measurement, then an evidence-based choice of loader
or snapshot work; a complete tenant state inventory and checkpoint protocol;
contention measurements before changing admission. These are concrete follow-on
engineering tasks, not completion claims. Existing scoped appliance tests and
the separate real Linux/Mini acceptance remain the consumers of those changes.
