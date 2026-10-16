(* Fixed native exporter over an ACTUAL independently retained SessionEntry.
   Artifacts are inert until the same authoritative source row is committed.
   This neither records an utterance nor creates a current observation pin. *)
functor Veri7vn_Native_Session_Input_Export
  (structure Entry:VERI7VN_NATIVE_SESSION_ENTRY
   val executable:Veri7vn_Executable_Identity.pin) :>
sig
  type artifacts={projection:string,sequent:string,context_closure:string,
    reconstruction:string,executable:string}
  val qualify:Veri7vn_Native_Identity_Allocator.allocator ->
    Veri7vn_Native_Recovery_Check.image -> Veri7vn_Native_Installed_Roots.registry ->
    Entry.entry -> artifacts
end =
struct
  structure P=Veri7vn_Managed_Provenance;
  structure I=Veri7vn_Native_Identity_Allocator;
  structure L=Veri7vn_Native_Literals;
  structure V=Veri7vn_Native_Recovery_Check;
  structure A=Veri7vn_Native_Admission;
  structure E=Veri7vn_Executable_Identity;
  structure D=Veri7vn_Native_Construction_Codec;
  structure Q=Veri7vn_Native_Recovery_Source;
  structure Codec=Veri7vn_Session_Input_Codec;
  structure Pin=Veri7vn_Native_Recovery_Pin;
  type artifacts={projection:string,sequent:string,context_closure:string,
    reconstruction:string,executable:string};
  fun require true _=()|require false message=error message;
  fun export allocator image roots entry=
    let val development=Entry.development entry
      val original=Entry.snapshot entry
      val identity= #identity original
      val actual_input=Entry.input entry
      val policy=V.image_policy image
      val _=require(Entry.retained entry andalso P.development_live development andalso
        #workspace identity=I.workspace allocator andalso
        P.development_workspace development= #workspace identity andalso
        I.lookup_input_identity allocator actual_input=SOME(#utterance identity) andalso
        L.bytes actual_input= #bytes original andalso L.encoding actual_input= #encoding original andalso
        Context.subthy(E.code_theory executable,A.policy_theory policy))
        "Session export is not the actual retained source/context/image association"
      val head=case I.lookup_generation_id allocator(P.generation development)of
          SOME id=>id|NONE=>error "Session export has no original native source generation"
      val metadata={version=1,workspace= #workspace identity,session= #session identity,
        utterance= #utterance identity,source_generation=head,
        source_dependencies=P.development_dependencies development,
        observation= #observation original,input_encoding= #encoding original,input_bytes= #bytes original}:Codec.metadata
      val(graph,owners)=D.collect_for_image roots policy allocator development
      val payload={graph=graph}:Codec.payload
      val _=Codec.check_graph metadata payload
      fun source id=
        let val owner=case find_first(fn owner=>P.source_identity owner=id)owners of
              SOME owner=>owner|NONE=>error "Session export native code-source owner is absent"
          val input=P.source_input owner
          val _=require(P.source_workspace owner=I.workspace allocator andalso
            I.lookup_input_identity allocator input=SOME id andalso L.retained input andalso
            L.encoding input="UTF-8") "Session export native code source is not its actual original UTF8 owner"
        in {id=id,encoding=L.encoding input,bytes=L.bytes input}:Q.source_record end
      val closure=Q.encode{image=V.context_closure image,sources=map source(D.source_ids graph)}
      val result={projection=Codec.encode_projection metadata,sequent="",context_closure=closure,
        reconstruction=Codec.encode_payload payload,executable=Pin.material executable}:artifacts
      val _=require(Entry.retained entry andalso P.development_live development)
        "Session source/context revoked during export"
    in result end;
  fun qualify allocator image roots entry=
    Thread_Attributes.with_attributes Thread_Attributes.no_interrupts(fn original=>
      let val owner=Entry.retain entry
        val result=Exn.capture(fn()=>Thread_Attributes.with_attributes original
          (fn _=>export allocator image roots owner))()
        val _=Entry.release owner
      in Exn.release result end);
end;
