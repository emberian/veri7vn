(* Focused executable contract checks for the untrusted shared numeric lexer. *)
structure NumericTest =
struct
  val checks = ref 0
  fun assert label good = (checks := !checks + 1; if good then () else raise Fail label)
  fun number text n d = assert ("parse " ^ text) (ExactNumeric.parse text = SOME (n, d))
  fun invalid text = assert ("reject " ^ text) (ExactNumeric.parse text = NONE)
  fun norm text expected = assert ("normalize " ^ text) (ExactNumeric.normalize text = expected)
  val _ = List.app (fn (text, n, d) => number text n d)
    [("0", 0, 1), ("-0", 0, 1), ("+12", 12, 1), (".5", 1, 2),
     ("-.5", ~1, 2), ("\226\136\146.5", ~1, 2), ("1.2300", 123, 100),
     ("1e3", 1000, 1), ("-1.25E-2", ~1, 80), (".1e+2", 10, 1),
     ("1,234,567.89", 123456789, 100), ("1/2", 1, 2), ("1 / 2", 1, 2),
     ("-2/-4", 1, 2), ("1.5/0.5", 3, 1), ("1e2/4e-1", 250, 1)]
  val _ = List.app invalid
    ["", " 2", "2 ", "1.", "1,", "1,23", "1234,567", "1,,234",
     "1.2.3", "--2", "+-2", "1e", "1e+", "1e2e3", "1e10001", "1/0", "1//2",
     "1/- 2", "- 2", "1..2", "2_000", "1e3kg"]
  val _ = norm "-0.5 m" (SOME "-1/2 m")
  val _ = norm "\226\136\1465 C" (SOME "-5 C")
  val _ = norm ".1MPa / .05GPa" (SOME "1/10MPa / 1/20GPa")
  val _ = norm "1e3m = 1,000m." (SOME "1000m = 1000m.")
  val _ = norm "CO2 at 3 kg/m3, carbon-14 and iodine-131" (SOME "CO2 at 3 kg/m3, carbon-14 and iodine-131")
  val _ = norm "1,23 m" NONE
  val _ = norm "1.2.3m" NONE
  val _ = norm "- 2 m" NONE
  val _ = norm "--2 m" NONE
  val _ = norm "1 / 2 g" (SOME "1/2 g")
  val _ = norm "1/0g" NONE
  val _ = norm "1e+m" NONE
  val _ = norm "2eV" (SOME "2eV")
  val _ = assert "byte spans preserve Unicode sign"
    (case ExactNumeric.scan "x \226\136\146.5m" of
       [ExactNumeric.Number {start = 2, stop = 7, value = (~1, 2)}] => true | _ => false)
  val _ = assert "malformed run is not retried"
    (case ExactNumeric.scan "1.2.3m 4m" of
       [ExactNumeric.Malformed {start = 0, stop = 5, ...}, ExactNumeric.Number {value = (4,1), ...}] => true | _ => false)
  val _ = assert "digit cap"
    (ExactNumeric.parse (String.implode (List.tabulate (4097, fn _ => #"9"))) = NONE)
  val _ = norm "2_000 m" NONE
  val _ = assert "mask units and exact values"
    (ExactNumeric.mask ".1MPa and -.05GPa" = SOME
      {text = "qnum0qMPa and qnum1qGPa", numbers = [("qnum0q", (1,10)), ("qnum1q", (~1,20))]})
  val _ = assert "mask cannot trust user placeholders"
    (ExactNumeric.mask "qnum0q and .5m" = SOME
      {text = "qnum0q and qnum1qm", numbers = [("qnum1q", (1,2))]})
  val _ = norm "Ca(OH)2 K4[Fe(CN)6] 5 kg/m^3" (SOME "Ca(OH)2 K4[Fe(CN)6] 5 kg/m^3")
  val _ = norm "1,, g" NONE
  val _ = norm "a 10-second period and 1e-3-second interval" (SOME "a 10-second period and 1/1000-second interval")
  val _ = norm "10--second" NONE
  val _ = norm "10-3 seconds" NONE
  val _ = norm "1e-foo" NONE
  val _ = assert "exponent lower boundary allowed"
    (case ExactNumeric.parse "1e-10000" of SOME (1, d) => d > 1 | _ => false)
  val _ = assert "exponent upper boundary allowed"
    (case ExactNumeric.parse "1e10000" of SOME (n, 1) => n > 1 | _ => false)
  val _ = invalid "1e-10001"
  val _ = assert "digit boundary allowed"
    (case ExactNumeric.parse (String.implode (List.tabulate (4096, fn _ => #"9"))) of SOME (_, 1) => true | _ => false)
  val _ = assert "mask freshness survives case folding"
    (ExactNumeric.mask "QNUM0Q and .5m" = SOME
      {text = "QNUM0Q and qnum1qm", numbers = [("qnum1q", (1,2))]})
  val _ = assert "electrical role cannot borrow a case-folded user marker"
    (ExactNumeric.mask "Voltage QNUM0Q V and current 2 A" = SOME
      {text = "Voltage QNUM0Q V and current qnum1q A", numbers = [("qnum1q", (2,1))]})
  val _ = number "1/ 2" 1 2
  val _ = number "1 /2" 1 2
  val _ = number "1 / 2" 1 2
  val _ = number "1/ -2" ~1 2
  val _ = norm "1/ 2 g" (SOME "1/2 g")
  val _ = norm "1/ 2 / 3 g" NONE
  val _ = print ("EXACT_NUMERIC PASS " ^ Int.toString (!checks) ^ " checks\n")
end
