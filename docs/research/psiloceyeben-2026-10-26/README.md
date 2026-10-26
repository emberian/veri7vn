# Oracle7 and the Psiloceyeben projects: a Dregg packaging study

Observed 26 October 2026. This is an investigation and architecture proposal,
not a deployment or a new whole-system qualification.

**Recommendation:** offer Oracle7 as an evidence-bearing tool to hosted agents.
Package the current slim runtime, an explicitly versioned veri7vn backend, and
knowledge stores as one logical appliance with independently identifiable parts.
Keep specialist construction in a separate writable workspace. Mini continues
to decide who may call, spend, publish and install; Oracle7 computes and proposes.

An operator-installed large appliance is a valid option. Mini's present size
limits are implementation choices we can revise, including different operator
and user limits. The reason to separate code, stores and mutable state is their
very different update and sharing patterns, not a prohibition on large packages.

## What was fetched and checked

- All **15 public GitHub repositories**, **8 Hugging Face model repositories**,
  and the **one specialist dataset** listed for `psiloceyeben`. No public HF
  Spaces were listed. Git history and source checkouts are local under
  `var/universe-20261026/{github,huggingface}/` (about 155 MiB at inspection).
- GitHub checkouts are sparse by source-file extension. HF checkouts omit large
  stores and media, and LFS payload downloads were disabled. These are research
  copies, not runnable full installations. HF partial-clone fetching failed for
  several repositories; refetching the Git objects without filtering succeeded.
- Fetched the veri7vn and Mini origins without merging or changing their active
  branches. Mini's existing untracked work was preserved. Original `upstream/`
  was not changed.
- Read Mini's current receiving/tool/package code at `307b13ea`, its handoff,
  and the adjacent nanodregg orientation at `c4800fb7`. No service on the public
  node was inspected or changed. Source support is not evidence of deployment.
- Ran the narrow component probes below. Did not rerun Oracle7's whole exam,
  download the new multi-gigabyte stores, build Isabelle/Lean, call external
  model providers, install services, or contact the author.

[Inventory](inventory.json) records all 24 repositories, exact commits, file
counts and store manifests. [Probe results](component-probes.json) and
[their runner](probe_components.py) are retained with this report.

## The release channels have diverged

