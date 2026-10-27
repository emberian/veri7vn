(* UNTRUSTED. The English recognizer for the space family: a hand port of the
   regular expressions and branch order of
     upstream/root/specialists/orbits/organ_orbits_v1.py            (OrbitsOrgan)
     upstream/root/specialists/planetary/organ_planetary_v1.py      (PlanetaryOrgan)
     upstream/root/specialists/spacecraft/organ_spacecraft_v1.py    (SpacecraftOrgan)
     upstream/root/specialists/spacecomms/organ_spacecomms_v1.py    (SpaceCommsOrgan)
     upstream/root/specialists/astronomy/organ_astronomy_v1.py      (AstronomyOrgan)
     upstream/root/specialists/astronomy-v2/organ_astronomy_v2.py   (AstronomyOrganV2)
     upstream/root/specialists/astronomy-v3/organ_astronomy_v3.py   (AstronomyOrganV3)
     upstream/root/specialists/astronomy-v3-r2/organ_astronomy_v3_r2.py (boundary patch)
   and of their shared narrowing rule narrow_v1.py. It reads numbers and words
   off the question and builds a typed Space.request; it computes nothing about
   the answer. Every value, decline and response text comes from the verified HOL
   kernel (Space.reply_of). NONE means the question is not taken (the organ
   returns None).

   Matching is case-insensitive by lower-casing the text; patterns are written in
   lower case and passed to Regex.compile as written. \w and \d are ASCII here.

   Additional safeguards and representation differences from the original port:
   - patterns with the non-ASCII letters delta (dv) are dropped (the engine is
     byte-wise, so \b around them would differ);
   - complete shared numeric tokens retain signs and exact values; declared
     path/altitude units are converted by the exported typed distance function;
   - where the organs raise (an exception inside the Oracle7 head, counted as
     "not taken") the recognizer returns NONE: an astronomy ratio of a non-positive
     quotient (log10 of it), a Hohmann question whose second altitude cannot be
     found. Planetary non-positive mass/radius reaches the kernel's refusal;
   - orbits and spacecraft/spacecomms narrowing: a withheld reply is returned only
     for a short direct question, as the organs do (answer() in each organ). *)
structure Recognizer :
sig
  val organs : string list
  val recognize : string -> string -> (string * Space.reply) option
