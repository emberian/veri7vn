theory ConceptNet_Checks
 imports Veri7vn_ConceptNet_Source.ConceptNet_Source
begin
lemma confidence_one_exact:
 "concept_weight (Cell_RealBits [63,240,0,0,0,0,0,0])=Some concept_scale"
 by (simp add: byte_string_def concept_scale_def Let_def)
lemma confidence_negative_zero:
 "concept_weight (Cell_RealBits [128,0,0,0,0,0,0,0])=Some 0"
 by (simp add: byte_string_def Let_def)
lemma confidence_nonfinite_rejected:
 "concept_weight (Cell_RealBits [127,240,0,0,0,0,0,0])=None"
 by (simp add: byte_string_def Let_def)
lemma confidence_subnormal_exact:
 "concept_weight (Cell_RealBits [0,0,0,0,0,0,0,1])=Some 1"
 by (simp add: byte_string_def Let_def)
lemma numeric_surrogate_rejected:
 "concept_query 16 32 [97] [98] (Source_Batch 4 [] True)=ConceptSchemaRejected"
 by (simp add: concept_query_def)
ML \<open>
 val nat = Veri7vn_Numerals.nat_of_integer;
 fun label xs=map nat xs;
 val a=label [97]; val b=label [98]; val c=label [99];
 val isa=label [73,115,65];
 fun text x= @{code Cell_Text} x;
 fun row s t= [text isa,text s,text [],text t,text [],
    @{code Cell_RealBits} (label [63,240,0,0,0,0,0,0]),text [],text (label [100])];
 val rows=row a b :: replicate 30 (row b c);
 val batch= @{code Source_Batch} (nat 8,rows,false);
 val reply= @{code run_structured_concept_query} (@{code ConceptNetQuery} (nat 64,nat 64,a,c)) batch;
 val _ = (case reply of @{code ConceptPath} (dictionary,original,
      @{code FeasiblePath} (path,cost),false) =>
      if length path=2 andalso length original=2 andalso
        original=[row a b,row b c] andalso dictionary=[a,b,c]
      then () else error "ConceptNet dictionary/row path lineage changed"
   | _=>error "ConceptNet generated checked source chain failed");
 val _ = (case @{code concept_render_reply} reply of
    [(first,SOME caption),(second,SOME _)] =>
       if first=row a b andalso second=row b c andalso
          is_prefix (op =) (label [83,111,117,114,99,101,32,114,111,119,58,32]) caption
       then () else error "ConceptNet source caption lost original row provenance"
    | _=>error "ConceptNet typed row renderer failed");
 val _ = (case @{code run_structured_concept_query} (@{code ConceptNetQuery} (nat 64,nat 64,c,a)) batch of
    @{code ConceptCategoryGuard} => () | _=>error "ConceptNet degree filter lost");
 val d=label [100];
 val disconnected= @{code Source_Batch} (nat 8,rows @ [row d d],false);
 val _ = (case @{code run_structured_concept_query}
      (@{code ConceptNetQuery} (nat 64,nat 64,d,c)) disconnected of
    @{code ConceptInconclusive} _ => ()
    | _=>error "ConceptNet finite-view absence escaped inconclusive boundary");
 val _ = (case @{code run_structured_concept_query}
      (@{code ConceptNetQuery} (nat 64,nat 64,c,c)) batch of
    @{code ConceptInconclusive} _ => ()
    | _=>error "ConceptNet zero-hop path fabricated a source citation");
 val _ = if @{code concept_weight} (@{code Cell_RealBits} (label [63,240,0,0,0,0,0,0])) =
      @{code concept_weight} (@{code Cell_Integer} (false,label [1])) then ()
      else error "ConceptNet binary64/integer ranking disagreement";
 val _ = writeln "VERI7VN_CONCEPTNET generated exact-label checked partial-source chain PASS";
\<close>
end
