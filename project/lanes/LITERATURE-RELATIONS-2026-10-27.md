# Relations literature, 27 October 2026

Owner: Sol relation literature. No new specialist panels ran. There are **no new
panel numbers or runtime improvements** from this lane. The historical relations
score in `docs/parity/relations.md` is 16,284 right / 0 wrong / 2,692 withheld of
18,976; this experiment does not revalidate it or change it.

Seven useful primary PDFs are saved under
[/Users/ember/paperbin/oracle7-20261027/relations/](/Users/ember/paperbin/oracle7-20261027/relations/README.md).
An existing provenance paper was reused. The [manifest](/Users/ember/paperbin/oracle7-20261027/relations/manifest.json)
records titles, authors, publication/preprint years, source URLs, byte sizes,
SHA-256 hashes, discovery paths, reading depth and why each is useful. Selected
full-text sections were read; no paper is represented as read cover to cover.

Both requested search systems were used. Five Kagi queries covered completeness,
negative knowledge, identity, abstention and cardinality. Five Scry queries used
literal LIMIT 5–15 and the existing client's 10 million nanodollar raw-work cap.
Four succeeded; the broad negative-knowledge query hit its exposure guard and
the narrower follow-up returned zero rows. Targeted arXiv lookup verified the
completeness survey, Predicting Completeness and Selective QA, plus a related
paper. The raw queries, schema and responses are saved in the paper directory's
`search/`. No credential was written into the artifacts, command arguments or
logs. Discovery results were checked against primary PDFs and author/publisher
pages before use.

## What the literature changes about the design

The first action should be to represent unknown eligibility explicitly, then
connect the existing snapshot-relative theorems to honest consumer claims.
Completeness heuristics are useful for choosing what evidence to acquire next.
They cannot discharge completeness premises for the verified answer path.

### 1. Preserve unknown alternatives during uniqueness decisions

