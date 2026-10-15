# Domain specialists: omissions review before implementation

Review date: 2026-10-15. Pinned upstream:
`c5d6a29d5bc5e2525078e5a53afa1abf659e4d69`.

This was a read-only source review. No upstream runtime imports, specialist
execution, proof builds or additional downloads were performed. Manifest/AST
inventory covered the 119 previously unclassified manifest entries; selected
high-pressure implementations and their inherited helpers were read in detail.
This is a design-pressure audit, **not** completed behavioral classification,
proof coverage or an end-to-end replay of every specialist.

## Result

The native/open-HOL direction can accommodate these capabilities. The current
contracts leave several choices too implicit for safe parallel implementation:
lossless payload handling, structured results and completeness, semantic profiles
beyond dimensions, optimality evidence, finite probability models, and observation
of external language engines. These need concrete shared contracts and owned
acceptance cases before runtime, compiler and family lanes choose representations
independently. None requires a closed universal datatype of all values.

## Reachability and limits of evidence

These are not merely dormant research files:

- `upstream/workbench/data/specialists.json` lists algorithms, SQL, dataformats,
  games-v3, genetics-v2, logic-v3, calculus, coldchain-v2, airquality, git,
  additive-v2 and robotics-v2 as admitted. That is the release's metadata claim,
  not a new validation of its exams.
- `upstream/root/specialists/_gate/standing_net_v6.txt:1` contains these families.
  The pinned `HEAD_MANIFEST.json` contains `oracle_release_runtime_w525`;
  `.../admitted/oracle_release_runtime_w525.py:39–44,68–76` selects that standing
  file and constructs the network. These are static call-path links; later
  routing/precedence can still determine whether a particular question reaches it.
- `upstream/root/specialists/_gate/network_v1.py:328–346` resolves a standing ID
  to its manifest and `_Organ.reply`.
  `upstream/root/specialists/_gate/combo_runtime_v1.py:68–84,135–152` loads the
  named class, invokes its `answer`, applies manifest kind/decline rules, and
  **drops its `value` field**, retaining response prose. This explains why
  preserving a nominal `value` interface would still lose existing semantics.

All paths below start at `upstream/root/specialists/` unless written in full.
Line references describe inspected source, not executed results. Suggested test
inputs are design counterexamples/proposed regressions, not newly reproduced
runtime failures. Relation-family execution also retains the previously recorded
missing-store limitation.

## Required corrections

### DG-01 — P1: distinguish literal payloads from language normalization

**Evidence.** `dataformats/organ_formats_v1.py:32–49` collapses whitespace before
extracting JSON; `:51–74` extracts and hashes/encodes text from that normalized
string. The requested SHA-256 of a quoted string containing two spaces is a
different operation after those spaces become one. JSON error line/column values
also refer to transformed text. `biology/organ_biology_v1.py:27–28,46–53` transforms
sequence syntax, while `genetics-v2/organ_genetics_v1.py:21–41,117–136` depends on allele
case. `rel-tvseries-v2/organ_relation_v2g.py:19–26` treats capitalization as evidence
for title versus pronoun resolution. A universal lowercase/whitespace pass is not
meaning-preserving across these inputs.

**Gap.** C03 says text has spans and codecs, but does not specify whether original
bytes/codepoints survive normalization, how normalized spans map back, or where
literal payloads are protected. A global normalizer chosen now could make exact
hash/format operations impossible to recover later.

**Change.** Define immutable original input plus explicit derived views and span
maps. Payload codecs declare encoding, normalization, case and escaping policies.
Natural-language cues can normalize separately from quoted code/data. Structure
must record which view was interpreted. Add lossless text/byte payload and Unicode
round-trip checks to interpretation-model, runtime-service and routing-dialogue;
connect them to PO-01/PO-04. Repair the demonstrated source pattern deliberately
rather than preserve whitespace corruption for apparent compatibility.

