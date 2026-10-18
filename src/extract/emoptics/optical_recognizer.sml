(* UNTRUSTED optical measurement adapter. It retains supplied units,
   exact numeric tokens and original spans. It does not calculate conversions. *)
structure OpticalMeasurements =
struct
  fun unit alias tag dimension caseSensitive : MeasuredInput.unitSpec =
    {alias=alias,tag=tag,dimension=dimension,caseSensitive=caseSensitive}
  val units =
    map (fn (a,t) => unit a t "length" false)
      [("nanometers","nm"),("nanometres","nm"),("nm","nm"),
       ("micrometers","um"),("micrometres","um"),("um","um"),
       ("\194\181m","um"),("\206\188m","um"),("mm","mm"),("cm","cm"),
       ("metres","m"),("meters","m"),("m","m")] @
    map (fn (a,t) => unit a t "frequency" true)
      [("THz","THz"),("GHz","GHz"),("MHz","MHz"),("kHz","kHz"),
       ("mHz","mHz"),("Hz","Hz")] @
    map (fn a => unit a "degrees" "angle" false) ["degrees","degree","deg","\194\176"] @
    map (fn a => unit a "radians" "angle" false) ["radians","radian","rad"]
  fun scan s = MeasuredInput.scan units s
  fun supplied s = List.mapPartial (fn item =>
    case item of MeasuredInput.Measurement m =>
      (case #unitBinding m of MeasuredInput.Explicit {unit,...} =>
         SOME (#value m,#tag unit,#numberSpan m)
       | _ => NONE)
    | _ => NONE) (scan s)
  fun unsupported s = List.exists (fn item => case item of
      MeasuredInput.Malformed _ => true
    | MeasuredInput.Measurement {unitBinding=MeasuredInput.Unsupported _,...} => true
    | _ => false) (scan s)
end

(* UNTRUSTED role recognizer. No conversions or physical arithmetic; HOL consumes typed units and indices.
   Carries original exact measurements and source/target index roles forward.
   It constructs a request for the checked optical kernel. *)
structure OpticalWaveRoles =
struct
  structure M=MeasuredInput
  structure N=ExactNumeric
  type amount=N.rational * string
  datatype spectralInput = FrequencyInput of amount
    | FrequencyInInput of N.rational * amount
    | WavelengthInput of N.rational * amount
    | RedundantInput of N.rational * amount * amount
  datatype target = WantFrequency | WantWavelength | WantEnergy
  datatype result = NotWave | Missing of string
    | Wave of {input:spectralInput, target:target, targetIndex:N.rational}
  fun low s=String.map Char.toLower s
  fun search p s=Regex.search (Regex.compile p) s
  fun has p s=Option.isSome(search p s)
  fun word w s=has ("\\b"^w^"\\b") s
  fun pos ({start,...}:Regex.match)=start
  fun singleton [x]=SOME x | singleton _=NONE
  val media=[("vacuum",(1,1):N.rational),("air",(1000293,1000000)),
             ("water",(1333,1000)),("diamond",(2417,1000))]
  fun prefix s stop=String.substring(s,0,stop)
  fun tail s start=String.extract(s,start,NONE)
  fun afterIndex s start = has "\\b(?:index(?: of refraction)?|refractive index|n[12]?)\\s*(?:of|=|is)?\\s*$" (prefix (low s) start)
  fun parse s =
    let
      val q=low s
      val fields=OpticalMeasurements.scan s
      val malformed=OpticalMeasurements.unsupported s
      val ms=List.mapPartial(fn M.Measurement m=>SOME m|_=>NONE)fields
      fun dim d=List.mapPartial (fn m=>case #unitBinding m of
          M.Explicit {unit,...}=>if #dimension unit=d then SOME m else NONE
        | _=>NONE) ms
      fun amt m=case #unitBinding m of M.Explicit{unit,...}=>(#value m,#tag unit)
        | _=>raise Fail "typed source lost its unit"
      (* A parenthetical restatement names the same supplied measurement only
         when its exact value and unit tag agree. Other repetitions stay distinct. *)
      fun restated label fields = case fields of [a,b]=>
        (case #unitBinding b of M.Explicit{span,...}=>
          if amt a=amt b andalso
             has ("\\(\\s*"^label^"\\s*(?:of|=|is)?\\s*$") (prefix q (#start(#numberSpan b))) andalso
             has "^\\s*\\)" (tail q (#stop span))
          then [a] else fields
        | _=>fields)
        | _=>fields
      val ls=restated "wavelength" (dim "length")
      val fs=restated "frequency" (dim "frequency")
      val indices=List.filter(fn m=>afterIndex s (#start(#numberSpan m)))ms
      fun roleIndex role = singleton (List.filter (fn m=>
        has ("\\b"^role^"(?: medium)? (?:refractive )?index\\s*(?:of|=|is)?\\s*$")
          (prefix q (#start(#numberSpan m)))) indices)
      val sourceRole=roleIndex "source"
      val targetRole=roleIndex "target"
      val badIndex=List.exists(fn m=>case #unitBinding m of M.Bare=>false|_=>true)indices
      val names=List.filter(fn(name,_)=>word name q)media
      val targetStart=case search "\\b(?:what|find|calculate|determine|give)\\b" q of
           SOME m=>pos m|NONE=>size q
      val targetRx="\\b(?:energy|frequency|wavelength)\\b"
      val afterMeasurements=tail q (foldl(fn(m,n)=>Int.max(#stop(#numberSpan m),n))0 ms)
      val asks=if targetStart<size q then tail q targetStart
        else if has targetRx afterMeasurements then afterMeasurements else q
      val beforeAsk=prefix q targetStart
      val want=case search targetRx asks of NONE=>NONE | SOME m=>
        (case Regex.whole asks m of "energy"=>SOME WantEnergy
          | "frequency"=>SOME WantFrequency | "wavelength"=>SOME WantWavelength | _=>NONE)
      val sourceBefore=case ls of [m]=>prefix q (#start(#numberSpan m))|_=>beforeAsk
      val explicitVacuumSource=has "\\bvacuum[- ]wavelength\\s*(?:of|=|is)?\\s*$" sourceBefore orelse
         has "\\bwavelength\\b.*\\bin vacuum\\b" beforeAsk
      val explicitVacuumTarget=word "vacuum[- ]wavelength" asks orelse
         has "\\bwavelength\\b.*\\bin vacuum\\b" asks
      fun unknownLocation text = List.exists (fn m =>
        case Regex.group text m 1 of NONE=>false | SOME w=>
          not (List.exists(fn(name,_)=>name=w)media) andalso
          not (List.exists(fn u=>u=w)
             ["nm","nanometers","nanometres","um","micrometers","micrometres",
              "mm","cm","m","metres","meters","hz","khz","mhz","ghz","thz","joules","ev"]))
        (Regex.findall (Regex.compile "\\b(?:in|through|inside|within)\\s+(?:(?:a|an|the)\\s+)?([a-z]+)\\b") text)
      val unknownMedium=unknownLocation q orelse has "\\b(?:glass|medium|material|substance)\\b" q
      fun index ()=case indices of
          [m]=>SOME(#value m)
        | []=>if unknownMedium then NONE else (case names of [(_,n)]=>SOME n
               | []=>SOME(1,1)
               | _=>NONE)
        | _=>NONE
      fun finish target sourceIndex targetIndex = case (ls,fs) of
          ([],[f])=>Wave{input=(if null indices andalso null names then FrequencyInput(amt f) else FrequencyInInput(sourceIndex,amt f)),target=target,targetIndex=targetIndex}
        | ([l],[])=>Wave{input=WavelengthInput(sourceIndex,amt l),target=target,targetIndex=targetIndex}
        | ([l],[f])=>Wave{input=RedundantInput(sourceIndex,amt l,amt f),target=target,targetIndex=targetIndex}
        | _=>Missing "one source wavelength and/or frequency with explicit units required"
    in
      if not (has "\\b(?:light|photon|laser|wavelength)\\b" q) orelse
         has "\\b(?:lens|mirror|angle|sound)\\b" q then NotWave
      else if malformed orelse badIndex then Missing "malformed measurement or dimensioned index"
      else case want of NONE=>NotWave | SOME target=>
        if length indices>1 then
          (case (sourceRole,targetRole) of
            (SOME ns,SOME nt)=>if length indices<>2 then Missing "extra index fields"
              else if (explicitVacuumSource andalso #value ns<>(1,1)) orelse
                      (explicitVacuumTarget andalso #value nt<>(1,1))
                then Missing "vacuum and explicit medium index conflict"
              else finish target (#value ns) (#value nt)
          | _=>Missing "multiple indices need explicit source and target roles")
        else case (target,ls,fs) of
          (WantEnergy,[],[f])=>
          (* Energy from frequency needs no unspecified medium, but an explicit
             phase index remains a domain-bearing operand. *)
          if null indices andalso null names then finish target (1,1) (1,1)
          else (case index() of SOME n=>finish target n n
                | NONE=>Missing "source phase index is ambiguous")
        | _=>(case index() of NONE=>Missing "source/target phase index is missing or ambiguous"
          | SOME n=>
            if (Option.isSome sourceRole andalso explicitVacuumSource andalso n<>(1,1)) orelse
               (Option.isSome targetRole andalso explicitVacuumTarget andalso n<>(1,1))
              then Missing "vacuum and explicit medium index conflict"
            else if Option.isSome targetRole andalso not(null ls) andalso not explicitVacuumSource
              then Missing "a target index alone does not specify the source wavelength medium"
            else finish target (if explicitVacuumSource then (1,1) else n)
               (if explicitVacuumTarget then (1,1) else n))
    end
end

(* UNTRUSTED angle/medium recognizer. The typed frame is not converted
   here. All intermediate indices are retained; missing interface geometry is
   a separate result, never a first/last-index shortcut. *)
structure OpticalAngleRoles =
struct
  structure W=OpticalWaveRoles
  structure M=MeasuredInput
  type rational=ExactNumeric.rational
  datatype frame=Normal | Surface
  datatype angle=Degrees of frame * rational | Radians of frame * rational
  datatype result=NotRefraction | Missing of string
    | SingleInterface of angle * rational * rational
    | ParallelInterfaces of angle * rational list
    | UnorientedInterfaces of angle * rational list
  fun parse s =
    let
      val q=W.low s
      val ms=List.mapPartial(fn M.Measurement m=>SOME m|_=>NONE)(OpticalMeasurements.scan s)
      val angles=List.mapPartial(fn m=>case #unitBinding m of M.Explicit {unit,...}=>
        if #dimension unit="angle" then SOME(#value m,#tag unit) else NONE | _=>NONE)ms
      val nums=List.mapPartial(fn m=>if W.afterIndex s (#start(#numberSpan m)) then
        (case #unitBinding m of M.Bare=>SOME(#start(#numberSpan m),#value m)|_=>NONE) else NONE)ms
      val names=List.concat(map(fn(n,v)=>map(fn m=>(W.pos m,v))
        (Regex.findall(Regex.compile("\\b"^n^"\\b"))q))W.media)
      fun insert (x as (p,_),[])=[x]
        | insert (x as (p,_),(y as (q,_))::ys)=if p<=q then x::y::ys else y::insert(x,ys)
      val indices=foldl insert [] (nums@names)
      val fromPos=Option.map W.pos(W.search "\\b(?:from|leaves|leaving|exits?|out of)\\b" q)
      val from=case fromPos of SOME p=>(case List.filter(fn(i,_)=>i>p)indices of x::_=>SOME x|[]=>NONE) | NONE=>NONE
      val surface=W.has "\\b(?:to|with|from|relative to)\\s+(?:the\\s+)?surface\\b" q
      val normal=W.has "\\b(?:to|with|from|relative to)\\s+(?:the\\s+)?normal\\b" q
      val afterAngleAsk=case W.search "\\b(?:what|find|calculate|determine|give)\\b" q of
          SOME m=>if List.exists(fn measured=>case #unitBinding measured of
              M.Explicit{unit,span}=> #dimension unit="angle" andalso #stop span<W.pos m
              | _=>false)ms then W.tail q (W.pos m) else ""
        | NONE=>""
      val targetSurface=W.has "\\b(?:to|with|from|relative to)\\s+(?:the\\s+)?surface\\b" afterAngleAsk orelse
        W.has "\\b(?:(?:refraction|refracted) angle|angle of refraction)\\s+(?:to|with|from|relative to)\\s+(?:the\\s+)?surface\\b" q
      val reference=if surface then Surface else Normal
      fun ordered (x,y)=case from of SOME z=>if #1 z= #1 y then (#2 y,#2 x) else (#2 x,#2 y)
                    | NONE=>(#2 x,#2 y)
      (* Descriptions may restate the same boundary before an explicit from/to
         clause. Check both earlier roles; never discard intermediate media. *)
      fun restatedBoundary ()=case indices of [x,y,u,v]=>
        let val (ns,nt)=ordered(u,v)
            val beforeX=W.prefix q (#1 x)
            val beforeY=W.prefix q (#1 y)
            val between=String.substring(q,#1 x,#1 y - #1 x)
            val afterY=String.substring(q,#1 y,#1 u - #1 y)
            val forwardDescription=
              W.has "\\b(?:inside|in)\\s+(?:a\\s+)?(?:material|medium|glass)\\s+(?:of\\s+)?index\\s*$" beforeX andalso
              W.has "\\b(?:boundary|surface|interface)\\s+with\\s+index\\s*$" beforeY
            val reverseDescription=W.has "\\bon the far side\\b" between andalso
              W.has "\\bstarts in index\\s*$" beforeY
            val namedHeading=W.has "^[a-z]+\\s+to\\s+$" beforeY andalso
              W.has "^[a-z]+\\s*:" afterY
            val explicitLater=case fromPos of SOME p=>p>= #1 u orelse
              (p>= #1 y andalso p< #1 u)|NONE=>false
        in if explicitLater andalso
             (((forwardDescription orelse namedHeading) andalso #2 x=ns andalso #2 y=nt) orelse
              (reverseDescription andalso #2 x=nt andalso #2 y=ns))
           then SOME(ns,nt) else NONE end
        | _=>NONE
      fun result a=case indices of
        [x,y]=>let val (n1,n2)=ordered(x,y) in SingleInterface(a,n1,n2) end
      | _::_::_::_=>(case restatedBoundary() of SOME(n1,n2)=>SingleInterface(a,n1,n2)
          | NONE=>if W.has "\\bparallel (?:interfaces|boundaries|surfaces)\\b" q
                    then ParallelInterfaces(a,map #2 indices)
                    else UnorientedInterfaces(a,map #2 indices))
      | _=>Missing "both incident and transmitted indices required"
    in
      if not(W.has "\\b(?:refraction|refracts?|refracted|snell)\\b" q) then NotRefraction
      else if OpticalMeasurements.unsupported s then Missing "malformed source measurement"
      else if targetSurface then Missing "surface-relative output angle is not yet supported"
      else if surface andalso normal then Missing "conflicting angle reference directions"
      else case angles of
        [(v,"degrees")]=>result(Degrees(reference,v))
      | [(v,"radians")]=>result(Radians(reference,v))
      | _=>Missing "one explicit incident angle required"
    end
end

structure OpticalRecognizer =
struct
  structure E=Emoptics
  structure W=OpticalWaveRoles
  structure A=OpticalAngleRoles
  fun rat (n,d)=E.mk_rat n d
  fun lengthUnit u=case u of "nm"=>E.L_nm|"um"=>E.L_um|"mm"=>E.L_mm|"cm"=>E.L_cm|_=>E.L_m
  fun frequencyUnit u=case u of "mHz"=>E.F_mHz|"kHz"=>E.F_kHz|"MHz"=>E.F_MHz
    |"GHz"=>E.F_GHz|"THz"=>E.F_THz|_=>E.F_Hz
  fun len (v,u)=(rat v,lengthUnit u)
  fun freq (v,u)=(rat v,frequencyUnit u)
  fun input s=case s of W.FrequencyInput a=>E.optical_frequency_input(freq a)
    |W.FrequencyInInput(n,a)=>E.optical_source_frequency_input(rat n)(freq a)
    |W.WavelengthInput(n,a)=>E.optical_wavelength_input(rat n)(len a)
    |W.RedundantInput(n,a,b)=>E.optical_redundant_input(rat n)(len a)(freq b)
  fun target t=case t of W.WantFrequency=>E.OpticalFrequencyTarget
    |W.WantWavelength=>E.OpticalWavelengthTarget|W.WantEnergy=>E.OpticalEnergyTarget
  fun frame f=case f of A.Normal=>E.AngleToNormal|A.Surface=>E.AngleToSurface
  fun recognize text =
    if W.has "\\bcritical angle\\b|\\blens\\b|\\bmirror\\b" (W.low text) then NONE
    else case W.parse text of
      W.Wave{input=s,target=t,targetIndex=n}=>SOME(E.O_Wave(target t,rat n,input s))
    | W.Missing _=>SOME E.O_UnknownOptical
    | W.NotWave=>(case A.parse text of
        A.SingleInterface(A.Degrees(f,a),n1,n2)=>SOME(E.optical_snell(frame f)(rat a)(rat n1)(rat n2))
      | A.NotRefraction=>NONE
      | _=>SOME E.O_UnknownOptical)
end
