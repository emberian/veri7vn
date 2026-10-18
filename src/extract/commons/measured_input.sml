(* UNTRUSTED measurement adapter: preserves original byte spans and units.
   No conversions or physical laws occur here. A consumer supplies its unit
   vocabulary and grammatical quantity roles; exported HOL code converts values.
   Scan only attaches known units. Unknown words after separated numbers remain
   Bare: consumers must consume/check the whole grammatical field, not assume
   absence of a recognized unit means absence of a supplied condition.
   requestedOutput is deliberately a separate type and cannot supply inheritance. *)
structure MeasuredInput :>
sig
  type span = {start:int, stop:int}
  type unitSpec = {alias:string, tag:string, dimension:string, caseSensitive:bool}
  datatype unitBinding = Bare | Explicit of {unit:unitSpec, span:span}
                       | Unsupported of span
  type measurement = {id:int, numberSpan:span, value:ExactNumeric.rational,
                      unitBinding:unitBinding}
  datatype item = Measurement of measurement | Malformed of {span:span, reason:string}
  type sourceUnit
  datatype requestedOutput = RequestedOutput of {unit:unitSpec, span:span}
  datatype origin = Supplied of span | Inherited
  datatype binding = Bound of {measurement:measurement, unit:unitSpec, origin:origin}
                   | MissingUnit | UnsupportedUnit of span
                   | WrongDimension of {expected:string, actual:string}
  val unitAt : unitSpec list -> string -> int -> unitBinding option
  val scan : unitSpec list -> string -> item list
  val sourceUnit : measurement -> sourceUnit option
  val agreeSource : measurement list -> sourceUnit option
  val bind : {expected:string, inheritFrom:sourceUnit option} -> measurement -> binding
  val requested : unitSpec list -> string -> span -> requestedOutput option
