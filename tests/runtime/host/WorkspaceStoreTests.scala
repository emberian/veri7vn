package veri7vn.runtime.host
import scala.language.unsafeNulls
import java.nio.file.Files

object WorkspaceStoreTests {
  def main(args: Array[String]): Unit = {
    import WorkspaceStore.*
    val root=Files.createTempDirectory("veri7vn-store-test-")
    var store=new WorkspaceStore(root,Limits(1024,4096,8,128))
    val original=Array[Byte](0,1,2,-1)
    require(store.commitDraft(0,"draft1",Vector(DraftFile("literal.bin",original)))==Right(DraftAck("draft1",1)))
    original(0)=99
    store.readDraft("draft1") match {
      case Available(v)=>require(v.files.head._2.sameElements(Array[Byte](0,1,2,-1)))
      case _=>sys.error("missing committed artifact")
    }
    require(store.commitDraft(0,"stale",Vector(DraftFile("x",Array[Byte](1))))==Left(Conflict(1)))
    require(store.revokeDraft("draft1"))
    require(store.readDraft("draft1")==Unavailable)
    val locator="a"*64
    require(store.compareAndAppend("source",None,locator))
    require(!store.compareAndAppend("source",None,"b"*64))
    require(store.withSourceHead("source")(identity)==Some(locator))
    require(store.revokeSource("source"))
    val versionBeforeIds=store.currentRevision
    val ids=store.reserveNativeIds(3)
    require(ids.first==BigInt(1) && ids.past==BigInt(4) && ids.workspace.matches("[0-9a-f]{32}"))
    require(store.currentRevision==versionBeforeIds,"ID allocation confused workspace revision")
    store.close(); store=new WorkspaceStore(root,Limits(1024,4096,8,128))
    require(store.readDraft("draft1")==Unavailable,"revoked payload restored")
    require(store.head("source").isEmpty)
    val afterCrash=store.reserveNativeIds(2)
    require(afterCrash.first==ids.past && afterCrash.workspace==ids.workspace,"native ID block reused after reopen")
    require(store.withSourceHead("source")(_=>sys.error("revoked source materialized")).isEmpty)
    require(!store.compareAndAppend("source",None,locator),"revoked source reacquired")
    var oversized=false
    try store.commitDraft(store.currentRevision,"too_large",Vector(DraftFile("x",new Array[Byte](1025))))
    catch {case _: IllegalArgumentException=>oversized=true}
    require(oversized)
    var aggregate=false
    try store.commitDraft(store.currentRevision,"aggregate",Vector.tabulate(5)(i=>DraftFile("x"+i,new Array[Byte](1024))))
    catch {case _: IllegalArgumentException=>aggregate=true}
    require(aggregate)
    val payloadSlots=Vector("projection","sequent","context_closure","reconstruction").map(name=>(name,name.getBytes(java.nio.charset.StandardCharsets.US_ASCII)))
    val payloadMap=payloadSlots.toMap
    val attributes=Vector("version"->"2","profile"->"native-kernel/1","role"->"kernel-evidence","workspace"->store.nativeWorkspace,"association"->"1000000000000000000000000000001","semantic-generation"->"2",
      "projection"->digest(payloadMap("projection")),"sequent"->digest(payloadMap("sequent")),"context-closure"->digest(payloadMap("context_closure")),
      "kind"->"fixed-certificate","payload"->digest(payloadMap("reconstruction")),"executable"->"")
    val manifest=("\u0005\u0006veri7vn-native-association\u0006"+attributes.map((k,v)=>k+"="+v).mkString("\u0006")+"\u0005\u0005\u0006\u0005").getBytes(java.nio.charset.StandardCharsets.US_ASCII)
    val slots=("manifest"->manifest)+:payloadSlots
    val material=new NativeRecoveryMaterial(BigInt("1000000000000000000000000000001"),BigInt(2),slots,Vector(BigInt("1000000000000000000000000000001"),BigInt(2)))
    def checkRole(profile:String,role:String,empty:Boolean,executable:Boolean,accepted:Boolean):Unit={
      val sequent=if(empty)Array.emptyByteArray else Array[Byte](1)
      val code=Array[Byte](7)
      val attrs=attributes.map {case(k,v)=>k->(k match {
        case "profile"=>profile
        case "role"=>role
        case "kind"=>"controlled-recipe"
        case "sequent"=>digest(sequent)
        case "executable"=>if(executable)digest(code)else ""
        case _=>v
      })}
      val frame=("\u0005\u0006veri7vn-native-association\u0006"+attrs.map((k,v)=>k+"="+v).mkString("\u0006")+"\u0005\u0005\u0006\u0005").getBytes(java.nio.charset.StandardCharsets.US_ASCII)
      val candidateSlots=("manifest"->frame)+:payloadSlots.map {case(n,b)=>n->(if(n=="sequent")sequent else b)}
      val candidate=new NativeRecoveryMaterial(material.association,BigInt(2),candidateSlots++(if(executable)Vector("executable"->code)else Vector.empty),material.dependencies)
      var allowed=true
      try {validateRecovery(store.nativeWorkspace,candidate)
        val expected=if(role=="effect-source-observation")"acquired-source" else if(role=="session-input")"source-input" else if(role.endsWith("-request"))"request-child" else if(role=="build-candidate")"artifact" else if(role=="domain-output" || role=="source-domain-output" || role=="search-output" || role=="math-output")"refined-output" else "observation"
        require(recoveryCategory(frame)==expected,"recovery category mismatch")
        val abstractRequirement=if(expected=="refined-output" || expected=="observation")"evidence" else expected
        require(matchesRecoveryRequirement(frame,abstractRequirement),"abstract recovery requirement mismatch")
        require(!matchesRecoveryRequirement(frame,if(abstractRequirement=="evidence")"artifact" else "evidence"),"cross-role recovery accepted")
        require(!matchesRecoveryRequirement(frame,"refined-output"),"legacy requirement category accepted")
      } catch {case _:IllegalArgumentException=>allowed=false}
      finally candidate.release()
      require(allowed==accepted,"closed role/sequent rule "+profile+"/"+role)
    }
    for((profile,role)<-Vector("local-mcp/1"->"effect-source-observation","native-session-input/1"->"session-input","source-quantities/1"->"source-domain-request","literal-native-proof/1"->"search-request","quantities/1"->"domain-request","native-development/1"->"build-request","native-development/1"->"build-candidate",
      "native-export-admission/1"->"initial-qualification","native-export-admission/1"->"initial-qualification-request",
      "named-native-export-structure/1"->"update-qualification","named-native-export-structure/1"->"update-qualification-request")){
      checkRole(profile,role,true,true,true)
      checkRole(profile,role,false,true,false)
      checkRole(profile,role,true,false,false)
    }
    checkRole("literal-native-proof/1","search-output",false,true,true)
    checkRole("literal-native-proof/1","search-output",true,true,false)
    checkRole("literal-native-proof/1","search-output",false,false,false)
    checkRole("source-quantities-runtime-refinement/1","source-domain-output",false,true,true)
    checkRole("source-quantities-runtime-refinement/1","source-domain-output",true,true,false)
    checkRole("source-quantities-runtime-refinement/1","source-domain-output",false,false,false)
    checkRole("native-session-input/1","domain-request",true,true,false)
    checkRole("quantities-runtime-refinement/1","domain-output",false,true,true)
    checkRole("quantities-runtime-refinement/1","domain-output",true,true,false)
    checkRole("quantities-runtime-refinement/1","domain-output",false,false,false)
    checkRole("native-kernel/1","kernel-evidence",true,false,false)
    checkRole("exact-arithmetic/1","math-request",true,true,false)
    checkRole("exact-arithmetic/1","math-output",true,true,false)
    checkRole("native-development/1","math-request",true,true,false)
    require(matchesRecoveryRequirement(manifest,"evidence") && !matchesRecoveryRequirement(manifest,"artifact"),"kernel evidence requirement")
    checkRole("exact-arithmetic/1","math-request",false,true,true)
    checkRole("exact-arithmetic/1","math-output",false,true,true)
    var wrongManifest=false
    val mismatched=new NativeRecoveryMaterial(material.association,BigInt(2),slots.map {case(name,bytes)=>(name,if(name=="sequent")Array[Byte](99) else bytes)},material.dependencies)
    try store.commitNative("native_wrong_slot",0,0,0,Array[Byte](1),Array[Byte](2),Some(mismatched))
    catch {case _: IllegalArgumentException=>wrongManifest=true}
    require(wrongManifest && store.latestNative.isEmpty,"manifest mismatch reached durable journal")
    val native=store.commitNative("native_material",0,0,0,Array[Byte](1),Array[Byte](2),Some(material)).get
    val intentRoot=Files.createTempDirectory("veri7vn-native-write-intent-")
    var interrupted=new WorkspaceStore(intentRoot,Limits(1024,4096,8,128))
    // Use this workspace's authenticated envelope in the storage seam fixture.
    val interruptedSlots=slots.map {case(name,bytes)=>(name,if(name=="manifest")new String(bytes,java.nio.charset.StandardCharsets.US_ASCII)
      .replace(store.nativeWorkspace,interrupted.nativeWorkspace).getBytes(java.nio.charset.StandardCharsets.US_ASCII) else bytes)}
    val interruptedMaterial=new NativeRecoveryMaterial(material.association,BigInt(2),interruptedSlots,material.dependencies)
    interrupted.afterNativeBlobPublish=()=>throw new IllegalStateException("after managed native write")
    var writeFailed=false
    try interrupted.commitNative("unadopted",0,0,0,Array[Byte](1),Array[Byte](2),Some(interruptedMaterial))
    catch {case _:IllegalStateException=>writeFailed=true}
    require(writeFailed && interrupted.latestNative.isEmpty)
    val plannedHash=digest(interruptedMaterial.slots.head._2)
    require(Files.exists(intentRoot.resolve("blobs").resolve(plannedHash)),"fault did not reach managed write")
    interrupted.close();interrupted=new WorkspaceStore(intentRoot,Limits(1024,4096,8,128))
    require(interrupted.latestNative.isEmpty && !Files.exists(intentRoot.resolve("blobs").resolve(plannedHash)),"unadopted private blob escaped startup intent cleanup")
    interrupted.close();interruptedMaterial.release()
    val expectedManifest=manifest.clone()
    slots.head._2(0)=0
    val protectedMaterial=store.committedNativeRecovery(native,material.association).get
    require(protectedMaterial.withMaterial(_.slots.find(_._1=="manifest").get._2.sameElements(expectedManifest)),"caller mutated committed manifest")
    require(store.committedNativeRecovery(native,material.association+1).isEmpty,"foreign association authorized")
    store.close(); store=new WorkspaceStore(root,Limits(1024,4096,8,128))
    require(store.committedNativeRecovery(store.latestNative.get,material.association).nonEmpty,"committed native slots not recovered")
    val liveCapability=store.committedNativeRecovery(store.latestNative.get,material.association).get
    val oldNativeView=liveCapability.withMaterial(_.slots.head._2)
    val dispatch=new NativeDispatchMaterial("pure",BigInt("1000000000000000000000000000002"),BigInt(0),"a"*64,"pure,1,2,3,4,5,6,7,8".getBytes)
    store.commitNative("native_next",1,0,0,Array[Byte](3),Array[Byte](4),dispatch=Some(dispatch))
    require(oldNativeView.forall(_==0.toByte),"journal advance retained captured native material bytes")
    val unknown=store.nativeDispatch("pure",dispatch.id,BigInt(0)).get
    require(unknown.sequence==2 && unknown.status=="unknown" && unknown.deployment=="a"*64,"dispatch was not durably unknown before handoff")
    var duplicateDispatch=false
    try store.commitNative("native_duplicate",2,0,0,Array[Byte](5),Array[Byte](6),dispatch=Some(dispatch))
    catch {case _:java.sql.SQLException=>duplicateDispatch=true}
    require(duplicateDispatch && store.latestNative.get.sequence==2,"duplicate dispatch advanced journal")
    store.close();store=new WorkspaceStore(root,Limits(1024,4096,8,128))
    require(store.nativeDispatch("pure",dispatch.id,BigInt(0)).exists(_.status=="unknown"),"unknown dispatch lost after restart")
    var capabilityDenied=false
    try protectedMaterial.withMaterial(_=>()) catch {case _:IllegalArgumentException=>capabilityDenied=true}
    require(capabilityDenied,"captured native material survived journal advance")
    require(store.committedNativeRecovery(native,material.association).isEmpty,"historical event authorized current recovery")
    val retained=store.committedNativeRecovery(store.latestNative.get,material.association).get
    require(retained.sequence==2 && retained.originSequence==1,"retained association confused current checkpoint and authorized origin")
    val publicId=material.association+2
    val publicSlots=material.slots.map {case(name,bytes)=>(name,if(name=="manifest")new String(expectedManifest,java.nio.charset.StandardCharsets.US_ASCII)
      .replace(material.association.toString,publicId.toString).getBytes(java.nio.charset.StandardCharsets.US_ASCII) else bytes)}
    val publicMaterial=new NativeRecoveryMaterial(publicId,BigInt(2),publicSlots,Vector(publicId,BigInt(3)))
    store.commitNative("native_public",2,0,0,Array[Byte](7),Array[Byte](8),Some(publicMaterial))
    val deniedRecord=store.commitNative("native_forget",3,0,0,Array[Byte](9),Array[Byte](10),
      invalidations=Some(new NativeInvalidations("forget",Vector(BigInt(2))))).get
    require(store.committedNativeRecovery(deniedRecord,material.association).isEmpty,"forgotten native dependency still restorable")
    require(store.committedNativeRecovery(deniedRecord,publicId).nonEmpty,"unrelated native artifact invalidated")
    require(store.hasForgottenNativeArtifacts,"native erasure intent missing")
    // Storage seam only: the real service must obtain its actual native cleanup
    // barrier before calling this method. This fixture asserts no HOL release.
    store.eraseForgottenNativeArtifacts()
    require(!store.hasForgottenNativeArtifacts && !Files.exists(root.resolve("blobs").resolve(digest(expectedManifest))),"native private origin manifest was not erased")
    require(store.committedNativeRecovery(store.latestNative.get,publicId).nonEmpty,"shared public native payload erased")
    var erasedRebind=false
    try store.commitNative("native_resurrect",4,0,0,Array[Byte](11),Array[Byte](12),Some(material))
    catch {case _:IllegalArgumentException=>erasedRebind=true}
    require(erasedRebind && store.latestNative.get.sequence==4,"erased native association revived")
    store.close();store=new WorkspaceStore(root,Limits(1024,4096,8,128))
    require(store.committedNativeRecovery(store.latestNative.get,material.association).isEmpty,"restart revived old native origin")
    require(store.committedNativeRecovery(store.latestNative.get,publicId).nonEmpty,"restart lost unrelated public artifact")
    store.close()
    val corrupt=Files.createTempDirectory("veri7vn-store-corrupt-")
    Files.write(corrupt.resolve("journal.db"),"not a database".getBytes)
    var rejected=false
    try new WorkspaceStore(corrupt) catch {case _: java.sql.SQLException=>rejected=true}
    require(rejected)
    val channel=java.nio.channels.FileChannel.open(corrupt.resolve("writer.lock"),java.nio.file.StandardOpenOption.WRITE)
    val lock=channel.tryLock(); require(lock!=null,"constructor leaked writer lease"); lock.release(); channel.close()
    import veri7vn.runtime.service.MetadataFrame.*
    val wire=Node(7,Vector(Atom(BigInt("123456789012345678901234567890")),Node(0,Vector())))
    require(decode(encode(wire))==wire)
    var bad=0
    for(bytes<-Vector(Array[Byte](2),encode(wire)++Array[Byte](0),encode(wire).dropRight(1))) {
      try decode(bytes) catch {case _: IllegalArgumentException=>bad+=1; case _: java.io.EOFException=>bad+=1}
    }
    require(bad==3)
    var deep: Wire=Atom(0); for(i<-1 to 65) deep=Node(0,Vector(deep))
    var bounded=false
    try encode(deep) catch {case _: IllegalArgumentException=>bounded=true}
    require(bounded)
    println("METADATA_FRAME_PASS natural_roundtrip unknown trailing truncated depth_bound")
    println("WORKSPACE_STORE_PASS exact_bytes cas revoke_restart source_tombstone bounded_payload")
  }
}
