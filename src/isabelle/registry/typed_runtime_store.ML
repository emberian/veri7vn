(* Instantiated privately by a finite generated bundle. There is no interpreter,
   conversion callback, evidence constructor, or dynamically typed value here. *)
signature VERI7VN_RUNTIME_CARRIERS =
sig
  type value
  type continuation
  val executable: Veri7vn_Executable_Identity.pin
end;
signature VERI7VN_TYPED_RUNTIME_STORE =
sig
  type value
  type continuation
  type value_handle
  type continuation_handle
  type store
  val empty: store
  val executable: Veri7vn_Executable_Identity.pin
  val put_value: value -> store -> value_handle * store
  val put_continuation: continuation -> store -> continuation_handle * store
  val value: Veri7vn_Executable_Identity.pin -> value_handle -> store -> value
  val continuation: Veri7vn_Executable_Identity.pin -> continuation_handle -> store -> continuation
  val remove_value: value_handle -> store -> store
  val remove_continuation: continuation_handle -> store -> store
end;
functor Veri7vn_Typed_Runtime_Store (Carriers: VERI7VN_RUNTIME_CARRIERS)
  :> VERI7VN_TYPED_RUNTIME_STORE
    where type value = Carriers.value
      and type continuation = Carriers.continuation =
struct
  type value = Carriers.value;
  type continuation = Carriers.continuation;
  datatype value_handle = Value_Handle of serial;
  datatype continuation_handle = Continuation_Handle of serial;
  type store = {values: value Inttab.table, continuations: continuation Inttab.table};
  val executable = Carriers.executable;
  val empty = {values=Inttab.empty, continuations=Inttab.empty};
  fun put_value v ({values, continuations}: store) =
    let val id=serial () in (Value_Handle id,
      {values=Inttab.update_new (id,v) values, continuations=continuations}) end;
  fun put_continuation k ({values, continuations}: store) =
    let val id=serial () in (Continuation_Handle id,
      {values=values, continuations=Inttab.update_new (id,k) continuations}) end;
  fun remove_value (Value_Handle id) ({values,continuations}: store) =
    {values=Inttab.delete_safe id values, continuations=continuations};
  fun remove_continuation (Continuation_Handle id) ({values,continuations}: store) =
    {values=values, continuations=Inttab.delete_safe id continuations};
  fun check pin = if Veri7vn_Executable_Identity.same (pin, executable) then ()
    else error "Executable generation mismatch";
  fun value pin (Value_Handle id) ({values,...}: store) =
    (check pin; case Inttab.lookup values id of SOME v => v
      | NONE => error "Unknown runtime value handle");
  fun continuation pin (Continuation_Handle id) ({continuations,...}: store) =
    (check pin; case Inttab.lookup continuations id of SOME k => k
      | NONE => error "Unknown runtime continuation handle");
end;
