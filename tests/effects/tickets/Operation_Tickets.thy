theory Operation_Tickets
  imports Veri7vn_Effect_Tickets.Veri7vn_Effect_Tickets
begin
ML \<open>
local
  structure Private = Veri7vn_Private_Operation_Tickets ();
  structure View : VERI7VN_OPERATION_TICKET_VIEW = Private;
  val issuer=Private.new_issuer ();
  fun context (version:IntInf.int) : {owner_version:IntInf.int,epoch:IntInf.int} = {owner_version=version,epoch=0};
  fun operation version : Private.operation_identity =
    {workspace="workspace",request=2,profile=4,code_generation=5,
     operation=6,step=0,cost=1,inputs=[7],owner_version=version,epoch=0,
     journal_sequence=1,semantic_generation=8,
     implementation_artifact="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"};
  fun identity version : Private.execution_identity = {execution=1,slot=3,operation=operation version};
  fun assert true _ = () | assert false text = error text;
  val scope=Private.begin_scope issuer (context 0);
  val ticket=Private.issue_pure scope (identity 0) (42:int);
  val answers=Par_List.map (fn _ => try View.consume_pure ticket) [1,2];
  val _=assert (length (map_filter I answers)=1) "concurrent ticket duplicate consumption";
  val _=assert (snd (the (find_first is_some answers) |> the)=42) "ticket native payload changed";
  val unused=Private.issue_pure scope (identity 0) (43:int);
  val _=assert (is_none (try (Private.begin_scope issuer) (context 0))) "parallel owner scope";
  val _=Private.close_scope scope;
  val _=assert (is_none (try View.consume_pure unused)) "closed ticket consumed";
  val next=Private.begin_scope issuer (context 1);
  val _=Private.close_scope scope;
  val _=assert (is_none (try (Private.begin_scope issuer) (context 2))) "old close reopened active issuer";
  val _=assert (is_none (try (Private.issue_pure next (identity 0)) (44:int))) "wrong owner-version ticket";
  val acquisition:Private.acquisition_identity={operation=operation 1,attempt=9,slot=3,source_binding=12,
    capability=10,target=11,sources=[12],dependencies=[13],protocol="local/1",receipt="receipt"};
  val acquired=Private.issue_acquisition next acquisition ("exact-input",42:int);
  val (_,payload)=View.consume_acquisition acquired;
  val _=assert (payload=("exact-input",42)) "acquired payload changed";
  val _=assert (is_none (try View.consume_acquisition acquired)) "acquisition ticket reused";
  val retention:Private.retention_identity={workspace="workspace",request=2,grant=14,
    object_id=15,destination=Private.SessionDestination 16,owner_version=1,epoch=0,journal_sequence=2};
  val retained=Private.issue_retention next retention ("recipient-only",17:int);
  val (_,retained_payload)=View.consume_retention retained;
  val _=assert (retained_payload=("recipient-only",17)) "retention payload changed";
  val _=assert (is_none (try View.consume_retention retained)) "retention ticket reused";
  val late_retention=Private.issue_retention next retention (18:int);
  val _=Private.close_scope next;
  val _=assert (is_none (try View.consume_retention late_retention)) "closed retention ticket consumed";
in
  val _=writeln "VERI7VN_EFFECTS operation_tickets PASS";
end;
\<close>
end