**Refuting cases.** Quoted two-space versus one-space hash inputs; multiline JSON
error positions; case-sensitive genotype; title `You` versus pronoun `you`.

### DG-02 — P1: typed results need evidence-bearing shape and completeness

**Evidence.**

- `sql/organ_sql_v1.py:31–39,95–121`: NULL, strings, floats and byte blobs; scalar
  versus row collections; empty results; at most twenty displayed rows; an
  additional row proves there are more. The returned list omits the `more` flag
  and the response alone says “at least”.
- `statistics/organ_stats_v1.py:77–81`: mode returns `None`, one scalar or a list.
  `None` means no unique mode, not a runtime exception or unavailable value.
- `calculus/organ_calculus_v1.py:111–137`: exact fractions become floats for
  numeric `value`; symbolic derivatives are strings; an antiderivative's `+ C`
  appears only in the response while `value` stores one representative polynomial.
- `robotics-v2/organ_robotics_v1.py:68–90`: forward kinematics returns `[x,y]`,
  while units, relative-angle convention and frame information remain in prose.
- `algorithms/organ_algorithms_v1.py:82–89`: shortest-path witness is prose while
  `value` retains only cost. `logic-v3/organ_logic_v2.py:56–62` similarly puts a
  refuting assignment in prose while retaining only a Boolean.
- `git/organ_git_v1.py:2–4,11–44,60–62`: commands are returned as reference text,
  explicitly never executed. A command-shaped result is not an effect request.

**Gap.** A generic “structured claim/result” is architecturally sound but does not
yet constrain client codecs, materialization, pagination, checked witnesses or
partial result handling. Different lanes could serialize every object as display
text or scalar/list and reproduce precisely the loss we intend to fix.

**Change.** Establish an extensible native value/claim codec registration contract:
native type and representation relation, lossless serialization where supported,
display projection, shape/dimension metadata, evidence dependencies, and supported
materialization bounds. Each family owns its native algebraic types; the common
contract must not prescribe a closed value universe. Keep completeness/order,
schema and NULL distinct from exception/missingness. A truncated rowset can license
a partial-result/lower-bound claim; it cannot masquerade as all results. Code
artifacts remain data until a separate explicit execution transition.

**Tasks/checks.** Add a shared representation/codec work package consumed by
plan-composition, runtime-service, workspace-client and family migrations.
Acceptance must include SQL rows with NULL/blob, a truncated ordered result, a
multimode, an exact rational, symbolic expression with parameters, a framed
vector and a witness-bearing graph/logic result. Link PO-02/03/04/07. No generated
file format should pretend to serialize native proof authority.

### DG-03 — P1: externally evaluated languages need an explicit assurance boundary

**Evidence.** `sql/organ_sql_v1.py:21–54` creates an in-memory SQLite connection,
configures an authorizer/limits/progress handler; `:67–83` uses `EXPLAIN` to judge
SQL validity; `:94–121` executes user-provided setup/query and reports SQLite's
actual result/error. This is richer than the internal relational lookup language:
SQLite coercion, NULL, bags/order, functions and recursive `WITH` may matter.
`dataformats/organ_formats_v1.py:43–49` judges validity with Python's JSON parser,
not a separately specified strict JSON grammar.

**Gap.** Native refined computation and source reports are covered in general,
but no decision says how a specialist whose *intended question* is “what does
engine X do with this program?” fits C02–C04. Neither silently trusting SQLite
as a proof oracle nor declaring all such behavior unimplementable is appropriate.

**Change.** Distinguish:

1. A supported formal language fragment with modeled semantics, checked/refined
   execution and stated limits.
2. A version/configuration-pinned **observation of an engine invocation**, with
   exact input/setup, output or error, resource/isolation conditions and an
   explicit external boundary. Its claim is about that observed run, not a
   theorem about all SQL semantics.

