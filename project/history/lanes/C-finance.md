# Finance continuation: interpreting the model and replaying an answer

Owner: Codex natural deputy. The final source passed its scoped Isabelle build:
64 checked statements, zero oracles. The fresh executable preserves all 559
shipped items and all 451 untouched generated items, with zero wrong, false yes
or valid withheld. The 31 new boundary probes improve from 11 right to 31 right.
Composed runtime and relocated-package checks are being collected separately.

## What the running pilot established

A fresh run against the unchanged pilot binary (`var/finance/c-natural/before`)
scored all 559 shipped items correctly in specialist and family modes:
finance 65/64, finance-v2 64/64, finance-v2-r2 64/64, economics 39/39,
retail 45/51 (dev/heldout). Wrong, false yes and withheld-valid were zero.
Cold startup was 3.1–4.1 ms. These are baseline numbers, not results of this change.
The original organs and earlier fresh panels are documented in B-finance.

New boundary probes found real errors outside those templates. Minus signs on
rates were dropped; a fractional number of monthly deposits was rounded; a
125% discount produced a negative price; a request for tax returned final
price. Root independently found that tax explicitly based on original price
was instead charged on the discounted price, and a savings question returned
the amount paid. Those are interpretation/model defects despite perfect panels. On the final
31 boundary probes the pilot gets 11 right, 8 wrong, 11 false yes and one
valid withheld. These
probes are development evidence, authored by the maintainer with two root
contributions; they are not an independent held-out panel.

## Coherent repair

- Read signed annual rates and terms exactly. Negative annual rates can be
  ordinary arithmetic; annuity accumulation now covers them when the monthly
  growth factor is positive. A term must contain an exact whole number of
  months. No rounded deposit count is silently substituted.
- Check nonnegative price/tax and discounts from 0% through 100% in HOL,
  including standalone discounts and sales tax. Standalone savings use the
  same typed model with zero tax.
- Make the retail tax base and requested quantity typed inputs. Compute final
  price, tax amount, or savings compared with full price including tax. The
  original-price tax base is supported when explicit. An ambiguous model or
  missing savings comparison is an explicit taken refusal.
- Apply the completed two-phase reading to all three finance variants.
- Declare supported kinds and boundaries in capabilities.json so dispatch and
  packaging can accept the actual implementation rather than an old manifest.

## Checked proof statements

`annuity_accumulates` is strengthened: a successful exact annuity result implies
positive month count, `of_nat (months y) = 12*y`, and equality to the independently
iterated monthly accumulation. Its unnecessary nonnegative-rate premise is
removed; the domain check requires a positive monthly growth factor.

`disc_val_bounds`: a nonnegative initial price with each discount between 0 and
100 yields a price between zero and the initial price. `discount_bounds` binds
that law to successful standalone-discount output. `discount_tax_bounds`
binds successful kernel output to nonnegative total bounded by the full taxed
price, and to the checked discount domain.

`disc_val_product` connects recursive successive discounts to a product of
factors. `check_discount_tax_iff` says the independently computed product check
passes exactly when the kernel returns that exact discounted-and-taxed value.
`discount_tax_value_checked` connects extraction of the actual kernel result to
that checker. No English parsing correctness is claimed.

For the extended retail request, `retail_tax_components` proves final price is
discounted price plus tax, and savings plus final price equals full price with
tax. Three binding theorems connect successful final-price, tax and savings
kernel results to those quantities and their actual result kinds.

## A usable evidence packet

For the ordinary discounted-price tax route, the driver emits the exact typed
price, list of discount percentages, tax-rate fraction and exact kernel result
as numerator/denominator strings. It invokes the exported HOL checker and
records its decision. The runtime consumer independently checks those fields,
domain, rounding and their binding to the visible answer; inconsistent packets
are refused. The serializer and consumer arithmetic check are untrusted. The
HOL theorem supports the typed calculation under its assumptions; it does not
turn the English interpretation or the whole response into a proof object.

