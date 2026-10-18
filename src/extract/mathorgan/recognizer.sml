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
  exception Reject of string
  val organs : string list
  val recognize : string -> string -> (string * Mathkernel.prequest) option
end =
struct
  structure K = Mathkernel
  exception Reject of string

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
        | go (({start, stop, ...} : Regex.match) :: ms) s =
            go ms (String.substring (s, 0, start) ^ stripCommas (String.substring (s, start, stop - start))
                   ^ String.extract (s, stop, NONE))
    in go ms s end

  (* Shared exact numeric adapter; role binding remains untrusted. *)
  fun ratOf lit = case ExactNumeric.parse lit of
      SOME (n,d) => K.mk_rat n d
    | NONE => raise Reject "Malformed exact numeric literal."

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
  datatype tok = Word of string | Digits of string | Sp of string | Punct of char
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

  (* AffineParser and the checked affine kernel now own complete equation
     requests. This legacy request interface no longer reduces coefficients
     in untrusted SML or supplies an echo-veto list. *)
  fun algebraRoute _ = NONE

  (* ---------- op: integer_sqrt / gcd_lcm / unit_convert ---------- *)
  val SQRT_TRIG = "\\b(?:square root|sqrt|perfect square)\\b"
  val GCD_TRIG = "\\b(?:gcd|greatest common (?:divisor|factor)|hcf)\\b"
  val LCM_TRIG = "\\b(?:lcm|least common multiple|lowest common multiple)\\b"

  (* Keep the sign and validate the ENTIRE numeral. Int.fromString accepted
     a decimal prefix and overflowed at machine-word size in the scout. These
     are integer operators, so noninteger and multi-argument square-root
     questions are a recognizer refusal, never a silently changed request. *)
  fun integerInputs low expected =
    let
      val ms = findall "(?<![a-z0-9_.+-])([-+]?\\d+(?:\\.\\d+)?)(?![a-z0-9_.])" low
      val lits = map (g1 low) ms
      val badSyntax = has "[/]|[0-9][eE][-+]?[0-9]|[-+]\\s+\\d|\226\136\146" low
      fun one lit = if has "^[-+]?\\d+$" lit then valOf (IntInf.fromString lit)
                    else raise Reject "This route requires whole-number inputs."
    in
      if badSyntax orelse length lits <> expected then
        raise Reject "This route needs an unambiguous list of whole-number inputs."
      else map one lits
    end

  fun sqrtRoute low =
    if not (has SQRT_TRIG low) then NONE
    else
      case integerInputs low 1 of
        [n] =>
          let val perfect = has "perfect square" low
              val input = K.Int_of_integer n
              val exact = n < 0 orelse perfect orelse has "\\binteger\\b" low
                orelse K.value_lit (K.reply_of (K.Ask (K.Sqrt (input, true)))) = SOME "yes"
          in if exact then SOME (K.Ask (K.Sqrt (input, perfect)))
             else raise Reject "This route computes integer square roots; it does not give an exact irrational root."
          end
      | _ => NONE

  fun gcdRoute low =
    if not (has GCD_TRIG low orelse has LCM_TRIG low) then NONE
    else
      case integerInputs low 2 of
        [a, b] => SOME (K.Ask (K.GcdLcm (K.nat_of_integer (IntInf.abs a),
                                        K.nat_of_integer (IntInf.abs b), has LCM_TRIG low)))
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
    List.concat (List.mapPartial (fn m => Option.map String.explode (grp low m 1)) (findall UNIT_TOK low))
    @ List.concat (List.mapPartial (fn m => Option.map String.explode (grp low m 2)) (findall UNIT_TOK low))

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
        else if not (String.isSubstring "=" low) andalso length cqn >= 3 andalso spanHasLetter low then
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
             SOME r => SOME r
           | NONE =>
               (case route ("ops", opsRoute) of
                  SOME r => SOME r
                | NONE =>
                    (case route ("word", wordRoute) of
                       SOME r => SOME r
                     | NONE => route ("guards", guardRoute)))
    end
end
