(* Privileged native gate. ML policy construction belongs to the trusted image;
   workers receive no ML evaluation channel. Registry insertion is not admission. *)
signature VERI7VN_NATIVE_ADMISSION =
sig
  datatype route = Kernel | Oracle of string list
  type policy
  type accepted
  datatype scope = Exact_Native_Proposition
  type claim
  val exact_claim: cterm -> claim
  val propose_scope: claim -> {modality: string, domain: string, coverage: string} -> bool
  type request = {claim: claim, hypotheses: term list, premises: term list,
    sorts: sort list}
  datatype result = Accepted of accepted | Rejected of string list
  val policy_theory: policy -> theory
  val policy: theory -> policy
  val policy_with_oracles: theory -> string list -> policy
  val define: policy -> binding -> cterm -> policy * term * thm * theory
  val define_command: policy -> binding -> string option -> string ->
    policy * term * thm * theory
  val advance: policy -> theory -> policy
  val join: policy list -> theory -> policy
  val admit: policy -> Veri7vn_Native_Registry.generation ->
    Veri7vn_Native_Registry.registry -> Veri7vn_Native_Registry.object_handle ->
    route -> request -> result
  val theorem: accepted -> thm
  val target: accepted -> cterm
  val scope: accepted -> scope
  val generation: accepted -> Veri7vn_Native_Registry.generation
  val route: accepted -> route
  val observed_oracles: accepted -> string list
  val acceptance_policy: accepted -> policy
  val clear_cached_generation: policy -> Veri7vn_Native_Registry.generation -> unit