| Source | Pinned revision | What it contains |
| --- | --- | --- |
| [GitHub oracle7](https://github.com/psiloceyeben/oracle7/tree/87b015e) | `87b015e` | Code/research for 4.0, runtime w558. Does not contain the full store distribution. |
| [HF oracle7](https://huggingface.co/psiloceyeben/oracle7/tree/226a5d99af1d9538bbb75ffd9784e0607340f46e) | `226a5d99` | Full-data 4.0, published October 20; w558. |
| [HF oracle7-slim](https://huggingface.co/psiloceyeben/oracle7-slim/tree/083e3a6c0e2cfc131e62bdc16cb4ec1346194635) | `083e3a6c` | **4.9, published October 23**; w436, whose actual ancestry includes w571 and w558. The lower number is an epoch naming change, not an older runtime. |
| [Author's veri7vn integration branch](https://github.com/psiloceyeben/veri7vn/tree/oracle7-3.2) | `a35f428` | Build/static-link/parity scripts and the 3.2 integration record. Fork's default `dev` is still `fc3ab3a`. |

Use the pinned HF slim source for the latest release. Fetching GitHub alone
misses 4.1–4.9. The full release was held at 4.0 after later release bars failed;
combining the latest slim code with full stores would be a new configuration
requiring its own qualification.

The slim tree has **374 specialist directories and 339 files labelled ADMIT**.
Directory count, admitted specialist count and number of distinct capabilities
are different: multiple generations coexist. Compared with full 4.0 there are
64 additional directories, largely composed-specialist generations, four built
tables and `meteorology-v2`. This count does not revalidate each verdict's hashes.

The main changes since our earlier snapshot are:

- **3.2:** our kernels as a cross-check, new star-related specialists, routing
  corrections and read-back checks for prose transformations.
- **4.0:** route measurements, a residue ledger, restrictions on unsupported
  conversation state, route caching and another attempt at resolving pronouns.
- **4.1–4.9, shipped together in slim:** building Wikidata tables from question
  examples; synthesizing bounded programs from worked examples; using previous
  programs as reusable moves; joining programs by quantity dimensions and units;
  expanded relation readers; premise/whole-title checks; sensor examination;
  a coordinator that builds missing pieces during planning.

This is concrete code, but the broad self-building claim needs its bounds kept
visible. `workbench/swarm/composer_v3.py` searches a finite arithmetic/categorical
vocabulary, permits up to two fitted constants, emits Python/JavaScript, and
checks examples. `point.py` composes available parts and builds from supplied
reserve examples. It is not an unrestricted autonomous software engineer.
The Wikidata builder makes network requests and writes local source captures;
ordinary offline question answering and specialist building are different modes.

The newest tests are not a universal accuracy guarantee. The publisher reports
strong results on the four 4.9 construction targets, while the preceding PI48d
web panel reports only 53.9% precision for slim. Its mechanical scorer has known
wording limitations, but the documented failures still rule out treating every
answer as authoritative. See the pinned slim `README.md` and `CHANGELOG.md`.

## What happened to veri7vn

The integration is real. Both HF releases contain
`root/specialists/_proved/PROVED.json`: **19 native families, 128 specialists**.
They are static Linux x86-64 executables. The manifest points to `3bf43cf`,
whose source baseline is the earlier `fc3ab3a`; the fork adds build/measurement
scripts and restores family regex files during builds. The published parity
record covers 7,172 held-out questions and is the author's measurement, not a
rerun in this investigation.

That snapshot predates our final corrections. Relative to our 144-specialist
registry, the map lacks the 16 IDs in **earth (8), finance (5), variants (3)**.
It also does not integrate our relation kernel or the separate code, math,
document, dialogue, word-problem and guard stages. Updating the cross-check
would not by itself integrate those routes. Our own last complete 144-folder
archive is still the older `b0813cc` delivery; subsequent corrections have
separately qualified family packages. A new combined artifact needs assembly
and composition checks, rather than being inferred from the newer source head.

**The “proved” label is too broad for the implemented comparison.** The same
w551 code remains in 4.9. It checks a yes/no prefix and the first standalone
number, with a rounding tolerance. A kernel refusal, error, timeout or unsupported
architecture leaves the original answer unchanged. Multi-specialist network
answers are excluded. The original answer is retained when the comparator says
it agrees; the kernel's full semantic result does not replace it.

The retained probe executes the real comparator and chat method with an explicit
stub parent and kernel. It accepts all of these pairs as agreement:

| Original | Kernel |
| --- | --- |
| `10 kg` | `10 m` |
| `Paris` | `London` |
| `10; second result 5` | `10; second result 900` |
| `0` | `1` |

The stubbed chat method consequently marks `10 kg` proved when its kernel says
`10 m`. These are comparator counterexamples, **not claims that those exact
answers were observed at the live service**. They establish that the label is
not a proof of complete answer agreement. Source: the pinned slim
`self_loop/admitted/oracle_release_runtime_w551.py`, especially `agrees` and
`OracleReleaseRuntimeW551.chat`.

For Dregg, keep the upstream answer, kernel answer and comparison outcome
separate. Use explicit evidence categories such as source-record answer,
heuristic cross-check and kernel-backed calculation, with theorem premises and
recognition assumptions. A proof about supplied arithmetic or rows does not
prove the English interpretation or source truth. Do not export upstream's
`proved` flag as a blanket Mini trust decision.

## The wider universe

The six HF companions last changed October 15; they are distinct applications,
not newly installed abilities of the core just because their cards link to it.

| Project | Actual surface and integration judgment |
| --- | --- |
| [Trafficcop](https://huggingface.co/psiloceyeben/oracle7-trafficcop) | Small stdlib decision function taking state and options, returning a choice, abstention and receipt. Vendored into Chameleon's repair/capture workflow. Good first optional tool; its choices remain proposals, not Mini permission. Reproduced 16/16 dev, 30/32 held-out routing decisions, 2/2 structured cases; all five tested mutants scored below the real implementation. |
| [DeepSpace](https://huggingface.co/psiloceyeben/oracle7-deepspace) | Stdlib telemetry/fault-response simulator, lookahead and rule gate. Despite its stale README saying unpublished, source is present and three 320-tick simulation smoke cases execute successfully. A useful simulation laboratory; not qualified here for real spacecraft control. |
| [Infrastructure](https://huggingface.co/psiloceyeben/oracle7-infrastructure) | Linux/systemd discovery, readings, forecasts and action proposals. Operator observability candidate. Its installer enables/restarts a privileged service, so do not treat the installer as an agent tool. Separate read access from any action execution, governed by current Mini authority. |
| [Chameleon](https://huggingface.co/psiloceyeben/oracle7-chameleon) | Website/repository reconstruction, browser contracts and repair operations, with Trafficcop included. Source is substantial, but no dependency manifest was found in the fetched release inventory. Published first-pass held-out completion is 1/4; broad release gate remains unmet. Package as a sandboxed job with explicit acquisition/build/browser dependencies. |
| [Vision](https://huggingface.co/psiloceyeben/oracle7-vision) | Fixed descriptors, exemplar lookup, glyph rendering/OCR, chart and screen helpers. Exemplar stores/fonts must be provisioned or rebuilt; the release is under 0.5 MB of source/results, not the reported 410–490 MB recognition store. Its published ChartQA/GUI results do not support using it as the default general visual agent. |
| [Artist](https://huggingface.co/psiloceyeben/oracle7-artist) | Composes cited COCO object cutouts with geometric/color checks. The sprite library required by `artist.core.Library` is not included. Needs separate asset construction and attribution; a constrained collage tool rather than a general image generator. |
| [Specialist dataset](https://huggingface.co/datasets/psiloceyeben/oracle7-specialists) | Currently README, attributes and an empty placeholder. No community specialist packages to ingest. The shipping specialists live inside the model repositories. |

The other GitHub projects provide useful context and some independent products:

| Repositories | Role |
| --- | --- |
| `wander-around`, `wander-substrate` | Tabular/SQLite data rendered as walkable worlds. Potential optional view of a shared corpus or research catalog. The first is a smaller general interface; the second includes corpus layout and rendering pipelines. |
| `wander-around-oracle` | World/game engine and an older Oracle account. Its README describes a different hybrid architecture and explicitly omits the model training method. Do not merge that claim with current Oracle7's no-neural runtime. |
| `HERMES-WebKit`, `-BRIDGE.PY` | LLM-backed websites and agent identity/memory/tool scaffolding. **Not Nous Research Hermes**, which Mini already hosts. Their provider/credential/process machinery should not replace Mini's existing authority boundary. |
| `spore-animation-studios` | Scripted sprite/ffmpeg animation. Plausible bounded rendering job; assets and character creation are separate from rendering. |
| `HOODBarons`, `GardenWithELiza` | Market-analysis UI and chain-derived multiplayer game. Concrete applications, not core knowledge dependencies. External data/services and deployment assumptions need separate packaging review. |
| `FOLD`, `alphafoldmicro`, `QUM.pi` | HRR/fixed-point experiments, defense/allocator demonstrations and sensor-stream tooling. Potential research modules, not established guarantees about arbitrary domains. |
| `Metacognition`, `AI-Sentience-` | Historical prompts/conceptual material; low priority for executable packaging. |

Every repo is pinned in the inventory. Some assert MIT in README prose without
a standalone license file; others lacked a clear top-level license in this
survey. Resolve per-package distribution terms before bundling the whole universe.
The shared author and name do not imply one license, runtime or dependency tree.

## Actual packaging constraints and interfaces

### Data and licensing

The current `PACK_MANIFEST.json` totals are more useful than the stale download
sizes in the READMEs:

| Variant | Packed stores | Unpacked stores | Entire HF repository's file sizes |
| --- | --- | --- | --- |
| Slim 4.9 | 5.035 GB | 15.005 GB | 5.163 GB |
| Full 4.0 | 12.124 GB | 33.095 GB | 12.249 GB |

Decimal GB; excludes the Python environment and writable state. Keeping both
packed and unpacked stores consumes both amounts. Compared with the old local
pack manifest, both expect the added/changed entity-name and v2 relation stores;
slim also has its distinct DBpedia stand-in store. Do not treat our old corpus
as interchangeable without matching per-file hashes.

Slim's published data terms exclude the full release's non-commercial OpenStax
material. Prefer slim as the first general hosted distribution, preserving each
source's attribution and terms. Full is a separate data profile, not simply
“slim plus more files.” See the pinned releases' `DATA_LICENSES.md`. Runtime code
is Apache-2.0; veri7vn code is CC0; those do not erase data/asset terms.

### Process and API

`oracle7.py` has a useful `Engine.chat(text, session_id)` interface. Its dedicated
single worker thread serializes calls because its stores are thread-bound.
Scaling requires bounded worker processes/queues, not simply adding HTTP threads.
The published roughly 2 GB RAM figure is not a new measurement here.

The stock loopback `/chat` server is an inadequate final adapter:

- It returns only `response`, `path`, `status`, `references`, dropping other
  runtime fields such as proof metadata.
- It defaults callers to the same `http` session and accepts a caller-selected
  `X-Oracle-Session`. That is a selector, not tenant authorization.
- It has no Mini identity, admission, resource-accounting or durable retry binding.

The Workbench's MCP module is an **MCP client** for calling other tools. It is
not an existing MCP server that exposes Oracle7 to our agents. An outbound tool
connector and an inbound Oracle service are opposite integration directions.

Mutable state needs explicit paths: `ORACLE7_STATE`, `ORACLE7_WORKBENCH_LOCAL`
and the builder's `SPECBUILD_HOME`. The latter does not automatically follow the
Workbench-local override. Audit other relative/default writes in a read-only-image
smoke run. The Workbench can import/edit/run code, connect external services and
apply updates; it belongs in the builder profile, not the query service's surface.

### Mini

There is already a suitable agent-facing route:
`native/grain-runtime/src/mcp.rs` exposes `mini_application_api` for configured
apps. `application_api_tools.rs` and `main.rs` bind calls to a named resident
session, ticket, subject, purse, generations and host pins. Each physical call
requires current native admission. An application result can then be published
through the existing resource mechanisms under separate authority.

This route is not arbitrary HTTP forwarding. An Oracle app needs the SPK
resident/Cap'n Proto API bridge and a bound application session. Also,
`X-Oracle-Session` is absent from the allowed ordinary headers; the adapter should
derive session scope from the authorized application binding, not ask agents to
smuggle tenant identity through an extra header. Large evidence should be a
separately readable artifact: the current model-facing body presentation limit
is 32 KiB. That limit too can be revised with a resource policy.

The existing SPK importer has hardcoded 256 MiB input and 768 MiB expanded limits
(`native/spk-host/src/materialize.rs:18–26`). Its documented implementation holds
raw/decoded data in memory; the ingest service caps memory at 2 GiB. **These are
not fixed product boundaries.** For operator-installed Oracle packages we can
introduce a larger admitted resource profile, while preserving smaller user
profiles. A credible large-package implementation must address extraction memory,
disk reservation, bounded decompression, interruption recovery and hash checks,
not only increase the constants. Streaming extraction is a candidate improvement.

Mini/nanodregg have changed direction since the earlier handoffs. The current
nanodregg orientation calls Mini finish-only and itself a separate exploration.
This does not override Ember's current request to integrate with Mini. It favors
a portable Oracle service contract with thin host-specific receiving adapters.
No deployed Oracle route was found in Mini's searched native/deploy source.

## Architecture choices

These are not mutually exclusive; they share the same versioned service contract.

| Choice | Strength | What needs building / principal cost |
| --- | --- | --- |
| Native veri7vn tool bundle | Small, fast, offline; closest to our checked computation paths. Useful even without the Oracle corpus. | Refresh/package current kernels; preserve recognition and source premises. Lacks Oracle7's newest builders and general retrieval by itself. |
| External Oracle appliance, governed calls | Easiest place to share large immutable stores and pool workers. Portable across Mini and other agent hosts. | A real governed receiving/tool adapter and tenant state isolation. Simply granting raw network access would skip Mini's accounting and authority. |
| Operator-installed Oracle SPK appliance | Uses Mini's existing app lifecycle, tickets, API tools and resource publication. Can expose a human Workbench as well as agent APIs. | Raise/configure operator import limits and improve ingestion, or provision stores separately. Supply the HTTP/Cap'n Proto bridge and qualify the actual lifecycle. Larger operational integration than a standalone service smoke test. |
| Per-workspace builder/laboratory | Groups can build specialists, inspect exams and share selected artifacts. Strong fit for collaborative agent research. | Isolated generated-code execution, explicit network/data acquisition, resource limits and promotion into a pinned answering profile. Highest mutable-state and lifecycle burden. |

**My choice:** one portable Oracle appliance contract, deployed first as a bounded
query service; Mini's governed app route is the intended access path. An
operator-installed SPK is a reasonable initial deployment once its importer is
made suitable. Retain the external-service option if shared-store efficiency or
simpler operations makes it preferable. Do not require redesigning the Oracle
engine into Lean or Objective Bend to host it.

Inside that appliance, keep three independently versioned layers:

1. **Code/runtime:** Python environment, pinned 4.9 code, current veri7vn binaries,
   the service adapter, all required notices. No auto-update during serving.
2. **Knowledge:** content-hashed store set plus source/license manifest. It can be
   shipped in the large operator package or supplied as a separately verified
   read-only store. Share its physical pages between instances where the host
   supports this; do not share writable tenant memory.
3. **Workspace:** conversations, receipts, caches and optional learned specialists.
   A builder gets its own writable overlay. Promotion makes a new named code/data
   version; an exam pass never grants installation or publication authority.

First proposed tools: `oracle.ask`, `oracle.capabilities`, `oracle.explain`, and
an explicit veri7vn calculation/check surface. These names are proposals, not
implemented tools. Calls should bind request ID, authorized conversation handle,
code/data/kernel versions and bounded output. Return status and evidence even on
refusal; keep execution error distinct from deliberate abstention. Separate a
historical result receipt from permission to act on or disclose that result.

Mini supplies identity, authority, budgets and durable receiving. The Python
Oracle computes answers; it does not implement a second Mini policy engine.
Conversation calls and builder operations can mutate state, so lost replies
must not become blind resubmissions. Pure stateless queries can use a cache keyed
by the exact request and complete code/data profile.

## First implementation slice, when selected

Build one pinned slim query appliance with the full evidence-preserving adapter
and private workspace paths. Qualify it locally on Linux x86-64, with explicit
kernel unavailable/disagree/refuse cases, and measure actual cold/warm memory,
latency and disk usage. Then put that same artifact behind Mini's existing app
API receiving path and exercise two authorized tenants, a cross-tenant refusal,
a current-law/grant refusal, and a lost-reply recovery. The test must traverse the
actual host and worker; a mock HTTP pass is not integration evidence.

In parallel conceptually, choose the operator provisioning shape: large SPK
with streamed import, or small code image plus separately verified stores.
That choice should follow measured package/import behavior, not an inherited
constant. Start with one operator size profile; expose user-selected installation
only after its separate resource/admission policy is defined.

Keep the builder and the six companion tools as later optional capabilities of
that same hosting contract. This preserves the broader ambition without making
the first agent question depend on deploying every repository.

## Reproduce this investigation's executable checks

From the veri7vn checkout, using the retained source snapshots:

```sh
.venv/bin/python -B docs/research/psiloceyeben-2026-10-26/probe_components.py \
  var/universe-20261026 --out var/universe-20261026/component-probes-rerun.json
```

The runner executes only w551's comparator/chat wrapper with explicit doubles,
Trafficcop's routing panel, three DeepSpace scenarios, and the swarm's unit-key
functions. It makes no network calls, starts no services, and builds no proof
sessions. Its successful execution establishes those narrow observations only.
