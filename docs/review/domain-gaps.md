# Domain specialists: omissions review before implementation

This source audit of pinned Oracle7 `c5d6a29d5bc5e2525078e5a53afa1abf659e4d69` produced DG-01–08. It establishes representation/coverage obligations, not passing native migrations. Use the completed [profile classification](../coverage/classification/domain-profiles.json), [residual map](../coverage/classification/residual-matrix.md) and actual [family scope](../families/domains.md) when implementing.

## Result

Open HOL supports the required domains. Shared consumers need lossless literals, typed results, explicit external-engine boundaries, claim-specific certificates and semantic profiles beyond dimensions. Preserve useful behavior while repairing known defects; matching method signatures do not establish equivalence.

## Reachability and limits of evidence

The workbench catalogue and `_gate/standing_net_v6.txt` list these specialists. Admitted w525 selects that network; `network_v1.py:328–346` loads manifests and `combo_runtime_v1.py:68–84,135–152` invokes the organ. The wrapper drops `value` and retains response prose. These source paths establish potential dispatch, not that every input wins earlier precedence or that optional stores load. The review used manifest/AST inventory and selected source/helper reading, without running upstream code.

## Required corrections

### DG-01 — P1: distinguish literal payloads from language normalization

`dataformats/organ_formats_v1.py:32–74` normalizes whitespace before JSON/hash/encoding. Biology cleans sequences; genetics depends on allele case; relation TV titles use capitalization. Preserve immutable original bytes, declared payload regions and view→source maps. Normalize cues separately. Check repeated-space hashes, multiline JSON positions, case-sensitive genotype and title `You` versus pronoun `you`.

Owners: interpretation/registry/runtime/dialogue; PO-01/04, G02.

### DG-02 — P1: typed results need evidence-bearing shape and completeness

SQL has NULL/blob/REAL and twenty-row prefixes; statistics has absent/single/tied modes; calculus has exact fractions, symbolic parameters and antiderivative constants; robotics has framed vectors; graph/logic need witnesses. Git reference commands are data, not effect requests.

Register native carrier/representation/codec, display projection, shape, dependencies and bounds. Preserve ordering, coverage, parameter binding, NULL versus missing/error and artifact identity. Test these values through plan/host/client consumers, including exact fractions and graph refutations. PO-02/03/04/07; G03.

### DG-03 — P1: externally evaluated languages need an explicit assurance boundary

`sql/organ_sql_v1.py` executes a restricted fresh SQLite connection: authorizer, progress budget, setup, final query, heterogeneous output and truncation. A faithful invocation licenses an engine observation under pinned version/configuration, not general SQL semantics or safe arbitrary host code. A formally supported SQL fragment is a separate stronger service.

Bind original input, target, configuration, actual attempt/result and error/budget scope through the executor. Syntax error, missing table, denial and timeout differ. Apply the same distinction to external toolchain observations. Owned algorithms still need their own native meaning/implementation bridge. C02/C05; PO-03/04/10.

### DG-04 — P1: optimization claims require stronger evidence than a witness

A valid path/tree proves feasibility. Shortest path, MST, complete solution set and impossibility require objective/domain/coverage and stronger checking. Preserve directedness, signed weights, parallel rows, isolates and ties; reject inputs outside an algorithm's contract before executing. EOQ's continuous optimum is distinct from integer stock policy.

Test a nonoptimal valid path, directed input to undirected MST, negative edges, tied optima and bounded search exhaustion. No-found-candidate under a budget is not impossibility. Owners: graphs/math/plans; PO-03/04/06/09.

### DG-05 — P1: “units retained” is not a sufficient semantic profile

Temperature points and differences have different addition laws. dB aggregation uses intensity/reference semantics. Robotics angles need frame/relative-angle convention; calendars need date rules, not fixed seconds. Numeric exactness, approximation/error and normative rounding require explicit relations.

Profiles own native operations and admitted conversions. Reject point+point, dB-as-linear-sum, frame mismatch and decimal-to-exact casts. Shared plans preserve conditions across each conversion. Owners: domains/math/registry/plans/refinement; PO-02/03/07.

### DG-06 — P2: finite probability, statistics and model assumptions need a family

Games convolves exact dice counts and distinguishes replacement; genetics enumerates case-sensitive gametes; statistics distinguishes sample/population and ties. Existing V2 repairs argument roles and invalid probabilities; preserve them. Fairness/independence/finite population are model premises, not measured-world conclusions.

Use exact finite distributions/counts and explicit convention/result types. Test impossible die face, replacement, PMF normalization, invalid k>n, multimodes and changed sample/population denominator. Empirical estimates and heuristic scores remain distinct. Owners: domains/plans; PO-03/04/09.

### DG-07 — P2: conditions from standards and physical models must remain first-class

AQI truncates/interpolates/rounds under versioned tables; Food Code cooling needs both stages; building/occupational rules require supplied conditions; physical formulas assume idealized models. A condition mentioned only in prose cannot constrain composition.

Retain policy/source version, missing inputs, model applicability, rounding and caveats in native results and requirements. Test missing first cooling stage, unsupported averaging period, boundary rounding and integer-versus-continuous policy. Computed policy/model consequences do not become personal advice or universal world assertions. PO-02/03/04/09.

### DG-08 — P2: boundary variants alter recognition, not merely implementation

Inherited `narrow_v1`, `numbers_rule_v1`, `names_narrowing_v1` and formula readers alter valid input domains, role extraction and refusal. Revised versions can repair bugs or block ambiguous multiple rates/phases. Inventory actual override order and source dependencies per manifest. Test positive recognition, domain refusal and dependency failure against each distinct boundary; common arithmetic does not migrate its recognizer. PO-01/04/08; ACC-15.

## Provisional partition of the 119 entries

The original partition is superseded by 81 reviewed profiles covering all 119 manifests, with no unreviewed manifest remainder. Group implementation by shared laws: exact quantities; nonlinear/framed numerics; finite logic/counting/statistics; codecs/calendars; external-language observations; guarded tables/policies; physical models; reference/artifact services. Preserve per-manifest recognition, conventions and unavailable data in the ledger. Classification is complete source accounting, not completed lifting.
