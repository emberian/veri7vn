(* UNTRUSTED. The English recognizer: a hand port of the regular expressions
   and branch order of upstream/root/specialists/acoustics/organ_acoustics_v1.py
   (AcousticsOrgan.answer and speed). It reads numbers off the question and
   builds a typed Acoustics.request; it computes nothing. Every value, decline
   and response text comes from the verified HOL kernel (Acoustics.reply_of).
   NONE means the question is not taken at all (the organ returns None).

   Deliberate differences from the organ, all in the kernel's favour:
   - a temperature at or below -273.15 C is passed to the kernel, which
     declines it as impossible; the organ silently fell back to air at 20 C;
   - a string with a non-positive length and no wave speed is declined as
     underspecified (wave speed missing) rather than impossible, because the
     kernel checks for missing values before impossible ones. *)
structure Recognizer :
sig
  val recognize : string -> Acoustics.request option
end =
struct
  structure A = Acoustics

  val N = "(qnum[0-9]+q)"
  val deg = "\194\176"          (* U+00B0 DEGREE SIGN, UTF-8 *)
  val celsius = "\226\132\131"  (* U+2103 DEGREE CELSIUS, UTF-8 *)

  val cache : (string * Regex.regex) list ref = ref []
  fun re p =
    case List.find (fn (q, _) => q = p) (!cache) of
      SOME (_, r) => r
    | NONE => let val r = Regex.compile p in cache := (p, r) :: !cache; r end

  fun search p s = Regex.search (re p) s
  fun has p s = isSome (search p s)
  fun findall p s = Regex.findall (re p) s
  fun grp s m g = Regex.group s m g
  fun grpOr s m gs = case List.mapPartial (grp s m) gs of x :: _ => SOME x | [] => NONE

  (* Every role capture resolves through the current lexer's token table.
     Text that merely looks like a token cannot supply a numeric value. *)
  exception UnboundNumeral
  val numericValues : (string * ExactNumeric.rational) list ref = ref []
  fun rationalOf token = case List.find (fn (key, _) => key = token) (!numericValues) of
      SOME (_, value) => value | NONE => raise UnboundNumeral
  fun ratOf token : A.rat = let val (n, d) = rationalOf token in A.mk_rat n d end
  fun withNumerals read text = case ExactNumeric.mask text of NONE => NONE
    | SOME {text = masked, numbers} =>
        let val previous = !numericValues
            val _ = numericValues := numbers
            val answer = (read masked handle UnboundNumeral => NONE)
                handle e => (numericValues := previous; raise e)
            val _ = numericValues := previous
        in answer end

  fun lower s = String.map Char.toLower s
  fun collapse s = String.concatWith " " (String.tokens Char.isSpace s)

  fun replaceAll (s, pat, rep) =
    let
      val n = size pat
      fun go i acc start =
        if n = 0 orelse i + n > size s then
          String.concat (rev (String.extract (s, start, NONE) :: acc))
        else if String.substring (s, i, n) = pat then
          go (i + n) (rep :: String.substring (s, start, i - start) :: acc) (i + n)
        else go (i + 1) acc start
    in go 0 [] 0 end

  (* speed(low): a stated speed of sound, else air at a stated temperature,
     else air at 20 C *)
  val statedSpeed = "\\b(?:speed of sound|sound speed|wave speed)\\s*(?:is|of|=)?\\s*" ^ N ^ "\\s*m/s"
  val trailingSpeed = N ^ "\\s*m/s\\s*(?:speed of sound|sound speed)"
  val bareSpeed = "\\bspeed\\s*(?:is|of|=)?\\s*" ^ N ^ "\\s*m/s"
  val motionContext = "\\bdoppler\\b|\\bmoving\\b|\\bapproach|\\brecede|\\btoward|\\baway from\\b|\\bdriving\\b"
  fun labelledSpeedMatch low = case search statedSpeed low of SOME m => SOME m | NONE => search trailingSpeed low
  (* In a wave equation a plain stated speed denotes propagation speed.
     With moving actors it is ambiguous; require the explicit sound/wave label. *)
  fun speedMatch low = case labelledSpeedMatch low of SOME m => SOME m
      | NONE => if has motionContext low then NONE else search bareSpeed low

  fun speed (low : string) : A.medium =
    let
      val stated =
        speedMatch low
    in
      case stated of
        SOME m => A.Stated (ratOf (valOf (grp low m 1)))
      | NONE =>
          let
            val tm = search (N ^ "\\s*(?:" ^ deg ^ "\\s*c|degrees? c(?:elsius)?|" ^ celsius ^ "|c\\b)") low
            val air = String.isSubstring "air" low
            val water = has "\\bwater\\b" low
          in
            case tm of
              SOME m => if air orelse not water then A.AirAt (ratOf (valOf (grp low m 1)))
                        else A.AirDefault
            | NONE => A.AirDefault
          end
    end

  val ordinals = [("first", 1), ("fundamental", 1), ("second", 2), ("third", 3),
                  ("fourth", 4), ("fifth", 5), ("sixth", 6), ("seventh", 7)]

  fun recognize (text : string) : A.request option =
    let
      val t = collapse text
      val low = lower t
      val sound = has ("\\bsound\\b|\\bacoustic|\\bdecibel|\\bdb\\b|\\bdoppler\\b|\\bsiren\\b|\\bhorn\\b|"
                       ^ "\\bpipe\\b|\\bstring\\b|\\bharmonic|\\bbeats?\\b|\\btuning fork\\b|\\bpitch\\b|"
                       ^ "\\bhonk\\w*|\\bwhistle\\b|\\bhear\\b") low
      (* These inputs state a physical condition for which this recognizer
         has no unit/model conversion. Do not silently replace it by air
         at 20 C or interpret feet per second as metres per second. *)
      val unsupportedSpeed = has (N ^ "\\s*(?:ft/s|feet(?:/|\\s+per\\s+)second|fps|mph|km/h|km/s|cm/s|mm/s|miles?\\s+per\\s+hour|met(?:er|re)s?\\s+per\\s+second)\\b") low
      val unsupportedTemperature = has (N ^ "\\s*(?:" ^ deg ^ "\\s*[fk]|degrees?\\s*(?:f(?:ahrenheit)?|k(?:elvin)?)|fahrenheit|kelvin)\\b") low
      val ambiguousSpeed = has motionContext low andalso isSome (search bareSpeed low)
          andalso not (isSome (labelledSpeedMatch low))
      val water = has "\\bwater\\b" low
      val waterTemperature = search (N ^ "\\s*(?:" ^ deg ^ "\\s*c|degrees? c(?:elsius)?|" ^ celsius ^ "|c\\b)") low
      val waterAtOtherTemperature = case waterTemperature of NONE => false
          | SOME m => let val (n, d) = rationalOf (valOf (grp low m 1)) in n <> 20 * d end
      val unsupportedWater = not (isSome (speedMatch low)) andalso
          (has "\\b(?:sea|salt)\\s*water\\b" low orelse
           (water andalso (waterAtOtherTemperature orelse
             not (has "\\bspeed of sound\\b|\\bhow fast (?:does|is) sound\\b" low))))
    in
      if not sound orelse unsupportedSpeed orelse unsupportedTemperature orelse unsupportedWater orelse ambiguousSpeed then NONE
      else if has "\\bbeat frequency\\b|\\bbeats? per second\\b" low
              orelse (has "\\bbeats?\\b" low andalso length (findall (N ^ "\\s*hz\\b") low) >= 2) then
        let val fs = map (fn m => ratOf (valOf (grp low m 1))) (findall (N ^ "\\s*hz\\b") low)
        in case fs of
             a :: b :: _ => SOME (A.Beat (SOME a, SOME b))
           | [a] => SOME (A.Beat (SOME a, NONE))
           | [] => SOME (A.Beat (NONE, NONE))
        end
      else if has motionContext low
              andalso has "\\bfrequency\\b|\\bpitch\\b|\\bhear\\b|\\bheard\\b|\\bobserved\\b" low then
        let
          val fm = search (N ^ "\\s*hz\\b") low
          (* Remove the labelled medium speed before looking for a mover's
             speed. Its position in the sentence must not change the model. *)
          val movingText = case speedMatch low of
              SOME m => replaceAll (low, Regex.whole low m, " ") | NONE => low
          val vm = search (N ^ "\\s*m/s\\b") movingText
        in
          case (fm, vm) of
            (SOME fm, SOME vm) =>
              let
                val f = ratOf (valOf (grp low fm 1))
                val u = ratOf (valOf (grp movingText vm 1))
                val medium = speed low
                val toward = has "\\btoward|\\bapproach" low
                val away = has "\\baway from\\b|\\brecede|\\bmoving away\\b" low
                (* Assign each motion phrase to its nearest preceding named
                   actor. A source mentioned in an earlier clause must not
                   turn a moving listener into a moving source. The kernel
                   models one moving actor, so two moving actors fall through. *)
                val motions = findall "\\b(?:moves?|moving|drives?|driving|runs?|running|walks?|walking|approach\\w*|reced\\w*)\\b" low
                fun actor ({start, ...} : Regex.match) =
                  let val prefix = String.substring (low, 0, start)
                  in case rev (findall "\\b(listener|observer|you|i|source|siren|car|train|ambulance|horn)\\b" prefix) of
                       [] => NONE
                     | m :: _ => SOME (List.exists (fn x => grp prefix m 1 = SOME x)
                                                ["listener", "observer", "you", "i"])
                  end
                val actors = List.mapPartial actor motions
                val listener = List.exists (fn x => x) actors
                val bothMoving = listener andalso List.exists (fn x => not x) actors
                val dir = if toward = away then A.Unclear else if toward then A.Toward else A.Away
              in
                if bothMoving then NONE else
                  SOME (A.Doppler (SOME f, SOME u, if listener then A.Listener else A.Source, dir, medium))
              end
          | (fm, vm) =>
              SOME (A.Doppler (Option.map (fn m => ratOf (valOf (grp low m 1))) fm,
                               Option.map (fn m => ratOf (valOf (grp movingText m 1))) vm,
                               A.Source, A.Unclear, A.AirDefault))
        end
      else if has "\\bdecibel|\\bdb\\b" low then
        let
          val ls = map (fn m => ratOf (valOf (grp low m 1))) (findall (N ^ "\\s*(?:db|decibels?)\\b") low)
          val combined = has "\\btogether\\b|\\bcombined\\b|\\bboth\\b|\\btotal\\b" low
          val dm = map (fn m => ratOf (valOf (grp low m 1)))
                       (findall (N ^ "\\s*(?:m|meters?|metres?|ft|feet)\\b(?!\\s*/)") low)
          val mixedDistances = has (N ^ "\\s*(?:m|meters?|metres?)\\b(?!\\s*/)") low
                               andalso has (N ^ "\\s*(?:ft|feet)\\b(?!\\s*/)") low
          val rm = search ("\\b(?:intensity|power)\\b[^.?]*?\\b" ^ N ^ "\\s*times\\b|\\b" ^ N
                           ^ "\\s*times (?:the |as )?(?:intensity|intense|power|more intense)") low
        in
          if (combined orelse has "\\btwo\\b" low) andalso length ls >= 2 then SOME (A.DbSum ls)
          else if combined andalso length ls = 1 andalso has "\\btwo\\b|\\bidentical\\b|\\bsame\\b" low then
            SOME (A.DbTwoEqual (hd ls))
          else if length ls = 1 andalso length dm >= 2 then
            if mixedDistances then NONE else SOME (A.DbDistance (hd ls, hd dm, hd (tl dm)))
          else case rm of
            SOME m => SOME (A.DbRatio (ratOf (valOf (grpOr low m [1, 2]))))
          | NONE =>
              if length ls = 2 andalso has "\\bhow many times\\b|\\bratio\\b" low then
                SOME (A.IntensityRatio (hd ls, hd (tl ls)))
              else NONE
        end
      else
        let
          val pm = search ("\\b(open|closed|stopped)\\b[^.?]*\\bpipe\\b|\\bpipe\\b[^.?]*\\b(open|closed) at "
                           ^ "(?:both ends|one end)\\b|\\bpipe (open|closed)\\b") low
          val sm = has "\\bstring\\b" low
        in
          if (isSome pm orelse sm) andalso has "\\bfrequency\\b|\\bharmonic\\b|\\bfundamental\\b|\\bovertone\\b" low then
            let
              val lm = search (N ^ "\\s*(m|cm)\\b(?!\\s*/)(?:\\s*(?:long|length))?") low
              val len = Option.map (fn m => (ratOf (valOf (grp low m 1)),
                                             if grp low m 2 = SOME "cm" then A.Centimetre else A.Metre)) lm
              val om = search "\\b(first|second|third|fourth|fifth|sixth|seventh|fundamental)\\b(?:\\s+harmonic)?" low
              val nm = search (N ^ "(?:st|nd|rd|th)\\s+harmonic\\b|\\bharmonic\\s*(?:n\\s*=\\s*)?" ^ N) low
              val harmonicValue = Option.map (fn m => rationalOf (valOf (grpOr low m [1, 2]))) nm
              val badHarmonic = case harmonicValue of SOME (n, d) => n < 0 orelse d <> 1 | NONE => false
              val n = case harmonicValue of
                        SOME (n, _) => n
                      | NONE => (case om of
                                   SOME m => let val w = valOf (grp low m 1)
                                             in IntInf.fromInt (#2 (valOf (List.find (fn (k, _) => k = w) ordinals))) end
                                 | NONE => 1)
              val hn = A.mk_nat n
            in
              if badHarmonic then NONE else if sm then
                let val vm = search ("\\bwave speed\\s*(?:of|is|=)?\\s*" ^ N ^ "\\s*m/s|" ^ N ^ "\\s*m/s") low
                    val v = Option.map (fn m => ratOf (valOf (grpOr low m [1, 2]))) vm
                in SOME (A.StringHarmonic (hn, len, v)) end
              else
                let
                  val m = valOf pm
                  val which = valOf (grpOr low m [1, 2, 3])
                  val closed = (which = "closed" orelse which = "stopped")
                               andalso not (has "\\bclosed at both ends\\b" low)
                  val medium = speed low
                in
                  if closed then SOME (A.PipeClosed (hn, len, medium))
                  else SOME (A.PipeOpen (hn, len, medium))
                end
            end
          else if has "\\bwavelength\\b" low
                  andalso not (has "\\bfrequency\\b" low andalso
                    (has ("\\bwavelength\\s*(?:of|is|=)?\\s*" ^ N ^ "\\s*(?:m|cm)\\b(?!\\s*/)") low
                     orelse has (N ^ "\\s*(?:m|cm)\\s*wavelength\\b") low)) then
            (case search (N ^ "\\s*(k?hz)\\b") low of
               NONE => SOME (A.Wavelength (NONE, A.AirDefault))
             | SOME m =>
                 SOME (A.Wavelength (SOME (ratOf (valOf (grp low m 1)),
                                           if grp low m 2 = SOME "khz" then A.KHz else A.Hz),
                                     speed low)))
          else
            let
              val lm = if has "\\bfrequency\\b" low then
                         (case search ("\\bwavelength\\s*(?:of|is|=)?\\s*" ^ N ^ "\\s*(m|cm)\\b(?!\\s*/)") low of
                            SOME m => SOME m
                          | NONE => search (N ^ "\\s*(m|cm)\\s*wavelength\\b") low)
                       else NONE
            in
              case lm of
                SOME m =>
                  SOME (A.Frequency ((ratOf (valOf (grp low m 1)),
                                      if grp low m 2 = SOME "cm" then A.Centimetre else A.Metre),
                                     speed low))
              | NONE =>
                  if has "\\bspeed of sound\\b|\\bhow fast (?:does|is) sound\\b" low then
                    if has "\\bwater\\b" low then SOME A.SpeedWater
                    else if has "\\bair\\b" low orelse not (has "\\bin (?!air)\\w+" low) then
                      SOME (A.SpeedAir (speed low))
                    else NONE
                  else NONE
            end
        end
    end
  val recognize = withNumerals recognize

end
