(* UNTRUSTED finite whole-request reader. Typed legs retain units and are
   evaluated by Wordprob.journey_reply; this reader does no trip arithmetic.
   Equal weighting is admitted only by an explicit equal-times/distances clause. *)
structure JourneyRecognizer =
struct
  structure Q = Wordprob
  structure M = MeasuredRecognizer
  exception Reject = MeasuredRecognizer.Reject
  val n = "(qnum[0-9]+q)"
  val u = "([a-z]+)"
  val quantity = n ^ "\\s*" ^ u
  val rate = quantity ^ "\\s*(?:/|per\\s+)\\s*" ^ u
  fun matches p s = M.matches p s
  fun g s m i = M.g s m i
  fun whole p s = case matches ("^\\s*" ^ p ^ "\\s*$") s of [m] => SOME m | _ => NONE
  fun trim s = String.concatWith " " (String.tokens Char.isSpace s)
  val prefix = "(?:(?:a|the)\\s+)?(?:car|train|cyclist|runner|person|vehicle|bus|walker|boat)\\s+(?:travels?|moves?|walks?|runs?|drives?|cycles?)\\s+"
  val optionalVerb = "(?:(?:travels?|moves?|walks?|runs?|drives?|cycles?)\\s+)?"

  fun recognize text =
    let val raw = M.lower text
    in if not (M.has "\\baverage speed\\b" raw) orelse
       not (M.has "\\b(then|equal|and|legs|stops?|waits?)\\b" raw) then NONE else
      let
        val _ = if size text <= 8192 then () else raise Reject "The journey request is too long."
        val {text=masked,numbers} = case ExactNumeric.mask raw of SOME x => x
          | NONE => raise Reject "A journey quantity is malformed or exceeds the supported range."
        fun rat key = case List.find (fn (k,_)=>k=key) numbers of SOME (_, (a,b)) =>
          if size (IntInf.toString a) <= 256 andalso size (IntInf.toString b) <= 256
          then Q.mk_rat a b else raise Reject "A journey quantity exceeds the supported range."
          | NONE => raise Reject "An unbound numeric marker is not a quantity."
        val request = prefix ^ "(.+?)\\s*[.]?\\s+(?:what is|find|calculate)\\s+(?:(?:its|the|their)\\s+)?(?:overall\\s+)?average speed(?:\\s+in\\s+([a-z]+)\\s*(?:/|per\\s+)\\s*([a-z]+))?\\s*[?.]?"
        val m = case whole request masked of SOME x => x | NONE =>
          raise Reject "Give a complete journey and ask for its average speed, with distance per time as the output unit."
        val body = trim (g masked m 1)
        fun getRate s r i = Q.MotionRate (rat (g s r i),M.require Q.Mlength (g s r (i+1)),M.require Q.Mtime (g s r (i+2)))
        fun firstUnit s r i = M.require Q.Mlength (g s r i)
        fun parseLeg s =
          case whole (optionalVerb ^ "(?:at\\s+)?" ^ rate ^ "\\s+for\\s+" ^ quantity) s of
            SOME r => (Q.RateDuration (getRate s r 1,rat (g s r 4),M.require Q.Mtime(g s r 5)),firstUnit s r 2)
          | NONE => (case whole (optionalVerb ^ quantity ^ "\\s+in\\s+" ^ quantity) s of
              SOME r => (Q.DistanceDuration (rat(g s r 1),firstUnit s r 2,rat(g s r 3),M.require Q.Mtime(g s r 4)),firstUnit s r 2)
            | NONE => (case whole (optionalVerb ^ quantity ^ "\\s+at\\s+" ^ rate) s of
                SOME r => (Q.DistanceRate(rat(g s r 1),firstUnit s r 2,getRate s r 3),firstUnit s r 2)
              | NONE => (case whole ("(?:stops?|waits?)\\s+for\\s+" ^ quantity) s of
                  SOME r => (Q.RateDuration(Q.MotionRate(Q.mk_rat 0 1,Q.U_meter,Q.U_hour),rat(g s r 1),M.require Q.Mtime(g s r 2)),Q.U_meter)
                | NONE => raise Reject "Each journey leg needs distance and time, speed and time, or distance and positive speed.")))
        fun splitLegs s =
          let val separators = matches "\\s*[,;]?\\s*(?:and\\s+)?then\\s+" s
              fun loop [] start acc = rev (trim(String.extract(s,start,NONE))::acc)
                | loop (r::rs) start acc = loop rs (#stop r) (trim(String.substring(s,start,#start r-start))::acc)
          in loop separators 0 [] end
        fun explicit () =
          let val parts = splitLegs body
              val _ = if length parts >= 2 andalso length parts <= 8 then () else
                raise Reject "Specify two to eight journey legs, or explicitly state equal times or equal distances."
              val legs = map parseLeg parts
          in (Q.ExplicitLegs(map #1 legs),#2(hd legs)) end
        val pairPattern = "(?:at\\s+)?" ^ rate ^ "\\s+and\\s+(?:at\\s+)?" ^ rate
        val equalTimeReading =
          case whole (pairPattern ^ "\\s+for\\s+equal\\s+(?:times|durations)") body of
            SOME r => SOME r
          | NONE => whole ("for\\s+equal\\s+(?:times|durations)\\s+at\\s+" ^ rate ^ "\\s+and\\s+(?:at\\s+)?" ^ rate) body
        val (journey,fallback) =
          case equalTimeReading of
            SOME r => (Q.EqualTimes(getRate body r 1,getRate body r 4),firstUnit body r 2)
          | NONE => (case whole ("(?:for\\s+)?equal\\s+distances\\s+at\\s+" ^ rate ^ "\\s+and\\s+(?:at\\s+)?" ^ rate) body of
              SOME r => (Q.EqualDistances(getRate body r 1,getRate body r 4),firstUnit body r 2)
            | NONE => (case whole (pairPattern ^ "\\s+for\\s+equal\\s+distances") body of
                SOME r => (Q.EqualDistances(getRate body r 1,getRate body r 4),firstUnit body r 2)
              | NONE => explicit ()))
        val (ou,ot) = if g masked m 2 = "" then (fallback,Q.U_hour)
          else (M.require Q.Mlength(g masked m 2),M.require Q.Mtime(g masked m 3))
      in SOME(journey,ou,ot) end
    end
end