The original-price tax and alternate-target routes have binding theorems but
currently do not emit this replay packet. Their absence is not treated as a
successful replay check.

## Final validation

The successful attempt is
`var/finance/remote-attempts/20261018T065410Z-4eda56aff52b/receipt.json`.
Its full log contains the completed Finance and Finance_Export theories and
`VERI7VN_FINANCE PASS theorems=64 oracles=0`; cancellation is false and the build
completion marker is true. Current HOL sources match its snapshot. After that build, the untrusted
recognizer received a complete signed-decimal token boundary repair; leading-dot
rates such as -.5% are supported and malformed-number tails are not reinterpreted.
The final executable was rebuilt from the same checked export.
The generated SML SHA256 is
`b6fd9f121e7a76064264038bf03e870dec0d11479471d6a7ff9c0017bddcdc30`.
The 737,944-byte macOS executable SHA256 is
`079c948a498522777e71ea59f842cd3f907dd0babef5b1e97bf88ebb19051b4c`.

| Panel | Dev | Held-out | Wrong / false yes / valid withheld |
|---|---:|---:|---|
| finance | 65/65 | 64/64 | 0 / 0 / 0 |
| finance-v2 | 64/64 | 64/64 | 0 / 0 / 0 |
| finance-v2-r2 | 64/64 | 64/64 | 0 / 0 / 0 |
| economics | 39/39 | 39/39 | 0 / 0 / 0 |
| retail | 45/45 | 51/51 | 0 / 0 / 0 |

Both pinned-specialist and family modes achieve these 559/559 results, matching
the old pilot. Development numeric samples with seeds 181071–181076 remain
466/466 for both old and final binaries. After the final numeric-token repair,
the unchanged generators were run into scratch with untouched seeds
184071–184076; no cases were inspected or used to tune source. These score
finance 64/61, finance-v2 64/60, finance-v2-r2 64/60, and economics 39/39
(dev/held-out), all correct: 451/451 for both old and final binaries. Retail
has no numeric generator. The samples retain the generator's original phrasing,
so they are not independent language evaluation. The full six-criteria harness remains INCOMPLETE because
head, core-lane and self comparisons were not measured.

The 31 authored boundary probes score 31 right, zero wrong, zero false yes and
zero valid withheld; the old pilot scores 11 right, 8 wrong, 11 false yes and one valid withheld.
The earlier B-finance probe set remains 26/26 correct. Root's original-price-tax
and taxed-full-price-savings questions now return $155.00 and $64.50. Standalone
125% and negative discounts, negative tax and nonintegral monthly deposit terms
are explicitly declined. The report does not claim arbitrary English parsing
correctness or that all pre-existing loan/savings term conventions changed.

A ten-pair new-process comparison measured median 2.89 ms for the final binary
and 2.99 ms for the pilot. The first invocation immediately after compilation,
while parallel scoring was active, took 89.5 ms; subsequent samples in that
run were 5.9–7.1 ms. Thus the receipt supports a small steady new-process cost,
not a universal first-launch latency bound. Specialist median round-trip times
are 0.14–1.35 ms, below their 50 ms budgets.

Raw receipts: `var/finance/c-natural/shipped-final.json`,
`fresh-final/`, `untouched-before/`, `untouched-final/`,
`probes-before-final31.json`, `probes-after-final.json`,
`pilot-probes-final.json`, and `startup-final.json` under the same directory. No source or generated
corpus was written under upstream. The failed proof attempts were script
failures; no failed export was used in the final executable.

Changed files: Finance.thy, Finance_Export.thy, recognizer.sml, main.sml,
build.sh, capabilities.json and c_probes.py within src/extract/finance, plus
this report. Consumer: `var/finance/bin/finance --specialist ID`, family mode,
and the shared dispatcher using the capability overlay. Runtime/package owner
will provide the actual producer replay and mutation receipts.
