(* Fixed producer instantiated only with the parent's actual EffectCore. No
   reconstruction callback, execution state or numeric context selector. *)
functor Veri7vn_Native_Effect_Export
  (structure Core:sig
     type entry
     val context:entry->Veri7vn_Managed_Provenance.development
     val input_binding:entry->Veri7vn_Native_Effect_Inputs.binding
     val original_metadata:entry->IntInf.int->Veri7vn_Native_Effect_Codec.original
     val response_state:entry->Veri7vn_Native_Effect_Responses.response->{prestate:IntInf.int,epoch:IntInf.int}
   end
   val executable:Veri7vn_Executable_Identity.pin) :>
sig
  type artifacts={projection:string,sequent:string,context_closure:string,reconstruction:string,executable:string}
  val request:Veri7vn_Native_Identity_Allocator.allocator->Veri7vn_Native_Recovery_Check.image->Core.entry->IntInf.int->artifacts
  val observation:Veri7vn_Native_Identity_Allocator.allocator->Veri7vn_Native_Recovery_Check.image->Core.entry->
    Veri7vn_Native_Effect_Observation.checked->string->artifacts
end =
struct
  structure Codec=Veri7vn_Native_Effect_Codec;
  structure P=Veri7vn_Managed_Provenance;
  structure I=Veri7vn_Native_Identity_Allocator;
  structure N=Veri7vn_Native_Registry;
  structure L=Veri7vn_Native_Literals;
  structure V=Veri7vn_Native_Recovery_Check;
  structure A=Veri7vn_Native_Admission;
  structure D=Veri7vn_Native_Construction_Codec;
  structure E=Veri7vn_Executable_Identity;
  structure Check=Veri7vn_Native_Effect_Observation;
  structure Responses=Veri7vn_Native_Effect_Responses;
  type artifacts={projection:string,sequent:string,context_closure:string,reconstruction:string,executable:string};
  fun require true _=()|require false message=error message;
  fun context allocator image entry (original:Codec.original) witness=
    let val development=Core.context entry
      val policy=V.image_policy image
      val _=require(P.development_live development andalso P.development_workspace development= #workspace original
        andalso I.workspace allocator= #workspace original andalso
        I.lookup_generation_id allocator(P.generation development)=SOME(#generation(#names original)) andalso
        Context.eq_thy(Proof_Context.theory_of(N.context(P.generation development)),A.policy_theory policy) andalso
        Context.subthy(E.code_theory executable,A.policy_theory policy)) "Effect original installed context mismatch"
      val(graph,owners)=D.collect allocator development
      val _=require(null owners andalso null(D.source_ids graph)) "Fixed effect image unexpectedly contains code source replay"
      val binding=Core.input_binding entry
      fun input source id expected=
        let val actual=P.source_input source
          val _=require(P.source_identity source=id andalso P.source_workspace source= #workspace original
            andalso I.lookup_input_identity allocator actual=SOME id andalso L.retained actual andalso L.encoding actual="UTF-8"
            andalso size(L.bytes actual)= #size(expected:Veri7vn_Native_Effect_Inputs.source_data) andalso
            Codec.digest(L.bytes actual)= #sha256 expected) "Effect original source identity/bytes differ"
        in L.bytes actual end
      val originals={configuration=input(#configuration binding)(#configuration original)(#configuration_source original),
        packet=input(#packet binding)(#packet original)(#packet_source original)}:Codec.originals
    in Codec.encode_context original {image=V.context_closure image,graph=graph,originals=originals,witness=witness}end;
  fun request allocator image entry prestate=
    let val original=Core.original_metadata entry prestate
    in {projection=Codec.encode(Codec.Request original),sequent="",
      context_closure=context allocator image entry original NONE,
      reconstruction="veri7vn-effect-request/2",executable=Veri7vn_Native_Recovery_Pin.material executable}:artifacts end;
  fun observation allocator image entry checked witness=
    let val response=Check.response checked
      val actual=Core.response_state entry response
      val original=Core.original_metadata entry(#prestate actual)
      val expected={workspace= #workspace original,attempt= #attempt(#names original),
        request= #request(#names original),capability= #capability(#names original),
        operation= #operation original,configuration= #configuration original,
        configuration_epoch= #configuration_epoch original,configuration_source= #configuration_source original,
        packet_source= #packet_source original}:Check.expected
      val checked_again=Check.check expected response witness
      val rejected=case Check.status checked_again of Check.RejectedResponse=>true|Check.ConfirmedResponse=>false
      val projection=Codec.Observation{original=original,response=P.source_identity(Responses.source response),
        epoch= #epoch actual,rejected=rejected,receipt=Check.receipt_digest checked_again,schema=Check.schema checked_again}
    in {projection=Codec.encode projection,sequent="",context_closure=context allocator image entry original(SOME witness),
      reconstruction=L.bytes(P.source_input(Responses.source response)),
      executable=Veri7vn_Native_Recovery_Pin.material executable}:artifacts end;
end;
