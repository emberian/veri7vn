(* UNTRUSTED. The English recognizer for the geometry and statistics
   specialists: a hand port of the regular expressions and branch order of
     upstream/root/specialists/geometry*/organ_geometry_v{1,2,3,4}.py
     upstream/root/specialists/statistics*/organ_stats_v{1,2,3}.py
   and of their shared narrowing rule narrow_v1.py. It reads numbers and words
   off the question and builds a typed GeoStats.grequest / srequest; it
   computes nothing. Every value, decline and response text comes from the
   verified HOL kernel (GeoStats.g_reply, GeoStats.s_reply). NONE means the
   question is not taken (the organ returns None).

   Matching is case-insensitive by lower-casing the TEXT (the patterns below
   are written in lower case, as the organs' patterns are used with re.I or on
   lower-cased text); patterns are compiled as written. \w and \d are ASCII.

   Layering follows the organs' class hierarchy: v1 is the base; geometry v2
   (not a manifest of its own) narrows v1; geometry v3 adds two reading
   classes; geometry v4 adds imperative verbs; statistics v2 rewrites the
   counting and binomial readers and adds the exact-fraction note; statistics
   v3 reads "of the data set" as "of". *)
structure Recognizer :
sig
  val organs : string list
  val recognize : string -> string -> (string * GeoStats.reply) option
