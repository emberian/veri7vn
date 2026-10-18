(* UNTRUSTED. The English recognizer for lane S10 (anatomy, anatomy-r2, agriculture-v2,
   gardening, nutrition-label-v2): a hand port of the regular expressions and branch order of
     upstream/root/specialists/anatomy/organ_anatomy_v1.py        (AnatomyOrgan)
     upstream/root/specialists/anatomy-r2/organ_anatomy_r2.py     (AnatomyOrganBoundary)
     upstream/root/specialists/agriculture-v2/organ_agriculture_v{1,2}.py
     upstream/root/specialists/gardening/organ_gardening_v1.py
     upstream/root/specialists/nutrition-label-v2/organ_nutrition_label_v{1,2}.py
   and of their shared narrowing rule narrow_v1.py. It reads numbers and words off the question
   and builds a typed AnatomyAgri.request; it computes nothing. Every value, decline and response
   text comes from the verified HOL kernel (AnatomyAgri.reply_of). NONE means the question is not
   taken (the organ returns None).

   The patterns of the anatomy count/superlative/produces tables and the daily-value table are
   paired by position with the HOL lists (count_order, super_order, made_order, dv_order), whose
   contents tables_check.py compares with the organ files; the pattern strings here were
   generated from the organs' own lists and tables_check.py compares them too.

   Patterns are passed to Regex.compile as written (the text is lower-cased here).
   Where the organ computes before it asks the kernel (the sign of an input, a product of two
   numbers read off the text), the recognizer only compares numeral literals with zero. *)
structure Recognizer :
sig
  val organs : string list
  val recognize : string -> string -> (string * AnatomyAgri.request) option
