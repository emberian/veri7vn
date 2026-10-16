(* Paste inside SAME F generated universe after the existing Search helpers.
   Add to recovery_view, alongside SearchRequestAssociation:
     SearchSourceSupportAssociation of search_source_expectation
   This view covers the original RequestChildRole and retained source rows;
   it grants no active Q/Scope association or execution permission. *)
type search_source_expectation={names:search_projection,control:search_control_names,
  dependencies:IntInf.int list,
  phase:{execution:IntInf.int option,stopped:string option,reason:IntInf.int option}};
fun search_input_frame p n=encode_event(@{code search_service_input}(search_control p n));
(* Shadows the earlier generic definition in this SAME F unit. The original
   source has one explicit request owner; other intrinsic producer identities
   retain their existing associations. *)
fun search_support_frames p n=map(fn id=>if id= #input p then search_input_frame p n
    else search_intrinsic_frame id)
  (filter(fn id=>id<> #parameter n andalso id<> #output n)(search_control_values p n));
fun search_phase_valid(control:search_control_names)
    {execution,stopped,reason}=
  (case execution of NONE=>true|SOME id=>id= #execution control)andalso
  (case(stopped,reason)of(NONE,NONE)=>true|
    (SOME kind,SOME id)=>is_some execution andalso id=(case kind of
      "exhausted"=> #exhausted control|"budget"=> #budget control|
      "deadline"=> #deadline control|"cancelled"=> #cancelled control|
      "failed"=> #failed control|_=>0)|_=>false);
fun search_source_matches state
    ({names,control,dependencies,phase}:search_source_expectation)=
  search_phase_valid control phase andalso
  #context names= #receiver names andalso #worker names= #receiver names andalso
  @{code search_service_source_matches}state(search_control names control)
    (map nat dependencies)(nat(#cost names))(is_some(#execution phase));
fun search_source_retained({names,control,dependencies,...}:search_source_expectation)=
  map(fn frame=>case decode_event frame of SOME(@{code RegisterManaged}row)=>row|
    _=>error "Search retained original-source support profile differs")
    (search_support_frames names control @ [search_parameter_frame names control dependencies]);
(* restore_matches splice:
   val search_sources=map_filter(fn SearchSourceSupportAssociation value=>SOME value|_=>NONE)views;
   val _=List.app(fn value=>guard(search_source_matches state value)
     "Restored Search original source differs from retained cancelled requirement")search_sources;
   Add search_sources' exact (rid,gid,slot) keys to request_keys while the common
   required-original-slot inventory still includes cancelled requests. Once the
   core splits active and inert source inventories, compare them independently.
   Add maps search_source_retained search_sources to retained. The original
   SourceSupportAssociation fields come ONLY from SearchResident.expected_source.
   Do not weaken active SearchRequestAssociation or terminal continuation checks.
*)
