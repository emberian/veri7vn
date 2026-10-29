# Claude handoff — 29 October 2026

Ember asked for a fresh turn from Claude. The task is to make Oracle7/veri7vn
useful as a fast shared service and broaden its reasoning capabilities. Do not
let the next four reader cases become the whole project. Ember's latest request
was an implementation/design sprint: write substantial exploratory Rust, learn
from it, and discuss adoption before spending another long cycle on integration.

## Start here

- [Current work and backlog](NATIVE-EXPANSION-2026-10-29.md).
- [Callable capabilities](../native/docs/CAPABILITIES.md).
- [Four design experiments](../native/experiments/README.md) and
  [Astra's source review](../native/experiments/REVIEW.md).
- [Native hosting](../native/docs/RUNTIME-HOST.md),
  [package](../native/docs/DISTRIBUTION.md),
  [remaining Engine migration](../native/docs/MIGRATION.md).

The checkout is `/Users/ember/dev/o7vn`, branch `dev`, remote
`github.com:emberian/veri7vn.git`. Before this handoff, HEAD was `dae7e48`, pushed.
The handoff commit also saves the new audit tools and diagnosis receipts.
Read `AGENTS.md`; `upstream/` is read-only. Stage named files; never stash/reset
the shared tree. Ordinary commits/pushes and unsigned commits are authorized.

## What actually works

The private standalone HTTP service discovers and invokes optional native
graph, polynomial/dimensional, chemistry, scientific, dependency, DNA and
statistical operations. A global bounded worker pool shares resources across
tenant handles. It does not create an Engine or corpus for each tenant.

The optional runtime profile uses a shared indexed KQA image and persistent
SQLite journals. Structured queries and language turns have restart/retry
checks, tenant/resource separation and explicit namespace retirement. Exact
shortest paths have checked finite/unreachable/negative-cycle witnesses.
Rust MST candidates can use a resident extracted checker within its narrower
connected-tree theorem. Pure typed input refusals retain healthy workers.

The refreshed Linux archive is
`var/native-reader-20261029/native-appliance-linux-x86_64.tar.gz`, SHA-256
`683106a6cc7e83ba35a8ea60489d80683355935dbfc6e7cbadd470de76f16540`.
It contains the `2fda9fe` extension, needs compatible CPython/system libraries,
and keeps data and private state external. It is not a fresh signed Mini package,
full Engine replacement, public gateway or sustained multitenant qualification.
`~/dev/minidregg/docs/oracle-appliance.md` describes the older signed Python
appliance; do not mix its measurements with this native package. Mini was not
modified or freshly tested in this recent batch.

`native/oracle-logic` is a separate grounded normal-program stable-model core:
18 executed checks including real clingo, independent model-witness checks,
bounded child handling and query probes instead of exhaustive enumeration.
Absence claims trust the solver. It is outside the main workspace and has no
PyO3/HTTP/package operation. Its new demos are unexecuted.

## The implementation sprint

`dae7e48` added isolated Rust prototypes, not registered providers:

1. Streaming integer-posting queries with shared images, bounded cursors and
   scalar consumers. SQL pushdown/shared DAG materialization already exist in
   production. The opportunity is avoiding string/evidence copies where a
   consumer genuinely needs only a scalar. Relation projection needs ordering;
   the prototype's quadratic sort must not be promoted for scale.
2. Maintained demand views with shared public graph and small private overlays.
   Insertions propagate; affected deletions rederive roots to avoid circular
   support. Cache capacity must not veto committed source truth. An adapter
   needs durable-version coordination and invalidation/eviction.
3. Conditional rational formula replay with dimensions and explicit premises.
   Original-domain evaluation preserves singularities but currently adds work.
   Merge useful domain/assumption ideas into existing algebra before adding a
   second hosted API; rational work/depth limits remain absent.
4. Thirteen nonmonotonic scenario readouts: defaults, duplicate source support,
   withdrawal, competing actions, diagnosis and conflicting obligations.
   The evidence-token revision layer is promising. Its mutable builder can
   change content without changing the revision label: seal or content-address
   snapshots before caching. Possible actions are not authority to execute.

No prototype was compiled, tested or benchmarked. Rustfmt, source review and
hand traces only. Astra reviewed; streaming image-mixing and allocation-accounting
findings were fixed in source. Sol did implementation. Ember corrected our model
choice: Terra is cheaper scoped help, not the final critical reviewer; use Astra
for major final reviews. Root recommends scalar-output contracts and evidence
revisions as the first next experiments, not wholesale engine replacement.

## Two reader defects: exact state and next decisions

The original 100 questions remain 36 correct / 4 refused / 60 unknown / 0 wrong
or errors. Expanded composition adds interpretations, not answers on that set;
historical timings are slower, with no matched speedup claim.

The frozen new 16-case challenge failed: 1 new correct count, 7 unanswered
positives, 4 expected declines, 4 storage errors. No wrong answers. Old code had
10 unanswered positives / 6 expected declines. Preserve these fixtures and
limits. They are independent finite-image cases, not a fleet panel score.

**Storage:** four diagnostic probes show eager flat fragment storage/dedup keys
consume ~93% of the 2 MiB envelope before semantic admission. One cached region
contains 1,290 fragments. This is not nested-product work or transient walker
storage. See [diagnosis](../native/evidence/2026-10-29-composition-byte-diagnosis.json).
Proposed fix: exact step/program arena, thin region records, shared provenance,
one viability record per program, flatten only at existing evaluator/output
boundaries. Preserve every alternative, child-region witness and guard order;
account interner keys and temporary flattening while the arena remains live.
**That remedy has not been written.** The author's agent lost network permission.

**Learned form conflict:** a genuine count question loses “number of” because
Reader7 tries the alias “number of albums” → album before its existing canonical
plural branch. Combined with a mislabeled “Which calendar month follows March?”
Count example, it produces support 2 for Count under `which X1`, then conflicts
with the entity answer-form guard. Do not fix this by dropping disagreeing results.

The [source audit](lanes/NFORM-EVIDENCE-2026-10-29.md) has exact training indices,
source hashes and a small general patch: try canonical plurals before aliases.
Recovered before/after provenance confirms the legitimate album row moves to
`which number of X1`. Eight portable regression methods are authored in
`tools/reader_audit/test_canonical_plural_first.py` but not run. Full retraining,
image rebuilding and cohort comparisons remain. Reader6 has separate alignment;
this is not a complete fix for every alias consumer.

Fresh upstream fetch still matches pinned revision
`c473d28914e480425adb29b4f7f42485b8cfb4e3`; reader_v7 SHA-256
`f37f687e8190f08ff862738543790d6bcd56185a1a807ffdbd5cf8340da85354`.
The patch is suitable for a small upstream proposal after source checks. Compare
code-only and learned-data changes separately so a combined win hides neither.

## Dirty files and stopped work

`native/oracle-core/src/composition.rs` and `segments.rs` contain **temporary
diagnostic instrumentation**, including Limit-to-Invalid error changes. They
are not a production fix and must not enter a release. Their exact snapshots,
build/probe logs and raw observations are preserved in
`var/composition-byte-four-20261029/`. Keep or remove only these known diagnostic
hunks deliberately; do not reset the checkout. The lane report is saved in the
handoff commit with the completed diagnosis.

The integrator agent stopped on an account usage limit; the reader agent stopped
on revoked network permission. The four probes completed first. A handoff-time
hbox process inspection found no relevant live build, source-provenance replay
or table export. Unrelated old shell waiters were left alone. No daemon or solver
was started by the design sprint. Recheck actual processes before launching work;
do not assume a failed agent stopped a child.

Central build workspace: `hbox:/tank/lanes/o7-native-20261028`.
Cargo: `/home/hbox/.cargo/bin/cargo`, two build jobs, reuse the existing target.
Python: `wheel-env/bin/python`. Image: `data/reader-image-v3.sqlite`.
Source-replay scratch: `form-priority-20261029/`; raw reports are also local under
`var/reader-form-20261029/provenance/`. No broad suite is needed to validate the
small source patch. After a representation fix, start with contracts and the four
failures, then the frozen 16/100 comparisons. Package only a qualified candidate.

## Broader work that must not disappear

- Full Engine route order/guards, other relation/document stores, dialogue owner
  capture/restore and real effect executors remain. An outbox is not an executor.
- Fresh signed Mini/Hermes agent/browser/restart journey and authenticated public
  serving remain. Shared pools need sustained load/fairness/memory evidence.
- The broader specialist/assurance backlog has not had a current fleet audit.
  Current READMEs distinguish individual measurements from fleet completion.
- Astronomy/ephemerides, convex optimization, learned readouts and richer
  bio/statistical models remain largely unimplemented ambitions.
- Upstream needs small native/provider PRs. Discussion is not code acceptance.

[Upstream discussion 5](https://huggingface.co/psiloceyeben/oracle7-slim/discussions/5)
was updated through checkpoint `ab05020`; it explicitly includes reader failures.
Biology PR 8 and statistics PR 9 were open at the last check. The new plural
patch is not posted. User authorization for substantive upstream PRs/updates
already exists; avoid duplicate posts and verify current source first.

`4494386` simplified documentation and deleted two spent provisioning reports;
JSON receipts and live obligations were retained. Please keep current docs useful
rather than accumulating another chronology of successful commands. Use `cv`
session `codex:01a14da6` for context: around 30623 is the original Rust ambition,
30818 the broad goal. The latest steer asks for design exploration and a fresh
Claude perspective. `cv prompts` is unavailable; use `cv show`.
