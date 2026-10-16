(* Internal lifetime coordination only. A claim grants exclusive cleanup of one
   already-owned reference; it carries no native identity or execution authority. *)
structure Veri7vn_Native_Release_Claim :>
sig
  type owner
  type claim
  val create:unit -> owner
  val is_live:owner -> bool
  val with_live:owner -> (unit -> 'a) -> 'a
  val try_claim:owner -> claim option
  val finish:claim -> unit
  val retry:claim -> unit
end =
struct
  datatype state=Live|InProgress of serial|Retry|Done of serial;
  datatype owner=Owner of state Synchronized.var;
  datatype claim=Claim of owner * serial;
  fun create()=Owner(Synchronized.var "native_release_claim" Live);
  fun is_live(Owner cell)=case Synchronized.value cell of Live=>true|_=>false;
  fun with_live(Owner cell) action=Synchronized.change_result cell
    (fn Live=>(action(),Live)|_=>error "Native owner released or releasing");
  fun try_claim(owner as Owner cell)=Synchronized.change_result cell
    (fn Live=>let val key=serial()in(SOME(Claim(owner,key)),InProgress key)end
      |Retry=>let val key=serial()in(SOME(Claim(owner,key)),InProgress key)end
      |state=>(NONE,state));
  fun finish(Claim(Owner cell,key))=Synchronized.change cell
    (fn InProgress current=>if current=key then Done key else error "Stale native cleanup claim"
      |Done current=>if current=key then Done current else error "Stale native cleanup claim"
      |_=>error "Native cleanup claim is not active");
  fun retry(Claim(Owner cell,key))=Synchronized.change cell
    (fn InProgress current=>if current=key then Retry else error "Stale native cleanup claim"
      |_=>error "Native cleanup claim is not active");
end;
