theory Domain_Display_Checks
  imports "Veri7vn_Domain_Checked_Display.Domain_Checked_Display"
begin
lemma exact_domain_display_examples:
  "checked_domain_statement (LinearValue Inch (470/127)) [] False [69,120,97,99,116,32,113,117,97,110,116,105,116,121,32,52,55,48,47,49,50,55,32,105,110] \<noteq> None"
  "checked_domain_statement (PointValue Fahrenheit 32) [] False [69,120,97,99,116,32,116,101,109,112,101,114,97,116,117,114,101,45,112,111,105,110,116,32,51,50,47,49,32,100,101,103,70] \<noteq> None"
  "checked_domain_statement (DeltaValue Fahrenheit 18) [] False [69,120,97,99,116,32,116,101,109,112,101,114,97,116,117,114,101,45,100,105,102,102,101,114,101,110,99,101,32,49,56,47,49,32,100,101,103,70] \<noteq> None"
  "checked_domain_statement (LinearValue Joule 1) [105,700] True [67,111,110,100,105,116,105,111,110,97,108,32,111,110,32,97,108,108,32,50,32,97,116,116,97,99,104,101,100,32,112,114,101,109,105,115,101,115,58,32,69,120,97,99,116,32,113,117,97,110,116,105,116,121,32,49,47,49,32,74,32,117,110,100,101,114,32,116,104,101,32,97,100,111,112,116,101,100,32,105,100,101,97,108,32,115,112,114,105,110,103,32,114,101,115,112,111,110,115,101,32,109,111,100,101,108] \<noteq> None"
  by eval+
lemma domain_display_refusals:
  "checked_domain_statement (DeltaValue Fahrenheit 32) [] False [69,120,97,99,116,32,116,101,109,112,101,114,97,116,117,114,101,45,112,111,105,110,116,32,51,50,47,49,32,100,101,103,70] = None"
  "checked_domain_statement (LinearValue Joule 1) [105,700] True [69,120,97,99,116,32,113,117,97,110,116,105,116,121,32,49,47,49,32,74,32,117,110,100,101,114,32,116,104,101,32,97,100,111,112,116,101,100,32,105,100,101,97,108,32,115,112,114,105,110,103,32,114,101,115,112,111,110,115,101,32,109,111,100,101,108] = None"
  "checked_domain_statement (LinearValue Joule 1) [105,700] True [67,111,110,100,105,116,105,111,110,97,108,32,111,110,32,97,108,108,32,50,32,97,116,116,97,99,104,101,100,32,112,114,101,109,105,115,101,115,58,32,69,120,97,99,116,32,113,117,97,110,116,105,116,121,32,49,47,49,32,74] = None"
  "checked_domain_statement (LinearValue Joule 1) [105,700] True [67,111,110,100,105,116,105,111,110,97,108,32,111,110,32,97,108,108,32,49,32,97,116,116,97,99,104,101,100,32,112,114,101,109,105,115,101,115,58,32,69,120,97,99,116,32,113,117,97,110,116,105,116,121,32,49,47,49,32,74,32,117,110,100,101,114,32,116,104,101,32,97,100,111,112,116,101,100,32,105,100,101,97,108,32,115,112,114,105,110,103,32,114,101,115,112,111,110,115,101,32,109,111,100,101,108] = None"
  "checked_domain_statement (LinearValue Joule 1) [] False [69,120,97,99,116,32,113,117,97,110,116,105,116,121,32,49,47,48,32,74] = None"
  "checked_domain_statement (LinearValue Joule 1) [] False [69,120,97,99,116,32,113,117,97,110,116,105,116,121,32,49,47,49,32,78] = None"
  "checked_domain_statement (LinearValue Joule 1) [] False [69,120,97,99,116,32,113,117,97,110,116,105,116,121,32,49,47,49,32,60,115,99,114,105,112,116,62] = None"
  by eval+

