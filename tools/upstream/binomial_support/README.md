# Binomial support follow-up for Oracle7 10.3.1

Submitted as [upstream PR #11](https://huggingface.co/psiloceyeben/oracle7-slim/discussions/11).
The PR is open; this is not a merged-release claim.

The patch answers zero when a valid binomial question asks for more successes
than trials. It first admits complete nonnegative integer counts and the existing
safe probability domain. In particular, n=0, k>0, p=1 returns zero without
attempting a negative power. The within-support floating-point formula is
unchanged; no extreme-tail precision improvement is claimed.

Count admission is part of this repair. The previous reader could turn
`-3 trials` into three trials, `3.5 trials` into five trials, and `3e2 trials`
into two trials. It also read a fractional success count's integer prefix.
The new binomial-only token consumes a complete numeric literal, preserves
ordinary terminal commas and outer parentheses, then admits only an integer
atom with value >=0. Internal punctuation and count expressions are not evaluated. Scientific and
fractional count spellings are unsupported and refused, rather than truncated.
Explicit plus signs and negative zero are complete nonnegative integer values.
Probability parsing and combination/permutation readers are unchanged.

`binomial-support.patch` changes the five self-contained statistics source
copies and adds `tests/statistics/test_binomial_support.py`. The v3 class inherits
its binomial behavior from its local v2/v1 copies. `pins.json` binds exact source
and patch hashes to separately fetched slim/full revisions:

- slim: `0ab769781e33ef169b1a3c2a7f055a83c62dca7d`
- full: `9f52489c6c26533258dcafa23ad9f1e7e0dfc37c`

Both pinned trees identify the release as 10.3.1. All 31 fetched full statistics,
math and control files are byte-identical to their slim counterparts. The patch
passes `git apply --check` against each exact selective baseline.

Run the portable tests against a patched source tree without importing its head
or loading models:

```sh
ORACLE7_TEST_ROOT=/absolute/path/to/checkout python3 -B -m unittest discover \
  -s tools/upstream/binomial_support -p test_binomial_support.py -v
```

Once the patch's test is installed under the upstream `tests/statistics/`, it
can also run with the ordinary upstream unittest discovery command. The eight new
methods cover six class entrypoints, including all five source copies and v3
inheritance. Small-problem truth enumerates Bernoulli outcome sequences with
exact rational masses, independently of the organ's coefficient formula.

The scoped panel comparison uses each tree's own shipped statistics scorers:

```sh
python3 -B tools/upstream/binomial_support/check_panels.py \
  --baseline /absolute/path/to/baseline --patched /absolute/path/to/checkout \
  --out /absolute/path/to/panel-results.json
```

On each pinned variant, the baseline fails 1,206 subtests of the new suite,
with no errors; the patch passes all eight methods. Failure breakdown: 1,008
outside-support cases, 15 probability-role cases, 18 complete signed-count
cases, 63 original malformed-count false yes, 30 decorated/expression false yes,
and 72 punctuation cases (including outside-support requests). The punctuation
controls preserve the old valid comma/parenthesis spellings and exercise the
new zero branch; they also admit plain parenthesized integer atoms. Both baseline and patch pass the five
existing probability-binding methods. All 860 shipped panel replies are
unchanged on each variant, with zero wrong and zero false yes. Scorer-correct
counts including correct declines are statistics dev 142/142, heldout 128/142;
statistics-v2 dev 144/144, heldout 130/144; statistics-v3 144/144 on both splits.
These are scoped specialist checks, not a new whole-head or six-criterion
Workbench admission result.

The complete head chain (359 small source modules), the math readers, gate
standing lists/loader and operation dispatcher were inventoried separately.
Math organ v1/v2/v3 has generic arithmetic reading, not this binomial mass
branch; math solver v1/v2/v3 has a separate binomial-coefficient operation.
They are unchanged. The statistics-v3 manifest is on standing_v2. However,
operations102 marks specialists as text and rejects direct invocation; owner
folds also require a reply to vary with every supplied number. An isolated
one-specialist gate probe gives a correct outside-support zero dependence 0/3,
versus 3/3 for the ordinary one-of-two case. This is a component observation,
not a loaded chat run. No chat or direct structured-operation gain is claimed.

Our extracted consumer remains narrower. `GeoStats_Stats.sdecline_of` explicitly
refuses n<k, and `binomial_value` assumes k<=n, n<=10000 and 0<=p<=1. This
upstream Python patch changes no Isabelle, SML, extracted binary or theorem
claim. Supporting zero outside the extracted boundary needs a separately
proved/exported change.

`validation.json` retains final source/patch/test hashes, exact pinned versions,
all scoped test and panel results, and relative log hash references.

Detailed source manifests, raw probes, test logs, panel receipts, head-route
inventory and draft PR body are under the ignored scratch directory
`var/upstream-binomial-support-20261031/`. No upstream working tree was written,
no full head was run, and no external message or PR was published by this lane.
