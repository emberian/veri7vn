# D computing: model boundaries and reference coverage

Owner: Codex computing deputy. **Ready and frozen for integration.** Proof,
exact native compilation, shipped panels and actual dispatcher checks passed.
C is committed as `5cc53be`; its binary `967e1dc818741cc58292973c3c324c8470f72f5bb25012d901edadd97e3e4107`
is captured by the runtime package owner. D edits only the live computing tree.

## Concrete scope

`var/computing-beyond/D-counterexamples-before.json` records the actual C binary:
1. One address bit and three data bits returns zero bytes, truncating six bits.
2. UART 7E1 character throughput is labeled bytes per second.
3. Explicitly nonuniform alphanumeric password entropy gets the uniform formula.
4. Both Python IDs claim that `os.remove` does not exist because their partial
   reference table lacks it.

Repair capacity using rational bytes and an independent finite-address model;
carry UART character/byte units and decline unspecified byte mapping for non-eight
bit frames; decline unsupported entropy distributions; state reference coverage
without inferring runtime absence, and add the useful `os.remove` reference row.
The new row is sourced to CPython v3.12.3, preserving the original 856 rows.

## Per-specialist semantic frontier

| Exact ID | Examined behavior and change | Remaining bounded frontier |
|---|---|---|
| networking | C fixed host-capacity prefix requests and impossible containment context; actual /20 from 4000 devices and /20-inside-/24 refusal replayed. | Natural-language negation/private classification and compound requests remain unproved; other numeric branches have panel and existing kernel coverage only. |
| embedded | D challenges partial-byte memory and non-eight-bit UART units; independent bit-address capacity and explicit character units are the target. Existing CTC rounding bound and UBRR range proof reviewed. | Register hardware behavior, fractional character counts, clock tolerance and unrecognized timer wording remain outside the model. |
| cyber | C repaired plural-password recognition and insufficient entropy precision. D explicit nonuniform/dependent selection must not use uniform entropy or average-guess formula. | Probability-distribution entropy, dictionary models and arbitrary conditional distributions remain unsupported; digest/Base64 branches retain existing proofs and panels. |
| linux-v2 | C actual mode 889 rejection now reaches consumer; mode 775 symbolic conversion examined as correct facts even when question asks denied bits. | Requested complement wording, unusual cron conventions and compound operations remain unexamined beyond panels. |
| git | C restore/save ambiguity, keep-vs-pop and list/cherry-pick morphology fixed with direct probes. | Compound stash-and-delete requests select one intent; command execution and repository transitions remain outside the reference model. |
| sql | C independently characterized canonical DISTINCT classes and grouped COUNT(*) WHERE partitions; 16 whole-result SQLite comparisons passed. | General grouped aggregates, stable tied ORDER BY, binary floating point, unsupported syntax and resource bounds remain open. |
| python | D false runtime-absence claim for missing `os.remove` row; preserve lookup semantics, fix coverage wording and add exact-version sourced row. | Multi-name questions resolve first match; reference is partial, does not execute Python or certify runtime behavior. |
| python-r2 | Same table/kernel as python; independently exercise the same missing-row counterexample and new entry through this exact ID. | Same partial-reference and first-match boundary; no claim of separately implemented semantics. |
| robotics-v2 | C differential-drive three-sentence recognition and opposite wheel ordering checked; 10cm wheel at 60RPM independently gives pi*0.1 m/s. | Slip, dynamics, uncertain units and unexamined kinematic branches retain only their existing formula assumptions and panels. |

## Checks and consumer

D now retains **1364/1364** on the shipped computing panels: zero wrong, zero
false yes, zero valid withheld. All 63 new policy assertions pass directly and
through the actual dispatcher; answerability is counted separately below.


## Implementation and proof

Managed hbox attempt `20261018T080954Z-08345c20899d` failed two proof scripts
in 2m53s: early simplification erased the library cardinality lemma pattern, and
an uninstantiated lookup-completeness fact stalled automatic search. Explicit
rule application and an explicit witness contradiction repair these obligations
without weakening either statement. The retry passed. The checked statements include:

- `8 * emb_value (EAddr n (Some w)) = of_nat (card (bit_addresses n) * w)`,
  where `bit_addresses n` is the set of Boolean lists of length n. No alignment
  premise remains. The locations result similarly equals this cardinality.
- A successful `EUartTp E_byte ...` or `EUartTime E_byte ...` requires `d = 8`.
  The existing rate/time conservation identities now carry an explicit unit.
- `cyb_reply CDistribution` is withheld, kind `underspecified`, with no value.
  This is a model-boundary result, not a probability-distribution entropy proof.
- `py_resolve cs = PyMissing m a` implies there is no row named `m.a` in
  `py_entries`, and `py_reply q cs` is withheld. No Python runtime absence follows.

