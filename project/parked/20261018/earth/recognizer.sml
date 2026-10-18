(* UNTRUSTED. The English recognizer for the earth family: a hand port of the
   regular expressions and branch order of
     upstream/root/specialists/geography/organ_geography_v1.py     (GeographyOrgan)
     upstream/root/specialists/geology/organ_geology_v1.py         (GeologyOrgan)
     upstream/root/specialists/seismology/organ_seismology_v1.py   (SeismologyOrgan)
     upstream/root/specialists/hydrology/organ_hydrology_v1.py     (HydrologyOrgan)
     upstream/root/specialists/ocean/organ_ocean_v1.py             (OceanOrgan)
     upstream/root/specialists/meteorology/organ_weather_v1.py     (WeatherOrgan)
     upstream/root/specialists/greenhouse/organ_greenhouse_v1.py   (GreenhouseOrgan)
     upstream/root/specialists/greenhouse-r2/organ_greenhouse_r2.py (boundary patch)
   and of their shared narrowing rule narrow_v1.py. It reads numbers and words
   off the question and builds a typed Earth.request; it computes nothing.
   Every value, decline and response text comes from the verified HOL kernel
   (Earth.reply_of). NONE means the question is not taken (the organ returns
   None). The one place this file decides anything the organs also decide is
   the narrowing wrapper "a decline is only taken for a short direct
   question", which asks the kernel (Earth.answers) whether the request would
   be declined.

   Matching is case-insensitive by lower-casing the text (patterns are written
   in lower case). \w and \d are ASCII here. Non-ASCII characters in the
   organs' patterns (the degree sign, the multiplication sign, micro, the
   superscript two) are matched as their UTF-8 bytes in groups.

   Completion: optional coefficient connectors in Gutenberg-Richter counts;
   invalid coordinate latitudes reach the kernel instead of being dropped.
   Other differences from the organs: a zero half-life,
   Manning n or wetted perimeter, a negative daughter-to-parent ratio, a zero
   flow rate reach the kernel, which declines them as impossible (the organ
   raises ZeroDivisionError or computes). *)
structure Recognizer :
sig
  val organs : string list
  val recognize : string -> string -> (string * Earth.request) option
