(* One fixed generated family instance. No caller supplies executable code,
   theorem names, a proof callback, or an acceptance constructor. *)
signature VERI7VN_ROW_INSTANCE =
sig
  type instance type recipe type verified_manifest type relation_recipe
  type limits = {input_bytes:int,materialized_rows:int,metadata_nodes:int,
    metadata_depth:int,metadata_bytes:int,seconds:int}
  val qualify: limits -> instance
  val executable: instance -> Veri7vn_Executable_Identity.pin
  val operation: instance -> Veri7vn_Row_Kernel.operation
  val implementation_contract: instance -> Veri7vn_Native_Admission.accepted
  val projection_contract: instance -> Veri7vn_Native_Admission.accepted
  val relation_contract: instance -> Veri7vn_Native_Admission.accepted
  val relation_contracts: instance -> Veri7vn_Native_Admission.accepted list
  val component_contract: instance -> Veri7vn_Native_Admission.accepted
  val codec_contract: instance -> Veri7vn_Native_Admission.accepted
  val cost_contract: instance -> Veri7vn_Native_Admission.accepted
  val metadata_contracts: instance -> Veri7vn_Native_Admission.accepted list
  val modeled_cost: instance -> IntInf.int
  val limits: instance -> limits
  val same_instance: instance * instance -> bool
  val is_live: instance -> bool
  (* generation validates the input certificate only. The recipe retains the
     exact public constructor metadata, not that input context or provenance. *)
  val elaborate: instance -> {generation:Veri7vn_Native_Registry.generation,metadata:cterm} -> recipe
  val recipe_is_live: recipe -> bool
  val recipe_instance: recipe -> instance
  val recipe_generation: recipe -> Veri7vn_Native_Registry.generation
  val metadata: recipe -> cterm
  val parameters: recipe -> Veri7vn_Row_Kernel.acquisition *
    (Veri7vn_Row_Kernel.query * Veri7vn_Row_Kernel.context)
  val validate_manifest: recipe -> cterm -> verified_manifest
  val validate_manifest_wire: recipe -> Word8Vector.vector -> verified_manifest
  val manifest: verified_manifest -> cterm option
  val manifest_wire: verified_manifest -> Word8Vector.vector option
  val metadata_record: verified_manifest -> Veri7vn_Row_Kernel.metadata_record option
  val retention_private: verified_manifest -> bool option
  val manifest_value: verified_manifest -> Veri7vn_Row_Kernel.manifest
  val acquire: recipe -> verified_manifest -> IntInf.int list ->
    (Veri7vn_Row_Kernel.batch * Veri7vn_Row_Kernel.observation) option
  val query: recipe -> Veri7vn_Row_Kernel.observation list -> Veri7vn_Row_Kernel.query_outcome
  val elaborate_relation: recipe -> cterm -> relation_recipe
  val relation_parent: relation_recipe -> recipe
  val relation_metadata: relation_recipe -> cterm
  val relation_operation: relation_recipe -> Veri7vn_Row_Kernel.source_operation
  val relation_query: relation_recipe -> Veri7vn_Row_Kernel.batch -> Veri7vn_Row_Kernel.relation_result
  val restrict_relation_inputs: relation_recipe ->
    (Veri7vn_Native_Literals.input * Veri7vn_Managed_Provenance.source_owner) list -> unit
  val restrict_relation_unit: relation_recipe -> Veri7vn_Managed_Native_Unit.token -> unit
  val relation_input_owners: relation_recipe -> Veri7vn_Managed_Provenance.source_owner list
  val release_relation: relation_recipe -> unit
  val release_recipe: recipe -> unit
  val release: instance -> unit
