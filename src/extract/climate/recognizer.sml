(* UNTRUSTED. The English recognizer for the climate family: a hand port of the
   regular expressions and branch order of
     upstream/root/specialists/carboncapture/organ_carboncapture_v1.py  (CarbonCaptureOrgan)
     upstream/root/specialists/airquality/organ_airquality_v1.py        (AirQualityOrgan)
     upstream/root/specialists/climate/organ_climate_v1.py              (ClimateOrgan)
     upstream/root/specialists/carbonmat/organ_carbonmat_v1.py          (CarbonMatOrgan)
     upstream/root/specialists/coldchain/organ_coldchain_v1.py          (ColdChainOrgan)
     upstream/root/specialists/coldchain-v2/organ_coldchain_v2.py       (ColdChainOrganV2)
   and of their shared narrowing rule narrow_v1.py (and the numbers rule). It reads
   numbers and words off the question and builds a typed Climate.request; it
   computes nothing. Every value, decline and response text comes from the
   verified HOL kernel (Climate.reply_of). NONE means the question is not taken
   (the organ returns None). The structure of this file (helpers, narrowing) is
   lane G's src/extract/quantity/recognizer.sml.

   Matching is case-insensitive by lower-casing the TEXT; patterns are passed as
   written (lower case), as the fixed regex.sml requires. \w and \d are ASCII
   here; non-ASCII symbols (the micro sign, lambda, degree, superscripts, a-ring)
   are matched as their UTF-8 bytes and where an organ pattern puts \b next to
   one, this port drops the \b (Python counts those characters as word
   characters, this matcher does not).

   Completion: measured/read pollutant concentrations, decimal cooling
   durations, and the same complete food vocabulary for both coldchain versions.
   Other differences from the organs: a fuel economy of 0
   mpg reaches the kernel, which declines it (the organ raises
   ZeroDivisionError); a negative solar constant is declined; cooling readings,
   hour counts and temperatures are exact rationals, not floats. *)
structure Recognizer :
sig
  val organs : string list
  val recognize : string -> string -> (string * Climate.request) option
