(* UNTRUSTED. The English recognizer for the chemistry family: a hand port of
     upstream/root/specialists/chemistry/organ_chemistry_v1.py          (ChemistryOrgan)
     upstream/root/specialists/chemistry-v3/organ_chemistry_v{2,3}.py    (narrowing, Fahrenheit)
     upstream/root/specialists/chemistry-v3/formula_reader_v2.py         (formula_in)
     upstream/root/specialists/decay/organ_decay_v1.py                   (DecayOrgan)
     upstream/root/specialists/labsolutions/organ_labsolutions_v1.py     (LabSolutionsOrgan)
     upstream/root/specialists/labsolutions-r2/organ_labsolutions_r2.py  (boundary)
   and of their shared narrowing rule narrow_v1.py. It reads numbers and words
   off the question and builds a typed Chemistry.request. ExactNumeric supplies
   complete signed tokens; role binding, unit scaling and formula selection
   remain untrusted. No answer arithmetic is performed here.
   Every value, decline and response text comes from the verified kernel
   (Chemistry.reply_of). NONE means the question is not taken.

   Matching: patterns the organs compile with re.I run on the lower-cased text
   (Regex.compile folds literals itself); groups whose case matters (formulas)
   are read back from the case-preserving masked text at the same byte offsets. Patterns the
   organs compile without re.I run case-sensitively on the original text
   (Regex.compileCS). The formula text is normalised: the middle dot and "*"
   become "." (the organ does this inside parse; the reply echoes the
   normalised formula). Matched square bracket groups become parentheses;
   complete formula tokens prevent partial neutral-species recovery. *)
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

  exception UnboundNumeral
  val originalQuestion = ref ""
  val numberBindings : (string * ExactNumeric.rational) list ref = ref []
  fun decPair token =
    case List.find (fn (marker, _) => marker = token) (!numberBindings) of
      SOME (_, pair) => pair
    | NONE => raise UnboundNumeral
  fun ratOf token = let val (n, d) = decPair token in Q.mk_rat n d end
  fun ratInt (n : int) = Q.mk_rat (IntInf.fromInt n) 1


  fun collapse s = String.concatWith " " (String.tokens Char.isSpace s)

  fun rstrip chars s =
    let fun go n = if n > 0 andalso Char.contains chars (String.sub (s, n - 1)) then go (n - 1) else n
    in String.substring (s, 0, go (size s)) end

  (* the formula as the kernel's character list, "middle dot" and "*" read as "." *)
  fun normFormula s =
    let
      fun balanced [] [] = true
        | balanced [] _ = false
        | balanced (c :: cs) stack =
            if c = #"(" orelse c = #"[" then balanced cs (c :: stack)
            else if c = #")" orelse c = #"]" then
              (case stack of a :: rest =>
                ((a = #"(" andalso c = #")") orelse (a = #"[" andalso c = #"]"))
                andalso balanced cs rest | [] => false)
            else balanced cs stack
      val brackets = balanced (String.explode s) []
      fun go [] = []
        | go (c1 :: c2 :: r) = if c1 = #"\194" andalso c2 = #"\183" then #"." :: go r else sub c1 (c2 :: r)
        | go [c] = sub c []
      and sub c r =
        (if c = #"*" then #"." else if brackets andalso c = #"[" then #"("
         else if brackets andalso c = #"]" then #")" else c) :: go r
    in String.implode (go (String.explode s)) end
  fun fchars (s : string) =
    Q.chars_of (map (fn c => IntInf.fromInt (Char.ord c)) (String.explode (normFormula s)))
  fun fclass (s : string) : int = IntInf.toInt (Q.fclass (fchars s))

  fun zip3 (pats, xs, what) =
    if length pats = length xs then ListPair.zip (pats, xs)
    else raise Fail ("recognizer table length differs from HOL list: " ^ what)

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
    val RELATION = "\\b(?:qnum[0-9]+q|one|two|three|four|five|six|seven|eight|nine|ten)\\s+(?:\\w+\\s+){0,2}"
      ^ "(?:more|less|fewer|longer|shorter)\\s+than\\b|\\b(?:twice|three times|half)\\s+(?:as\\s+\\w+\\s+as\\s+)?the\\s+\\w+\\b"
    val RATE = "\\bqnum[0-9]+q\\s+[a-z]+\\s+(?:for|per|every)\\s+(?:qnum[0-9]+q|a|an|one|each)\\s+[a-z]+"
    fun narrative t =
      let val low = lower t
      in sentences t >= 3 orelse words t > 40 orelse has RELATION low orelse has RATE low end
    fun short_direct t = sentences t <= 2 andalso words t <= 25 andalso not (narrative t)
  end


  val NUM = "(qnum[0-9]+q)"

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

  val G2MOL = NUM ^ "\\s*(?:g|grams?)\\s+of\\s+(\\S+)"
  val MOL2G = NUM ^ "\\s*(?:mol|moles?)\\s+of\\s+(\\S+)"
  val PCT = "\\b(?:percent|percentage|%)\\s+(?:by mass\\s+)?(?:of\\s+)?(\\w+)\\s+in\\s+(\\S+)"
  (* B-chemistry step 2: "percentage by mass of F is E" (the generator's heldout phrasing; the organ's PCT wants "of E in F") *)
  val PCT2 = "\\b(?:percent|percentage)\\s+by\\s+(?:mass|weight)\\s+of\\s+(\\S+)\\s+is\\s+(\\w+)"
  (* B-chemistry step 3: the whole composition, which the organ's one-element PCT never gave *)
  val PCOMP = "\\bpercent(?:age)?\\s+composition\\b|\\belemental\\s+composition\\b|\\bcomposition\\s+by\\s+(?:mass|weight)\\b"
    ^ "|\\bpercent(?:age)?s?\\s+(?:by\\s+(?:mass|weight)\\s+)?of\\s+(?:each|every|all)\\s+(?:the\\s+)?elements?\\b"
    ^ "|\\bmass\\s+percent(?:age)?s?\\s+of\\s+(?:each|every|all)\\s+(?:the\\s+)?elements?\\b"
  val MOLAR = "\\bmolar mass\\b|\\bmolecular (?:mass|weight)\\b|\\bformula (?:mass|weight)\\b|\\bmass of one mole\\b"

  (* A complete formula-shaped token, including brackets and any unsupported
     charge suffix. Never turn Ca[OH]2 into Ca or OH, or an ion into a neutral
     prefix. The HOL parser decides whether the entire token is readable. *)
  fun formulaMatches t =
    let
      fun part c = Char.isAlphaNum c orelse Char.contains "()[]{}.*+-" c orelse Char.ord c >= 128
      fun finish i = if i < size t andalso part (String.sub (t, i)) then finish (i + 1) else i
      fun trim i j = if j > i andalso String.sub (t, j - 1) = #"." then trim i (j - 1) else j
      fun go i acc =
        if i >= size t then rev acc
        else if part (String.sub (t, i)) then
          let val stop = finish i
              val last = trim i stop
              val raw = String.substring (t, i, last - i)
              val upper = List.exists Char.isUpper (String.explode raw)
              val m = {start = i, stop = last, groups = Vector.fromList [SOME (i, last)]}
          in go stop (if upper then m :: acc else acc) end
        else go (i + 1) acc
    in go 0 [] end

  (* the organ's first formula-shaped token; v1: ChemistryOrgan._formula_in *)
  fun formulaV1 t =
    let
      fun go [] = NONE
        | go (m :: ms) =
            let val f = Regex.whole t m
            in if hasCS "[a-z]\\d|\\d|\\(|[A-Z][a-z]?[A-Z]" f orelse Q.is_symbol f then SOME f else go ms end
    in go (formulaMatches t) end

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
    in go (formulaMatches t) NONE end

  fun nameSym w = Option.map #2 (List.find (fn (n, _) => n = w) Q.elem_names)

  (* A one-species amount conversion cannot answer a reaction or a mixture
     by silently selecting its first ingredient. Bind the complete formula
     token across the question, not just the first number/formula pair. *)
  fun onlyFormula target t =
    let
      fun relevant m =
        let val f = Regex.whole t m
            val syms = Regex.findall (rcs "[A-Z][a-z]?") f
            val shaped = hasCS "\\d|\\(|\\[" f orelse length syms >= 2
            val object = Q.is_symbol f andalso
              hasCS "\\b(?:of|for)\\s+$" (String.substring (t, 0, #start m))
        in (shaped orelse object) andalso fclass f <> 2 end
    in List.all (fn m => normFormula (Regex.whole t m) = normFormula target)
         (List.filter relevant (formulaMatches t)) end

  (* ChemistryOrgan.answer. fahr: the property reply also gives Fahrenheit (v2/v3) *)
  fun chemV1 reader fahrOn t : Q.request option =
    let
      val low = lower t
      fun massKind (rx, mk') =
        case findall rx low of
          [m] =>
            if not (has "\\bmol(?:e|es)?\\b|\\bgrams?\\b|\\bhow many\\b|\\bmass\\b" low) then NONE
            else
              let
                val f = rstrip "?.," (valOf (grp t m 2))
                val q = ratOf (g1 t m)
              in
                if not (onlyFormula f t) then NONE
                else case fclass f of
                  2 => NONE
                | _ => SOME (mk (mk' (q, fchars f)))
              end
        | _ => NONE
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
      fun pct2 () =
        case search PCT2 low of
          NONE => NONE
        | SOME m =>
            let
              val elw = valOf (grp t m 2)
              val f = rstrip "?.," (valOf (grp t m 1))
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
      fun comp () =
        if not (has PCOMP low) orelse has "\\bsolution\\b|\\bmixture\\b|\\balloy\\b|\\bsample\\b|\\bair\\b" low then NONE
        else
          let
            val shaped = List.filter (fn f => hasCS "\\d|\\(" f orelse length (Regex.findall (rcs "[A-Z][a-z]?") f) >= 2)
                                     (map (Regex.whole t) (formulaMatches t))
            fun distinct [] = []
              | distinct (x :: xs) = x :: distinct (List.filter (fn y => y <> x) xs)
          in
            if length (distinct shaped) >= 2 then NONE      (* two compounds named: not one composition *)
            else case reader t of
                   NONE => NONE
                 | SOME f => (case fclass f of 2 => NONE | _ => SOME (mk (Q.PercentComp (fchars f))))
          end
      fun molar () =
        if not (has MOLAR low) then NONE
        else case reader t of
               NONE => NONE
             | SOME f => if not (onlyFormula f t) then SOME NONE
                         else (case fclass f of 2 => SOME NONE | _ => SOME (SOME (mk (Q.MolarMass (fchars f)))))
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
          (case (case comp () of SOME r => SOME r | NONE => (case pct () of SOME r => SOME r | NONE => pct2 ())) of
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
                SOME tu => SOME (Q.HL_stated (ratOf v, tu), SOME (#start m, #stop m))
              | NONE => NONE
            end
    in
      case stated of
        SOME x => SOME x
      | NONE =>
          (case List.filter (fn (p, _) => has ("\\b(?:" ^ p ^ ")\\b") (lower (!originalQuestion))) isoPats of
             [(_, i)] => SOME (Q.HL_iso i, NONE)
           | _ => NONE)
    end

  fun decay text =
    let val t = collapse text in
      if t = "" orelse Narrow.narrative t then NONE
      else
        let val low = lower t in
          (* B-chemistry step 2: the organ's gate also needs one of these words; "how many grams are left after T" with an
             amount in the question is a remaining-amount question about the isotope it names (shipped heldout phrasing) *)
          if not (has "\\bhalf[- ]?li(?:fe|ves)\\b|\\bdecay\\w*\\b|\\bradioactive\\b|\\bisotope\\b|\\bremain" low
                  orelse (has "\\b(?:left|still)\\b" low andalso has AMOUNT low)) then NONE
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
                    case search (NUM ^ "\\s*(?:%|percent\\b)") askL of
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
  val N = NUM
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
          val wv = findall (N ^ "\\s*%\\s*(?:\\(?w/v\\)?|weight(?:/| per )volume)") low
        in
          case (wv, volsMl) of
            ([m], [ml]) =>
              let val (n, d) = decPair (g1 low m)
              in SOME (mk (Q.WvMass (Q.mk_rat n d, ml))) end
          | _ =>
            (* B-chemistry step 3: one concentration and two volumes (stock volume, final volume) *)
            if has "\\bdilut\\w*\\b|\\bstock\\b" low andalso length concs = 1 andalso length vols = 2
               andalso has "\\b(?:water|solvent|diluent)\\b" low andalso has "\\bhow (?:much|many)\\b|\\badd\\b" low
            then SOME (mk (Q.WaterToAdd (List.nth (vols, 0), List.nth (vols, 1))))
            else if has "\\bdilut\\w*\\b" low andalso length concs = 1 andalso length vols = 2
                    andalso has "\\bconcentration\\b|\\bmolarity\\b|\\bhow concentrated\\b" low
                    andalso not (has "\\bhow (?:much|many) (?:of )?(?:the )?(?:stock|ml|milliliters|liters|l)\\b" low)
            then SOME (mk (Q.DilutedConc (List.nth (concs, 0), List.nth (vols, 0), List.nth (vols, 1))))
            else if has "\\bhow many (?:moles?|mol)\\b" low andalso length concs = 1 andalso length vols = 1
            then SOME (mk (Q.MolesInSol (List.nth (concs, 0), List.nth (vols, 0))))
            else if has "\\bmolarity\\b|\\bconcentration\\b" low andalso length vols = 1 andalso null concs
                    andalso not (has (N ^ "\\s*(?:g|grams?|mg|milligrams?)\\b") low)
                    andalso length (findall (N ^ "\\s*(?:moles?|mol)\\b") low) = 1
            then
              let val m = valOf (search (N ^ "\\s*(?:moles?|mol)\\b") low)
                  val (n, d) = decPair (g1 low m)
              in SOME (mk (Q.MolarityMoles (Q.mk_rat n d, hd vols))) end
            else
            if has "\\bdilut\\w*\\b|\\bstock\\b|\\bhow much (?:of )?(?:the )?qnum" low andalso length concs = 2 andalso length vols = 1
            then SOME (mk (Q.Dilution (List.nth (concs, 0), List.nth (concs, 1), List.last vols)))
            else
              case f of
                NONE => if has "\\bgrams?\\b|\\bmolarity\\b" low then SOME (mk Q.NeedFormula) else NONE
              | SOME f =>
                  if not (onlyFormula f t) then NONE
                  else if fclass f <> 0 then SOME (mk (Q.Molarity (fchars f, ratInt 1, ratInt 1)))
                  else
                    let
                      val gramsMatches = findall (N ^ "\\s*(g|grams?|mg|milligrams?)\\b") low
                      val gramsM = case gramsMatches of [m] => SOME m | _ => NONE
                    in
                      if has "\\bmolarity\\b|\\bconcentration\\b|\\bwhat is the (?:molar )?concentration\\b" low
                         andalso isSome gramsM andalso length vols = 1
                      then
                        let
                          val m = valOf gramsM
                          val milli = String.isPrefix "m" (valOf (grp low m 2))
                          val grams = scaled (g1 low m) (1, if milli then 1000 else 1)
                        in SOME (mk (Q.Molarity (fchars f, grams, hd vols))) end
                      else if has "\\bhow (?:many|much)\\b|\\bmass\\b|\\bweigh\\b|\\bgrams?\\b" low
                              andalso not (has "\\bhow many (?:moles?|mol|millimoles?|mmol)\\b" low)   (* the organ answered grams to a moles question *)
                              andalso length concs = 1 andalso length vols = 1
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

  fun recognizeMasked mode text =
    if mode = "family" then
      let fun go [] = NONE
            | go (id :: ids) = case byId id text of SOME r => SOME (id, r) | NONE => go ids
      in go familyOrder end
    else Option.map (fn r => (mode, r)) (byId mode text)
  fun recognize mode text =
    case ExactNumeric.mask text of
      NONE => (numberBindings := []; NONE)
    | SOME {text = masked, numbers} =>
        let val low = lower masked
            (* An unissued placeholder must not make one candidate disappear
               while another quantity is silently selected by fall-through. *)
            val issued = List.all
              (fn m => isSome (List.find (fn (key, _) => key = Regex.whole low m) numbers))
              (findall "qnum[0-9]+q" low)
        in if not issued then NONE
           else (originalQuestion := text; numberBindings := numbers;
                 (recognizeMasked mode masked handle UnboundNumeral => NONE))
        end

end
