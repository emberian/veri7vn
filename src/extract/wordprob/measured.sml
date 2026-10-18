(* UNTRUSTED finite English-to-measured-request adapter. ExactNumeric owns
   numeral syntax. This module binds roles and units, never computes answers.
   Every consumed numeric mask is resolved through its non-user-injectable table.
   Unsupported or ambiguous measured questions refuse, never fall back to the
   old unit-erasing motion/geometry recognizer. *)
structure MeasuredRecognizer =
struct
  structure Q = Wordprob
  exception Reject of string
  fun lower s = String.map Char.toLower s
  fun matches p s = Regex.findall (Regex.compile p) s
  fun has p s = not (null (matches p s))
  fun grp s m n = Regex.group s m n
  fun g s m n = case grp s m n of SOME x => x | NONE => ""
  val marker = "(qnum[0-9]+q)"
  fun unit word =
    case lower word of "s" => SOME (Q.Mtime, Q.U_second)
    | "hr" => SOME (Q.Mtime, Q.U_hr)
    | other => Recognizer.unitOf other
  fun require kind word =
    case unit word of SOME (k,u) => if k = kind then u
        else raise Reject "The given unit has the wrong dimension."
    | NONE => raise Reject "This unit is not supported."
  fun one [] = raise Reject "A required quantity or unit is missing."
    | one [x] = x
    | one _ = raise Reject "More than one quantity matches this role."

  fun recognize text =
    let
      val raw = lower text
      val rawq = Recognizer.questionPart raw
      val geometryGoal = has "\\b(rectangle|circle|cylinder|cone|sphere)\\b" raw
        andalso has "\\b(area|perimeter|circumference|volume)\\b" rawq
      val motionGoal = has "\\b(speed|rate|how fast|how far|distance)\\b" rawq
        andalso has "\\b(travel|travels|travelled|traveled|moves?|moving|walks?|runs?|drives?|driving|speed|distance)\\b" raw
    in
      if not (geometryGoal orelse motionGoal) then NONE else
      let
        val {text=masked, numbers} = case ExactNumeric.mask raw of
          SOME x => x | NONE => raise Reject "A numeric input is malformed or exceeds the supported range."
        val q = Recognizer.questionPart masked
        fun rat key = case List.find (fn (k,_) => k=key) numbers of
          SOME (_, (n,d)) => Q.mk_rat n d
        | NONE => raise Reject "Unbound numeric marker."
        fun pair key = case List.find (fn (k,_) => k=key) numbers of
          SOME (_,v) => v | NONE => raise Reject "Unbound numeric marker."
        fun near role =
          let val m = one (matches ("\\b" ^ role ^ "\\s*(?:(?:of|is|=)\\s*)?" ^ marker ^ "\\s*([a-z]+)\\b") masked)
          in (rat (g masked m 1), require Q.Mlength (g masked m 2)) end
        fun hasRole role = has ("\\b" ^ role ^ "\\b") masked
        val targets = matches "\\bin\\s+(?:(square|cubic)\\s+)?([a-z]+)(?:\\s*(?:/|per\\s+)\\s*([a-z]+))?(?:\\^?([0-9]+))?\\b" q
        val inWords = matches "\\bin\\s+(qnum[0-9]+q|[a-z][a-z0-9]*)" q
        val unparsedTarget = null targets andalso List.exists (fn m =>
          not (List.exists (fn (key,_) => key = g q m 1) numbers)) inWords
        fun targetLength degree fallback =
          case targets of [] => if unparsedTarget then raise Reject "The requested output unit is not supported." else fallback
          | [m] => let val power = g q m 1
                       val exponent = g q m 4
                       val named = if power="square" then 2 else if power="cubic" then 3 else 1
                       val actual = case exponent of "" => named | "1" => 1 | "2" => 2 | "3" => 3
                         | _ => raise Reject "This output dimension is not supported."
                       val _ = if power <> "" andalso actual <> named
                               then raise Reject "The requested output dimensions conflict." else ()
                   in if actual <> degree orelse g q m 3 <> ""
                      then raise Reject "The requested output has the wrong dimension."
                      else require Q.Mlength (g q m 2) end
          | _ => raise Reject "More than one output unit was requested."
        fun piValue () =
          let val forward = matches ("(?:\\bpi|\207\128)\\s*(?:(?:=|as|is)\\s*)?" ^ marker) masked
              val backward = matches (marker ^ "\\s+for\\s+(?:pi\\b|\207\128)") masked
          in case forward @ backward of [] => Q.Pidouble
             | [m] => let val (n,d) = pair (g masked m 1)
                      in if n*50 = 157*d then Q.Pi314
                         else raise Reject "This explicit pi value is not supported." end
             | _ => raise Reject "More than one pi value was supplied." end
        fun geom () =
          let
            val shapes = List.filter (fn name => has ("\\b" ^ name ^ "\\b") masked)
                         ["rectangle","circle","cylinder","cone","sphere"]
            val goals = List.filter (fn name => has ("\\b" ^ name ^ "\\b") q)
                        ["area","perimeter","circumference","volume"]
            val _ = if length shapes = 1 andalso length goals = 1 then ()
                    else raise Reject "This question does not identify one shape and one geometric goal."
            val isVol = has "\\bvolume\\b" q
            val (shape,degree,a,au,b,bu) =
              if has "\\brectangle\\b" masked then
                let val ((a,au),(b,bu)) =
                      if hasRole "length" orelse hasRole "width"
                      then (near "length",near "width")
                      else let val m=one(matches (marker ^ "\\s*([a-z]+)\\s+by\\s+" ^ marker ^ "\\s*([a-z]+)\\b") masked)
                           in ((rat(g masked m 1),require Q.Mlength(g masked m 2)),
                               (rat(g masked m 3),require Q.Mlength(g masked m 4))) end
                in if has "\\barea\\b" q then (Q.RectangleArea,2,a,au,b,bu)
                   else if has "\\bperimeter\\b" q then (Q.RectanglePerimeter,1,a,au,b,bu)
                   else raise Reject "Unsupported rectangle goal." end
              else
                let val (a,au) = if hasRole "radius" then near "radius"
                      else let val (d,u)=near "diameter" in (Q.half_rat d,u) end
                in if has "\\bcircle\\b" masked then
                     if has "\\barea\\b" q then (Q.CircleAreaU,2,a,au,a,au)
                     else if has "\\bcircumference\\b" q then (Q.CircleCircumference,1,a,au,a,au)
                     else raise Reject "Unsupported circle goal."
                   else if has "\\bsphere\\b" masked andalso isVol then (Q.SphereVolume,3,a,au,a,au)
                   else if isVol then let val (b,bu)=near "height"
                        in if has "\\bcylinder\\b" masked then (Q.CylinderVolume,3,a,au,b,bu)
                           else if has "\\bcone\\b" masked then (Q.ConeVolume,3,a,au,b,bu)
                           else raise Reject "Unsupported volume shape." end
                   else raise Reject "Unsupported geometry goal."
                end
            val out = targetLength degree au
          in Q.Geometry (shape,a,au,b,bu,out,piValue ()) end
        fun motion () =
          let
            val rates = matches (marker ^ "\\s*([a-z]+)\\s*(?:/|per\\s+)\\s*([a-z]+)\\b") masked
            val quantities = matches (marker ^ "\\s*([a-z]+)\\b") masked
            fun outsideRate m = not (List.exists (fn r => #start r <= #start m andalso #start m < #stop r) rates)
            fun quantitiesOf kind = List.filter (fn m => outsideRate m andalso
              (case unit (g masked m 2) of SOME (k,_) => k=kind | NONE => false)) quantities
            fun quantity kind = let val m=one (quantitiesOf kind)
              in (rat (g masked m 1),require kind (g masked m 2)) end
            val (t,tu)=quantity Q.Mtime
          in if not (has "\\b(speed|rate|how fast)\\b" q) then
               let val r=one rates
                   val du=require Q.Mlength (g masked r 2)
                   val rt=require Q.Mtime (g masked r 3)
               in Q.Distance (rat (g masked r 1),du,rt,t,tu,targetLength 1 du) end
             else
               let val _ = if null rates then () else raise Reject "Speed requires distance and duration, not another rate."
                   val (x,du)=quantity Q.Mlength
                   val (ou,ot)=case targets of [] => if unparsedTarget then raise Reject "The requested output unit is not supported." else (du,Q.U_hour)
                     | [m] => if g q m 1 <> "" orelse g q m 4 <> "" orelse g q m 3 = ""
                              then raise Reject "A speed output needs a distance unit per time unit."
                              else (require Q.Mlength (g q m 2),require Q.Mtime (g q m 3))
                     | _ => raise Reject "More than one output unit was requested."
               in Q.Speed (x,du,t,tu,ou,ot) end
          end
        val _ = if has "\\b(then|after that|twice|faster|slower)\\b" masked
                then raise Reject "This multi-step measured problem is not supported." else ()
      in SOME (if geometryGoal then geom () else motion ()) end
    end
end
