theory Source_Quantity_Kernel_Tests
  imports Veri7vn_Source_Quantity_Consumer.Source_Quantity_Consumer
begin

text \<open>This check exercises the actual domain bundle's of_int input
normalization, which a generated pure interpreter fixture cannot qualify. The
source cell producer is not replaced with a fixture instance; a complete charged
source-to-domain wrapper test still requires that actual producer.\<close>
ML \<open>
local
 structure M=Veri7vn_Domain_Execution;
 structure A=Veri7vn_Native_Admission;
 structure R=Veri7vn_Native_Registry;
 structure E=Veri7vn_Executable_Identity;
 val pin=M.executable();
 val generation=R.generation @{context}{packages=["source-quantity"],runtime="native bundle component",
   policy="exact of_int normalization",sources=[],interpretation="closed source integer carrier"};
 val instance=(case M.attach{policy=A.policy @{theory},generation=generation,
   code_context=E.code_theory pin,limits={nodes=5000,depth=100,seconds=5}}of
     M.Ready value=>value | _=>error "Source quantity bundle instance failed");
 fun evaluate term=Timeout.apply(Time.fromSeconds 5)(fn()=>
   Veri7vn_Bounded_Projection.materialize 20000
     (fn()=>Code_Evaluation.dynamic_value_strict @{context} term))();
 fun check input expected=
   let val request=(case M.prepare pin instance input of M.Ready value=>value
         | _=>error "Source of_int domain input was not prepared");
     val outcome=Exn.capture(fn()=>
       let val output=(case M.execute pin instance request of M.Ready value=>value
             | _=>error "Source of_int domain input was not executed");
         val checked=Exn.capture(fn()=>
           let val projected=(case M.project pin output of M.Ready value=>value
                 | _=>error "Source of_int domain output unavailable");
             val test= @{term "(=) :: domain_reply => domain_reply => bool"}
               $ Thm.term_of projected $ expected;
             val expanded=Thm.rhs_of(Simplifier.rewrite
               (fold Simplifier.add_simp
                 [@{thm Frct_def},@{thm fst_conv},@{thm snd_conv}]
                 (put_simpset HOL_basic_ss @{context}))
               (Thm.cterm_of @{context} test));
           in if evaluate (Thm.term_of expanded) aconv @{term True}
             then () else error "Source of_int domain output changed exact value/model" end)();
         val _=M.release_output output;
       in Exn.release checked end)();
     val _=M.release_request request;
   in Exn.release outcome end;
 val _=check @{cterm "registered_domain_dispatch
   (DomainCall (ConvertLinear Centimetre Metre)
     [LinearValue Centimetre (of_int (100::int))] [] None)"}
   @{term "DomainAnswer (LinearValue Metre 1) []"};
 val _=check @{cterm "registered_domain_dispatch
   (DomainCall (Spring SpringForce)
     [LinearValue NewtonPerMetre (of_int (3::int)),LinearValue Metre (of_int (2::int))]
     [17,18] (Some 91))"}
   @{term "DomainAnswer (LinearValue Newton 6) [91,17,18]"};
 val _=check @{cterm "registered_domain_dispatch
   (DomainCall (Spring SpringForce)
     [LinearValue NewtonPerMetre (of_int (3::int)),LinearValue Metre (of_int (2::int))]
     [17,18] None)"}
   @{term "DomainBlocked MissingIdealModel"};
 val _=M.release_instance instance;
in val _=writeln "INTEGRATION source_quantity_of_int_bundle PASS" end;
\<close>
end
