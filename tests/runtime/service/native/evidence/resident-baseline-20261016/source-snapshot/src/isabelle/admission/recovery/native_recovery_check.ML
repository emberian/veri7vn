(* Protected correspondence witness. Decoded saved IDs never construct native facts. *)
signature VERI7VN_NATIVE_RECOVERY_CHECK =
sig
  type projection = {claim_id:IntInf.int,target_id:IntInf.int,interpretation_id:IntInf.int,
    conditional:bool,premises:IntInf.int list,dependencies:IntInf.int list,
    semantic_generation:IntInf.int}
  type saved = {workspace:string,evidence_id:IntInf.int,projection:projection,
    assumption_ids:IntInf.int list,sort_ids:IntInf.int list}
  type verified
  type image
  type retained_context
  val retain_context:verified->retained_context
  val retain_context_for:verified->IntInf.int->retained_context option
  val retained_generation:retained_context->Veri7vn_Native_Registry.generation
  val release_context:retained_context->unit
  type batch
  type verified_batch
  val active_replays:batch->int
  val restore_batch:unit->batch
  val restore_batch_with:Veri7vn_Native_Recovery_Inputs.pool->batch
  val recheck_in:batch->Veri7vn_Native_Identity_Allocator.allocator->image->
    Veri7vn_Committed_Native_Recovery.committed->verified
  val seal_batch:batch->verified_batch
  val fragment:verified_batch->Veri7vn_Native_Identity_Allocator.fragment
  val abort_batch:batch->unit
  val install_host_image: Veri7vn_Native_Admission.policy -> string -> image
  val encode_projection: saved -> string
  val decode_projection: string -> saved
  val context_closure: image -> string
  val public_recipe: Veri7vn_Managed_Provenance.consequence -> string
  type artifacts = {projection:string,sequent:string,context_closure:string,reconstruction:string}
  val qualify: Veri7vn_Native_Identity_Allocator.allocator -> image ->
    Veri7vn_Managed_Provenance.consequence -> saved -> artifacts
  val recheck: Veri7vn_Native_Identity_Allocator.allocator ->
    image -> Veri7vn_Committed_Native_Recovery.committed -> verified
  val claim: verified -> unit
  val saved: verified -> saved
  val consequence: verified -> Veri7vn_Managed_Provenance.consequence
  val release: verified -> unit
