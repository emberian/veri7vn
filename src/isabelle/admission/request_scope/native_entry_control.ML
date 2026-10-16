(* A shared lifetime cell, never a permission or execution state machine. Typed
   entries retain their own jobs/outputs; the Owner remains authority. *)
signature VERI7VN_NATIVE_ENTRY_CONTROL =
sig
  type cell
  val create: bool -> cell
  val incarnation: cell -> serial
  val active: cell -> bool
  val deny: cell -> unit
  val released: cell -> bool
  val mark_released: cell -> unit
end;
structure Veri7vn_Native_Entry_Control :> VERI7VN_NATIVE_ENTRY_CONTROL =
struct
  datatype cell=Cell of {incarnation:serial,active:bool Synchronized.var,
    released:bool Synchronized.var};
  fun create active=Cell{incarnation=serial(),active=Synchronized.var "entry_active" active,
    released=Synchronized.var "entry_released" false};
  fun incarnation(Cell{incarnation,...})=incarnation;
  fun active(Cell{active,released,...})=Synchronized.value active andalso not(Synchronized.value released);
  fun deny(Cell{active,...})=Synchronized.change active(K false);
  fun released(Cell{released,...})=Synchronized.value released;
  fun mark_released(Cell{active,released,...})=
    (Synchronized.change active(K false);Synchronized.change released(K true));
end;
