(* UNTRUSTED. The English recognizer for the energy family: a hand port of the
   regular expressions and branch order of
     upstream/root/specialists/thermo/organ_thermo_v1.py                (ThermoOrgan)
     upstream/root/specialists/energy-v2/organ_energy_v{1,2}.py          (EnergyOrganV2)
     upstream/root/specialists/energy-v3/organ_energy_v3.py              (EnergyOrganV3)
     upstream/root/specialists/hvac/organ_hvac_v1.py                     (HvacOrgan)
     upstream/root/specialists/renewables/organ_renewables_v1.py         (RenewablesOrgan)
     upstream/root/specialists/iot/organ_iot_v1.py                       (IotOrgan)
   and of their shared narrowing rule narrow_v1.py (hvac, renewables, iot).
   It reads numbers and words off the question and builds a typed
   Energy.family_request; it computes no result. Every value, decline and
   response text comes from the verified HOL kernel (Energy.reply_of). NONE
   means the question is not taken (the organ returns None).

   Tables are not duplicated here except where the organ keeps the name of a
   material in a dictionary: Energy.mat_table pairs each name with the HOL
   material, and tables_check.py checks the HOL text against the organ.

   Matching is case-insensitive by lower-casing the text (the patterns are
   written in lower case). \w and \d are ASCII here. Non-ASCII symbols in the
   organs' patterns (degree sign, superscripts, multiplication sign, Delta,
   mu) are written as their UTF-8 bytes.

   Differences from the organs, all in the kernel's favour and none on the
   panels: a zero divisor (volume, current, reference, rated power) reaches the
   kernel, which refuses it as impossible (the organs raise); the ADC code is
   the exact floor (the organ adds 1e-9 to absorb float error); temperatures
   are exact rationals of kelvin. *)
structure Recognizer :
sig
  val organs : string list
  val recognize : string -> string -> (string * Energy.family_request) option
