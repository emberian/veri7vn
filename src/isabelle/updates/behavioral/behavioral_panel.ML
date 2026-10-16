(* Fixed panel wire: one row per line, final newline mandatory.
     exact<TAB>numerator<TAB>positive denominator<TAB>original bindings term
     decline<TAB>-<TAB>-<TAB>original bindings term
     unknown<TAB>-<TAB>-<TAB>original bindings term
   Bindings are original UTF-8 subspans, not pretty-printed term replacements. *)
signature VERI7VN_BEHAVIORAL_BINDINGS =
sig
  type bindings
  val parse: Veri7vn_Managed_Provenance.source_owner * Veri7vn_Native_Literals.slice -> bindings
  val live: bindings -> bool
  val release: bindings -> unit
end;

functor Veri7vn_Behavioral_Panel(Bindings:VERI7VN_BEHAVIORAL_BINDINGS) :>
sig
  type panel
  type row={index:int,expected:Veri7vn_Behavioral_Metrics.expectation,bindings:Bindings.bindings}
  val parse: Veri7vn_Managed_Provenance.source_owner * Veri7vn_Native_Literals.slice -> panel
  val rows: panel -> row list
  val source: panel -> Veri7vn_Managed_Provenance.source_owner
  val original: panel -> string
  val dependencies: panel -> IntInf.int list
  val live: panel -> bool
  val release: panel -> unit
end =
struct
  structure P=Veri7vn_Managed_Provenance;
  structure L=Veri7vn_Native_Literals;
  structure I=Veri7vn_Native_Identity_Allocator;
  structure V=Veri7vn_Behavioral_Metrics;
  type row={index:int,expected:V.expectation,bindings:Bindings.bindings};
  type payload={source:P.source_owner,slice:L.slice,lease:L.lease,rows:row list};
  datatype panel=Panel of payload option Synchronized.var;
  val require=V.require;
  fun get(Panel cell)=case Synchronized.value cell of SOME p=>p | NONE=>error "Behavioral panel released";
  fun live panel=(let val{source,slice,lease,rows}=get panel
    in ignore(L.lease_input lease);P.owns_input source(L.owner slice) andalso
      L.retained(L.owner slice) andalso forall(Bindings.live o #bindings)rows end)
    handle ERROR _=>false;
  fun checked panel=(require(live panel)"Behavioral panel unavailable";get panel);
  fun rows panel= #rows(checked panel);
  fun source panel= #source(checked panel);
  fun original panel=L.original(#slice(checked panel));
  fun dependencies panel=[P.source_identity(source panel)];
  fun release(Panel cell)=Thread_Attributes.uninterruptible_body(fn _=>
    Synchronized.change cell(fn NONE=>NONE
    | SOME{lease,rows,...}=>(List.app(Bindings.release o #bindings)rows;
        Option.app I.release_disposed_input(L.release lease);NONE)));
  fun integer text=
    let val _=require(size text>0 andalso size text<=2048)"Behavioral expectation integer bound";
      val value=case IntInf.fromString text of SOME n=>n | NONE=>error "Behavioral expectation integer";
      val printed=IntInf.toString value;
      val canonical=if String.isPrefix "~" printed then "-"^String.extract(printed,1,NONE)else printed;
      val _=require(canonical=text)"Noncanonical behavioral expectation integer";
    in value end;
  fun parse(source,slice)=
    let
      val _=require(P.owns_input source(L.owner slice) andalso L.retained(L.owner slice))
        "Behavioral panel source ownership";
      val text=L.original slice;
      val _=require(L.encoding(L.owner slice)="UTF-8" andalso size text>0 andalso
        size text<=65536 andalso String.sub(text,size text-1)= #"\n")"Behavioral panel byte framing";
      val lines=String.fields(fn c=>c= #"\n")text;
      val lines=take(length lines-1)lines;
      val _=require(not(null lines) andalso length lines<=32)"Behavioral panel row bound";
      val lease=L.retain(L.owner slice);
      val allocated=Unsynchronized.ref([]:Bindings.bindings list);
      val{start=base,...}=L.offsets slice;
      fun line(index,(offset,rows)) raw=
        let
          val fields=String.fields(fn c=>c= #"\t")raw;
          val(tag,n,d,bindings)=case fields of [a,b,c,e]=>(a,b,c,e)
            | _=>error "Behavioral panel row requires four fields";
          val expected=case(tag,n,d)of
              ("exact",_,_)=>let val pair=(integer n,integer d)
                in require(V.rational pair)"Behavioral expectation rational";V.Expected_Rational pair end
            | ("decline","-","-")=>V.Must_Decline
            | ("unknown","-","-")=>V.Unknown
            | _=>error "Behavioral expectation tag";
          val _=require(size bindings>0 andalso size bindings<=16384)"Behavioral bindings byte bound";
          val start=base+offset+size tag+size n+size d+3;
          val span=L.slice(L.owner slice){start=start,stop=start+size bindings,expected=bindings};
          val parsed=Thread_Attributes.uninterruptible(fn restore=>fn()=>
            let val parsed=restore Bindings.parse(source,span)
              val _=allocated:=parsed::(!allocated)
            in parsed end)();
        in (offset+size raw+1,{index=index,expected=expected,bindings=parsed}::rows)end;
      fun loop _ state []=state
        | loop index state(raw::rest)=loop(index+1)(line(index,state)raw)rest;
      val attempted=Exn.capture(fn()=>
        let val(_,rows)=loop 0 (0,[])lines
        in Panel(Synchronized.var "behavioral_panel"(SOME{source=source,slice=slice,
          lease=lease,rows=rev rows}))end)();
    in case attempted of Exn.Res panel=>panel | Exn.Exn exn=>
      (List.app Bindings.release(!allocated);
       Option.app I.release_disposed_input(L.release lease);Exn.reraise exn)end;
end;
