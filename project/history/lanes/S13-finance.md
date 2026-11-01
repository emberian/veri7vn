# Lane S13-finance (2026-10-17/18)

Marker: `VERI7VN_FINANCE PASS theorems=44 oracles=0` (remote build on persvati, log `var/finance/remote-build.log`; 4 earlier local builds failed on proof details, each fixed in one edit, none repeated on the same lemma more than twice). Binary `var/finance/bin/finance`, 644,248 bytes (not committed).

## Panel results (harness, `var/finance/parity/`; right / wrong / valid withheld / false yes)

| Specialist | dev | heldout | shipped heldout |
|---|---|---|---|
| finance-v2-r2 | 64/0/0/0 | 64/0/0/0 | 64/64 |
| finance-v2 | 64/0/0/0 | 64/0/0/0 | 64/64 |
| finance | 65/0/0/0 | 51/0/13/0 | 51/64 (same 13 safe declines) |
| economics | 39/0/0/0 | 26/0/13/0 | 26/39 (same 13 safe declines) |
| retail | 45/0/0/0 | 51/0/0/0 | 51/51 |

Against the shipped organs (`score.py`): 0 disagreements per specialist; the family mode (no `--specialist`) differs from the organs on 16 finance-v1 items only because finance-v2-r2 sits first in the order and answers what v1 declines. Latency p50 per question in binary: economics 0.11 ms, retail 0.09, finance 1.5, finance-v2 13.6, v2-r2 17.8 (budget 50 ms). The finance cost is the 120-bit interval enclosures of exp/ln. Cold start about 270 ms, worse than lane G's 7 ms (not investigated; likely the large table-free Approximation code initialisation).

## Theorems (in `Finance.thy`; read the file for full statements)
kernel_exact_sound, kernel_cents_sound, kernel_approx_sound, kernel_underspecified, kernel_impossible, kernel_refusal, kernel_imprecise, never_even_iff; loan_amortizes (the stated payment drives the balance to 0 after n months), savings_reaches_goal, loan_interest_is_total_minus_principal, apy_compounding, apy_at_least_nominal (Bernoulli), doubling_model ((1+r) powr t = 2), compound_matches_exponential, eoq_model, break_even_equation, margin_markup_relation, price_from_margin_correct, price_from_markup_correct, discounts_compose, multiplier_equation, tax_multiplier_relation, fisher_relation, unemployment_in_range; rounding: round_sig_sound, to_dec_sound, to_dec_at_sound, to_dec_g4_sound, enclose_fmt_sound, quant_sound, round_tie_up, round_frac_eq, compound_frac_props; reply_* theorems. Tables checked by `tables_check.py` (24 checks, PASS).

## Untrusted / limits
Recognizer and reply layout are not proved. Economics and finance-v1 heldout misses are the organs' own safe declines (percentage-cut elasticity, CPI-by-year phrasing, "Employed: X. Unemployed: Y" form), reproduced, not fixed. Cold start and finance-v2 latency worth a look. `by eval` not used.
