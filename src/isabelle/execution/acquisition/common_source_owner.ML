(* Fixed private source owner. Instantiate with the FINAL assembly's consume-only
   tickets. Source associations never enter through an argument or raw accessor. *)
functor Veri7vn_Common_Source_Fn(Tickets:VERI7VN_OPERATION_TICKET_VIEW) :>
sig
  include VERI7VN_COMMON_SOURCE_OWNER
  val attach:acquisition_payload Tickets.acquisition_ticket->snapshot
  val attach_into:acquisition_payload Tickets.acquisition_ticket->snapshot option Unsynchronized.ref->snapshot
end =
struct
  structure K=Veri7vn_Source_Acquisition_Kernel;
  structure C=Veri7vn_Source_Acquisition_Code;
  structure L=Veri7vn_Native_Literals;
  structure P=Veri7vn_Managed_Provenance;
  structure R=Veri7vn_Native_Registry;
  structure A=Veri7vn_Native_Admission;
  structure I=Veri7vn_Native_Identity_Allocator;
  structure U=Veri7vn_Managed_Native_Unit;
  structure S=Veri7vn_Native_Request_Scope;
  structure N=Veri7vn_Native_Descriptor;
  type limits={input_bytes:int,rows:int,metadata_bytes:int,seconds:int};
  type declaration_payload={development:P.development,owner:P.source_owner,source:L.slice,limits:limits};
  datatype declaration=Declaration of {key:serial,root:decl_payload option Synchronized.var}
  withtype decl_payload={development:P.development,owner:P.source_owner,
    source:L.slice,unit:U.token,native:cterm,settings:K.settings,limits:limits};
  datatype reservation=Reservation of {root:reserve_payload option Synchronized.var,started:bool Synchronized.var}
  withtype reserve_payload={declaration:declaration,child:S.child,allocator:I.allocator,
    target:IntInf.int,attempt:IntInf.int,binding:IntInf.int,semantic_generation:IntInf.int};
  type acquired={declaration:declaration,child:S.child,generation:R.generation,
    native:cterm,observation:cterm,observation_projection:thm,meaning:thm,ownership:thm,qualification:A.accepted,carrier:K.association,unit:U.token,
    receipt:Tickets.acquisition_identity,dependencies:IntInf.int list};
  datatype snapshot=Snapshot of {key:serial,root:acquired option Synchronized.var};
  datatype input_witness=Witness of {key:serial,root:acquired option Synchronized.var};
  type acquisition_payload={executable:Veri7vn_Executable_Identity.pin,reservation:reservation,input:L.input,
    manifest_input:L.input,source_owner:P.source_owner,manifest_owner:P.source_owner};
  fun require true _=() | require false text=error text;
  fun policy_limits({input_bytes,rows,metadata_bytes,seconds}:limits)=
    input_bytes>0 andalso input_bytes<=1048576 andalso rows>0 andalso rows<=65536 andalso
    metadata_bytes>0 andalso metadata_bytes<=100000 andalso seconds>0 andalso seconds<=5;
  fun declaration_view(Declaration{root,...})=(case Synchronized.value root of
    NONE=>error "Source declaration retired" | SOME p=>
      (require(P.development_live(#development p) andalso
        P.owns_input(#owner p)(L.owner(#source p)) andalso L.retained(L.owner(#source p)) andalso
        is_some(U.inspect(#unit p))) "Source declaration owner unavailable";p));
  fun declaration_live d=is_some(try declaration_view d);
  fun canonical ct=YXML.string_of_body(Term_XML.Encode.term_raw(Thm.term_of ct));
  fun declare_into {development,owner,source,limits:limits} cleanup=
    let val _=require(policy_limits limits) "Source acquisition profile bounds";
      val generation=P.generation development;
      val ctxt=R.context generation;
      val original=L.original source;
      val _=require(Context.subthy(K.theory,Proof_Context.theory_of ctxt)) "Source kernel absent from receiver generation";
      val _=require(P.development_live development andalso
        P.development_workspace development=P.source_workspace owner andalso
        P.owns_input owner(L.owner source) andalso size original<= #metadata_bytes limits)
        "Source settings original owner/bound";
      val t=Term_XML.Decode.term_raw(YXML.parse_body original);
      val _=require(fastype_of t= @{typ source_acquisition_settings} andalso
        null(Term.add_frees t []) andalso null(Term.add_vars t [])) "Closed source settings type";
      val native=Thm.cterm_of ctxt t;
      val _=require(canonical native=original) "Source settings canonical original bytes";
      val settings=the(K.decode_settings ctxt t);
      val _=require(K.integer_of_nat(C.settings_format_version settings)=1) "Unsupported source settings version";
      val byte_limit=C.settings_byte_limit settings;
      val row_limit=C.settings_row_limit settings;
      val _=require(byte_limit>0 andalso byte_limit<=IntInf.fromInt(#input_bytes limits) andalso
        row_limit>0 andalso row_limit<=IntInf.fromInt(#rows limits)) "Source settings exceed profile";
    in Thread_Attributes.uninterruptible_body(fn _=>let
      val token=U.create{generation=generation,inputs=[L.owner source],objects=[]}R.empty;
      val made=Exn.capture(fn()=>Declaration{key=serial(),root=Synchronized.var "source_declaration"(SOME
        {development=development,owner=owner,source=source,unit=token,native=native,
         settings=settings,limits=limits})})();
    in case made of Exn.Res declaration=>(cleanup:=SOME declaration;declaration)
      | Exn.Exn failure=>(ignore(U.release token);Exn.reraise failure) end) end;
  fun declare args=declare_into args(Unsynchronized.ref NONE);
  fun retire_declaration(Declaration{root,...})=Thread_Attributes.uninterruptible_body(fn _=>
    Option.app(fn{unit,...}:decl_payload=>ignore(U.release unit))
      (Synchronized.change_result root(fn p=>(p,NONE))));
  fun reserve_into {declaration,child} cleanup=Thread_Attributes.uninterruptible_body(fn _=>
    let val d=declaration_view declaration;
      val parent=S.parent child;
      val allocator=S.allocator parent;
      val _=require(S.child_live child andalso
        I.workspace allocator=P.development_workspace(#development d)) "Source child owner mismatch";
      val _=require(L.same_input(L.owner(S.source child),L.owner(#source d)) andalso
        L.offsets(S.source child)=L.offsets(#source d)) "Source child original settings span mismatch";
      val held_child=S.retain_child child;
      val result=Exn.capture(fn()=>
        let val p={declaration=declaration,child=held_child,allocator=allocator,
          target=I.allocate allocator,attempt=I.allocate allocator,binding=I.allocate allocator,
          semantic_generation=N.semantic_generation_id allocator(P.generation(#development d))};
          val _=S.claim held_child
        in Reservation{root=Synchronized.var "source_acquisition_reservation"(SOME p),
          started=Synchronized.var "source_acquisition_started" false} end)();
    in case result of Exn.Res reservation=>(cleanup:=SOME reservation;reservation)
      | Exn.Exn failure=>(S.release_child held_child;Exn.reraise failure) end);
  fun reserve args=reserve_into args(Unsynchronized.ref NONE);
  fun reservation_view(Reservation{root,...})=(case Synchronized.value root of NONE=>
    error "Source reservation released" | SOME p=>
      (require(S.child_live(#child p) andalso declaration_live(#declaration p))
        "Source reservation ancestry unavailable";p));
  fun reservation_identity r=
    let val p=reservation_view r; val id=S.identity(#child p)
    in {request= #request id,slot= #slot id,target= #target p,attempt= #attempt p,
      source_binding= #binding p,semantic_generation= #semantic_generation p} end;
  fun executable()=K.executable;
  fun modeled_cost reservation=
    let val limits= #limits(declaration_view(#declaration(reservation_view reservation)))
    in 1+64*(IntInf.fromInt(#input_bytes limits)+IntInf.fromInt(#metadata_bytes limits))+
      16*IntInf.fromInt(#rows limits) end;
  fun release_reservation(Reservation{root,...})=Thread_Attributes.uninterruptible_body(fn _=>Option.app(fn p:reserve_payload=>S.release_child(#child p))
    (Synchronized.change_result root(fn p=>(p,NONE))));
  fun acquired_live({declaration,child,unit,...}:acquired)=
    S.child_live child andalso declaration_live declaration andalso
      (case U.inspect unit of NONE=>false | SOME view=>forall L.retained(#inputs view));
  fun snapshot_view(Snapshot{root,...})=(case Synchronized.value root of SOME p=>
      (require(acquired_live p) "Source snapshot ancestry unavailable";p)
    | NONE=>error "Source snapshot released");
  fun witness_view(Witness{root,...})=(case Synchronized.value root of SOME p=>
      (require(acquired_live p) "Source witness ancestry unavailable";p)
    | NONE=>error "Source witness released");
  fun reprove ctxt proposition seconds=
    Timeout.apply(Time.fromSeconds seconds)(fn()=>
      Goal.prove ctxt [] [] (HOLogic.mk_Trueprop proposition)
        (fn {context,...}=>HEADGOAL(Code_Simp.dynamic_tac context)))();
  fun attach_into ticket cleanup=
    let val(receipt,{executable,reservation,input,manifest_input,source_owner,manifest_owner}:acquisition_payload)=
        Tickets.consume_acquisition ticket;
      val p=reservation_view reservation;
      val Reservation{started,...}=reservation;
      val _=Synchronized.change started(fn previous=>
        (require(not previous) "Source acquisition reservation already consumed";true));
      val d=declaration_view(#declaration p);
      val identity=reservation_identity reservation;
      val operation= #operation receipt;
      val generation=P.generation(#development d);
      val ctxt=R.context generation;
      val supports=distinct(op =)(P.source_identity source_owner::P.source_identity manifest_owner::
        P.source_identity(#owner d)::P.development_dependencies(#development d));
      val _=require(Veri7vn_Executable_Identity.same(executable,K.executable) andalso
        #implementation_artifact operation= #artifact(Veri7vn_Executable_Identity.manifest K.executable) andalso
        #cost operation=modeled_cost reservation andalso #request operation= #request identity andalso #slot receipt= #slot identity andalso
        #target receipt= #target identity andalso #attempt receipt= #attempt identity andalso
        #source_binding receipt= #source_binding identity andalso
        #semantic_generation operation= #semantic_generation identity andalso
        #workspace operation=I.workspace(#allocator p) andalso
        P.source_workspace source_owner= #workspace operation andalso
        P.source_workspace manifest_owner= #workspace operation andalso
        P.owns_input source_owner input andalso P.owns_input manifest_owner manifest_input andalso
        List.all(member(op =)(#inputs operation))supports andalso
        member(op =)(#sources receipt)(#binding p)) "Charged acquisition binding mismatch";
      val limits= #limits d;
      val raw=L.bytes input;
      val meta=L.bytes manifest_input;
      val _=require(size raw<= #input_bytes limits andalso size meta<= #metadata_bytes limits)
        "Source acquisition byte bounds";
      val nat=K.nat_of_integer;
      val requirement=K.instantiate(#settings d)(nat(#request identity))(nat(#attempt p))
        (nat(#binding p))(nat 0);
      val to_bytes=map(IntInf.fromInt o Char.ord)o String.explode;
      val record=the(K.decode_manifest(IntInf.fromInt(#metadata_bytes limits))(to_bytes meta));
      val _=require(C.metadata_private record) "Only private acquisition profile is installed";
      val manifest=K.manifest requirement record;
      val bytes=to_bytes raw;
      val carrier=the(Timeout.apply(Time.fromSeconds(#seconds limits))
        (fn()=>K.construct requirement manifest bytes)());
      val native=Thm.cterm_of ctxt(K.reify carrier);
      val natural=HOLogic.mk_number HOLogic.natT;
      val native_bytes=HOLogic.mk_list @{typ integer}
        (map(fn n=>HOLogic.mk_number @{typ integer} n)bytes);
      val metadata_bytes=HOLogic.mk_list @{typ integer}
        (map(fn n=>HOLogic.mk_number @{typ integer} n)(to_bytes meta));
      val owned= @{term source_owned_acquisition_meaning} $ Thm.term_of(#native d) $
        natural(#request identity) $ natural(#attempt p) $ natural(#binding p) $
        HOLogic.mk_number @{typ integer} (IntInf.fromInt(#metadata_bytes limits)) $
        metadata_bytes $ native_bytes $ Thm.term_of native;
      val ownership=reprove ctxt owned (#seconds limits);
      val implication=Drule.infer_instantiate ctxt
        [(("settings",0),#native d),(("request",0),Thm.cterm_of ctxt(natural(#request identity))),
         (("attempt",0),Thm.cterm_of ctxt(natural(#attempt p))),
         (("binding",0),Thm.cterm_of ctxt(natural(#binding p))),
         (("limit",0),Thm.cterm_of ctxt(HOLogic.mk_number @{typ integer}(IntInf.fromInt(#metadata_bytes limits)))),
         (("metadata",0),Thm.cterm_of ctxt metadata_bytes),(("bytes",0),Thm.cterm_of ctxt native_bytes),
         (("a",0),native)] @{thm owned_acquisition_association};
      val meaning=Thm.implies_elim implication ownership;
      val(h,registry)=R.insert generation "fixed-owned-source-acquisition"(R.Theorem ownership)R.empty;
      val qualification=(case A.admit(S.policy(S.parent(#child p)))generation registry h A.Kernel
        {claim=A.exact_claim(Thm.cterm_of ctxt(Thm.prop_of ownership)),hypotheses=[],premises=[],
         sorts=Thm.shyps_of ownership} of A.Accepted accepted=>accepted
        | A.Rejected reasons=>error(space_implode "; " reasons));
      val observation=Thm.cterm_of ctxt(K.reify_observation(K.association_observation carrier));
      val observation_projection=reprove ctxt
        (HOLogic.mk_eq(@{term association_observation}$Thm.term_of native,Thm.term_of observation))
        (#seconds limits);
    in Thread_Attributes.uninterruptible_body(fn _=>let
      val unit=U.create{generation=generation,inputs=[input,manifest_input],objects=[]}R.empty;
      val held_child=(case Exn.capture S.retain_child (#child p) of Exn.Res child=>child
        | Exn.Exn failure=>(ignore(U.release unit);Exn.reraise failure));
      val acquired={declaration= #declaration p,child=held_child,generation=generation,native=native,observation=observation,observation_projection=observation_projection,
        meaning=meaning,ownership=ownership,qualification=qualification,carrier=carrier,unit=unit,receipt=receipt,dependencies=supports};
      val Reservation{root=reservation_root,...}=reservation;
      val installed=Synchronized.change_result reservation_root(fn state=>(is_some state,state));
      val built=Exn.capture(fn()=>Snapshot{key=serial(),root=Synchronized.var "owned_source_snapshot"(SOME acquired)})();
      val result=(case built of Exn.Res result=>result | Exn.Exn failure=>
        (ignore(U.release unit);S.release_child held_child;Exn.reraise failure));
      val _=cleanup:=SOME result;
      val _=if installed andalso acquired_live acquired then () else
        (ignore(U.release unit);S.release_child held_child;cleanup:=NONE;
          error "Source retired during charged acquisition")
    in result end) end;
  fun attach ticket=attach_into ticket(Unsynchronized.ref NONE);
  fun release_snapshot(Snapshot{root,...})=Thread_Attributes.uninterruptible_body(fn _=>Option.app(fn{unit,child,...}:acquired=>(ignore(U.release unit);S.release_child child))
    (Synchronized.change_result root(fn p=>(p,NONE))));
  fun clone_acquired(p:acquired)=Thread_Attributes.uninterruptible_body(fn _=>
    let val inputs= #inputs(the(U.inspect(#unit p)));
      val unit=U.create{generation= #generation p,inputs=inputs,objects=[]}R.empty;
      val child=(case Exn.capture S.retain_child (#child p) of Exn.Res child=>child
        | Exn.Exn failure=>(ignore(U.release unit);Exn.reraise failure))
    in {declaration= #declaration p,child=child,generation= #generation p,native= #native p,
        observation= #observation p,observation_projection= #observation_projection p,
        meaning= #meaning p,ownership= #ownership p,qualification= #qualification p,
        carrier= #carrier p,unit=unit,receipt= #receipt p,dependencies= #dependencies p}:acquired end);
  fun witness p=Witness{key=serial(),root=Synchronized.var "source_observer_witness"(SOME p)};
  fun transfer_into snapshot cleanup=Thread_Attributes.uninterruptible_body(fn _=>
    let val result=witness(clone_acquired(snapshot_view snapshot)); val _=cleanup:=SOME result
    in result end);
  fun transfer snapshot=transfer_into snapshot(Unsynchronized.ref NONE);
  fun clone_witness original=Thread_Attributes.uninterruptible_body(fn _=>witness(clone_acquired(witness_view original)));
  fun release_witness(Witness{root,...})=Thread_Attributes.uninterruptible_body(fn _=>Option.app(fn{unit,child,...}:acquired=>(ignore(U.release unit);S.release_child child))
    (Synchronized.change_result root(fn p=>(p,NONE))));
  fun witness_live witness=is_some(try witness_view witness);
  fun same_witness(a,b)=
    let val pa=witness_view a; val pb=witness_view b
    in #target(#receipt pa)= #target(#receipt pb) andalso
      #workspace(#operation(#receipt pa))= #workspace(#operation(#receipt pb)) end;
  fun association witness= #carrier(witness_view witness);
  fun native_association witness= #native(witness_view witness);
  fun native_observation witness= #observation(witness_view witness);
  fun association_meaning witness= #meaning(witness_view witness);
  fun acquisition_meaning witness= #ownership(witness_view witness);
  fun acquisition_qualification witness= #qualification(witness_view witness);
  fun observation_projection witness= #observation_projection(witness_view witness);
  fun generation witness= #generation(witness_view witness);
  fun policy witness=S.policy(S.parent(#child(witness_view witness)));
  fun dependencies witness= #dependencies(witness_view witness);
  fun child witness= #child(witness_view witness);
  fun receipt_binding witness=
    let val operation= #operation(#receipt(witness_view witness))
    in {workspace= #workspace operation,request= #request operation,
      semantic_generation= #semantic_generation operation,inputs= #inputs operation} end;

end;
