(* Reads one exam per line:  H|D n head_ok head_fy head_wrong comp_ok comp_fy comp_wrong core_n core_taken
   self_answered p50_hundredths budget_hundredths
   and prints the HOL decision followed by the HOL reasons, one line per exam. *)
structure G = Veri7vn_Gate

fun nat s = G.nat_of_integer (valOf (IntInf.fromString s))

fun reasonName G.DOMAIN = "DOMAIN"
  | reasonName G.FALSE_YES = "FALSE_YES"
  | reasonName G.WRONG = "WRONG"
  | reasonName G.LANE = "LANE"
  | reasonName G.SELF = "SELF"
  | reasonName G.BUDGET = "BUDGET"

fun decisionName G.ADMIT = "ADMIT"
  | decisionName G.NEGATIVE = "NEGATIVE"
  | decisionName G.WOULD_PASS = "WOULD_PASS"
  | decisionName G.WOULD_FAIL = "WOULD_FAIL"

fun line l =
  case String.tokens Char.isSpace l of
    [s, n, hok, hfy, hwr, cok, cfy, cwr, cn, ct, sa, p, b] =>
      let
        val e = G.Exam (nat n, G.Tally (nat hok, nat hfy, nat hwr), G.Tally (nat cok, nat cfy, nat cwr),
                        nat cn, nat ct, nat sa, nat p, nat b)
        val sp = if s = "H" then G.Heldout else G.Dev
      in
        print (String.concatWith " " (decisionName (G.decide sp e) :: map reasonName (G.reasons e)) ^ "\n")
      end
  | [] => ()
  | _ => (print "BAD_INPUT\n")

fun loop () =
  case TextIO.inputLine TextIO.stdIn of
    NONE => ()
  | SOME l => (line l; loop ())

val () = loop ()
