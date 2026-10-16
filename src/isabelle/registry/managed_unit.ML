(* Storage ownership, not provenance/admission/access authority. A trusted producer
   witness is owned by admission; only that witness can authorize dependency edges. *)
signature VERI7VN_MANAGED_NATIVE_UNIT =
sig
  type token
  type view = {generation: Veri7vn_Native_Registry.generation,
    inputs: Veri7vn_Native_Literals.input list,
    objects: Veri7vn_Native_Registry.object_handle list}
  val create: view -> Veri7vn_Native_Registry.registry -> token
  val inspect: token -> view option
  val locator: token -> int
  val release: token -> view option
end;
structure Veri7vn_Managed_Native_Unit :> VERI7VN_MANAGED_NATIVE_UNIT =
struct
  structure R = Veri7vn_Native_Registry;
  type view = {generation: R.generation, inputs: Veri7vn_Native_Literals.input list,
    objects: R.object_handle list};
  type owned = {view:view,leases:Veri7vn_Native_Literals.lease list};
  datatype token = Token of {id: serial, payload: owned option Synchronized.var};
  structure L = Veri7vn_Native_Literals;
  fun acquire [] held = rev held
    | acquire (input::rest) held =
        (case Exn.capture L.retain input of
          Exn.Res lease => acquire rest (lease::held)
        | Exn.Exn exn => (List.app (fn lease => ignore (L.release lease)) held;Exn.reraise exn));
  fun create ({generation,inputs,objects}: view) registry =
    let
      val _=List.app (fn h=>ignore (R.lookup generation h registry)) objects;
      val inputs=distinct L.same_input inputs;
      val view={generation=generation,inputs=inputs,objects=objects};
    in Thread_Attributes.uninterruptible_body (fn _ =>
      let val leases=acquire inputs []
        val created=Exn.capture (fn () => Token {id=serial (),
          payload=Synchronized.var "veri7vn_managed_native_unit" (SOME {view=view,leases=leases})}) ()
      in case created of Exn.Res token => token
        | Exn.Exn exn => (List.app (fn lease=>ignore (L.release lease)) leases;Exn.reraise exn)
      end) end;
  fun inspect (Token {payload,...}) = Option.map #view (Synchronized.value payload);
  fun locator (Token {id,...}) = id;
  (* Do not erase inputs here: another live unit may own the same source input.
     The lifecycle owner performs scoped refcount/Forget after releasing units. *)
  fun release (Token {payload,...}) = Thread_Attributes.uninterruptible_body (fn _ =>
    (case Synchronized.change_result payload (fn old => (old,NONE)) of
      NONE => NONE
    | SOME {view,leases} =>
        (List.app (fn lease=>ignore (L.release lease)) leases;SOME view)));
end;
