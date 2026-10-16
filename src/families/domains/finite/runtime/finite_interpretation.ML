(* A bounded, literal-preserving proposal reader. No admission or execution,
   no new authority, and no caller-supplied Isabelle syntax. *)
signature VERI7VN_FINITE_INTERPRETATION =
sig
  datatype proposal = Proposed of {input:cterm,source:Veri7vn_Native_Literals.slice,
    convention:string} | Unrecognized | Malformed of string
  val interpret: Proof.context -> Veri7vn_Native_Literals.slice -> proposal
end;
structure Veri7vn_Finite_Interpretation :> VERI7VN_FINITE_INTERPRETATION =
struct
  datatype proposal = Proposed of {input:cterm,source:Veri7vn_Native_Literals.slice,
    convention:string} | Unrecognized | Malformed of string;
  fun digits s = size s>0 andalso forall Char.isDigit (String.explode s);
  fun decimal raw =
    let val negative=String.isPrefix "-" raw;
      val magnitude=if negative then String.extract(raw,1,NONE) else raw;
      val parts=String.fields(fn c=>c= #".")magnitude;
      val (whole,fraction)=case parts of [a] => (a,"") | [a,b] => (a,b)
        | _=>error "Expected a decimal literal";
      val _=if digits whole andalso (fraction="" orelse digits fraction) andalso
        size raw<=256 then () else error "Expected a bounded decimal literal";
      val numerator=the(IntInf.fromString(whole^fraction));
      val denominator=IntInf.pow(10,size fraction);
      val signed=if negative then ~numerator else numerator;
    in HOLogic.mk_binop @{const_name divide}
      (HOLogic.mk_number @{typ rat} signed,HOLogic.mk_number @{typ rat} denominator) end;
  fun operation tokens = (case tokens of
      "mean"::rest=>SOME(@{term Mean},rest,"exact arithmetic mean")
    | "average"::rest=>SOME(@{term Mean},rest,"exact arithmetic mean")
    | "median"::rest=>SOME(@{term Median},rest,"middle sorted observation; average central pair")
    | "mode"::rest=>SOME(@{term Modes},rest,"all maximizing values, including ties")
    | "modes"::rest=>SOME(@{term Modes},rest,"all maximizing values, including ties")
    | "range"::rest=>SOME(@{term Range},rest,"maximum minus minimum")
    | "population"::"variance"::rest=>SOME(@{term "Variance PopulationVariance"},rest,"population; denominator n")
    | "sample"::"variance"::rest=>SOME(@{term "Variance SampleVariance"},rest,"sample; denominator n-1")
    | "variance"::rest=>SOME(@{term "Variance SampleVariance"},rest,"sample default; denominator n-1")
    | _=>NONE);
  fun interpret ctxt source =
    let val original=Veri7vn_Native_Literals.original source;
      val _=if size original<=65536 then () else error "Finite request exceeds byte limit";
      val tokens=String.tokens(fn c=>Char.isSpace c orelse c= #"," orelse c= #":") original;
      val _=if length tokens<=4096 then () else error "Finite request exceeds token limit";
    in case operation tokens of NONE=>Unrecognized
      | SOME(op_term,rest,convention)=>
        let val literals=case rest of "of"::xs=>xs | xs=>xs;
          val _=if null literals then error "A data collection is required" else ();
          val values=map decimal literals;
          val collection=@{const RationalCollection} $ HOLogic.mk_list @{typ rat} values;
          val call=@{const FiniteCall} $ op_term $
            HOLogic.mk_list @{typ finite_value} [collection] $ HOLogic.mk_list HOLogic.natT [];
          val input=Thm.cterm_of ctxt (@{const registered_finite_dispatch} $ call);
        in Proposed{input=input,source=source,convention=convention}end
    end handle ERROR reason=>Malformed reason | Option=>Malformed "Invalid decimal literal";
end;
