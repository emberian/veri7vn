(* Optional closed family. Pair numerators and positive denominators are exact;
   bounded input admission precedes generated arithmetic. *)
signature VERI7VN_MATHEMATICS_LINEAR =
sig
  type instance type request type output
  datatype view = No_Solutions | All_Rationals | One_Rational of IntInf.int * IntInf.int
  val attach: Veri7vn_Native_Admission.policy -> Veri7vn_Native_Registry.generation -> instance
  val executable: unit -> Veri7vn_Executable_Identity.pin
  val registered_input: request -> cterm option
  val modeled_cost: request -> IntInf.int option
  val belongs_to: request -> output -> bool
  val prepare: instance -> (IntInf.int * IntInf.int) * (IntInf.int * IntInf.int) -> request option
  val prepare_source: instance -> cterm -> request option
  val source: request -> cterm option
  val execute: instance -> request -> output option
  val check: output -> thm option
  val project: output -> cterm option
  val view: output -> view option
  val complete_contract: instance -> Veri7vn_Native_Admission.accepted
  val release_request: request -> unit
  val release_output: output -> unit
end;
structure Veri7vn_Mathematics_Linear :> VERI7VN_MATHEMATICS_LINEAR =
struct
  structure R = Veri7vn_Native_Registry;
  structure A = Veri7vn_Native_Admission;
  datatype view = No_Solutions | All_Rationals | One_Rational of IntInf.int * IntInf.int;
  val context = @{context};
  val pin = Veri7vn_Executable_Identity.pin @{theory}
    {artifact="veri7vn.mathematics-linear/1", compiler="Isabelle code generator / PolyML",
     target="SML", serializers=["positive-denominator exact integer pairs"],
     foreign_primitives=[], settings=["8192 input bits; complete rational solution sets"]};
  datatype instance = Instance of {id: serial, generation: R.generation, contract: A.accepted};
  type pair = IntInf.int * IntInf.int;
  datatype payload = Input of {instance: serial, origin: serial, a: pair, b: pair, native: cterm, source: cterm option}
    | Answer of {origin: serial, input: cterm, view: view, native: cterm};
  structure Store = Veri7vn_Typed_Runtime_Store
    (struct type value=payload type continuation=unit val executable=pin end);
  val store = Synchronized.var "mathematics_linear" Store.empty;
  datatype request = Request of Store.value_handle;
  datatype output = Output of Store.value_handle;
  fun complete_contract (Instance {contract,...}) = contract;
  fun attach policy generation =
    let
      val th = @{thm linear_execution_refinement};
      val (h, registry) = R.insert generation "mathematics.linear-complete" (R.Theorem th) R.empty;
      val target = Thm.cterm_of (R.context generation) (Thm.prop_of th);
    in case A.admit policy generation registry h A.Kernel
      {claim=A.exact_claim target,hypotheses=[],premises=[],sorts=Thm.shyps_of th} of
      A.Accepted contract => Instance {id=serial (),generation=generation,contract=contract}
    | A.Rejected reasons => error (space_implode "; " reasons)
    end;
  fun bounded n = n=0 orelse IntInf.log2 (IntInf.abs n) < 8192;
  fun valid (n,d) = d>0 andalso bounded n andalso bounded d;
  fun put value = Synchronized.change_result store (fn st => Store.put_value value st);
  val live = Synchronized.var "mathematics_linear_origins" Inttab.empty;
  fun get h = try (Store.value pin h) (Synchronized.value store);
  fun live_answer h = (case get h of SOME (value as Answer {origin,...}) =>
    if Inttab.defined (Synchronized.value live) origin then SOME value else NONE | _ => NONE);
  fun generated_int n = Veri7vn_Numerals.int_of_integer n;
  fun rational (n,d) = @{code Fract} (generated_int n) (generated_int d);
  fun int_term n = HOLogic.mk_number @{typ int} n;
  fun rat_term (n,d) = @{term "Fract::int\<Rightarrow>int\<Rightarrow>rat"} $ int_term n $ int_term d;
  fun executable () = pin;
  fun pair_term (n,d) = HOLogic.mk_prod (int_term n,int_term d);
  fun prepare (Instance {id,...}) (a,b) =
    if valid a andalso valid b then
      let val native = Thm.cterm_of context (@{term linear_pair_run} $ pair_term a $ pair_term b)
      in let val origin=serial ();
             val handle_id=put (Input {instance=id,origin=origin,a=a,b=b,native=native,source=NONE});
             val _=Synchronized.change live (Inttab.update (origin,[]))
         in SOME (Request handle_id) end end
    else NONE;
  fun source (Request h) = (case get h of SOME (Input {source,...}) => source | _ => NONE);
  fun prepare_source (selected as Instance {generation,...}) raw =
    let
      val _ = if fastype_of (Thm.term_of raw) = @{typ "nat list"} andalso
        Context.subthy (Thm.theory_of_cterm raw, Proof_Context.theory_of (R.context generation))
        then () else raise Match;
      val bytes = HOLogic.dest_list (Thm.term_of raw);
      val _ = if length bytes <= 1024 then () else raise Match;
      val ns = map (fn t => let val n = snd (HOLogic.dest_number t)
        in if 0<=n andalso n<128 then n else raise Match end) bytes;
      val generated = map Veri7vn_Numerals.nat_of_integer ns;
    in case @{code linear_ascii_pairs} generated of NONE => NONE
      | SOME ((n,d),(m,e)) =>
        (case prepare selected ((Veri7vn_Numerals.integer_of_int n,Veri7vn_Numerals.integer_of_int d),
              (Veri7vn_Numerals.integer_of_int m,Veri7vn_Numerals.integer_of_int e)) of
          NONE => NONE | SOME (request as Request h) =>
          (case get h of SOME (Input {instance,origin,a,b,native,...}) =>
            (Synchronized.change store (fn st =>
              (* Retain original cterm, including its receiver context. *)
              let val st' = Store.remove_value h st in st' end);
             Synchronized.change live (Inttab.delete_safe origin);
             let val origin' = serial ();
                 val h' = put (Input {instance=instance,origin=origin',a=a,b=b,native=native,source=SOME raw});
                 val _ = Synchronized.change live (Inttab.update (origin',[]))
             in SOME (Request h') end)
          | _ => NONE))
    end handle TERM _ => NONE | TYPE _ => NONE | Match => NONE;
  fun registered_input (Request h) =
    (case get h of SOME (Input {native,...}) => SOME native | _ => NONE);
  fun modeled_cost (Request h) =
    (case get h of SOME (Input {a=(n,d),b=(m,e),...}) =>
      let fun width x = if x=0 then 1 else IntInf.log2 (IntInf.abs x)+1
          val bits = fold (fn x => fn total => width x + total) [n,d,m,e] 0
      in SOME (IntInf.fromInt (bits*bits+bits)) end | _ => NONE);
  fun belongs_to (Request r) (Output ohandle) =
    (case (get r,get ohandle) of
      (SOME (Input {origin=a,...}),SOME (Answer {origin=b,...})) => a=b | _ => false);
  fun decode answer =
    (case answer of @{code NoSolutions} => (No_Solutions,@{term NoSolutions})
    | @{code AllRationals} => (All_Rationals,@{term AllRationals})
    | @{code OneRational} q => let
        val (n,d) = @{code quotient_of} q;
        val pair = (Veri7vn_Numerals.integer_of_int n,Veri7vn_Numerals.integer_of_int d);
      in (One_Rational pair,@{term OneRational} $ rat_term pair) end);
  fun execute (Instance {id,...}) (Request h) =
    (case get h of SOME (Input {instance,origin,a,b,native=input,...}) =>
      if id<>instance then NONE else
      let val (view,native) = Timeout.apply (Time.fromSeconds 2)
            (fn () => decode (@{code solve_linear} (rational a) (rational b))) ();
      in Synchronized.change_result live (fn table =>
        if not (Inttab.defined table origin) then (NONE,table) else
        let val output_handle = put (Answer {origin=origin,input=input,view=view,
              native=Thm.cterm_of context native})
        in (SOME (Output output_handle),Inttab.map_entry origin (cons output_handle) table) end)
      end
    | _ => NONE)
    handle Timeout.TIMEOUT _ => NONE;
  (* Optional kernel evidence route checks the exact generated answer against
     the retained request; callers can never substitute a candidate solution. *)
  fun check (Output h) =
    (case live_answer h of SOME (Answer {input,native,...}) =>
      let
        val equation = Timeout.apply (Time.fromSeconds 2)
          (Code_Simp.dynamic_conv context) input;
        val expected = @{term "Some::linear_solution\<Rightarrow>linear_solution option"}
          $ Thm.term_of native;
      in if Thm.term_of (Thm.rhs_of equation) aconv expected then SOME equation else NONE end
    | _ => NONE)
    handle Timeout.TIMEOUT _ => NONE;
  fun project (Output h) = (case live_answer h of SOME (Answer {native,...}) => SOME native | _ => NONE);
  fun view (Output h) = (case live_answer h of SOME (Answer {view,...}) => SOME view | _ => NONE);
  fun release_request (Request h) =
    (case get h of SOME (Input {origin,...}) =>
      (let val children = Synchronized.change_result live (fn table =>
           (the_default [] (Inttab.lookup table origin),Inttab.delete_safe origin table))
       in Synchronized.change store (fn st => fold Store.remove_value (h::children) st) end) | _ => ());
  fun release_output (Output h) = Synchronized.change store (Store.remove_value h);
end;
