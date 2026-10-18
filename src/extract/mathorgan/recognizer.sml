(* UNTRUSTED. The English recognizer for the head mathematics route: a hand
   port of the question-reading layers of Oracle7's chain,
     upstream/root/wander-train/oracle_release_runtime_w55.py    (algebra host:
        _extract scans outward from '=' over math characters; linear sides in x)
     upstream/root/wander-train/oracle_operator_specs_v{1,2}.py  (op: integer_sqrt,
        gcd_lcm, unit_convert: triggers, parses, and the unit table _TO_BASE)
     upstream/root/wander-train/word_problems_v1.py + w488     (organ:math>word:
        s_percent_of, s_convert, and the word-unit tables TIME/MASS)
     upstream/root/wander-train/math_organ_v3.py                 (the math-token
        classifier _is_math_word, ported for the guards' letter features)
     the precision-guard folds w511 (P7), w513 (Q1), w514 (R1), w516 (R6),
        w533 (G4 unthousand, G5 echo, G6 units-not-variables)
   It reads numbers and words off the question and builds a typed Mathkernel
   prequest; it computes nothing. Every value, decline, reply text and path
   comes from the HOL kernel (Mathkernel.reply_of). NONE means the route is
   not taken. What is ported by hand, and so untrusted, is the patterns, the
   branch order and the guard feature extraction.

   The w-chain's G4 fold strips thousands separators before routing ("2,025"
   is one number), so this recognizer does too. Matching is case-insensitive
   on lower-cased text; \w and \d are ASCII. *)
structure Recognizer :
sig
  val organs : string list
  val recognize : string -> string -> (string * Mathkernel.prequest) option
