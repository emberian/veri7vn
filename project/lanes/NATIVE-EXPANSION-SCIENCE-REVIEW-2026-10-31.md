# Thermal dynamics and coding translation source review — 31 October 2026

Review owner: Astra science review lane. This is a source review of the shared
phase-two tree following first-wave commit `64dcd1e`. No builds, tests, live host
calls, panels or commits were run by this lane. The central validation lane owns
execution. There are no shipped-panel numbers and no completion claim here.

## What was examined

- `native/oracle-science/src/thermal_transient.rs`, its contract tests and example;
  the science library dispatch/catalog, Python adapter, Rust pure-host
  interpretation, thermal client, analytic scorer and manufactured consumer tests.
- `native/oracle-bio/src/translation.rs`, its contract tests and prepared example;
  library dispatch/catalog, Python adapter, Rust pure-host interpretation,
  translation client, specialist, scorer and manufactured consumer tests.

No theorem is added or claimed. These are handwritten floating-point and literal
sequence computations with explicit untrusted status.

## Mathematical and semantic reading

The transient free-node equation is `(C + h L) theta_new = C theta_old + h q +
h boundary`, with offsets relative to the supplied reference temperature. Fixed
nodes retain their prescribed temperature. Positive capacities make the exact
real matrix positive definite even for an ungrounded component. Numerical
Cholesky failure is refused. The accepted path comprises two backward-Euler
halfsteps; the full step is only the local difference estimate. Original-node
storage, applied energy, reservoir heat and outgoing edge heat use the accepted
absolute temperatures. Equal/opposite link contributions are accumulated with
compensated sums. The source correctly does not claim rigorous global error,
physical truth, measured reservoir capacity or certified event absence.

The factor cache is local, bounded to eight entries and keyed by exact step-size
bits; graph and capacities stay immutable during a call. The local work estimate
accounts for full-step insertion evicting the half-step factor. Cooperative checks
surround the foreign factorization, which is not internally interruptible.

Translation uses the 64-entry ordinary standard-code assignment, not an initiation
row. Reverse coordinates use `[end-hi,end-lo)` and reverse-complement each
original base. Frame skips the oriented 5-prime end. Source identity retains the
original case and ordered labels, while computation normalizes ASCII case.
Ambiguous codons always become X under `unknown`, including unanimous amino-acid
or stop expansions; `reject` covers the whole supplied source. Remainder admission
precedes stop handling. Trailing geometry may overlap the stop-policy untranslated
suffix, which is explicitly documented. `complete` is policy completion, not a
claim that every source base became protein. No core table, coordinate or policy
error was identified in this reading.

## Findings sent to owners

1. **Thermal request identity not verified by consumer (repaired; source rechecked).**
   `tools/usage/thermal_transient.py` only tests the `sha256:` prefix. A reply from
   a different conductance/integration model with the same nodes and sample
   schedule can pass the consumer. Bind a reproducible identity to the supplied
   request. The repair uses sorted typed-default-filled objects, length-prefixed
   UTF-8/container encoding and binary64 numeric bits; Rust and Python implement
   `thermal-canonical-binary64-v1`. Parameter/policy mutation tests are authored.
2. **Thermal public aggregate energy unchecked (repaired; source rechecked).** The consumer recomputed
   balances from nodes, then returns the native aggregate energy fields without
   verifying them. Its manufactured accepted fixture even omits all aggregate
   fields. Missing or fabricated storage, applied, reservoir, residual and
   internal-cancellation aggregates must be checked against the independent node
   totals before being passed onward. The repair requires every aggregate finite
   and compares it with independently recomputed totals; mutation tests are authored.
3. **Thermal event interpolant unchecked (repaired; source rechecked).** The consumer checked that the
   event estimate lies in its bracket and that endpoint temperatures straddle the
   threshold, but does not recompute the claimed linear interpolation. A different
   time anywhere inside the bracket passed. The repair recomputes interpolation
   with a 1e-12 scaled tolerance and authors a wrong-time mutation test.
4. **Typed thermal admission allocates before bounds (repaired; source rechecked).** `run` serialized
   the whole typed input to a Vec before checking request bytes or structural/text
   caps and before acquiring its shared memory reservation. Oversized direct Rust
   inputs therefore cause extra unbounded serialization/allocation before refusal.
   HTTP ingress caps mitigate the host route, not the public typed/context API.
   The repair preflights all shapes/text, reserves before serialization and uses
   a capped writer. Text length is checked before trimming, so oversized whitespace
   also refuses before an unbounded scan. The allowance conservatively includes
   four times the configured byte ceiling. Oversized/tiny-ledger tests are authored.
