(* UNTRUSTED lexical adapter. Exact arithmetic here is ordinary SML, not a HOL
   theorem. A caller must bind each token to its quantity role and check its
   domain; a negative token is preserved, never silently made positive.

   Byte spans are half-open [start, stop). scan reports malformed numeric runs
   as a whole and never retries their tails. Units may immediately follow a
   token (.5m, 2MPa, 1e3kg); numbers embedded in identifiers or isotope names
   (H2O, carbon-14) are not tokens. A trailing period/comma is punctuation.
   parse accepts only a whole numeric literal, without surrounding whitespace.

   Grammar: signed decimal, optional scientific exponent; or one such literal
   divided by another. Commas require groups of exactly three digits after a
   first group of one to three digits. Unicode minus U+2212 is an explicit sign.
   Resource limits are deliberate: callers receive Malformed above either cap. *)
structure ExactNumeric :
sig
  type rational = IntInf.int * IntInf.int
  datatype token = Number of {start : int, stop : int, value : rational}
                 | Malformed of {start : int, stop : int, reason : string}
  val maxDigits : int
  val maxExponent : int
  val at : string -> int -> token option
  val scan : string -> token list
  val parse : string -> rational option
  val canonical : rational -> string
  val normalize : string -> string option
  val mask : string -> {text : string, numbers : (string * rational) list} option
