(* UNTRUSTED. Lane S17-variants: the three variant manifests of the quantity
   family, as a thin layer over lane G's recognizer (RecognizerBase, derived
   from src/extract/quantity/recognizer.sml by build.sh; lane G's file is not
   edited). The verified kernel (Quantity.reply_of) is lane G's and is used
   unchanged, so every value, decline and reply text still comes from it.

   What differs from the base versions, read off the organs in
   upstream/root/specialists/:
     densities-r2  = densities + names_narrowing_v1 (organ_densities_v2.py):
                     silent when a material word occurs only capitalised in
                     the middle of a sentence (a proper name).
     units-v2      = the units_v2 organ (organ_units_v2.py): lane G's unitsV2
                     (exact rationals, quantity-first phrasing, narrow_v1).
     units-v3-r2   = units-v3 + a boundary narrowing (organ_units_v3_r2.py):
                     silent on a turn with another domain's markers (heat
                     loss, R-values, ...) and none of units' own.
   Every rule here only turns a base answer into "not taken"; none can create
   an answer or change a value. *)
structure Recognizer :
sig
  val organs : string list
  val recognize : string -> string -> (string * Quantity.request) option
end =
struct
  structure B = RecognizerBase

  val cache : (string * Regex.regex) list ref = ref []
  fun lower s = String.map Char.toLower s
  fun re p =
    case List.find (fn (q, _) => q = p) (!cache) of
      SOME (_, r) => r
    | NONE => let val r = Regex.compile p in cache := (p, r) :: !cache; r end
  fun has p s = isSome (Regex.search (re p) s)

  (* ---- densities-r2: names_narrowing_v1.named_not_material ---- *)
  (* MAT_RX of organ_densities_v1.py (checked against the organ by variants_check.py) *)
  val matPats = [
      "(?:fresh |pure |liquid )?water", "sea ?water|salt water", "ice", "alumin(?:i)?um",
      "(?:mild |carbon |structural )?steel", "(?:pure )?iron", "copper", "gold", "silver", "lead",
      "concrete", "(?:window |soda-lime )?glass", "petrol|gasoline", "diesel(?: fuel)?",
      "ethanol|ethyl alcohol", "mercury", "air", "granite", "brass", "titanium", "platinum", "zinc",
      "nickel", "(?:whole )?milk", "honey", "uranium", "tungsten", "magnesium", "olive oil"]

  fun escape w = String.translate (fn c => if Char.isAlphaNum c orelse c = #" " orelse c = #"-" then String.str c
                                           else "\\" ^ String.str c) w

  fun isWs c = Char.isSpace c
  (* Python: re.search(r"(?:^|[.!?]\s+)$", prefix) *)
  fun atSentenceStart prefix =
    if prefix = "" orelse prefix = "\n" then true
    else
      let
        fun back i = if i > 0 andalso isWs (String.sub (prefix, i - 1)) then back (i - 1) else i
        val j = back (size prefix)
      in j < size prefix andalso j > 0 andalso Char.contains ".!?" (String.sub (prefix, j - 1)) end

  fun wordsOf t =
    let val lowt = lower t
    in List.concat (map (fn p =>
         map (fn ({start, stop, ...} : Regex.match) => String.substring (t, start, stop - start))
             (Regex.findall (re ("\\b(?:" ^ p ^ ")\\b")) lowt)) matPats)
    end

  fun namedNotMaterial t words =
    let
      val lowt = lower t
      fun one w =
        let
          val hits = Regex.findall (re ("\\b" ^ escape w ^ "\\b")) lowt
          val firsts = map (fn ({start, ...} : Regex.match) => (start, String.sub (t, start))) hits
          val lowerHit = List.exists (fn (_, c) => Char.isLower c) firsts
          val midCaps = List.exists (fn (s, c) => Char.isUpper c andalso not (atSentenceStart (String.substring (t, 0, s)))) firsts
        in midCaps andalso not lowerHit end
    in List.exists one words end

  fun densitiesR2 text =
    let val words = wordsOf text
    in if not (null words) andalso namedNotMaterial text words then NONE else B.densities text end

  (* ---- units-v3-r2: organ_units_v3_r2.py ---- *)
  val NOT_MINE = "\\b(?:heat loss|R-\\d{1,2}|R-value|U-value|heating degree days)\\b"
  val MINE = "\\b(?:convert|conversion|how many \\w+ (?:is|are|in)|in (?:kilo|milli|centi)?\\w+s?\\?)\\b(?![\\s\\S]*\\bR-\\d)"

  fun unitsV3R2 text =
    let val low = lower text
    in if has NOT_MINE low andalso not (has MINE low) then NONE else B.unitsV3 text end

  val variants = ["densities-r2", "units-v2", "units-v3-r2"]
  val organs = variants @ B.organs

  fun byId "densities-r2" = densitiesR2
    | byId "units-v2" = B.unitsV2
    | byId "units-v3-r2" = unitsV3R2
    | byId other = (fn text => Option.map #2 (B.recognize other text))

  fun recognize mode text =
    if List.exists (fn v => v = mode) variants
    then Option.map (fn r => (mode, r)) (byId mode text)
    else B.recognize mode text
end