ML \<open>
local
  structure IDs=Veri7vn_Native_Identity_Allocator;
  structure P=Veri7vn_Managed_Provenance;
  structure A=Veri7vn_Native_Admission;
  structure L=Veri7vn_Native_Literals;
  structure C=Veri7vn_Domain_Conditions;
  structure D=Veri7vn_Domain_Request;
  structure M=Veri7vn_Domain_Execution;
  structure E=Veri7vn_Executable_Identity;
  structure V=Veri7vn_Domain_Display;
  structure G=Veri7vn_Domain_Native_Gate;
  val ids=IDs.install_host_block{workspace="d15d15d15d15d15d15d15d15d15d15d1",first=1,past=1000};
  val policy=A.policy @{theory};
  val development=P.public_image ids policy;
  fun owned text=let val owner=L.input{bytes=text,encoding="UTF-8"}
    in(owner,P.install_host_source ids owner,
      L.slice owner{start=0,stop=size text,expected=text})end;
  val(declaration,source,slice)=owned "ideal_spring_model force_response energy_response";
  val model=C.prepare{allocator=ids,development=development,source=source,slice=slice,
    role=C.IdealSpringModel,proposition= @{cprop "ideal_spring_model force_response energy_response"}};
  fun ready(M.Ready value)=value | ready(M.Refused _)=error "Display domain execution refused";
  val instance=ready(M.attach{policy=policy,generation=P.generation development,
    code_context=E.code_theory(M.executable()),limits={nodes=5000,depth=100,seconds=2}});
  val text="registered_domain_dispatch (DomainCall (Spring SpringEnergy) " ^
    "[LinearValue NewtonPerMetre 200,LinearValue Metre (Fract 1 10)] [] (Some " ^
    IntInf.toString(C.identity model) ^ "))";
  val(owner,source,slice)=owned text;
  val input=Thm.cterm_of @{context}(Syntax.read_term @{context} text);
  fun prepare()=D.prepare{allocator=ids,instance=instance,development=development,
    source=source,slice=slice,input=input,conditions=[model]};
  val request=prepare();
  val output=ready(M.execute(M.executable())instance(D.family_request request));
  val other=prepare();
  val other_output=ready(M.execute(M.executable())instance(D.family_request other));
  val bridge=V.attach{allocator=ids,policy=policy,instance=instance};
  val sentence="Conditional on all 1 attached premises: Exact quantity 1/1 J under the adopted ideal spring response model";
  val display=V.prepare_exact bridge request output;
  val projected=V.project display;
  val witness=G.specialize bridge request output;
  val retained_root=Unsynchronized.ref(NONE:G.witness option);
  val retained=G.retain_into witness retained_root;
  val _=if G.matches_snapshot retained(G.snapshot witness) then ()
    else error "Retained native association changed its frozen correspondence";
  val _=G.release retained;
  val _=if not(G.live retained) andalso G.live witness then ()
    else error "Sibling domain evidence lifetime was coupled";
  val cancelled_witness=Unsynchronized.ref(NONE:G.witness option);
  val cancellation=Exn.capture(fn()=>Thread_Attributes.uninterruptible(fn restore=>fn()=>
    let val _=restore(fn()=>ignore(G.specialize_into bridge request output cancelled_witness))()
    in restore(fn()=>raise Thread.Thread.Interrupt)()end)())();
  val _=case cancellation of Exn.Exn exn=>if Exn.is_interrupt exn then ()else Exn.reraise exn
    | Exn.Res _=>error "Domain evidence rollback did not interrupt";
  val _=case !cancelled_witness of SOME w=>G.release w
    | NONE=>error "Interrupted domain evidence lost condition-lease cleanup ownership";
  val _=if G.live witness then ()else error "Cancelled evidence retired an independent owner";
  val saved=G.snapshot witness;
  val changed:G.saved={request= #request saved,output= #output saved,target= @{prop True},
    implementation= #implementation saved,model_contract= #model_contract saved,
    rendering_contract= #rendering_contract saved,statement_html= #statement_html saved};
  val _=if G.matches_snapshot witness saved andalso not(G.matches_snapshot witness changed)
    then ()else error "Domain runtime-refinement snapshot accepted changed target";
  val _=if G.live witness andalso is_some(G.model_contract witness) andalso
    Thm.term_of(G.target witness) aconv Thm.term_of(D.specialize request output) andalso
    map Thm.term_of(G.assumptions witness)=[Thm.term_of(C.proposition model)]
    then ()else error "Domain gate lost conditional target/contract/assumption";
  val _=case #conditions projected of [condition]=>
      if #identity condition=C.identity model andalso #owner_identity condition=C.owner_identity model andalso
        #statement condition=L.original(C.source_slice model) andalso
        Thm.term_of(#proposition condition) aconv Thm.term_of(C.proposition model) andalso #model projected
      then () else error "Domain display lost full exact premise/source association"
    | _=>error "Domain display lost model premise";
  fun refuses f=if can f()then error "Invalid domain display accepted" else ();
  val _=refuses(fn()=>V.prepare bridge request other_output sentence);
  val _=refuses(fn()=>V.prepare bridge request output
    "Conditional on all 1 attached premises: Exact quantity 2/1 J under the adopted ideal spring response model");
  val _=refuses(fn()=>V.prepare bridge request output "Exact quantity 1/1 J");
  val _=C.release model;
  val _=refuses(fn()=>V.project display);
  val _=if G.live witness then error "Invalid model retained native domain gate"else ();
  val _=G.release witness;
  val _=D.release request;
  val _=D.release other;
  val _=V.release bridge;
  val _=M.release_instance instance;
  val _=Option.app IDs.release_disposed_input(L.drop_base owner);
  val _=Option.app IDs.release_disposed_input(L.drop_base declaration);
  val _=if L.disposed declaration then ()else error "Domain evidence cancellation leaked premise source lease";
  val _=P.release development;
in val _=writeln "VERI7VN_DOMAINS checked_display PASS" end;
\<close>
end
