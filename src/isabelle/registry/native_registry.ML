(* Object ownership only. Looking up an object is not admission or current authority. *)
signature VERI7VN_NATIVE_REGISTRY =
sig
  type generation
  type object_handle
  type registry
  datatype native_object = Certified of cterm | Theorem of thm | Context of Proof.context
  type dependencies = {packages: string list, runtime: string, policy: string,
    sources: string list, interpretation: string}
  val empty: registry
  val generation: Proof.context -> dependencies -> generation
  val same_generation: generation * generation -> bool
  val same_handle: object_handle * object_handle -> bool
  (* Non-authenticating locator; no reverse/decoding constructor. *)
  val generation_locator: generation -> int
  val context: generation -> Proof.context
  val dependencies: generation -> dependencies
  val insert: generation -> string -> native_object -> registry -> object_handle * registry
  val lookup: generation -> object_handle -> registry -> native_object
  val named: generation -> string -> registry -> object_handle option
  val remove_object: generation -> object_handle -> registry -> registry
  val drop_generation: generation -> registry -> registry
end;

structure Veri7vn_Native_Registry :> VERI7VN_NATIVE_REGISTRY =
struct
  type dependencies = {packages: string list, runtime: string, policy: string,
    sources: string list, interpretation: string};
  datatype generation = Generation of {id: serial, context: Proof.context, dependencies: dependencies};
  datatype object_handle = Handle of {generation: serial, object: serial};
  datatype native_object = Certified of cterm | Theorem of thm | Context of Proof.context;
  type registry = {objects: (serial * native_object) Inttab.table,
    names: object_handle Symtab.table};
  val empty = {objects = Inttab.empty, names = Symtab.empty};
  fun generation context dependencies =
    Generation {id = serial (), context = context, dependencies = dependencies};
  fun identity (Generation {id, ...}) = id;
  val generation_locator = identity;
  fun context (Generation {context, ...}) = context;
  fun dependencies (Generation {dependencies, ...}) = dependencies;
  fun same_generation (g, h) = identity g = identity h;
  fun same_handle (Handle {generation=g, object=a}, Handle {generation=h, object=b}) = g=h andalso a=b;
  fun key g name = string_of_int (identity g) ^ ":" ^ name;
  fun valid g (Certified ct) = can (Thm.transfer_cterm (Proof_Context.theory_of (context g))) ct
    | valid g (Theorem th) = Context.subthy_id (Thm.theory_id th, Context.theory_id (Proof_Context.theory_of (context g)))
    | valid g (Context ctxt) = Context.eq_thy (Proof_Context.theory_of ctxt, Proof_Context.theory_of (context g));
  fun insert g name obj ({objects, names}: registry) =
    let
      val _ = if name = "" then error "Empty native object name" else ();
      val k = key g name;
      val _ = if Symtab.defined names k then error ("Native object cannot be rebound: " ^ name) else ();
      val _ = if valid g obj then () else error "Native object outside generation theory lineage";
      val id = serial ();
      val h = Handle {generation = identity g, object = id};
    in (h, {objects = Inttab.update_new (id, (identity g, obj)) objects,
      names = Symtab.update_new (k, h) names}) end;
  fun lookup g (Handle {generation, object}) ({objects, ...}: registry) =
    if identity g <> generation then error "Native object generation mismatch"
    else (case Inttab.lookup objects object of
      SOME (owner, obj) => if owner = generation then obj else error "Native object owner mismatch"
    | NONE => error "Unknown native object object_handle");
  fun named g name ({names, ...}: registry) = Symtab.lookup names (key g name);
  fun filter_names predicate table = Symtab.fold (fn entry =>
    if predicate entry then Symtab.update entry else I) table Symtab.empty;
  fun filter_objects predicate table = Inttab.fold (fn entry =>
    if predicate entry then Inttab.update entry else I) table Inttab.empty;
  fun remove_object g (h as Handle {generation, object}) ({objects,names}: registry) =
    if identity g <> generation then error "Native object generation mismatch"
    else {objects=Inttab.delete_safe object objects,
      names=filter_names (fn (_,other) => not (same_handle (h,other))) names};
  fun drop_generation g ({objects,names}: registry) =
    {objects=filter_objects (fn (_,(owner,_)) => owner <> identity g) objects,
      names=filter_names (fn (_,Handle {generation,...}) => generation <> identity g) names};
end;
