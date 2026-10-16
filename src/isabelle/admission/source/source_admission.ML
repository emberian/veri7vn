(* Family-specific consumer of the private state owner's confirmed acquisition
   tickets. No globally instantiated issuer or raw-ID acceptance constructor. *)
signature VERI7VN_SOURCE_ADMISSION =
sig
  type reservation
  type association
  type query_result
  type relation_result
  type acquisition_payload = {reservation:reservation,
    input:Veri7vn_Native_Literals.input,manifest_input:Veri7vn_Native_Literals.input,
    source_owner:Veri7vn_Managed_Provenance.source_owner,
    manifest_owner:Veri7vn_Managed_Provenance.source_owner}
  val prepare: {allocator:Veri7vn_Native_Identity_Allocator.allocator,
    recipe:Veri7vn_Row_Instance.recipe} -> reservation
  val operation_instance: reservation -> Veri7vn_Row_Instance.instance
  val operation: reservation -> Veri7vn_Row_Kernel.source_operation
  val native_metadata: reservation -> cterm
  val reservation_live: reservation -> bool
  val native_template: reservation -> cterm
  val target_id: reservation -> IntInf.int
  val request: reservation -> IntInf.int
  val attempt: reservation -> IntInf.int
  val source_binding: reservation -> IntInf.int
  val slot: reservation -> IntInf.int
  val semantic_generation: reservation -> IntInf.int
  val reservation_executable: reservation -> Veri7vn_Executable_Identity.pin
  val release_reservation: reservation -> unit
  val execute_associated_query: association -> query_result
  val prepare_relation: {allocator:Veri7vn_Native_Identity_Allocator.allocator,
    recipe:Veri7vn_Row_Instance.relation_recipe} -> reservation
  val execute_associated_relation: association -> relation_result
  val relation_outcome: relation_result -> Veri7vn_Row_Kernel.relation_result
  val release_relation_result: relation_result -> unit
  val release_query_result: query_result -> unit
  val query_outcome: query_result -> Veri7vn_Row_Kernel.query_outcome
  val association_id: association -> IntInf.int
  val output_id: association -> IntInf.int
  val managed_dependencies: association -> IntInf.int list
  val retention_private: association -> bool option
  val instance: association -> Veri7vn_Row_Instance.instance
  val executable: association -> Veri7vn_Executable_Identity.pin
  val native_generation: association -> Veri7vn_Native_Registry.generation
  val relation_contracts: association -> Veri7vn_Native_Admission.accepted list
  val relation_implementation_contract: association -> Veri7vn_Native_Admission.accepted
  val implementation_contract: association -> Veri7vn_Native_Admission.accepted
  val same_association: association * association -> bool
  val is_live: association -> bool
  val release: association -> unit
end;

functor Veri7vn_Source_Admission
  (Tickets:VERI7VN_OPERATION_TICKET_VIEW) :>
sig
  include VERI7VN_SOURCE_ADMISSION
  val attach: acquisition_payload Tickets.acquisition_ticket -> association
