(* Paste ONLY inside the ONE existing Metadata_Frame generated unit, after
   encode_event. Never ML_file separately: generated state/event carriers must be
   shared with its actual reducer. Plain records cross the native boundary. *)
type effect_names=Veri7vn_Native_Effect_Codec.names;
fun effect_names(n:effect_names)= @{code service_effect_names}
  (nat(#request n))(nat(#goal n))(nat(#interpretation n))(nat(#target n))
  (nat(#capability n))(nat(#profile n))(nat(#operation n))(nat(#step n))
  (nat(#generation n))(nat(#attempt n))(nat(#batch n));
fun effect_registration_frames names inputs=
  map(fn event=>case event of @{code RegisterManaged} value=>
      (integer(@{code retained_id}value),encode_event event)
    |_=>error "Fixed effect registration helper emitted another event")
    (@{code service_effect_registration}(effect_names names)(map nat inputs));
fun effect_reserve_frame names prestate dependencies=
  encode_event(@{code service_effect_reserve}(effect_names names)(nat prestate)(map nat dependencies));
fun effect_stage_frame names prestate sources dependencies=
  encode_event(@{code service_effect_stage}(effect_names names)(nat prestate)(map nat sources)(map nat dependencies));
fun effect_start_frame names=encode_event(@{code service_effect_start}(effect_names names));
fun effect_observation_frame batch attempt source rejected=
  encode_event(@{code service_effect_observation_stage}(nat batch)(nat attempt)(nat source)rejected);
fun effect_current_context state attempt= @{code service_effect_handoff_current}state(nat attempt);
fun effect_request_matches state (original:Veri7vn_Native_Effect_Codec.original)=
  @{code service_effect_request_matches}state(effect_names(#names original))(nat(#prestate original))
    (map nat(#sources original))(map nat(#dependencies original));
fun effect_recovery_matches state projection=case projection of
    Veri7vn_Native_Effect_Codec.Request original=>effect_request_matches state original
  |Veri7vn_Native_Effect_Codec.Observation{original,response,rejected,...}=>
    @{code service_effect_observation_matches}state(effect_names(#names original))(nat(#prestate original))
      (map nat(#sources original))(map nat(#dependencies original))(nat response)rejected;
fun effect_source_visible state {source,attempt,request,rejected}=
  @{code service_effect_source_visible}state(nat source)(nat attempt)(nat request)rejected;
fun effect_command_descriptor(command:claim_start)=
  let fun number n=(guard(n>=0 andalso size(IntInf.toString n)<=128) "Effect command natural bound";IntInf.toString n)
    fun vector values=(guard(length values<=8192) "Effect command vector bound";commas(map number values))
    val cost= #cost command
    val raw=YXML.string_of_body[XML.Elem(("effect-start-command",[("version","1"),
      ("attempt",number(#attempt command)),("request",number(#request command)),
      ("target",number(#target command)),("capability",number(#capability command)),
      ("prestate",number(#prestate command)),("epoch",number(#epoch command)),
      ("profile",number(#profile cost)),("code_generation",number(#code_generation cost)),
      ("operation",number(#operation cost)),("step",number(#step cost)),("units",number(#units cost)),
      ("sources",vector(#sources command)),("dependencies",vector(#dependencies command))]),[])]
  in guard(size raw<=16384) "Effect command descriptor byte bound";raw end;
fun effect_request_dependencies(original:Veri7vn_Native_Effect_Codec.original)=
  case @{code service_effect_request_origin}(effect_names(#names original))(nat(#prestate original))
      (map nat(#dependencies original)) of NONE=>error "Fixed effect request origin absent"
  |SOME request=>distinct(op =)(integer(@{code request_id}request)::
      map integer(@{code request_dependencies}request)@
      maps(fn goal=>map integer(@{code goal_references}goal))(@{code request_goals}request));
fun effect_observation_dependencies state {attempt,source,rejected}=
  case @{code effect_observation_retained}state(@{code service_effect_observation}(nat attempt)(nat source)rejected) of
    NONE=>NONE|SOME value=>SOME(map integer(@{code retained_dependencies}value));
fun effect_observation_permitted state {attempt,source,rejected}=
  @{code effect_observation_permitted}state(@{code service_effect_observation}(nat attempt)(nat source)rejected);
