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

  (* Every role capture resolves through the current lexer's token table.
     Text that merely looks like a token cannot supply a numeric value. *)
  exception UnboundNumeral
  val originalInput = ref ""
  val numericValues : (string * ExactNumeric.rational) list ref = ref []
  fun rationalOf token = case List.find (fn (key, _) => key = token) (!numericValues) of
      SOME (_, value) => value | NONE => raise UnboundNumeral
  fun ratOf token : Q.rat = let val (n, d) = rationalOf token in Q.mk_rat n d end
  fun withNumerals read text = case ExactNumeric.mask text of NONE => NONE
    | SOME {text = masked, numbers} =>
        let val previous = !numericValues
            val previousInput = !originalInput
            val _ = originalInput := text
            val _ = numericValues := numbers
            val answer = (read masked handle UnboundNumeral => NONE)
                handle e => (numericValues := previous; originalInput := previousInput; raise e)
            val _ = numericValues := previous
            val _ = originalInput := previousInput
        in answer end

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
    val RELATION = "\\b(?:qnum[0-9]+q|\\d+(?:\\.\\d+)?|one|two|three|four|five|six|seven|eight|nine|ten)\\s+(?:\\w+\\s+){0,2}"
      ^ "(?:more|less|fewer|longer|shorter)\\s+than\\b|\\b(?:twice|three times|half)\\s+(?:as\\s+\\w+\\s+as\\s+)?the\\s+\\w+\\b"
    val RATE = "\\b(?:qnum[0-9]+q|\\d+(?:\\.\\d+)?)\\s+[a-z]+\\s+(?:for|per|every)\\s+(?:qnum[0-9]+q|\\d+(?:\\.\\d+)?|a|an|one|each)\\s+[a-z]+"
    fun narrative t =
      let val low = lower t
      in sentences t >= 3 orelse words t > 40 orelse has RELATION low orelse has RATE low end
    fun short_direct t = sentences t <= 2 andalso words t <= 25 andalso not (narrative t)
  end

  val NUM = "(qnum[0-9]+q)"
  val cube = "\194\179"   (* U+00B3 SUPERSCRIPT THREE, UTF-8 *)

  (* These physical formulas consume nonnegative magnitudes. NUM must not
     silently turn a stated negative mass, volume, depth or stiffness positive.
     Linear/affine unit conversions use their own signed-number grammar. *)
  fun negativeMagnitude text = List.exists (fn (_, (n, _)) => n < 0) (!numericValues)
    orelse has ("\\b(?:negative|minus)\\s+" ^ NUM) (lower text)

  (* The shared adapter reads original spans. Marker ids are paired only with
     the exact scanner sequence that issued them; role regexes cannot invent a
     second number or reinterpret a requested output as a measured source. *)
  structure MI = MeasuredInput
  fun dimension (Q.Tmp _) = "temperature"
    | dimension (Q.Lin u) =
        if List.exists (fn v => u=v) [Q.U_metre,Q.U_kilometre,Q.U_centimetre,Q.U_millimetre,Q.U_inch,Q.U_foot,Q.U_yard,Q.U_mile,Q.U_nautical_mile] then "length"
        else if List.exists (fn v => u=v) [Q.U_kilogram,Q.U_gram,Q.U_milligram,Q.U_pound,Q.U_ounce,Q.U_tonne,Q.U_stone] then "mass"
        else if List.exists (fn v => u=v) [Q.U_pascal,Q.U_kilopascal,Q.U_bar,Q.U_atmosphere,Q.U_psi,Q.U_mmhg] then "pressure"
        else if List.exists (fn v => u=v) [Q.U_joule,Q.U_kilojoule,Q.U_megajoule,Q.U_gigajoule,Q.U_calorie,Q.U_kilocalorie,Q.U_kilowatt_hour,Q.U_megawatt_hour,Q.U_watt_hour,Q.U_millijoule,Q.U_milliwatt_hour,Q.U_btu] then "energy"
        else "other"
  fun specs (tag,dim,aliases) = map (fn alias => {alias=alias,tag=tag,dimension=dim,caseSensitive=false}:MI.unitSpec) aliases
  fun modelUnit tag = Q.lookup_unit tag
  val caseSymbols = ["pa","kpa","j","kj","kwh","Wh","mJ","MJ","GJ","mWh","MWh"]
  (* Bare "in" is the preposition in these material/condition clauses; inches
     remain available by their spelled unit names. *)
  val modelUnits = map (fn (alias,u) => {alias=alias,tag=alias,dimension=dimension u,caseSensitive=List.exists (fn n=>n=alias) caseSymbols}:MI.unitSpec) (List.filter (fn (name,_)=>name<>"in") Q.unit_names)
    @ map (fn (alias,tag)=>{alias=alias,tag=tag,dimension="energy",caseSensitive=true}:MI.unitSpec)
        [("J","j"),("kJ","kj"),("kWh","kwh")]
    @ map (fn (alias,tag)=>{alias=alias,tag=tag,dimension="pressure",caseSensitive=true}:MI.unitSpec)
        [("Pa","pa"),("kPa","kpa")]
    @ specs ("rho_kg_m3","density",["kg/m3","kg/m^3","kg/m\194\179","kilograms per cubic metre","kilograms per cubic meter"])
    @ specs ("rho_g_cm3","density",["g/cm3","g/cm^3","g/cm\194\179","grams per cubic centimetre","grams per cubic centimeter"])
    @ specs ("rho_kg_l","density",["kg/l","kg/litre","kg/liter"])
    @ specs ("rho_lb_ft3","density",["lb/ft3","lb/ft^3","lb/ft\194\179","lbs/ft3"])
    @ specs ("g_mps2","acceleration",["m/s2","m/s^2","m/s\194\178","metres per second squared","meters per second squared"])
    @ specs ("g_fps2","acceleration",["ft/s2","ft/s^2","ft/s\194\178","feet per second squared"])
    @ specs ("g_standard","acceleration",["standard gravities","standard gravity"])
    @ specs ("eta_percent","efficiency",["%","percent"])
    @ specs ("eta_fraction","efficiency",["fraction"])
    @ specs ("c","temperature",["degrees C","degree C","\194\176C"])
    @ specs ("f","temperature",["degrees F","degree F","\194\176F"])
  fun modelInputsUsing table =
    let val ms = List.mapPartial (fn MI.Measurement m => SOME m | _ => NONE) (MI.scan table (!originalInput))
    in if length ms = length (!numericValues) then ListPair.zip (map #1 (!numericValues),ms)
       else raise UnboundNumeral end
  fun modelInputs () = modelInputsUsing modelUnits
  fun mDim (_, {unitBinding=MI.Explicit{unit,...},...}:MI.measurement) = #dimension unit
    | mDim _ = "unbound"
  fun ofDim d ms = List.filter (fn x => mDim x=d) ms
  fun mRat (_,m:MI.measurement) = let val(n,d)= #value m in Q.mk_rat n d end
  fun mTag (_, {unitBinding=MI.Explicit{unit,...},...}:MI.measurement) = #tag unit
    | mTag _ = raise UnboundNumeral
  fun measuredQty dim (x as (_,m)) =
    case MI.bind {expected=dim,inheritFrom=NONE} m of
      MI.Bound{unit,...} => (case modelUnit (#tag unit) of SOME(Q.Lin u) => (mRat x,u) | _ => raise UnboundNumeral)
    | _ => raise UnboundNumeral
  datatype modelOutput = DefaultOutput | Requested of Q.qunit | BadOutput
  fun requestedModelOutput expected =
    let val raw= !originalInput
        val low=lower raw
        val prefixes=findall "\\b(?:in|how many)\\s+" low
        fun read ({start,stop,...}:Regex.match) =
          case MI.unitAt modelUnits raw stop of
            SOME(MI.Explicit{unit,span}) =>
              if #dimension unit=expected then
                (case MI.requested modelUnits raw span of
                   SOME(MI.RequestedOutput{unit,...}) =>
                     (case modelUnit (#tag unit) of SOME(Q.Lin u)=>SOME(Requested u) | _=>SOME BadOutput)
                 | _=>SOME BadOutput)
              else if #dimension unit="other" then NONE else SOME BadOutput
          | SOME(MI.Unsupported _) => SOME BadOutput
          | _ => if has "(?:heat|energy|pressure|answer|result)\\s+in\\s*$" (String.substring(low,0,stop))
                 then SOME BadOutput else NONE
        val outs=List.mapPartial read prefixes
    in case outs of []=>DefaultOutput | [o']=>o' | _=>BadOutput end

  fun hasState low = not(null(ofDim "temperature" (modelInputs())))
    orelse has ("\\b(?:temperature|heated|cooled)\\s*(?:(?:of|to|is|=|:)\\s*)?" ^ NUM) low
    orelse has "\\bat\\s+(?:(?:a|the)\\s+)?temperature\\b|\\b(?:compressed|superheated|saturated|heated|cooled)\\s+(?:water|air|mercury|petrol|diesel|ethanol|milk|oil)\\b" low
    orelse has "\\b(?:temperature dependent|thermal expansion|compressibility)\\b" low
  fun referenceCondition low = hasState low orelse not(null(ofDim "pressure" (modelInputs())))
    orelse has ("\\b(?:at|under)\\s+" ^ NUM) low
  fun unsupported c = SOME(Q.UnsupportedCondition c)

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
      if t = "" orelse Narrow.narrative t then NONE
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
                if (densityWord orelse massAsk orelse volAsk) andalso referenceCondition low then unsupported Q.C_reference_state
                else if (densityWord orelse massAsk orelse volAsk) andalso
                        length (modelInputs()) > length vols + length masses then unsupported Q.C_unread_input
                else if negativeMagnitude t then NONE
                else if not (phaseFits m low) then NONE
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
  val extraNames = [(deg ^ "c", "c"), (deg ^ "f", "f"),
    ("degree c", "c"), ("degrees c", "c"), ("degree f", "f"), ("degrees f", "f"),
    ("degree k", "k"), ("degrees k", "k")]
  fun charLen s = size s - (if String.isPrefix deg s then 1 else 0)
  val names =
    let
      val all = map (lower o #1) Q.unit_names @ map #1 extraNames
      (* stable sort by length, longest first, as sorted(..., key=len, reverse=True) *)
      fun ins (x, []) = [x]
        | ins (x, y :: ys) = if charLen x > charLen y then x :: y :: ys else y :: ins (x, ys)
    in rev (foldl (fn (x, acc) => rev (ins (x, rev acc))) [] all) end
  fun escape s = String.translate (fn c => if Char.isAlphaNum c then String.str c else "\\" ^ String.str c) s
  val UNIT_RX = "(" ^ String.concatWith "|" (map escape names) ^ ")"
  val UNIT_END = "(?![\\w/^]|\194\178|\194\179|\\s+per\\b)"
  val DELTA_WORD = "(?:temperature\\s+)?(?:difference|interval|change|increase|decrease|rise|drop)"
  val CONV = NUM ^ "\\s*" ^ UNIT_RX ^ "(?:\\s+" ^ DELTA_WORD ^ ")?\\s+(?:to|in|into|=|as|comes?\\s+to\\s+in)\\s+" ^ UNIT_RX ^ UNIT_END
  val HOWMANY = "how many\\s+" ^ UNIT_RX ^ "\\s+(?:are\\s+)?(?:in|is|make up)\\s+(?:an?\\s+|one\\s+)?(?:" ^ DELTA_WORD ^ "(?:\\s+of)?\\s+)?(?:" ^ NUM ^ "\\s*)?"
    ^ UNIT_RX ^ UNIT_END
  val QTY = NUM ^ "\\s*" ^ UNIT_RX ^ UNIT_END
  val TARGET = "\\bhow many\\s+" ^ UNIT_RX ^ UNIT_END
  val TWO = "^\\s*(?:i have|we have|there (?:is|are)|it(?:'s| is)|it weighs|it measures|it runs for)\\s+" ^ NUM ^ "\\s*"
    ^ UNIT_RX ^ "\\s*[.!]\\s*(?:how many\\s+" ^ UNIT_RX ^ "\\s+(?:is|are|does)\\s+that|what is that in\\s+" ^ UNIT_RX
    ^ "|convert (?:that|it) to\\s+" ^ UNIT_RX ^ ")\\s*[?.!]?\\s*$"

  (* Only the role grammar is case-insensitive. Preserve symbol spelling:
     mJ and MJ, and mWh and MWh, are different typed units. Ambiguous lowercase
     mj/mwh is unsupported; spelled aliases remain case-insensitive. *)
  fun unitOf name =
    let val folded=lower name
        val sensitive=List.exists (fn n=>n=folded) ["mj","mwh","gj","wh"]
        val n = case List.find (fn (e, _) => e = folded) extraNames of
            SOME (_, a) => a | NONE => if sensitive then name else folded
    in case Q.lookup_unit n of SOME u => u | NONE => raise UnboundNumeral end
  val conversionUnits = modelUnits
    @ specs ("k","temperature",["degree k","degrees k"])
  fun unitRole text ({groups,...}:Regex.match) i =
    case Vector.sub(groups,i) of
      NONE=>raise UnboundNumeral
    | SOME(a,b)=>
      let val name=String.substring(text,a,b-a)
          val u=unitOf name
          (* The preposition in cannot extend another unit. It is added only
             when this bound role itself spells the inch abbreviation. *)
          val table=if lower name="in" then
              {alias="in",tag="in",dimension="length",caseSensitive=false}::conversionUnits
            else conversionUnits
      in case MI.requested table text {start=a,stop=b} of
          SOME _=>u | NONE=>raise UnboundNumeral end

  (* A change is a vector on a temperature scale; a point is affine.  Keep
     the original operation through the quantity-first and two-sentence paths.
     Multiple numeral roles need an endpoint reader, not a last-match guess. *)
  fun temperatureUnit (Q.Tmp _) = true | temperatureUnit _ = false
  val CHANGE = "(?:difference|interval|change|increase|decrease|rise|drop)"
  val STEP = "(?:of\\s+|by\\s+|is\\s+|=\\s*)?"
  fun conversionRequest low (x, a, b) =
    if not (has ("\\b" ^ CHANGE ^ "\\b|\\bdelta\\b|\206\148|\206\180") low)
    then SOME (Q.Convert (x,a,b))
    else let
      val explicit = has ("\\btemperature\\s+" ^ CHANGE ^ "\\s+" ^ STEP ^ NUM
        ^ "|\\b" ^ CHANGE ^ "\\s+(?:in|of)\\s+temperature\\s+" ^ STEP ^ NUM
        ^ "|" ^ NUM ^ "\\s*" ^ UNIT_RX ^ "\\s+temperature\\s+" ^ CHANGE ^ "\\b"
        ^ "|" ^ CONV ^ "\\s+as\\s+(?:a\\s+)?temperature\\s+" ^ CHANGE ^ "\\b") low
      val intervalRole = has ("\\b" ^ CHANGE ^ "\\s+(?:of|by)\\s+" ^ NUM
        ^ "|" ^ NUM ^ "\\s*" ^ UNIT_RX ^ "\\s+" ^ CHANGE ^ "\\b"
        ^ "|(?:\\bdelta\\s*t|\206\148\\s*t|\206\180\\s*t)\\s*(?:=|of)?\\s*" ^ NUM) low
      val between = has ("\\b(?:temperature\\s+)?" ^ CHANGE
        ^ "\\s+(?:(?:in|of)\\s+temperature\\s+)?between\\b") low
      val temperature = temperatureUnit a andalso temperatureUnit b
      val change = explicit orelse (temperature andalso intervalRole)
    in if (temperature andalso between) orelse (change andalso length (!numericValues) > 1)
       then NONE
       else SOME (if change then Q.ConvertDelta (x,a,b) else Q.Convert (x,a,b))
    end

  fun trim s = collapse s

  fun unitsV1 text =
    let
      val t=collapse text
      val low = lower t
    in
      case search CONV low of
        SOME m => conversionRequest low (ratOf (g1 low m), unitRole t m 2, unitRole t m 3)
      | NONE =>
          (case search HOWMANY low of
             SOME m =>
               let val v = case grp low m 2 of SOME s => ratOf (trim s) | NONE => Q.mk_rat 1 1
               in conversionRequest low (v, unitRole t m 3, unitRole t m 1) end
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
                       (case conversionRequest low (ratOf (g1 low q), unitRole t q 2, unitRole t tg 1) of
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
    let val t=text
        val low = lower t
    in
      case search TWO low of
        SOME m =>
          let val target = valOf (List.find (fn i=>isSome(grp low m i)) [3,4,5])
          in conversionRequest low (ratOf (g1 low m), unitRole t m 2, unitRole t m target) end
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

  val GRAVITY_ROLE = "\\b(?:gravity|gravitational acceleration|acceleration due to gravity)\\b|\\bg\\s*="
  val SURFACE_ROLE = "\\b(?:surface|ambient|atmospheric|external)\\s+(?:absolute\\s+)?pressure\\b"
  val DENSITY_ROLE = "\\b(?:density|rho)\\b"
  fun hydrostatic low =
    let val gravityUnits = List.filter (fn ({alias,...}:MI.unitSpec)=>lower alias<>"g") modelUnits
          @ specs ("g_standard","acceleration",["g"])
        val ms = modelInputsUsing gravityUnits
        val hs = ofDim "length" ms
        val gs = ofDim "acceleration" ms
        val ps = ofDim "pressure" ms
        val ds = ofDim "density" ms
        val suppliedG = has GRAVITY_ROLE low
        val suppliedP = has SURFACE_ROLE low
        val suppliedD = has DENSITY_ROLE low
        val fl = fluidOf low
        val modePhrase = case search ("\\b(?:what(?:'s| is)?|find|calculate|compute|give|determine)\\s+(?:the\\s+)?"
          ^ "((?:(?:gauge|absolute|total|hydrostatic)\\b|[ ()])*)pressure\\b") low of
            SOME m=>g1 low m
          | NONE=> (case search "\\bpressure\\s+(gauge|absolute|total)\\b" low of SOME m=>g1 low m | NONE=>"")
        val absolute = not(has "\\bgauge\\b" modePhrase) andalso has "\\b(?:absolute|total)\\b" modePhrase
        fun suppliedDensity x = Q.SuppliedDensity(mRat x,
          case mTag x of "rho_g_cm3"=>Q.U_gram | "rho_lb_ft3"=>Q.U_pound | _=>Q.U_kilogram,
          case mTag x of "rho_g_cm3"=>Q.U_cubic_centimetre | "rho_lb_ft3"=>Q.U_cubic_foot | "rho_kg_l"=>Q.U_litre | _=>Q.U_cubic_metre)
        val rho = case ds of [x]=>SOME(suppliedDensity x) | []=>Option.map Q.ReferenceDensity fl | _=>NONE
        val g = case gs of [x] => (mRat x,case mTag x of "g_fps2"=>Q.G_fps2 | "g_standard"=>Q.G_standard | _=>Q.G_mps2)
                         | _ => (Q.mk_rat 1 1,Q.G_standard)
        val surface = case ps of [x]=>measuredQty "pressure" x | _=>(Q.mk_rat 101325 1,Q.U_pascal)
        val outputOK = case requestedModelOutput "pressure" of DefaultOutput=>true | Requested u=>u=Q.U_pascal | BadOutput=>false
        val complete = length ms=length hs+length gs+length ps+length ds
        val inputs = length hs<=1 andalso length gs<=1 andalso length ps<=1 andalso length ds<=1
           andalso (not suppliedG orelse length gs=1) andalso (null gs orelse suppliedG)
           andalso (not suppliedP orelse length ps=1) andalso (null ps orelse suppliedP)
           andalso (not suppliedD orelse length ds=1) andalso (null ds orelse suppliedD)
    in if isSome fl orelse suppliedD then
         if hasState low then unsupported Q.C_reference_state
         else if not complete orelse not inputs orelse not outputOK then unsupported Q.C_unread_input
         else case rho of NONE=>unsupported Q.C_unread_input
              | SOME d=>SOME(Q.Hydrostatic(d,Option.map (measuredQty "length") (one hs),g,surface,absolute))
       else NONE
    end

  fun fluids text =
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
          if has "\\bpressure\\b" ask andalso has "\\b(?:deep|depth|below|under|beneath|down)\\b" low then
            hydrostatic low
          else if (has GRAVITY_ROLE low orelse has SURFACE_ROLE low orelse has DENSITY_ROLE low orelse hasState low)
              andalso isSome fl andalso has "\\b(?:buoyan\\w*|upthrust|submerged|float\\w*)\\b" low
            then unsupported Q.C_other_operation
          else if negativeMagnitude t then NONE
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
  val fuelEnergyLabels = zip3 (["kwh|kilowatt[- ]hours?", "mwh|megawatt[- ]hours?",
                                "mj|megajoules?", "gj|gigajoules?"],
                               Q.fuel_energy_units, "fuel_energy_units")
  fun energyUnitMention text = List.find (fn (p, _) => has ("\\b(?:" ^ p ^ ")\\b") text) fuelEnergyLabels

  val EFFICIENCY_ROLE = "\\b(?:efficiency|efficient)\\b"
  val USEFUL_ROLE = "\\b(?:useful|delivered|deliver|usable)\\s+(?:heat|energy)\\b|\\b(?:heat|energy)\\s+delivered\\b"
  fun usefulFuel f low ask =
    let val ms=modelInputs()
        val masses=ofDim "mass" ms
        val energies=ofDim "energy" ms
        val etas=ofDim "efficiency" ms
        val bare=List.filter (fn (_,m:MI.measurement)=>case #unitBinding m of MI.Bare=>true|_=>false) ms
        val bareEta=List.filter (fn (token,_) => has ("\\befficiency\\s*(?:(?:of|is|=|:)\\s*)?" ^ token
             ^ "(?=\\s*(?:[,;?.!)]|$|and\\b|with\\b))") low) bare
        val es=etas@bareEta
        val eta=case es of [x]=>SOME(mRat x,if mDim x="efficiency" andalso mTag x="eta_percent" then Q.E_percent else Q.E_fraction) | _=>NONE
        val complete=length ms=length masses+length energies+length es
        val inverse=has "\\b(?:need|needed|required|require)\\b" ask
          andalso has "\\b(?:fuel|mass|how much|how many)\\b" ask andalso not(null energies)
        val explicit=has EFFICIENCY_ROLE low
        val output=requestedModelOutput (if inverse then "mass" else "energy")
    in if has "\\b(?:moisture|wet basis|dry basis|higher heating value|gross calorific)\\b|\\b(?:wet|damp|green)\\s+(?:wood|firewood|logs|coal)\\b" low then unsupported Q.C_moisture
       else if has "\\bco2\\b|carbon dioxide|emission|emit|\\bchemical\\s+energy\\b|\\breleased\\s+energy\\b" ask then unsupported Q.C_other_operation
       else if (not explicit andalso not(null es)) orelse output=BadOutput orelse not complete orelse length es>1 orelse (explicit andalso null es) then unsupported Q.C_unread_input
       else if inverse then
         if (case output of Requested u=>u<>Q.U_kilogram | _=>false) then unsupported Q.C_other_operation
         else if length energies=1 andalso null masses then SOME(Q.FuelUsefulMass(f,measuredQty "energy" (hd energies),eta))
         else unsupported Q.C_unread_input
       else if length masses<=1 andalso null energies then
         SOME(Q.FuelUsefulEnergy(f,Option.map (measuredQty "mass") (one masses),(case output of Requested u=>u | _=>Q.U_megajoule),eta))
       else unsupported Q.C_unread_input
    end

  fun fuels text =
    let val t = collapse text
    in
      if t = "" orelse Narrow.narrative t then NONE
      else
        let
          val low = lower t
          val found = List.mapPartial (fn (p, f) => if has ("\\b(?:" ^ p ^ ")\\b") low then SOME f else NONE) fuelPats
          val found = if List.exists (fn f => f = fAnthracite) found andalso List.exists (fn f => f = fCoal) found
                      then List.filter (fn f => f <> fCoal) found else found
        in
          case found of
            [f] =>
              if not (has "\\bburn\\w*|combust\\w*|energy|heat|co2|carbon dioxide|emission|emit\\w*|calorific" low orelse isSome (energyUnitMention low))
              then NONE
              else if has EFFICIENCY_ROLE low orelse has USEFUL_ROLE low
                      orelse has "\\b(?:moisture|wet basis|dry basis|higher heating value|gross calorific)\\b|\\b(?:wet|damp|green)\\s+(?:wood|firewood|logs|coal)\\b" low
                then usefulFuel f low (lower (Narrow.last_sentence t))
              else if negativeMagnitude t then NONE
              else if has (NUM ^ "\\s*(?:litres?|liters?|l|gallons?|gal|m3|cubic)\\b") low then NONE
              else
                let
                  val ask = lower (Narrow.last_sentence t)
                  val ms = modelInputs()
                  val masses = map (measuredQty "mass") (ofDim "mass" ms)
                  val energies = map (measuredQty "energy") (ofDim "energy" ms)
                  val complete = length ms = length masses + length energies
                  fun need r = if Narrow.short_direct t then SOME r else NONE
                  fun kgOutput () = case requestedModelOutput "mass" of
                    DefaultOutput=>true | Requested u=>u=Q.U_kilogram | BadOutput=>false
                in
                  if not complete orelse length masses>1 orelse length energies>1 then unsupported Q.C_unread_input
                  else if has "\\bco2\\b|carbon dioxide|emission|emit" ask then
                    if not(null energies) orelse not(kgOutput()) then unsupported Q.C_other_operation
                    else let val r = Q.FuelCO2 (f, one masses)
                         in if length masses = 1 then SOME r else need r end
                  else if has ("\\bhow (?:much|many kilograms?|many kg|many tonnes?)\\b.*\\b(?:need|needed|required|burn)\\b|"
                               ^ "\\bmass of\\b.*\\bneeded\\b") ask andalso not (null energies) andalso null masses then
                    if kgOutput() then SOME (Q.FuelMassNeeded (f, hd energies)) else unsupported Q.C_other_operation
                  else if has "\\b(?:energy|heat)\\b" ask orelse
                          (has "\\bhow many\\b" ask andalso isSome (energyUnitMention ask)) then
                    if not(null energies) then unsupported Q.C_other_operation
                    else case requestedModelOutput "energy" of
                      BadOutput=>unsupported Q.C_unread_input
                    | out=>
                      if length masses <> 1 then
                        if has "\\b(?:per kilogram|per kg|calorific|energy content|energy density)\\b" low andalso null masses
                        then if out=DefaultOutput then SOME (Q.FuelNCV f) else unsupported Q.C_other_operation
                        else need (Q.FuelEnergy (f, NONE, Q.U_megajoule))
                      else SOME (Q.FuelEnergy (f, SOME (hd masses),case out of Requested u=>u | _=>Q.U_megajoule))
                  else NONE
                end
          | _ => NONE
        end
    end

  val densities = withNumerals densities
  val unitsV1 = withNumerals unitsV1
  val unitsV2 = withNumerals unitsV2
  val unitsV3 = withNumerals unitsV3
  val springs = withNumerals springs
  val fluids = withNumerals fluids
  val fuels = withNumerals fuels

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
