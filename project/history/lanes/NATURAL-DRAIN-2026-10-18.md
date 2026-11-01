# Natural-family drain

All natural-family jobs are terminal and every owner has stopped. Root requested a finite drain before whole-system testing. No new successors are being opened. Already submitted final proof attempts are the last retries: a successful attempt gets one bound native compile and focused gate; a failure gets a durable handoff. Root owns commits and package selection. Existing selected archives have not been changed by this drain.

## Completed and operational

| Family | Latest integrated packet | Receipt / readiness |
|---|---|---|
| Finance | F, `7231021` | `var/finance/f-inventory/live-ready.json` |
| Chemistry | I, `e8e57bb` | `var/chemistry/next-solution-complete/i-live-ready.json` |
| Earth | I, `a2add49` | `var/earth/i-pressure/live-ready.json` |
| Climate | H, `9b1f1be` | `var/climate/h-capture/live-ready.json` |
| Life | I, `64f8383` | `var/life/i-delivery/live-ready.json` |
| Anatomy/agriculture | H, `0b63a6b` | `var/anatomyagri/h-delivery/live-ready.json` |
| Trades | G, `e1e9427` | `var/G-trades/ready.json` |
| Materials | F/G, `82ec579` | `var/G-materials/ready.json` |

Finance is completely stopped. Final native `42bab4146891b057a6ffa019e8b8bffd2d2a8359a95ca7312e2ac0aa835852ed` proves distinct observed/requested turnover periods in the kernel. The 88-root proof has zero oracles; 176 authored policies give 140 right and 36 valid withheld, zero wrong/false yes. All 48 fresh period checks and 14 independent default-dispatch checks pass. Shipped score remains 553/559 with six documented Fisher-model disagreements. Exact capture: `var/C-runtime-package/bound-prepared/20261018T103058Z-7436a228df68/finance`; default receipt: `var/runtime-default/finance-F-final.json`. This capture is next-only, not an implicit replacement of selected delivery.

## Final staged and stopped work

| Packet / owner | Actual state | Durable locator |
|---|---|---|
| Materials G feasibility, materials_trades | Final `259636f0` ready: proof84/0; 161 checks152 right/9 valid withheld/0 wrong or false yes; actual CLI22/22. Held0947 two false accepts repaired. Shipped439/440 (one underdetermined request withheld), fresh455/456 and441/442. No jobs; integrated `82ec579`, captured under `bound-prepared/20261018T104005Z-026703f3bf16/materials`. | `var/G-materials/ready.json` names8 sources plus `project/lanes/G-materials.md`; exact held history retained. |
| Anatomy H portion model, life_anatomy | Final native `9770e1dc` published. Proof77/0; 158 policies give136 right/22 valid withheld/0 wrong or false yes; shipped156/156 and actual staged dispatcher8/8. No jobs; integrated `0b63a6b`, captured under `bound-prepared/20261018T103812Z-8a6d681e7a87/anatomyagri`. | `var/anatomyagri/h-delivery/live-ready.json` (8 named files); `var/anatomyagri/h-next/DRAIN.md`; `project/lanes/H-anatomyagri.md`. |
| Chemistry J reaction amount units, chemistry_parser | Final proof142/0 and bound staged native `1680f709` passed. Shipped1206/1206;342 direct/composed checks334 right/8 valid withheld/0 wrong; prior196 net controls180 right/16 valid withheld. Nine-file stage remains unpromoted, live I unchanged. Stopped. | `var/chemistry/next-reaction-units/j-ready.json`, `ready-files.json` and `RESUME.md`; `project/lanes/J-chemistry.md`. |
| Climate I tiny-area precision, earth_climate | Final `20261018T103226Z-95decb8e8219` failed the remaining width/2 arithmetic tactic at Climate_Num.thy102; no export/native, stopped. First `b2602a7e9ac9` failed three local tactics; accidental main-checkout `b7fc7c5cd6e8` was cancelled before proof and exported nothing. Exact unchanged-statement repair is recorded for later, no retry. | `var/climate/i-small-mass/drain-state.json`; `project/lanes/I-climate.md`. |
| Earth J daily light, earth_climate | Final `f965b2da9238` failed: unavailable `positivity` tactic in Earth_Green.thy228/241. No export, native or retry. Stopped. | `var/earth/j-daily-light/drain-state.json`; `project/lanes/J-earth.md`. |
| Trades H layer/fabric dimensions, materials_trades | Proof `09e44ae53927` passed 51 roots, zero oracles. Reader has not been natively compiled; no live promotion. Stopped. | `var/H-trades/drain-state.json`; `project/lanes/H-trades.md`. |
| Life J diversity, life_anatomy | Counterexamples, model plan and 23 expected probes only; no implementation or proof. Stopped. | `var/anatomyagri/h-next/DRAIN.md` records the cross-family stopping boundary. |

Do not infer native capability from a passed staged proof. Do not consume exports from failed/cancelled attempts, resubmit a still-running job, or overwrite a released predecessor with an unchecked successor. Each owner handoff records its exact resume command and local source state. Snapshot paths and compiler receipts, not report dates, determine the relevant bytes.

Machine state: `var/natural/drain-state.json`. Only genuinely unintegrated final ready packets appear in `var/natural/root-current-ready.json`; historical queues are retained separately. Update this report with terminal outcomes rather than opening additional work.