end =
struct
  structure S = Space

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
  fun startOf (m : Regex.match) = #start m

  fun collapse s = String.concatWith " " (String.tokens Char.isSpace s)

  exception InvalidNumeric
  val numericValues : (string * ExactNumeric.rational) list ref = ref []
  fun rationalOf token = case List.find(fn(k,_)=>k=token)(!numericValues) of
      SOME(_,value)=>value | NONE=>raise InvalidNumeric
  fun ratOf token = let val(n,d)=rationalOf token in S.mk_rat n d end
  val ratE = ratOf

  (* ---------- narrow_v1 (copied from lane G's recognizer) ---------- *)
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
    val RELATION = "\\b(?:qnum[0-9]+q|one|two|three|four|five|six|seven|eight|nine|ten)\\s+(?:\\w+\\s+){0,2}"
      ^ "(?:more|less|fewer|longer|shorter)\\s+than\\b|\\b(?:twice|three times|half)\\s+(?:as\\s+\\w+\\s+as\\s+)?the\\s+\\w+\\b"
    val RATE = "\\bqnum[0-9]+q\\s+[a-z]+\\s+(?:for|per|every)\\s+(?:qnum[0-9]+q|a|an|one|each)\\s+[a-z]+"
    fun narrative t =
      let val low = lower t
      in sentences t >= 3 orelse words t > 40 orelse has RELATION low orelse has RATE low end
    fun short_direct t = sentences t <= 2 andalso words t <= 25 andalso not (narrative t)
  end

  val N = "(qnum[0-9]+q)"

  (* the organs' answer(): a withheld reply is returned only for a short direct question *)
  (* A successful narrowed recognizer returns exactly the request whose reply
     it saved. call below captures that reply before another recognizer runs. *)
  val checkedReply : S.reply option ref = ref NONE
  fun narrowed t req =
    let val reply = S.reply_of req
        val _ = checkedReply := SOME reply
    in if S.answered reply then SOME req
       else if Narrow.short_direct t then SOME req else NONE end

  (* ---------- orbits ---------- *)
  val orbitBodies = [("earth", S.O_earth), ("moon", S.O_moon), ("mars", S.O_mars),
                     ("sun", S.O_sun), ("jupiter", S.O_jupiter), ("venus", S.O_venus)]

  fun orbitBody low =
    let
      val found = List.mapPartial (fn (n, b) =>
        case search ("\\b" ^ n ^ "\\b") low of SOME m => SOME (startOf m, b) | NONE => NONE) orbitBodies
      fun best [] = NONE
        | best ((p, b) :: r) = (case best r of SOME (q, c) => if q < p then SOME (q, c) else SOME (p, b) | NONE => SOME (p, b))
    in Option.map #2 (best found) end

  (* The same typed distance conversion serves paths and orbit altitudes. *)
  val ORBIT_LEN = "(?:km|kilomet(?:er|re)s?|mi|miles?|m|met(?:er|re)s?)"
  val LENGTH_END = "\\b(?!\\s*/|\\s*per\\b|\\s*\\^)"
  fun distanceUnit u = if String.isPrefix "mi" u then S.Db_mile
    else if u="m" orelse String.isPrefix "met" u then S.Db_m else S.Db_km
  fun orbitAlts low =
    map (fn m => (startOf m,
      S.dkm(S.Dist(ratOf(g1 low m),S.Ds_one,distanceUnit(valOf(grp low m 2))))))
      (findall (N ^ "\\s*(" ^ ORBIT_LEN ^ ")" ^ LENGTH_END) low)

  fun orbits text =
    let
      val t = collapse text
      val low = lower t
    in
      if Narrow.narrative t then NONE
      else if not (has "\\borbit\\w*\\b|\\bescape velocity\\b|\\bhohmann\\b|\\bdelta[- ]?v\\b|\\bgeostationary\\b|\\bgeosynchronous\\b|\\bsynchronous orbit\\b|\\bareostationary\\b" low) then NONE
      else
        let
          val body =
            case orbitBody low of
              SOME b => SOME b
            | NONE => if has "\\bgeostationary\\b|\\bleo\\b|\\biss\\b" low then SOME S.O_earth else NONE
        in
          case body of
            NONE => narrowed t (S.OSpeed (NONE, NONE))
          | SOME b =>
              let
                val ob = SOME b
                val alts = orbitAlts low
              in
                if has "\\bgeostationary\\b|\\bgeosynchronous\\b|\\bsynchronous orbit\\b|\\bareostationary\\b" low then
                  narrowed t (S.OSync ob)
                else if has "\\bhohmann\\b|\\btransfer\\b" low
                        andalso has "\\bdelta[- ]?v\\b|\\bburns?\\b|\\bhow long\\b|\\btransfer time\\b" low then
                  let
                    val time = has "\\bhow long\\b|\\btransfer time\\b|\\btime\\b" low andalso not (has "\\bdelta[- ]?v\\b" low)
                    fun mk p = if time then S.OHohTime (ob, p) else S.OHohDv (ob, p)
                  in
                    if length alts < 2 then narrowed t (mk NONE)
                    else
                      (case search ("\\bfrom\\b[^.?]*?" ^ N ^ "\\s*" ^ ORBIT_LEN ^ LENGTH_END) low of
                         SOME fm =>
                           let
                             val s1 = case #groups fm of g => (case Vector.sub (g, 1) of SOME (a, _) => a | NONE => ~1)
                           in
                             case (List.find(fn(p,_)=>p=s1) alts,List.find(fn(p,_)=>p<>s1) alts) of
                               (SOME(_,a1),SOME(_,a2)) => narrowed t (mk (SOME(a1,a2)))
                             | _ => NONE
                           end
                       | NONE => narrowed t (mk (SOME (#2 (List.nth (alts, 0)), #2 (List.nth (alts, 1))))))
                  end
                else if has "\\bescape velocity\\b|\\bescape speed\\b" low then
                  narrowed t (S.OEscape (ob,
                    if not (null alts) andalso has "\\baltitude\\b|\\babove\\b|\\bfrom (?:an? )?orbit\\b|\\bat qnum" low
                    then SOME (#2 (hd alts)) else NONE))
                else if has "\\bspeed\\b|\\bvelocity\\b|\\bhow fast\\b|\\bperiod\\b|\\bhow long\\b.*\\borbit\\b|\\btake to orbit\\b" low then
                  let
                    val period = has "\\bperiod\\b|\\bhow long\\b|\\btake\\b" low
                    val alt = case alts of [] => NONE | (_, a) :: _ => SOME a
                  in narrowed t (if period then S.OPeriod (ob, alt) else S.OSpeed (ob, alt)) end
                else NONE
              end
        end
    end

  (* ---------- planetary ---------- *)
  fun planetary text =
    let
      val t = collapse text
      val low = lower t
    in
      if t = "" orelse Narrow.narrative t then NONE
      else if not (has "\\bplanet\\w*\\b|\\bmoon\\b|\\basteroid\\b|\\bexoplanet\\b|\\bdwarf planet\\b|\\bbody\\b|\\bworld\\b|\\bsatellite\\b" low) then NONE
      else
        let
          val mE = search (N ^ "\\s*(?:times (?:the )?earth'?s? mass|earth masses|m_?e\\b|m\226\138\149)") low
          val rE = search (N ^ "\\s*(?:times (?:the )?earth'?s? radius|earth radii|r_?e\\b|r\226\138\149)") low
          val body =
            case (mE, rE) of
              (SOME a, SOME b) =>
                SOME (S.Pb_earth (ratOf (g1 low a), ratOf (g1 low b)), true)
            | _ =>
              let
                val mm = search (N ^ "\\s*kg\\b") low
                val rm = search ("\\bradius\\s*(?:of|is|=)?\\s*" ^ N ^ "\\s*(km|m)" ^ LENGTH_END ^ "|" ^ N ^ "\\s*(km|m)\\s*(?:in\\s+)?radius\\b") low
              in
                case (mm, rm) of
                  (SOME m, SOME r) =>
                    let val ri = if isSome(grp low r 1) then 1 else 3
                        val unit = valOf(grp low r (ri+1))
                    in SOME(S.Pb_si(ratOf(g1 low m),ratOf(valOf(grp low r ri)),
                         if unit="km" then S.Lu_km else S.Lu_m),false) end
                | _ => NONE
              end
        in
          case body of
            NONE => NONE
          | SOME (b, isEarth) =>
              if has "\\bescape (?:velocity|speed)\\b" low then SOME (S.PEscape b)
              else if has "\\borbital (?:velocity|speed)\\b|\\bcircular (?:orbit )?(?:velocity|speed)\\b" low then SOME (S.POrbV b)
              else if has "\\bdensity\\b" low then SOME (S.PDensity b)
              else if has "\\bweigh\\w*\\b" low then
                (if isEarth then
                   (case (b, search (N ^ "\\s*(?:kg|kilograms?)\\b") low) of
                      (S.Pb_earth (m, r), SOME wm) => SOME (S.PWeightE (m, r, ratOf (g1 low wm)))
                    | _ => NONE)
                 else NONE)
              else if has "\\bgravity\\b|\\bgravitational acceleration\\b|\\bsurface g\\b|\\bacceleration due to gravity\\b" low then SOME (S.PGravity b)
              else NONE
        end
    end

  (* ---------- spacecraft ---------- *)
  val MASS = "\\s*(kg|kilograms?|t|tonnes?|metric tons?)\\b"
  fun massU u = if u = "t" orelse String.isPrefix "tonne" u orelse String.isPrefix "metric" u then S.Mu_t else S.Mu_kg
  fun forceU u =
    if u = "kn" orelse String.isPrefix "kilonewton" u then S.Fu_kn
    else if u = "mn" orelse String.isPrefix "meganewton" u then S.Fu_mn else S.Fu_n

  fun spacecraft text =
    let
      val t = collapse text
      val low = lower t
    in
      if Narrow.narrative t then NONE
      else if not (has "\\brocket\\b|\\bspacecraft\\b|\\bdelta[- ]?v\\b|\\bisp\\b|\\bspecific impulse\\b|\\bthrust\\b|\\bpropellant\\b|\\bexhaust velocity\\b|\\bengine\\b|\\bstage\\b" low) then NONE
      else
        let
          val isp = search ("\\b(?:isp|specific impulse)\\s*(?:of|is|=|:)?\\s*" ^ N ^ "\\s*(?:s|sec\\w*)?\\b|" ^ N ^ "\\s*(?:s|seconds?)\\s*(?:isp|specific impulse)\\b") low
          val veM = search ("\\bexhaust (?:velocity|speed)\\s*(?:of|is|=)?\\s*" ^ N ^ "\\s*(km/s|m/s)") low
          val ve =
            case (isp, veM) of
              (SOME m, _) => SOME (S.Ve_isp (ratOf (valOf (firstGroup low m [1, 2]))))
            | (NONE, SOME m) => SOME (S.Ve_speed (ratOf (g1 low m), if valOf (grp low m 2) = "km/s" then S.Su_kmps else S.Su_mps))
            | _ => NONE
          val m0 = search ("\\b(?:initial|wet|fueled|fuelled|launch|total|starting|gross) mass\\s*(?:of|is|=)?\\s*" ^ N ^ MASS
                           ^ "|" ^ N ^ MASS ^ "\\s*(?:initial|wet|fueled|fuelled|total mass|starting mass|at launch|fully fueled)") low
          val mf = search ("\\b(?:final|dry|empty|burnout|end) mass\\s*(?:of|is|=)?\\s*" ^ N ^ MASS
                           ^ "|" ^ N ^ MASS ^ "\\s*(?:final|dry|empty|at burnout)") low
          fun massOf m = if isSome (grp low m 1) then (ratOf (g1 low m), massU (valOf (grp low m 2)))
                         else (ratOf (valOf (grp low m 3)), massU (valOf (grp low m 4)))
          val M0 = Option.map massOf m0
          val MF = Option.map massOf mf
          val thrust = search (N ^ "\\s*(kn|mn|n|newtons?|kilonewtons?|meganewtons?)\\b(?!\\s*/)\\s*(?:of\\s+)?(?:thrust)?|\\bthrust\\s*(?:of|is|=)?\\s*"
                               ^ N ^ "\\s*(kn|mn|n|newtons?|kilonewtons?|meganewtons?)\\b") low
          val F =
            case thrust of
              SOME m => if has "\\bthrust\\b|\\bengine (?:of|rated at)\\b" low then
                          (if isSome (grp low m 1) then SOME (ratOf (g1 low m), forceU (valOf (grp low m 2)))
                           else SOME (ratOf (valOf (grp low m 3)), forceU (valOf (grp low m 4))))
                        else NONE
            | NONE => NONE
          fun take req = narrowed t req
        in
          if isSome isp andalso has "\\bexhaust velocity\\b|\\beffective exhaust\\b" low
             andalso has "\\bwhat\\b|\\bfind\\b|\\bcalculate\\b|\\bconvert\\b|\\?" low andalso not (isSome M0) andalso not (isSome F) then
            (case ve of SOME (S.Ve_isp i) => take (S.SExhaust i) | _ => NONE)
          else if isSome F andalso has "\\bthrust[- ]to[- ]weight\\b|\\btwr\\b" low then
            let
              val mm = case M0 of
                         SOME x => SOME x
                       | NONE =>
                           (case search ("\\b(?:mass|weighs|weighing)\\s*(?:of|is)?\\s*" ^ N ^ MASS ^ "|" ^ N ^ MASS ^ "\\s*(?:rocket|vehicle|spacecraft|lander)") low of
                              SOME m => SOME (massOf m)
                            | NONE => NONE)
            in
              case (F, mm) of
                (SOME (f, fu), SOME (mv, mu)) => take (S.STwr (f, fu, mv, mu))
              | _ => NONE
            end
          else if isSome F andalso isSome ve
                  andalso has "\\bmass flow\\b|\\bburn time\\b|\\bhow long\\b|\\bburn for\\b|\\bpropellant (?:flow|consumption)\\b" low then
            let val (f, fu) = valOf F val v = valOf ve in
              if has "\\bburn time\\b|\\bhow long\\b|\\bburn for\\b" low then
                (case search (N ^ MASS ^ "\\s*(?:of\\s+)?(?:propellant|fuel)|\\b(?:propellant|fuel)\\s*(?:mass\\s*)?(?:of|is|=)?\\s*" ^ N ^ MASS) low of
                   SOME pm => let val (pv, pu) = massOf pm in take (S.SBurn (f, fu, v, pv, pu)) end
                 | NONE => NONE)
              else take (S.SMassFlow (f, fu, v))
            end
          else
            let
              val dvM = search ("\\b(?:delta[- ]?v)\\s*(?:of|is|=)?\\s*" ^ N ^ "\\s*(km/s|m/s)|" ^ N ^ "\\s*(km/s|m/s)\\s*(?:of\\s+)?(?:delta[- ]?v|burn|maneuver|manoeuvre)") low
            in
              if isSome dvM andalso isSome ve andalso has "\\bpropellant\\b|\\bfuel\\b" low
                 andalso has "\\bhow much\\b|\\bmass of propellant\\b|\\bpropellant mass\\b|\\bneeded\\b|\\brequired\\b" low then
                let
                  val m = valOf dvM
                  val (dv, du) = if isSome (grp low m 1) then (ratOf (g1 low m), valOf (grp low m 2))
                                 else (ratOf (valOf (grp low m 3)), valOf (grp low m 4))
                  val duu = if du = "km/s" then S.Su_kmps else S.Su_mps
                  val v = valOf ve
                in
                  case (M0, MF) of
                    (SOME (mv, mu), _) => take (S.SProp0 (v, dv, duu, mv, mu))
                  | (NONE, SOME (mv, mu)) => take (S.SPropF (v, dv, duu, mv, mu))
                  | _ => NONE
                end
              else if isSome ve andalso isSome M0 andalso isSome MF
                      andalso has "\\bdelta[- ]?v\\b|\\bchange in velocity\\b|\\bvelocity change\\b" low then
                let val (a, au) = valOf M0 val (b, bu) = valOf MF
                in take (S.SDeltaV (valOf ve, a, au, b, bu)) end
              else NONE
            end
        end
    end

  (* ---------- spacecomms ---------- *)
  val NE = N

  fun commsDist low : S.dist option =
    case search (NE ^ "\\s*(au|astronomical units?)" ^ LENGTH_END) low of
      SOME m => SOME (S.Dist (ratE (g1 low m), S.Ds_one, S.Db_au))
    | NONE =>
      (case search (NE ^ "\\s*(million|billion)\\s*(km|kilomet(?:er|re)s?|miles?|m|met(?:er|re)s?)" ^ LENGTH_END) low of
         SOME m =>
           SOME (S.Dist (ratE (g1 low m), if valOf (grp low m 2) = "million" then S.Ds_million else S.Ds_billion,
                         distanceUnit(valOf(grp low m 3))))
       | NONE =>
         (case search (NE ^ "\\s*(km|kilomet(?:er|re)s?|miles?|m|met(?:er|re)s?)" ^ LENGTH_END) low of
            SOME m => SOME (S.Dist (ratE (g1 low m), S.Ds_one, distanceUnit(valOf(grp low m 2))))
          | NONE => NONE))

  fun rateU u =
    if u = "bps" orelse u = "bit/s" then S.Ru_bps
    else if u = "kbps" orelse u = "kbit/s" then S.Ru_kbps
    else if u = "mbps" orelse u = "mbit/s" then S.Ru_mbps else S.Ru_gbps

  fun spacecomms text =
    let
      val t = collapse text
      val low = lower t
    in
      if Narrow.narrative t then NONE
      else if not (has "\\bsignal\\b|\\blight\\b|\\bradio\\b|\\bdelay\\b|\\blatency\\b|\\bround[- ]trip\\b|\\blink\\b|\\bdownlink\\b|\\buplink\\b|\\bspacecraft\\b|\\bprobe\\b|\\brover\\b|\\bpath loss\\b|\\bfspl\\b|\\bbits? in flight\\b" low) then NONE
      else
        let
          val rate = case search (NE ^ "\\s*(bps|kbps|mbps|gbps|bit/s|kbit/s|mbit/s|gbit/s)\\b") low of
                       SOME m => SOME (ratE (g1 low m), rateU (valOf (grp low m 2)))
                     | NONE => NONE
          fun take req = narrowed t req
        in
          if has "\\bpath loss\\b|\\bfspl\\b" low then
            let
              val d = commsDist low
              val fm = case search (NE ^ "\\s*(hz|khz|mhz|ghz)\\b") low of
                         SOME m => SOME (ratE (g1 low m),
                                         case valOf (grp low m 2) of "hz" => S.Fq_hz | "khz" => S.Fq_khz | "mhz" => S.Fq_mhz | _ => S.Fq_ghz)
                       | NONE => NONE
            in take (S.CFspl (d, fm)) end
          else
            (case search (NE ^ "\\s*(kb|mb|gb|tb|kbit|mbit|gbit|bits?)\\b") low of
               SOME sm =>
                 if isSome rate andalso has "\\bhow long\\b|\\btime\\b|\\bsend\\b|\\btransfer\\b|\\bdownlink\\b|\\bupload\\b|\\bdownload\\b" low
                    andalso not (has "\\bdelay\\b|\\blatency\\b|\\blight\\b" low) then
                   let
                     val unit = valOf (grp low sm 2)
                     val (us, ue) = case Vector.sub (#groups sm, 2) of SOME x => x | NONE => (0, 0)
                     val rawLast = String.sub (t, ue - 1)
                     val isBytes = (unit = "kb" orelse unit = "mb" orelse unit = "gb" orelse unit = "tb") andalso rawLast = #"B"
                     val pre = case unit of
                                 "kb" => S.Dp_k | "mb" => S.Dp_m | "gb" => S.Dp_g | "tb" => S.Dp_t
                               | "kbit" => S.Dp_k | "mbit" => S.Dp_m | "gbit" => S.Dp_g | _ => S.Dp_one
                     val (r, ru) = valOf rate
                   in take (S.CXfer (ratE (g1 low sm), pre, isBytes, r, ru)) end
                 else spacecommsRest t low rate take
             | NONE => spacecommsRest t low rate take)
        end
    end
  and spacecommsRest t low rate take =
    if has "\\bbits? in flight\\b|\\bin transit\\b" low then
      take (S.CBits (commsDist low, rate))
    else if has "\\bhow long\\b|\\bdelay\\b|\\blatency\\b|\\blight[- ]time\\b|\\btravel time\\b|\\btake\\b" low then
      take (S.CLight (commsDist low, has "\\bround[- ]trip\\b|\\bthere and back\\b|\\bto get a reply\\b|\\breply\\b|\\bresponse\\b" low))
    else NONE


  (* ---------- astronomy (v1, v2, v3, v3-r2) ---------- *)
  val abodies = [("mercury", S.A_mercury), ("venus", S.A_venus), ("earth", S.A_earth), ("moon", S.A_moon),
                 ("mars", S.A_mars), ("jupiter", S.A_jupiter), ("saturn", S.A_saturn),
                 ("uranus", S.A_uranus), ("neptune", S.A_neptune), ("pluto", S.A_pluto)]

  fun replaceAll p rep s =
    let
      fun go i [] acc = String.concat (rev (String.extract (s, i, NONE) :: acc))
        | go i (({start, stop, ...} : Regex.match) :: ms) acc =
            go stop ms (rep :: String.substring (s, i, start - i) :: acc)
    in go 0 (findall p s) [] end

  val EARTH_UNIT = "\\bearth\\s+(?:years?|days?|hours?|masses|mass units|radii|diameters|gravities)\\b"

  (* the bodies named in the text, first by position; skip one body *)
  fun bodyIn low (skip : S.abody option) : S.abody option =
    let
      val found = List.mapPartial (fn (n, b) =>
        if Option.map (fn s => s = b) skip = SOME true then NONE
        else case search ("\\b" ^ n ^ "\\b") low of SOME m => SOME (startOf m, b) | NONE => NONE) abodies
      fun best [] = NONE
        | best ((p, b) :: r) = (case best r of SOME (q, c) => if q < p then SOME (q, c) else SOME (p, b) | NONE => SOME (p, b))
    in Option.map #2 (best found) end

  val props = [
    (S.P_mass, "\\bmass\\b|\\bhow (?:heavy|massive)\\b"),
    (S.P_diameter, "\\bdiameter\\b|\\bhow (?:big|wide|large)\\b"),
    (S.P_density, "\\bdensity\\b"),
    (S.P_gravity, "\\bgravity\\b|\\bgravitational acceleration\\b"),
    (S.P_escape, "\\bescape velocity\\b"),
    (S.P_day, "\\blength of (?:a |the )?day\\b|\\bhow long is (?:a |the )?day\\b|\\bday length\\b"),
    (S.P_rotation, "\\brotation period\\b|\\bhow long .* to (?:rotate|spin)\\b"),
    (S.P_distance, "\\bdistance from the sun\\b|\\bhow far .* from the sun\\b|\\bfrom the sun\\b"),
    (S.P_period, "\\borbital period\\b|\\bhow long .* to orbit\\b|\\blength of (?:a |its )?year\\b|\\bhow long is (?:a |its |the )?year\\b|\\byear in (?:earth )?days\\b"),
    (S.P_velocity, "\\borbital (?:velocity|speed)\\b"),
    (S.P_eccentricity, "\\beccentricity\\b"),
    (S.P_tilt, "\\b(?:axial )?tilt\\b|\\bobliquity\\b"),
    (S.P_temperature, "\\b(?:mean |average )?temperature\\b|\\bhow (?:hot|cold)\\b"),
    (S.P_pressure, "\\b(?:surface |atmospheric )?pressure\\b"),
    (S.P_moons, "\\bhow many moons\\b|\\bnumber of moons\\b|\\bmoons? does\\b"),
    (S.P_rings, "\\brings?\\b"),
    (S.P_magnetic, "\\bmagnetic field\\b")]

  fun firstProp low exclude =
    Option.map #1 (List.find (fn (p, pat) => not (List.exists (fn x => x = p) exclude) andalso has pat low) props)

  val KNOWN_FAKE = "\\b(?:vulcan|nibiru|planet x|krypton|tatooine|arrakis|pandora|gallifrey|cybertron|mongo)\\b"
  val COMPARE = "\\bhow many times\\b|\\bby what factor\\b|\\bwhat factor\\b|\\bratio\\b|\\bcompared? (?:to|with)\\b|"
    ^ "\\brelative to\\b|\\bexceeds?\\b|\\bdivided by\\b|\\bversus\\b|\\bvs\\.?\\b|\\btimes (?:more|larger|bigger|heavier|greater|as)\\b"
  val SIZE = "\\b(?:larger|bigger|wider|large|big|wide|diameter|size)\\b"
  val REF = "\\b(?:relative to|compared? (?:to|with)|than|exceeds?|divided by|versus|vs\\.?|over)\\s+(?:the\\s+)?(?:planet\\s+)?([a-z]+)"
    ^ "|\\bratio of\\s+(?:the\\s+)?[^,?]*?\\bto\\s+(?:the\\s+)?([a-z]+)"
  val NOT_MINE = "\\bqnum[0-9]+q\\s*(?:x|times)\\s+(?:the\\s+)?(?:earth|jupiter|sun|moon)'?s?\\b|\\ba (?:rocky |gas )?planet with\\b|\\ba moon with\\b"

  fun title s =
    String.concatWith " " (map (fn w =>
      if w = "" then w else String.str (Char.toUpper (String.sub (w, 0))) ^ lower (String.extract (w, 1, NONE)))
      (String.fields (fn c => c = #" ") s))

  (* sign and zero-ness of a sheet number, from its printed text *)
  fun cellSign (c : S.cell) : (bool * bool) option =   (* (negative, zero) *)
    case c of
      S.Cnum (s, _, _) =>
        (case ExactNumeric.parse s of SOME(n,_)=>SOME(n<0,n=0) | NONE=>NONE)
    | _ => NONE

  datatype res = Fall | Take of S.request | Crash

  (* UNTRUSTED role parser. A year count, source planet, target planet and
     every supplied period must be consumed by this grammar. Unused conditions
     cannot fall through to a one-year NASA property lookup. All arithmetic
     on the accepted count/periods is performed by AYearConvert in HOL. *)
  fun yearConversion low : res =
    let
      val count = "(qnum[0-9]+q|zero|one|two|three|four|five|six|seven|eight|nine|ten|an?)"
      val body = "([a-z]+)"
      val tail = "[?.! ]*$"
      (* Captures are reordered into source, target, count below. *)
      val patterns = [
        ("\\bhow many " ^ body ^ " years? (?:are|is|equal|in) " ^ count ^ " " ^ body ^ " years?" ^ tail, (3,1,2)),
        ("\\bhow many " ^ body ^ " years? (?:are|is) " ^ count ^ " years? on " ^ body ^ tail, (3,1,2)),
        ("\\b(?:convert|express) " ^ count ^ " " ^ body ^ " years? (?:to|into|in) " ^ body ^ " years?" ^ tail, (2,3,1)),
        ("\\bhow many " ^ body ^ " years? (?:does|do) " ^ count ^ " years? on " ^ body ^ " last" ^ tail, (3,1,2)),
        ("\\bhow many " ^ body ^ " years? (?:is|are) " ^ count ^ " orbits? of " ^ body ^ tail, (3,1,2)),
        ("\\b" ^ count ^ " " ^ body ^ " years? (?:in|to|into) " ^ body ^ " years?" ^ tail, (2,3,1)),
        ("\\b" ^ count ^ " " ^ body ^ " years? (?:is|are) how many " ^ body ^ " years?" ^ tail, (2,3,1))]
      fun first [] = NONE
        | first ((pat,groups)::rest) = case search pat low of
            SOME m => SOME(m,groups) | NONE => first rest
      fun planet name = case List.find(fn(n,b)=>n=name andalso b<>S.A_moon) abodies of
          SOME(_,b)=>b | NONE=>raise InvalidNumeric
      val words = [("zero",0),("one",1),("two",2),("three",3),("four",4),("five",5),
                   ("six",6),("seven",7),("eight",8),("nine",9),("ten",10),("a",1),("an",1)]
      fun quantity token = case List.find(fn(w,_)=>w=token) words of
          SOME(_,n)=>(IntInf.fromInt n,1:IntInf.int) | NONE=>rationalOf token
      fun rat(n,d) = S.mk_rat n d
      fun equal((a,b):ExactNumeric.rational,(c,d):ExactNumeric.rational) = a*d=c*b
      val cue = has "\\bhow many [a-z]+ years?\\b|\\b(?:to|into|in) [a-z]+ years?\\b" low
      val explicit = has "\\b(?:qnum[0-9]+q|zero|two|three|four|five|six|seven|eight|nine|ten)\\b" low orelse has "\\bdays?\\b" low
    in case first patterns of
      NONE => if cue andalso explicit then Crash else Fall
    | SOME(m,(sg,tg,cg)) =>
      let
        val src = planet(valOf(grp low m sg))
        val dst = planet(valOf(grp low m tg))
        val n = rat(quantity(valOf(grp low m cg)))
        val prefix = String.substring(low,0,#start m)
        val days = N ^ "\\s+(?:earth\\s+)?days?\\b"
        val definitions = [
          body ^ "\\s+takes\\s+" ^ days ^ "(?:\\s+to orbit (?:the )?sun)?",
          "(?:an? |one )?" ^ body ^ "(?:'s)?\\s+(?:orbital period|year)\\s+(?:is|lasts|takes|=|of)\\s+" ^ days,
          "(?:a |one )?year on\\s+" ^ body ^ "\\s+(?:is|lasts|takes)\\s+" ^ days]
        fun consume [] remaining periods = (remaining,periods)
          | consume (pat::rest) remaining periods =
            let
              fun bind (pm,ps) =
                let val b = planet(g1 remaining pm)
                    val value = rationalOf(valOf(grp remaining pm 2))
                    val _ = if b=src orelse b=dst then () else raise InvalidNumeric
                in case List.find(fn(c,_)=>c=b) ps of
                     NONE => (b,value)::ps
                   | SOME(_,old) => if equal(value,old) then ps else raise InvalidNumeric
                end
              val ps = List.foldl bind periods (findall pat remaining)
            in consume rest (replaceAll pat " " remaining) ps end
        val (remaining,periods) = consume definitions prefix []
        val rest = replaceAll "\\b(?:and|given|assume|assuming|that|use)\\b|[\\s.,;:]" "" remaining
        val _ = if rest="" then () else raise InvalidNumeric
        fun period b = case List.find(fn(c,_)=>b=c) periods of
            SOME(_,value)=>rat value
          | NONE=>if b=S.A_earth then S.mk_rat 36525 100 else S.cell_num(S.sheet b S.P_period)
      in Take(S.AYearConvert(src,dst,n,period src,period dst)) end
    end handle InvalidNumeric=>Crash

  (* the ratio of two sheet values; v1 reads mass or diameter only *)
  fun ratioReq style subj refb prop =
    case (cellSign (S.sheet subj prop), cellSign (S.sheet refb prop)) of
      (SOME (na, za), SOME (nb, zb)) =>
        if zb then Fall
        else if za orelse (na <> nb) then Crash     (* v2: log10 of a non-positive quotient raises *)
        else Take (S.ARatio (style, subj, refb, prop))
    | _ => Fall

  fun v1 (strip : bool) t low : S.request option =
    let
      val blow = if strip then replaceAll EARTH_UNIT " " low else low
      fun bodyOf skip = bodyIn blow skip
    in
      if has KNOWN_FAKE low andalso has "\\b(?:planet|moon|gravity|mass|orbit|day|year|sun|diameter)\\b" low then
        let val m = valOf (search KNOWN_FAKE low)
        in SOME (S.AFake (title (String.substring (t, #start m, #stop m - #start m)))) end
      else
        case bodyOf NONE of
          NONE => NONE
        | SOME body =>
          let
            val wm = search (N ^ "\\s*(kg|kilograms?|lbs?|pounds?)\\b") low
            val weightHit =
              if isSome wm andalso has "\\bweigh\\b|\\bweight\\b" low then
                let val tgt = (case bodyOf (SOME S.A_earth) of SOME b => b | NONE => body)
                    val m = valOf wm
                in if tgt <> S.A_earth
                   then SOME (S.AWeight (ratOf (g1 low m), if String.isPrefix "k" (valOf (grp low m 2)) then S.Wu_kg else S.Wu_lb, tgt))
                   else NONE end
              else NONE
          in
            case weightHit of
              SOME r => SOME r
            | NONE =>
              if has "\\b(?:sun)?light\\b" low andalso has "\\bsun(?:light)?\\b" low andalso body <> S.A_moon then
                SOME (S.ALight body)
              else
                let
                  val m2 = search "\\bhow many times (?:more |larger|bigger|heavier|more massive|wider)?\\s*(massive|heavy|heavier|large|larger|big|bigger|wide|wider)?\\b" low
                  val other = bodyOf (SOME body)
                in
                  if isSome m2 andalso isSome other then
                    SOME (S.ARatio (S.Rs_v1, body, valOf other,
                                    if has "\\b(?:larger|bigger|wider|large|big|wide|diameter)\\b" low then S.P_diameter else S.P_mass))
                  else if has "\\bin earth years\\b|\\bhow many earth years\\b" low then SOME (S.AYears body)
                  else if body = S.A_moon andalso has "\\bhow far\\b|\\bdistance\\b" low then SOME S.AMoonKm
                  else
                    case firstProp low [] of
                      NONE => NONE
                    | SOME p => if body = S.A_moon andalso p = S.P_distance then SOME S.AMoonKkm else SOME (S.AProp (body, p))
                end
          end
    end

  (* v2: any comparison phrasing; the subject is the first body named *)
  fun v2cmp t low : res =
    if not (has COMPARE low) then Fall
    else
      let val blow = replaceAll EARTH_UNIT " " low in
        case bodyIn blow NONE of
          NONE => Fall
        | SOME body =>
          (case bodyIn blow (SOME body) of
             NONE => Fall
           | SOME other =>
               let
                 val prop = firstProp low [S.P_rings, S.P_magnetic]
                 val key = case prop of
                             NONE => if has SIZE low then S.P_diameter else S.P_mass
                           | SOME p => p
               in ratioReq S.Rs_v2 body other key end)
      end

  (* v3: the reference body is read from the comparison's grammar *)
  fun v3cmp t low : res =
    if not (has COMPARE low) then Fall
    else
      let
        val blow = replaceAll EARTH_UNIT " " low
        val refw = List.mapPartial (fn m =>
          let val w = valOf (firstGroup low m [1, 2])
          in List.find (fn (n, _) => n = w) abodies end) (findall REF low)
      in
        case refw of
          [] => Fall
        | (_, refb) :: _ =>
            (case bodyIn blow (SOME refb) of
               NONE => Fall
             | SOME subj =>
                 if subj = refb then Fall
                 else
                   let
                     val prop = firstProp low [S.P_rings, S.P_magnetic]
                     val key = case prop of
                                 NONE => if has SIZE low then S.P_diameter else S.P_mass
                               | SOME p => p
                   in ratioReq S.Rs_v2 subj refb key end)
      end

  fun astroV2 t low =
    case v2cmp t low of Take r => SOME r | Crash => NONE | Fall => v1 true t low
  fun astroV3 t low =
    case v3cmp t low of Take r => SOME r | Crash => NONE | Fall => astroV2 t low

  (* SI force symbols keep their case. A standalone lower-case n can be a
     name or variable and is not silently interpreted as a newton. None of
     these force requests may use the table's kg-equivalent weight output. *)
  fun forceUnit original low =
    has "\\bnewtons?\\b" low orelse
    List.exists (fn (m : Regex.match) =>
      let val symbol = String.substring (original, #start m, #stop m - #start m)
      in List.exists (fn unit => symbol = unit) ["N", "kN", "mN", "MN"] end)
      (findall "\\b(?:n|kn|mn)\\b" low)

  fun astro variant text =
    let val t = collapse text in
      if t = "" then NONE
      else
        let val low = lower t in
          (* All public versions now use the grammatical comparison direction.
             Earth years is a unit; Earth's year still names the subject.
             kg-equivalent weight must never answer a force-in-newtons request,
             and a fluid's pressure is not a planet's atmospheric pressure. *)
          if has NOT_MINE low
             orelse (has "\\bweigh\\w*\\b" low andalso forceUnit t low)
             orelse (has "\\bmercury\\b" low andalso
                     (has "\\b(?:liquid|fluid|metal|diver|depth|submerged|buoyant)\\b" low orelse
                      has "\\b(?:solid|metallic|molten|gaseous|vaporous) mercury\\b|\\bmercury (?:vapou?r|gas|metal)\\b" low))
          then NONE else case yearConversion low of
            Take r => SOME r | Crash => NONE | Fall => astroV3 t low
        end
    end

  (* ---------- dispatch ---------- *)
  val organs = ["orbits", "planetary", "spacecraft", "spacecomms", "astronomy", "astronomy-v2",
                "astronomy-v3", "astronomy-v3-r2"]

  fun byId "orbits" = orbits
    | byId "planetary" = planetary
    | byId "spacecraft" = spacecraft
    | byId "spacecomms" = spacecomms
    | byId "astronomy" = astro "v1"
    | byId "astronomy-v2" = astro "v2"
    | byId "astronomy-v3" = astro "v3"
    | byId "astronomy-v3-r2" = astro "r2"
    | byId other = raise Fail ("unknown specialist " ^ other)

  (* Numerical satellite requests outrank table properties, including a
     recognized satellite question that lacks its required altitude. Surface
     escape calculations use mu/r; NASA property queries retain the NASA cell.
     This is UNTRUSTED interpretation, over requests, never answer values. *)
  fun explicitOrbit (S.OSpeed (_, SOME _)) = true
    | explicitOrbit (S.OPeriod (_, SOME _)) = true
    | explicitOrbit (S.OEscape (_, SOME _)) = true
    | explicitOrbit (S.OSync _) = true
    | explicitOrbit (S.OHohDv _) = true
    | explicitOrbit (S.OHohTime _) = true
    | explicitOrbit _ = false
  fun orbitalSubject text req =
    let val low = lower text in
      explicitOrbit req orelse
      has "\\b(?:spacecraft|satellite|iss|leo|circles?)\\b" low orelse
      (case req of S.OEscape _ => has "\\bsurface\\b" low andalso not (has "\\bnasa\\b" low)
                 | _ => false)
    end
  fun explicitComms (S.CLight (NONE, _)) = false
    | explicitComms _ = true

  (* One checked reply per successful recognizer. In this module narrowed is
     the only producer of checkedReply, and returns its identical request.
     Call-local capture prevents subsequent candidates from replacing it. *)
  fun call id text =
    let val _ = checkedReply := NONE
        val req = byId id text
        val reply = !checkedReply
    in Option.map (fn r => (id, r, reply)) req end

  fun family text =
    case yearConversion (lower (collapse text)) of
      Take r => SOME ("astronomy-v3-r2", r, NONE)
    | Crash => NONE
    | Fall => familyOther text
  and familyOther text =
    case call "planetary" text of SOME x => SOME x
    | NONE => (case call "spacecraft" text of SOME x => SOME x
      | NONE => let
          val orbital = call "orbits" text
          fun rest () =
            let val comms = call "spacecomms" text
                fun tableOrFallback () =
                  case call "astronomy-v3-r2" text of SOME x => SOME x
                  | NONE => (case orbital of SOME x => SOME x | NONE => comms)
            in case comms of SOME (x as (_, r, _)) =>
                 if explicitComms r then SOME x else tableOrFallback ()
               | NONE => tableOrFallback () end
        in case orbital of SOME (x as (_, r, _)) =>
             if orbitalSubject text r then SOME x else rest ()
           | NONE => rest () end)

  fun recognizePrepared mode text =
    Option.map (fn (id, req, saved) =>
      (id, case saved of SOME reply => reply | NONE => S.reply_of req))
      (if mode = "family" then family text else call mode text)

  (* Scientific multiplication is structured syntax, separate from the shared
     decimal lexer. Its mantissa is lexer-issued, its exponent is parsed whole,
     and malformed expressions reject the entire question before role parsing. *)
  fun scientificText text =
    let
      val opRx = "(?:x|\195\151|\\*)\\s*10\\s*\\^\\s*"
      val operators = length(findall opRx (lower text))
      fun expression (ExactNumeric.Malformed _) = NONE
        | expression (ExactNumeric.Number {start,stop,value=(n,d)}) =
          let val rest = String.extract(text,stop,NONE)
          in case search ("^\\s*" ^ opRx) (lower rest) of
               NONE => NONE
             | SOME ({stop=afterOp,...}:Regex.match) =>
               let val exponentText = String.extract(rest,afterOp,NONE)
               in case search "^([+-]?[0-9]+)(?=\\s|$|[?;,]|kg\\b|km\\b|m\\b)" exponentText of
                    NONE => raise InvalidNumeric
                  | SOME em =>
                    let val raw=g1 exponentText em
                        val exponent=case ExactNumeric.parse raw of
                          SOME(e,one)=>if one=1 andalso IntInf.abs e<=10000 then IntInf.toInt e else raise InvalidNumeric
                        | NONE=>raise InvalidNumeric
                        val scaled=if exponent>=0 then (n*IntInf.pow(10,exponent),d)
                                   else (n,d*IntInf.pow(10,~exponent))
                    in SOME(start,stop+afterOp+ #stop em,ExactNumeric.canonical scaled) end
               end
          end
      val expressions=List.mapPartial expression (ExactNumeric.scan text)
      fun splice pos [] acc = String.concat(rev(String.extract(text,pos,NONE)::acc))
        | splice pos ((a,b,replacement)::rest) acc =
          if a<pos then raise InvalidNumeric
          else splice b rest (replacement::String.substring(text,pos,a-pos)::acc)
    in if length expressions=operators then SOME(splice 0 expressions []) else NONE end
    handle InvalidNumeric=>NONE

  fun recognize mode text =
    case scientificText text of NONE=>NONE
    | SOME normalized =>
      (case ExactNumeric.mask normalized of NONE=>NONE
       | SOME {text=prepared,numbers} =>
         let val previous= !numericValues
             val _=numericValues:=numbers
             val result=(recognizePrepared mode prepared handle InvalidNumeric=>NONE
                         | e=>(numericValues:=previous;raise e))
             val _=numericValues:=previous
         in result end)

end