Decide how the latter is licensed as a source/observer capability under existing
assurance profiles or an explicitly revised profile. The observer implementation
still needs a genuine contract/bridge. “It called Python” is not a completed
semantic lift. Do not make proving all of SQLite an immediate prerequisite.
An engine error may be an accepted result *about a rejected program*, distinct
from veri7vn failing to run its own task. Pin actual backend behavior and preserve
the release's honest “run in SQLite” scope.

**Tasks/checks.** Add external-language observation under source-semantics,
state-effects and domain-family decomposition. Test syntax error versus missing
table, budget stop versus invalidity, NULL/row order, and forbidden side effects.
Inventory optional backend dependencies in deployment-builder; connect PO-03/04/10.

### DG-04 — P1: optimization claims require stronger evidence than a witness

**Evidence.** `algorithms/organ_algorithms_v1.py:61–111` runs Dijkstra and Kruskal,
claiming shortest path or minimum spanning-tree weight; it also makes unreachable
and disconnected claims. A feasible path/tree does not prove minimality, and no
found path is not a proof of unreachable. Graph edge direction is explicit in
`_graph` at `:38–46`, but the MST loop ignores direction at `:103`. The regex at
`:17` only admits unsigned weights while `:70` tries to reject negative weights;
parser domain correctness must be linked to algorithm preconditions.
`retail/organ_retail_v1.py:67–76` also returns a closed-form EOQ optimum under an
implicit cost model; continuous optimum and feasible integer order count differ.

**Gap.** Current graph-family emphasizes source relation paths, and generic
witness soundness does not force an optimality/completeness claim distinction.
This capability could be misplaced under “graph reachability” or a numeric formula.

**Change.** Define claim-specific obligations for feasible result, optimum with
bound/certificate, complete enumeration and impossibility. Optimization can use
proved algorithms or compact checked certificates; do not require every optimizer
to be trusted. Graph representation must fix directedness, parallel edges,
isolated vertices, weights and tie behavior. Keep cost, solution/witness and
bound separate. Domain-family/graph-family work should explicitly own this finite
algorithm/optimization family, with PO-03/04/06/07 consumers.

**Refuting cases.** A nonoptimal valid path; directed edges submitted as an MST;
unreachable target; equal optima; negative-edge parse rejection; EOQ continuous
solution versus integer candidate policy. These are proposed tests, not new
runtime reproductions.

### DG-05 — P1: “units retained” is not a sufficient semantic profile

| Existing pressure | Exact source evidence | Required distinction |
|---|---|---|
| Affine temperature | `units-v3-r2/organ_units_v1.py:49–54,78–86`; network `Q.temp_point` at `_gate/network_v1.py:105–109` | Temperature point versus difference; affine conversion versus multiplicative scale; admissible operations and absolute-zero domain |
| Exact rational conversion | `units-v2/organ_units_v2.py:19–41,44–50,85–90` | Exact factor/value versus display approximation; a float-matching heuristic is not exact provenance |
| Logarithmic level | `acoustics/organ_acoustics_v1.py:76–102` | dB level/reference, intensity ratio and level difference; adding two levels is not scalar addition |
| Angles and frames | `robotics-v2/organ_robotics_v1.py:68–90`; `organ_robotics_v2.py:68–77` | Degrees/radians, relative joint angles, frame and orientation, signed angular velocity, vector output; angle cannot be silently any dimensionless real |
| Tuning convention | `music-v2/organ_music_v1.py:113–118,223–226` | Cents are logarithmic pitch interval; frequency depends on tuning reference and temperament |
| Time versus calendar | `units-v3-r2/organ_units_v1.py:30–31`; `dataformats/organ_formats_v1.py:99–106`; `linux-v2/organ_linux_v1.py:125–143` | Fixed 86400-second day versus calendar date/weekday versus cron field combinatorics; no implied time-zone/DST-aware scheduler |
| Normative rounding | `airquality/organ_airquality_v1.py:20–28,36–65` | Truncate concentration, interpolate specified breakpoint table, then round half-up; this is algorithmic meaning, not generic display rounding |

