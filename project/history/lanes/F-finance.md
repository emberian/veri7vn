# Finance: observed periods, turnover targets and reorder units

Status: final replacement is published and frozen for root integration. The earlier d679 candidate is historical and held; its exact source/report/native evidence remains in `var/finance/f-inventory/d679-snapshot/` and `d679-operational/`.

Weekly cost of goods sold previously used the annual multiplier for inventory days and mislabeled a weekly turnover ratio as annual. The reader now binds the observation period separately from the requested turnover period, retaining both as typed hour/day/week/365-day-year inputs until the proved kernel computes the result. COGS $700 per week and average inventory $100 gives one inventory day, seven turns over the observed week, or 365 annual turns. COGS $3000 over 30 days and average inventory $1000 gives ten inventory days, three turns over that period, or 36.5 annual turns. Reorder points align demand and lead-time units before adding safety stock.

The untrusted reader accounts for every numeric occurrence and refuses competing quantities or multiple targets. It counts overlapping descriptions of the same daily demand token once. Missing safety stock defaults to zero; explicitly unknown safety stock does not. Calendar months, business-day calendars, incompatible packaging, compound rates, changing demand and unsupported requested quantities return typed refusals. Those useful unsupported requests remain withheld-valid, not answered capabilities.

## What is proved

The successful scoped build scans 88 statements with zero oracles. Nine added public laws state:

- Accepted inventory days have positive COGS and observation period, nonnegative average inventory, and satisfy `days * COGS = average_inventory * source_days`.
- Equal observation durations produce identical actual inventory-day kernel outcomes, including guards.
- Accepted reorder points have nonnegative demand, lead time and safety stock, positive demand period, and satisfy `(point - safety_stock) * demand_period_days = demand * lead_time_days`.
- Accepted reorder points are nonnegative.
- A 365-day inventory period has the same actual kernel outcome as the inherited annual inventory request.
- Daily demand and lead-time units have the same actual kernel outcome as the inherited daily reorder request.
- Accepted turnover has nonnegative COGS and positive average inventory, source period and target period, and satisfies `turnover * average_inventory * source_days = COGS * target_days`.
- Accepted turnover is nonnegative.
- Requesting turnover over its positive observed period gives the same actual kernel outcome as the inherited COGS/average-inventory ratio.

The last three laws apply directly to `R_TurnoverPeriod`; period scaling is in the proved kernel, not hidden in the English reader. The reader, numeric role binding, rendering and JSON remain untrusted. Demand is constant during lead time; different currencies and packaging conversions are not modeled. An omitted observation period retains the annual model assumption. An omitted turnover target uses the stated observation period. Replies name both periods explicitly.

## Results

| Evidence | Exact E predecessor | Final F |
|---|---:|---:|
| 88 authored cases, retail + family policy assertions | 38/176 | 176/176 |
| Right observations, including invalid-domain refusals | 46 | 140 |
| Wrong numeric observations | 52 | 0 |
| Invalid requests answered | 6 | 0 |
| Valid requests withheld | 50 | 36 |
| Answered requests without a defensible scalar reference | 22 | 0 |

Per dispatch mode there are 58 correct numeric answers, 12 invalid-domain refusals and 18 valid unsupported requests withheld. Original replies and classifications are retained in `baseline-expanded.json`; final observations are in `native-probes.json`. All 48 fresh exact-rational period/rate questions generated with seed 191347 after selecting the replacement binary pass (`fresh-turnover.json`). The prior d679 set of 32 fresh checks is historical evidence only.

The actual shipped specialist and family scores are both **553/559**, six wrong labels, zero false yes and zero withheld valid. All six labels are the previously documented exact-Fisher-versus-subtraction disagreements; this packet does not change that branch. Retail remains **96/96**. Existing discount-stage policies pass **60/60**, separately 36 right and 24 valid withheld across both modes.

Fourteen actual dispatcher checks pass on both staged and published final bytes, covering inventory days, mixed-unit reorder points, all three turnover examples above, invalid demand, unsupported periods, inherited cashflow and checked discount-with-tax. The binary is 899944 bytes. Five cold starts took 3.93–4.36 ms; shipped retail median round trips were 0.22 ms in specialist mode and 0.34 ms in family mode.

## Exact evidence

All following paths are under `var/finance/f-inventory/` unless stated otherwise.

- Source: `next/`; checked stage: `stage/`; seven named final files and modes: `live-ready.json`.
- Proof: `stage/var/finance/remote-attempts/20261018T101853Z-d87b63082c80/receipt.json`. Actual Finished, exit zero, no cancellation, durable `VERI7VN_FINANCE PASS theorems=88 oracles=0`. Target elapsed 114.798 seconds.
- Final native: `42bab4146891b057a6ffa019e8b8bffd2d2a8359a95ca7312e2ac0aa835852ed`.
- Current compiler manifest: `var/finance/native-attempts/20261018T103058Z-7436a228df68/compile-inputs.json`. It validates the current proof/runtime closure and reproduces the staged binary exactly.
- Evaluations: `baseline-expanded.json`, `native-probes.json`, `shipped.json`, `retail-preservation.json`, `fresh-turnover.json`, `replacement-composed.json`, `live-composed.json`.

The canonical binary, generated code, export and immutable receipt alias are published. Previous operational files and exports are preserved. Source modes are unchanged. Earlier literal/proof-method failures, the cancelled duplicate and the held d679 candidate remain attributable to their own receipts; no failed export was consumed.

## Specialist frontier and drain boundary

`retail` now supports the period and cross-unit calculations above. Calendar schedules, packaging conversions, uncertain demand and general successive-discount list wording remain unsupported. `finance`, `finance-v2` and `finance-v2-r2` retain the prior opening-balance/deposit-timing/loan-target model; the cashflow composition control passes. `economics` retains exact Fisher arithmetic and its six scorer disagreements. No new economics claim is made.

This packet is the Finance stopping boundary for the requested drain. No new successor is running. Root owns final integration and package selection; the previously selected archive is unchanged. Independent default-dispatch/capture receipts may be appended to readiness without rebuilding these exact bytes.