end =
struct
  structure Q = AnatomyAgri

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
  fun firstGroup s m gs = case List.mapPartial (grp s m) gs of x :: _ => SOME x | [] => NONE

  (* replace every match of p in s by f applied to the match *)
  fun replaceWith p f s =
    let
      fun go i [] acc = String.concat (rev (String.extract (s, i, NONE) :: acc))
        | go i ((m as {start, stop, ...} : Regex.match) :: ms) acc =
            go stop ms (f m :: String.substring (s, i, start - i) :: acc)
    in go 0 (findall p s) [] end

  (* Python str.replace: every occurrence of a literal substring *)
  fun replaceStr needle rep s =
    let
      val n = size needle
      fun go i acc =
        if i > size s - n then String.concat (rev (String.extract (s, i, NONE) :: acc))
        else if String.substring (s, i, n) = needle then go (i + n) (rep :: acc)
        else go (i + 1) (String.substring (s, i, 1) :: acc)
    in if n = 0 then s else go 0 [] end

  fun decimalParts (lit0 : string) =
    let
      val lit = String.translate (fn #"," => "" | c => String.str c) lit0
      val (ip, fp) = case String.fields (fn c => c = #".") lit of
                       [a] => (a, "")
                     | [a, b] => (a, b)
                     | _ => raise Fail ("bad numeral " ^ lit0)
    in (valOf (IntInf.fromString (ip ^ fp)), IntInf.pow (10, size fp)) end
  fun ratOf lit = let val (n, d) = decimalParts lit in Q.mk_rat n d end
  fun sameNumber a b = let val (an, ad) = decimalParts a val (bn, bd) = decimalParts b
    in an * bd = bn * ad end

  (* a numeral literal that reads as zero ("0", "0.0", "0,0") *)
  fun isZero lit = List.all (fn c => c = #"0" orelse c = #"." orelse c = #",") (String.explode lit)

  fun nat s = Q.nat_of_integer (valOf (IntInf.fromString s))

  fun collapse s = String.concatWith " " (String.tokens Char.isSpace s)

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
    val RELATION = "\\b(?:\\d+(?:\\.\\d+)?|one|two|three|four|five|six|seven|eight|nine|ten)\\s+(?:\\w+\\s+){0,2}"
      ^ "(?:more|less|fewer|longer|shorter)\\s+than\\b|\\b(?:twice|three times|half)\\s+(?:as\\s+\\w+\\s+as\\s+)?the\\s+\\w+\\b"
    val RATE = "\\b\\d+(?:\\.\\d+)?\\s+[a-z]+\\s+(?:for|per|every)\\s+(?:\\d+(?:\\.\\d+)?|a|an|one|each)\\s+[a-z]+"
    fun narrative t =
      let val low = lower t
      in sentences t >= 3 orelse words t > 40 orelse has RELATION low orelse has RATE low end
    fun short_direct t = sentences t <= 2 andalso words t <= 25 andalso not (narrative t)
  end


  val NUM = "(\\d+(?:,\\d{3})*(?:\\.\\d+)?)"
  val FT = "\\s*(?:ft|feet|foot|')"
  val times = "\195\151"
  val sq2 = "\194\178"
  val mu = "\194\181"

  (* first element of a table whose pattern matches, in table order *)
  fun firstMatch pats low =
    Option.map #2 (List.find (fn (p, _) => has p low) pats)

  (* ================= anatomy ================= *)
  val countPats = [
    "\\bbones?\\b.*\\b(?:adult|human (?:body|skeleton)|in the body|skeleton)\\b|\\b(?:adult|human) (?:skeleton|body)\\b.*\\bbones\\b",
    "\\bbones?\\b.*\\bskull\\b|\\bskull\\b.*\\bbones?\\b",
    "\\bpairs? of ribs\\b",
    "\\bribs\\b",
    "\\bcervical vertebrae\\b",
    "\\bthoracic vertebrae\\b",
    "\\blumbar vertebrae\\b",
    "\\bbones?\\b.*\\bhand\\b|\\bhand\\b.*\\bbones?\\b",
    "\\bbones?\\b.*\\bfoot\\b|\\bfoot\\b.*\\bbones?\\b",
    "\\bcarpal\\w*\\b",
    "\\btarsal\\w*\\b",
    "\\b(?:baby|primary|deciduous|milk) teeth\\b",
    "\\b(?:adult|permanent) teeth\\b|\\bteeth\\b.*\\badult\\b",
    "\\bchambers?\\b.*\\bheart\\b|\\bheart\\b.*\\bchambers?\\b",
    "\\bvalves?\\b.*\\bheart\\b|\\bheart\\b.*\\bvalves?\\b",
    "\\blobes?\\b.*\\blungs?\\b|\\blungs?\\b.*\\blobes?\\b",
    "\\bcranial nerves\\b",
    "\\bspinal nerves\\b",
    "\\bchromosomes\\b"]
  val superPats = [
    "\\b(?:largest|longest|biggest|strongest) bone\\b",
    "\\bsmallest bone\\b",
    "\\b(?:largest|biggest) organ\\b",
    "\\blongest muscle\\b",
    "\\b(?:largest|biggest) internal organ\\b",
    "\\b(?:largest|biggest) artery\\b"]
  val makesPats = [
    "\\binsulin\\b",
    "\\bbile\\b",
    "\\burine\\b",
    "\\bred blood cells\\b",
    "\\bmelatonin\\b",
    "\\bthyroxine\\b|\\bthyroid hormone\\b",
    "\\badrenaline\\b|\\bepinephrine\\b",
    "\\bsurfactant\\b",
    "\\bpepsin\\b"]
  val dvPats = [
    "\\bsodium\\b",
    "\\bsaturated fat\\b",
    "\\btotal fat\\b|\\bfat\\b",
    "\\bcholesterol\\b",
    "\\bdietary fiber\\b|\\bfiber\\b|\\bfibre\\b",
    "\\badded sugars?\\b",
    "\\btotal carbohydrates?\\b|\\bcarbohydrates?\\b|\\bcarbs\\b",
    "\\bprotein\\b",
    "\\bcalcium\\b",
    "\\biron\\b",
    "\\bpotassium\\b",
    "\\bvitamin d\\b"]

  val countTab = zip3 (countPats, Q.count_order, "count_order")
  val superTab = zip3 (superPats, Q.super_order, "super_order")
  val makesTab = zip3 (makesPats, Q.made_order, "made_order")
  val dvTab = zip3 (dvPats, Q.dv_order, "dv_order")

  val symptoms = "\\bsymptom\\w*\\b|\\bpain\\b|\\bhurt\\w*\\b|\\bshould i\\b|\\bdiagnos\\w*\\b|\\bdisease\\b|\\bdoctor\\b|\\bmy\\b|\\btreat\\w*\\b|\\bbroken\\b|\\bnormal for\\b"

  val notMine = "\\b(?:dogs?|puppy|puppies|cats?|kittens?|horses?|cows?|pigs?|sheep|goats?|rabbits?|hamsters?|birds?|parrots?|fish|animals?|pets?|canine|feline|equine|veterinar\\w*)\\b"
  val mine = "\\b(?:humans?|people|person|man|woman|men|women|child|children|baby|babies|adults? human)\\b"

  (* Explicit developmental context narrows the fixed table. We do not invent
     a single infant skeleton count; fusion and eruption are outside this table. *)
  fun scopedCount low c =
    let val stageText = replaceWith "\\bbaby teeth\\b" (fn _ => "primary teeth") low
    in
      if has "\\b(?:newborns?|neonatal|neonates?|infants?|infancy|babies|baby|fetal|foetal|fetus|foetus|embryos?)\\b" stageText
      then Q.CountAt (c, Q.NewbornStage)
      else if has "\\b(?:child|children|childhood|adolescents?|juveniles?|toddlers?)\\b" stageText
      then Q.CountAt (c, Q.DevelopingStage)
      else if has "\\badults?\\b" stageText then Q.CountAt (c, Q.AdultStage)
      else Q.Count c
    end

  fun anatomy text =
    if Narrow.narrative text then NONE
    else
      let val low0 = lower (collapse text)
          val inverted = search "\\b(bone|organ|internal organ|muscle|artery)\\s+(?:is|in (?:the )?(?:human )?(?:body|skeleton) is)\\s+(?:the )?(longest|smallest|largest|biggest)\\b" low0
          val low = case inverted of NONE => low0 | SOME m =>
            low0 ^ " " ^ valOf (grp low0 m 2) ^ " " ^ g1 low0 m
      in
        if has symptoms low orelse (has notMine low andalso not (has mine low)) then NONE
        else if has "\\bhow many\\b|\\bnumber of\\b" low then
          Option.map (scopedCount low)
            (case firstMatch (tl countTab) low of
               SOME specific => SOME specific
             | NONE => firstMatch countTab low)
        else if has "\\bwhat\\b|\\bwhich\\b|\\bname\\b" low then
          (case (if has "\\bbody\\b|\\bhuman\\b|\\bskeleton\\b|\\bmuscle\\b|\\bbone\\b|\\borgan\\b|\\bartery\\b" low
                 then firstMatch superTab low else NONE) of
             SOME s => SOME (Q.Superlative s)
           | NONE =>
               if has "\\b(?:produce|produces|make|makes|secrete|secretes)\\b" low
                  andalso has "\\bwhich\\b|\\bwhat\\b" low
                  andalso has "\\borgan\\b|\\bgland\\b|\\bbody\\b|\\bpart\\b" low
               then Option.map Q.Produces (firstMatch makesTab low)
               else NONE)
        else NONE
      end

  (* anatomy-r2: silent on a turn with another domain's markers and none of its own *)
  fun anatomyR2 text =
    let val low = lower text
    in if has notMine low andalso not (has mine low) then NONE else anatomy text end

  (* ================= agriculture-v2 ================= *)
  val cropTab = zip3 (["corn", "maize", "soybeans", "soybean", "wheat", "sorghum", "barley", "oats"],
                      Q.crop_order, "crop_order")
  val gradeRe = "(?<![\\w.+\226\136\146-])(\\d{1,3})-(\\d{1,3})-(\\d{1,3})(?![\\d.-])"

  fun nutrientOf low =
    let
      val m = case search "\\b(nitrogen|phosphate|phosphorus|p2o5|potash|potassium|k2o)\\b" low of
                SOME m => SOME m
              | NONE => search "\\blb(?:s)?\\.?\\s+(?:of\\s+)?(n|p|k)\\b|\\b(n|p|k)\\s+(?:per|/)\\s*acre\\b" low
    in
      case m of
        NONE => NONE
      | SOME m =>
          (case firstGroup low m [1, 2] of
             SOME w =>
               SOME (if List.exists (fn x => x = w) ["nitrogen", "n"] then Q.Nit
                     else if List.exists (fn x => x = w) ["phosphate", "phosphorus", "p2o5", "p"] then Q.Pho
                     else Q.Pot)
           | NONE => NONE)
    end

  fun agriV1 low =
    if not(has "\\bfertili[sz]er\\b|\\burea\\b|\\bgrade\\b|\\bproduct\\b|\\blb\\b|\\bpounds\\b|\\bbag\\b|\\bapply\\b" low) then agriRest low
    else case findall gradeRe low of
      [] => if has "[0-9.]+-[0-9.]+-[0-9.]+" low then SOME Q.FertUnread else agriRest low
    | [gm] =>
      let
        val (ga,gb,gc)=(nat(g1 low gm),nat(valOf(grp low gm 2)),nat(valOf(grp low gm 3)))
        val masked = replaceStr (Regex.whole low gm) "fertilizer_grade" low
        val tokens = ExactNumeric.scan masked
        val bad = List.exists (fn ExactNumeric.Malformed _ => true | _ => false) tokens
        val nutrientPattern = "(?:nitrogen|n|phosphate|p2o5|potash|k2o)"
        val nutrients = List.mapPartial (fn(pat,n) => if has pat masked then SOME n else NONE)
          [("\\bnitrogen\\b|\\b(?:lb(?:s)?\\.?|pounds)\\s+(?:of\\s+)?n\\b|\\bn\\s*(?:per|/)\\s*acre\\b",Q.Nit),
           ("\\bphosphate\\b|\\bp2o5\\b",Q.Pho),
           ("\\bpotash\\b|\\bk2o\\b",Q.Pot)]
        val unsupported = has "\\belemental\\b|\\bphosphorus\\b|\\bpotassium\\b|\\bhectares?\\b|\\bkilograms?\\b|\\bkg\\b" masked
        fun pick role = List.mapPartial
          (fn ExactNumeric.Number {start,stop,value,...} =>
             let val pre=String.substring(masked,0,start)
                 val post=String.extract(masked,stop,NONE)
             in case role(pre,post) of SOME perAcre => SOME(start,value,perAcre) | NONE=>NONE end
           | _ => NONE) tokens
        val unit = "^\\s*(?:lb|lbs|pounds)\\s*(?:of\\s+)?(?:actual\\s+)?"
        val rate = pick(fn(_,post) =>
          if has (unit ^ nutrientPattern ^ "\\b") post
          then SOME(has(unit ^ nutrientPattern ^ "\\s*(?:per|/|an?)\\s*acre\\b") post)
          else NONE)
        val qty = pick(fn(pre,post) =>
          if has "^\\s*(?:lb|lbs|pounds)\\s*(?:(?:bag|sack)\\s+)?(?:of\\s+)?(?:the\\s+|a\\s+)?(?:fertilizer_grade|fertili[sz]er|urea|product)\\b" post orelse
             (has "\\b(?:bag|sack)\\s+(?:of\\s+)?(?:fertilizer_grade\\s+)?(?:weighs|weighing|is)\\s*$" pre andalso has "^\\s*(?:lb|lbs|pounds)\\b" post)
          then SOME(has "^\\s*(?:lb|lbs|pounds)\\s*(?:(?:bag|sack)\\s+)?(?:of\\s+)?(?:the\\s+|a\\s+)?(?:fertilizer_grade|fertili[sz]er|urea|product)(?:\\s+fertili[sz]er)?\\s*(?:per|/)\\s*acre\\b" post)
          else NONE)
        val areas = pick(fn(_,post) => if has "^\\s*acres?\\b" post then SOME false else NONE)
        val queryStart = case rev(findall "\\b(?:how (?:much|many pounds)|what (?:rate|amount))\\b" masked) of
          m::_ => #start m | [] => 0
        fun context (position,_,inputRate) =
          let
            val query = if queryStart < position then String.substring(masked,queryStart,position-queryStart)
                        else String.extract(masked,queryStart,NONE)
            val target = case search "\\b(?:for|at|supply|supplies|supplied|provide|provides|provided|deliver|delivers)\\b" query of
              SOME m => String.substring(query,0,#start m) | NONE => query
            val wantsRate = has "\\bper\\s+acre\\b|/\\s*acre\\b|\\bwhat rate\\b" target
            val wantsTotal = not wantsRate andalso has "\\btotal\\b|\\ball\\b" target
            fun rat(n,d)=Q.mk_rat n d
          in case areas of
            [] => if wantsTotal andalso inputRate then NONE
                  else if wantsRate andalso not inputRate then NONE
                  else SOME(if inputRate then Q.PerAcreFertilizer else Q.TotalFertilizer)
          | [(_,area,_)] =>
              if inputRate andalso not wantsRate then SOME(Q.TotalFromRate(rat area))
              else if not inputRate andalso wantsRate then SOME(Q.RateFromTotal(rat area))
              else SOME(if inputRate then Q.PerAcreFertilizer else Q.TotalFertilizer)
          | _ => NONE
          end
        fun bind constructor n item =
          case context item of NONE => SOME Q.FertUnread
          | SOME scope => let val(_, (numerator,denominator),_)=item
                         in SOME(constructor(scope,n,ga,gb,gc,Q.mk_rat numerator denominator)) end
      in
        if bad orelse unsupported then SOME Q.FertUnread
        else case (nutrients,rate,qty) of
          ([n],[r],[]) => bind Q.FertilizerNeed n r
        | ([n],[],[q]) => bind Q.FertilizerHas n q
        | _ => SOME Q.FertUnread
      end
    | _ => SOME Q.FertUnread
  and agriRest low =
    let
      val rs = search ("\\b" ^ NUM ^ "[- ]?(?:inch|in\\.?|\\\")\\s*rows?\\b|\\brows?\\s*(?:spaced\\s*)?(?:at\\s*)?" ^ NUM ^ "\\s*(?:inches|in\\.?|\\\")\\s*(?:apart)?") low
      val ss = search ("\\b(?:seeds?|plants?)\\s*(?:spaced\\s*)?(?:every\\s*|at\\s*|)" ^ NUM ^ "\\s*(?:inches|in\\.?|\\\")|" ^ NUM ^ "\\s*(?:inches|in\\.?|\\\")\\s*(?:apart\\s*)?(?:in the row|within the row|in-row|between (?:seeds|plants))") low
    in
      case (rs, ss) of
        (SOME rm, SOME sm) =>
          if has "\\bper acre\\b|\\bpopulation\\b|\\bseeds? (?:per|an|/) ?acre\\b|\\bplants? (?:per|an|/) ?acre\\b|\\bhow many (?:seeds|plants)\\b" low then
            let val rl = valOf (firstGroup low rm [1, 2])
                val sl = valOf (firstGroup low sm [1, 2])
            in if isZero rl orelse isZero sl then NONE
               else SOME (Q.SeedsPerAcre (ratOf rl, ratOf sl)) end
          else agriGerm low
      | _ => agriGerm low
    end
  and agriGerm low =
    if not (has "\\bgermination\\b" low) then agriYield low
    else
      let
        val tokens = ExactNumeric.scan low
        val malformed = List.exists (fn ExactNumeric.Malformed _ => true | _ => false) tokens
        fun pick pred = List.mapPartial
          (fn ExactNumeric.Number {start,stop,value,...} =>
                let val prefix = String.substring (low,0,start)
                    val suffix = String.extract (low,stop,NONE)
                in if pred (prefix,suffix) then SOME value else NONE end
            | _ => NONE) tokens
        val germs = pick (fn (prefix,suffix) =>
          has "^\\s*%\\s*germination\\b" suffix orelse
          (has "\\bgermination\\s*(?:rate\\s*)?(?:of|is|=)?\\s*$" prefix
           andalso has "^\\s*%" suffix))
        val targets = pick (fn (prefix,suffix) =>
          has "\\b(?:(?:expected|target|final|desired)\\s+)?(?:stand|population)\\s*(?:of|is|=)?\\s*$" prefix orelse
          has "^\\s*plants\\s*(?:per|an|/)\\s*acre\\b" suffix)
        val perAcre = has "\\b(?:per|an|/)\\s*acre\\b|/\\s*acre\\b" low
        val unsupportedArea = has "\\b(?:per|an|/)\\s*(?:hectare|ha|square|sq)\\b|/\\s*(?:ha|m2|ft2)\\b" low
        val mixedScope = perAcre andalso has "\\btotal\\b|\\bfor\\s+[0-9.]+\\s+acres\\b" low
        val whole = has "\\bwhole\\b|\\bminimum\\b|\\bat least\\b|\\bbuy\\b|\\bpurchase\\b" low
        val theoretical = has "\\bexpected seed requirement\\b|\\btheoretical\\b|\\bseeding rate\\b" low
        val asks = has "\\bhow many (?:whole )?seeds\\b|\\bseeding rate\\b|\\bseeds? (?:to plant|needed)\\b|\\bplant how many\\b|\\bminimum number of seeds\\b|\\bexpected seed requirement\\b" low
        val scope = if perAcre then Q.PerAcreSeeds else Q.TotalSeeds
      in
        if not asks then agriYield low
        else if malformed orelse unsupportedArea orelse mixedScope then SOME Q.SeedsUnread
        else case (germs,targets) of
          ([(gn,gd)],[(tn,td)]) =>
            let val gp = Q.mk_rat gn gd
                val target = Q.mk_rat tn td
            in if whole orelse (not perAcre andalso not theoretical)
               then SOME (Q.SeedsMinimum (scope,gp,target))
               else SOME (Q.SeedsExpected (scope,gp,target)) end
        | _ => SOME Q.SeedsUnread
      end
  and agriYield low =
    let
      val bu = search (NUM ^ "\\s*(?:bu|bushels?)\\s*(?:/|per|an?)\\s*(?:ac|acre)\\b") low
      val crop = Option.map #2 (List.find (fn (c, _) => has ("\\b" ^ c ^ "\\b") low) cropTab)
    in
      case (bu, crop) of
        (SOME bm, SOME c) =>
          if has "\\bkg\\s*/\\s*ha\\b|\\bkg per hectare\\b|\\bkilograms per hectare\\b|\\btonnes? per hectare\\b|\\bt\\s*/\\s*ha\\b" low
          then SOME (Q.Yield (ratOf (g1 low bm), c,
                              if has "\\btonnes? per hectare\\b|\\bt\\s*/\\s*ha\\b" low then Q.THa else Q.KgHa))
          else agriWater low
      | _ => agriWater low
    end
  and agriWater low =
    let
      val ai = case search (NUM ^ "\\s*(?:inch(?:es)?|in\\.?)\\s*(?:of water\\s*)?(?:on|over|across|to)\\s*" ^ NUM ^ "\\s*acres?\\b") low of
                 SOME m => SOME (ratOf (g1 low m), SOME (ratOf (valOf (grp low m 2))))
               | NONE => (case search (NUM ^ "\\s*acre[- ]inch(?:es)?\\b") low of
                            SOME m => SOME (ratOf (g1 low m), NONE)
                          | NONE => NONE)
    in
      case ai of
        SOME (i, a) => if has "\\bgallons\\b" low then SOME (Q.AcreInch (i, a)) else NONE
      | NONE => NONE
    end

  fun agriculture text =
    let
      val t = lower (collapse text)
      val t = replaceWith "\\b(\\d+(?:\\.\\d+)?)[- ](?:pound|lb)s?\\b" (fn m => g1 t m ^ " lb") t
      val t2 = t
      val t = replaceWith "\\blb\\s*/\\s*acre of (n|nitrogen|p2o5|phosphate|k2o|potash)\\b"
                (fn m => "lb of " ^ g1 t2 m ^ " per acre") t
      val r =
        if Narrow.narrative t then NONE
        else
          case agriV1 t of
            SOME req => if Q.answers req orelse Narrow.short_direct t then SOME req else NONE
          | NONE => NONE
    in
      case r of
        SOME _ => r
      | NONE =>
          if has gradeRe t andalso
             has "\\bhow much (?:nitrogen|phosphate|potash|n|p2o5|k2o)\\b|\\bhow many pounds\\b|\\bhow much (?:product|fertili[sz]er)\\b" t
          then SOME Q.AgriUnderspecified else NONE
    end

  (* ================= gardening ================= *)
  fun shapeOf dims areaLit =
    case dims of
      SOME (l, w) => SOME (Q.Dims (ratOf l, ratOf w))
    | NONE => Option.map (fn a => Q.Area (ratOf a)) areaLit

  fun gardening text =
    if Narrow.narrative text then NONE
    else
      let
        val low = lower (collapse text)
      in
        if has "(?:^|[ (,:])-[0-9]" low then NONE
        else if not (has "\\bgarden\\w*\\b|\\braised bed\\b|\\bbed\\b|\\bmulch\\b|\\bcompost\\b|\\bsoil\\b|\\bplants?\\b|\\blawn\\b|\\bplanting\\b|\\bfertili[sz]er\\b|\\bwater\\w*\\b" low)
        then NONE
        else
          let
            val dims = case search (NUM ^ FT ^ "?\\s*(?:x|" ^ times ^ "|by)\\s*" ^ NUM ^ FT) low of
                         SOME m => SOME (g1 low m, valOf (grp low m 2))
                       | NONE => NONE
            val rate = search (NUM ^ "\\s*(?:lb|lbs|pounds)\\s*(?:of\\s+\\w+\\s+)?(?:per|/|each|every)\\s*1,?000\\s*(?:sq\\.? ?ft|square feet)") low
            val lowArea = case rate of SOME rm => replaceStr (Regex.whole low rm) " " low | NONE => low
            val areaM = Option.map (fn m => g1 lowArea m) (search (NUM ^ "\\s*(?:sq\\.? ?ft|square feet|ft2|ft" ^ sq2 ^ ")") lowArea)
            (* Python: area_m and num(area_m) or dims product; falsy when zero *)
            val areaShape =
              case areaM of
                SOME a => if not (isZero a) then SOME (Q.Area (ratOf a))
                          else (case dims of SOME (l, w) => if isZero l orelse isZero w then NONE else SOME (Q.Dims (ratOf l, ratOf w)) | NONE => NONE)
              | NONE => (case dims of SOME (l, w) => if isZero l orelse isZero w then NONE else SOME (Q.Dims (ratOf l, ratOf w)) | NONE => NONE)
            val areaLit = case areaM of SOME a => if not (isZero a) then SOME a else NONE | NONE => NONE
          in
            (* water *)
            if has "\\bgallons\\b" low andalso has "\\binch(?:es)? of water\\b|\\binches? of rain\\b|\\bwater\\b" low andalso isSome areaShape then
              (case search (NUM ^ "\\s*(?:inch(?:es)?|in\\.?)\\s*(?:of water|of rain)?") low of
                 NONE => NONE
               | SOME wi => SOME (Q.GardenWater (valOf areaShape, ratOf (g1 low wi))))
            else if isSome rate andalso isSome areaShape andalso has "\\bfertili[sz]er\\b|\\bnitrogen\\b|\\blime\\b|\\bcompost\\b|\\bhow much\\b" low then
              SOME (Q.GardenFert (ratOf (g1 low (valOf rate)), valOf areaShape))
            else
              let
                val rowsp = search (NUM ^ "\\s*[- ]?(?:inch(?:es)?|in)\\s+(?:rows|between rows)\\b") low
                val plantsp = search (NUM ^ "\\s*[- ]?(?:inch(?:es)?|in)\\s+(?:plant spacing|between plants)\\b") low
                val along = search ("\\brows?\\s+(?:(?:run|running)\\s+)?along\\s+(?:the\\s+)?" ^ NUM ^ FT ^ "\\s+side\\b") low
                val rectangular = case (rowsp, plantsp, dims) of
                    (SOME rm, SOME pm, SOME (l, w)) =>
                      let val rs = g1 low rm val ps = g1 low pm
                          val oriented = case along of
                              SOME am => if sameNumber (g1 low am) l then SOME (l, w)
                                         else if sameNumber (g1 low am) w then SOME (w, l) else NONE
                            | NONE => if sameNumber l w orelse sameNumber rs ps then SOME (l, w) else NONE
                      in Option.map (fn (length, width) => Q.GardenRectGrid
                           (ratOf length, ratOf width, ratOf rs, ratOf ps)) oriented end
                  | _ => NONE
                val sp = search (NUM ^ "\\s*(?:inch(?:es)?|in\\.?|\\\")\\s*(?:apart|spacing|on center)|\\bspac\\w*\\s*(?:of|at)?\\s*" ^ NUM ^ "\\s*(?:inch(?:es)?|in\\.?|\\\")") low
              in
                if isSome rectangular andalso has "\\bhow many\\b" low andalso has "\\bplants?\\b" low
                then rectangular
                else if (isSome rowsp orelse isSome plantsp) andalso isSome dims andalso has "\\bhow many\\b" low andalso has "\\bplants?\\b" low
                then SOME Q.GardenNeedOrientation
                else case (sp, dims) of
                  (SOME sm, SOME (l, w)) =>
                    if has "\\bhow many\\b" low andalso has "\\bplants?\\b|\\bseedlings?\\b|\\btransplants?\\b|\\bheads?\\b" low then
                      let val sl = valOf (firstGroup low sm [1, 2])
                      in if isZero sl then NONE else SOME (Q.GardenGrid (ratOf l, ratOf w, ratOf sl)) end
                    else gardenSoil low dims areaLit
                | _ => gardenSoil low dims areaLit
              end
          end
      end
  and gardenSoil low dims areaLit =
    let
      val dep = search (NUM ^ "\\s*(?:inch(?:es)?|in\\.?|\\\")\\s*(?:deep|tall|high)|\\b(?:deep|depth|tall|high)\\w*\\s*(?:of|is)?\\s*" ^ NUM ^ "\\s*(?:inch(?:es)?|in\\.?)") low
      val depFt = search (NUM ^ FT ^ "\\s*(?:deep|tall|high)\\b") low
      val shape = case dims of
                    SOME (l, w) => SOME (Q.Dims (ratOf l, ratOf w))
                  | NONE => Option.map (fn a => Q.Area (ratOf a)) areaLit
    in
      if (isSome dep orelse isSome depFt) andalso isSome shape
         andalso has "\\bsoil\\b|\\bmix\\b|\\bfill\\b|\\bmulch\\b|\\bcompost\\b|\\bbags?\\b|\\bcubic\\b" low then
        let
          val d = case depFt of
                    SOME m => Q.Feet (ratOf (g1 low m))
                  | NONE => let val m = valOf dep in Q.Inches (ratOf (valOf (firstGroup low m [1, 2]))) end
          val sh = valOf shape
          val bag = search (NUM ^ "\\s*(?:cu\\.? ?ft|cubic f(?:oo|ee)t)\\s*bags?|\\bbags?\\s*(?:of|hold(?:ing)?)?\\s*" ^ NUM ^ "\\s*(?:cu\\.? ?ft|cubic f(?:oo|ee)t)") low
        in
          case bag of
            SOME bm =>
              if has "\\bhow many bags\\b|\\bbags\\b" low
              then SOME (Q.GardenBags (sh, d, ratOf (valOf (firstGroup low bm [1, 2]))))
              else gardenUnits low sh d
          | NONE => gardenUnits low sh d
        end
      else NONE
    end
  and gardenUnits low sh d =
    if has "\\bcubic yards?\\b|\\byards\\b" low then SOME (Q.GardenYards (sh, d))
    else if has "\\bcubic feet\\b|\\bcu\\.? ?ft\\b|\\bhow much soil\\b|\\bvolume\\b" low then SOME (Q.GardenFeet (sh, d))
    else NONE

  (* ================= nutrition-label-v2 ================= *)
  val personal = "\\bshould (?:i|we|my)\\b|\\bhow much should\\b|\\bhealthy for (?:me|my)\\b|\\blose weight\\b|\\bgain weight\\b|\\bmy (?:child|son|daughter|baby|doctor)\\b|\\bpregnan\\w*\\b|\\bdiet plan\\b|\\bam i\\b"

  fun nutV1 t =
    let
      val low = lower t
      val tokens = ExactNumeric.scan low
      val bad = List.exists (fn ExactNumeric.Malformed _ => true | _ => false) tokens
      val quantities = List.mapPartial
        (fn ExactNumeric.Number{start,stop,value,...}=>SOME(value,String.substring(low,0,start),String.extract(low,stop,NONE))|_=>NONE) tokens
      fun quantitiesWith pattern = List.mapPartial(fn(v,_,post)=>
        if has pattern post then SOME(v,post)else NONE)quantities
      fun rat(n,d)=Q.mk_rat n d
      fun scaled(n,d)(a,b)=(n*a,d*b)
      fun add((n,d),(a,b))=(n*b+a*d,d*b)

    in
      if has personal low then NONE
      else if has "\\bbmi\\b|\\bbody mass index\\b" low then
        let
          val ages=List.mapPartial(fn(v,pre,post)=>if has "^[- ]*(?:years?[- ]old|year[- ]olds?)\\b" post orelse has "\\b(?:aged?|age of)\\s*$" pre then SOME v else NONE)quantities
          val pediatric=has "\\b(?:child|children|teen|teenager|pediatric|infant|toddler|adolescent|baby)\\b" low orelse List.exists(fn(n,d)=>n<20*d)ages
          val kg=quantitiesWith "^\\s*(?:kg|kilograms?)\\b"
          val lb=quantitiesWith "^\\s*(?:lb|lbs|pounds?)\\b"
          val metres=quantitiesWith "^\\s*(?:m|meters?|metres?|cm|centimet\\w+)\\b(?!\\s*/)"
          val feet=quantitiesWith "^\\s*(?:ft|feet|foot|')\\b"
          val inches=quantitiesWith "^\\s*(?:inches|inch|in|\\\")\\b"
          val cat=has "\\bcategory\\b|\\bclass\\w*\\b|\\bwhat (?:range|group)\\b" low
          fun metricHeight(v,post)=if has "^\\s*c" post then scaled v (1,100)else v
          fun inchesHeight() = case(feet,inches)of
            ([],[(v,_)])=>SOME v
          | ([(v,_)],[])=>SOME(scaled v(12,1))
          | ([((fnn,fd),_)],[((inn,id),_)])=>if fnn<0 orelse inn<0 then NONE else SOME(add(scaled(fnn,fd)(12,1),(inn,id)))
          | _=>NONE
        in
          if bad then SOME Q.NutUnderspecified
          else if pediatric then SOME Q.NutAdultOnly
          else case(kg,lb,metres,inchesHeight())of
            ([(mass,_)],[],[h],NONE)=>SOME(Q.BmiMetric(rat mass,Q.Mm(rat(metricHeight h)),cat))
          | ([],[(mass,_)],[],SOME h)=>SOME(Q.BmiImperial(rat mass,Q.Iin(rat h),cat))
          | ([(mass,_)],[],[],SOME h)=>SOME(Q.BmiMetric(rat mass,Q.Mm(rat(scaled h(127,5000))),cat))
          | ([],[(mass,_)],[h],NONE)=>SOME(Q.BmiMetric(rat(scaled mass(45359237,100000000)),Q.Mm(rat(metricHeight h)),cat))
          | _=>SOME Q.NutUnderspecified
        end
      else if has "\\bcalories\\b|\\bkcal\\b" low andalso has "\\bprotein\\b|\\bcarb\\w*\\b|\\bfat\\b|\\balcohol\\b" low
              andalso has "\\bhow many calories\\b|\\btotal calories\\b|\\bcalories (?:are )?in\\b|\\bcalories does\\b" low then
        let
          val tokens = ExactNumeric.scan low
          val bad = List.exists (fn ExactNumeric.Malformed _ => true | _ => false) tokens
          fun grams name =
            let
              val values = List.mapPartial
                (fn ExactNumeric.Number {start,stop,value,...} =>
                  let val pre=String.substring(low,0,start)
                      val post=String.extract(low,stop,NONE)
                  in if has ("^\\s*g(?:rams?)?\\s*(?:of\\s+)?(?:" ^ name ^ ")\\b") post orelse
                        (has ("\\b(?:" ^ name ^ ")\\s*(?:of|:|=)?\\s*$") pre andalso has "^\\s*g(?:rams?)?\\b" post)
                     then SOME value else NONE end
                 | _ => NONE) tokens
            in case values of
                 [v] => SOME v
               | [] => if has ("\\b(?:" ^ name ^ ")\\b") low then NONE else SOME(0,1)
               | _ => NONE
            end
          fun rat(n,d)=Q.mk_rat n d
        in
          if bad then SOME Q.NutUnderspecified
          else case (grams "protein",grams "carb\\w*",grams "fat",grams "alcohol") of
            (SOME p,SOME c,SOME f,SOME a) => SOME(Q.Kcal(rat p,rat c,rat f,rat a))
          | _ => SOME Q.NutUnderspecified
        end
      else if has "\\bpercent\\w*\\b|\\b%\\b|\\bshare\\b|\\bproportion\\b" low
              andalso has "\\bcalories from fat\\b|\\bof (?:the )?calories\\b.*\\bfat\\b|\\bfat\\b.*\\bof (?:the )?calories\\b" low then
        (if bad then SOME Q.NutUnderspecified
         else case(quantitiesWith "^\\s*g(?:rams?)?\\s*(?:of\\s+)?(?:total\\s+)?fat\\b",
                   quantitiesWith "^\\s*(?:calories|kcal)\\b")of
           ([(fat,_)],[(energy,_)])=>SOME(Q.PctFatCal(rat fat,rat energy))
         | _=>SOME Q.NutUnderspecified)
      else if has "\\bdaily value\\b|\\b%\\s*dv\\b|\\bpercent dv\\b|\\bdv\\b" low then
        (if bad then SOME Q.NutUnderspecified
         else case(List.filter(fn(p,d)=>has p (if p = List.nth(dvPats,2) then replaceStr "saturated fat" "" low else low))dvTab,
              quantitiesWith ("^\\s*(?:mg|g|mcg|"^mu^"g)\\b"))of
           ([(_,d)],[(amount,post)])=>
             let val u=if has "^\\s*mg\\b" post then Q.U_mg else if has "^\\s*g\\b" post then Q.U_g else Q.U_mcg
             in SOME(Q.PctDV(d,rat amount,u))end
         | _=>SOME Q.NutUnderspecified)
      else NONE
    end

  fun nutrition text =
    if Narrow.narrative text then NONE
    else
      let
        val t = lower (collapse text)
        val t0 = t
        val t = replaceWith "\\b(\\d+(?:,\\d{3})*(?:\\.\\d+)?)[- ](?:calorie|cal|kcal)s?\\b" (fn m => g1 t0 m ^ " calories") t
        val t = replaceWith "\\bof (?:its|their|the|this|that) calories\\b" (fn _ => "of the calories") t
        val t = replaceWith "\\bcalories (?:are |is |that are |that come |come |comes |coming )?from fat\\b" (fn _ => "calories from fat") t
        val low = t
      in
        if has personal low then NONE
        else
          case nutV1 t of
            SOME r => SOME r
          | NONE =>
              if not (has "\\d" low) then NONE
              else if has "\\bbmi\\b|\\bbody mass index\\b" low
                      orelse (has "\\bpercent\\w*\\b|%|\\bshare\\b|\\bproportion\\b" low andalso has "\\bcalories\\b" low andalso has "\\bfat\\b" low)
                      orelse has "\\bdaily value\\b|%\\s*dv\\b|\\bpercent dv\\b" low
                      orelse (has "\\bhow many calories\\b|\\btotal calories\\b" low andalso has "\\bprotein\\b|\\bcarb\\w*\\b|\\bfat\\b|\\balcohol\\b" low)
              then SOME Q.NutUnderspecified
              else NONE
      end

  (* ================= dispatch ================= *)
  val organs = ["anatomy", "anatomy-r2", "agriculture-v2", "gardening", "nutrition-label-v2"]
  val familyOrder = ["nutrition-label-v2", "agriculture-v2", "gardening", "anatomy-r2"]

  fun byId id text =
    case id of
      "anatomy" => anatomy text
    | "anatomy-r2" => anatomyR2 text
    | "agriculture-v2" => agriculture text
    | "gardening" => gardening text
    | "nutrition-label-v2" => nutrition text
    | _ => NONE

  fun recognize mode text =
    if mode = "family" then
      let fun go [] = NONE
            | go (id :: ids) = case byId id text of SOME r => SOME (id, r) | NONE => go ids
      in go familyOrder end
    else Option.map (fn r => (mode, r)) (byId mode text)
end
