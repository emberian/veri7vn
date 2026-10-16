(* Proposal policy only: original keyword ordering, bounded fixed numeric
   operators, and actual retained-library inspection. No request text executes. *)
structure Veri7vn_Growth_Proposal_Policy =
struct
  type proposal={operations:string list,expression:term,source:string,unsupported:string list};
  val vocabulary=[("square",["square","squared"]),("double",["double","doubled","twice"]),
    ("increment",["add one","increment","plus one"]),("absolute",["absolute","abs value","magnitude"]),
    ("negate",["negate","flip the sign"])];
  fun position text word=let val n=size text val k=size word
    fun scan i=if i+k>n then NONE else if String.substring(text,i,k)=word then SOME i else scan(i+1)
    in scan 0 end;
  (* w37 chooses the first matching alias in each operator's declared order. *)
  fun hit text(name,aliases)=get_first(fn alias=>Option.map(fn at=>(at,name))(position text alias))aliases;
  fun step "square" expression= @{term Power} $ expression $ HOLogic.mk_number @{typ nat} 2
    | step "double" expression= @{term Times} $ expression $ @{term "Rational 2"}
    | step "increment" expression= @{term Plus} $ expression $ @{term "Rational 1"}
    | step "absolute" expression= @{term Absolute} $ expression
    | step "negate" expression= @{term Negate} $ expression
    | step _ _=error "Unknown fixed growth operation";
  val unsupported_words=["sort","descending","reverse","unique","duplicate","even","odd",
    "positive","negative","sum","count","maximum","minimum","average","mean","join",
    "string","word","list"];
  fun suggest text:proposal=
    let val _=if size text<=8192 then ()else error "Growth proposal request byte bound"
      val low=String.map Char.toLower text
      val hits=sort (prod_ord int_ord string_ord)(map_filter(hit low)vocabulary)
      val operations=map #2 hits
      val expression=fold step operations @{term "Parameter 0"}
      val unsupported=filter(is_some o position low)unsupported_words
      val source=if null operations orelse not(null unsupported) then "" else
        "definition proposed_recipe :: math_expr where\n  \"proposed_recipe = "^
        YXML.content_of(Syntax.string_of_term @{context} expression)^"\"\n"
    in {operations=operations,expression=expression,source=source,unsupported=unsupported}end;
  fun words text=String.tokens(not o Char.isAlphaNum)(String.map Char.toLower text);
end;

