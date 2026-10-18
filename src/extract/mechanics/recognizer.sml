(* UNTRUSTED. The English recognizer for the mechanics family: a hand port of
   the regular expressions and branch order of
     upstream/root/specialists/physics/organ_mechanics_v1.py        (MechanicsOrgan)
     upstream/root/specialists/physics-r2/organ_mechanics_v2.py     (MechanicsOrganV2)
     upstream/root/specialists/physics-r3/organ_physics_r3.py       (MechanicsOrganV2Boundary)
     upstream/root/specialists/mechanisms/organ_mechanisms_v1.py    (MechanismsOrgan)
     upstream/root/specialists/mechanisms-v2/organ_mechanisms_v2.py (MechanismsOrganV2, numbers_rule_v1)
     upstream/root/specialists/bodies-v2/organ_bodies_v{1,2}.py     (BodiesOrgan, BodiesOrganV2)
     upstream/root/specialists/sports/organ_sports_v1.py            (SportsOrgan)
     upstream/root/specialists/fleet/organ_fleet_v1.py              (FleetOrgan)
     upstream/root/specialists/fluids-r2/organ_fluids_v{1,2}.py     (FluidsOrgan, FluidsOrganV2)
   and of their shared narrowing rule narrow_v1.py. It reads numbers and words
   off the question and builds a typed Mechanics.request; it computes nothing.
   Every value, decline and response text comes from the verified HOL kernel
   (Mechanics.reply_of). NONE means the question is not taken (the organ
   returns None). Where an organ wrapper looks at the organ's reply (physics-r2
   asks whether it declined, mechanisms-v2 whether it is underspecified), this
   file asks the kernel for the reply of the request it just built.

   Patterns are passed to Regex.compile exactly as written, so every pattern
   applied to lower-cased text is written in lower case; the few
   case-sensitive organ patterns (newtons "N", joules "J", body names, "MA")
   are applied to the original text. \w and \d are ASCII here.

   Additional safeguards beyond the original port: inputs the organs divide by zero on or take a square root of a
   negative on reach the kernel, which declines them as impossible (the organs
   raise exceptions); a true-shooting turn with no attempts is a withheld
   reply, where the organ is silent. *)
structure Recognizer :
sig
  val organs : string list
  val recognize : string -> string -> (string * Mechanics.request) option
