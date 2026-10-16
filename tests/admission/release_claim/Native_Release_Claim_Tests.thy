theory Native_Release_Claim_Tests
  imports "Veri7vn_Native_Lifetime.Native_Lifetime"
begin
ML \<open>
local
  structure Claim=Veri7vn_Native_Release_Claim;
  fun assert true _=()|assert false message=error message;
  val owner=Claim.create();
  val _=assert(not(Claim.is_done owner)) "Live owner reported completed cleanup";
  val first=the(Claim.try_claim owner);
  (* Keep the actual first claim outstanding while a second thread attempts
     cleanup of the SAME owner. No scheduler race or timeout establishes this. *)
  val second=Future.fork(fn()=>Claim.try_claim owner);
  val _=assert(is_none(Future.join second)) "Concurrent same-owner release acquired a second claim";
  val _=assert(not(Claim.is_live owner) andalso not(can(Claim.with_live owner)(fn()=>())))
    "Retain allowed while cleanup owns the handle";
  val _=assert(not(Claim.is_done owner)) "In-progress cleanup reported completion";
  val _=Claim.retry first;
  val _=assert(not(Claim.is_done owner)) "Retryable failed cleanup reported completion";
  val retry=the(Claim.try_claim owner);
  val _=assert(not(can Claim.finish first) andalso not(can Claim.retry first))
    "Stale failed claim completed a later cleanup attempt";
  val blocked=Future.fork(fn()=>Claim.try_claim owner);
  val _=assert(is_none(Future.join blocked)) "Retry cleanup allowed a concurrent second claimant";
  val _=Claim.finish retry;
  val _=Claim.finish retry;
  val _=assert(is_none(Claim.try_claim owner) andalso not(Claim.is_live owner) andalso Claim.is_done owner)
    "Completed owner became retainable or releasable again";
  val _=writeln "native_release_claim_concurrent_retry_finish_ok";
in end;
\<close>
end
