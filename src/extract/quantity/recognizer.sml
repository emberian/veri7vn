(* UNTRUSTED. The English recognizer for the quantity family: a hand port of
   the regular expressions and branch order of
     upstream/root/specialists/densities/organ_densities_v1.py   (DensitiesOrgan)
     upstream/root/specialists/units/organ_units_v1.py           (UnitsOrgan)
     upstream/root/specialists/units-v3/organ_units_v{2,3}.py    (UnitsOrganV2, V3)
     upstream/root/specialists/springs/organ_springs_v1.py       (SpringsOrgan)
     upstream/root/specialists/fluids/organ_fluids_v1.py         (FluidsOrgan)
     upstream/root/specialists/fuels/organ_fuels_v1.py           (FuelsOrgan)
   and of their shared narrowing rule narrow_v1.py. It reads numbers and words
   off the question and builds a typed Quantity.request; it computes nothing.
   Every value, decline and response text comes from the verified HOL kernel
   (Quantity.reply_of). NONE means the question is not taken (the organ
   returns None).

   Tables are not duplicated here: unit names come from Quantity.unit_names,
   and each organ's i-th unit or material pattern is paired with the i-th
   entry of the HOL list for that organ (Quantity.dens_vol_units,
   Quantity.material_order, ...), whose factors tables_check.py checks against
   the organ files. What is ported by hand, and so untrusted, is the patterns
   and the branch order.

   Matching is case-insensitive by lower-casing pattern and text (all organ
   patterns use re.I or lower-cased text). \w and \d are ASCII here.

   Differences from the organs, all in the kernel's favour and none on the
   panels: a zero spring constant, stretch or mass reaches the kernel, which
   declines it as impossible (the organ raises ZeroDivisionError); the units
   organ v2's re-rendering of v1's float into exact form is not needed (the
   kernel computes exactly). *)
structure Recognizer :
sig
  val organs : string list
  val recognize : string -> string -> (string * Quantity.request) option
