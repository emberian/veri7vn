(* Closed inert expert-source construction profile. No method, ML or command
   implementation is transported: P.replay_source is the fixed receiver. *)
structure Veri7vn_Native_Recovery_Replay =
struct
  structure P=Veri7vn_Managed_Provenance;
  structure I=Veri7vn_Native_Identity_Allocator;
  structure L=Veri7vn_Native_Literals;
  structure G=Veri7vn_Native_Recovery_Graph;
  type recipe={graph:G.graph_description,name:Thm_Name.T};
  fun number value=case IntInf.fromString value of SOME n=>
      if n>0 andalso size value<=128 andalso IntInf.toString n=value then n else error "Replay ID bounds"
    | NONE=>error "Replay ID syntax";
  fun integer value=case Int.fromString value of SOME n=>
      if n>=0 andalso Int.toString n=value then n else error "Replay offset canonical form"
    | NONE=>error "Replay offset syntax";
  fun physical d=case P.alias_parent d of SOME parent=>physical parent|NONE=>d;
  fun has_replay d=is_some(P.replay_recipe(physical d)) orelse exists has_replay(P.context_parents d);
  fun collect allocator development name =
    let fun identity d=case I.lookup_generation_id allocator(P.generation d)of SOME id=>id
          | NONE=>error "Replay construction context is not canonically bound"
      fun walk depth d (nodes,owners)=
        let val id=identity d
        in if exists(fn(n:G.construction_node)=> #context_id n=id)nodes then(nodes,owners)
          else if depth>128 orelse length nodes>=128 then error "Replay construction DAG bound"
          else let val parents=P.context_parents d
            val(nodes',owners')=fold(walk(depth+1))parents(nodes,owners)
            val original=physical d
            val(construction,own)=case P.replay_recipe original of
              SOME{parents=named,source,slice}=>
                let val _=if length named=length parents then()else error "Replay logical import arity"
                  val{start,stop}=L.offsets slice
                in(G.Replay{source_id=P.source_identity source,start=start,stop=stop,imports=map #1 named},[source])end
            | NONE=>(case P.definition_recipe original of
                SOME{source,slice,binding,embedded,...}=>
                  let val name=Binding.name_of binding val{start,stop}=L.offsets slice
                    val _=if length parents=1 andalso Binding.reset_pos binding=Binding.name name
                      then()else error "Unsupported exact definition binding/parent in replay DAG"
                  in(G.Definition{source_id=P.source_identity source,start=start,stop=stop,name=name,embedded=embedded},[source])end
              | NONE=>if null parents then(G.Public,[])else error "Unregistered expert construction parent")
            val n={context_id=id,parents=map identity parents,construction=construction}:G.construction_node
          in(nodes'@[n],own@owners')end end
      val(nodes,owners)=walk 0 development([],[])
    in({graph={head=identity development,nodes=nodes},name=name}:recipe,owners)end;
  fun node graph id=the(find_first(fn(n:G.construction_node)=> #context_id n=id)(#nodes(graph:G.graph_description)));
  fun ordered_nodes(graph:G.graph_description)=
    let fun visit id seen=if member(op =)seen id then seen
          else fold visit(#parents(node graph id))(seen@[id])
    in map(node graph)(visit(#head graph)[])end;
  fun context_ids graph=map #context_id(ordered_nodes graph);
  fun source_ids graph=distinct(op =)(map_filter(fn(n:G.construction_node)=>case #construction n of
    G.Public=>NONE|G.Definition{source_id,...}=>SOME source_id|G.Replay{source_id,...}=>SOME source_id)(ordered_nodes graph));
  fun attrs name fields=XML.Elem((name,fields),[]);
  fun encode({graph={head,nodes},name=(theorem,index)}:recipe)=
    let fun row({context_id,parents,construction}:G.construction_node)=
        let val(kind,fields,imports)=case construction of G.Public=>("public",[],[])
          | G.Definition{source_id,start,stop,name,embedded}=>("definition",
              [("source",IntInf.toString source_id),("start",Int.toString start),("stop",Int.toString stop),
               ("name",name),("embedded",Bool.toString embedded)],[])
          | G.Replay{source_id,start,stop,imports}=>("replay",
              [("source",IntInf.toString source_id),("start",Int.toString start),("stop",Int.toString stop)],imports)
        in XML.Elem(("node",[("context",IntInf.toString context_id),("kind",kind)]@fields),
          map(fn id=>attrs "parent"[("id",IntInf.toString id)])parents @
          map(fn name=>attrs "import"[("name",name)])imports)end
    in YXML.string_of_body[XML.Elem(("veri7vn-managed-expert-replay",
      [("version","1"),("head",IntInf.toString head),("theorem",theorem),("index",Int.toString index)]),map row nodes)]end;
  fun framing bytes=
    let val n=size bytes
      fun scan i depth nodes=if i>=n then if depth=0 then()else error "Replay framing"
        else if String.sub(bytes,i)=Char.chr 5 andalso i+1<n andalso String.sub(bytes,i+1)=Char.chr 6
        then if i+2<n andalso String.sub(bytes,i+2)=Char.chr 5
          then if depth>0 then scan(i+3)(depth-1)nodes else error "Replay framing close"
          else if depth<16 andalso nodes<4096 then scan(i+2)(depth+1)(nodes+1)else error "Replay framing bounds"
        else scan(i+1)depth nodes
    in if n<=100000 then scan 0 0 0 else error "Replay recipe byte bound"end;
  fun decode bytes=
    let val _=framing bytes
      fun field fields name=the(AList.lookup(op =)fields name)
      fun row(XML.Elem(("node",fields),body))=
        let val context_id=number(field fields "context")
          val parents=map_filter(fn XML.Elem(("parent",[("id",id)]),[])=>SOME(number id)|_=>NONE)body
          val imports=map_filter(fn XML.Elem(("import",[("name",name)]),[])=>SOME name|_=>NONE)body
          fun source ctor=ctor{source_id=number(field fields "source"),start=integer(field fields "start"),stop=integer(field fields "stop")}
          val construction=case field fields "kind"of "public"=>G.Public
            | "replay"=>source(fn{source_id,start,stop}=>G.Replay{source_id=source_id,start=start,stop=stop,imports=imports})
            | "definition"=>source(fn{source_id,start,stop}=>G.Definition{source_id=source_id,start=start,stop=stop,
                name=field fields "name",embedded=case field fields "embedded"of "true"=>true|"false"=>false|_=>error "Replay boolean"})
            | _=>error "Unknown replay construction"
        in{context_id=context_id,parents=parents,construction=construction}:G.construction_node end
        | row _=error "Replay construction row"
      val recipe=case YXML.parse_body bytes of
        [XML.Elem(("veri7vn-managed-expert-replay",[("version","1"),("head",head),("theorem",name),("index",index)]),body)]=>
          {graph={head=number head,nodes=map row body},name=(name,integer index)}:recipe
      | _=>error "Managed expert replay schema"
      val graph= #graph recipe val ids=map #context_id(#nodes graph)
      val _=if not(null ids) andalso length ids<=128 andalso length(distinct(op =)ids)=length ids andalso
          member(op =)ids(#head graph) andalso encode recipe=bytes then()else error "Replay canonical graph bounds"
      fun check(n:G.construction_node)seen=if forall(fn id=>member(op =)seen id)(#parents n)
        then #context_id n::seen else error "Replay graph cyclic or unordered"
      val _=fold check(#nodes graph)[]
      val _=if length(context_ids graph)=length ids then()else error "Replay graph has unrelated nodes"
    in recipe end;
  fun is_recipe bytes=(framing bytes;case YXML.parse_body bytes of
    [XML.Elem(("veri7vn-managed-expert-replay",_),_)]=>true|_=>false);
  fun ordinary scope allocator policy obtain({graph,name}:recipe)=Thread_Attributes.with_attributes Thread_Attributes.no_interrupts(fn original=>
    let fun next(n:G.construction_node)entries=
        let val parents=map(fn id=>the(AList.lookup(op =)entries id))(#parents n)
          fun slice source_id start stop=
            let val source=obtain source_id val input=P.source_input source val bytes=L.bytes input
              val _=if start>=0 andalso stop>=start andalso stop<=size bytes then()else error "Replay source span bounds"
            in(source,L.slice input{start=start,stop=stop,expected=String.substring(bytes,start,stop-start)})end
          val d=Thread_Attributes.with_attributes original(fn _=>case #construction n of G.Public=>
              if null parents then P.public_image_owned scope allocator policy else error "Replay public parent arity"
            | G.Definition{source_id,start,stop,name,embedded}=>
              let val(source,span)=slice source_id start stop
                val parent=case parents of[d]=>d|_=>error "Replay definition parent arity"
              in #1((if embedded then P.define_from_embedded_slice_owned scope else P.define_from_slice_owned scope)parent source(Binding.name name)span)end
            | G.Replay{source_id,start,stop,imports}=>let val(source,span)=slice source_id start stop
                val _=if length imports=length parents then()else error "Replay import arity"
              in P.replay_source_owned scope(imports~~parents)source span end)
        in AList.update(op =)(#context_id n,d)entries end
      val result=Exn.capture(fn()=>let val entries=fold next(#nodes graph)[]
        in Thread_Attributes.with_attributes original(fn _=>P.named_theorem(the(AList.lookup(op =)entries(#head graph)))name)end)()
    in Exn.release result end);
end;