end =
struct
  structure A=Veri7vn_Native_Admission;
  structure R=Veri7vn_Native_Registry;
  structure E=Veri7vn_Executable_Identity;
  structure L=Veri7vn_Native_Literals;
  structure P=Veri7vn_Managed_Provenance;
  structure I=Veri7vn_Native_Identity_Allocator;
  structure N=Veri7vn_Native_Descriptor;
  structure K=Veri7vn_Row_Kernel;
  structure RI=Veri7vn_Row_Instance;
  datatype reservation = Reservation of {id:serial,
    payload:reservation_payload option Synchronized.var,
    children:association list Synchronized.var}
  and association = Association of {id:serial,association_id:IntInf.int,output_id:IntInf.int,
    payload:association_payload option Synchronized.var,
    results:(serial * K.query_outcome option Synchronized.var) list Synchronized.var,
    relation_results:(serial * K.relation_result option Synchronized.var) list Synchronized.var}
  withtype reservation_payload = {allocator:I.allocator,recipe:RI.recipe,
    template:cterm,target:IntInf.int,request:IntInf.int,attempt:IntInf.int,
    source_binding:IntInf.int,slot:IntInf.int,semantic_generation:IntInf.int,
    relation:RI.relation_recipe option}
  and association_payload = {reservation:reservation,input:L.input,manifest_input:L.input,
    source_owner:P.source_owner,manifest_owner:P.source_owner,
    batch:K.batch,observation:K.observation,manifest:RI.verified_manifest,
    receipt:Tickets.acquisition_identity}
  datatype query_result = QueryResult of {id:serial,owner:association,
    payload:K.query_outcome option Synchronized.var};
  datatype relation_result = RelationResult of {id:serial,owner:association,
    payload:K.relation_result option Synchronized.var};
  type acquisition_payload={reservation:reservation,input:L.input,manifest_input:L.input,
    source_owner:P.source_owner,manifest_owner:P.source_owner};
  fun require true _=() | require false text=error text;
  fun available message (SOME value)=value | available message NONE=error message;
  fun reservation_view (Reservation {payload,...}) =
    (case Synchronized.value payload of SOME p=>if RI.recipe_is_live (#recipe p) then p
      else error "Source recipe released" | NONE=>error "Source reservation released");
  fun reservation_live (Reservation {payload,...})=
    (case Synchronized.value payload of NONE=>false | SOME {recipe,...}=>RI.recipe_is_live recipe);
  fun association_view (Association {payload,...}) =
    (case Synchronized.value payload of SOME p=>p | NONE=>error "Source association released");
  fun is_live (Association {payload,...}) =
    (case Synchronized.value payload of NONE=>false | SOME {reservation,input,manifest_input,source_owner,manifest_owner,...}=>
      reservation_live reservation andalso L.retained input andalso L.retained manifest_input andalso
      P.owns_input source_owner input andalso P.owns_input manifest_owner manifest_input);
  fun same_association (Association {id=a,...},Association {id=b,...})=a=b;
  fun prepare {allocator,recipe} =
    let val generation=RI.recipe_generation recipe
      val ctxt=R.context generation
      val metadata=RI.metadata recipe
      val (acquisition,(_,context))=RI.parameters recipe
      val request=K.nat_to_integer (K.acquisition_request acquisition)
      val attempt=K.nat_to_integer (K.acquisition_attempt acquisition)
      val source_binding=K.nat_to_integer (K.acquisition_source_binding acquisition)
      val slot=(case K.context_pin context of Veri7vn_Row_Code.ReservedSourceOutput n=>K.nat_to_integer n
        | _=>error "Fresh acquisition requires an actual reserved output pin")
      val (_,qctx)=HOLogic.dest_prod (Thm.term_of metadata)
      val (q,c)=HOLogic.dest_prod qctx
      val template=Syntax.check_term ctxt
        (Const (@{const_name requested_acquired_meaning},dummyT) $ c $ q) |> Thm.cterm_of ctxt
      val payload={allocator=allocator,recipe=recipe,template=template,target=I.allocate allocator,
        request=request,attempt=attempt,source_binding=source_binding,slot=slot,
        semantic_generation=N.semantic_generation_id allocator generation,relation=NONE}
    in Reservation {id=serial (),payload=Synchronized.var "source_reservation" (SOME payload),
      children=Synchronized.var "source_associations" []} end;
  fun prepare_relation {allocator,recipe} =
    let val reservation as Reservation{payload,...}=
      prepare{allocator=allocator,recipe=RI.relation_parent recipe};
      val ctxt=R.context(RI.recipe_generation(RI.relation_parent recipe));
      val relation_template=Syntax.check_term ctxt
        (Const(@{const_name run_structured_relation_query},dummyT) $
          Thm.term_of(RI.relation_metadata recipe)) |> Thm.cterm_of ctxt;
      val _=Synchronized.change payload (Option.map(fn
        {allocator,recipe=parent,template,target,request,attempt,source_binding,slot,semantic_generation,...}=>
        {allocator=allocator,recipe=parent,template=relation_template,target=target,request=request,
         attempt=attempt,source_binding=source_binding,slot=slot,
         semantic_generation=semantic_generation,relation=SOME recipe}));
    in reservation end;
  fun operation_instance r=RI.recipe_instance (#recipe (reservation_view r));
  fun operation r=(case #relation(reservation_view r) of NONE=>K.count_operation
    | SOME recipe=>RI.relation_operation recipe);
  fun native_metadata r= RI.metadata (#recipe (reservation_view r));
  fun native_template r= #template (reservation_view r);
  fun target_id r= #target (reservation_view r);
  fun request r= #request (reservation_view r);
  fun attempt r= #attempt (reservation_view r);
  fun source_binding r= #source_binding (reservation_view r);
  fun slot r= #slot (reservation_view r);
  fun semantic_generation r= #semantic_generation (reservation_view r);
  fun reservation_executable r=RI.executable (operation_instance r);
  fun release (Association {payload,results,relation_results,...}) =
    (Synchronized.change payload (K NONE);
     List.app (fn (_,cell)=>Synchronized.change cell (K NONE))
       (Synchronized.change_result results (fn old=>(old,[])));
     List.app(fn (_,cell)=>Synchronized.change cell (K NONE))
       (Synchronized.change_result relation_results(fn old=>(old,[]))));
  fun release_reservation (Reservation {payload,children,...}) =
    (case Synchronized.change_result payload (fn old=>(old,NONE)) of NONE=>()
    | SOME {recipe,...}=>
      (List.app release (Synchronized.change_result children (fn old=>(old,[])));
       RI.release_recipe recipe));
  fun attach ticket =
    let val (identity,{reservation,input,manifest_input,source_owner,manifest_owner}:acquisition_payload)=Tickets.consume_acquisition ticket
      val saved=reservation_view reservation
      val operation= #operation identity
      val _=require (I.workspace (#allocator saved)= #workspace operation andalso
        P.source_workspace source_owner= #workspace operation andalso
        P.source_workspace manifest_owner= #workspace operation andalso
        #request saved= #request operation andalso #attempt saved= #attempt identity andalso
        #source_binding saved= #source_binding identity andalso
        #slot saved= #slot identity andalso #target saved= #target identity andalso
        #semantic_generation saved= #semantic_generation operation andalso
        member (op =) (#sources identity) (#source_binding saved) andalso
        member (op =) (#inputs operation) (P.source_identity source_owner) andalso
        member (op =) (#inputs operation) (P.source_identity manifest_owner) andalso
        P.owns_input source_owner input andalso P.owns_input manifest_owner manifest_input andalso
        L.retained input andalso L.retained manifest_input)
        "Confirmed acquisition does not match reserved native input"
      val recipe= #recipe saved
      val config=RI.limits (RI.recipe_instance recipe)
      val manifest_bytes=L.bytes manifest_input
      val _=require (size manifest_bytes<= #metadata_bytes config)
        "Manifest byte bound before materialization"
      val verified_manifest=RI.validate_manifest_wire recipe (Byte.stringToBytes manifest_bytes)
      val raw=L.bytes input
      val (acquisition,_)=RI.parameters recipe
      val _=require (size raw<= #input_bytes config andalso
        IntInf.fromInt (size raw)<=K.acquisition_byte_limit acquisition)
        "Acquisition byte bound before materialization"
      val bytes=map (IntInf.fromInt o Char.ord) (String.explode raw)
      val (batch,observation)=available "Actual source decoder rejected input or acquisition bounds"
        (RI.acquire recipe verified_manifest bytes)
      val association=Association {id=serial (),association_id=I.allocate (#allocator saved),
        output_id=I.allocate (#allocator saved),payload=Synchronized.var "source_association"
        (SOME {reservation=reservation,input=input,manifest_input=manifest_input,
          source_owner=source_owner,manifest_owner=manifest_owner,batch=batch,
          observation=observation,manifest=verified_manifest,receipt=identity}),results=Synchronized.var "source_results" [],
        relation_results=Synchronized.var "source_relation_results" []}
      val Reservation {payload,children,...}=reservation
      val installed=Synchronized.change_result payload (fn state=>
        case state of NONE=>(false,NONE) | SOME p=>
          (Synchronized.change children (cons association);(true,SOME p)))
      val _=if installed andalso is_live association then () else
        (release association;error "Acquisition reservation retired during execution")
    in association end;
  fun execute_associated_query association =
    let val _=require (is_live association) "Source association released"
      val {reservation,observation,...}=association_view association
      val {recipe,...}=reservation_view reservation
      val _=require(is_none(#relation(reservation_view reservation)))
        "Relation reservation cannot invoke count operation"
      val result=RI.query recipe [observation]
      val id=serial ()
      val cell=Synchronized.var "source_query_result" (SOME result)
      val Association {payload,results,...}=association
      val installed=Synchronized.change_result payload (fn state=>case state of
        NONE=>(false,NONE) | SOME p=>(Synchronized.change results (cons (id,cell));(true,SOME p)))
      val _=if installed andalso is_live association then () else
        (Synchronized.change cell (K NONE);error "Source retired during query")
    in QueryResult {id=id,owner=association,payload=cell} end;
  fun execute_associated_relation association =
    let val _=require(is_live association) "Source association released";
      val {reservation,batch,...}=association_view association;
      val recipe=available "Reservation is not a structured relation query"
        (#relation(reservation_view reservation));
      val result=RI.relation_query recipe batch;
      val id=serial();
      val cell=Synchronized.var "source_relation_result" (SOME result);
      val Association{payload,relation_results,...}=association;
      val installed=Synchronized.change_result payload(fn state=>case state of NONE=>(false,NONE)
        | SOME p=>(Synchronized.change relation_results(cons(id,cell));(true,SOME p)));
      val _=if installed andalso is_live association then () else
        (Synchronized.change cell(K NONE);error "Source retired during relation query");
    in RelationResult{id=id,owner=association,payload=cell} end;
  fun release_relation_result(RelationResult{id,owner=Association{relation_results,...},payload})=
    (Synchronized.change payload(K NONE);
     Synchronized.change relation_results(filter(fn(other,_)=>other<>id)));
  fun relation_outcome(RelationResult{owner,payload,...})=
    (require(is_live owner) "Source relation result released";the(Synchronized.value payload));
  fun release_query_result (QueryResult {id,owner=Association {results,...},payload}) =
    (Synchronized.change payload (K NONE);
     Synchronized.change results (filter (fn (other,_)=>other<>id)));
  fun query_outcome (QueryResult {owner,payload,...}) =
    (require (is_live owner) "Source query released";the (Synchronized.value payload));
  fun association_id (Association {association_id,...})=association_id;
  fun output_id (Association {output_id,...})=output_id;
  fun managed_dependencies association =
    let val {reservation,source_owner,manifest_owner,receipt,...}=association_view association
      val saved=reservation_view reservation
      val operation= #operation receipt
    in distinct (op =) (association_id association :: output_id association ::
      #target saved :: #semantic_generation saved :: P.source_identity source_owner ::
      P.source_identity manifest_owner ::
      #request saved :: #attempt saved :: #slot saved :: #capability receipt ::
      #sources receipt @ #dependencies receipt @ #inputs operation) end;
  fun retention_private a=RI.retention_private (#manifest (association_view a));
  fun instance a=operation_instance (#reservation (association_view a));
  fun executable a=reservation_executable (#reservation (association_view a));
  fun native_generation a= RI.recipe_generation (#recipe (reservation_view (#reservation (association_view a))));
  fun relation_contracts a=RI.relation_contracts(instance a);
  fun relation_implementation_contract a= RI.relation_contract(instance a);
  fun implementation_contract a= RI.implementation_contract
    (operation_instance (#reservation (association_view a)));
end;
