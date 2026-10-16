(* Shared inert native construction DAG codec. A graph describes construction,
   never a theorem selector, artifact acceptance or execution ticket. *)
structure Veri7vn_Native_Construction_Codec =
struct
  structure P=Veri7vn_Managed_Provenance;
  structure I=Veri7vn_Native_Identity_Allocator;
  structure L=Veri7vn_Native_Literals;
  structure G=Veri7vn_Native_Recovery_Graph;
  fun number value=case IntInf.fromString value of SOME n=>
      if n>0 andalso size value<=128 andalso IntInf.toString n=value then n else error "Replay ID bounds"
    | NONE=>error "Replay ID syntax";
  fun integer value=case Int.fromString value of SOME n=>
      if n>=0 andalso Int.toString n=value then n else error "Replay offset canonical form"
    | NONE=>error "Replay offset syntax";
  fun physical d=case P.alias_parent d of SOME parent=>physical parent|NONE=>d;
  fun has_replay d=is_some(P.replay_recipe(physical d)) orelse is_some(P.proof_recipe(physical d)) orelse exists has_replay(P.context_parents d);
  fun collect_internal roots boot allocator development =
    let fun identity d=case I.lookup_generation_id allocator(P.generation d)of SOME id=>id
          | NONE=>error "Replay construction context is not canonically bound"
      fun walk depth d (nodes,owners)=
        let val id=identity d
        in if exists(fn(n:G.construction_node)=> #context_id n=id)nodes then(nodes,owners)
          else if depth>128 orelse length nodes>=128 then error "Replay construction DAG bound"
          else let val parents=P.context_parents d
            val(nodes',owners')=fold(walk(depth+1))parents(nodes,owners)
            val original=physical d
            val(construction,own)=case P.proof_recipe original of
              SOME{source,slice,wire,sequent,...}=>let val{start,stop}=L.offsets slice
                in(G.Proof{source_id=P.source_identity source,start=start,stop=stop,wire=wire,sequent=sequent},[source])end
            | NONE=>(case P.replay_recipe original of
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
              | NONE=>if null parents then
                  (case roots of NONE=>(G.Public,[]) | SOME registry=>
                    let val thy=Proof_Context.theory_of(Veri7vn_Native_Registry.context(P.generation original))
                      val locator=Context.theory_name{long=true}thy
                    in if member(op =)(Veri7vn_Native_Installed_Roots.locators registry)locator then
                      (if Veri7vn_Native_Installed_Roots.matches registry locator thy then
                        (G.Installed_Public locator,[])else error "Public construction differs from fixed installed root")
                      else case boot of SOME actual=>if Context.eq_thy(thy,actual)then(G.Public,[])
                        else error "Public construction is neither fixed installed root nor exact boot"
                      |NONE=>error "Public construction is not a fixed installed root"end)
                else error "Unregistered expert construction parent"))
            val n={context_id=id,parents=map identity parents,construction=construction}:G.construction_node
          in(nodes'@[n],own@owners')end end
      val(nodes,owners)=walk 0 development([],[])
    in({head=identity development,nodes=nodes}:G.graph_description,owners)end;
  val collect=collect_internal NONE NONE;
  fun collect_with_roots roots=collect_internal(SOME roots)NONE;
  fun collect_for_image roots policy=collect_internal(SOME roots)(SOME(Veri7vn_Native_Admission.policy_theory policy));
  fun node graph id=the(find_first(fn(n:G.construction_node)=> #context_id n=id)(#nodes(graph:G.graph_description)));
  fun ordered_nodes(graph:G.graph_description)=
    let fun visit id seen=if member(op =)seen id then seen
          else fold visit(#parents(node graph id))(seen@[id])
    in map(node graph)(visit(#head graph)[])end;
  fun context_ids graph=map #context_id(ordered_nodes graph);
  fun source_ids graph=distinct(op =)(map_filter(fn(n:G.construction_node)=>case #construction n of
    G.Public=>NONE|G.Installed_Public _=>NONE|G.Proof{source_id,...}=>SOME source_id|G.Definition{source_id,...}=>SOME source_id|G.Replay{source_id,...}=>SOME source_id)(ordered_nodes graph));
  fun attrs name fields=XML.Elem((name,fields),[]);
  fun hex bytes=String.translate(fn c=>let val n=Char.ord c val alphabet="0123456789abcdef"
    in str(String.sub(alphabet,n div 16))^str(String.sub(alphabet,n mod 16))end)bytes;
  fun unhex text=let val n=size text
      val _=if n<=200000 andalso n mod 2=0 then()else error "Proof hex byte bounds"
      fun digit c=if c>= #"0" andalso c<= #"9" then Char.ord c-48
        else if c>= #"a" andalso c<= #"f" then Char.ord c-87 else error "Proof hex canonical digit"
    in String.implode(List.tabulate(n div 2,fn i=>Char.chr(16*digit(String.sub(text,2*i))+digit(String.sub(text,2*i+1)))))end;
  fun budget nodes=
    let val decoded=fold(fn(n:G.construction_node)=>fn total=>case #construction n of
        G.Proof{wire,sequent,...}=>total+size wire+size sequent|_=>total)nodes 0
      val estimate=512+fold(fn(n:G.construction_node)=>fn total=>total+640+160*length(#parents n)+
        (case #construction n of G.Proof{wire,sequent,...}=>2*(size wire+size sequent)
          | G.Replay{imports,...}=>fold(fn name=>fn count=>count+size name+32)imports 0
          | G.Definition{name,...}=>size name|G.Public=>0|G.Installed_Public locator=>size locator))nodes 0
    in if decoded<=45000 andalso estimate<=100000 then()else
      error "Construction aggregate decoded/encoded byte bound"end;
  fun validate(graph:G.graph_description)=
    let val ids=map #context_id(#nodes graph)
      fun positive n=n>0 andalso size(IntInf.toString n)<=128
      val _=if not(null ids) andalso length ids<=128 andalso forall positive ids andalso
        length(distinct(op =)ids)=length ids andalso member(op =)ids(#head graph)
        then()else error "Construction graph identity bounds"
      fun check(n:G.construction_node)seen=
        if length(#parents n)<=128 andalso forall(fn id=>member(op =)seen id)(#parents n)
        then #context_id n::seen else error "Construction graph cyclic or unordered"
      val _=fold check(#nodes graph)[]
      val _=if length(context_ids graph)=length ids then()else error "Construction graph has unrelated nodes"
    in budget(#nodes graph)end;
  fun encode_node({context_id,parents,construction}:G.construction_node)=
        let val(kind,fields,imports)=case construction of G.Public=>("public",[],[])
          | G.Installed_Public locator=>("installed-public",[("root",locator)],[])
          | G.Definition{source_id,start,stop,name,embedded}=>("definition",
              [("source",IntInf.toString source_id),("start",Int.toString start),("stop",Int.toString stop),
               ("name",name),("embedded",Bool.toString embedded)],[])
          | G.Proof{source_id,start,stop,wire,sequent}=>("proof",
              [("source",IntInf.toString source_id),("start",Int.toString start),("stop",Int.toString stop),
               ("wire",hex wire),("sequent",hex sequent)],[])
          | G.Replay{source_id,start,stop,imports}=>("replay",
              [("source",IntInf.toString source_id),("start",Int.toString start),("stop",Int.toString stop)],imports)
        in XML.Elem(("node",[("context",IntInf.toString context_id),("kind",kind)]@fields),
          map(fn id=>attrs "parent"[("id",IntInf.toString id)])parents @
          map(fn name=>attrs "import"[("name",name)])imports)end
  fun framing bytes=
    let val n=size bytes
      fun scan i depth nodes=if i>=n then if depth=0 then()else error "Replay framing"
        else if String.sub(bytes,i)=Char.chr 5 andalso i+1<n andalso String.sub(bytes,i+1)=Char.chr 6
        then if i+2<n andalso String.sub(bytes,i+2)=Char.chr 5
          then if depth>0 then scan(i+3)(depth-1)nodes else error "Replay framing close"
          else if depth<16 andalso nodes<4096 then scan(i+2)(depth+1)(nodes+1)else error "Replay framing bounds"
        else scan(i+1)depth nodes
    in if n<=100000 then scan 0 0 0 else error "Replay recipe byte bound"end;
  fun field fields name=the(AList.lookup(op =)fields name)
  fun decode_node(XML.Elem(("node",fields),body))=
        let val context_id=number(field fields "context")
          val parents=map_filter(fn XML.Elem(("parent",[("id",id)]),[])=>SOME(number id)|_=>NONE)body
          val imports=map_filter(fn XML.Elem(("import",[("name",name)]),[])=>SOME name|_=>NONE)body
          fun source ctor=ctor{source_id=number(field fields "source"),start=integer(field fields "start"),stop=integer(field fields "stop")}
          val construction=case field fields "kind"of "public"=>G.Public
            | "installed-public"=>G.Installed_Public(field fields "root")
            | "proof"=>source(fn{source_id,start,stop}=>G.Proof{source_id=source_id,start=start,stop=stop,
                wire=unhex(field fields "wire"),sequent=unhex(field fields "sequent")})
            | "replay"=>source(fn{source_id,start,stop}=>G.Replay{source_id=source_id,start=start,stop=stop,imports=imports})
            | "definition"=>source(fn{source_id,start,stop}=>G.Definition{source_id=source_id,start=start,stop=stop,
                name=field fields "name",embedded=case field fields "embedded"of "true"=>true|"false"=>false|_=>error "Replay boolean"})
            | _=>error "Unknown replay construction"
        in{context_id=context_id,parents=parents,construction=construction}:G.construction_node end
    | decode_node _=error "Replay construction row"
  fun decoded_budget body=
    let fun encoded_proofs(XML.Elem((_,fields),children))=
            fold(fn(_,value)=>fn count=>count+size value)
              (filter(fn(name,_)=>name="wire" orelse name="sequent")fields)0 +
            fold(fn child=>fn count=>count+encoded_proofs child)children 0
          | encoded_proofs _=0
    in if fold(fn item=>fn count=>count+encoded_proofs item)body 0<=90000
      then()else error "Construction aggregate decoded byte bound"end;
  fun encode_nodes graph=(validate graph;map encode_node(#nodes graph));
  fun decode_nodes head body=
    let val _=decoded_budget body
      val graph={head=head,nodes=map decode_node body}:G.graph_description
      val _=validate graph
      val _=if encode_nodes graph=body then()else error "Noncanonical construction node rows"
    in graph end;
  fun encode(graph:G.graph_description)=
    let val body=encode_nodes graph
      val bytes=YXML.string_of_body[XML.Elem(("veri7vn-managed-construction-graph",
        [("version","1"),("head",IntInf.toString(#head graph))]),body)]
    in if size bytes<=100000 then bytes else error "Construction graph encoded byte bound"end;
  fun decode bytes=
    let val _=framing bytes
      val graph=case YXML.parse_body bytes of
        [XML.Elem(("veri7vn-managed-construction-graph",[("version","1"),("head",head)]),body)]=>
          decode_nodes(number head)body
      | _=>error "Construction graph schema"
      val _=if encode graph=bytes then()else error "Noncanonical construction graph"
    in graph end;
end;