end =
struct
  type rational = IntInf.int * IntInf.int
  datatype token = Number of {start : int, stop : int, value : rational}
                 | Malformed of {start : int, stop : int, reason : string}
  val maxDigits = 4096
  val maxExponent = 10000
  exception Bad of string
  val unicodeMinus = "\226\136\146"
  fun digit c = c >= #"0" andalso c <= #"9"
  fun alpha c = (c >= #"a" andalso c <= #"z") orelse (c >= #"A" andalso c <= #"Z")
  fun minusAt s i = i >= 0 andalso i + 3 <= size s
                    andalso String.substring (s, i, 3) = unicodeMinus
  fun normalizeMinus s =
    let fun go i acc =
          if i >= size s then String.concat (rev acc)
          else if minusAt s i then go (i + 3) ("-" :: acc)
          else go (i + 1) (String.str (String.sub (s, i)) :: acc)
    in go 0 [] end
  fun allDigits s = size s > 0 andalso List.all digit (String.explode s)
  fun integer s =
    if allDigits s then valOf (IntInf.fromString s) else raise Bad "expected digits"
  fun gcd (a : IntInf.int, b : IntInf.int) =
    if b = 0 then a else gcd (b, IntInf.mod (a, b))
  fun reduced (n : IntInf.int, d : IntInf.int) =
    if d = 0 then raise Bad "zero denominator"
    else let val g = gcd (IntInf.abs n, IntInf.abs d)
             val sign = if d < 0 then ~1 else 1
         in (IntInf.div (n, g) * sign, IntInf.div (d, g) * sign) end
  fun splitSign s =
    if size s = 0 then raise Bad "missing number"
    else case String.sub (s, 0) of
           #"-" => (~1 : IntInf.int, String.extract (s, 1, NONE))
         | #"+" => (1 : IntInf.int, String.extract (s, 1, NONE))
         | _ => (1 : IntInf.int, s)
  fun wholeDigits s =
    case String.fields (fn c => c = #",") s of
      [one] => if allDigits one then one else raise Bad "invalid integer part"
    | first :: rest =>
        if allDigits first andalso size first <= 3
           andalso List.all (fn group => size group = 3 andalso allDigits group) rest
        then String.concat (first :: rest)
        else raise Bad "invalid comma grouping"
    | [] => raise Bad "missing integer part"
  fun decimal literal =
    let
      val (sign, unsigned) = splitSign literal
      val (mantissa, exponent) =
        case String.fields (fn c => c = #"e" orelse c = #"E") unsigned of
          [m] => (m, 0)
        | [m, e] =>
            let val (es, digits) = splitSign e
                val amount = integer digits
                val _ = if amount <= IntInf.fromInt maxExponent then ()
                        else raise Bad "exponent exceeds resource limit"
            in (m, IntInf.toInt (es * amount)) end
        | _ => raise Bad "multiple exponents"
      val (ip, fp) =
        case String.fields (fn c => c = #".") mantissa of
          [i] => (wholeDigits i, "")
        | [i, f] =>
            if not (allDigits f) then raise Bad "invalid fractional part"
            else (if i = "" then "0" else wholeDigits i, f)
        | _ => raise Bad "multiple decimal points"
      val numerator = sign * integer (ip ^ fp)
      val scale = size fp - exponent
    in if scale >= 0 then reduced (numerator, IntInf.pow (10, scale))
       else reduced (numerator * IntInf.pow (10, ~scale), 1)
    end
  fun trim s =
    let val n = size s
        fun left i = if i < n andalso Char.isSpace (String.sub (s, i)) then left (i + 1) else i
        fun right i = if i > 0 andalso Char.isSpace (String.sub (s, i - 1)) then right (i - 1) else i
        val a = left 0
        val b = Int.max (a, right n)
    in String.substring (s, a, b - a) end
  fun value literal =
    let val s = normalizeMinus literal
        val _ = if size s <= maxDigits * 2 + 16 andalso
                   length (List.filter digit (String.explode s)) <= maxDigits
                then () else raise Bad "digit count exceeds resource limit"
    in case String.fields (fn c => c = #"/") s of
         [one] => decimal one
       | [left, right] =>
           let val (ln, ld) = decimal (trim left)
               val (rn, rd) = decimal (trim right)
           in reduced (ln * rd, ld * rn) end
       | _ => raise Bad "multiple fraction slashes"
    end

  fun blockedLeft s i =
    i > 0 andalso
      (let val c = String.sub (s, i - 1)
       in alpha c orelse digit c orelse Char.contains "_.,+-/~)]}^" c
          orelse Char.ord c >= 128 end)
  fun signAt s i = i < size s andalso
    (Char.contains "+-" (String.sub (s, i)) orelse minusAt s i)
  fun signWidth s i = if minusAt s i then 3 else 1
  fun skipSpace s i =
    if i < size s andalso Char.isSpace (String.sub (s, i)) then skipSpace s (i + 1) else i
  fun numericAhead s i =
    i < size s andalso
      (digit (String.sub (s, i)) orelse
       (String.sub (s, i) = #"." andalso numericAhead s (i + 1)) orelse
       (signAt s i andalso numericAhead s (skipSpace s (i + signWidth s i))))
  fun starts s i =
    i >= 0 andalso i < size s andalso not (blockedLeft s i) andalso numericAhead s i
  fun runEnd s i =
    let fun go j =
          if j >= size s then j
          else if minusAt s j then go (j + 3)
          else let val c = String.sub (s, j)
               in if c = #"-" andalso j > i andalso j + 1 < size s
                     andalso alpha (String.sub (s, j + 1)) then j
                  else if digit c orelse Char.contains ".,+-/_" c then go (j + 1)
                  else if c = #"e" orelse c = #"E" then
                    (* eV is a unit suffix; e3 and e+3 are exponents. A bare e
                       is malformed. Quantity roles still belong to callers. *)
                    if j + 1 < size s andalso alpha (String.sub (s, j + 1))
                    then j else go (j + 1)
                  else j
               end
    in go i end
  fun trimPunctuation s start stop =
    if stop > start andalso Char.contains ".," (String.sub (s, stop - 1))
    then stop - 1 else stop
  fun at s i =
    if not (starts s i) then NONE
    else let
      fun fractions stop =
        let val slash = skipSpace s stop
        in if stop > i andalso String.sub (s, stop - 1) = #"/" andalso slash > stop
           then let val finish = runEnd s slash
                in if finish > slash then fractions finish else stop end
           else if slash < size s andalso String.sub (s, slash) = #"/"
           then let val rhs = skipSpace s (slash + 1)
                    val finish = runEnd s rhs
                in if finish > rhs then fractions finish else rhs end
           else stop end
      val first = if signAt s i then skipSpace s (i + signWidth s i) else i
      val spacedSign = signAt s i andalso first <> i + signWidth s i
      val rawStop = fractions (runEnd s (if spacedSign then first else i))
      val stop = trimPunctuation s i rawStop
      val literal = String.substring (s, i, stop - i)
    in SOME (if spacedSign then Malformed {start = i, stop = rawStop, reason = "space after sign"}
        else Number {start = i, stop = stop, value = value literal}
        handle Bad reason => Malformed {start = i, stop = rawStop, reason = reason})
    end
  fun scan s =
    let fun go i acc =
          if i >= size s then rev acc
          else case at s i of
                 NONE => go (i + 1) acc
               | SOME (token as Number {stop, ...}) => go stop (token :: acc)
               | SOME (token as Malformed {stop, ...}) => go stop (token :: acc)
    in go 0 [] end
  fun parse s =
    case at s 0 of
      SOME (Number {stop, value, ...}) => if stop = size s then SOME value else NONE
    | _ => NONE
  fun canonical pair =
    let val (n, d) = reduced pair
        fun signed n = if n < 0 then "-" ^ IntInf.toString (~n) else IntInf.toString n
    in signed n ^ (if d = 1 then "" else "/" ^ IntInf.toString d) end
  (* Rendering convenience only: un-tokenized structural digits (m^3, records)
     remain in the text. Regex role readers must use mask and issued-value
     lookup, or bind original scan spans; normalize alone is not provenance. *)
  fun normalize s =
    let fun go pos [] acc = SOME (String.concat (rev (String.extract (s, pos, NONE) :: acc)))
          | go _ (Malformed _ :: _) _ = NONE
          | go pos (Number {start, stop, value} :: rest) acc =
              go stop rest (canonical value :: String.substring (s, pos, start - pos) :: acc)
    in go 0 (scan s) [] end
  (* Placeholders let a role recognizer use (qnum[0-9]+q), without another
     number grammar. Each generated marker is absent from the ASCII-case-folded original text;
     callers must resolve captures through numbers, never trust a user marker. *)
  fun mask s =
    let
      val folded = String.map Char.toLower s
      fun fresh i =
        let val marker = "qnum" ^ Int.toString i ^ "q"
        in if String.isSubstring marker folded then fresh (i + 1) else (marker, i + 1) end
      fun go pos _ [] text numbers =
            SOME {text = String.concat (rev (String.extract (s, pos, NONE) :: text)),
                  numbers = rev numbers}
        | go _ _ (Malformed _ :: _) _ _ = NONE
        | go pos next (Number {start, stop, value} :: rest) text numbers =
            let val (marker, after) = fresh next
            in go stop after rest
                 (marker :: String.substring (s, pos, start - pos) :: text)
                 ((marker, value) :: numbers) end
    in go 0 0 (scan s) [] [] end

end