**Change.** Before selecting quantity/plan signatures, define extensible semantic
profiles with native carrier, representation, allowed operations/conversions,
reference/convention/model parameters, exact/approximate/error contracts and
serialization. A shared SI exponent vector can be one component, not the full
type. Tie permitted numeric optimization to the profile. Add these cases to
plan-composition, domain-families, staged-execution and PO-02/03/07 acceptance.

A bounded search of `organ*.py` did not locate substantive complex-number
operations; the core math reviewer should establish complex branch requirements
from the actual core. This is not evidence that Oracle7 lacks them.

### DG-06 — P2: finite probability, statistics and model assumptions need a family

**Evidence.** `games-v3/organ_games_v1.py:35–43,97–121,123–143` computes exact
finite counts/convolution and replacement-dependent probabilities, then `:65–66`
casts the rational to a float in `value`. `genetics-v2/organ_genetics_v1.py:21–41`
enumerates gamete products into a rational probability mass function;
`:133–161` returns scalar probabilities or ordered ratio text.
`statistics/organ_stats_v1.py:47–52,77–93` covers binomial probabilities,
multimodality and sample versus population estimators.
`logic-v3/organ_logic_v2.py:27–31,56–62` distinguishes finite exhaustive truth
tables from one counterexample assignment.

**Gap.** Treating these as ordinary arithmetic loses the sample space/model,
independence/replacement assumptions, estimator convention, multiplicity and
normalization obligations. Treating confidence or observed examples as proof
would be an even larger mistake. These implementations are deterministic model
calculations, not evidence of a general probabilistic inference engine.

**Change.** Own finite-distribution/counting/statistical profiles explicitly.
Define model assumptions and mapping from observations to the chosen estimator;
preserve rational PMFs/counts where used; separate probability, empirical estimate,
heuristic score and formal consequence. Support checked countermodels and complete
finite decision procedures as distinct evidence kinds. Pin cost bounds to actual
state spaces, not just input character count: dice count is capped but sides and
integer sizes still affect work; truth-table cost is exponential in variables.

**Tasks/checks.** A domain-family subtask for these profiles plus PO-03/04/06/10.
Test replacement changes, exact probability normalization, degenerate sample size,
multiple modes, invalid versus contingent formulas, and budget exhaustion that
does not become impossibility. No requirement to ship general Bayesian inference
or randomized solvers follows from this source review.

### DG-07 — P2: conditions from standards and physical models must remain first-class

**Evidence.** `coldchain-v2/organ_coldchain_v1.py:2–12,46–62` evaluates numbers
against cited 2022 Food Code clauses. The total-cooling branch returns Boolean
`ok` for a six-hour total while text separately says the first stage must take
at most two hours. That Boolean is not a proof of compliance with every condition,
and the organ explicitly does not judge a food safe to eat. `airquality/...:22–28,
118–132` carries table edition, averaging periods and truncation policy.
`additive-v2/organ_additive_v1.py:115–133` applies mesh Euler formulas assuming a
closed triangular mesh and a genus, rather than checking an actual mesh topology.

**Gap.** General “source dependencies and domain conditions” is directionally
correct but does not settle the common result a policy/model evaluator exposes:
which rule was applied, which predicates were observed/proved/assumed, and what
remains unknown. A bare pass/fail or scalar can overclaim before rendering begins.

**Change.** Use scoped model/policy evaluation records: versioned rule/source,
applicability, supplied observations, assumptions, checked obligations, unresolved
obligations and licensed conclusion. This is not a mandate for a new universal
deontic logic. Require finite policy/physical-model cases in source-semantics,
domain-families, diagnostics-repair and PO-01/03/04/09. A successful partial rule
check cannot be rendered or composed as complete compliance or physical truth.

