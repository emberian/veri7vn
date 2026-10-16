theory Scope_Envelope_Tests
  imports Veri7vn_Native_Request_Scope.Native_Request_Scope
begin
ML \<open>
local
  structure S=Veri7vn_Native_Scope_Saved;
  structure E=Veri7vn_Native_Scope_Envelope;
  structure W=Veri7vn_Native_Authority_Wire;
  fun check true _=()|check false text=error text;
  fun rejects f text=case Exn.capture f()of
      Exn.Res _=>error text
    |Exn.Exn failure=>if Exn.is_interrupt failure then Exn.reraise failure else();
  fun child goal slot interpretation decision source predecessors:S.child=
    {identity={request=1,goal=goal,slot=slot,interpretation=interpretation,decision=decision},
     source={source=source,start=0,stop=1},predecessors=predecessors};
  val originals=[{identity=20,encoding="UTF-8",bytes="x"},
    {identity=21,encoding="binary",bytes="x"}]:S.source list;
  val plan=[child 2 3 4 5 20 [],child 6 7 8 9 21 [(2,3)],
    child 10 11 12 13 22 [(6,7)]];
  fun packet sources required receiver:E.packet=
    {saved={version=1,workspace="00000000000000000000000000000001",request=1,
       observation=S.StateTimeUnused,sources=sources,children=plan},
     required=required,image="actual-image-placeholder-data",executable="actual-pin-placeholder-data",
     receiver=receiver,family="\000\005\006unchanged-family\255"};
  structure Encoding=Veri7vn_Native_Recovery_Encoding;
  val _=check(Encoding.valid "UTF-8" "\000\127\194\128\224\160\128\237\159\191\244\143\191\191")
    "UTF8 rejected valid boundary scalar values";
  val _=List.app(fn bytes=>check(not(Encoding.valid "UTF-8" bytes) andalso
      Encoding.valid "binary" bytes andalso Encoding.valid "native-term/1" bytes)
      "Physical encoding conflated malformed text and binary")
    ["\128","\192\128","\224\159\191","\237\160\128","\244\144\128\128","\245\128\128\128","\226\130"];
  structure Pool=Veri7vn_Native_Recovery_Inputs;
  structure L=Veri7vn_Native_Literals;
  structure I=Veri7vn_Native_Identity_Allocator;
  structure TestInput=Veri7vn_Checked_Recovery_Input_Pool(struct
    type verified={workspace:string,identity:IntInf.int,encoding:string,bytes:string}
    fun binding(value:verified)=value
  end);
  val ids=I.install_host_block{workspace="1234567890abcdef1234567890abcde1",first=1,past=1000};
  val pool=Pool.create ids;
  fun acquire identity encoding bytes=TestInput.acquire pool
    {workspace=I.workspace ids,identity=identity,encoding=encoding,bytes=bytes};
  val utf=acquire 10 "UTF-8" "x";
  val binary=acquire 11 "binary" "x";
  val native=acquire 12 "native-term/1" "x";
  val _=check(not(L.same_input(Pool.input utf,Pool.input binary)) andalso
    not(L.same_input(Pool.input binary,Pool.input native))) "Pool erased exact physical labels";
  val _=rejects(fn()=>acquire 10 "binary" "x") "Pool accepted same saved ID with another encoding";
  val _=rejects(fn()=>acquire 13 "UTF-8" "\192\128") "Pool accepted malformed UTF8";
  val raw=acquire 13 "binary" "\192\128";
  val raw_input=Pool.input raw;
  val _=Pool.close pool;
  val _=List.app Pool.release[utf,binary,native,raw];
  val _=check(L.disposed raw_input) "Pool did not dispose final binary owner";
  val original=packet originals [(2,3),(6,7)](E.Installed "HOL.Main");
  val bytes=E.encode original;
  val decoded=E.decode bytes;
  val _=check(E.encode decoded=bytes andalso #family decoded= #family original)
    "Scope envelope changed physical family bytes";
  val _=check(map #encoding(#sources(#saved decoded))=["UTF-8","binary"])
    "Scope envelope relabelled identical physical bytes";
  val _=check(length(#children(#saved decoded))=3 andalso length(#sources(#saved decoded))=2)
    "Scope envelope resurrected forgotten inactive source or removed original plan";
  val _=rejects(fn()=>E.encode(packet originals [(6,7),(2,3)] E.Boot))
    "Scope accepted reordered accessible subset";
  val _=rejects(fn()=>E.encode(packet originals [(2,3),(6,7),(10,11)] E.Boot))
    "Scope accepted required child with erased original";
  val _=rejects(fn()=>E.encode(packet(originals @
      [{identity=22,encoding="binary",bytes="z"}])[(2,3),(6,7)] E.Boot))
    "Scope retained erased inactive original";
  val _=rejects(fn()=>E.decode(bytes^"x"))"Scope ignored trailing closure data";
  val _=rejects(fn()=>E.decode(String.substring(bytes,0,size bytes-1)))
    "Scope accepted truncated physical source/family";
  val _=rejects(fn()=>W.read("\000\000\000\000\00201"))
    "Shared AuthorityWire accepted noncanonical natural";
  val _=check(W.write(W.read(W.write(W.Node(7,[W.Atom 0,W.Atom 123]))))=
    W.write(W.Node(7,[W.Atom 0,W.Atom 123]))) "Shared AuthorityWire roundtrip";
in val _=writeln "RECOVERY scope_envelope_physical_labels_and_erased_subset PASS";end;
\<close>
end
