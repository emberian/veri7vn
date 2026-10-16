(* Internal native owner bridge. Public source IDs are never mint authority. *)
signature VERI7VN_NATIVE_RELATION_LANGUAGE_GATE =
sig
  type reading type declaration
  type inputs={utterance:Veri7vn_Native_Literals.input,
    utterance_owner:Veri7vn_Managed_Provenance.source_owner,declaration:declaration}
  datatype status=Unrecognized | Input_Budget | Readings of int list
  val bind_declaration: {parent:Veri7vn_Row_Instance.recipe,
    input:Veri7vn_Native_Literals.input,owner:Veri7vn_Managed_Provenance.source_owner} -> declaration
  val release_declaration: declaration -> unit
  type description={index:int,entity:Veri7vn_Native_Literals.slice,
    property_capture:Veri7vn_Native_Literals.slice option,entities:IntInf.int list,
    property:IntInf.int,reader_revision:IntInf.int list,label_revision:IntInf.int list,rule:IntInf.int}
  val inspect: inputs -> status
  val describe: inputs -> int -> description
  val declaration_bytes: cterm -> string
  val select: {utterance:Veri7vn_Native_Literals.input,
    utterance_owner:Veri7vn_Managed_Provenance.source_owner,
    declaration:declaration,index:int} -> reading
  val recipe: reading -> Veri7vn_Row_Instance.relation_recipe
  val capture: reading -> Veri7vn_Native_Literals.slice
  val derivation: reading -> thm
  val release: reading -> unit
