(* UNTRUSTED. The English recognizer for the word-problem organ: a hand port
   of upstream/root/wander-train/word_problems_v1.py (called by fold w488's
   dispatch, printed by w488, pluralised by w490). It reads numbers, units and
   trigger words off the question and builds a typed Wordprob.wp request list
   plus the "round to the nearest ..." digit count; it computes nothing. Every
   value, decline and response text comes from the verified HOL kernel
   (Wordprob.reply_of'). Geometry and motion are handled only by measured.sml;
   their old unit-erasing adapters have been removed. An empty request list is the organ abstaining; two or
   more entries is two schemas reading the problem differently, which the
   organ also abstains on (the kernel decides; this file just lists what
   fired).

   Case handling, matching the organ exactly: patterns the organ compiles with
   re.I run with Regex.compile over lower-cased text; patterns the organ
   compiles case-SENSITIVELY (the quantity reader's "percent", the "$X off"
   look, the word-number years) run with Regex.compileCS over the original
   text, so upper-case text does not match them, as in Python.

   Guards the organ gets from exceptions (a schema raising ZeroDivisionError
   is skipped exactly like a schema that does not fire) are enforced here, so
   the request list is what the organ's SCHEMAS loop would have collected: a
   unit-price count above one (the organ's own filter), a nonzero whole for
   percent-of-total, a nonzero time for motion speed. NOT modelled: Python's
   float arithmetic (the kernel computes exact rationals) and math.isfinite
   (an exact rational is always finite; the organ can only leave the finite
   range through float overflow, which no panel question reaches). *)
structure Recognizer :
sig
  exception Reject of string
  val answer : string -> bool * (IntInf.int option * Wordprob.wp list)
  val unitOf : string -> (Wordprob.mkind * Wordprob.wunit) option
  val questionPart : string -> string
  val roundingOf : string -> IntInf.int option
end =
struct
  structure Q = Wordprob
  exception Reject of string

  val cache : (string * Regex.regex) list ref = ref []
  fun lower s = String.map Char.toLower s
  fun re p =
    case List.find (fn (q, _) => q = p) (!cache) of
      SOME (_, r) => r
    | NONE => let val r = Regex.compile p in cache := (p, r) :: !cache; r end
  fun reX p = Regex.compileCS p   (* case-sensitive: not cached, rare *)

  fun search p s = Regex.search (re p) s
  fun has p s = isSome (search p s)
  fun findall p s = Regex.findall (re p) s
  fun findallX p s = Regex.findall (reX p) s
  fun grp s m g = Regex.group s m g
  fun g1 s m = valOf (grp s m 1)
  fun g2 s m = valOf (grp s m 2)

  fun collapse s = String.concatWith " " (String.tokens Char.isSpace s)

  (* Shared full-literal exact parser; no decimal-prefix conversion. *)
  fun parts lit = case ExactNumeric.parse lit of SOME q => q
    | NONE => raise Fail ("malformed numeral " ^ lit)
  fun ratOf lit = let val (n, d) = parts lit in Q.mk_rat n d end
  (* U+2212 MINUS SIGN (UTF-8 e2 88 92) -> "-", as the organ's quantities() *)
  val minus = "\226\136\146"
  fun substMinus s =
    let val n = size s
        fun go i = if i + 3 > n then []
                   else if String.substring (s, i, 3) = minus then i :: go (i + 3)
                   else go (i + 1)
        val spots = go 0
        fun put [] j acc = String.substring (s, j, n - j) :: acc
          | put (i :: is) j acc = put is (i + 3) ("-" :: String.substring (s, j, i - j) :: acc)
    in String.concat (rev (put spots 0 [])) end

  (* ---------------- negative givens ---------------------------------------
     The organ's quantity reader takes the numeral and drops a sign in front of
     it ("-60 km" is read as 60 km). The kernel's requests are unsigned, so the
     sign cannot be carried; instead the recognizer reports whether any numeral
     the reader consumed had a minus sign directly in front of it (ASCII
     hyphen or U+2212), standing at the start of the text or after a space,
     an opening bracket or a dollar sign. The kernel then declines
     (Wordprob.negative_given_declines). A hyphen between two numerals or
     inside a word ("5-6", "twenty-five") has a digit or letter before it and
     does not count. UNTRUSTED like the rest of this file: its completeness is
     checked over the core panel by score_core.py, not proved. *)
  fun negativeGiven (t : string) : bool =
    let
      val tt = substMinus t
      fun signBefore (m : Regex.match) =
        let val p = #start m in
          p >= 1 andalso String.sub (tt, p - 1) = #"-"
          andalso (p = 1 orelse
                   (let val c = String.sub (tt, p - 2)
                    in Char.isSpace c orelse c = #"(" orelse c = #"$" end))
        end
      (* the digits themselves, so that "$-5" and "-5" are both seen: the
         reader's own match may begin at the "$" *)
      val digitRuns = Regex.findall (Regex.compileCS "\\d") tt
      fun runStarts [] _ = []
        | runStarts (m :: ms) prevStop =
            (if #start m = prevStop then [] else [m]) @ runStarts ms (#stop m)
    in List.exists signBefore (runStarts digitRuns ~1) end

  (* ---------------- quantities(): the organ's typed quantity reader -------- *)

  datatype qtag = TMoney | TPercent | TRate | TUnit of Q.mkind | TCount
  type quant = {tag : qtag, v : Q.rat, num : IntInf.int, den : IntInf.int,
                unit : Q.wunit option, word : string option, pos : int}

  val NUM = "(\\d{1,3}(?:,\\d{3})+(?:\\.\\d+)?|\\d+(?:\\.\\d+)?)"
  (* the organ's reader is case-sensitive (no re.I), so it runs exact *)
  val QTY_RX = "(\\$\\s?)?" ^ NUM ^ "\\s*(%|percent\\b)?\\s*([A-Za-z]+(?:/[A-Za-z]+)?)?"

  val WORDNUMS = [("one", 1), ("two", 2), ("three", 3), ("four", 4), ("five", 5),
                  ("six", 6), ("seven", 7), ("eight", 8), ("nine", 9), ("ten", 10),
                  ("eleven", 11), ("twelve", 12), ("twenty", 20), ("thirty", 30),
                  ("forty", 40), ("fifty", 50), ("hundred", 100)]
  val WORDNUM_ALT = String.concatWith "|" (map #1 WORDNUMS)

  fun rstripDots s =
    if size s > 0 andalso String.sub (s, size s - 1) = #"."
    then rstripDots (String.extract (s, 0, SOME (size s - 1))) else s

  (* unit_of: the organ walks its four tables in order (length, mass, volume,
     time), and for each table tries the word, its minus-s and minus-es forms *)
  fun lookupUnit (cand : string) (k : Q.mkind) : Q.wunit option =
    case List.find (fn (n, (k', u)) => n = cand andalso k' = k) Q.unit_table of
      SOME (_, (_, u)) => SOME u | NONE => NONE
  val MKINDS = [Q.Mlength, Q.Mmass, Q.Mvolume, Q.Mtime]
  fun unitOf (word : string) : (Q.mkind * Q.wunit) option =
    let
      val w = rstripDots (lower word)
      val cands = [w]
        @ (if String.isSuffix "s" w then [String.extract (w, 0, SOME (size w - 1))] else [])
        @ (if String.isSuffix "es" w then [String.extract (w, 0, SOME (size w - 2))] else [])
      fun tryGroup k = case List.mapPartial (fn c => lookupUnit c k) cands of
                         x :: _ => SOME (k, x) | [] => NONE
    in case List.mapPartial tryGroup MKINDS of x :: _ => SOME x | [] => NONE end

  fun quantities (t : string) : quant list =
    let
      val tt = substMinus t
      val ms = findallX QTY_RX tt
      fun one (m : Regex.match) =
        let
          val pos = #start m
          val (num, den) = parts (g2 tt m)
          val v = Q.mk_rat num den
        in
          if isSome (grp tt m 1) then {tag = TMoney, v = v, num = num, den = den,
                                       unit = NONE, word = NONE, pos = pos}
          else if isSome (grp tt m 3) then {tag = TPercent, v = v, num = num, den = den,
                                            unit = NONE, word = NONE, pos = pos}
          else (case grp tt m 4 of
              SOME wd =>
                if Char.contains wd #"/"
                then {tag = TRate, v = v, num = num, den = den,
                      unit = NONE, word = SOME (lower wd), pos = pos}
                else (case unitOf wd of
                        SOME (k, u) => {tag = TUnit k, v = v, num = num, den = den,
                                        unit = SOME u, word = NONE, pos = pos}
                      | NONE => {tag = TCount, v = v, num = num, den = den,
                                 unit = NONE, word = SOME (lower wd), pos = pos})
            | NONE => {tag = TCount, v = v, num = num, den = den,
                       unit = NONE, word = NONE, pos = pos})
        end
      val numbered = map one ms
      (* word numbers, re.I, in WORDNUM order; everything then sorted by position *)
      val worded =
        List.concat (map (fn (w, n) =>
            map (fn m => {tag = TCount, v = Q.mk_rat n 1, num = n, den = 1,
                          unit = NONE, word = NONE, pos = #start m})
                (findall ("\\b" ^ w ^ "\\b") (lower tt))) WORDNUMS)
      fun ins (x : quant, []) = [x]
        | ins (x, y :: ys) = if #pos x <= #pos y then x :: y :: ys else y :: ins (x, ys)
    in foldl (fn (x, acc) => ins (x, acc)) [] (numbered @ worded) end

  (* question_part(): split after . ? ! on whitespace, keep the last part that
     asks (ends in ? or starts find/what/how/determine/calculate, re.I), else
     the last part; always lower-cased *)
  fun splitSentences (s : string) : string list =
    let
      val n = size s
      fun isSD c = c = #"." orelse c = #"?" orelse c = #"!"
      fun skipWs i = if i < n andalso Char.isSpace (String.sub (s, i)) then skipWs (i + 1) else i
      fun go i start acc =
        if i >= n then rev (String.substring (s, start, n - start) :: acc)
        else if Char.isSpace (String.sub (s, i)) andalso i > start andalso isSD (String.sub (s, i - 1))
        then go (skipWs i) (skipWs i) (String.substring (s, start, i - start) :: acc)
        else go (i + 1) start acc
    in go 0 0 [] end
  fun asksWord (p : string) : bool = has "^(?:find|what|how|determine|calculate)\\b" (lower p)
  fun questionPart (t : string) : string =
    let
      val parts = splitSentences t
      val asking = List.filter (fn p => String.isSuffix "?" p orelse asksWord p) parts
      val chosen = case asking of [] => List.last parts | _ => List.last asking
    in lower chosen end

  fun ofTag (f : quant -> bool) qs = List.filter f qs
  val moneyQ = ofTag (fn {tag = TMoney, ...} => true | _ => false)
  val pctQ = ofTag (fn {tag = TPercent, ...} => true | _ => false)
  val rateQ = ofTag (fn {tag = TRate, ...} => true | _ => false)
  val countQ = ofTag (fn {tag = TCount, ...} => true | _ => false)
  fun kindQ k = ofTag (fn {tag = TUnit k', ...} => k = k' | _ => false)
  fun integral ({num, den, ...} : quant) = num mod den = 0
  fun gt1 ({num, den, ...} : quant) = num > den

  (* comma-grouped {:,.0f} / {:,.2f} of a numeral, for the "$X off" look;
     truncating at two decimals, which only differs from Python's rounding for
     inputs no text writes after a dollar sign *)
  fun commas0 (n : IntInf.int) : string =
    let fun go n = if n < 1000 then [IntInf.toString n]
                   else go (n div 1000) @ [StringCvt.padLeft #"0" 3 (IntInf.toString (n mod 1000))]
    in String.concatWith "," (go n) end
  fun moneyFmt (q : quant) : string =
    let val {num, den, ...} = q in
      if integral q then commas0 (num div den)
      else commas0 (num div den) ^ "." ^ StringCvt.padLeft #"0" 2 (IntInf.toString ((num * 100) div den mod 100))
    end
  fun rxEscape s = String.translate (fn c => if Char.isAlphaNum c then String.str c else "\\" ^ String.str c) s

  (* ---------------- legacy non-measured schemas, in the organ's order -----
     Each takes (t, tl, q, qs): original text, lower-cased text, lower-cased
     question part, quantity list. NONE = did not fire. *)

  fun sSimpleInterest (t, tl, q, qs) =
    if not (has "interest" tl) orelse not (has "how much interest|interest (?:was|did|will)" q)
    then NONE
    else
      let
        val money = moneyQ qs
        val pct = pctQ qs
        val yrsDigits = List.filter (fn {tag = TUnit Q.Mtime, unit = SOME u, ...} => Q.uname u = "year"
                                      | _ => false) qs
        (* word-number years: case-sensitive on the original text *)
        val yrsWords = map (fn m => case List.find (fn (w', _) => w' = g1 t m) WORDNUMS of
                                       SOME (_, n) => Q.mk_rat n 1
                                     | NONE => raise Fail "wordnum")
                           (findallX ("\\b(" ^ WORDNUM_ALT ^ ")\\s+years?") t)
        val yrs = if null yrsDigits then yrsWords else map #v yrsDigits
      in
        if length money <> 1 orelse length pct <> 1 orelse length yrs <> 1 then NONE
        else SOME (Q.SimpleInterest (#v (hd money), #v (hd pct), hd yrs))
      end

  fun sUnitPrice (t, tl, q, qs) =
    if not (has "how much (?:does|did|is) (?:each|one|a single)|cost of (?:each|one)|price (?:of|per) (?:each|one)" q)
    then NONE
    else
      let
        val money = moneyQ qs
        val counts = List.filter (fn c => integral c andalso gt1 c) (countQ qs)
      in
        if length money <> 1 orelse length counts <> 1 then NONE
        else SOME (Q.UnitPrice (#v (hd money), #v (hd counts)))
      end

  fun sTotalCost (t, tl, q, qs) =
    if has "\\beach\\b|\\bone\\b" q then NONE
    else if not (has "how much (?:did|does|will|would) .{0,40}(?:pay|cost|spend)|total cost|how much .{0,20}(?:all|in all)" q)
    then NONE
    else
      let
        val money = moneyQ qs
        val counts = List.filter integral (countQ qs)
      in
        if length money <> 1 orelse length counts <> 1
           orelse not (has "\\beach\\b|\\bper\\b|\\bapiece\\b" tl)
        then NONE
        else SOME (Q.TotalCost (#v (hd counts), #v (hd money)))
      end

  fun sSalePrice (t, tl, q, qs) =
    if not (has "sale price|new price|price after|how much .{0,30}after the discount" q) then NONE
    else
      let
        val money = moneyQ qs
        val pct = pctQ qs
        val offWord = has "\\boff\\b|discount" tl
        (* "$40 off" on the text, "40 off" on the comma-stripped text, both
           case-sensitive; %g of the exact value through the kernel's g6r *)
        fun isOff (mq : quant) =
          isSome (Regex.search (reX ("\\$\\s?" ^ rxEscape (moneyFmt mq) ^ "\\s*off")) t)
          orelse let val tc = String.translate (fn #"," => "" | c => String.str c) t
                 in isSome (Regex.search (reX (rxEscape (Q.g6r (#v mq)) ^ "\\s*off")) tc) end
      in
        if length money = 2 andalso null pct andalso offWord then
          let val off = List.filter isOff money
              val orig = List.filter (not o isOff) money
          in if length off = 1 andalso length orig = 1
             then SOME (Q.SaleOff (#v (hd orig), #v (hd off))) else NONE end
        else if length money = 1 andalso length pct = 1 andalso offWord
        then SOME (Q.SalePct (#v (hd money), #v (hd pct)))
        else NONE
      end

  fun sPercentOfTotal (t, tl, q, qs) =
    if not (has "what percent" q) then NONE
    else
      let val nums = ofTag (fn {tag = TMoney, ...} => true | {tag = TCount, ...} => true
                             | {tag = TUnit Q.Mlength, ...} => true
                             | {tag = TUnit Q.Mmass, ...} => true
                             | {tag = TUnit Q.Mvolume, ...} => true | _ => false) qs
      in
        case nums of
            (* the organ divides by the larger, which raises on two zeros: skip *)
            [{num = n1, v = w1, ...}, {num = n2, v = w2, ...}] =>
              if n1 = 0 andalso n2 = 0 then NONE
              else SOME (Q.PercentOfTotal (w1, w2))
          | _ => NONE
      end

  fun sPercentOf (t, tl, q, qs) =
    case search ("what is " ^ NUM ^ "\\s*(?:%|percent) of \\$?\\s?" ^ NUM) tl of
      SOME m => SOME (Q.PercentOf (String.isSubstring "$" t, ratOf (g1 tl m), ratOf (valOf (grp tl m 2))))
    | NONE => NONE

  fun sConvert (t, tl, q, qs) =
    case search "how many ([a-z]+)" q of
      SOME m => (case unitOf (g1 q m) of
          SOME (k, to) =>
            let val src = List.filter (fn x => (case #tag x of TUnit k' => k = k' | _ => false)
                                              andalso #unit x <> SOME to) qs
            in if length src <> 1 orelse length qs <> 1 then NONE
               else case #unit (hd src) of
                      SOME from => SOME (Q.Convert (#v (hd src), from, to))
                    | NONE => NONE
            end
        | NONE => NONE)
    | NONE => NONE

  (* ---------------- answer(): the organ's own control flow ---------------- *)

  val MULTISTEP =
    "\\b(?:left|remain(?:s|ing)?|change|faster|slower|longer|shorter|minus|except|more than|less than|times a (?:day|week)|every (?:day|week|month|year)|each of the|house is|twice|triple|then|after that|in addition|altogether|combined)\\b"

  fun roundingOf (tl : string) : IntInf.int option =
    case search "round(?:ed)?\\s+(?:your answer\\s+)?to\\s+(?:the\\s+nearest\\s+)?(\\w+)" tl of
      SOME m => (case g1 tl m of
                   "tenth" => SOME 1 | "hundredth" => SOME 2 | "thousandth" => SOME 3
                 | "whole" => SOME 0 | "cent" => SOME 2 | "dollar" => SOME 0
                 | "one" => SOME 1 | "two" => SOME 2 | _ => NONE)
    | NONE => NONE

  fun answer (text : string) : bool * (IntInf.int option * Q.wp list) =
    let
      val t = collapse text
      (* The legacy schemas still bind their original decimal syntax. Reject a
         full shared token they would truncate; measured schemas support the
         broader shared grammar through numeric masks. *)
      fun validateNumbers () = List.app (fn ExactNumeric.Malformed _ =>
                    raise Reject "A numeric input is malformed or exceeds the supported range."
                | ExactNumeric.Number {start,stop,...} =>
                    let val literal = String.substring(t,start,stop-start)
                        val plain = substMinus literal
                    in if has ("^[-+]?" ^ NUM ^ "$") plain then ()
                       else raise Reject "This word-problem schema does not yet support that numeric notation." end)
                (ExactNumeric.scan t)
      val tl = lower t
      val q = questionPart t
      val qs = quantities t
    in
      if has MULTISTEP tl then (false, (NONE, []))
      else
        let
          val hits = List.mapPartial (fn f => f (t, tl, q, qs))
            [sSimpleInterest, sUnitPrice, sTotalCost, sSalePrice, sPercentOfTotal,
             sPercentOf, sConvert]
          val _ = if null hits then () else validateNumbers ()
        in (negativeGiven t, (roundingOf tl, hits)) end
    end
end
