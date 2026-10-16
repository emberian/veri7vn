(* Fixed checked rendering bound to the actual domain request/output. A display
   is a native publication candidate, not permission to publish or a theorem of
   physical truth. Exact premise associations accompany the numeric sentence. *)
signature VERI7VN_DOMAIN_DISPLAY =
sig
  type bridge type display
  type condition_view = {identity:IntInf.int,owner_identity:IntInf.int,
    proposition:cterm,statement:string,source_span:int*int,
    role:Veri7vn_Domain_Conditions.role}
  type projection = {statement_html:string,conditions:condition_view list,model:bool}
  val attach: {allocator:Veri7vn_Native_Identity_Allocator.allocator,
    policy:Veri7vn_Native_Admission.policy,
    instance:Veri7vn_Domain_Execution.instance} -> bridge
  val contract: bridge -> Veri7vn_Native_Admission.accepted
  val dependencies: bridge -> IntInf.int list
  val live: bridge -> bool
  val matches: bridge -> Veri7vn_Domain_Execution.instance -> bool
  val prepare: bridge -> Veri7vn_Domain_Request.request ->
    Veri7vn_Domain_Execution.output -> string -> display
  val prepare_exact: bridge -> Veri7vn_Domain_Request.request ->
    Veri7vn_Domain_Execution.output -> display
  val request: display -> Veri7vn_Domain_Request.request
  val output: display -> Veri7vn_Domain_Execution.output
  val project: display -> projection
  val release: bridge -> unit