end =
struct
  structure E = Energy

  val cache : (string * Regex.regex) list ref = ref []
  fun lower s = String.map Char.toLower s
  fun re p =
    case List.find (fn (q, _) => q = p) (!cache) of
      SOME (_, r) => r
    | NONE => let val r = Regex.compile p in cache := (p, r) :: !cache; r end

  fun search p s = Regex.search (re p) s
  fun has p s = isSome (search p s)
  fun findall p s = Regex.findall (re p) s
  exception UnboundNumeral
  val numericText = ref ""
  val numericTokens : ExactNumeric.token list ref = ref []
  val capturedValues : (string * ExactNumeric.rational) list ref = ref []
  fun tokensFor s =
    if s = !numericText then !numericTokens
    else let val ts = ExactNumeric.scan s
             val _ = numericText := s
             val _ = numericTokens := ts
             val _ = capturedValues := []
         in ts end
  fun numericHead lit = size lit > 0 andalso
    (Char.isDigit (String.sub (lit,0)) orelse Char.contains "+-." (String.sub (lit,0))
     orelse String.isPrefix "\226\136\146" lit)
  (* A scalar role must cover one whole lexer-issued token. Alternation groups
     go through this same gate. Its exact value comes from that token. *)
  fun grp s (m as {groups,...} : Regex.match) g =
    case Regex.group s m g of
      NONE => NONE
    | SOME lit =>
        if not (numericHead lit) then SOME lit
        else let val ts = tokensFor s
                 val span = Vector.sub (groups,g)
             in case List.find (fn ExactNumeric.Number {start,stop,...} => span = SOME (start,stop)
                                | _ => false) ts of
                  SOME (ExactNumeric.Number {value,...}) =>
                    (capturedValues := (lit,value) :: !capturedValues; SOME lit)
                | _ => raise UnboundNumeral
             end
  fun g1 s m = valOf (grp s m 1)
  fun firstGroup s m gs = case List.mapPartial (grp s m) gs of x :: _ => SOME x | [] => NONE

  fun replaceAllWith p rep s =
    let
      fun go i [] acc = String.concat (rev (String.extract (s, i, NONE) :: acc))
        | go i ((m as {start, stop, ...} : Regex.match) :: ms) acc =
            go stop ms (rep m :: String.substring (s, i, start - i) :: acc)
    in go 0 (findall p s) [] end

  fun collapse s = String.concatWith " " (String.tokens Char.isSpace s)

  (* exact rationals as (numerator, denominator) pairs of IntInf *)
  type q = IntInf.int * IntInf.int
  fun mk ((n, d) : q) : E.rat = E.mk_rat n d
  fun qmul ((a, b) : q) ((c, d) : q) : q = (a * c, b * d)
  fun qdiv ((a, b) : q) ((c, d) : q) : q = (a * d, b * c)
  fun qint (n : int) : q = (IntInf.fromInt n, 1)
  fun qpow10 (e : int) : q = if e >= 0 then (IntInf.pow (10, e), 1) else (1, IntInf.pow (10, ~e))

  fun dec lit : q =
    case List.find (fn (key,_) => key = lit) (!capturedValues) of
      SOME (_,value) => value
    | NONE => raise UnboundNumeral
  fun integerOf lit = let val (n,d) = dec lit
                      in if d = 1 then n else raise UnboundNumeral end
  fun gq s m = dec (g1 s m)
  fun gqn s m n = dec (valOf (grp s m n))
  fun nat (n : IntInf.int) = E.nat_of_integer n

  (* ---------- narrow_v1 ---------- *)
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
  (* ---------- thermo ---------- *)
  val deg = "\194\176"
  val sup3 = "\194\179"
  val sup2 = "\194\178"
  (* This role pattern only finds candidate spans. ExactNumeric issues the
     tokens and values; grp rejects candidates that cover only a suffix. *)
  val NUMERAL = "([+\\-\226\136\146]?(?:\\d+(?:,\\d{3})*(?:\\.\\d+)?|\\.\\d+)(?:e[+-]?\\d+)?(?:\\s*/\\s*[+\\-\226\136\146]?(?:\\d+(?:,\\d{3})*(?:\\.\\d+)?|\\.\\d+)(?:e[+-]?\\d+)?)?)"
  val NT = NUMERAL
  val TEMP_RX = NT ^ "\\s*(?:" ^ deg ^ "\\s*|degrees?\\s*)?(c|k|f|celsius|kelvin|fahrenheit)\\b"

  fun tunit u = if String.isPrefix "c" u then E.TU_C else if String.isPrefix "f" u then E.TU_F else E.TU_K

  (* is the temperature below absolute zero? (routing only; the kernel decides again) *)
  fun below ((n, d) : q, u) =
    let val c = case u of E.TU_C => n * 100 < ~27315 * d
                        | E.TU_F => n * 100 < ~45967 * d
                        | E.TU_K => n < 0
    in c end

  fun thermoTrigger low =
    has "\\bheat\\b|\\benergy\\b|\\bgas\\b|\\bcarnot\\b|\\befficien|\\bradiat" low

  fun massKg low =
    case search (NT ^ "\\s*(kg|kilograms?|g|grams?)\\b") low of
      NONE => NONE
    | SOME m => SOME (gq low m, if String.isPrefix "k" (valOf (grp low m 2)) then E.MU_kg else E.MU_g)
  fun massOpt low = Option.map (fn (v, u) => (mk v, u)) (massKg low)

  fun thermo text =
    let
      val t = collapse text
      val low = lower t
      val tms = List.map (fn m => (gq low m, tunit (valOf (grp low m 2)))) (findall TEMP_RX low)
      val tl = List.map (fn (v, u) => E.Temp (mk v, u)) tms
      fun req q = SOME (E.FThermo (E.Thermo (tl, q)))
      (* Fuel combustion, heating values and useful delivered heat describe
         different operations from sensible/latent material heating. Explicit supported model names
         can still select their own thermodynamic equations. *)
      val fuelProcess = has "\\b(?:burn(?:ing|ed|t|s)?|combust(?:ion|ing|ed|s)?|calorific|heating values?|hhv|lhv|heat of combustion)\\b" low
      val deliveredHeat = has "\\b(?:useful|usable|delivered)\\s+(?:heat|thermal energy)\\b" low
      val namedModel = has "\\bcarnot\\b|\\bideal (?:heat )?engine\\b|\\bideal gas\\b|\\bpv ?= ?nrt\\b|\\bstefan|\\bblack ?body\\b|\\bradiat\\w* power\\b|\\bpower radiated\\b" low
    in
      if (fuelProcess orelse deliveredHeat) andalso not namedModel then NONE
      else if List.exists below tms then
        (if thermoTrigger low then req E.TAny else NONE)
      else if has "\\bcarnot\\b|\\bmaximum (?:theoretical )?efficiency\\b|\\bideal (?:heat )?engine\\b" low then
        let val hotFirst = not (has "\\bcold\\b[^.?]*\\bhot\\b" low) orelse has "\\bhot\\b[^.?]*\\bcold\\b" low
        in req (E.TCarnot hotFirst) end
      else if has "\\bideal gas\\b|\\bpv ?= ?nrt\\b|\\bmoles? of (?:an? )?(?:ideal )?gas\\b|\\bgas\\b.*\\b(?:pressure|volume)\\b" low
              andalso not (has "\\bheat\\b" low) then
        let
          val n = Option.map (fn m => mk (gq low m)) (search (NT ^ "\\s*(?:mol|moles)\\b") low)
          val p = Option.map (fn m =>
                    (mk (gq low m),
                     case valOf (grp low m 2) of
                       "pa" => E.PU_Pa | "kpa" => E.PU_kPa | "atm" => E.PU_atm | _ => E.PU_bar))
                  (search (NT ^ "\\s*(pa|kpa|atm|bar)\\b") low)
          val v = Option.map (fn m =>
                    let val u = valOf (grp low m 2)
                    in (mk (gq low m),
                        if String.isPrefix "m" u andalso u <> "ml" then E.VU_m3
                        else if String.isPrefix "l" u then E.VU_L else E.VU_mL) end)
                  (search (NT ^ "\\s*(m\\^?3|m" ^ sup3 ^ "|l|liters?|litres?|ml)\\b") low)
        in req (E.TGas (n, p, v)) end
      else if has "\\bstefan|\\bblack ?body\\b|\\bradiat\\w* power\\b|\\bpower radiated\\b" low then
        let
          val a = Option.map (fn m => mk (gq low m))
                    (search (NT ^ "\\s*(m\\^?2|m" ^ sup2 ^ "|square met(?:er|re)s?)\\b") low)
          val e = case search ("\\bemissivity\\s*(?:of|is|=)?\\s*" ^ NT) low of
                    SOME m => mk (gq low m) | NONE => mk (qint 1)
        in req (E.TRad (a, e)) end
      else if has "\\b(?:melt|freeze|boil|vapori[sz]e|evaporate|condense)\\b" low
              andalso has "\\bheat\\b|\\benergy\\b|\\bjoules?\\b" low
              andalso has "\\b(?:water|ice|steam)\\b" low then
        let val m = massOpt low
        in if has "\\bmelt|\\bfreeze" low then req (E.TFusion m) else req (E.TVapor m) end
      else if has "\\bheat\\b|\\benergy\\b|\\bjoules?\\b" low
              andalso has "\\braise|\\bheat(?:ing)?\\b.*\\bfrom\\b|\\bwarm|\\bcool|\\bchange\\b|\\bincrease\\b|\\bby \\d" low then
        let
          val mat = List.find (fn (name, _) => has ("\\b" ^ name ^ "\\b") low) E.mat_table
          val cm = search ("\\bspecific heat(?: capacity)?\\s*(?:of|is|=)?\\s*" ^ NT) low
          val cs = case cm of
                     SOME m => E.C_given (mk (gq low m))
                   | NONE => (case mat of SOME (_, mt) => E.C_mat mt | NONE => E.C_none)
          val dm = search ("\\bby\\s+" ^ NT ^ "\\s*(?:" ^ deg ^ "\\s*|degrees?\\s*)?(?:c|k|celsius|kelvin)\\b") low
          val dq = case dm of SOME m => E.DT_by (mk (gq low m)) | NONE => E.DT_temps
        in req (E.TSens (massOpt low, cs, dq)) end
      else NONE
    end

  (* ---------- energy-v2 / energy-v3 ---------- *)
  val NE = "(\\d+(?:,\\d{3})*(?:\\.\\d+)?)"
  val NS = NUMERAL
  val cent = "\194\162"

  fun wattsOf low =
    case search (NE ^ "\\s*(kw|kilowatts?|w|watts?)\\b(?!\\s*h\\b)") low of
      NONE => NONE
    | SOME m => SOME (qmul (gq low m) (if String.isPrefix "k" (valOf (grp low m 2)) then qint 1000 else qint 1))

  fun hoursOf low : E.hspec option =
    case search (NE ^ "\\s*(?:hours?|hrs?|h)\\s*(?:a|per|each)\\s*day\\b") low of
      SOME m =>
        let val h = mk (gq low m)
        in case search (NE ^ "\\s*days?\\b") low of
             SOME d => SOME (E.H_pdd (h, mk (gq low d)))
           | NONE =>
               if has "\\b(?:a|per|each|in a|for a|over a)\\s+year\\b|\\bannual|\\byearly\\b" low then SOME (E.H_pdy h)
               else if has "\\b(?:a|per|each|in a|for a|over a)\\s+month\\b|\\bmonthly\\b" low then SOME (E.H_pdm h)
               else SOME (E.H_day h)
        end
    | NONE =>
        (case (case search ("\\bfor\\s+" ^ NE ^ "\\s*(?:hours?|hrs?|h)\\b") low of
                 SOME m => SOME m
               | NONE => search (NE ^ "\\s*(?:hours?|hrs?)\\b") low) of
           SOME m => SOME (E.H_tot (mk (gq low m)))
         | NONE =>
             (case search (NE ^ "\\s*minutes?\\b") low of
                SOME m => SOME (E.H_min (mk (gq low m)))
              | NONE => NONE))

  (* $ per kWh *)
  fun tariffOf low : E.rat option =
    case (case search ("\\$\\s*" ^ NE ^ "\\s*(?:per|/|a|an)\\s*kwh\\b") low of
            SOME m => SOME m
          | NONE => search (NE ^ "\\s*(?:\\$|dollars?)\\s*(?:per|/|a)\\s*kwh\\b") low) of
      SOME m => SOME (mk (gq low m))
    | NONE =>
        (case search (NE ^ "\\s*(?:cents?|c|" ^ cent ^ ")\\s*(?:per|/|a|an)\\s*kwh\\b") low of
           SOME m => SOME (mk (qdiv (gq low m) (qint 100)))
         | NONE => NONE)

  val PAYBACK = "\\bpayback|\\bpay (?:for )?itself|\\bbreak even\\b|\\bpay back\\b"

  fun paybackV2 low =
    let
      val save = case search ("\\bsav\\w*\\s+(?:about\\s+|me\\s+|us\\s+)?\\$\\s*" ^ NE ^ "\\s*(?:a|per|each)\\s*(year|month)") low of
                   SOME m => SOME m
                 | NONE => search ("\\$\\s*" ^ NE ^ "\\s*(?:a|per|each)\\s*(year|month)\\s*(?:in\\s+)?sav") low
      val costs = List.filter (fn (m : Regex.match) =>
                    case save of SOME (s : Regex.match) => not (#start s <= #start m andalso #start m < #stop s)
                               | NONE => true)
                  (findall ("\\$\\s*" ^ NE ^ "(?:\\s*(k))?") low)
      val cost = case costs of
                   m :: _ => SOME (mk (qmul (gq low m) (if isSome (grp low m 2) then qint 1000 else qint 1)))
                 | [] => NONE
      val sv = Option.map (fn m => (mk (gq low m), valOf (grp low m 2) = "month")) save
    in E.HPayback (cost, sv) end

  val SWAP = "\\b(?:replac\\w*|swap\\w*|switch\\w*)\\b.*?" ^ NE ^ "\\s*(?:w|watts?)\\b.*?\\b(?:with|for|to)\\b.*?" ^ NE ^ "\\s*(?:w|watts?)\\b"

  fun energyV1 (low : string) : E.home_req option =
    if has "\\bbattery|\\bpower bank\\b|\\bups\\b" low andalso has "\\bhow long\\b|\\bruntime\\b|\\brun time\\b|\\blast\\b" low then
      let
        val wh = search (NS ^ "\\s*(kwh|wh)\\b") low
        val ah = search (NS ^ "\\s*ah\\b") low
        val v = search (NS ^ "\\s*v(?:olts?)?\\b") low
        val load = search ("(?<![\\w.-])(?:a|an|the)?\\s*" ^ NS ^ "\\s*(kw|kilowatts?|w|watts?)\\b(?!\\s*h\\b)\\s*(?:device|load|appliance|fridge|light|laptop|lamp|fan|tv|router|pump|heater)?") low
        val cap =
          case wh of
            SOME m => SOME (if valOf (grp low m 2) = "kwh" then E.Cap_kwh (mk (gq low m)) else E.Cap_wh (mk (gq low m)))
          | NONE => (case (ah, v) of
                       (SOME a, SOME vv) => SOME (E.Cap_ahv (mk (gq low a), mk (gq low vv)))
                     | _ => NONE)
        val load = Option.map (fn m => mk (qmul (gq low m) (if String.isPrefix "k" (valOf (grp low m 2)) then qint 1000 else qint 1))) load
        fun fraction name =
          let val rx = "(?:" ^ name ^ ")\\s*(?:of|is|=|:)?\\s*" ^ NT ^ "\\s*(%)?"
              val revRx = NT ^ "\\s*(%)\\s*(?:" ^ name ^ ")"
          in case (case search rx low of SOME m => SOME m | NONE => search revRx low) of
               NONE => NONE
             | SOME m => SOME (mk (if isSome (grp low m 2) then qdiv (gq low m) (qint 100) else gq low m))
          end
        val eff = fraction "(?:inverter )?efficiency"
        val depth = fraction "(?:usable )?depth(?:[- ]of[- ]discharge)?|dod|usable capacity"
        val adjusted = has "\\befficiency\\b|\\bdepth\\b|\\bdod\\b|\\busable capacity\\b|-\\d" low
        val unknownFactor =
          (has "efficiency" low andalso not (isSome eff)) orelse
          (has "depth|dod|usable capacity" low andalso not (isSome depth)) orelse
          has "round[- ]?trip" low
      in if unknownFactor then SOME E.HRuntimeMissingFactors
         else if adjusted then
           SOME (E.HRuntimeAdjusted (cap, load,
             case eff of SOME x => x | NONE => mk (qint 1),
             case depth of SOME x => x | NONE => mk (qint 1)))
         else SOME (E.HRuntime (cap, load)) end
    else if has "\\bsolar\\b|\\bpv\\b|\\bpanels?\\b" low andalso has "\\bsun ?hours?\\b|\\bpeak sun\\b|\\bsunlight hours?\\b" low then
      let
        val k = search (NE ^ "\\s*(kw|kilowatts?|w|watts?)\\b(?!\\s*h\\b)") low
        val sh = case search (NE ^ "\\s*(?:peak\\s+)?(?:sun|sunlight)[ -]?hours?\\b") low of
                   SOME m => SOME m
                 | NONE => search ("\\b(?:peak\\s+)?sun[ -]?hours?\\s*(?:of|is|=)?\\s*" ^ NE) low
        val isk = case k of SOME m => String.isPrefix "k" (valOf (grp low m 2)) | NONE => true
        val np = Option.map (fn m => mk (gq low m)) (search (NE ^ "\\s*(?:x\\s*)?panels?\\b") low)
        val der = search (NE ^ "\\s*%\\s*(?:system\\s+)?(?:losses|loss)\\b") low
        val eff = search ("\\b(?:derate|efficiency|performance ratio)\\s*(?:of|is|=)?\\s*" ^ NE ^ "\\s*(%?)") low
        val derate =
          case der of
            SOME m => E.Dr_loss (mk (gq low m))
          | NONE =>
              (case eff of
                 SOME m =>
                   let val x = gq low m
                       val pct = valOf (grp low m 2) <> ""
                       val big = #1 x > #2 x   (* number above 1 *)
                   in E.Dr_eff (mk (if pct orelse big then qdiv x (qint 100) else x)) end
               | NONE => E.Dr_none)
        val per = if has "\\b(?:a|per|each|in a)\\s+year\\b|\\bannual|\\byearly\\b" low then E.Per_year
                  else if has "\\b(?:a|per|each|in a)\\s+month\\b|\\bmonthly\\b" low then E.Per_month
                  else E.Per_day
      in SOME (E.HSolar (Option.map (fn m => (mk (gq low m), isk)) k, np,
                         Option.map (fn m => mk (gq low m)) sh, derate, per)) end
    else
      case search SWAP low of
        SOME m =>
          let
            val a = mk (gq low m)
            val b = mk (gqn low m 2)
            val rest = String.extract (low, #stop m, NONE) ^ " " ^ String.substring (low, 0, #start m)
          in SOME (E.HSwap (a, b, hoursOf rest, tariffOf low)) end
      | NONE =>
          if has "\\bhow much (?:energy|electricity|power)\\b|\\bkwh\\b|\\bhow much (?:does|will|would) it cost\\b|\\bcost to run\\b|\\bhow much .* cost\\b|\\benergy (?:use|usage|consumption)\\b" low then
            let val w = wattsOf low
                val h = hoursOf low
                val cost = has "\\bcost\\b|\\bprice\\b|\\bbill\\b|\\bspend\\b|\\bhow much money\\b" low
            in if (isSome w andalso isSome h) orelse has "\\bkwh\\b|\\bwatts?\\b|\\bkw\\b" low
               then SOME (E.HEnergy (Option.map mk w, h, tariffOf low, cost)) else NONE end
          else NONE

  fun energyV2 (t : string) : E.home_req option =
    let val low = lower t
    in if has PAYBACK low then SOME (paybackV2 low)
       else energyV1 (replaceAllWith "\\bcosts\\b" (fn _ => "cost") low)
    end

  val PASSIVE = "\\b(?:an?\\s+|the\\s+)?(\\d+(?:\\.\\d+)?)\\s*(w|watts?)\\s+([a-z]+(?:\\s[a-z]+)?)\\s+(?:is|was|gets|being|are)?\\s*(?:replaced|swapped)\\s+(?:by|with|for)\\s+(?:an?\\s+|the\\s+)?(\\d+(?:\\.\\d+)?)\\s*(w|watts?)\\b"

  fun homeV2 text =
    let val t = collapse text
    in Option.map E.FHome (energyV2 t) end

  fun homeV3 text =
    let
      val t = lower (collapse text)
      val t = replaceAllWith PASSIVE (fn m => "replace a " ^ g1 t m ^ " w " ^ valOf (grp t m 3) ^ " with a " ^ valOf (grp t m 4) ^ " w") t
      val r = energyV2 t
    in
      case r of
        SOME (E.HEnergy _) =>
          if has "\\bsav(?:e|ed|es|ing|ings)\\b" t then NONE else Option.map E.FHome r
      | _ => Option.map E.FHome r
    end

  (* ---------- narrowing wrapper (hvac, renewables, iot) ---------- *)
  val ANSWERED = fn (r : E.family_request) => E.answered (E.reply_of r)

  fun narrowed text (r : E.family_request option) =
    let val t = collapse text
    in
      if Narrow.narrative t then NONE
      else case r of
             NONE => NONE
           | SOME req => if ANSWERED req orelse Narrow.short_direct t then SOME req else NONE
    end

  (* Physical magnitudes keep their signs; a later typed guard decides domain.
     Prevent a failed negative match from restarting at its unsigned suffix. *)
  val NE = NUMERAL

  (* ---------- hvac ---------- *)
  val times = "\195\151"
  fun roomDimensions low =
    case search (NE ^ "\\s*(?:ft|feet|foot)?\\s*(?:x|by|" ^ times ^ ")\\s*" ^ NE ^ "\\s*(?:ft|feet|foot)?\\s*(?:x|by|" ^ times ^ ")\\s*" ^ NE ^ "\\s*(?:ft|feet|foot)?\\b") low of
      SOME m => SOME [gq low m, gqn low m 2, gqn low m 3]
    | NONE => NONE

  fun volumeOf low : E.rat option =
    case roomDimensions low of
      SOME [a,b,c] => SOME (mk (qmul (qmul a b) c))
    | _ => Option.map (fn m => mk (gq low m)) (search (NE ^ "\\s*(?:cubic feet|cu\\.? ?ft|ft3|ft" ^ sup3 ^ ")\\b") low)

  val DELTA = "(?:temperature (?:difference|rise|drop|change)|delta[- ]?t|dt|\206\180t|\206\148t)"

  fun hvac text =
    let
      val t = collapse text
      val low0 = lower t
      val low = replaceAllWith "\\br-?(\\d+(?:\\.\\d+)?)\\b"
        (fn m => "r value " ^ valOf (Regex.group low0 m 1)) low0
      val cfm = search (NE ^ "\\s*cfm\\b") low
      val ach = search (NE ^ "\\s*(?:ach|air changes? (?:per|an|each) hour)\\b") low
      val sq = NE ^ "\\s*(?:sq\\.? ?ft|square feet|ft2|ft" ^ sup2 ^ ")\\b"
      fun first (a : E.family_request option) b = case a of SOME _ => a | NONE => b
      val sizing =
        if has "\\bwhat size (?:ac|air conditioner|furnace|heat pump|unit)\\b|\\bhow big (?:an? )?(?:ac|air conditioner|furnace|heat pump|unit)\\b" low
        then SOME (E.FHvac E.VSizing) else NONE
      val tons =
        if has "\\btons?\\b" low andalso has "\\bbtu" low andalso not (isSome cfm) then
          let val bm = search (NE ^ "\\s*btu(?:/h|/hr| per hour)?\\b") low
              val tm = search (NE ^ "\\s*tons?\\b") low
          in case bm of
               SOME m => if has "\\bhow many tons\\b|\\bin tons\\b|\\bto tons\\b|\\btons\\?" low
                         then SOME (E.FHvac (E.VTons (mk (gq low m)))) else
                         (case tm of SOME m2 => SOME (E.FHvac (E.VBtuh (mk (gq low m2)))) | NONE => NONE)
             | NONE => (case tm of SOME m2 => SOME (E.FHvac (E.VBtuh (mk (gq low m2)))) | NONE => NONE)
          end
        else NONE
      val airch =
        if has "\\bach\\b|\\bair changes?\\b" low then
          let val badDimensions = case roomDimensions low of SOME xs => List.exists (fn (n,_) => n <= 0) xs | NONE => false
              val v = volumeOf low
              val c = Option.map (fn m => mk (gq low m)) cfm
              val a = Option.map (fn m => mk (gq low m)) ach
          in
            if badDimensions then SOME (E.FHvac E.VBadDimensions)
            else if not (isSome v) then SOME (E.FHvac (E.VAch (NONE, NONE)))
            else if isSome cfm andalso not (has "\\bhow many cfm\\b|\\bwhat cfm\\b|\\bcfm (?:do i need|is needed|needed|required)\\b" low)
              then SOME (E.FHvac (E.VAch (c, v)))
            else if isSome ach then SOME (E.FHvac (E.VCfm (a, v)))
            else SOME (E.FHvac (E.VAch (NONE, v)))
          end
        else NONE
      val sens =
        case cfm of
          SOME cm =>
            if has "\\bsensible\\b|\\bheat\\b|\\bbtu" low then
              let val dm = case search ("\\b" ^ DELTA ^ "\\s*(?:of|is|=)?\\s*" ^ NE) low of
                             SOME m => SOME m
                           | NONE => search (NE ^ "\\s*(?:" ^ deg ^ "\\s*|degrees?\\s*)?f?\\s*(?:temperature (?:difference|rise|drop)|delta[- ]?t|difference|rise|drop)\\b") low
              in SOME (E.FHvac (E.VSens (mk (gq low cm), Option.map (fn m => mk (gq low m)) dm))) end
            else NONE
        | NONE => NONE
      val cond =
        let val rm = case search ("\\br(?:[- ]?value)?\\s*(?:of|is|=)?\\s*" ^ NE ^ "\\b") low of
                       SOME m => SOME m
                     | NONE => search ("\\br-?" ^ NE ^ "\\b") low
        in
          case rm of
            SOME rmm =>
              if has "\\bheat loss\\b|\\bheat (?:flow|transfer|gain)\\b|\\bbtu" low then
                let
                  val am = search sq low
                  val r = mk (dec (valOf (firstGroup low rmm [1, 2])))
                  val a = Option.map (fn m => mk (gq low m)) am
                  val hdd = search (NE ^ "\\s*(?:hdd|heating degree days?)\\b") low
                in
                  case hdd of
                    SOME h => SOME (E.FHvac (E.VSeasonal (a, r, mk (gq low h))))
                  | NONE =>
                      let
                        val dm = case search ("\\b" ^ DELTA ^ "\\s*(?:of|is|=)?\\s*" ^ NE) low of
                                   SOME m => SOME m
                                 | NONE => search (NE ^ "\\s*(?:" ^ deg ^ "\\s*|degrees?\\s*)?f?\\s*(?:temperature )?(?:difference|delta)\\b") low
                        val temps = List.map (fn m => mk (gq low m)) (findall (NE ^ "\\s*(?:" ^ deg ^ "\\s*|degrees?\\s*)?f\\b") low)
                        val d = case dm of
                                  SOME m => SOME (E.DS_direct (mk (gq low m)))
                                | NONE => (case temps of t0 :: t1 :: _ => SOME (E.DS_pair (t0, t1)) | _ => NONE)
                      in SOME (E.FHvac (E.VCond (a, r, d))) end
                end
              else NONE
          | NONE => NONE
        end
    in
      narrowed text (first sizing (first tons (first airch (first sens cond))))
    end

  (* ---------- renewables ---------- *)
  fun pct low name : E.rat option =
    case (case search (name ^ "[^0-9%+-]{0,25}?" ^ NE ^ "\\s*%") low of
            SOME m => SOME m
          | NONE => search (NE ^ "\\s*%\\s*" ^ name) low) of
      SOME m => SOME (mk (qdiv (gq low m) (qint 100)))
    | NONE => Option.map (fn m => mk (gq low m)) (search (name ^ "[^0-9+-]{0,20}?" ^ NE ^ "\\b") low)

  val MS = "(?:m/s|mph|km/h|knots?)"
  val CUBIC_PER_S = "m3\\s*/\\s*s|m" ^ sup3 ^ "\\s*/\\s*s|cubic met(?:er|re)s? per second|cumecs"

  fun renewables text =
    let
      val t = collapse text
      val low = lower t
      val one_ = mk (qint 1)
      fun req r = SOME (E.FRen r)
      val wind = has "\\bwind\\b|\\bturbine\\b|\\brotor\\b|\\bblades?\\b" low
      val result =
        if has "\\bhydro\\w*\\b|\\bdam\\b|\\bturbine\\b.*\\bwater\\b|\\bhead of\\b|\\bflow rate\\b" low andalso has CUBIC_PER_S low then
          let
            val q = search (NE ^ "\\s*(?:" ^ CUBIC_PER_S ^ ")") low
            val h = case search ("\\b(?:head|drop|fall|falling|height)\\s*(?:of|is|=)?\\s*" ^ NE ^ "\\s*m\\b") low of
                      SOME m => SOME m
                    | NONE => search (NE ^ "\\s*m\\s*(?:of\\s+)?(?:head|drop|fall)\\b") low
          in
            case (q, h) of
              (SOME qm, SOME hm) =>
                let val eta = case pct low "\\befficien\\w*" of SOME e => e | NONE => one_
                in req (E.RHydro (mk (gq low qm), mk (dec (valOf (firstGroup low hm [1, 2]))), eta)) end
            | _ => NONE
          end
        else if has "\\bsolar\\b|\\bpv\\b|\\bphotovoltaic\\b|\\bpanels?\\b|\\bmodules?\\b" low
                andalso has ("m2|m" ^ sup2 ^ "|square met(?:er|re)s?") low andalso has "\\befficien\\w*" low then
          let
            val a = search (NE ^ "\\s*(?:m2|m" ^ sup2 ^ "|square met(?:er|re)s?)(?!\\s*/)") low
            val irr = search (NE ^ "\\s*w\\s*/\\s*(?:m2|m" ^ sup2 ^ "|square met(?:er|re))") low
            val eff = pct low "\\befficien\\w*"
          in
            case (a, eff) of
              (SOME am, SOME e) =>
                let val i = case irr of
                              SOME m => E.Irr_given (mk (gq low m))
                            | NONE => if has "\\bstc\\b|\\bstandard test conditions\\b|\\bpeak sun\\b|\\bfull sun\\b" low then E.Irr_stc else E.Irr_none
                in req (E.RPV (mk (gq low am), i, e)) end
            | _ => NONE
          end
        else if has "\\bcapacity factor\\b" low then
          let
            val rated = search (NE ^ "\\s*(kw|mw|gw)\\b(?!h)") low
            val energy = search (NE ^ "\\s*(kwh|mwh|gwh)\\b") low
            val cf = pct low "\\bcapacity factor\\b"
          in
            case rated of
              NONE => NONE
            | SOME rm =>
                let
                  val pw = fn u => case u of "kw" => 3 | "mw" => 6 | _ => 9
                  val R = qmul (gq low rm) (qpow10 (pw (valOf (grp low rm 2))))
                  val H = case search (NE ^ "\\s*hours\\b") low of SOME m => gq low m | NONE => qint 8760
                in
                  case energy of
                    SOME em =>
                      if has "\\bwhat is (?:the |its )?capacity factor\\b|\\bcalculate (?:the )?capacity factor\\b|\\bfind (?:the )?capacity factor\\b|\\bcapacity factor\\?" low then
                        req (E.RCapF (mk R, mk (qmul (gq low em) (qpow10 (pw (String.substring (valOf (grp low em 2), 0, 2))))), mk H))
                      else (case cf of SOME c => req (E.RAnnual (mk R, mk H, c)) | NONE => NONE)
                  | NONE => (case cf of SOME c => req (E.RAnnual (mk R, mk H, c)) | NONE => NONE)
                end
          end
        else if not wind then NONE
        else
          let
            val sp = findall (NE ^ "\\s*(" ^ MS ^ ")\\b") low
          in
            if length sp >= 2 andalso has "\\bhow many times\\b|\\bfactor\\b|\\bratio\\b|\\bhow much more\\b|\\bincrease\\b|\\bchange\\b" low
               andalso not (has "\\bdiameter\\b|\\bradius\\b|\\bswept\\b" low) then
              (if valOf (grp low (hd sp) 2) <> valOf (grp low (hd (tl sp)) 2) then NONE
               else
                 let
                   val mm = search ("\\bfrom\\s+" ^ NE ^ "\\s*" ^ MS ^ "\\s+to\\s+" ^ NE) low
                   val mr = search ("\\bto\\s+" ^ NE ^ "\\s*" ^ MS ^ "[^.?]{0,20}?\\bfrom\\s+" ^ NE) low
                 in
                   case (mm, mr) of
                     (SOME m, _) => req (E.RRatio (mk (gq low m), mk (gqn low m 2)))
                   | (NONE, SOME m) => req (E.RRatio (mk (gqn low m 2), mk (gq low m)))
                   | _ => NONE
                 end)
            else
              let
                val vm = search (NE ^ "\\s*m/s\\b") low
                val dm = search ("\\b(?:rotor|blade)?\\s*diameter\\s*(?:of|is|=)?\\s*" ^ NE ^ "\\s*m\\b|" ^ NE ^ "\\s*m\\s*(?:rotor\\s+)?diameter\\b|" ^ NE ^ "[- ]m(?:eter|etre)?\\s+rotor\\b") low
                val rm = search ("\\b(?:blade length|blades?|radius)\\s*(?:of|is|=)?\\s*" ^ NE ^ "\\s*m\\b|" ^ NE ^ "\\s*m\\s*(?:long\\s+)?blades?\\b|" ^ NE ^ "\\s*m\\s*radius\\b") low
                val am = search ("\\bswept area\\s*(?:of|is|=)?\\s*" ^ NE ^ "\\s*(?:m2|m" ^ sup2 ^ ")|" ^ NE ^ "\\s*(?:m2|m" ^ sup2 ^ ")\\s*swept") low
                fun anyg m = case firstGroup low m [1, 2, 3] of SOME s => dec s | NONE => raise Fail "no group"
              in
                case vm of
                  SOME v =>
                    if (isSome dm orelse isSome rm orelse isSome am) andalso has "\\bpower\\b|\\bhow much\\b|\\boutput\\b|\\bwatts?\\b|\\bkw\\b|\\bmw\\b" low then
                      let
                        val geo = case (am, dm, rm) of
                                    (SOME m, _, _) => E.G_swept (mk (anyg m))
                                  | (NONE, SOME m, _) => E.G_diam (mk (anyg m))
                                  | (NONE, NONE, SOME m) => E.G_rad (mk (anyg m))
                                  | _ => raise Fail "unreachable"
                        val rho = case search ("\\b(?:air )?density\\s*(?:of|is|=)?\\s*" ^ NE ^ "\\s*kg") low of
                                    SOME m => mk (gq low m) | NONE => E.air_density
                        val cp = pct low "\\b(?:cp|power coefficient|efficiency)\\b"
                      in req (E.RWind (geo, mk (gq low v), rho, cp)) end
                    else NONE
                | NONE => NONE
              end
          end
    in
      if has "\\befficien\\w*\\b|\\bpower coefficient\\b|\\bcp\\b" low
         andalso not (isSome (pct low "\\b(?:efficien\\w*|power coefficient|cp)\\b"))
      then NONE
      else narrowed text result
    end

  (* ---------- iot ---------- *)
  val CUR = "(a|ma|ua|\194\181a|\206\188a|microamps?|milliamps?|amps?)\\b"
  fun toMa (v : q) (u0 : string) : q =
    let
      val u1 = if String.isSuffix "s" u0 then String.substring (u0, 0, size u0 - 1) else u0
      val u = case u1 of "amp" => "a" | "milliamp" => "ma" | "microamp" => "ua"
                       | "\194\181a" => "ua" | "\206\188a" => "ua" | x => x
    in qmul v (case u of "a" => qint 1000 | "ma" => qint 1 | _ => qpow10 ~3) end

  val LIFE = "\\bhow long\\b|\\blife\\b|\\blast\\b|\\bhours\\b|\\bdays\\b"

  fun iot text =
    let
      val t = collapse text
      val low = lower t
      fun req r = SOME (E.FIot r)
      val bits = search "\\b(\\d{1,2})[- ]?bits?\\b" low
      val vref = case search ("\\b(?:vref|reference(?: voltage)?|v_?ref|full[- ]scale)\\s*(?:of|is|=|:)?\\s*" ^ NE ^ "\\s*v\\b") low of
                   SOME m => SOME (mk (gq low m))
                 | NONE => Option.map (fn m => mk (gq low m)) (search (NE ^ "\\s*v\\s*(?:reference|vref|full[- ]scale)\\b") low)
      fun battery () : E.family_request option option =
        (* SOME r: the battery block returned r; NONE: it fell through to data rate *)
        let
          val cap = search (NE ^ "\\s*mah\\b") low
          val curs = List.map (fn m => (toMa (gq low m) (valOf (grp low m 2)))) (findall (NE ^ "\\s*" ^ CUR) low)
        in
          if not (has "\\bbattery\\b|\\bbatteries\\b|\\bcell\\b" low orelse has "\\baverage current\\b" low) then NONE
          else
            let
              val duty = case search ("\\b(?:awake|active|on|transmitting|duty cycle(?: of)?)\\s*(?:for\\s+)?" ^ NE ^ "\\s*%|" ^ NE ^ "\\s*%\\s*(?:of the time\\s+)?(?:duty cycle|awake|active|of the time)") low of
                           SOME m => SOME (qdiv (dec (valOf (firstGroup low m [1, 2]))) (qint 100))
                         | NONE => NONE
              val days = has "\\bdays?\\b" low andalso not (has "\\bhours\\b" low)
            in
              case duty of
                SOME d =>
                  let
                    val act = search (NE ^ "\\s*" ^ CUR ^ "\\s*(?:when\\s+|while\\s+)?(?:awake|active|on|transmitting)|(?:awake|active|transmitting)\\w*(?:(?:[^.;]|\\.(?=\\d)){0,30}?\\bat)?\\s*(?:current\\s*)?(?:of|is|=|at|draws)?\\s*" ^ NE ^ "\\s*" ^ CUR) low
                    val slp = search (NE ^ "\\s*" ^ CUR ^ "\\s*(?:when\\s+|while\\s+|in\\s+)?(?:asleep|sleep\\w*|idle)|(?:sleep\\w*|asleep|idle)(?:(?:[^.;]|\\.(?=\\d)){0,30}?\\bat)?\\s*(?:current\\s*)?(?:of|is|=|at|draws)?\\s*" ^ NE ^ "\\s*" ^ CUR) low
                    fun cur m = case (grp low m 1, grp low m 3) of
                                  (SOME v, _) => toMa (dec v) (valOf (grp low m 2))
                                | (NONE, SOME v) => toMa (dec v) (valOf (grp low m 4))
                                | _ => raise Fail "no current"
                  in
                    case (act, slp) of
                      (SOME a, SOME s) =>
                        (case cap of
                           SOME c => if has LIFE low
                                     then SOME (req (E.IBat (mk (gq low c), mk (cur a), mk (cur s), mk d, days)))
                                     else SOME (req (E.IAvgCur (mk (cur a), mk (cur s), mk d)))
                         | NONE => SOME (req (E.IAvgCur (mk (cur a), mk (cur s), mk d))))
                    | _ => SOME NONE
                  end
              | NONE =>
                  (case cap of
                     SOME c =>
                       if length curs = 1 andalso has LIFE low
                       then SOME (req (E.IBatConst (mk (gq low c), mk (hd curs), days)))
                       else NONE
                   | NONE => NONE)
            end
        end
      val adc =
        case bits of
          SOME bm =>
            if has "\\badc\\b|\\banalog[- ]to[- ]digital\\b|\\bconverter\\b" low then
              let val n = integerOf (g1 low bm)
              in
                if n < 1 orelse n > 32 then SOME NONE
                else
                  let val nn = nat n
                  in
                    if not (isSome vref) then SOME (req (E.IAdcLsb (nn, NONE)))
                    else if has "\\bresolution\\b|\\blsb\\b|\\bstep size\\b|\\bsmallest (?:change|step)\\b" low andalso not (has "\\breading\\b|\\bcode\\b|\\bcount\\b" low)
                      then SOME (req (E.IAdcLsb (nn, vref)))
                    else
                      let
                        val code = search "\\b(?:reading|code|count|value|output)\\s*(?:of|is|=|:)?\\s*(\\d+)\\b(?!\\s*(?:v|bit|mv))|\\breads\\s+(\\d+)\\b" low
                        val volt = search ("\\binput (?:of\\s+)?" ^ NE ^ "\\s*v\\b|" ^ NE ^ "\\s*v\\s*(?:input|signal|in)\\b|\\b(?:for|at)\\s+" ^ NE ^ "\\s*v\\b(?!\\s*(?:reference|vref|full))") low
                      in
                        if isSome code andalso has "\\bvolt\\w*\\b|\\bwhat voltage\\b|\\bin volts\\b" low andalso not (isSome volt) then
                          SOME (req (E.IAdcVolt (nn, vref, nat (integerOf (valOf (firstGroup low (valOf code) [1, 2]))))))
                        else if isSome volt andalso has "\\bcode\\b|\\breading\\b|\\bcount\\b|\\bdigital value\\b|\\boutput\\b" low then
                          SOME (req (E.IAdcCode (nn, vref, mk (dec (valOf (firstGroup low (valOf volt) [1, 2, 3]))))))
                        else SOME NONE
                      end
                  end
              end
            else NONE
        | NONE => NONE
      val result =
        case adc of
          SOME r => r
        | NONE =>
            if has "\\bnyquist\\b|\\bminimum sampl\\w+ (?:rate|frequency)\\b|\\bsample (?:at )?(?:least|minimum)\\b|\\bhow fast\\b.*\\bsampl" low then
              (case search (NE ^ "\\s*(hz|khz|mhz)\\b") low of
                 NONE => NONE
               | SOME m =>
                   let val sc = case valOf (grp low m 2) of "hz" => 0 | "khz" => 3 | _ => 6
                   in req (E.INyquist (mk (qmul (gq low m) (qpow10 sc)))) end)
            else
              (case battery () of
                 SOME r => r
               | NONE =>
                   let
                     val sps = search (NE ^ "\\s*(?:samples?(?:/s| per second| a second)|sps|hz)\\b") low
                     val bpsm = search "\\b(\\d+)[- ]?bits?\\s*(?:per sample|samples?|resolution|each)?\\b" low
                   in
                     case (sps, bpsm) of
                       (SOME s, SOME b) =>
                         if has "\\bdata rate\\b|\\bbit rate\\b|\\bthroughput\\b|\\bstorage\\b|\\bper day\\b|\\bbytes\\b|\\bbandwidth\\b" low then
                           let
                             val ch = case search "\\b(\\d+)\\s+(?:channels?|sensors?)\\b" low of
                                        SOME m => integerOf (g1 low m) | NONE => 1
                             val sv = mk (gq low s)
                             val bv = nat (integerOf (g1 low b))
                           in
                             if has "\\bper day\\b|\\ba day\\b|\\bdaily\\b|\\bstorage\\b" low
                             then req (E.IStorage (sv, bv, nat ch))
                             else req (E.IDataRate (sv, bv, nat ch))
                           end
                         else NONE
                     | _ => NONE
                   end)
    in narrowed text result end

  (* ---------- dispatch ---------- *)
  val organs = ["thermo", "energy-v2", "energy-v3", "hvac", "renewables", "iot"]

  fun byId "thermo" = thermo
    | byId "energy-v2" = homeV3
    | byId "energy-v3" = homeV3
    | byId "hvac" = hvac
    | byId "renewables" = renewables
    | byId "iot" = iot
    | byId other = raise Fail ("unknown specialist " ^ other)

  (* Manifest context plus family capability additions; used only to choose among them when no
     --specialist is given *)
  fun context "thermo" = "\\b(?:heat|energy|joules?|ideal gas|carnot|efficiency|stefan|black ?body|radiat\\w*|melt|boil|vapori[sz]e)\\b"
    | context "energy-v2" = "\\b(?:kwh|watts?|kw|battery|solar|payback|energy|electricity|power bank|tariff|bill)\\b|\\b(?:\\d+(?:\\.\\d*)?|\\.\\d+)\\s*w\\b|\\b(?:cost|price)\\b.*\\b(?:run|running|operate|operating)\\b"
    | context "energy-v3" = "\\b(?:kwh|watts?|kw|battery|solar|payback|energy|electricity|power bank|tariff|bill)\\b|\\b(?:\\d+(?:\\.\\d*)?|\\.\\d+)\\s*w\\b|\\b(?:cost|price)\\b.*\\b(?:run|running|operate|operating)\\b"
    | context "hvac" = "\\b(?:cfm|ach|air changes?|btu\\w*|tons?|r-?\\d+|r-value|heat loss|hvac|furnace|air conditioner|ac)\\b"
    | context "renewables" = "\\b(?:wind|turbine|rotor|capacity factor|solar|pv|photovoltaic|hydro\\w*|dam|betz)\\b"
    | context "iot" = "\\b(?:adc|analog[- ]to[- ]digital|battery|mah|duty cycle|nyquist|sampl\\w+|sensor|data rate|bit rate)\\b|\\baverage current\\b"
    | context other = raise Fail ("unknown specialist " ^ other)

  val familyOrder = ["thermo", "hvac", "renewables", "iot", "energy-v3"]

  fun recognizeUnchecked mode text =
    if mode = "family" then
      let val low = lower text
          fun go [] = NONE
            | go (id :: ids) =
                if has (context id) low then
                  (case byId id text of SOME r => SOME (id, r) | NONE => go ids)
                else go ids
      in go familyOrder end
    else Option.map (fn r => (mode, r)) (byId mode text)

  fun recognize mode text =
    if List.exists (fn ExactNumeric.Malformed _ => true | _ => false) (ExactNumeric.scan text)
    then NONE
    else (recognizeUnchecked mode text handle UnboundNumeral => NONE)
end
