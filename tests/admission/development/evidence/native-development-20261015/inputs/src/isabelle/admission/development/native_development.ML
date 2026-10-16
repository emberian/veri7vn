(* Receiver-owned source reconstruction. No source-supplied ML, attributes,
   command implementations, proof methods, or policy constructors are evaluated. *)
signature VERI7VN_NATIVE_DEVELOPMENT =
sig
  type built
  val replay: Veri7vn_Native_Admission.policy ->
    {expected_source:string, source:string, imports:string list} -> built
  val replay_parents: (string * Veri7vn_Native_Admission.policy) list ->
    {expected_source:string, source:string, imports:string list} -> built
  val command_spans: built -> {command:string,start:int,stop:int} list
  val source: built -> string
  val theory: built -> theory
  val policy: built -> Veri7vn_Native_Admission.policy
  val theorem: built -> string -> thm
end;
structure Veri7vn_Native_Development :> VERI7VN_NATIVE_DEVELOPMENT =
struct
  structure A=Veri7vn_Native_Admission;
  datatype built = Built of {source:string,theory:theory,policy:A.policy,
    spans:{command:string,start:int,stop:int} list};
  fun command_spans (Built {spans,...})=spans;
  fun source (Built {source,...})=source;
  fun theory (Built {theory,...})=theory;
  fun policy (Built {policy,...})=policy;
  fun theorem development name=Global_Theory.get_thm (theory development) name;
  datatype declaration = Definition of binding * string * string
    | Lemma of binding * string * string list;
  val definition_parser = Parse.command_name "definition" |-- Parse.binding --
    (Parse.$$$ "::" |-- Parse.typ) -- (Parse.$$$ "where" |-- Parse.prop)
    >> (fn ((b,T),p)=>Definition(b,T,p));
  (* This grammar is deliberately inert: method names and attributes never enter
     Method/Attrib/Outer_Syntax evaluators. Facts are resolved in native context. *)
  val lemma_parser = (Parse.command_name "lemma" || Parse.command_name "theorem") |--
    Parse.binding -- (Parse.$$$ ":" |-- Parse.prop) --
    (Parse.command_name "by" |--
      ((Parse.reserved "simp" >> K []) ||
       (Parse.$$$ "(" |-- Parse.reserved "simp" |--
         Scan.optional (Parse.reserved "add" |-- Parse.$$$ ":" |-- Scan.repeat1 Parse.name) []
         --| Parse.$$$ ")")))
    >> (fn ((b,p),facts)=>Lemma(b,p,facts));
  val parser = Parse.command_name "theory" |-- Parse.name --
    (Parse.$$$ "imports" |-- Scan.repeat1 Parse.name) --|
    Parse.$$$ "begin" -- Scan.repeat (definition_parser || lemma_parser) --|
    Parse.command_name "end";
  fun reconstruct (Definition(b,rawT,rawprop)) (p,_) =
    let val (p',_,_,thy')=A.define_command p b (SOME rawT) rawprop
    in (p',thy') end
    | reconstruct (Lemma(b,rawprop,facts)) (p,thy) =
    let
      val ctxt=Proof_Context.init_global thy;
      val prop=Syntax.read_prop ctxt rawprop;
      val rules=map (Proof_Context.get_thm ctxt) facts;
      val th=Goal.prove_global thy [] [] prop (fn {context,...} =>
        HEADGOAL (Simplifier.asm_full_simp_tac (fold Simplifier.add_simp rules context)));
      val (_,thy')=Global_Theory.add_thm ((b,th),[]) thy;
      val p'=A.advance p thy';
    in (p',thy') end;
  fun replay_parents approved_parents {expected_source,source=original,imports=expected_imports} =
    Timeout.apply (Time.fromSeconds 10) (fn () => let
      val _=if original=expected_source then () else error "Exact development source mismatch";
      val _=if size original<=1000000 then () else error "Development source byte bound";
      val _=if null approved_parents then error "Development requires approved native parents" else ();
      val locators=map #1 approved_parents;
      val _=if length(distinct (op =) locators)=length locators then ()
        else error "Duplicate approved source import locator";
      val policies=map #2 approved_parents;
      val parents=map A.policy_theory policies;
      (* Keyword parsing uses the actual merged approved native parent context. *)
      val base=hd parents;
      val keywords=fold (fn parent => fn known => Keyword.merge_keywords
        (known,Thy_Header.get_keywords parent)) (tl parents)
        (Thy_Header.get_keywords base);
      val located=Veri7vn_Native_Source_Tokens.tokenize keywords original;
      val tokens=map #token located;
      fun spans []=[]
        | spans [(command,start)]=[{command=command,start=start,stop=size original}]
        | spans ((command,start)::(next as (_,stop))::rest)=
            {command=command,start=start,stop=stop}::spans(next::rest);
      val original_spans=spans(map_filter (fn {token,start,...}=>
        if Token.is_command token then SOME(Token.content_of token,start) else NONE) located);
      val ((name,imports),declarations)=
        (case Scan.read Token.stopper parser (filter Token.is_proper tokens) of
          SOME result=>result | NONE=>error "Unsupported controlled expert development syntax");
      val _=if imports=expected_imports andalso imports=locators
        then () else error "Development imports differ from actual approved native parent";
      val _=if Thy_Header.is_base_name name then () else error "Development requires a base theory name";
      val child=Theory.begin_theory (name,Position.none) parents;
      val initial=A.join policies child;
      val (current,theory0)=fold reconstruct declarations (initial,child);
      val theory=Theory.end_theory theory0;
      val policy=A.advance current theory;
    in Built {source=original,theory=theory,policy=policy,spans=original_spans} end) ();
  fun replay approved inputs = replay_parents
    [(Context.theory_name {long=false} (A.policy_theory approved),approved)] inputs;
end;
