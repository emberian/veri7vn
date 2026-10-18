(* UNTRUSTED. The English recognizer for the materials family: a hand port of
   the regular expressions and branch order of
     upstream/root/specialists/additive-v2/organ_additive_v{1,2}.py   (AdditiveOrganV2)
     upstream/root/specialists/materials-v2/organ_materials_v{1,2}.py (MaterialsOrganV2)
     upstream/root/specialists/soil/organ_soil_v1.py                  (SoilOrgan)
     upstream/root/specialists/soil-r2/organ_soil_r2.py               (SoilOrganBoundary)
     upstream/root/specialists/water/organ_water_v1.py                (WaterOrgan)
     upstream/root/specialists/water-r3/organ_water_r{2,3}.py         (WaterOrganBoundaryBoundary)
   and of their shared narrowing rule narrow_v1.py. It reads numbers and words
   off the question and builds a typed Materials.request; it computes
   nothing but the half of a diameter, the difference of two temperatures,
   and percent-to-ratio normalization (exact integer fractions). Every value, decline and response text comes
   from the verified HOL kernel (Materials.reply_of). NONE means the question
   is not taken (the organ returns None).

   Matching is case-insensitive by lower-casing the text; patterns are written
   in lower case. \w and \d are ASCII here; the organs' non-ASCII symbols
   (degree, times, alpha, cubic, squared) are matched as UTF-8 byte sequences.
   Python's \b next to the letter alpha counts alpha as a word character; the
   ported patterns spell that out explicitly. *)
structure Recognizer :
sig
  val organs : string list
  val recognize : string -> string -> (string * Materials.request) option
