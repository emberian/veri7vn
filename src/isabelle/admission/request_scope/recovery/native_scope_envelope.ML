(* Inert shared scoped-role closure. Binary framing keeps original blobs and the
   nested family closure byte-exact, without another Base64 expansion. The 1 MiB
   AuthorityWire bound applies only to the metadata header; the complete role
   slot remains bounded by the existing 16 MiB context-closure limit. *)
structure Veri7vn_Native_Scope_Envelope =
struct
  structure S=Veri7vn_Native_Scope_Saved;
  structure W=Veri7vn_Native_Authority_Wire;
  datatype receiver=Boot|Installed of string;
  fun receiver_name Boot=""|receiver_name(Installed locator)=locator;
  type packet={saved:S.parent,required:S.required,image:string,executable:string,receiver:receiver,family:string};
  val magic="V7SCOPE2";
  val max_bytes=16777216;
  val max_sources=64;
  val max_source_bytes=1048576;
  val max_original_bytes=2097152;
  fun require true _=()|require false message=error message;
  fun positive n=n>0 andalso size(IntInf.toString n)<=128;
  fun natural n=require(n>=0 andalso size(IntInf.toString n)<=128) "Scope natural bound";
  fun int_atom n=W.Atom(IntInf.fromInt n);
  fun key({identity,...}:S.child)=(#goal identity,#slot identity);
  fun encoding_tag "UTF-8"=0 |encoding_tag "binary"=1 |encoding_tag "native-term/1"=2
    |encoding_tag _=error "Unsupported original Scope encoding";
  fun encoding 0="UTF-8"|encoding 1="binary"|encoding 2="native-term/1"
    |encoding _=error "Unsupported original Scope encoding tag";
  fun workspace_number text=
    let val _=require(size text=32 andalso forall(fn c=>Char.isDigit c orelse(c>= #"a" andalso c<= #"f"))
      (String.explode text)) "Scope workspace syntax"
    in fold(fn c=>fn n=>16*n+IntInf.fromInt(if Char.isDigit c then Char.ord c-48 else Char.ord c-87))
      (String.explode text)(0:IntInf.int)end;
  fun workspace_text n=
    let val _=require(n>=0 andalso n<IntInf.pow(2,128)) "Scope workspace bound"
      val digits=String.map Char.toLower(IntInf.fmt StringCvt.HEX n)
    in String.implode(replicate(32-size digits)#"0")^digits end;
  fun validate({saved={version,workspace,request,observation=_,sources,children},required,image,executable,receiver,family}:packet)=
    let val _=ignore(workspace_number workspace)
      val _=require(version=1 andalso positive request andalso not(null children) andalso length children<=256 andalso
        length sources<=max_sources andalso size image<=1048576 andalso size executable<=1048576 andalso
        (case receiver of Boot=>true|Installed locator=>size locator>0 andalso size locator<=4096) andalso size family<=max_bytes) "Scope envelope version/objects"
      val all_ids=request::maps(fn({identity,...}:S.child)=>
        [#goal identity,#slot identity,#interpretation identity,#decision identity])children
      val _=require(forall positive all_ids andalso length(distinct(op =)all_ids)=length all_ids)
        "Scope identity overlap/bounds"
      val source_ids=map #identity sources
      val _=require(forall positive source_ids andalso length(distinct(op =)source_ids)=length source_ids andalso
        forall(fn({bytes,encoding,...}:S.source)=>size bytes<=max_source_bytes andalso can encoding_tag encoding)sources andalso
        fold(fn({bytes,...}:S.source)=>fn n=>n+size bytes)sources 0<=max_original_bytes)
        "Scope original source bounds/duplicates"
      val keys=map key children
      val _=require(not(null required) andalso length(distinct(op =)required)=length required andalso
        filter(fn key=>member(op =)required key)keys=required) "Scope required subset/order"
      fun child(c:S.child)seen=
        let val id= #identity c val span= #source c
          val _=require(#request id=request andalso positive(#source span) andalso #start span>=0 andalso
            #stop span>= #start span andalso length(#predecessors c)<=256 andalso
            length(distinct(op =)(#predecessors c))=length(#predecessors c) andalso
            forall(fn predecessor=>member(op =)seen predecessor)(#predecessors c)) "Scope original child DAG/span"
          val _=if member(op =)required(key c)then
            (case find_first(fn({identity,...}:S.source)=>identity= #source span)sources of
              SOME{bytes,...}=>require(#stop span<=size bytes) "Scope required source span"
            |NONE=>error "Scope required original source absent")else()
        in key c::seen end
      val _=fold child children []
      val needed=distinct(op =)(map(fn(c:S.child)=> #source(#source c))
        (filter(fn c=>member(op =)required(key c))children))
    in require(length needed=length source_ids andalso forall(fn id=>member(op =)needed id)source_ids)
      "Scope retained source set differs from required child originals"end;
  fun pair(a,b)=W.Node(0,[W.Atom a,W.Atom b]);
  fun header({saved={workspace,request,observation=S.StateTimeUnused,sources,children,...},required,image,executable,receiver,family}:packet)=
    W.Node(2,[W.Atom(workspace_number workspace),W.Atom request,W.Atom 0,
      W.Node(0,map(fn({identity,encoding,bytes}:S.source)=>W.Node(0,
        [W.Atom identity,int_atom(encoding_tag encoding),int_atom(size bytes)]))sources),
      W.Node(0,map(fn({identity,source,predecessors}:S.child)=>W.Node(0,
        [W.Node(0,map W.Atom[#request identity,#goal identity,#slot identity,#interpretation identity,#decision identity]),
         W.Node(0,[W.Atom(#source source),int_atom(#start source),int_atom(#stop source)]),
         W.Node(0,map pair predecessors)]))children),W.Node(0,map pair required),int_atom(size image),int_atom(size executable),
      (case receiver of Boot=>W.Node(0,[])|Installed locator=>W.Node(1,[int_atom(size locator)])),int_atom(size family)]);
  fun u32 n=(require(n>=0 andalso n<=2147483647) "Scope length bound";
    String.implode(map(fn divisor=>Char.chr((n div divisor)mod 256))[16777216,65536,256,1]));
  fun encode(packet as {saved={sources,...},image,executable,receiver,family,...}:packet)=
    let val _=validate packet val metadata=W.write(header packet)
      val total=12+size metadata+size image+size executable+size(receiver_name receiver)+size family+fold(fn({bytes,...}:S.source)=>fn n=>n+size bytes)sources 0
      val _=require(total<=max_bytes) "Scoped closure aggregate byte bound"
    in String.concat([magic,u32(size metadata),metadata] @ map #bytes sources @ [image,executable,receiver_name receiver,family])end;
  fun is_envelope bytes=String.isPrefix magic bytes;
  fun decode bytes=
    let val _=require(size bytes<=max_bytes andalso is_envelope bytes andalso size bytes>=12) "Scoped closure framing"
      val position=Unsynchronized.ref 8
      fun take n=let val _=require(n>=0 andalso n<=size bytes- !position) "Truncated scoped closure"
          val value=String.substring(bytes,!position,n) val _=position:= !position+n
        in value end
      val header_length=fold(fn c=>fn n=>256*n+IntInf.fromInt(Char.ord c))(String.explode(take 4))(0:IntInf.int)
      val _=require(header_length<=IntInf.fromInt W.max_bytes) "Scope metadata header bound"
      val tree=W.read(take(IntInf.toInt header_length))
      fun atom(W.Atom n)=n|atom _=error "Scope natural field"
      fun integer tree=let val n=atom tree
        in require(n<=2147483647) "Scope integer field bound";IntInf.toInt n end
      fun rows(W.Node(0,items))=items|rows _=error "Scope row group"
      fun unpair(W.Node(0,[a,b]))=(atom a,atom b)|unpair _=error "Scope predecessor pair"
      val(workspace,request,source_rows,children,required,image_size,executable_size,receiver_row,family_size)=case tree of
        W.Node(2,[workspace,request,W.Atom 0,sources,children,required,image,executable,receiver,family])=>
          (workspace_text(atom workspace),atom request,rows sources,rows children,map unpair(rows required),integer image,integer executable,receiver,integer family)
      |_=>error "Scoped closure metadata schema"
      val receiver_size=case receiver_row of W.Node(0,[])=>0
        |W.Node(1,[length])=>let val n=integer length
          in require(n>0 andalso n<=4096) "Scope installed receiver locator bound";n end
        |_=>error "Scope receiver policy selector"
      val specs=map(fn W.Node(0,[id,label,length])=>(atom id,encoding(integer label),integer length)
        |_=>error "Scope source header")source_rows
      val _=require(family_size<=max_bytes andalso image_size<=1048576 andalso executable_size<=1048576 andalso length specs<=max_sources andalso forall(fn(_,_,n)=>n<=max_source_bytes)specs andalso
        fold(fn(_,_,n)=>fn total=>total+n)specs 0<=max_original_bytes andalso
        fold(fn(_,_,n)=>fn total=>total+n)specs (image_size+executable_size+receiver_size+family_size)=size bytes- !position)
        "Scope original/family aggregate framing"
      val sources=map(fn(id,encoding,length)=>{identity=id,encoding=encoding,bytes=take length}:S.source)specs
      val parsed_children=map(fn W.Node(0,[identity,span,predecessors])=>
        (case(rows identity,rows span)of([request,goal,slot,interpretation,decision],[source,start,stop])=>
          {identity={request=atom request,goal=atom goal,slot=atom slot,interpretation=atom interpretation,
            decision=atom decision},source={source=atom source,start=integer start,stop=integer stop},
            predecessors=map unpair(rows predecessors)}:S.child|_=>error "Scope child header")
        |_=>error "Scope child header")children
      val image=take image_size
      val executable=take executable_size
      val receiver=if receiver_size=0 then Boot else Installed(take receiver_size)
      val family=take family_size
      val packet={saved={version=1,workspace=workspace,request=request,observation=S.StateTimeUnused,
          sources=sources,children=parsed_children},required=required,image=image,executable=executable,receiver=receiver,family=family}:packet
      val _=validate packet
      val _=require(encode packet=bytes) "Noncanonical scoped closure"
    in packet end;
  fun family bytes= #family(decode bytes);
end;
