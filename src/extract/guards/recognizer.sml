(* UNTRUSTED. The recognizer half of the precision-guard decision: it computes
   the regex-shaped features of Guards.thy's `feats` record from the raw
   (question, route, reply), mirroring the Python guard functions fold by fold.
   The kernel (Guards.thy, exported) consumes them; it never sees raw text.

   Every feature carries a comment naming the Python it mirrors. Sources:
   upstream/root/fable-content/oracle-m-series-2026-08-15/self_loop/admitted/
   oracle_release_runtime_w51{0,1,3,4,6}.py, w53{2,3,4}.py.

   Case policy: Python regexes with re.I run against the lower-cased text (the
   shared matcher lower-cases pattern literals at compile, so a pattern matched
   against lowered text behaves like re.I). Python patterns WITHOUT re.I that
   need capitals (w510's of-phrase and specifics word walk, w514's R5 shape,
   w533's unit tokens) are hand-coded scanners over the raw text, because the
   shared matcher cannot express a case-sensitive class.

   Known divergences from Python, none of which touch the 114 panel items:
   - the Unicode minus (U+2212) of w532's NEG is read as the ASCII minus;
   - text is collapsed and lower-cased bytewise: Unicode whitespace and
     non-ASCII letters are not folded as Python's str.split/re.I fold them.
   (W5-15 fixed: w511's P1 and w510's quoted titles now match the curly quotes
   by codepoint; w510's quoted-title words keep their capitals; P1 reads the
   whole reply, not its first 300 characters.) *)
structure Recognizer =
struct

structure R = Regex

fun collapse s = String.concatWith " " (String.tokens Char.isSpace s)
fun lower s = String.map Char.toLower s
fun takeStr n s = String.substring (s, 0, Int.min (n, String.size s))
fun hasSub sub s = String.isSubstring sub s
fun strip s =
  let fun lead i = if i < String.size s andalso Char.isSpace (String.sub (s, i)) then lead (i + 1) else i
      fun trail i = if i > 0 andalso Char.isSpace (String.sub (s, i - 1)) then trail (i - 1) else i
      val a = lead 0
      val b = trail (String.size s)
  in if a >= b then "" else String.substring (s, a, b - a) end

(* ---- the kernel bridge: target strings <-> kernel char lists ---- *)

fun pow2 n = if n <= 0 then 1 else 2 * pow2 (n - 1)
fun bitsOf n = List.tabulate (8, fn i => (n div pow2 i) mod 2 = 1)
fun ichar c = Guards.mk_char (bitsOf (Char.ord c))
fun bitsOfS s = map (bitsOf o Char.ord) (String.explode s)
fun istr s = Guards.mk_str (bitsOfS s)
fun digitsToInt ds =
  let fun go ([], _, a) = a
        | go (b :: r, i, a) = go (r, i + 1, a + (if b then pow2 i else 0))
  in go (ds, 0, 0) end
fun cchar c = Char.chr (digitsToInt (Guards.digits_of c))
fun kstr cs = String.implode (map cchar cs)   (* a kernel char list, back to a target string *)
fun irat (n, d) = Guards.mk_rat n d     (* IntInf numerator and denominator *)

fun member x xs = List.exists (fn y => y = x) xs
fun dedupByKey key xs =
  let fun go ([], seen, acc) = List.rev acc
        | go (x :: r, seen, acc) =
            let val k = key x
            in if member k seen then go (r, seen, acc) else go (r, k :: seen, x :: acc) end
  in go (xs, [], []) end

fun sub1 rx s = Option.isSome (R.search rx s)
fun m1 rx s = Option.mapPartial (fn m => R.group s m 1) (R.search rx s)
fun fullmatch rx s =
  case R.matchHere rx s 0 of
    SOME m => #stop m = String.size s
  | NONE => false
fun findAll rx s = List.map (fn m => R.whole s m) (R.findall rx s)
fun matchAt0 rx s = Option.isSome (R.matchHere rx s 0)
fun subAll rx s =
  case R.search rx s of
    NONE => s
  | SOME m => subAll rx (String.concat [String.substring (s, 0, #start m), " ",
                                         String.extract (s, #stop m, NONE)])

(* ---- compiled patterns (the Python source in each comment) ---- *)

(* w510 WH: ^\s*(who|whom|...|has|have)\b with re.I *)
val whq = R.compile "^\\s*(who|whom|whose|what|what's|which|where|when|why|how|in what|in which|at what|on what|for what|from what|to what|by what|name the|determine|find|compute|calculate|solve|is|are|was|were|do|does|did|can|could|has|have)\\b"
(* w510/w516 CHAT (re.I): listener words *)
val chat = R.compile "\\b(you|your|yours|you're|you've|yourself|i|i'm|i've|i'd|me|my|mine|we|us|our|hi|hey|hello|excuse me|please|sir|madam|ma'am|mum|mom|dad|thanks|thank)\\b"
(* w511 ATTR (re.I) *)
val attr = R.compile "\\b(largest|longest|smallest|highest|hardest|tallest|biggest|deepest|fastest|oldest|first|last|most|least|symbol|capital|currency|population|velocity|speed|mass|weight|number|name|author|year|date|age|height|length|distance|temperature|density|boiling|melting|freezing|area|volume)\\b"
(* w511 P1's punctuation class on the captured title *)
val punct = R.compile "[{}();=<>]"
(* w511 NUMQ (re.I) *)
val numq = R.compile "^\\s*(how many|how much|how long|how far|how fast|how old|convert|calculate|compute)\\b|\\bin (?:degrees |square |cubic )?(?:newtons?|joules?|kilojoules?|watts?|kwh|kg|kilograms?|grams?|pounds?|meters?|metres?|km|kilometers?|centimeters?|miles?|seconds?|minutes?|hours?|days?|years?|liters?|litres?|milliliters?|dollars?|pascals?|amps?|volts?|ohms?|celsius|fahrenheit|kelvin|m/s|km/s|km/h|mph|m/s squared|kg per cubic meter|grams per mole|moles?)\\b"
(* w511's "what is the <quantity>" shape (re.I) *)
val whatThe = R.compile "^\\s*what(?:'s| is| was) the (?:kinetic |potential )?(area|volume|circumference|perimeter|energy|momentum|force|speed|velocity|density|mass|weight|power|resistance|current|pressure|work|cost|price|average|mean|hypotenuse|ph|square root|cube root|sum|product|value)\\b"
(* w511 P2's number words in the reply (re.I) *)
val numword = R.compile "\\b(zero|none|no|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|twenty|thirty|hundred|thousand|million|billion|dozen|half)\\b"
(* w511 P7 premise: a negative physical given, case-sensitive on the raw question *)
val negPhys = R.compile "(?:^|(?<=\\s))-\\s?\\d+(?:\\.\\d+)?\\s*(m\\b|meters?\\b|metres?\\b|km\\b|kilometers?\\b|miles?\\b|kg\\b|kilograms?\\b|grams?\\b|seconds?\\b|minutes?\\b|hours?\\b|liters?\\b|litres?\\b)"
(* w511 P7 exemption (re.I) *)
val symbolic = R.compile "[\\^=]|\\bfactor|\\bsimplify|\\bsolve|\\bexpand|\\bevaluate"
(* w511 P7 private (re.I) *)
val priv7 = R.compile "^\\s*(what|what's|who|when|where|which|how old)\\b.*\\bmy (?:mother|father|mom|dad|best friend|friend|wife|husband|partner|sister|brother|boss|neighbou?r)'s (?:\\w+ )?(?:name|number|address|birthday|age|email|password)\\b"
(* w513 "read ...;" in the reply head *)
val readPh = R.compile "read ([^;]{1,60});"
val hasLetter = R.compile "[a-z]"
(* w513 Q1 operators/algebra (re.I) *)
val q1ops = R.compile "[+\\-*/^=]|\\b(simplify|evaluate|expression|expand|x|y|z)\\b"
(* w513 Q3 shape, on the lower-cased question *)
val q3shape = R.compile "^\\s*what(?:'s| is| was| are)\\s+the\\s+[a-z ]{2,30}?\\s+(?:of|for)\\s+([a-z][a-z\\-]{3,30})\\s*\\??\\s*$"
(* w514 R1: unit tokens removed first (re.I), then the ops check without +- *)
val unitTok14 = R.compile "\\b(?:m/s²|m/s\\^2|m/s|km/h|km/s|kg/m³|kg/m3|g/cm³|g/cm3|g/ml|mol|kwh)\\b"
val r1ops = R.compile "[=]|\\b(simplify|evaluate|expression|expand|factor|solve|x|y|z)\\b"
(* w516 factual gate *)
val whw = R.compile "\\b(who|whom|whose|what|which|where|when|how many|how much|how long|how old|how far)\\b"
val yesno = R.compile "^\\s*(?:is|are|was|were|do|does|did|can|could|has|have|had)\\b"
val followup = R.compile "^\\s*(?:what|how)\\s+about\\b|^\\s*and\\b"
val pronoun = R.compile "\\b(it|its|there|that|this|they|them|those|these|he|she|him|her|his|their|one)\\b"
val genYou = R.compile "\\b(?:what\\s+happens\\s+)?(?:if|when)\\s+you(?:r)?\\b|\\bwhat\\s+happens\\s+to\\s+you(?:r)?\\b|\\bcan\\s+you\\s+(?:get|catch|die|survive|see|tell\\s+if)\\b|\\bshould\\s+you\\b|\\bdo\\s+you\\s+need\\b"
(* w516 DEF_Q (re.I) *)
val defq = R.compile "^\\s*(?:what|who)(?:'s|\\s+is|\\s+are|\\s+was|\\s+were)\\s+(?:an?\\s+|the\\s+)?[a-z0-9][\\w\\-' ]{1,40}\\??\\s*$|^\\s*what\\s+does\\s+.{1,40}\\s+mean\\s*\\?\\s*$|\\b(explain|describe|summari[sz]e|tell me about|overview)\\b"
(* w516 R6 ops (re.I) *)
val r6ops = R.compile "[=+*/^]|\\b(compute|evaluate|simplify|calculate|solve)\\b"
(* w532 NEG (re.I): a negative number that is not a temperature *)
val negNum = R.compile "(?:^|(?<=[\\s(=:,]))-\\s?\\d+(?:\\.\\d+)?(?![\\d.])(?!\\s*(?:°|degrees?\\b|deg\\b|[cfk]\\b|celsius|fahrenheit|kelvin))"
(* w532 NEG_IN_REPLY *)
val negTok = R.compile "-\\s?\\d"
(* w532 PRIVATE (re.I) *)
val privA = R.compile "\\b(?:what(?:'s| is| are| was)|how (?:much|many)\\b.*?\\b(?:is|are|do|did|have)|when (?:is|was)|where (?:is|are))\\s+(?:in\\s+)?(?:the\\s+\\w+(?:\\s+\\w+)?\\s+of\\s+)?my\\b|\\bwhat (number|word|colou?r|card|letter|animal|thing) am i thinking\\b|\\bwhat am i thinking\\b|\\bwhat (?:did|do) i (?:have|eat|say|do)\\b"
(* w534 PRIVATE (re.I) and QUANTITY (re.I) *)
val privB = R.compile "\\b(?:what|what's|whats|who|whom|where|when|which|how\\s+(?:much|many|old|long))\\b[^?]*\\bmy\\s+(?:\\w+\\s+){0,2}?(?:social\\s+security(?:\\s+number)?|ssn|pin|password|passcode|passport(?:\\s+number)?|bank(?:\\s+account)?|account|balance|salary|income|address|phone(?:\\s+number)?|e-?mail|credit\\s+card|debit\\s+card|card|name|age|birthday|home|house|flat|apartment|car|boss|sister|brother|mother|mum|mom|father|dad|wife|husband|partner|son|daughter|friend|neighbou?r|dog|cat|pet|dreams?|lunch|dinner|breakfast|plans?|schedule|weight|height|blood\\s+type|code|key|lock|front\\s+door|country|city|town|street|school|job|work|company|team|doctor|bill|order|parcel|flight)\\b|\\bmy\\s+(?:social\\s+security(?:\\s+number)?|ssn|pin|password|passcode|passport(?:\\s+number)?|bank(?:\\s+account)?|account|balance|salary|income|address|phone(?:\\s+number)?|e-?mail|credit\\s+card|debit\\s+card|card|name|age|birthday|home|house|flat|apartment|car|boss|sister|brother|mother|mum|mom|father|dad|wife|husband|partner|son|daughter|friend|neighbou?r|dog|cat|pet|dreams?|lunch|dinner|breakfast|plans?|schedule|weight|height|blood\\s+type|code|key|lock|front\\s+door|country|city|town|street|school|job|work|company|team|doctor|bill|order|parcel|flight)'?s?\\s+(?:\\w+\\s+)?(?:is|are|was|were)\\s*\\?|\\bwhat\\s+(?:did|do|will|am|was|shall)\\s+i\\b(?!\\s+(?:need|have\\s+to|call|use)\\b)|\\bwhat\\s+(?:number|word|colou?r|card|letter|animal|thing|name)\\s+am\\s+i\\s+thinking\\b"
val quantity = R.compile "\\d+(?:\\.\\d+)?\\s*(?:%|kg|g|m|km|mi|miles?|mph|mpg|lbs?|cm|mm|l|litres?|liters?|kwh|kw|w|v|a|hours?|h|minutes?|min|days?|weeks?|months?|°|degrees?|\\$|dollars?|euros?|pounds?)\\b|\\$\\s?\\d"
(* w533 *)
val asDecimal = R.compile "\\bas an? (?:decimal|percentage|percent)\\b"
val fraction = R.compile "^\\s*-?\\d+\\s*/\\s*\\d+\\s*$"
val equation = R.compile "^\\s*([a-z])\\s*=\\s*(-?\\d+(?:\\.\\d+)?)\\s*$"
val algebra = R.compile "\\b(simplify|expand|factori[sz]e|factor|solve|expression|polynomial|derivative|differentiate|integral|integrate|equation|variable|function)\\b|\\d[a-z](?![a-z])|(?<![a-z/])[a-z](?![a-z/])\\s*[\\^=+*<>]|[\\^=+*(]\\s*[a-z](?![a-z/])|\\$"
(* w533 SUBSTANCE (re.I) and SKY (re.I) *)
val subst = R.compile "\\b\\d+(?:\\.\\d+)?\\s*(?:litres?|liters?|l|ml|millilitres?|milliliters?|grams?|g|kg|kilograms?|cubic\\s+\\w+|m3|cm3)\\s+of\\b"
val sky = R.compile "\\b(moons?|orbits?|orbiting|planets?|rings?|satellites?|spacecraft|probes?|telescope)\\b"
(* w514 CITE (for resp_r) and the leading [ev:...] tag (for resp_q) *)
val cite = R.compile "\\[ev:[a-z_]+\\]|\\[[a-z]+_[0-9a-f]{6,}\\]|\\[\\d+\\]"
val evTag = R.compile "^\\s*\\[ev:[a-z_]+\\]\\s*"
(* words of at least three letters *)
val word3 = R.compile "\\b[a-z]{3,}\\b"
(* w510 quoted titles *)
(* w510's quoted spans, re.finditer(r"[\"“'‘]([^\"”'’]{3,60})[\"”'’]", q): classes of
   CODEPOINTS, matched by hand over UTF-8 characters (quotedSpans, below) because
   the shared Regex matches bytes and a curly quote is three (W5-15). *)
fun utf8Chars s =      (* the string split into UTF-8 characters, each as its bytes *)
  let val n = String.size s
      fun cont i = i < n andalso Char.ord (String.sub (s, i)) >= 0x80 andalso Char.ord (String.sub (s, i)) < 0xC0
      fun go (i, acc) =
        if i >= n then List.rev acc
        else let fun stop j = if cont j then stop (j + 1) else j
                 val j = stop (i + 1)
             in go (j, String.substring (s, i, j - i) :: acc) end
  in go (0, []) end
fun quotedSpans q =
  let val cs = Vector.fromList (utf8Chars q)
      val n = Vector.length cs
      fun at i = Vector.sub (cs, i)
      val opens = ["\"", "\226\128\156", "'", "\226\128\152"]     (* " “ ' ‘ *)
      val closes = ["\"", "\226\128\157", "'", "\226\128\153"]    (* " ” ' ’ *)
      fun run (j, k) = if j < n andalso not (member (at j) closes) andalso k < 60 then run (j + 1, k + 1) else (j, k)
      fun scan (i, acc) =
        if i >= n then List.rev acc
        else if member (at i) opens then
          let val (j, k) = run (i + 1, 0)
          in if k >= 3 andalso j < n andalso member (at j) closes
             then scan (j + 1, String.concat (List.tabulate (k, fn t => at (i + 1 + t))) :: acc)
             else scan (i + 1, acc)
          end
        else scan (i + 1, acc)
  in scan (0, []) end
(* w510's word walk: [A-Za-z][A-Za-z0-9'\-]*|\d{4}, hand-coded like the other
   case-sensitive scanners *)
fun isUpperC c = #"A" <= c andalso c <= #"Z"
fun isDigitC c = #"0" <= c andalso c <= #"9"
fun anyWords q =
  let
    val n = String.size q
    fun isAl c = isUpperC c orelse (#"a" <= c andalso c <= #"z")
    fun wordch c = Char.isAlphaNum c orelse c = #"'" orelse c = #"-"
    fun go (i, acc) =
      if i >= n then List.rev acc
      else if isAl (String.sub (q, i)) then
        let fun take j = if j < n andalso wordch (String.sub (q, j)) then take (j + 1) else j
            val j = take (i + 1)
        in go (j, String.substring (q, i, j - i) :: acc) end
      else if i + 4 <= n andalso CharVector.all isDigitC (String.substring (q, i, 4)) then
        go (i + 4, String.substring (q, i, 4) :: acc)
      else go (i + 1, acc)
  in go (0, []) end

(* w510 STOP, lower-cased *)
val stop510 = ["a","an","the","of","in","on","at","to","for","from","by","with","and","or","but",
  "is","are","was","were","be","been","being","do","does","did","has","have","had","what",
  "which","who","whom","whose","where","when","why","how","that","this","these","those","it",
  "its","as","into","than","then","there","their","they","them","he","she","his","her","him",
  "we","our","you","your","i","me","my","not","no","yes","all","any","some","many","much",
  "more","most","one","two","first","name","called","known","type","kind"]

(* ---- the three reply heads ---- *)

fun respG3 reply = takeStr 300 (lower (collapse reply))

fun stripEv s =
  case R.search evTag s of
    NONE => s
  | SOME m => String.extract (s, #stop m, NONE)

fun respQ reply = takeStr 300 (lower (stripEv (collapse reply)))
fun respR reply = takeStr 300 (lower (collapse (subAll cite reply)))

(* ---- numbers (w511/w513/w514 NUM) as (numerator, denominator) ---- *)

val numPat = R.compile "(?<![\\w.])[-+]?(?:\\d{1,3}(?:,\\d{3})+|\\d+)(?:\\.\\d+)?(?:[eE][-+]?\\d+)?"

(* Arbitrary precision (IntInf): with the default 32-bit int, "26.09759007"
   (2,609,759,007 after scaling) raised Overflow and the binary returned an
   error line instead of a verdict (W5-15, two units-v3 replies on the core
   panel). Python's float() never overflows here; past the float range it gives
   inf or 0, so the decimal exponent is clamped to +-400 (a divergence only for
   numbers no reply prints). *)
fun parseNum t =
  let val t0 = String.translate (fn c => if c = #"," then "" else String.str c) t
      val (sign, r1) = if String.isPrefix "-" t0 then (~1 : IntInf.int, String.extract (t0, 1, NONE))
                       else if String.isPrefix "+" t0 then (1, String.extract (t0, 1, NONE))
                       else (1, t0)
      val (mant, expo) =
        case String.tokens (fn c => c = #"e" orelse c = #"E") r1 of
          [m] => (m, 0)
        | [m, e] => (m, Int.max (~400, Int.min (400, Option.getOpt (Int.fromString e, 0) handle Overflow => 0)))
        | _ => (r1, 0)
      val (ip, fp) =
        case String.tokens (fn c => c = #".") mant of
          [i] => (i, "")
        | [i, f] => (i, f)
        | _ => (mant, "")
      val ipV = Option.getOpt (IntInf.fromString (if ip = "" then "0" else ip), 0)
      val fpV = Option.getOpt (IntInf.fromString (if fp = "" then "0" else fp), 0)
      val fpLen = String.size fp
      fun pow10 n = IntInf.pow (10, n)
      val e10 = expo - fpLen
      val mag = ipV * pow10 fpLen + fpV
  in if e10 >= 0 then (sign * mag * pow10 e10, 1 : IntInf.int) else (sign * mag, pow10 (~e10)) end

fun ratsOf s = map (irat o parseNum) (findAll numPat s)
fun numPairsOf s = map parseNum (findAll numPat s)   (* the pairs behind the rats, for dumping *)

(* ---- w510: gate, specifics, of-phrases ---- *)

(* _question(q): q.rstrip().endswith("?") or WH.match(q) *)
fun question510 q =
  String.isSuffix "?" (collapse q) orelse matchAt0 whq (lower q)

fun gate510 q = not (sub1 chat (lower q)) andalso question510 q

fun stripApos s =
  let val n = String.size s
      fun lead i = if i < n andalso String.sub (s, i) = #"'" then lead (i + 1) else i
      fun trail i = if i > 0 andalso String.sub (s, i - 1) = #"'" then trail (i - 1) else i
      val a = lead 0
      val b = trail n
  in if a >= b then "" else String.substring (s, a, b - a) end

(* _specifics(q): quoted-title words, then the capitalised-word / 4-digit walk *)
fun specifics q =
  let
    val qs = q   (* raw text: capitals matter *)
    val quotedWords =
      (* re.findall(r"[A-Za-z0-9]+", group): ASCII letters of both cases (the shared
         Regex lower-cases the class and the text here is raw, so alnum1 dropped capitals) *)
      List.concat (map (String.tokens (fn c => not (isUpperC c orelse isDigitC c orelse (#"a" <= c andalso c <= #"z"))))
                       (quotedSpans qs))
    fun keep w = not (member (lower w) stop510) andalso String.size w > 2
    val words = anyWords qs
    fun walk ([], _) = []
      | walk (w :: r, i) =
          (if String.size w = 4 andalso CharVector.all isDigitC w then [w]
           else if i > 0 andalso String.size w > 0 andalso isUpperC (String.sub (w, 0))
                   andalso keep w then [w] else []) @ walk (r, i + 1)
    fun key w = lower (stripApos w)
    (* Python's _specifics returns the dedup keys themselves: w.lower().strip("'") *)
  in map key (dedupByKey key (List.filter keep quotedWords @ walk (words, 0))) end

(* "of (the)? <Proper Phrase>" groups: hand-coded, because the Python pattern
   (word "of", optional "the", then a chain of Capitalized words) needs a
   case-sensitive class *)
fun ofPhrases q =
  let
    val n = String.size q
    fun isWordish c = Char.isAlphaNum c orelse c = #"_"
    fun capAt i = i < n andalso isUpperC (String.sub (q, i))
    fun lowRun i =
      let fun go (j, k) = if j < n andalso #"a" <= String.sub (q, j) andalso String.sub (q, j) <= #"z"
                          then go (j + 1, k + 1) else (j, k)
      in go (i + 1, 0) end    (* at least one lowercase letter after the capital *)
    fun tryOf i =
      if i + 3 <= n andalso String.substring (q, i, 3) = "of "
         andalso (i = 0 orelse not (isWordish (String.sub (q, i - 1)))) then
        let val j0 = if i + 7 <= n andalso String.substring (q, i + 3, 4) = "the " then i + 7 else i + 3
            fun phrase j acc =
              if capAt j then
                let val (j', k) = lowRun j
                in if k >= 1 then
                     phrase (if j' < n andalso String.sub (q, j') = #" " andalso capAt (j' + 1)
                             then j' + 1 else j')
                           (String.substring (q, j, j' - j) :: acc)
                   else (j, acc) end
              else (j, acc)
            val (je, ws) = phrase j0 []
        in if null ws then NONE else SOME (String.concatWith " " (List.rev ws), je) end
      else NONE
    fun scan (i, acc) =
      if i >= n then List.rev acc
      else case tryOf i of
             SOME (ph, j) => scan (Int.max (j, i + 1), ph :: acc)
           | NONE => scan (i + 1, acc)
  in map (fn ph => map lower (String.tokens (fn c => c = #" ") ph)) (scan (0, [])) end

(* ---- w511 ---- *)

(* w511 NO_ENTRY.match(resp), its quoted group. Python's [\"“] and [^\"”]{1,120} are
   classes of CODEPOINTS; the shared Regex matches bytes, so a curly quote (three
   bytes in UTF-8) inside a class matched only its first byte and the real replies
   ("I have no admitted entry for “my passport number”") never matched (W5-15,
   found on the head's own replies; the synthesized fixtures used ASCII quotes).
   The prefix is matched by the regex; the quotes and the 1..120-codepoint group
   by hand. resp is the WHOLE collapsed reply (w511: " ".join(resp.split())),
   not the 300-character head the other folds read. *)
val noEntryHead = R.compile "^\\s*(?:\\[ev:[a-z_]+\\]\\s*)?i have no admitted (?:entry|record) for "
val openCurly = "\226\128\156"     (* U+201C “ *)
val closeCurly = "\226\128\157"    (* U+201D ” *)
fun bytesAt s i t = i + String.size t <= String.size s andalso String.substring (s, i, String.size t) = t
fun noEntryGroup s =
  case R.search noEntryHead s of
    NONE => NONE
  | SOME m =>
      let val n = String.size s
          val i = #stop m
          val start = if i < n andalso String.sub (s, i) = #"\"" then SOME (i + 1)
                      else if bytesAt s i openCurly then SOME (i + 3) else NONE
          fun cont c = Char.ord c >= 0x80 andalso Char.ord c < 0xC0   (* UTF-8 continuation byte *)
          fun scan (j, cps) =
            if j >= n then NONE
            else if String.sub (s, j) = #"\"" orelse bytesAt s j closeCurly then SOME (j, cps)
            else scan (j + 1, if cont (String.sub (s, j)) then cps else cps + 1)
      in case start of
           NONE => NONE
         | SOME a => (case scan (a, 0) of
                        SOME (j, cps) => if cps >= 1 andalso cps <= 120 then SOME (String.substring (s, a, j - a)) else NONE
                      | NONE => NONE)
      end

(* Finite complete equation surface, shared by the G5 request feature and
   P2 answer-type reconstruction. This is untrusted text recognition, not
   certificate verification. The route consumer checks affine packets before
   invoking guards; the standalone guards program does not check packets. *)
val solveQuestion = R.compile "^\\s*(?:(?:solve(?: for x)?|find x(?: if| given| when)?|what is (?:the value of )?x(?: if| given| when)?)\\s*:?\\s*)?([0-9xe,+ */().\226\136\146-]+)=([0-9xe,+ */().\226\136\146-]+?)(?:\\s+for x)?[?.]?\\s*$"
val equationCourtesy = R.compile "^(?:please\\s+|(?:can|could|would)\\s+you\\s+(?:please\\s+)?)(?=(?:solve|find|calculate|compute|evaluate)\\b)"
fun completeEquation q =
  let val text = lower(collapse q)
      val body = case R.search equationCourtesy text of
          SOME m => String.extract(text,#stop m,NONE) | NONE => text
  in sub1 solveQuestion body end

fun f511Of (q, route, reply, respG3low) =
  let val ql = lower q
      val ne = noEntryGroup (lower (collapse reply))
      val (neP, neA, neF) = case ne of
            NONE => (false, false, false)
          | SOME g => (true, sub1 attr g, not (sub1 punct g))
      val classification = collapse(stripEv(lower(collapse reply)))
      val solutionSet = route = "algebra:solved" andalso completeEquation ql andalso
        (classification = "every rational value of x satisfies this equation." orelse
         classification = "no rational value of x satisfies this equation.")
      val asksNum = (sub1 numq ql orelse matchAt0 whatThe ql) andalso not solutionSet
      val numwordHit = sub1 numword (lower (collapse reply))
  in Guards.F511 (sub1 negPhys q,        (* neg_phys_given *)
                  sub1 symbolic ql,      (* symbolic_cue *)
                  sub1 priv7 ql,         (* private_p7 *)
                  neP, neA, neF,         (* ne_present, ne_attr_hit, ne_punct_free *)
                  asksNum, numwordHit) end

(* ---- w513 ---- *)

fun f513Of (q, respQlow) =
  let val ql = lower q
      val mr = R.search readPh respQlow
      val (rp, rl) = case mr of
            NONE => (false, false)
          | SOME m => (true, case R.group respQlow m 1 of SOME g => sub1 hasLetter g | NONE => false)
      val shape = R.matchHere q3shape ql 0
      val subj = Option.mapPartial (fn m => R.group ql m 1) shape
  in Guards.F513 (rp, rl,                         (* read_present, read_has_letter *)
                  not (sub1 q1ops ql),            (* q1_ops_free *)
                  map istr (findAll word3 ql),    (* q_words13 *)
                  Option.isSome shape,            (* q3_shape *)
                  Option.map istr subj) end       (* subject_stem_q3 *)

(* ---- w514 ---- *)

(* "in what year did <Cap Word(s)> <verb>": case-sensitive, hand-coded.
   Group 1 (the subject) is the FIRST [A-Z][\w\-]+ word. *)
fun r5Subject q =
  let
    val n = String.size q
    val verbs = ["win","lose","invent","discover","defeat","conquer","beat","sign",
                 "land","arrive","die","found","build","first"]
    fun isWordChar c = Char.isAlphaNum c orelse c = #"_"
    fun skipWs i = if i < n andalso Char.isSpace (String.sub (q, i)) then skipWs (i + 1) else i
    fun prefixAt (i, p) =
      i + String.size p <= n andalso String.substring (q, i, String.size p) = p
    fun capWord i =
      if i < n andalso isUpperC (String.sub (q, i)) then
        let fun go j = if j < n andalso (isWordChar (String.sub (q, j)) orelse
                                         String.sub (q, j) = #"-") then go (j + 1) else j
            val j = go (i + 1)
        in if j > i + 1 then SOME (i, j) else NONE end
      else NONE
    fun verbAt k =
      let fun try [] = false
            | try (v :: vs) =
                prefixAt (k, v) andalso
                (k + String.size v >= n orelse not (isWordChar (String.sub (q, k + String.size v))))
                orelse try vs
      in try verbs end
    val i0 = skipWs 0
    (* (?i:in ) and (?i:what|which) are case-insensitive; " year did " and
       " the " outside them stay case-sensitive *)
    fun iprefixAt (i, p) =
      i + String.size p <= n andalso
      String.map Char.toLower (String.substring (q, i, String.size p)) = p
    val i1 = if iprefixAt (i0, "in ") then skipWs (i0 + 3) else i0
    val i2 = if iprefixAt (i1, "what ") orelse iprefixAt (i1, "which ") then i1 + 5 else ~1
    val i3 = if i2 >= 0 andalso prefixAt (i2, "year did ") then i2 + 9 else ~1
    val i4 = if i3 >= 0 andalso prefixAt (i3, "the ") then i3 + 4 else i3
  in
    if i4 < 0 then NONE
    else case capWord i4 of
           NONE => NONE
           | SOME (a, b) =>
               let
                   (* the subject is the first Cap word; further Cap words may
                      stand between it and the verb; stop where the verb's own
                      space begins *)
                   fun more k =
                     if k < n andalso Char.isSpace (String.sub (q, k)) then
                       (case capWord (skipWs k) of
                          SOME (_, b2) => more b2
                        | NONE => k)
                     else k
                   val k = more b
               in if k < n andalso Char.isSpace (String.sub (q, k)) andalso verbAt (skipWs k)
                  then SOME (String.substring (q, a, b - a)) else NONE end
  end

fun f514Of q =
  let val ql = lower q
      val qNoun = subAll unitTok14 ql
      val subj = r5Subject q
  in Guards.F514 (not (sub1 r1ops qNoun),       (* r1_ops_free *)
                  map istr (findAll word3 qNoun), (* q_words14 *)
                  Option.isSome subj,            (* r5_shape *)
                  Option.map (istr o lower) subj) end   (* subject_stem_r5; lowered: Python checks re.I against the head *)

(* ---- w516 ---- *)

(* w516 factual(q): a "?" question with a wh word or a yes/no opening, not
   conversation *)
fun factual516 q =
  let val ql = lower q
      val chatHit = sub1 chat ql
      val chatOk = if chatHit then not (sub1 chat (lower (subAll genYou q))) else true
  in String.isSubstring "?" q
     andalso (sub1 whw ql orelse matchAt0 yesno ql)
     andalso not (sub1 followup ql)
     andalso not (length (String.tokens Char.isSpace q) <= 8 andalso sub1 pronoun ql)
     andalso chatOk end

fun f516Of q =
  let val ql = lower q
  in Guards.F516 (factual516 q,                 (* factual_v8 *)
                  sub1 defq ql,                 (* def_q16 *)
                  matchAt0 yesno ql,            (* yesno_q16 *)
                  not (sub1 r6ops ql),          (* r6_ops_free *)
                  map istr (findAll word3 ql)) end

(* ---- w517 ---- *)

(* w517 GENERIC_YOU2 (re.I): the rest of the generic-you family *)
val genYou2 = R.compile "\\byour\\s+(?:own\\s+)?(?:dna|genes?|body|brain|skin|hair|heart|blood|teeth|tooth|eyes?|ears?|nose|stomach|liver|lungs?|bones?|muscles?|health|immune\\s+system|income|earnings|take-home|salary|pay|taxes|wages|savings|house|home|car|kids|children|child|baby|dog|cat|pet|fingers?|nails?|face|head|legs?|arms?|feet|hands?|knuckles|eyesight|vision|weight|coworkers?|co-workers?|boss|employer|landlord|neighbou?rs?|doctor|lawyer|bank|wallet|credit\\s+score)\\b|\\bhow\\s+(?:can|should|could)\\s+you\\s+(?!feel\\b|help\\b)\\w+|\\bwhat\\s+(?:will\\s+)?happens?\\s+(?:if|when)\\b|\\b(?:would|could|might|do|can)\\s+you\\s+(?:find|see|expect\\s+to\\s+(?:find|see)|call|measure)\\b|\\bare\\s+you\\s+(?:allowed|required|legally)\\b|\\bif\\s+you(?:'re|\\s+are)\\b"
(* w517 TRIVIA_NOQ (re.I) and OPEN_REQ (re.I) *)
val triviaNoq = R.compile "^\\s*(?:which|who|whom|whose|in\\s+which|in\\s+what|name\\s+the|name)\\b|\\b(?:which|whom|what)(?:\\s+[\\w'\\-]+){0,3}\\s*\\.?\\s*$"
val openReq = R.compile "^\\s*(?:what\\s+is|what's|what\\s+are|tell|explain|describe|give|list|write|show|make|create|compare|help|summari[sz]e|define|can|could|would|will|please|let's|lets)\\b"
val howB = R.compile "^\\s*how\\b"

fun rstripDots s =
  let val n = String.size s
      fun go i = if i > 0 andalso String.sub (s, i - 1) = #"." then go (i - 1) else i
  in String.substring (s, 0, go n) end

(* w517 factual2(q): w516's factual, or a generic-you question with '?', or
   trivia (5+ words, no '?') *)
fun factual2 q =
  if factual516 q then true
  else if String.isSubstring "?" q then
    (if not (sub1 chat (lower q)) then false
     else
       let val rest = lower (subAll genYou2 (subAll genYou q))
       in not (sub1 chat rest)
          andalso (sub1 whw (lower q) orelse matchAt0 yesno (lower q) orelse matchAt0 howB (lower q)) end)
  else
    length (String.tokens Char.isSpace q) >= 5
    andalso not (sub1 chat (lower q))
    andalso not (matchAt0 openReq (lower q))
    andalso sub1 triviaNoq (lower (rstripDots (strip q)))

fun f517Of q = Guards.F517 (factual2 q)

(* ---- w532 ---- *)

fun f532Of (q, reply) =
  let val ql = lower q
  in Guards.F532 (sub1 negNum ql,               (* neg_num_q *)
                  sub1 negTok reply,            (* neg_tok_resp *)
                  sub1 privA ql) end            (* private_g2a *)

(* ---- w533 ---- *)

(* math_value(reply): strip the [ev:...] tag, take up to the first sentence
   end (". " or a final "."), strip. *)
fun mathValue reply =
  let val t0 = stripEv (collapse reply)
      val n = String.size t0
      fun findDot i =
        if i >= n then NONE
        else if String.sub (t0, i) = #"." andalso (i = n - 1 orelse Char.isSpace (String.sub (t0, i + 1)))
        then SOME i
        else findDot (i + 1)
      val cut = case findDot 1 of SOME i => i | NONE => n
  in strip (String.substring (t0, 0, cut)) end

fun escapeRe s =
  String.translate (fn c => if Char.isAlphaNum c then String.str c else "\\" ^ String.str c) s
fun noSpaceLower s = lower (String.translate (fn c => if Char.isSpace c then "" else String.str c) s)

(* w533 UNIT_TOK letters, case-sensitive on the raw question, hand-coded:
   \d\s*([a-zA-Z]{1,3}(?:/[a-zA-Z]{1,3}\d?)?)\b | \bin\s+([a-zA-Z]{1,3}/[a-zA-Z]{1,3}\d?)\b *)
fun unitLetters q =
  let
    val n = String.size q
    fun isAl c = isUpperC c orelse (#"a" <= c andalso c <= #"z")
    fun isWordish c = Char.isAlphaNum c orelse c = #"_"
    fun takeLetters i k =
      let fun go (j, 0, acc) = (j, List.rev acc)
            | go (j, m, acc) =
                if j < n andalso isAl (String.sub (q, j))
                then go (j + 1, m - 1, String.sub (q, j) :: acc)
                else (j, List.rev acc)
      in go (i, k, []) end
    fun afterDigit i =
      let val k = if i + 1 < n andalso Char.isSpace (String.sub (q, i + 1))
                  then (let fun sp m = if m < n andalso Char.isSpace (String.sub (q, m)) then sp (m + 1) else m
                        in sp (i + 1) end)
                  else i + 1
          val (k2, ls1) = takeLetters k 3
      in if null ls1 then NONE
         else
           let val (k3, ls2) =
                   if k2 < n andalso String.sub (q, k2) = #"/" then
                     let val (e, a) = takeLetters (k2 + 1) 3
                         val e2 = if e < n andalso isDigitC (String.sub (q, e)) then e + 1 else e
                     in if null a then (k2, []) else (e2, a) end
                   else (k2, [])
               val end_ = if null ls2 then k2 else k3
           in if end_ < n andalso isWordish (String.sub (q, end_)) then NONE
              else SOME (ls1 @ ls2, end_) end end
    fun inForm i =
      if i + 3 <= n andalso String.substring (q, i, 3) = "in "
         andalso (i = 0 orelse not (isWordish (String.sub (q, i - 1)))) then
        let fun sp m = if m < n andalso Char.isSpace (String.sub (q, m)) then sp (m + 1) else m
            val k = sp (i + 3)
            val (k2, ls1) = takeLetters k 3
        in if null ls1 orelse k2 >= n orelse String.sub (q, k2) <> #"/" then NONE
           else let val (e, a) = takeLetters (k2 + 1) 3
                    val e2 = if e < n andalso isDigitC (String.sub (q, e)) then e + 1 else e
                in if null a orelse (e2 < n andalso isWordish (String.sub (q, e2))) then NONE
                   else SOME (ls1 @ a, e2) end end
      else NONE
    fun scan (i, acc) =
      if i >= n then List.concat (List.rev acc)
      else let val hit = if isDigitC (String.sub (q, i)) then afterDigit i else inForm i
           in case hit of
                SOME (ls, j) => scan (Int.max (j, i + 1), ls :: acc)
              | NONE => scan (i + 1, acc) end
  in scan (0, []) end

fun f533Of (q, route, reply) =
  let
    val ql = lower q
    val v = lower (mathValue reply)
    val fracEcho = fullmatch fraction v andalso sub1 asDecimal ql
                   andalso String.isSubstring (noSpaceLower v) (noSpaceLower ql)
    (* A complete equation-solving request may correctly return a value already
       present in its equation. This is a recognition policy, not a proof of
       the English or of the answer. Incidental "at x=..." still triggers G5. *)
    val requestedEquation = route = "algebra:solved" andalso completeEquation ql
    val eqGiven = not requestedEquation andalso (
      case R.matchHere equation v 0 of
        SOME m =>
          (case (R.group v m 1, R.group v m 2) of
             (SOME x, SOME value) =>
               let val given = R.compile ("(?:^|[,;(]|\\b(?:at|when|if|where|given|with|for|and))\\s*"
                                          ^ escapeRe x ^ "\\s*=\\s*" ^ escapeRe value ^ "(?![\\d.])")
               in sub1 given ql end
           | _ => false)
      | NONE => false)
    val letters = List.mapPartial (fn c => if Char.isAlpha c then SOME (ichar c) else NONE)
                 (String.explode v)
    val unitL = map ichar (unitLetters q)
  in Guards.F533 (fracEcho, eqGiven,
                  not (sub1 algebra ql),   (* no_algebra_q *)
                  letters, unitL,          (* value_letters, unit_letters *)
                  sub1 subst ql,           (* substance_q *)
                  sub1 sky ql,             (* sky_q *)
                  hasSub "specialist:astronomy" route,   (* astro_route *)
                  hasSub "specialist:chemistry" route) end

(* ---- w534 ---- *)

fun f534Of (q, specialistInPath) =
  let val ql = lower q
  in Guards.F534 (specialistInPath, sub1 privB ql, sub1 quantity ql) end

(* ---- the full record ---- *)

fun featsOf {status : string, q : string, route : string, reply : string,
             human : bool option, premise : (string * int * int list) option} : Guards.feats =
  let
    val answered = status = "answered"
    val rg3 = respG3 reply
    val rq = respQ reply
    val rr = respR reply
    val prem = case premise of NONE => NONE
                | SOME (l, y, ys) =>
                    Guards.mk_premise (bitsOfS l) (IntInf.fromInt y) (map IntInf.fromInt ys)
  in Guards.Feats (answered, istr route, istr rg3, istr rq, istr rr,
                   ratsOf q, ratsOf (collapse reply),
                   human, prem,
                   Guards.F510 (gate510 q, map istr (specifics q), map (map istr) (ofPhrases q)),
                   f511Of (q, route, reply, rg3),
                   f513Of (q, rq),
                   f514Of q,
                   f516Of q,
                   f517Of q,
                   f532Of (q, reply),
                   f533Of (q, route, reply),
                   f534Of (q, hasSub "specialist" route)) end

end
