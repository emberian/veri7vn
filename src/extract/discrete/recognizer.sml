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

  (* Complete adjacent quantities. Unknown modifiers never default to one. *)
  val gameSmall = [("zero",0),("one",1),("two",2),("three",3),("four",4),
    ("five",5),("six",6),("seven",7),("eight",8),("nine",9),("ten",10),
    ("eleven",11),("twelve",12),("thirteen",13),("fourteen",14),("fifteen",15),
    ("sixteen",16),("seventeen",17),("eighteen",18),("nineteen",19),
    ("twenty",20),("thirty",30),("forty",40),("fifty",50),("sixty",60),
    ("seventy",70),("eighty",80),("ninety",90),("hundred",100),("a",1),("an",1)]
  fun gameNumber phrase =
    if has "^[+-]?[0-9]+$" phrase then
      SOME (if String.isPrefix "-" phrase then IntInf.~ (intOf (String.extract (phrase,1,NONE)))
        else if String.isPrefix "+" phrase then intOf (String.extract (phrase,1,NONE)) else intOf phrase)
    else if String.isPrefix "minus " phrase then Option.map IntInf.~ (gameNumber (String.extract (phrase,6,NONE)))
    else if String.isPrefix "negative " phrase then Option.map IntInf.~ (gameNumber (String.extract (phrase,9,NONE)))
    else
      let val words = String.tokens (fn c => Char.isSpace c orelse c = #"-") phrase
          fun small w = Option.map (IntInf.fromInt o #2) (List.find (fn (s,_) => s=w) gameSmall)
      in case words of
           [w] => small w
         | [a,b] => (case (small a,small b) of
              (SOME x,SOME y) => if x >= 20 andalso x <= 90 andalso x mod 10 = 0 andalso y > 0 andalso y < 10
                                then SOME (x+y) else if x=1 andalso y=100 then SOME 100 else NONE
            | _ => NONE)
         | _ => NONE
      end
  fun gameNumberish w =
    isSome (gameNumber w) orelse has "^[+0-9.-]" w orelse
    List.exists (fn x => x=w) ["minus","negative","positive","plus","and","thousand","million"]
  fun quantityBefore low (m : Regex.match) =
    let val words = rev (String.tokens Char.isSpace (String.substring (low,0,#start m)))
        fun gather [] acc = acc
          | gather (w::ws) acc = if gameNumberish w then gather ws (w::acc) else acc
    in case words of
         [] => NONE
       | w::_ => if gameNumberish w then gameNumber (String.concatWith " " (gather words [])) else NONE
    end

  fun atLeast low =
    if not (has "\\bat least one\\b" low andalso has PROB low andalso
      has "\\bdi(?:e|ce)\\b|\\bd[0-9]+\\b" low) then NONE
    else
      let
        val faces = findall "\\bat least one\\b" low
        val sides = findall "([^ ]+)-sided\\b|\\bd([0-9]+)\\b" low
        val rolls = findall "\\b(?:rolls|throws|tosses|tries|attempts|trials|times)\\b|(?:fair\\s+)?(?:[^ ]+-sided\\s+)?\\bdice\\b" low
        fun cleanFace str =
          if size str > 0 andalso Char.contains ".!,;?" (String.sub (str,size str - 1))
          then String.substring (str,0,size str - 1) else str
        fun faceAfter (m : Regex.match) =
          let val words = String.tokens Char.isSpace (String.extract (low,#stop m,NONE))
              fun gather [] acc = (rev acc,[])
                | gather (w::ws) acc = if gameNumberish (cleanFace w)
                    then gather ws (cleanFace w::acc) else (rev acc,w::ws)
              val (number,rest) = gather words []
              val complete = case rest of [] => true
                | w::_ => List.exists (fn x => x = w)
                    ["in","on","from","when","if","with","after","over","during",
                     "among","out","of","rolling","rolls","throws","times"]
          in if complete then gameNumber (String.concatWith " " number) else NONE end
        val face = case faces of [m] => faceAfter m | _ => NONE
        val side = case sides of [] => SOME 6
          | [m] => gameNumber (valOf (case grp low m 1 of SOME x => SOME x | NONE => grp low m 2))
          | _ => NONE
        val remaining = subCI "([^ ]+)-sided\\b|\\bd[0-9]+\\b" "" (subCI "\\bat least one\\s+((?:minus|negative)\\s+[^ ,;?]+|[^ ,;?]+)" "" low)
        val unsafe = has "\\b(?:and|or|not|neither|except)\\b" low
        val count = case rolls of [] => if has "[0-9]" remaining then NONE else SOME 1
          | [m] => quantityBefore low m | _ => NONE
      in case (face,side,count) of
           (SOME f,SOME s,SOME k) =>
             if not unsafe andalso s >= 1 andalso s <= 1000 andalso k >= 0 andalso k <= 1000
             then SOME (D.G_atleast (natI s,natI k,D.Int_of_integer f)) else SOME D.G_need
         | _ => SOME D.G_need
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
                          SOME _ => SOME D.G_need
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
      case List.filter (fn (p, _) => has p low) cardPats of
        [] => NONE
      | [(pat, ci)] =>
          let
            val cm = valOf (search pat low)
            val prefixWords = rev (String.tokens Char.isSpace (String.substring (low,0,#start cm)))
            val count = case quantityBefore low cm of SOME n => SOME n
              | NONE => (case prefixWords of
                  w::_ => if List.exists (fn v => v=w) ["draw","drawing","pull","pulling","of","a","an"] then SOME 1 else NONE
                | [] => NONE)
            val withRepl = has "\\bwith replacement\\b|\\breplac(?:e|ing) (?:it|the card|each)\\b|\\bputting it back\\b" low
            val withoutRepl = has "\\bwithout replacement\\b" low
            val sizes = findall "([^ ]+)-card deck\\b|\\bdeck of ([^ ]+) cards\\b" low
            val standard = List.all (fn m => gameNumber (valOf (case grp low m 1 of SOME x => SOME x | NONE => grp low m 2)) = SOME 52) sizes
            val extra = has "\\b(?:exactly|at least|at most|draws|trials|attempts|times|jokers?|decks|and|or|not|neither|except)\\b" low
          in
            if length (findall pat low) <> 1 orelse not standard orelse extra orelse (withRepl andalso withoutRepl) then SOME D.G_need
            else case count of
                SOME k => if k < 0 orelse k > 1000 then SOME D.G_need
                  else if k = 1 then SOME (D.G_card_one (cardOf ci))
                  else SOME (D.G_card_k (cardOf ci,natI k,withRepl))
              | NONE => SOME D.G_need
          end
      | _ => SOME D.G_need
    else NONE

  fun games text =
    let
      val t0 = subCI "\226\136\146" "-" (collapse text)
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

  val TAIL = "\\s*(?:is (?:it|this|the argument|this argument) (?:a )?valid(?: argument)?|what (?:is this|form is this|fallacy is this)|name (?:the|this) (?:form|fallacy))\\??\\s*$"

  fun stripTail body =
    case search TAIL body of
      SOME {start, ...} => String.substring (body, 0, start)
    | NONE => body

  fun formOf body =
    let fun go _ [] = NONE
          | go i (p :: ps) = if has p body then SOME (List.nth (D.form_list, i)) else go (i + 1) ps
    in go 0 forms end

  fun unwrapFormula s =
    let val s=strip s val n=size s
    in if n>=2 andalso List.exists(fn q=>String.sub(s,0)=q)[#"'",#"\"",#"`"]
       then if String.sub(s,n-1)=String.sub(s,0) then SOME(String.substring(s,1,n-2)) else NONE
       else SOME s end

  fun logic text =
    let
      val low=lower(collapse text)
      val t=subCI "^using a truth table,?\\s+" "" low
      fun L r=SOME(D.RLogic r)
      fun need()=L D.L_need
      val clsTail="(?:(?:a )?tautology(?:, (?:a )?contradiction,? or contingent)?|(?:a )?contradiction|contingent|satisfiable|always true)"
      val named=search "^(?:name this argument form:|what argument form \\(or fallacy\\) is this:|identify the form of this argument:|what kind of argument is this\\?)\\s*(.+)$" t
      val namedBody=case named of SOME m=>SOME(g1 t m) | NONE=>if has "^if |\\btherefore\\b" t then SOME t else NONE
      val namedForm=case namedBody of NONE=>NONE | SOME b=>formOf(strip(stripTail b))
      val body=subCI "^(?:check whether the premises entail the conclusion:\\s*|(?:is(?: the argument)?|determine whether|does)\\s+)" "" t
      val argEnd="(?:\\. is it valid\\??|\\s+(?:is (?:a )?)?valid(?: argument)?[?.]?|\\s+hold as a valid inference\\??)$"
      val argBody=strip(subCI argEnd "" body)
      val argBody=case unwrapFormula argBody of SOME b=>b | NONE=>argBody
      val symbolic=findall ("\\|-|"^tsile^"|"^thf) argBody
      val marks=if null symbolic then findall "\\b(?:therefore|entails?)\\b" argBody else symbolic
      val logicalCue=has "\\btautolog\\w*\\b|\\bcontradiction\\b|\\bcontingent\\b|\\bsatisfiable\\b|\\balways true\\b|\\bargument\\b|\\binference\\b" t orelse not(null symbolic)
      fun parsePrem s =
        if strip s="" then SOME [] else
        let val parts=String.fields(fn c=>c= #"," orelse c= #";") s
            val fs=map parseF parts
        in if List.all isSome fs then SOME(map valOf fs) else NONE end
      fun formula s=case unwrapFormula s of NONE=>need()
        | SOME b=>case parseF b of NONE=>need() | SOME f=>L(D.L_formula f)
      fun classification()=
        case search ("^(?:is|determine whether)\\s+(.+?)\\s+(?:is )?"^clsTail^"[?.]?$") t of
          SOME m=>formula(g1 t m)
        | NONE=>
          (case search ("^(?:classify|evaluate|check)(?: the)?(?: formula| statement| expression)?\\s+(.+?)(?:: ?"^clsTail^")?[?.]?$") t of
             SOME m=>formula(g1 t m)
           | NONE=>if logicalCue then need() else NONE)
    in
      case namedForm of SOME f=>L(D.L_form f)
      | NONE=>if isSome named then need() else
        case marks of
          [m]=>let val prem=String.substring(argBody,0,#start m)
                   val concl=String.extract(argBody,#stop m,NONE)
               in case (parsePrem prem,parseF concl) of
                 (SOME ps,SOME c)=>L(D.L_argument(ps,c)) | _=>need() end
        | []=>classification()
        | _=>need()
    end

  (* ====================================================================
     algorithms
     ==================================================================== *)
  val ALGNUM = "[+-]?(?:[0-9]+(?:\\.[0-9]*)?|\\.[0-9]+)(?:/[+-]?(?:[0-9]+(?:\\.[0-9]*)?|\\.[0-9]+))?"
  fun algoNumber raw =
    let val s=strip raw
        val ds=String.fields (fn c=>c= #"/") s
        fun nonzero d=List.exists(fn c=> #"1"<=c andalso c<= #"9")(String.explode d)
        val denominatorOk=case ds of [_]=>true | [_,d]=>nonzero d | _=>false
        val unsignedPlus=if String.isPrefix "+" s then String.extract(s,1,NONE) else s
    in if has ("^"^ALGNUM^"$") s andalso denominatorOk then SOME(fracOf unsignedPlus) else NONE end

  fun algoList s =
    if strip s="" then SOME [] else
    let val xs=map algoNumber(String.fields(fn c=>c= #",") s)
    in if List.all isSome xs then SOME(map valOf xs) else NONE end

  fun oneList text =
    let val ms=findall "\\[([^\\[\\]]*)\\]" text
        val brackets=List.filter(fn c=>c= #"[" orelse c= #"]")(String.explode text)
    in case (ms,brackets) of
      ([m],[#"[",#"]"])=>SOME(g1 text m, String.substring(text,0,#start m)^"#list#"^String.extract(text,#stop m,NONE))
      | _=>NONE end

  fun algoEdges body =
    let
      val chunks=String.fields(fn c=>c= #"," orelse c= #";") body
      val node="([a-z][a-z0-9_]*|[0-9]+)"
      val edge="^\\s*"^node^"\\s*(<->|->|-|to)\\s*"^node^"\\s*(?:\\(\\s*("^ALGNUM^")\\s*\\)|(?:[:=]|weight|cost|w)?\\s*("^ALGNUM^"))\\s*$"
      fun parse chunk = case search edge (lower chunk) of
        NONE=>NONE
      | SOME m=>let val w=case grp chunk m 4 of SOME s=>SOME s | NONE=>grp chunk m 5
                in case Option.mapPartial algoNumber w of NONE=>NONE
                   | SOME v=>SOME(g1 chunk m,valOf(grp chunk m 2),valOf(grp chunk m 3),v) end
      val es=map parse chunks
    in if null es orelse not(List.all isSome es) then NONE else SOME(map valOf es) end

  fun graphParts t =
    case search "(?:\\b(?:edges|graph)\\s*:\\s*|^(?:graph with weighted edges|for the graph with edges)\\s+)" (lower t) of
      NONE=>NONE
    | SOME m=>
      let val prefixCommand=strip(String.substring(t,0,#start m))
          val after=String.extract(t,#stop m,NONE)
          val split=search "\\.?\\s+(?=(?:what|find|calculate|compute|give)\\b)" (lower after)
          val (body,command)=case split of
            SOME sm=>(String.substring(after,0,#start sm),String.extract(after,#stop sm,NONE))
          | NONE=>(after,prefixCommand)
          val body=subCI "[?.;,]$" "" (strip body)
      in if isSome split andalso prefixCommand<>"" then NONE
         else SOME(body,strip command) end

  fun algoListRequest t low =
    let
      fun need()=SOME(D.RAlgos D.A_need)
      val isSort=has "\\bsort\\b|\\bsorted\\b|\\bascending\\b|\\bdescending\\b" low
      val isSearch=has "\\bbinary search\\b" low
      val payload=case oneList t of SOME p=>SOME p | NONE=>
        if has "[\\[\\]]" t then NONE else
        case search ":\\s*" t of NONE=>NONE
        | SOME m=>SOME(subCI "[?.]$" "" (String.extract(t,#stop m,NONE)),String.substring(t,0,#start m)^" #list#")
    in
      case payload of NONE=>if isSort orelse isSearch then need() else NONE
      | SOME(body,cmd0)=>
        let val cmd=lower(collapse cmd0)
            val xs=algoList body
            val sortGrammar="^(?:sort(?: these numbers| the list| numbers)?(?: in (?:ascending|descending) order)? #list#(?: in (?:ascending|descending) order)?|put these in sorted order, ascending #list#|list these from largest to smallest \\(descending\\) #list#)[?.]?$"
            val searchGrammar="^(?:using )?binary search (?:for|find|target) ("^ALGNUM^") in (?:the )?(?:sorted )?list #list#(?:,? what index is it at)?[?.]?$"
            val searchAlt="^binary search (?:the )?list #list# for ("^ALGNUM^")\\. at which index \\(0-based\\)\\?$"
            val target=case search searchGrammar cmd of SOME m=>SOME m | NONE=>search searchAlt cmd
        in
          if isSearch then case (xs,target) of
              (SOME ns,SOME m)=>(case algoNumber(g1 cmd m) of SOME x=>SOME(D.RAlgos(D.A_bsearch(ns,x))) | NONE=>need())
            | _=>need()
          else if isSort andalso has sortGrammar cmd andalso not(has "ascending" cmd andalso has "descending" cmd) then
            (case xs of SOME ns=>SOME(D.RAlgos(D.A_sort(ns,has "descending" cmd))) | NONE=>need())
          else if isSort then need() else NONE
        end
    end

  fun dirEdges edges = List.concat(map(fn(a,op_,b,w)=>if op_="->" orelse op_="to" then [(a,(b,w))] else [(a,(b,w)),(b,(a,w))])edges)

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
      val t=subCI "\226\136\146" "-" (collapse text)
      val low=lower t
      fun need()=SOME(D.RAlgos D.A_need)
      val graphIntent=has "\\bshortest path\\b|\\bshortest distance\\b|\\bdijkstra\\b|\\bcheapest path\\b|\\bminimum spanning tree\\b|\\bmst\\b" low
      val mst=has "\\bminimum spanning tree\\b|\\bmst\\b" low
      val sp=has "\\bshortest path\\b|\\bshortest distance\\b|\\bdijkstra\\b|\\bcheapest path\\b" low
      val lead="(?:(?:what is|find|calculate|compute|give me) )?(?:the )?"
      val mstGrammar="^"^lead^"(?:(?:total )?weight of (?:the |its )?)?(?:minimum spanning tree|mst)(?: (?:weight|of|for|with))?[?.]?$"
      val spGrammar="^"^lead^"(?:shortest path|shortest distance|cheapest path)(?: (?:length|distance))? from ([a-z0-9_]+) to ([a-z0-9_]+)(?: (?:in|for|with))?(?: \\(dijkstra\\))?[?.]?$"
    in
      if has "\\bwrite\\b|\\bfunction\\b|\\bimplement\\w*\\b|\\bcode\\b|\\bprogram\\b|\\bpython\\b|\\bjavascript\\b|\\bjava\\b|\\bc\\+\\+" low then NONE
      else if graphIntent then
        if mst andalso sp then need() else
        (case graphParts t of NONE=>need()
        | SOME(body,command)=>
          case algoEdges body of NONE=>need()
          | SOME es=>
            if mst then
              if has mstGrammar (lower command) andalso List.all(fn (_,op_,_,_)=>op_<>"->" andalso op_<>"to") es
              then SOME(D.RAlgos(D.A_mst(map(fn(a,_,b,w)=>(a,(b,w)))es)))
              else need()
            else case search spGrammar (lower command) of NONE=>need()
              | SOME m=>
                let val s=g1 command m val e=valOf(grp command m 2)
                in SOME(D.RAlgos(D.A_sp(dirEdges es,nat(length es),s,e))) end)
      else if has "\\btime complexity\\b|\\bbig[- ]o\\b|\\bcomplexity of\\b|\\bhow fast is\\b" low then
        (case List.find(fn(nm,_)=>has("\\b"^nm^"\\b")low) complexityOrder of NONE=>NONE
         | SOME(_,i)=>SOME(D.RAlgos(D.A_complexity(nat i,has "\\baverage\\b" low))))
      else algoListRequest t low
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

  (* Whole ordinal phrases, rather than suffix matches: twenty-first is not
     first, -1st is not first, and 21.5th is not fifth. This parser is untrusted. *)
  val ordinalUnits = [("first", 1), ("second", 2), ("third", 3), ("fourth", 4),
    ("fifth", 5), ("sixth", 6), ("seventh", 7), ("eighth", 8), ("ninth", 9)]
  val ordinalWords = ordinalUnits @
    [("tenth",10), ("eleventh",11), ("twelfth",12), ("thirteenth",13),
     ("fourteenth",14), ("fifteenth",15), ("sixteenth",16), ("seventeenth",17),
     ("eighteenth",18), ("nineteenth",19), ("twentieth",20), ("thirtieth",30),
     ("fortieth",40), ("fiftieth",50)] @
    List.concat (map (fn (ten, n) => List.concat (map (fn (unit, k) =>
      [(ten ^ "-" ^ unit, n + k), (ten ^ " " ^ unit, n + k)]) ordinalUnits))
      [("twenty",20), ("thirty",30), ("forty",40)])
  val cardinalWords = ["zero", "one", "two", "three", "four", "five", "six", "seven",
    "eight", "nine", "ten", "eleven", "twelve", "thirteen", "fourteen", "fifteen",
    "sixteen", "seventeen", "eighteen", "nineteen", "twenty", "thirty", "forty",
    "fifty", "sixty", "seventy", "eighty", "ninety", "hundred", "thousand",
    "million", "billion", "and", "negative", "minus", "plus", "positive", "-", "+", "\226\136\146", "\226\128\147"]
  fun numberModifier token =
    List.exists (fn w => w = token) cardinalWords orelse
    (* Gather only adjacent numeric-looking tokens; exact ordinalValue below
       rejects a fraction/scientific spelling instead of discarding it. *)
    has "^(?:[+-]|\226\136\146|\226\128\147)?(?:[0-9]|\\.[0-9])" token
  fun ordinalValue phrase =
    case List.find (fn (word, _) => word = phrase) ordinalWords of
      SOME (_, n) => SOME n
    | NONE =>
      (case search "^([0-9]+)(st|nd|rd|th)$" phrase of
         NONE => NONE
       | SOME m =>
         let val n = intOf (g1 phrase m)
             val suffix = valOf (grp phrase m 2)
             val lastTwo = n mod 100
             val expected = if lastTwo >= 11 andalso lastTwo <= 13 then "th"
               else if n mod 10 = 1 then "st" else if n mod 10 = 2 then "nd"
               else if n mod 10 = 3 then "rd" else "th"
         in if n >= 1 andalso n <= 50 andalso suffix = expected
            then SOME (IntInf.toInt n) else NONE end)
  fun derivativeOrder low =
    case search "\\bderivative\\b" low of
      NONE => SOME 1
    | SOME m =>
      let
        val prefixText = String.substring (low, 0, #start m)
        val words = rev (String.tokens Char.isSpace prefixText)
        fun qualifiers flag (w :: ws) =
              if w = "partial" orelse w = "ordinary" orelse w = "total"
              then qualifiers flag ws
              else if w = "order" then
                (if flag then (true, w :: ws) else qualifiers true ws)
              else (flag, w :: ws)
          | qualifiers flag [] = (flag, [])
        val (explicit, words) = qualifiers false words
        fun preceding [] acc = rev acc
          | preceding (w :: ws) acc =
              if numberModifier w then preceding ws (w :: acc) else rev acc
      in
        case words of
          [] => if explicit then NONE else SOME 1
        | raw :: rest =>
          let val ordered = String.isSuffix "-order" raw
              val token = if ordered then String.substring (raw, 0, size raw - 6) else raw
              val indicated = explicit orelse ordered orelse numberModifier token orelse
                has "(?:st|nd|rd|th)(?:[^a-z0-9]|$)" token
              val prefix = preceding rest []
              val phrase = String.concatWith " " (rev prefix @ [token])
          in if token = "find" andalso not explicit andalso not ordered then SOME 1
             else if indicated then ordinalValue phrase else SOME 1 end
      end

  (* Complete coordinate-derivative commands. The HOL request retains both
     the polynomial's source variable and the coordinate being varied. *)
  fun coordinateCalc low =
    let
      val t0=subCI "[?.]$" "" (strip low)
      val functionAt=search ("^if ([fgh])\\(\\s*([a-z])\\s*\\)\\s*=\\s*(.+),\\s*what is \\1'\\(\\s*"^NUMRE^"\\s*\\)$") t0
      val t0=case functionAt of NONE=>t0 | SOME m=>
        "differentiate "^g1 t0 m^"("^valOf(grp t0 m 2)^")="^valOf(grp t0 m 3)^
        " at "^valOf(grp t0 m 2)^"="^valOf(grp t0 m 4)
      val t1=subCI "^(?:what is|find|compute|calculate|determine)\\s+(?:(?:the|a)\\s+)?" "" t0
      val pm=search ("\\s+(?:at|when|where)\\s+(?:([a-z])\\s*=\\s*)?"^NUMRE^"$") t1
      val point=case pm of NONE=>NONE | SOME m=>SOME(grp t1 m 1,valOf(grp t1 m 2))
      val t2=case pm of NONE=>t1 | SOME m=>String.substring(t1,0,#start m)
      val vm=search "\\s+(?:with respect to|wrt)\\s+([a-z])$" t2
      val explicit=case vm of NONE=>NONE | SOME m=>SOME(g1 t2 m)
      val t3=case vm of NONE=>t2 | SOME m=>String.substring(t2,0,#start m)
      val dd=search "^d/d([a-z])\\s+(.+)$" t3
      fun order prefix =
        let val p=strip(subCI "(?:^|\\s)(?:partial|ordinary|total)$" "" (strip prefix))
            val p=strip(subCI "^partial\\s+" "" p)
            val p=strip(subCI "(?:-|\\s)order$" "" p)
        in if p="" then SOME 1 else ordinalValue p end
      val de=search "^(.*?)derivative(?: of)?\\s+(.+)$" t3
      val diff=search "^differentiate\\s+(.+)$" t3
      val opExpr=case dd of SOME m=>SOME(1,valOf(grp t3 m 2),SOME(g1 t3 m))
        | NONE=>case diff of SOME m=>SOME(1,g1 t3 m,explicit)
        | NONE=>case de of NONE=>NONE | SOME m=>
          (case order(g1 t3 m) of NONE=>NONE | SOME n=>SOME(n,valOf(grp t3 m 2),explicit))
    in
      case opExpr of NONE=>NONE | SOME(n,expression,target0)=>
      let val fm=search "^[fgh]\\(\\s*([a-z])\\s*\\)\\s*=\\s*(.+)$" expression
          val declared=case fm of NONE=>NONE | SOME m=>SOME(g1 expression m)
          val expr=case fm of NONE=>expression | SOME m=>valOf(grp expression m 2)
          val target=case target0 of SOME v=>SOME v | NONE=>declared
          val compatible=case (target0,declared) of (SOME a,SOME b)=>a=b | _=>true
          val ddCompatible=case (dd,explicit,target0) of (SOME _,SOME a,SOME b)=>a=b | _=>true
      in
        if not compatible orelse not ddCompatible orelse has "[0-9]e[+-]?[0-9]" expr then NONE else
        case (parsePoly expr,target) of
          (SOME(poly,source),SOME v)=>
            (case point of NONE=>SOME(D.C_partial(poly,source,v,nat n))
             | SOME(pointVar,value)=>if (case pointVar of NONE=>true | SOME w=>w=v)
                then SOME(D.C_partial_at(poly,source,v,nat n,fracOf value)) else NONE)
        | _=>NONE
      end
    end

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
            NONE => if has "with respect to|\\bwrt\\b|\\bd/d[a-z]\\b|\\b[fgh]\\(\\s*[a-z]\\s*\\)\\s*=" low
                    then SOME(D.RCalc(D.C_need(nat 2))) else NONE
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
              if has "(?<!anti-)\\bderivative\\b|\\bdifferentiate\\b|\\bd/d[a-z]\\b|\\bf'\\(" low andalso
                 (has "with respect to|\\bwrt\\b|\\bd/d[a-z]\\b" low orelse
                  has "\\b[fgh]\\(\\s*([a-z])\\s*\\)\\s*=" low)
              then SOME(D.RCalc(case coordinateCalc low of SOME r=>r | NONE=>D.C_need(nat 2)))
              else if List.exists (fn v => v <> var) vars then SOME (D.RCalc (D.C_need (nat 2)))
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
                  val n = case derivativeOrder low of SOME n => n | NONE => 0
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
  (* Payload bytes never pass through whitespace or case normalization. Only
     the command view is normalized; quoted spans and colon tails are masked.
     Quotes delimit literal bytes, not a second JSON escape language. *)
  fun literalView text =
    let
      val n = size text
      fun at i = String.sub (text, i)
      fun opener i = let val c = at i in
        c = #"`" orelse c = #"\"" orelse
        (c = #"'" andalso (i = 0 orelse not (Char.isAlphaNum (at (i-1))))) end
      fun close q i =
        if i >= n then NONE
        else if at i = q then SOME i
        else if q <> #"`" andalso at i = #"\\" andalso i+1 < n then close q (i+2)
        else close q (i+1)
      fun go i start parts literals =
        if i >= n then (String.concat (rev (String.extract(text,start,NONE)::parts)), rev literals, false)
        else if opener i then
          (case close (at i) (i+1) of
             NONE => (String.concat (rev (String.substring(text,start,i-start)::parts)),rev literals,true)
           | SOME j => go (j+1) (j+1)
               (" " :: String.substring(text,start,i-start)::parts)
               ((at i,String.substring(text,i+1,j-i-1),j+1)::literals))
        else go (i+1) start parts literals
    in go 0 0 [] [] end

  fun trimSpace s =
    let val n=size s
        fun left i = if i<n andalso Char.isSpace(String.sub(s,i)) then left(i+1) else i
        fun right i = if i>0 andalso Char.isSpace(String.sub(s,i-1)) then right(i-1) else i
        val a=left 0 val b=right n
    in if b<a then "" else String.substring(s,a,b-a) end

  fun baseOf "binary" = 2 | baseOf "bin" = 2 | baseOf "octal" = 8 | baseOf "oct" = 8
    | baseOf "decimal" = 10 | baseOf "dec" = 10 | baseOf "hexadecimal" = 16 | baseOf "hex" = 16
    | baseOf _ = 10

  fun formats text =
    let
      val (masked, spans, malformed) = literalView text
      val literals = map #2 spans
      val backticks = List.all (fn (q,_,_) => q = #"`") spans
      (* A colon outside a literal starts a raw payload. Find its offset in
         the original prefix, because masking deliberately changes lengths. *)
      fun colon i = if i >= size text then NONE else
        if String.sub(text,i) = #":" then SOME i
        else if List.exists (fn c => String.sub(text,i)=c) [#"`",#"\"",#"'"]
             andalso not (String.sub(text,i)= #"'" andalso i>0 andalso Char.isAlphaNum(String.sub(text,i-1)))
             then NONE else colon(i+1)
      val cp = colon 0
      val command = case cp of SOME i => String.substring(text,0,i) | NONE => masked
      val low = lower (collapse command)
      val raw = Option.map (fn i => trimSpace(String.extract(text,i+1,NONE))) cp
      val p0 = case literals of [s] => if malformed then NONE else SOME s
                | [] => if malformed then NONE else raw
                | _ => NONE
      fun wrapped body s = List.exists (fn q => body=q^s^q orelse body=q^s^q^"?") ["`","\"","'"]
      val p = case raw of
          SOME body =>
            if List.exists (fn q => String.isPrefix q body) ["`","\"","'"] then
              (case (literals,malformed) of ([s],false) => if wrapped body s then SOME s else NONE | _ => NONE)
            else SOME body
        | NONE => p0
      val jsonOp = has "\\bvalid json\\b|\\bis this json\\b|\\bparse (?:this )?json\\b" low
      val b64Op = has "\\bbase ?64\\b" low andalso has "\\bdecode\\b|\\bencode\\b|\\b(?:from|to|in) base ?64\\b" low
      val urlOp = has "\\burl[- ]?(?:encode|decode|encoding|decoding)\\b|\\bpercent[- ]encod" low
      val hashes = findall "\\b(sha-?256|sha-?1|md5)\\b" low
      val hashOp = not(null hashes) andalso has "\\bhash\\b|\\bdigest\\b|\\bchecksum\\b|\\bof\\b" low
      (* Check the entire command, not just the presence of an operation
         keyword. Unknown prefixes/suffixes may change the requested bytes. *)
      val lead = "(?:(?:what is|what's|give me|compute|calculate|find|please) )?"
      val hashGrammar = "^" ^ lead ^ "(?:the )?(?:sha-?256|sha-?1|md5)(?: (?:hash|digest|checksum))?(?: (?:of|for))?(?: please)? ?[?.!]*$"
      val b64Grammar = "^" ^ lead ^ "(?:base ?64 (?:encode|decode)(?: (?:this|the string|the text))?|(?:encode|decode)(?: the)?(?: string| text)?(?: (?:in|to|from))? base ?64|(?:in|to|from) base ?64(?: \\((?:encode|decode)\\))?)(?: please)? ?[?.!]*$"
      val urlGrammar = "^" ^ lead ^ "(?:url[- ]?(?:encode|decode|encoding|decoding)|percent[- ]encoding)(?: (?:this|the string|the text))?(?: please)? ?[?.!]*$"
      val jsonGrammar = "^(?:is this (?:valid )?json|is (?:this )?json valid|parse (?:this )?json(?: and tell me if it is valid json)?)(?: please)? ?[?.!]*$"
      val commandOk = if jsonOp then has jsonGrammar low else if hashOp then has hashGrammar low
                      else if b64Op then has b64Grammar low
                      else if urlOp then has urlGrammar low else true
      val tail = case rev spans of [] => "" | (_,_,stop)::_ => lower(collapse(String.extract(text,stop,NONE)))
      val tailOk = isSome cp orelse
        has "^(?:[?.!]*|please[?.!]*|(?:in|to|from) base ?64(?: \\((?:encode|decode)\\))?[?.!]*)$" tail
      val nops = length(List.filter (fn x=>x) [jsonOp,b64Op,urlOp,hashOp])
      fun F r = SOME(D.RFormats r)
      fun need () = F D.F_need
      fun withPayload f = case p of SOME s => F(f(bytes s)) | NONE => need()
    in
      if nops>1 orelse (nops>0 andalso (not commandOk orelse not tailOk)) then need()
      else if jsonOp then
        (* Raw JSON includes its own quotation syntax. Outer backticks alone
           may delimit JSON; a colon body is otherwise consumed in full. *)
        (case raw of
           SOME body =>
             if String.isPrefix "`" body then
               (case (literals,malformed) of ([s],false) => if wrapped body s then F(D.F_json(bytes s)) else need() | _ => need())
             else F(D.F_json(bytes body))
         | NONE => case (literals,malformed) of ([s],false) => if backticks then F(D.F_json(bytes s)) else need() | _ => need())
      else if b64Op then
        if has "\\bdecode\\b|\\bfrom base ?64\\b" low andalso has "\\bencode\\b|\\bto base ?64\\b" low then need()
        else if has "\\bdecode\\b|\\bfrom base ?64\\b" low then withPayload D.F_b64dec
        else withPayload D.F_b64enc
      else if hashOp then
        (case hashes of
           [m] => let val algo=String.translate(fn #"-"=>"" | c=>String.str c)(g1 low m)
                      val a=if algo="sha256" then D.H_sha256 else if algo="sha1" then D.H_sha1 else D.H_md5
                  in withPayload(fn b=>D.F_hash(a,b)) end
         | _ => need())
      else if urlOp then
        if has "decode|decoding" low andalso has "encode|encoding" low then need()
        else if has "decode|decoding" low then withPayload D.F_urldec else withPayload D.F_urlenc
      else formatsRest (collapse text) (subCI "\226\136\146" "-" (lower(collapse text)))
    end
  and formatsRest t low =
    let
      fun F r = SOME(D.RFormats r)
      val bases="(binary|bin|octal|oct|decimal|dec|hexadecimal|hex)"
      val intent=has "\\bconvert\\b|\\bwhat is\\b" low andalso has ("\\b"^bases^"\\b") low
      (* No suffix search: the entire numerical request must match. *)
      val bm=search ("^(?:convert|what is)\\s+([+-]?(?:0x[0-9a-f]+|0b[01]+|0o[0-7]+|[0-9a-f]+))"
        ^"(?:\\s+\\(?(?:in |from )?"^bases^"\\)?)?\\s+(?:to|in|into|as)\\s+"^bases^"[?.]?$") low
    in
      case bm of
        SOME m =>
          let val tok=g1 low m
              val neg=String.isPrefix "-" tok
              val unsigned=if neg orelse String.isPrefix "+" tok then String.extract(tok,1,NONE) else tok
              val pre=if size unsigned>=2 then String.substring(unsigned,0,2) else ""
              val prefix=if pre="0x" then SOME 16 else if pre="0b" then SOME 2 else if pre="0o" then SOME 8 else NONE
              val src=Option.map baseOf(grp low m 2)
              val dst=baseOf(valOf(grp low m 3))
              val base=case prefix of SOME b=>b | NONE=>(case src of SOME b=>b | NONE=>10)
              val digs=case prefix of SOME _=>String.extract(unsigned,2,NONE) | NONE=>unsigned
          in if (isSome prefix andalso isSome src andalso prefix<>src)
                   orelse (base=10 andalso has "^[0-9]+e[0-9]+$" digs) then F D.F_need
             else if neg then F(D.F_signed_base(bytes tok,nat base,nat dst,true,bytes digs))
             else F(D.F_base(bytes tok,nat base,nat dst,bytes digs)) end
      | NONE => if intent then F D.F_need else dayOf t low
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
