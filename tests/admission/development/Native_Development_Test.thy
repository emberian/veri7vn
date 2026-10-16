theory Native_Development_Test
  imports "Veri7vn_Admission.Veri7vn_Admission" Expert_Source
begin
ML \<open>
val parent = @{theory Veri7vn_Admission};
val import = Context.theory_name {long=true} parent;
val base_policy=Veri7vn_Native_Admission.policy parent;
fun replay inputs=Veri7vn_Native_Development.replay_parents [(import,base_policy)] inputs;
val original = File.read (Path.append (Resources.master_directory @{theory})
  (Path.explode "Expert_Source.thy"));
val built = replay
  {expected_source=original,source=original,imports=[import]};
val _ = if Veri7vn_Native_Development.source built = original then () else error "source lost";
val _ = Veri7vn_Native_Development.theorem built "Expert_Source.bump_correct";
val ordinary = @{theory Expert_Source};
val replayed=Veri7vn_Native_Development.theory built;
val ordinary_general=Global_Theory.get_thm ordinary "Expert_Source.bump_general";
val replayed_general=Veri7vn_Native_Development.theorem built "Expert_Source.bump_general";
val _=if Thm.prop_of ordinary_general aconv Thm.prop_of replayed_general then ()
  else error "Source lemma changed global parameter generalization";
val ordinary_definition=Global_Theory.get_thm ordinary "Expert_Source.bump_def";
val replayed_definition=Veri7vn_Native_Development.theorem built "Expert_Source.bump_def";
val _=if Thm.prop_of ordinary_definition aconv Thm.prop_of replayed_definition then ()
  else error "Source command changed its exported definition proposition";
fun code_equations thy =
 let val ctxt=Proof_Context.init_global thy
     val (_,equations)=Code.equations_of_cert thy (Code.get_cert ctxt [] "Expert_Source.bump")
 in case equations of SOME rows=>map_filter (fn (_, (th,_))=>Option.map Thm.prop_of th) rows
  | NONE=>error "Source definition lacks native executable equations" end;
val original_code=code_equations ordinary;
val replay_code=code_equations replayed;
val _=if not(null original_code) andalso length original_code=length replay_code andalso
  ListPair.allEq (op aconv) (original_code,replay_code) then ()
  else error "Source command changed native code equations";
fun source_spec thy expected =
 let val T=Sign.the_const_type thy "Expert_Source.bump"
 in exists (fn {terms,rules,...}=>exists (fn term=>term aconv Const("Expert_Source.bump",T)) terms
   andalso exists (fn th=>Thm.prop_of th aconv expected) rules)
   (Spec_Rules.retrieve_global thy (Const("Expert_Source.bump",T))) end;
val _=if source_spec ordinary (Thm.prop_of ordinary_definition) andalso
  source_spec replayed (Thm.prop_of replayed_definition) then ()
  else error "Source command lost native specification registration";

val consequence=Veri7vn_Native_Development.theorem built "Expert_Source.answer_correct";
val _ = if null (Thm_Deps.all_oracles [consequence]) then () else error "oracle";
val native_thy=Veri7vn_Native_Development.theory built;
val gen=Veri7vn_Native_Registry.generation (Proof_Context.init_global native_thy)
  {packages=[],runtime="development-test",policy="kernel",sources=[original],interpretation="exact"};
val (handle_,registry)=Veri7vn_Native_Registry.insert gen "consequence"
  (Veri7vn_Native_Registry.Theorem consequence) Veri7vn_Native_Registry.empty;
val target=Thm.cterm_of (Proof_Context.init_global native_thy) (Thm.prop_of consequence);
val _=case Veri7vn_Native_Admission.admit (Veri7vn_Native_Development.policy built)
  gen registry handle_ Veri7vn_Native_Admission.Kernel
  {claim=Veri7vn_Native_Admission.exact_claim target,hypotheses=[],premises=[],sorts=Thm.shyps_of consequence}
  of Veri7vn_Native_Admission.Accepted _ => ()
  | Veri7vn_Native_Admission.Rejected errors => error (commas errors);
fun rejected source =
  if can (replay)
    {expected_source=source,source=source,imports=[import]}
  then error "forbidden source accepted" else ();
val _=rejected ("theory Forgery imports " ^ import ^ " begin ML \"val p = Veri7vn_Native_Admission.policy @{theory}\" end");
val _=rejected ("theory False_Theorem imports " ^ import ^ " begin lemma impossible: \"False\" by simp end");
val _=rejected ("theory Tactic imports " ^ import ^ " begin lemma possible: \"True\" by (tactic \"ALLGOALS assume_tac\") end");
val _=rejected ("theory Axiom imports " ^ import ^ " begin axiomatization bad :: bool where false_fact: False end");
val _=if can (replay)
 {expected_source=original,source=original ^ " ",imports=[import]} then error "swapped source" else ();
val _=if can (replay)
 {expected_source=original,source=original,imports=["Main"]} then error "swapped parent" else ();
fun branch name constant value =
 let val text="theory " ^ name ^ " imports " ^ import ^ " begin definition " ^
   constant ^ " :: nat where \"" ^ constant ^ " = " ^ value ^ "\" end"
 in replay
  {expected_source=text,source=text,imports=[import]} end;
val left=branch "Left_Source" "left_value" "20";
val right=branch "Right_Source" "right_value" "22";
val joined_source="theory Joined_Source imports \"pkg.left\" \"pkg.right\" begin " ^
 "lemma total: \"Left_Source.left_value + Right_Source.right_value = 42\" " ^
 "by (simp add: Left_Source.left_value_def Right_Source.right_value_def) end";
val joined=Veri7vn_Native_Development.replay_parents
 [("pkg.left",Veri7vn_Native_Development.policy left),
  ("pkg.right",Veri7vn_Native_Development.policy right)]
 {expected_source=joined_source,source=joined_source,imports=["pkg.left","pkg.right"]};
val _=Veri7vn_Native_Development.theorem joined "Joined_Source.total";
val _=if can (Veri7vn_Native_Development.replay_parents
 [("pkg.left",Veri7vn_Native_Development.policy left),("pkg.right",base_policy)])
 {expected_source=joined_source,source=joined_source,imports=["pkg.left","pkg.right"]}
 then error "wrong approved import context accepted" else ();
writeln "native_development_source_reconstruction_ok";
\<close>
end
