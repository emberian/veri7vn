(* D63 nonassertional request recovery material. These bytes locate and check a
   retained Q recipe and terminal observation; they never issue admission, mutate
   the native authority, manufacture a Scope child or restart a worker. Parent
   assembly authenticates C's exact child/pins/outcome/execution correspondence. *)
functor Veri7vn_Search_Request_Codec_Fn (
  structure S: VERI7VN_NATIVE_SEARCH
  structure Q:
  sig
    type request
    type saved={encoding:string,bytes:string,start:int,stop:int,target:term,
      catalogue:Thm_Name.T list,limits:S.limits,actions:S.action list,
      scope_identity:Veri7vn_Native_Request_Scope.identity option}
    val snapshot: request -> saved
    val native_scope: request -> Veri7vn_Native_Request_Scope.child option
    val receiver: request -> Veri7vn_Managed_Provenance.development
    val worker: request -> Veri7vn_Managed_Provenance.development
    val source: request -> Veri7vn_Managed_Provenance.source_owner
    val cost: request -> IntInf.int
    val executable: request -> Veri7vn_Executable_Identity.pin
  end) =
struct
  structure Wire=Veri7vn_Search_Protocol_Fn(S);
  structure P=Veri7vn_Managed_Provenance;
  structure R=Veri7vn_Native_Registry;
  structure I=Veri7vn_Native_Identity_Allocator;
  structure Scope=Veri7vn_Native_Request_Scope;
  val require=Wire.require;
  val node=Wire.node;
  val document=Wire.document;
  datatype stop=Exhausted | Budget | Deadline | Cancelled | Failed;
  datatype phase=Pending of IntInf.int option | Stopped of
    {stop:stop,execution:IntInf.int,reason:IntInf.int,diagnostic:string,progress:XML.tree};
  type names={capability:IntInf.int,operation:IntInf.int,profile:IntInf.int,step:IntInf.int,
    template:IntInf.int,claim:IntInf.int,parameter:IntInf.int,execution:IntInf.int,code:IntInf.int,
    evidence:IntInf.int,output:IntInf.int,batch:IntInf.int,exhausted:IntInf.int,budget:IntInf.int,
    deadline:IntInf.int,cancelled:IntInf.int,failed:IntInf.int};
  val name_keys=["capability","operation","profile","step","template","claim","parameter","execution","code",
    "evidence","output","batch","exhausted","budget","deadline","cancelled","failed"];
  fun name_values(n:names)=[#capability n,#operation n,#profile n,#step n,#template n,#claim n,#parameter n,
    #execution n,#code n,#evidence n,#output n,#batch n,#exhausted n,#budget n,#deadline n,#cancelled n,#failed n];
  fun names_of_values [capability,operation,profile,step,template,claim,parameter,execution,code,
      evidence,output,batch,exhausted,budget,deadline,cancelled,failed]=
      {capability=capability,operation=operation,profile=profile,step=step,template=template,claim=claim,
       parameter=parameter,execution=execution,code=code,evidence=evidence,output=output,batch=batch,
       exhausted=exhausted,budget=budget,deadline=deadline,cancelled=cancelled,failed=failed}:names
    | names_of_values _=error "Search stored control name arity";
  type links={context:IntInf.int,receiver:IntInf.int,worker:IntInf.int,source:IntInf.int,cost:IntInf.int};
  datatype material=Material of {links:links,names:names,saved:Q.saved,phase:phase};
  type artifacts={association:IntInf.int,semantic_generation:IntInf.int,manifest:string,
    projection:string,sequent:string,context_closure:string,reconstruction:string,executable:string};
  fun positive n=n>0 andalso size(IntInf.toString n)<=128;
  fun stop_name Exhausted="exhausted" | stop_name Budget="budget" | stop_name Deadline="deadline" |
    stop_name Cancelled="cancelled" | stop_name Failed="failed";
  fun read_stop "exhausted"=Exhausted | read_stop "budget"=Budget | read_stop "deadline"=Deadline |
    read_stop "cancelled"=Cancelled | read_stop "failed"=Failed | read_stop _=error "Search stored stop variant";
  fun execution(Pending id)=id | execution(Stopped{execution,...})=SOME execution;
  fun reason(Pending _)=NONE | reason(Stopped{reason,...})=SOME reason;
  fun stopped request {execution,reason,diagnostic,report:S.report}=
    let val stop=case #outcome report of S.Exhausted=>Exhausted | S.BudgetStop=>Budget |
      S.Deadline=>Deadline | S.Cancelled=>Cancelled | S.ProofProposal _=>error "Proof proposal is not a stopped request";
      val _=require(positive execution andalso positive reason) "Search stopped execution/reason identity";
    in Stopped{stop=stop,execution=execution,reason=reason,diagnostic=Wire.safe diagnostic 2048,
      progress=Wire.progress(R.context(P.generation(Q.receiver request)))report}end;
  fun failed {execution,reason,diagnostic}=
    (require(positive execution andalso positive reason) "Search failed execution/reason identity";
     Stopped{stop=Failed,execution=execution,reason=reason,diagnostic=Wire.safe diagnostic 2048,
       progress=node "progress"[("expansions","0"),("trace_total","0"),("remaining_total","0"),("details_truncated","false")]
         [node "trace"[][],node "remaining"[][]]});
  fun snapshot context request names phase=
    let val child=case Q.native_scope request of SOME child=>child | NONE=>error "Search recovery requires actual typed child";
      val ids=Scope.allocator(Scope.parent child);
      val _=require(positive context) "Search original context selector identity";
    in Material{links={context=context,receiver=I.generation_id ids(P.generation(Q.receiver request)),
      worker=I.generation_id ids(P.generation(Q.worker request)),source=P.source_identity(Q.source request),
      cost=Q.cost request},names=names,saved=Q.snapshot request,phase=phase}end;
  fun inspect(Material value)=value;
  fun phase_xml(Pending execution)=
        (require(case execution of NONE=>true|SOME id=>positive id) "Search pending execution identity";
         node "pending"[("execution",case execution of NONE=>""|SOME id=>IntInf.toString id)][])
    | phase_xml(Stopped{stop,execution,reason,diagnostic,progress})=
        (require(positive execution andalso positive reason) "Search terminal execution/reason identity";
         Wire.validate_progress progress;
         node "stopped"[("kind",stop_name stop),("execution",IntInf.toString execution),("reason",IntInf.toString reason)]
           [node "diagnostic"[][XML.Text(Wire.safe diagnostic 2048)],progress]);
  fun phase_of_xml(XML.Elem(("pending",attrs),[]))=
        let val a=Wire.attributes["execution"]attrs
        in Pending(if a "execution"="" then NONE else SOME(Wire.identity(a "execution")))end
    | phase_of_xml(XML.Elem(("stopped",attrs),[XML.Elem(("diagnostic",[]),body),progress]))=
        let val a=Wire.attributes["kind","execution","reason"]attrs;
          val _=Wire.validate_progress progress
        in Stopped{stop=read_stop(a "kind"),execution=Wire.identity(a "execution"),reason=Wire.identity(a "reason"),
          diagnostic=Wire.safe(Wire.plain body)2048,progress=progress}end
    | phase_of_xml _=error "Search stored phase shape";
  (* Exact upper bound of the YXML term encoding, traversed before construction.
     Names and repeated type payloads are charged by bytes, not just term nodes. *)
  datatype task=TermTask of term*int | TypeTask of typ*int;
  fun term_bound budget term=
    let fun name text=(ignore(Wire.safe text 1048576);size text);
      fun index (_,i)=if i=0 then 0 else 3+size(string_of_int i);
      fun sort_bytes sorts=fold(fn cls=>fn total=>total+7+name cls)sorts 0;
      fun walk [] total _=total
        | walk (job::jobs) total nodes=
          let val _=require(total<=budget andalso nodes<=100000) "Search target recovery encoding byte/node bound";
            val (bytes,next)=case job of
              TermTask(t,depth)=>
                (require(depth<=1024) "Search target recovery term depth bound";
                 case t of Const(n,T)=>(10+name n,TypeTask(T,0)::jobs) |
                   Free(n,T)=>(10+name n,TypeTask(T,0)::jobs) |
                   Var(ni as(n,_),T)=>(10+name n+index ni,TypeTask(T,0)::jobs) |
                   Bound i=>(7+size(string_of_int i),jobs) |
                   Abs(n,T,b)=>(24+name n,TypeTask(T,0)::TermTask(b,depth+1)::jobs) |
                   f $ x=>(21,TermTask(f,depth+1)::TermTask(x,depth+1)::jobs))
            | TypeTask(T,depth)=>
                (require(depth<=64) "Search target recovery type depth bound";
                 case T of Type(n,args)=>(10+name n+7*length args,map(fn T=>TypeTask(T,depth+1))args@jobs) |
                   TFree(n,sort)=>(10+name n+sort_bytes sort,jobs) |
                   TVar(ni as(n,_),sort)=>(10+name n+index ni+sort_bytes sort,jobs));
            val total'=total+bytes;
            val _=require(total'<=budget) "Search target recovery encoding byte bound";
          in walk next total'(nodes+1)end;
    in walk[TermTask(term,0)]0 0 end;
  fun encode(Material{links={context,receiver,worker,source,cost},names,saved,phase})=
    let val _=require(forall positive[context,receiver,worker,source,cost] andalso context=receiver andalso worker=receiver)
        "Search first-profile recovery context/worker/receiver identities/cost";
      val {encoding,bytes,start,stop,target,catalogue,limits,actions,scope_identity}=saved;
      val _=require(encoding="UTF-8" andalso size bytes<=1048576 andalso Veri7vn_Search_UTF8.valid bytes andalso
        start>=0 andalso stop>start andalso stop<=size bytes andalso stop-start<=65536 andalso
        Veri7vn_Search_UTF8.valid(String.substring(bytes,start,stop-start))) "Search recovery exact original source/span";
      val ids=case scope_identity of SOME ids=>ids | NONE=>error "Search recovery missing native child identity";
      val _=require(forall positive[#request ids,#goal ids,#slot ids,#interpretation ids,#decision ids] andalso
        length(distinct(op =)[#request ids,#goal ids,#slot ids,#interpretation ids,#decision ids])=5)
        "Search recovery child identity uniqueness";
      val controls=name_values names;
      val _=require(forall positive controls andalso length(distinct(op =)controls)=length controls andalso
        not(exists(fn n=>member(op =)[#request ids,#goal ids,#slot ids,#interpretation ids,#decision ids,source,receiver,worker]n)controls))
        "Search recovery control identity uniqueness";
      val _=require(case execution phase of NONE=>true | SOME id=>id= #execution names)
        "Search phase differs from original consumed execution";
      val _=case phase of Pending _=>() | Stopped{stop,reason,...}=>require(reason=(case stop of
          Exhausted=> #exhausted names | Budget=> #budget names | Deadline=> #deadline names |
          Cancelled=> #cancelled names | Failed=> #failed names)) "Search stopped reason differs from producer association";
      val _=require(length catalogue<=128 andalso not(null actions) andalso length actions<=64 andalso
        #expansions limits>0 andalso #expansions limits<=10000 andalso #frontier limits>0 andalso #frontier limits<=1000 andalso
        #successors limits>0 andalso #successors limits<=16 andalso #milliseconds limits>0 andalso #milliseconds limits<=30000)
        "Search recovery catalogue/action/limit bound";
      val action_trees=map Wire.action_xml actions;
      val _=List.app(fn tree=>ignore(Wire.action_of_xml(length catalogue)tree))action_trees;
      val facts=map(fn(name,index)=>
        (require(index>=0 andalso index<=1000000 andalso size name>0) "Search managed catalogue native index";
         node "fact"[("name",Wire.safe name 512),("index",string_of_int index)][]))catalogue;
      val attrs=[("version","1"),("context",IntInf.toString context),("receiver",IntInf.toString receiver),
        ("worker",IntInf.toString worker),("source",IntInf.toString source),("cost",IntInf.toString cost),
        ("request",IntInf.toString(#request ids)),("goal",IntInf.toString(#goal ids)),("slot",IntInf.toString(#slot ids)),
        ("interpretation",IntInf.toString(#interpretation ids)),("decision",IntInf.toString(#decision ids)),
        ("start",string_of_int start),("stop",string_of_int stop),
        ("expansions",string_of_int(#expansions limits)),("frontier",string_of_int(#frontier limits)),
        ("successors",string_of_int(#successors limits)),("milliseconds",string_of_int(#milliseconds limits))];
      fun tree target_body=node "search-request"attrs
        [node "control"(name_keys ~~ map IntInf.toString controls)[],
         node "original"[("encoding",encoding)][XML.Text(Wire.safe bytes 1048576)],node "target"[]target_body,
         node "catalogue"[]facts,node "actions"[]action_trees,phase_xml phase];
      val fixed=size(document(tree []));
      val estimate=term_bound(1048576-fixed)target;
      val encoded=document(tree(Term_XML.Encode.term_raw target));
      val _=require(size encoded<=1048576 andalso size encoded<=fixed+estimate)
        "Search request material exceeds exact recovery encoding bound";
    in encoded end;
  fun checked_body raw=
    let val _=require(size raw>0 andalso size raw<=1048576) "Search request material byte bound";
      fun structural part (depth,nodes)=if String.isPrefix "\006" part then
          if size part=1 then (require(depth>0) "Search request YXML close";(depth-1,nodes))
          else (require(depth<4096 andalso nodes<150000) "Search request YXML structural bound";(depth+1,nodes+1))
        else(depth,nodes);
      val (depth,_)=fold structural(String.fields(fn c=>c= #"\005")raw)(0,0);
      val _=require(depth=0) "Search request YXML balance";
    in YXML.parse_body raw end;
  datatype xml_task=TermTree of XML.tree*int | TypeTree of XML.tree*int;
  fun preflight_target body=
    let fun one [tree]=tree | one _=error "Search target variant singleton";
      fun wrap(XML.Elem((":",[]),body))=one body | wrap _=error "Search target structural wrapper";
      fun names raw count=
        (require(length raw=count andalso map #1 raw=map string_of_int(0 upto (count-1)))
          "Search target variant attributes";map #2 raw);
      fun integer text=(require(size text<=20) "Search target integer bound";
        case IntInf.fromString text of SOME n=>
          (require(n>=0 andalso IntInf.toString n=text) "Search target canonical nonnegative index";
           ignore(IntInf.toInt n handle Overflow=>error "Search target native index bound"))
        | NONE=>error "Search target integer encoding");
      fun variant max (XML.Elem((tag,attrs),body))=(Wire.natural max tag,attrs,body)
        | variant _ _=error "Search target variant element";
      fun name text=ignore(Wire.safe text 1048576);
      fun index raw=let val values=if length raw=1 then names raw 1 else names raw 2
        in name(hd values);if length values=2 then integer(nth values 1)else()end;
      fun sorts body=List.app(fn XML.Elem((":",[]),text)=>name(Wire.plain text)
        | _=>error "Search target sort wrapper")body;
      fun loop [] _=()
        | loop (job::jobs) nodes=
          let val _=require(nodes<100000) "Search target XML node bound";
            val next=case job of TermTree(tree,depth)=>
              let val _=require(depth<=1024) "Search target XML term depth bound";
                val(tag,attrs,body)=variant 5 tree;
              in case tag of 0=>(List.app name(names attrs 1);TypeTree(one body,0)::jobs)
                | 1=>(List.app name(names attrs 1);TypeTree(one body,0)::jobs)
                | 2=>(index attrs;TypeTree(one body,0)::jobs)
                | 3=>(ignore(names attrs 0);integer(Wire.plain body);jobs)
                | 4=>(List.app name(names attrs 1);case body of [T,b]=>
                    TypeTree(wrap T,0)::TermTree(wrap b,depth+1)::jobs
                    | _=>error "Search target abstraction pair")
                | 5=>(ignore(names attrs 0);case body of [f,x]=>
                    TermTree(wrap f,depth+1)::TermTree(wrap x,depth+1)::jobs
                    | _=>error "Search target application pair")
                | _=>error "Search target term tag"end
            | TypeTree(tree,depth)=>
              let val _=require(depth<=64) "Search target XML type depth bound";
                val(tag,attrs,body)=variant 2 tree
              in case tag of 0=>(List.app name(names attrs 1);map(fn tree=>TypeTree(wrap tree,depth+1))body@jobs)
                | 1=>(List.app name(names attrs 1);sorts body;jobs)
                | 2=>(index attrs;sorts body;jobs)
                | _=>error "Search target type tag"end;
          in loop next(nodes+1)end;
    in loop[TermTree(one body,0)]0 end;
  fun decode raw=
    let val (a,names,bytes,target_body,facts,actions,phase)=case checked_body raw of
        [XML.Elem(("search-request",attrs),[XML.Elem(("control",control),[]),XML.Elem(("original",original_attrs),original),
          XML.Elem(("target",[]),target),XML.Elem(("catalogue",[]),facts),XML.Elem(("actions",[]),actions),phase])]=>
          let val oattr=Wire.attributes["encoding"]original_attrs
            val controls=Wire.attributes name_keys control;
            val _=require(oattr "encoding"="UTF-8") "Search recovery original encoding"
          in (Wire.attributes["version","context","receiver","worker","source","cost","request","goal","slot", "interpretation", "decision",
            "start","stop","expansions","frontier","successors","milliseconds"]attrs,
            names_of_values(map(Wire.identity o controls)name_keys),Wire.plain original,target,facts,actions,phase)end
        | _=>error "Search request material closed shape";
      val _=require(a "version"="1" andalso length facts<=128 andalso not(null actions) andalso length actions<=64)
        "Search request material version/catalogue/action bound";
      val catalogue=map(fn XML.Elem(("fact",attrs),[])=>
          let val a=Wire.attributes["name","index"]attrs in (Wire.safe(a "name")512,Wire.natural 1000000(a "index"))end
        | _=>error "Search stored managed fact shape")facts;
      val _=preflight_target target_body;
      val target=Term_XML.Decode.term_raw target_body;
      val saved={encoding="UTF-8",bytes=bytes,start=Wire.natural 1048576(a "start"),stop=Wire.natural 1048576(a "stop"),target=target,
        catalogue=catalogue,actions=map(Wire.action_of_xml(length catalogue))actions,
        limits={expansions=Wire.natural 10000(a "expansions"),frontier=Wire.natural 1000(a "frontier"),
          successors=Wire.natural 16(a "successors"),milliseconds=Wire.natural 30000(a "milliseconds")},
        scope_identity=SOME{request=Wire.identity(a "request"),goal=Wire.identity(a "goal"),slot=Wire.identity(a "slot"),
          interpretation=Wire.identity(a "interpretation"),decision=Wire.identity(a "decision")}}:Q.saved;
      val material=Material{links={context=Wire.identity(a "context"),receiver=Wire.identity(a "receiver"),worker=Wire.identity(a "worker"),
        source=Wire.identity(a "source"),cost=Wire.identity(a "cost")},names=names,saved=saved,phase=phase_of_xml phase};
      val _=require(encode material=raw) "Search request material is not canonical";
    in material end;
  fun digest bytes=Message_Digest.rep(SHA256.digest bytes);
  val recipe="checked-original-search-request/1";
  fun export image context request names phase=
    let val _=require(Context.subthy(Veri7vn_Executable_Identity.code_theory(Q.executable request),
        Veri7vn_Native_Admission.policy_theory(Veri7vn_Native_Recovery_Check.image_policy image)))
        "Search request executable is outside installed image";
      val material=snapshot context request names phase;
      val {links,saved,...}=inspect material;
      val child=the(#scope_identity saved);
      val parent=Scope.parent(the(Q.native_scope request));
      val workspace=Scope.allocator parent |> I.workspace;
      val _=require(Context.eq_thy(Veri7vn_Native_Admission.policy_theory(Scope.policy parent),
        Veri7vn_Native_Admission.policy_theory(Veri7vn_Native_Recovery_Check.image_policy image)))
        "Search first receiver must be the actual installed public boot image";
      val executable=Veri7vn_Native_Recovery_Pin.material(Q.executable request);
      val projection=encode material;
      val required=[(#goal child,#slot child)];
      val original=Scope.snapshot parent required;
      val _=require(length(#children original)=1) "Search first profile requires its actual singleton original plan";
      val image_closure=Veri7vn_Native_Recovery_Check.context_closure image;
      val family=Veri7vn_Native_Recovery_Source.encode{image=image_closure,sources=[]};
      val closure=Veri7vn_Native_Scope_Envelope.encode{saved=original,required=required,
        image=image_closure,executable=executable,receiver=Veri7vn_Native_Scope_Envelope.Boot,family=family};
      val manifest=Veri7vn_Recovery_Manifest.encode{profile=Veri7vn_Recovery_Manifest.SearchRequest,
        workspace=workspace,association= #slot child,semantic_generation= #receiver links,
        projection=digest projection,sequent=digest "",context_closure=digest closure,
        reconstruction=Veri7vn_Recovery_Manifest.Controlled_Recipe,payload=digest recipe,
        executable=SOME(digest executable)};
    in {association= #slot child,semantic_generation= #receiver links,manifest=manifest,
      projection=projection,sequent="",context_closure=closure,reconstruction=recipe,executable=executable}:artifacts end;
  (* Produces inert checked recipe data. C checkpoint/child membership, current
     goal outcome and exact consumed execution remain the parent's generated
     matcher obligations before actual Scope/Q reconstruction. *)
  fun verify image pin committed=
    let val m=Veri7vn_Committed_Native_Recovery.materials committed;
      val executable=Veri7vn_Native_Recovery_Pin.material pin;
      val _=require(Context.subthy(Veri7vn_Executable_Identity.code_theory pin,
        Veri7vn_Native_Admission.policy_theory(Veri7vn_Native_Recovery_Check.image_policy image)))
        "Search restore request executable is outside actual installed image";
      val envelope=Veri7vn_Recovery_Manifest.decode{max_bytes=8192}(#manifest m);
      val _=Veri7vn_Recovery_Manifest.require_profile Veri7vn_Recovery_Manifest.SearchRequest envelope;
      val _=require(#workspace envelope= #workspace m andalso #association envelope= #association m andalso
        #semantic_generation envelope= #semantic_generation m andalso #sequent m="" andalso
        #reconstruction envelope=Veri7vn_Recovery_Manifest.Controlled_Recipe andalso
        #projection envelope=digest(#projection m) andalso #sequent envelope=digest "" andalso
        #context_closure envelope=digest(#context_closure m) andalso #payload envelope=digest recipe andalso
        #executable envelope=SOME(digest executable) andalso #reconstruction m=recipe)
        "Search committed request role/pin/image/integrity differs";
      val packet=Veri7vn_Native_Scope_Envelope.decode(#context_closure m);
      val installed=Veri7vn_Native_Recovery_Check.context_closure image;
      val _=require(#image packet=installed andalso #family packet=Veri7vn_Native_Recovery_Source.encode{image=installed,sources=[]} andalso
        #executable packet=executable andalso #receiver packet=Veri7vn_Native_Scope_Envelope.Boot)
        "Search scoped receiver/image/family/executable differs";
      val material=decode(#projection m);
      val {links,saved,...}=inspect material;
      val child=the(#scope_identity saved);
      val plan= #saved packet;
      val _=require(#association m= #slot(the(#scope_identity saved)) andalso
        #semantic_generation m= #receiver links andalso #workspace plan= #workspace m andalso
        #request plan= #request child andalso #required packet=[(#goal child,#slot child)] andalso
        (case #children plan of [{identity,source,predecessors}]=>identity=child andalso null predecessors andalso
          #source source= #source links andalso #start source= #start saved andalso #stop source= #stop saved | _=>false) andalso
        (case #sources plan of [{identity,encoding,bytes}]=>identity= #source links andalso
          encoding= #encoding saved andalso bytes= #bytes saved | _=>false))
        "Search original request/scoped source envelope differs"
    in material end;
end;
