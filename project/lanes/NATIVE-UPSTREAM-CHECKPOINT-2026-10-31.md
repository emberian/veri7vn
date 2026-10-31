# Native upstream checkpoint — 31 October 2026

The original native expansion is committed and pushed as `feca38a`. This is a runnable
review cut, not a claim that upstream has adopted the Rust runtime. Central
validation passed 171 Rust and 142 Python checks, 99 new hosted workflow cases,
durable evidence replay, and 256 bounded requests across 64 tenants in one host.
See [the expansion tracker](NATIVE-SOL-EXPANSION-2026-10-31.md) for scope and
[the receipt](../../native/evidence/2026-10-31-native-expansion-validation.json)
for actual execution results.

The [following native cycle](NATIVE-NEXT-CYCLES-2026-10-31.md) is also committed
and pushed in `70f4ca5`, `14ceb7d` and `64430c7`, with validation in `0875b14`.
It adds the typed encoded service path, packed reader composition, contiguous
graph checking and resumable evidence clients. Its separate receipts record
169 Rust tests and actual HTTP/restart checks, then one fixed-CPU comparison.
Small service medians improved; reader latency did not show a resolved gain.
These results do not replace the earlier expansion's evidence or its limits.

## What upstream has received

- [Appliance/native discussion #5](https://huggingface.co/psiloceyeben/oracle7-slim/discussions/5#6ae606dd5c92f39cdda2bca0):
  immutable code, architecture, capability and evidence links. The proposed
  review order is execution/host, typed providers, then durable state. Native
  adoption still requires upstream review and integration; this discussion is
  not a merged native PR.
- [Plural repair PR #10](https://huggingface.co/psiloceyeben/oracle7-slim/discussions/10#6ae607095daeb736a3958ac2):
  new release measurements, including two to ten correct on the targeted cohort
  and no gain on the 100-question control. Upstream's broader cascade comparison
  remains outstanding. Newly exposed Date/quantity and empty-count defects are
  reported rather than hidden by selecting a convenient interpretation.
- Upstream 10.3.1 incorporated the biology and binomial probability-binding
  contributions (#8 and #9). The maintainer requested a further binomial support
  correction: a valid event with more successes than trials has probability zero.
  The correction is submitted as [PR #11](https://huggingface.co/psiloceyeben/oracle7-slim/discussions/11)
  at `9c5867ff7372468b16da84a3097b7daab8d4883f`, with a
  [reply on #9](https://huggingface.co/psiloceyeben/oracle7-slim/discussions/9#6ae6092677373232a4eba978).
  It passes eight new and five existing test methods on pinned slim/full trees;
  all 860 shipped statistics replies remain unchanged on each. The focused patch
  and independent tests live in
  [the contribution directory](../../tools/upstream/binomial_support/README.md).

The #5/#10 comments were read back from the Hub after posting; #11 was confirmed
as an open pull request. Publication does not mean acceptance or merge.
Earlier sibling issues and GitHub contributions are recorded in their own
upstream trackers; this checkpoint does not claim a fresh census of every thread.

## Work still needed, in priority order

| Work | Concrete problem | Next useful result |
| --- | --- | --- |
| Reader representation and semantics | Packed composition removes fragment flattening, but the retained question still needs 1,292 fragment checks and about 55–56 ms. Numeric literals can still occupy Date slots, and empty-child count semantics withhold valid zero results. | Stable checked-stage handles through execution, exact cached recipe admission, and separate slot/completeness repairs. Preserve every interpretation and witness. |
| Native call overhead | Typed encoding lowered scoped LP/GLM/small-graph medians to 49/85/27 microseconds; the retained chain reached 1.96 ms. Contract traversals and substantial graph work remain. | Remove further demonstrated repeated work without weakening independent checks. The latest library boundary excludes TCP; it does not supersede earlier HTTP observations. |
| Prepared consumers | Thermal reuse pays off in the scoped internal benchmark; sequence timings reverse with execution order. | Symmetric warmup, output lifetime and accounting before changing sequence code or claiming a gain. |
| State ownership | Native scalar context and revisable evidence are durable, but several Python conversation owners remain outside native recovery. | Migrate each real owner with explicit import/export and delivered-answer commit semantics; test cross-provider handoff and restart. |
| Evidence scale | Host policy caps history at 128 records/revisions and restore checks the complete history. | Configurable owner limits and measured checkpoint/retention design preserving IDs, withdrawals and exact retry. Incremental solving must agree with the fresh reference. |
| Learned bindings | The tiny Pythia readout pilot fit training data but all held-out proposals abstained. | A larger predeclared study with independent prose, rejection controls and useful held-out coverage; keep uncertainty visible. |
| Upstream integration | The native runtime is published in our repository, while upstream currently receives small Python repairs and the architectural proposal. | Review and adopt coherent layers with explicit compatibility boundaries, rather than presenting a large feature count as integration. |

The [next work cycles](NATIVE-NEXT-CYCLES-2026-10-31.md) concentrate on the first two rows, with
specialist consumers exposing the cost of the shared architecture. Deeper
scientific models, approximate sequence search, scheduling and stronger learned
readouts remain design avenues in the scout reports; they are not secretly
completed features or prerequisites for publishing this checkpoint.

Full Python Engine takeover, automatic release-identity migration and public
gateway authentication are not qualified by this native cut. Mini integration
is outside the current work. No new formal theorem is claimed for the Python
binomial correction or the numerical modeling additions.
