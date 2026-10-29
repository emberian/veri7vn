# Native capability and performance expansion

Owner: root. Active goal authorized 29 October: improve domain coverage and
performance across Oracle7, the shared native appliance, and veri7vn/extracted
implementations; integrate useful capabilities without requiring a formal proof
for everything shipped. Preserve the distinction between computed, checked,
sourced, numerical and theorem-backed claims. Ordinary committed checkpoints
and an upstream issue/PR update are authorized.

## First provider checkpoint

- Added petgraph graph optimization and an independent forest optimality check.
- Added egg polynomial search with independent exact normalization, plus typed
  dimensional admission and candidate checking.
- Added faer scientific solving/fitting with rank, conditioning and residuals.
- Added differential-dataflow versioned dependencies with support retractions,
  cycles and actual settled-frontier snapshots.
- Added optional PyO3 features for these providers and host-selected reasoning
  registration through the existing operation registry without a Python Engine.
- Read relevant existing papers and wrote the [integration program](../native/docs/INTEGRATIONS.md)
  connecting these mechanisms to existing specialists and new domains.

Central Linux checks: 51 focused Rust tests and warnings-denied Clippy passed.
The combined extension passed 17 existing Python contracts, actual calls for
the new providers, and the three-operation discovery/invocation path. Python
adapter contracts: 16 passed. Existing appliance component composition:
11 passed, one source-dependent test skipped. No new specialist-panel numbers
or Isabelle theorem statements yet. See the retained native evidence.

The synthetic graph comparison improved end-to-end time including checking.
The small incremental workload lost to recomputation by about 10x despite exact
agreement. That negative result is a decision input, not a reason to hide the
comparison. Scientific fitting remains numerical; dimensions and residuals do
not prove the caller's physical model.

## Work to carry through next

1. Connect external graph candidates to the extracted `mst_cert` interface.
   Audit isolated-node/disconnected-forest semantics against its edge-derived
   node universe; expose the checker rather than recomputing candidates inside it.
2. Build a real typed scientific consumer in energy/mechanics/chemistry, extend
   its useful domain and score its shipped panel plus independent model cases.
3. Investigate incremental crossover workloads, demand-driven views, bounded
   fresh recomputation, retained-state cost and tenant/epoch isolation. Do not
   make the current all-pairs batch the default public-KB architecture.
4. Extend symbolic reasoning with explicit assumptions/domains, exact reaction
   balancing and certificate replay. Evaluate egglog when cooperating interval,
   nonzero and dimensional analyses justify the additional machinery.
5. Connect optional providers to release admission, operator enablement, shared
   capacity/contained workers and the signed Mini agent/browser/restart journey.
   Current PyO3 functions and host injection are a useful interface, not that journey.
6. Continue the [complete native runtime](lanes/NATIVE-FOUNDATION-2026-10-28.md):
   compositional language, route ordering, dialogue adapters, effect executors,
   durable retention/migration and full-resource profiles remain unfinished.
7. Follow up on the published upstream checkpoint with small optional-backend/
   provider contributions, reproducible cases, unaffected-head controls and
   explicit implementation/data versions.

## Standalone service checkpoint

The [native service](../native/docs/STANDALONE.md) now runs independently of
minidregg. It exposes the three reasoning operations, numerical solve/fit and
thermal networks, and two finite dependency interfaces through actual catalog
discovery and direct calls. One global process pool shares an admitted extension
snapshot and reuses workers across profiles. It has no per-tenant engine or data
load. Cancellation, saturation, failure retirement and process ownership are
tested; this is a private pure-computation service, not authenticated public
hosting or the complete durable conversational runtime.

Root central evidence: 54 focused Rust tests, warnings-denied Clippy, 15 process
tests on each of macOS/Linux, 10 Linux service tests including the actual CLI
launch/call/restart journey, nine macOS service fixtures with one Linux-extension
skip. The extracted MST session passed its four-theorem zero-oracle marker;
the two new wrapper statements establish spanning and weight minimality for the
supplied candidate. All 13 binary adapter tests passed, and actual Rust graph
candidates composed with the extracted checker. Disconnected forests remain
explicitly unsupported by that proof interface.

