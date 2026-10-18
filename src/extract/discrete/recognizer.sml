(* UNTRUSTED. The English recognizer for the discrete family: a hand port of
     upstream/root/specialists/games-v3/organ_games_v{1,2,3}.py   (GamesOrganV3)
     upstream/root/specialists/logic-v3/organ_logic_v{1,2,3}.py   (LogicOrganV3)
     upstream/root/specialists/algorithms/organ_algorithms_v1.py  (AlgorithmsOrgan)
     upstream/root/specialists/calculus/organ_calculus_v1.py      (CalculusOrgan)
     upstream/root/specialists/dataformats/organ_formats_v1.py    (FormatsOrgan)
   and of their shared narrowing rule narrow_v1.py. It reads numbers, words
   and byte strings off the question and builds a typed Discrete.request; it
   computes nothing. Every value, decline and response text comes from the
   verified HOL kernel (Discrete.reply_of). NONE means the question is not
   taken (the organ returns None).

   Matching is case-insensitive by running the lower-cased pattern literals on
   the lower-cased text; group text is read back from the ORIGINAL text at the
   same offsets (ASCII lower-casing preserves offsets). The regex engine is
   byte-wise, so a non-ASCII symbol in a pattern is its UTF-8 byte sequence. *)
structure Recognizer :
sig
  val organs : string list
  val recognize : string -> string -> (string * Discrete.request) option