end;
structure Veri7vn_Row_Instance :> VERI7VN_ROW_INSTANCE =
struct
  structure K=Veri7vn_Row_Kernel;
  structure A=Veri7vn_Native_Admission;
  structure R=Veri7vn_Native_Registry;
  structure E=Veri7vn_Executable_Identity;
  type limits={input_bytes:int,materialized_rows:int,metadata_nodes:int,
    metadata_depth:int,metadata_bytes:int,seconds:int};
  datatype instance=Instance of {id:serial,payload:instance_payload option Synchronized.var,
    recipes:recipe list Synchronized.var}
  and recipe=Recipe of {id:serial,owner:instance,payload:recipe_payload option Synchronized.var,
    manifests:verified_manifest list Synchronized.var,relations:relation_recipe list Synchronized.var}
  and verified_manifest=Manifest of {owner:recipe,payload:manifest_payload option Synchronized.var}
  and relation_recipe=RelationRecipe of {owner:recipe,payload:relation_payload option Synchronized.var}
  withtype instance_payload={generation:R.generation,policy:A.policy,limits:limits,
    implementation:A.accepted,relation:A.accepted,relation_basis:A.accepted list,projection:A.accepted,components:A.accepted,codec:A.accepted,cost:A.accepted,
    metadata:A.accepted list,modeled_cost:IntInf.int}
  and recipe_payload={generation:R.generation,metadata:cterm,parameters:K.metadata}
  and manifest_payload={native:cterm option,value:K.manifest,wire:Word8Vector.vector option,record:K.metadata_record option}
  and relation_payload={metadata:cterm,value:K.relation_requirement,inputs:(Veri7vn_Native_Literals.input * Veri7vn_Managed_Provenance.source_owner) list,units:Veri7vn_Managed_Native_Unit.token list};
  fun require true _=() | require false message=error message;
  fun view (Instance {payload,...}) = (case Synchronized.value payload of SOME p=>p
    | NONE=>error "Row instance released");
  fun is_live (Instance {payload,...})=is_some (Synchronized.value payload);
  fun same_instance (Instance {id=a,...},Instance {id=b,...})=a=b;
  fun executable i=(ignore(view i);K.executable);
  fun operation i=(ignore(view i);K.operation);
  fun implementation_contract i= #implementation(view i);
  fun projection_contract i= #projection(view i);
  fun relation_contract i= #relation(view i);
  fun relation_contracts i= #relation(view i):: #relation_basis(view i);
  fun component_contract i= #components(view i);
  fun codec_contract i= #codec(view i);
  fun cost_contract i= #cost(view i);
  fun metadata_contracts i= #metadata(view i);
  fun modeled_cost i= #modeled_cost(view i);
  fun limits i= #limits(view i);
  fun valid_limits ({input_bytes,materialized_rows,metadata_nodes,metadata_depth,metadata_bytes,seconds}:limits)=
    input_bytes>0 andalso input_bytes<=1048576 andalso
    materialized_rows>0 andalso materialized_rows<=65536 andalso
    metadata_nodes>0 andalso metadata_nodes<=20000 andalso
    metadata_depth>0 andalso metadata_depth<=128 andalso
    metadata_bytes>0 andalso metadata_bytes<=100000 andalso seconds>0 andalso seconds<=5;
  fun admit policy generation label theorem =
    let val ctxt=R.context generation;
      val native=Thm.transfer (Proof_Context.theory_of ctxt) theorem;
      val (h,registry)=R.insert generation label (R.Theorem native) R.empty;
    in case A.admit policy generation registry h A.Kernel
      {claim=A.exact_claim(Thm.cterm_of ctxt(Thm.prop_of native)),hypotheses=Thm.hyps_of native,
       premises=Thm.prems_of native,sorts=Thm.shyps_of native} of
      A.Accepted a=>a | A.Rejected reasons=>error(space_implode "; " reasons) end;
  fun qualify (config:limits) =
    let
      (* Qualification and constructor-only recipe values belong to the public
         shipped image. Source/NL provenance is separately owned by admission. *)
      val policy=A.policy K.code_theory;
      val generation=R.generation(Proof_Context.init_global K.code_theory)
        {packages=["veri7vn.qualified-row-kernel/1"],runtime="Eval / PolyML",
         policy="native kernel-only fixed family",sources=["shipped row kernel"],
         interpretation="qualified source observations and exact row meaning"};
      val _=require(valid_limits config) "Row operation limits outside supported envelope";
      val _=require(Context.subthy(K.code_theory,Proof_Context.theory_of(R.context generation)))
        "Row operation native generation lacks fixed code theory";
      val implementation=admit policy generation "fixed-row-operation" K.operation_contract;
      val projection=admit policy generation "fixed-row-scalar-projection" K.projection_contract;
      val components=admit policy generation "fixed-row-staged-components" K.component_contract;
      val relation=admit policy generation "fixed-source-relation-observer" K.relation_contract;
      val relation_acquisition=admit policy generation "fixed-source-relation-acquisition" K.relation_acquisition_contract;
      val relation_incomplete=admit policy generation "fixed-source-relation-incomplete" K.relation_incomplete_contract;
      val codec=admit policy generation "fixed-row-wire-codec" K.codec_contract;
      val metadata=map_index(fn (n,th)=>admit policy generation ("fixed-source-metadata-"^string_of_int n) th) K.metadata_contracts;
      val cost=admit policy generation "fixed-row-positive-cost" K.positive_cost_contract;
      fun natural n=K.nat_of_integer(IntInf.fromInt n);
      val modeled=K.modeled_cost (natural(#input_bytes config))
        (natural(#materialized_rows config)) (natural(#metadata_nodes config)) |> K.nat_to_integer;
      val _=require(modeled>0) "Fixed generated operation cost is not positive";
    in Instance{id=serial(),payload=Synchronized.var "row_instance"(SOME
      {generation=generation,policy=policy,limits=config,implementation=implementation,relation=relation,relation_basis=[relation_acquisition,relation_incomplete],projection=projection,components=components,
       codec=codec,cost=cost,metadata=metadata,modeled_cost=modeled}),recipes=Synchronized.var "row_recipes" []} end;
  fun recipe_is_live (Recipe{owner,payload,...})=is_live owner andalso is_some(Synchronized.value payload);
  fun recipe_instance (Recipe {owner,...})=owner;
  fun recipe_view (r as Recipe {owner,payload,...}) =
    (ignore(view owner);case Synchronized.value payload of SOME p=>p | NONE=>error "Row recipe released");
  fun recipe_generation r= #generation(recipe_view r);
  fun metadata r= #metadata(recipe_view r);
  fun parameters r= #parameters(recipe_view r);
  fun bound ({metadata_nodes,metadata_depth,metadata_bytes,...}:limits) t =
    let fun walk [] _=()
      | walk ((u,d)::todo) n=
        (require(n<metadata_nodes andalso d<=metadata_depth) "Row metadata structural bound";
         case u of f$x=>walk((f,d+1)::(x,d+1)::todo)(n+1)
         | Abs _=>error "Row metadata must use native constructors, not abstractions"
         | Var _=>error "Unresolved row metadata variable"
         | Free _=>error "Open row metadata parameter"
         | _=>walk todo(n+1));
      val _=walk[(t,0)]0;
      val bytes=Term_XML.Encode.term_raw t |> YXML.string_of_body;
    in require(size bytes<=metadata_bytes) "Row metadata byte bound" end;
  fun elaborate owner {generation,metadata=raw} =
    let val qualified=view owner;
      val ctxt=R.context generation;
      val thy=Proof_Context.theory_of ctxt;
      val _=require(Context.subthy(K.code_theory,thy) andalso
        Context.subthy(A.policy_theory(#policy qualified),thy)) "Row recipe native generation mismatch";
      (* Validate the input certificate against its declared generation, then
         retain only the exact constructor term in the public compiler image.
         Certification rejects constants/types absent from that image. No
         private definition is unfolded, erased or relabelled as public data. *)
      val input=Thm.transfer_cterm thy raw;
      val term=Thm.term_of input;
      val _=bound(#limits qualified) term;
      val _=require(fastype_of term=
        @{typ "source_acquisition_requirement * acquired_row_requirement * source_plan_context"})
        "Row recipe native type mismatch";
      val public_generation= #generation qualified;
      val public_context=R.context public_generation;
      val native=Thm.cterm_of public_context term;
      val _=require(Thm.term_of native=term) "Row recipe certification changed its exact native term";
      val values as (acquisition,(_,context))=
        (case K.decode_metadata public_context term of SOME value=>value
        | NONE=>error "Row recipe is not fixed native constructor metadata");
      val config= #limits qualified;
      val byte_limit=K.acquisition_byte_limit acquisition;
      val row_limit=K.acquisition_row_limit acquisition;
      val material_limit=K.materialization_limit context |> K.nat_to_integer;
      val _=require(byte_limit>0 andalso byte_limit<=IntInf.fromInt(#input_bytes config) andalso
        row_limit>0 andalso row_limit<=IntInf.fromInt(#materialized_rows config) andalso
        material_limit>0 andalso material_limit<=IntInf.fromInt(#materialized_rows config))
        "Row recipe exceeds qualified operation limits";
      val r=Recipe{id=serial(),owner=owner,payload=Synchronized.var "row_recipe"
        (SOME{generation=public_generation,metadata=native,parameters=values}),
        manifests=Synchronized.var "row_manifests" [],relations=Synchronized.var "row_relation_recipes" []};
      val Instance {payload,recipes,...}=owner;
      val installed=Synchronized.change_result payload(fn state=>case state of NONE=>(false,NONE)
        | SOME p=>(Synchronized.change recipes(cons r);(true,SOME p)));
    in if installed then r else error "Row instance retired during elaboration" end;
  fun validate_manifest owner raw =
    let val saved=recipe_view owner;
      val native=Thm.transfer_cterm(Proof_Context.theory_of(R.context(#generation saved))) raw;
      val _=bound(limits(recipe_instance owner))(Thm.term_of native);
      val _=require(fastype_of(Thm.term_of native)= @{typ native_source_manifest})
        "Source manifest native type mismatch";
      val value=the(K.decode_manifest(R.context(#generation saved))(Thm.term_of native));
      val (acquisition,_)= #parameters saved;
      val _=require(K.matches acquisition value) "Manifest differs from immutable source recipe";
      val m=Manifest{owner=owner,payload=Synchronized.var "row_manifest"(SOME{native=SOME native,value=value,wire=NONE,record=NONE})};
      val Recipe{payload,manifests,...}=owner;
      val installed=Synchronized.change_result payload(fn state=>case state of NONE=>(false,NONE)
        | SOME p=>(Synchronized.change manifests(cons m);(true,SOME p)));
    in if installed then m else error "Row recipe retired during manifest validation" end;
  fun manifest_view (Manifest{owner,payload})=
    (ignore(recipe_view owner);case Synchronized.value payload of SOME p=>p
      | NONE=>error "Source manifest released");
  fun manifest m= #native(manifest_view m);
  fun manifest_wire m= #wire(manifest_view m);
  fun metadata_record m= #record(manifest_view m);
  fun retention_private m=Option.map K.metadata_private(metadata_record m);
  fun manifest_value m= #value(manifest_view m);
  fun validate_manifest_wire owner wire =
    let val saved=recipe_view owner;
      val config=limits(recipe_instance owner);
      val _=require(Word8Vector.length wire<= #metadata_bytes config) "Source metadata frame bound";
      val bytes=Word8Vector.foldr(fn (b,rest)=>IntInf.fromInt(Word8.toInt b)::rest) [] wire;
      val decoded=Timeout.apply(Time.fromSeconds(#seconds config))
        (fn () => K.decode_source_metadata_wire(IntInf.fromInt(#metadata_bytes config)) bytes) ();
      val record=the decoded;
      val (acquisition,_)= #parameters saved;
      val value=K.construct_source_manifest acquisition record;
      val _=require(K.matches acquisition value) "Metadata frame differs from immutable source recipe";
      val m=Manifest{owner=owner,payload=Synchronized.var "row_wire_manifest"
        (SOME{native=NONE,value=value,wire=SOME wire,record=SOME record})};
      val Recipe{payload,manifests,...}=owner;
      val installed=Synchronized.change_result payload(fn state=>case state of NONE=>(false,NONE)
        | SOME p=>(Synchronized.change manifests(cons m);(true,SOME p)));
    in if installed then m else error "Row recipe retired during native metadata decoding" end;
  fun acquire recipe (m as Manifest{owner=manifest_owner,...}) bytes =
    let val Recipe{id=a,...}=recipe;
      val Recipe{id=b,...}=manifest_owner;
      val _=require(a=b) "Source manifest belongs to another recipe";
      val (acquisition,_)=parameters recipe;
      val config=limits(recipe_instance recipe);
      val _=require(length bytes<= #input_bytes config andalso
        IntInf.fromInt(length bytes)<=K.acquisition_byte_limit acquisition) "Source input byte bound";
    in Timeout.apply(Time.fromSeconds(#seconds config))
      (fn () => K.acquire acquisition (manifest_value m) bytes) () end;
  fun query recipe observations =
    let val (_, (query,context))=parameters recipe;
      val config=limits(recipe_instance recipe);
      val _=require(length observations<= #materialized_rows config) "Source population bound";
    in Timeout.apply(Time.fromSeconds(#seconds config))
      (fn () => K.query context query observations |> K.extract_final_count) () end;
  fun elaborate_relation owner raw =
    let val saved=recipe_view owner;
      val term=Thm.term_of raw;
      val _=bound(limits(recipe_instance owner)) term;
      val _=require(fastype_of term= @{typ source_relation_requirement})
        "Structured relation requirement native type mismatch";
      val ctxt=R.context(#generation saved);
      val metadata=Thm.cterm_of ctxt term;
      val _=require(Thm.term_of metadata=term) "Relation requirement certification changed term";
      val value=(case K.decode_relation_requirement ctxt term of SOME v=>v
        | NONE=>error "Relation requirement is not fixed constructor metadata");
      val result=RelationRecipe{owner=owner,payload=Synchronized.var "source_relation_recipe"
        (SOME{metadata=metadata,value=value,inputs=[],units=[]})};
      val Recipe{payload,relations,...}=owner;
      val installed=Synchronized.change_result payload(fn state=>case state of NONE=>(false,NONE)
        | SOME p=>(Synchronized.change relations(cons result);(true,SOME p)));
    in if installed then result else error "Source recipe retired during relation elaboration" end;
  fun relation_view(RelationRecipe{owner,payload})=
    (ignore(recipe_view owner);case Synchronized.value payload of SOME p=>
      (require(List.all (fn (input,owner)=>Veri7vn_Native_Literals.retained input andalso
        Veri7vn_Managed_Provenance.owns_input owner input) (#inputs p))
        "Structured relation input invalidated";
       require(List.all(is_some o Veri7vn_Managed_Native_Unit.inspect)(#units p))
         "Structured relation occurrence retired";p)
      | NONE=>error "Structured relation recipe released");
  fun relation_parent(r as RelationRecipe{owner,...})=(ignore(relation_view r);owner);
  fun relation_metadata r= #metadata(relation_view r);
  fun relation_operation r=(ignore(relation_parent r);K.relation_operation);
  fun relation_query (r as RelationRecipe{owner,...}) batch =
    let val {value,...}=relation_view r;
      val config=limits(recipe_instance owner)
    in Timeout.apply(Time.fromSeconds(#seconds config)) (K.query_relation value) batch end;
  (* Extra lifecycle restrictions can only deny use; they never admit evidence. *)
  fun restrict_relation_inputs (r as RelationRecipe{payload,...}) inputs =
    let val _=relation_view r;
      val _=require(List.all (fn (input,owner)=>Veri7vn_Native_Literals.retained input andalso
        Veri7vn_Managed_Provenance.owns_input owner input) inputs) "Relation restriction input unavailable"
    in Synchronized.change payload (fn NONE=>error "Structured relation recipe released"
      | SOME {metadata,value,inputs=old,units}=>SOME{metadata=metadata,value=value,
          inputs=old@inputs,units=units}) end;
  fun restrict_relation_unit (r as RelationRecipe{payload,...}) unit =
    let val _=relation_view r;
      val _=require(is_some(Veri7vn_Managed_Native_Unit.inspect unit)) "Relation occurrence unavailable"
    in Synchronized.change payload(fn NONE=>error "Structured relation recipe released"
      | SOME {metadata,value,inputs,units}=>SOME{metadata=metadata,value=value,
          inputs=inputs,units=unit::units}) end;
  fun relation_input_owners r=map snd (#inputs(relation_view r));
  fun release_relation(RelationRecipe{payload,...})=Synchronized.change payload(K NONE);
  fun release_recipe (Recipe{id,owner=Instance{recipes,...},payload,manifests,relations,...}) =
    (Synchronized.change payload(K NONE);
     List.app(fn RelationRecipe{payload,...}=>Synchronized.change payload(K NONE))
       (Synchronized.change_result relations(fn old=>(old,[])));
     List.app(fn Manifest{payload,...}=>Synchronized.change payload(K NONE))
       (Synchronized.change_result manifests(fn old=>(old,[])));
     Synchronized.change recipes(filter(fn Recipe{id=other,...}=>id<>other)));
  fun release (Instance{payload,recipes,...}) =
    (case Synchronized.change_result payload(fn old=>(old,NONE)) of NONE=>()
    | SOME {policy,generation,...}=>
      (List.app release_recipe(Synchronized.change_result recipes(fn old=>(old,[])));
       A.clear_cached_generation policy generation));
end;