end;
structure Veri7vn_Native_Relation_Language_Gate :> VERI7VN_NATIVE_RELATION_LANGUAGE_GATE =
struct
  structure L=Veri7vn_Native_Literals;
  structure P=Veri7vn_Managed_Provenance;
  structure RI=Veri7vn_Row_Instance;
  structure U=Veri7vn_Managed_Native_Unit;
  type declaration_payload={parent:RI.recipe,input:L.input,owner:P.source_owner,unit:U.token};
  datatype declaration=Declaration of declaration_payload option Synchronized.var;
  type inputs={utterance:L.input,utterance_owner:P.source_owner,declaration:declaration};
  datatype status=Unrecognized | Input_Budget | Readings of int list;
  type description={index:int,entity:L.slice,property_capture:L.slice option,
    entities:IntInf.int list,property:IntInf.int,reader_revision:IntInf.int list,
    label_revision:IntInf.int list,rule:IntInf.int};
  val ctxt= @{context};
  fun require b message=if b then () else error message;
  fun encode t=YXML.string_of_body(Term_XML.Encode.term_raw t);
  fun evaluate t=Timeout.apply (Time.fromSeconds 5)
    (Code_Simp.dynamic_conv ctxt) (Thm.cterm_of ctxt t);
  fun normal t=Thm.term_of(Thm.rhs_of(evaluate t));
  fun declaration_bytes ct=
    let val t=Thm.term_of ct;
      val _=require(fastype_of t= @{typ relation_language_declaration}) "Wrong relation declaration type";
      val _=require(null(Term.add_frees t []) andalso null(Term.add_vars t [])) "Open relation declaration";
    in encode(normal t) end;
  fun bind_declaration {parent,input,owner}=
    let val _=require(RI.recipe_is_live parent andalso P.owns_input owner input andalso L.retained input)
        "Declaration source owner unavailable";
      val unit=U.create{generation=RI.recipe_generation parent,inputs=[input],objects=[]}
        Veri7vn_Native_Registry.empty
    in Declaration(Synchronized.var "source_relation_declaration" (SOME
      {parent=parent,input=input,owner=owner,unit=unit})) end;
  fun declaration_view(Declaration cell)=
    let val p=the(Synchronized.value cell);
      val _=require(RI.recipe_is_live(#parent p) andalso P.owns_input (#owner p) (#input p) andalso
        L.retained(#input p) andalso is_some(U.inspect(#unit p))) "Declaration occurrence retired"
    in p end;
  fun release_declaration(Declaration cell)=
    let val old=Synchronized.change_result cell(fn p=>(p,NONE))
    in Option.app(fn p=>Option.app(fn view=>List.app(fn input=>
      if L.disposed input then Veri7vn_Native_Identity_Allocator.release_disposed_input input else ())
      (#inputs view)) (U.release(#unit p))) old end;
  type payload={utterance:L.input,utterance_owner:P.source_owner,
    declaration:declaration,
    query:RI.relation_recipe,capture:L.slice,proof:thm,leases:L.lease list};
  datatype reading=Reading of payload option Synchronized.var;
  fun live(Reading cell)=
    let val p=the(Synchronized.value cell);
      val _=require(P.owns_input (#utterance_owner p) (#utterance p) andalso
        L.retained(#utterance p) andalso
        List.all (is_some o try L.lease_input) (#leases p))
        "Relation language source owner unavailable";
      val _=declaration_view(#declaration p);
      val _=RI.relation_metadata(#query p);
    in p end;
  fun interpret ({utterance,utterance_owner,declaration}:inputs)=
    let val declared=declaration_view declaration;
      val declaration_input= #input declared;
      val declaration_owner= #owner declared;
      val _=require(not(L.same_input(utterance,declaration_input))) "Relation input roles require distinct occurrences";
      val _=require(P.owns_input utterance_owner utterance andalso
        P.owns_input declaration_owner declaration_input andalso
        P.source_workspace utterance_owner=P.source_workspace declaration_owner)
        "Relation language source owner mismatch";
      val raw=L.bytes utterance;
      val encoded=L.bytes declaration_input;
      val _=require(size raw<=256 andalso size encoded<=65536) "Relation language byte budget";
      val decl=Term_XML.Decode.term_raw(YXML.parse_body encoded);
      val _=require(declaration_bytes(Thm.cterm_of ctxt decl)=encoded) "Noncanonical relation declaration";
      val _=require(normal(@{term reader_revision}$decl)=normal(@{term fixed_relation_reader_revision}) andalso
        normal(@{term label_revision}$decl)<>HOLogic.mk_list HOLogic.natT [])
        "Relation declaration requires the fixed reader revision and a label revision";
      val bytes=HOLogic.mk_list HOLogic.natT
        (map (HOLogic.mk_number HOLogic.natT o Char.ord) (String.explode raw));
      val proof=evaluate(@{term interpret_relation_question}$decl$bytes);
      val alternatives=HOLogic.dest_list(Thm.term_of(Thm.rhs_of proof));
    in {raw=raw,proof=proof,alternatives=alternatives,declared=declared} end;
  fun inspect (inputs as {utterance,declaration,...}:inputs)=
    if size(L.bytes utterance)>256 orelse size(L.bytes(#input(declaration_view declaration)))>65536 then Input_Budget
    else case #alternatives(interpret inputs) of []=>Unrecognized
      | alternatives=>Readings(map_index(fn(i,_)=>i) alternatives);
  fun original_slice input raw sp =
    let val (start,stop)=HOLogic.dest_prod sp;
      val first=HOLogic.dest_nat start; val past=HOLogic.dest_nat stop
    in L.slice input {start=first,stop=past,expected=String.substring(raw,first,past-first)} end;
  fun describe (inputs as {utterance,...}:inputs) index =
    let val {raw,alternatives,...}=interpret inputs;
      val _=require(index>=0 andalso index<length alternatives) "Unresolved relation diagnostic";
      val selected=nth alternatives index;
      val request=normal(@{term question_request}$selected);
      val native=the(Veri7vn_Row_Kernel.decode_relation_requirement ctxt request);
      val (entities,property)=(case native of Veri7vn_Row_Code.SnapshotRelationQuery values=>values);
      val property_capture=(case normal(@{term property_capture}$selected) of
        Const(name,_)=>if name= @{const_name None} then NONE else error "Invalid property capture"
      | Const(name,_) $ sp=>if name= @{const_name Some} then SOME(original_slice utterance raw sp)
          else error "Invalid property capture"
      | _=>error "Invalid property capture");
      fun naturals field=map (IntInf.fromInt o HOLogic.dest_nat)
        (HOLogic.dest_list(normal(field$selected)))
    in {index=index,entity=original_slice utterance raw (normal(@{term entity_capture}$selected)),
      property_capture=property_capture,entities=map Veri7vn_Row_Kernel.nat_to_integer entities,
      property=Veri7vn_Row_Kernel.nat_to_integer property,
      reader_revision=naturals @{term question_reader_revision},
      label_revision=naturals @{term question_label_revision},
      rule=IntInf.fromInt(HOLogic.dest_nat(normal(@{term question_rule}$selected)))} end;
  fun select {utterance,utterance_owner,declaration,index}=
    let val {raw,proof,alternatives,declared}=interpret {utterance=utterance,
      utterance_owner=utterance_owner,declaration=declaration};
      val parent= #parent declared; val declaration_input= #input declared;
      val _=require(index>=0 andalso index<length alternatives) "Unresolved relation reading";
      val selected=nth alternatives index;
      val request=normal(@{term question_request}$selected);
      val query=RI.elaborate_relation parent (Thm.cterm_of ctxt request);
      val _=RI.restrict_relation_inputs query [(utterance,utterance_owner),(declaration_input,#owner declared)];
      val _=RI.restrict_relation_unit query (#unit declared);
      val _=require(Thm.term_of(RI.relation_metadata query)=request) "Relation recipe changed selected request";
      val (start,stop)=HOLogic.dest_prod(normal(@{term entity_capture}$selected));
      val first=HOLogic.dest_nat start; val past=HOLogic.dest_nat stop;
      val capture=L.slice utterance {start=first,stop=past,
        expected=String.substring(raw,first,past-first)};
      val utterance_lease=L.retain utterance;
      val declaration_lease=(L.retain declaration_input handle exn=>
        (Option.app Veri7vn_Native_Identity_Allocator.release_disposed_input
          (L.release utterance_lease);Exn.reraise exn));
    in Reading(Synchronized.var "owned_relation_language_reading" (SOME
      {utterance=utterance,utterance_owner=utterance_owner,declaration=declaration,query=query,capture=capture,proof=proof,leases=[utterance_lease,declaration_lease]})) end;
  fun recipe r= #query(live r);
  fun capture r= #capture(live r);
  fun derivation r= #proof(live r);
  fun release(Reading cell)=
    let val old=Synchronized.change_result cell (fn p=>(p,NONE))
    in Option.app (fn p=>(RI.release_relation(#query p);List.app (fn lease=>
      Option.app Veri7vn_Native_Identity_Allocator.release_disposed_input (L.release lease))
      (#leases p))) old end;
end;
