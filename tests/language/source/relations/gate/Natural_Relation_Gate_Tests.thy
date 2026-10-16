theory Natural_Relation_Gate_Tests
  imports Veri7vn_Natural_Relation_Gate.Natural_Relation_Gate
    Veri7vn_Natural_Relation_Questions_Tests.Natural_Relation_Questions_Tests
    Veri7vn_Row_Kernel_Tests.Row_Kernel_Tests
begin
ML \<open>
local
  structure G=Veri7vn_Native_Relation_Language_Gate;
  structure L=Veri7vn_Native_Literals;
  structure P=Veri7vn_Managed_Provenance;
  structure I=Veri7vn_Native_Identity_Allocator;
  structure RI=Veri7vn_Row_Instance;
  val ids=I.install_host_block{workspace="22222222222222222222222222222222",
    first=3000000000000000000000000000000,past=3000000000000000000000000060000};
  val generation=Veri7vn_Native_Registry.generation @{context}
    {packages=[],runtime="protected language consumer",policy="test image",sources=[],interpretation="fixed reader"};
  val instance=RI.qualify{input_bytes=65536,materialized_rows=256,metadata_nodes=20000,
    metadata_depth=128,metadata_bytes=65536,seconds=5};
  val simp=@{context} addsimps @{thms kernel_acquisition_def kernel_query_def kernel_context_def kernel_clock_def};
  val metadata=Simplifier.rewrite simp @{cterm "(kernel_acquisition,kernel_query,kernel_context)"} |> Thm.rhs_of;
  val parent=RI.elaborate instance {generation=generation,metadata=metadata};
  val declaration_term=Thm.rhs_of(Code_Simp.dynamic_conv @{context} @{cterm reader_fixture});
  val declaration=L.input{bytes=G.declaration_bytes declaration_term,encoding="native-term/1"};
  val utterance=L.input{bytes="who wrote Pride and Prejudice?",encoding="UTF-8"};
  val other=L.input{bytes=L.bytes utterance,encoding="UTF-8"};
  val false_version=L.input{bytes=G.declaration_bytes
    (Thm.rhs_of(Code_Simp.dynamic_conv @{context}
      @{cterm "reader_fixture\<lparr>reader_revision := [2]\<rparr>"})),encoding="native-term/1"};
  val false_version_owner=P.install_host_source ids false_version;
  val u=P.install_host_source ids utterance;
  val d=P.install_host_source ids declaration;
  val wrong=P.install_host_source ids other;
  val declared=G.bind_declaration{parent=parent,input=declaration,owner=d};
  val false_declared=G.bind_declaration{parent=parent,input=false_version,owner=false_version_owner};
  val sibling_declared=G.bind_declaration{parent=parent,input=declaration,owner=d};
  fun select owner=G.select{utterance=utterance,utterance_owner=owner,
    declaration=declared,index=0};
  val _=if is_none(try select wrong) then () else error "Equal bytes forged protected ownership";
  val _=if is_none(try(fn()=>G.select{utterance=utterance,utterance_owner=u,
    declaration=false_declared,index=0})())
    then () else error "Declaration relabeled the fixed native reader version";
  val _=(case G.inspect{utterance=utterance,utterance_owner=u,
    declaration=declared} of G.Readings [0]=>()
    | _=>error "Recognized question lost reading status");
  val ambiguous=L.input{bytes="what is the author of Pride and Prejudice?",encoding="UTF-8"};
  val ambiguous_owner=P.install_host_source ids ambiguous;
  val _=(case G.inspect{utterance=ambiguous,utterance_owner=ambiguous_owner,
    declaration=declared} of G.Readings [0,1]=>()
    | _=>error "Property alternatives were silently selected");
  val diagnostic=G.describe{utterance=ambiguous,utterance_owner=ambiguous_owner,
    declaration=declared} 1;
  val _=if #property diagnostic=57 andalso #entities diagnostic=[170583] andalso
    L.original(#entity diagnostic)="Pride and Prejudice" andalso
    Option.map L.original (#property_capture diagnostic)=SOME "author" andalso
    #reader_revision diagnostic=[118,49] then () else error "Ambiguity diagnostic guessed labels or spans";
  val unknown=L.input{bytes="nonsense",encoding="UTF-8"};
  val _=(case G.inspect{utterance=unknown,utterance_owner=P.install_host_source ids unknown,
    declaration=declared} of G.Unrecognized=>()
    | _=>error "Unrecognized question received a reading");
  val reading=select u;
  val _=if Thm.term_of(RI.relation_metadata(G.recipe reading))= @{term "SnapshotRelationQuery [170583] 50"}
    then () else error "Selected reader request changed before native recipe";
  val _=if L.original(G.capture reading)="Pride and Prejudice" then () else error "Original byte span changed";
  val retained_recipe=G.recipe reading;
  val surviving=G.select{utterance=utterance,utterance_owner=u,declaration=sibling_declared,index=0};
  val _=G.release_declaration declared;
  val _=if L.retained declaration andalso is_none(try RI.relation_parent retained_recipe) andalso
    is_some(try G.recipe surviving) then () else error "Occurrence retirement affected sibling or left escaped authority";
  val sibling=L.retain declaration;
  val _=L.invalidate declaration;
  val _=if not(L.disposed declaration) andalso is_none(try L.lease_input sibling) then ()
    else error "Invalidated declaration sibling retained authority or lost storage";
  val _=if is_none(try RI.relation_parent retained_recipe) then ()
    else error "Escaped recipe survived declaration invalidation";
  val _=if is_none(try G.recipe reading) then () else error "Invalid declaration retained query authority";
  val _=G.release reading;
  val _=G.release reading;
  val _=if is_none(try RI.relation_parent retained_recipe) then ()
    else error "Released language reading retained native query authority";
  val _=Option.app I.release_disposed_input(L.release sibling);
  val _=G.release surviving;
  val _=G.release_declaration sibling_declared;
  val _=G.release_declaration false_declared;
  val _=RI.release instance;
  val _=List.app(fn input=>Option.app I.release_disposed_input(L.drop_base input)) [utterance,declaration,other,false_version,ambiguous,unknown];
in val _=writeln "LANGUAGE protected_relation_recipe_bridge PASS" end;
\<close>
end