end =
struct
  structure D = Discrete
  fun dropWhile' p [] = []
    | dropWhile' p (x :: xs) = if p x then dropWhile' p xs else x :: xs

  val cache : (string * Regex.regex) list ref = ref []
  fun lower s = String.map Char.toLower s
  fun re p =
    case List.find (fn (q, _) => q = p) (!cache) of
      SOME (_, r) => r
    | NONE => let val r = Regex.compile p in cache := (p, r) :: !cache; r end

  (* patterns run on lower-cased text; groups are read from the original text *)
  fun search p s = Regex.search (re p) s
  fun has p s = isSome (search p s)
  fun findall p s = Regex.findall (re p) s
  fun grp s m g = Regex.group s m g
  fun g1 s m = valOf (grp s m 1)
  fun collapse s = String.concatWith " " (String.tokens Char.isSpace s)

  (* replace every match (found in the lower-cased text) by rep, case-insensitively *)
  fun subCI p rep s =
    let
      val ms = findall p (lower s)
      fun go i [] acc = String.concat (rev (String.extract (s, i, NONE) :: acc))
        | go i (({start, stop, ...} : Regex.match) :: rest) acc =
            go stop rest (rep :: String.substring (s, i, start - i) :: acc)
    in go 0 ms [] end

  fun natI (i : IntInf.int) = D.nat_of_integer i
  fun nat (i : int) = natI (IntInf.fromInt i)
  fun bytes s = map (fn c => nat (Char.ord c)) (String.explode s)
  fun letterIdx c = nat (Char.ord c - 97)

  (* "-12.5", "3/4", "1,000" -> exact rational *)
  fun fracOf (lit0 : string) : D.rat =
    let
      val lit = String.translate (fn #"," => "" | c => String.str c) lit0
      val (neg, body) = if String.isPrefix "-" lit then (true, String.extract (lit, 1, NONE)) else (false, lit)
      fun dec b =
        let val (ip, fp) = case String.fields (fn c => c = #".") b of
                             [a] => (a, "") | [a, c] => (a, c) | _ => raise Fail ("bad numeral " ^ lit0)
            val num = valOf (IntInf.fromString (ip ^ fp))
        in (num, IntInf.pow (10, size fp)) end
      val (n, d) =
        case String.fields (fn c => c = #"/") body of
          [a] => dec a
        | [a, b] => let val (n1, d1) = dec a val (n2, d2) = dec b in (n1 * d2, d1 * n2) end
        | _ => raise Fail ("bad numeral " ^ lit0)
    in D.mk_rat (if neg then IntInf.~ n else n) d end

  fun intOf (s : string) : IntInf.int = valOf (IntInf.fromString s)

  (* ---------- narrow_v1 ---------- *)
  structure Narrow =
  struct
    fun words t = length (String.tokens Char.isSpace t)
    fun splits ends t =
      let
        val t = collapse t
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
    val RELATION = "\\b(?:\\d+(?:\\.\\d+)?|one|two|three|four|five|six|seven|eight|nine|ten)\\s+(?:\\w+\\s+){0,2}"
      ^ "(?:more|less|fewer|longer|shorter)\\s+than\\b|\\b(?:twice|three times|half)\\s+(?:as\\s+\\w+\\s+as\\s+)?the\\s+\\w+\\b"
    val RATE = "\\b\\d+(?:\\.\\d+)?\\s+[a-z]+\\s+(?:for|per|every)\\s+(?:\\d+(?:\\.\\d+)?|a|an|one|each)\\s+[a-z]+"
    fun narrative t =
      let val low = lower t
      in sentences t >= 3 orelse words t > 40 orelse has RELATION low orelse has RATE low end
    fun short_direct t = sentences t <= 2 andalso words t <= 25 andalso not (narrative t)
  end

  (* ====================================================================
     games-v3
     ==================================================================== *)
  val handOf = fn i => List.nth (D.hand_list, i)
  val cardOf = fn i => List.nth (D.card_list, i)

  (* stable order of sorted(list(HANDS) + list(ALIASES), key=len, reverse=True) *)
  val handKeys =
    [("three of a kind", 6), ("three-of-a-kind", 6), ("straight flush", 1), ("four of a kind", 2),
     ("four-of-a-kind", 2), ("royal flush", 0), ("full house", 3), ("full-house", 3), ("straight", 5),
     ("two pair", 7), ("one pair", 8), ("a pair", 8), ("flush", 4), ("quads", 2), ("trips", 6),
     ("royal", 0), ("boat", 3)]

  val cardPats =
    [("\\baces?\\b", 0), ("\\bkings?\\b", 1), ("\\bqueens?\\b", 2), ("\\bjacks?\\b", 3), ("\\bface cards?\\b", 4),
     ("\\bhearts?\\b", 5), ("\\bspades?\\b", 6), ("\\bdiamonds?\\b", 7), ("\\bclubs?\\b", 8),
     ("\\bred cards?\\b", 9), ("\\bblack cards?\\b", 10)]

  val NW = "(\\d+|one|two|three|four|five|six|seven|eight|nine|ten|twelve|twenty)"
  fun nOf (s : string) : IntInf.int option =
    if s <> "" andalso Char.isDigit (String.sub (s, 0)) then SOME (intOf s)
    else case s of
      "one" => SOME 1 | "two" => SOME 2 | "three" => SOME 3 | "four" => SOME 4 | "five" => SOME 5
    | "six" => SOME 6 | "seven" => SOME 7 | "eight" => SOME 8 | "nine" => SOME 9 | "ten" => SOME 10
    | "twelve" => SOME 12 | "twenty" => SOME 20 | _ => NONE
  fun numWord (s : string) : IntInf.int option =
    if s <> "" andalso Char.isDigit (String.sub (s, 0)) then SOME (intOf s)
    else case s of
      "two" => SOME 2 | "three" => SOME 3 | "four" => SOME 4 | "five" => SOME 5 | "six" => SOME 6
    | "one" => SOME 1 | "a" => SOME 1 | "an" => SOME 1 | _ => NONE

  val PROB = "\\bprobability\\b|\\bchance\\b|\\bodds\\b|\\blikely\\b"

  fun anagram t low =
    if not (has "\\barrangements?\\b|\\banagrams?\\b|\\bpermutations\\b|\\b(?:re)?arranged\\b|\\bways\\b[^.?]{0,25}?\\b(?:arrange|order|rearrange|permute)\\b" low
            andalso has "\\bhow many\\b|\\bnumber of\\b|\\bdistinct\\b|\\bcount\\b" low
            andalso has "\\bletters?\\b|\\bword\\b|\\banagrams?\\b" low)
    then NONE
    else
      let
        val q = "[\"'\226\128\156]?"
        val m = case search ("\\bthe\\s+word\\s+" ^ q ^ "([a-z]{2,20})\\b") low of
                  SOME m => SOME m
                | NONE =>
                    (case search ("\\bletters\\s+(?:of|in)\\s+(?!the\\b)" ^ q ^ "([a-z]{2,20})\\b") low of
                       SOME m => SOME m
                     | NONE => search ("\\b(?:anagrams?|arrangements?|permutations)\\s+(?:of|for)\\s+(?!the\\b)" ^ q ^ "([a-z]{2,20})\\b") low)
      in
        case m of
          NONE => SOME D.G_anagram_none
        | SOME m =>
            let val w = g1 t m
            in if List.exists (fn x => x = lower w) ["word", "letters", "letter", "the", "a", "an"]
                    andalso not (List.all Char.isUpper (String.explode w))
                    andalso not (has "\\bthe\\s+word\\s+" low)
               then SOME D.G_anagram_none
               else SOME (D.G_anagram (map (fn c => nat (Char.ord (Char.toUpper c))) (String.explode w)))
            end
      end

  fun atLeast low =
    case search "\\bat least one\\s+(\\d|six|one|five|four|three|two)\\b" low of
      NONE => NONE
    | SOME al =>
        if not (has "\\bdi(?:e|ce)\\b|\\bd(\\d+)\\b" low andalso has PROB low) then NONE
        else
          let
            val faceNum = g1 low al
            val sd = search "\\b(\\d+)-sided\\b|\\bd(\\d+)\\b" low
            val sdv = case sd of NONE => NONE
                      | SOME m => (case grp low m 1 of SOME x => SOME x | NONE => grp low m 2)
            val s = case sdv of SOME x => intOf x | NONE => 6
            val dm = search ("\\b" ^ NW ^ "\\s+(?:fair\\s+)?(?:\\d+-sided\\s+)?dice\\b") low
            val k0 =
              let fun first [] = NONE
                    | first (p :: ps) = (case search p low of SOME m => nOf (g1 low m) | NONE => first ps)
              in first ["\\b" ^ NW ^ "\\s+times\\b", "\\b" ^ NW ^ "\\s+(?:rolls|throws|tosses|tries|attempts)\\b",
                        "\\brolled\\s+" ^ NW ^ "\\s+times\\b"] end
            val k1 = case (k0, dm) of (NONE, SOME m) => nOf (g1 low m) | _ => k0
          in
            case k1 of
              NONE =>
                let
                  val sdnums = case sd of NONE => []
                               | SOME m => List.mapPartial (grp low m) [1, 2]
                  val others = List.filter (fn m => let val x = Regex.whole low m in x <> faceNum andalso not (List.exists (fn y => y = x) sdnums) end)
                                           (findall "\\b\\d+\\b" low)
                in if not (null others) then SOME D.G_atleast_unknown
                   else if s < 2 then NONE
                   else SOME (D.G_atleast (natI s, nat 1))
                end
            | SOME k =>
                if k = 0 orelse k > 1000 orelse s < 2 then NONE
                else SOME (D.G_atleast (natI s, natI k))
          end

  fun gamesCore t =
    let
      val low = lower t
    in
      case anagram t low of
        SOME r => SOME r
      | NONE =>
      case atLeast low of
        SOME r => SOME r
      | NONE =>
        (* v1._answer *)
        let
          val pokerCtx = has "\\bpoker\\b|\\bfive[- ]card\\b|\\b5[- ]card\\b|\\bhand\\b" low
          val name = if pokerCtx andalso has "\\bprobability\\b|\\bchance\\b|\\bodds\\b|\\bhow many\\b|\\blikely\\b" low
                     then List.find (fn (k, _) => has ("\\b" ^ k ^ "\\b") low) handKeys
                     else NONE
        in
          case name of
            SOME (_, i) => SOME (D.G_poker (has "\\bhow many\\b" low, handOf i))
          | NONE =>
          let
            val dm = search ("\\b(\\d+|two|three|four|five|six|a|one)\\s+(?:fair\\s+)?(?:(\\d+)-sided\\s+)?(?:dice|die|d(\\d+)s?)\\b") low
          in
            if isSome dm andalso has PROB low then
              let
                val m = valOf dm
                val n = numWord (g1 low m)
                val s = case grp low m 2 of SOME x => intOf x | NONE => (case grp low m 3 of SOME x => intOf x | NONE => 6)
              in
                case n of
                  NONE => NONE
                | SOME n =>
                    if n = 0 orelse n > 20 orelse s < 2 then NONE
                    else
                      let
                        val alm = search "\\bat least one\\s+(\\d+|six|one|five|four|three|two)\\b" low
                        val smm = search "\\b(?:sum|total)\\s*(?:of|is|=)?\\s*(\\d+)\\b|\\broll(?:ing)?\\s+(?:a|an)\\s+(\\d+)\\b|\\bget(?:ting)?\\s+(?:a\\s+)?(\\d+)\\b" low
                      in
                        case alm of
                          SOME _ =>
                            let val k = case search "\\bin\\s+(\\d+)\\s+(?:rolls|throws|tries)\\b" low of
                                          SOME r => intOf (g1 low r) | NONE => n
                            in SOME (D.G_atleast (natI s, natI k)) end
                        | NONE =>
                            (case smm of
                               SOME r =>
                                 let val k = intOf (valOf (List.find (fn x => x <> "") (List.mapPartial (grp low r) [1, 2, 3])))
                                 in SOME (D.G_dice (natI n, natI s, natI k)) end
                             | NONE => cards low)
                      end
              end
            else cards low
          end
        end
    end
  and cards low =
    if has "\\bdeck\\b|\\bcards?\\b" low andalso has PROB low andalso not (has "\\bpoker\\b|\\bhand\\b" low) then
      case List.find (fn (p, _) => has p low) cardPats of
        NONE => NONE
      | SOME (_, ci) =>
          let
            val km = search ("\\b(two|three|four|2|3|4)\\s+(?:\\w+\\s+){0,2}?(?:in a row|consecutive\\w*)\\b|"
                             ^ "\\b(two|three|four|2|3|4)\\s+(?:aces|kings|queens|jacks|hearts|spades|diamonds|clubs|face cards|red cards|black cards)\\b") low
            val k = case km of
                      NONE => 1
                    | SOME m => (case numWord (valOf (case grp low m 1 of SOME x => SOME x | NONE => grp low m 2)) of
                                   SOME v => IntInf.toInt v | NONE => 1)
            val repl = has "\\bwith replacement\\b|\\breplac(?:e|ing) (?:it|the card|each)\\b|\\bputting it back\\b" low
                       andalso not (has "\\bwithout replacement\\b" low)
          in
            if k = 1 then SOME (D.G_card_one (cardOf ci))
            else SOME (D.G_card_k (cardOf ci, nat k, repl))
          end
    else NONE

  fun games text =
    let
      val t0 = collapse text
      val t1 = subCI "\\bchances\\b" "chance" t0
      val t1 = subCI "\\bprobabilities\\b" "probability" t1
      val t1 = subCI "\\blikelihood\\b" "chance" t1
      val t1 = subCI "\\bhow probable\\b" "what is the probability" t1
      val t1 = subCI "\\bodds are\\b" "odds is" t1
      val t1 = subCI "\\ba pair of dice\\b" "two dice" t1
    in
      if Narrow.narrative t1 then NONE
      else
        let val t2 = subCI "\\b(?:dealt|deal|draw|drawing|holding|hold)\\s+(?:five|5)\\s+cards\\b" "dealt a five-card hand" t1
        in Option.map D.RGames (gamesCore t2) end
    end

  (* ====================================================================
     logic-v3
     ==================================================================== *)
  val aR = "\226\134\146"      (* U+2192 *)
  val aLR = "\226\134\148"     (* U+2194 *)
  val andS = "\226\136\167"    (* U+2227 *)
  val orS = "\226\136\168"     (* U+2228 *)
  val notS = "\194\172"        (* U+00AC *)
  val tsile = "\226\138\162"   (* U+22A2 *)
  val thf = "\226\136\180"     (* U+2234 *)

  datatype tok = TIFF | TIMP | TAND | TOR | TNOT | TL | TR | TV of char

  fun tokenize (s0 : string) : tok list option =
    let
      val s = lower s0
      val n = size s
      fun starts i p = i + size p <= n andalso String.substring (s, i, size p) = p
      fun isW c = Char.isAlphaNum c orelse c = #"_"
      fun wordEnd i = if i < n andalso isW (String.sub (s, i)) then wordEnd (i + 1) else i
      fun go i acc =
        if i >= n then SOME (rev acc)
        else
          let val c = String.sub (s, i)
          in
            if Char.isSpace c then go (i + 1) acc
            else if starts i "<->" then go (i + 3) (TIFF :: acc)
            else if starts i aLR then go (i + 3) (TIFF :: acc)
            else if starts i "->" then go (i + 2) (TIMP :: acc)
            else if starts i aR then go (i + 3) (TIMP :: acc)
            else if starts i andS then go (i + 3) (TAND :: acc)
            else if starts i "&&" then go (i + 2) (TAND :: acc)
            else if c = #"&" orelse c = #"^" then go (i + 1) (TAND :: acc)
            else if starts i orS then go (i + 3) (TOR :: acc)
            else if starts i "||" then go (i + 2) (TOR :: acc)
            else if c = #"|" then go (i + 1) (TOR :: acc)
            else if starts i notS then go (i + 2) (TNOT :: acc)
            else if c = #"~" orelse c = #"!" then go (i + 1) (TNOT :: acc)
            else if c = #"(" then go (i + 1) (TL :: acc)
            else if c = #")" then go (i + 1) (TR :: acc)
            else if isW c then
              let
                val e = wordEnd i
                val w = String.substring (s, i, e - i)
              in
                if w = "iff" then go e (TIFF :: acc)
                else if w = "if" andalso starts i "if and only if"
                        andalso (i + 14 >= n orelse not (isW (String.sub (s, i + 14))))
                then go (i + 14) (TIFF :: acc)
                else if w = "implies" then go e (TIMP :: acc)
                else if w = "and" then go e (TAND :: acc)
                else if w = "or" then go e (TOR :: acc)
                else if w = "not" then go e (TNOT :: acc)
                else if size w = 1 andalso Char.isLower c then go e (TV c :: acc)
                else NONE
              end
            else NONE
          end
    in go 0 [] end

  exception ParseErr

  fun parseToks (toks : tok list) : D.fm option =
    let
      val ts = ref toks
      fun peek () = case !ts of [] => NONE | t :: _ => SOME t
      fun eat () = case !ts of [] => raise ParseErr | t :: r => (ts := r; t)
      fun iff () =
        let fun loop a = if peek () = SOME TIFF then (eat (); loop (D.FEquiv (a, imp ()))) else a
        in loop (imp ()) end
      and imp () =
        let val a = orr ()
        in if peek () = SOME TIMP then (eat (); D.FImpl (a, imp ())) else a end
      and orr () =
        let fun loop a = if peek () = SOME TOR then (eat (); loop (D.FDisj (a, andd ()))) else a
        in loop (andd ()) end
      and andd () =
        let fun loop a = if peek () = SOME TAND then (eat (); loop (D.FConj (a, nott ()))) else a
        in loop (nott ()) end
      and nott () =
        case peek () of
          SOME TNOT => (eat (); D.FNeg (nott ()))
        | SOME TL => (eat (); let val e = iff () in (case eat () of TR => e | _ => raise ParseErr) end)
        | _ => (case eat () of TV c => D.FVar (letterIdx c) | _ => raise ParseErr)
      val e = iff ()
    in if null (!ts) then SOME e else NONE end
    handle ParseErr => NONE

  fun parseF (s : string) : D.fm option =
    case tokenize s of
      NONE => NONE
    | SOME [] => NONE
    | SOME ts => parseToks ts

  fun isVar (D.FVar _) = true | isVar _ = false

  fun strip s = let val l = String.explode s
                    val l1 = List.rev (dropWhile' Char.isSpace (List.rev (dropWhile' Char.isSpace l)))
                in String.implode l1 end

  val forms = [
    "^if (\\w+)(?:,)? then (\\w+)\\.? \\1\\.? therefore,? \\2\\.?$",
    "^if (\\w+)(?:,)? then (\\w+)\\.? not \\2\\.? therefore,? not \\1\\.?$",
    "^if (\\w+)(?:,)? then (\\w+)\\.? \\2\\.? therefore,? \\1\\.?$",
    "^if (\\w+)(?:,)? then (\\w+)\\.? not \\1\\.? therefore,? not \\2\\.?$",
    "^if (\\w+)(?:,)? then (\\w+)\\.? if \\2(?:,)? then (\\w+)\\.? therefore,? if \\1(?:,)? then \\3\\.?$",
    "^(\\w+) or (\\w+)\\.? not \\1\\.? therefore,? \\2\\.?$"]

  val TAIL = "\\s*(?:is (?:it|this|the argument|this argument) (?:a )?valid(?: argument)?|what (?:is this|form is this|fallacy is this)[^?]*|name (?:the|this) (?:form|fallacy))\\??\\s*$"

  fun stripTail body =
    case search TAIL body of
      SOME {start, ...} => String.substring (body, 0, start)
    | NONE => body

  fun formOf body =
    let fun go _ [] = NONE
          | go i (p :: ps) = if has p body then SOME (List.nth (D.form_list, i)) else go (i + 1) ps
    in go 0 forms end

  val TOK = "(?:<->|->|" ^ aR ^ "|" ^ aLR ^ "|" ^ andS ^ "|" ^ orS ^ "|" ^ notS ^ "|~|!|&&?|\\|\\|?|\\^|\\(|\\)|,|;|\\b[a-z]\\b)"
  val SPAN_L = "((?:\\s*" ^ TOK ^ ")+)\\s*$"
  val SPAN_R = "^\\s*((?:\\s*" ^ TOK ^ ")+)"
  val SPAN_ANY = "(?:\\s*" ^ TOK ^ ")+"
  val CLS = "\\btautolog\\w*\\b|\\bcontradiction\\b|\\bcontingent\\b|\\bsatisfiable\\b|\\balways true\\b"
  val SYMB = "<->|->|" ^ aR ^ "|" ^ aLR ^ "|" ^ andS ^ "|" ^ orS ^ "|" ^ notS ^ "|~|&|\\|"

  fun splitSemi (s : string) = String.fields (fn c => c = #";" orelse c = #",") s

  fun parseAll (parts : string list) : D.fm list option =
    let val ps = List.filter (fn x => strip x <> "") parts
        val rs = map parseF ps
    in if null ps orelse List.exists (not o isSome) rs then NONE else SOME (map valOf rs) end

  fun shape low =
    let
      val starts = 0 :: map (fn {stop, ...} : Regex.match => stop) (findall "[:?]\\s+|\\.\\s+(?=if\\b)" low)
      fun go [] = NONE
        | go (s :: ss) =
            let val body = strip (stripTail (String.extract (low, s, NONE)))
            in case formOf body of SOME f => SOME (D.RLogic (D.L_form f)) | NONE => go ss end
    in go starts end

  fun turnstile low =
    case search ("\\|-|" ^ tsile ^ "|" ^ thf) low of
      NONE => NONE
    | SOME {start, stop, ...} =>
        if not (has "\\bvalid\\b|\\binvalid\\b|\\bentail\\w*\\b|\\bfollows?\\b|\\bsound\\b" low) then NONE
        else
          let
            val left = String.substring (low, 0, start)
            val right = String.extract (low, stop, NONE)
            val premS = case search SPAN_L left of SOME m => g1 left m | NONE => ""
            val conclS = case search SPAN_R right of SOME m => g1 right m | NONE => ""
            val concl = parseF (let val c = strip conclS
                                    val l = List.rev (dropWhile' (fn x => x = #"," orelse x = #";") (List.rev (String.explode c)))
                                in String.implode l end)
          in
            case (parseAll (splitSemi premS), concl) of
              (SOME ps, SOME c) => SOME (D.RLogic (D.L_argument (ps, c)))
            | _ => SOME (D.RLogic D.L_bad_argument)
          end

  (* the first quoted span, as the regex  ["'`‘“]([^"'`’”]+)["'`’”]  would find it *)
  fun quotedSpan (s : string) : string option =
    let
      val n = size s
      fun starts i p = i + size p <= n andalso String.substring (s, i, size p) = p
      val lq = "\226\128\152" val rq = "\226\128\153" val ldq = "\226\128\156" val rdq = "\226\128\157"
      fun openLen i = if starts i lq orelse starts i ldq then SOME 3
                      else if i < n andalso Char.contains "\"'`" (String.sub (s, i)) then SOME 1 else NONE
      fun closeLen i = if starts i rq orelse starts i rdq then SOME 3
                       else if i < n andalso Char.contains "\"'`" (String.sub (s, i)) then SOME 1 else NONE
      fun run j = if j >= n then NONE
                  else case closeLen j of SOME _ => SOME j | NONE => run (j + 1)
      fun tryAt i =
        if i >= n then NONE
        else case openLen i of
               NONE => tryAt (i + 1)
             | SOME l =>
                 (case run (i + l) of
                    SOME k => if k > i + l then SOME (String.substring (s, i + l, k - i - l)) else tryAt (i + 1)
                  | NONE => tryAt (i + 1))
    in tryAt 0 end

  fun classOf e = SOME (D.RLogic (D.L_formula e))

  fun quoted low =
    if not (has CLS low) then NONE
    else
      case quotedSpan low of
        NONE => NONE
      | SOME span =>
          let val symbolic = has SYMB span
          in
            if not symbolic andalso not (has "\\b(?:and|or|not|iff|implies)\\b" span) then NONE
            else
              case parseF span of
                NONE => if not symbolic then NONE else SOME (D.RLogic D.L_bad_formula)
              | SOME e => if isVar e then NONE else classOf e
          end

  fun cutSuffixA s = case search "\\s+a$" s of SOME {start, ...} => String.substring (s, 0, start) | NONE => s
  fun cutPrefixA s = case search "^a\\s+" s of SOME {stop, ...} => String.extract (s, stop, NONE) | NONE => s

  fun span low =
    if not (has CLS low) then NONE
    else
      let
        val spans = List.filter (fn x => has SYMB x) (map (fn m => strip (Regex.whole low m)) (findall SPAN_ANY low))
      in
        if null spans then NONE
        else
          let
            val best = List.foldl (fn (x, b) => if size x > size b then x else b) (hd spans) (tl spans)
            val cands = [best, cutSuffixA best, cutPrefixA best, cutSuffixA (cutPrefixA best)]
            fun go [] = SOME (D.RLogic D.L_bad_formula)
              | go (c :: cs) = (case parseF c of
                                  SOME e => if isVar e then go cs else classOf e
                                | NONE => go cs)
          in go cands end
      end

  fun logicV1 low =
    if not (has "\\btautolog\\w*\\b|\\bcontradiction\\b|\\bcontingent\\b|\\bvalid\\b|\\binvalid\\b|\\bfallacy\\b|\\bargument form\\b|\\bmodus\\b|\\btruth table\\b|\\blogically\\b|\\bsatisfiable\\b" low)
    then NONE
    else
      let
        val body0 = case CharVector.findi (fn (_, c) => c = #":") low of
                      SOME (i, _) =>
                        let fun skip j = if j < size low andalso Char.isSpace (String.sub (low, j)) then skip (j + 1) else j
                        in String.extract (low, skip (i + 1), NONE) end
                    | NONE => low
        val body = strip (stripTail body0)
      in
        case formOf body of
          SOME f => SOME (D.RLogic (D.L_form f))
        | NONE =>
          let
            val arg =
              case search ("(?:premises?:?\\s*)?(.+?)\\s*(?:\\|-|" ^ tsile ^ "|therefore|" ^ thf ^ "|entails?)\\s*(.+?)\\s*(?:\\?|$|\\bvalid\\b)") low of
                SOME am =>
                  if has "\\bvalid\\b|\\binvalid\\b|\\bentail\\w*\\b" low
                     andalso has ("->|" ^ aR ^ "|<->|" ^ aLR ^ "|" ^ andS ^ "|" ^ orS ^ "|" ^ notS ^ "|~|\\|-|" ^ tsile ^ "|\\bimplies\\b") low
                  then
                    let
                      val p1 = g1 low am
                      val premS = case search "^\\s*(?:is the argument|is|are|does)\\s+" p1 of
                                    SOME {stop, ...} => String.extract (p1, stop, NONE) | NONE => p1
                      val c2 = valOf (grp low am 2)
                      val conclS = case search "\\s*(?:valid|a valid argument).*$" c2 of
                                     SOME {start, ...} => String.substring (c2, 0, start) | NONE => c2
                    in
                      case (parseAll (splitSemi premS), parseF conclS) of
                        (SOME ps, SOME c) => SOME (D.RLogic (D.L_argument (ps, c)))
                      | _ => NONE
                    end
                  else NONE
              | NONE => NONE
          in
            case arg of
              SOME r => SOME r
            | NONE =>
              let
                val fm =
                  case search "(?:is|formula|statement|expression|sentence)\\s+[\"'`]?(.+?)[\"'`]?\\s+(?:a |an )?(?:tautology|contradiction|contingent|valid|satisfiable|always true)" low of
                    SOME m => SOME (g1 low m)
                  | NONE =>
                    (case search "(?:classify|evaluate|check)\\s+[\"'`]?(.+?)[\"'`]?\\s*(?:[:.?]|$)" low of
                       SOME m => SOME (g1 low m)
                     | NONE => (case search "[\"'`](.+?)[\"'`]" low of SOME m => SOME (g1 low m) | NONE => NONE))
              in
                case fm of
                  NONE => NONE
                | SOME f =>
                    if has "\\btautolog\\w*\\b|\\bcontradiction\\b|\\bcontingent\\b|\\bsatisfiable\\b|\\balways true\\b" low then
                      (case parseF f of
                         NONE => NONE
                       | SOME e => if isVar e then NONE else classOf e)
                    else NONE
              end
          end
      end

  fun logic text =
    let
      val t = collapse text
      val low = lower t
    in
      case shape low of
        SOME r => SOME r
      | NONE =>
      case turnstile low of
        SOME r => SOME r
      | NONE =>
      case quoted low of
        SOME r => SOME r
      | NONE =>
      case span low of
        SOME r => SOME r
      | NONE => logicV1 low
    end

  (* ====================================================================
     algorithms
     ==================================================================== *)
  val EDGE = "\\b([a-z0-9]{1,3})\\s*(->|-|<->|to)\\s*([a-z0-9]{1,3})\\b\\s*(?:\\(|:|=|weight|w|cost)?\\s*(\\d+(?:\\.\\d+)?)\\)?"

  (* the edges in order: (a, op, b, weight) with the names as written *)
  fun edgesOf (t : string) : (string * string * string * D.rat) list =
    map (fn m => (valOf (grp t m 1), valOf (grp t m 2), valOf (grp t m 3), fracOf (valOf (grp t m 4))))
        (findall EDGE (lower t))

  fun dirEdges edges =
    List.concat (map (fn (a, op_, b, w) => if op_ = "->" then [(a, (b, w))] else [(a, (b, w)), (b, (a, w))]) edges)

  fun mkEdge (a, (b, w)) = (a, (b, w))

  val NUMLIST = "\\[?\\s*(-?\\d+(?:\\.\\d+)?(?:\\s*,\\s*-?\\d+(?:\\.\\d+)?){2,})\\s*\\]?"

  val complexityNames = D.complexity_names
  (* sorted(COMPLEXITY, key=len, reverse=True): stable, longest first *)
  val complexityOrder =
    let
      val idx = ListPair.zip (complexityNames, List.tabulate (length complexityNames, fn i => i))
      fun insert x [] = [x]
        | insert (x as (nx, _)) ((y as (ny, _)) :: ys) =
            if size nx > size ny then x :: y :: ys else y :: insert x ys
    in List.foldl (fn (x, acc) => insert x acc) [] idx end

  fun algorithms text =
    let
      val t = collapse text
      val low = lower t
      fun finish r = r
      val shortDirect = Narrow.short_direct text
    in
      if has "\\bwrite\\b|\\bfunction\\b|\\bimplement\\w*\\b|\\bcode\\b|\\bprogram\\b|\\bpython\\b|\\bjavascript\\b|\\bjava\\b|\\bc\\+\\+" low
      then NONE
      else
        let
          val need = fn k => if shortDirect then SOME (D.RAlgos k) else NONE
        in
          if has "\\bshortest path\\b|\\bshortest distance\\b|\\bdijkstra\\b|\\bcheapest path\\b" low then
            let
              val edges = edgesOf t
              val m = search "\\bfrom\\s+([a-z0-9]{1,3})\\s+to\\s+([a-z0-9]{1,3})\\b" low
            in
              case (edges, m) of
                ([], _) => need D.A_sp_need
              | (_, NONE) => need D.A_sp_need
              | (_, SOME m) =>
                  let
                    val s = valOf (grp t m 1) val e = valOf (grp t m 2)
                    val es = map (fn (a, (b, w)) => (a, (b, w))) (dirEdges edges)
                  in SOME (D.RAlgos (D.A_sp (es, nat (length edges), s, e))) end
            end
          else if has "\\bminimum spanning tree\\b|\\bmst\\b" low then
            let val edges = edgesOf t
            in if length edges < 2 then need D.A_mst_need
               else SOME (D.RAlgos (D.A_mst (map (fn (a, _, b, w) => (a, (b, w))) edges)))
            end
          else
            let
              val nl = search NUMLIST t
              fun numbers m = map (fn x => fracOf (strip x)) (String.fields (fn c => c = #",") (g1 t m))
              val lowNl = lower t
            in
              if has "\\bbinary search\\b" low andalso isSome nl then
                let
                  val m = valOf nl
                  val rest = String.substring (lowNl, 0, #start m) ^ " " ^ String.extract (lowNl, #stop m, NONE)
                in
                  case search "\\b(?:for|find|search for|target|looking for)\\s+(-?\\d+(?:\\.\\d+)?)\\b" rest of
                    NONE => need D.A_bsearch_need
                  | SOME tm => SOME (D.RAlgos (D.A_bsearch (numbers m, fracOf (g1 rest tm))))
                end
              else if has "\\bsort\\b|\\bsorted\\b|\\bascending\\b|\\bdescending\\b|\\bin order\\b" low andalso isSome nl
                      andalso not (has "\\bcomplexity\\b|\\bbig[- ]o\\b" low) then
                let val desc = has "\\bdescending\\b|\\blargest (?:to|first)\\b|\\bhigh(?:est)? to low" low
                in SOME (D.RAlgos (D.A_sort (numbers (valOf nl), desc))) end
              else if has "\\btime complexity\\b|\\bbig[- ]o\\b|\\bcomplexity of\\b|\\bhow fast is\\b" low then
                (case List.find (fn (nm, _) => has ("\\b" ^ nm ^ "\\b") low) complexityOrder of
                   NONE => NONE
                 | SOME (_, i) => SOME (D.RAlgos (D.A_complexity (nat i, has "\\baverage\\b" low))))
              else NONE
            end
        end
    end

  (* ====================================================================
     calculus
     ==================================================================== *)
  val BADPOLY = "\\b(?:sin|cos|tan|sec|csc|cot|log|ln|exp|sqrt|arc\\w*)\\b|[e]\\^|\\$|\\\\|/\\s*[a-z]|\\be\\s*\\*\\*|\\|"
  val TERM = "([+-]?)\\s*(\\d+(?:\\.\\d+)?(?:/\\d+)?)?\\s*\\*?\\s*(?:([a-z])\\s*(?:\\^\\s*(\\d+)|\\*\\*\\s*(\\d+))?)?"

  fun replaceStr (a : string) (b : string) (s : string) : string =
    let
      val n = size a
      fun go i acc =
        if i >= size s then String.concat (rev acc)
        else if i + n <= size s andalso String.substring (s, i, n) = a then go (i + n) (b :: acc)
        else go (i + 1) (String.str (String.sub (s, i)) :: acc)
    in go 0 [] end

  (* a plain polynomial in one variable: ((power, coefficient) terms, variable) *)
  fun parsePoly (expr : string) : ((D.nat * D.rat) list * string) option =
    let
      val s0 = strip expr
      val s1 = String.implode (List.rev (dropWhile' (fn c => Char.contains "?.!," c) (List.rev (String.explode s0))))
      val s = List.foldl (fn ((a, b), x) => replaceStr a b x) s1
                [("\194\178", "^2"), ("\194\179", "^3"), ("\226\129\180", "^4"), ("\226\129\181", "^5"),
                 ("\226\129\182", "^6"), ("\226\136\146", "-"), ("\194\183", "*")]
      val ls = lower s
    in
      if s = "" orelse has BADPOLY ls orelse has "[()\\[\\]{}=<>]" ls then NONE
      else
        let
          val vars = List.foldl (fn (c, acc) => if Char.isLower c andalso not (List.exists (fn d => d = c) acc) then c :: acc else acc)
                                [] (String.explode ls)
        in
          if length vars > 1 then NONE
          else
            let
              val body = String.concat (String.tokens (fn c => c = #" ") ls)
              val var = case vars of [c] => String.str c | _ => "x"
              fun loop pos acc =
                if pos >= size body then SOME (rev acc)
                else
                  case Regex.matchHere (re TERM) body pos of
                    NONE => NONE
                  | SOME m =>
                      let
                        val stop = #stop m
                        val sign = valOf (grp body m 1)
                        val coef = grp body m 2
                        val v = grp body m 3
                        val p1 = grp body m 4
                        val p2 = grp body m 5
                      in
                        if stop = pos then NONE
                        else if not (isSome coef) andalso not (isSome v) then NONE
                        else if pos > 0 andalso sign = "" then NONE
                        else
                          let
                            val c0 = case coef of SOME x => fracOf x | NONE => fracOf "1"
                            val c = if sign = "-" then fracOf ("-" ^ (case coef of SOME x => x | NONE => "1")) else c0
                            val p = if isSome v then (case p1 of SOME x => intOf x | NONE => (case p2 of SOME x => intOf x | NONE => 1)) else 0
                          in
                            if p > 50 then NONE else loop stop ((natI p, c) :: acc)
                          end
                      end
            in
              case loop 0 [] of
                NONE => NONE
              | SOME terms => SOME (terms, var)
            end
        end
    end

  val NUMRE = "(-?\\d+(?:\\.\\d+)?(?:/\\d+)?)"

  fun calcExpr t low : string option =
    case search "`([^`]+)`" low of
      SOME m => SOME (g1 t m)
    | NONE =>
    case search "\\b[fgh]\\s*\\(\\s*[a-z]\\s*\\)\\s*=\\s*(.+?)(?:,|;|\\?|$| at | from | when | for )" low of
      SOME m => SOME (g1 t m)
    | NONE =>
    case search "(?:\\b(?:derivative|differentiate|anti-?derivative|primitive|integral|integrate|slope of the tangent(?: line)? to)|\\bd/d[a-z])\\s+(?:of\\s+)?(?:y\\s*=\\s*)?(.+?)(?:\\s+(?:with respect to|wrt|at|from|when|for|between|evaluated)\\b|\\s*d[a-z]\\b|,|\\?|$)" low of
      SOME m => SOME (g1 t m)
    | NONE => NONE

  fun calculus text =
    let
      val t = collapse text
      val low = lower t
    in
      if not (has "\\bderivative\\b|\\bdifferentiate\\b|\\bd/d[a-z]\\b|\\bintegral\\b|\\bintegrate\\b|\\banti-?derivative\\b|\\bprimitive\\b|\\bslope of the tangent\\b|\\bf'\\(" low)
      then NONE
      else if has "\\bsolve\\b|\\$|\\\\" low then NONE
      else if has "/0+(?![0-9.])" (replaceStr " " "" low)
      then SOME (D.RCalc (D.C_need (nat 2)))
      else
        case calcExpr t low of
          NONE =>
            if has "\\b(?:derivative|integral|antiderivative) of\\s*\\??$|\\bdifferentiate\\s*\\??$|\\bintegrate\\s*\\??$" low
            then SOME (D.RCalc (D.C_need (nat 0))) else NONE
        | SOME e =>
          case parsePoly e of
            NONE => NONE
          | SOME (poly, parsedVar) =>
            let
              (* Recognition is untrusted. Never reinterpret an explicit variable,
                 order, malformed number, or zero denominator as a simpler request. *)
              val declared = findall "(?:with respect to|wrt|d/d|\\bat\\s+|\\bwhen\\s+|\\bwhere\\s+)\\s*([a-z])\\b|\\bd([a-z])\\b" low
              fun declaredVar m = case grp low m 1 of SOME v => v | NONE => valOf (grp low m 2)
              val vars = map declaredVar declared @ map (g1 low)
                (findall "\\b(?:from|to)\\s+([a-z])\\s*=" low)
              val hasVariable = List.exists Char.isAlpha (String.explode e)
              val var = if hasVariable then parsedVar else (case vars of v :: _ => v | [] => parsedVar)
            in
              if List.exists (fn v => v <> var) vars then SOME (D.RCalc (D.C_need (nat 2)))
              else if has "\\bintegra|\\banti-?derivative\\b|\\bprimitive\\b" low then
                let
                  val bounds =
                    case search ("\\bfrom\\s+" ^ NUMRE ^ "\\s+to\\s+" ^ NUMRE ^ "(?![a-z0-9_/+*^-]|\\.[a-z0-9])") low of
                      SOME m => SOME (g1 low m, valOf (grp low m 2))
                    | NONE =>
                    case search ("\\bbetween\\s+" ^ NUMRE ^ "\\s+and\\s+" ^ NUMRE ^ "(?![a-z0-9_/+*^-]|\\.[a-z0-9])") low of
                      SOME m => SOME (g1 low m, valOf (grp low m 2))
                    | NONE =>
                    case search ("\\b[a-z]\\s*=\\s*" ^ NUMRE ^ "\\s+to\\s+(?:[a-z]\\s*=\\s*)?" ^ NUMRE ^ "(?![a-z0-9_/+*^-]|\\.[a-z0-9])") low of
                      SOME m => SOME (g1 low m, valOf (grp low m 2))
                    | NONE => NONE
                in
                  case bounds of
                    SOME (a, b) => SOME (D.RCalc (D.C_def (poly, var, fracOf a, fracOf b)))
                  | NONE => if has "\\bfrom\\b|\\bbetween\\b" low then SOME (D.RCalc (D.C_need (nat 2)))
                            else SOME (D.RCalc (D.C_anti (poly, var)))
                end
              else
                let
                  val orderWords = [("first", 1), ("second", 2), ("third", 3), ("fourth", 4),
                    ("fifth", 5), ("sixth", 6), ("seventh", 7), ("eighth", 8), ("ninth", 9), ("tenth", 10)]
                  val n = case search "\\b([a-z0-9]+(?:th|nd|rd|st)|second)\\s+derivative\\b" low of
                    NONE => 1
                  | SOME m => let val word = g1 low m in
                      case List.find (fn (w, _) => w = word) orderWords of
                        SOME (_, n) => n
                      | NONE => (case IntInf.fromString word of
                          SOME n => if n >= 1 andalso n <= 50 then IntInf.toInt n else 0
                        | NONE => 0)
                    end
                  val pm = case search ("\\b(?:at|when|where)\\s+(?:[a-z]\\s*=\\s*)?" ^ NUMRE ^ "(?![a-z0-9_/+*^-]|\\.[a-z0-9])") low of
                             SOME m => SOME (g1 low m)
                           | NONE => (case search ("\\bf'+\\(\\s*" ^ NUMRE ^ "\\s*\\)") low of SOME m => SOME (g1 low m) | NONE => NONE)
                  val tangent = has "tangent" low
                in
                  if n = 0 then SOME (D.RCalc (D.C_need (nat 2))) else case pm of
                    SOME x0 => SOME (D.RCalc (D.C_deriv_at (poly, var, nat n, fracOf x0, tangent)))
                  | NONE =>
                      if has "\\b(?:at|when|where)\\s+" low then SOME (D.RCalc (D.C_need (nat 2)))
                      else if tangent then SOME (D.RCalc (D.C_need (nat 1)))
                      else SOME (D.RCalc (D.C_deriv (poly, var, nat n)))
                end
            end
    end

  (* ====================================================================
     dataformats
     ==================================================================== *)
  fun payload (t : string) (low : string) : string option =
    case search "`([^`]+)`" low of
      SOME m => SOME (g1 t m)
    | NONE =>
    case search "\"([^\"]+)\"" low of
      SOME m => SOME (g1 t m)
    | NONE =>
    case search "'([^']+)'" low of
      SOME m => SOME (g1 t m)
    | NONE =>
    case search ":\\s*(\\S.*?)\\s*\\??$" low of
      SOME m => SOME (g1 t m)
    | NONE => NONE

  fun baseOf "binary" = 2 | baseOf "bin" = 2 | baseOf "octal" = 8 | baseOf "oct" = 8
    | baseOf "decimal" = 10 | baseOf "dec" = 10 | baseOf "hexadecimal" = 16 | baseOf "hex" = 16
    | baseOf _ = 10

  fun formats text =
    let
      val t = collapse text
      val low = lower t
      fun F r = SOME (D.RFormats r)
    in
      if has "\\bvalid json\\b|\\bis this json\\b|\\bparse (?:this )?json\\b" low then
        let
          val p = case search "`([^`]+)`" low of
                    SOME m => SOME (g1 t m)
                  | NONE => (case search "json\\b[^:{\\[]*:\\s*(.+?)\\s*$" low of SOME m => SOME (g1 t m) | NONE => NONE)
        in case p of NONE => NONE | SOME p => F (D.F_json (bytes p)) end
      else if has "\\bbase ?64\\b" low andalso
              (case payload t low of NONE => true | SOME _ => false) then NONE
      else if has "\\bbase ?64\\b" low andalso has "\\bdecode\\b|\\bfrom base ?64\\b" low then
        F (D.F_b64dec (bytes (valOf (payload t low))))
      else if has "\\bbase ?64\\b" low andalso has "\\bencode\\b|\\bto base ?64\\b|\\bin base ?64\\b" low then
        F (D.F_b64enc (bytes (valOf (payload t low))))
      else
        case search "\\b(sha-?256|sha-?1|md5)\\b" low of
          SOME m =>
            if has "\\bhash\\b|\\bdigest\\b|\\bchecksum\\b|\\bof\\b" low then
              (case payload t low of
                 NONE => NONE
               | SOME p =>
                   let val algo = String.translate (fn #"-" => "" | c => String.str c) (g1 low m)
                       val a = if algo = "sha256" then D.H_sha256 else if algo = "sha1" then D.H_sha1 else D.H_md5
                   in F (D.F_hash (a, bytes p)) end)
            else formatsRest t low
        | NONE => formatsRest t low
    end
  and formatsRest t low =
    let fun F r = SOME (D.RFormats r)
    in
      if has "\\burl[- ]?(?:encode|decode|encoding|decoding)\\b|\\bpercent[- ]encod" low then
        (case payload t low of
           NONE => NONE
         | SOME p =>
             if has "decode" low orelse has "decoding" low then F (D.F_urldec (bytes p)) else F (D.F_urlenc (bytes p)))
      else
        let
          val bm = search ("\\b(0x[0-9a-f]+|0b[01]+|0o[0-7]+|[0-9a-f]+)\\b(?:\\s+\\(?(?:in |from )?(binary|bin|octal|oct|decimal|dec|hexadecimal|hex)\\)?)?"
                           ^ "\\s+(?:to|in|into|as)\\s+(binary|bin|octal|oct|decimal|dec|hexadecimal|hex)\\b") low
        in
          case bm of
            SOME m =>
              if has "\\bconvert\\b|\\bwhat is\\b|\\bin\\b" low then
                let
                  val tok = g1 low m
                  val src = grp low m 2
                  val dst = valOf (grp low m 3)
                  val pre = if size tok >= 2 then String.substring (tok, 0, 2) else ""
                  val base = if pre = "0x" then 16 else if pre = "0b" then 2 else if pre = "0o" then 8
                             else (case src of SOME s => baseOf s | NONE => 10)
                  val digs = if pre = "0x" orelse pre = "0b" orelse pre = "0o" then String.extract (tok, 2, NONE) else tok
                in F (D.F_base (bytes tok, nat base, nat (baseOf dst), bytes digs)) end
              else dayOf t low
          | NONE => dayOf t low
        end
    end
  and dayOf t low =
    case search "\\b(\\d{4})-(\\d{2})-(\\d{2})\\b" low of
      SOME m =>
        if has "\\bwhat day\\b|\\bweekday\\b|\\bday of the week\\b" low then
          SOME (D.RFormats (D.F_day (bytes (Regex.whole t m), natI (intOf (g1 t m)),
                                     natI (intOf (valOf (grp t m 2))), natI (intOf (valOf (grp t m 3))))))
        else NONE
    | NONE => NONE

  (* ---------- dispatch ---------- *)
  val organs = ["games-v3", "logic-v3", "dataformats", "algorithms", "calculus"]

  fun byId "games-v3" = games
    | byId "logic-v3" = logic
    | byId "dataformats" = formats
    | byId "algorithms" = algorithms
    | byId "calculus" = calculus
    | byId other = raise Fail ("unknown specialist " ^ other)

  (* The family: each manifest's organ in a fixed order, the first that takes
     the question answers it. *)
  val familyOrder = ["dataformats", "calculus", "algorithms", "games-v3", "logic-v3"]

  fun recognize mode text =
    if mode = "family" then
      let fun go [] = NONE
            | go (id :: ids) = case byId id text of SOME r => SOME (id, r) | NONE => go ids
      in go familyOrder end
    else Option.map (fn r => (mode, r)) (byId mode text)
end
