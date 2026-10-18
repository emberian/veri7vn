# The finance family

Five shipped Oracle7 specialists (`finance`, `finance-v2`, `finance-v2-r2`, `economics`, `retail`) as one verified HOL kernel (`Finance.thy`), exported to SML and compiled with Isabelle's MLton into `var/finance/bin/finance`. Same recipe as lane G (`src/extract/quantity/`).

- Exact rationals: loan payments, savings goals, APY with periodic compounding, simple interest, every economics formula, margins, markups, discounts, tax, break-even, reorder point, turnover. Compound growth with a whole number of periods is rounded to cents from an unreduced exact fraction.
- Through `HOL-Decision_Procs.Approximation` (two builds cap): doubling time (ln), continuous compounding and continuous APY (exp), fractional compounding periods, EOQ (sqrt).
- Untrusted: `regex.sml`, `recognizer.sml` (hand port of the organs' regexes and narrowing), `main.sml`, reply layout (`show_fmt`, checked by the self test).
- Check: `python3 src/extract/finance/tables_check.py`. Build: `tools/dev/remote-build persvati src/extract/finance Veri7vn_Finance --expect 'VERI7VN_FINANCE PASS'`, then copy the exported `finance.ML` to `var/finance/build/finance_generated.sml` and run mlton as `build.sh` does. Score: `python3 src/extract/finance/score.py` and `tools/parity/harness.py`.

Results and statements: `project/lanes/S13-finance.md`.
