# Lane W6-24 trades and wordprob: laws in place of restatements

Families: `src/extract/trades/` (Veri7vn_Trades) and `src/extract/wordprob/`
(Veri7vn_Wordprob). Branch dev, unsigned commit, not pushed.

## What changed

Trades gained four theorems (three the audit asked for, one splitting an
honest exception out of the involution). Wordprob lost its six vacuous
`*_value` theorems (each was `x / y * y = x` in another spelling) and gained
ten binding ones tied to other schemas, to the table, or to the decline rule.

### Trades (`Trades.thy`, section "Laws of the colour and lumber tables")

    theorem mix_symmetric: "mix_ryb a b = mix_ryb b a & mix_rgb a b = mix_rgb b a"
    theorem complement_involution: "x ~= C_violet ==> comp_of (comp_of x) = x"
    theorem complement_violet_exception: "comp_of (comp_of C_violet) = C_purple & C_purple ~= C_violet"
    theorem actual_below_nominal: "actual n = Some x ==> 0 < x & x < of_nat n"

Finding: the audit's `comp_of (comp_of x) = x` is false for violet. The
organ's table sends violet to yellow and yellow to purple. The kernel keeps
the organ's table (changing it would change replies); the two theorems state
exactly where the law holds and where it does not.

### Wordprob (`Wordprob.thy`, replacing the six vacuous theorems)

    lemma scale_pos: "0 < scale u"        (and scale_nz: "scale u ~= 0"; helpers)
    theorem convert_roundtrip: "wvalue (Convert (wvalue (Convert x a b)) b a) = x"
    theorem unit_price_guard: "~ wdecline (UnitPrice p n) ==> n ~= 0"
    theorem unit_price_answered_guard: "answered (reply_of (rnd, [UnitPrice p n])) ==> n ~= 0"
    theorem unit_price_total_cost:
      "answered (reply_of (rnd, [UnitPrice p n])) ==> wvalue (TotalCost n (wvalue (UnitPrice p n))) = p"
    theorem percent_of_total_sym: "wvalue (PercentOfTotal a b) = wvalue (PercentOfTotal b a)"
    theorem percent_of_total_range:
      "0 <= a ==> 0 <= b ==> ~ wdecline (PercentOfTotal a b) ==>
       0 <= wvalue (PercentOfTotal a b) & wvalue (PercentOfTotal a b) <= 100"
    theorem motion_speed_dist:
      "~ wdecline (MotionSpeed x u t u') ==> wvalue (MotionDist (wvalue (MotionSpeed x u t u')) t u' l) = x"
    theorem cone_cyl_ratio: "wvalue (CylVol r h p) = 3 * wvalue (ConeVol r h p)"
    theorem sphere_four_cones: "wvalue (SphereVol r p) = 4 * wvalue (ConeVol r r p)"
    theorem cyl_base_height: "wvalue (CylVol r h p) = wvalue (CircleArea r p) * h"

(ASCII spelling here; the .thy files hold the Isabelle symbols.) Removed:
`convert_value`, `unit_price_value`, `percent_of_total_value`,
`motion_speed_value`, `cone_vol_value`, `sphere_vol_value`.
`unit_price_total_cost` and `motion_speed_dist` are cross-schema laws;
`unit_price_answered_guard` and `percent_of_total_range` read the guard from
the reply, not from a hypothesis. `Wordprob_Export.thy` and the theorem list
in `main.sml` follow (the answerer's provenance now names the new theorems).

## Checks and results

- Remote build on persvati: `VERI7VN_WORDPROB PASS theorems=41 oracles=0` and
  `VERI7VN_TRADES PASS theorems=32 oracles=0`, marker last in both exports. No
  `by eval` in either family. Wordprob needed three builds in total (a
  `scale` non-zero fact for simp, two singleton-fact fixes); trades one proof
  (`mix_symmetric`) was rewritten after `auto` over 81 colour pairs did not
  finish.
- Audit recount (`tools/audit`): trades B 22 -> 26, vacuous 0, unscanned theorems 0;
  wordprob vacuous 6 -> 0, B 7 -> 17 (counting two helper lemmas as helpers),
  unscanned theorems 0. Ten new binding theorems across the two families,
  four of them in trades, ten in wordprob (total 14 against the 6 asked for).
- Replies unchanged. Trades: 357 panel items over architecture, printing,
  printing-v2, safety, woodworking, crafts, both splits, harness reply
  compared with the previous run (timing field removed): 0 differences, all
  six heldout verdict files equal. Wordprob: the 924-question core panel run
  through the previous and the new binary (provenance removed): 0 differences;
  `score_core.py` reports 915/924 agreement with the organ (the nine
  differences are the declared negative-given declines), 24/24 core word
  items equal to the recorded head reply.

## What remains

- Audit item 2 of wordprob (printed number within the rounding bound, end to
  end, over `reply_of`) and item 3 (a HOL `has_negative_given`, so `neg` is
  not a recognizer bit) are not done; `negative_given_declines` and
  `checked_answered_iff` still lean on the recognizer's flag.
- Trades audit item 3 is met by `actual_below_nominal` over the table; the
  table is still checked against the organ by `tables_check.py`.
- Operational: a killed `remote-build` leaves its remote Isabelle running.
  Two such orphans of this lane (identified by their command lines, my
  session) were stopped by PID on persvati.
