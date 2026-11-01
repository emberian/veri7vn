# Explicit supplied-model ownership

This fresh qualification tests the actual HTTP `/query` composition: the exact
`Model supplied data: ` prefix selects a bounded modeling owner before the
ordinary language cascade. The host executes the existing typed Rust statistics
provider. Its checked reply is projected once: `reply.result` retains the numerical
payload, provider classification/runtime identity or refusal reason stay intact,
and `modeling_reason` records the conversational result/refusal. Human response
text contains no serialized copy of the payload. Invalid owned input stays with that owner. An absent statistics profile
is an HTTP execution error, not a successful semantic refusal.

This composition differs from the original Workbench's core-first extension.
The spent panel, scorer and negative original verdict remain unchanged. Passing
this qualification would establish neither original gate admission nor a new
shipped specialist-panel score. Central execution receipts remain separate; the native boundary observation is recorded below.

`panel.json` freezes independent inputs and analytic gold. Dev and heldout have
different data and gold; their shared coverage is deliberate. Both contain
forward and algebraic inverse calibrations, nonperfect-line intervals for the
mean and a new observation, binomial and exposure-adjusted Poisson fits, a
full-rank two-parameter binomial fit, and exact separation refusals. They also
exercise malformed JSON, duplicate and unknown fields, unsupported operations,
missing units/assumptions/grouping/exposure, invalid support and byte/row/parameter/
prediction limits. The unit strings are caller labels, never conversions.

The calibration lines are `4+3x` and `7−2x`. Separate four-row nonperfect designs
have centered x values `[-3,-1,1,3]`; residuals are `[1,-1,-1,1]` and
`[-2,2,2,-2]`, perpendicular to both design columns. Their SSE values are 4 and
16, with two residual degrees of freedom. At confidence 0.5 the exact Student t
quantile is `sqrt(2/3)`. At x=0 this gives mean interval radii `1/sqrt(3)` and
`2/sqrt(3)`; a new observation at relative precision 1 gives radii `sqrt(5/3)`
and `2sqrt(5/3)`. No model solver produces these gold values.

Intercept-only binomial probabilities are total successes divided by total
trials, `6/9` and `7/14`. Poisson rates are total counts divided by total
exposure, `12/6` and `15/10`; requested expected counts multiply by the new
exposure. Two distinct predictor rows with their own interior binomial counts
form a saturated two-parameter model: probabilities are `1/4,3/4` and `1/5,3/5`.
All-zero or all-success binomial groups have no finite intercept MLE.
`events_exposure.validate_result` independently replays the host's exact finite
existence or separation witness, binds every supplied field and checks numerical
convergence. Host checked flags alone are insufficient. These Python boundaries
are untrusted software, not theorems.

Standalone exclusion controls check the old organ returns `None` without making
HTTP calls. They are not domain refusals and are never scored as composed
false yeses. Native controls require the native unsupported owner for unprefixed
requests. Prepared Engine controls independently require its own Oracle identity
with self-description provenance and arithmetic mean 7 for rows 4,7,10. They
must answer; standalone abstention is not their gold.

The original six criteria provide useful distinctions, but only within scope:

- DOMAIN: independently correct supplied-model answers are counted; head-relative
  gain remains unmeasured without paired real core evidence. No invented core
  declines or original gain claim.
- FALSEYES: an asserted answer to owned invalid input is a false yes. Correct
  general or identity answers are expected answers, not false yeses.
- FEWWRONG: the runner accepts zero failed numerical, certificate, quantity,
  unit, binding or status checks; its receipt retains wrong asserted replies.
- STAYSLANE: standalone exclusions and exact-prefix native controls are scoped
  checks, not the original 924-question general-panel leakage measurement.
- SELF: separate actual prepared Engine identity controls require core ownership
  and independent identity semantics; they do not merely compare prior prose.
- BUDGET: every request has a finite timeout and a 1 MiB response cap. Individual
  latencies and all HTTP failures are retained; this is not the original mixed
  median-latency criterion. The host's own configured limits must be retained.

