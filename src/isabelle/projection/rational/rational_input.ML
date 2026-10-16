(* Fixed kernel-certified literal normalization; no evaluation or authority. *)
structure Veri7vn_Rational_Input =
struct
  type limits={nodes:int,depth:int,seconds:int};
  fun within ({nodes,depth,...}:limits) t=
    let fun walk [] _=true
      | walk ((t,d)::pending) count=
        if count>=nodes orelse d>depth then false else
        (case t of f$x=>walk((f,d+1)::(x,d+1)::pending)(count+1)
        | Abs _=>false | Free _=>false | Var _=>false
        | _=>walk pending(count+1))
    in walk[(t,0)]0 end;
  (* The abstract Frct constructor is not an executable input constant. Only
     explicit pairs without nested abstract rationals are accepted here, so
     Frct_def cannot duplicate a recursively computed representation tree. *)
  fun contains_frct t=Term.exists_subterm
    (fn Const(name,_)=>name= @{const_name Rat.Frct} | _=>false) t;
  fun safe_frct_inputs t=
    (case t of Const(name,_) $ argument=>
      if name= @{const_name Rat.Frct} then
        (case strip_comb argument of (Const(pair,_),[n,d])=>
          pair= @{const_name Pair} andalso not(contains_frct n) andalso not(contains_frct d)
        | _=>false)
      else safe_frct_inputs argument
    | f$x=>safe_frct_inputs f andalso safe_frct_inputs x
    | Const(name,_)=>name<> @{const_name Rat.Frct}
    | Abs _=>false | Free _=>false | Var _=>false | _=>true);
  fun conversion_context ctxt=fold Simplifier.add_simp
    [@{thm Frct_def},@{thm fst_conv},@{thm snd_conv},@{thm rational_integer_one_input},
      @{thm rat_number_expand(1)},@{thm rat_number_expand(2)},@{thm rat_number_expand(3)},
      @{thm rational_nat_one_input},@{thm rational_int_zero_input},@{thm rational_int_one_input},@{thm rational_int_numeral_input}]
    (put_simpset HOL_basic_ss ctxt);
  exception Input_Conversion_Bound;
  fun normalize ctxt (limits:limits) original=
    let
      val _=if #nodes limits>0 andalso #depth limits>0 andalso #seconds limits>0
        andalso within limits(Thm.term_of original) then () else raise Input_Conversion_Bound;
      val _=if safe_frct_inputs(Thm.term_of original) then ()
        else error "Unsupported computed abstract rational representation";
      val equality=Timeout.apply(Time.fromReal(Real.fromInt(#seconds limits)))
        (Simplifier.rewrite (conversion_context ctxt)) original;
      val converted=Thm.rhs_of equality;
      val _=if null(Thm.hyps_of equality) andalso Thm.nprems_of equality=0 andalso
        Thm.term_of(Thm.lhs_of equality) aconv Thm.term_of original then ()
        else error "Rational conversion changed its certified input";
      val _=if within limits(Thm.term_of converted) then () else raise Input_Conversion_Bound;
    in (converted,equality) end;
end;
