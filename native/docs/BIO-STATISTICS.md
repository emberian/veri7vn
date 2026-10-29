# Supplied DNA and statistical models

These optional providers compute on arguments supplied in the request. They
do not query a genome, establish biological significance, prove a theorem, or
establish that a statistical assumption holds. They have no specialist panel
scores yet and are not admitted Mini capabilities.

The Python extension enables them with the Cargo features `bio` and
`statistics`. Neither is enabled by default. A default extension has no
`bio_call`, `bio_catalog`, `statistics_call` or `statistics_catalog` export.
Calling a missing export directly fails; configuring a profile whose exports
are absent makes standalone-service startup fail. No placeholder operation is
advertised as callable.

The host chooses the extension file and verifies its SHA-256. It also chooses
the allowed profiles, worker count and process limits. A request cannot choose
an extension, path, profile, tenant authority or executable. The private
loopback service still requires its trusted bridge to set the tenant header;
that header is routing information, not authentication.

An operator configuration for one extension containing both features is:

```json
{
  "schema": 1,
  "port": 7071,
  "limits": {"workers": 2},
  "providers": [
    {"id": "dna", "profile": "bio", "extension": "/operator/oracle_native.so", "sha256": "REPLACE_WITH_ACTUAL_LOWERCASE_SHA256"},
    {"id": "regression", "profile": "statistics", "extension": "/operator/oracle_native.so", "sha256": "REPLACE_WITH_ACTUAL_LOWERCASE_SHA256"}
  ]
}
```

Run `python3 tools/appliance/native_service.py --config /operator/native.json`.
The platform's actual extension suffix may differ. Use the same actual hash in
both rows. All configured profiles share one global pool. Rows with the same
artifact hash reuse one immutable snapshot, and a resident worker for those
bytes serves both profiles. Adding a provider does not create a separate pool
or load public data. There is no retained conversation or durable replay;
reusing a request ID computes again.

The service exposes `GET /operations`, `GET /operations/{operation_id}` and
`POST /invoke`. Each invocation has `request_id`, `conversation_id`,
`operation_id` and `arguments`. The first two IDs correlate requests; neither
provides authority or makes a computation durable.

## Align supplied DNA

`bio.align_pairwise` accepts the following `arguments`:

```json
{
  "query": "ACGT",
  "reference": "TTACGTAA",
  "mode": "query_global",
  "scoring": {"match_score": 2, "mismatch_score": -1, "gap_open": -3, "gap_extend": -1},
  "ambiguity": "reject"
}
```

`global` consumes both sequences. `local` chooses a best local path, which can
be empty with score zero. `query_global` consumes the whole query and allows
free clipping at the reference ends. Scores are integers: match is 1 through
1000, mismatch is -1000 through 0, and
`-1000 <= gap_open <= gap_extend <= -1`. A gap run of length k scores
`gap_open + (k-1)*gap_extend`.

DNA is case insensitive. Whitespace, FASTA, U and literal gaps are rejected.
Ambiguous DNA letters are rejected by default. With `always_mismatch`, IUPAC
ambiguity letters are accepted but every non-ACGT comparison is a mismatch,
including N compared with N. This is not a probability model.

Before alignment allocation, native admission checks the mode, scoring,
ambiguity, sequence lengths, DP cells and estimated working memory. Current
caps are 256 KiB of native request JSON, 4096 bases per sequence, 1,048,576
DP cells per pass and a 16 MiB working-memory estimate. The cell cap applies
to `(query_length+1)*(reference_length+1)`, so not every pair of individually
admitted sequence lengths fits. The estimate is not a process RSS limit.

The result includes one candidate path, its score and coordinates, edit
counts, an independently replayed score and an independently recomputed
optimal score. Coordinates are zero-based half-open in the supplied forward
orientation. An insertion consumes query; a deletion consumes reference.
Other equally scoring paths may exist. The adapter withholds a malformed
reply or disagreement among the candidate and checked scores. No strand
search, homology judgment, variant interpretation, clinical conclusion or
sequence design is available.

## Fit a supplied linear model

The operation ID is `statistics.linear_regression`, and its worker profile is
`statistics`. For example, the following `arguments` fit a common mean:

