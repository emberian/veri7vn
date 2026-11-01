# Binomial probability binding — 29 October 2026

The shipped statistics readers and our running geostats consumer returned
`P(X=1)=0.5` for two trials with `p=0.5%`. The correct probability is `0.005`,
and the correct mass is `0.00995`. Their decimal regex alternative consumed the
number before the percent alternative could consume its suffix. Scientific
notation suffered the same truncation: `p=0.5e-2` became `0.5`.

Root review also exposed newly accepted scientific literals underflowing to
float endpoints. A shared upstream Fraction decoder now checks the exact domain
before float conversion, bounds tokens at 4096 characters and exponent magnitude
at 10000, and refuses nonzero-to-zero or non-one-to-one rounding. Five test
methods cover extreme exponents, long near-boundary decimals, nonzero subnormal
values and actual endpoints. The original floating-point mass formula remains;
no general extreme-tail numerical guarantee is claimed. Our rational consumer
already checks this domain exactly and keeps its existing parser bounds.

The repair consumes the whole signed decimal/scientific literal and its optional
percent suffix, then scales percent by 100. Malformed scalar continuations are
refused. V1 now also applies the existing probability-domain guard. No probability
distribution, estimator, count parser, native regression or inference model was
added. Formula reference: [NIST binomial distribution](https://www.itl.nist.gov/div898/handbook/eda/section3/eda366i.htm).

## Ownership and consumers

Transferred by root: `src/extract/geostats/recognizer.sml`, new
`binomial_binding_probes.json` and `check_binomial_binding.py` in that directory,
and a narrow `README.md` note. The recognizer is hand-written, not generated;
`generate_paired.py` generates only paired-data probes. It binds exact scalar
values to `S_binom`; the existing `s_kernel` validates the domain and evaluates
the binomial mass. No HOL theorem statement changed. The existing binding theorem
requires `k <= n`, `n <= slimit`, `0 <= p`, `p <= 1` and returns exactly
`of_nat (n choose k) * p^k * (1-p)^(n-k)`. This defect is before that boundary.

The upstream draft updates five deployed copies: `organ_stats_v1.py` in
statistics, statistics-v2 and statistics-v3, and `organ_stats_v2.py` in v2/v3.
Each directory remains self-contained. The actual classes are StatsOrgan,
StatsOrganV2 and StatsOrganV3. Scratch is `var/statistics-correctness-20261029/`:
selective immutable `baseline/`, repaired `checkout/`, portable five-method test
suite, `binomial-probability-binding.patch` and `pr-description.md`.

Current Hugging Face main was checked with `git ls-remote` and the 15 source,
panel, manifest and scorer files fetched at
`c473d28914e480425adb29b4f7f42485b8cfb4e3`. Tracked UPSTREAM lane reports had no
statistics repair. Root published [upstream PR #9](https://huggingface.co/psiloceyeben/oracle7-slim/discussions/9)
after review, commit `cdd14607b000fcaff5a3e317ee4c7bd3c6ec42a6`. It is open;
upstream acceptance is not claimed. Publication receipt: `published.json`.
The original `upstream/` remains read-only.

## Upstream checks and exact panel counts

`python3 -B -m unittest discover -s .../checkout/tests/statistics -v`: five
methods pass; the same tests against the exact pinned baseline fail 688
assertions/subtests. Expected masses enumerate every Bernoulli outcome sequence
with exact rational masses, independently of the coefficient formula. Coverage
includes all counts for 0–5 trials, decimal percent/exponent equivalence,
endpoints, signs, probability-role spellings, invalid domains and malformed
continuations. The Python readers and these regressions are untrusted.

All 860 shipped items ran before and after through their own shipped scorers:

| Specialist | Dev scorer-correct | Heldout scorer-correct | Wrong / false yes | Changed replies |
| --- | ---: | ---: | ---: | ---: |
| statistics | 142/142 | 128/142 | 0 / 0 | 0 |
| statistics-v2 | 144/144 | 130/144 | 0 / 0 | 0 |
| statistics-v3 | 144/144 | 144/144 | 0 / 0 | 0 |

Correct totals include the panel's correct declines (two per split in v1,
four per split in v2/v3). Numerically answered correct counts are v1 140/126,
v2 140/126 and v3 140/140; old phrasing misses remain. The regular panels have
no decimal-percent or exponent probability cases. Receipt: `panel-results.json`.
`git apply --check` accepts the upstream patch on the exact selective baseline.

## Our consumer: qualified and promoted

The pre-change warm binary `var/geostats/bin/geostats` passes 77/302 independent
probes in each of family/statistics/statistics-v2/statistics-v3 mode. It scores
142/142, 144/144, 144/144 on both respective shipped splits, zero wrong/false yes.
Receipt: `geostats-baseline.json`.

Central validation compiled the repaired reader against the unchanged checked
export with the managed native compiler. All 302 independent probes passed in
each of four modes (1208 checks); all 860 shipped panel items were scorer-correct,
with zero wrong answers and zero false yes. The compiled source hashes and proof
receipt match; no theorem changed and no Isabelle rebuild was needed.

Root promoted artifact `d02e017b383f54e8fbc69dfde24b990d23ffbdf6ad80688e6142c1b2cb17ad10`
to the registered local consumer `var/geostats/bin/geostats`, preserving the old
binary under `var/geostats/promotions/20261029-binomial-binding/`. Evidence:
`native/evidence/2026-10-29-geostats-binding.json`. Existing packaged appliances
have not been rebuilt by this promotion. The upstream patch is published separately as PR #9; no whole Engine/fleet
qualification is claimed.