end;
structure Veri7vn_Native_Admission :> VERI7VN_NATIVE_ADMISSION =
struct
  structure R = Veri7vn_Native_Registry;
  datatype route = Kernel | Oracle of string list;
  datatype scope = Exact_Native_Proposition;
  datatype claim = Claim of cterm;
  fun exact_claim target = Claim target;
  (* English labels are proposals. Only this exact native projection is licensed. *)
  fun propose_scope (Claim _) {modality,domain,coverage} =
    modality = "native proposition" andalso domain = "certified target" andalso
    coverage = "exact proposition";
  type request = {claim: claim, hypotheses: term list, premises: term list,
    sorts: sort list};
  (* Exact native theorem identity, never proposition-only caching. *)
  datatype policy = Policy of {theory: theory, allowed_oracles: string list,
    audit: (R.generation * R.object_handle * string list) list Synchronized.var,
    lineage: theory list Synchronized.var};
  datatype accepted = Consequence of {theorem: thm, target: cterm, scope: scope,
    generation: R.generation, object_handle: R.object_handle, route: route,
    policy: policy, observed_oracles: string list};
  datatype result = Accepted of accepted | Rejected of string list;
  fun policy_with_oracles theory allowed_oracles = Policy {theory=theory, allowed_oracles=allowed_oracles,
    audit=Synchronized.var "veri7vn_admission_audit" [],
    lineage=Synchronized.var "veri7vn_admission_lineage" [theory]};
  fun policy theory = policy_with_oracles theory [];
  fun policy_theory (Policy {theory,...}) = theory;
  fun define (Policy {theory=base,allowed_oracles,...}) binding raw_rhs =
    let
      val rhs = Thm.transfer_cterm base raw_rhs;
      val t = Thm.term_of rhs;
      val _ = if null (Term.add_frees t []) andalso null (Term.add_vars t []) then ()
        else error "Definition RHS must bind its term parameters";
      val lthy = Named_Target.theory_init base;
      val ((constant,(_,definition)),lthy') = Local_Theory.define
        ((binding,NoSyn),((Binding.suffix_name "_def" binding,[]),t)) lthy;
      val ((constant',definition0),thy') = Local_Theory.exit_result_global
        (fn phi => fn (c,d) => (Morphism.term phi c,Morphism.thm phi d))
        ((constant,definition),lthy');
      val definition' = Thm.transfer thy' definition0;
      val _ = if null (Thm.hyps_of definition') andalso Thm.nprems_of definition' = 0
        andalso null (Thm_Deps.all_oracles [definition']) then ()
        else error "Controlled definition did not export a closed kernel theorem";
    in (policy_with_oracles thy' allowed_oracles,constant',definition',thy') end;
  fun define_command (Policy {theory=base,allowed_oracles,...}) binding raw_type raw_proposition =
    let
      val _=if size raw_proposition<=100000 andalso
        (case raw_type of NONE=>true | SOME text=>size text<=100000) then ()
        else error "Native definition command byte bound"
      val lthy=Named_Target.theory_init base
      val ((constant,(_,definition)),lthy')=Specification.definition_cmd {verbose=false}
        (SOME (binding,raw_type,NoSyn)) [] [] ((Binding.empty,[]),raw_proposition) lthy
      val ((constant',definition0),thy')=Local_Theory.exit_result_global
        (fn phi=>fn(c,d)=>(Morphism.term phi c,Morphism.thm phi d))
        ((constant,definition),lthy')
      val definition'=Thm.transfer thy' definition0
      val _=if null(Thm.hyps_of definition') andalso Thm.nprems_of definition'=0 andalso
        null(Thm.tpairs_of definition') andalso null(Thm_Deps.all_oracles[definition']) then ()
        else error "Native definition command did not export a closed kernel theorem"
    in (policy_with_oracles thy' allowed_oracles,constant',definition',thy') end;
  fun permitted (Policy {theory=base,lineage,...}) thy =
    Synchronized.change_result lineage (fn checked =>
      if exists (fn old => Context.eq_thy (old,thy)) checked then (true,checked)
      else let
        val expected = Theory.all_axioms_of base;
        val actual = Theory.all_axioms_of thy;
        val ok = Context.subthy (base,thy) andalso length actual = length expected andalso
          forall (fn (name,prop) => case AList.lookup (op =) expected name of
            SOME p => prop aconv p | NONE => false) actual;
      in (ok, if ok then take 64 (thy::checked) else checked) end);
  fun advance (p as Policy {allowed_oracles,...}) thy =
    if permitted p thy then policy_with_oracles thy allowed_oracles
    else error "Cannot advance policy over an unapproved theory extension";
  fun join [] _ = error "Cannot join an empty native policy set"
    | join policies thy =
      let
        val _ = List.app (fn Policy {theory,...} =>
          if Context.subthy (theory,thy) then ()
          else error "Native policy is not an ancestor of the imported theory") policies;
        fun add_axiom (name,prop) table =
          (case Symtab.lookup table name of NONE => Symtab.update (name,prop) table
          | SOME old => if old aconv prop then table
            else error ("Conflicting approved native axiom: " ^ name));
        val expected = fold (fn Policy {theory,...} =>
          fold add_axiom (Theory.all_axioms_of theory)) policies Symtab.empty;
        val actual = Theory.all_axioms_of thy;
        val _ = if Symtab.size expected = length actual andalso forall
          (fn (name,prop) => case Symtab.lookup expected name of
            SOME old => old aconv prop | NONE => false) actual then ()
          else error "Native policy composition contains an unapproved axiom";
        val Policy {allowed_oracles=first,...} = hd policies;
        val allowed = filter (fn name => forall
          (fn Policy {allowed_oracles,...} => member (op =) allowed_oracles name) policies) first;
      in policy_with_oracles thy allowed end;
  fun clear_cached_generation (Policy {audit,lineage,...}) gen =
    let val thy = Proof_Context.theory_of (R.context gen)
    in
      Synchronized.change audit (filter_out (fn (g,_,_) =>
        Context.subthy (thy,Proof_Context.theory_of (R.context g))));
      Synchronized.change lineage (filter_out (fn old => Context.subthy (thy,old)))
    end;
  fun terms_equal xs ys = length xs = length ys andalso ListPair.allEq (op aconv) (xs,ys);
  fun oracle_names th = Thm_Deps.all_oracles [th] |> map (#1 o #1) |> distinct (op =);
  fun audited (Policy {audit,...}) gen candidate_handle th =
    Synchronized.change_result audit (fn entries =>
      (case find_first (fn (g,h,_) => R.same_generation (g,gen) andalso
        R.same_handle (h,candidate_handle)) entries of
        SOME (_,_,names) => (names,entries)
      | NONE => let
          val _ = Thm.consolidate [th];
          val names = oracle_names th;
        in (names,take 256 ((gen,candidate_handle,names)::entries)) end));
  fun admit (p as Policy {allowed_oracles,...}) gen registry candidate_handle route
      ({claim=Claim raw_target,hypotheses,premises,sorts}: request) =
    let
      val thy = Proof_Context.theory_of (R.context gen);
      val th = (case R.lookup gen candidate_handle registry of R.Theorem th => Thm.transfer thy th
        | _ => error "Candidate handle is not a theorem");
      val target = Thm.transfer_cterm thy raw_target;
      (* Native ancestry and the complete axiom table cover hidden dependencies,
         including proof bodies not recorded at full proof-term level. *)
      val checks = [
        (permitted p thy, "Generation contains an unapproved theory extension"),
        (Context.subthy (Thm.theory_of_thm th,thy), "Forbidden theorem ancestry"),
        (Context.subthy (Thm.theory_of_cterm target,thy), "Forbidden target ancestry"),
        (Thm.prop_of th aconv Thm.term_of target, "Exact target mismatch"),
        (terms_equal (Thm.hyps_of th) hypotheses, "Undeclared or missing hypotheses"),
        (terms_equal (Thm.prems_of th) premises, "Undeclared or missing premises"),
        (Thm.shyps_of th = sorts, "Type/sort conditions mismatch"),
        (null (Thm.tpairs_of th), "Unresolved flex-flex constraints"),
        (fastype_of (Thm.term_of target) = propT, "Target is not a proposition")];
      val errors = map_filter (fn (ok,msg) => if ok then NONE else SOME msg) checks;
    in if not (null errors) then Rejected errors else
      let
        val names = Timeout.apply (Time.fromSeconds 5) (audited p gen candidate_handle) th;
        val allowed = (case route of Kernel => [] | Oracle ns =>
          filter (member (op =) allowed_oracles) ns);
        val forbidden = filter_out (member (op =) allowed) names;
        val skipped = exists (fn n => Long_Name.base_name n = "skip_proof") names;
      in if skipped then Rejected ["Proof skipping is forbidden"]
        else if not (null forbidden) then Rejected (map (fn n => "Forbidden oracle: " ^ n) forbidden)
        else Accepted (Consequence {theorem=th,target=target,scope=Exact_Native_Proposition,
          generation=gen,object_handle=candidate_handle,route=route,
          policy=p,observed_oracles=names}) end
    end handle ERROR msg => Rejected [msg]
      | THM (msg,_,_) => Rejected [msg]
      | Thm.CONTEXT (msg,_,_,_,_) => Rejected [msg]
      | Timeout.TIMEOUT _ => Rejected ["Native dependency audit deadline exceeded"];
  fun theorem (Consequence {theorem,...}) = theorem;
  fun target (Consequence {target,...}) = target;
  fun scope (Consequence {scope,...}) = scope;
  fun generation (Consequence {generation,...}) = generation;
  fun route (Consequence {route,...}) = route;
  fun observed_oracles (Consequence {observed_oracles,...}) = observed_oracles;
  fun acceptance_policy (Consequence {policy,...}) = policy;
end;