```json
{
  "features": [[], [], []],
  "response": [1, 2, 3],
  "intercept": true,
  "covariance": "classical_normal_errors",
  "model": {
    "description": "Supplied common mean",
    "predictor_names": [],
    "predictor_units": [],
    "response_unit": "1",
    "assumptions": ["Independent Gaussian observations with common mean and variance"]
  }
}
```

Each feature row represents one observation. `intercept=true` adds a constant;
do not include that constant in the feature rows. Positive optional
`relative_precisions` are fixed loss weights. Predictor names, units,
description and at least one assumption are required caller declarations;
the provider does not verify them. Defaults are confidence level 0.95 and
relative numerical-rank cutoff 1e-12. Confidence may range from 0.5 through
0.999 and the rank cutoff from machine epsilon through 0.01.

`classical_normal_errors` supplies Student-t inference conditional on the
declared linear mean, independent Gaussian errors, fixed design and weights
proportional to inverse conditional error variance. `hc3_asymptotic` uses HC3
covariance on the transformed weighted rows and asymptotic normal Wald tails.
It does not promise finite-sample coverage, or handle clustered or time-series
dependence. Neither method establishes causation. Intervals are pointwise for
a prespecified model, without selection or multiplicity adjustment.

The complete native result is retained inside the adapter's `result` field:

| Native outcome | Adapter classification | Meaning |
| --- | --- | --- |
| `fit_with_conditional_inference` | `numerical_fit_with_conditional_inference` | A fit and inference conditional on the listed assumptions. |
| `fit_without_inference` | `numerical_fit_without_inference` | A full-rank fit, with `inference=null` and explicit reasons. |
| `rank_deficient_fit` | `numerical_unidentifiable_fit` | A rank-truncated minimum-norm candidate in supplied coordinates; parameters are not identifiable. |

All three are answered computations. An answered fit does not imply available
inference. Missing residual degrees of freedom, roundoff-scale residuals,
poor conditioning and the native inference policies can withhold inference.
Rank-deficient prediction estimability is not tested; fitted means are absent
in that case. Diagnostics include original-row residuals, rank, leverage and
influence measures. Influence diagnostics are not outlier probabilities.

Optional `predictions` contain feature rows. Conditional mean intervals use
the chosen covariance method when inference is available. Individual future
observation intervals require classical covariance and an explicit
`observation_relative_precision` on the same scale as the training weights.
HC3 does not estimate future observation noise and refuses this option.
Extrapolation and covariate shift are not assessed.

Current caps are 1 MiB of native request JSON, 512 observations, 64 parameters
including any intercept, 128 prediction rows, a work estimate `n*p*p` of
2,097,152 and 32 MiB of SVD scratch. Computation uses one thread. The native
catalog and operation descriptor report the limits used by this build. The
whole HTTP-envelope byte limit can admit less than the native request cap.

## Refusals and validation

Structural invalid arguments are HTTP 400 before dispatch. Native admission
errors become an HTTP 200 completed envelope whose reply has
`status=withheld`, `reason=native_request_refused` and
`authority=computation_only`. Invalid native results are withheld separately.
Pool saturation and process failures follow the existing native-service error
protocol. Unknown operations return 404. No unsupported domain capability is
silently substituted.

Direct PyO3 callers pass JSON to `bio_call` or `statistics_call` and receive
JSON strings; refusals raise `ValueError`. These calls release the Python GIL.
Their cancellation flag is local and false; standalone hosting supplies wall
deadlines and cancellation by supervising the shared worker. Rust-Bio
alignment, SVD and distribution quantile calls are not interruptible inside
the library. Process resource limits are not a filesystem/network sandbox;
Darwin does not provide the Linux address-space limit used by this worker.

The central validator owns execution. The focused suites authored for this
integration are `tools/oracle_components/test_native_bio.py`,
`tools/oracle_components/test_native_statistics.py`,
`tests/appliance/test_native_domain_service.py` and
`native/tests/test_python_domains.py`. Set `ORACLE_NATIVE_TEST_EXTENSION` to
the combined extension for the actual HTTP and snapshot/worker reuse tests.
The PyO3 suite requires both features; setting
`ORACLE_NATIVE_EXPECT_DOMAINS=absent` instead checks their absence in a default
build. These checks use supplied analytic examples and negative cases. They
are not specialist panel scores or formal proofs.