**Source:** [Darari et al., Completeness Statements (2013)](https://www.inf.unibz.it/~nutt/Publications/13-iswc.pdf),
definitions 1, 3–5 (PDF pp. 6–8). Their available graph is contained in an ideal
graph; a completeness statement identifies a region where they coincide. This
gives a precise basis for local closure rather than whole-database closure.

**Code:** `src/extract/relations/request/Relation_Request.thy:subject_matches`,
`src/extract/relations/identity/Relation_Identity.thy:identity_pool` and
`inverse_identity_choice`, plus `tools/relations/scoped_fetch.py:exact_rows`.
Currently absent P21/P106 evidence can make an alternative fail the requested
predicate. An unbounded scan does not make the missing assertion false.

**Proposed statement:** Let `Models(E,C)` be worlds extending truthful positive
evidence `E`, respecting explicit negative evidence and scoped closure premises
`C`. If a covered candidate universe has exactly one definitely eligible ID `s`
and all other IDs are definitely ineligible, then for every `W` in
`Models(E,C)`, `{u | eligible(W,u)} = {s}`. If any alternative's eligibility is
unknown, refuse the unique-identity claim. Conjunction should propagate unknown
unless a conjunct is definitely false. Conflicting signed evidence refuses.

**Test:** The isolated experiment below checks the rule against every finite
completion, and replays Terra's missing-gender counterexample against the native
binary. Add the same completion tests to each requested-kind consumer when
integrating this representation.

**Expected improvement and cost:** Prevent unsupported unique answers; supply
specific missing predicates for follow-up. More answers will be qualified or
withheld until explicit exclusions or local coverage are available. A separate
snapshot-only claim can remain useful if it carries that limitation.

### 2. Carry scoped coverage and evidence through the consumer

**Sources:** [Razniewski et al., survey, arXiv v2 (2023)](https://arxiv.org/abs/2305.05403v2),
§§2.4 and 7.1; existing [Green, Karvounarakis and Tannen, Provenance Semirings (2007)](https://doi.org/10.1145/1265530.1265535),
introduction. Completeness and cardinality assertions have query scopes and may
have temporal validity. Positive provenance composes witnesses through query
operations; that alone does not supply an absence or coverage witness.

**Code:** `tools/relations/fetch.py` currently sets `complete`/`dom_complete` for
its scans. `Relation_Reader.thy:snapshot_complete_wrt` and
`identity/Relation_Identity.thy:inverse_snapshot_complete` already express more
precise external premises. The appliance's `title_route_v1.py` and composer
consumers also need to preserve missing-date uncertainty and statement scope.

**Proposed statement:** For a named immutable snapshot `S`, fetch coverage gives
`fetched_ids = query(S)` for the specified property, targets, filters and time.
A world-level conclusion additionally requires `query(S) = query(W)` for the
claimed world/time. Neither a snapshot hash nor a non-truncated SQL scan proves
the second equality. Coverage of a composed query requires coverage of its
eligibility predicates, not just its relation edge.

**Concrete representation/test:** Attach source revision, statement IDs,
canonical IDs, query/target set, row-limit status, coverage scope and time to the
answer receipt. Keep scan coverage, classification closure, name-candidate
coverage and world coverage separate. Reject stale/wrong-property/wrong-target
certificates. Test that a snapshot-only witness yields a visibly qualified
snapshot statement, while absence of world coverage blocks a current unique
claim. Date precision, territory and edition scope must survive composition.

**Expected improvement and cost:** Makes existing conditional proofs useful to
callers without overstating them. Adds a small receipt type and propagation work;
avoid introducing a full provenance algebra before a consumer needs one.

### 3. Decide identity before projecting display labels

**Source:** [Hoffart et al., Robust Disambiguation (2011)](https://aclanthology.org/D11-1072/),
§§1.1–1.2. AIDA combines popularity, local context and collective coherence.
Its discussion shows how short or mixed-topic inputs can mislead context or
coherence. This supports better ranking, not a uniqueness certificate.

**Code:** `tools/relations/fetch.py` resolves entity values to labels. The
`Relation_Reader.thy` snapshot section already warns that singleton projected
labels need not imply singleton identities. The P86 composer consumer has the
same boundary. Inverse identity code already retains QIDs and provides a useful
pattern.

**Proposed statement/test:** Require agreement of canonical object ID sets before
display projection. Distinct `Q1` and `Q2` with the same label must not satisfy
identity agreement. Add two fixtures with equal labels/distinct IDs and with
distinct aliases/the same ID; the first is ambiguous, the second one identity.
Use context/popularity to order clarification options or evidence acquisition,
while retaining all unexcluded candidates for the decision.

**Expected improvement and cost:** Closes label-collision false agreement and
makes clarification useful. It may withhold previously agreed text and require
the fetch/export representation to retain both entity ID and label. No neural
linker is necessary for this repair.

### 4. Use independent count evidence to detect gaps and justify closure

**Source:** [Mirza et al., Enriching Knowledge Bases with Counting Quantifiers (2018)](https://arxiv.org/abs/1807.03656),
§§1–3 and §6.2. A count can be recorded without naming all objects. Ordinals
often support a lower bound rather than an exact total. CINEX's reported
precision, including roughly 60% average extraction precision, makes unreviewed
extractions unsuitable as exact premises.

**Code:** Extend a future relation-evidence sidecar next to `scoped_fetch.py`;
do not overload `complete` with an inferred row count. Start with the absent
properties/coverage needs classified by `docs/parity/relations.md`, choosing a
small useful predicate with an explicit, source-backed total.

**Proposed statement:** For a fixed predicate, subject, time and identity scope,
let `K` be distinct truthful named objects and `R` all real objects. Then
`K ⊆ R` implies `|K| ≤ |R|`; an independently warranted exact total `n`, together
with `|K| = n`, implies `K = R`. A witnessed total larger than `|K|` establishes
missing objects. An ordinal lower bound never establishes exact closure.

**Test:** Fixtures for 2 named objects/exact total 3 (gap), 3 distinct objects/total
3 (closure), duplicate IDs (no extra count), total below known distinct objects
(conflict), and an ordinal “third” followed by four known objects (consistent
lower bound). Preserve temporal/source scope in every case.

**Expected improvement and cost:** Enables honest counts and useful gap detection
before collecting every name. Requires a small manually warranted count corpus
or source-template extraction; automatic CINEX-style output should remain an
acquisition candidate until verified.

### 5. Measure selective utility under the failures users actually bring

**Sources:** [Kamath, Jia and Liang, Selective QA (2020)](https://aclanthology.org/2020.acl-main.503/),
§§3.1, 4.3, 5.1–5.3; [Galárraga et al., Predicting Completeness (2017; preprint 2016)](https://arxiv.org/abs/1612.05786),
§§3–4; [Arnaout et al., Wikinegata (2021)](https://www.vldb.org/pvldb/vol14/p2807-arnaout.pdf),
introduction/approach. Selective QA evaluates error against answered fraction
and shows confidence can fail under domain shift. Completeness prediction and
peer-derived negatives are empirically useful heuristics with assumptions.

**Code/test:** Keep the shipped specialist scores as the completion metric, and
add a separately labelled development diagnostic over real usage failures:
missing classification, equal-label identities, fourth-candidate disagreement,
unknown release year, expired coverage, missing property, and unsupported
paraphrase. Report right/wrong/withheld alongside risk among answered questions
and useful snapshot-qualified answers. Do not consume held-out tests to tune
the recognizer. A hard evidence gate always wins over a high confidence score.

**Proposed operational invariant:** Statistical scores may schedule a lookup or
rank a clarification. They cannot change UNKNOWN to FALSE/TRUE or fabricate a
coverage premise. Compare a proposed recognizer/linker on both shipped panels
and this shifted diagnostic before broadening its acceptance.

**Expected improvement and cost:** Finds false certainty hidden by template
success, and helps prioritize missing evidence by user value. Adds a maintained
development corpus; learned calibration is optional and should wait until there
is enough labelled usage data. The paper's neural-QA thresholds are not Oracle7
thresholds.

## Bounded experiment and exact result

Changed repository files:

- `tools/usage/relation-literature/possible_identity.py`
- `tools/usage/relation-literature/test_possible_identity.py`
- `tools/usage/relation-literature/README.md`
- this lane report

The model uses TRUE/FALSE/UNKNOWN and a stated universe-coverage premise. It
does not infer closure from SQL, constrain gender/occupation to single values,
or treat distinct IDs as equal because labels coincide. Explicit contradictory
signed facts refuse.

Command run:

```sh
python3 -B tools/usage/relation-literature/test_possible_identity.py
```

Exact result: **8 tests passed in 0.801 seconds**, including enumeration of
**1,093 three-valued assignments over 0–6 candidate IDs** and every two-valued
completion of their unknown facts. The model's returned ID equals the unique
singleton shared by all finite completions, if such a singleton exists.

The existing native binary, SHA-256
`bdacf372cae82d237e3cba0f3d5b95746f40d84c4d8a5fa7fb2a438653170c38`,
returned subject 102 when subject 103 lacked the requested P21 value. Adding that
value, consistently with the original positive evidence, returned `ambiguous`
with IDs 102 and 103. The proposed rule withheld in both states. The fixture is
reused from `tools/usage/relation-audit-semantics/test_semantics.py` so it remains
connected to the semantic review's actual native consumer.

No theorem was changed, proved or refuted by this lane. The statements above
are proposed obligations. In particular, existing snapshot theorems retain
their explicit premises; this experiment shows why a real-world interpretation
needs stronger premises. Finite enumeration does not prove the unbounded HOL
statement or validate a real linker/store.

## Remaining work and consumers

Root owns prioritization and integration. The next runtime change should be the
three-valued eligibility representation plus a consumer-visible snapshot scope,
coordinated with `terra_relations_semantics` and `terra_relations_consumers`.
Those lanes received the experiment and source recommendations. Their current
review reports are `RELATIONS-SEMANTICS-2026-10-27.md` and the consumer lane's
report; this lane does not edit their files or common runtime paths.

Before claiming completion, root must decide the intended answer scope, integrate
it through the actual relation/title consumers, run their focused regressions,
and obtain fresh shipped panel numbers. A future Isabelle statement needs the
truth/closure and candidate-universe assumptions made explicit; it must use the
designated scoped build lock. No build was needed or run for this research.
