(* Controlled producers, rather than an arbitrary list of provenance labels.
   Public image/source-owner installation are privileged native-host operations. *)
signature VERI7VN_MANAGED_PROVENANCE =
sig
  type source_owner
  type development
  type consequence
  type construction_scope
  val construction_scope: unit -> construction_scope
  val abort_scope: construction_scope -> unit
  val commit_scope: construction_scope -> unit
  val public_image_owned: construction_scope -> Veri7vn_Native_Identity_Allocator.allocator ->
    Veri7vn_Native_Admission.policy -> development
  val staged_public_image_owned: construction_scope -> Veri7vn_Native_Identity_Allocator.allocator ->
    Veri7vn_Native_Admission.policy -> Veri7vn_Committed_Native_Recovery.committed -> development
  val define_from_slice_owned: construction_scope -> development -> source_owner -> binding ->
    Veri7vn_Native_Literals.slice -> development * term * consequence
  val define_from_embedded_slice_owned: construction_scope -> development -> source_owner -> binding ->
    Veri7vn_Native_Literals.slice -> development * term * consequence
  val context_alias_owned: construction_scope -> development -> development
  val context_alias_with_parents_owned: construction_scope -> development -> development list -> development
  val replay_source_owned: construction_scope -> (string * development) list -> source_owner ->
    Veri7vn_Native_Literals.slice -> development
  val install_host_source: Veri7vn_Native_Identity_Allocator.allocator ->
    Veri7vn_Native_Literals.input -> source_owner
  val restore_source: Veri7vn_Native_Recovery_Source.source -> source_owner
  val source_identity: source_owner -> IntInf.int
  val source_workspace: source_owner -> string
  val owns_input: source_owner -> Veri7vn_Native_Literals.input -> bool
  val public_image: Veri7vn_Native_Identity_Allocator.allocator ->
    Veri7vn_Native_Admission.policy -> development
  val staged_public_image: Veri7vn_Native_Identity_Allocator.allocator ->
    Veri7vn_Native_Admission.policy -> Veri7vn_Committed_Native_Recovery.committed -> development
  val context_alias: development -> development
  val context_alias_with_parents: development -> development list -> development
  val alias_parent: development -> development option
  val restate: development -> consequence -> consequence
  val context_parents: development -> development list
  val context_lineage: development -> Veri7vn_Native_Registry.generation list
  val source_dependencies: consequence -> IntInf.int list
  val generation: development -> Veri7vn_Native_Registry.generation
  val public_theorem: development -> Thm_Name.T -> consequence
  (* RHS is parsed from the exact original source slice by this producer. *)
  val define_from_slice: development -> source_owner -> binding ->
    Veri7vn_Native_Literals.slice -> development * term * consequence
  val define_from_embedded_slice: development -> source_owner -> binding ->
    Veri7vn_Native_Literals.slice -> development * term * consequence
  type definition_recipe = {parent:development,source:source_owner,binding:binding,
    slice:Veri7vn_Native_Literals.slice,embedded:bool}
  val definition_recipe: development -> definition_recipe option
  val consequence_development: consequence -> development
  val source_input: source_owner -> Veri7vn_Native_Literals.input
  val replay_source: (string * development) list -> source_owner ->
    Veri7vn_Native_Literals.slice -> development
  type replay_recipe = {parents:(string * development) list,source:source_owner,
    slice:Veri7vn_Native_Literals.slice}
  val replay_recipe: development -> replay_recipe option
  val named_theorem: development -> Thm_Name.T -> consequence
  val public_name: consequence -> Thm_Name.T option
  val accepted: consequence -> Veri7vn_Native_Admission.accepted
  val dependencies: consequence -> IntInf.int list
  val workspace: consequence -> string
  val is_live: consequence -> bool
  val release: development -> unit
