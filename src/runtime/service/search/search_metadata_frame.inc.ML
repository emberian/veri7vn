(* Owner integration fragment: paste inside Veri7vn_Metadata_Frame's existing
   generated compilation unit, after encode_event. Never ML_file this separately:
   its @{code} terms must share the actual reducer's carrier universe. Numeric
   projections below are obtained ONLY from actual Source/Gate handles or their
   authenticated C/Scope restoration, not resident client packets. *)
type search_projection={identity:Veri7vn_Native_Request_Scope.identity,context:IntInf.int,
  receiver:IntInf.int,worker:IntInf.int,input:IntInf.int,cost:IntInf.int};
type search_control_names={capability:IntInf.int,operation:IntInf.int,profile:IntInf.int,step:IntInf.int,
  template:IntInf.int,claim:IntInf.int,parameter:IntInf.int,execution:IntInf.int,code:IntInf.int,
  evidence:IntInf.int,output:IntInf.int,batch:IntInf.int,exhausted:IntInf.int,budget:IntInf.int,
  deadline:IntInf.int,cancelled:IntInf.int,failed:IntInf.int};
fun search_control_values (p:search_projection) (n:search_control_names)=
  let val i= #identity p in
    [#request i,#goal i,#slot i,#interpretation i,#decision i,#receiver p,#input p,
     #capability n,#operation n,#profile n,#step n,#template n,#claim n,#parameter n,
     #execution n,#code n,#evidence n,#output n,#batch n,#exhausted n,#budget n,
     #deadline n,#cancelled n,#failed n]end;
fun search_control p n=
  let val values=search_control_values p n;
    val _=guard(length values=24 andalso forall(fn id=>id>0)values andalso
      length(distinct(op =)values)=length values) "Search native control domains overlap"
  in @{code search_service_control}(map nat values)end;
fun search_intrinsic_frame id=(guard(id>0) "Search intrinsic identity";
  encode_event(@{code search_service_intrinsic}(nat id)));
fun search_support_frames p n=map search_intrinsic_frame
  (filter(fn id=>id<> #parameter n andalso id<> #output n)(search_control_values p n));
fun search_prerequisites (p:search_projection) (n:search_control_names) native=
  let val i= #identity p in distinct(op =)
    ([#parameter n,#capability n,#operation n,#profile n,#code n,#template n,#input p,#receiver p,
      #interpretation i,#decision i]@native)end;
fun search_parameter_frame p n owned=encode_event
  (@{code search_service_parameter}(search_control p n)(map nat owned));
fun search_reserve_frame p n prestate cost deps=encode_event
  (@{code search_service_reserve}(search_control p n)(nat prestate)(nat cost)(map nat deps));
fun search_execute_frame p n cost=encode_event
  (@{code search_service_execute}(search_control p n)(nat cost));
fun search_evidence_frame p n deps native=encode_event
  (@{code search_service_evidence}(search_control p n)(map nat deps)(map nat native));
fun search_publish_frame p n deps native=encode_event
  (@{code search_service_publish}(search_control p n)(map nat deps)(map nat native));
fun search_stop stopped=case stopped of "exhausted"=> @{code SearchExhausted} |
    "budget"=> @{code SearchBudget} | "deadline"=> @{code SearchDeadline} |
    "cancelled"=> @{code SearchCancelled} | "failed"=> @{code SearchFailed} |
    _=>error "Unknown fixed native search stop";
fun search_stopped_frame p n stopped=
  encode_event(@{code search_service_stopped}(search_control p n)(search_stop stopped));
fun search_request_matches state p n deps cost=
  @{code search_service_request_matches}state(search_control p n)(map nat deps)(nat cost);
fun search_output_matches state p n deps native=
  @{code search_service_output_matches}state(search_control p n)(map nat deps)(map nat native);
fun search_execution_matches state p n cost consumed=
  @{code search_service_execution_matches}state(search_control p n)(nat cost)consumed;
fun search_stopped_matches state p n stopped=
  @{code search_service_stopped_matches}state(search_control p n)(search_stop stopped);