end =
struct
  structure Q = Quantity

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

  (* These physical formulas consume nonnegative magnitudes. NUM must not
     silently turn a stated negative mass, volume, depth or stiffness positive.
     Linear/affine unit conversions use their own signed-number grammar. *)
  fun negativeMagnitude text = has "(?:^|[^\\w])(?:-|\226\136\146)\\s*\\d|\\b(?:negative|minus)\\s+\\d" (lower text)

  (* ---------- densities ---------- *)
  val matPats = zip3 ([
      "(?:fresh |pure |liquid )?water", "sea ?water|salt water", "ice", "alumin(?:i)?um",
      "(?:mild |carbon |structural )?steel", "(?:pure )?iron", "copper", "gold", "silver", "lead",
      "concrete", "(?:window |soda-lime )?glass", "petrol|gasoline", "diesel(?: fuel)?",
      "ethanol|ethyl alcohol", "mercury", "air", "granite", "brass", "titanium", "platinum", "zinc",
      "nickel", "(?:whole )?milk", "honey", "uranium", "tungsten", "magnesium", "olive oil"],
    Q.material_order, "material_order")
  val mWater = List.nth (Q.material_order, 0)
  val mSea = List.nth (Q.material_order, 1)
  val mAir = List.nth (Q.material_order, 16)

  (* Explicit phase is a material cue only when it matches this table's
     ordinary-state entry. This is not a model of melting or thermal
     expansion: liquid copper and solid mercury must not use these rows. *)
  fun phaseMention phase m low = List.exists (fn (pat, mat) => mat = m andalso
      has ("\\b" ^ phase ^ "\\s+(?:" ^ pat ^ ")\\b") low) matPats
  fun phaseKnown m low = List.exists (fn p => phaseMention p m low)
      ["liquid", "solid", "gaseous", "metallic"]
  fun phaseFits m low =
      (not (phaseMention "liquid" m low) orelse List.exists (fn x => x = m) Q.fluid_order)
      andalso (not (phaseMention "solid" m low) orelse
        (m <> mAir andalso not (List.exists (fn x => x = m) Q.fluid_order)))
      andalso (not (phaseMention "gaseous" m low) orelse m = mAir)
      andalso (not (phaseMention "metallic" m low) orelse List.exists (fn x => x = m) Q.elements)

  fun materials low =
    let val found = List.mapPartial (fn (p, m) => if has ("\\b(?:" ^ p ^ ")\\b") low then SOME m else NONE) matPats
    in if List.exists (fn m => m = mSea) found andalso List.exists (fn m => m = mWater) found
       then List.filter (fn m => m <> mWater) found else found
    end

  val volUnitPats = zip3 ([
      "m3|m\\^3|m" ^ cube ^ "|cubic met(?:re|er)s?", "litres?|liters?|l\\b", "ml|millilit(?:re|er)s?",
      "cm3|cm\\^3|cm" ^ cube ^ "|cubic centimet(?:re|er)s?|cc\\b", "(?:us )?gallons?",
      "ft3|ft\\^3|ft" ^ cube ^ "|cubic f(?:oo|ee)t"], Q.dens_vol_units, "dens_vol_units")
  val massUnitPats = zip3 (["kg|kilograms?|kilos?", "g\\b|grams?", "tonnes?|metric tons?", "lbs?|pounds?"],
                           Q.dens_mass_units, "dens_mass_units")

  fun amounts pats low =
    List.concat (map (fn (p, u) =>
      map (fn m => (ratOf (g1 low m), u)) (findall (NUM ^ "\\s*(?:" ^ p ^ ")(?![a-z])") low)) pats)

  fun askUnit pats ask default =
    case List.find (fn (p, _) => has ("\\b(?:in|how many)\\s+(?:" ^ p ^ ")") ask) pats of
      SOME (_, u) => u
    | NONE => default

  fun densFloat low mats =
    if not (has "\\b(?:solid|block|piece|lump|bar|cube|chunk|sphere|ball)\\b" low) then NONE
    else case search "\\b(?:in|on)\\s+(?:the\\s+)?([a-z ]+?)\\??$" low of
      NONE => NONE
    | SOME m =>
        (case materials (g1 low m) of
           [fluid] =>
             (case List.filter (fn k => k <> fluid) mats of
                [obj] => SOME (Q.Floats (obj, fluid))
              | _ => NONE)
         | _ => NONE)

  fun densities text =
    let
      val t = collapse text
    in
      if t = "" orelse Narrow.narrative t orelse negativeMagnitude t then NONE
      else
        let
          val low = lower t
          val ask = lower (Narrow.last_sentence t)
          val mats = materials low
          val densityWord = has "\\bdensit(?:y|ies)\\b" low
          val massAsk = has ("\\b(?:mass|how heavy|weigh|how many (?:kg|kilograms?|grams?|tonnes?|pounds?|lbs?)\\b|"
                             ^ "in (?:kg|kilograms?|grams?|tonnes?|pounds?)\\b)") ask
          val volAsk = has ("\\b(?:volume|how much space|how many (?:litres?|liters?|cubic|gallons?|ml|millilit)|"
                            ^ "in (?:litres?|liters?|cubic|gallons?|m3|ml))") ask
        in
          case mats of
            [] => NONE
          | [m] =>
              let
                val vols = amounts volUnitPats low
                val masses = amounts massUnitPats low
                val none = null vols andalso null masses
              in
                if not (phaseFits m low) then NONE
                else if densityWord andalso none andalso List.exists (fn e => e = m) Q.elements
                        andalso not (phaseKnown m low) then NONE
                else if densityWord andalso none andalso has "\\b(?:what|how|give|tell|find)\\b" ask then
                  SOME (Q.Density m)
                else if massAsk andalso length vols = 1 andalso null masses then
                  SOME (Q.MassOf (m, SOME (hd vols), askUnit massUnitPats ask (hd Q.dens_mass_units)))
                else if volAsk andalso length masses = 1 andalso null vols then
                  SOME (Q.VolumeOf (m, SOME (hd masses), askUnit volUnitPats ask (hd Q.dens_vol_units)))
                else if (massAsk orelse volAsk) andalso none andalso Narrow.short_direct t
                        andalso String.isSuffix "?" t then
                  SOME (if massAsk then Q.MassOf (m, NONE, hd Q.dens_mass_units)
                        else Q.VolumeOf (m, NONE, hd Q.dens_vol_units))
                else NONE
              end
          | _ =>
              if has "\\bfloat|sink\\b" low andalso length mats = 2 then densFloat low mats else NONE
        end
    end

  (* ---------- units v1, v2, v3 ---------- *)
  val deg = "\194\176"   (* U+00B0 DEGREE SIGN, UTF-8 *)
  (* the organ's TEMP has two non-ASCII names; HOL string literals are ASCII *)
  val extraNames = [(deg ^ "c", "c"), (deg ^ "f", "f")]
  fun charLen s = size s - (if String.isPrefix deg s then 1 else 0)
  val names =
    let
      val all = map #1 Q.unit_names @ map #1 extraNames
      (* stable sort by length, longest first, as sorted(..., key=len, reverse=True) *)
      fun ins (x, []) = [x]
        | ins (x, y :: ys) = if charLen x > charLen y then x :: y :: ys else y :: ins (x, ys)
    in rev (foldl (fn (x, acc) => rev (ins (x, rev acc))) [] all) end
  fun escape s = String.translate (fn c => if Char.isAlphaNum c then String.str c else "\\" ^ String.str c) s
  val UNIT_RX = "(" ^ String.concatWith "|" (map escape names) ^ ")"
  val CONV = "(-?\\d+(?:\\.\\d+)?)\\s*" ^ UNIT_RX ^ "\\s+(?:to|in|into|=|as|comes?\\s+to\\s+in)\\s+" ^ UNIT_RX ^ "\\b"
  val HOWMANY = "how many\\s+" ^ UNIT_RX ^ "\\s+(?:are\\s+)?(?:in|is|make up)\\s+(?:an?\\s+|one\\s+)?(-?\\d+(?:\\.\\d+)?\\s*)?"
    ^ UNIT_RX ^ "\\b"
  val QTY = "(-?\\d+(?:\\.\\d+)?)\\s*" ^ UNIT_RX ^ "(?![\\w/])"
  val TARGET = "\\bhow many\\s+" ^ UNIT_RX ^ "(?![\\w/])"
  val TWO = "^\\s*(?:i have|we have|there (?:is|are)|it(?:'s| is)|it weighs|it measures|it runs for)\\s+(-?\\d+(?:\\.\\d+)?)\\s*"
    ^ UNIT_RX ^ "\\s*[.!]\\s*(?:how many\\s+" ^ UNIT_RX ^ "\\s+(?:is|are|does)\\s+that|what is that in\\s+" ^ UNIT_RX
    ^ "|convert (?:that|it) to\\s+" ^ UNIT_RX ^ ")\\s*[?.!]?\\s*$"

  fun unitOf name =
    let val n = case List.find (fn (e, _) => e = name) extraNames of SOME (_, a) => a | NONE => name
    in case Q.lookup_unit n of SOME u => u | NONE => raise Fail ("unit name not in HOL table: " ^ name) end

  fun trim s = collapse s

  fun unitsV1 text =
    let
      val low = lower (collapse text)
    in
      case search CONV low of
        SOME m => SOME (Q.Convert (ratOf (g1 low m), unitOf (valOf (grp low m 2)), unitOf (valOf (grp low m 3))))
      | NONE =>
          (case search HOWMANY low of
             SOME m =>
               let val v = case grp low m 2 of SOME s => ratOf (trim s) | NONE => Q.mk_rat 1 1
               in SOME (Q.Convert (v, unitOf (valOf (grp low m 3)), unitOf (valOf (grp low m 1)))) end
           | NONE => NONE)
    end

  fun unitsV2 text =
    let val t = collapse text
    in
      if Narrow.narrative t then NONE
      else
        let
          val low = lower t
          val r =
            case unitsV1 t of
              SOME r => SOME r
            | NONE =>
                (case (search QTY low, search TARGET low) of
                   (SOME q, SOME tg) =>
                     if Narrow.sentences t = 1 andalso Narrow.words t <= 12
                        andalso valOf (grp low q 2) <> valOf (grp low tg 1) then
                       (case unitsV1 ("Convert " ^ g1 low q ^ " " ^ valOf (grp low q 2) ^ " to " ^ g1 low tg) of
                          SOME r2 => if Q.answers r2 then SOME r2 else NONE
                        | NONE => NONE)
                     else NONE
                 | _ => NONE)
        in
          case r of
            SOME req => if not (Q.answers req) andalso not (Narrow.short_direct t) then NONE else SOME req
          | NONE => NONE
        end
    end

  fun unitsV3 text =
    let val low = lower text
    in
      case search TWO low of
        SOME m =>
          let val target = valOf (firstGroup low m [3, 4, 5])
          in unitsV2 ("Convert " ^ g1 low m ^ " " ^ valOf (grp low m 2) ^ " to " ^ target) end
      | NONE => unitsV2 text
    end

  (* ---------- springs ---------- *)
  val K = NUM ^ "\\s*(?:n/m|newtons? per met(?:re|er))\\b|\\bk\\s*=\\s*" ^ NUM ^ "\\s*(?:n/m)?|"
    ^ "(?:spring constant|stiffness)\\s+(?:of\\s+|is\\s+)?" ^ NUM
  val FORCE = NUM ^ "\\s*(?:n|newtons?)\\b(?!\\s*/|\\s*per)"
  val springMassPats = zip3 ([NUM ^ "\\s*(?:kg|kilograms?)\\b", NUM ^ "\\s*(?:g|grams?)\\b"],
                             Q.spring_mass_units, "spring_mass_units")
  val dispPats = zip3 ([NUM ^ "\\s*(?:m|met(?:re|er)s?)\\b(?!\\s*/|\\s*per)", NUM ^ "\\s*(?:cm|centimet(?:re|er)s?)\\b",
                        NUM ^ "\\s*(?:mm|millimet(?:re|er)s?)\\b"], Q.spring_disp_units, "spring_disp_units")

  fun amountsRx pats s = List.concat (map (fn (p, u) => map (fn m => (ratOf (g1 s m), u)) (findall p s)) pats)
  fun one [x] = SOME x
    | one _ = NONE

  fun springs text =
    let val t = collapse text
    in
      if t = "" orelse Narrow.narrative t orelse negativeMagnitude t orelse not (has "\\bsprings?\\b|\\bhooke\\b|\\bspring constant\\b" (lower t)) then NONE
      else
        let
          val low = lower t
          val ask = lower (Narrow.last_sentence t)
          val km = search K low
          val k = Option.map (fn m => ratOf (valOf (firstGroup low m [1, 2, 3]))) km
          val rest = if isSome km then replaceAll K " " low else low
          val forces = map (fn m => ratOf (g1 rest m)) (findall FORCE rest)
          val masses = amountsRx springMassPats rest
          val disps = amountsRx dispPats rest
          fun need r = if Narrow.short_direct t then SOME r else NONE
          val askedForce = has ("\\b(?:what|how much|which|find the|calculate the|determine the)\\s+(?:\\w+\\s+){0,2}?force\\b") ask
        in
          if has "\\bperiod\\b|\\bfrequency\\b|\\bhow long\\b.*\\boscillat|\\boscillat\\w*\\b.*\\bhow long\\b" ask
             andalso has "\\bmass\\b|\\bkg\\b|\\bg\\b|\\bgrams?\\b|\\bblock\\b|\\bweight\\b" low then
            let
              val freq = has "\\bfrequency\\b" ask
              val r = if freq then Q.SpringFrequency (k, one masses) else Q.SpringPeriod (k, one masses)
            in if isSome k andalso length masses = 1 then SOME r else need r end
          else if has "\\b(?:energy|work)\\b" ask then
            let val r = Q.SpringEnergy (k, one disps)
            in if isSome k andalso length disps = 1 then SOME r else need r end
          else if has "\\bspring constant\\b|\\bstiffness\\b|\\bwhat is k\\b" ask andalso not askedForce then
            let val r = Q.SpringConstant (one forces, one disps)
            in if length forces = 1 andalso length disps = 1 then SOME r else need r end
          else if has ("\\b(?:how far|extension|displacement|how much (?:does|will|would) .{0,40}"
                       ^ "(?:stretch|extend|compress))\\b") ask andalso not askedForce then
            let val r = Q.SpringExtension (k, one forces)
            in if isSome k andalso length forces = 1 then SOME r else need r end
          else if askedForce then
            let val r = Q.SpringForce (k, one disps)
            in if isSome k andalso length disps = 1 then SOME r else need r end
          else NONE
        end
    end

  (* ---------- fluids ---------- *)
  val fluidPats = zip3 (["(?:fresh |pure )?water", "sea ?water|salt water|the sea|the ocean|ocean", "mercury",
                         "petrol|gasoline", "diesel", "ethanol", "olive oil", "honey", "milk"],
                        Q.fluid_order, "fluid_order")
  val solidPats = zip3 (["ice", "aluminium", "steel", "concrete", "glass", "granite", "iron", "copper", "gold",
                         "lead", "brass"], Q.solid_order, "solid_order")
  val DEPTH = NUM ^ "\\s*(?:m|met(?:re|er)s?)\\b(?!\\s*/|\\s*per|\\s*\\^|\\s*3|" ^ cube ^ ")\\s*(?:deep|down|below|under|beneath|depth)?"
  val fluidVolPats = zip3 ([NUM ^ "\\s*(?:m3|m\\^3|m" ^ cube ^ "|cubic met(?:re|er)s?)",
                            NUM ^ "\\s*(?:litres?|liters?|l)\\b",
                            NUM ^ "\\s*(?:cm3|cm\\^3|cm" ^ cube ^ "|cubic centimet(?:re|er)s?)"],
                           Q.fluid_vol_units, "fluid_vol_units")
  val fFresh = List.nth (Q.fluid_order, 0)
  val fSea = List.nth (Q.fluid_order, 1)

  fun fluidOf low =
    let
      val found = List.mapPartial (fn (p, f) => if has ("\\b(?:" ^ p ^ ")\\b") low then SOME f else NONE) fluidPats
      val found = if List.exists (fn f => f = fSea) found andalso List.exists (fn f => f = fFresh) found
                  then List.filter (fn f => f <> fFresh) found else found
    in one found end

  fun fluids text =
    let val t = collapse text
    in
      if t = "" orelse Narrow.narrative t orelse negativeMagnitude t then NONE
      else
        let
          val low = lower t
          val ask = lower (Narrow.last_sentence t)
          val fl = fluidOf low
          fun need r = if Narrow.short_direct t then SOME r else NONE
        in
          if has "\\bpressure\\b" ask andalso has "\\b(?:deep|depth|below|under|beneath|down)\\b" low then
            (case fl of
               NONE => NONE
             | SOME f =>
                 let
                   val ds = map (fn m => (ratOf (g1 low m), Q.U_metre)) (findall DEPTH low)
                   val absolute = has "\\b(?:absolute|total)\\b" low
                   val r = if absolute then Q.PressureAbs (f, one ds) else Q.PressureGauge (f, one ds)
                 in if length ds = 1 then SOME r else need r end)
          else if has "\\bbuoyan\\w*\\b|\\bupthrust\\b" low andalso has "\\bforce\\b|\\bupthrust\\b|\\bhow much\\b" ask then
            (case fl of
               NONE => NONE
             | SOME f =>
                 let val vs = amountsRx fluidVolPats low
                     val r = Q.Buoyant (f, one vs)
                 in if length vs = 1 then SOME r else need r end)
          else if has "\\b(?:fraction|percent(?:age)?|how much)\\b.*\\b(?:below|under|submerged|beneath)\\b" ask
                  andalso has "\\bfloat" low then
            (case fl of
               NONE => NONE
             | SOME f =>
                 (case List.mapPartial (fn (p, s) => if has ("\\b" ^ p ^ "\\b") low then SOME s else NONE) solidPats of
                    [s] => SOME (Q.Submerged (s, f))
                  | _ => NONE))
          else NONE
        end
    end

  (* ---------- fuels ---------- *)
  val fuelPats = zip3 (["petrol|gasoline|motor gasoline", "diesel(?: fuel| oil)?|gas oil",
                        "jet (?:fuel|kerosene)|kerosene|jet a-?1?", "lpg|liquefied petroleum gas|propane",
                        "natural gas|methane gas", "(?:bituminous |hard )?coal", "lignite|brown coal", "anthracite",
                        "wood|firewood|logs", "charcoal"], Q.fuel_order, "fuel_order")
  val fCoal = List.nth (Q.fuel_order, 5)
  val fAnthracite = List.nth (Q.fuel_order, 7)
  val fuelMassPats = zip3 ([NUM ^ "\\s*(?:tonnes?|metric tons?|t)\\b", NUM ^ "\\s*(?:kg|kilograms?|kilos?)\\b",
                            NUM ^ "\\s*(?:g|grams?)\\b"], Q.fuel_mass_units, "fuel_mass_units")
  val fuelEnergyPats = zip3 ([NUM ^ "\\s*(?:kwh|kilowatt[- ]hours?)\\b", NUM ^ "\\s*(?:mwh|megawatt[- ]hours?)\\b",
                              NUM ^ "\\s*(?:mj|megajoules?)\\b", NUM ^ "\\s*(?:gj|gigajoules?)\\b"],
                             Q.fuel_energy_units, "fuel_energy_units")

  fun fuels text =
    let val t = collapse text
    in
      if t = "" orelse Narrow.narrative t orelse negativeMagnitude t then NONE
      else
        let
          val low = lower t
          val found = List.mapPartial (fn (p, f) => if has ("\\b(?:" ^ p ^ ")\\b") low then SOME f else NONE) fuelPats
          val found = if List.exists (fn f => f = fAnthracite) found andalso List.exists (fn f => f = fCoal) found
                      then List.filter (fn f => f <> fCoal) found else found
        in
          case found of
            [f] =>
              if not (has "\\bburn\\w*|combust\\w*|energy|heat|co2|carbon dioxide|emission|emit\\w*|calorific|kwh|mj\\b" low)
              then NONE
              else if has (NUM ^ "\\s*(?:litres?|liters?|l|gallons?|gal|m3|cubic)\\b") low then NONE
              else
                let
                  val ask = lower (Narrow.last_sentence t)
                  val masses = amountsRx fuelMassPats low
                  val energies = amountsRx fuelEnergyPats low
                  fun need r = if Narrow.short_direct t then SOME r else NONE
                in
                  if has "\\bco2\\b|carbon dioxide|emission|emit" ask then
                    let val r = Q.FuelCO2 (f, one masses)
                    in if length masses = 1 then SOME r else need r end
                  else if has ("\\bhow (?:much|many kilograms?|many kg|many tonnes?)\\b.*\\b(?:need|needed|required|burn)\\b|"
                               ^ "\\bmass of\\b.*\\bneeded\\b") ask andalso not (null energies) andalso null masses then
                    SOME (Q.FuelMassNeeded (f, hd energies))
                  else if has "\\b(?:energy|heat|how many (?:kwh|kilowatt|mj|megajoules|gj))\\b" ask then
                    if length masses <> 1 then
                      if has "\\b(?:per kilogram|per kg|calorific|energy content|energy density)\\b" low andalso null masses
                      then SOME (Q.FuelNCV f)
                      else need (Q.FuelEnergy (f, NONE, Q.U_megajoule))
                    else
                      SOME (Q.FuelEnergy (f, SOME (hd masses),
                                          if has "\\bkwh|kilowatt" ask then Q.U_kilowatt_hour else Q.U_megajoule))
                  else NONE
                end
          | _ => NONE
        end
    end

  (* ---------- dispatch ---------- *)
  val organs = ["densities", "units", "units-v3", "springs", "fluids", "fuels"]

  fun byId "densities" = densities
    | byId "units" = unitsV1
    | byId "units-v3" = unitsV3
    | byId "springs" = springs
    | byId "fluids" = fluids
    | byId "fuels" = fuels
    | byId other = raise Fail ("unknown specialist " ^ other)

  (* The family: each manifest's organ in a fixed order, the first that takes
     the question answers it. Fuels before densities (two fuel questions name
     petrol or diesel, which the densities organ also knows); units-v3 stands
     for both units manifests (it takes every units-v1 panel question). *)
  val familyOrder = ["fuels", "springs", "fluids", "densities", "units-v3"]

  fun recognize mode text =
    if mode = "family" then
      let fun go [] = NONE
            | go (id :: ids) = case byId id text of SOME r => SOME (id, r) | NONE => go ids
      in go familyOrder end
    else Option.map (fn r => (mode, r)) (byId mode text)
end
