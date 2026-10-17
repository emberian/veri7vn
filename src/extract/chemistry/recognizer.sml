(* UNTRUSTED. The English recognizer for the chemistry family: a hand port of
     upstream/root/specialists/chemistry/organ_chemistry_v1.py          (ChemistryOrgan)
     upstream/root/specialists/chemistry-v3/organ_chemistry_v{2,3}.py    (narrowing, Fahrenheit)
     upstream/root/specialists/chemistry-v3/formula_reader_v2.py         (formula_in)
     upstream/root/specialists/decay/organ_decay_v1.py                   (DecayOrgan)
     upstream/root/specialists/labsolutions/organ_labsolutions_v1.py     (LabSolutionsOrgan)
     upstream/root/specialists/labsolutions-r2/organ_labsolutions_r2.py  (boundary)
   and of their shared narrowing rule narrow_v1.py. It reads numbers and words
   off the question and builds a typed Chemistry.request; it computes nothing.
   Every value, decline and response text comes from the verified kernel
   (Chemistry.reply_of). NONE means the question is not taken.

   Matching: patterns the organs compile with re.I run on the lower-cased text
   (Regex.compile folds literals itself); groups whose case matters (formulas)
   are read back from the original text at the same byte offsets. Patterns the
   organs compile without re.I run case-sensitively on the original text
   (Regex.compileCS). The formula text is normalised: the middle dot and "*"
   become "." (the organ does this inside parse; the reply echoes the
   normalised formula). *)
structure Recognizer :
sig
  val organs : string list
  val recognize : string -> string -> (string * Chemistry.request) option
