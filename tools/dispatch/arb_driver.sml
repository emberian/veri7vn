(* UNTRUSTED driver around the VERIFIED arbitration rule.
   The rule itself (arbitrate, cand, outcome) is Isabelle-generated SML from
   src/isabelle/specialists/Arbitration.thy (export_code in Gate_Export.thy);
   this file only reads one line of oracle readings per turn and prints the
   outcome. Everything on the input line is computed elsewhere and taken on
   trust (see dispatch.py); which candidate wins is the HOL function's.

   Input line:  g ix0 d0 c0 dep0 a0 wn0 wa0 ctx0 v0 ix1 d1 ... (9 fields per candidate)
     g    number of givens the turn supplies (nat)
     ix   candidate index (returned on Pick/Disagree)
     d    1 if the reply is an in-domain decline
     c    1 if that decline is checked (impossible / out of range)
     dep  counterfactual dependence count (nat; a checked decline is fed g here)
     a    1 if the reply assumes a value
     wn   wording trigrams with a number (nat)
     wa   wording trigrams total (nat)
     ctx  1 if the specialist's context_regex matches the asking sentence
     v    the reply's answer value scaled to an integer, or ? when none
   Output line: PICK ix | DISAGREE a b | FALLTHROUGH | BAD *)
structure G = Veri7vn_Gate

fun nat s = G.nat_of_integer (valOf (IntInf.fromString s))

fun ivof s = if s = "?" then NONE else SOME (valOf (IntInf.fromString s))

fun cand [ix, d, c, dp, a, wn, wa, cx, v] =
      G.Cand (d = "1", c = "1", nat dp, a = "1", (nat wn, nat wa), cx = "1",
              ivof v, valOf (Int.fromString ix))
  | cand _ = raise Fail "cand needs 9 fields"

(* combo_runtime_v1._same_value with rel = 0.005, on values scaled to integers:
   abs (a - b) <= (1/200) * max (abs a, abs b) *)
fun same (a : IntInf.int) b =
  IntInf.* (IntInf.abs (a - b), 200) <= IntInf.max (IntInf.abs a, IntInf.abs b)

fun group9 [] = []
  | group9 xs = List.take (xs, 9) :: group9 (List.drop (xs, 9))

fun ixof (G.Cand (_, _, _, _, _, _, _, r)) = r

fun outcomeName (G.Pick c) = "PICK " ^ Int.toString (ixof c)
  | outcomeName (G.Disagree (a, b)) =
      "DISAGREE " ^ Int.toString (ixof a) ^ " " ^ Int.toString (ixof b)
  | outcomeName G.Fallthrough = "FALLTHROUGH"

fun line l =
  case String.tokens Char.isSpace l of
    [] => ()
  | g :: fields =>
      if g = "" orelse length fields mod 9 <> 0 then print "BAD\n"
      else
        let
          val cs = map cand (group9 fields)
        in
          print (outcomeName (G.arbitrate same (nat g) cs) ^ "\n")
        end
        handle Fail _ => print "BAD\n"

fun loop () =
  case TextIO.inputLine TextIO.stdIn of
    NONE => ()
  | SOME l => (line l; loop ())

val () = loop ()
