# Public reader preparation and explicit Engine readiness

This prepared-serving mode targets the exact U8 source cut. It has passed
isolated hbox qualification. The Rust host now admits the artifact through typed
configuration and prepares tenant-owned workers before serving; see the
[host contract](../../../native/docs/HOST.md#public-preparation-for-legacy-python).
The [central receipt](../../../native/evidence/2026-10-31-native-route-validation.json)
records 11 focused checks, one public-artifact manufacture, actual cold/warm
worker calls and missing/tampered artifact refusals before readiness. Cold
readiness took 29.59 seconds under the unchanged 120-second startup bound; the
previously stalled question completed cold and warm under its 30-second bound.
These observations do not qualify other upstream revisions or all Engine routes.

The retained U8 modeling diagnostic timed out at its unchanged 30-second query
limit. The actual query executor was constructing the standing specialist family;
a background thread was learning public reader operators. The main thread waited
for `Engine.chat`. That is initialization after ready, not evidence of a bad
modeling parser, a semantic decline or a proved deadlock. Its frozen diagnostic
remains under `var/coherent-native-20261031/modeling-diagnostic/`.

## Exact source boundary

`pins.json` names the five modified source files and exact byte hashes from U8
(source revision `c473d28914e480425adb29b4f7f42485b8cfb4e3`, tip w574,
materialization receipt `97286fb824bb102a24ac9e7458fc8d8426212ad0bff2b585bd00d6e0462d00a5`).
`prepared-serving.patch` also adds `workbench/swarm/runtime_preparation.py`.
Primary `upstream/` and `var/appliance-20261029/candidate-u8` are immutable inputs.
Apply only to a **new materialization**, with a fresh complete materialization
receipt that includes the patch and new helper. Do not reuse the old admitted
receipt for changed code. The launcher’s original CRLF lines are retained.

The new mode is explicit: `ORACLE7_PREPARED_SERVING=1`. Without it, existing
standalone authoring retains its lazy family/background-organ behavior and local
reader learning. In prepared mode:

- `oracle7.load`, already running on Engine’s executor, calls `prepare_runtime`
  before returning the runtime.
- w504 constructs its entire standing family before any query. w572’s constructor
  synchronously calls its idempotent preparation method in this mode, covering
  both the launcher and explicit-tip constructor path. It suppresses its
  background loader, then initializes required air/physics/facts synchronously
  after family construction. Its caught errors and missing dependencies become
  startup errors. Process-global import/path/cwd swaps and reader assembly no
  longer overlap that daemon or live queries during preparation.
- Reader and clause table admission is load-only. Missing or mismatched artifacts
  fail before ready; serving never invokes their learner or creates a cache.
- The existing enclosing host’s startup deadline remains unchanged. Initialization
  that exceeds it remains unavailable. This patch adds no larger deadline and
  cannot promise that all dependencies fit the current limit before measurement.

Readiness means the **declared generic Engine dependencies have initialized**;
it establishes neither complete natural-language coverage nor restored dialogue.
The separate finite native routes do not require this generic Engine preparation.

## Shared public artifact and private state

`prepare.py` calls the existing public reader and clause learners directly,
without importing `organs10`, constructing Engine or touching its private MADE
state. It uses a new temporary cache and publishes exactly two files: a reader90
pickle and a clause101 pickle, plus `MANIFEST.json`. Temporary compiler files are
removed only from the tool’s own temporary directory. Publication uses the existing
atomic exclusive Linux/macOS directory publisher; an existing output is refused.
Private lessons, ledgers, overlays, session records and scratch are never copied.
Extra compiler outputs are refused rather than silently dropped. Source and
artifact directories must be disjoint. Serving refuses alternate/private training
and KB paths rather than reusing public tables for another input.

The external manifest binds full SHA256s of actual public train/KB bytes, every
Python source under `workbench/swarm`, the complete materialization receipt,
CPython version/cache tag/pickle protocol, fixed hash seed, and every reader/
clause preprocessing option read from the inspected source. Filename keys retain
the original truncated upstream keys; those names are **not** the admission key.
Different options or full source/data identity cannot reuse a stale alias merely
because a truncated filename collides. The source materialization itself must
already be admitted and protected; the receipt’s self-declared hashes alone do
not verify its other contents.

The operator must supply both `ORACLE7_READER_ARTIFACT` (absolute nonsymlink path)
and **independently admitted** `ORACLE7_READER_ARTIFACT_SHA256`. A digest supplied
beside an untrusted payload does not confer trust. Admission hashes the pinned
manifest, verifies identity and exact two-file inventory, and verifies each file’s
size/full digest before decoding that exact bounded byte string. File growth or in-place mutation cannot substitute unchecked bytes between hashing and decoding. This retains up to an additional 512 MiB byte buffer transiently during decoding; no lower peak-memory claim is made. Each file is capped at
512 MiB; manifest is capped at 2 MiB. Pickle can execute arbitrary code: this is
trusted executable input, not a safe format for unauthenticated contributions.
Read-only protected custody must continue throughout serving. Permissions set by
the tool aid custody but do not protect against the owner changing the files.

Private conversations still use private `ORACLE7_STATE`; only immutable public
learned tables are shared. Each process assembles its own reader objects/globals
on its serialized Engine initialization thread. This shares disk compilation,
not arbitrary live Python objects or per-tenant mutable contexts.

## Single central validation union

The scoped source and fixture checks are:

```sh
python3 -B tools/upstream/runtime_preparation/check_sources.py --tree /absolute/immutable-u8
python3 -B -m unittest discover -s tools/upstream/runtime_preparation -p 'test_*.py' -v
```

The eight artifact fixture methods cover publication without replacement, warm read with
no writes, missing operator pin, manifest/payload tampering before pickle decode,
source/data/options/Python mismatch, a concurrent rewrite before decoding, missing/extra/private files, alternate private
inputs and symlinks. They import no full Engine or reader. Three additional
synthetic worker checks preserve unprepared constructor-only wording and refuse
absent preparation markers or unsupported explicit tips before ready. Actual
U8 preparation and worker observations are recorded separately in the receipt.

`derive.py` provides the concrete source recipe. It verifies the pinned baseline
receipt and actual non-store files, copies those files into its own new staging
directory, shares only declared stores as immutable symlinks, applies the exact
patch, and hashes the complete final file inventory (including actual shared store
bytes). It writes a fresh `APPLIANCE.json` with the new file inventory, patch digest
and parent receipt digest, then publishes without replacement. No old receipt is
reused as the new deployment identity; no source/store hardlink is modified.

```sh
python3 -B tools/upstream/runtime_preparation/derive.py \
  --baseline /absolute/immutable-u8 \
  --baseline-sha256 97286fb824bb102a24ac9e7458fc8d8426212ad0bff2b585bd00d6e0462d00a5 \
  --output /absolute/new-patched-u8
```

Admit the resulting source receipt and retain its actual hash before manufacturing.
Then manufacture once under the designated hbox resource controls:

```sh
PYTHONHASHSEED=0 /absolute/same-u8-venv/bin/python -B \
  tools/upstream/runtime_preparation/prepare.py \
  --tree /absolute/new-patched-u8 --output /absolute/new-public-reader-artifact
```

Keep the actual stdout receipt, source manifest, exact artifacts and compiler
resource usage. The public data inventory is `root/organs10/kqa/{train,kb}.json`;
required reader source is the complete `workbench/swarm/*.py` closure. Standing
family initialization also needs all paths named by `standing_v1.txt` and their
normal dependencies; air/physics require their existing materialized inputs.
This tool manufactures no family objects or separate physics artifacts.

Only after root’s frozen-source execution go, qualify an isolated prepared-mode
Engine with the **unchanged** external startup=120/query=30 bounds and exact failed
question. Set the three explicit preparation variables above and hash seed before
Python starts. Retain startup duration and component failure, first/warm replies,
artifact bytes before/after, private workspace inventory, actual source identity
and old timeout record. Fail if a required dependency is not ready, a learner runs
on a serving path, private state enters the artifact, or source/artifact changes.
A missing/tampered/version-mismatched artifact must fail startup before any query,
not start learning. Then and only then consider the still-missing exact modeling
core baselines and original six-criterion admission. No timeout becomes a decline.

## Rust host integration

The prepared source supports only the exact audited U8 w574 class. Its w573/w574
descendants have no constructor/preparation overrides; the w574 organ loader uses
fields initialized before preparation. The fixed-class constructor call and
completion marker cover both launcher and explicit-tip construction. Other
prepared tips are refused.

The Rust host admits the source materialization and independently pinned public
manifest through `engine.prepared`. Artifact identity and replacement policy
participate in deployment identity. The launcher can relocate external public
tables without copying them into the package. Only admitted configuration reaches
the child after its environment is cleared; inherited environment variables do
not select this mode.

One supervisor per configured slot performs preparation outside query work.
Initial readiness precedes the listening announcement. An unused ready generation
can be assigned once; eviction retires its process and prepares a replacement.
A process that held one tenant's private state is never assigned to another.
Attempts and backoff are bounded; exhaustion remains unavailable until host
restart. Shutdown cancels preparation, joins supervisors and reaps owned children.

Constructor readiness does not prove continued liveness: idle death is detected
on use, eviction or shutdown. Public files are shared; Python object heaps remain
per process. Full Engine recovery, sustained mixed-tenant performance and
compatibility with later upstream revisions remain separate work. The
[host guide](../../../native/docs/HOST.md) documents configuration and the current
[checkpoint](../../../project/lanes/NATIVE-HOST-2026-11-01.md) binds actual hosted
qualification to its source and artifacts.
