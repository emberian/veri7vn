(* UNTRUSTED. The English recognizer for the trades family: a hand port of the
   regular expressions and branch order of
     upstream/root/specialists/architecture/organ_architecture_v1.py (ArchitectureOrgan)
     upstream/root/specialists/printing/organ_printing_v1.py         (PrintingOrgan)
     upstream/root/specialists/printing-v2/organ_printing_v2.py      (PrintingOrganV2, with numbers_rule_v1)
     upstream/root/specialists/safety/organ_safety_v1.py             (SafetyOrgan)
     upstream/root/specialists/woodworking/organ_woodworking_v1.py   (WoodworkingOrgan)
     upstream/root/specialists/crafts/organ_crafts_v1.py             (CraftsOrgan)
   and of their shared narrowing rule narrow_v1.py. It reads numbers and words off the
   question and builds a typed Trades.request; it computes nothing except the one
   product of two stated lengths into an area (drywall) and the comparison of
   openings with that area. Every value, decline and response text comes from the
   verified HOL kernel (Trades.reply_of). NONE means the question is not taken (the
   organ returns None).

   The tables are not duplicated here: each occupancy pattern is paired with the
   same-position entry of Trades.use_order, each filament pattern with
   Trades.fil_order, the factors of which tables_check.py compares with the organs.

   Matching is case-insensitive by lower-casing the text (patterns are passed as
   written, lower-case, per the regex fix of commit d85f26c). \w and \d are ASCII
   here.

   Differences from the organs, none on the panels: a zero load factor, rise or
   spring-like divisor reaches the kernel, which declines it (the organs raise
   ZeroDivisionError); Python's floats are exact rationals here. *)
structure Recognizer :
sig
  val organs : string list
  val recognize : string -> string -> (string * Trades.request) option
end =
struct
  structure Q = Trades

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

  fun replaceAll p rep s =
    let
      fun go i [] acc = String.concat (rev (String.extract (s, i, NONE) :: acc))
        | go i (({start, stop, ...} : Regex.match) :: ms) acc =
            go stop ms (rep :: String.substring (s, i, start - i) :: acc)
    in go 0 (findall p s) [] end

  (* python's str.replace(sub, "") for a literal substring *)
  fun replaceLit sub rep s =
    if sub = "" then s else
    let
      val n = size sub
      fun go i acc =
        if i > size s - n then String.concat (rev (String.extract (s, i, NONE) :: acc))
        else if String.substring (s, i, n) = sub then go (i + n) (rep :: acc)
        else go (i + 1) (String.str (String.sub (s, i)) :: acc)
    in go 0 [] end

  (* exact decimals: "1,000.50" -> (100050, 100) *)
  type lr = IntInf.int * IntInf.int
  fun lrOf (lit0 : string) : lr =
    let
      val lit = String.translate (fn #"," => "" | c => String.str c) lit0
      val (ip, fp) = case String.fields (fn c => c = #".") lit of
                       [a] => (a, "")
                     | [a, b] => (a, b)
                     | _ => raise Fail ("bad numeral " ^ lit0)
    in (valOf (IntInf.fromString (ip ^ fp)), IntInf.pow (10, size fp)) end
  fun lrMul ((a, b) : lr, (c, d) : lr) : lr = (a * c, b * d)
  fun lrDiv ((a, b) : lr, (c, d) : lr) : lr = (a * d, b * c)
  fun lrCmp ((a, b) : lr, (c, d) : lr) = IntInf.compare (a * d, c * b)
  fun lrIsZero ((a, _) : lr) = a = 0
  fun toQ ((a, b) : lr) : Q.rat = Q.mk_rat a b
  fun ratOf s = toQ (lrOf s)
  fun natOf (s : string) = Q.nat_of_integer (valOf (IntInf.fromString s))

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

  (* narrow_v1.numbers: digit runs that are not part of a word or a decimal *)
  fun numbers t = length (findall "(?<![\\w.])\\d+(?:\\.\\d+)?(?!\\w|\\.\\d)" (lower t))

  val N = "(\\d+(?:,\\d{3})*(?:\\.\\d+)?)"     (* architecture, printing *)
  val M = "(\\d+(?:\\.\\d+)?)"                   (* safety, woodworking, crafts *)
  val times = "\195\151"                        (* U+00D7 *)
  val dprime = "\226\128\179"                   (* U+2033 *)
  val sq2 = "\194\178"                          (* U+00B2 *)
  val cu3 = "\194\179"                          (* U+00B3 *)
  fun some x = SOME x
  fun optNum s m g = Option.map ratOf (grp s m g)

  datatype step = Take of Q.request | Stop | Next
  fun run [] = NONE
    | run (s :: ss) = (case s () of Take r => SOME r | Stop => NONE | Next => run ss)

  fun answered r = Q.answered (Q.reply_of r)
  fun replyKind r = Q.reply_kind (Q.reply_of r)

  fun startsWith p s = String.isPrefix p s
  fun lrZeroOrLess ((a, _) : lr) = a <= 0

  (* ---------- architecture ---------- *)
  val AREA = "\\s*(?:sq\\.? ?ft|square feet|ft2|ft" ^ sq2 ^ "|sf)\\b"
  val useRx = ["\\bbusiness\\b|\\boffice\\w*\\b", "\\bmercantile\\b|\\bretail\\b|\\bstore\\b|\\bshop\\b",
               "\\bresidential\\b|\\bdwelling\\b|\\bapartment\\w*\\b", "\\bclassroom\\w*\\b", "\\bstanding\\b",
               "\\bchairs only\\b|\\bconcentrated\\b|\\bauditorium\\b|\\btheater\\b|\\btheatre\\b",
               "\\btables and chairs\\b|\\bunconcentrated\\b|\\brestaurant\\b|\\bdining\\b|\\bbanquet\\b",
               "\\bexercise\\b|\\bgym\\w*\\b|\\bfitness\\b", "\\breading room\\w*\\b", "\\bstack\\w*\\b",
               "\\bcommercial kitchen\\w*\\b|\\bkitchen\\w*\\b", "\\bwarehouse\\w*\\b|\\bstorage\\b"]
  val usePats = zip3 (useRx, Q.use_order, "use_order")

  fun architecture text : Q.request option =
    if Narrow.narrative text then NONE else
    let
      val low = lower (collapse text)
      val lot = search ("\\blot\\s*(?:area\\s*)?(?:of|is|=|size)?\\s*(?:\\w+\\s+){0,2}?" ^ N ^ AREA
                        ^ "|" ^ N ^ AREA ^ "\\s*lot\\b") low
      val lotLr = Option.map (fn m => lrOf (valOf (firstGroup low m [1, 2]))) lot
      val lotv = case lotLr of SOME l => if lrIsZero l then NONE else SOME l | NONE => NONE
      fun ramp () =
        if has "\\bramp\\b" low andalso has "\\bhow long\\b|\\blength\\b|\\brun\\b" low then
          let val u = "(inches|inch|in\\b|\\\"|feet|foot|ft|')"
          in
            case search (N ^ "\\s*" ^ u ^ "\\s*(?:rise|high|tall|change in level|vertical)|\\brise\\s*(?:of|is)?\\s*" ^ N ^ "\\s*" ^ u) low of
              SOME m =>
                let val (v, un) = case grp low m 1 of SOME v => (v, valOf (grp low m 2))
                                                     | NONE => (valOf (grp low m 3), valOf (grp low m 4))
                in Take (Q.Ramp (ratOf v, startsWith "f" un orelse startsWith "'" un)) end
            | NONE => Next
          end
        else Next
      fun far () =
        if has "\\bfar\\b|\\bfloor area ratio\\b" low then
          let
            val fr = search "\\b(?:far|floor area ratio)\\s*(?:of|is|=)?\\s*(\\d+(?:\\.\\d+)?)\\b" low
            val fl = search ("\\b(?:total )?(?:floor|building|gross floor) area\\s*(?:of|is|=)?\\s*" ^ N ^ AREA
                             ^ "|" ^ N ^ AREA ^ "\\s*(?:of\\s+)?(?:total\\s+)?(?:floor|building|gross) area\\b|"
                             ^ N ^ AREA ^ "\\s*building\\b") low
          in
            case (lotv, fr, fl) of
              (SOME l, SOME f, _) =>
                if has "\\bmax\\w*\\b|\\bhow much\\b|\\ballow\\w*\\b|\\bbuild\\b" low
                then Take (Q.MaxFloor (ratOf (g1 low f), toQ l))
                else (case fl of SOME m => Take (Q.Far (ratOf (valOf (firstGroup low m [1, 2, 3])), toQ l)) | NONE => Next)
            | (SOME l, NONE, SOME m) => Take (Q.Far (ratOf (valOf (firstGroup low m [1, 2, 3])), toQ l))
            | _ => Next
          end
        else Next
      fun coverage () =
        case lotv of
          SOME l =>
            if has "\\blot coverage\\b|\\bcoverage\\b" low then
              (case search ("\\bfootprint\\s*(?:of|is|=)?\\s*" ^ N ^ AREA ^ "|" ^ N ^ AREA ^ "\\s*(?:building\\s+)?footprint\\b") low of
                 SOME m => Take (Q.Coverage (ratOf (valOf (firstGroup low m [1, 2])), toQ l))
               | NONE => Next)
            else Next
        | NONE => Next
      fun occupant () =
        if has "\\boccupant load\\b|\\boccupants\\b|\\bhow many (?:people|occupants)\\b|\\begress width\\b|\\bexit width\\b|\\bstair width\\b" low then
          case search (N ^ AREA) low of
            NONE => Stop
          | SOME am =>
              let
                val a = ratOf (g1 low am)
                val fm = search ("\\b(?:load factor|occupant load factor)\\s*(?:of|is|=)?\\s*" ^ N
                                 ^ "|" ^ N ^ "\\s*(?:sq\\.? ?ft|square feet|sf)\\s*(?:net|gross)?\\s*per\\s*(?:person|occupant)") low
                val src = case fm of
                            SOME m => SOME (Q.Given (ratOf (valOf (firstGroup low m [1, 2]))))
                          | NONE => (case List.find (fn (rx, _) => has rx low) usePats of
                                       SOME (_, u) => SOME (Q.Table u) | NONE => NONE)
              in
                case src of
                  NONE => Stop
                | SOME s =>
                    if has "\\begress width\\b|\\bexit width\\b|\\bstair width\\b|\\bhow wide\\b" low
                    then Take (Q.Egress (a, s, has "\\bstair\\w*\\b" low))
                    else Take (Q.Occupant (a, s))
              end
        else Next
    in
      case run [ramp, far, coverage, occupant] of
        SOME r => if answered r then SOME r else NONE
      | NONE => NONE
    end

  (* ---------- printing (v1; v2 wraps it) ---------- *)
  val filRx = ["pla", "petg", "abs", "asa", "tpu", "nylon"]
  val filPats = zip3 (filRx, Q.fil_order, "fil_order")


  (* Unit/source roles remain untrusted; exact conversions happen in HOL. *)
  val linearUnits = List.concat (map (fn (tag,aliases) => map (fn alias =>
    {alias=alias,tag=tag,dimension="length",caseSensitive=false}) aliases)
    [("mm",["mm","millimeter","millimeters","millimetre","millimetres"]),
     ("cm",["cm","centimeter","centimeters","centimetre","centimetres"]),
     ("m",["m","meter","meters","metre","metres"]),
     ("in",["in","inch","inches","\"",dprime]),
     ("ft",["ft","foot","feet","'"]), ("yd",["yd","yds","yard","yards"])])
  fun linearUnit tag = case tag of "mm"=>SOME Q.BU_mm | "cm"=>SOME Q.BU_cm
    | "m"=>SOME Q.BU_m | "in"=>SOME Q.BU_in | "ft"=>SOME Q.BU_ft
    | "yd"=>SOME Q.BU_yd | _=>NONE
  fun linearValue m = case MeasuredInput.bind {expected="length",inheritFrom=NONE} m of
      MeasuredInput.Bound{unit,...} => Option.map(fn u=>(toQ(#value m),u))(linearUnit(#tag unit))
    | _=>NONE
  fun measuredNumbers raw =
    let val items=MeasuredInput.scan linearUnits raw in
      if List.exists(fn MeasuredInput.Malformed _=>true | _=>false)items then NONE
      else SOME(List.mapPartial(fn MeasuredInput.Measurement m=>SOME m | _=>NONE)items)
    end
  fun unitStop (m:MeasuredInput.measurement) = case #unitBinding m of
      MeasuredInput.Explicit{span={stop,...},...}=>stop
    | _=> #stop(#numberSpan m)
  fun layersExact raw =
    let
      (* Ignore the 3D process name, preserving byte positions for measurements. *)
      val input=replaceAll "\\b3[dD]\\b" "  " raw
      val low=lower input
      fun prefix (m:MeasuredInput.measurement)=String.substring(low,0,#start(#numberSpan m))
      fun after m=String.extract(low,unitStop m,NONE)
      fun layerRole m=has "\\blayer (?:height|thickness)\\s*(?:of|is|=|:)?\\s*$" (prefix m)
        orelse has "^\\s*(?:layers?\\b|layer (?:height|thickness)\\b)" (after m)
      fun heightRole m=not(layerRole m) andalso
        (has "\\b(?:height|tall|high)\\s*(?:of|is|=|:)?\\s*$" (prefix m)
        orelse has "^\\s*(?:tall|high|height)\\b" (after m))
      fun only [m]=linearValue m | only _=NONE
      val framing=["a","an","the","part","model","print","printed","printing","printer","is","has","at","with",
        "of","and","using","uniform","constant","layer","layers","height","thickness","tall","high",
        "how","many","what","number","count","calculate","for"]
      fun remainder ms =
        let fun go pos [] acc=String.concat(rev(String.extract(low,pos,NONE)::acc))
              | go pos (m::rest) acc=go(unitStop m)rest
                  (" "::String.substring(low,pos,#start(#numberSpan m)-pos)::acc)
        in go 0 ms [] end
      fun parse ms =
        let val rest=remainder ms
            val words=map(fn m=>Regex.whole rest m)(findall "[a-z]+" rest)
            val direct=List.all(fn w=>List.exists(fn f=>f=w)framing)words
        in if length ms<>2 orelse not direct then Q.Layers(NONE,NONE)
           else Q.Layers(only(List.filter heightRole ms),only(List.filter layerRole ms)) end
    in case measuredNumbers input of SOME ms=>parse ms | NONE=>Q.Layers(NONE,NONE) end
  fun fabricYardsExact raw =
    let val low=lower raw
        val framing=["how","many","much","yards","yard","yd","yds","are","is","in","of","convert","to",
          "fabric","cloth","ribbon","yarn","material","length","long","the","a","an","this","that"]
        fun parse [m] =
              let val first= #start(#numberSpan m)
                  val rest=String.substring(low,0,first)^" "^String.extract(low,unitStop m,NONE)
                  val words=map(fn x=>Regex.whole rest x)(findall "[a-z]+" rest)
                  val direct=List.all(fn w=>List.exists(fn f=>w=f)framing)words
              in if not direct then Q.YardsUnread else
                (case linearValue m of SOME(v,u)=>Q.Yards(v,u) | NONE=>Q.YardsUnread) end
          | parse _=Q.YardsUnread
    in case measuredNumbers raw of SOME ms=>parse ms | NONE=>Q.YardsUnread end

  fun printingCore text : Q.request option =
    let
      val low = lower (collapse text)
    in
      if not (has ("\\b3d[- ]?print\\w*\\b|\\bfilament\\b|\\bprint(?:er|ing)?\\b|\\blayer height\\b|\\bnozzle\\b|\\bshrink\\w*\\b|\\bpla\\b|\\bpetg\\b|\\babs\\b") low)
      then NONE
      else
        let
          val mat = Option.map #2 (List.find (fn (k, _) => has ("\\b" ^ k ^ "\\b") low) filPats)
          val dm = search ("\\bdensity\\s*(?:of|is|=)?\\s*" ^ N) low
          val dens = case dm of
                       SOME m => Q.D_given (ratOf (g1 low m))
                     | NONE => (case mat of SOME f => Q.D_typical f | NONE => Q.D_none)
          fun diameter () =
            if has "\\bfilament\\b|\\bdiameter\\b|\\bspool\\b" low then
              let
                val ms = findall (N ^ "\\s*mm\\b(?!\\s*(?:/s|layer|tall|high|line|extrusion))") low
                val ok = List.find (fn m =>
                           let val v = lrOf (g1 low m)
                           in lrCmp (v, lrOf "1.5") <> LESS andalso lrCmp (v, lrOf "3.2") <> GREATER end) ms
              in Option.map (fn m => ratOf (g1 low m)) ok end
            else NONE
          val d_mm = diameter ()
          fun shrink () =
            if has "\\bshrink\\w*\\b" low andalso has "\\bscale\\b|\\bcompensat\\w*\\b|\\bhow much (?:bigger|larger)\\b" low
            then Take (Q.Shrink (Option.map (fn m => ratOf (g1 low m)) (search (N ^ "\\s*%") low)))
            else Next
          fun layers () =
            if has "\\bhow many layers\\b|\\blayer count\\b|\\bnumber of layers\\b" low then
              Take (layersExact text)
            else Next
          fun flow () =
            if has ("\\bvolumetric\\b|\\bflow rate\\b|\\bmm3/s\\b|\\bmm" ^ cu3 ^ "/s\\b") low then
              let
                val lh = search ("\\blayer height\\s*(?:of|is)?\\s*" ^ N ^ "|" ^ N ^ "\\s*mm\\s*layer") low
                val lw = search ("\\b(?:line|extrusion) width\\s*(?:of|is)?\\s*" ^ N ^ "|" ^ N ^ "\\s*mm\\s*(?:line|extrusion) width") low
                val sp = search (N ^ "\\s*mm/s\\b") low
                fun v m = Option.map (fn m => ratOf (valOf (firstGroup low m [1, 2]))) m
              in Take (Q.Flow (v lh, v lw, Option.map (fn m => ratOf (g1 low m)) sp)) end
            else Next
          fun cost () =
            let
              val grams = search (N ^ "\\s*(?:g|grams?)\\b(?!/)") low
              val price = search ("\\$\\s*" ^ N ^ "\\s*(?:per|/|a)\\s*(kg|kilogram|spool)") low
            in
              case (price, grams) of
                (SOME p, SOME g) =>
                  if has "\\bcost\\b|\\bhow much\\b|\\bprice\\b" low then
                    let val pr = ratOf (g1 low p) val gr = ratOf (g1 low g) in
                      if valOf (grp low p 2) = "spool" then
                        (case search (N ^ "\\s*(kg|g)\\s*spool") low of
                           NONE => Take (Q.Cost (gr, Q.Per_spool (pr, NONE)))
                         | SOME s => Take (Q.Cost (gr, Q.Per_spool (pr, SOME (ratOf (g1 low s), valOf (grp low s 2) = "kg")))))
                      else Take (Q.Cost (gr, Q.Per_kg pr))
                    end
                  else Next
              | _ => Next
            end
          val lm = search (N ^ "\\s*(m|meters?|metres?)\\s*of\\b|\\b" ^ N ^ "\\s*(m|meters?|metres?)\\b(?!\\s*/)") low
          val km = search (N ^ "\\s*(kg|g|grams?|kilograms?)\\b(?!/)") low
          fun length () =
            case km of
              SOME k =>
                if has "\\bhow (?:long|many meters|many metres|much length)\\b|\\blength\\b" low
                   andalso not (has "\\bweigh|\\bmass\\b|\\bhow (?:much|many grams)\\b(?! length)"
                                    (replaceLit (Regex.whole low k) "" low))
                then
                  let val mg = lrMul (lrOf (g1 low k), if startsWith "k" (valOf (grp low k 2)) then lrOf "1000" else lrOf "1")
                  in Take (Q.FilLength (toQ mg, d_mm, dens)) end
                else Next
            | NONE => Next
          fun mass () =
            case lm of
              SOME m =>
                if has "\\bweigh|\\bmass\\b|\\bhow (?:much|many grams)\\b" low
                then Take (Q.FilMass (ratOf (valOf (firstGroup low m [1, 3])), d_mm, dens))
                else Next
            | NONE => Next
        in
          run [shrink, layers, flow, cost, length, mass]
        end
    end

  fun printingV1 text : Q.request option =
    if Narrow.narrative (replaceAll "(?<=\\d)\\.(?=\\d)" "" text) then NONE
    else case printingCore (replaceAll "\\bprinted\\b" "printed (printing)" (lower text)) of
           NONE => NONE
         | SOME r => if answered r orelse Narrow.short_direct text then SOME r else NONE

  (* v2: "printed" is a print cue, "mm high" reads as "mm tall", and the family numbers rule *)
  fun printingV2 text : Q.request option =
    let
      val t = replaceAll "\\bmm high\\b" "mm tall" (lower text)
    in
      case printingV1 t of
        NONE => NONE
      | SOME r => (case r of Q.Layers _=>SOME r | _=>if replyKind r = "underspecified" andalso numbers text >= 1 then NONE else SOME r)
    end

  (* ---------- safety ---------- *)
  fun safety text : Q.request option =
    let
      val low = lower (collapse text)
      fun judge () =
        if has "\\bis (?:it|this|that) safe\\b|\\bam i safe\\b|\\bsafe for me\\b|\\bokay to (?:work|enter|climb)\\b" low
           andalso has "\\b(?:work\\w*|job|site|lift\\w*|ladder|noise|dba|exposure|shift|osha|niosh|scaffold\\w*)\\b" low
        then Take Q.Judge else Next
      val levels = List.map (fn m => ratOf (g1 low m)) (findall (M ^ "\\s*db(?:a)?\\b") low)
      fun noise () =
        if not (null levels) andalso has "\\bnoise\\b|\\bdb" low
           andalso has "\\bhow long\\b|\\bpermissible\\b|\\bexposure\\b|\\bdose\\b|\\btwa\\b|\\btime[- ]weighted\\b|\\ballowed\\b" low
        then
          if has "\\bdose\\b|\\btwa\\b|\\btime[- ]weighted\\b" low then
            let val durs = List.map (fn m => ratOf (g1 low m)) (findall (M ^ "\\s*(?:hours?|hrs?|h)\\b") low)
            in
              if has "\\btwa\\b|\\btime[- ]weighted\\b" low andalso not (has "\\bdose\\b" low)
              then Take (Q.Twa (levels, durs)) else Take (Q.NoiseDose (levels, durs))
            end
          else Take (Q.NoiseTime (hd levels))
        else Next
      fun ladder () =
        if has "\\bladder\\b" low andalso has "\\bhow far\\b|\\bbase\\b|\\bfoot\\b|\\bfeet from\\b|\\baway from\\b|\\bdistance\\b|\\bset\\b" low
        then
          case search (M ^ "\\s*(ft|feet|foot|m|meters?|metres?)\\b") low of
            NONE => Take (Q.Ladder (NONE, Q.L_ft))
          | SOME m => Take (Q.Ladder (SOME (ratOf (g1 low m)), if startsWith "f" (valOf (grp low m 2)) then Q.L_ft else Q.L_m))
        else Next
      fun niosh () =
        if has "\\bniosh\\b|\\brecommended weight limit\\b|\\brwl\\b|\\blifting index\\b" low then
          let
            val tokens = ExactNumeric.scan low
            val ns = if List.exists (fn ExactNumeric.Malformed _ => true | _ => false) tokens then []
                     else List.mapPartial (fn ExactNumeric.Number n => SOME n | _ => NONE) tokens
            fun prefixOf ({start,...} : {start:int,stop:int,value:lr}) = String.substring (low, 0, start)
            fun after ({stop,...} : {start:int,stop:int,value:lr}) = String.extract (low, stop, NONE)
            fun only ([n] : {start:int,stop:int,value:lr} list) = SOME (toQ (#value n)) | only _ = NONE
            fun grab label letter incompatible = only (List.filter (fn n =>
              not (has incompatible (after n)) andalso (has ("\\b(?:" ^ label ^ ")\\s*(?:of|is|=|:)?\\s*$") (prefixOf n) orelse
              has ("(?<![\\w])" ^ letter ^ "\\s*=\\s*$") (prefixOf n))) ns)
            val otherLength = "^\\s*(?:mm|millimet\\w*|m|metres?|meters?|inch(?:es)?|in|feet|foot|ft)\\b"
            val h = grab "horizontal(?: distance| location)?" "h" otherLength
            val v = grab "vertical (?:height|location|start)" "v" otherLength
            val d = grab "(?:travel distance|vertical travel(?: distance)?|lift distance|distance (?:moved|travell?ed))" "d" otherLength
            val a = grab "asymmetry(?: angle)?" "a" "^\\s*(?:rad(?:ians?)?|turns?|grads?)\\b"
            val fm = grab "frequency multiplier" "fm" "^\\s*(?:%|percent\\b)"
            val cm = grab "coupling multiplier" "cm" "^\\s*(?:%|percent\\b)"
            val want_li = has "\\blifting index\\b|\\bli\\b" low
            val ld = if want_li then only (List.filter (fn n =>
              (has "\\b(?:load|weighs?|lifting|lift(?:s|ing)? a)\\s*(?:of|is|=|:)?\\s*$" (prefixOf n)
               andalso has "^\\s*kg\\b" (after n)) orelse
              has "^\\s*kg\\s*(?:load|box|object|bag)\\b" (after n)) ns) else NONE
          in Take (Q.Niosh (h, v, d, a, fm, cm, want_li, ld)) end
        else Next
    in
      run [judge, noise, ladder, niosh]
    end

  (* ---------- woodworking ---------- *)
  val xby = "(?:x|" ^ times ^ "|by)"
  val inch1 = "(in|inch(?:es)?|\\\"|" ^ dprime ^ ")"
  fun isInchUnit u = startsWith "in" u orelse u = "\"" orelse u = dprime
  val sideWords = [("picture frame", 4), ("rectangular", 4), ("triangular", 3), ("pentagonal", 5),
                   ("rectangle", 4), ("hexagonal", 6), ("octagonal", 8), ("dodecagon", 12),
                   ("triangle", 3), ("pentagon", 5), ("hexagon", 6), ("octagon", 8), ("decagon", 10),
                   ("square", 4)]

  (* The complete dimension field is isolated by the product/role grammar.
     Shared unit parsing therefore cannot mistake a product separator for part
     of a compound unit. These spans are local to the isolated unit field. *)
  fun boardFeetExact raw =
    let
      fun u alias tag = {alias=alias,tag=tag,dimension="length",caseSensitive=false}
      val units = List.concat (map (fn (tag,aliases) => map (fn a=>u a tag) aliases)
        [("in",["in","inch","inches","\"",dprime]),("ft",["ft","foot","feet","'"]),
         ("cm",["cm","centimeter","centimeters","centimetre","centimetres"]),
         ("mm",["mm","millimeter","millimeters","millimetre","millimetres"])])
      fun unit field default =
        if List.all Char.isSpace (String.explode field) then default else
        case MeasuredInput.unitAt units field 0 of
          SOME (ub as MeasuredInput.Explicit {unit=us,span={stop,...}}) =>
            if not (List.all Char.isSpace (String.explode (String.extract(field,stop,NONE)))) then NONE
            else (case MeasuredInput.bind {expected="length",inheritFrom=NONE}
                    {id=0,numberSpan={start=0,stop=0},value=(0,1),unitBinding=ub} of
              MeasuredInput.Bound _ => (case #tag us of "in"=>SOME Q.BU_in | "ft"=>SOME Q.BU_ft
                  | "cm"=>SOME Q.BU_cm | "mm"=>SOME Q.BU_mm | _=>NONE)
            | _=>NONE)
        | _=>NONE
      val marker="(qnum[0-9]+q)"
      val field="\\s*((?!(?:lumber|boards?|planks?|each)\\b)[a-z]+|\\\"|'|" ^ dprime ^ ")?\\s*"
      fun parse {text=masked,numbers=ns} =
        let
          val low=lower masked
          fun value key = Option.map (toQ o #2) (List.find(fn(k,_)=>k=key) ns)
          fun capture m i = case grp low m i of SOME x=>x | NONE=>""
          fun qty m i = value (capture m i)
          val countNoun="(?:boards?(?![- ]f(?:ee|oo)t)|pieces?|planks?)\\b"
          val countMatches=findall(marker ^ "\\s+(?:" ^ countNoun ^ "|of them\\b)") low
          val wordMatches=findall ("(?:^|\\b(?:in|for|of|from|with))\\s*([a-z]+(?:[- ][a-z]+){0,4})\\s+" ^ countNoun) low
          val smallWords=[("a",1),("an",1),("zero",0),("one",1),("two",2),("three",3),("four",4),
             ("five",5),("six",6),("seven",7),("eight",8),("nine",9),("ten",10),("eleven",11),
             ("twelve",12),("thirteen",13),("fourteen",14),("fifteen",15),("sixteen",16),
             ("seventeen",17),("eighteen",18),("nineteen",19),("twenty",20),("thirty",30),
             ("forty",40),("fifty",50),("sixty",60),("seventy",70),("eighty",80),("ninety",90)]
          fun wordValue w = Option.map #2 (List.find(fn(k,_)=>k=w)smallWords)
          fun wordCount phrase =
            case String.tokens(fn c=>Char.isSpace c orelse c = #"-")phrase of
              [w]=>wordValue w
            | [a,b]=>(case(wordValue a,wordValue b)of(SOME x,SOME y)=>
                  if x>=20 andalso x mod 10=0 andalso y>0 andalso y<10 then SOME(x+y) else NONE
                | _=>NONE)
            | _=>NONE
          val quantityNouns=length(findall countNoun low) + length(findall "\\bof them\\b" low)
          val pluralNouns=length(findall "\\b(?:boards|pieces|planks|of them)\\b" low)
          val residue=List.foldl(fn(m,t)=>replaceLit (Regex.whole low m) " " t) low wordMatches
          val qtyWords=map #1 (List.filter(fn(w,_)=>not(List.exists(fn a=>w=a)["a","an","one"])) smallWords)
            @ ["hundred","thousand","million","dozen","half","quarter","both","several","some"]
          val leftoverQuantity=has ("\\b(?:" ^ String.concatWith "|" qtyWords ^ ")\\b") residue
          val count = if leftoverQuantity then NONE else case (countMatches,wordMatches) of
              ([m],[])=>if quantityNouns=1 then qty m 1 else NONE
            | ([],[m])=>if quantityNouns=1 then Option.map(fn n=>toQ(IntInf.fromInt n,1))(wordCount(capture m 1)) else NONE
            | ([],[])=>if pluralNouns=0 then SOME(toQ(1,1)) else NONE
            | _=>NONE
          val countKeys=map(fn m=>capture m 1)countMatches
          val ending="(?=\\s*(?:long\\b|length\\b|board\\b|lumber\\b|[?,.;]|$))"
          val tuple1=marker ^ field ^ xby ^ "\\s*" ^ marker ^ field ^ xby ^ "\\s*" ^ marker ^ field ^ ending
          val tuple2=marker ^ field ^ xby ^ "\\s*" ^ marker ^ field ^
            "(?:lumber|boards?|planks?)?\\s*[,;]?\\s*(?:each\\s+)?" ^ marker ^ field ^ ending
          val tuples=case findall tuple1 low of []=>findall tuple2 low | xs=>xs
          fun mk (ak,au,bk,bu,ck,cu) =
            case (value ak,unit au (SOME Q.BU_in),value bk,unit bu (SOME Q.BU_in),value ck,unit cu NONE,count) of
              (SOME a,SOME ua,SOME b,SOME ub,SOME c,SOME uc,SOME n)=>
                if List.all(fn(k,_)=>List.exists(fn used=>k=used)(ak::bk::ck::countKeys))ns
                then Q.BoardFeet(a,ua,b,ub,c,uc,n) else Q.BoardUnread
            | _=>Q.BoardUnread
          fun namedRole role = findall(marker ^ field ^ role ^ "\\b")low
          val thick=namedRole "(?:thick|thickness)"
          val wide=namedRole "(?:wide|width)"
          val long=namedRole "(?:long|length)"
        in case tuples of
             [m]=>mk(capture m 1,capture m 2,capture m 3,capture m 4,capture m 5,capture m 6)
           | []=>(case(thick,wide,long)of
               ([a],[b],[c])=>mk(capture a 1,capture a 2,capture b 1,capture b 2,capture c 1,capture c 2)
             | _=>Q.BoardUnread)
           | _=>Q.BoardUnread
        end
    in if has "\\b(?:round|cylindrical|tapered|irregular|hollow|cutouts?|notches?|waste|allowance)\\b" (lower raw)
       then Q.BoardUnread
       else case ExactNumeric.mask raw of NONE=>Q.BoardUnread | SOME x=>parse x end

  fun woodworkingCore text : Q.request option =
    let
      val low = lower (collapse text)
      fun actual () =
        case search ("\\b(\\d{1,2})\\s*" ^ xby ^ "\\s*(\\d{1,2})\\b(?!\\s*(?:ft|feet|foot|'|m\\b|sheet))") low of
          SOME nm =>
            if has "\\bactual\\b|\\breally\\b|\\breal (?:size|dimensions?)\\b|\\btrue (?:size|dimensions?)\\b|\\bnominal\\b" low
               andalso has ("\\blumber\\b|\\bboard\\b|\\bstud\\b|\\bwood\\b|\\bjoist\\b|\\b\\d{1,2}\\s*(?:x|" ^ times ^ ")\\s*\\d{1,2}\\b") low
               andalso not (has "\\bboard feet\\b|\\bboard foot\\b" low)
            then Take (Q.ActualSize (natOf (g1 low nm), natOf (valOf (grp low nm 2))))
            else Next
        | NONE => Next
      fun boardFeet () =
        if has "\\bboard[- ]f(?:ee|oo)t(?:age)?\\b|\\bbd\\.? ?ft\\b" low
        then Take(boardFeetExact text) else Next
      fun concrete () =
        if has "\\bconcrete\\b|\\bslab\\b|\\bfooting\\b|\\bpour\\b" low andalso has ("\\bcubic yards?\\b|\\byards?\\b|\\byd3\\b|\\byd" ^ cu3 ^ "\\b") low then
          let
            val m = search (M ^ "\\s*(?:ft|feet|foot|')?\\s*" ^ xby ^ "\\s*" ^ M ^ "\\s*(?:ft|feet|foot|')") low
            val d = search (M ^ "\\s*(in|inch(?:es)?|\\\"|" ^ dprime ^ "|ft|feet|foot)\\s*(?:thick|deep|depth)\\b|\\b(?:thick|deep|depth)\\w*\\s*(?:of|is|=)?\\s*" ^ M ^ "\\s*(in|inch(?:es)?|ft|feet)") low
          in
            case (m, d) of
              (SOME m, SOME d) =>
                let val (dv, du) = case grp low d 1 of SOME v => (v, valOf (grp low d 2))
                                                      | NONE => (valOf (grp low d 3), valOf (grp low d 4))
                in Take (Q.Concrete (ratOf (g1 low m), ratOf (valOf (grp low m 2)), ratOf dv, isInchUnit du)) end
            | _ => Stop
          end
        else Next
      fun drywall () =
        if has "\\bdrywall\\b|\\bgypsum\\b|\\bsheetrock\\b|\\bplasterboard\\b" low andalso has "\\bhow many\\b|\\bsheets\\b|\\bpanels\\b" low then
          let
            val sheet = if has ("\\b4\\s*" ^ xby ^ "\\s*10\\b") low then Q.S40 else if has ("\\b4\\s*" ^ xby ^ "\\s*12\\b") low then Q.S48 else Q.S32
            val am = search (M ^ "\\s*(?:sq\\.? ?ft|square feet|ft2|ft" ^ sq2 ^ ")") low
            val dims = search (M ^ "\\s*(?:ft|feet|foot|')\\s*(?:x|" ^ times ^ "|by|long by|wide by)\\s*" ^ M ^ "\\s*(?:ft|feet|foot|')") low
            val area = case am of
                         SOME m => SOME (lrOf (g1 low m))
                       | NONE => (case dims of SOME d => SOME (lrMul (lrOf (g1 low d), lrOf (valOf (grp low d 2)))) | NONE => NONE)
          in
            case area of
              NONE => Stop
            | SOME a =>
                let
                  val op_ = search ("\\b(?:minus|less|subtract\\w*|with|excluding)\\s+(?:a\\s+|an\\s+)?(?:\\w+\\s+){0,3}?" ^ M
                                    ^ "\\s*(?:sq\\.? ?ft|square feet)\\s*(?:of\\s+)?(?:openings?|windows?|doors?)") low
                  val opn = case op_ of SOME m => lrOf (g1 low m) | NONE => lrOf "0"
                in
                  if lrCmp (opn, a) <> LESS then Stop else Take (Q.Drywall (toQ a, toQ opn, sheet))
                end
          end
        else Next
      fun stairs () =
        if has "\\bstairs?\\b|\\bstaircase\\b|\\brisers?\\b|\\bsteps\\b" low
           andalso has "\\btotal rise\\b|\\brise of\\b|\\bfloor to floor\\b|\\bfloor-to-floor\\b|\\bheight of\\b" low then
          case search ("\\b(?:total rise|rise|floor[- ]to[- ]floor(?: height)?|height)\\s*(?:of|is|=)?\\s*" ^ M
                       ^ "\\s*(in|inch(?:es)?|\\\"|" ^ dprime ^ "|ft|feet)") low of
            NONE => Stop
          | SOME m =>
              Take (Q.Stairs (ratOf (g1 low m), startsWith "f" (valOf (grp low m 2)),
                              has "\\bhow (?:tall|high)\\b|\\beach riser\\b|\\briser height\\b" low
                              andalso not (has "\\bhow many\\b" low)))
        else Next
      fun roof () =
        case search "\\b(\\d+(?:\\.\\d+)?)\\s*(?:/|-in-|in|:)\\s*12\\b" low of
          SOME pm =>
            if has "\\bpitch\\b|\\broof\\b|\\brafter\\b|\\bslope\\b" low then
              let val x = ratOf (g1 low pm) in
                if has "\\brafter\\b" low andalso has "\\blength\\b|\\bhow long\\b" low then
                  (case search ("\\brun\\s*(?:of|is|=)?\\s*" ^ M ^ "\\s*(ft|feet|in|inch(?:es)?)|" ^ M ^ "\\s*(ft|feet|in|inch(?:es)?)\\s*(?:of\\s+)?run\\b") low of
                     NONE => Stop
                   | SOME rm =>
                       let val (rv, ru) = case grp low rm 1 of SOME v => (v, valOf (grp low rm 2))
                                                              | NONE => (valOf (grp low rm 3), valOf (grp low rm 4))
                       in Take (Q.Rafter (x, ratOf rv, startsWith "f" ru)) end)
                else if has "\\bangle\\b|\\bdegrees?\\b" low then Take (Q.Pitch x)
                else Next
              end
            else Next
        | NONE => Next
      fun miter () =
        if has "\\bmiter\\b|\\bmitre\\b" low andalso has "\\bangle\\b|\\bdegrees?\\b|\\bset\\b|\\bcut\\b" low then
          let
            val n = case search "\\b(\\d+)[- ]sided\\b|\\b(\\d+)\\s+sides\\b" low of
                      SOME sm => SOME (natOf (valOf (firstGroup low sm [1, 2])))
                    | NONE => (case List.find (fn (w, _) => has ("\\b" ^ w ^ "\\b") low) sideWords of
                                 SOME (_, k) => SOME (natOf (Int.toString k)) | NONE => NONE)
          in case n of NONE => Stop | SOME n => Take (Q.Miter n) end
        else Next
      fun moisture () =
        if has "\\bmoisture content\\b" low andalso has "\\bwood\\b|\\blumber\\b|\\bboard\\b|\\btimber\\b|\\bsample\\b" low then
          let
            val wm = search (M ^ "\\s*g\\s*(?:when\\s+)?(?:wet|green)\\b|\\b(?:wet|green) (?:mass|weight)\\s*(?:of|is|=)?\\s*" ^ M) low
            val dm = search (M ^ "\\s*g\\s*(?:when\\s+)?(?:oven[- ])?dry\\b|\\b(?:oven[- ])?dry (?:mass|weight)\\s*(?:of|is|=)?\\s*" ^ M) low
          in
            case (wm, dm) of
              (SOME w, SOME d) => Take (Q.Moisture (ratOf (valOf (firstGroup low w [1, 2])), ratOf (valOf (firstGroup low d [1, 2]))))
            | _ => Stop
          end
        else Next
    in
      run [actual, boardFeet, concrete, drywall, stairs, roof, miter, moisture]
    end

  fun woodworking text : Q.request option =
    (* Decimal punctuation is not a sentence boundary, even in a malformed
       numeric run. The raw text still goes to the exact scanner below. *)
    if Narrow.narrative (replaceAll "(?<=[0-9])\\.(?=[0-9])" "" text) then NONE
    else case woodworkingCore text of
           NONE => NONE
         | SOME r => (case r of Q.BoardFeet _ => SOME r | Q.BoardUnread => SOME r
             | _ => if answered r orelse Narrow.short_direct text then SOME r else NONE)

  (* ---------- crafts ---------- *)
  val colourWords = [("red", Q.C_red), ("yellow", Q.C_yellow), ("blue", Q.C_blue), ("green", Q.C_green),
                     ("orange", Q.C_orange), ("purple", Q.C_purple), ("violet", Q.C_violet),
                     ("cyan", Q.C_cyan), ("magenta", Q.C_magenta), ("white", Q.C_white), ("black", Q.C_black)]
  val colourRx = "\\b(red|yellow|blue|green|orange|purple|violet|cyan|magenta|white|black)\\b"
  fun colourOf w = #2 (valOf (List.find (fn (k, _) => k = w) colourWords))
  val crUnit = "(inch(?:es)?|in\\b|\\\"|cm|centimet\\w+)"

  fun crafts text : Q.request option =
    let
      val t = collapse text
      val low = lower t
      val gauge = has "\\d+(?:\\.\\d+)?\\s*(?:stitches|sts|rows)\\s*(?:per|over|in)\\s*\\d" low andalso Narrow.sentences t <= 2
    in
      if Narrow.narrative (if has "\\byards?\\b" low andalso has "\\b(?:fabric|cloth|ribbon|yarn|material)\\b" low
          then replaceAll "(?<=[0-9])\\.(?=[0-9])" "" text else text) andalso not gauge then NONE
      else
        let
          fun colour () =
            let
              val cols = List.map (fn m => g1 low m) (findall colourRx low)
              val distinct = List.foldl (fn (c, acc) => if List.exists (fn x => x = c) acc then acc else acc @ [c]) [] cols
              val mixing = has "\\bmix\\w*\\b|\\bcombin\\w*\\b|\\bwhat colou?r\\b|\\bmake\\w*\\b" low
              val light = has "\\blights?\\b|\\brgb\\b|\\badditive\\b|\\bscreen\\b|\\bdigital\\b" low
              val explicitRgb = has "\\brgb\\b|\\bdigital\\b|\\bsaturated\\b" low
              val paint = has "\\bpaint\\w*\\b|\\bryb\\b" low
              val words = List.map (fn m => Regex.whole low m) (findall "[a-z]+" low)
              val framing = ["what","colour","color","does","do","is","the","and","with","of","when","you","get","from","in","if","i",
                "mix","mixes","mixed","mixing","combine","combines","combined","combining","make","makes","produce","produces","give","gives","together",
                "rgb","digital","additive","saturated","full","channel","channels","light","lights","screen"]
              val knownWords = List.all (fn w => List.exists (fn (c,_) => w=c) colourWords orelse List.exists (fn f => w=f) framing) words
              val primaryOnly = List.all (fn c => c="red" orelse c="green" orelse c="blue") cols
            in
              if mixing andalso light then
                if null cols orelse not knownWords orelse paint orelse has "[0-9%]" low
                   orelse (not explicitRgb andalso not primaryOnly)
                then Take (Q.MixRgb [])
                else Take (Q.MixRgb (List.map colourOf cols))
              else if mixing andalso length distinct = 2 andalso has "\\bpaint\\w*\\b|\\bryb\\b|\\bcolou?r\\b" low then
                Take (Q.MixRyb (colourOf (hd distinct), colourOf (List.nth (distinct,1))))
              else Next
            end
          fun complement () =
            case search "\\bcomplement(?:ary)?(?: colou?r)?\\s+(?:of|to|for)\\s+(red|yellow|blue|green|orange|purple|violet)\\b" low of
              SOME m => Take (Q.Complement (colourOf (g1 low m)))
            | NONE => Next
          fun rows () =
            let
              val tokens = ExactNumeric.scan low
              val ns = if List.exists (fn ExactNumeric.Malformed _ => true | _ => false) tokens then []
                       else List.mapPartial (fn ExactNumeric.Number n => SOME n | _ => NONE) tokens
              fun after ({stop,...} : {start:int,stop:int,value:lr}) = String.extract (low, stop, NONE)
              fun unit n = case search ("^\\s*" ^ crUnit) (after n) of
                NONE => NONE | SOME m => SOME (valOf (grp (after n) m 1))
              fun inches u = startsWith "in" u orelse u = "\""
              fun pairs (a::b::rest) = (a,b)::pairs (b::rest) | pairs _ = []
              fun only [x] = SOME x | only _ = NONE
              val explicit = List.mapPartial (fn (a,b) =>
                let val gap = String.substring (low, #stop a, #start b - #stop a)
                in if has "^\\s*rows\\s*(?:per|in|over|=|to)\\s*(?:every\\s*)?$" gap
                   then Option.map (fn u => (#start a, #stop b, #value a, #value b, u)) (unit b)
                   else NONE end) (pairs ns)
              val implicit = List.mapPartial (fn a =>
                case search ("^\\s*rows\\s*(?:per|an|/)\\s*" ^ crUnit) (after a) of
                  NONE => NONE
                | SOME m => SOME (#start a, #stop a, #value a, (1,1), valOf (grp (after a) m 1))) ns
              val gauge = only (explicit @ implicit)
            in
              case gauge of NONE => Next
              | SOME (gstart,gstop,count,span,u) =>
                if has "\\bhow many rows\\b|\\brows (?:do i|should i|to)\\b|\\brow count\\b" low then
                  (case only (List.mapPartial (fn n =>
                     if #start n >= gstart andalso #stop n <= gstop then NONE
                     else Option.map (fn tu => (n,tu)) (unit n)) ns) of
                     NONE => Stop
                   | SOME (n,tu) => Take (Q.Rows (toQ count,toQ span,inches u,toQ (#value n),inches tu)))
                else Next
            end
          fun knit () =
            let
              val g3 = search (M ^ "\\s*(?:stitches|sts|st)\\s*(?:per|in|over|=|to)\\s*(?:every\\s*)?" ^ M ^ "\\s*" ^ crUnit) low
              val g2 = search (M ^ "\\s*(?:stitches|sts)\\s*(?:per|an|/)\\s*(inch|in\\b|cm)") low
              val gm = case g3 of
                         SOME m => SOME (m, lrDiv (lrOf (g1 low m), lrOf (valOf (grp low m 2))), valOf (grp low m 3))
                       | NONE => (case g2 of SOME m => SOME (m, lrOf (g1 low m), valOf (grp low m 2)) | NONE => NONE)
            in
              case gm of
                NONE => Next
              | SOME (m, spu, unit) =>
                  if has "\\bcast on\\b|\\bhow many stitches\\b|\\bstitches (?:do i|should i|to) (?:need|cast)\\b|\\bstitches wide\\b" low then
                    (let val rest = replaceLit (Regex.whole low m) " " low in case search (M ^ "\\s*" ^ crUnit ^ "\\s*(?:wide|width|across|scarf|panel)?") rest of
                       NONE => Stop
                     | SOME wm =>
                         Take (Q.CastOn (toQ spu, startsWith "in" unit orelse unit = "\"", ratOf (g1 rest wm),
                                         startsWith "in" (valOf (grp rest wm 2)) orelse valOf (grp rest wm 2) = "\""))
                     end)
                  else Next
            end
          fun quilt () =
            if has "\\bquilt\\w*\\b|\\bblocks?\\b|\\bsquares?\\b" low andalso has "\\bhow many\\b" low then
              let
                val q = search (M ^ "\\s*" ^ xby ^ "\\s*" ^ M ^ "\\s*(?:inch(?:es)?|in\\b|\\\")\\s*(?:quilt|top|throw|blanket)?") low
                val b = search (M ^ "[- ]?(?:inch|in\\b|\\\")\\s*(?:finished\\s*)?(?:blocks?|squares?)") low
              in
                case (q, b) of
                  (SOME q, SOME b) =>
                    if lrIsZero (lrOf (g1 low b)) then Stop
                    else Take (Q.Quilt (ratOf (g1 low q), ratOf (valOf (grp low q 2)), ratOf (g1 low b)))
                | _ => Next
              end
            else Next
          fun cut () =
            if has "\\bcut\\b" low andalso has "\\bfinished\\b" low andalso has "\\bseam allowance\\b|\\bquilt\\w*\\b|\\bblock\\b|\\bsquare\\b" low then
              case search (M ^ "[- ]?(?:inch|in\\b|\\\")\\s*finished|\\bfinished (?:size|block|square)?\\s*(?:of|is)?\\s*" ^ M) low of
                SOME f => Take (Q.CutSize (ratOf (valOf (firstGroup low f [1, 2]))))
              | NONE => Next
            else Next
          fun yards () =
            if has "\\byards?\\b" low andalso
               has "\\bhow many\\b|\\bconvert\\b|\\bin yards\\b" low andalso
               has "\\b(?:fabric|cloth|ribbon|yarn|material)\\b" low
            then Take (fabricYardsExact text) else Next
          fun mat () =
            if has "\\bmat\\b|\\bframe\\b" low andalso has "\\bborder\\b" low then
              let
                val a = search (M ^ "\\s*" ^ xby ^ "\\s*" ^ M ^ "\\s*(?:inch(?:es)?|in\\b|\\\"|cm)?\\s*(?:print|photo|art\\w*|picture|painting)?") low
                val bm = search (M ^ "[- ]?(?:inch|in\\b|\\\"|cm)\\s*(?:wide\\s*)?border|\\bborder(?:s)?\\s*(?:of|is)?\\s*" ^ M) low
              in
                case (a, bm) of
                  (SOME a, SOME b) => Take (Q.Mat (ratOf (g1 low a), ratOf (valOf (grp low a 2)), ratOf (valOf (firstGroup low b [1, 2]))))
                | _ => Next
              end
            else Next
          fun clay () =
            case search "(\\d+(?:\\.\\d+)?)\\s*%\\s*shrink\\w*|\\bshrink\\w*\\s*(?:of|is|by)?\\s*(\\d+(?:\\.\\d+)?)\\s*%" low of
              SOME cs =>
                if has "\\bclay\\b|\\bfir(?:e|ed|ing)\\b|\\bkiln\\b|\\bceramic\\w*\\b" low then
                  (case search (M ^ "\\s*(inch(?:es)?|in\\b|\\\"|cm|mm)\\b") low of
                     NONE => Stop
                   | SOME sz =>
                       let val u = valOf (grp low sz 2)
                           val cu = if u = "\"" then Q.CU_quote else if u = "cm" then Q.CU_cm else if u = "mm" then Q.CU_mm else Q.CU_in
                       in Take (Q.Clay (ratOf (valOf (firstGroup low cs [1, 2])), ratOf (g1 low sz), cu)) end)
                else Next
            | NONE => Next
        in
          case run [colour, complement, rows, knit, quilt, cut, yards, mat, clay] of
            SOME r => (case r of Q.Rows _ => SOME r | Q.MixRgb _ => SOME r | Q.Yards _ => SOME r | Q.YardsUnread => SOME r | _ => if answered r then SOME r else NONE)
          | NONE => NONE
        end
    end

  (* ---------- dispatch ---------- *)
  val organs = ["architecture", "printing", "printing-v2", "safety", "woodworking", "crafts"]

  fun byId "architecture" = architecture
    | byId "printing" = printingV1
    | byId "printing-v2" = printingV2
    | byId "safety" = safety
    | byId "woodworking" = woodworking
    | byId "crafts" = crafts
    | byId other = raise Fail ("unknown specialist " ^ other)

  (* The family: each manifest's organ in a fixed order, the first that takes the question answers it. *)
  val familyOrder = ["safety", "architecture", "printing-v2", "woodworking", "crafts"]

  fun recognize mode text =
    if mode = "family" then
      let fun go [] = NONE
            | go (id :: ids) = case byId id text of SOME r => SOME (id, r) | NONE => go ids
      in go familyOrder end
    else Option.map (fn r => (mode, r)) (byId mode text)
end
