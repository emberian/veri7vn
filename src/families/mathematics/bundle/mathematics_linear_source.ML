signature VERI7VN_MATHEMATICS_LINEAR_SOURCE =
sig
  type checked
  val check: Veri7vn_Mathematics_Linear.request -> Veri7vn_Mathematics_Linear.output -> checked
  val source: checked -> cterm
  val parser_equation: checked -> thm
  val worker_equation: checked -> thm
  val complete_set: checked -> thm
  val statement: checked -> string
end;
structure Veri7vn_Mathematics_Linear_Source :> VERI7VN_MATHEMATICS_LINEAR_SOURCE =
struct
  structure X = Veri7vn_Mathematics_Linear;
  datatype checked = Checked of {request:X.request, output:X.output, source:cterm,
    parser:thm, worker:thm, complete:thm, statement:string};
  fun get (Checked data) =
    if X.belongs_to (#request data) (#output data) andalso is_some (X.project (#output data))
    then data else error "Linear source/output association was released";
  fun source value = #source (get value);
  fun parser_equation value = #parser (get value);
  fun worker_equation value = #worker (get value);
  fun complete_set value = #complete (get value);
  fun statement value = #statement (get value);
  fun require (SOME value) = value | require NONE = error "Missing live linear source or result";
  fun prove ctxt equality = Timeout.apply (Time.fromSeconds 2)
    (fn () => Goal.prove ctxt [] [] (HOLogic.mk_Trueprop equality)
      (fn {context,...} => HEADGOAL (Code_Simp.dynamic_tac context))) ();
  fun check request output =
    let
      val _ = if X.belongs_to request output then () else error "Unrelated linear output";
      val raw = require (X.source request);
      val input = require (X.registered_input request);
      val result = require (X.project output);
      val ctxt = Proof_Context.init_global (Thm.theory_of_cterm raw);
      val (head,args) = strip_comb (Thm.term_of input);
      val (a,b) = (case (head,args) of (Const (name,_),[a,b]) =>
        if name = @{const_name linear_pair_run} then (a,b) else raise Match | _ => raise Match);
      val pairs = HOLogic.mk_prod (a,b);
      val parser_result = Const (@{const_name Some},fastype_of pairs --> Type (@{type_name option},[fastype_of pairs])) $ pairs;
      val parser = prove ctxt (HOLogic.mk_eq
        (@{term linear_ascii_pairs} $ Thm.term_of raw, parser_result));
      val worker_result = @{term "Some::linear_solution\<Rightarrow>linear_solution option"} $ Thm.term_of result;
      val worker = prove ctxt (HOLogic.mk_eq (Thm.term_of input,worker_result));
      val complete = @{thm linear_pair_complete} OF [worker];
      val _ = if null (Thm.hyps_of parser) andalso null (Thm.hyps_of worker)
        andalso null (Thm.hyps_of complete) andalso Thm.nprems_of complete=0
        then () else error "Conditional linear source evidence";
      val text = (case require (X.view output) of X.No_Solutions =>
          "No rational solutions."
        | X.All_Rationals => "Every rational number is a solution."
        | X.One_Rational (n,d) => "The unique rational solution is " ^
            IntInf.toString n ^ "/" ^ IntInf.toString d ^ ".");
      val checked = Checked {request=request,output=output,source=raw,
        parser=parser,worker=worker,complete=complete,statement=text};
      val _ = get checked;
    in checked end;
end;