end =
struct
  structure G = GeoStats

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

  (* replace every match of p in s by (f match) *)
  fun replaceFn p f s =
    let
      fun go i [] acc = String.concat (rev (String.extract (s, i, NONE) :: acc))
        | go i ((m as {start, stop, ...} : Regex.match) :: ms) acc =
            go stop ms (f m :: String.substring (s, i, start - i) :: acc)
    in go 0 (findall p s) [] end
  fun replaceAll p rep s = replaceFn p (fn _ => rep) s

  (* ---------- exact decimals: numerator / denominator ---------- *)
  type dec = IntInf.int * IntInf.int
  fun parseDec (lit : string) : dec =
    let
      val (neg, body) = if String.isPrefix "-" lit then (true, String.extract (lit, 1, NONE)) else (false, lit)
      val (ip, fp) = case String.fields (fn c => c = #".") body of
                       [a] => (a, "")
                     | [a, b] => (a, b)
                     | _ => raise Fail ("bad numeral " ^ lit)
      val num = valOf (IntInf.fromString (ip ^ fp))
    in (if neg then IntInf.~ num else num, IntInf.pow (10, size fp)) end
  fun toRat ((a, b) : dec) = G.mk_rat a b
  fun decEq ((a, b) : dec, (c, d) : dec) = a * d = c * b
  fun decGe ((a, b) : dec, (c, d) : dec) = a * d >= c * b
  fun decHalf ((a, b) : dec) : dec = (a, b * 2)
  fun decIsZero ((a, _) : dec) = a = 0
  fun natOf (digits : string) = G.mk_nat (valOf (IntInf.fromString digits))
  fun intOf (digits : string) = valOf (IntInf.fromString digits)

  (* ---------- narrow_v1 ---------- *)
  structure Narrow =
  struct
    fun strip s = collapse s
    fun words t = length (String.tokens Char.isSpace t)
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
    val RELATION = "\\b(?:\\d+(?:\\.\\d+)?|one|two|three|four|five|six|seven|eight|nine|ten)\\s+(?:\\w+\\s+){0,2}"
      ^ "(?:more|less|fewer|longer|shorter)\\s+than\\b|\\b(?:twice|three times|half)\\s+(?:as\\s+\\w+\\s+as\\s+)?the\\s+\\w+\\b"
    val RATE = "\\b\\d+(?:\\.\\d+)?\\s+[a-z]+\\s+(?:for|per|every)\\s+(?:\\d+(?:\\.\\d+)?|a|an|one|each)\\s+[a-z]+"
    val NUM = "(?<![\\w.])\\d+(?:\\.\\d+)?(?!\\w|\\.\\d)"
    fun numbers t = length (findall NUM t)
    fun narrative t =
      let val low = lower t
      in sentences t >= 3 orelse words t > 40 orelse has RELATION low orelse has RATE low end
    fun short_direct t = sentences t <= 2 andalso words t <= 25 andalso not (narrative t)
  end

  val N = "(-?\\d+(?:\\.\\d+)?)"

  (* =================== geometry =================== *)
  structure Geo =
  struct
    exception BadGeometry
    val N = "([+\\-\226\136\146]?(?:\\d+(?:,\\d{3})*(?:\\.\\d+)?|\\.\\d+)(?:e[+-]?\\d+)?(?:\\s*/\\s*[+\\-\226\136\146]?(?:\\d+(?:,\\d{3})*(?:\\.\\d+)?|\\.\\d+)(?:e[+-]?\\d+)?)?)"
    fun parseDec lit = case ExactNumeric.parse lit of SOME q => q | NONE => raise BadGeometry
    (* Scalar roles bind whole issued spans, never a suffix of an exponent,
       negative quantity, identifier or malformed numeral. *)
    fun grp text (m as {groups,...}: Regex.match) g =
      case Regex.group text m g of
        NONE => NONE
      | SOME lit =>
          if size lit > 0 andalso (Char.isDigit (String.sub(lit,0)) orelse
               Char.contains "+-." (String.sub(lit,0)) orelse String.isPrefix "\226\136\146" lit)
          then if List.exists (fn ExactNumeric.Number {start,stop,...} =>
                    Vector.sub(groups,g) = SOME(start,stop) | _ => false) (ExactNumeric.scan text)
               then SOME lit else raise BadGeometry
          else SOME lit
    fun g1 text m = valOf (grp text m 1)
    val unitRx = "(?:millimet(?:er|re)s?|centimet(?:er|re)s?|kilomet(?:er|re)s?|met(?:er|re)s?|inches|inch|feet|foot|yards?|mm|cm|km|ft|yd|in|m)"
    fun unitOf w =
      if has "^(?:mm|millimet)" w then G.LU_mm
      else if has "^(?:cm|centimet)" w then G.LU_cm
      else if has "^(?:km|kilomet)" w then G.LU_km
      else if has "^(?:in|inch)" w then G.LU_in
      else if has "^(?:ft|feet|foot)" w then G.LU_ft
      else if has "^(?:yd|yard)" w then G.LU_yd else G.LU_m
    fun suffix text stop = String.extract(text,stop,NONE)
    fun unitSpec alias tag dimension sensitive : MeasuredInput.unitSpec =
      {alias=alias,tag=tag,dimension=dimension,caseSensitive=sensitive}
    val lengthUnits = List.concat(map(fn(tag,names)=>
      map(fn name=>unitSpec name tag "length" (size name<=2)) names)
      [("mm",["mm","millimeter","millimeters","millimetre","millimetres"]),
       ("cm",["cm","centimeter","centimeters","centimetre","centimetres"]),
       ("m",["m","meter","meters","metre","metres"]),
       ("km",["km","kilometer","kilometers","kilometre","kilometres"]),
       ("in",["in","inch","inches"]),("ft",["ft","foot","feet"]),("yd",["yd","yard","yards"])])
    val outputUnits = lengthUnits @ List.concat(map(fn({alias,tag,caseSensitive,...}:MeasuredInput.unitSpec)=>
      map(fn a=>unitSpec a tag "area" caseSensitive)["square "^alias,alias^"2",alias^"^2",alias^"\194\178"] @
      map(fn a=>unitSpec a tag "volume" caseSensitive)["cubic "^alias,alias^"3",alias^"^3",alias^"\194\179"]) lengthUnits)
    fun cleanUnitTail text stop =
      let val rest=lower(suffix text stop)
      in case search "^\\s*([a-z]+)" rest of NONE=>not(has "^\\s*[0-9]" rest)
       | SOME m=>List.exists(fn w=>w=valOf(Regex.group rest m 1))
          ["by","x","and","or","long","wide","high","tall","thick","radius","diameter","height","width",
           "length","base","edge","side","leg","hypotenuse","is","with","has","what","find","compute",
           "calculate","determine","the","a","of","rectangle","rectangular","box","cuboid","square",
           "triangle","circle","sphere","cylinder","cone","cube","polygon","legs"]
      end
    fun attachedUnit text stop =
      case MeasuredInput.unitAt lengthUnits text stop of
        SOME(MeasuredInput.Explicit{unit={tag,...},span={stop=last,...}})=>
          if cleanUnitTail text last then SOME(unitOf tag,last) else raise BadGeometry
      | SOME(MeasuredInput.Unsupported _)=>raise BadGeometry
      | _=>NONE
    fun prepare text =
      let val original = collapse text
          val lowOriginal = lower original
          val outputRx = "\\b(?:in|into)\\s+((?:square\\s+|cubic\\s+)?(" ^ unitRx ^ ")(?:[23]|\\^[23]|\194\178|\194\179)?)(?![a-z0-9])"
          val outputs = findall outputRx lowOriginal
          val _ = if length outputs>1 then raise BadGeometry else ()
          val explicitOutput = case outputs of []=>NONE | m::_=>SOME m
          val requested = case explicitOutput of NONE=>NONE | SOME(m:Regex.match)=>
            (case Vector.sub(#groups m,1) of NONE=>raise BadGeometry | SOME(a,b)=>
              (case MeasuredInput.requested outputUnits original {start=a,stop=b} of
                 SOME(MeasuredInput.RequestedOutput{unit={tag,dimension,...},span={stop,...}})=>
                   if cleanUnitTail original stop then SOME(unitOf tag,dimension) else raise BadGeometry
               | _=>raise BadGeometry))
          (* Output fields never supply an inherited input unit. *)
          val t = case explicitOutput of NONE=>original | SOME({start,stop,...}:Regex.match)=>
            String.substring(original,0,start)^String.extract(original,stop,NONE)
          fun countRole stop = has "^\\s*-?\\s*sided\\b" (lower(suffix t stop))
          val ts = ExactNumeric.scan t
          val _ = if List.exists (fn ExactNumeric.Malformed _ => true | _ => false) ts
                  then raise BadGeometry else ()
          val inputUnits = List.mapPartial (fn ExactNumeric.Number {stop,...} => Option.map #1 (attachedUnit t stop) | _ => NONE) ts
          val mixed = case inputUnits of [] => false | u::us => List.exists (fn v => v<>u) us
          val hasBare = List.exists (fn ExactNumeric.Number {stop,...} => not(countRole stop) andalso not(isSome(attachedUnit t stop)) | _ => false) ts
          val _ = if mixed andalso hasBare then raise BadGeometry else ()
          val firstUnit = List.find (fn ExactNumeric.Number {stop,...} => isSome(attachedUnit t stop) | _ => false) ts
          val outputPhrase = search "\\b(?:in|into)\\s+([a-z]+(?:\\s+[a-z]+)?)(?:[23]|\\^[23]|\194\178|\194\179)?(?:[?.]|$)" lowOriginal
          val _ = if isSome outputPhrase andalso not(isSome explicitOutput) then raise BadGeometry else ()
          val operationPower = if has "\\b(?:interior )?angles?\\b" (lower t) then "angle"
              else if has "\\bvolume\\b" (lower t) then "volume"
              else if has "\\barea\\b" (lower t) then "area" else "length"
          val _ = case requested of SOME(_,dimension)=>if dimension=operationPower then () else raise BadGeometry | NONE=>()
          val target = case requested of SOME(unit,_)=>SOME unit
            | NONE => (case firstUnit of SOME(ExactNumeric.Number {stop,...}) =>
                          Option.map #1 (attachedUnit t stop) | _ => NONE)
          fun replacement (ExactNumeric.Number {start,stop,value}) =
                if countRole stop then (start,stop,String.substring(t,start,stop-start))
                else (case attachedUnit t stop of
                   SOME (source,last) =>
                     let val rest = suffix t last
                         val _ = if has "^(?:[23]|\\^[23]|\194\178|\194\179)" rest then raise BadGeometry else ()
                         val q = G.converted_parts source (valOf target) (toRat value)
                     in (start,last,ExactNumeric.canonical q) end
                 | NONE =>
                     let val tail = lower(suffix t stop)
                         val _ = if has "^\\s*(?:['\"]|\194\181|\206\188|\194\176)" tail then raise BadGeometry else ()
                         val _ = case search "^\\s*([a-z]+)" tail of
                           NONE => ()
                         | SOME m =>
                             let val w = valOf(Regex.group tail m 1)
                             in if List.exists (fn x => x=w)
                               ["by","x","and","or","sides","sided","units","unit","long","wide","high","tall",
                                "radius","diameter","height","width","length","base","edge","side","leg","hypotenuse",
                                "is","with","has","what","find","compute","calculate","determine","the","a","of",
                                "rectangle","rectangular","box","cuboid","square","triangle","circle","sphere","cylinder","cone","cube","polygon","legs"]
                               then () else raise BadGeometry end
                     in (start,stop,
                         case (inputUnits,target) of
                           (source::_,SOME dest) =>
                             if has "\\b(?:interior )?angles?\\b" (lower t)
                             then String.substring(t,start,stop-start)
                             else ExactNumeric.canonical (G.converted_parts source dest (toRat value))
                         | _ => String.substring(t,start,stop-start)) end)
            | replacement _ = raise BadGeometry
          fun rewrite pos [] acc = String.concat(rev(String.extract(t,pos,NONE)::acc))
            | rewrite pos ((a,b,v)::rest) acc = rewrite b rest (v::String.substring(t,pos,a-pos)::acc)
      in (rewrite 0 (map replacement ts) [],target) end

    fun valD low word : dec option =
      let val role = if word="side" orelse word="edge" orelse word="base" then word ^ "(?:\\s+length)?" else word
      in case search ("\\b" ^ role ^ "\\s*(?:of|=|is|:)?\\s*" ^ N) low of
        SOME m => SOME (parseDec (g1 low m))
      | NONE =>
          (case search (N ^ "\\s*(?:cm|m|mm|in|ft|units?)?\\s*" ^ role ^ "\\b") low of
             SOME m => SOME (parseDec (g1 low m))
           | NONE => NONE)
      end

    fun some d = SOME (toRat d)

    (* organ_geometry_v1.GeometryOrgan.answer on the collapsed, lower-cased text *)
    fun v1 (low : string) : G.grequest option =
      let
        val want =
          if has "\\bsurface area\\b" low then SOME "surface"
          else if has "volume" low then SOME "volume"
          else if has "\\barea\\b" low then SOME "area"
          else if has "\\bperimeter\\b" low then SOME "perimeter"
          else if has "circumference" low then SOME "circumference"
          else NONE
        fun first [] = NONE
          | first (f :: fs) = (case f () of SOME x => SOME x | NONE => first fs)

        fun pythagoras () =
          if has "\\bhypotenuse\\b|\\bright triangle\\b|\\bright-angled\\b" low andalso want = NONE then
            let
              val nums = map (fn m => parseDec (g1 low m)) (findall N low)
              val hyp = valD low "hypotenuse"
              val asked = has ("\\b(?:find|what is|how long is) the hypotenuse\\b|\\bhypotenuse\\?|"
                               ^ "\\blength of the hypotenuse\\b") low
            in
              if asked andalso length nums >= 2 then
                SOME (G.G_hypotenuse (toRat (List.nth (nums, 0)), toRat (List.nth (nums, 1))))
              else
                case hyp of
                  SOME h =>
                    if length nums >= 2 then
                      (case List.find (fn x => not (decEq (x, h))) nums of
                         NONE => SOME (G.G_leg (toRat h, NONE))
                       | SOME other => SOME (G.G_leg (toRat h, some other)))
                    else NONE
                | NONE => NONE
            end
          else NONE

        fun angles () =
          let
            val rx = "\\b(?:sum of (?:the )?(?:interior )?angles|interior angles? (?:sum|add up))\\b.*?\\b(\\d+)[- ]sided\\b"
              ^ "|\\b(\\d+)[- ]sided polygon\\b.*\\bangles?\\b"
              ^ "|\\binterior angles?\\b.*\\b(pentagon|hexagon|heptagon|octagon|nonagon|decagon|triangle|quadrilateral)\\b"
          in
            case search rx low of
              NONE => NONE
            | SOME m =>
                let
                  val n =
                    case (grp low m 1, grp low m 2, grp low m 3) of
                      (SOME d, _, _) => natOf d
                    | (NONE, SOME d, _) => natOf d
                    | (NONE, NONE, SOME w) =>
                        G.mk_nat (case w of "triangle" => 3 | "quadrilateral" => 4 | "pentagon" => 5
                                   | "hexagon" => 6 | "heptagon" => 7 | "octagon" => 8 | "nonagon" => 9
                                   | _ => 10)
                    | _ => raise Fail "angles"
                in SOME (G.G_angle_sum n) end
          end

        val r0 = valD low "radius"
        val dm = valD low "diameter"
        val r = case (r0, dm) of (NONE, SOME d) => SOME (decHalf d) | _ => r0
        val h = ref (valD low "height")
        val side = valD low "side"
        fun isWant w = want = SOME w

        fun circle () =
          if not (has "circle" low) then NONE
          else case r of
            NONE => SOME (G.G_circle_area NONE)
          | SOME rr =>
              if isWant "area" then SOME (G.G_circle_area (some rr))
              else if isWant "circumference" orelse isWant "perimeter" then SOME (G.G_circumference (some rr))
              else NONE
        fun sphere () =
          if not (has "sphere" low) then NONE
          else case r of
            NONE => SOME (G.G_sphere_volume NONE)
          | SOME rr =>
              if isWant "volume" then SOME (G.G_sphere_volume (some rr))
              else if isWant "surface" then SOME (G.G_sphere_surface (some rr))
              else NONE
        fun cylinder () =
          if not (has "cylinder" low) then NONE
          else case (r, !h) of
            (SOME rr, SOME hh) =>
              if isWant "volume" then SOME (G.G_cylinder_volume (some rr, some hh))
              else if isWant "surface" then SOME (G.G_cylinder_surface (some rr, some hh))
              else NONE
          | _ => SOME (G.G_cylinder_volume (NONE, NONE))
        fun cone () =
          if not (has "cone" low) then NONE
          else case (r, !h) of
            (SOME rr, SOME hh) => if isWant "volume" then SOME (G.G_cone_volume (some rr, some hh)) else NONE
          | _ => SOME (G.G_cone_volume (NONE, NONE))
        fun cube () =
          if not (has "cube" low) then NONE
          else
            let
              val s = case side of
                        SOME x => if decIsZero x then valD low "edge" else SOME x
                      | NONE => valD low "edge"
            in
              case s of
                NONE => SOME (G.G_cube_volume NONE)
              | SOME ss =>
                  if isWant "volume" then SOME (G.G_cube_volume (some ss))
                  else if isWant "surface" then SOME (G.G_cube_surface (some ss))
                  else NONE
            end
        fun rect () =
          if not (has "\\b(?:rectangle|rectangular|box|cuboid)\\b" low) then NONE
          else
            let
              val l0 = valD low "length"
              val w0 = valD low "width"
              val by = "(?:by|x|\195\151)"
              val (l, w) =
                case search (N ^ "\\s*" ^ by ^ "\\s*" ^ N ^ "(?:\\s*" ^ by ^ "\\s*" ^ N ^ ")?") low of
                  SOME m =>
                    ((case grp low m 3 of SOME d => h := SOME (parseDec d) | NONE => ());
                     (SOME (parseDec (g1 low m)), SOME (parseDec (valOf (grp low m 2)))))
                | NONE => (l0, w0)
            in
              case (l, w) of
                (SOME ll, SOME ww) =>
                  if isWant "volume" then
                    (case !h of
                       NONE => SOME (G.G_box_volume (some ll, some ww, NONE))
                     | SOME hh => SOME (G.G_box_volume (some ll, some ww, some hh)))
                  else if isWant "area" then SOME (G.G_rect_area (some ll, some ww))
                  else if isWant "perimeter" then SOME (G.G_rect_perimeter (some ll, some ww))
                  else NONE
              | _ => SOME (G.G_rect_area (NONE, NONE))
            end
        fun square () =
          if has "square" low then
            (case side of
               SOME s =>
                 if isWant "area" then SOME (G.G_square_area (toRat s))
                 else if isWant "perimeter" then SOME (G.G_square_perimeter (toRat s))
                 else NONE
             | NONE => NONE)
          else NONE
        fun triangle () =
          if has "triangle" low andalso isWant "area" then
            let val b = valD low "base" in
              case (b, !h) of
                (SOME bb, SOME hh) => SOME (G.G_tri_area (some bb, some hh))
              | _ =>
                  (case search ("\\bsides?\\s*(?:of\\s*)?" ^ N ^ "\\s*,\\s*" ^ N ^ "\\s*,?\\s*and\\s*" ^ N) low of
                     SOME m =>
                       SOME (G.G_heron (toRat (parseDec (g1 low m)), toRat (parseDec (valOf (grp low m 2))),
                                        toRat (parseDec (valOf (grp low m 3)))))
                   | NONE => SOME (G.G_tri_area (NONE, NONE)))
            end
          else NONE
      in
        case first [pythagoras, angles] of
          SOME x => SOME x
        | NONE =>
            if want = NONE then NONE
            else first [circle, sphere, cylinder, cone, cube, rect, square, triangle]
      end

    fun answered req = G.answered (G.g_reply req)
    fun isNeed req = G.reply_kind (G.g_reply req) = "underspecified"

    (* organ_geometry_v2: v1 narrowed (narrow_v1) *)
    fun v2 (text : string) : G.grequest option =
      if Narrow.narrative text then NONE
      else
        case v1 (lower (collapse text)) of
          NONE => NONE
        | SOME req =>
            if not (answered req) andalso not (Narrow.short_direct text) then NONE
            else if isNeed req andalso Narrow.numbers text >= 2 then NONE
            else SOME req

    (* organ_geometry_v3 *)
    val SIDES = "\\bsides\\s+(?:are|measure|measuring|of lengths?|with lengths?|that measure|equal to)\\s+"
    val HYP = "\\bhypotenuse\\b[^.,;?\\d]*?\\b(?:is|measures?|equals?|of length)\\s+(\\d+(?:\\.\\d+)?)"
    fun v3 (text : string) : G.grequest option =
      let
        val t = replaceAll SIDES "sides " (lower text)
      in
        case v2 t of
          SOME r => SOME r
        | NONE =>
            (case search HYP t of
               NONE => NONE
             | SOME hm =>
                 let val ns = map (Regex.whole t) (findall Narrow.NUM t) in
                   if length ns = 2 andalso has "\\bleg\\b" t
                      andalso has "\\bother leg\\b|\\bmissing leg\\b|\\bsecond leg\\b" t
                   then
                     let val h = g1 t hm
                         val a = if List.nth (ns, 0) = h then List.nth (ns, 1) else List.nth (ns, 0)
                     in v2 ("a right triangle has a hypotenuse of " ^ h ^ " and a leg of " ^ a
                            ^ ". what is the other leg?") end
                   else NONE
                 end)
      end

    (* organ_geometry_v4 *)
    val IMPERATIVE = "\\b(?:compute|calculate|determine|give|work out|get)\\s+(?=the (?:length of the )?hypotenuse\\b)"
    fun v4 (text : string) : G.grequest option = v3 (replaceAll IMPERATIVE "find " (lower text))

    fun reply f text =
      if not(has "\\b(?:circle|sphere|cylinder|cone|cube|rectangle|rectangular|box|cuboid|square|triangle|hypotenuse|polygon|sided|pentagon|hexagon|heptagon|octagon|nonagon|decagon|quadrilateral)\\b" (lower text))
      then NONE
      else ((let val (t,u) = prepare text
             in Option.map (fn req => case u of NONE => G.g_reply req
                               | SOME unit => G.geometry_unit_reply unit req) (f t) end)
            handle BadGeometry => SOME G.units_refusal)
    fun byId "geometry" text = reply v4 text
      | byId "geometry-v3" text = reply v4 text
      | byId "geometry-v4" text = reply v4 text
      | byId _ _ = NONE
  end

  (* =================== statistics =================== *)
  structure Stat =
  struct
    structure S = GeoStats
    val NUMS = "-?\\d+(?:\\.\\d+)?"

    (* organ_stats_v1.nums_after *)
    fun numsAfter (t : string) : dec list option =
      case search ("(?:of|for|in|data(?:set)?|numbers|values|list)[:\\s]+"
                   ^ "((?:-?\\d+(?:\\.\\d+)?[,\\s]+(?:and\\s+)?)+-?\\d+(?:\\.\\d+)?)") t of
        NONE => NONE
      | SOME m =>
          let val body = g1 t m in SOME (map (fn mm => parseDec (Regex.whole body mm)) (findall NUMS body)) end

    fun rats ds = map toRat ds

    fun pairOf low m = (valOf (grp low m 1), valOf (grp low m 2))

    (* "p" of the binomial readers: a decimal or a percentage, as an exact fraction *)
    fun probOf (ps : string) : S.rat =
      if String.isSuffix "%" ps
      then let val (a, b) = parseDec (String.substring (ps, 0, size ps - 1)) in G.mk_rat a (b * 100) end
      else toRat (parseDec ps)

    (* organ_stats_v1.StatsOrgan.answer on the collapsed, lower-cased text *)
    fun v1 (low : string) : S.srequest option =
      let
        fun first [] = NONE
          | first (f :: fs) = (case f () of SOME x => SOME x | NONE => first fs)

        fun comb () =
          let
            val rx = "\\b(?:how many (?:ways|combinations)|combinations?|choose)\\b.*?(\\d+)\\D+(\\d+)"
              ^ "|\\b(\\d+)\\s*c\\s*(\\d+)\\b|\\b(\\d+)\\s+choose\\s+(\\d+)\\b"
          in
            case search rx low of
              NONE => NONE
            | SOME m =>
                if has "\\bchoose\\b|\\bcombination|\\bways to (?:choose|pick|select)\\b|\\d\\s*c\\s*\\d" low
                   andalso not (has "permutation" low) andalso not (has "arrange" low)
                then
                  let
                    val gs = List.mapPartial (grp low m) [1, 2, 3, 4, 5, 6]
                    val a = intOf (List.nth (gs, 0))
                    val b = intOf (List.nth (gs, 1))
                    val (n, k) = if a >= b then (a, b) else (b, a)
                  in SOME (S.S_choose (G.mk_nat n, G.mk_nat k, false)) end
                else NONE
          end
        fun perm () =
          case search "\\b(?:permutations?|arrangements?|ways to arrange|orderings?)\\b.*?(\\d+)(?:\\D+(\\d+))?" low of
            NONE => NONE
          | SOME m =>
              if has "\\bpermutation|\\barrange" low then
                let
                  val n0 = intOf (g1 low m)
                in
                  case grp low m 2 of
                    NONE => SOME (S.S_arrange (G.mk_nat n0, NONE, false))
                  | SOME ks =>
                      let val k0 = intOf ks
                          val (n, k) = if k0 > n0 then (k0, n0) else (n0, k0)
                      in SOME (S.S_arrange (G.mk_nat n, SOME (G.mk_nat k), false)) end
                end
              else NONE
        fun binom () =
          case search ("\\bprobability\\b.*?\\bexactly (\\d+)\\b.*?\\b(\\d+) (?:trials|flips|tosses|rolls|attempts|times)\\b"
                       ^ ".*?\\b(?:p|probability of success|chance)\\s*(?:=|of|is)?\\s*(0?\\.\\d+|\\d+(?:\\.\\d+)?%)") low of
            NONE => NONE
          | SOME m =>
              SOME (S.S_binom (natOf (g1 low m), natOf (valOf (grp low m 2)), probOf (valOf (grp low m 3)), false))
        fun zscore () =
          case search ("\\bz[- ]?score\\b.*?(-?\\d+(?:\\.\\d+)?)\\D+?(?:mean|average|\206\188)\\D*?(-?\\d+(?:\\.\\d+)?)"
                       ^ "\\D+?(?:standard deviation|sd|std|\207\131)\\D*?(\\d+(?:\\.\\d+)?)") low of
            NONE => NONE
          | SOME m =>
              SOME (S.S_z (toRat (parseDec (g1 low m)), toRat (parseDec (valOf (grp low m 2))),
                           toRat (parseDec (valOf (grp low m 3)))))
        fun dataQ () =
          case numsAfter low of
            NONE => NONE
          | SOME ds =>
              let
                val data = rats ds
                val which =
                  List.find (fn (_, rx) => has rx low)
                    [("stdev", "\\bstandard deviation\\b|\\bstd\\.? ?dev\\b|\\bsd\\b"), ("variance", "\\bvariance\\b"),
                     ("median", "\\bmedian\\b"), ("mode", "\\bmode\\b"), ("range", "\\brange\\b"),
                     ("mean", "\\bmean\\b|\\baverage\\b")]
                val pop = has "\\bpopulation\\b" low
              in
                case which of
                  NONE => NONE
                | SOME ("mean", _) => SOME (S.S_mean (data, false))
                | SOME ("median", _) => SOME (S.S_median (data, false))
                | SOME ("mode", _) => SOME (S.S_mode data)
                | SOME ("range", _) => SOME (S.S_range data)
                | SOME ("stdev", _) => SOME (S.S_stdev (pop, data))
                | SOME (_, _) => SOME (S.S_variance (pop, data))
              end
      in first [comb, perm, binom, zscore, dataQ] end

    (* organ_stats_v2 *)
    val D = "(\\d+)"
    val P = "(\\d*\\.\\d+|\\d+(?:\\.\\d+)?\\s*%|0|1)"

    (* (rx, order): "nk" = first group is n, "kn" = first group is k *)
    fun knFrom low (rxs : (string * string) list) : (IntInf.int * IntInf.int) option =
      case rxs of
        [] => NONE
      | (rx, order) :: rest =>
          (case search rx low of
             SOME m =>
               let val a = intOf (g1 low m) val b = intOf (valOf (grp low m 2))
               in SOME (if order = "nk" then (b, a) else (a, b)) end
           | NONE => knFrom low rest)

    fun knChoose low =
      knFrom low
        [("\\b" ^ D ^ "\\s+choose\\s+" ^ D ^ "\\b", "nk"), ("\\b" ^ D ^ "\\s*c\\s*" ^ D ^ "\\b", "nk"),
         ("\\bc\\(\\s*" ^ D ^ "\\s*,\\s*" ^ D ^ "\\s*\\)", "nk"),
         ("\\bchoose\\s+" ^ D ^ "\\b(?:\\s+\\w+)?\\s+(?:from|out of|of|among)\\s+(?:a (?:group|set) of\\s+)?" ^ D ^ "\\b", "kn"),
         ("\\b(?:pick|select)\\s+" ^ D ^ "\\b(?:\\s+\\w+)?\\s+(?:from|out of|of|among)\\s+" ^ D ^ "\\b", "kn"),
         ("\\bcombinations of\\s+" ^ D ^ "\\s+(?:\\w+\\s+)?(?:taken|chosen)\\s+" ^ D ^ "\\b", "nk"),
         ("\\bcombinations of\\s+" ^ D ^ "\\s+(?:from|out of)\\s+" ^ D ^ "\\b", "kn")]

    (* SOME (k option, n) or NONE when the order cannot be read *)
    fun knPerm low : (IntInf.int option * IntInf.int) option =
      case knFrom low
             [("\\bp\\(\\s*" ^ D ^ "\\s*,\\s*" ^ D ^ "\\s*\\)", "nk"),
              ("\\bpermutations? of\\s+" ^ D ^ "\\s+(?:\\w+\\s+)?taken\\s+" ^ D ^ "\\b", "nk"),
              ("\\b" ^ D ^ "\\s+(?:\\w+\\s+)?(?:from|out of|of)\\s+" ^ D ^ "\\b", "kn")] of
        SOME (k, n) => SOME (SOME k, n)
      | NONE =>
          (case search ("\\b(?:permutations of|ways to arrange|arrangements of|arrange)\\s+" ^ D ^ "\\b") low of
             SOME m => SOME (NONE, intOf (g1 low m))
           | NONE => NONE)

    fun v2 (low : string) : S.srequest option =
      let
        val isPerm = has "\\bpermutation|\\barrange|\\bordered\\b|\\bp\\(\\d" low
        val isComb = has ("\\bchoose\\b|\\bcombination|\\bways to (?:choose|pick|select)\\b|\\b\\d+\\s*c\\s*\\d+\\b|\\bc\\(\\d") low
                     andalso not isPerm
      in
        if isComb orelse isPerm then
          (if isPerm then
             (case knPerm low of
                NONE => NONE
              | SOME (k, n) => SOME (S.S_arrange (G.mk_nat n, Option.map G.mk_nat k, true)))
           else
             (case knChoose low of
                NONE => NONE
              | SOME (k, n) => SOME (S.S_choose (G.mk_nat n, G.mk_nat k, true))))
        else
          let
            val binom =
              if has "\\bprobability\\b|\\bchance\\b" low andalso has "\\bexactly\\b" low
                 andalso has "\\btrials?\\b|\\bflips?\\b|\\btosses\\b|\\brolls?\\b|\\battempts?\\b|\\bshots?\\b" low
              then
                let
                  val km = search ("\\bexactly\\s+" ^ D ^ "\\b") low
                  val nm = search (D ^ "\\s+(?:independent\\s+)?(?:trials?|flips?|tosses|rolls?|attempts?|shots?)\\b") low
                  val pm =
                    List.foldl (fn (rx, acc) => case acc of SOME _ => acc | NONE => search rx low) NONE
                      ["\\bp\\s*=\\s*" ^ P,
                       "\\b(?:probability|chance) of (?:a )?success(?: on each trial)?\\s*(?:is|of|=)?\\s*" ^ P,
                       "\\bsuccess (?:probability|chance|rate)\\s*(?:is|of|=)?\\s*" ^ P,
                       "\\bwith (?:a )?(?:probability|chance)\\s*(?:of)?\\s*" ^ P]
                in
                  case (km, nm, pm) of
                    (SOME k, SOME n, SOME p) =>
                      let val ps = String.translate (fn #" " => "" | c => String.str c) (g1 low p)
                      in SOME (S.S_binom (natOf (g1 low k), natOf (g1 low n), probOf ps, true)) end
                  | _ => NONE
                end
              else NONE
          in
            case binom of
              SOME r => SOME r
            | NONE =>
                (case v1 low of
                   SOME (S.S_mean (xs, _)) => SOME (S.S_mean (xs, true))
                 | SOME (S.S_median (xs, _)) => SOME (S.S_median (xs, true))
                 | other => other)
          end
      end

    (* organ_stats_v3 *)
    val DATASET = "\\b(of|for|in)\\s+(?:(?:the|these|this|those)\\s+)?(?:data ?set|data|numbers|values|list|sample|observations|scores)\\b[:\\s]*"
    fun v3 (low : string) : S.srequest option =
      v2 (replaceFn DATASET (fn m => (g1 low m) ^ " ") low)

    fun norm text = lower (collapse text)
    fun reply f text = Option.map S.s_reply (f (norm text))
    (* The list grammar owns commas as observation separators. Each complete
       scalar literal is then parsed exactly; no numeric-prefix extraction. *)
    val LISTNUM = "[+\\-\226\136\146]?(?:\\d+(?:\\.\\d+)?|\\.\\d+)(?:e[+-]?\\d+)?(?:\\s*/\\s*[+\\-\226\136\146]?(?:\\d+(?:\\.\\d+)?|\\.\\d+)(?:e[+-]?\\d+)?)?"
    fun exactList body =
      let val bare = case search "^\\s*\\[(.*)\\]\\s*$" body of SOME m => g1 body m | NONE => body
          val t = replaceAll "\\band\\b" "," bare
      in if not(has ("^\\s*" ^ LISTNUM ^ "(?:(?:\\s*,\\s*|\\s+)" ^ LISTNUM ^ ")*\\s*$") t)
         then NONE
         else let val vals = map (fn m => ExactNumeric.parse(Regex.whole t m)) (findall LISTNUM t)
              in if List.all isSome vals then SOME(map (toRat o valOf) vals) else NONE end
      end
    fun unsupportedDatasetOperation t = has "\\b(?:trimmed|geometric|harmonic|winsori[sz]ed|rolling|moving|first|last|largest|smallest|distinct|unique)\\b" t
    (* Both weighted spellings consume complete value and weight lists. Once a
       dataset has a weight marker it cannot fall back to an unweighted mean. *)
    fun weighted text =
      let val t = replaceAll "[?.]$" "" (norm text)
          val prefix = has "\\bweighted (?:mean|average)\\b" t
          val tail = "\\s+(?:weighted\\s+by|(?:with|using)\\s+weights|weights)\\s*:?\\s*(.+)$"
          val body = search "\\b(?:mean|average)\\s+(?:of|for)\\s+(?:(?:the|these)\\s+)?(?:(?:data ?set|data|values|numbers|list)\\s*:?\\s*)?(.+)$" t
          fun parse b =
            case search tail b of
              NONE => if prefix then SOME G.modifier_refusal else NONE
            | SOME (m as {start,...}) =>
                let val values = String.substring(b,0,start)
                    val weights = g1 b m
                    val owns = prefix orelse isSome(exactList values) orelse
                      has ("^\\s*\\[?\\s*" ^ LISTNUM ^ "(?:\\s*,\\s*|\\s+)" ^ LISTNUM) values
                in if not owns then NONE
                   else if unsupportedDatasetOperation t then SOME G.modifier_refusal
                   else case (exactList values, exactList weights) of
                      (SOME xs,SOME ws) => SOME(G.weighted_reply xs ws)
                    | _ => SOME G.modifier_refusal
                end
      in case body of
           SOME m => parse(g1 t m)
         | NONE => if prefix then SOME G.modifier_refusal else NONE
      end
    fun dataset text =
      let val t = replaceAll "[?.]$" "" (norm text)
          val t = replaceFn DATASET (fn m => (g1 t m) ^ " ") t
          val which = List.find (fn (_,rx) => has rx t)
            [("stdev","\\bstandard deviation\\b|\\bstd\\.? ?dev\\b|\\bsd\\b"),
             ("variance","\\bvariance\\b"),("median","\\bmedian\\b"),("mode","\\bmode\\b"),
             ("range","\\brange\\b"),("mean","\\bmean\\b|\\baverage\\b")]
          val excludedOtherOperation = has "\\bz[- ]?score\\b" t
          val body = search "\\b(?:of|for|in|data(?:set)?|numbers|values|list)[:\\s]+(.+)$" t
          fun request kind xs = case kind of
              "stdev" => S.S_stdev (has "\\bpopulation\\b" t,xs)
            | "variance" => S.S_variance (has "\\bpopulation\\b" t,xs)
            | "median" => S.S_median(xs,true) | "mode" => S.S_mode xs
            | "range" => S.S_range xs | _ => S.S_mean(xs,true)
      val unsupportedPrefix = unsupportedDatasetOperation t
      in if excludedOtherOperation then NONE
         else case (which,body) of
           (SOME(kind,_),SOME m) =>
             let val b = replaceAll ",\\s*(?:what is|find|compute|calculate|determine)\\s+(?:the\\s+)?(?:population\\s+|sample\\s+)?(?:mean|average|median|mode|range|variance|standard deviation)\\s*$" "" (g1 t m)
                 val ex = search "\\s+(?:excluding|except|without|omitting)\\s+(.+)$" b
                 val (values,excluded) = case ex of NONE =>
                     (b,if has "\\b(?:excluding|except|without|omitting|remove|drop|ignore)\\b" t then NONE else SOME [])
                   | SOME (em as {start,...}) => (String.substring(b,0,start),exactList(g1 b em))
                 val parsed = exactList values
                 val listPrefix = has ("^\\s*\\[?\\s*" ^ LISTNUM ^ "(?:\\s*,\\s*|\\s+(?:and\\s+)?)" ^ LISTNUM) values
                 val explicitDataset = has "\\b(?:data ?set|data|numbers|values|list|observations)\\b" (norm text)
                 val ownsDataset = isSome parsed orelse listPrefix orelse explicitDataset
             in if not ownsDataset then NONE
                else if unsupportedPrefix then SOME G.modifier_refusal
                else case (parsed,excluded) of
                  (SOME xs,SOME es) => SOME(G.filtered_reply es (request kind xs))
                | _ => if has "[0-9]|\\b(?:excluding|except|without|omitting)\\b" b
                       then SOME G.modifier_refusal else NONE
             end
         | _ => NONE
      end
    (* z-score scalar roles use the same whole-token binding as geometry;
       a negative standard deviation reaches the existing positive-SD guard. *)
    fun exactZ text =
      let val t = norm text
          fun role rx = case search (rx ^ "\\s*(?:of|for|is|=)?\\s*(?:(?:a|the)\\s+)?(?:value\\s+of\\s+)?" ^ Geo.N) t of
              NONE => NONE
            | SOME m => Option.map (toRat o Geo.parseDec) (Geo.grp t m 1)
      in case (role "\\bz[- ]?score\\b", role "(?:\\bmean\\b|\\baverage\\b|\206\188)",
               role "(?:\\bstandard deviation\\b|\\bsd\\b|\\bstd\\b|\207\131)") of
           (SOME x,SOME mu,SOME sd) => SOME(S.s_reply(S.S_z(x,mu,sd)))
         | _ => NONE
      end handle Geo.BadGeometry => NONE
    (* Paired lists are consumed together, in order. The HOL wrapper checks
       equal lengths before zip, preserving every observation and duplicate. *)
    fun paired text =
      let val t = replaceAll "[?.]$" "" (norm text)
          val marker = has "\\bcovariance\\b|\\bregression\\b|\\bleast[- ]squares\\b" t
          val label = "\\s+(?:values|data|observations)\\s*[:=]?\\s*"
          val separator = "\\s*(?:,?\\s+and\\s+|;\\s*|,\\s*)y"
          val lists = case search ("\\bx" ^ label ^ "(.+?)" ^ separator ^ label ^ "(.+)$") t of
              SOME m => SOME m
            | NONE => search ("\\bx\\s*[:=]\\s*(\\[[^]]*\\])" ^ separator ^
                "\\s*[:=]\\s*(\\[[^]]*\\])$") t
          fun list body = if has "^\\s*\\[\\s*\\]\\s*$" body then SOME [] else exactList body
          val unsupported = unsupportedDatasetOperation t orelse
            (has "\\bcovariance\\b" t andalso has "\\bregression\\b|\\bleast[- ]squares\\b" t) orelse
            has "\\b(?:weighted|weights|excluding|except|without|omitting|remove|drop|ignore|nonlinear|non-linear|quadratic|cubic|polynomial|power|loglinear|exponential|logistic|logarithmic|standardi[sz]ed|normali[sz]ed|origin|constrained|fixed|robust|ridge|lasso|regulari[sz]ed|bayesian|orthogonal|interval|confidence|residuals?|correlation)\\b" t
          val reverseOrientation = has "\\bx\\s+(?:on|against|versus|vs[.]?)\\s+y\\b" t
          (* Consume the operation prefix as well as both data lists: an
             unfamiliar model or direction must not become ordinary y-on-x. *)
          fun completePrefix (m : Regex.match) =
            let val pre = String.substring(t,0,#start m)
                val lead = "(?:(?:what is|calculate|compute|find|give me)\\s+(?:the\\s+)?)?"
                val fit = "(?:(?:ordinary|linear)\\s+)?(?:regression|least[- ]squares)"
                val tail = "\\s+(?:for|from|using|of)\\s*$"
                val scalar = "(?:\\s+(?:line|slope|intercept|slope and intercept))?"
                val direction = "(?:\\s+of\\s+y\\s+(?:on|against|versus|vs[.]?)\\s+x)?"
            in has ("^" ^ lead ^ "(?:(?:(?:population|sample)\\s+)?covariance|" ^ fit ^ scalar ^ direction ^ ")" ^ tail) pre
               orelse has ("^" ^ lead ^ fit ^ "\\s+prediction\\s+at\\s+x\\s*(?:=|of)?\\s*.+?" ^ tail) pre
               orelse has ("^predict\\s+y\\s+at\\s+x\\s*(?:=|of)?\\s*.+?\\s+(?:from|using)\\s+(?:the\\s+)?" ^ fit ^ "\\s+line" ^ tail) pre
            end
          fun prediction () =
            case search "\\bat\\s+x\\s*(?:=|of)?\\s*(.+?)\\s+(?:from|for|using)\\b" t of
               NONE => NONE
             | SOME m => Option.map (G.P_predict o toRat) (ExactNumeric.parse (g1 t m))
          fun operation () =
            if has "\\bcovariance\\b" t then
              if has "\\bpopulation\\b" t andalso has "\\bsample\\b" t then NONE
              else if has "\\bpopulation\\b" t then SOME(G.P_covariance true)
              else if has "\\bsample\\b" t then SOME(G.P_covariance false) else NONE
            else if has "\\bpredict(?:ion)?\\b" t then prediction ()
            else if has "\\bslope\\b" t andalso has "\\bintercept\\b" t then SOME G.P_line
            else if has "\\bslope\\b" t then SOME G.P_slope
            else if has "\\bintercept\\b" t then SOME G.P_intercept
            else SOME G.P_line
      in if not marker then NONE
         else case lists of NONE => NONE
         | SOME m =>
           if unsupported orelse reverseOrientation orelse not(completePrefix m) then SOME G.modifier_refusal
           else case (list(g1 t m),list(valOf(grp t m 2))) of
             (SOME xs,SOME ys) => (case operation () of
                 SOME req => SOME(G.paired_reply req xs ys)
               | NONE => SOME (if has "\\bcovariance\\b" t then G.paired_model_refusal else G.paired_prediction_refusal))
           | _ => SOME G.modifier_refusal
      end
    fun complete text =
      case paired text of SOME r => SOME r
      | NONE => if has "\\bz[- ]?score\\b" (norm text) then exactZ text
      else if has "\\bweighted (?:mean|average)\\b" (norm text) andalso
         has "\\b(?:excluding|except|without|omitting|remove|drop|trim|ignore)\\b" (norm text)
      then SOME G.modifier_refusal
      else case weighted text of SOME r => SOME r
      | NONE => (case dataset text of SOME r => SOME r | NONE => reply v3 text)
    fun byId "statistics" text = complete text
      | byId "statistics-v2" text = complete text
      | byId "statistics-v3" text = complete text
      | byId _ _ = NONE
  end

  val organs = ["geometry", "geometry-v3", "geometry-v4", "statistics", "statistics-v2", "statistics-v3"]
  val familyOrder = ["geometry-v4", "statistics-v3"]

  fun byId id text =
    case Geo.byId id text of
      SOME r => SOME r
    | NONE => Stat.byId id text

  fun recognize mode text =
    if mode = "family" then
      let fun go [] = NONE
            | go (id :: ids) = case byId id text of SOME r => SOME (id, r) | NONE => go ids
      in go familyOrder end
    else Option.map (fn r => (mode, r)) (byId mode text)
end