end =
struct
  structure M = Mechanics

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

  (* splice a replacement over every match (positions found in the lower-cased text, spliced into the original) *)
  fun substCI p rep orig =
    let
      val low = lower orig
      fun go i [] acc = String.concat (rev (String.extract (orig, i, NONE) :: acc))
        | go i (({start, stop, ...} : Regex.match) :: ms) acc =
            go stop ms (rep :: String.substring (orig, i, start - i) :: acc)
    in go 0 (findall p low) [] end

  (* Every arithmetic role resolves to a lexer-issued token. This scoped
     table is restored before recognize returns; no request retains it. *)
  exception InvalidNumeric
  val numericValues : (string * ExactNumeric.rational) list ref = ref []
  fun rationalOf token =
    case List.find(fn(key,_)=>key=token)(!numericValues) of
      SOME(_,value) => value | NONE => raise InvalidNumeric
  fun ratOf token : M.rat = let val(n,d)=rationalOf token in M.mk_rat n d end
  (* Only validated structured innings and score fields use raw integers. *)
  fun rawRat raw : M.rat = case ExactNumeric.parse raw of
      SOME(n,d)=>M.mk_rat n d | NONE=>raise InvalidNumeric

  fun natOf (n : int) = M.nat_of_integer (IntInf.fromInt n)
  fun collapse s = String.concatWith " " (String.tokens Char.isSpace s)
  fun optG s m g = Option.map ratOf (grp s m g)
  fun firstRat p s = case search p s of SOME m => SOME (ratOf (g1 s m)) | NONE => NONE
  fun firstStr p s = case search p s of SOME m => SOME (g1 s m) | NONE => NONE
  (* case-sensitive checks: the regex matcher folds literals to lower case, so a pattern that is case-sensitive in
     the organ is matched on the lower-cased text and the original characters are checked afterwards *)
  fun upperAt orig i = i < size orig andalso Char.isUpper (String.sub (orig, i))
  fun lowerAt orig i = i < size orig andalso Char.isLower (String.sub (orig, i))
  fun groupStart m g = case Regex.group "" m g of _ => (case Vector.sub (#groups m, g) of SOME (a, _) => SOME a | NONE => NONE)
  fun strZero token = #1(rationalOf token)=0
  fun rawZero s = case ExactNumeric.parse s of SOME(n,_)=>n=0 | NONE=>false

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
    fun last_sentence t =
      let
        val (s, sp) = splits ".!?;" t
      in
        case rev sp of
          [] => s
        | i :: _ => let fun skip j = if j < size s andalso Char.isSpace (String.sub (s, j)) then skip (j + 1) else j
                    in String.extract (s, skip i, NONE) end
      end
    val RELATION = "\\b(?:qnum[0-9]+q|one|two|three|four|five|six|seven|eight|nine|ten)\\s+(?:\\w+\\s+){0,2}"
      ^ "(?:more|less|fewer|longer|shorter)\\s+than\\b|\\b(?:twice|three times|half)\\s+(?:as\\s+\\w+\\s+as\\s+)?the\\s+\\w+\\b"
    val RATE = "\\bqnum[0-9]+q\\s+[a-z]+\\s+(?:for|per|every)\\s+(?:qnum[0-9]+q|a|an|one|each)\\s+[a-z]+"
    fun narrative t =
      let val low = lower t
      in sentences t >= 3 orelse words t > 40 orelse has RELATION low orelse has RATE low end
    fun short_direct t = sentences t <= 2 andalso words t <= 25 andalso not (narrative t)
    fun numbers t = length(findall "qnum[0-9]+q" t)
  end

  (* A numeric role cannot capture a digit from a unit or an identifier. *)
  val NUM = "(qnum[0-9]+q)"
  val SNUM = NUM
  val UNUM = NUM
  val deg = "\194\176"
  val sq2 = "\194\178"
  val cube = "\194\179"

  (* ---------- physics v1 ---------- *)
  val MASS_UNIT = "(?:kilograms?|kg|grams?|g|tonnes?|metric tons?|t|pounds?|lbs?)"
  val Pm = SNUM ^ "\\s*(" ^ MASS_UNIT ^ ")\\b(?!\\s*/|\\s*per\\b|\\s*\\^)"
  fun massUnit u = if u="g" orelse u="gram" orelse u="grams" then M.MU_g
    else if u="t" orelse String.isPrefix "tonne" u orelse String.isPrefix "metric ton" u then M.MU_tonne
    else if String.isPrefix "lb" u orelse String.isPrefix "pound" u then M.MU_lb else M.MU_kg
  val massSpecs = map (fn alias => {alias=alias,tag=alias,dimension="mass",caseSensitive=false})
    ["kg","kilogram","kilograms","g","gram","grams","t","tonne","tonnes",
     "metric ton","metric tons","lb","lbs","pound","pounds"] @
    map (fn alias => {alias=alias,tag=alias,dimension="force",caseSensitive=false})
      ["kg force","kilogram force","kilograms force","lb force","lbs force","pound force","pounds force"]
  fun massValue low (m:Regex.match) =
    let val (_,numberStop)=valOf(Vector.sub(#groups m,1))
    in case MeasuredInput.unitAt massSpecs low numberStop of
         SOME(MeasuredInput.Explicit{unit,...}) =>
           if #dimension unit = "mass" then M.mass_kg (ratOf(g1 low m)) (massUnit(#tag unit))
           else raise InvalidNumeric
       | _ => raise InvalidNumeric
    end
  fun firstMass low = Option.map (massValue low) (search Pm low)
  val Pv = SNUM ^ "\\s*(?:m/s|meters? per second|metres? per second)(?!\\s*(?:\\^?2|" ^ sq2 ^ "|squared|per second))"
  val Pa = SNUM ^ "\\s*(?:m/s\\^?2|m/s" ^ sq2 ^ "|meters? per second squared|metres? per second squared|m/s/s)"
  val Pt = SNUM ^ "\\s*(?:s|sec|seconds?)\\b(?!\\s*squared)"
  val Ph = SNUM ^ "\\s*(?:m|meters?|metres?)\\b(?!\\s*/|\\s*per)"
  val PF = SNUM ^ "\\s*(n|newtons?)\\b"           (* case-sensitive "N" / "newtons": checked on the original text *)
  val PE = SNUM ^ "\\s*(j|joules?)\\b"            (* case-sensitive "J" / "joules": checked on the original text *)
  (* first amount whose unit, as written, is the capital letter or the all-lower-case word *)
  fun firstCS p orig low =
    let
      fun ok (m : Regex.match) =
        case Vector.sub (#groups m, 2) of
          SOME (a, b) => let val w = String.substring (orig, a, b - a) in w = String.map Char.toUpper w andalso size w = 1 orelse w = lower w andalso size w > 1 end
        | NONE => false
    in case List.find ok (findall p low) of SOME m => SOME (ratOf (g1 low m)) | NONE => NONE end
  val Pdeg = SNUM ^ "\\s*(?:degrees?|" ^ deg ^ ")"

  fun physicsV1 text : M.request option =
    let
      val t = collapse text
      val low = lower t
    in
      if not (has ("\\b(?:velocity|speed|accelerat\\w*|falls?|dropped|drop|force|weight|kinetic|potential|momentum|"
                   ^ "work|power|projectile|launched|thrown)\\b") low) then NONE
      else
        let
          val m_ = firstMass low and v_ = firstRat Pv low and a_ = firstRat Pa low
          val t_ = firstRat Pt low and h_ = firstRat Ph low
          val F_ = firstCS PF t low and E_ = firstCS PE t low and d_ = firstRat Pdeg low
          (* Python's "not a_": absent or zero *)
          val noA = case firstStr Pa low of NONE => true | SOME a => strZero a
          val rest1 = has "\\bfrom rest\\b|\\bat rest\\b|\\bstarts? (?:from )?stationary\\b" low
          val rest2 = has "\\bfrom rest\\b|\\bat rest\\b" low
        in
          if has "\\b(?:range|how far)\\b" low andalso has "\\b(?:launched|thrown|projectile|fired|kicked)\\b" low then
            SOME (M.PhRange (v_, d_))
          else if has "\\b(?:dropped|falls?|fall from|drop)\\b" low andalso isSome h_ andalso noA then
            (if has "\\bspeed|velocity|how fast\\b" low then SOME (M.PhImpact (valOf h_)) else SOME (M.PhFall (valOf h_)))
          else if has "\\bkinetic energy\\b" low then SOME (M.PhKE (m_, v_))
          else if has "\\bpotential energy\\b" low then SOME (M.PhPE (m_, h_))
          else if has "\\bmomentum\\b" low then SOME (M.PhMomentum (m_, v_))
          else if has "\\bweight\\b" low andalso isSome m_ andalso noA then SOME (M.PhWeight (valOf m_))
          else if has "\\bforce\\b" low then SOME (M.PhForce (m_, a_))
          else if has "\\bwork\\b" low andalso isSome F_ andalso isSome h_ then SOME (M.PhWork (valOf F_, valOf h_))
          else if has "\\bpower\\b" low andalso isSome E_ andalso isSome t_ then SOME (M.PhPower (valOf E_, valOf t_))
          else if has "\\b(?:final (?:velocity|speed)|velocity after|speed after|how fast)\\b" low then
            SOME (M.PhFinalV (a_, t_, v_, rest1))
          else if has "\\b(?:how far|distance|displacement)\\b" low andalso isSome a_ andalso isSome t_ then
            SOME (M.PhDistance (valOf a_, valOf t_, v_, rest2))
          else NONE
        end
    end

  val IDIOM = "\\b(?:air|police|task|labou?r|work|armed|special|security|naval|defen[cs]e|peacekeeping|driving|life)\\s+forces?\\b|"
    ^ "\\bworkforce\\b|\\b(?:in|into) force\\b|\\bby force\\b|\\bforce majeure\\b|\\bforce of (?:habit|nature|will)\\b|\\bthe force\\b"
  val ASKS = [("weight", "\\bweigh"), ("force", "\\bforce\\b|\\bnewtons?\\b"), ("ke", "\\bkinetic\\b|\\benergy\\b"),
              ("pe", "\\bpotential\\b|\\benergy\\b"), ("momentum", "\\bmomentum\\b"),
              ("range", "\\brange\\b|\\bhow far\\b|\\bdistance\\b|\\bprojectile\\b|\\bgo\\b"),
              ("impact_speed", "\\bspeed\\b|\\bfast\\b|\\bvelocity\\b"), ("fall_time", "\\bhow long\\b|\\btime\\b|\\bseconds?\\b")]

  fun physicsR2 text : M.request option =
    let
      val t = text
      val low = lower t
      val idiomOnly = has IDIOM low andalso not (has "\\bforce\\b" (lower (substCI IDIOM " " low)))
                      andalso not (has "\\b(?:velocity|speed|accelerat\\w*|kinetic|potential|momentum|projectile)\\b" low)
    in
      if Narrow.narrative t orelse idiomOnly then NONE
      else
        case physicsV1 text of
          NONE => NONE
        | SOME req =>
            let
              val rep = M.reply_of req
              val answered = M.answered rep
            in
              if not answered then (if Narrow.short_direct t then SOME req else NONE)
              else
                let
                  val kind = M.reply_kind rep
                  val ls = lower (Narrow.last_sentence t)
                  val iq = search "\\b(?:what|how|find|calculate|compute|determine|give|which)\\b" ls
                  val region = case iq of SOME {start, ...} => String.extract (ls, start, NONE) | NONE => ls
                in
                  case List.find (fn (k, _) => k = kind) ASKS of
                    SOME (_, want) => if has want region then SOME req else NONE
                  | NONE => SOME req
                end
            end
    end

  fun physicsR3 text : M.request option =
    let val low = lower text
    in
      if has "\\b(?:torque|levers?|beaufort|knots?|passwords?|brute[- ]force|characters?|usda|calories)\\b" low
         andalso not (has "\\b(?:mass|kg|accelerat\\w*|velocity|projectile|momentum|falls?|dropped|kinetic|potential energy)\\b" low)
      then NONE else physicsR2 text
    end

  fun zipChecked (xs, ys, what) =
    if length xs = length ys then ListPair.zip (xs, ys)
    else raise Fail ("recognizer table length differs from HOL list: " ^ what)

  (* ---------- bodies ---------- *)
  val bodyKeys = ["Mercury", "Venus", "Earth", "the Moon", "Mars", "Jupiter", "Saturn", "Uranus", "Neptune",
                  "Pluto", "the Sun", "Ceres", "Io", "Europa", "Ganymede", "Callisto", "Titan", "Triton", "Enceladus"]
  val bodies = zipChecked (bodyKeys, M.body_order, "body_order")
  val bodyEarth = List.nth (M.body_order, 2)
  val bodyMoon = List.nth (M.body_order, 3)

  val GIVEN_G = "\\bg\\s*=\\s*" ^ NUM ^ "\\s*(?:m/s\\^?2|m/s" ^ sq2 ^ "|m/s/s)|\\bgravity\\s+(?:of|is)\\s+" ^ NUM
    ^ "\\s*(?:m/s\\^?2|m/s" ^ sq2 ^ "|m/s/s)"
  val MASS = Pm
  val HEIGHT = NUM ^ "\\s*(?:m|met(?:re|er)s?)\\b(?!\\s*/|\\s*per)"
  val LENGTH = NUM ^ "\\s*(?:m|met(?:re|er)s?)\\s+(?:long|in length)|(?:length|long)\\s+(?:of\\s+)?" ^ NUM
    ^ "\\s*(?:m|met(?:re|er)s?)\\b"
  val ANY_BODY = "\\b(mercury|venus|moon|mars|jupiter|saturn|uranus|neptune|pluto|ceres|io|europa|ganymede|callisto|titan|triton|enceladus)\\b(?:'s)?"
  val GRAVITY_ASK = "\\b(?:fall\\w*|drop\\w*|released|weigh\\w*|weight|pendulum|impact|land\\w*|hit\\w*|gravity|how long|how fast|speed|period)\\b"

  (* organ_bodies_v1._gravity: a stated g, else exactly one non-Earth body named after on/at/from/of *)
  fun gravityV1 t low =
    case search GIVEN_G low of
      SOME m =>
        let val s = valOf (firstGroup low m [1, 2])
        in SOME (M.G_stated (ratOf s)) end
    | NONE =>
        let
          val found = List.mapPartial (fn (k, b) =>
            let
              val ci = String.isPrefix "the " k
              val name = if ci then String.extract (k, 4, NONE) else k
              val pre = "\\b(?:on|at|from|of)\\s+(?:the\\s+)?(?:surface of\\s+(?:the\\s+)?)?(" ^ lower name ^ ")\\b"
              (* the organ's pattern is case-sensitive (lower-case preposition, capitalised name) unless it is "the Moon"/"the Sun" *)
              fun hit (m : Regex.match) =
                ci orelse (lowerAt t (#start m) andalso (case Vector.sub (#groups m, 1) of SOME (a, _) => upperAt t a | NONE => false))
              val hits = List.filter hit (findall pre low)
            in if not (null hits) andalso k <> "Earth" then SOME b else NONE end) bodies
        in case found of [b] => SOME (M.G_body b) | _ => NONE end

  (* organ_bodies_v2._gravity: a body named anywhere in proper-noun form *)
  fun gravityV2 t low =
    case search GIVEN_G low of
      SOME _ => gravityV1 t low
    | NONE =>
        let
          fun cap (m : Regex.match) = case Vector.sub (#groups m, 1) of SOME (a, _) => upperAt t a | NONE => false
          val moonOk = List.exists (fn m => List.exists (fn g => case Vector.sub (#groups m, g) of SOME (a, _) => upperAt t a | NONE => false) [1, 2, 3])
                         (findall "\\b(?:the|our) (moon)\\b|\\b(moon)'s|\\bon (moon)\\b" low)
          val names = List.mapPartial (fn m =>
            if not (cap m) then NONE
            else let val n = g1 low m
                 in if n = "moon" andalso not moonOk then NONE else SOME n end) (findall ANY_BODY low)
          fun dedupe [] = [] | dedupe (x :: xs) = x :: dedupe (List.filter (fn y => y <> x) xs)
          val uniq = dedupe names
          fun toBody "moon" = bodyMoon
            | toBody n = #2 (valOf (List.find (fn (k, _) => lower k = n) bodies))
        in case uniq of [n] => SOME (M.G_body (toBody n)) | _ => gravityV1 t low end

  fun bodiesV1 gravf text : M.request option =
    let val t = collapse text in
      if t = "" orelse Narrow.narrative t then NONE
      else
        let
          val low = lower t
          val asklow = lower (Narrow.last_sentence t)
          fun need r = if Narrow.short_direct t then SOME r else NONE
        in
          case gravf t low of
            NONE => NONE
          | SOME g =>
              let
                val masses = map (massValue low) (findall MASS low)
                val heights = map (fn m => g1 low m) (findall HEIGHT low)
                val falls = has "\\b(?:drop(?:ped)?|falls?|fall(?:ing)?|released)\\b" low
              in
                if has "\\bpendulum\\b" low andalso has "\\bperiod\\b|\\bhow long\\b.*\\bswing\\b|\\bswing\\b" asklow then
                  (case search LENGTH low of
                     NONE => need (M.BdPendulum (g, NONE))
                   | SOME m => SOME (M.BdPendulum (g, SOME (ratOf (valOf (firstGroup low m [1, 2]))))))
                else if has "\\bweigh|\\bweight\\b" asklow then
                  (case masses of [m] => SOME (M.BdWeight (g, SOME m)) | _ => need (M.BdWeight (g, NONE)))
                else if falls andalso has "\\b(?:how long|how many seconds|time)\\b" asklow then
                  (case heights of [h] => SOME (M.BdFall (g, SOME (ratOf h))) | _ => need (M.BdFall (g, NONE)))
                else if falls andalso has "\\b(?:speed|how fast|velocity)\\b" asklow then
                  (case heights of [h] => SOME (M.BdImpact (g, SOME (ratOf h))) | _ => need (M.BdImpact (g, NONE)))
                else NONE
              end
        end
    end

  fun bodiesV2 text : M.request option =
    case bodiesV1 gravityV2 text of
      SOME r => SOME r
    | NONE =>
        let val t = collapse text
        in
          if t = "" then NONE
          else
            let val low = lower t
            in case gravityV2 t low of
                 SOME g => if has GRAVITY_ASK low andalso has "\\d" t then SOME (M.BdUnreadable g) else NONE
               | NONE => NONE
            end
        end

  (* ---------- mechanisms ---------- *)
  val rpmRx = UNUM ^ "\\s*(?:rpm|rev(?:olution)?s? per minute)\\b"
  val tqRx = UNUM ^ "\\s*(?:n\\s*(?:\194\183|\\.)?\\s*m|newton[- ]met(?:er|re)s?|nm)\\b"

  (* organ_mechanisms_v1._driver_driven: (driver, driven) from grammar, never from order of mention *)
  fun driverDrivenPair low nu width decode =
    let
      val m1 = search (nu ^ "[^.?;]*?\\b(?:drives|turns|meshes with and drives|is connected to and drives)\\b[^.?;]*?" ^ nu) low
      val m2 = search (nu ^ "[^.?;]*?\\b(?:is driven by|driven by)\\b[^.?;]*?" ^ nu) low
      val a = search ("\\b(?:driver|driving|input|motor)\\b[^.?;]*?" ^ nu ^ "|" ^ nu ^ "[^.?;]*?\\b(?:driver|driving|input)\\b(?! speed)") low
      val b = search ("\\b(?:driven|output|follower)\\b[^.?;]*?" ^ nu ^ "|" ^ nu ^ "[^.?;]*?\\b(?:driven|output|follower)\\b(?! speed)") low
      fun pick m = decode m (if isSome(grp low m 1) then 1 else 1+width)
    in
      case m1 of
        SOME m => SOME(decode m 1,decode m (1+width))
      | NONE => (case m2 of
          SOME m => SOME(decode m (1+width),decode m 1)
        | NONE => (case(a,b) of (SOME ma,SOME mb) => SOME(pick ma,pick mb) | _ => NONE))
    end
  fun driverDriven low u =
    driverDrivenPair low (UNUM ^ "[- ]?" ^ u) 1 (fn m => fn i => valOf(grp low m i))

  fun loadUnit s = if s = "kg" then M.LD_kg else M.LD_n
  val LEN = "(?:millimet(?:er|re)s?|mm|centimet(?:er|re)s?|cm|met(?:er|re)s?|m|feet|foot|ft|inches|inch|in|yards?|yd|miles?|mi)"
  fun lenUnit s =
    if s = "cm" orelse String.isPrefix "centimet" s then M.LU_cm
    else if s = "mm" orelse String.isPrefix "millimet" s then M.LU_mm
    else if s = "ft" orelse s = "foot" orelse s = "feet" then M.LU_ft
    else if s = "in" orelse s = "inch" orelse s = "inches" then M.LU_in
    else if s="yd" orelse String.isPrefix "yard" s then M.LU_yd
    else if s="mi" orelse String.isPrefix "mile" s then M.LU_mi else M.LU_m
  fun lengthPair ((x,u),(y,v)) =
    case (u,v) of
      (NONE,NONE) => SOME (x,y)
    | (SOME a,SOME b) => SOME (M.length_m x a,M.length_m y b)
    | _ => NONE
  fun namedLength low name =
    let
      (* A missing unit is genuinely absent, never an unsupported unit word. *)
      val suffix = "(?:\\s*(" ^ LEN ^ ")\\b|\\b(?=\\s*(?:[,.;?!:]|$|and\\b|with\\b|to\\b|from the fulcrum\\b|" ^ name ^ ")))"
      val a = search (name ^ "\\s*(?:of|is|=)?\\s*" ^ NUM ^ suffix) low
      val b = search (NUM ^ suffix ^ "\\s*(?:from the fulcrum )?" ^ name) low
    in
      case (a,b) of
        (NONE,NONE) => NONE
      | _ => let val m = case a of SOME m => m | NONE => valOf b
             in SOME (ratOf (g1 low m),Option.map lenUnit (grp low m 2)) end
    end

  fun mechV1 text : M.request option =
    let
      val t = collapse text
      val low = lower t
      val rpm = search rpmRx low
      val tq = search tqRx low
      fun need n = SOME (M.McNeed (natOf n))
    in
      if has "\\bteeth\\b|\\btooth\\b" low andalso has "\\bgears?\\b" low then
        (case driverDriven low "(?:teeth|tooth)" of
           NONE => need 0
         | SOME (a, b) =>
             let val ra = ratOf a and rb = ratOf b
             in
               case rpm of
                 SOME rm =>
                   if has "\\b(?:output|driven|speed of the|how fast)\\b" low then SOME (M.McGearSpeed (ratOf (g1 low rm), ra, rb))
                   else (case tq of SOME q => if has "\\btorque\\b" low then SOME (M.McGearTorque (ratOf (g1 low q), ra, rb))
                                              else SOME (M.McGearRatio (ra, rb))
                                  | NONE => SOME (M.McGearRatio (ra, rb)))
               | NONE =>
                   (case tq of SOME q => if has "\\btorque\\b" low then SOME (M.McGearTorque (ratOf (g1 low q), ra, rb))
                                          else SOME (M.McGearRatio (ra, rb))
                             | NONE => SOME (M.McGearRatio (ra, rb)))
             end)
      else if has "\\bbelt\\b|\\bpulley\\b" low andalso isSome rpm
              andalso has ("\\bdiameter|" ^ NUM ^ "\\s*" ^ LEN ^ "\\s+pulley\\b") low then
        (case driverDrivenPair low (UNUM ^ "[- ]?(" ^ LEN ^ ")\\b") 2
          (fn m => fn i => M.length_m (ratOf(valOf(grp low m i))) (lenUnit(valOf(grp low m (i+1))))) of
           NONE => need 1
         | SOME (d1,d2) => SOME(M.McBeltSpeed(ratOf(g1 low(valOf rpm)),d1,d2)))
      else if isSome (search (UNUM ^ "\\s*(?:supporting\\s+)?(?:strands|ropes|rope segments|segments of rope)\\b") low)
              andalso has "\\bpulley" low then
        let
          val m = valOf (search (UNUM ^ "\\s*(?:supporting\\s+)?(?:strands|ropes|rope segments|segments of rope)\\b") low)
          val n = ratOf (g1 low m)
        in
          case search (UNUM ^ "\\s*(n|newtons?|kg)\\b") low of
            NONE => SOME (M.McPulleyMA n)
          | SOME ld => SOME (M.McPulleyEffort (n, (ratOf (g1 low ld), loadUnit (valOf (grp low ld 2)))))
        end
      else if has "\\blever\\b|\\bfulcrum\\b|\\bcrowbar\\b|\\bseesaw\\b" low
              andalso (not (has "\\btorque\\b" low)
                orelse has "\\b(?:effort|load|resistance) arm\\b|\\bfulcrum\\b" low) then
        let
          fun either p1 p2 = case search p1 low of SOME m => SOME m | NONE => search p2 low
          val ea = namedLength low "\\beffort arm\\b"
          val la = namedLength low "\\b(?:load|resistance) arm\\b"
          val arms = case (ea,la) of (SOME e,SOME l) => lengthPair(e,l) | _ => NONE
        in
          case arms of
            SOME (e,l) =>
              let
                val ld = either ("\\b(?:lift|load of|weighing|move)\\s*(?:a\\s+)?" ^ UNUM ^ "\\s*(n|newtons?|kg)\\b")
                                (UNUM ^ "\\s*(n|newtons?|kg)\\s*(?:load|rock|weight|object)\\b")
              in
                case ld of
                  SOME mld =>
                    if has "\\beffort\\b|\\bforce\\b|\\bhow (?:much|hard)\\b" low
                    then SOME (M.McLeverEffort (e, l, SOME (ratOf (g1 low mld), loadUnit (valOf (grp low mld 2)))))
                    else SOME (M.McLeverMA (e, l))
                | NONE => SOME (M.McLeverMA (e, l))
              end
          | _ => need 2
        end
      else if has "\\bramp\\b|\\binclined plane\\b|\\bincline\\b" low andalso has "\\bmechanical advantage\\b|\\bma\\b" low then
        let
          val lm = namedLength low "\\b(?:length|long)\\b"
          val hm = namedLength low "\\b(?:height|high|tall)\\b"
        in
          case (lm,hm) of
            (SOME a,SOME b) =>
              (case lengthPair(a,b) of SOME(l,h) => SOME(M.McInclineMA(l,h)) | NONE => need 3)
          | _ => need 3
        end
      else if isSome tq andalso isSome rpm andalso has "\\bpower\\b|\\bwatts?\\b|\\bkw\\b|\\bhorsepower\\b" low then
        SOME (M.McShaftPower (ratOf (g1 low (valOf rpm)), ratOf (g1 low (valOf tq))))
      else if has "\\btorque\\b" low then
        let
          val f = search (UNUM ^ "\\s*(?:n|newtons?)\\b(?!\\s*(?:\194\183|\\.)?\\s*m)") low
          val r = search (UNUM ^ "\\s*(" ^ LEN ^ ")\\s*(?:long|wrench|lever|arm|from the (?:axis|center|pivot|bolt))|\\b(?:wrench|lever|arm|radius)\\s*(?:of|is)?\\s*"
                          ^ UNUM ^ "\\s*(" ^ LEN ^ ")\\b") low
        in
          case (f, r) of
            (SOME mf, SOME mr) =>
              let
                val fv = ratOf (g1 low mf)
                val rv = ratOf (valOf (firstGroup low mr [1, 3]))
                val ru = lenUnit (valOf (firstGroup low mr [2, 4]))
              in
                case search ("\\bat (?:an angle of )?" ^ UNUM ^ "\\s*(?:degrees|deg|" ^ deg ^ ")") low of
                  SOME ma => SOME (M.McTorqueAngle (fv, rv, ru, ratOf (g1 low ma)))
                | NONE => SOME (M.McTorque (fv, rv, ru))
              end
          | _ => need 4
        end
      else NONE
    end

  fun mechV2 text : M.request option =
    let
      val low0 = lower text
      val t1 = if has "\\btorque\\b" low0 andalso not (has "\\b(?:effort|load|resistance) arm\\b|\\bfulcrum\\b" low0)
               then substCI "\\blever\\b" "wrench" text else text
      val t2 = substCI "\\blift(?:s|ed|ing)\\b" "lift" t1
      val r = case mechV1 t2 of
                SOME (M.McLeverMA (e, l)) =>
                  if has "\\beffort\\b|\\bforce\\b|\\bhow (?:much|hard)\\b" (lower t2)
                     andalso not (has "\\bmechanical advantage\\b" (lower t2) orelse (has "\\bma\\b" (lower t2) andalso String.isSubstring "MA" t2))
                  then SOME (M.McLeverEffort (e, l, NONE)) else SOME (M.McLeverMA (e, l))
              | other => other
    in
      case r of
        SOME req => if M.reply_kind (M.reply_of req) = "underspecified" andalso Narrow.numbers text >= 1 then NONE else r
      | NONE => NONE
    end

  (* ---------- sports ---------- *)
  (* organ_sports_v1.stat: "N name" or "name [of|:|=] N", the first name that matches *)
  fun stat low names : string option =
    let
      fun one nm =
        case search (NUM ^ "\\s*" ^ nm ^ "\\b") low of
          SOME m => SOME (g1 low m)
        | NONE => (case search ("\\b" ^ nm ^ "\\s*(?:of|:|=)?\\s*" ^ NUM) low of SOME m => SOME (g1 low m) | NONE => NONE)
      fun go [] = NONE
        | go (n :: ns) = case one n of SOME s => SOME s | NONE => go ns
    in go names end
  fun st low names = Option.map ratOf (stat low names)
  val zero = M.mk_rat 0 1

  fun sportsInner text : M.request option =
    let
      val t = collapse text
      val low = lower t
    in
      if has "\\bpasser rating\\b|\\bqb rating\\b|\\bquarterback rating\\b" low then
        (case (st low ["completions?", "cmp"], st low ["attempts?", "att", "passes attempted"],
               st low ["(?:passing )?yards", "yds"], st low ["(?:passing )?touchdowns?", "tds?"],
               st low ["interceptions?", "ints?", "picks"]) of
           (SOME c, SOME a, SOME y, SOME td, SOME i) => SOME (M.SpPasser (c, a, y, td, i))
         | _ => NONE)
      else if has "\\btrue shooting\\b|\\bts%\\b|\\bts percentage\\b" low then
        (case (st low ["points", "pts"], st low ["field goal attempts", "fga", "shots"], st low ["free throw attempts", "fta"]) of
           (SOME p, SOME fga, SOME fta) => SOME (M.SpTrueShooting (p, fga, fta))
         | _ => NONE)
      else if has "\\bera\\b|\\bearned run average\\b|\\bwhip\\b" low then
        (case search "(?<![\\w.,/+\\-])(\\d+)(?:\\.(\\d+))?\\s*(?:innings(?: pitched)?|ip)\\b" low of
           NONE => NONE
         | SOME m =>
             let
               val wS = g1 low m
               val fS = case grp low m 2 of SOME d => d | NONE => "0"
               val w = rawRat wS and f = rawRat fS
               val dead = valOf (Int.fromString fS) >= 3 orelse (rawZero wS andalso rawZero fS)
             in
               if has "\\bwhip\\b" low then
                 (case (st low ["walks?", "bb"], st low ["hits?", "h"]) of
                    (SOME bb, SOME h) => SOME (M.SpWhip (w, f, bb, h))
                  | _ => if dead then SOME (M.SpWhip (w, f, zero, zero)) else NONE)
               else
                 (case st low ["earned runs?", "er"] of
                    SOME er => SOME (M.SpEra (w, f, er))
                  | NONE => if dead then SOME (M.SpEra (w, f, zero)) else NONE)
             end)
      else
        let
          val abS = stat low ["at[- ]bats?", "ab"]
          val h = case st low ["hits?", "h"] of
            SOME v => SOME v
          | NONE => if isSome abS andalso strZero (valOf abS) then SOME zero else NONE
        in
          if isSome abS andalso has "\\bbatting average\\b|\\bon[- ]base\\b|\\bobp\\b|\\bslugging\\b|\\bslg\\b" low then
            let val ab = ratOf (valOf abS) in
              if has "\\bslugging\\b|\\bslg\\b" low then
                (case (st low ["singles", "1b"], st low ["doubles", "2b"], st low ["triples", "3b"],
                       st low ["home runs?", "hr", "homers"]) of
                   (s1, SOME s2, SOME s3, SOME hr) =>
                     (case (s1, h) of
                        (NONE, NONE) => NONE
                      | _ => SOME (M.SpSlg (s1, getOpt (h, zero), s2, s3, hr, ab)))
                 | _ => NONE)
              else if has "\\bon[- ]base\\b|\\bobp\\b" low then
                (case h of
                   NONE => NONE
                 | SOME hh =>
                     SOME (M.SpObp (hh, getOpt (st low ["walks?", "bb"], zero),
                                    getOpt (st low ["hit by pitch(?:es)?", "hbp"], zero),
                                    getOpt (st low ["sacrifice flies", "sac flies", "sf"], zero), ab)))
              else (case h of NONE => NONE | SOME hh => SOME (M.SpAvg (hh, ab)))
            end
          else if has "\\bgames behind\\b|\\bgames back\\b|\\bgb\\b" low then
            (case findall "\\b(\\d+)\\s*-\\s*(\\d+)\\b" low of
               a :: b :: _ =>
                 SOME (M.SpGamesBehind (rawRat (g1 low a), rawRat (valOf (grp low a 2)), rawRat (g1 low b), rawRat (valOf (grp low b 2))))
             | _ => NONE)
          else if has "\\bwin(?:ning)? percentage\\b|\\bwin pct\\b|\\bwin rate\\b" low then
            let
              val recm = search "\\b(\\d+)\\s*-\\s*(\\d+)(?:\\s*-\\s*(\\d+))?\\b" low
              val w = st low ["wins", "w"] and l = st low ["losses", "l"]
              val tie = getOpt(st low ["ties", "draws", "t"],zero)
              val totals = case (w,l,recm) of
                  (SOME ws,SOME ls,_) => SOME(ws,ls,tie)
                | (_,_,SOME m) => SOME(rawRat(g1 low m),rawRat(valOf(grp low m 2)),
                    case grp low m 3 of SOME v=>rawRat v | NONE=>zero)
                | _ => NONE
            in
              Option.map M.SpWinPct totals
            end
          else NONE
        end
    end

  fun sports text : M.request option =
    if Narrow.narrative text then NONE
    else
      case sportsInner text of
        NONE => NONE
      | SOME r => if not (M.answered (M.reply_of r)) andalso not (Narrow.short_direct text) then NONE else SOME r

  (* ---------- fleet ---------- *)
  val MPG = NUM ^ "\\s*(?:us\\s+)?(uk\\s+|imperial\\s+)?mpg\\b|" ^ NUM ^ "\\s*miles per (?:us\\s+)?(imperial\\s+)?gallon\\b"
  val LPK = NUM ^ "\\s*(?:l|liters?|litres?)\\s*(?:/|per)\\s*100\\s*km\\b"

  fun fleetInner text : M.request option =
    let
      val t = collapse text
      val low = lower t
      val mpg = search MPG low
      val lpk = search LPK low
    in
      if has "\\bstopping distance\\b|\\bdistance to stop\\b|\\bhow far .* to stop\\b|\\bbraking distance\\b" low then
        let
          val v = search (NUM ^ "\\s*(km/h|kph|mph|m/s)\\b") low
          val mu = search ("\\b(?:friction(?: coefficient)?|coefficient of friction|mu|\206\188)\\s*(?:of|is|=)?\\s*" ^ NUM) low
          val rt = search ("\\breaction time\\s*(?:of|is|=)?\\s*" ^ NUM ^ "\\s*(?:s|sec|seconds?)\\b|" ^ NUM ^ "\\s*(?:s|sec|seconds?)\\s*reaction\\b") low
        in
          case (v, mu) of
            (SOME mv, SOME mm) =>
              let
                val unit = case valOf (grp low mv 2) of "mph" => M.SU_mph | "m/s" => M.SU_ms | _ => M.SU_kmh
                val vv = SOME (ratOf (g1 low mv), unit)
                val muv = SOME (ratOf (g1 low mm))
              in
                if has "\\bbraking distance\\b" low andalso not (has "\\bstopping distance\\b" low) then SOME (M.FvBraking (vv, muv))
                else SOME (M.FvStopping (vv, muv, Option.map (fn m => ratOf (valOf (firstGroup low m [1, 2]))) rt))
              end
          | _ => SOME (M.FvBraking (NONE, NONE))
        end
      else
        let
          val dist = search (NUM ^ "\\s*(miles?|mi|km|kilometers?|kilometres?)\\b(?!\\s*(?:per|/)\\s*(?:hour|h|gallon|liter|litre))")
                            (substCI "100\\s*km|miles per (?:us\\s+|imperial\\s+)?gallon" "" low)
          val ukOf = fn m => isSome (grp low m 2) orelse isSome (grp low m 4)
          val mpgVal = fn m => ratOf (valOf (firstGroup low m [1, 3]))
        in
          if not (isSome dist) andalso (isSome mpg orelse isSome lpk)
             andalso has "\\bconvert\\b|\\bl/100\\s*km\\b|\\bliters? per 100|\\blitres? per 100|\\bmpg\\b|\\bmiles per gallon\\b" low then
            (if isSome mpg andalso has "l/100|liters? per 100|litres? per 100" low then
               SOME (M.FvToLpk (ukOf (valOf mpg), mpgVal (valOf mpg)))
             else if isSome lpk andalso has "\\bmpg\\b|miles per gallon" low then
               SOME (M.FvToMpg (has "\\buk\\b|\\bimperial\\b" low, ratOf (g1 low (valOf lpk))))
             else NONE)
          else if isSome dist andalso (isSome mpg orelse isSome lpk)
                  andalso has "\\bfuel\\b|\\bgas\\b|\\bgallons?\\b|\\bliters?\\b|\\blitres?\\b|\\bcost\\b|\\bco2\\b|\\bcarbon\\b|\\bemissions?\\b|\\bspend\\b" low then
            let
              val dm = valOf dist
              val dlow = substCI "100\\s*km|miles per (?:us\\s+|imperial\\s+)?gallon" "" low
              val d = ratOf (g1 dlow dm)
              val du = if String.isPrefix "mi" (valOf (grp dlow dm 2)) then M.DU_mi else M.DU_km
              val ec = case mpg of
                         SOME m => M.E_mpg (ukOf m, mpgVal m)
                       | NONE => M.E_lpk (ratOf (g1 low (valOf lpk)))
            in
              if has "\\bco2\\b|\\bcarbon\\b|\\bemissions?\\b" low then SOME (M.FvCO2 (d, du, ec, has "diesel" low))
              else if has "\\bcost\\b|\\bspend\\b|\\bhow much money\\b|\\bprice\\b" low then
                let
                  val price = search ("\\$\\s*" ^ NUM ^ "\\s*(?:per|/|a)\\s*(gallon|gal|liter|litre|l)\\b") low
                  val pr = Option.map (fn m => (ratOf (g1 low m), String.isPrefix "gal" (valOf (grp low m 2)))) price
                in SOME (M.FvCost (d, du, ec, pr)) end
              else if has "\\bliters?\\b|\\blitres?\\b" low andalso not (has "\\bgallons?\\b" low) then SOME (M.FvLitres (d, du, ec))
              else SOME (M.FvGallons (d, du, ec))
            end
          else NONE
        end
    end

  fun fleet text : M.request option =
    if Narrow.narrative text then NONE
    else
      case fleetInner text of
        NONE => NONE
      | SOME r => if not (M.answered (M.reply_of r)) andalso not (Narrow.short_direct text) then NONE else SOME r

  (* ---------- fluids-r2 ---------- *)
  val fluidRx = ["(?:fresh |pure )?water", "sea ?water|salt water|the sea|the ocean|ocean", "mercury",
                 "petrol|gasoline", "diesel", "ethanol", "olive oil", "honey", "milk"]
  val fluidPats = zipChecked (fluidRx, M.fluid_order, "fluid_order")
  val solidPats = zipChecked (["ice", "aluminium", "steel", "concrete", "glass", "granite", "iron", "copper", "gold",
                               "lead", "brass"], M.solid_order, "solid_order")
  val DEPTH = NUM ^ "\\s*(" ^ LEN ^ ")\\b(?!\\s*/|\\s*per|\\s*\\^|\\s*3|" ^ cube ^ ")\\s*(?:deep|down|below|under|beneath|depth)?"
  val fluidVolPats = [(NUM ^ "\\s*(?:m3|m\\^3|m" ^ cube ^ "|cubic met(?:re|er)s?)", M.VU_m3),
                      (NUM ^ "\\s*(?:litres?|liters?|l)\\b", M.VU_l),
                      (NUM ^ "\\s*(?:cm3|cm\\^3|cm" ^ cube ^ "|cubic centimet(?:re|er)s?)", M.VU_cm3)]
  val fFresh = List.nth (M.fluid_order, 0)
  val fSea = List.nth (M.fluid_order, 1)
  fun one [x] = SOME x | one _ = NONE

  fun fluidOf low =
    let
      val found = List.mapPartial (fn (p, f) => if has ("\\b(?:" ^ p ^ ")\\b") low then SOME f else NONE) fluidPats
      val found = if List.exists (fn f => f = fSea) found andalso List.exists (fn f => f = fFresh) found
                  then List.filter (fn f => f <> fFresh) found else found
    in one found end

  (* These requests carry fixed table density, g0 and (for absolute pressure)
     p0. Supplied conditions must not be dropped when this simpler reader wins.
     Richer sibling models may answer; this reader makes its limitation explicit. *)
  fun suppliedFluidConditions low =
    has "\\b(?:gravity|density|densities|rho|specific gravity)\\b|\\bg\\s*(?:=|is|of|qnum)" low orelse
    has "\\b(?:surface|atmospheric|ambient|external|initial) (?:absolute )?pressure\\b|\\bp[ _]?0\\b" low
  fun fluidOperation ask low =
    (has "\\bpressure\\b" ask andalso has "\\b(?:deep|depth|below|under|beneath|down)\\b" low) orelse
    has "\\bbuoyan\\w*\\b|\\bupthrust\\b" ask orelse
    (has "\\b(?:fraction|percent(?:age)?|how much)\\b.*\\b(?:below|under|submerged|beneath)\\b" ask andalso has "\\bfloat" low)

  fun fluidsV1 text : M.request option =
    let val t = collapse text
    in
      if t = "" orelse Narrow.narrative t then NONE
      else
        let
          val low = lower t
          val ask = lower (Narrow.last_sentence t)
          val fl = fluidOf low
          fun need r = if Narrow.short_direct t then SOME r else NONE
        in
          if isSome fl andalso fluidOperation ask low andalso suppliedFluidConditions low
          then need M.FsModelLimit
          else if has "\\bpressure\\b" ask andalso has "\\b(?:deep|depth|below|under|beneath|down)\\b" low then
            (case fl of
               NONE => NONE
             | SOME f =>
                 let
                   val ds = map (fn m => M.length_m (ratOf (g1 low m)) (lenUnit (valOf (grp low m 2)))) (findall DEPTH low)
                   val absolute = has "\\b(?:absolute|total)\\b" low
                   val d = one ds
                   val r = if absolute then M.FsAbs (f, d) else M.FsGauge (f, d)
                 in if length(findall NUM low) > length ds then need M.FsModelLimit
                    else if length ds = 1 then SOME r else need r end)
          else if has "\\bbuoyan\\w*\\b|\\bupthrust\\b" low andalso has "\\bforce\\b|\\bupthrust\\b|\\bhow much\\b" ask then
            (case fl of
               NONE => NONE
             | SOME f =>
                 let
                   val vs = List.concat (map (fn (p, u) => map (fn m => (ratOf (g1 low m), u)) (findall p low)) fluidVolPats)
                   val r = M.FsBuoyant (f, one vs)
                 in if length(findall NUM low) > length vs then need M.FsModelLimit
                    else if length vs = 1 then SOME r else need r end)
          else if has "\\b(?:fraction|percent(?:age)?|how much)\\b.*\\b(?:below|under|submerged|beneath)\\b" ask
                  andalso has "\\bfloat" low then
            (case fl of
               NONE => NONE
             | SOME f =>
                 if not(null(findall NUM low)) then need M.FsModelLimit else
                 (case List.mapPartial (fn (p, s) => if has ("\\b" ^ p ^ "\\b") low then SOME s else NONE) solidPats of
                    [s] => SOME (M.FsSubmerged (s, f))
                  | _ => NONE))
          else NONE
        end
    end

  (* names_narrowing_v1.named_not_material: a material word that appears only capitalised mid-sentence is a name *)
  fun escape s = String.translate (fn c => if Char.isAlphaNum c then String.str c else "\\" ^ String.str c) s
  fun prefixOk p =
    let
      fun rtrim cs = case cs of c :: rest => if Char.isSpace c then rtrim rest else cs | [] => []
      val core = rev (rtrim (rev (String.explode p)))
    in p = "" orelse (length core < size p andalso not (null core) andalso Char.contains ".!?" (List.last core)) end

  fun namedNotMaterial t words =
    let
      val low = lower t
      fun check w =
        let
          val hits = findall ("\\b" ^ escape (lower w) ^ "\\b") low
          val first = fn ({start, ...} : Regex.match) => String.sub (t, start)
          val lowerHits = List.filter (fn m => Char.isLower (first m)) hits
          val midCaps = List.filter (fn (m as {start, ...} : Regex.match) =>
                                       Char.isUpper (first m) andalso not (prefixOk (String.substring (t, 0, start)))) hits
        in not (null midCaps) andalso null lowerHits end
    in List.exists check words end

  fun fluidsR2 text : M.request option =
    let
      val t = text
      val low = lower t
      val words = List.concat (map (fn (p, _) =>
        map (fn (m as {start, stop, ...} : Regex.match) => String.substring (t, start, stop - start))
            (findall ("\\b(?:" ^ p ^ ")\\b") low)) fluidPats)
    in
      if not (null words) andalso namedNotMaterial t words then NONE else fluidsV1 text
    end

  (* ---------- dispatch ---------- *)
  val organs = ["physics", "physics-r2", "physics-r3", "mechanisms", "mechanisms-v2", "bodies-v2", "sports", "fleet", "fluids-r2"]

  fun byId "physics" = physicsV1
    | byId "physics-r2" = physicsR2
    | byId "physics-r3" = physicsR3
    | byId "mechanisms" = mechV1
    | byId "mechanisms-v2" = mechV2
    | byId "bodies-v2" = bodiesV2
    | byId "sports" = sports
    | byId "fleet" = fleet
    | byId "fluids-r2" = fluidsR2
    | byId other = raise Fail ("unknown specialist " ^ other)

  (* The family: each manifest's organ in a fixed order, the first that takes the question answers it.
     Narrow, named-domain organs first; physics-r3 (the broad one) last. *)
  val familyOrder = ["fluids-r2", "bodies-v2", "fleet", "sports", "mechanisms-v2", "physics-r3"]

  (* Structured scores and baseball innings are not decimal quantities.
     Protect those spans, mask all other complete numeric tokens once,
     then restore their original notation before semantic parsing. *)
  fun prepare text =
    let
      val low = lower text
      val innings = "(?<![\\w.,/+\\-])\\d+(?:\\.\\d+)?\\s*(?:innings(?: pitched)?|ip)\\b"
      val records = "(?<![\\w.,/+\\-])\\d+\\s*-\\s*\\d+(?:\\s*-\\s*\\d+)?(?![\\w/+\\-]|[.,][0-9])"
      val unitDenominator = "\\b(?:l|liters?|litres?)\\s*(?:/|per)\\s*100\\s*km\\b"
      val patterns = [unitDenominator] @ (if has "\\bera\\b|\\bwhip\\b|\\bearned run average\\b" low then [innings] else [])
        @ (if has "\\bgames (?:behind|back)\\b|\\bgb\\b|\\bwin(?:ning)? (?:percentage|pct|rate)\\b" low then [records] else [])
      fun protect (pattern,(current,saved)) =
        let
          val hits = findall pattern (lower current)
          fun fresh marker = if String.isSubstring (lower marker) (lower text) orelse List.exists(fn (m,_)=>m=marker) saved
                             then fresh(marker ^ "q") else marker
          fun go pos [] pairs acc = (String.concat(rev(String.extract(current,pos,NONE)::acc)),pairs)
            | go pos (({start,stop,...}:Regex.match)::rest) pairs acc =
                let val marker = fresh("qstructured" ^ Int.toString(length pairs) ^ "q")
                    val raw = String.substring(current,start,stop-start)
                in go stop rest ((marker,raw)::pairs)
                     (marker::String.substring(current,pos,start-pos)::acc) end
        in go 0 hits saved [] end
      val (protected,saved) = List.foldl protect (text,[]) patterns
    in
      case ExactNumeric.mask protected of
        NONE => NONE
      | SOME {text=masked,numbers} => SOME {text=List.foldl(fn((marker,raw),acc)=>substCI marker raw acc) masked saved, numbers=numbers}
    end

  fun recognizePrepared mode text =
    if mode = "family" then
      let fun go [] = NONE
            | go (id :: ids) = case byId id text of SOME r => SOME (id, r) | NONE => go ids
      in go familyOrder end
    else Option.map (fn r => (mode, r)) (byId mode text)
    handle InvalidNumeric => NONE

  fun recognize mode text =
    case prepare text of
      NONE => NONE
    | SOME {text=prepared,numbers} =>
        let val previous = !numericValues
            val _ = numericValues := numbers
            val result = (recognizePrepared mode prepared
              handle e => (numericValues := previous; raise e))
            val _ = numericValues := previous
        in result end
end