end =
struct
  structure K = Mathkernel

  val cache : (string * Regex.regex) list ref = ref []
  fun lower s = String.map Char.toLower s
  fun re p =
    case List.find (fn (q, _) => q = p) (!cache) of
      SOME (_, r) => r
    | NONE => let val r = Regex.compile p in cache := (p, r) :: !cache; r end

  fun search p s = Regex.search (re p) s
  fun has p s = isSome (search p s)
  fun findall p s = Regex.findall (re p) s
  fun grp s m g = Regex.group s m g
  fun g1 s m = valOf (grp s m 1)

  fun collapse s = String.concatWith " " (String.tokens Char.isSpace s)

  fun eraseAll p s =
    let
      fun go i [] acc = String.concat (rev (String.extract (s, i, NONE) :: acc))
        | go i (({start, stop, ...} : Regex.match) :: ms) acc =
            go stop ms (String.substring (s, i, start - i) :: acc)
    in go 0 (findall p s) [] end

  (* G4 (w533): "2,025" is one number; only digit + 3-digit groups *)
  val THOUSANDS = "(?<![\\d,.])(\\d{1,3})((?:,\\d{3})+)(?![\\d,])"
  fun unthousand s =
    let
      val ms = rev (findall THOUSANDS s)
      fun stripCommas t = String.translate (fn #"," => "" | c => String.str c) t
      fun go [] s = s
        | go ({start, stop, ...} : Regex.match :: ms) s =
            go ms (String.substring (s, 0, start) ^ stripCommas (String.substring (s, start, stop - start))
                   ^ String.extract (s, stop, NONE))
    in go ms s end

  (* "1,000.50" -> mk_rat 100050 100, exactly; "-12.5" allowed *)
  fun ratOf (lit0 : string) : K.rat =
    let
      val lit = String.translate (fn #"," => "" | c => String.str c) lit0
      val (neg, body) = if String.isPrefix "-" lit then (true, String.extract (lit, 1, NONE))
                        else (false, lit)
      val (ip, fp) = case String.fields (fn c => c = #".") body of
                       [a] => (a, "")
                     | [a, b] => (a, b)
                     | _ => raise Fail ("bad numeral " ^ lit0)
      val num = valOf (IntInf.fromString (ip ^ fp))
      val den = IntInf.pow (10, size fp)
    in K.mk_rat (if neg then IntInf.~ num else num) den end

  fun intOf s = valOf (Int.fromString (String.translate (fn #"," => "" | c => String.str c) s))

  val NUM = "(\\d+(?:,\\d{3})*(?:\\.\\d+)?)"

  (* content words for the guard rules (Q1/R1/R6): 3+ letter words minus the
     stop list *)
  val STOPS = ["what", "the", "is", "was", "are", "and", "how", "which", "who"]
  fun contentWords t =
    let
      val ws = map (fn m => Regex.whole t m) (findall "[a-z]{3,}" t)
    in List.filter (fn w => not (List.exists (fn s => s = w) STOPS)) ws end

  (* the math-token classifier of the evaluate organ (math_organ_v3), ported
     so the guards' letter features match the organ's own reading:
     - a single letter (but a/i between spaces) is a variable;
     - a 2-3 letter run is a product only when GLUED to mathematics;
     - a word longer than 3 letters is English;
     - a number or an operator is mathematics; a bare sentence '.' is not. *)
  datatype tok = Word of string | Digits of string | Sp of string | Punct of string
  fun toks low =
    let
      val ms = findall "([a-z]+)|(\\d+(?:\\.\\d+)?)|(\\s+)|(.)" low
      fun one m =
        case (grp low m 1, grp low m 2, grp low m 3) of
          (SOME w, _, _) => Word w
        | (NONE, SOME d, _) => Digits d
        | (NONE, NONE, SOME s) => Sp s
        | _ => Punct (String.sub (low, #start m))
    in map one ms end

  fun glued (prev : tok option, nxt : tok option) =
    let
      fun leftGlued (Word _) = false | leftGlued (Digits _) = true
        | leftGlued (Sp _) = false | leftGlued (Punct _) = true
      fun rightGlued (Sp _) = false
        | rightGlued (Word _) = false
        | rightGlued (Punct c) = not (Char.contains ".,?!;:" c)
        | rightGlued (Digits _) = true
    in
      (case prev of SOME t => leftGlued t | NONE => false)
      orelse (case nxt of SOME t => rightGlued t | NONE => false)
    end

  fun isMathTok (prev, t, nxt) =
    case t of
      Word w =>
        if size w = 1 then not (w = "a" orelse w = "i")
        else if size w > 3 then false
        else glued (prev, nxt)
    | Digits _ => true
    | Sp _ => true
    (* a sentence end (and the colon, which the organ rewrites to one) breaks *)
    | Punct c => c <> #"." andalso c <> #":"

  (* every maximal math span (joined tokens); the organ keeps a span only
     when it has a digit *)
  fun spans low =
    let
      val ts = toks low
      fun at i = if i >= 0 andalso i < length ts then SOME (List.nth (ts, i)) else NONE
      fun tokText (Word w) = w | tokText (Digits d) = d | tokText (Sp _) = " " | tokText (Punct c) = String.str c
      fun flat cur = String.concat (map tokText (rev cur))
      fun go _ [] cur acc = rev (if null cur then acc else flat cur :: acc)
        | go i (t :: ts) cur acc =
            if isMathTok (at (i - 1), t, at (i + 1))
            then go (i + 1) ts (t :: cur) acc
            else go (i + 1) ts [] (if null cur then acc else flat cur :: acc)
      fun existsDigit s = List.exists Char.isDigit (String.explode s)
    in List.filter existsDigit (go 0 ts [] []) end

  (* the letters of the digit spans (what the evaluator would read as
     variables), and whether any digit span carries a letter at all *)
  fun spanLetters low =
    let val ss = spans low
    in List.concat (map (String.explode o String.translate (fn c => if Char.isAlpha c then String.str c else "")) ss) end
  fun spanHasLetter low = List.exists Char.isAlpha (spanLetters low)

  (* ---------- algebra host (w55) ---------- *)
  (* the characters the equation scan admits: digits, operators, brackets,
     space, and the three variables x y z *)
  fun okChar c =
    Char.isDigit c orelse Char.contains "+-*/^(). " c
    orelse c = #"x" orelse c = #"y" orelse c = #"z"
  (* scan outward from the first '=' over okChar only (w55._extract) *)
  fun extractEq low =
    case String.index (low, #"=") of
      NONE => NONE
    | SOME e =>
        let
          val left = String.substring (low, 0, e)
          val right = String.extract (low, e + 1, NONE)
          fun back i = if i > 0 andalso okChar (String.sub (left, i - 1)) then back (i - 1) else i
          fun fwd j = if j < size right andalso okChar (String.sub (right, j)) then fwd (j + 1) else j
          val lo = back (size left)
          val hi = fwd 0
          val lhs = collapse (String.substring (left, lo, size left - lo))
          val rhs = collapse (String.substring (right, 0, hi))
        in
          if lhs = "" orelse rhs = "" then NONE else SOME (lhs, rhs)
        end

  (* "a x + b" with rational a b: [num]x, [num]x + num, a bare number, x *)
  datatype lin = Lin of K.rat * K.rat
  fun parseLin t =
    let
      fun rat s = ratOf (String.translate (fn #"*" => "" | c => String.str c) s)
    in
      case search "^\\s*(-?\\d+\\.?\\d*)?\\s*x\\b" t of
        SOME m =>
          let
            val a = case grp t m 1 of SOME s => rat s | NONE => K.mk_rat 1 1
            val rest = String.extract (t, #stop m, NONE)
          in
            case search "^\\s*([+-])\\s*(\\d+\\.?\\d*)" rest of
              SOME m2 =>
                let val mag = valOf (grp rest m2 2)
                in SOME (Lin (a, rat (if g1 rest m2 = "-" then "-" ^ mag else mag))) end
            | NONE => if collapse rest = "" then SOME (Lin (a, K.mk_rat 0 1)) else NONE
          end
      | NONE =>
          (case search "^\\s*(-?\\d+\\.?\\d*)\\s*$" t of
             SOME m => SOME (Lin (K.mk_rat 0 1, rat (g1 t m)))
           | NONE => NONE)
    end

  fun algebraRoute low =
    let
      val hasVar = has "(?<![a-z])[xyz](?![a-z])" low
      val ask = has "\\b(?:solve|simplify|collect|expand|what is [xyz]\\b|find [xyz]\\b|value of [xyz]\\b)" low
      val looksAlgebraic = hasVar andalso (isSome (String.index (low, #"=")) orelse ask)
      val hasDigit = has "\\d" low
    in
      if not (looksAlgebraic andalso hasDigit) then NONE
      else
        case extractEq low of
          NONE => NONE
        | SOME (lhs, rhs) =>
            (case (parseLin lhs, parseLin rhs) of
               (SOME (Lin (a, b)), SOME (Lin (c, d))) =>
                 (* the values the question itself states (the echo guard's
                    givens): every "x = v" in the text *)
                 let
                   val gs = map ratOf (List.mapPartial (fn m => grp low m 1)
                                       (findall "(?<![a-z])x\\s*=\\s*(-?\\d+\\.?\\d*)" low))
                 in SOME (K.Ask (K.SolveLin a b c d gs)) end
             | _ => NONE)
    end

  (* ---------- op: integer_sqrt / gcd_lcm / unit_convert ---------- *)
  val SQRT_TRIG = "\\b(?:square root|sqrt|perfect square)\\b"
  val GCD_TRIG = "\\b(?:gcd|greatest common (?:divisor|factor)|hcf)\\b"
  val LCM_TRIG = "\\b(?:lcm|least common multiple|lowest common multiple)\\b"

  fun nonNeg s = not (String.isPrefix "-" s)

  (* Isabelle's code-generation int is a wrapper; nat needs a conversion *)
  fun codeInt s = K.Int_of_integer (IntInf.fromInt (intOf s))
  fun codeNat s = K.nat_of_integer (IntInf.fromInt (intOf s))

  fun sqrtRoute low =
    if not (has SQRT_TRIG low) then NONE
    else
      case List.find (nonNeg o g1 low) (findall ("-?" ^ NUM) low) of
        SOME m => SOME (K.Ask (K.Sqrt (codeInt (g1 low m), has "perfect square" low)))
      | NONE => NONE

  fun gcdRoute low =
    if not (has GCD_TRIG low orelse has LCM_TRIG low) then NONE
    else
      case map (g1 low) (findall NUM low) of
        [a, b] => SOME (K.Ask (K.GcdLcm (codeNat a, codeNat b, has LCM_TRIG low)))
      | _ => NONE

  (* the op conversion table is _TO_BASE: only these stems are the op's; any
     other unit word ("kilograms", "milligrams") is NotOurs there and falls
     through to the word-problem organ *)
  val opUnits = ["mm", "cm", "m", "km", "inch", "inches", "foot", "feet", "mile", "miles",
                 "yard", "yards", "mg", "g", "kg", "tonne", "pound", "pounds", "ounce",
                 "ounces", "second", "seconds", "minute", "minutes", "hour", "hours",
                 "day", "days", "week", "weeks"]
  fun isOpUnit u = List.exists (fn x => x = u) opUnits

  fun convUnitOf u =
    case u of
      "second" => SOME K.T_second | "seconds" => SOME K.T_second
    | "minute" => SOME K.T_minute | "minutes" => SOME K.T_minute
    | "hour" => SOME K.T_hour | "hours" => SOME K.T_hour
    | "day" => SOME K.T_day | "days" => SOME K.T_day
    | "week" => SOME K.T_week | "weeks" => SOME K.T_week
    | "year" => SOME K.T_year | "years" => SOME K.T_year
    | "milligram" => SOME K.M_milligram | "milligrams" => SOME K.M_milligram
    | "gram" => SOME K.M_gram | "grams" => SOME K.M_gram
    | "kilogram" => SOME K.M_kilogram | "kilograms" => SOME K.M_kilogram
    | "ounce" => SOME K.M_ounce | "ounces" => SOME K.M_ounce
    | "pound" => SOME K.M_pound | "pounds" => SOME K.M_pound
    | _ => NONE

  (* _UNIT_RX: "N unit in|to|into|as unit"; _UNIT_RX_REV: "how many unit (are )?in|to N unit" *)
  val CONV_FWD = "(-?\\d+(?:\\.\\d+)?)\\s*([a-z]+)\\s+(?:in|to|into|as)\\s+([a-z]+)\\b"
  val CONV_REV = "how many\\s+([a-z]+)\\s+(?:are\\s+)?(?:in|to)\\s+(-?\\d+(?:\\.\\d+)?)\\s*([a-z]+)\\b"

  fun opConvRoute low =
    let
      fun conv (num, fromW, toW) =
        if isOpUnit fromW andalso isOpUnit toW then
          (case (convUnitOf fromW, convUnitOf toW) of
             (SOME a, SOME b) => SOME (K.OpConv (ratOf num, a, b, fromW, toW))
           | _ => NONE)
        else NONE
    in
      case search CONV_REV low of
        SOME m => conv (valOf (grp low m 2), valOf (grp low m 3), g1 low m)
      | NONE =>
          (case search CONV_FWD low of
             SOME m => conv (g1 low m, valOf (grp low m 2), valOf (grp low m 3))
           | NONE => NONE)
    end

  (* ---------- organ:math>word (word_problems_v1 + w488) ---------- *)
  val PCT_OF = "what is " ^ NUM ^ "\\s*(?:%|percent) of \\$?\\s?" ^ NUM
  (* s_convert: "how many U ..." with U a word unit; the panel's shapes have
     "are there in" / "are in", which the op host's tighter pattern does not
     reach - and word units like "kilograms" are not the op's stems at all *)
  val WORD_CONV = "how many\\s+([a-z]+)\\s+(?:are\\s+there\\s+)?(?:are\\s+)?in\\s+(-?\\d+(?:\\.\\d+)?)\\s+([a-z]+)\\b"

  fun percentRoute low =
    case search PCT_OF low of
      SOME m => SOME (K.Ask (K.PercentOf (ratOf (g1 low m), ratOf (valOf (grp low m 2)))))
    | NONE => NONE

  fun wordConvRoute low =
    case search WORD_CONV low of
      SOME m =>
        let val (toW, num, fromW) = (g1 low m, valOf (grp low m 2), valOf (grp low m 3))
        in
          (* the op host had first claim and declined; the word organ takes
             any unit its own tables carry *)
          case (convUnitOf fromW, convUnitOf toW) of
            (SOME a, SOME b) => SOME (K.WordConv (ratOf num, a, b, toW))
          | _ => NONE
        end
    | NONE => NONE

  (* ---------- the precision guards ----------
     In the chain these fire on the reply the evaluate route gave; on the
     shapes that reach them here that reply is a letter product (or a bare
     number), and the organ's own token classifier - ported above - decides
     which. Order is the chain's: P7 (w511), Q1 (w513), R1 (w514), R6 (w516),
     then the reply guards G6/G5 (w533). *)
  val P7_UNITS = "m\\b|meters?\\b|metres?\\b|km\\b|kilometers?\\b|miles?\\b|kg\\b|kilograms?\\b|grams?\\b|seconds?\\b|minutes?\\b|hours?\\b|liters?\\b|litres?\\b"
  val P7_GIVEN = "(?:^|(?<=\\s))-\\s?\\d+(?:\\.\\d+)?\\s*(?:" ^ P7_UNITS ^ ")"
  val SYMBOLIC_CUE = "[\\^=]|\\bfactor\\b|\\bsimplify\\b|\\bsolve\\b|\\bexpand\\b|\\bevaluate\\b"
  val ALGEBRA = "\\b(?:simplify|expand|factori[sz]e|factor|solve|expression|polynomial|derivative|differentiate|integral|integrate|equation|variable|function)\\b|\\d[a-z](?![a-z])|(?<![a-z/])[a-z](?![a-z/])\\s*[\\^=+*<>]|[\\^=+*(]\\s*[a-z](?![a-z/])|\\$"
  val UNIT_TOK = "\\d\\s*([a-zA-Z]{1,3}(?:/[a-zA-Z]{1,3}\\d?)?)\\b|\\bin\\s+([a-zA-Z]{1,3}/[a-zA-Z]{1,3}\\d?)\\b"
  val COMPUTE_RX = "\\b(?:compute|evaluate|simplify|calculate|solve)\\b"
  (* the formula shapes: a physical or geometric quantity asked on English words *)
  val FORMULA_Q = "\\b(?:area|perimeter|circumference|volume|density|kinetic energy|potential energy|momentum|mass|weight|speed|velocity)\\b"
  val AS_DECIMAL = "^\\s*what is (\\d+)\\s*/\\s*(\\d+) as an? (?:decimal|percentage|percent)\\s*\\?\\s*$"

  fun unitLetters low =
    List.concat (map (fn m => List.mapPartial (fn s => Option.map String.explode s) [grp low m 1, grp low m 2])
                      (findall UNIT_TOK low))

  fun guardRoute low =
    if has FORMULA_Q low then
      let
        val cq = contentWords low
        val nq = eraseAll UNIT_TOK low
        val cqn = contentWords nq
        val vls = spanLetters low
        val uls = unitLetters low
      in
        if not (has SYMBOLIC_CUE low) andalso has P7_GIVEN low then
          SOME (K.GuardP7 (true, false))
        else if not (has "[+\\-*/^=]" low) andalso length cq >= 3 andalso spanHasLetter low then
          SOME (K.GuardQ1 (true, true))
        else if not (isSome (String.index (low, #"="))) andalso length cqn >= 3 andalso spanHasLetter low then
          SOME (K.GuardR1 (true, true))
        else if not (has "[=+*/^]" low) andalso not (has COMPUTE_RX low) andalso length cq >= 4 then
          SOME (K.GuardR6 (true, true))
        else if not (has ALGEBRA low) andalso spanHasLetter low
                andalso List.all (fn c => List.exists (fn d => d = c) uls) vls then
          (* G6: the organ's reply is the question's own unit letters *)
          SOME (K.GuardG6 (map String.str vls, map String.str uls, true))
        else NONE
      end
    else
      (* G5: the fraction echo - the organ echoed the question's own fraction *)
      (case search AS_DECIMAL low of
         SOME _ => SOME (K.GuardG5 (true, true))
       | NONE => NONE)

  (* ---------- dispatch, in the chain's order ----------
     algebra (w55) is innermost; then the op host (w59); then the word-problem
     fold (w488); the guard folds (w511+) wrap all of them. *)
  val organs = ["algebra", "ops", "word", "guards"]

  fun opsRoute low =
    case sqrtRoute low of
      SOME r => SOME r
    | NONE =>
        (case gcdRoute low of
           SOME r => SOME r
         | NONE => opConvRoute low)

  fun wordRoute low =
    case percentRoute low of
      SOME r => SOME r
    | NONE => wordConvRoute low

  fun recognize (mode : string) (text : string) : (string * K.prequest) option =
    let
      val t = collapse (unthousand text)
      val low = lower t
      fun route (name, f) =
        if mode <> "family" andalso mode <> name then NONE
        else case f low of SOME r => SOME (name, r) | NONE => NONE
    in
      if t = "" then NONE
      else case route ("algebra", algebraRoute) of
             SOME r => r
           | NONE =>
               (case route ("ops", opsRoute) of
                  SOME r => r
                | NONE =>
                    (case route ("word", wordRoute) of
                       SOME r => r
                     | NONE => route ("guards", guardRoute)))
    end
end
