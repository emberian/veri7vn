# Lane S14-trades: architecture, printing, printing-v2, safety, woodworking, crafts (handoff, 2026-10-17)

Six Oracle7 specialists are one verified HOL kernel over typed trade requests, exported to
Standard ML and compiled with the MLton inside Isabelle into one 811 KB binary
(`var/trades/bin/trades`, not committed). Files: `src/extract/trades/`
([README](../../src/extract/trades/README.md)).

## Result on the shipped panels (right / wrong / valid withheld / false yes)

| Specialist | Split | n | Binary | Shipped held-out | p50 in binary vs 50 ms |
|---|---|---|---|---|---|
| architecture | dev / heldout | 10 / 10 | 10/0/0/0, **10/0/0/0** | 10/10, 0 fy | 0.10 ms |
| printing | dev / heldout | 39 / 36 | 39/0/0/0, **30/0/6/0** | 30/36, 0 fy | 0.12 ms |
| printing-v2 | dev / heldout | 36 / 37 | 36/0/0/0, **37/0/0/0** | 36/37, 1 fy | 0.14 ms |
| safety | dev / heldout | 44 / 45 | 44/0/0/0, **45/0/0/0** | 45/45, 0 fy | 0.38 ms |
| woodworking | dev / heldout | 36 / 36 | 36/0/0/0, **33/0/3/0** | 33/36, 0 fy | 0.06 ms |
| crafts | dev / heldout | 14 / 14 | 14/0/0/0, **14/0/0/0** | 14/14, 0 fy | 0.06 ms |

0 wrong and 0 false yes everywhere. Named misses are the shipped organs' own misses, and the
organ comparison in `score.py` shows 0 disagreements in per-manifest mode:
- printing (6 withheld): "A part 180 mm high is printed with 0.2 mm layers. What is the layer count?"
  and five like it (v1 does not read "printed" as a print cue; printing-v2 fixes exactly these).
- woodworking (3 withheld): "Board footage of one 1" x 12" plank 10 feet long?", the 2" x 4" x 12 feet and
  4" x 4" x 8 feet planks (the organ's board-foot pattern needs the "board feet" cue).
Family mode (no argument) uses printing-v2 for printing wording, so printing's 6 are answered there (36/36).
The harness (`tools/parity/harness.py`, no head answerer, so INCOMPLETE) agrees: its printing row is the family order.
Binary 811,272 bytes, cold start 3.9 to 8.7 ms, p50 round trip 0.1 to 0.4 ms against a 50 ms budget.
Harness verdicts: `var/trades/parity/`.

## Check-native receipt

`python3 tools/dev/check-native --session Veri7vn_Trades --session-root src/extract/trades --expect 'VERI7VN_TRADES PASS' --timeout 1800`
status `passed`; marker `VERI7VN_TRADES PASS theorems=28 oracles=0`. Receipt
`var/native-scaffold/sessions/dc7636e45d87515b/receipt.json`. Sessions: `Veri7vn_Trades_Base` and `Veri7vn_Trades`.
Table check: `python3 src/extract/trades/tables_check.py` PASS (77 checks).

## Theorem statements (from `Trades.thy`)

```
kernel_exact_sound:  kernel r = Exact k q ==> missing r = None /\ ~impossible r /\ k = kind_of r /\ spec_exact r q
kernel_duo_sound:    kernel r = Duo k x y ==> missing r = None /\ ~impossible r /\
                     ((EX a b. r = ActualSize a b /\ actual a = Some x /\ actual b = Some y /\ k = K_actual_size)
                      \/ (EX w h b. r = Mat w h b /\ x = w + 2*b /\ y = h + 2*b /\ k = K_mat_outer))
kernel_hue_sound:    kernel r = Hue k c ==> missing r = None /\ ~impossible r /\ (the mix_ryb / mix_rgb / comp_of case of r gives c)
kernel_approx_sound: kernel r = Approx k d ==> missing r = None /\ ~impossible r /\ k = kind_of r /\
                     |dec_val d - phys r| <= |phys r| / 1000 + 1 / 1000
kernel_underspecified: kernel r = Decline (Underspecified w) <-> missing r = Some w
kernel_impossible:   (EX why. kernel r = Decline (Impossible why)) <-> missing r = None /\ impossible r
kernel_judgement:    kernel r = Decline Judgement <-> missing r = None /\ ~impossible r /\ is_judge r
kernel_imprecise:    kernel r = Decline Imprecise ==> missing r = None /\ ~impossible r /\ ~is_judge r
expr_of_meaning:     ~impossible r ==> interpret_floatarith (expr_of r) [] = phys r
round_he_spec, ceil_eps_cover, floor_eps_fit, to_fixed_sound, enclose_m_sound, stated_dec_sound, round_tie_up
rafter_pythagoras:   phys (Rafter x rv u)^2 = rv^2 + (rv * x/12)^2
pitch_tan:           tan (pi/180 * phys (Pitch x)) = x/12
noise_halving:       phys (NoiseTime (l+5)) * 2 = phys (NoiseTime l)
egress_widths:       egress_per True = 3/10 /\ egress_per False = 1/5
```
`spec_exact r q` is the defining equation per kind: e.g. FAR: `0 < lot /\ q * lot = floor area`; occupant load:
`least_cover (area / factor) q` (the least whole number not below x - 1e-9); NIOSH RWL `q = 23 HM VM DM AM FM CM`;
lifting index `q * RWL = load`; shrink scale `(1 - p/100) * q = 1`; moisture `q * dry = (wet - dry) * 100`;
cast-on `spec_he (gauge * width) q` (nearest, an exact tie to even, as Python round); quilt blocks
`most_fit` across times down. Declines: missing input, impossible (zero lot or factor, shrinkage not in [0,100),
non-positive layer, spool or diameter, openings at least the area, frame under 3 sides, dry above wet, nominal size
outside PS 20, a colour pair the wheel does not mix), and the safety judgement.

## Untrusted and limits
- `regex.sml`, `recognizer.sml` (hand port of the organs' regexes and narrow_v1, numbers rule for printing-v2), `main.sml`.
- Reply text layout (`render_dec`, comma grouping) is checked by the self test and the panels, not proved.
- Exact decimal ties round up (`round_tie_up`); the organs round binary floats, so a tie can differ in the last digit.
- The family kernel enclosure uses a 1/1000 relative-plus-absolute bound (`kernel_approx_sound`), looser than lane G's.
- Lemma notes: `answer_exact_spec` took many builds because of simp loops, now proved case by case; no lemma deferred.
- `self_test` is not exported to SML (it ran 170 ms at start-up); the build runs it in Isabelle.

## Reproduce
See the README build block. Scoring: `PYTHONDONTWRITEBYTECODE=1 python3 -B src/extract/trades/score.py`;
harness: `python3 tools/parity/harness.py --answerer var/trades/bin/trades --specialist architecture,printing-v2,printing,safety,woodworking,crafts --split both --out var/trades/parity`.
