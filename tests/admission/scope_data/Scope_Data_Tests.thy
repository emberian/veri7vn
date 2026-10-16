theory Scope_Data_Tests
  imports Veri7vn_Native_Scope_Data.Native_Scope_Data
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
in val _=writeln "RECOVERY pure_scope_envelope_physical_labels_and_erased_subset PASS";end;
\<close>
end