end;
structure Veri7vn_Managed_Provenance :> VERI7VN_MANAGED_PROVENANCE =
struct
  structure A = Veri7vn_Native_Admission;
  structure R = Veri7vn_Native_Registry;
  structure L = Veri7vn_Native_Literals;
  structure I = Veri7vn_Native_Identity_Allocator;
  structure U = Veri7vn_Managed_Native_Unit;
  structure S = Veri7vn_Native_Recovery_Source;
  structure C = Veri7vn_Committed_Native_Recovery;
  datatype source_owner = Source of {input:L.input,id:IntInf.int,workspace:string};
  datatype development = Development of {id:serial,payload:payload option Synchronized.var}
  withtype payload = {allocator:I.allocator,policy:A.policy,
    generation:R.generation,unit:U.token,parents:development list,sources:source_owner list,
    alias_parent:development option,staging:C.committed option Synchronized.var,
    public:bool,replay:{parents:(string*development)list,source:source_owner,slice:L.slice}option,
    recipe:{parent:development,source:source_owner,binding:binding,
      slice:L.slice,embedded:bool} option,
    consequences:A.accepted option Synchronized.var list Synchronized.var,
    children:development list Synchronized.var};
  type definition_recipe = {parent:development,source:source_owner,binding:binding,
    slice:L.slice,embedded:bool};
  type replay_recipe={parents:(string*development)list,source:source_owner,slice:L.slice};
  datatype consequence = Consequence of {development:development,
    accepted:A.accepted option Synchronized.var,public_name:Thm_Name.T option};
  datatype construction_scope = ConstructionScope of
    development list option Synchronized.var;
  fun construction_scope ()=ConstructionScope(Synchronized.var "native_construction_scope"(SOME []));
  (* Detach only this island. Shared parents and input owners belong to the
     coordinator's refcount closure, and are never recursively forgotten here. *)
  fun release development = Thread_Attributes.uninterruptible (fn _=>fn () =>
    let
      (* Only fixed native-root cleanup is masked. Resource cancellation/join
         belongs to the outer lifecycle before this ownership transition. *)
      fun drain []=()
        | drain (Development {payload=cell,...}::pending)=
          (case Synchronized.change_result cell (fn old=>(old,NONE)) of
            NONE=>drain pending
          | SOME {allocator,unit,policy,generation,consequences,children,...}=>
            let val owned=Synchronized.change_result children (fn old=>(old,[]))
              val facts=Synchronized.change_result consequences (fn old=>(old,[]))
              val _=List.app (fn c=>Synchronized.change c (K NONE)) facts
              val _=A.clear_cached_generation policy generation
              val _=Veri7vn_Proof_Transport.release_generation generation
              val detached=U.release unit
              val _=Option.app (fn {inputs,...}=>List.app I.release_disposed_input
                (filter L.disposed inputs))detached
              val _=I.release_generation allocator generation
            in drain(owned @ pending) end)
    in drain[development] end) ();

  fun abort_scope (ConstructionScope state)=Thread_Attributes.uninterruptible(fn _=>fn()=>
    let val owned=Synchronized.change_result state(fn old=>(the_default [] old,NONE))
    in List.app release owned end)();
  fun commit_scope (ConstructionScope state)=Thread_Attributes.uninterruptible(fn _=>fn()=>
    Synchronized.change state(fn old=>case old of NONE=>error "Native construction scope already closed"
      | SOME _=>NONE))();
  fun scope_register NONE _=()
    | scope_register (SOME(ConstructionScope state)) development=
      Synchronized.change state(fn old=>case old of
        NONE=>error "Native construction scope closed during publication"
      | SOME owned=>if length owned>=512 then error "Native construction scope bound"
        else SOME(development::owned));
  fun view (Development {payload=cell,...}) = (case Synchronized.value cell of SOME p => p
    | NONE => error "Managed native development is unavailable");
  fun make_development (p:payload)=Development {id=serial(),
    payload=Synchronized.var "veri7vn_managed_development" (SOME p)};
  fun same_development (Development {id=a,...},Development {id=b,...})=a=b;
  fun make_consequence (development as Development {payload=root,...}) name accepted =
    let val cell=Synchronized.var "veri7vn_managed_consequence" (SOME accepted)
      val installed=Synchronized.change_result root (fn payload =>
        (case payload of NONE => (false,NONE)
        | SOME (p as {consequences,...}) =>
          (Synchronized.change consequences (cons cell);(true,SOME p))))
      val _=if installed then () else
        (Synchronized.change cell (K NONE);error "Managed native development was released")
    in Consequence {development=development,accepted=cell,public_name=name} end;
  fun register_child (Development {payload=root,...}) child =
    Synchronized.change_result root (fn payload =>
      (case payload of NONE => (false,NONE)
      | SOME (p as {children,...}) =>
        (Synchronized.change children (cons child);(true,SOME p))));
  fun install_host_source allocator input =
    let val id=I.input_identity allocator input
    in Source{input=input,id=id,workspace=I.workspace allocator}end;
  (* Saved identity comes from the fixed protected source checker. Its numeric
     association is installed only with the complete verified restore batch. *)
  fun restore_source checked =
    Source{input=S.input checked,id=S.identity checked,workspace=S.workspace checked};
  fun source_identity (Source {id,...}) = id;
  fun source_workspace (Source {workspace,...}) = workspace;
  fun source_input (Source {input,...}) = input;
  fun owns_input (Source {input,...}) other = L.same_input (input,other);
  fun managed_unit (owned:U.view) registry =
    (case Exn.capture (U.create owned) registry of Exn.Res unit=>unit
    | Exn.Exn exn=>(List.app I.release_disposed_input
        (filter L.disposed (#inputs owned));Exn.reraise exn));
  type construction = {scope:construction_scope option,allocator:I.allocator,policy:A.policy,generation:R.generation,
    staging:C.committed option,parents:development list,sources:source_owner list,
    alias_parent:development option,public:bool,recipe:definition_recipe option,replay:replay_recipe option,
    inputs:L.input list,objects:R.object_handle list,registry:R.registry,
    owners:development list,consequence:(Thm_Name.T option * A.accepted) option};
  fun publish (c:construction)=Thread_Attributes.uninterruptible(fn _=>fn()=>
    let val unit=Unsynchronized.ref(NONE:U.token option)
      val development=Unsynchronized.ref(NONE:development option)
      val result=Exn.capture(fn()=>
        let val _=(case #staging c of NONE=>ignore(I.generation_id(#allocator c)(#generation c))
              | SOME _=>I.mark_staged_generation(#allocator c)(#generation c))
          val owned=managed_unit {generation= #generation c,inputs= #inputs c,
            objects= #objects c}(#registry c)
          val _=unit:=SOME owned
          val d=make_development{allocator= #allocator c,policy= #policy c,
            generation= #generation c,unit=owned,parents= #parents c,sources= #sources c,
            alias_parent= #alias_parent c,staging=Synchronized.var "development_staging" (#staging c),
            public= #public c,recipe= #recipe c,replay= #replay c,
            consequences=Synchronized.var "development_consequences" [],
            children=Synchronized.var "development_children" []}
          val _=development:=SOME d
          val _=scope_register(#scope c)d
          val _=List.app(fn parent=>if register_child parent d then ()
            else error "Native development owner retired")(#owners c)
          val fact=Option.map(fn(name,a)=>make_consequence d name a)(#consequence c)
        in(d,fact)end)()
    in case result of Exn.Res value=>value | Exn.Exn exn=>
      (Option.app release (!development);
       Option.app(fn owned=>Option.app(fn {inputs,...}=>List.app I.release_disposed_input
         (filter L.disposed inputs))(U.release owned))(!unit);
       List.app I.release_disposed_input(filter L.disposed(#inputs c));
       A.clear_cached_generation(#policy c)(#generation c);
       Veri7vn_Proof_Transport.release_generation(#generation c);
       I.release_generation(#allocator c)(#generation c);
       Exn.reraise exn)
    end)();
  fun image scope staging allocator approved_policy =
    let val thy=A.policy_theory approved_policy
      (* Rebuild a global public context and fresh cache policy. Never retain a
         caller's private local context or private accepted theorem here. *)
      val policy=A.policy thy
      val generation=R.generation (Proof_Context.init_global thy)
        {packages=[],runtime="trusted-native-image",policy="kernel",sources=[],
         interpretation="exact-native-proposition"}
    in #1(publish{scope=scope,allocator=allocator,policy=policy,generation=generation,
      staging=staging,parents=[],sources=[],alias_parent=NONE,public=true,recipe=NONE,
      inputs=[],objects=[],registry=R.empty,owners=[],consequence=NONE,replay=NONE})end;
  val public_image=image NONE NONE;
  fun public_image_owned scope=image(SOME scope)NONE;
  fun staged_image scope allocator policy committed =
    if #workspace(C.materials committed)=I.workspace allocator then image scope (SOME committed) allocator policy
    else error "Staged native context workspace mismatch";
  val staged_public_image=staged_image NONE;
  fun staged_public_image_owned scope=staged_image(SOME scope);
  fun generation development = #generation (view development);
  fun available_development registered (Development {payload=cell,...}) =
    (case Synchronized.value cell of NONE=>false
    | SOME {unit,parents,sources,alias_parent,staging,allocator,generation,...}=>
      let val assigned=is_some(I.lookup_generation_id allocator generation)
        val mapped_sources=forall(fn Source{input,id,workspace}=>
          workspace=I.workspace allocator andalso
          I.lookup_input_identity allocator input=SOME id)sources
        val published=assigned andalso mapped_sources
        val material=published orelse (not registered andalso
          (case Synchronized.value staging of SOME c=>C.is_live c | NONE=>false))
        val _=if published then Synchronized.change staging (K NONE) else ()
      in material andalso is_some(U.inspect unit) andalso
        forall (available_development registered) parents andalso
        (case alias_parent of NONE=>true | SOME p=>available_development registered p) andalso
        forall (fn Source {input,...}=>L.retained input) sources end);
  val live_development=available_development true;
  fun check_live development=if available_development false development then ()
    else error "Managed native development is unavailable";
  fun admit policy generation theorem =
    let val thy=Proof_Context.theory_of (R.context generation)
      val th=Thm.transfer thy theorem
      val target=Thm.cterm_of (R.context generation) (Thm.prop_of th)
      val (h,r)=R.insert generation "managed-producer" (R.Theorem th) R.empty
    in case A.admit policy generation r h A.Kernel
      {claim=A.exact_claim target,hypotheses=Thm.hyps_of th,
       premises=Thm.prems_of th,sorts=Thm.shyps_of th} of
      A.Accepted accepted => (accepted,h,r)
    | A.Rejected reasons => error (space_implode "; " reasons) end;
  fun public_theorem development name =
    let val _=check_live development
      val {public,policy,generation,...}=view development
      val _=if public then () else error "Named public theorem requires a public image"
      val th=Global_Theory.get_thm_name (A.policy_theory policy) (name,Position.none)
      val (accepted,_,_)=admit policy generation th
    in make_consequence development (SOME name) accepted end;
  fun define_source scope embedded parent
      (source as Source {input,id=_,workspace}) binding slice =
    Timeout.apply (Time.fromSeconds 5) (fn () =>
      let val _=check_live parent
        val {allocator,policy,generation,...}=view parent
        val _=if I.workspace allocator=workspace andalso L.same_input (input,L.owner slice)
          andalso L.retained input then () else error "Definition source ownership mismatch"
        val _=if L.encoding input="UTF-8" then () else error "Unsupported native source encoding"
        val bytes=L.original slice
        val _=if size bytes<=100000 then () else error "Definition source byte bound"
        val ctxt=R.context generation
        val term_source=if embedded then
          let val tokens=Token.explode (Thy_Header.get_keywords (Proof_Context.theory_of ctxt))
              Position.none bytes |> filter Token.is_proper
            val _=case tokens of [tok] =>
              (case Token.kind_of tok of Token.String => () | Token.Cartouche => ()
               | _ => error "Expected a native embedded term token")
              | _ => error "Expected exactly one embedded term token"
          in case Scan.read Token.stopper Parse.term tokens of
            SOME text => text | NONE => error "Malformed embedded native term" end
          else bytes
        val rhs=Syntax.read_term ctxt term_source
        val _=if Term.size_of_term rhs<=20000 then () else error "Definition term bound"
        val (policy',constant,definition,thy)=A.define policy binding (Thm.cterm_of ctxt rhs)
        val gen=R.generation (Proof_Context.init_global thy) (R.dependencies generation)
        val (accepted,h,r)=admit policy' gen definition
        val (development,fact)=publish{scope=scope,allocator=allocator,policy=policy',generation=gen,
          staging=Synchronized.value(#staging(view parent)),parents=[parent],sources=[source],
          alias_parent=NONE,public=false,
          recipe=SOME{parent=parent,source=source,binding=binding,slice=slice,embedded=embedded},
          inputs=[input],objects=[h],registry=r,owners=[parent],consequence=SOME(NONE,accepted),replay=NONE}
      in case fact of SOME consequence=>(development,constant,consequence)
        | NONE=>(release development;error "Native consequence publication invariant")end)();
  val define_from_slice=define_source NONE false;
  val define_from_embedded_slice=define_source NONE true;
  fun define_from_slice_owned scope=define_source(SOME scope)false;
  fun define_from_embedded_slice_owned scope=define_source(SOME scope)true;
  fun logical_nodes development =
    let fun walk [] _ acc=rev acc
          | walk ((d as Development {id,...})::todo) seen acc=
            if Inttab.defined seen id then walk todo seen acc
            else let val p=view d
              in walk (#parents p @ todo) (Inttab.update(id,()) seen) (d::acc) end
    in walk [development] Inttab.empty [] end;
  fun all_sources development=maps (fn d=> #sources(view d)) (logical_nodes development);
  fun same_source (Source {id=a,workspace=w,input=x},Source {id=b,workspace=v,input=y})=
    a=b andalso w=v andalso L.same_input(x,y);
  fun sources_equal xs ys=forall (fn x=>exists (fn y=>same_source(x,y)) ys) xs andalso
    forall (fn y=>exists (fn x=>same_source(x,y)) xs) ys;
  fun alias_context scope parent logical_parents =
    let val _=check_live parent
      val old=view parent
      val originals= #parents old
      val _=if length originals=length logical_parents andalso
        ListPair.allEq (fn (a,b)=>
          (check_live b;
           I.workspace(#allocator(view a))=I.workspace(#allocator(view b)) andalso
           Context.eq_thy(Proof_Context.theory_of(R.context(#generation(view a))),
             Proof_Context.theory_of(R.context(#generation(view b)))))) (originals,logical_parents)
        andalso sources_equal (maps all_sources originals) (maps all_sources logical_parents)
        then () else error "Context alias changes logical native ancestry/source ownership"
      val generation=R.generation (R.context (#generation old)) (R.dependencies (#generation old))
    in #1(publish{scope=scope,allocator= #allocator old,policy= #policy old,generation=generation,
      staging=Synchronized.value(#staging old),parents=logical_parents,sources= #sources old,
      alias_parent=SOME parent,public=false,recipe=NONE,
      inputs=map source_input(#sources old),objects=[],registry=R.empty,
      owners=[parent],consequence=NONE,replay=NONE})end;
  val context_alias_with_parents=alias_context NONE;
  fun context_alias parent=alias_context NONE parent (#parents(view parent));
  fun context_alias_with_parents_owned scope=alias_context(SOME scope);
  fun context_alias_owned scope parent=alias_context(SOME scope)parent(#parents(view parent));
  fun alias_parent development= #alias_parent (view development);
  fun restate alias (Consequence {development=original,accepted=cell,public_name}) =
    let val _=check_live alias
      val _=check_live original
      val _=(case alias_parent alias of SOME parent=>
        if same_development(parent,original) then () else error "Native restatement owner mismatch"
        | NONE=>error "Native restatement requires an actual context alias")
      val original_thm=(case Synchronized.value cell of SOME a=>A.theorem a
        | NONE=>error "Native original consequence released")
      val {policy,generation,...}=view alias
      val (accepted,_,_)=admit policy generation original_thm
    in make_consequence alias public_name accepted end;
  fun replay_owned scope parents (source as Source{input,workspace,...}) slice =
    let val _=if null parents then error "Managed development requires native parents" else ()
      val parent_developments=map #2 parents
      val first=hd parent_developments
      val _=List.app check_live parent_developments
      val allocator= #allocator(view first)
      val _=if workspace=I.workspace allocator andalso
        forall(fn d=>I.workspace(#allocator(view d))=workspace)parent_developments andalso
        L.same_input(input,L.owner slice) andalso L.retained input andalso
        L.encoding input="UTF-8" then () else error "Managed development source/parent ownership mismatch"
      val sourcebytes=L.original slice
      val stage=Synchronized.value(#staging(view first))
      val _=if forall(fn d=>is_some(Synchronized.value(#staging(view d)))=is_some stage)
        parent_developments then () else error "Mixed staged/ordinary development parents"
      val built=Veri7vn_Native_Development.replay_parents
        (map(fn(name,d)=>(name,#policy(view d)))parents)
        {expected_source=sourcebytes,source=sourcebytes,imports=map #1 parents}
      val theory=Veri7vn_Native_Development.theory built
      val policy=Veri7vn_Native_Development.policy built
      val generation=R.generation(Proof_Context.init_global theory)(R.dependencies(#generation(view first)))
      val (development,_)=publish{scope=scope,allocator=allocator,policy=policy,generation=generation,
        staging=stage,parents=parent_developments,sources=[source],alias_parent=NONE,
        public=false,recipe=NONE,replay=SOME{parents=parents,source=source,slice=slice},
        inputs=[input],objects=[],registry=R.empty,owners=parent_developments,consequence=NONE}
    in development end;
  val replay_source=replay_owned NONE;
  fun replay_source_owned scope=replay_owned(SOME scope);
  fun replay_recipe development= #replay(view development);
  fun named_theorem development name =
    let val _=check_live development
      val {policy,generation,...}=view development
      val theorem=Global_Theory.get_thm_name(A.policy_theory policy)(name,Position.none)
      val _=if Thm.get_name_hint theorem=name then ()
        else error "Managed theorem requires its exact canonical native name"
      val (accepted,_,_)=admit policy generation theorem
    in make_consequence development (SOME name) accepted end;
  fun definition_recipe development= #recipe (view development);
  fun consequence_development (Consequence {development,...})=development;
  fun public_name (Consequence {public_name,...}) = public_name;
  fun accepted (Consequence {development,accepted,...}) =
    (check_live development;case Synchronized.value accepted of SOME a => a
      | NONE => error "Managed native consequence is unavailable");
  fun source_ids development=map source_identity (all_sources development);
  fun context_parents development= #parents(view development);
  fun context_lineage development=map (fn d=> #generation(view d)) (logical_nodes development);
  fun source_dependencies (Consequence {development,...}) =
    (check_live development;distinct (op =) (source_ids development));
  fun dependencies (Consequence {development,...}) =
    let val _=if live_development development then ()
        else error "Unregistered managed native dependency correspondence"
      val allocator= #allocator(view development)
      fun identity gen=(case I.lookup_generation_id allocator gen of SOME id=>id
        | NONE=>error "Unregistered staged native context dependency")
    in distinct (op =) (map identity (context_lineage development) @ source_ids development) end;
  fun workspace (Consequence {development,...}) = I.workspace (#allocator (view development));
  fun is_live (Consequence {development,accepted,...}) =
    live_development development andalso is_some (Synchronized.value accepted);

end;
