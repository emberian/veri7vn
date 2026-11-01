# Modeling supplied rows

This specialist turns an explicit request into useful conditional fitted values,
calibration points, binomial probabilities or exposure-adjusted Poisson expected
counts. It calls the existing Rust statistics provider through the private HTTP
host. Python parses and checks replies; it never substitutes its own fit.

Questions begin exactly `Model supplied data: ` followed by JSON with
`operation` and `arguments`. Operations are `statistics.calibration` and
`statistics.events_exposure`. The dev and heldout panels contain complete examples.
Unprefixed questions belong to the ordinary Oracle. The specialist makes no
causal, sampling-quality, source-completeness or model-truth claim.

Calibration requires all paired rows, predictor name and units, response units,
assumptions, covariance model, direction, uncertainty choice and query values.
An individual-observation request also requires new-observation relative precision.
GLM requires explicit likelihood family, method, full design and sampling counts,
sampling-unit/grouping declarations, predictor units, assumptions and requested
predictions. Poisson predictions require new exposure; binomial predictions
require trials. Unknown fields are refused. The byte cap is 64 KiB, with at most
256 training rows, 16 GLM parameters and 32 predictions. The existing bounded
exact-cone checker and independent certificate replay are reused. These checks
are untrusted software, not new theorems.

Every returned native result, status, diagnostic and exact certificate is retained,
along with the supplied request and checked client reply. Finite-fit acceptance
requires the existing numerical/certificate contract. Separation and other
nonaccepted native results withhold predictions. Transport or malformed replies
are `execution_failure`, never a successful semantic refusal. Pure calls use the
configured tenant label through the existing normalized host transport; sessions
hold no private modeling state and calls make no durable replay promise.

## Validation commands for the central runner

Central qualification passed all 14 dev and 14 heldout supplied-panel cases,
with zero wrong answers, false yes or execution failures. See the
[receipt](../../../../native/evidence/2026-10-31-coherent-native-validation.json).
The subsequent [prepared-U8 examination](../../../../native/evidence/2026-10-31-native-route-validation.json)
completed all 28 real core baselines and the unchanged original exam. Admission
is **negative**: zero domain gain and two wrong calibration answers per split.
Core-first composition selects generic mean calculations from numbers in the
request JSON, or nonfillable Python-documentation refusals for GLM operation IDs,
before this specialist can supply the requested result. Direct hosted panel
success does not qualify that composition.

The domain panel also contains standalone lane controls whose scorer expects
abstention. Applied to complete core replies, that condition misclassifies valid
identity/arithmetic answers; the raw false-yes totals must not be interpreted as
new errors introduced by this specialist. The [diagnosis](../../../../project/lanes/MODELING-ADMISSION-2026-10-31.md)
keeps these limitations distinct. The heldout exam is spent; future admission
needs explicit route ownership, appropriate composed-control gold and a fresh
independent heldout set. The earlier unprepared-U8 timeout remains retained.
The panel is 14 dev and 14 separately authored heldout cases: five useful numeric
answers, one exact-witness semantic refusal, four invalid-input refusals, and four
out-of-lane controls per split. Gold is analytic: lines 1+2x and 5−2x, aggregate
binomial fractions 1/2 and 2/5, Poisson rates sum(count)/sum(exposure), and boundary
all-zero/all-success likelihoods with no finite intercept MLE. Non-perfect-line mean intervals use the analytic df=1 Cauchy quantile and SSE/(n−2)=6; intercept-only binomial probability intervals use the inverse-logit of the analytic normal Wald endpoints. These are new
specialist cases, separate from shipped statistics controls.

With the final relocated package running on port 8765 and the statistics profile
live, run from repository root:

```sh
python3 -B tools/usage/specialist/modeling/test_contract.py
python3 -B tools/usage/specialist/modeling/run_panel.py --url http://127.0.0.1:8765 --split both
```

This exercises actual Rust hosted calls. The runner exits nonzero on numerical,
refusal, lane or transport failures. Retain stdout and exact package/profile/image
identities with the central receipt. A module panel is not six-criterion admission.

For actual head-relative DOMAIN and FALSEYES, generate exact core questions and
measure them with the admitted real Engine via the existing U8 batch runner:

```sh
python3 -B tools/usage/specialist/modeling/core_cases.py --split dev --out var/modeling-dev-cases.json
python3 -B tools/usage/specialist/modeling/core_cases.py --split heldout --out var/modeling-heldout-cases.json
python3 -B tools/usage/run_batch.py --runtime var/appliance-20261029/candidate-u8 --cases var/modeling-dev-cases.json --out var/modeling-core-dev
python3 -B tools/usage/run_batch.py --runtime var/appliance-20261029/candidate-u8 --cases var/modeling-heldout-cases.json --out var/modeling-core-heldout
python3 -B tools/usage/specialist/modeling/examine.py --dev-evidence var/modeling-core-dev --heldout-evidence var/modeling-core-heldout --out var/modeling-admission --url http://127.0.0.1:8765
```

The examiner copies the original Workbench exam and 924-question general panel to
fresh scratch, copies the specialist/client source closure, and executes the
original six checks. It replays only exact measured core replies, rejects missing
or failed measurements, and uses live hosted Rust calls where core-first
composition permits them. It does not invent core declines. Its copied manifest
records the receiving URL/tenant; heldout is spent once by the original gate.
If the real core batch is unavailable, report DOMAIN/FALSEYES and full admission
as incomplete. General/self lane checks require no live Engine calls. Original
Workbench median timing includes its many fast out-of-lane checks; retain hosted
panel timing separately before claiming useful-call latency.

Keep old statistics comparisons separate: pinned `geostats --specialist {id}`
through `tools.parity.harness` for statistics/statistics-v2/statistics-v3, each
split and six criteria, versus the retained baseline. The family-wide binary's
11 general-question takes versus cap 9 was a recorded NEGATIVE result, not a
new score for this specialist. Historical acoustics/networking fallback false
yeses also need exact current-profile reproduction before being called live bugs.

Nothing writes into `upstream/`, widens existing statistics manifests, installs
Mini payloads or changes extracted SML. Upstream adoption and package catalog
registration belong to root.

Original Workbench `Loaded.reply` preserves response text but drops custom result
fields. The adapter therefore also serializes the complete structured record in
its tagged response. The scorer reads that representation only when its status
matches the outer reply; this retains the unchanged original exam rather than
replacing its wrapper with a more convenient one. Execution failures stay visible
through that projection. Direct consumers retain the ordinary structured fields.
