# Native capability and performance expansion

Owner: root. Active goal authorized 29 October: improve domain coverage and
performance across Oracle7, the shared native appliance, and veri7vn/extracted
implementations; integrate useful capabilities without requiring a formal proof
for everything shipped. Preserve the distinction between computed, checked,
sourced, numerical and theorem-backed claims. Ordinary committed checkpoints
and an upstream issue/PR update are authorized.

## Current checkpoint — 29 October, after `259d7b9`

This page tracks current work. Detailed measurements are linked below.
The native service now has a relocatable Linux package, optional durable runtime
hosting, shared workers, restart/retry checks, permanent namespace retirement,
resident extracted MST checking and exact shortest paths. Invalid pure requests
can leave a healthy worker resident. The refreshed package contains reader code
`2fda9fe`; the later `259d7b9` stable-model reasoning crate is qualified separately
and is **not hosted or included as a callable package operation**.

Reader composition preserves the original 100 results: 36 correct, four refused,
60 unknown, zero wrong and zero operational errors. That sample has no answer
gain, and its historical timings do not establish a speedup. The new frozen
[16-case challenge](lanes/NCOMP-CASES-2026-10-29.md) failed: one newly correct
answer, seven unanswered positives, four expected declines and four composition
storage-limit errors. No wrong answers were returned. The learned `which X1`
source admits conflicting Count and entity readings; byte-error ownership is
still under diagnosis. Keep the questions, bounds and expected facts unchanged.

### Outstanding work, including work displaced by this batch

1. Diagnose and repair the four composition storage failures; investigate the
   learned answer-form conflict without suppressing legitimate interpretations.
2. Integrate stable-model reasoning through shared workspace/PyO3, discovery and
   HTTP, with an operator-admitted solver resource and bounded child lifetime.
3. Complete Engine compatibility: other relation/document stores and reader
   families, route ordering, dialogue state adapters and real effect executors.
4. Qualify the fresh signed Mini/Hermes agent/browser/restart journey. Independent
   native HTTP checks do not establish that integration or a public deployment.
5. Measure sustained mixed multitenant load, fairness and memory; finish gateway
   authentication/admission, containment, retention operations and explicit
   release-history migration. Bounded pools alone do not establish production SLOs.
6. Turn the public native branch checkpoints into small reviewable upstream
   provider/backend contributions. Biology PR 8 and statistics PR 9 remain open;
   they are not a native-runtime PR.
7. Resume the wider specialist and assurance burndown. This native batch did not
   re-audit the old Wave-6 backlog or establish a current consolidated fleet score.
8. Revisit deeper symbolic/interval reasoning and verified CAS, ephemerides,
   optimization, richer biological/statistical models and learned representation
   probes. These remain candidates for implementation, not delivered features.

Start with [native overview](../native/README.md),
[service use](../native/docs/STANDALONE.md),
[runtime hosting](../native/docs/RUNTIME-HOST.md),
[distribution](../native/docs/DISTRIBUTION.md) and
[migration boundaries](../native/docs/MIGRATION.md).

## Exploratory implementation sprint

The next four designs are separate from the packaged service. They were authored
for design review, without compiling, running fixtures or measuring performance.
They must not appear as available hosted operations.

- [Streaming queries](../native/experiments/streaming-query/README.md): shared
  integer postings, pull operators and scalar consumers; ordered relation
  projection and existing language-stage semantics constrain integration.
- [Maintained views](../native/experiments/maintained-views/README.md): shared
  public graph, private support overlays and cached demands. Insertions extend
  results; affected deletions rederive them to avoid circular support.
- [Conditional symbolic formulas](../native/experiments/conditional-symbolics/README.md):
  exact typed DAGs, assumptions and replayable rewrites that preserve domains.
- [Nonmonotonic scenarios](../native/oracle-logic/DEMOS.md): evidence revisions,
  defaults, alternative actions, diagnosis and explicit repair of inconsistencies.

Sol authors the prototypes; Astra reviews their composition and failure cases.
The next decision is which design earns a narrow execution experiment, not whether
all four should be wired into production. Existing specialist and Mini obligations
above remain in the backlog.

## Measurements and source records

These receipts retain the workloads, source identities and limitations. Tests of
one component do not qualify the whole Engine, appliance or specialist fleet.

| Subject | Record |
| --- | --- |
| Initial graph, algebra and science providers | [Provider evaluation](../native/evidence/2026-10-29-reasoning.json) |
| Incremental dependencies, including the small-workload slowdown | [Batch comparison](../native/evidence/2026-10-29-incremental.json), [rooted comparison](../native/evidence/2026-10-29-rooted-crossover.json) |
| Shared worker memory and capacity | [Pool exercise](../native/evidence/2026-10-29-native-pool.json), [host validation](../native/evidence/2026-10-29-provider-host-validation.json) |
| Exact chemistry | [Validation](../native/evidence/2026-10-29-chemistry-validation.json) |
| Language, DNA and statistical providers | [Validation](../native/evidence/2026-10-29-language-chemistry-domains-validation.json) |
| Shared lexical work and request refusals | [Validation](../native/evidence/2026-10-29-native-performance-validation.json), [paired reader timings](../native/evidence/2026-10-29-native-performance-reader.json) |
| Durable service, retirement and distribution (`7773163`) | [Validation](../native/evidence/2026-10-29-stable-appliance-validation.json) |
| Resident extracted graph checking | [MST receipt](../native/evidence/2026-10-29-resident-mst.json) |
| Exact paths and worker reuse (`951a178`) | [Validation](../native/evidence/2026-10-29-graph-pure-validation.json) |
| Expanded reader and refreshed package (`2fda9fe`) | [Validation](../native/evidence/2026-10-29-segment-reader-validation.json), [failed new cohort](../native/evidence/2026-10-29-targeted-composition.json) |
| Standalone stable-model core (`259d7b9`) | [Validation](../native/evidence/2026-10-29-logic-validation.json), [solver build](../native/evidence/2026-10-29-clingo-build.json) |
| Extracted statistics probability repair | [Geostats binding](../native/evidence/2026-10-29-geostats-binding.json) |

## Upstream

[Discussion 5](https://huggingface.co/psiloceyeben/oracle7-slim/discussions/5)
now includes checkpoint `ab05020`, covering durable hosting, the refreshed
package, reader failures and standalone logic. The implementation remains on
veri7vn's `dev` branch; no native-runtime PR has been opened.
The focused [biology PR 8](https://huggingface.co/psiloceyeben/oracle7-slim/discussions/8)
and [statistics PR 9](https://huggingface.co/psiloceyeben/oracle7-slim/discussions/9)
were open at the latest check.