end;
structure Veri7vn_Domain_Display :> VERI7VN_DOMAIN_DISPLAY =
struct
  structure D=Veri7vn_Domain_Request;
  structure M=Veri7vn_Domain_Execution;
  structure C=Veri7vn_Domain_Conditions;
  structure A=Veri7vn_Native_Admission;
  structure R=Veri7vn_Native_Registry;
  structure E=Veri7vn_Executable_Identity;
  structure IDs=Veri7vn_Native_Identity_Allocator;
  structure L=Veri7vn_Native_Literals;
  structure B=Veri7vn_Bounded_Projection;
  val code_theory= @{theory};
  val pin=E.pin code_theory {artifact="veri7vn.fixed-domain-display/1",
    compiler="Isabelle code generator / PolyML",target="Eval (SML)",
    serializers=["bounded typed quantity grammar","bounded HTML bytes"],
    foreign_primitives=[],settings=["exact conditions retained separately"]};
  type condition_view={identity:IntInf.int,owner_identity:IntInf.int,
    proposition:cterm,statement:string,source_span:int*int,role:C.role};
  type projection={statement_html:string,conditions:condition_view list,model:bool};
  type bridge_data={instance:M.instance,implementation:A.accepted,contract:A.accepted};
  datatype bridge=Bridge of IntInf.int list * bridge_data option Synchronized.var;
  datatype display=Display of bridge * D.request * M.output * string;
  fun guard true _=() | guard false message=error message;
  fun get(Bridge(_,root))=(case Synchronized.value root of SOME data=>data
    | NONE=>error "Domain display bridge released");
  fun contract bridge= #contract(get bridge);
  fun dependencies(bridge as Bridge(ids,_))=(ignore(get bridge);ids);
  fun live bridge=(let val{instance,implementation,contract}=get bridge
    in M.same_instance(instance,instance) andalso
      Thm.eq_thm(A.theorem implementation,A.theorem(M.contract instance)) andalso
      R.same_generation(A.generation contract,A.generation implementation) andalso
      E.exact_code_context pin code_theory end)handle ERROR _=>false;
  fun matches bridge instance=live bridge andalso M.same_instance(#instance(get bridge),instance);
  fun release(Bridge(_,root))=Synchronized.change root(K NONE);
  fun attach {allocator,policy,instance}=
    let val implementation=M.contract instance;
      val generation=A.generation implementation;
      val semantic=(case IDs.lookup_generation_id allocator generation of SOME id=>id
        | NONE=>error "Domain display requires actual registered generation");
      val th= @{thm fixed_domain_display_contract_checked};
      val target=Thm.cterm_of(R.context generation)(Thm.prop_of th);
      val(handle_id,registry)=R.insert generation "domain.fixed-display"(R.Theorem th)R.empty;
      val accepted=(case A.admit policy generation registry handle_id A.Kernel
        {claim=A.exact_claim target,hypotheses=[],premises=[],sorts=Thm.shyps_of th} of
          A.Accepted value=>value | A.Rejected reasons=>error(cat_lines reasons));
      val _=guard(null(Thm.hyps_of(A.theorem accepted)) andalso
        Thm.nprems_of(A.theorem accepted)=0 andalso null(A.observed_oracles accepted))
        "Unconditional fixed domain display contract required";
      val bridge=Bridge([IDs.allocate allocator,IDs.allocate allocator,semantic],
        Synchronized.var "veri7vn_domain_display_bridge"
          (SOME{instance=instance,implementation=implementation,contract=accepted}));
    in guard(live bridge)"Domain display instance unavailable";bridge end;
  val nat= Veri7vn_Numerals.nat_of_integer;
  val integer= Veri7vn_Numerals.integer_of_nat;
  val packet= @{code domain_display_packet};
  val reflect= @{code "Code_Evaluation.term_of :: domain_value => Code_Evaluation.term"};
  fun bytes cap values=
    (guard(length values<=cap)"Domain display output byte bound";
     String.implode(map(fn n=>let val k=integer n
       in guard(0<=k andalso k<256)"Domain display nonbyte output";
          Char.chr(IntInf.toInt k)end)values));
  fun request(Display(_,r,_,_))=r;
  fun output(Display(_,_,out,_))=out;
  fun project(Display(bridge,r,out,sentence))=
    let
      val _=guard(matches bridge(D.instance r))"Domain display belongs to another instance";
      val _=guard(size sentence<=16384)"Domain display input byte bound";
      val (native,ids)=(case D.result_view r out of D.Answer{value,conditions}=>(value,conditions)
        | _=>error "A refused or blocked domain result is not a numeric display");
      val associations=D.condition_associations r;
      val actual_ids=map(IntInf.fromInt o HOLogic.dest_nat)(HOLogic.dest_list(Thm.term_of ids));
      val _=guard(actual_ids=map C.identity associations)"Domain display condition association changed";
      val model=exists(fn c=>C.role c=C.IdealSpringModel)associations;
      val input=map(nat o IntInf.fromInt o Char.ord)(String.explode sentence);
      val(value,count,display_model,html)=(case Timeout.apply(Time.fromSeconds 5)packet input of SOME p=>p
        | NONE=>error "Domain sentence rejected by fixed checker");
      val reflected=Timeout.apply(Time.fromSeconds 5)(fn()=>
        (B.preflight 20000(fn()=>reflect value);B.materialize 20000(fn()=>reflect value)))();
      val _=guard(reflected aconv Thm.term_of native andalso
        integer count=IntInf.fromInt(length associations) andalso display_model=model)
        "Domain sentence differs from actual typed result/qualifiers";
      fun condition c=let val{start,stop}=L.offsets(C.source_slice c)
        in {identity=C.identity c,owner_identity=C.owner_identity c,
          proposition=C.proposition c,statement=L.original(C.source_slice c),
          source_span=(start,stop),role=C.role c}:condition_view end;
      val conditions=map condition associations;
      val statement_html=bytes 65536 html;
      val _=ignore(D.specialize r out);
      val _=guard(matches bridge(D.instance r))"Domain display revoked during projection";
    in {statement_html=statement_html,conditions=conditions,model=model}:projection end;
  fun prepare bridge r out sentence=
    let val display=Display(bridge,r,out,sentence);val _=project display in display end;
  (* Proposal formatting has no semantic authority: prepare checks its entire
     typed value and qualifiers through the fixed generated decoder. *)
  val unit_labels=[(@{const_name Metre},"m"),
    (@{const_name Kilometre},"km"),
    (@{const_name Centimetre},"cm"),
    (@{const_name Millimetre},"mm"),
    (@{const_name Inch},"in"),
    (@{const_name Foot},"ft"),
    (@{const_name Yard},"yd"),
    (@{const_name Mile},"mi"),
    (@{const_name NauticalMile},"nmi"),
    (@{const_name Kilogram},"kg"),
    (@{const_name Gram},"g"),
    (@{const_name Milligram},"mg"),
    (@{const_name Pound},"lb"),
    (@{const_name Ounce},"oz"),
    (@{const_name Tonne},"t"),
    (@{const_name Stone},"stone"),
    (@{const_name Litre},"L"),
    (@{const_name Millilitre},"mL"),
    (@{const_name GallonUS},"US-gal"),
    (@{const_name QuartUS},"US-qt"),
    (@{const_name PintUS},"US-pt"),
    (@{const_name CupUS},"US-cup"),
    (@{const_name FluidOunceUS},"US-floz"),
    (@{const_name CubicMetre},"m^3"),
    (@{const_name SquareMetre},"m^2"),
    (@{const_name SquareFoot},"ft^2"),
    (@{const_name Acre},"acre"),
    (@{const_name Hectare},"ha"),
    (@{const_name SquareKilometre},"km^2"),
    (@{const_name SquareMile},"mi^2"),
    (@{const_name MetrePerSecond},"m/s"),
    (@{const_name KilometrePerHour},"km/h"),
    (@{const_name MilePerHour},"mph"),
    (@{const_name Knot},"kn"),
    (@{const_name Second},"s"),
    (@{const_name Minute},"min"),
    (@{const_name Hour},"h"),
    (@{const_name Day},"d"),
    (@{const_name Week},"week"),
    (@{const_name Pascal},"Pa"),
    (@{const_name Kilopascal},"kPa"),
    (@{const_name Bar},"bar"),
    (@{const_name Atmosphere},"atm"),
    (@{const_name Psi},"psi"),
    (@{const_name MmHg},"mmHg-conventional"),
    (@{const_name Joule},"J"),
    (@{const_name Kilojoule},"kJ"),
    (@{const_name Calorie},"cal-thermochemical"),
    (@{const_name Kilocalorie},"kcal-thermochemical"),
    (@{const_name KilowattHour},"kWh"),
    (@{const_name Btu},"BTU"),
    (@{const_name Watt},"W"),
    (@{const_name Kilowatt},"kW"),
    (@{const_name Horsepower},"hp-mechanical"),
    (@{const_name Byte},"B"),
    (@{const_name Kilobyte},"kB"),
    (@{const_name Megabyte},"MB"),
    (@{const_name Gigabyte},"GB"),
    (@{const_name Terabyte},"TB"),
    (@{const_name Kibibyte},"KiB"),
    (@{const_name Mebibyte},"MiB"),
    (@{const_name Gibibyte},"GiB"),
    (@{const_name Newton},"N"),
    (@{const_name NewtonPerMetre},"N/m"),
    (@{const_name Kelvin},"K"),
    (@{const_name Celsius},"degC"),
    (@{const_name Fahrenheit},"degF")];
  fun label(Const(name,_))=(case AList.lookup(op =)unit_labels name of
    SOME value=>value | NONE=>error "Unknown native domain display unit")
    | label _=error "Noncanonical native domain unit";
  fun numeral(Const(name,_))=if name= @{const_name Num.One}then (1:IntInf.int)
        else error "Noncanonical native numeral"
    | numeral(Const(name,_) $ n)=if name= @{const_name Num.Bit0}then 2*numeral n
        else if name= @{const_name Num.Bit1}then 2*numeral n+1
        else error "Noncanonical native numeral"
    | numeral _=error "Noncanonical native numeral";
  fun number(Const(name,_))=if name= @{const_name zero_class.zero}then (0:IntInf.int)
        else if name= @{const_name one_class.one}then 1 else error "Noncanonical native number"
    | number(Const(name,_) $ n)=if name= @{const_name Num.numeral}then numeral n
        else if name= @{const_name uminus_class.uminus}then ~ (number n)
        else error "Noncanonical native number"
    | number _=error "Noncanonical native number";
  fun fraction t=(case strip_comb t of
      (Const(name,_),[pair])=>if name= @{const_name Rat.Frct}
        then let val(n,d)=HOLogic.dest_prod pair in(number n,number d)end
        else (number t,1)
    | (Const(name,_),[n,d])=>if name= @{const_name Fract}then(number n,number d)
        else(number t,1)
    | _=>(number t,1));
  fun decimal n=let val text=if n<0 then "-" ^ IntInf.toString(~n)else IntInf.toString n
    in guard(size text<=513)"Domain display numeral digit bound";text end;
  fun prepare_exact bridge r out=
    let val value=(case D.result_view r out of D.Answer{value,...}=>Thm.term_of value
          | _=>error "A refused or blocked result has no exact numeric sentence");
      val(carrier,unit,q)=(case strip_comb value of (Const(name,_),[unit,q])=>
        (if name= @{const_name LinearValue}then "quantity"
         else if name= @{const_name PointValue}then "temperature-point"
         else if name= @{const_name DeltaValue}then "temperature-difference"
         else error "Unknown native domain value",unit,q)
        | _=>error "Noncanonical native domain value");
      val(n,d)=fraction q;
      val _=guard(d>0)"Native rational denominator must be positive";
      val conditions=D.condition_associations r;
      val model=exists(fn c=>C.role c=C.IdealSpringModel)conditions;
      val header=if null conditions then ""else "Conditional on all " ^
        Int.toString(length conditions) ^ " attached premises: ";
      val sentence=header ^ "Exact " ^ carrier ^ " " ^ decimal n ^ "/" ^ decimal d ^ " " ^ label unit ^
        (if model then " under the adopted ideal spring response model"else "");
    in prepare bridge r out sentence end;
end;