The runner sends requests sequentially. Each request is immediately retried with
identical bytes and IDs and must return identical status and bytes. It stores
complete requests/replies. After the central executor restarts its owned host
against the same durable state, `--replay-from` checks the entire successful
receipt verbatim. The runner starts or stops no host and changes no host config.
Use a distinct `--run-id` when changing an input/configuration; IDs are bounded
ASCII identifiers. Expected profile changes use separate hosts or state/tenant.

From repository root, with the final relocated statistics-enabled native-v1 host
on port 8765 (request-byte limit above 70 KiB, reply-byte limit at least 1 MiB):

```sh
python3 -B tools/usage/specialist/modeling/composed/qualify.py --url http://127.0.0.1:8765 --split both --controls native --conversation-request-bytes 65536 --run-id composed-native-v1 --out var/modeling-composed/native.json
```

Restart that same host/state externally, then:

```sh
python3 -B tools/usage/specialist/modeling/composed/qualify.py --url http://127.0.0.1:8765 --conversation-request-bytes 65536 --replay-from var/modeling-composed/native.json --out var/modeling-composed/restarted.json
```

With the real prepared Engine configured in an ordinary query-journal host
(statistics enabled; not readonly-v1), run its independent general/self controls
alongside the new supplied-model panel:

```sh
python3 -B tools/usage/specialist/modeling/composed/qualify.py --url http://127.0.0.1:8766 --split both --controls engine --run-id composed-engine-v1 --out var/modeling-composed/engine.json
```

On a separately configured host lacking statistics, and then on a statistics-
enabled readonly-v1 host, respectively:

```sh
python3 -B tools/usage/specialist/modeling/composed/qualify.py --url http://127.0.0.1:8767 --mode profile-unavailable --run-id composed-no-profile --out var/modeling-composed/no-profile.json
python3 -B tools/usage/specialist/modeling/composed/qualify.py --url http://127.0.0.1:8768 --mode readonly --run-id composed-readonly --out var/modeling-composed/readonly.json
```

The first requires HTTP503 `modeling_profile_unavailable`; the second requires
HTTP200 completed, withheld, `conversation_transition_unsupported`. Neither is a
numeric domain success. Execution failures remain failures; no generic mean or
Python-documentation fallback may answer owned JSON. Preserve exact host binary,
profile, image, deployment and fixture hashes with the central receipt.

## Enclosing request admission

The first native run retained a 51/53 result: both unchanged oversized-byte
fixtures received HTTP413 `conversation_limit` before the modeling owner rather
than the fixtures' expected owner refusal. The native release admits at most
65536 bytes for the entire encoded `/query` envelope, including IDs and text.
The modeling owner's 65536-byte text cap cannot be reached first in that profile.
The original failure receipt remains evidence; no input or numerical gold changed.

`--conversation-request-bytes` must match the actual native release configuration.
Only the known `owned-byte-limit` invalid-input fixtures whose actual UTF-8
encoded request exceeds that declared limit use the enclosing-boundary check.
They must return HTTP413 `conversation_limit`, `state_may_have_changed:false`,
and no answer/result. Other cases still require their original semantic outcome;
an arbitrary HTTP413 cannot pass. The receipt counts these checks separately as
`transport_boundary`; they are not modeling semantic successes. The ordinary host
without this flag still requires the original HTTP200 owner `invalid_input`.

To verify just the unchanged boundary inputs after recording that initial run:

```sh
python3 -B tools/usage/specialist/modeling/composed/qualify.py --url http://127.0.0.1:8765 --conversation-request-bytes 65536 --only-boundaries --run-id composed-native-boundary --out var/modeling-composed/native-boundary.json
```

After restarting the same host/state, reuse the initial receipt's already
acknowledged successful replies without rerunning the mathematical panel:

```sh
python3 -B tools/usage/specialist/modeling/composed/qualify.py --url http://127.0.0.1:8765 --conversation-request-bytes 65536 --replay-acknowledged-only --replay-from var/modeling-composed/native-initial.json --out var/modeling-composed/native-acknowledged-restart.json
```

This mode permits prior failures only when each is precisely a validated known
oversized enclosing-boundary record. It preserves the prior receipt and digest,
excludes those uncommitted errors, and replays only correct HTTP200 completed
acknowledgements. Immediate identical responses for errors may be recomputation;
they never establish durable replay. Restart durable replay claims cover only
the acknowledged completed replies.