end =
struct
  structure Q = Climate


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

  (* "1,000.50" -> mk_rat 100050 100, exactly; "-12.5" allowed (units) *)
  fun ratOf (lit0 : string) : Q.rat =
    let
      val lit = String.translate (fn #"," => "" | c => String.str c) lit0
      val (neg, body) = if String.isPrefix "-" lit then (true, String.extract (lit, 1, NONE))
                        else (false, lit)
      val (ip, fp) = case String.fields (fn c => c = #".") body of
                       [a] => (a, "")
                     | [a, b] => (a, b)
                     | _ => raise Fail ("bad numeral " ^ lit0)
      val num = valOf (IntInf.fromString (ip ^ fp))
      val den = IntInf.pow (10, size fp)
    in Q.mk_rat (if neg then IntInf.~ num else num) den end

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
  val cube = "\194\179"   (* U+00B3 SUPERSCRIPT THREE, UTF-8 *)

  (* ---------- helpers shared by the six organs ---------- *)
  fun intOf (s : string) : IntInf.int =
    let val (neg, body) = if String.isPrefix "-" s then (true, String.extract (s, 1, NONE)) else (false, s)
        val v = valOf (IntInf.fromString body)
    in if neg then IntInf.~ v else v end
  fun mkInt s = Q.mk_int (intOf s)
  fun numG s m gs = ratOf (valOf (firstGroup s m gs))
  fun strG s m gs = valOf (firstGroup s m gs)
  val zero = Q.mk_rat 0 1

  (* numerator and denominator of a decimal literal, and the literal times k *)
  fun parts (lit0 : string) : IntInf.int * IntInf.int =
    let
      val lit = String.translate (fn #"," => "" | c => String.str c) lit0
      val (ip, fp) = case String.fields (fn c => c = #".") lit of
                       [a] => (a, "") | [a, b] => (a, b) | _ => raise Fail ("bad numeral " ^ lit0)
      val ip = if ip = "" then "0" else ip
    in (valOf (IntInf.fromString (ip ^ fp)), IntInf.pow (10, size fp)) end
  fun ratTimes k lit = let val (n, d) = parts lit in Q.mk_rat (k * n) d end
  fun sameLit a b = let val (n1, d1) = parts a val (n2, d2) = parts b in n1 * d2 = n2 * d1 end

  (* the organ's answer(): a narrative turn is never taken; a decline is only said
     for a short direct question; a kernel "not taken" (a particle value in a gas
     unit) is silence *)
  fun finish t req =
    if Q.not_taken req then NONE
    else if (not (Narrow.short_direct t)) andalso (not (Q.answers req)) then NONE
    else SOME req

  val N = NUM

  (* ---------- carboncapture ---------- *)
  val ccMass = N ^ "\\s*(tonnes?|tons?|t|kg|kilograms?|mt|gt|gigatonnes?|megatonnes?)\\b"
  val ccMpg = N ^ "\\s*(?:mpg|miles per gallon)\\b"
  val ccGal = N ^ "\\s*(?:us\\s+)?gallons?\\b"
  val ccCap = "(\\d+(?:\\.\\d+)?)\\s*%\\s*(?:capture|of (?:the |its )?(?:co2|emissions))|\\bcapture (?:rate|efficiency)\\s*(?:of|is)?\\s*(\\d+(?:\\.\\d+)?)\\s*%|\\bcaptur\\w*\\s*(\\d+(?:\\.\\d+)?)\\s*%"
  val ccEnergy = N ^ "\\s*(kwh|mwh|gj)\\s*(?:per|/|a)\\s*(?:tonne|ton|t)\\b"

  fun carboncapture text =
    let val t = collapse text
    in
      if Narrow.narrative t then NONE
      else
        let
          val low = lower t
          val fuelWord = List.find (fn f => has ("\\b" ^ f ^ "\\b") low) ["gasoline", "petrol", "diesel"]
          fun fuelOf f = if f = "diesel" then Q.F_diesel else Q.F_gasoline
          val mass = search ccMass low
          val unit = Option.map (fn m => valOf (grp low m 2)) mass
          val mpg = search ccMpg low
          val gal = search ccGal low
        in
          if has "\\boffsets?\\b|\\bcredits?\\b|\\bprice\\b|\\bworth\\b|\\$" low then NONE
          else if isSome fuelWord andalso isSome mpg andalso has "\\bper mile\\b|\\bco2 per\\b|\\bgrams\\b" low then
            finish t (Q.Req_cc (Q.Cc_co2_per_mile (fuelOf (valOf fuelWord), valOf fuelWord, ratOf (g1 low (valOf mpg)))))
          else if isSome fuelWord andalso isSome gal andalso has "\\bco2\\b|\\bcarbon dioxide\\b|\\bemi\\w+\\b" low then
            finish t (Q.Req_cc (Q.Cc_fuel_co2 (fuelOf (valOf fuelWord), valOf fuelWord, ratOf (g1 low (valOf gal)))))
          else
            let val cap = search ccCap low
            in
              if isSome cap andalso isSome mass andalso has "\\bcaptur\\w*\\b" low then
                let
                  val c = ratOf (valOf (firstGroup low (valOf cap) [1, 2, 3]))
                  val m = ratOf (g1 low (valOf mass))
                  val u = valOf unit
                  val ek = search ccEnergy low
                in
                  case ek of
                    SOME e =>
                      if has "\\benergy\\b|\\bhow much (?:energy|electricity|power)\\b" low then
                        let val eu = valOf (grp low e 2)
                            val eunit = if eu = "kwh" then Q.E_kwh else if eu = "mwh" then Q.E_mwh else Q.E_gj
                        in finish t (Q.Req_cc (Q.Cc_capture_energy (m, u, c, ratOf (g1 low e), eunit))) end
                      else finish t (Q.Req_cc (Q.Cc_captured (m, u, c)))
                  | NONE => finish t (Q.Req_cc (Q.Cc_captured (m, u, c)))
                end
              else if isSome mass andalso has "\\bco2\\b|\\bcarbon dioxide\\b" low
                      andalso has "\\bcarbon\\b" (replaceAll "carbon dioxide" "" low) then
                let val m = ratOf (g1 low (valOf mass)) val u = valOf unit
                in
                  if has "\\b(?:of|from) (?:pure )?carbon\\b|\\bcarbon (?:is )?(?:burned|burnt|combusted|oxidi[sz]ed)\\b|\\bburning\\b.*\\bcarbon\\b|\\bcarbon\\b.*\\b(?:produce|make|form|yield)s?\\b" low
                     andalso has "\\bhow much co2\\b|\\bhow many\\b.*\\bco2\\b|\\bco2 (?:is )?(?:produced|formed|released|made)\\b|\\bmass of co2\\b|\\bproduce\\b" low then
                    finish t (Q.Req_cc (Q.Cc_c_to_co2 (m, u)))
                  else if has "\\bhow much carbon\\b|\\bcarbon content\\b|\\bmass of carbon\\b|\\bin terms of carbon\\b|\\bas carbon\\b" low then
                    finish t (Q.Req_cc (Q.Cc_co2_to_c (m, u)))
                  else NONE
                end
              else NONE
            end
        end
    end

  (* ---------- airquality ---------- *)
  val pollutants =
    [(Q.P_pm25, "pm\\s*2\\.5|fine particulates?|fine particles"), (Q.P_pm10, "pm\\s*10\\b|coarse particles"),
     (Q.P_o3, "ozone|\\bo3\\b"), (Q.P_co, "carbon monoxide|\\bco\\b"),
     (Q.P_so2, "sulfur dioxide|sulphur dioxide|\\bso2\\b"), (Q.P_no2, "nitrogen dioxide|\\bno2\\b")]
  val aqNum = "(\\d+(?:\\.\\d+)?)"
  val aqUnit = "\\s*(\194\181g/m\194\179|\194\181g/m3|ug/m3|ug/m\194\179|\206\188g/m\194\179|\206\188g/m3|micrograms? per cubic met(?:er|re)|ppm|ppb)?"
  fun aunitOf NONE = Q.Au_none
    | aunitOf (SOME "ppm") = Q.Au_ppm
    | aunitOf (SOME "ppb") = Q.Au_ppb
    | aunitOf (SOME _) = Q.Au_ug
  fun isPm p = (p = Q.P_pm25 orelse p = Q.P_pm10)

  (* (pollutant, value, unit) in order of position, first mention per pollutant *)
  fun readings low =
    let
      val found =
        List.concat (map (fn (p, rx) =>
          let
            val a = map (fn m => (p, g1 low m, grp low m 2, #start m))
                      (findall ("(?:" ^ rx ^ ")\\s*(?:\\(?\\s*(?:24|8|1)[- ]?h(?:ou)?r\\s*\\)?\\s*)?(?:level|concentration|reading|reads|measured|average|of|is|at|=|:|\\s)*" ^ aqNum ^ aqUnit) low)
            val b = List.mapPartial (fn m =>
                      let val u = grp low m 2
                      in if isSome u orelse isPm p then SOME (p, g1 low m, u, #start m) else NONE end)
                      (findall (aqNum ^ aqUnit ^ "\\s*(?:of\\s+)?(?:24[- ]?h(?:ou)?r\\s+|8[- ]?h(?:ou)?r\\s+|1[- ]?h(?:ou)?r\\s+)?(?:" ^ rx ^ ")") low)
          in a @ b end) pollutants)
      fun insert x [] = [x]
        | insert (x as (_, _, _, s1)) ((y as (_, _, _, s2)) :: ys) = if s1 <= s2 then x :: y :: ys else y :: insert x ys
      val sorted = List.foldl (fn (x, acc) => insert x acc) [] found
      fun uniq [] _ = []
        | uniq ((p, v, u, s) :: rest) seen =
            if List.exists (fn q => q = p) seen then uniq rest seen
            else (p, v, u) :: uniq rest (p :: seen)
    in uniq sorted [] end

  fun airquality text =
    let val t = collapse text
    in
      if Narrow.narrative t then NONE
      else
        let val low = lower t
        in
          if not (has "\\baqi\\b|\\bair quality\\b" low) then NONE
          else if has "\\bshould i\\b|\\bis it safe (?:for me|to)\\b|\\bcan i\\b|\\bmy (?:asthma|child|kids?|son|daughter)\\b" low then NONE
          else
            let val rd = readings low
            in
              if null rd then
                (case search "\\baqi\\s*(?:of|is|=|reading of|value of|at)?\\s*(-?\\d+(?:\\.\\d+)?)\\b|(-?\\d+(?:\\.\\d+)?)\\s*(?:on the )?aqi\\b" low of
                   SOME m =>
                     if has "\\bcategory\\b|\\bwhat (?:level|color|colour)\\b|\\bunhealthy\\b|\\bgood\\b|\\bmoderate\\b|\\bhazardous\\b|\\bwhat does\\b|\\bmean\\b|\\bhow (?:bad|good)\\b" low then
                       let val s = strG low m [1, 2]
                       in finish t (Q.Req_aq (Q.Aq_category (ratOf s, s))) end
                     else NONE
                 | NONE => NONE)
              else
                let
                  val hourly = has "\\b(?:1|one)[- ]?h(?:ou)?r\\b|\\bhourly\\b" low andalso not (has "\\b24[- ]?h(?:ou)?r\\b" low)
                in finish t (Q.Req_aq (Q.Aq_index (hourly, map (fn (p, v, u) => Q.Reading (p, ratOf v, aunitOf u)) rd))) end
            end
        end
    end

  (* ---------- climate ---------- *)
  val clSolar = "\\b(?:solar constant|solar irradiance|insolation|s0?)\\s*(?:of|is|=)?\\s*" ^ N ^ "\\s*w|" ^ N ^ "\\s*w\\s*/\\s*m(?:2|\194\178)"
  val clAlbedo = "\\balbedo\\s*(?:of|is|=)?\\s*(\\d*\\.?\\d+)\\s*(%)?"
  fun ratDiv lit k = let val (n, d) = parts lit in Q.mk_rat n (d * k) end

  (* (C0, C) from "from A to B ppm", a doubling, or a pre-industrial baseline *)
  fun conc low =
    case search ("\\bfrom\\s+" ^ N ^ "\\s*(?:ppm)?\\s*to\\s+" ^ N ^ "\\s*ppm") low of
      SOME m => SOME (ratOf (g1 low m), ratOf (valOf (grp low m 2)))
    | NONE =>
      let
        val vals = map (fn m => g1 low m) (findall (N ^ "\\s*ppm") low)
      in
        if has "\\bdoubl\\w*\\b" low andalso length vals = 1 then SOME (ratOf (hd vals), ratTimes 2 (hd vals))
        else
          case search ("\\b(?:pre-?industrial|baseline|reference|initial)\\s*(?:level\\s*)?(?:of|is|was|=)?\\s*" ^ N ^ "\\s*ppm|" ^ N ^ "\\s*ppm\\s*(?:pre-?industrial|baseline)") low of
            SOME m =>
              if length vals = 2 then
                let val b = strG low m [1, 2]
                    val (v0, v1) = (List.nth (vals, 0), List.nth (vals, 1))
                in SOME (ratOf b, ratOf (if sameLit v0 b then v1 else v0)) end
              else NONE
          | NONE => NONE
      end

  val gwpRx = "\\bgwp(?:100|-100)?\\s*(?:of|is|=)?\\s*" ^ N
  val massRx = N ^ "\\s*(tonnes?|tons?|t|kg|mt|gt)\\b"
  val gtcWords = "\\bgtc\\b|\\bgigatonnes? of carbon\\b|\\bpetagrams? of carbon\\b|\\bpgc\\b|\\bgtco2\\b|\\bgigatonnes? of co2\\b|\\bgigatonnes? of carbon dioxide\\b"
  val gtcMass = N ^ "\\s*(gtc|pgc|gtco2|gigatonnes? of carbon dioxide|gigatonnes? of co2|gigatonnes? of carbon|petagrams? of carbon)\\b"

  (* a branch returns SOME (reply request or silence) or NONE = falls through *)
  fun ppmBranch low =
    if not (has gtcWords low andalso has "\\bppm\\b" low) then NONE
    else
      let
        val pm = search (N ^ "\\s*ppm") low
        val cm = search gtcMass low
        val toMass = has "\\bhow many (?:gtc|gtco2|gigatonnes|petagrams)\\b|\\bin (?:gtc|gtco2|gigatonnes)\\b|\\bhow much (?:carbon|co2)\\b|\\bmass\\b" low
      in
        if isSome pm andalso (toMass orelse not (isSome cm)) then
          let val p = ratOf (g1 low (valOf pm))
          in SOME (SOME (if has "\\bgtco2\\b|\\bgigatonnes? of (?:co2|carbon dioxide)\\b" low then Q.Req_cl (Q.Cl_ppm_to_gtco2 p)
                         else Q.Req_cl (Q.Cl_ppm_to_gtc p))) end
        else if isSome cm then
          let val c = ratOf (g1 low (valOf cm))
              val co2 = has "co2|dioxide" (valOf (grp low (valOf cm) 2))
          in SOME (SOME (Q.Req_cl (Q.Cl_mass_to_ppm (c, co2, if co2 then "GtCO2" else "GtC")))) end
        else NONE
      end

  val lamRx1 = "(?:\\blambda|\206\187|\\bfeedback parameter|\\bsensitivity parameter)\\s*(?:of|is|=)?\\s*" ^ N ^ "\\s*(?:k|\194\176c)\\s*(?:per|/)\\s*(?:w|\\(w)"
  val lamRx2 = N ^ "\\s*(?:k|\194\176c)\\s*(?:per|/)\\s*\\(?w\\s*/?\\s*m"
  val sensRx = "\\b(?:climate )?sensitivity\\s*(?:of|is|=)?\\s*" ^ N ^ "\\s*(?:\194\176\\s*c|degrees?|k)?|\\becs\\s*(?:of|is|=)?\\s*" ^ N ^ "|" ^ N ^ "\\s*(?:\194\176\\s*c|degrees?\\s*c?|k)\\s*per doubling"

  fun warmBranch low =
    if not (has "\\bforcing\\b|\\bwarming\\b|\\btemperature (?:rise|increase|change)\\b|\\bhow much (?:would|does) (?:the )?(?:earth|temperature|planet) warm\\b|\\bequilibrium\\b" low
            andalso has "\\bco2\\b|\\bcarbon dioxide\\b|\\bppm\\b" low) then NONE
    else
      case conc low of
        NONE => SOME (SOME (Q.Req_cl (Q.Cl_forcing NONE)))
      | SOME cc =>
          if has "\\bwarming\\b|\\btemperature\\b|\\bwarm\\b|\\bdegrees\\b" low andalso not (has "\\bforcing\\b.*\\?$" low) then
            let
              val lam = case search lamRx1 low of SOME m => SOME m | NONE => search lamRx2 low
              val sens = search sensRx low
            in
              case lam of
                SOME m => SOME (SOME (Q.Req_cl (Q.Cl_warming (SOME cc, Q.Sens_lambda (ratOf (g1 low m))))))
              | NONE =>
                (case sens of
                   SOME m => SOME (SOME (Q.Req_cl (Q.Cl_warming (SOME cc, Q.Sens_ecs (numG low m [1, 2, 3])))))
                 | NONE =>
                   if not (has "\\bforcing\\b" low) then SOME (SOME (Q.Req_cl (Q.Cl_warming (SOME cc, Q.Sens_none))))
                   else SOME (SOME (Q.Req_cl (Q.Cl_forcing (SOME cc)))))
            end
          else SOME (SOME (Q.Req_cl (Q.Cl_forcing (SOME cc))))

  fun climate text =
    let val t = collapse text
    in
      if Narrow.narrative t then NONE
      else
        let
          val low = lower t
          fun done NONE = NONE
            | done (SOME req) = finish t req
        in
          if has "\\bwill\\b|\\bby (?:19|20|21)\\d{2}\\b|\\bin (?:20[3-9]\\d|21\\d{2})\\b|\\bpredict\\w*\\b|\\bforecast\\w*\\b|\\bproject\\w*\\b" low then NONE
          else if has "\\beffective temperature\\b|\\bradiating temperature\\b|\\bequilibrium temperature\\b|\\bblackbody temperature\\b" low
                  andalso has "\\balbedo\\b" low then
            (case (search clSolar low, search clAlbedo low) of
               (SOME s, SOME a) =>
                 let
                   val sv = numG low s [1, 2]
                   val av = case grp low a 2 of SOME _ => ratDiv (g1 low a) 100 | NONE => ratOf (g1 low a)
                 in finish t (Q.Req_cl (Q.Cl_eff_temp (SOME sv, SOME av))) end
             | _ => finish t (Q.Req_cl (Q.Cl_eff_temp (NONE, NONE))))
          else if has "\\bco2[- ]?e(?:q|quivalent)?\\b|\\bco2 equivalent\\b|\\bcarbon dioxide equivalent\\b" low then
            (case search gwpRx low of
               NONE => finish t (Q.Req_cl (Q.Cl_co2e (NONE, zero, "", "")))
             | SOME g =>
                 (case search massRx low of
                    NONE => NONE
                  | SOME mm => finish t (Q.Req_cl (Q.Cl_co2e (SOME (ratOf (g1 low g)), ratOf (g1 low mm), valOf (grp low mm 2), g1 low g)))))
          else
            (case ppmBranch low of
               SOME r => done r
             | NONE => (case warmBranch low of SOME r => done r | NONE => NONE))
        end
    end

  (* ---------- carbonmat ---------- *)
  val cmIdx = "\\(\\s*(-?\\d+)\\s*,\\s*(-?\\d+)\\s*\\)"
  val cmThick = "(\\d+(?:\\.\\d+)?)\\s*(nm\\b|nanomet\\w+\\b|\195\165|\195\133|angstroms?\\b)"
  val cmArea = "(\\d+(?:\\.\\d+)?)\\s*(m2\\b|m\194\178|square met(?:er|re)s?\\b|cm2\\b|cm\194\178|square centimet(?:er|re)s?\\b)"

  fun carbonmat text =
    let val t = collapse text
    in
      if Narrow.narrative t then NONE
      else
        let val low = lower t
        in
          case search cmIdx low of
            SOME m =>
              if has "\\bnanotubes?\\b|\\bcnt\\b|\\bswcnt\\b|\\bswnt\\b|\\bchiral\\w*\\b" low then
                let
                  val ns = g1 low m
                  val ms = valOf (grp low m 2)
                  val n = intOf ns
                  val mm = intOf ms
                  val bad = n < 0 orelse mm < 0 orelse n < mm orelse (n = 0 andalso mm = 0)
                  val nI = Q.mk_int n
                  val mI = Q.mk_int mm
                in
                  if bad then finish t (Q.Req_cm (Q.Cm_diameter (nI, mI)))
                  else if has "\\bdiameter\\b|\\bhow (?:wide|thick|big)\\b" low then finish t (Q.Req_cm (Q.Cm_diameter (nI, mI)))
                  else if has "\\bchiral angle\\b|\\bangle\\b" low then finish t (Q.Req_cm (Q.Cm_angle (nI, mI)))
                  else if has "\\bmetallic\\b|\\bsemiconduct\\w*\\b|\\bconduct\\w*\\b|\\belectronic\\b|\\bband ?gap\\b" low then finish t (Q.Req_cm (Q.Cm_type (nI, mI)))
                  else if has "\\barmchair\\b|\\bzigzag\\b|\\bwhat type\\b|\\bwhich type\\b|\\bclassif\\w*\\b" low then finish t (Q.Req_cm (Q.Cm_kind (nI, mI)))
                  else NONE
                end
              else cmRest t low
          | NONE => cmRest t low
        end
    end
  and cmRest t low =
    let
      val th = search cmThick low
      val ar = search cmArea low
    in
      if isSome th andalso has "\\bgraphene\\b|\\bgraphite\\b" low andalso has "\\blayers?\\b|\\bsheets?\\b" low
         andalso has "\\bthick\\w*\\b" low then
        let val u = valOf (grp low (valOf th) 2)
            val ang = (u = "angstrom" orelse u = "angstroms" orelse u = "\195\165" orelse u = "\195\133")
        in finish t (Q.Req_cm (Q.Cm_layers (ratOf (g1 low (valOf th)), ang))) end
      else if isSome ar andalso has "\\bgraphene\\b" low andalso has "\\bmass\\b|\\bweigh\\w*\\b|\\bhow (?:much|heavy)\\b" low
              andalso has "\\bsingle[- ]layer\\b|\\bmonolayer\\b|\\bone layer\\b|\\bgraphene sheet\\b|\\bof graphene\\b" low then
        let val u = valOf (grp low (valOf ar) 2)
            val cm2 = (String.isPrefix "c" u orelse has "centi" u)
        in finish t (Q.Req_cm (Q.Cm_mass (ratOf (g1 low (valOf ar)), cm2))) end
      else NONE
    end

  (* ---------- coldchain, coldchain-v2 ---------- *)
  val TEMP = "(-?\\d+(?:\\.\\d+)?)\\s*(?:\194\176\\s*|degrees?\\s*)?(f|c)\\b"
  val foodWords = "\\bfood\\b|\\bhold\\w*\\b|\\bcool\\w*\\b|\\breheat\\w*\\b|\\bcook\\w*\\b|\\bfridge\\b|\\brefrigerat\\w*\\b|\\bcooler\\b|\\bdate mark\\w*\\b|\\bdiscard\\b|\\bdanger zone\\b|\\btcs\\b|\\bleftovers?\\b|\\bsoup\\b|\\bchili\\b|\\brice\\b"
  val cdTempFull = "(-?\\d+(?:\\.\\d+)?)\\s*(?:\194\176\\s*|degrees?\\s*)?(f|c|fahrenheit|celsius)\\b"
  val coolRx = "\\bcool\\w*\\b.*?\\bfrom\\s+" ^ TEMP ^ ".*?\\bto\\s+" ^ TEMP ^ ".*?\\b(?:in|within|over|took)\\s+(-?\\d+(?:\\.\\d+)?)\\s*(hours?|hrs?|minutes?)"
  val days = [("monday", Q.Monday), ("tuesday", Q.Tuesday), ("wednesday", Q.Wednesday), ("thursday", Q.Thursday),
              ("friday", Q.Friday), ("saturday", Q.Saturday), ("sunday", Q.Sunday)]

  fun tempOf v u = Q.Temp (ratOf v, String.isPrefix "c" u)

  fun coldchainCore text =
    let val t = collapse text
    in
      if Narrow.narrative t andalso not (has "\\bfood code\\b" (lower t)) then NONE
      else
        let
          val low = lower t
          val ts = map (fn m => tempOf (g1 low m) (valOf (grp low m 2))) (findall cdTempFull low)
          fun cool () =
            case search coolRx low of
              NONE => NONE
            | SOME m =>
                let val req = Q.Req_cd (Q.Cd_cool (tempOf (g1 low m) (valOf (grp low m 2)), tempOf (valOf (grp low m 3)) (valOf (grp low m 4)),
                                                  Q.Dur (ratOf (valOf (grp low m 5)), String.isPrefix "min" (valOf (grp low m 6)))))
                in if Q.answers req then SOME req else NONE end
        in
          if not (has foodWords low) then NONE
          else case cool () of
            SOME req => SOME req
          | NONE =>
            if has "\\bcold[- ]hold\\w*\\b|\\bfridge\\b|\\brefrigerat\\w*\\b|\\bcooler\\b|\\bwalk-in\\b" low andalso not (null ts)
               andalso has "\\bokay\\b|\\bok\\b|\\bsafe\\b|\\bcomply|\\bcompliant\\b|\\ballowed\\b|\\bgood enough\\b|\\bcold enough\\b|\\bmeet\\b|\\bwithin\\b" low then
              SOME (Q.Req_cd (Q.Cd_cold (hd ts)))
            else if has "\\bhot[- ]hold\\w*\\b|\\bsteam table\\b|\\bwarmer\\b|\\bchafing\\b" low andalso not (null ts)
                    andalso not (has "\\breheat" low) then
              SOME (Q.Req_cd (Q.Cd_hot (hd ts)))
            else if has "\\bcook\\w*\\b|\\binternal temp\\w*\\b|\\bdone\\b|\\bminimum (?:internal )?temp\\w*\\b" low
                    andalso has "\\btemp\\w*\\b|\\bhow hot\\b|\\bdegrees\\b|\\bdone\\b" low then
              (if has "\\b(?:poultry|chicken|turkey|duck|stuffing|stuffed)\\b" low then SOME (Q.Req_cd (Q.Cd_cook Q.Cook_poultry))
               else if has "\\bground (?:beef|meat|pork)\\b|\\bhamburger\\b|\\bburgers?\\b|\\bsausage\\b" low then SOME (Q.Req_cd (Q.Cd_cook Q.Cook_ground))
               else if has "\\b(?:steak|pork chop|whole[- ]muscle|roast|fish|seafood|salmon|shrimp|eggs?)\\b" low then SOME (Q.Req_cd (Q.Cd_cook Q.Cook_whole))
               else NONE)
            else if has "\\breheat\\w*\\b" low andalso has "\\btemp\\w*\\b|\\bhow hot\\b|\\bdegrees\\b|\\bhot hold\\w*\\b" low then
              SOME (Q.Req_cd Q.Cd_reheat)
            else if has "\\bout of (?:temperature|temp)\\b|\\bat room temperature\\b|\\btime as a (?:public health )?control\\b|\\bwithout temperature control\\b|\\bsitting out\\b|\\bleft out\\b" low
                    andalso has "\\bhours?\\b|\\bhow long\\b" low then
              (case search ("(-?\\d+(?:\\.\\d+)?)\\s*(?:hours?|hrs?)\\b") low of
                 SOME hm => if not (has "\\bhow long\\b" low) then SOME (Q.Req_cd (Q.Cd_tphc (SOME (ratOf (g1 low hm)))))
                            else SOME (Q.Req_cd (Q.Cd_tphc NONE))
               | NONE => SOME (Q.Req_cd (Q.Cd_tphc NONE)))
            else if has "\\bdate mark\\w*\\b|\\bdiscard by\\b|\\buse by\\b|\\bhow long\\b.*\\b(?:fridge|refrigerat\\w*|keep)\\b|\\bkeep\\b.*\\b(?:fridge|refrigerat\\w*)\\b" low then
              (case search ("\\b(?:made|prepared|opened|cooked|prepped)\\s+(?:on\\s+)?(monday|tuesday|wednesday|thursday|friday|saturday|sunday)\\b") low of
                 SOME dm => SOME (Q.Req_cd (Q.Cd_date (SOME (#2 (valOf (List.find (fn (n, _) => n = valOf (grp low dm 1)) days))))))
               | NONE => SOME (Q.Req_cd (Q.Cd_date NONE)))
            else if has "\\bdanger zone\\b" low then SOME (Q.Req_cd Q.Cd_danger)
            else NONE
        end
    end

  val foodish = "\\btime as a (?:public health )?control\\b|\\bsandwich\\w*|\\bsalad\\b|\\bmeat\\b|\\bchicken\\b|\\bdish\\b|\\bstock\\b|\\bmeals?\\b|\\bbeans\\b|\\bpasta\\b"
  fun coldchainV2 text =
    let
      val t0 = collapse text
      val t1 = replaceAll "\\bhamburgers\\b" "hamburger" t0
      val low = lower t1
      val viaCool =
        if has "\\bcool\\w*\\b" low then
          let
            val hm = search "\\b(?:in|within|over|took|taking)\\s+(\\d+(?:\\.\\d+)?)\\s*(hours?|hrs?|minutes?)\\b" low
            val a = search ("\\bfrom\\s+" ^ TEMP ^ "(?:\\s+down)?\\s+to\\s+" ^ TEMP) low
            val b = search ("\\b(?:after reaching|once (?:it|at)|at)\\s+" ^ TEMP ^ "[^?]*?\\bto\\s+" ^ TEMP) low
            val m = case a of SOME x => SOME x | NONE => b
          in
            case (m, hm) of
              (SOME mm, SOME h) =>
                coldchainCore ("Food cooled from " ^ g1 low mm ^ " " ^ valOf (grp low mm 2) ^ " to " ^ valOf (grp low mm 3) ^ " "
                               ^ valOf (grp low mm 4) ^ " in " ^ g1 low h ^ " " ^ valOf (grp low h 2) ^ ".")
            | _ => NONE
          end
        else NONE
    in
      case viaCool of
        SOME r => SOME r
      | NONE =>
        let val t2 = if has foodish low andalso not (has "\\bfood\\b" low) then "Food: " ^ t1 else t1
        in coldchainCore t2 end
    end

  (* ---------- dispatch ---------- *)
  val organs = ["carboncapture", "airquality", "climate", "carbonmat", "coldchain", "coldchain-v2"]

  fun wrap f text =
    case f text of
      NONE => NONE
    | SOME req => SOME req

  fun byId "carboncapture" = carboncapture
    | byId "airquality" = airquality
    | byId "climate" = climate
    | byId "carbonmat" = carbonmat
    | byId "coldchain" = coldchainV2
    | byId "coldchain-v2" = coldchainV2
    | byId other = raise Fail ("unknown specialist " ^ other)

  (* Both coldchain manifests use the completed reader. The family asks each
     domain in a fixed order, taking its first recognized request. *)
  val familyOrder = ["airquality", "carbonmat", "coldchain-v2", "climate", "carboncapture"]

  fun recognize mode text =
    if mode = "family" then
      let fun go [] = NONE
            | go (id :: ids) = case byId id text of SOME r => SOME (id, r) | NONE => go ids
      in go familyOrder end
    else Option.map (fn r => (mode, r)) (byId mode text)
end