`tables_check.py` passes all 18 checks, preserving all original rows and checking
857 generated rows against the original data plus the nonshadowing extension.
The exact reference source is
[CPython v3.12.3 os_remove__doc__](https://github.com/python/cpython/blob/v3.12.3/Modules/clinic/posixmodule.c.h#L2812-L2823).
The local 3.12.14 runtime agrees on signature/doc line, but does not supply the
3.12.3 version claim. No removal function was executed.

The untrusted `d_probes.py` uses Boolean-address enumeration and frame-bit lists,
plus explicit reference/distribution expectations. Tuning seed 911029 now has 63
checks, including one *computable* nonuniform distribution (two symbol
probabilities 0.9 and 0.1). Against immutable C, **17/63 policy assertions pass**.
That is not a capability score: among 43 independently classified answerable
requests, C has **17 answered correctly, 16 wrong and 10 valid withheld**. The
remaining 20 are 18 underspecified questions (all incorrectly asserted by C under
this request model) and two unknown-reference names (both withheld). Missing
`os.mkdir` and recorded signatures count as valid unsupported, as does the
explicit computable nonuniform distribution. A future successful refusal will
still count as withheld-valid for those requests. No invalid-query false-yes
metric is inferred from these policy checks. Shipped panels retain their own
scorer definitions. `var/computing-beyond/D-probes-before.json` retains every reply.
Arithmetic evaluation seed 925307 was first run after native compilation froze;
it varies only 15 memory cases, while the fixed semantic cases repeat.

The UART adapter chooses the unit attached to the requested count/rate, rather
than any mention of characters elsewhere. Two mixed-wording probes ask for bytes
while describing seven-bit characters; both must retain the mapping refusal.
These recognizer refinements postdate the proof submission and will be bound by
the native compilation input manifest, not attributed to the immutable proof
snapshot. The four affected capability declarations validate independently.


## Final evidence

- Proof: `var/computing/remote-attempts/20261018T082035Z-967dd249f084/receipt.json`.
  Managed hbox build passed in **1m30s**, exports published, marker
  `VERI7VN_COMPUTING PASS theorems=122 oracles=0`.
  Source digest `688e0afb67e22d79f0ba247ef14c1ec63c81d3c08828b1aefe16b0aca27ecdfd`;
  generated export SHA `035e0b337ce8497379f601dadee869ac9a0e19a538a622c5e06a55f432fb3dbf`.
- Native: `var/computing/native-attempts/20261018T082716Z-c42d8c31b45d/compile-inputs.json`.
  Shared compiler's exact input snapshot passed; current proof dependencies match.
  Binary SHA `2124ffc06475b3772fd2dde3285ff0f643269c4c0f51042e6c87695279e6dc7c`,
  **1,199,384 bytes**, at `var/computing/bin/computing` and the immutable attempt's
  `binary`. This is 368 bytes smaller than C, not a meaningful resource claim.
  Recognizer SHA `1a1f4ced19260232bd1863e0560e87c920d36920befef81349fbf55dd83a086e`;
  commons/main unchanged from C.
- Shipped own scorers: `var/computing-beyond/D-shipped.json`; independent scoped
  parity: `var/computing-beyond/D-parity/`. Both give the table below. The harness
  remains **INCOMPLETE** overall because head/core/LANE/SELF/full-budget inputs
  were not supplied; no all-six-criteria ADMIT is claimed.
- Author semantic checks: `D-probes-tune.json`, `D-probes-eval.json` under
  `var/computing-beyond/`, seeds 911029 and 925307. Each gives **63/63 policy
  assertions**, separately **38 correct answers, 0 wrong, 5 valid withheld**
  among 43 answerable requests; 18 underspecified and two reference-unknown
  requests are withheld. The five remaining valid withheld are `os.mkdir` and
  the absent `sys.set_asyncgen_hooks` signature for both Python IDs, plus the
  computable 0.9/0.1 entropy distribution. They remain capability gaps.
- Actual consumer: `var/computing-beyond/D-composition.json`, **63/63** same
  assertions using the installed binary through `tools/dispatch/dispatch.py`.
  Every reply is taken, decisive, stages `[specs]`; all new deliberate refusals
  survive acceptance. Capability counts match direct execution.
- C regression: `var/computing-beyond/D-C-regression.json`, **40/40**, including
  16 complete-result SQLite differential comparisons. `tables_check.py` passes
  18 checks; `gen_pyref.py --check` passes without writing the table.

| Specialist | Dev right/total | Held-out right/total |
|---|---:|---:|
| networking | 74/74 | 71/71 |
| embedded | 25/25 | 25/25 |
| cyber | 20/20 | 20/20 |
| linux-v2 | 42/42 | 42/42 |
| git | 10/10 | 10/10 |
| sql | 61/61 | 61/61 |
| python | 198/198 | 224/224 |
| python-r2 | 198/198 | 224/224 |
| robotics-v2 | 36/36 | 23/23 |

## Frozen changed files

`src/extract/computing/Computing_Export.thy`, `Numerics.thy`, `Pyref.thy`,
`Pyref_Table.thy`, `README.md`, `capabilities.json`, `gen_pyref.py`,
`recognizer.sml`, `tables_check.py`, new `d_probes.py`, new `pyref_extensions.json`;
and `project/lanes/D-symbolic-computing.md`. No C report, upstream file, shared
runtime source, or captured C artifact was edited. Root owns integration commits.

The running consumer is the computing binary, selected either directly with
`--specialist` or by dispatcher registry. Static capability evidence describes
the model and remains distinct from per-answer proof. No D Linux parity is
claimed yet. The runtime package owner can capture this exact native receipt;
its prior C capture remains immutable.
