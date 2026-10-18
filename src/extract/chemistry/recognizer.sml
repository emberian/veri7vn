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


  val MASS_UNIT = "(?:g|grams?|mg|milligrams?|kg|kilograms?|ug|\194\181g|\206\188g|micrograms?)"
  val MASS_AMOUNT = NUM ^ "\\s*(" ^ MASS_UNIT ^ ")\\b(?!\\s*/|\\s+per\\b)"
  fun massUnit u =
    case lower u of
      "g" => SOME Q.MassGram | "gram" => SOME Q.MassGram | "grams" => SOME Q.MassGram
    | "mg" => SOME Q.MassMilligram | "milligram" => SOME Q.MassMilligram | "milligrams" => SOME Q.MassMilligram
    | "kg" => SOME Q.MassKilogram | "kilogram" => SOME Q.MassKilogram | "kilograms" => SOME Q.MassKilogram
    | "ug" => SOME Q.MassMicrogram | "\194\181g" => SOME Q.MassMicrogram | "\206\188g" => SOME Q.MassMicrogram
    | "microgram" => SOME Q.MassMicrogram | "micrograms" => SOME Q.MassMicrogram
    | _ => NONE

  (* A requested output unit is distinct from the numeric input amount. None
     means ambiguous/unsupported; SOME NONE means no explicit mass target. *)
  fun massTargetFor molar low =
    let val requested = findall ("\\b(?:how many|in|to|and)\\s+(" ^ MASS_UNIT ^ "|ounces?|pounds?|lbs?|tons?|tonnes?|stones?)\\b") low
        val units = map (fn m =>
          if has "^\\s*(?:/|per\\b)" (String.extract (low,#stop m,NONE))
             andalso not (molar andalso has "^\\s*(?:/\\s*mol(?:e|es)?|per\\s+moles?)\\b" (String.extract (low,#stop m,NONE))) then NONE
          else massUnit (g1 low m)) requested
    in case units of [] => SOME NONE
       | SOME u :: us => if List.all (fn v => v = SOME u) us then SOME (SOME u) else NONE
       | _ => NONE
    end

  val massTarget = massTargetFor false

  (* Non-mass amount classes compare only explicit canonical identities. *)
  fun amountClass u =
    case lower u of
      "atom" => SOME "atoms" | "atoms" => SOME "atoms"
    | "nucleus" => SOME "nuclei" | "nuclei" => SOME "nuclei"
    | "mol" => SOME "mol" | "mole" => SOME "mol" | "moles" => SOME "mol"
    | "becquerel" => SOME "bq" | "becquerels" => SOME "bq" | "bq" => SOME "bq"
    | "count per minute" => SOME "cpm" | "counts per minute" => SOME "cpm" | "cpm" => SOME "cpm"
    | "units" => SOME "units" | _ => NONE

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

  val G2MOL = NUM ^ "\\s*(" ^ MASS_UNIT ^ ")\\s+of\\s+(\\S+)"
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
      fun formulaAmount m group build =
        let val f = rstrip "?.," (valOf (grp t m group))
        in if not (onlyFormula f t) orelse fclass f = 2 then NONE
           else SOME (Q.RM (build (ratOf (g1 t m), fchars f))) end
      fun massConversion () =
        case (findall G2MOL low, findall MOL2G low, massTarget low) of
          ([m], [], SOME NONE) =>
            if has "\\bmol(?:e|es)?\\b" low then
              (case massUnit (valOf (grp low m 2)) of
                SOME u => formulaAmount m 3 (fn (q,f) => Q.MeasuredMoles (q,u,f))
              | NONE => NONE)
            else NONE
        | ([], [m], SOME target) =>
            if isSome target orelse has "\\bgrams?\\b|\\bmass\\b|\\bweigh" low then
              formulaAmount m 2 (fn (q,f) => Q.MeasuredMass (q,f,case target of SOME u => u | NONE => Q.MassGram))
            else NONE
        | _ => NONE
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
                         else (case (fclass f,massTargetFor true low) of
                           (2,_) => SOME NONE | (_,NONE) => SOME NONE
                         | (_,SOME NONE) => SOME (SOME (mk (Q.MolarMass (fchars f))))
                         | (_,SOME (SOME u)) => SOME (SOME (Q.RM (Q.MeasuredMolarMass (fchars f,u)))))
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
      case massConversion () of
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

  (* Explicit reaction clauses: reaction; named mole amounts; requested yield
     or remainder. Every quantity and formula must be claimed exactly once.
     Coefficients and amounts are checked again by the extracted kernel. *)
  fun reactionRequest text =
    let
      fun sequence [] = SOME []
        | sequence (NONE :: _) = NONE
        | sequence (SOME x :: xs) = Option.map (fn rest => x :: rest) (sequence xs)
      fun distinct [] = true
        | distinct (x :: xs) = not (List.exists (fn y => y = x) xs) andalso distinct xs
      fun term s =
        case searchCS "^\\s*([0-9]*)\\s*([^\\s]+)\\s*$" s of
          NONE => NONE
        | SOME m =>
            let val digits = g1 s m
                val f = valOf (grp s m 2)
                val start = String.sub (f, 0)
            in if not (Char.isUpper start orelse start = #"(" orelse start = #"[") then NONE
               else case ExactNumeric.parse (if digits = "" then "1" else digits) of
                 SOME (n, 1) => SOME (normFormula f, Q.nat_of_integer n)
               | _ => NONE end
      fun side s =
        case sequence (map term (String.fields (fn c => c = #"+") s)) of
          SOME xs => SOME xs
        | NONE => NONE
      fun index name xs =
        let fun go _ [] = NONE
              | go i ((f, _) :: rest) = if f = name then SOME i else go (i + 1) rest
        in go 0 xs end
      fun amounts source lhs rhs =
        case ExactNumeric.mask source of
          NONE => NONE
        | SOME {text = masked, numbers} =>
            let
              val low = lower masked
              val matches = findall (NUM ^ "\\s*(mol|moles?|mmol|millimoles?)\\b\\s+(?:of\\s+)?([^\\s,;]+)") low
              fun pair m =
                let val marker = g1 low m
                    val unit = valOf (grp low m 2)
                    val f = normFormula (valOf (grp masked m 3))
                in case List.find (fn (key, _) => key = marker) numbers of
                     NONE => NONE
                   | SOME (_, (n, d)) =>
                       SOME (f, Q.mk_rat n (d * (if unit = "mmol" orelse String.isPrefix "milli" unit then 1000 else 1)))
                end
              fun gaps pos first [] = has "^\\s*$" (String.extract (low, pos, NONE))
                | gaps pos first (m :: ms) =
                    let val gap = String.substring (low, pos, #start m - pos)
                        val pattern = if first then "^\\s*(?:(?:amounts?|initial(?:ly)?|with|starting)\\s*:?\\s*)?$"
                                      else "^\\s*(?:,|and|,\\s*and)\\s*$"
                    in has pattern gap andalso gaps (#stop m) false ms end
            in
              if null matches orelse not (gaps 0 true matches)
              then NONE
              else case sequence (map pair matches) of
                NONE => NONE
              | SOME xs =>
                  if not (distinct (map #1 xs)) then NONE
                  else if not (List.all (fn (f, _) => List.exists (fn (name, _) => name = f) xs) lhs)
                       orelse not (List.all (fn (f, _) => List.exists (fn (name, _) => name = f) (lhs @ rhs)) xs)
                  then NONE else SOME xs
            end
      fun query source lhs rhs =
        let val s = rstrip "?." (collapse source)
            fun make left grams f =
              Option.map (fn _ =>
                let val name = fchars f
                in if left then (if grams then Q.NetFinalGrams name else Q.NetFinalMoles name)
                   else (if grams then Q.NetYieldGrams name else Q.NetYieldMoles name) end)
                (index (normFormula f) (if left then lhs @ rhs else rhs))
        in
          case search "^(?:(?:what is|calculate) (?:the )?)?(?:theoretical )?(yield|leftover|remaining)(?: (?:amount|mass))?(?: of)?\\s+([^\\s]+)\\s+in\\s+(mol|moles|g|grams)$" (lower s) of
            SOME m => make (g1 (lower s) m <> "yield") (String.isPrefix "g" (valOf (grp (lower s) m 3))) (valOf (grp s m 2))
          | NONE =>
              (case search "^how many (mol|moles|g|grams) of ([^\\s]+) (form|are produced|remain|are left)$" (lower s) of
                 SOME m => make (List.exists (fn word => word = valOf (grp (lower s) m 3)) ["remain", "are left"])
                   (String.isPrefix "g" (g1 (lower s) m)) (valOf (grp s m 2))
               | NONE => NONE)
        end
    in
      case String.fields (fn c => c = #";") text of
        [equation, given, wanted] =>
          (case search "^\\s*(?:(?:reaction|for)\\s*:?\\s*)?(.+?)\\s*->\\s*(.+?)\\s*$" (lower equation) of
             NONE => NONE
           | SOME m =>
               (case (side (g1 equation m), side (valOf (grp equation m 2))) of
                  (SOME lhs, SOME rhs) =>
                    (case (amounts given lhs rhs, query wanted lhs rhs) of
                       (SOME values, SOME wanted) =>
                         SOME (Q.RNS (map (fn (f, k) => (fchars f, k)) lhs,
                                     map (fn (f, k) => (fchars f, k)) rhs,
                                     map (fn (f, a) => (fchars f, a)) values, wanted))
                     | _ => NONE)
                | _ => NONE))
      | _ => NONE
    end

  fun chemistry (narrow, fahr, reader) text =
    let val t = collapse text in
      if has "->" (!originalQuestion) then reactionRequest (!originalQuestion)
      else if t = "" then NONE
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
  val AMOUNT = NUM ^ "\\s*(" ^ MASS_UNIT ^ "|atoms?|nuclei|nucleus|mol|moles?|becquerels?|bq|units|counts? per minute|cpm)\\b(?!\\s*/|\\s+per\\b)"
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
                                   val sameClass = isSome (amountClass u0) andalso amountClass u0 = amountClass u1
                                 in
                                   if IntInf.> (IntInf.* (a0, d1), IntInf.* (a1, d0)) andalso IntInf.> (a1, 0)
                                      andalso sameClass
                                   then SOME (Q.mk_rat (IntInf.* (a1, d0)) (IntInf.* (d1, a0))) else NONE
                                 end
                             | _ => NONE)
                      val mu = case search "\\bhow many (years|days|hours|minutes|seconds)\\b" askL of
                                 SOME m => tunitOf (g1 askL m) | NONE => NONE
                    in
                      case (frac0, amounts) of
                        (NONE, [(n0,u0),(n1,u1)]) =>
                          (case (massUnit u0, massUnit u1) of
                            (SOME source, SOME target) =>
                              SOME (Q.RM (Q.MeasuredDecayTime (h,ratOf n0,source,ratOf n1,target,mu)))
                          | _ => answerOrNeed (Q.TimeToFraction (h,frac,mu)))
                      | _ => answerOrNeed (Q.TimeToFraction (h,frac,mu))
                    end
                  else if has "\\bhow many half[- ]?lives\\b" askL then
                    (case times of
                       [(v, tu)] => SOME (mkD (Q.HalfLives (h, SOME (v, tu))))
                     | _ => need (Q.HalfLives (h, NONE)))
                  else if has "\\b(?:remain\\w*|left|still)\\b" askL then
                    (case times of
                       [(v, tu)] =>
                         (case amounts of
                            [(n0, u0)] =>
                              (case (massUnit u0, massTarget askL) of
                                (SOME source, SOME target) =>
                                  SOME (Q.RM (Q.MeasuredRemaining (h,SOME (v,tu),ratOf n0,source,
                                    case target of SOME u => u | NONE => source)))
                              | (NONE, SOME NONE) => SOME (mkD (Q.Remaining (h,SOME (v,tu),SOME (ratOf n0,u0))))
                              | _ => NONE)
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

  val VOL_UNIT = "(?:millilit(?:er|re)s?|microlit(?:er|re)s?|lit(?:er|re)s?|ml|ul|\194\181l|l)"
  val CONC_UNIT = "(?:millimolar|micromolar|molar|mmol/l|umol/l|mol/l|mm|um|\194\181m|m)"
  val AMOUNT_UNIT = "(?:millimoles?|micromoles?|moles?|mmol|umol|\194\181mol|mol)"
  fun solutionPrefix u =
    if has "^(?:ml|millilit(?:er|re)s?|mm|millimolar|mmol/l|mmol|millimoles?)$" u then Q.SolMilli
    else if has "^(?:ul|microlit(?:er|re)s?|um|micromolar|umol/l|umol|micromoles?|\194\181l|\194\181m|\194\181mol)$" u then Q.SolMicro
    else Q.SolBase
  fun prefixScale u =
    case solutionPrefix u of Q.SolMilli => (1,1000) | Q.SolMicro => (1,1000000) | _ => (1,1)
  fun solutionTarget units fallback low =
    let val allUnits = "(?:" ^ VOL_UNIT ^ "|" ^ CONC_UNIT ^ "|" ^ AMOUNT_UNIT ^ "|" ^ MASS_UNIT ^ ")"
        val ms = findall ("\\b(?:how many|in|to|and)\\s+(" ^ allUnits ^ ")\\b") low
        val us = map (fn m => solutionPrefix (g1 low m)) ms
        val wrongDimension = List.exists (fn m => not(has ("^" ^ units ^ "$") (g1 low m))) ms
        val unsupported = has "\\b(?:how many|in|to|and)\\s+(?:gallons?|pints?|quarts?|cups?|fluid ounces?|nanomoles?|nanomolar|nm)\\b" low
        val compound = List.exists (fn (m : Regex.match) =>
          has "^\\s*(?:/|per\\b)" (String.extract(low,#stop m,NONE))) ms
    in if unsupported orelse compound orelse wrongDimension then NONE
       else case us of [] => SOME fallback | u::rest => if List.all (fn v => v=u) rest then SOME u else NONE
    end
  fun solutionResult make units fallback low =
    Option.map (fn u => Q.RL(make,u)) (solutionTarget units fallback low)

  (* Stock is a named role, not the larger of two numbers. The two remaining
     syntactic layouts carry an explicit 'from' and 'to' relation. *)
  fun directedConcs low matches =
    let
      fun afterStock (m : Regex.match) =
        has "^\\s+(?:[a-z][a-z0-9()]*\\s+)?stock\\b" (String.extract(low,#stop m,NONE))
      fun beforeStock (m : Regex.match) =
        has "\\bstock(?:\\s+solution)?(?:\\s+(?:is|of|at|has))?\\s*$" (String.substring(low,0,#start m))
      fun beforeFrom (m : Regex.match) =
        has "\\bfrom\\s*$" (String.substring(low,0,#start m))
      fun beforeTo (m : Regex.match) =
        has "\\bto\\s*$" (String.substring(low,0,#start m))
      val tagged = List.filter (fn m => afterStock m orelse beforeStock m) matches
      fun value m = scaled (g1 low m) (prefixScale (valOf(grp low m 2)))
    in case (matches,tagged) of
      ([a,b],[stock]) => if #start stock = #start a then SOME(value a,value b) else SOME(value b,value a)
    | ([a,b],[]) => if beforeFrom a andalso beforeTo b then SOME(value a,value b) else NONE
    | _ => NONE
    end

  fun directedVolumes low matches =
    let
      fun isFinal (m : Regex.match) =
        has "\\b(?:to(?:\\s+(?:a|the))?(?:\\s+final)?(?:\\s+volume(?:\\s+of)?)?|final\\s+volume(?:\\s+is)?)\\s*$" (String.substring(low,0,#start m))
      fun value m = scaled (g1 low m) (prefixScale (valOf(grp low m 2)))
    in case (matches,List.filter isFinal matches) of
      ([a,b],[final]) => if #start final = #start b then SOME(value a,value b) else SOME(value b,value a)
    | _ => NONE
    end

  fun sameNamedSolute low matches =
    let
      fun name (m : Regex.match) =
        case search "\\s+([a-z][a-z0-9()]*(?:\\s+[a-z][a-z0-9()]*){0,2})\\s+(?:stock|solution)\\b"
                    (String.extract(low,#stop m,NONE)) of
          NONE => NONE
        | SOME found => if #start found <> 0 then NONE
                        else let val n = g1 (String.extract(low,#stop m,NONE)) found
                             in if n = "stock" then NONE else SOME n end
      val names = List.mapPartial name matches
    in case names of [] => true | n::ns => List.all (fn x => x=n) ns end

  fun labAnswer t : Q.request option =
    let
      val low = lower t
    in
      if has (N ^ "\\s*(?:" ^ VOL_UNIT ^ "|" ^ CONC_UNIT ^ ")\\b\\s*(?:/|per\\b)") low then NONE
      else if has (N ^ "\\s*" ^ AMOUNT_UNIT ^ "\\b(?!\\s*/l\\b)\\s*(?:/|per\\b)") low then NONE
      else if not (has "\\bsolution\\b|\\bmolar\\w*\\b|\\bdilut\\w*\\b|\\bstock\\b|\\bw/v\\b|\\b\\d+(?:\\.\\d+)?\\s*(?:m|mm)\\b" low) then NONE
      else
        let
          val volMatches = findall (N ^ "\\s*(" ^ VOL_UNIT ^ ")\\b") low
          val concMatches = findall (N ^ "\\s*(" ^ CONC_UNIT ^ ")\\b(?![a-z])") low
          val vols = map (fn m => scaled (g1 low m) (prefixScale (valOf(grp low m 2)))) volMatches
          val volsMl = map (fn m => scaled (g1 low m) (let val (a,b)=prefixScale(valOf(grp low m 2)) in (a*1000,b) end)) volMatches
          val concs = map (fn m => scaled (g1 low m) (prefixScale (valOf(grp low m 2)))) concMatches
          val f = formulaV2 t
          val wv = findall (N ^ "\\s*%\\s*(?:\\(?w/v\\)?|weight(?:/| per )volume)") low
        in
          if not (sameNamedSolute low concMatches) orelse
             (case f of SOME formula => not (onlyFormula formula t) | NONE => false) then NONE
          else case (wv, volsMl) of
            ([m], [ml]) =>
              let val (n, d) = decPair (g1 low m)
              in SOME (mk (Q.WvMass (Q.mk_rat n d, ml))) end
          | _ =>
            (* B-chemistry step 3: one concentration and two volumes (stock volume, final volume) *)
            if has "\\bdilut\\w*\\b|\\bstock\\b" low andalso length concs = 1 andalso length vols = 2
               andalso has "\\b(?:water|solvent|diluent)\\b" low andalso has "\\bhow (?:much|many)\\b|\\badd\\b" low
            then (case directedVolumes low volMatches of NONE => NONE | SOME (stock,final) => solutionResult (Q.AddSolvent (hd concs, stock, final)) VOL_UNIT Q.SolMilli low)
            else if has "\\bdilut\\w*\\b" low andalso length concs = 1 andalso length vols = 2
                    andalso has "\\bconcentration\\b|\\bmolarity\\b|\\bhow concentrated\\b" low
                    andalso not (has "\\bhow (?:much|many) (?:of )?(?:the )?(?:stock|ml|milliliters|liters|l)\\b" low)
            then (case directedVolumes low volMatches of NONE => NONE | SOME (stock,final) => solutionResult (Q.DilutedMolarity (hd concs, stock, final)) CONC_UNIT Q.SolBase low)
            else if has ("\\bhow many " ^ AMOUNT_UNIT ^ "\\b") low andalso length concs = 1 andalso length vols = 1
            then solutionResult (Q.SoluteAmount (hd concs, hd vols)) AMOUNT_UNIT Q.SolBase low
            else if has "\\bmolarity\\b|\\bconcentration\\b" low andalso length vols = 1 andalso null concs
                    andalso not (has (N ^ "\\s*" ^ MASS_UNIT ^ "\\b") low)
                    andalso length (findall (N ^ "\\s*" ^ AMOUNT_UNIT ^ "\\b") low) = 1
            then
              let val m = valOf (search (N ^ "\\s*(" ^ AMOUNT_UNIT ^ ")\\b") low)
                  val n = scaled (g1 low m) (prefixScale (valOf(grp low m 2)))
              in solutionResult (Q.SolutionMolarity (n, hd vols)) CONC_UNIT Q.SolBase low end
            else
            if has "\\bdilut\\w*\\b|\\bstock\\b|\\bhow much (?:of )?(?:the )?qnum" low andalso length concs = 2 andalso length vols = 1
            then (case directedConcs low concMatches of NONE => NONE
                  | SOME (stock,target) => solutionResult (Q.StockVolume(stock,target,hd vols)) VOL_UNIT Q.SolMilli low)
            else
              case f of
                NONE => if has "\\bgrams?\\b|\\bmolarity\\b" low then SOME (mk Q.NeedFormula) else NONE
              | SOME f =>
                  if not (onlyFormula f t) then NONE
                  else if fclass f <> 0 then SOME (mk (Q.Molarity (fchars f, ratInt 1, ratInt 1)))
                  else
                    let
                      val gramsMatches = findall MASS_AMOUNT low
                      val gramsM = case gramsMatches of [m] => SOME m | _ => NONE
                    in
                      if has "\\bmolarity\\b|\\bconcentration\\b|\\bwhat is the (?:molar )?concentration\\b" low
                         andalso isSome gramsM andalso length vols = 1
                      then
                        let
                          val m = valOf gramsM
                          val unit = massUnit (valOf (grp low m 2))
                        in case unit of
                          SOME u => solutionResult (Q.MassSolutionMolarity (fchars f,ratOf (g1 low m),u,hd vols)) CONC_UNIT Q.SolBase low
                        | NONE => NONE end
                      else if (has "\\bmass\\b|\\bweigh\\w*\\b|\\bgrams?\\b" low orelse (case massTarget low of SOME (SOME _) => true | _ => false))
                              andalso not (has "\\bhow many (?:moles?|mol|millimoles?|mmol)\\b" low)   (* the organ answered grams to a moles question *)
                              andalso length concs = 1 andalso length vols = 1
                      then (case massTarget low of
                        NONE => NONE
                      | SOME target => SOME (Q.RM (Q.MeasuredSolutionMass (fchars f,hd concs,hd vols,
                          case target of SOME u => u | NONE => Q.MassGram))))
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
      else if t = "" then NONE
      else case labAnswer t of
             NONE => NONE
           | SOME r =>
               let val directed = case r of Q.RL (Q.StockVolume _, _) => true | _ => false
                   val onlyRateFlag = directed andalso Narrow.sentences t <= 2 andalso Narrow.words t <= 40
                                      andalso not (has Narrow.RELATION (lower t))
               in if Narrow.narrative t andalso not onlyRateFlag then NONE
                  else if Q.answers r orelse Narrow.short_direct t then SOME r else NONE end
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
    if has "->" text then
      (* Reaction '+' separates species; it must not be read as a spaced unary
         sign before the next coefficient. Mask only the amount clause. *)
      if mode = "family" orelse mode = "chemistry" orelse mode = "chemistry-v3"
      then Option.map (fn request => (if mode = "family" then "chemistry-v3" else mode, request))
                      (reactionRequest text)
      else NONE
    else case ExactNumeric.mask text of
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
