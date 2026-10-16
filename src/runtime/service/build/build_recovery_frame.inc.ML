(* Include in the SAME F generated unit before restore_matches. The first
   resident build profile is a singleton request. Composite restoration needs
   its own captured common plan; this helper does not guess one. *)
type build_request_expectation={metadata:Veri7vn_Native_Development_Codec.metadata,
  payload:Veri7vn_Native_Development_Codec.payload,
  request:Veri7vn_Native_Build_Request_Envelope.packet};
type build_output_expectation={metadata:Veri7vn_Native_Development_Codec.metadata,
  payload:Veri7vn_Native_Development_Codec.payload};
fun build_restore_retained state (requests:build_request_expectation list)
    (outputs:build_output_expectation list)=
  let
    fun original(m:Veri7vn_Native_Development_Codec.metadata)=
      let val parents=filter(fn r=>integer(@{code request_id}r)= #request m)(@{code requests}state)
        val parent=case parents of [r]=>r|_=>error "Build original parent is not unique"
        val children=filter(fn g=>integer(@{code goal_id}g)= #goal m)(@{code request_goals}parent)
        val child=case children of [g]=>g|_=>error "Build original child is not unique"
      in guard(length(@{code request_goals}parent)=1) "Unsupported composite Build restoration";
        (parent,child)end;
    fun registered frame=case decode_event frame of SOME(@{code RegisterManaged}row)=>row
      |_=>error "Build expected registration profile";
    fun request_rows({metadata=m,request=packet,...}:build_request_expectation)=
      let val control= #plan packet;val names=build_names_from_plan control
        val(parent,child)=original m
        val native=distinct(op =)(#dependencies m @ #parents m)
        val dependencies=distinct(op =)([#template control,#profile control,#setup control,
          #operation control,#capability control,#step control,#operation_generation control,
          #code_generation control] @ native)
        val _=guard(@{code request_dependencies}parent=map nat dependencies)
          "Build original shared dependencies differ from native producer"
        val supports=distinct(op =)(#interpretation control:: #capability control::dependencies)
        val parameter=registered(build_parameter_frame names parent child native
          (distinct(op =)(#source_owner m:: #parents m))[])
        val has_parameter=exists(fn row=> @{code retained_id}row=nat(#parameter control))
          (@{code retained_values}state)
      in map(registered o build_intrinsic_frame)supports @
        (if has_parameter then[parameter]else[])end;
    fun output_rows({metadata=m,...}:build_output_expectation)=
      let val paired=filter(fn{metadata=r,...}:build_request_expectation=>
          #request r= #request m andalso #goal r= #goal m andalso #slot r= #slot m)requests
        val packet=case paired of [{request,...}]=>request
          |_=>error "Build candidate lacks exact original request"
        val names=build_names_from_plan(#plan packet)
        val(parent,child)=original m
        val required=build_requirement(build_projection_from_metadata m)
        val closure=distinct(op =)(#dependencies m @ #parents m @ #input_bindings m)
        val frame=build_artifact_frame names parent child required(#semantic_generation m)
          closure(#input_bindings m)(@{code RequestLocal}(nat(#request m)))[]
        val assignment=case decode_event frame of
          SOME(@{code StageOutput}(_, @{code ArtifactOutput}a,NONE))=>a
          |_=>error "Build expected artifact profile"
        val matches=filter(fn actual=> @{code artifact_assigned_output}actual=nat(#candidate m))
          (@{code required_native_artifacts}state)
        val _=guard(matches=[assignment]) "Build retained assignment differs from native producer"
        val _=guard(@{code artifact_expected_retained}state assignment=
          SOME(@{code artifact_assigned_retained}assignment))
          "Build artifact retention is not canonical for its original owner"
      in @{code artifact_assigned_retained}assignment end;
    val _=guard(sort IntInf.compare(map(fn{metadata,...}:build_output_expectation=> #candidate metadata)outputs)=
      sort IntInf.compare(map(integer o @{code artifact_assigned_output})(@{code required_native_artifacts}state)))
      "Build native artifact coverage differs"
  in maps request_rows requests @ maps output_rows outputs end;