The [rooted crossover](../native/evidence/2026-10-29-rooted-crossover.json)
shows why demand matters: the 4,096-node affected-update batch took 90.5 ms with
maintained execution versus 1,109 ms fresh, including setup and teardown.
Fresh remained faster for the 48-node chain. These are single-trial synthetic
workloads with exact answer/delta agreement; no automatic crossover is inferred.
The [pool exercise](../native/evidence/2026-10-29-native-pool.json) ran 96 mixed
sequential calls across 48 tenant identities at 0.305 ms median, using one child.
After a burst, the parent plus two children occupied about 34.5 MiB PSS.
The burst immediately refused 91 of 96 attempts: a capacity-bound test, not
a throughput or fairness success claim. See [the validation receipt](../native/evidence/2026-10-29-provider-host-validation.json).

The [chemistry checkpoint](../native/evidence/2026-10-29-chemistry-validation.json),
commit `94add5b`, adds exact charge/isotope-conserving reaction balancing through
the optional reasoning profile and pure standalone service. Central hbox checks
passed ten native contracts, 24 adapter contracts, ten actual-extension service
checks and warnings-denied reasoning Clippy. The reused combined artifact also
contains unfinished core changes, which this scoped receipt does not qualify.
There are no new shipped specialist-panel scores or theorem statements.

The [language/domain checkpoint](../native/evidence/2026-10-29-language-chemistry-domains-validation.json)
now integrates learned exact fragment/outer composition, shared semantic stages
and typed attribute columns, cancellable atomic language turns, supplied-DNA
alignment and statistical regression. All 101 scoped Rust checks passed,
as did combined warnings-denied Clippy, 15 actual binding checks, eight new
adapter checks and 15 standalone service checks. Default-feature export absence
was checked separately. The DNA and statistics providers remain optional and
operate on supplied arguments, with no new specialist-panel score or theorem.

The first eager composition revision regressed the pinned original 40 questions
from 17 correct / 23 unknown / no errors to 14 correct / 21 unknown / five errors;
intermediate revisions reached 16 correct / 23 unknown / one error. Demand-driven
outer regions and shared semantic evaluation restore 17 / 23 with no wrong answers
or errors, under unchanged bounds. Static review also caught a Unicode equality
mismatch before final validation; the shared helper and differential contract
preserve existing comparisons and evidence.

The [predeclared paired 100](../native/evidence/2026-10-29-language-chemistry-reader.json)
compares the exact retained whole-only artifact with the new combined artifact:
35→36 correct, 61→60 unknown, four refusals each, zero wrong answers/errors.
The gained BristolUni subscriber qualifier is independently checked across all
matching public-university candidates in the pinned KB. Median latency rises
2.08→10.0 ms and p95 20.1→30.7 ms. These are single fresh-process measurements on
warm filesystem caches, not fleet scores or throughput claims. Full paired
reports, observation hashes and intermediate regressions are retained.

Next performance work: share repeated lexical analysis and indexed prefix probes
without semantic fast paths, discarded alternatives or raised bounds. Expected
native input refusal currently retires an otherwise healthy worker. A future
typed expected-failure protocol should distinguish safe invalid_input/resource_limit
from unexpected faults/timeouts, keep immutable snapshots shared and test the
same PID through valid→expected-refusal→valid. Do not assume all ValueErrors are
safe. The current checkpoint preserves the existing retirement rule and tests
replacement/recovery.

Continue broader routing, durable retention/migration, dialogue adapters, actual
effect executors, representations, specialist panels and signed Mini integration.
Terra reviewed the optional DNA/statistics sources and cancellation notifier;
central execution supplies the measured results above. The broader goal remains
active.

## Upstream and active second batch