end =
struct
  type span = {start:int, stop:int}
  type unitSpec = {alias:string, tag:string, dimension:string, caseSensitive:bool}
  datatype unitBinding = Bare | Explicit of {unit:unitSpec, span:span}
                       | Unsupported of span
  type measurement = {id:int, numberSpan:span, value:ExactNumeric.rational,
                      unitBinding:unitBinding}
  datatype item = Measurement of measurement | Malformed of {span:span, reason:string}
  datatype sourceUnit = SourceUnit of unitSpec
  datatype requestedOutput = RequestedOutput of {unit:unitSpec, span:span}
  datatype origin = Supplied of span | Inherited
  datatype binding = Bound of {measurement:measurement, unit:unitSpec, origin:origin}
                   | MissingUnit | UnsupportedUnit of span
                   | WrongDimension of {expected:string, actual:string}
  fun space c = Char.isSpace c
  fun skip s i = if i < size s andalso space(String.sub(s,i)) then skip s (i+1) else i
  fun lower s = String.map Char.toLower s
  fun word c = Char.isAlphaNum c orelse c = #"_" orelse Char.ord c >= 128
  fun starts s i t = i >= 0 andalso i+size t <= size s andalso
                     String.substring(s,i,size t)=t
  (* Whitespace in an alias denotes one or more spaces. Spellings are consumer
     data; optional spacing around slash is handled without changing spans. *)
  fun matchAlias s start ({alias,caseSensitive,...}:unitSpec) =
    let val text = if caseSensitive then s else lower s
        val a = if caseSensitive then alias else lower alias
        fun go i j =
          if j=size a then SOME i
          else if space(String.sub(a,j)) then
            if i<size s andalso space(String.sub(s,i)) then go(skip s i)(skip a j)
            else NONE
          else if String.sub(a,j) = #"/" then
            let val k=skip s i in
              if k<size text andalso String.sub(text,k) = #"/"
              then go(skip s (k+1))(j+1) else NONE end
          else if i<size text andalso String.sub(text,i)=String.sub(a,j)
               then go(i+1)(j+1) else NONE
    in go start 0 end
  fun suffixEnd s i =
    let fun go j = if j>=size s orelse List.exists(fn c=>String.sub(s,j)=c)
                      [#",",#";",#"?",#"!",#")",#"("] then j
                  else if space(String.sub(s,j)) then j else go(j+1)
    in go i end
  fun continuation table s i =
    let val j=skip s i
        fun knownAt k = List.exists (fn u => case matchAlias s k u of
              SOME b => b>k andalso (b=size s orelse not(word(String.sub(s,b))))
            | NONE => false) table
        val dottedUnit = j<size s andalso String.sub(s,j) = #"." andalso
          ((j+1<size s andalso Char.isAlpha(String.sub(s,j+1))) orelse knownAt(skip s (j+1)))
        val joinedUnit = dottedUnit orelse (j>i andalso knownAt j) orelse
          (j<size s andalso String.sub(s,j) = #"-" andalso
            let val k=skip s (j+1) in k<size s andalso
              (Char.isAlpha(String.sub(s,k)) orelse Char.ord(String.sub(s,k)) >= 128) end)
        fun whole t = starts (lower s) j t andalso
                      (j+size t=size s orelse not(word(String.sub(s,j+size t))))
    in joinedUnit orelse i<size s andalso word(String.sub(s,i)) orelse
       j<size s andalso (List.exists(fn c=>String.sub(s,j)=c)[#"/",#"^",#"*"]
                         orelse starts s j "\194\183" orelse starts s j "\195\151"
                         orelse starts s j "\226\139\133" orelse starts s j "\226\136\153"
                         orelse starts s j "\194\178" orelse starts s j "\194\179"
                         orelse whole "per" orelse whole "squared" orelse whole "cubed")
    end
  fun unitAt table s start =
    if start < 0 orelse start > size s then NONE else
    let val a=skip s start
        val matches=List.mapPartial(fn u=>case matchAlias s a u of
                   NONE=>NONE | SOME b=>if b<size s andalso
                     (Char.isAlpha(String.sub(s,b)) orelse String.sub(s,b) = #"_")
                     then NONE else SOME(u,b)) table
        fun better ((u,b),NONE)=SOME(u,b)
          | better ((u,b),SOME(v,c))=if b>c then SOME(u,b) else SOME(v,c)
    in case List.foldl better NONE matches of
         NONE=>NONE
       | SOME(u,b)=>if continuation table s b
          then SOME(Unsupported{start=a,stop=suffixEnd s (skip s b)})
          else SOME(Explicit{unit=u,span={start=a,stop=b}})
    end
  fun scan table s =
    let fun one (ExactNumeric.Malformed{start,stop,reason},i) =
              (Malformed{span={start=start,stop=stop},reason=reason},i+1)
          | one (ExactNumeric.Number{start,stop,value},i) =
              (Measurement{id=i,numberSpan={start=start,stop=stop},value=value,
                unitBinding=case unitAt table s stop of SOME u=>u | NONE=>
                  if stop<size s andalso
                    (word(String.sub(s,stop)) orelse String.sub(s,stop) = #"/")
                  then Unsupported{start=stop,stop=suffixEnd s stop} else Bare},i+1)
        fun go [] _ = []
          | go (t::ts) i = let val(x,j)=one(t,i) in x::go ts j end
    in go (ExactNumeric.scan s) 0 end
  (* Source units are extracted only from measured inputs, never requested output. *)
  fun sourceUnit ({unitBinding=Explicit{unit,...},...}:measurement) = SOME(SourceUnit unit)
    | sourceUnit _ = NONE
  fun agreeSource ms =
    let val us=List.mapPartial sourceUnit ms
        fun same(SourceUnit a,SourceUnit b)= #tag a = #tag b andalso #dimension a = #dimension b
    in case us of []=>NONE | u::rest=>if List.all(fn v=>same(u,v))rest then SOME u else NONE end
  fun bind {expected,inheritFrom} (m:measurement) =
    let fun check u origin = if #dimension u = expected
          then Bound{measurement=m,unit=u,origin=origin}
          else WrongDimension{expected=expected,actual= #dimension u}
    in case #unitBinding m of
         Explicit{unit,span}=>check unit (Supplied span)
       | Unsupported span=>UnsupportedUnit span
       | Bare=>(case inheritFrom of SOME(SourceUnit u)=>check u Inherited | NONE=>MissingUnit)
    end
  (* The grammar, not this lexical helper, determines the exact output-unit span. *)
  fun requested table s ({start,stop}:span) =
    if start < 0 orelse stop < start orelse stop > size s then NONE else
    case unitAt table s start of
      SOME(Explicit{unit,span={stop=b,...}})=>
        if b<=stop andalso List.all space (String.explode(String.substring(s,b,stop-b)))
        then SOME(RequestedOutput{unit=unit,span={start=skip s start,stop=b}}) else NONE
    | _=>NONE
end