end =
struct
  structure Q = Chemistry

  val cache : (string * Regex.regex) list ref = ref []
  fun lower s = String.map Char.toLower s
  fun re p =
    case List.find (fn (q, _) => q = p) (!cache) of
      SOME (_, r) => r
    | NONE => let val r = Regex.compile p in cache := (p, r) :: !cache; r end
  val cacheCS : (string * Regex.regex) list ref = ref []
  fun rcs p =
    case List.find (fn (q, _) => q = p) (!cacheCS) of
      SOME (_, r) => r
    | NONE => let val r = Regex.compileCS p in cacheCS := (p, r) :: !cacheCS; r end

  fun search p s = Regex.search (re p) s
  fun has p s = isSome (search p s)
  fun searchCS p s = Regex.search (rcs p) s
  fun hasCS p s = isSome (searchCS p s)
  fun findall p s = Regex.findall (re p) s
  fun grp s m g = Regex.group s m g
  fun g1 s m = valOf (grp s m 1)

  fun ratOf (lit0 : string) : Q.rat =
    let
      val lit = String.translate (fn #"," => "" | c => String.str c) lit0
      val (ip, fp) = case String.fields (fn c => c = #".") lit of
                       [a] => (a, "")
                     | [a, b] => (a, b)
                     | _ => raise Fail ("bad numeral " ^ lit0)
      val num = valOf (IntInf.fromString (ip ^ fp))
      val den = IntInf.pow (10, size fp)
    in Q.mk_rat num den end
  fun ratInt (n : int) : Q.rat = Q.mk_rat (IntInf.fromInt n) 1
  fun ratMul (a : string) (k : int) : Q.rat = (* a decimal numeral times an integer *)
    let
      val lit = String.translate (fn #"," => "" | c => String.str c) a
      val (ip, fp) = case String.fields (fn c => c = #".") lit of
                       [a] => (a, "") | [a, b] => (a, b) | _ => raise Fail "bad numeral"
    in Q.mk_rat (IntInf.* (valOf (IntInf.fromString (ip ^ fp)), IntInf.fromInt k)) (IntInf.pow (10, size fp)) end

  fun collapse s = String.concatWith " " (String.tokens Char.isSpace s)

  fun rstrip chars s =
    let fun go n = if n > 0 andalso Char.contains chars (String.sub (s, n - 1)) then go (n - 1) else n
    in String.substring (s, 0, go (size s)) end

  (* the formula as the kernel's character list, "middle dot" and "*" read as "." *)
  fun normFormula s =
    let
      fun go [] = []
        | go (c1 :: c2 :: r) = if c1 = #"\194" andalso c2 = #"\183" then #"." :: go r else sub c1 (c2 :: r)
        | go [c] = sub c []
      and sub c r = (if c = #"*" then #"." else c) :: go r
    in String.implode (go (String.explode s)) end
  fun fchars (s : string) =
    Q.chars_of (map (fn c => IntInf.fromInt (Char.ord c)) (String.explode (normFormula s)))
  fun fclass (s : string) : int = IntInf.toInt (Q.fclass (fchars s))

  fun zip3 (pats, xs, what) =
    if length pats = length xs then ListPair.zip (pats, xs)
    else raise Fail ("recognizer table length differs from HOL list: " ^ what)

  (* a decimal numeral as (numerator, denominator) *)
  fun decPair (lit0 : string) : IntInf.int * IntInf.int =
    let
      val lit = String.translate (fn #"," => "" | c => String.str c) lit0
      val (ip, fp) = case String.fields (fn c => c = #".") lit of
                       [a] => (a, "") | [a, b] => (a, b) | _ => raise Fail ("bad numeral " ^ lit0)
    in (valOf (IntInf.fromString (ip ^ fp)), IntInf.pow (10, size fp)) end

  (* ---------- narrow_v1 ---------- *)
  structure Narrow =
  struct
    fun strip s = collapse s
    fun words t = length (String.tokens Char.isSpace t)
    (* whitespace runs preceded by one of the characters in ends, in the stripped text *)
    fun splits ends t =
      let
        val t = strip t
        val n = size t
        fun go i acc =
          if i >= n then rev acc
          else if Char.isSpace (String.sub (t, i)) andalso i > 0
                  andalso Char.contains ends (String.sub (t, i - 1))
          then let fun skip j = if j < n andalso Char.isSpace (String.sub (t, j)) then skip (j + 1) else j
               in go (skip i) (i :: acc) end
          else go (i + 1) acc
      in (t, go 0 []) end
    fun sentences t =
      let val (s, sp) = splits ".!?" t in if s = "" then 0 else 1 + length sp end
    fun last_sentence t =
      let
        val (s, sp) = splits ".!?;" t
      in
        case rev sp of
          [] => s
        | i :: _ => let fun skip j = if j < size s andalso Char.isSpace (String.sub (s, j)) then skip (j + 1) else j
                    in String.extract (s, skip i, NONE) end
      end
    val RELATION = "\\b(?:\\d+(?:\\.\\d+)?|one|two|three|four|five|six|seven|eight|nine|ten)\\s+(?:\\w+\\s+){0,2}"
      ^ "(?:more|less|fewer|longer|shorter)\\s+than\\b|\\b(?:twice|three times|half)\\s+(?:as\\s+\\w+\\s+as\\s+)?the\\s+\\w+\\b"
    val RATE = "\\b\\d+(?:\\.\\d+)?\\s+[a-z]+\\s+(?:for|per|every)\\s+(?:\\d+(?:\\.\\d+)?|a|an|one|each)\\s+[a-z]+"
    fun narrative t =
      let val low = lower t
      in sentences t >= 3 orelse words t > 40 orelse has RELATION low orelse has RATE low end
    fun short_direct t = sentences t <= 2 andalso words t <= 25 andalso not (narrative t)
  end


  val NUM = "(\\d+(?:,\\d{3})*(?:\\.\\d+)?)"

  fun mk r = Q.RC r
  fun mkD r = Q.RD r

  (* ======================= chemistry ======================= *)
  val propPats = [
    ("\\batomic (?:mass|weight)\\b", Q.P_atomic_mass),
    ("\\batomic number\\b|\\bproton number\\b|\\bhow many protons\\b", Q.P_atomic_number),
    ("\\belectronegativity\\b", Q.P_electronegativity),
    ("\\bmelting point\\b|\\bmelts? at\\b", Q.P_melting_point),
    ("\\bboiling point\\b|\\bboils? at\\b", Q.P_boiling_point),
    ("\\bdensity\\b", Q.P_density),
    ("\\belectron configuration\\b", Q.P_electron_configuration),
    ("\\bioni[sz]ation energy\\b", Q.P_ionization_energy),
    ("\\bstandard state\\b|\\b(?:solid|liquid|gas) at room temperature\\b|\\bstate at room temperature\\b", Q.P_standard_state),
    ("\\bgroup block\\b|\\bwhat (?:kind|type) of element\\b|\\bis \\w+ a (?:metal|nonmetal|metalloid|noble gas)\\b", Q.P_group_block),
    ("\\bdiscovered\\b|\\byear (?:of )?discovery\\b", Q.P_year_discovered),
    ("\\b(?:chemical )?symbol\\b", Q.P_symbol)]

  val FORMULA = "\\b((?:[A-Z][a-z]?\\d*|\\((?:[A-Z][a-z]?\\d*)+\\)\\d*)+(?:(?:[.*]|\194\183)\\d*(?:[A-Z][a-z]?\\d*)+)?)\\b"
  val G2MOL = "\\b(\\d+(?:\\.\\d+)?)\\s*(?:g|grams?)\\s+of\\s+(\\S+)"
  val MOL2G = "\\b(\\d+(?:\\.\\d+)?)\\s*(?:mol|moles?)\\s+of\\s+(\\S+)"
  val PCT = "\\b(?:percent|percentage|%)\\s+(?:by mass\\s+)?(?:of\\s+)?(\\w+)\\s+in\\s+(\\S+)"
  val MOLAR = "\\bmolar mass\\b|\\bmolecular (?:mass|weight)\\b|\\bformula (?:mass|weight)\\b|\\bmass of one mole\\b"

  (* the organ's first formula-shaped token; v1: ChemistryOrgan._formula_in *)
  fun formulaV1 t =
    let
      fun go [] = NONE
        | go (m :: ms) =
            let val f = Regex.whole t m
            in if hasCS "[a-z]\\d|\\d|\\(|[A-Z][a-z]?[A-Z]" f orelse Q.is_symbol f then SOME f else go ms end
    in go (Regex.findall (rcs FORMULA) t) end

  (* formula_reader_v2.formula_in *)
  fun formulaV2 t =
    let
      fun go [] lone = lone
        | go (m :: ms) lone =
            let
              val f = Regex.whole t m
              val syms = Regex.findall (rcs "[A-Z][a-z]?") f
            in
              if null syms then go ms lone
              else if hasCS "\\d|\\(" f orelse length syms >= 2 then SOME f
              else
                let val s0 = Regex.whole f (hd syms)
                in
                  if not (Q.is_symbol s0) then go ms lone
                  else if lone = NONE andalso hasCS "\\b(?:of|for)\\s+$" (String.substring (t, 0, #start m)) then go ms (SOME f)
                  else go ms lone
                end
            end
    in go (Regex.findall (rcs FORMULA) t) NONE end

  fun nameSym w = Option.map #2 (List.find (fn (n, _) => n = w) Q.elem_names)

  (* ChemistryOrgan.answer. fahr: the property reply also gives Fahrenheit (v2/v3) *)
  fun chemV1 reader fahrOn t : Q.request option =
    let
      val low = lower t
      fun massKind (rx, mk') =
        case search rx low of
          NONE => NONE
        | SOME m =>
            if not (has "\\bmol(?:e|es)?\\b|\\bgrams?\\b|\\bhow many\\b|\\bmass\\b" low) then NONE
            else
              let
                val f = rstrip "?.," (valOf (grp t m 2))
                val q = ratOf (g1 t m)
              in
                case fclass f of
                  2 => NONE                                         (* ValueError: try the next pattern *)
                | _ => SOME (mk (mk' (q, fchars f)))               (* readable, or a KeyError decline *)
              end
      fun first [] = NONE
        | first (x :: xs) = case massKind x of SOME r => SOME r | NONE => first xs
      fun pct () =
        case search PCT low of
          NONE => NONE
        | SOME m =>
            let
              val elw = valOf (grp t m 1)
              val f = rstrip "?.," (valOf (grp t m 2))
              val sym = case nameSym (lower elw) of SOME s => SOME s | NONE => if Q.is_symbol elw then SOME elw else NONE
            in
              case sym of
                NONE => NONE
              | SOME s =>
                  if fclass f <> 0 then NONE
                  else
                    let val r = mk (Q.Percent (fchars s, fchars f))
                    in if Q.answers r then SOME r else NONE end
            end
      fun molar () =
        if not (has MOLAR low) then NONE
        else case reader t of
               NONE => NONE
             | SOME f => (case fclass f of 2 => SOME NONE | _ => SOME (SOME (mk (Q.MolarMass (fchars f)))))
      fun prop () =
        case List.find (fn (p, _) => has p low) propPats of
          NONE => NONE
        | SOME (_, p) =>
            let
              val bySym = Option.map #2 (List.find (fn (n, _) => has ("\\b" ^ n ^ "\\b") low) Q.elem_names)
              val sym = case bySym of
                          SOME s => SOME s
                        | NONE => (case searchCS "\\b(?:of|for|is)\\s+([A-Z][a-z]?)\\b" t of
                                     SOME m => let val s = g1 t m in if Q.is_symbol s then SOME s else NONE end
                                   | NONE => NONE)
            in
              case sym of
                SOME s => SOME (mk (Q.Property (p, fchars s,
                                  fahrOn andalso has "\\bfahrenheit\\b|\194\176\\s*f\\b|\\bdegrees f\\b" low)))
              | NONE =>
                  (case search "\\b(?:of|for)\\s+([a-z]+ium|[a-z]+on|[a-z]+gen)\\b" low of
                     SOME m => SOME (mk (Q.NoSuchElement (g1 t m)))
                   | NONE => NONE)
            end
    in
      case first [(G2MOL, Q.GramsToMoles), (MOL2G, Q.MolesToGrams)] of
        SOME r => SOME r
      | NONE =>
          (case pct () of
             SOME r => SOME r
           | NONE =>
               (case molar () of
                  SOME NONE => NONE
                | SOME (SOME r) => SOME r
                | NONE => prop ()))
    end

  fun shortDeclined narrow t r =
    (* organ_chemistry_v2 / labsolutions: a decline is only given to a short direct question *)
    not narrow orelse Q.answers r orelse Narrow.short_direct t

  fun chemistry (narrow, fahr, reader) text =
    let val t = collapse text in
      if t = "" then NONE
      else if narrow andalso Narrow.narrative t then NONE
      else case chemV1 reader fahr t of
             NONE => NONE
           | SOME r => if shortDeclined narrow t r then SOME r else NONE
    end

  (* ======================= decay ======================= *)
  val tpats = [("years?|yrs?", Q.TU_year), ("days?", Q.TU_day), ("hours?|hrs?", Q.TU_hour),
               ("minutes?|mins?", Q.TU_minute), ("seconds?|secs?|s\\b", Q.TU_second)]
  fun tunitOf word =
    Option.map #2 (List.find (fn (p, _) => has ("^(?:" ^ p ^ ")$") word) tpats)

  val isoPats = zip3 ([
    "carbon[- ]?14|c[- ]?14|14c|radiocarbon", "uranium[- ]?238|u[- ]?238", "uranium[- ]?235|u[- ]?235",
    "iodine[- ]?131|i[- ]?131", "cobalt[- ]?60|co[- ]?60", "c(?:a)?esium[- ]?137|cs[- ]?137",
    "strontium[- ]?90|sr[- ]?90", "radium[- ]?226|ra[- ]?226", "plutonium[- ]?239|pu[- ]?239",
    "tritium|hydrogen[- ]?3|h[- ]?3", "radon[- ]?222|rn[- ]?222|radon", "potassium[- ]?40|k[- ]?40",
    "phosphorus[- ]?32|p[- ]?32", "technetium[- ]?99m|tc[- ]?99m", "fluorine[- ]?18|f[- ]?18",
    "americium[- ]?241|am[- ]?241"], Q.iso_order, "iso_order")

  val HALF_RX = "half[- ]?life\\s+(?:of|is|was|equal to|=)?\\s*(?:about\\s+)?" ^ NUM
    ^ "\\s*(years?|yrs?|days?|hours?|hrs?|minutes?|mins?|seconds?|s)\\b|"
    ^ NUM ^ "[- ](years?|days?|hours?|minutes?|seconds?)\\s+half[- ]?life"
  val AMOUNT = NUM ^ "\\s*(g|grams?|mg|milligrams?|kg|kilograms?|\194\181g|micrograms?|atoms|nuclei|mol|moles?|becquerels?|bq|units|counts? per minute|cpm)\\b"
  val FRACTION_WORDS = [("half", (1, 2)), ("a quarter", (1, 4)), ("one quarter", (1, 4)), ("an eighth", (1, 8)),
    ("one eighth", (1, 8)), ("a sixteenth", (1, 16)), ("one sixteenth", (1, 16)), ("a tenth", (1, 10)),
    ("one tenth", (1, 10)), ("a hundredth", (1, 100))]

  (* decimal numeral text of a rational, for comparisons only *)
  fun isPositive (s : string) = IntInf.> (valOf (IntInf.fromString (String.translate (fn #"." => "" | #"," => "" | c => String.str c) s)), 0)

  fun halfLife t low =
    let
      val stated =
        case search HALF_RX low of
          NONE => NONE
        | SOME m =>
            let
              val (v, u) = case grp low m 1 of
                             SOME _ => (valOf (grp t m 1), valOf (grp low m 2))
                           | NONE => (valOf (grp t m 3), valOf (grp low m 4))
            in
              case tunitOf u of
                SOME tu => if isPositive v then SOME (Q.HL_stated (ratOf v, tu), SOME (#start m, #stop m)) else NONE
              | NONE => NONE
            end
    in
      case stated of
        SOME x => SOME x
      | NONE =>
          (case List.filter (fn (p, _) => has ("\\b(?:" ^ p ^ ")\\b") low) isoPats of
             [(_, i)] => SOME (Q.HL_iso i, NONE)
           | _ => NONE)
    end

  fun decay text =
    let val t = collapse text in
      if t = "" orelse Narrow.narrative t then NONE
      else
        let val low = lower t in
          if not (has "\\bhalf[- ]?li(?:fe|ves)\\b|\\bdecay\\w*\\b|\\bradioactive\\b|\\bisotope\\b|\\bremain" low) then NONE
          else
            case halfLife t low of
              NONE => NONE
            | SOME (h, span) =>
                let
                  val restO = case span of
                                NONE => t
                              | SOME (a, b) => String.substring (t, 0, a) ^ " " ^ String.extract (t, b, NONE)
                  val restL = lower restO
                  val ask = Narrow.last_sentence t
                  val askL = lower ask
                  val times = List.concat (map (fn (p, tu) =>
                      map (fn m => (ratOf (g1 restL m), tu))
                          (findall (NUM ^ "\\s*(?:" ^ p ^ ")(?![a-z])") restL)) tpats)
                  val amounts = map (fn m => (g1 restL m, valOf (grp restO m 2))) (findall AMOUNT restL)
                  val frac0 =
                    case search "\\b(\\d+(?:\\.\\d+)?)\\s*(?:%|percent\\b)" askL of
                      SOME m => let val (n, d) = decPair (g1 askL m) in SOME (Q.mk_rat n (IntInf.* (d, 100))) end
                    | NONE =>
                        (case List.find (fn (w, _) => has ("\\b" ^ w ^ "\\b") askL
                                                      andalso has "\\bhow long|\\bwhen\\b|\\btime\\b" askL) FRACTION_WORDS of
                           SOME (_, (a, b)) => SOME (Q.mk_rat (IntInf.fromInt a) (IntInf.fromInt b))
                         | NONE => NONE)
                  fun need r = if Narrow.short_direct t then SOME (mkD r) else NONE
                  fun answerOrNeed r = if Q.answers (mkD r) then SOME (mkD r) else need r
                in
                  if has "\\bhow long\\b|\\bhow many (?:years|days|hours|minutes|seconds)\\b|\\bwhen\\b|\\btime (?:will|does|it)" askL
                     andalso null times then
                    let
                      val frac =
                        case frac0 of
                          SOME q => SOME q
                        | NONE =>
                            (case amounts of
                               [(n0, u0), (n1, u1)] =>
                                 let
                                   val (a0, d0) = decPair n0
                                   val (a1, d1) = decPair n1
                                   val pre = fn u => String.substring (lower u, 0, Int.min (2, size u))
                                 in
                                   if IntInf.> (IntInf.* (a0, d1), IntInf.* (a1, d0)) andalso IntInf.> (a1, 0)
                                      andalso pre u0 = pre u1
                                   then SOME (Q.mk_rat (IntInf.* (a1, d0)) (IntInf.* (d1, a0))) else NONE
                                 end
                             | _ => NONE)
                      val mu = case search "\\bhow many (years|days|hours|minutes|seconds)\\b" askL of
                                 SOME m => tunitOf (g1 askL m) | NONE => NONE
                    in answerOrNeed (Q.TimeToFraction (h, frac, mu)) end
                  else if has "\\bhow many half[- ]?lives\\b" askL then
                    (case times of
                       [(v, tu)] => SOME (mkD (Q.HalfLives (h, SOME (v, tu))))
                     | _ => need (Q.HalfLives (h, NONE)))
                  else if has "\\b(?:remain\\w*|left|still)\\b" askL then
                    (case times of
                       [(v, tu)] =>
                         (case amounts of
                            [(n0, u0)] => SOME (mkD (Q.Remaining (h, SOME (v, tu), SOME (ratOf n0, u0))))
                          | _ =>
                              if has "\\b(?:fraction|percent|percentage|proportion|how much of)\\b" askL andalso null amounts
                              then SOME (mkD (Q.RemFraction (h, SOME (v, tu), has "\\bpercent|percentage\\b" askL)))
                              else need (Q.Remaining (h, SOME (v, tu), NONE)))
                     | _ => need (Q.Remaining (h, NONE, NONE)))
                  else NONE
                end
        end
    end

  (* ======================= labsolutions ======================= *)
  val N = "(\\d+(?:\\.\\d+)?)"
  (* VOL and CONC of the organ as exact fractions (numerator, denominator) of a litre / of a molar *)
  fun volFactor w =
    if w = "l" orelse w = "liter" orelse w = "liters" orelse w = "litre" orelse w = "litres" then (1, 1)
    else if w = "ul" orelse w = "\194\181l" then (1, 1000000)
    else (1, 1000)
  fun concFactor w =
    if w = "m" orelse w = "molar" orelse w = "mol/l" then (1, 1)
    else if w = "um" orelse w = "\194\181m" then (1, 1000000)
    else (1, 1000)
  fun scaled lit (fn_, fd) =
    let val (n, d) = decPair lit in Q.mk_rat (IntInf.* (n, IntInf.fromInt fn_)) (IntInf.* (d, IntInf.fromInt fd)) end

  fun labAnswer t : Q.request option =
    let
      val low = lower t
    in
      if not (has "\\bsolution\\b|\\bmolar\\w*\\b|\\bdilut\\w*\\b|\\bstock\\b|\\bw/v\\b|\\b\\d+(?:\\.\\d+)?\\s*(?:m|mm)\\b" low) then NONE
      else
        let
          val vols = map (fn m => scaled (g1 low m) (volFactor (valOf (grp low m 2))))
                         (findall (N ^ "\\s*(l|liters?|litres?|ml|millilit(?:er|re)s?|ul|\194\181l)\\b") low)
          val volsMl = map (fn m => scaled (g1 low m) (let val (a, b) = volFactor (valOf (grp low m 2)) in (a * 1000, b) end))
                         (findall (N ^ "\\s*(l|liters?|litres?|ml|millilit(?:er|re)s?|ul|\194\181l)\\b") low)
          val concs = map (fn m => scaled (g1 low m) (concFactor (valOf (grp low m 2))))
                         (findall (N ^ "\\s*(m|molar|mol/l|mm|millimolar|mmol/l|um|\194\181m)\\b(?![a-z])") low)
          val f = formulaV2 t
          val wv = search (N ^ "\\s*%\\s*(?:\\(?w/v\\)?|weight(?:/| per )volume)") low
        in
          case (wv, volsMl) of
            (SOME m, ml :: _) =>
              let val (n, d) = decPair (g1 low m)
              in SOME (mk (Q.WvMass (Q.mk_rat n d, ml))) end
          | _ =>
            if has "\\bdilut\\w*\\b|\\bstock\\b|\\bhow much (?:of )?(?:the )?\\d" low andalso length concs >= 2 andalso not (null vols)
            then SOME (mk (Q.Dilution (List.nth (concs, 0), List.nth (concs, 1), List.last vols)))
            else
              case f of
                NONE => if has "\\bgrams?\\b|\\bmolarity\\b" low then SOME (mk Q.NeedFormula) else NONE
              | SOME f =>
                  if fclass f <> 0 then SOME (mk (Q.Molarity (fchars f, ratInt 1, ratInt 1)))
                  else
                    let
                      val gramsM = search (N ^ "\\s*(g|grams?|mg|milligrams?)\\b") low
                    in
                      if has "\\bmolarity\\b|\\bconcentration\\b|\\bwhat is the (?:molar )?concentration\\b" low
                         andalso isSome gramsM andalso not (null vols)
                      then
                        let
                          val m = valOf gramsM
                          val milli = String.isPrefix "m" (valOf (grp low m 2))
                          val grams = scaled (g1 low m) (1, if milli then 1000 else 1)
                        in SOME (mk (Q.Molarity (fchars f, grams, hd vols))) end
                      else if has "\\bhow (?:many|much)\\b|\\bmass\\b|\\bweigh\\b|\\bgrams?\\b" low
                              andalso not (null concs) andalso not (null vols)
                      then SOME (mk (Q.MassNeeded (fchars f, hd concs, hd vols)))
                      else NONE
                    end
        end
    end

  fun labsolutions boundary text =
    let val t = collapse text in
      if boundary andalso
         has "\\bstock of \\w|\\bSQL\\b|\\bSELECT\\b|`" (lower t)
         andalso not (has "\\b(?:molar\\w*|mol|moles|mL|litres?|liters?|grams? of|dilut\\w*|stock solution|\\d+(?:\\.\\d+)?\\s*M\\b)" (lower t))
      then NONE
      else if t = "" orelse Narrow.narrative t then NONE   (* narrative(text) is first in LabSolutionsOrgan.answer *)
      else case labAnswer t of
             NONE => NONE
           | SOME r => if Q.answers r orelse Narrow.short_direct t then SOME r else NONE
    end

  (* ======================= dispatch ======================= *)
  val organs = ["chemistry", "chemistry-v3", "decay", "labsolutions", "labsolutions-r2"]

  fun byId "chemistry" = chemistry (false, false, formulaV1)
    | byId "chemistry-v3" = chemistry (true, true, formulaV2)
    | byId "decay" = decay
    | byId "labsolutions" = labsolutions false
    | byId "labsolutions-r2" = labsolutions true
    | byId other = raise Fail ("unknown specialist " ^ other)

  (* The family: decay and the lab solutions (which name a stock, a solution or
     a half-life) before the chemistry organ's general molar-mass reader.
     labsolutions-r2 stands for both lab manifests (it only adds a boundary). *)
  val familyOrder = ["decay", "labsolutions-r2", "chemistry-v3"]

  fun recognize mode text =
    if mode = "family" then
      let fun go [] = NONE
            | go (id :: ids) = case byId id text of SOME r => SOME (id, r) | NONE => go ids
      in go familyOrder end
    else Option.map (fn r => (mode, r)) (byId mode text)
end