end;
structure Veri7vn_Native_Recovery_Check :> VERI7VN_NATIVE_RECOVERY_CHECK =
struct
  structure A=Veri7vn_Native_Admission;
  structure P=Veri7vn_Managed_Provenance;
  structure I=Veri7vn_Native_Identity_Allocator;
  structure C=Veri7vn_Committed_Native_Recovery;
  structure S=Veri7vn_Native_Sequent;
  structure Q=Veri7vn_Native_Recovery_Source;
  structure L=Veri7vn_Native_Literals;
  structure R=Veri7vn_Native_Registry;
  structure G=Veri7vn_Native_Recovery_Graph;
  structure X=Veri7vn_Native_Recovery_Replay;
  type projection = {claim_id:IntInf.int,target_id:IntInf.int,interpretation_id:IntInf.int,
    conditional:bool,premises:IntInf.int list,dependencies:IntInf.int list,
    semantic_generation:IntInf.int};
  type saved = {workspace:string,evidence_id:IntInf.int,projection:projection,
    assumption_ids:IntInf.int list,sort_ids:IntInf.int list};
  type batch=G.batch;
  type verified_batch=G.verified_batch;
  val active_replays=G.active_replays;
  val restore_batch=G.create;
  val restore_batch_with=G.create_with;
  val seal_batch=G.seal;
  val abort_batch=G.abort;
  structure Bind=Veri7vn_Checked_Generation_Reassociation
    (struct type verified=verified_batch val bindings=G.bindings end);
  fun fragment witness=I.combine_fragments[Bind.fragment witness,G.input_fragment witness];
  datatype verified=Verified of {saved:saved,consequence:P.consequence,
    claimed:bool Synchronized.var,lease:G.lease};
  (* Privileged startup boundary: manifest must come from the actual selected
     session build database/heaps, never a client-provided label or current files. *)
  datatype image=Image of {policy:A.policy,manifest:string};
  fun install_host_image policy manifest =
    if size manifest>0 andalso size manifest<=1048576 then Image {policy=policy,manifest=manifest}
    else error "Native recovery boot image manifest bound";
  fun positive n = n>0 andalso size (IntInf.toString n)<=128;
  fun number s = (if size s>128 then error "Recovery ID digit bound" else
    case IntInf.fromString s of SOME n =>
    if positive n andalso IntInf.toString n=s then n else error "Recovery noncanonical ID"
    | NONE => error "Recovery invalid ID");
  fun ids ns=space_implode "," (map IntInf.toString ns);
  fun numbers ""=[] | numbers s=map number (String.tokens (fn c=>c= #",") s);
  fun validate (s:saved) =
    let val p= #projection s
      val own= #evidence_id s :: #claim_id p :: #target_id p :: #interpretation_id p ::
        #semantic_generation p :: #premises p
      val _=if forall positive own andalso length (distinct (op =) own)=length own
        then () else error "Recovery ID domains overlap/invalid"
      val _=if #premises p= #assumption_ids s @ #sort_ids s andalso
        #dependencies p<>[] andalso hd (#dependencies p)= #semantic_generation p andalso
        forall positive (#dependencies p) andalso
        length(distinct(op =)(#dependencies p))=length(#dependencies p) andalso
        #conditional p=not (null (#premises p)) then ()
        else error "Recovery projection dependency/condition/role mismatch"
      val _=if forall(fn id=>not(member(op =) own id))(tl(#dependencies p)) then ()
        else error "Recovery source IDs overlap native object identity domains"
    in s end;
  fun encode_projection s =
    let val s=validate s val p= #projection s
    in YXML.string_of_body [XML.Elem (("veri7vn-native-projection",
      [("version","1"),("workspace",#workspace s),("evidence",IntInf.toString (#evidence_id s)),
       ("claim",IntInf.toString (#claim_id p)),("target",IntInf.toString (#target_id p)),
       ("interpretation",IntInf.toString (#interpretation_id p)),
       ("generation",IntInf.toString (#semantic_generation p)),
       ("conditional",Bool.toString (#conditional p)),("assumptions",ids (#assumption_ids s)),
       ("sorts",ids (#sort_ids s)),("dependencies",ids (#dependencies p))]),[])] end;
  fun decode_projection bytes =
    let val _=if size bytes<=1048576 then () else error "Recovery projection byte bound"
      (* Fixed shallow schema, including canonical re-encoding; do not accept an
         unbounded nested XML tree merely because its outer fields look right. *)
      val _=if length (String.fields (fn c=>c=Char.chr 5) bytes)=5
        then () else error "Recovery projection framing"
      val s=(case YXML.parse_body bytes of
        [XML.Elem (("veri7vn-native-projection",attrs),[])] =>
          let fun f k=the (AList.lookup (op =) attrs k)
            val _=if f "version"="1" then () else error "Recovery projection version"
            val assumptions=numbers (f "assumptions") val sorts=numbers (f "sorts")
            val conditional=case f "conditional" of "true"=>true | "false"=>false
              | _=>error "Recovery conditional field"
          in {workspace=f "workspace",evidence_id=number (f "evidence"),
            assumption_ids=assumptions,sort_ids=sorts,
            projection={claim_id=number (f "claim"),target_id=number (f "target"),
              interpretation_id=number (f "interpretation"),semantic_generation=number (f "generation"),
              conditional=conditional,premises=assumptions@sorts,dependencies=numbers (f "dependencies")}} end
        | _=>error "Recovery projection schema")
      val _=if encode_projection s=bytes then () else error "Recovery noncanonical projection"
    in s end;
  fun context_closure (Image {policy,manifest}) =
    let val thy=A.policy_theory policy
    in YXML.string_of_body [XML.Elem (("veri7vn-canonical-public-image",[("version","1")]),
      XML.Encode.pair XML.Encode.string (XML.Encode.list XML.Encode.string)
        (manifest,map (Context.theory_name {long=true}) (thy :: Context.ancestors_of thy)))] end;
  fun public_recipe consequence =
    (case P.public_name consequence of SOME name =>
      YXML.string_of_body [XML.Elem (("veri7vn-public-theorem",[("version","1")]),Thm_Name.encode name)]
    | NONE=>error "Native consequence has no canonical public reconstruction profile");
  fun recipe_bounds bytes =
    let val n=size bytes
      fun scan i depth nodes =
        if i>=n then if depth=0 then () else error "Recovery recipe framing"
        else if String.sub(bytes,i)=Char.chr 5 andalso i+1<n andalso String.sub(bytes,i+1)=Char.chr 6
        then if i+2<n andalso String.sub(bytes,i+2)=Char.chr 5
          then if depth>0 then scan (i+3) (depth-1) nodes else error "Recovery recipe closing frame"
          else if depth<16 andalso nodes<2048 then scan (i+2) (depth+1) (nodes+1)
          else error "Recovery recipe framing bound"
        else scan (i+1) depth nodes
    in if n<=100000 then scan 0 0 0 else error "Recovery recipe byte bound" end;
  fun read_recipe bytes =
    (recipe_bounds bytes; case YXML.parse_body bytes of
      [XML.Elem (("veri7vn-public-theorem",[("version","1")]),body)]=>Thm_Name.decode body
    | _=>error "Unregistered native reconstruction profile");
  type step=G.step;
  type description=G.description;
  fun identity allocator development =
    (case I.lookup_generation_id allocator(P.generation development)of SOME id=>id
    | NONE=>error "Export native construction has no canonical context identity");
  fun native_recipe development =case P.definition_recipe development of SOME r=>SOME r
    | NONE=>(case P.alias_parent development of SOME parent=>native_recipe parent | NONE=>NONE);
  fun collect allocator development =
    let fun walk depth dev steps owners =if depth>128 then error "Recovery definition chain bound"
      else case native_recipe dev of NONE=>
        if null(P.context_parents dev)then
          (dev,{base_id=identity allocator dev,steps=steps}:description,owners)
        else error "Unregistered native context construction recipe"
      | SOME {source,binding,slice,embedded,...}=>
        let val parent=case P.context_parents dev of [p]=>p
              | _=>error "Definition reconstruction requires its exact parent context"
          val name=Binding.name_of binding
          val _=if Binding.reset_pos binding=Binding.name name then ()
            else error "Definition binding needs a registered exact recovery representation"
          val {start,stop}=L.offsets slice
          val step={context_id=identity allocator dev,source_id=P.source_identity source,
            start=start,stop=stop,name=name,embedded=embedded}:step
        in walk(depth+1)parent(step::steps)(source::owners)end
    in walk 0 development [] [] end;
  val step_enc=XML.Encode.list(XML.Encode.pair XML.Encode.string(XML.Encode.pair XML.Encode.string
    (XML.Encode.pair XML.Encode.int(XML.Encode.pair XML.Encode.int
      (XML.Encode.pair XML.Encode.string XML.Encode.bool)))));
  val step_dec=XML.Decode.list(XML.Decode.pair XML.Decode.string(XML.Decode.pair XML.Decode.string
    (XML.Decode.pair XML.Decode.int(XML.Decode.pair XML.Decode.int
      (XML.Decode.pair XML.Decode.string XML.Decode.bool)))));
  fun encode_steps({base_id,steps}:description)=YXML.string_of_body[XML.Elem
    (("veri7vn-controlled-definitions",[("version","2"),("base-context",IntInf.toString base_id)]),
      step_enc(map(fn{context_id,source_id,start,stop,name,embedded}:step=>
        (IntInf.toString context_id,(IntInf.toString source_id,(start,(stop,(name,embedded))))))steps))];
  fun decode_steps bytes=
    let val _=recipe_bounds bytes
      val (base,rows)=case YXML.parse_body bytes of
        [XML.Elem(("veri7vn-controlled-definitions",[("version","2"),("base-context",base)]),body)]=>
          (number base,step_dec body)
      | _=>error "Controlled definition context recipe schema"
      val desc={base_id=base,steps=map(fn(ctx,(src,(start,(stop,(name,embedded)))))=>
        {context_id=number ctx,source_id=number src,start=start,stop=stop,name=name,embedded=embedded}:step)rows}
      val _=if not(null(#steps desc)) andalso length(#steps desc)<=128 andalso encode_steps desc=bytes
        then()else error "Controlled definition recipe canonical bounds"
    in desc end;
  fun context_ids({base_id,steps}:description)=rev(base_id::map #context_id steps);
  fun source_ids({steps,...}:description)=distinct(op =)(rev(map #source_id steps));
  fun validate_description saved desc =
    let val contexts=context_ids desc val sources=source_ids desc
      val _=if #semantic_generation(#projection saved)=hd contexts andalso
        #dependencies(#projection saved)=contexts@sources andalso
        length(distinct(op =)contexts)=length contexts then()
        else error "Saved complete logical context/source closure differs from construction"
    in()end;
  fun ordinary_replay scope allocator policy obtain (desc:description)=
    let val root=P.public_image_owned scope allocator policy
      fun next(s:step)(parent,_) =
        let val source=obtain(#source_id s)val input=P.source_input source val bytes=L.bytes input
          val start= #start s val stop= #stop s
          val _=if start>=0 andalso stop>=start andalso stop<=size bytes then()
            else error "Definition qualification slice bounds"
          val slice=L.slice input{start=start,stop=stop,expected=String.substring(bytes,start,stop-start)}
          val(dev,_,c)=(if #embedded s then P.define_from_embedded_slice_owned scope else P.define_from_slice_owned scope)
            parent source(Binding.name(#name s))slice
        in(dev,SOME c)end
      val result=Exn.capture(fn()=>fold next(#steps desc)(root,NONE))()
    in case result of Exn.Res(_,SOME c)=>(root,c)
      | Exn.Res _=>(P.release root;error "Empty private definition qualification")
      | Exn.Exn exn=>(P.release root;Exn.reraise exn)end;
  type artifacts={projection:string,sequent:string,context_closure:string,reconstruction:string};
  fun qualify_basic_owned scope allocator(image as Image{policy,...}) consequence saved =
    let val _=if I.workspace allocator=P.workspace consequence andalso #workspace saved=P.workspace consequence
        andalso P.is_live consequence then()else error "Recovery export workspace/producer unavailable"
      val accepted=P.accepted consequence
      val snapshot=S.capture(A.target accepted)(A.theorem accepted)
      val sequent=S.encode snapshot
      val decoded=S.decode{max_bytes=1048576,max_depth=256,max_nodes=100000}sequent
      val projection=encode_projection saved val _=ignore(decode_projection projection)
      val (base,desc,owners)=collect allocator(P.consequence_development consequence)
      val _=if Context.eq_thy(Proof_Context.theory_of(R.context(P.generation base)),A.policy_theory policy)
        then()else error "Native construction baseline differs from installed image"
      val _=validate_description saved desc
      val _=if P.dependencies consequence= #dependencies(#projection saved)then()
        else error "Exported native projection omits actual logical context/source dependencies"
      val (development,fresh,closure,recipe)=case P.public_name consequence of SOME name=>
        let val _=if null(#steps desc)then()else error "Public theorem name attached to private construction"
          val dev=P.public_image_owned scope allocator policy val result=Exn.capture(P.public_theorem dev)name
        in case result of Exn.Res c=>(dev,c,context_closure image,public_recipe consequence)
          | Exn.Exn exn=>(P.release dev;Exn.reraise exn)end
      | NONE=>
        let fun owner id=the(find_first(fn source=>P.source_identity source=id)owners)
          val records=map(fn id=>let val input=P.source_input(owner id)
            in{id=id,encoding=L.encoding input,bytes=L.bytes input}:Q.source_record end)(source_ids desc)
          val closure=Q.encode{image=context_closure image,sources=records}
          val _=ignore(Q.decode closure)val recipe=encode_steps desc val _=ignore(decode_steps recipe)
          val(dev,c)=ordinary_replay scope allocator policy owner desc
        in(dev,c,closure,recipe)end
      fun check()=
        let val a=P.accepted fresh val th=A.theorem a
          val _=if S.matches decoded(A.target a)th andalso
            length(#assumption_ids saved)=length(Thm.hyps_of th@Thm.prems_of th)andalso
            length(#sort_ids saved)=length(Thm.shyps_of th)andalso
            P.source_dependencies fresh=source_ids desc andalso
            length(P.context_lineage(P.consequence_development fresh))=length(context_ids desc)
            then()else error "Native registered recipe is not exactly reconstructable"
        in{projection=projection,sequent=sequent,context_closure=closure,reconstruction=recipe}end
      val result=Exn.capture check()val _=P.release development
    in Exn.release result end;
  fun qualify_basic allocator image consequence saved=
    Thread_Attributes.with_attributes Thread_Attributes.no_interrupts(fn original=>
      let val scope=P.construction_scope()
        val result=Exn.capture(fn()=>Thread_Attributes.with_attributes original
          (fn _=>qualify_basic_owned scope allocator image consequence saved))()
        val _=P.abort_scope scope
      in Exn.release result end);
  fun qualify allocator(image as Image{policy,...}) consequence saved =
    if not(X.has_replay(P.consequence_development consequence))then qualify_basic allocator image consequence saved
    else let val _=if I.workspace allocator=P.workspace consequence andalso #workspace saved=P.workspace consequence
          andalso P.is_live consequence then()else error "Expert replay export producer/workspace unavailable"
      val name=case P.public_name consequence of SOME n=>n|NONE=>error "Expert replay requires exact named theorem"
      val(recipe,owners)=X.collect allocator(P.consequence_development consequence)name
      val graph= #graph recipe val contexts=X.context_ids graph val sources=X.source_ids graph
      val _=if #semantic_generation(#projection saved)=hd contexts andalso
        #dependencies(#projection saved)=contexts@sources andalso P.dependencies consequence=contexts@sources
        then()else error "Expert replay saved complete dependency closure differs"
      val _=List.app(fn(n:G.construction_node)=>case #construction n of G.Public=>
        let val generation=the(find_first(fn gen=>I.lookup_generation_id allocator gen=SOME(#context_id n))
            (P.context_lineage(P.consequence_development consequence)))
        in if Context.eq_thy(Proof_Context.theory_of(R.context generation),A.policy_theory policy)then()
          else error "Expert replay public parent differs from installed image"end|_=>())(#nodes graph)
      fun owner id=the(find_first(fn source=>P.source_identity source=id)owners)
      val records=map(fn id=>let val input=P.source_input(owner id)
        in{id=id,encoding=L.encoding input,bytes=L.bytes input}:Q.source_record end)sources
      val closure=Q.encode{image=context_closure image,sources=records}val _=ignore(Q.decode closure)
      val wire=X.encode recipe val _=ignore(X.decode wire)
      val projection=encode_projection saved val _=ignore(decode_projection projection)
      val accepted=P.accepted consequence val snapshot=S.capture(A.target accepted)(A.theorem accepted)
      val sequent=S.encode snapshot val decoded=S.decode{max_bytes=1048576,max_depth=256,max_nodes=100000}sequent
    in Thread_Attributes.with_attributes Thread_Attributes.no_interrupts(fn original=>
      let val scope=P.construction_scope()
      val checked=Exn.capture(fn()=>Thread_Attributes.with_attributes original(fn _=>
        let val fresh=X.ordinary scope allocator policy owner recipe
          val a=P.accepted fresh val th=A.theorem a
        val _=if S.matches decoded(A.target a)th andalso
          length(#assumption_ids saved)=length(Thm.hyps_of th@Thm.prems_of th)andalso
          length(#sort_ids saved)=length(Thm.shyps_of th)andalso P.source_dependencies fresh=sources andalso
          length(P.context_lineage(P.consequence_development fresh))=length contexts then()
          else error "Expert named theorem is not exactly reconstructable"
        in{projection=projection,sequent=sequent,context_closure=closure,reconstruction=wire}:artifacts end))()
      val _=P.abort_scope scope
      in Exn.release checked end)end;
  fun recheck_in batch allocator(image as Image{policy,...}) committed =
    let val _=if G.is_open batch then()else error "Recovery batch is sealed/aborted"
      fun run()=
      let val m=C.materials committed
        val manifest=Veri7vn_Recovery_Manifest.decode{max_bytes=8192}(#manifest m)
        val _=Veri7vn_Recovery_Manifest.require_profile Veri7vn_Recovery_Manifest.KernelEvidence manifest
        fun integrity(digest,bytes)=if Message_Digest.rep(SHA256.digest bytes)=digest then()
          else error "Native recovery named slot integrity mismatch"
        val _=List.app integrity[(#projection manifest,#projection m),(#sequent manifest,#sequent m),
          (#context_closure manifest,#context_closure m),(#payload manifest,#reconstruction m)]
        val saved=decode_projection(#projection m)
        val _=if I.workspace allocator= #workspace m andalso #workspace saved= #workspace m andalso
          #evidence_id saved= #association m andalso #semantic_generation(#projection saved)= #semantic_generation m
          then()else error "Recovery workspace/association/generation mismatch"
        val snapshot=S.decode{max_bytes=1048576,max_depth=256,max_nodes=100000}(#sequent m)
        val controlled=case C.reconstruction committed of Veri7vn_Recovery_Manifest.Controlled_Recipe=>true|_=>false
        val expert=controlled andalso X.is_recipe(#reconstruction m)
        val (lease,original,contexts,sources)=if expert then
          let val recipe=X.decode(#reconstruction m)val graph= #graph recipe
            val contexts=X.context_ids graph val sources=X.source_ids graph val closure=Q.decode(#context_closure m)
            val _=if #image closure=context_closure image andalso map #id(#sources closure)=sources andalso
              #semantic_generation(#projection saved)=hd contexts andalso #dependencies(#projection saved)=contexts@sources
              then()else error "Expert replay image/context/source closure mismatch"
            val lease=G.acquire_graph batch allocator policy(context_closure image)committed graph
          in(lease,(fn()=>P.named_theorem(G.canonical_development lease)(#name recipe)),contexts,sources)end
        else let val(desc,name)=case C.reconstruction committed of
            Veri7vn_Recovery_Manifest.Fixed_Certificate=>
              (if #context_closure m=context_closure image then()else error "Recovery public image mismatch";
               ({base_id= #semantic_generation(#projection saved),steps=[]}:description,SOME(read_recipe(#reconstruction m))))
          | Veri7vn_Recovery_Manifest.Controlled_Recipe=>
              let val closure=Q.decode(#context_closure m)val desc=decode_steps(#reconstruction m)
                val _=if #image closure=context_closure image andalso map #id(#sources closure)=source_ids desc
                  then()else error "Controlled context image/source closure mismatch"
              in(desc,NONE)end
          | _=>error "Unregistered native proof reconstruction profile"
          val _=validate_description saved desc
          val lease=G.acquire batch allocator policy(context_closure image)committed desc
          fun original()=case name of SOME n=>P.public_theorem(G.canonical_development lease)n|NONE=>the(G.definition lease)
        in(lease,original,context_ids desc,source_ids desc)end
        fun verify()=
          let val consequence=P.restate(G.development lease)(original())
            val a=P.accepted consequence val th=A.theorem a
            val _=if S.matches snapshot(A.target a)th andalso
              length(#assumption_ids saved)=length(Thm.hyps_of th@Thm.prems_of th)andalso
              length(#sort_ids saved)=length(Thm.shyps_of th)andalso
              P.source_dependencies consequence=sources andalso
              length(P.context_lineage(P.consequence_development consequence))=length contexts
              then()else error "Rechecked native complete sequent/context/source correspondence mismatch"
            val _=G.checked lease
          in Verified{saved=saved,consequence=consequence,lease=lease,
            claimed=Synchronized.var "veri7vn_recovery_claimed" false}end
        val result=Exn.capture verify()
      in case result of Exn.Res v=>v|Exn.Exn exn=>(G.release lease;Exn.reraise exn)end
      val result=Exn.capture run()
    in case result of Exn.Res v=>v|Exn.Exn exn=>(G.abort batch;Exn.reraise exn)end;
  fun recheck allocator image committed =
    let val batch=restore_batch()
      fun run()=let val v=recheck_in batch allocator image committed
          val witness=seal_batch batch val _=I.install_fragments allocator[fragment witness]
        in v end
      val result=Exn.capture run()
    in case result of Exn.Res v=>v|Exn.Exn exn=>(abort_batch batch;Exn.reraise exn)end;
  fun claim(Verified{claimed,lease,...})=(ignore(G.development lease);
    Synchronized.change claimed(fn false=>true|true=>error "Native recovery witness already installed"));
  fun saved(Verified{saved,...})=saved;
  fun consequence(Verified{consequence,lease,...})=(ignore(G.development lease);consequence);
  datatype retained_context=Retained_Context of G.lease;
  fun retain_context(Verified{lease,...})=Retained_Context(G.retain lease);
  fun retain_context_for(Verified{lease,...}) id=Option.map Retained_Context(G.retain_for lease id);
  fun retained_generation(Retained_Context lease)=P.generation(G.development lease);
  fun release_context(Retained_Context lease)=G.release lease;
  fun release(Verified{lease,...})=G.release lease;
end;