Checkpoint `b6481309b776407b0791ea1546cce58e16c5a7db` is committed and pushed.
Posted a substantive update to [upstream appliance discussion #5](https://huggingface.co/psiloceyeben/oracle7-slim/discussions/5)
on 29 October (comment `6ae2cd22050e230f92d13066`), linking the exact commit,
integration program and validation, including both performance results and
unfinished hosting boundaries. No PR or upstream merge is implied.

The second implementation batch completed demand-driven incremental views,
bounded fresh execution, thermal networks, the external extracted certificate,
shared process containment and standalone service integration. Its evidence is
separate from the first provider receipt.

The first Sol batch owned incremental reasoning, scientific solving, dimensional
symbolics and the host adapter. Root owned graph/algebra, interfaces, centralized
checks, integration and upstream communication. Lanes did not build or commit.


## Lexical reuse and expected request refusals

The [next focused checkpoint](../native/evidence/2026-10-29-native-performance-validation.json)
shares normalization/word boundaries and ordered indexed lexical rows, including
negative probes, within one request. All option projections, alternatives and
bounds remain. Optional retained-cache estimates and output scratch are separate
envelopes; cache saturation falls back to complete streaming, without a hard RSS
claim. Five new workspace contracts include mode/normalization/limit differential
checks and a warmed zero-SQL-work check. All 46 focused Rust contracts, combined
Clippy, 17 actual bindings, 20 pool checks and 16 service checks pass.

A first overloaded run looked slower (median 12.95 ms/p95 91.39 ms) at host load
32.55 versus the historical control's 6.30; it is retained. One approved balanced
control/new/new/control experiment then used the exact same 100 questions and
configuration with process CPU instrumentation on both artifacts. Every answer,
status and interpretation count remains identical: 36 correct, four refused,
60 unknown, zero wrong/errors. Query medians are 10.88–11.45 ms control versus
4.10–4.48 ms new; p95 is 33.44–34.72 versus 28.10–31.33 ms. Per-case CPU and wall
ratios have median 0.475 new/control; summed CPU ratio is 0.742. Matched-program
cases improve less (median CPU ratio 0.869) than cases with no matched program
(0.392). This is one bounded experiment, not a throughput or general-language
claim. Full reports, per-case ratios, hashes and the overloaded run are retained.

Only the exact compiled `NativeRequestError` for reviewed bio/statistics Invalid
or Limit variants, with fixed codes and bounded UTF-8 metadata, permits reuse.
Actual mixed-tenant valid/refused/valid calls retain the same PID/snapshot and
release the refused tenant lease. An actual unclassified numerical failure still
retires/reaps the worker and allows replacement. Generic ValueError and malformed
frames receive no reuse exemption. Independent bio-only/statistics-only builds
also repair and verify the provider-module feature gate masked by the earlier
combined build; default absence remains tested.

The durable Runtime host files are a separate following checkpoint and remain
outside this source manifest and qualification. Broader routes, dialogue,
retention, effects, specialist panels and Mini integration remain active work.

## Stable durable-host and distribution checkpoint

Commit `7773163` freezes the private data Runtime, explicit host retirement,
resident extracted MST checking and relocatable distribution. The [stable
receipt](../native/evidence/2026-10-29-stable-appliance-validation.json) binds the
staged-index snapshot, final extension and 140 source files. It records 115 scoped
Rust contracts plus one actual resident case, warnings-denied Clippy and 54
selected Python checks. Actual hosted and packaged journeys use manufactured
data, preserve exact replies across restart and keep operator resources external.
The retained Linux archive needs a compatible CPython/system environment.

State stores 1/2 upgrade to 3 without rewriting request/reply bytes; envelopes stay 2.
The new retirement budget affects release admission, and release-bound history
is not silently migrated. Permanent fences reclaim stateful namespace payloads
only under host authority; unresolved effects prevent retirement. No user store
was retired during qualification.

This cut retains the committed 6cc reader. Experimental segment/nested expansion
first regressed the same 100 to 33 correct/three binding-limit errors; that run and
diagnostics remain retained. Its structural repair has 30 authored contracts and
still needs central real-case qualification. Next graph/typed-refusal additions
are separate frozen work awaiting their own checks. Full routing, dialogue,
external effects, retention policy and Mini integration remain unfinished.