### DG-08 — P2: boundary variants alter recognition, not merely implementation

**Evidence.** `medicine-r2/organ_medicine_r2.py:9–18` suppresses animal-only
questions before delegating to FactsOrgan. `rel-tvseries-v2/organ_relation_v2g.py:
11–26` reconstructs the subject by regex over rendered answer text, then suppresses
pronoun/deictic readings. `rel-novels/organ_relation_v2.py:32–55` chooses handwritten
versus mined readers, catches store errors as silence, and renders subject/property
IDs into the response. `additive-v2/organ_additive_v2.py:29–43` replaces specific
parent readers, while retaining other parent computations.

**Change.** A shared implementation class does not establish semantic equivalence
among manifests or versions. Migration needs a per-entry mapping of recognition
ownership, applicability/decline and accepted operation kinds. Put entity/role
identity and guard evidence before rendering; do not duplicate response parsing.
Store failure must become dependency failure rather than silently opening a weaker
fallback. C03 already points in this direction; add these concrete regressions to
interpretation-model, routing-dialogue and coverage-disposition so its actual
consumer contract is determined before readers are bulk migrated.

## Provisional partition of the 119 entries

This disjoint inventory partition identifies where to split the large domain
task. It is based on declared operations, AST structure and the source reads
above. Entries can need several semantic profiles; categories are not proofs of
uniform behavior. Existing `needs-semantic-classification` statuses have **not**
been replaced with completed classifications.

| Pressure group | Count | Manifest IDs |
|---|---:|---|
| Symbolic/discrete algorithms | 3 | algorithms, calculus, logic-v3 |
| Probability/statistics/population models | 7 | ecology, games-v3, genetics-v2, statistics, statistics-v2, statistics-v3, wildlife |
| Codecs, executable syntax and structured reference | 9 | biology, dataformats, git, library, linux-v2, networking, python, python-r2, sql |
| Linguistic and named-reference tables | 6 | anatomy, anatomy-r2, government, grammar, mythology, ushistory |
| Standards, classifications and conventions | 13 | airquality, architecture, coldchain, coldchain-v2, crafts, music-v2, music-v2-r2, nutrition-label-v2, safety, soil, soil-r2, wiring, woodworking |
| Quantity/geometry/optimization profiles | 11 | acoustics, additive-v2, electrical, materials-v2, orbits, retail, robotics-v2, units, units-v2, units-v3, units-v3-r2 |
| Source-table plus quantity computations | 18 | astronomy, astronomy-v2, astronomy-v3, astronomy-v3-r2, bodies-v2, chemistry, chemistry-v3, cooking, cooking-v2, cooking-v3, cooking-v3-r2, densities, densities-r2, fuels, geography, labsolutions, labsolutions-r2, planetary |
| Other numerical/model families, still requiring detailed classification | 52 | agriculture-v2, carboncapture, carbonmat, climate, cyber, decay, economics, electronics, electronics-r2, embedded, energy-v2, energy-v3, finance, finance-v2, finance-v2-r2, fleet, fluids, fluids-r2, forestry, gardening, geology, geometry, geometry-v3, geometry-v4, greenhouse, greenhouse-r2, hvac, hydrology, iot, mechanisms, mechanisms-v2, meteorology, microbiology-v2, ocean, optics, optics-v2, optics-v3, optics-v5, optics-v5-r2, physics, physics-r2, physics-r3, printing, printing-v2, renewables, seismology, spacecomms, spacecraft, sports, thermo, water, water-r3 |

Counts sum to 119. The 161 RelationOrgan variants, 22 FactsOrgan variants, two
stateful site manifests and springs remain separately accounted for by the
existing coverage ledger. This review does not add sibling-product migration
scope or require a generic CAS, full SQL verification, general probabilistic
inference, CAD kernel or timezone scheduler merely because a small fragment is
present. It requires preserving those fragments' actual semantics and giving the
platform a sound way to grow beyond them.