end =
struct
  structure M = Materials

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

  (* exact decimal fractions read off the text: numerator and denominator *)
  type q = IntInf.int * IntInf.int
  fun qOfLit (lit0 : string) : q =
    let
      val lit = String.translate (fn #"," => "" | c => String.str c) lit0
      val (neg, body) = if String.isPrefix "-" lit then (true, String.extract (lit, 1, NONE)) else (false, lit)
      val (mant, ex) =
        case String.fields (fn c => c = #"e") body of
          [m] => (m, 0)
        | [m, e] => (m, valOf (Int.fromString e))
        | _ => raise Fail ("bad numeral " ^ lit0)
      val (ip, fp) = case String.fields (fn c => c = #".") mant of
                       [a] => (a, "")
                     | [a, b] => (a, b)
                     | _ => raise Fail ("bad numeral " ^ lit0)
      val num = valOf (IntInf.fromString (ip ^ fp))
      val num = if neg then IntInf.~ num else num
      val den = IntInf.pow (10, size fp)
    in
      if ex >= 0 then (num * IntInf.pow (10, ex), den) else (num, den * IntInf.pow (10, ~ex))
    end
  fun qSub ((a, b) : q, (c, d) : q) : q = (a * d - c * b, b * d)
  fun qHalf ((a, b) : q) : q = (a, 2 * b)
  fun qPos ((a, _) : q) = a > 0
  fun qNonPos ((a, _) : q) = a <= 0
  fun rat ((a, b) : q) : M.rat = M.mk_rat a b
  fun nat (i : int) : M.nat = M.nat_of_integer (IntInf.fromInt i)
  val zero : q = (0, 1)

  fun nth s m g = qOfLit (valOf (grp s m g))
  fun gstart (m : Regex.match) g =
    case Vector.sub (#groups m, g) of SOME (a, _) => a | NONE => ~1
  fun startOf (m : Regex.match) = #start m
  fun firstQ s m gs = Option.map qOfLit (firstGroup s m gs)

  fun removeAll pat s =
    let
      val n = size pat
      fun go i acc =
        if i >= size s then String.concat (rev acc)
        else if i + n <= size s andalso String.substring (s, i, n) = pat then go (i + n) acc
        else go (i + 1) (String.str (String.sub (s, i)) :: acc)
    in if n = 0 then s else go 0 [] end

  (* replace every match of pattern p in s by f applied to the match *)
  fun subst p f s =
    let
      fun go i [] acc = String.concat (rev (String.extract (s, i, NONE) :: acc))
        | go i ((m as {start, stop, ...} : Regex.match) :: ms) acc =
            go stop ms (f m :: String.substring (s, i, start - i) :: acc)
    in go 0 (findall p s) [] end

  val NUM = "(\\d+(?:,\\d{3})*(?:\\.\\d+)?)"
  val NUME = "(\\d+(?:,\\d{3})*(?:\\.\\d+)?(?:e[+-]?\\d+)?)"
  val NUMW = "(\\d+(?:,\\d{3})*(?:\\.\\d+)?(?:e-?\\d+)?)"
  val F_ = "(-?\\d+(?:\\.\\d+)?)"
  val times = "\195\151"      (* U+00D7 *)
  val cube3 = "\194\179"      (* U+00B3 *)
  val sq2 = "\194\178"        (* U+00B2 *)
  val deg = "\194\176"        (* U+00B0 *)
  val alpha = "\206\177"      (* U+03B1 *)
  val aring = "\195\165"      (* lower-case a with ring above *)

  fun answered req = M.answered (M.reply_of req)

  (* ---------- additive-v2 ---------- *)
  fun kw low args name =
    case search ("\\b" ^ name ^ "\\s*=\\s*" ^ F_) args of
      SOME m => SOME (nth args m 1)
    | NONE => NONE

  fun scad (args0 : string) (prim : string) : M.request option =
    let
      val args = args0
      val pos = map (fn m => nth args m 1) (findall ("(?:^|,)\\s*" ^ F_ ^ "\\s*(?=,|$)") args)
      val pos0 = case pos of x :: _ => SOME x | [] => NONE
      val posN = fn n => if length pos > n then SOME (List.nth (pos, n)) else NONE
      fun orElse a b = case a of SOME _ => a | NONE => b
      fun halfOf d = Option.map qHalf d
    in
      if prim = "cube" then
        (case search ("\\[\\s*" ^ F_ ^ "\\s*,\\s*" ^ F_ ^ "\\s*,\\s*" ^ F_ ^ "\\s*\\]") args of
           SOME m => SOME (M.ScadCube (rat (nth args m 1), rat (nth args m 2), rat (nth args m 3)))
         | NONE =>
             (case orElse (kw args args "size") pos0 of
                SOME s => SOME (M.ScadCube (rat s, rat s, rat s))
              | NONE => NONE))
      else if prim = "sphere" then
        (case orElse (orElse (kw args args "r") (halfOf (kw args args "d"))) pos0 of
           SOME r => SOME (M.ScadSphere (rat r))
         | NONE => NONE)
      else
        let
          val h = orElse (kw args args "h") pos0
          val r1 = orElse (kw args args "r1") (halfOf (kw args args "d1"))
          val r2 = orElse (kw args args "r2") (halfOf (kw args args "d2"))
          val r = orElse (kw args args "r") (halfOf (kw args args "d"))
          val r = if not (isSome r) andalso length pos >= 2 andalso not (isSome r1) then posN 1 else r
        in
          case h of
            NONE => NONE
          | SOME h =>
              (case (r1, r2) of
                 (SOME a, SOME b) => SOME (M.ScadFrustum (rat h, rat a, rat b))
               | _ => (case r of SOME r => SOME (M.ScadCylinder (rat h, rat r)) | NONE => NONE))
        end
    end

  (* Exact discrete roles for the closed triangular surface count model. *)
  fun mesh low : M.request option =
    if not (has "\\bmesh\\b|\\bstl\\b|\\bpolyhedron\\b|\\bmanifold\\b|\\bwatertight\\b" low
            andalso has "\\bhow many\\b|\\bnumber of\\b" low) then NONE
    else if has "\\bopen\\b|\\bwith (?:a )?boundary\\b|\\bquadrilateral\\b|\\bquadrangle\\b|\\bnon[- ]?triang\\w*\\b|\\bnon[- ]?orientable\\b" low
      then SOME M.MeshUnread
    else if not (has "\\bclosed\\b|\\bwatertight\\b|\\bpolyhedron\\b" low)
         orelse not (has "\\btriang(?:le|les|ular)\\b|\\bfacets?\\b|\\bstl\\b" low)
      then SOME M.MeshUnread
    else case ExactNumeric.mask low of
      NONE => SOME M.MeshUnread
    | SOME {text, numbers} =>
      let
        val marker = "(qnum[0-9]+q)"
        fun unique xs = List.foldl (fn (x,acc) => if List.exists (fn y => x=y) acc then acc else acc@[x]) [] xs
        fun captures rx = List.map (fn m => g1 text m) (findall rx text)
        fun role suffix prefix = unique (captures (marker ^ "\\s*(?:" ^ suffix ^ ")\\b") @
          captures ("\\b(?:" ^ prefix ^ ")\\s*(?:of|is|=|:)?\\s*" ^ marker))
        val fs = role "triangles|faces|triangular faces|facets" "(?:face|triangle|facet) count|faces|triangles|facets"
        val vs = role "vertices" "vertex count|vertices"
        val gs = role "holes?" "genus"
        val torus = has "\\btorus\\b|\\bdonut[- ]shaped\\b" text
        val noholes = has "\\bno holes\\b|\\bgenus[- ]zero\\b" text
        fun value id = #2 (valOf (List.find (fn (key,_) => key=id) numbers))
        val used = unique (fs @ vs @ gs)
        val unused = List.exists (fn (key,_) => not (List.exists (fn k => k=key) used)) numbers
        val invalidGenus = (has "\\bgenus\\b|\\bholes?\\b" text andalso null gs andalso not noholes andalso not torus)
        val g = case gs of [id] => value id | _ => if torus then (1,1) else (0,1)
        val conflicting = (torus andalso g <> (1,1)) orelse (noholes andalso g <> (0,1))
        val targetMatches = findall "\\b(?:how many|number of)\\s+(vertices|edges|triangles|faces|facets)\\b" text
        val targets = unique (List.map (fn m => g1 text m) targetMatches)
      in
        if unused orelse invalidGenus orelse conflicting orelse length gs > 1
           orelse has "\\b(?:how many|number of)\\s+(?:vertices|edges|triangles|faces|facets)\\s+(?:and|or)\\s+(?:vertices|edges|triangles|faces|facets)\\b" text then SOME M.MeshUnread
        else case (targets,fs,vs) of
          (["vertices"],[f],[]) => SOME (M.MeshVertices (rat (value f),rat g))
        | (["edges"],[f],[]) => SOME (M.MeshEdges (rat (value f),rat g))
        | ([target],[],[v]) => if target="triangles" orelse target="faces" orelse target="facets"
                             then SOME (M.MeshFaces (rat (value v),rat g)) else SOME M.MeshUnread
        | _ => SOME M.MeshUnread
      end

  fun additiveV1 (low : string) : M.request option =
    if has "\\b(?:cube|sphere|cylinder)\\s*\\(" low andalso has "\\bvolume\\b|\\bhow much material\\b" low
       andalso not (has "\\b(?:difference|union|intersection|hull|minkowski)\\s*\\(" low) then
      (case search "\\b(cube|sphere|cylinder)\\s*\\(([^()]*(?:\\[[^\\]]*\\])?[^()]*)\\)" low of
         NONE => NONE
       | SOME m => scad (valOf (grp low m 2)) (valOf (grp low m 1)))
    else mesh low

  val VU = "(mm3|mm" ^ cube3 ^ "|cm3|cm" ^ cube3 ^ "|ml|cubic millimet\\w+|cubic centimet\\w+)"
  fun vuOf u = if u = "cm3" orelse u = "cm" ^ cube3 orelse u = "ml" orelse String.isPrefix "cubic centi" u
               then M.VA_cm3 else M.VA_mm3

  fun extrude (low : string) : M.request option =
    case search (NUM ^ "\\s*" ^ VU ^ "\\s*(?:/|per)\\s*(s|sec\\w*|min\\w*)\\b") low of
      NONE => NONE
    | SOME fl =>
        if not (has "\\bhow long\\b|\\btime\\b|\\bminutes\\b|\\bhours\\b|\\bseconds\\b|\\bhow many (?:min|sec|hour)" low) then NONE
        else
          let
            val q = nth low fl 1
            val uq = vuOf (valOf (grp low fl 2))
            val pm = String.isPrefix "min" (valOf (grp low fl 3))
            val vols = List.filter (fn m => #start m <> #start fl)
                         (findall (NUM ^ "\\s*" ^ VU ^ "\\b(?!\\s*(?:/|per\\b))") low)
          in
            case vols of
              [] => SOME (M.Extrude (NONE, rat q, uq, pm))
            | m :: _ => SOME (M.Extrude (SOME (rat (nth low m 1), vuOf (valOf (grp low m 2))), rat q, uq, pm))
          end

  (* Input dimensions and output requests remain distinct. Shared measurements
     retain raw text spans; no missing unit is supplied by the requested output. *)
  fun scale (low : string) raw : M.request option =
    if not (has ("\\bscal\\w*\\b|\\btimes (?:the|its) size\\b|\\b(?:x|" ^ times ^ ") (?:the|its) size\\b|\\bin every (?:dimension|direction)\\b") low) then NONE
    else if not (has "\\bvolume\\b|\\bmass\\b|\\bweigh\\w*\\b|\\bheavy\\b|\\bmaterial\\b|\\bfilament\\b|\\bsurface area\\b|\\barea\\b|\\blength\\b|\\bwidth\\b|\\bheight\\b|\\blong\\b" low) then NONE
    else let
      val low = lower raw
      fun units dimension tag aliases = List.map (fn alias =>
        {alias=alias, tag=tag, dimension=dimension, caseSensitive=false}) aliases
      val unitTable =
        units "mass" "g" ["g", "gram", "grams"] @ units "mass" "kg" ["kg", "kilogram", "kilograms"] @
        units "length" "mm" ["mm", "millimeter", "millimeters", "millimetre", "millimetres"] @
        units "length" "cm" ["cm", "centimeter", "centimeters", "centimetre", "centimetres"] @
        units "length" "m" ["m", "meter", "meters", "metre", "metres"] @
        units "area" "cm2" ["cm2", "cm" ^ sq2] @ units "area" "mm2" ["mm2", "mm" ^ sq2] @
        units "volume" "cm3" ["cm3", "cm" ^ cube3] @ units "volume" "mm3" ["mm3", "mm" ^ cube3] @
        units "volume" "ml" ["ml", "milliliter", "milliliters", "millilitre", "millilitres"] @
        units "ratio" "percent" ["%", "percent"] @ units "ratio" "factor" ["x", "times", times]
      val scanned = MeasuredInput.scan unitTable raw
      val ns = List.mapPartial (fn MeasuredInput.Measurement n => SOME n | _ => NONE) scanned
      fun prefix (n : MeasuredInput.measurement) = String.substring (low, 0, #start (#numberSpan n))
      fun suffix (n : MeasuredInput.measurement) = String.extract (low, #stop (#numberSpan n), NONE)
      fun only [x] = SOME x | only _ = NONE
      fun dim "length" = M.ScaleLength | dim "area" = M.ScaleArea
        | dim "mass" = M.ScaleMass | dim _ = M.ScaleVolume
      fun bu "g" = M.BU_g | bu "kg" = M.BU_kg | bu "mm" = M.BU_mm
        | bu "cm" = M.BU_cm | bu "m" = M.BU_m | bu "cm2" = M.BU_cm2
        | bu "mm2" = M.BU_mm2 | bu "cm3" = M.BU_cm3 | bu "mm3" = M.BU_mm3 | bu _ = M.BU_ml
      fun factor (n : MeasuredInput.measurement) =
        let val pre = prefix n val post = suffix n
            val by = has "\\b(?:by|to)\\s+(?:a factor of\\s+)?$|\\bscale factor\\s*(?:of|is|=|:)?\\s*$|\\bscal\\w*\\s+(?:up|down)\\s*$" pre
            val to = has "\\bto\\s+(?:a factor of\\s+)?$" pre
            val scaleWords = findall "\\bscal(?:e|ed|ing)\\b(?!\\s+factor)" pre
            val operation = case rev scaleWords of [] => pre | m::_ => String.extract(pre,#start m,NONE)
            val down = has "\\bdown\\b|\\bsmaller\\b|\\bshrink\\w*\\b|\\breduc\\w*\\b|\\bdecreas\\w*\\b" operation
            val up = has "\\bup\\b|\\blarger\\b|\\benlarg\\w*\\b|\\bincreas\\w*\\b" operation
            val timesSuffix = has ("^\\s*(?:x|" ^ times ^ "|times)\\s+(?:larger|bigger|smaller|the size|its size|scale)\\b") post
            val smallerSuffix = has ("^\\s*(?:x|" ^ times ^ "|times)\\s+smaller\\b") post
            val explicitMultiplier = case #unitBinding n of MeasuredInput.Explicit {unit=u,...} => #alias u = "x" orelse #alias u = times | _ => false
            fun mode percent = if to orelse explicitMultiplier then M.ScaleMultiply
                else if percent andalso down then M.ScaleDecrease
                else if percent andalso up then M.ScaleIncrease
                else if down orelse smallerSuffix then M.ScaleDivide else M.ScaleMultiply
            val (a,b) = #value n
            val percentUnit = case #unitBinding n of MeasuredInput.Explicit {unit=u,...} => #tag u = "percent" | _ => false
            val directionAmbiguous = not to andalso not explicitMultiplier andalso not percentUnit andalso (down orelse up orelse smallerSuffix) andalso 0<a andalso a<b
        in if directionAmbiguous orelse (down andalso up) then NONE else case #unitBinding n of
          MeasuredInput.Bare => if (by andalso has ("^\\s*(?:(?:x|" ^ times ^ "|times)\\b|(?:in|throughout)\\s+every\\b|and\\b|[,.?!;:]|$)") post) orelse timesSuffix
            then SOME (#id n,(a,b),mode false) else NONE
        | MeasuredInput.Explicit {unit=u,span} =>
            if #dimension u = "ratio" andalso (by orelse timesSuffix orelse has "^\\s*(?:scale|of (?:the |its )?(?:original )?size)\\b" (String.extract(low,#stop span,NONE)))
            then SOME (#id n,(a,if #tag u = "percent" then b*100 else b),mode (#tag u = "percent")) else NONE
        | _ => NONE end
      val factorValue = only (List.mapPartial factor ns)
      val bases = List.mapPartial (fn (n : MeasuredInput.measurement) =>
        case #unitBinding n of MeasuredInput.Explicit {unit=u,...} =>
          if #dimension u = "ratio" then NONE else SOME(n,u)
        | _ => NONE) ns
      val densityMentioned = has "\\bdensity\\b" low
      val fixedDensity = has "\\b(?:constant|same|unchanged)\\s+(?:material\\s+)?density\\b|\\bdensity\\s+(?:(?:is|stays|remains)\\s+)?(?:constant|same|unchanged)\\b" low
      val changedDensity = has "\\bdensity\\b.*\\b(?:halv\\w*|doubl\\w*|tripl\\w*|increas\\w*|decreas\\w*|chang\\w*|reduc\\w*)\\b|\\b(?:halv\\w*|doubl\\w*|chang\\w*)\\s+(?:its |the )?density\\b" low
      val nonuniform = has "\\bnon[- ]?uniform\\w*\\b|\\b(?:only|just)\\b[^.?!;]*\\b(?:length|width|height|axis|axes|dimension|direction)\\b|\\b(?:one|single)\\s+(?:axis|dimension|direction)\\b" low
      val fixedAxis = has "\\b(?:length|width|height|axis|dimension)\\s+(?:(?:is|stays|remains)\\s+)?(?:unchanged|fixed|constant|the same)\\b|\\b(?:same|unchanged|fixed)\\s+(?:length|width|height)\\b|\\b(?:except|excluding|but not)\\b[^.?!;]*\\b(?:length|width|height|axis|dimension)\\b|\\banisotropic\\b" low
      val fixedMass = has "\\b(?:mass|weight)\\s+(?:(?:is|stays|remains)\\s+)?(?:unchanged|fixed|constant|the same)\\b|\\b(?:same|unchanged|fixed|constant)\\s+(?:mass|weight)\\b" low
      val unsupportedOperation = nonuniform orelse fixedAxis orelse fixedMass orelse (densityMentioned andalso (not fixedDensity orelse changedDensity))
      val malformed = List.exists (fn MeasuredInput.Malformed _ => true | _ => false) scanned
        orelse List.exists (fn (n : MeasuredInput.measurement) =>
          case #unitBinding n of MeasuredInput.Unsupported _ => true | _ => false) ns
      val wantsMass = has "\\b(?:weigh\\w*|mass|heavy)\\b" low
      val wantsVolume = has "\\bvolume\\b|\\bfilament\\b|\\bmaterial\\b" low
      val wantsArea = has "\\b(?:surface )?area\\b" low
      val wantsLength = has "\\b(?:length|width|height|long)\\b" low
      val targetText = case search "\\b(?:what|find|calculate|compute)\\b" low of
          NONE => "" | SOME m => String.extract (low,#start m,NONE)
      val explicit = List.mapPartial (fn (word,d) =>
        if has ("\\b" ^ word ^ "\\b") targetText then SOME d else NONE)
        [("(?:length|width|height|long)",M.ScaleLength),("(?:surface )?area",M.ScaleArea),
         ("volume",M.ScaleVolume),("(?:mass|weigh\\w*|heavy)",M.ScaleMass)]
      val distinctTargets = List.foldl (fn (d,ds) => if List.exists (fn x => x=d) ds then ds else d::ds) [] explicit
      val ambiguousTarget = length distinctTargets > 1
      val asksAmount = has "\\b(?:new|resulting|scaled)\\s+(?:length|width|height|area|volume|mass)\\b|\\bhow much\\b.*\\bweigh\\b" low
      val requested = case only distinctTargets of SOME d => SOME d | NONE =>
        if wantsMass then SOME M.ScaleMass else if wantsVolume then SOME M.ScaleVolume
        else if wantsArea then SOME M.ScaleArea else if wantsLength then SOME M.ScaleLength else NONE
    in if malformed orelse ambiguousTarget orelse unsupportedOperation then SOME M.ScaleUnread
       else case factorValue of NONE => SOME M.ScaleUnread
       | SOME (factorId,q,mode) =>
         if List.exists (fn (n : MeasuredInput.measurement) => #id n <> factorId andalso
              not (List.exists (fn (base,_) => #id base = #id n) bases)) ns then SOME M.ScaleUnread
         else (case bases of
          [(n,u)] => let val d = case requested of SOME d => d | NONE => dim (#dimension u)
                     in SOME (M.ScaleAmount (mode,rat q,d,rat (#value n),bu (#tag u))) end
        | [] => if asksAmount then SOME M.ScaleUnread else (case requested of SOME d => SOME (M.ScaleFactor (mode,rat q,d)) | NONE => SOME M.ScaleUnread)
        | _ => SOME M.ScaleUnread)
    end

  fun additive text =
    let val t = collapse text
    in
      if t = "" orelse Narrow.narrative t then NONE
      else
        let
          val low = lower t
          val r = case extrude low of SOME r => SOME r | NONE =>
                  (case scale low text of SOME r => SOME r | NONE => additiveV1 low)
        in
          case r of
            SOME req => if not (answered req) andalso not (has "\\d" t) then NONE else SOME req
          | NONE => NONE
        end
    end

  (* ---------- materials-v2 ---------- *)
  fun structure_ low =
    if has "\\bfcc\\b|\\bface[- ]centered\\b|\\bface[- ]centred\\b" low then SOME M.St_fcc
    else if has "\\bbcc\\b|\\bbody[- ]centered\\b|\\bbody[- ]centred\\b" low then SOME M.St_bcc
    else if has "\\bsimple cubic\\b|\\bprimitive cubic\\b|\\bsc\\b" low then SOME M.St_sc
    else NONE

  fun luOf u = if u = "cm" then M.LU_cm else if u = "mm" then M.LU_mm else M.LU_m
  fun luOfLen u = if u = "mm" then M.LU_mm else if u = "cm" then M.LU_cm else M.LU_m

  (* Quantity roles can precede or follow their number and unit. The selected
     output role must remain distinct from the supplied input roles. *)
  (* Quantity roles stay here; the shared lexer owns numeral spelling and spans.
     A malformed numeric run withholds the request rather than retrying its tail. *)
  fun scalars low =
    let val tokens = ExactNumeric.scan low
    in if List.exists (fn ExactNumeric.Malformed _ => true | _ => false) tokens then []
       else List.mapPartial (fn ExactNumeric.Number n => SOME n | _ => NONE) tokens end
  fun beforeScalar low ({start, ...} : {start:int, stop:int, value:q}) = String.substring (low, 0, start)
  fun afterScalar low ({stop, ...} : {start:int, stop:int, value:q}) = String.extract (low, stop, NONE)
  fun only [x] = SOME x | only _ = NONE
  fun pickScalar low ns pre post =
    Option.map #value (only (List.filter (fn n =>
      has pre (beforeScalar low n) orelse has post (afterScalar low n)) ns))

  fun hooke low =
    let
      val ns = scalars low
      val modulusRole = "(?:young'?s? modulus|elastic modulus|modulus)"
      fun unit s = case s of "pa" => M.SU_Pa | "gpa" => M.SU_GPa | _ => M.SU_MPa
      fun quantity role = only (List.mapPartial (fn n =>
        case search "^\\s*(gpa|mpa|pa)\\b" (afterScalar low n) of NONE => NONE
        | SOME m =>
          let val tail = String.extract (afterScalar low n, #stop m, NONE)
          in if has ("\\b" ^ role ^ "\\s*(?:of|is|=|:)?\\s*$") (beforeScalar low n)
                orelse has ("^\\s+(?:of\\s+)?" ^ role ^ "\\b") tail
             then SOME (rat (#value n), unit (valOf (grp (afterScalar low n) m 1))) else NONE end) ns)
      val modulus = quantity modulusRole
      val stress = quantity "stress"
      val strain = only (List.mapPartial (fn n =>
        let val tail = afterScalar low n
            val prefix = has "\\bstrain\\s*(?:of|is|=|:)?\\s*$" (beforeScalar low n)
                         andalso has "^(?:\\s|%|[.?!,;:]|$)" tail
            val suffix = has "^\\s*%?\\s+strain\\b" tail
            val pct = has "^\\s*%" tail
            val (a,b) = #value n
        in if prefix orelse suffix then SOME (rat (a, if pct then b * 100 else b)) else NONE end) ns)
      val explicitStress = has "\\b(?:what|find|calculate|compute|determine)(?: is| the|,)* stress\\b" low
      val explicitStrain = has "\\b(?:what|find|calculate|compute|determine)(?: is| the|,)* strain\\b" low
      val asksStress = explicitStress orelse (not explicitStrain andalso has "\\bstress\\?" low)
      val asksStrain = explicitStrain orelse (not explicitStress andalso has "\\bstrain\\?" low)
    in
      case modulus of NONE => NONE | SOME (e, eu) =>
        if asksStress andalso not asksStrain then Option.map (fn x => M.HookeStress (e, eu, x)) strain
        else if asksStrain andalso not asksStress then Option.map (fn (x, su) => M.HookeStrain (x, su, e, eu)) stress
        else NONE
    end

  fun materialsV1 (low : string) : M.request option =
    let val st = structure_ low in
      if has "\\bpacking (?:factor|fraction|efficiency)\\b|\\bapf\\b" low andalso isSome st
         andalso not (has "\\blattice (?:constant|parameter)\\b|\\bmolar mass\\b" low) then
        SOME (M.PackingFactor (valOf st))
      else if has "\\blattice (?:constant|parameter)\\b|\\bunit cell edge\\b|\\bedge length\\b" low
              andalso has "\\bdensity\\b" low then
        let
          val am = search ("\\b(?:lattice (?:constant|parameter)|edge(?: length)?)\\s*(?:of|is|=|a\\s*=)?\\s*" ^ NUME
                           ^ "\\s*(pm|nm|" ^ aring ^ "|angstroms?|a\\b)") low
          val mm = search ("\\b(?:molar mass|atomic (?:mass|weight))\\s*(?:of|is|=)?\\s*" ^ NUME ^ "\\s*g\\s*/\\s*mol|"
                           ^ NUME ^ "\\s*g\\s*/\\s*mol") low
        in
          case (am, mm) of
            (SOME a, SOME m) =>
              let
                val u = valOf (grp low a 2)
                val xu = if String.isPrefix "p" u then M.XU_pm else if String.isPrefix "n" u then M.XU_nm else M.XU_A
                val mv = valOf (firstQ low m [1, 2])
              in SOME (M.CrystalDensity (Option.map (fn s => s) st, rat (nth low a 1), xu, rat mv)) end
          | _ => NONE
        end
      else if has "\\bporosity\\b|\\bporous\\b|\\bvoid fraction\\b" low
              andalso has "\\bskeletal\\b|\\bsolid density\\b|\\btrue density\\b|\\bmaterial density\\b" low then
        (case (search ("\\b(?:bulk|apparent|envelope) density\\s*(?:of|is|=)?\\s*" ^ NUME) low,
               search ("\\b(?:skeletal|solid|true|material) density\\s*(?:of|is|=)?\\s*" ^ NUME) low) of
           (SOME b, SOME s) => SOME (M.PorosityAerogel (rat (nth low b 1), rat (nth low s 1)))
         | _ => NONE)
      else if has "\\bexpan\\w+\\b|\\bexpand\\w*\\b|\\bgrow\\w*\\b|\\blengthen\\w*\\b|\\bcontract\\w*\\b" low
              andalso has ("\\bthermal\\b|\\bheated\\b|\\bwarm\\w*\\b|\\btemperature\\b|\\bcoefficient\\b|(?<![a-z0-9_])"
                           ^ alpha ^ "(?![a-z0-9_])|\\balpha\\b") low then
        let
          val al = search ("(?:\\b(?:coefficient(?: of (?:linear )?(?:thermal )?expansion)?|alpha)|" ^ alpha
                           ^ ")\\s*(?:of|is|=)?\\s*" ^ NUME ^ "\\s*(?:x|" ^ times ^ ")?\\s*(?:10\\s*\\^?\\s*(-\\d+))?") low
          val lm = search (NUME ^ "\\s*(m|cm|mm|meters?|metres?)\\b(?!\\s*/)\\s*(?:long|length|rod|bar|beam|rail|bridge|pipe|steel|aluminum|aluminium|copper)?") low
          val dt = search ("\\b(?:by|rise of|change of|increase of|increases by)\\s*" ^ NUME ^ "\\s*(?:" ^ deg ^ "\\s*c|k|degrees?|c\\b)|"
                           ^ "\\bfrom\\s*(-?\\d+(?:\\.\\d+)?)\\s*(?:" ^ deg ^ "\\s*c|c\\b|degrees?)?\\s*to\\s*(-?\\d+(?:\\.\\d+)?)\\s*(?:"
                           ^ deg ^ "\\s*c|c\\b|degrees?)") low
        in
          case al of
            NONE => SOME (M.Expansion (NONE, rat zero, M.LU_m, rat zero))
          | SOME a =>
              (case (lm, dt) of
                 (SOME l, SOME d) =>
                   let
                     val mant = nth low a 1
                     val alphaV =
                       case grp low a 2 of
                         SOME e => let val k = valOf (Int.fromString e)  (* negative exponent *)
                                       val (n, dn) = mant
                                   in if k >= 0 then (n * IntInf.pow (10, k), dn) else (n, dn * IntInf.pow (10, ~k)) end
                       | NONE => mant
                     val dT = case grp low d 1 of
                                SOME s => qOfLit s
                              | NONE => qSub (nth low d 3, nth low d 2)
                   in SOME (M.Expansion (SOME (rat alphaV), rat (nth low l 1), luOf (valOf (grp low l 2)), rat dT)) end
               | _ => NONE)
        end
      else
        let
          val fm = search (NUME ^ "\\s*(kn|n|newtons?|kilonewtons?)\\b") low
          val am2 = search (NUME ^ "\\s*(mm2|mm" ^ sq2 ^ "|square millimet\\w+|m2|m" ^ sq2 ^ "|cm2|cm" ^ sq2 ^ ")") low
        in
          if not (has "\\bstress\\b|\\bstrain\\b|\\bmodulus\\b|\\byoung" low) then NONE
          else if has "\\byoung|\\bmodulus\\b|\\belastic modulus\\b" low
                  andalso has ("\\bstrain\\s*(?:of|is|=)?\\s*" ^ NUME) low
                  andalso has ("\\bstress\\s*(?:of|is|=)?\\s*" ^ NUME ^ "\\s*(mpa|gpa|pa)\\b") low
                  andalso not (has "\\bwhat (?:is )?(?:the )?(?:stress|strain)\\b" low) then
            let
              val sm = valOf (search ("\\bstress\\s*(?:of|is|=)?\\s*" ^ NUME ^ "\\s*(mpa|gpa|pa)\\b") low)
              val em = valOf (search ("\\bstrain\\s*(?:of|is|=)?\\s*" ^ NUME) low)
              val su = case valOf (grp low sm 2) of "pa" => M.SU_Pa | "gpa" => M.SU_GPa | _ => M.SU_MPa
              val e = nth low em 1
            in if qNonPos e then NONE else SOME (M.Modulus (rat (nth low sm 1), su, rat e)) end
          else if has "\\bstrain\\b" low
                  andalso has "\\bwhat (?:is )?(?:the )?strain\\b|\\bfind (?:the )?strain\\b|\\bcalculate (?:the )?strain\\b|\\bstrain\\?" low then
            let
              val ext = search ("\\b(?:stretch\\w*|elongat\\w*|extend\\w*|extension|compress\\w*|shorten\\w*|increase\\w*)\\s*(?:of|by)?\\s*" ^ NUME ^ "\\s*(mm|cm|m)\\b") low
              val orig = search (NUME ^ "\\s*(mm|cm|m)\\s*(?:long|length)|\\b(?:length|original length|long)\\s*(?:of|is)?\\s*" ^ NUME ^ "\\s*(mm|cm|m)\\b") low
            in
              case (ext, orig) of
                (SOME e, SOME orig_) =>
                  let
                    val ol = valOf (firstQ low orig_ [1, 3])
                    val ou = valOf (firstGroup low orig_ [2, 4])
                  in
                    if qNonPos ol then NONE
                    else SOME (M.Strain (rat (nth low e 1), luOfLen (valOf (grp low e 2)), rat ol, luOfLen ou))
                  end
              | _ => NONE
            end
          else
            case (fm, am2) of
              (SOME f, SOME a) =>
                if has "\\bstress\\b" low then
                  let
                    val fu = if String.isPrefix "k" (valOf (grp low f 2)) then M.FU_kN else M.FU_N
                    val au = valOf (grp low a 2)
                    val area = if String.isPrefix "mm" au orelse String.isSubstring "millimet" au then M.AU_mm2
                               else if String.isPrefix "cm" au then M.AU_cm2 else M.AU_m2
                    val av = nth low a 1
                  in if qNonPos av then NONE else SOME (M.Stress (rat (nth low f 1), fu, rat av, area)) end
                else NONE
            | _ => NONE
        end
    end

  fun materials text =
    let val t = collapse text
    in
      if t = "" orelse Narrow.narrative t then NONE
      else
        let
          val low = lower t
          val low =
            if isSome (structure_ low) andalso has "\\bdensity\\b" low
               andalso not (has "\\blattice (?:constant|parameter)\\b|\\bedge length\\b" low)
            then subst "\\ba\\s*=\\s*(?=\\d)" (fn _ => "lattice constant ") low else low
          val L = "(\\d+(?:\\.\\d+)?)\\s*(mm|cm|m)\\b"
          val low = subst ("\\b" ^ L ^ "\\s+(?:long\\s+)?(specimen|sample|bar|rod|wire|bolt|test piece|piece|strip|cable|member)\\b")
                      (fn m => valOf (grp low m 1) ^ " " ^ valOf (grp low m 2) ^ " long " ^ valOf (grp low m 3)) low
          val low = subst ("\\bgauge length\\s*(?:of|is|=)?\\s*" ^ L)
                      (fn m => valOf (grp low m 1) ^ " " ^ valOf (grp low m 2) ^ " long") low
          val low = subst "\\b(heated|warmed|cooled|raised|increased)\\s+(?=-?\\d)"
                      (fn m => valOf (grp low m 1) ^ " by ") low
        in
          case (case hooke low of SOME r => SOME r | NONE => materialsV1 low) of
            SOME req => if not (answered req) andalso not (has "\\d" low) then NONE else SOME req
          | NONE =>
              let
                val asks = has "\\b(?:what|find|calculate|compute|determine|how much|give)\\b|\\?" low
                val nums = has "\\d" low
              in
                if asks andalso nums andalso
                   ((isSome (structure_ low) andalso has "\\bdensity\\b" low
                     andalso has ("\\b(?:pm|nm|" ^ aring ^ "|angstroms?)\\b") low) orelse
                    has "\\b(?:find|calculate|what is|compute|determine) (?:the )?(?:engineering )?(?:strain|stress|young'?s modulus|elastic modulus)\\b" low orelse
                    (has ("\\bcoefficient\\b|\\balpha\\b|" ^ alpha) low
                     andalso has "\\bexpan\\w+\\b|\\bexpand\\w*\\b|\\blengthen\\w*\\b|\\blonger\\b" low))
                then SOME M.MatUnread else NONE
              end
        end
    end

  (* ---------- soil ---------- *)
  fun soilV1 (low : string) : M.request option =
    if not (has "\\bsoil\\b|\\bbulk density\\b|\\bporosity\\b|\\bwater content\\b|\\b(?:sand|silt|clay)\\b" low) then NONE
    else let
      val ns = scalars low
      fun pick pre post = pickScalar low ns pre post
      fun frac name = Option.map rat (only (List.mapPartial (fn n =>
        if has "^\\s*%" (afterScalar low n) andalso
           (has ("\\b" ^ name ^ "\\s*(?:content\\s*)?(?:of|is|=|:)?\\s*$") (beforeScalar low n)
            orelse has ("^\\s*%\\s*" ^ name ^ "\\b") (afterScalar low n))
        then SOME (#value n) else NONE) ns))
      val pdm = pick "\\bparticle density\\s*(?:of|is|=)?\\s*$" "(?!)"
      val pd = case pdm of SOME v => v | NONE => (265, 100)
      val bdm = pick "\\bbulk density\\s*(?:of|is|=|:)?\\s*$"
                     ("^\\s*g\\s*/\\s*cm(?:3|" ^ cube3 ^ "|\\^3)\\s*bulk density\\b")
      fun mass role = only (List.mapPartial (fn n =>
        if has "^\\s*g\\b(?!\\s*/)" (afterScalar low n) andalso
          (has ("\\b" ^ role ^ " (?:mass|weight)\\s*(?:of|is|=|:)?\\s*$") (beforeScalar low n)
           orelse has ("^\\s*g\\s*(?:when\\s+)?" ^ role ^ "\\b") (afterScalar low n))
        then SOME (rat (#value n)) else NONE) ns)
    in
      if has "\\btexture\\b|\\btextural\\b|\\bclassify\\b|\\bwhat (?:kind|type) of soil\\b" low then
        SOME (M.Texture (frac "sand", frac "silt", frac "clay"))
      else if has "\\bporosity\\b" low then SOME (M.SoilPorosity (Option.map rat bdm, rat pd, isSome pdm))
      else if has "\\bwater content\\b|\\bmoisture content\\b" low then
        if has "\\bvolumetric\\b" low then SOME (M.VolWaterContent (mass "wet", mass "(?:oven[- ])?dry", Option.map rat bdm))
        else SOME (M.WaterContent (mass "wet", mass "(?:oven[- ])?dry"))
      else if has "\\bbulk density\\b" low then
        SOME (M.BulkDensity (
          Option.map rat (pick "(?!)" "^\\s*g\\b(?!\\s*/)"),
          Option.map rat (pick "(?!)" ("^\\s*(?:cm3|cm" ^ cube3 ^ "|cm\\^3|cubic centimet(?:er|re)s|cc|ml)\\b"))))
      else NONE
    end

  fun soilCore text =
    let val t = collapse text
    in
      if t = "" orelse Narrow.narrative t then NONE
      else
        case soilV1 (lower t) of
          NONE => NONE
        | SOME req =>
            if M.silent req then NONE
            else SOME req
    end

  fun soil text = soilCore text
  fun soilR2 text =
    let val low = lower text
    in
      if has "\\b(?:aerogel|skeletal|solid density|foam|ceramic|metal|lattice|crystal\\w*|alloy|polymer)\\b" low
         andalso not (has "\\b(?:soil|loam|clay|sand|silt|field|topsoil|horizon)\\b" low) then NONE
      else soilCore text
    end

  (* ---------- water ---------- *)
  fun wnum low m g = rat (nth low m g)

  fun waterV1 (low : string) (raw : string) : M.request option =
    if has "\\b(?:safe|okay|ok) to drink\\b|\\bdrinkable\\b|\\bpotable\\b" low then SOME M.Potable
    else if has "\\bhardness\\b|\\bgrains? per gallon\\b|\\bgpg\\b" low then
      let
        val gm = search (NUMW ^ "\\s*(?:gpg|grains? per (?:us )?gallon|grains?)\\b") low
        val mm = search (NUMW ^ "\\s*(?:mg/l|ppm|milligrams per lit(?:er|re))\\b") low
      in
        case gm of
          SOME g =>
            if has "\\bmg/l\\b|\\bppm\\b|\\bmilligrams\\b" low
               andalso not (case mm of SOME m => #start m < #start g | NONE => false)
            then SOME (M.HardnessGpg (wnum low g 1))
            else (case mm of
                    SOME m => if has "\\bgpg\\b|\\bgrains?\\b" low then SOME (M.HardnessMgl (wnum low m 1)) else NONE
                  | NONE => NONE)
        | NONE =>
            (case mm of
               SOME m => if has "\\bgpg\\b|\\bgrains?\\b" low then SOME (M.HardnessMgl (wnum low m 1)) else NONE
             | NONE => NONE)
      end
    else if has "\\bmgd\\b|\\bmillion gallons? (?:per|a) day\\b" low andalso has "\\bpounds?\\b|\\blbs?\\b" low then
      let
        val fm = search (NUMW ^ "\\s*(?:mgd|million gallons? (?:per|a) day)\\b") low
        val dm = search (NUMW ^ "\\s*(?:mg/l|ppm)\\b") low
        val f = Option.map (fn m => wnum low m 1) fm
        val d = Option.map (fn m => wnum low m 1) dm
      in
        case (fm, dm) of
          (SOME _, SOME _) =>
            let
              val pm = search (NUMW ^ "\\s*%\\s*(?:available|strength|hypochlorite|pure)?") low
            in
              case pm of
                SOME p =>
                  if qPos (nth low p 1) andalso has "\\bhypochlorite\\b|\\bbleach\\b|\\b% (?:available|strength)\\b|\\bproduct\\b" low
                  then SOME (M.Pounds (f, d, SOME (wnum low p 1)))
                  else SOME (M.Pounds (f, d, NONE))
              | NONE => SOME (M.Pounds (f, d, NONE))
            end
        | _ => SOME (M.Pounds (f, d, NONE))
      end
    else if has "\\bct\\b|\\bct value\\b|\\bconcentration times time\\b" low then
      let
        (* Case folding is byte-preserving; spans are attached to raw user text. *)
        val low = lower raw
        fun units dimension tag aliases = List.map (fn alias =>
          {alias=alias, tag=tag, dimension=dimension, caseSensitive=false}) aliases
        val unitTable =
          units "ct" "ct" ["mg-min/L", "mg-mins/L", "mg-minute/L", "mg-minutes/L",
            "mg min/L", "mg mins/L", "mg minute/L", "mg minutes/L",
            "mg\194\183min/L", "mg\194\183mins/L", "mg\194\183minute/L", "mg\194\183minutes/L"] @
          units "concentration" "concentration" ["mg/L", "ppm"] @
          units "time" "minutes" ["min", "mins", "minute", "minutes"] @
          units "time" "hours" ["hr", "hrs", "hour", "hours"] @
          units "time" "seconds" ["sec", "secs", "second", "seconds"]
        val scanned = MeasuredInput.scan unitTable raw
        val malformed = List.exists (fn MeasuredInput.Malformed _ => true | _ => false) scanned
        val ns = List.mapPartial (fn MeasuredInput.Measurement n => SOME n | _ => NONE) scanned
        fun tail (n : MeasuredInput.measurement) = String.extract (low, #stop (#numberSpan n), NONE)
        fun prefix (n : MeasuredInput.measurement) = String.substring (low, 0, #start (#numberSpan n))
        (* Units establish dimensions; an explicit role cannot override them.
           Bare labelled CT retains the established mg-min/L convention. *)
        val ctRole = "(?:target\\s+)?ct(?: value| target)?"
        val concentrationRole = "(?:residual(?: concentration)?|concentration)"
        val timeRole = "(?:contact\\s+)?time"
        fun role pattern n = has ("\\b" ^ pattern ^ "\\s*(?:of|is|=|:)?\\s*$") (prefix n)
        fun labelled n = if role ctRole n then SOME 0
                         else if role concentrationRole n then SOME 1
                         else if role timeRole n then SOME 2 else NONE
        fun unit (n : MeasuredInput.measurement) = case #unitBinding n of
            MeasuredInput.Explicit {unit=u,span} =>
              let val dimension = if #dimension u = "ct" then 0
                                  else if #dimension u = "concentration" then 1 else 2
                  val factor : q = if #tag u = "hours" then (60,1)
                                   else if #tag u = "seconds" then (1,60) else (1,1)
              in SOME (dimension, factor, String.extract (low, #stop span, NONE)) end
          | _ => NONE
        fun bareTail t = has "^\\s*(?:$|[,.?!;:]|(?:and|at|with|for)\\b)" t
        fun suffixRole pattern t = has ("^\\s+" ^ pattern ^ "\\b") t
        fun consistent n dimension rest =
          (case labelled n of NONE => true | SOME r =>
            (case MeasuredInput.bind {expected=if r=0 then "ct" else if r=1 then "concentration" else "time", inheritFrom=NONE} n of
               MeasuredInput.Bound _ => true | _ => false)) andalso
          (not (suffixRole ctRole rest) orelse dimension = 0) andalso
          (not (suffixRole concentrationRole rest) orelse dimension = 1) andalso
          (not (suffixRole timeRole rest) orelse dimension = 2) andalso
          not (has "^\\s*[/^%]" rest)
        fun quantity n = case unit n of
            SOME (dimension, (a,b), rest) =>
              if consistent n dimension rest then
                let val (v,w) = #value n in SOME (dimension, rat (v*a,w*b)) end else NONE
          | NONE => if labelled n = SOME 0 andalso bareTail (tail n)
                    then SOME (0, rat (#value n)) else NONE
        val conflict = malformed orelse List.exists (fn n =>
          (case #unitBinding n of MeasuredInput.Unsupported _ => true | _ => false) orelse
          (case unit n of SOME (dimension, _, rest) => not (consistent n dimension rest)
           | NONE => isSome (labelled n) andalso not (labelled n = SOME 0 andalso bareTail (tail n)))) ns
        val quantities = if conflict then [] else List.mapPartial quantity ns
        fun selected dimension = only (List.mapPartial
          (fn (d,q) => if d = dimension then SOME q else NONE) quantities)
        val ct = selected 0
        val concentration = selected 1
        val time = selected 2
        val explicitTime = has "\\bhow (?:long|many minutes|much time)\\b|\\b(?:what|find|calculate|compute)\\s+(?:is\\s+)?(?:the\\s+)?(?:required\\s+)?(?:contact\\s+)?time\\b" low
        val explicitConcentration = not (has "\\bconcentration\\s+times\\s+time\\b" low) andalso has "\\b(?:what|find|calculate|compute)\\s+(?:is\\s+)?(?:the\\s+)?(?:required\\s+)?(?:residual(?: concentration)?|concentration)\\b" low
        val explicitCt = has "\\b(?:what|find|calculate|compute)\\s+(?:is\\s+)?(?:the\\s+)?ct\\b|\\bconcentration\\s+times\\s+time\\b" low
        val explicitTarget = explicitTime orelse explicitConcentration orelse explicitCt
        val wantTime = explicitTime orelse (not explicitTarget andalso has "\\b(?:contact )?time\\s*\\?$" low)
        val wantConcentration = explicitConcentration orelse (not explicitTarget andalso has "\\b(?:residual(?: concentration)?|concentration)\\s*\\?$" low)
      in if wantTime andalso wantConcentration then SOME (M.CtValue (NONE,NONE))
         else if wantTime then SOME (M.CtTime (ct, concentration))
         else if wantConcentration then SOME (M.CtConcentration (ct, time))
         else SOME (M.CtValue (concentration, time)) end
    else if has "\\bdemand\\b" low andalso has "\\bresidual\\b" low andalso has "\\bdose\\b|\\bdosage\\b" low then
      let
        fun pick name =
          case search ("\\b" ^ name ^ "\\s*(?:of|is|=)?\\s*" ^ NUMW) low of
            SOME m => SOME (wnum low m 1)
          | NONE => (case search (NUMW ^ "\\s*(?:mg/l|ppm)\\s*" ^ name ^ "\\b") low of
                       SOME m => SOME (wnum low m 1)
                     | NONE => NONE)
      in SOME (M.ChlorineDose (pick "demand", pick "residual")) end
    else if has "\\bdilut\\w*\\b|\\bhow much (?:bleach|concentrate|stock)\\b|\\bmake\\b.*\\b(?:solution|sanitizer)\\b" low then
      let
        val ns = scalars low
        fun wu u = if u = "ml" then M.WU_ml else if String.isPrefix "gal" u then M.WU_gal else M.WU_l
        val cs = List.mapPartial (fn n =>
          case search "^\\s*(%|ppm\\b|mg/l\\b)" (afterScalar low n) of NONE => NONE
          | SOME m => SOME (n, (rat (#value n), if valOf (grp (afterScalar low n) m 1) = "%" then M.C_pct else M.C_mgl),
                           String.extract (afterScalar low n, #stop m, NONE))) ns
        fun stock (n,_,tail) =
          has "\\b(?:stock|bleach|concentrate)(?: concentration| strength)?\\s*(?:of|is|at|=|:)?\\s*$" (beforeScalar low n)
          orelse has "^\\s*(?:stock|bleach|concentrate)\\b" tail
          orelse has "\\bfrom\\s*$" (beforeScalar low n)
        fun target (n,_,tail) =
          has "\\b(?:target|final)(?: concentration| strength)?\\s*(?:of|is|at|=|:)?\\s*$" (beforeScalar low n)
          orelse has "\\bto\\s*(?:a\\s*)?$" (beforeScalar low n)
          orelse has "^\\s*(?:target|sanitizer|solution)\\b" tail
        fun pair (a as (_,ca,_), b as (_,cb,_)) =
          let val sa = stock a val sb = stock b val ta = target a val tb = target b
          in if (sa andalso ta) orelse (sb andalso tb) orelse (sa andalso sb) orelse (ta andalso tb) then NONE
             else if sa orelse tb then SOME (ca,cb)
             else if sb orelse ta then SOME (cb,ca)
             else NONE end
        val concs = case cs of [a,b] => pair (a,b) | _ => NONE
        val vol = only (List.mapPartial (fn n =>
          case search "^\\s*(ml|liters?|litres?|l|gallons?|gal)\\b" (afterScalar low n) of NONE => NONE
          | SOME m => SOME (rat (#value n), wu (valOf (grp (afterScalar low n) m 1)))) ns)
      in SOME (M.Dilution (concs, vol)) end
    else if has "\\bph\\b" low andalso has "\\bh\\+|\\bhydrogen[- ]ion\\b|\\bhydronium\\b|\\bmol/l\\b|\\bconcentration\\b" low then
      let
        val hm = search (NUMW ^ "\\s*(?:mol/l|m\\b|moles? per lit)") low
        val pm = search "\\bph\\s*(?:of|is|=)?\\s*(\\d+(?:\\.\\d+)?)" low
      in
        case hm of
          SOME h =>
            if has "\\bwhat is the ph\\b|\\bfind the ph\\b|\\bph\\?|\\bcalculate the ph\\b|\\bthe ph\\b" low
               andalso (case pm of NONE => true | SOME p => #start h < #start p)
            then SOME (M.PhOf (wnum low h 1))
            else (case pm of SOME p => SOME (M.HConc (wnum low p 1)) | NONE => NONE)
        | NONE => (case pm of SOME p => SOME (M.HConc (wnum low p 1)) | NONE => NONE)
      end
    else NONE

  fun waterCore text =
    let val t = collapse text
    in
      if t = "" orelse Narrow.narrative t then NONE
      else
        case waterV1 (lower t) text of
          NONE => NONE
        | SOME req => if not (answered req) andalso not (Narrow.short_direct t) then NONE else SOME req
    end

  fun waterR2 text =
    let val low = lower text
    in
      if has "\\b(?:colon(?:y|ies)|cfu|plate count|serial(?:ly)? dilut\\w*|bacteri\\w*)\\b" low
         andalso not (has "\\b(?:water|hardness|chlorine|turbidity|ph|tds|ppm|mg/l)\\b" low) then NONE
      else waterCore text
    end

  fun waterR3 text =
    let val low = lower text
    in
      if has "\\b\\d+(?:\\.\\d+)?\\s*m\\b|\\bmolar\\w*|\\bmoles?\\b" low
         andalso not (has "\\b(?:water|hardness|chlorine|bleach|turbidity|ph|tds|ppm|mg/l)\\b" low) then NONE
      else waterR2 text
    end

  (* ---------- dispatch ---------- *)
  val organs = ["additive-v2", "materials-v2", "soil", "soil-r2", "water", "water-r3"]

  fun byId "additive-v2" = additive
    | byId "materials-v2" = materials
    | byId "soil" = soil
    | byId "soil-r2" = soilR2
    | byId "water" = waterCore
    | byId "water-r3" = waterR3
    | byId other = raise Fail ("unknown specialist " ^ other)

  (* The family: each family's organ in a fixed order, the first that takes
     the question answers it. *)
  val familyOrder = ["water", "additive-v2", "materials-v2", "soil"]

  fun recognize mode text =
    if mode = "family" then
      let fun go [] = NONE
            | go (id :: ids) = case byId id text of SOME r => SOME (id, r) | NONE => go ids
      in go familyOrder end
    else Option.map (fn r => (mode, r)) (byId mode text)
end