end =
struct
  structure E = Earth

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
  fun gs s m g = valOf (grp s m g)
  fun firstGroup s m gs = case List.mapPartial (grp s m) gs of x :: _ => SOME x | [] => NONE
  fun collapse s = String.concatWith " " (String.tokens Char.isSpace s)

  (* ---------- exact decimal fractions (numerator, positive denominator) ---------- *)
  type fr = IntInf.int * IntInf.int
  fun norm ((n, d) : fr) : fr = if d < 0 then (IntInf.~ n, IntInf.~ d) else (n, d)
  fun frOf (lit0 : string) : fr =
    let
      val lit = String.translate (fn #"," => "" | c => String.str c) lit0
      val (neg, body) = if String.isPrefix "-" lit then (true, String.extract (lit, 1, NONE)) else (false, lit)
      val (ip, fp) = case String.fields (fn c => c = #".") body of
                       [a] => (a, "")
                     | [a, b] => (a, b)
                     | _ => raise Fail ("bad numeral " ^ lit0)
      val num = valOf (IntInf.fromString (ip ^ fp))
    in (if neg then IntInf.~ num else num, IntInf.pow (10, size fp)) end
  fun fint (i : IntInf.int) : fr = (i, 1)
  fun fmul ((a, b) : fr) ((c, d) : fr) : fr = norm (a * c, b * d)
  fun fdivide ((a, b) : fr) ((c, d) : fr) : fr = norm (a * d, b * c)
  fun fadd ((a, b) : fr) ((c, d) : fr) : fr = norm (a * d + c * b, b * d)
  fun fsub ((a, b) : fr) ((c, d) : fr) : fr = norm (a * d - c * b, b * d)
  fun fneg ((a, b) : fr) : fr = (IntInf.~ a, b)
  fun fabs ((a, b) : fr) : fr = (IntInf.abs a, b)
  fun fle ((a, b) : fr) ((c, d) : fr) = a * d <= c * b
  fun flt ((a, b) : fr) ((c, d) : fr) = a * d < c * b
  fun fpos x = flt (fint 0) x
  fun fzero ((a, _) : fr) = a = 0
  fun fq ((a, b) : fr) : E.rat = E.mk_rat a b
  fun fqo (x : fr option) : E.rat option = Option.map fq x
  fun frOfInt (i : int) : fr = fint (IntInf.fromInt i)
  fun fpow10 (k : int) : fr = if k >= 0 then (IntInf.pow (10, k), 1) else (1, IntInf.pow (10, ~k))

  val deg = "\194\176"
  val degOpt = "(?:" ^ deg ^ ")?"
  val degSp = "(?:" ^ deg ^ "\\s*|degrees?\\s*)?"
  val sq2 = "\194\178"
  fun startsWith p s = String.isPrefix p s
  fun countOcc pat s =
    let val n = size pat
        fun go i acc = if i + n > size s then acc
                       else if String.substring (s, i, n) = pat then go (i + n) (acc + 1) else go (i + 1) acc
    in go 0 0 end

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
    fun narrative t =
      let val low = lower t
      in sentences t >= 3 orelse words t > 40 orelse has RELATION low orelse has RATE low end
    fun short_direct t = sentences t <= 2 andalso words t <= 25 andalso not (narrative t)
  end

  (* a decline is only taken for a short direct question *)
  fun gate t (r : E.request option) =
    case r of
      NONE => NONE
    | SOME req => if Narrow.short_direct t orelse E.answers req then r else NONE

  (* ============================ geography ============================ *)
  val GN = "(-?\\d+(?:\\.\\d+)?)"
  val COORD = GN ^ "\\s*" ^ degOpt ^ "\\s*([ns])?\\s*,?\\s*" ^ GN ^ "\\s*" ^ degOpt ^ "\\s*([ew])?"
  val PT = "\\(?\\s*" ^ COORD ^ "\\s*\\)?"

  fun signed (v : string) (h : string option) (neg : string) : fr =
    let val x = frOf v
    in case h of SOME hh => if hh = neg then fneg (fabs x) else x | NONE => x end

  fun geography text =
    let
      val t = collapse text
    in
      if Narrow.narrative t then NONE
      else
        let
          val low = lower t
          val cm = search "\\bcapital (?:city )?of\\s+(?:the\\s+)?([a-z' .]+?)\\s*(?:\\?|$|\\.|,)|\\b([a-z' .]+?)'s capital\\b" low
          val bad = has "\\bcapital (?:gains|letter|punishment|expenditure|investment)\\b" low
        in
          case (cm, bad) of
            (SOME m, false) =>
              let
                val c = collapse (valOf (firstGroup low m [1, 2]))
              in if E.capital_known c then SOME (E.RGeo (E.GCapital c)) else NONE end
          | _ =>
            let
              val pts = List.mapPartial (fn m =>
                let
                  val h2 = grp low m 2
                  val h4 = grp low m 4
                  val cnt = countOcc deg (Regex.whole low m)
                  val lat = gs low m 1
                  val lon = gs low m 3
                  val latf = frOf lat
                  val lonf = frOf lon
                in
                  if ((isSome h2 andalso isSome h4) orelse cnt >= 2)
                     andalso fle (fint ~180) lonf andalso fle lonf (fint 180)
                  then SOME (signed lat h2 "s", signed lon h4 "w") else NONE
                end) (findall PT low)
              val two = length pts >= 2
            in
              if two andalso has "\\bdistance\\b|\\bhow far\\b|\\bkm\\b|\\bmiles\\b|\\bgreat[- ]circle\\b" low then
                let
                  val ((la1, lo1), (la2, lo2)) = (List.nth (pts, 0), List.nth (pts, 1))
                  val miles = has "\\bmiles\\b" low andalso not (has "\\bkm\\b|\\bkilomet" low)
                in SOME (E.RGeo (E.GGc (miles, fq la1, fq lo1, fq la2, fq lo2))) end
              else if length pts >= 1 andalso has "\\bantipod\\w*\\b|\\bopposite side of the (?:earth|globe|world)\\b" low then
                let val (la, lo) = hd pts in SOME (E.RGeo (E.GAntipode (fq la, fq lo))) end
              else
                let
                  val lons =
                    case map (fn m => signed (gs low m 1) (SOME (gs low m 2)) "w")
                             (findall (GN ^ "\\s*" ^ degOpt ^ "\\s*([ew])\\b") low) of
                      [] => map (fn m => frOf (g1 low m)) (findall ("\\blongitudes?\\s+(?:of\\s+)?" ^ GN) low)
                    | xs => xs
                in
                  if length lons >= 2
                     andalso has "\\btime difference\\b|\\bhours? (?:ahead|behind|apart|difference)\\b|\\bsolar time\\b|\\blocal time\\b" low
                  then SOME (E.RGeo (E.GSolar (fq (List.nth (lons, 0)), fq (List.nth (lons, 1)))))
                  else
                    let
                      val lats = findall (GN ^ "\\s*" ^ degOpt ^ "\\s*([ns])\\b") low
                    in
                      if length lats >= 2 andalso has "\\bnorth[- ]south\\b|\\bdistance\\b|\\bhow far\\b" low
                         andalso null lons andalso length pts < 2
                      then
                        let val a = signed (gs low (List.nth (lats, 0)) 1) (SOME (gs low (List.nth (lats, 0)) 2)) "s"
                            val b = signed (gs low (List.nth (lats, 1)) 1) (SOME (gs low (List.nth (lats, 1)) 2)) "s"
                        in if fle (fint ~90) a andalso fle a (fint 90)
                              andalso fle (fint ~90) b andalso fle b (fint 90)
                           then SOME (E.RGeo (E.GLat (fq a, fq b))) else NONE end
                      else NONE
                    end
                end
            end
        end
    end

  (* ============================ geology ============================ *)
  val N = "(\\d+(?:,\\d{3})*(?:\\.\\d+)?)"
  val YRX = "\\s*(billion years|million years|thousand years|years?|yr|kyr|myr|gyr|ma|ga)\\b"
  fun yearsMult (u : string) : IntInf.int =
    if u = "thousand years" orelse u = "kyr" then 1000
    else if u = "million years" orelse u = "myr" orelse u = "ma" then 1000000
    else if u = "billion years" orelse u = "gyr" orelse u = "ga" then 1000000000
    else 1

  fun halfOf low : E.hl =
    let
      fun given m = E.HlGiven (fq (fmul (frOf (g1 low m)) (fint (yearsMult (gs low m 2)))))
    in
      case search ("\\bhalf[- ]life\\s*(?:of|is|=)?\\s*" ^ N ^ YRX) low of
        SOME m => given m
      | NONE =>
          (case search (N ^ YRX ^ "\\s*half[- ]life") low of
             SOME m => given m
           | NONE =>
               if has "\\bcarbon[- ]?14\\b|\\bc[- ]?14\\b|\\bradiocarbon\\b" low then E.HlIso E.C14
               else if has "\\bpotassium[- ]?40\\b|\\bk[- ]?40\\b" low then E.HlIso E.K40
               else if has "\\buranium[- ]?238\\b|\\bu[- ]?238\\b" low then E.HlIso E.U238
               else if has "\\buranium[- ]?235\\b|\\bu[- ]?235\\b" low then E.HlIso E.U235
               else E.HlNone)
    end

  val WORDS : (string * fr) list =
    [("one-half", (1, 2)), ("one half", (1, 2)), ("half", (1, 2)), ("one-quarter", (1, 4)), ("one quarter", (1, 4)),
     ("a quarter", (1, 4)), ("one-eighth", (1, 8)), ("one eighth", (1, 8)), ("an eighth", (1, 8)),
     ("one-sixteenth", (1, 16)), ("one sixteenth", (1, 16))]

  fun geologyReq t =
    let
      val low = lower t
      val plateWords = has "\\bplates?\\b|\\bspreading\\b|\\brift\\w*\\b|\\bseafloor\\b|\\bcontinent\\w*\\b" low
                       andalso has "\\bcm\\s*(?:/|per|a)\\s*(?:yr|year)\\b|\\bmm\\s*(?:/|per|a)\\s*(?:yr|year)\\b|\\bhow fast\\b|\\brate\\b|\\bhow far\\b" low
      val plate =
        if not plateWords then NONE
        else
          let
            val rm = search (N ^ "\\s*(cm|mm)\\s*(?:/|per|a|each)\\s*(?:yr|year)\\b") low
            val dm = search (N ^ "\\s*(km|kilomet\\w+)\\b") low
            val tm = search (N ^ "\\s*(million years|myr|ma|thousand years|years?)\\b") low
            fun yrs m = fmul (frOf (g1 low m)) (fint (yearsMult (gs low m 2)))
          in
            case (rm, tm) of
              (SOME r, SOME tmm) =>
                if has "\\bhow far\\b|\\bdistance\\b|\\bhow many (?:km|kilomet)" low then
                  let val rate = fmul (frOf (g1 low r)) (fint (if gs low r 2 = "cm" then 10 else 1))
                  in SOME (SOME (E.RGeol (E.GlPlateDist (fq rate, fq (yrs tmm))))) end
                else (case dm of
                        SOME d =>
                          if has "\\brate\\b|\\bhow fast\\b|\\bspeed\\b|\\bcm (?:per|/|a) (?:yr|year)\\b" low
                          then let val y = yrs tmm
                               in if not (fpos y) then SOME NONE
                                  else SOME (SOME (E.RGeol (E.GlPlateRate (fq (frOf (g1 low d)), fq y)))) end
                          else NONE
                      | NONE => NONE)
            | _ =>
                (case (dm, tm) of
                   (SOME d, SOME tmm) =>
                     if has "\\brate\\b|\\bhow fast\\b|\\bspeed\\b|\\bcm (?:per|/|a) (?:yr|year)\\b" low
                     then let val y = yrs tmm
                          in if not (fpos y) then SOME NONE
                             else SOME (SOME (E.RGeol (E.GlPlateRate (fq (frOf (g1 low d)), fq y)))) end
                     else NONE
                 | _ => NONE)
          end
    in
      case plate of
        SOME r => r
      | NONE =>
        let
          val grad = search ("\\b(?:geothermal )?gradient\\s*(?:of|is|=)?\\s*" ^ N
                             ^ "\\s*(?:" ^ deg ^ "\\s*c|c|degrees?(?: c)?)\\s*(?:/|per)\\s*(km|kilomet\\w+)") low
        in
          case (grad, has "\\btemperature\\b|\\bhow hot\\b" low) of
            (SOME gm, true) =>
              let
                val dep = search ("\\b(?:depth of|at|down)\\s*" ^ N ^ "\\s*(km|kilomet\\w+|m|met\\w+)\\b|"
                                  ^ N ^ "\\s*(km|kilomet\\w+)\\s*(?:deep|down|below|depth)") low
                val srf = search ("\\bsurface (?:temperature\\s*)?(?:is|of|=)?\\s*(-?\\d+(?:\\.\\d+)?)\\s*(?:"
                                  ^ deg ^ "\\s*c|c\\b|degrees)") low
              in
                case (dep, srf) of
                  (SOME d, SOME s) =>
                    let
                      val (dv, du) = case grp low d 1 of SOME v => (v, gs low d 2) | NONE => (gs low d 3, gs low d 4)
                      val km = if startsWith "k" du then frOf dv else fdivide (frOf dv) (fint 1000)
                    in SOME (E.RGeol (E.GlDepthTemp (fq (frOf (g1 low gm)), fq km, fq (frOf (g1 low s))))) end
                | _ => NONE
              end
          | _ =>
            if not (has ("\\bhalf[- ]li(?:fe|ves)\\b|\\bdecay\\w*\\b|\\bradiometric\\b|\\bradiocarbon\\b|\\bisotope\\b|\\bparent\\b"
                         ^ "|\\bdaughter\\b|\\bcarbon[- ]?14\\b|\\bc[- ]?14\\b|\\buranium\\b|\\bpotassium[- ]?40\\b") low)
            then NONE
            else
              let
                val h = halfOf low
                val ratio = search ("\\bdaughter[- ]to[- ]parent (?:ratio )?(?:of|is|=)?\\s*" ^ N
                                    ^ "|\\bratio of daughter to parent (?:is|of|=)?\\s*" ^ N
                                    ^ "|\\bd\\s*/\\s*p\\s*(?:=|is|of)\\s*" ^ N) low
                val pm = case search (N ^ "\\s*%\\s*(?:of\\b[^.?]{0,40}?)?(?:remains|remaining|is left|left)\\b") low of
                           SOME m => SOME m
                         | NONE => search ("\\b(?:remaining|left|remains)\\b[^.?%]{0,15}?" ^ N ^ "\\s*%") low
                val wm = search ("\\b(one[- ]half|half|one[- ]quarter|a quarter|one[- ]eighth|an eighth|one[- ]sixteenth)\\b"
                                 ^ "[^.?]{0,40}?(?:remains|is left|left)\\b") low
                val frac : fr option =
                  case pm of
                    SOME m => SOME (fdivide (frOf (g1 low m)) (fint 100))
                  | NONE =>
                      (case wm of
                         SOME m => (case List.find (fn (k, _) => k = g1 low m) WORDS of SOME (_, v) => SOME v | NONE => NONE)
                       | NONE => NONE)
              in
                if has "\\bhow old\\b|\\bage\\b|\\bhow long ago\\b|\\bhow many years\\b|\\bdate\\b" low
                   andalso (isSome ratio orelse isSome frac)
                then
                  (case ratio of
                     SOME m =>
                       SOME (E.RGeol (E.GlAge (h, E.MRatio (fq (frOf (valOf (firstGroup low m [1, 2, 3])))))))
                   | NONE => SOME (E.RGeol (E.GlAge (h, E.MFrac (fq (valOf frac))))))
                else
                  let
                    val tm = search ("\\bafter\\s+" ^ N ^ YRX ^ "|" ^ N ^ YRX ^ "\\s*(?:later|have passed|pass|elapse)") low
                  in
                    case tm of
                      SOME m =>
                        if has "\\bhow much\\b|\\bwhat (?:fraction|percent\\w*|proportion)\\b|\\bremain\\w*\\b|\\bleft\\b" low
                        then
                          (case h of
                             E.HlNone => SOME (E.RGeol (E.GlLeft (E.HlNone, fq (fint 0))))
                           | _ =>
                             let
                               val (nv, uv) = case grp low m 1 of SOME v => (v, gs low m 2) | NONE => (gs low m 3, gs low m 4)
                             in SOME (E.RGeol (E.GlLeft (h, fq (fmul (frOf nv) (fint (yearsMult uv)))))) end)
                        else NONE
                    | NONE => NONE
                  end
              end
        end
    end

  fun geology text =
    let val t = collapse text
    in if Narrow.narrative t then NONE else gate t (geologyReq t) end

  (* ============================ seismology ============================ *)
  exception UnknownSeismoNumber
  val seisToken = "(qnum[0-9]+q)"

  (* Separate compact magnitude labels from quantities before shared lexing.
     M0= remains the seismic-moment label, not a magnitude. *)
  fun separateMagnitudeLabels raw =
    let
      val matches = findall "\\b(?:mw|ml|m(?!0\\s*=))(?=[+\\-]?(?:[0-9]|\\.[0-9]))" raw
      fun go pos [] acc = String.concat (rev (String.extract(raw,pos,NONE)::acc))
        | go pos ((m:Regex.match)::ms) acc =
            go (#stop m) ms (" "::String.substring(raw,pos,#stop m-pos)::acc)
    in go 0 matches [] end

  fun seismologyReq t =
    let
      val raw = String.translate (fn #"^" => "^ " | c => String.str c) (separateMagnitudeLabels (lower t))
      val spGoal = has "\\bs\\s*-\\s*p\\b|\\bp[- ]?waves?\\b.*\\bs[- ]?waves?\\b|\\bs[- ]?waves?\\b.*\\bp[- ]?waves?\\b" raw
        andalso has "\\bdistance\\b|\\bhow far\\b|\\bepicenter\\b|\\bepicentre\\b" raw
      val grGoal = has "\\bgutenberg\\b|\\bb[- ]value\\b|\\ba[- ]value\\b|\\bhow many (?:earthquakes|quakes)\\b" raw
        andalso has "\\bper year\\b|\\bhow many\\b|\\bexpected number\\b|\\bannual\\b" raw
      val context = has "\\bearthquakes?\\b|\\bquakes?\\b|\\bmagnitude\\b|\\bseismic\\b|\\bseismogram\\b|\\brichter\\b|\\bs-p\\b|\\bp[- ]waves?\\b|\\bs[- ]waves?\\b|\\bgutenberg\\b" raw
    in
      if not context orelse has "\\bpredict\\w*\\b|\\bforecast\\w*\\b|\\bwhen will\\b|\\bnext (?:big )?(?:earthquake|quake)\\b" raw then NONE
      else case ExactNumeric.mask raw of NONE => NONE
      | SOME {text=low,numbers} =>
        let
          fun rational marker = case List.find (fn (name,_) => name=marker) numbers of
              SOME (_,q) => q | NONE => raise UnknownSeismoNumber
          fun quantity marker = fq (rational marker)
          fun unique pat groups = case findall pat low of
              [m] => SOME (quantity (valOf (firstGroup low m groups))) | _ => NONE
          val unitEnd = "(?![A-Za-z0-9_^]|\\s*(?:/|\\*|\\^|\194\183|per\\b))"
          fun speed wave = unique
            ("\\b" ^ wave ^ "[- ]?waves?\\s*(?:travel\\w*|speed|velocity|move\\w*)?\\s*(?:of|at|is|=)?\\s*" ^ seisToken ^ "\\s*km\\s*/\\s*s" ^ unitEnd
             ^ "|" ^ seisToken ^ "\\s*km\\s*/\\s*s" ^ unitEnd ^ "\\s*(?:for\\s+)?(?:the\\s+)?" ^ wave ^ "[- ]?waves?") [1,2]
          val magnitudePattern = "\\b(?:magnitude|mag\\.?|m|mw|ml)\\s*(?:of\\s*|=\\s*)?" ^ seisToken ^ "\\b" ^ unitEnd
          val magnitudeMatches = findall magnitudePattern low
          val suffixMatches = findall (seisToken ^ "\\s*(?:magnitude|earthquake|quake)\\b") low
          val magnitudes = if null magnitudeMatches then suffixMatches else magnitudeMatches
          val momentPattern = "\\b(?:seismic )?moment\\s*(?:of|is|=|m0)?\\s*(?:m0\\s*=\\s*)?" ^ seisToken
            ^ "(?:\\s*(?:x|\195\151|\\*)\\s*" ^ seisToken ^ "\\s*\\^\\s*" ^ seisToken ^ ")?"
            ^ "\\s*(?:n\\s*(?:\194\183|[.*])?\\s*m|newton[- ]met(?:er|re)s?)" ^ unitEnd
          val moments = findall momentPattern low
          fun momentValue m =
            let val v = rational (g1 low m) in
              case grp low m 2 of NONE => SOME (fq v)
              | SOME base =>
                  if rational base <> (10,1) orelse #2(rational(gs low m 3)) <> 1 then NONE
                  else case ExactNumeric.parse ("1e" ^ ExactNumeric.canonical (rational (gs low m 3))) of
                    SOME factor => SOME (fq (fmul v factor)) | NONE => NONE
            end
          val energy = has "\\benergy\\b|\\bjoules?\\b" low
          val amplitude = has "\\bamplitude\\b|\\bshaking\\b|\\bground motion\\b|\\bwave height\\b|\\bseismogram\\b" low
        in
          if spGoal then SOME (E.RSeis (E.SeSP
            (unique (seisToken ^ "\\s*(?:s\\b|sec\\w*\\b)" ^ unitEnd) [1],speed "p",speed "s")))
          else if grGoal then SOME (E.RSeis (E.SeGR
            (unique ("\\ba\\s*(?:[- ]?value)?\\s*(?:of|is|=)?\\s*" ^ seisToken) [1],
             unique ("\\bb\\s*(?:[- ]?value)?\\s*(?:of|is|=)?\\s*" ^ seisToken) [1],
             unique ("\\bmagnitude\\s*(?:of\\s*)?(?:>=|\226\137\165|at least|or (?:greater|more|larger)|)\\s*" ^ seisToken
               ^ "|" ^ seisToken ^ "\\s*or (?:greater|more|larger|above)") [1,2])))
          else if not (null moments) then
            (case moments of [m] =>
               if has "\\bmoment magnitude\\b|\\bmw\\b|\\bmagnitude\\b" low
               then Option.map (fn q => E.RSeis(E.SeMw q)) (momentValue m) else NONE
             | _ => NONE)
          else if has "\\bseismic moment\\b" low andalso has "\\bwhat\\b|\\bfind\\b|\\bhow (?:much|large)\\b|\\bcalculate\\b" low then
            (case magnitudes of [m] => SOME(E.RSeis(E.SeM0(quantity(g1 low m)))) | _ => NONE)
          else if length magnitudes=2 andalso
              has "\\bhow many times\\b|\\bhow much (?:more|stronger|bigger|larger)\\b|\\bratio\\b|\\bfactor\\b|\\btimes (?:more|stronger|larger|bigger)\\b" low then
            let val a=quantity(g1 low(hd magnitudes)) val b=quantity(g1 low(List.nth(magnitudes,1))) in
              if energy andalso not amplitude then SOME(E.RSeis(E.SeEnergy(a,b)))
              else if amplitude andalso not energy then SOME(E.RSeis(E.SeAmp(a,b)))
              else SOME(E.RSeis(E.SeAsk(a,b)))
            end
          else NONE
        end handle UnknownSeismoNumber => NONE
    end

  fun seismology text =
    let val t=collapse text
    in if Narrow.narrative t then NONE else seismologyReq t end

  (* ============================ hydrology ============================ *)
  fun legacyHydrologyReq t =
    let
      val low = lower t
      fun og m = Option.map (fn x => fq (frOf (g1 low x))) m
    in
      if has "\\brain\\w*\\b" low andalso has "\\bharvest|\\bcollect|\\bcatch|\\broof\\b|\\bgallons?\\b|\\blit(?:er|re)s?\\b" low
              andalso has "\\bhow much\\b|\\bhow many\\b" low then
        let
          val rin = search (N ^ "\\s*(inch|inches|in|mm|millimet(?:er|re)s?)\\b(?! ?/)") low
          val area = search (N ^ "\\s*(sq\\.? ?ft|square feet|square foot|ft2|m2|square met(?:er|re)s?|sq\\.? ?m)\\b") low
          val eff = case search (N ^ "\\s*%\\s*(?:collection )?(?:efficien\\w*|capture)") low of
                      SOME m => SOME m
                    | NONE => search ("\\befficiency\\s*(?:of|is)?\\s*" ^ N ^ "\\s*%") low
          val sys =
            case (rin, area) of
              (SOME r, SOME a) =>
                let val ru = gs low r 2
                    val au = gs low a 2
                in if startsWith "in" ru andalso (startsWith "sq" au orelse startsWith "square f" au orelse startsWith "ft" au)
                   then E.HUS
                   else if startsWith "m" ru andalso (startsWith "m" au orelse startsWith "square m" au orelse startsWith "sq" au)
                   then E.HSI else E.HMix
                end
            | _ => E.HMix
        in SOME (E.RHydro (E.HyHarvest (og rin, og area, og eff, sys))) end
      else if has "\\bmanning(?:'s|s)? (?:equation|formula|n|roughness)\\b" low then
        let
          val nm = search "\\b(?:manning'?s? n|roughness(?: coefficient)?|n)\\s*(?:of|is|=)?\\s*(0?\\.\\d+)" low
          val am = search ("\\b(?:flow |cross[- ]sectional )?area\\s*(?:of|is|=)?\\s*" ^ N) low
          val pm = search ("\\bwetted perimeter\\s*(?:of|is|=)?\\s*" ^ N) low
          val sm = search "\\bslope\\s*(?:of|is|=)?\\s*(0?\\.\\d+|\\d+(?:\\.\\d+)?\\s*%)" low
          val sv = Option.map (fn m =>
                      let val s = g1 low m
                      in if String.isSubstring "%" s
                         then fdivide (frOf (String.translate (fn #"%" => "" | #" " => "" | c => String.str c) s)) (fint 100)
                         else frOf s end) sm
          val wantQ = has "\\bflow rate\\b|\\bdischarge\\b|\\bq\\b" low
        in SOME (E.RHydro (E.HyManning (og nm, og am, og pm, fqo sv, wantQ))) end
      else if has "\\bhow long\\b.*\\b(?:fill|drain|empty)\\b|\\b(?:fill|drain|empty)\\b.*\\bhow long\\b|\\btime to (?:fill|drain|empty)\\b" low then
        let
          val vol = search (N ^ "\\s*(gallons?|gal|lit(?:er|re)s?|l|m3|cubic met(?:er|re)s?)\\b(?!\\s*(?:per|/))") low
          val rate1 = search (N ^ "\\s*(gallons?|gal|lit(?:er|re)s?|l|m3)\\s*(?:per|/|a)\\s*(min(?:ute)?|hour|hr|h|s(?:ec(?:ond)?)?)\\b") low
          val rate2 = search (N ^ "\\s*(gpm|lpm|l/min|l/s)\\b") low
          fun vu (u : string) = case String.sub (u, 0) of #"g" => E.VGal | #"l" => E.VL | _ => E.VM3
          fun tu (u : string) = case String.sub (u, 0) of #"m" => E.TMin | #"h" => E.THour | _ => E.TSec
          val (v, vunit) = case vol of SOME m => (SOME (fq (frOf (g1 low m))), vu (gs low m 2)) | NONE => (NONE, E.VL)
          val (r, runit, tunit) =
            case rate1 of
              SOME m => (SOME (fq (frOf (g1 low m))), vu (gs low m 2), tu (gs low m 3))
            | NONE =>
                (case rate2 of
                   SOME m =>
                     let val u = gs low m 2
                     in (SOME (fq (frOf (g1 low m))), if u = "gpm" then E.VGal else E.VL,
                         if u = "l/s" then E.TSec else E.TMin) end
                 | NONE => (NONE, E.VL, E.TMin))
        in SOME (E.RHydro (E.HyFill (v, vunit, r, runit, tunit))) end
      else if has "\\bflow rate\\b|\\bdischarge\\b" low andalso has "\\bvelocity\\b|\\bspeed\\b|\\bm/s\\b|\\bft/s\\b" low then
        let
          val vm = search (N ^ "\\s*(m/s|ft/s|fps)\\b") low
          val am = search (N ^ "\\s*(m2|m" ^ sq2 ^ "|square met(?:er|re)s?|ft2|sq\\.? ?ft|square feet)\\b") low
          val ms = case vm of SOME m => gs low m 2 = "m/s" | NONE => false
        in SOME (E.RHydro (E.HyCont (og vm, og am, ms))) end
      else NONE
    end

  exception UnknownRunoffNumber
  fun hydrologyReq t =
    let val raw=lower t in
      if not(has "\\brational method\\b|\\bpeak (?:runoff|discharge|flow)\\b|\\brunoff coefficient\\b" raw)
      then legacyHydrologyReq t
      else case ExactNumeric.mask raw of NONE=>NONE
      | SOME{text=low,numbers}=>
        let
          val token="(qnum[0-9]+q)"
          fun quantity marker=case List.find(fn(name,_)=>name=marker)numbers of
            SOME(_,q)=>fq q | NONE=>raise UnknownRunoffNumber
          fun unique pat=case findall pat low of [m]=>SOME m | _=>NONE
          val unitEnd="(?![A-Za-z0-9_^]|\\s*(?:/|\\*|\\^|\194\183|per\\b))"
          val cm=unique("\\b(?:runoff coefficient|coefficient|c)\\s*(?:of|is|=)?\\s*"^token^"(?![A-Za-z0-9_])\\s*(%)?")
          val im=unique(token^"\\s*(in/hr|in/h|inches per hour|mm/h|mm/hr|millimet(?:er|re)s per hour)"^unitEnd)
          val am=unique(token^"\\s*(acres?|ha|hectares?|km2|square kilomet(?:er|re)s?)"^unitEnd)
          val cv=Option.map(fn m=>E.runoff_coefficient (if isSome(grp low m 2)then E.CPercent else E.CFraction) (quantity(g1 low m)))cm
          fun v m=Option.map(fn m=>quantity(g1 low m))m
          val iu=case im of SOME m=>if startsWith "in"(gs low m 2)then E.IIn else E.IMm | NONE=>E.IMm
          val au=case am of SOME m=>let val u=gs low m 2 in if startsWith "acre" u then E.AAcre else if startsWith "km" u orelse startsWith "square" u then E.AKm2 else E.AHa end | NONE=>E.AHa
        in SOME(E.RHydro(E.HyRational(cv,v im,v am,iu,au))) end
        handle UnknownRunoffNumber=>NONE
    end
  fun hydrology text =
    let val t=collapse text in
      if Narrow.narrative t then NONE
      else case hydrologyReq t of
        SOME(r as E.RHydro(E.HyRational _))=>SOME r
      | request=>gate t request
    end

  (* ============================ ocean ============================ *)
  exception UnknownOceanNumber

  fun ocean text =
    let
      val t = collapse text
    in
      if Narrow.narrative t then NONE
      else case ExactNumeric.mask (lower t) of
        NONE => NONE
      | SOME {text = low, numbers} =>
        let
          val N = "(qnum[0-9]+q)"
          fun frOf marker =
            case List.find (fn (name, _) => name = marker) numbers of
              SOME (_, value) => value
            | NONE => raise UnknownOceanNumber
          fun metresOf v u = if startsWith "k" u then fmul (frOf v) (fint 1000) else frOf v
          val depth = search ("\\b(?:depth|deep)\\s*(?:of|is|=)?\\s*" ^ N ^ "\\s*(km|m|meters?|metres?)\\b|"
                              ^ N ^ "\\s*(km|m|meters?|metres?)\\s*(?:deep|depth|of water|below|down|beneath)\\b|"
                              ^ "\\bat\\s+" ^ N ^ "\\s*(km|m|meters?|metres?)\\b") low
          val dval : fr option =
            Option.map (fn m =>
              let val (v, u) = case grp low m 1 of
                                 SOME v => (v, gs low m 2)
                               | NONE => (case grp low m 3 of SOME v => (v, gs low m 4) | NONE => (gs low m 5, gs low m 6))
              in metresOf v u end) depth
        in
          if has "\\becho\\b|\\bsonar\\b|\\bping\\b|\\bsound(?:ing)?\\b.*\\b(?:return|back|echo)\\w*\\b" low
             andalso has "\\bdepth\\b|\\bhow deep\\b|\\bdeep\\b" low then
            (case search (N ^ "\\s*(s|sec\\w*|seconds?|ms|milliseconds?)\\b") low of
               NONE => NONE
             | SOME tm =>
                 let
                   val tt = if startsWith "m" (gs low tm 2) then fdivide (frOf (g1 low tm)) (fint 1000) else frOf (g1 low tm)
                   val vm = search ("\\b(?:speed of sound|sound speed|sound travels at)\\s*(?:of|is|=|at)?\\s*" ^ N
                                    ^ "\\s*m\\s*/\\s*s|" ^ N ^ "\\s*m\\s*/\\s*s") low
                   val (v, stated) = case vm of
                                       SOME m => (frOf (valOf (firstGroup low m [1, 2])), true)
                                     | NONE => (fint 1500, false)
                 in SOME (E.ROcean (E.OSonar (fq tt, fq v, stated))) end)
          else if has "\\bpressure\\b" low andalso isSome dval
                  andalso has "\\bsea\\b|\\bocean\\b|\\bseawater\\b|\\bwater\\b|\\bdiver\\b|\\bsubmarine\\b|\\bunderwater\\b" low then
            let
              val densityWord = has "\\b(?:density|rho)\\b|\207\129" low
              val densityMatches = findall
                ("(?:\\b(?:density|rho)\\b|\207\129)\\s*(?:of|is|=|:)?\\s*" ^ N
                 ^ "\\s*(?:kg\\s*/\\s*m(?:3|\194\179|\\^3)|kg\\s+per\\s+cubic\\s+met(?:er|re)s?)"
                 ^ "(?![A-Za-z0-9_^]|\\s*(?:/|\\*|\\^|\194\183|per\\b))") low
              val density = case densityMatches of [m] => SOME m | _ => NONE
              val depthMarker = valOf (firstGroup low (valOf depth) [1,3,5])
              val consumed = depthMarker :: (case density of SOME m => [g1 low m] | NONE => [])
              val everyNumberBound = List.all (fn (name,_) => List.exists (fn key=>key=name) consumed) numbers
              val unsupportedRole = has
                "\\b(?:gravity|gravitational|acceleration|p0)\\b|\\bg\\s*=|\\b(?:surface|ambient|external|reference|baseline|atmospheric)\\s+(?:absolute\\s+)?pressure\\b" low
              val rho = case density of SOME m => frOf (g1 low m)
                        | NONE => if has "\\bfresh ?water\\b|\\blake\\b" low then fint 1000 else fint 1025
              val abs = has "\\babsolute\\b|\\btotal pressure\\b|\\bincluding (?:the )?atmospher\\w*\\b" low
            in
              if unsupportedRole orelse not everyNumberBound orelse (densityWord andalso not(isSome density))
              then NONE
              else SOME (E.ROcean (E.OPressure (fq (valOf dval), fq rho, abs)))
            end
          else
            let
              val tsu =
                if has "\\btsunami\\b|\\bshallow[- ]water wave\\b|\\bshallow water\\b" low andalso isSome dval then
                  let
                    val d = valOf dval
                    val dist = search ("\\b(?:travel|cross|reach|cover|distance of|away|across)\\w*\\s*(?:\\w+\\s+){0,3}?" ^ N
                                       ^ "\\s*(km|kilomet\\w+)\\b|" ^ N ^ "\\s*(km|kilomet\\w+)\\s*(?:away|across|to\\b|distant)") low
                  in
                    case dist of
                      SOME m =>
                        if has "\\bhow long\\b|\\btime\\b|\\bhours?\\b|\\bminutes?\\b" low then
                          SOME (E.ROcean (E.OTsunamiTime (fq d, fq (frOf (valOf (firstGroup low m [1, 3]))))))
                        else if has "\\bspeed\\b|\\bhow fast\\b|\\bvelocity\\b" low then SOME (E.ROcean (E.OTsunamiSpeed (fq d)))
                        else NONE
                    | NONE =>
                        if has "\\bspeed\\b|\\bhow fast\\b|\\bvelocity\\b" low then SOME (E.ROcean (E.OTsunamiSpeed (fq d)))
                        else NONE
                  end
                else NONE
            in
              case tsu of
                SOME r => SOME r
              | NONE =>
                let
                  val tp = search ("\\bperiod\\s*(?:of|is|=)?\\s*" ^ N ^ "\\s*(?:s|sec\\w*)\\b|" ^ N ^ "[- ]?(?:s|sec\\w*|second)\\s*(?:wave )?period\\b") low
                in
                  case tp of
                    SOME m =>
                      if has "\\bdeep[- ]water\\b|\\bdeep ocean\\b|\\bopen ocean\\b" low then
                        let val per = fq (frOf (valOf (firstGroup low m [1, 2])))
                        in
                          if has "\\bwavelength\\b|\\bhow long\\b.*\\bwave\\b" low then SOME (E.ROcean (E.ODeepWL per))
                          else if has "\\bgroup\\b" low andalso has "\\bcapillary\\b|\\bsurface tension\\b" low then NONE
                          else if has "\\bgroup\\b" low andalso has "\\bspeed\\b|\\bvelocity\\b|\\bcelerity\\b" low then SOME (E.ROcean (E.ODeepGroupSpeed per))
                          else if has "\\bspeed\\b|\\bhow fast\\b|\\bvelocity\\b|\\bcelerity\\b" low then SOME (E.ROcean (E.ODeepSpeed per))
                          else NONE
                        end
                      else NONE
                  | NONE => NONE
                end
            end
        end
    end handle UnknownOceanNumber => NONE

  (* ============================ meteorology ============================ *)
  val WN = "(-?\\d+(?:\\.\\d+)?)"
  val TMP = WN ^ "\\s*" ^ degSp ^ "(?:f|c|fahrenheit|celsius)\\b"
  val TMPU = WN ^ "\\s*" ^ degSp ^ "(f|c|fahrenheit|celsius)\\b"

  fun tempOf low : (E.rat * E.tscale) option =
    Option.map (fn m => (fq (frOf (g1 low m)), if startsWith "f" (gs low m 2) then E.TsF else E.TsC)) (search TMPU low)

  fun rhOf low : fr option =
    Option.map (fn m => frOf (valOf (firstGroup low m [1, 2])))
      (search (WN ^ "\\s*%\\s*(?:relative )?humidity|(?:relative )?humidity\\s*(?:of|is|at|=)?\\s*" ^ WN ^ "\\s*%?") low)

  fun windUnit (u : string) : E.wunit =
    if u = "mph" then E.WMph
    else if u = "km/h" orelse u = "kph" orelse u = "kmh" then E.WKmh
    else if u = "m/s" then E.WMs else E.WKn

  fun f2c (v : fr) : fr = fdivide (fmul (fsub v (fint 32)) (fint 5)) (fint 9)

  fun meteorology text =
    let
      val t = collapse text
      val low = lower t
      val tt = tempOf low
      val (tv, tu) = case tt of SOME (v, u) => (SOME v, u) | NONE => (NONE, E.TsF)
      val rh = rhOf low
      val rhq = fqo rh
    in
      if has "\\b(?:tomorrow|next week|forecast|will it (?:rain|snow)|going to (?:rain|snow))\\b" low then NONE
      else if has "\\bheat index\\b|\\bfeels like\\b.*\\bhumid" low then
        SOME (E.RWeather (E.WHeat (tv, tu, rhq)))
      else if has "\\bwind ?chill\\b" low then
        let val wm = search (WN ^ "\\s*(mph|km/h|kph|kmh|m/s|knots?|kt)\\b") low
        in SOME (E.RWeather (E.WChill (tv, tu, Option.map (fn m => fq (frOf (g1 low m))) wm,
                                       case wm of SOME m => windUnit (gs low m 2) | NONE => E.WMph))) end
      else
        let
          val nTemps = length (findall TMP low)
          val dewWord = has "\\bdew ?point\\b" low
        in
          if dewWord andalso has "\\bhumidity\\b" low andalso not (nTemps >= 2 andalso not (isSome rh)) then
            let
              val given = has ("\\bdew ?point\\s*(?:is|of|=|:|was|reads)?\\s*" ^ TMP) low orelse has (TMP ^ "\\s*dew ?point\\b") low
            in SOME (E.RWeather (if given then E.WAirT (tv, tu, rhq) else E.WDew (tv, tu, rhq))) end
          else if has "\\b(?:relative )?humidity\\b" low andalso dewWord then
            let
              val temps = findall TMPU low
            in
              if length temps < 2 then SOME (E.RWeather (E.WRH (NONE, NONE, E.RhBoth)))
              else
                let
                  val cs = map (fn m => if startsWith "c" (gs low m 2) then frOf (g1 low m) else f2c (frOf (g1 low m))) temps
                  val dm = case search ("\\bdew ?point\\s*(?:is|of|=|:|was|reads)?\\s*(?:" ^ TMP ^ ")") low of
                             SOME m => SOME m
                           | NONE => search (TMP ^ "\\s*dew ?point\\b") low
                in
                  case dm of
                    NONE => SOME (E.RWeather (E.WRH (NONE, NONE, E.RhWhich)))
                  | SOME d =>
                      let
                        val ds = #start (d : Regex.match) and de = #stop (d : Regex.match)
                        fun idx _ [] = NONE
                          | idx i ((m : Regex.match) :: ms) = if ds <= #start m andalso #start m < de then SOME i else idx (i + 1) ms
                      in
                        case idx 0 temps of
                          NONE => SOME (E.RWeather (E.WRH (NONE, NONE, E.RhWhich)))
                        | SOME di =>
                            let
                              val td = List.nth (cs, di)
                              val tair = if di < 2 then List.nth (cs, 1 - di) else List.nth (cs, 0)
                            in SOME (E.RWeather (E.WRH (SOME (fq tair), SOME (fq td), E.RhBoth))) end
                      end
                end
            end
          else if has "\\bsaffir|\\bhurricane category\\b|\\bwhat category\\b.*\\b(?:hurricane|storm|wind)|\\bcategory (?:of|would)\\b.*\\bhurricane" low then
            let val wm = search (WN ^ "\\s*(mph|km/h|kph|kmh|knots?|kt|m/s)\\b") low
            in SOME (E.RWeather (E.WSaffir (Option.map (fn m => fq (frOf (g1 low m))) wm,
                                            case wm of SOME m => windUnit (gs low m 2) | NONE => E.WMph))) end
          else if has "\\bbeaufort\\b" low then
            let val wm = search (WN ^ "\\s*(knots?|kt|mph|m/s|km/h)\\b") low
            in SOME (E.RWeather (E.WBeaufort (Option.map (fn m => fq (frOf (g1 low m))) wm,
                                              case wm of SOME m => windUnit (gs low m 2) | NONE => E.WKn))) end
          else if has "\\bstandard atmosphere\\b|\\bisa\\b|\\blapse rate\\b" low andalso has "\\baltitude\\b|\\bheight\\b|\\belevation\\b|\\bat \\d" low then
            let
              val am = search (WN ^ "\\s*(km|m|ft|feet|meters?|metres?)\\b") low
              val au = case am of
                         SOME m => let val u = gs low m 2
                                   in if u = "km" then E.AltKm else if u = "ft" orelse u = "feet" then E.AltFt else E.AltM end
                       | NONE => E.AltM
            in SOME (E.RWeather (E.WIsa (Option.map (fn m => fq (frOf (g1 low m))) am, au, has "\\bpressure\\b" low))) end
          else NONE
        end
    end

  (* ============================ greenhouse ============================ *)
  fun gUnit (u : string) : E.gunit = if String.sub (u, 0) = #"f" then E.GF else E.GC

  fun lenUnit (u : string) : E.lunit =
    if u = "cm" then E.LCm else if u = "m" then E.LM else if u = "in" orelse u = "inches" then E.LIn else E.LFt

  fun legacyGreenhouseReq t =
    let
      val low = lower t
      fun og m = Option.map (fn x => fq (frOf (g1 low x))) m
    in
      if has "\\bvpd\\b|\\bvapou?r pressure deficit\\b" low then
        let
          val tm = findall (WN ^ "\\s*" ^ degSp ^ "(c|f|celsius|fahrenheit)\\b") low
          val rm = search (WN ^ "\\s*%\\s*(?:relative )?(?:humidity|rh)|\\b(?:relative humidity|rh|humidity)\\s*(?:of|is|=|at)?\\s*" ^ WN ^ "\\s*%?") low
          val leaf = search ("\\bleaf(?: temperature| temp)?\\s*(?:of|is|=|at)?\\s*" ^ WN ^ "\\s*" ^ degSp ^ "(c|f)\\b") low
          val air = List.find (fn (m : Regex.match) => case leaf of
                                          NONE => true
                                        | SOME (l : Regex.match) => not (#start l <= #start m andalso #start m < #stop l)) tm
          val rhq = Option.map (fn m => fq (frOf (valOf (firstGroup low m [1, 2])))) rm
        in
          SOME (E.RGreen (E.GhVpd (Option.map (fn m => fq (frOf (g1 low m))) air,
                                   case air of SOME m => gUnit (gs low m 2) | NONE => E.GC,
                                   Option.map (fn m => fq (frOf (g1 low m))) leaf,
                                   case leaf of SOME m => gUnit (gs low m 2) | NONE => E.GC,
                                   rhq, not (null tm))))
        end
      else if has "\\bgrowing degree days?\\b|\\bgdd\\b|\\bdegree days?\\b" low then
        let
          val hi = search ("\\b(?:high|max(?:imum)?|tmax)\\s*(?:of|is|=|was)?\\s*" ^ WN) low
          val lo = search ("\\b(?:low|min(?:imum)?|tmin)\\s*(?:of|is|=|was)?\\s*" ^ WN) low
          val base = case search ("\\bbase(?: temperature)?\\s*(?:of|is|=)?\\s*" ^ WN) low of
                       SOME m => SOME m
                     | NONE => search (WN ^ "\\s*" ^ degSp ^ "(?:f|c)?\\s*base\\b") low
        in SOME (E.RGreen (E.GhGdd (og hi, og lo, og base))) end
      else if has "\\bhow many plants\\b|\\bplants? (?:fit|per)\\b|\\bplant count\\b" low then
        let
          val am = search (WN ^ "\\s*(m2|m" ^ sq2 ^ "|square met(?:er|re)s?|sq\\.? ?ft|square feet|ft2)\\b") low
          val sp = findall (WN ^ "\\s*(cm|m|in|inches|ft|feet)\\b(?!\\s*(?:2|" ^ sq2 ^ "))") low
          val au = case am of
                     SOME m => let val u = gs low m 2 in if startsWith "m" u orelse startsWith "square m" u then E.GaM2 else E.GaFt2 end
                   | NONE => E.GaM2
          fun sv i = if length sp > i then SOME (fq (frOf (g1 low (List.nth (sp, i))))) else NONE
          fun su i = if length sp > i then lenUnit (gs low (List.nth (sp, i)) 2) else E.LM
        in SOME (E.RGreen (E.GhPlants (og am, au, sv 0, su 0, sv 1, su 1))) end
      else NONE
    end

  exception UnknownLightNumber
  fun greenhouseReq text =
    let val raw=lower text
        val light=has "\\bdli\\b|\\bdaily light integral\\b|\\bppfd\\b|\\bphotoperiod\\b" raw
    in if not light then legacyGreenhouseReq text
       else case ExactNumeric.mask raw of NONE=>NONE
       | SOME{text=low,numbers}=>
         let
           val token="(qnum[0-9]+q)"
           fun quantity marker=case List.find(fn(name,_)=>name=marker)numbers of
             SOME(_,q)=>fq q | NONE=>raise UnknownLightNumber
           fun unique pat=case findall pat low of [m]=>SOME m | _=>NONE
           val unitEnd="(?![A-Za-z0-9_^]|\\s*(?:/|\\*|\\^|\194\183|per\\b))"
           val area="m(?:2|\194\178|\\^2)"
           val pm=unique(token^"\\s*(?:umol|\194\181mol|\206\188mol|micromoles?)\\s*/\\s*"^area^"\\s*/\\s*(?:s|sec(?:ond)?s?)"^unitEnd)
           val dm=unique(token^"\\s*mol\\s*/\\s*"^area^"\\s*/\\s*(?:d|days?)"^unitEnd)
           val hm=unique(token^"\\s*(hours?|hrs?|h)\\b"^unitEnd)
           val want=has "\\bwhat ppfd\\b|\\bhow much ppfd\\b|\\bppfd (?:do i need|is needed|needed|required)\\b" low
           val selected=if want then dm else pm
           val consumed=List.map(fn m=>g1 low m)(List.mapPartial(fn x=>x)[selected,hm])
           val complete=length consumed=2 andalso length numbers=2 andalso
             List.all(fn(n,_)=>List.exists(fn c=>c=n)consumed)numbers
           fun value m=Option.map(fn m=>quantity(g1 low m))m
         in if not complete then SOME(E.RGreen(E.GhDli(NONE,NONE)))
            else if want then SOME(E.RGreen(E.GhPpfd(quantity(g1 low(valOf dm)),quantity(g1 low(valOf hm)))))
            else SOME(E.RGreen(E.GhDli(value pm,value hm)))
         end handle UnknownLightNumber=>NONE
    end

  fun greenhouse text =
    let val t = collapse text
    in if Narrow.narrative t then NONE else gate t (greenhouseReq t) end

  val NOT_MINE = "\\b(?:heating degree days|r-\\d{1,2}|r-value|u-value|sq ft of|square feet of)\\b"
  val MINE = "\\b(?:greenhouse|crop|plants?|seedlings?|vpd|dli|growing degree)\\b"
  fun greenhouseR2 text =
    let val low = lower text
    in if has NOT_MINE low andalso not (has MINE low) then NONE else greenhouse text end

  (* ============================ dispatch ============================ *)
  val organs = ["geography", "geology", "seismology", "hydrology", "ocean", "meteorology", "greenhouse", "greenhouse-r2"]
  val familyOrder = ["geography", "geology", "seismology", "hydrology", "ocean", "meteorology", "greenhouse"]

  fun byId id text =
    case id of
      "geography" => geography text
    | "geology" => geology text
    | "seismology" => seismology text
    | "hydrology" => hydrology text
    | "ocean" => ocean text
    | "meteorology" => meteorology text
    | "greenhouse" => greenhouse text
    | "greenhouse-r2" => greenhouseR2 text
    | _ => NONE

  fun recognize mode text =
    if mode = "family" then
      let fun go [] = NONE
            | go (id :: ids) = case byId id text of SOME r => SOME (id, r) | NONE => go ids
      in go familyOrder end
    else Option.map (fn r => (mode, r)) (byId mode text)
end