5. **Translation client coordinate types (repaired; source rechecked).** The workflow consumer compared
   nested Python dictionaries with `==`, so booleans and integral floats can stand
   in for integer coordinates/ordinals. The Python native adapter already adds
   explicit integer-type checks; the workflow consumer should preserve the same
   contract and test substitutions. It now explicitly checks every coordinate,
   ordinal and omission interval with `type(x) is int`; bool/float mutation cases
   are authored. No test run is claimed here.
6. **Translation negative scorer conflates outages (repaired; source rechecked).** Invalid gold counted
   any non-answer as correct, while the specialist turns OSError/HTTPError into a
   withheld input reply. An outage can therefore earn negative-case credit.
   The specialist now classifies locally checked input refusals as `invalid_input`
   and host/contract failures as `execution_failure`; only the former earn
   negative-case credit. The runner counts execution failures separately, and a
   manufactured outage test is authored. No test run is claimed here.
7. **Pure-host translation seam (repaired in source during review).** The initial
   tree dispatched translation but interpreted it as alignment, necessarily
   withholding valid results. The latest source adds its own original-coordinate
   codon replay with independently grouped assignments, source/request identities,
   omission maps and charged work. Execution remains for central validation.
8. **Thermal integral check uses unrelated energy scale (repaired; source rechecked).** The consumer's
   comparison of applied heat with the supplied schedule uses a tolerance also
   scaled by outgoing and reservoir heat. In two fixed reservoirs exchanging
   about 1e20 J, an expected 1 J applied input can be replaced by 2 J without
   failing the roughly 1e13 J tolerance. Use the accumulated absolute supplied
   segment energies for the applied-integral tolerance; preserve the broader
   scale for the balance itself. The repair independently sums source segment
   products and uses their own absolute-energy sum for source tolerance; storage
   equality uses storage magnitude and the capacity/temperature rounding floor.
   Aggregate comparisons use each quantity's own node totals. A two-reservoir,
   1e20 J exchange / 1 J source mutation case is authored; execution is pending.

## Remaining limits

The thermal consumer independently checks accounting; this does not independently
solve arbitrary dynamics or verify link integrals from sparse output samples.
The analytic panel provides separate truth for its selected manufactured models.
Translation has structural size bounds and WorkControl charging, but no shared
MemoryBudget-owned prepared source/result API. Its documented bounds explicitly
exclude allocator metadata, caller-owned inputs and process RSS.

All eight concrete findings above are repaired and source-rechecked. Focused
regression tests have been authored by the implementation lanes; this reviewer
has not executed them. Phase-two central validation, including live cross-language
identity agreement and consumer panels, remains required. The current central
first-wave runner explicitly excludes these phase-two edits. This report owns
no implementation paths and changes only this report file.

## Follow-up: thermal scenarios typed admission

The thermal author requested a source-only review of root-authorized phase-two
repairs to `thermal_scenarios.rs` and its tests. The sealed first-wave snapshot
is unaffected. The new preflight caps network/scenario/sensitivity counts, vectors
and strings before copying or serializing; string length precedes trimming.
Serialization first counts bytes through a capped nonallocating writer under
the original configured ceiling, then reserves the actual encoding allowance
before allocating a second capped writer's buffer. This preserves small valid
requests under a small ledger. Focused regressions are authored for malformed
typed inputs, tiny ledgers, escaped-text byte caps and actual-sized reservations.
These changes address the earlier admission-ordering gap by source inspection.

One additional retained-result accounting finding was repaired and source-rechecked:
the batch result allowance charged input bytes once, while each scenario's `ThermalResult` clones
the full description and assumptions (and its link/node evidence). With one fixed
node, 64 scenarios, 32 assumptions of 1024 bytes and a 1024-byte description,
returned declaration text alone is about 2.16 MB; the current guard formula is
only about 0.3 MB. The prepared-network guard drops before the batch result is
returned. The repair now charges the actual repeated description/assumptions
payload and slots, link endpoint strings and link-evidence structures for every
scenario, with bounded node/sensitivity allowances. A 64-scenario long-declaration
regression checks the live reservation after the prepared owner drops. No
execution occurred. This follow-up has no remaining source finding; focused
phase-two execution remains with the central runner.
