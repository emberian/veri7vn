(* UNTRUSTED. The English recognizer for the stores family: a hand port of the
   regular expressions, word tables and branch order of
     upstream/root/specialists/cooking/organ_nutrition_v1.py     (NutritionOrgan: answer, match, _sing)
     upstream/root/specialists/cooking-v3/organ_nutrition_v2.py  (NutritionOrganV2.normalize, narrowing)
     upstream/root/specialists/cooking-v3/organ_nutrition_v3.py  (NutritionOrganV3.normalize)
     upstream/root/specialists/cooking-v3-r2/organ_cooking_v3_r2.py (NOT_MINE / MINE boundary)
     upstream/root/specialists/warehouse/organ_site_v2.py        (SiteOrgan.answer and its readers)
     upstream/root/specialists/warehouse-r2/organ_site_v3.py     (unknown-item narrowing)
   and of the shared narrowing rule narrow_v1.py (the port is lane G's,
   src/extract/quantity/recognizer.sml, structure Narrow).

   It reads the question and, for cooking, picks the USDA entry the words most
   plausibly name (the organ's match(): every question word present, then the
   organ's penalties, then fewest extra words); for the site it resolves
   follow-ups, pronouns and ellipsis against the session and names the item,
   zone and sensor kind. It computes no value and decides no decline: that is
   the HOL kernel (Stores.nreply, Stores.site_reply) over the rows the fetch
   shim returns. Inherited patterns are in `pats` below with the organ's own
   text; tables_check.py compares those and the inherited word tables. Added
   quantity roles consume ExactNumeric-issued values and have separate probes.

   Matching is case-insensitive: the text is lower-cased and the pattern is
   passed as written (Regex.compile folds its literals; lane S17 fix). Spans
   found in the lower-cased text index the original text (ASCII folding keeps
   byte positions), so words echoed in replies keep their case.

   Beyond parity: polite/content-frame normalization is shared by all cooking
   variants, food-name "total" is preserved, fractional amounts are supported,
   and all lexical matches are supplied for the kernel's serving check. These
   intentional changes are covered by probes.json and the fresh-seed scorer. *)
structure Rx =
struct
  val cache : (string * Regex.regex) list ref = ref []
  fun lower s = String.map Char.toLower s
  fun re p =
    case List.find (fn (q, _) => q = p) (!cache) of
      SOME (_, r) => r
    | NONE => let val r = Regex.compile p in cache := (p, r) :: !cache; r end
  fun search p s = Regex.search (re p) (lower s)
  fun has p s = isSome (search p s)
  fun findall p s = Regex.findall (re p) (lower s)
  fun grp s m g = Regex.group s m g
  fun g s m i = valOf (grp s m i)
  fun whole s m = Regex.whole s m

  (* re.sub(p, f, s, count): f gets the match and the original text *)
  fun subWith p (f : Regex.match -> string) (count : int) s =
    let
      val ms = findall p s
      val ms = if count > 0 then List.take (ms, Int.min (count, length ms)) else ms
      fun go i [] acc = String.concat (rev (String.extract (s, i, NONE) :: acc))
        | go i ((m as {start, stop, ...} : Regex.match) :: rest) acc =
            go stop rest (f m :: String.substring (s, i, start - i) :: acc)
    in go 0 ms [] end
  fun sub p rep count s = subWith p (fn _ => rep) count s

  fun collapse s = String.concatWith " " (String.tokens Char.isSpace s)
  fun words s = length (String.tokens Char.isSpace s)

  (* str.rstrip(chars) *)
  fun rstrip chars s =
    let fun go n = if n > 0 andalso Char.contains chars (String.sub (s, n - 1)) then go (n - 1) else n
    in String.substring (s, 0, go (size s)) end
  fun strip s = rstrip " \t\n\r" (let fun go i = if i < size s andalso Char.isSpace (String.sub (s, i)) then go (i + 1) else i
                                  in String.extract (s, go 0, NONE) end)

  (* str.replace(a, b): every non-overlapping occurrence, case-sensitive *)
  fun replaceAll a b s =
    if a = "" then s else
    let
      val n = size a
      fun go i j acc =
        if j + n > size s then String.concat (rev (String.extract (s, i, NONE) :: acc))
        else if String.substring (s, j, n) = a then go (j + n) (j + n) (b :: String.substring (s, i, j - i) :: acc)
        else go i (j + 1) acc
    in go 0 0 [] end

  (* re.sub(re.escape(a), b, s, flags=re.I) *)
  fun replaceAllCI a b s =
    if a = "" then s else
    let
      val la = lower a and ls = lower s
      val n = size a
      fun go i j acc =
        if j + n > size s then String.concat (rev (String.extract (s, i, NONE) :: acc))
        else if String.substring (ls, j, n) = la then go (j + n) (j + n) (b :: String.substring (s, i, j - i) :: acc)
        else go i (j + 1) acc
    in go 0 0 [] end

  fun isWord c = Char.isAlphaNum c orelse c = #"_"
  (* re.search(r"\b" + re.escape(key) + r"\b", text) for an already lower-cased text and key *)
  fun hasWordPhrase key text =
    let
      val n = size key and m = size text
      fun wordAt i = i >= 0 andalso i < m andalso isWord (String.sub (text, i))
      fun bnd i = wordAt (i - 1) <> wordAt i
      fun go j = j + n <= m andalso
        ((String.substring (text, j, n) = key andalso bnd j andalso bnd (j + n)) orelse go (j + 1))
    in n > 0 andalso go 0 end

  (* re.findall(r"[a-z]+", s) on an already lower-cased s *)
  fun alphaRuns s = String.tokens (fn c => not (c >= #"a" andalso c <= #"z")) s
end

(* The organs' patterns, verbatim (Python source text, SML-escaped). Keys name
   the organ constant; tables_check.py checks each against the organ module. *)
structure Pats =
struct
  val pats : (string * string) list = [
    ("nutrition_v1.NUTRIENTS.saturated fat", "\\bsaturated fats?\\b|\\bsat(?:urated)? fat\\b"),
    ("nutrition_v1.NUTRIENTS.calories", "\\bcalories?\\b|\\bkcal\\b|\\benergy\\b"),
    ("nutrition_v1.NUTRIENTS.protein", "\\bproteins?\\b"),
    ("nutrition_v1.NUTRIENTS.fat", "\\b(?:total )?fats?\\b"),
    ("nutrition_v1.NUTRIENTS.carbohydrate", "\\bcarb(?:ohydrate)?s?\\b"),
    ("nutrition_v1.NUTRIENTS.fiber", "\\bfib(?:er|re)s?\\b"),
    ("nutrition_v1.NUTRIENTS.sugar", "\\bsugars?\\b"),
    ("nutrition_v1.NUTRIENTS.sodium", "\\bsodium\\b"),
    ("nutrition_v1.NUTRIENTS.calcium", "\\bcalcium\\b"),
    ("nutrition_v1.NUTRIENTS.iron", "\\biron\\b"),
    ("nutrition_v1.NUTRIENTS.vitamin c", "\\bvitamin c\\b"),
    ("nutrition_v1.NUTRIENTS.potassium", "\\bpotassium\\b"),
    ("nutrition_v1.NUTRIENTS.cholesterol", "\\bcholesterol\\b"),
    ("nutrition_v1.ASK", "\\b(?:how much|how many|what(?:'s| is)? the|amount of|content)\\b"),
    ("nutrition_v1.COUNT", "\\b(\\d+(?:\\.\\d+)?|an?|one|two|three)\\s+(?:medium |large |small )?([a-z]+)\\b"),
    ("nutrition_v2.CLITIC", "(?i)\\b(\\w+)(?:'|\226\128\153)(?:s|re|ve|ll|d|m)\\b"),
    ("nutrition_v2.NEG", "(?i)\\b(\\w+)n(?:'|\226\128\153)t\\b"),
    ("nutrition_v2.FRAME", "(?i)\\b(?:can|could|would|will) you (?:please )?(?:tell|give|show|let) me\\b|\\bi(?:'d| would) like to know\\b|\\bi (?:want|need) to know\\b|\\bdo you know\\b|\\blet me know\\b|\\bplease\\b"),
    ("nutrition_v2.MEASURE_NOUN", "(?i)\\b(?:contents?|levels?|values?|amounts?|quantity|quantities|count|total)\\b(?:\\s+(?:of|in|for))?"),
    ("cooking_v3_r2.NOT_MINE", "\\b(?:kinetic|potential energy|lifted|m/s|joules?|kJ|melt\\w*|ice|specific heat|torque|force|velocity|accelerat\\w*)\\b"),
    ("cooking_v3_r2.MINE", "\\b(?:cups?|tbsp|tablespoons?|teaspoons?|servings?|recipe|calories|protein|fat|carb\\w*|sodium|fib(?:er|re)|USDA|food|eat)\\b"),
    ("site_v2.KIND_WORDS.temperature", "\\b(?:temperature|temp|warm|hot|cold|heat)\\b"),
    ("site_v2.KIND_WORDS.humidity", "\\b(?:humidity|humid|damp|moisture)\\b"),
    ("site_v2.KIND_WORDS.light", "\\b(?:light|lighting|bright|dark|lux)\\b"),
    ("site_v2.KIND_WORDS.co2", "\\b(?:co2|carbon dioxide|air quality|stuffy)\\b"),
    ("site_v2.KIND_WORDS.occupancy", "\\b(?:occupancy|anyone|anybody|people|busy|occupied)\\b|\\bhow many (?:people|staff)\\b"),
    ("site_v2.STOCK", "\\bhow many\\b|\\bcount\\b|\\bstock\\b|\\bdo we (?:still )?have\\b|\\bquantity\\b|\\bleft\\b|\\bin stock\\b"),
    ("site_v2.WHERE", "\\bwhere\\b|\\bwhich (?:bin|aisle|shelf|location)\\b|\\bfind\\b|\\bkeep\\b|\\blocated\\b"),
    ("site_v2.RUNOUT", "\\brun(?:s|ning)? out\\b|\\bhow long\\b|\\bdays? of\\b|\\blast\\b|\\bempty\\b|\\busing\\b|\\busage\\b|\\bburn rate\\b"),
    ("site_v2.LOW", "\\b(?:running low|low on|what'?s low|anything low|need(?:s)? reorder\\w*|reorder list|below reorder|low stock)\\b"),
    ("site_v2.RANGE", "\\bnormal\\b|\\bok(?:ay)?\\b|\\bwithin range\\b|\\bin range\\b|\\bwrong\\b|\\bproblem\\b|\\bfine\\b|\\btoo (?:warm|hot|cold|humid|dark|bright|stuffy)\\b"),
    ("site_v2.STATUS", "\\b(?:status|how is|how'?s|check on|report on)\\b"),
    ("site_v2.REORDER", "\\b(?:re-?order|order|restock)\\s+(?P<n>\\d+)\\s+(?:more\\s+|of\\s+(?:the\\s+)?)?(?P<x>.+?)[.!?]?$"),
    ("site_v2.YES", "^\\s*(?:yes|yep|yeah|confirm|do it|go ahead|ok(?:ay)?|sure)\\b"),
    ("site_v2.NO", "^\\s*(?:no|nope|cancel|don'?t|stop)\\b"),
    ("site_v2.FOLLOW", "^\\s*(?:and|what about|how about|what of|same for)\\b"),
    ("site_v2.NEIGHBOUR", "\\b(?:next to it|next bin|next one|beside it|adjacent|neighbou?ring|next door|the one after)\\b"),
    ("site_v2.SELF", "\\bwhat can you (?:see|sense|measure|do|tell me)\\b|\\bwhat (?:do you|can you) know\\b")]

  (* Inline patterns of the organs (in their code, not module constants). *)
  val inline : (string * string) list = [
    ("nutrition_v1.in", "\\bin\\b"),
    ("nutrition_v2.of_in", "(?i)\\b(of|in)\\s+(?:of|in)\\b"),
    ("site_v2.pronoun", "\\b(?:it|that|them|those|they|this one)\\b"),
    ("site_v2.howmany_not_days", "\\bhow many\\b(?!.*\\bdays?\\b)"),
    ("site_v2.follow_strip", "^\\s*(?:and|what about|how about|what of|same for)\\s+(?:the\\s+)?"),
    ("site_v2.what_strip", "^(?:how many|what'?s the stock of|where (?:are|is|do we keep|can i find)|which bin has|give me the count on|when will we run out of|how long until|do we still have)\\s+(?:the\\s+)?"),
    ("site_v2.what_tail", "\\s+(?:do we have|are left|count|run out|left)$"),
    ("site_v2.aisle", "\\baisle\\s*(\\d+)\\b")]

  fun clean p =
    (* (?i) is a no-op here (matching is always case-insensitive); named groups become plain groups *)
    let
      val p = if String.isPrefix "(?i)" p then String.extract (p, 4, NONE) else p
      fun go s = case Substring.position "(?P<" (Substring.full s) of
                   (a, b) => if Substring.isEmpty b then s
                             else let val rest = Substring.string b
                                      val close = valOf (CharVector.findi (fn (_, c) => c = #">") rest)
                                  in go (Substring.string a ^ "(" ^ String.extract (rest, #1 close + 1, NONE)) end
    in go p end

  fun get k =
    case List.find (fn (k', _) => k' = k) (pats @ inline) of
      SOME (_, p) => clean p
    | NONE => raise Fail ("no pattern " ^ k)
end

(* lane G's port of narrow_v1 (src/extract/quantity/recognizer.sml) *)
structure Narrow =
struct
  fun splits ends t =
    let
      val t = Rx.collapse t
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
  fun narrative t = sentences t >= 3 orelse Rx.words t > 40 orelse Rx.has RELATION t orelse Rx.has RATE t
  fun short_direct t = sentences t <= 2 andalso Rx.words t <= 25 andalso not (narrative t)
end

structure Num =
struct
  (* "28.3495" -> mk_rat 283495 10000, exactly; "-7", "1e-05" (Python repr) allowed *)
  fun ratOf (lit : string) : Stores.rat =
    let
      val (mant, ex) = case String.fields (fn c => c = #"e" orelse c = #"E") lit of
                         [a] => (a, 0)
                       | [a, b] => (a, valOf (Int.fromString (String.translate (fn #"+" => "" | c => String.str c) b)))
                       | _ => raise Fail ("bad numeral " ^ lit)
      val (neg, body) = if String.isPrefix "-" mant then (true, String.extract (mant, 1, NONE)) else (false, mant)
      val (ip, fp) = case String.fields (fn c => c = #".") body of
                       [a] => (a, "")
                     | [a, b] => (a, b)
                     | _ => raise Fail ("bad numeral " ^ lit)
      val num = valOf (IntInf.fromString (ip ^ fp))
      val e = ex - size fp
      val (num, den) = if e >= 0 then (num * IntInf.pow (10, e), 1) else (num, IntInf.pow (10, ~e))
    in Stores.mk_rat (if neg then IntInf.~ num else num) den end

  fun intOf (s : string) : Stores.int = Stores.mk_int (valOf (IntInf.fromString s))
end

(* ---------------------------------------------------------------- cooking *)
structure Cook =
struct
  structure S = Stores

  val nutPats =
    map (fn n => let val k = S.nutrient_key n in (k, n, Pats.get ("nutrition_v1.NUTRIENTS." ^ k)) end) S.nutrient_order

  val FILLER = String.tokens Char.isSpace
    ("how much many is are there in of does do a an the has have contain contains what whats what's per serving "
     ^ "amount grams gram g kg oz lb cup cups tbsp tsp tablespoon tablespoons teaspoon teaspoons ounce ounces "
     ^ "pound pounds kilogram kilograms please tell me give me me about with")
  val PRODUCT_TYPES = ["oil", "spice", "babyfood", "beverage", "candy", "candie", "snack", "fast", "restaurant", "cereal",
    "sauce", "soup", "dessert", "formulated", "school", "infant", "margarine", "shortening", "salad", "flour", "gravy"]
  val SPECIALTY = ["sprouted", "stir", "dehydrated", "freeze", "imported", "industrial", "commercial", "prepared", "mix",
    "fortified", "enriched", "unenriched", "immature", "pickled", "flavored", "sweetened", "juice", "canned",
    "frozen", "dried", "instant", "peel", "zest", "rind", "yolk", "link", "sausage", "bran", "germ", "leaf", "leave",
    "sheep", "goat", "buffalo", "human", "smoked", "native", "alaska", "navajo", "hopi", "apache", "shoshone",
    "indian", "plains", "paste", "butter", "blanched", "imitation", "producer", "buttermilk", "dry", "evaporated",
    "condensed", "powder", "duck", "goose", "quail", "chocolate", "cocoa", "beverage", "homemade", "honey", "oil",
    "shake", "malted", "candied", "glazed", "breaded", "battered"]
  val VARIANT = ["green", "yellow", "orange", "purple", "low", "reduced", "nonfat", "lowfat", "skim", "light", "lite",
    "unsalted", "decaffeinated", "diet"]
  val PREP = ["raw", "cooked", "boiled", "roasted", "fried", "canned", "frozen", "dried", "baked", "grilled"]
  val WORDNUM = [("a", (1, 1)), ("an", (1, 1)), ("one", (1, 1)), ("two", (2, 1)), ("three", (3, 1)),
                 ("half a", (1, 2)), ("half an", (1, 2))]

  fun mem x xs = List.exists (fn y => y = x) xs
  fun uniq xs = List.foldl (fn (x, acc) => if mem x acc then acc else acc @ [x]) [] xs

  fun sing w0 =
    let
      val w = Rx.lower w0
      val n = size w
      fun ends s = String.isSuffix s w
    in
      if n > 4 andalso ends "ies" then String.substring (w, 0, n - 3) ^ "y"
      else if n > 4 andalso ends "oes" then String.substring (w, 0, n - 2)
      else if n > 3 andalso ends "es" andalso Char.contains "shx" (String.sub (w, n - 3)) then String.substring (w, 0, n - 2)
      else if n > 3 andalso ends "s" andalso not (ends "ss") then String.substring (w, 0, n - 1)
      else w
    end

  (* re.search(r"\b[A-Z]{3,}\b", desc.replace("USDA", "")), case-sensitive *)
  fun brand desc =
    let
      val d = Rx.replaceAll "USDA" "" desc
      val n = size d
      fun up i = i >= 0 andalso i < n andalso Char.isUpper (String.sub (d, i))
      fun wd i = i >= 0 andalso i < n andalso Rx.isWord (String.sub (d, i))
      fun go i =
        if i >= n then false
        else if up i andalso not (up (i - 1)) then
          let fun runEnd j = if up j then runEnd (j + 1) else j
              val j = runEnd i
          in (j - i >= 3 andalso not (wd (i - 1)) andalso not (wd j)) orelse go j end
        else go (i + 1)
    in go 0 end

  type food = {fid : IntInf.int, desc : string, toks : string list, seg0 : string list, brand : bool}

  fun mkFood (fid, desc) : food =
    let
      val low = Rx.lower desc
      val seg = case String.fields (fn c => c = #",") low of s :: _ => s | [] => ""
    in {fid = fid, desc = desc, toks = uniq (map sing (Rx.alphaRuns low)),
        seg0 = uniq (map sing (Rx.alphaRuns seg)), brand = brand desc}
    end

  (* Preference follows NutritionOrgan.match, but all lexical matches remain
     in play; the kernel checks their scaled servings before accepting. *)
  fun matchFood (foods : food vector) (phrase : string) : (food * food list) option =
    let
      val ws = Rx.alphaRuns (Rx.lower phrase)
      val want = uniq (List.mapPartial (fn t => if not (mem t FILLER) andalso size t > 1 then SOME (sing t) else NONE) ws)
      val head = case rev ws of h :: _ => sing h | [] => ""
      fun pen (f : food) =
        let
          val toks = #toks f
          fun inT w = mem w toks
          fun inW w = mem w want
          val p = (if #brand f then 6 else 0)
            + (if List.exists (fn w => mem w PRODUCT_TYPES andalso not (inW w)) (#seg0 f) then 8 else 0)
            + 3 * length (List.filter (fn w => mem w SPECIALTY andalso not (inW w)) toks)
            + 2 * length (List.filter (fn w => mem w VARIANT andalso not (inW w)) toks)
            + (if inW "egg" andalso inT "white" andalso not (inW "white") then 3 else 0)
            + (if inT "skin" andalso not (inT "flesh") andalso not (inW "skin") then 3 else 0)
            + (if inT "salt" andalso not (inT "without") andalso not (inW "salt") then 1 else 0)
          val p = if not (List.exists inW PREP) then (if inT "raw" then p - 2 else p)
                  else if inW "cooked" andalso inT "boiled" then p - 1 else p
          val p = if head <> "" andalso #seg0 f = [head] then p - 3 else p
        in p end
      fun key (f : food) = (pen f, length (List.filter (fn w => not (mem w want)) (#toks f)), size (#desc f), #fid f)
      fun lt ((a1, b1, c1, d1), (a2, b2, c2, d2)) =
        a1 < a2 orelse (a1 = a2 andalso (b1 < b2 orelse (b1 = b2 andalso (c1 < c2 orelse (c1 = c2 andalso d1 < d2)))))
    in
      if null want then NONE
      else
        let
          val hits = Vector.foldr (fn (f, acc) => if List.all (fn w => mem w (#toks f)) want then (key f, f) :: acc else acc)
                       [] foods
          (* stable merge sort on the organ's key *)
          fun merge ([], ys) = ys
            | merge (xs, []) = xs
            | merge (x :: xs, y :: ys) = if lt (#1 y, #1 x) then y :: merge (x :: xs, ys) else x :: merge (xs, y :: ys)
          fun msort [] = []
            | msort [x] = [x]
            | msort xs = let val h = length xs div 2
                         in merge (msort (List.take (xs, h)), msort (List.drop (xs, h))) end
          val sorted = msort hits
        in
          case sorted of
            [] => NONE
          | ((p0, _, _, _), best) :: _ =>
              let val near = sorted  (* Every lexical match remains a possible reading. *)
              in SOME (best, map #2 near) end
        end
    end

  fun unitAlternation () =
    let
      val names = map (fn (n, _) => n) S.mass_names @ map (fn (n, _) => n) S.measure_names
      fun ins (x, []) = [x]
        | ins (x, y :: ys) = if size x > size y then x :: y :: ys else y :: ins (x, ys)
    in String.concatWith "|" (List.foldl ins [] names) end
  val MARKER = "qnum[0-9]+q"
  val NUMBER = "(?:" ^ MARKER ^ "\\s+" ^ MARKER ^ ")|" ^ MARKER ^ "|an?|one|two|three|half an?|half a"
  val AMOUNT = "\\b(" ^ NUMBER ^ ")\\s*(" ^ unitAlternation () ^ ")\\b(?:\\s+of)?"
  (* Count modifiers describe the portion, so they are removed before matching
     food descriptions and carried explicitly into the checked request. *)
  val COUNT_PREFIX = "\\b(" ^ NUMBER ^ ")\\s+"
    ^ "(?:(extra small|extra large|small|medium|large|jumbo)\\s+)?"
    ^ "(?:(slices?|strips?|pieces?)\\s+(?:of\\s+)?)?"
  fun countSize s = case Rx.lower s of
      "small" => S.CS_small | "medium" => S.CS_medium | "large" => S.CS_large
    | "extra small" => S.CS_extra_small | "extra large" => S.CS_extra_large
    | "jumbo" => S.CS_jumbo | _ => S.CS_any
  fun countForm s = case sing (Rx.lower s) of
      "slice" => S.CF_slice | "strip" => S.CF_strip | "piece" => S.CF_piece | _ => S.CF_whole

  type issued = (string * {value : ExactNumeric.rational, literal : string}) list

  (* Only values issued by the shared scanner can occupy a numeric role.
     Number words are the explicit finite dictionary above. The one two-token
     construction is a nonnegative integer followed by a proper slash fraction. *)
  fun qtyOf (issued : issued) (q : string) : S.rat * string * string list =
    let
      val l = Rx.lower q
      fun lookup key = Option.map #2 (List.find (fn (marker, _) => marker = key) issued)
      fun checked (n, d) = if n >= 0 andalso d > 0 then S.mk_rat n d
                           else raise Fail "food quantities must be nonnegative"
    in
      case List.find (fn (word, _) => word = l) WORDNUM of
        SOME (_, (n, d)) => (checked (IntInf.fromInt n, IntInf.fromInt d), q, [])
      | NONE =>
          (case String.tokens Char.isSpace l of
             [marker] =>
               (case lookup marker of
                  SOME {value, literal} => (checked value, literal, [marker])
                | NONE => raise Fail "quantity marker was not issued")
           | [whole, fraction] =>
               (case (lookup whole, lookup fraction) of
                  (SOME {value = (w, wd), literal = wl}, SOME {value = (n, d), literal = fl}) =>
                    if wd = 1 andalso w >= 0 andalso n >= 0 andalso n < d
                       andalso String.isSubstring "/" fl
                    then (checked (w * d + n, d), wl ^ " " ^ fl, [whole, fraction])
                    else raise Fail "mixed quantity requires an integer and a proper fraction"
                | _ => raise Fail "mixed quantity markers were not issued")
           | _ => raise Fail "unsupported quantity role")
    end

  (* What the recognizer hands the kernel; rows are fetched afterwards. *)
  type recog = {nut : S.nutrient, amount : S.amount, phrase : string,
                hit : food option, near : food list}

  (* NutritionOrgan.answer up to the store lookups. NONE = the organ returns None. *)
  fun v1 (foods : unit -> food vector) (text : string) : recog option =
    (* Establish the nutrition domain before the exact quantity parser. An
       unrelated algebra token such as 3x must not become a Stores failure. *)
    if not (List.exists (fn (_, _, p) => Rx.has p text) nutPats) orelse
       not (Rx.has (Pats.get "nutrition_v1.ASK") text orelse
            Rx.has (Pats.get "nutrition_v1.in") text)
    then NONE
    else let
      val original = Rx.collapse text
      val {text = t, numbers} = case ExactNumeric.mask original of
          SOME masked => masked | NONE => raise Fail "malformed numeric token"
      val literals = List.mapPartial (fn ExactNumeric.Number {start, stop, ...} =>
            SOME (String.substring (original, start, stop - start)) | _ => NONE) (ExactNumeric.scan original)
      val issued : issued = ListPair.mapEq
        (fn ((marker, value), literal) => (marker, {value = value, literal = literal})) (numbers, literals)
      val _ = if List.all (fn m => mem (Rx.lower (Rx.whole t m)) (map #1 issued)) (Rx.findall ("\\b" ^ MARKER ^ "\\b") t)
              then () else raise Fail "unissued numeric marker in question"
      val found = List.mapPartial (fn (k, n, p) => Option.map (fn (m : Regex.match) => (#start m, k, n)) (Rx.search p t)) nutPats
      fun better ((s1, k1, _), (s2, k2, _)) = s1 < s2 orelse (s1 = s2 andalso k1 < k2)
      val nut = List.foldl (fn (x, NONE) => SOME x | (x, SOME y) => SOME (if better (x, y) then x else y)) NONE found
    in
      case nut of
        NONE => NONE
      | SOME (_, k, n) =>
          if not (Rx.has (Pats.get "nutrition_v1.ASK") t) andalso not (Rx.has (Pats.get "nutrition_v1.in") t) then NONE
          else
            let
              val m = Rx.search AMOUNT t
              val cm = if isSome m then NONE else Rx.search COUNT_PREFIX t
              (* Roles start at language boundaries, not inside unscanned
                 structural text. Signed number words such as "- two" are
                 unsupported; issued numeric signs already belong to values. *)
              val _ = case (case m of SOME x => SOME x | NONE => cm) of
                  SOME (mm as {start, ...} : Regex.match) =>
                    let val prefix = Rx.rstrip " \t\r\n" (String.substring (t, 0, start))
                        val adjacent = start > 0 andalso
                          not (Char.isSpace (String.sub (t, start - 1))) andalso
                          not (Char.contains "(:" (String.sub (t, start - 1)))
                        val priorNumeric = size prefix > 0 andalso
                          Char.contains "0123456789.,/+-" (String.sub (prefix, size prefix - 1))
                    in if adjacent orelse priorNumeric
                       then raise Fail "unsupported quantity token" else () end
                | NONE => ()
              val (quantity, quantityText, claimed) =
                case (case m of SOME x => SOME x | NONE => cm) of
                  SOME mm => qtyOf issued (Rx.g t mm 1)
                | NONE => (S.mk_rat 100 1, "", [])
              val _ = if length claimed = length issued andalso
                         List.all (fn (marker, _) => mem marker claimed) issued
                      then () else raise Fail "numeric token has no quantity role"
              val rest = Rx.sub (Pats.get ("nutrition_v1.NUTRIENTS." ^ k)) " " 1 t
              val rest = case m of SOME mm => Rx.replaceAll (Rx.whole t mm) " " rest
                         | NONE => (case cm of SOME mm => Rx.replaceAll (Rx.whole t mm) " " rest | NONE => rest)
              val _ = if List.exists (fn c => Char.isDigit c orelse Char.ord c >= 128) (String.explode rest)
                      then raise Fail "uninterpreted numeric or non-ASCII text outside quantity role" else ()
              val rest = String.map (fn c => if Char.isAlpha c andalso Char.ord c < 128 orelse c = #" " orelse c = #"," then c else #" ") rest
              val fv = foods ()
              val hit = matchFood fv rest
              val phrase = String.concatWith " "
                (List.filter (fn w => not (mem (Rx.lower w) FILLER))
                   (String.tokens (fn c => not (Char.isAlpha c)) rest))
              val amount =
                case m of
                  SOME mm =>
                    let
                      val q = quantityText and u = Rx.g t mm 2
                      val lu = Rx.lower u
                    in
                      case List.find (fn (nm, _) => nm = lu) S.mass_names of
                        SOME (_, mu) => S.A_mass (quantity, lu, mu)
                      | NONE =>
                          (case List.find (fn (nm, _) => nm = lu) S.measure_names of
                             SOME (_, me) => S.A_measure (quantity, q, u, me)
                           | NONE => raise Fail ("no unit " ^ u))
                    end
                | NONE =>
                    (case cm of
                       SOME mm =>
                         let val sz = case Rx.grp t mm 2 of SOME x => x | NONE => ""
                             val form = case Rx.grp t mm 3 of SOME x => x | NONE => ""
                             val description = String.concatWith " " (List.filter (fn x => x <> "") [sz, form, phrase])
                         in S.A_count (quantity, quantityText, description, countSize sz, countForm form) end
                     | NONE => S.A_default)
            in
              SOME {nut = n, amount = amount, phrase = Rx.strip phrase,
                    hit = Option.map #1 hit, near = case hit of SOME (_, nr) => nr | NONE => []}
            end
    end

  fun normalize2 text =
    let
      val t = Rx.sub (Pats.get "nutrition_v2.FRAME") " " 0 text
      val t = Rx.subWith (Pats.get "nutrition_v2.NEG") (fn m => Rx.g t m 1) 0 t
      val t = Rx.subWith (Pats.get "nutrition_v2.CLITIC") (fn m => Rx.g t m 1) 0 t
      val t = Rx.sub (Pats.get "nutrition_v2.MEASURE_NOUN") " of " 1 t
      val t = Rx.subWith (Pats.get "nutrition_v2.of_in") (fn m => Rx.g t m 1) 0 t
    in Rx.collapse t end

  fun normalize3 text =
    let val t = normalize2 text
    in
      if not (Rx.has (Pats.get "nutrition_v1.ASK") t) andalso size t > 0 andalso Char.isAlpha (String.sub (t, 0))
         andalso not (List.exists (fn p => String.isPrefix p (Rx.lower t)) ["how", "what", "which"])
      then "What is the " ^ String.str (Char.toLower (String.sub (t, 0))) ^ String.extract (t, 1, NONE)
      else t
    end

  (* Per manifest: (pre-narrowing passes, normalized text, decline-narrowing applies) *)
  fun recognize (mode : string) (foods : unit -> food vector) (text : string) : (recog * bool) option =
    case mode of
      "cooking" => Option.map (fn r => (r, false)) (v1 foods (normalize3 text))
    | "cooking-v2" => if Narrow.narrative text then NONE else Option.map (fn r => (r, true)) (v1 foods (normalize3 text))
    | "cooking-v3" => if Narrow.narrative text then NONE else Option.map (fn r => (r, true)) (v1 foods (normalize3 text))
    | "cooking-v3-r2" =>
        if Rx.has (Pats.get "cooking_v3_r2.NOT_MINE") text andalso not (Rx.has (Pats.get "cooking_v3_r2.MINE") text) then NONE
        else if Narrow.narrative text then NONE
        else Option.map (fn r => (r, true)) (v1 foods (normalize3 text))
    | _ => NONE
end

(* ------------------------------------------------------------------ site *)
structure Site =
struct
  structure S = Stores

  type tables = {items : (string * (string * string)) list, zones : (string * (IntInf.int * string)) list}

  fun norm s =
    let
      val s = String.map (fn c => let val c = Char.toLower c
                                  in if (c >= #"a" andalso c <= #"z") orelse Char.isDigit c orelse c = #" " orelse c = #"-"
                                     then c else #" " end) s
      fun w x = if size x > 3 andalso String.isSuffix "s" x andalso not (String.isSuffix "ss" x)
                then String.substring (x, 0, size x - 1) else x
    in String.concatWith " " (map w (String.tokens (fn c => c = #" ") s)) end

  (* the organ's dict {_norm(name): (sku, name)}: first position, last value *)
  fun mkTables (items : (string * string) list, zones : (IntInf.int * string) list) : tables =
    let
      fun add ((k, v), acc) =
        if List.exists (fn (k', _) => k' = k) acc then map (fn (k', v') => if k' = k then (k', v) else (k', v')) acc
        else acc @ [(k, v)]
      val its = List.foldl add [] (map (fn (sku, n) => (norm n, (sku, n))) items)
      val zs = List.foldl add [] (map (fn (zid, n) => (Rx.lower n, (zid, n))) zones)
    in {items = its, zones = zs} end

  fun item (tb : tables) t =
    let
      val n = " " ^ norm t ^ " "
      fun contains k = let val k = " " ^ k ^ " " in
                         let fun go i = i + size k <= size n andalso (String.substring (n, i, size k) = k orelse go (i + 1))
                         in go 0 end end
      val best = List.foldl (fn ((k, v), best) =>
                   if contains k andalso (case best of NONE => true | SOME (bk, _) => size k > size bk)
                   then SOME (k, v) else best) NONE (#items tb)
    in Option.map #2 best end

  fun zone (tb : tables) t =
    let
      val tl = Rx.lower t
      fun ins (x, []) = [x]
        | ins (x as (k, _), (y as (k', _)) :: ys) = if size k > size k' then x :: y :: ys else y :: ins (x, ys)
      val byLen = List.foldl ins [] (#zones tb)
    in
      case List.find (fn (k, _) => Rx.hasWordPhrase k tl) byLen of
        SOME (_, v) => SOME v
      | NONE =>
          (case Rx.search (Pats.get "site_v2.aisle") tl of
             SOME m => (case List.find (fn (k, _) => k = "aisle " ^ Rx.g tl m 1) (#zones tb) of
                          SOME (_, v) => SOME v | NONE => NONE)
           | NONE => NONE)
    end

  val kinds = map (fn k => (S.skind_key k, k)) S.skind_order
  fun kind t = case List.find (fn (key, _) => Rx.has (Pats.get ("site_v2.KIND_WORDS." ^ key)) t) kinds of
                 SOME (key, k) => SOME (key, k) | NONE => NONE
  fun skindOfKey key = Option.map #2 (List.find (fn (k', _) => k' = key) kinds)

  fun P k = Pats.get ("site_v2." ^ k)
  fun has k t = Rx.has (P k) t

  fun zoneT (z : IntInf.int * string) = (S.mk_int (#1 z), #2 z)

  (* Only an actual omitted-object question inherits the previous item. A short
     explicit unknown name ("purple widgets count?") is not an ellipsis. *)
  fun itemEllipsis t = Rx.has
    "^(?:and )?(?:how many(?: are left| left| do we have)?|count|stock|quantity|where|where (?:is|are|do we keep)|which bin|when will we run out|how long(?: until (?:empty|we run out))?|days left)[?.! ]*$" t

  fun resolveFollow tb t (st : S.sstate) =
    let
      val rest = Rx.rstrip "?.! " (Rx.sub (Pats.get "site_v2.follow_strip") "" 0 t)
    in
      case (zone tb rest, S.s_zone st) of
        (SOME _, SOME _) =>
          (case S.s_kind st of SOME k => rest ^ " " ^ S.skind_key k | NONE => "how is " ^ rest)
      | _ =>
          (case (S.s_zone st, kind rest) of
             (SOME (_, zn), SOME _) => zn ^ " " ^ rest
           | _ =>
               (case (S.s_item st, item tb rest) of
                  (SOME _, SOME _) => "how many " ^ rest
                | _ => t))
    end

  (* An order owns its complete quantity and item phrase. Numeric item codes
     are interpreted only by exact item-name matching, never as quantities.
     Unsupported order syntax must not become a stock read or a confirmation. *)
  fun orderRead (tb : tables) (st : S.sstate) t : S.rintent option =
    let
      val cue = Rx.has "\\b(?:re-?order|order|restock)\\b" t
      val command = Rx.search
        "^(?:(?:can|could|would|will) you (?:please )?|please )?(?:re-?order|order|restock)\\b\\s*" t
      fun invalid () = SOME S.R_invalid_order
      fun parse ({stop, ...} : Regex.match) =
        let
          val tail = Rx.strip (String.extract (t, stop, NONE))
          val number = ExactNumeric.at tail 0
          val (n, d, finish) = case number of
              SOME (ExactNumeric.Number {value = (n, d), stop, ...}) => (n, d, stop)
            | NONE =>
                (case List.find (fn (word, _) => String.isPrefix (word ^ " ") (Rx.lower tail)) Cook.WORDNUM of
                   SOME (word, (n, d)) => (IntInf.fromInt n, IntInf.fromInt d, size word)
                 | NONE => raise Fail "order quantity must be an exact numeral or supported number word")
            | _ => raise Fail "malformed order quantity"
          val _ = if n > 0 andalso d = 1 andalso finish < size tail
                        andalso Char.isSpace (String.sub (tail, finish))
                  then () else raise Fail "order quantity must be a positive whole number"
          val phrase = Rx.rstrip ".!? " (Rx.strip (String.extract (tail, finish, NONE)))
          val phrase = Rx.sub "^(?:more\\s+(?:of\\s+)?|of\\s+)?(?:the\\s+)?" "" 1 phrase
          val normalized = norm phrase
          (* norm is only used after rejecting punctuation and extra clauses;
             otherwise its dropped characters could turn an unknown phrase into
             a known item's name. Hyphens and item-code digits remain intact. *)
          val _ = if phrase <> "" andalso List.all
                    (fn c => Char.isAlphaNum c andalso Char.ord c < 128
                             orelse Char.isSpace c orelse c = #"-") (String.explode phrase)
                  then () else raise Fail "unsupported order item phrase"
          val matches = List.filter (fn (key, _) => key = normalized) (#items tb)
          val target = case matches of [(_, it)] => SOME it | _ => NONE
          val target = case target of SOME it => SOME it | NONE =>
            if List.exists (fn p => Rx.lower phrase = p) ["it", "them", "that", "those", "this one"]
            then S.s_item st else NONE
        in case target of SOME it => SOME (S.R_reorder (S.mk_nat n, SOME it, phrase))
                        | NONE => invalid () end
    in
      if not cue then NONE
      else case command of SOME m => (parse m handle Fail _ => invalid ())
        | NONE => if has "LOW" t then NONE else invalid ()
    end

  (* SiteOrgan.answer after the confirmation check: the reading of the turn *)
  fun read (tb : tables) (st : S.sstate) (t : string) : S.rintent =
    if has "SELF" t then S.R_self
    else if isSome (S.s_item st) andalso has "NEIGHBOUR" t then S.R_neighbour
    else
      let
        val t = if has "FOLLOW" t then resolveFollow tb t st else t
        val t = case S.s_item st of
                  SOME (_, nm) =>
                    if not (isSome (item tb t)) andalso Rx.has (Pats.get "site_v2.pronoun") t
                    then Rx.sub (Pats.get "site_v2.pronoun") nm 1 t else t
                | NONE => t
        val t = case S.s_item st of
                  SOME (_, nm) =>
                    if not (isSome (item tb t)) andalso not (isSome (zone tb t)) andalso not (isSome (kind t))
                       andalso itemEllipsis t
                    then Rx.rstrip "?.! " t ^ " " ^ nm else t
                | NONE => t
        val t =
          case (S.s_kind st, S.s_item st, zone tb t) of
            (SOME k, NONE, SOME (_, zn)) =>
              if not (isSome (kind (Rx.replaceAllCI zn " " t))) andalso Rx.words t <= 5
              then Rx.rstrip "?.! " t ^ " " ^ S.skind_key k
              else if S.s_last st = S.SL_zone_status andalso Rx.words t <= 5 andalso not (isSome (item tb t))
              then "how is " ^ Rx.rstrip "?.! " t else t
          | (_, _, SOME _) =>
              if S.s_last st = S.SL_zone_status andalso Rx.words t <= 5 andalso not (isSome (item tb t))
              then "how is " ^ Rx.rstrip "?.! " t else t
          | _ => t
      in
        if has "LOW" t then S.R_low
          else
            let
              val it = item tb t
              val z = zone tb t
              val k = kind (case z of SOME (_, zn) => Rx.replaceAllCI zn " " t | NONE => t)
            in
              case (it, z) of
                (SOME i, NONE) =>
                  if has "WHERE" t andalso not (has "STOCK" t) then S.R_where i
                  else if has "RUNOUT" t andalso not (Rx.has (Pats.get "site_v2.howmany_not_days") t) then S.R_runout i
                  else S.R_stock i
              | _ =>
                  if isSome z andalso (isSome k orelse has "STATUS" t) then
                    (case (z, k) of
                       (SOME zz, NONE) => S.R_zone_status (zoneT zz)
                     | (SOME zz, SOME (_, kk)) => S.R_sensor (zoneT zz, kk, has "RANGE" t)
                     | _ => S.R_none)
                  else if has "STOCK" t orelse has "WHERE" t orelse has "RUNOUT" t then
                    let
                      val w = Rx.rstrip "?.! " (Rx.sub (Pats.get "site_v2.what_strip") "" 0 t)
                      val w = Rx.sub (Pats.get "site_v2.what_tail") "" 0 w
                    in S.R_unknown_item w end
                  else if isSome z then S.R_none
                  else (case k of SOME (_, kk) => S.R_kind_only kk | NONE => S.R_off_site)
            end
      end

  fun recognize (tb : tables) (st : S.sstate) (text : string) : S.intent =
    let val t = Rx.collapse text
    in
      if t = "" then S.I_read S.R_none
      else if Rx.has
        "^(?:yes|yep|yeah|confirm|do it|go ahead|ok(?:ay)?|sure|no|nope|cancel|don'?t|stop)(?:\\s+(?:the\\s+)?(?:order|request|proposal))?(?:,?\\s+(?:please|thanks|thank you))?[.!? ]*$" t
      then S.I_confirm (not (has "NO" t), read tb st t)
      else case orderRead tb st t of
        SOME r => S.I_read r
      | NONE => if has "YES" t orelse has "NO" t then S.I_read S.R_invalid_order
                else S.I_read (read tb st t)
    end
end
