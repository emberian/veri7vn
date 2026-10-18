# Life E: requested quantity, future time, and complete dilution tokens

D's committed artifact remains immutable. A root counterexample after D showed
that `-1:100 dilution` was still read as positive `1:100`: D had repaired colony
and volume tokens, while dilution still used the older suffix matcher. E binds
one complete dilution token using the shared exact parser, normalizing bounded
power/colon notation without discarding a sign. A diagnostic preserves valid
ratio, fraction, scientific and power forms and refuses negative, zero-
denominator and malformed ratios; it still passes the prior 43 probes.

Concrete ecology counterexamples are recorded in
`var/life/e-next/ecology-counterexamples.json`. A one-sentence question that
supplies growth rate 0.2 and asks for population after five years returned the
initial derivative 18 instead of population about 231.969. The same future
rate question returned initial rate 18 instead of about 35.631; an exponential
future rate question returned population 271.828 instead of rate 54.366.
Logistic population with zero carrying capacity wrongly answered zero.
Negative N/K examples withheld, so no reachable sign error is claimed from
those examples alone.

E introduces distinct future-rate requests, binds the output target separately
from parameter declarations, and uses the population at the requested time.
The exported real model and interval model agree. New statements connect each
future rate to its population trajectory, establish zero-population equilibrium
and the initial logistic rate, prove the exponential derivative, and bind the
logistic rate enclosure to its domain and error bound. Nonnegative population
and elapsed time and positive carrying capacity are required; signed
exponential rates remain supported. The bounded forward logistic model admits
negative intrinsic rates at or below capacity, while declining them above
capacity, where finite-time divergence can occur.

The first two E proof attempts exposed missing simplifications of local let
bindings and rational casts; both were repaired. Final hbox proof receipt
`20261018T080826Z-5fe6244d97a0` passed 116 scanned theorems with zero oracles.
The final native compiler receipt is
`var/life/native-attempts/20261018T081614Z-14e575ad1e8b/compile-inputs.json`.
It binds the successful theory closure and the actual generated ML, commons,
shared numeric parser, recognizer and main consumed by the compiler. The
numeric dependency remains frozen at `2f313c77fadce09298f0387599e630b04a6551e800f52b6c79a88468b2cc046d`.

The compiled E binary scores 179/179 shipped items in both dispatch modes,
zero wrong, false yes or withheld. Development offsets 10181001 and 10182003
and newly untouched offset 10187017 each score 179/179. All 13 table checks
pass. Five fresh starts were 3.55, 3.39, 2.88, 2.98 and 2.93 ms; median 2.98 ms.
The binary is 788456 bytes with SHA-256
`f67dff8a4da44aa1cad92078ba834d909d7ec4567a20928ed0215386ab6cd4a5`.

Authored evaluation now separates policy assertions from capability. All 80
policy assertions pass, but capability is **73 right, 0 wrong, 0 false yes,
7 withheld-valid**. Those seven requests concern incomplete dominance,
mitochondrial translation, frame 2, two backward-time models, explicit
month/year conversion, and negative-rate logistic population above capacity
at a finite admissible time. They are not solved capabilities. The frozen D
binary on the same questions scored 60 right, 7 wrong, 7 false yes and 6
withheld-valid. The shipped organ scores 27 right, 16 wrong, 17 false yes,
19 withheld-valid and one error. Missing roles or mathematically impossible
inputs are separately classified. These corrections do not alter official
scorer results; historical 43/43 probe claims in C-life describe policy assertions.

Receipts: `var/life/e-next/{shipped-bound,probes-bound,probes-d-baseline}.json`
and `var/life/c-beyond/{e-bound-10181001,e-bound-10182003,e-bound-untouched-10187017}.json`.
Frozen E artifacts and named source hashes are in `var/life/e-delivery/ready.json`.
The runtime consumer gains `logistic_rate_at` and `exp_rate_at` through the
family-owned capabilities sidecar. Ecology mixed-unit conversion, backward
time, negative-rate above-capacity finite trajectories and all other remaining
ledger gaps remain future work.
